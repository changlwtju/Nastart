#!/usr/bin/env python3
"""Exercise the Agent upgrade transaction with isolated releases on local Docker."""

from __future__ import annotations

import getpass
import json
import os
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import tempfile
import time
from contextlib import contextmanager
from collections.abc import Iterator
from pathlib import Path

from agent_smoke_test import request_json, require_status
from verify_agent_docker import AGENT_DIR, SERVICE, command, wait_for_health


def prepare_release(directory: Path, version: str, container: str, *, broken: bool = False) -> None:
    directory.mkdir(parents=True)
    for name in ("compose.sh", "Dockerfile"):
        shutil.copy2(AGENT_DIR / name, directory / name)
    source = (AGENT_DIR / "nastart_agent.py").read_text()
    source, count = re.subn(r'^AGENT_VERSION = "[^"]+"$', f'AGENT_VERSION = "{version}"', source, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError("Expected a single AGENT_VERSION assignment")
    if broken:
        health = 'self.respond(200, {"ok": True, "version": AGENT_VERSION})'
        if source.count(health) != 1:
            raise RuntimeError("Cannot locate the fixture health handler")
        source = source.replace(health, 'self.respond(503, {"ok": False, "version": AGENT_VERSION})')
    (directory / "nastart_agent.py").write_text(source)

    compose = (AGENT_DIR / "compose.yaml").read_text()
    compose = compose.replace("container_name: nastart-agent", f"container_name: {container}")
    compose = compose.replace('"8787:8787"', '"127.0.0.1::8787"')
    compose = compose.replace("      - /var/run/docker.sock:/var/run/docker.sock:ro\n", "")
    (directory / "compose.yaml").write_text(compose)


@contextmanager
def loopback_ssh(directory: Path, remote_home: Path) -> Iterator[tuple[int, dict[str, str]]]:
    user = getpass.getuser()
    directory.mkdir()
    remote_home.mkdir()
    for key in ("host", "client"):
        command("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(directory / key))
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]

    remote_shell = directory / "session.sh"
    docker_config = os.environ.get("DOCKER_CONFIG", str(Path.home() / ".docker"))
    remote_shell.write_text(
        f"export HOME={shlex.quote(str(remote_home))}\n"
        f"export DOCKER_CONFIG={shlex.quote(docker_config)}\n"
        f"export PATH={shlex.quote(os.environ['PATH'])}\n"
        'cd "$HOME" && exec /bin/sh -c "$SSH_ORIGINAL_COMMAND"\n'
    )
    config = directory / "sshd_config"
    config.write_text(
        f"ListenAddress 127.0.0.1\nPort {port}\nAllowUsers {user}\n"
        f"HostKey {json.dumps(str(directory / 'host'))}\n"
        f"PidFile {json.dumps(str(directory / 'sshd.pid'))}\n"
        f"AuthorizedKeysFile {json.dumps(str(directory / 'client.pub'))}\n"
        "UsePAM no\nStrictModes no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n"
        f"ForceCommand /bin/sh {shlex.quote(str(remote_shell))}\n"
    )
    client_dir = directory / "bin"
    client_dir.mkdir()
    client = client_dir / "ssh"
    client.write_text(
        "#!/bin/sh\nexec /usr/bin/ssh -F /dev/null -o BatchMode=yes "
        f"-o UserKnownHostsFile={shlex.quote(str(directory / 'known_hosts'))} "
        f"-o IdentitiesOnly=yes -i {shlex.quote(str(directory / 'client'))} \"$@\"\n"
    )
    client.chmod(0o700)
    with (directory / "sshd.log").open("w") as log:
        daemon = subprocess.Popen(["/usr/sbin/sshd", "-D", "-e", "-f", str(config)], stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 5
            while True:
                if daemon.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError((directory / "sshd.log").read_text())
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                        break
                except OSError:
                    time.sleep(0.1)
            yield port, dict(os.environ, PATH=f"{client_dir}{os.pathsep}{os.environ['PATH']}")
        finally:
            if daemon.poll() is None:
                daemon.terminate()
            daemon.wait(timeout=5)


def verify(directory: Path, remote_home: Path, ssh_port: int, ssh_env: dict[str, str]) -> None:
    suffix = secrets.token_hex(4)
    project = f"nastart-agent-upgrade-check-{suffix}"
    active = remote_home / ".nastart-agent"
    candidate, broken = (directory / name / "agent" for name in ("candidate", "broken"))
    old_version, new_version, bad_version = (f"{base}-verify-{suffix}" for base in ("0.1.0", "0.1.1", "0.1.2"))
    prepare_release(active, old_version, project)
    compose_path = active / "compose.yaml"
    compose_path.write_text(compose_path.read_text().replace(
        "${NASTART_DOCKERHUB_NAMESPACE:?set NASTART_DOCKERHUB_NAMESPACE}/", ""
    ))
    prepare_release(candidate, new_version, project)
    prepare_release(broken, bad_version, project, broken=True)
    code = f"{secrets.randbelow(1_000_000):06d}"
    env = dict(os.environ, NASTART_PAIRING_CODE=code, NASTART_DOCKERHUB_NAMESPACE=project)
    compose = ("sh", str(active / "compose.sh"), "-p", project)
    scripts = Path(__file__).resolve().parent
    token_file = directory / "token"

    def data_volume() -> str:
        return command("docker", "inspect", "--format",
                       '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}',
                       project, capture=True)

    def image_tag(version: str) -> str:
        prefix = "" if version == old_version else f"{project}/"
        return f"{prefix}{SERVICE}:{version}"

    def image_id(version: str) -> str:
        return command("docker", "image", "inspect", "--format", "{{.Id}}", image_tag(version), capture=True)

    def upgrade(source: Path) -> subprocess.CompletedProcess[str]:
        bundle_scripts = source.parent / "scripts"
        bundle_scripts.mkdir()
        for name in ("upgrade_agent_via_ssh.sh", "upgrade_agent_on_host.sh"):
            shutil.copy2(scripts / name, bundle_scripts / name)
        result = subprocess.run(
            ["bash", str(bundle_scripts / "upgrade_agent_via_ssh.sh"), "--host", "127.0.0.1",
             "--user", getpass.getuser(), "--port", str(ssh_port), "--token-file", str(token_file),
             "--container", project, "--timeout", "30", "--build"],
            env=dict(ssh_env, NASTART_DOCKERHUB_NAMESPACE=project),
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300,
        )
        print(result.stdout, end="", flush=True)
        if list(remote_home.glob(".nastart-agent-upgrade.*")):
            raise RuntimeError("An SSH staging directory remained after the transaction")
        return result

    try:
        command(*compose, "build", SERVICE, env=env)
        command(*compose, "up", "-d", "--no-build", "--pull", "never", SERVICE, env=env)
        wait_for_health(project, "healthy")
        volume = data_volume()
        if not volume:
            raise RuntimeError("The fixture did not mount its data volume")
        previous_id = image_id(old_version)
        host_port = command(*compose, "port", SERVICE, "8787", capture=True, env=env)
        status, paired = request_json(f"http://{host_port}", "/v1/pair", body={"code": code})
        require_status("initial pairing", status, paired)
        token = paired.get("token")
        if not isinstance(token, str) or not token:
            raise RuntimeError("Pairing did not return a token")
        with os.fdopen(os.open(token_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600), "w") as file:
            file.write(token)
        print(f"Paired once before upgrade. Data volume={volume}", flush=True)

        first = upgrade(candidate)
        if first.returncode != 0 or "Upgraded to" not in first.stdout:
            raise RuntimeError("The healthy candidate did not complete the upgrade")
        if data_volume() != volume or image_id(old_version) != previous_id:
            raise RuntimeError("The successful upgrade replaced the volume or previous image")
        healthy_id = image_id(new_version)

        second = upgrade(broken)
        if (second.returncode != 1 or "running unhealthy" not in second.stdout
                or f"Rolled back to {image_tag(new_version)}" not in second.stdout):
            raise RuntimeError("The broken candidate did not exercise the verified rollback")
        if data_volume() != volume or image_id(new_version) != healthy_id:
            raise RuntimeError("Rollback did not keep the same volume and previous image")
        for name in ("nastart_agent.py", "Dockerfile", "compose.yaml", "compose.sh"):
            if (active / name).read_bytes() != (candidate / name).read_bytes():
                raise RuntimeError(f"Rollback did not restore {name}")
        print(f"Verified rollback exit={second.returncode}. Same volume={volume}; same initial token accepted.", flush=True)
    finally:
        command(*compose, "down", "--volumes", "--timeout", "3", env=env)
        for version in (old_version, new_version, bad_version):
            tag = image_tag(version)
            if subprocess.run(["docker", "image", "inspect", tag],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                command("docker", "image", "rm", tag)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="nastart-agent-upgrade-test-") as temporary:
        directory = Path(temporary)
        remote_home = directory / "remote"
        with loopback_ssh(directory / "ssh", remote_home) as (port, env):
            print("Running both transactions through an isolated loopback SSH server.", flush=True)
            verify(directory, remote_home, port, env)
