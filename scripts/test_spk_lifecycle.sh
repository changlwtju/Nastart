#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
if (( $# > 1 )); then
    echo "Usage: $0 [built.spk]" >&2
    exit 2
fi
cd "$root"
PYTHONPATH="$root/scripts" python3 - "${1:-}" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import ssl
import stat
import subprocess
import sys
import tarfile
import tempfile
from http.client import RemoteDisconnected
from urllib.error import URLError

from agent_smoke_test import request_json


def command(*args, env=None, stdin=None, expected=0, timeout=120):
    result = subprocess.run(
        args, env=env, input=stdin, text=True, capture_output=True, timeout=timeout,
    )
    if result.returncode != expected:
        # This helper is never used to pass a secret as an argument or to print Docker logs.
        raise RuntimeError(f"{' '.join(map(str, args))}: exit {result.returncode}: {result.stderr.strip()}")
    return result.stdout.strip()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_dsm_project(temp, package, target, resource):
    projects = resource["docker-project"]["projects"]
    require(len(projects) == 1, "expected one DSM Docker project")
    project = f"{temp.name}-worker"
    project_dir = target / projects[0]["path"]
    compose_file = project_dir / "compose.yaml"
    template = compose_file.read_text()
    data = package / "var"
    agent_data = data / "container-data"
    image = re.search(r'^    image: "([^"]+)"$', template, re.MULTILINE)[1]
    socket_gid = command("docker", "run", "--rm", "--network", "none", "--entrypoint", "stat",
                         "-v", "/var/run/docker.sock:/var/run/docker.sock:ro",
                         image, "-c", "%g", "/var/run/docker.sock")
    require(socket_gid.isdecimal(), "could not resolve the fixture Docker socket group")
    # On Docker Desktop the daemon and its socket are inside the Linux VM.
    fixture_bin = temp / "bin"
    fixture_bin.mkdir()
    stat_stub = fixture_bin / "stat"
    stat_stub.write_text(f"#!/bin/sh\nprintf '%s\\n' '{socket_gid}'\n")
    stat_stub.chmod(0o755)
    env = dict(os.environ, SYNOPKG_PKGNAME="nastart-agent", SYNOPKG_PKGDEST=str(target),
               SYNOPKG_PKGVAR=str(data), SYNOPKG_PKGINST_TEMP_DIR=str(target),
               SYNOPKG_TEMP_LOGFILE=str(temp / "package.log"), PATH=f"{fixture_bin}:{os.environ['PATH']}")
    compose_cli = ("docker", "compose")
    try:
        command(*compose_cli, "version")
    except RuntimeError:
        compose_cli = ("docker-compose",)

    def compose(*args):
        return command(*compose_cli, "-p", project, "--env-file", project_dir / ".env",
                       "-f", compose_file, *args, timeout=240)

    def install(phase):
        compose_file.write_text(template)
        command(package / "scripts" / "preinst", env=dict(env, SYNOPKG_PKG_STATUS=phase))
        # DSM creates the package var directory before handing off to the Worker.
        data.mkdir(exist_ok=True)
        config = compose_file.read_text()
        require(config.count('"8787:8787"') == 1, "SPK is missing the normal TCP 8787 mapping")
        compose_file.write_text(config.replace('"8787:8787"', '"127.0.0.1::8787"'))
        compose("config", "--quiet")
        compose("up", "--no-start", "--no-build")
        command(package / "scripts" / "start-stop-status", "start", env=env)
        compose("start")

    def connect():
        from time import monotonic, sleep

        deadline = monotonic() + 45
        while monotonic() < deadline:
            try:
                agent = compose("ps", "-q", "agent")
                published = command("docker", "port", agent, "8787/tcp")
                require(re.fullmatch(r"127\.0\.0\.1:\d+", published), "test port escaped loopback")
                cert = (agent_data / "tls-cert.pem").read_text()
                context = ssl.create_default_context(cadata=cert)
                url = f"https://{published}"
                http, payload = request_json(url, "/healthz", context=context)
                if http == 200 and payload.get("ok"):
                    return url, context, hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert)).hexdigest()
            except (OSError, RuntimeError, URLError):
                sleep(1)
        raise RuntimeError("DSM project did not become healthy over HTTPS")

    def retained_state():
        return {name: hashlib.sha256((agent_data / name).read_bytes()).hexdigest() for name in
                ("agent-id", "pairing-token", "pairing-code-digest", "spk-pairing-code",
                 "tls-cert.pem", "tls-key.pem")}

    try:
        install("INSTALL")
        url, context, fingerprint = connect()
        require(stat.S_IMODE(agent_data.stat().st_mode) == 0o700, "Agent data directory is not private")
        code_file = agent_data / "spk-pairing-code"
        code = code_file.read_text().strip()
        require(re.fullmatch(r"[0-9]{6}", code) and stat.S_IMODE(code_file.stat().st_mode) == 0o600,
                "expected a private one-time pairing code in the package data directory")
        agent = compose("ps", "-q", "agent")
        require(f"One-time pairing code: {code}" in command("docker", "logs", agent),
                "first startup did not provide the one-time pairing code")
        http, paired = request_json(url, "/v1/pair", body={"code": code}, context=context)
        require(http == 200 and paired.get("token") and paired.get("providerHint") == "synology",
                "fresh DSM project pairing failed")
        token, identity = paired["token"], paired["agentId"]
        snapshot = retained_state()

        def verify_retained(phase):
            url, context, live_fingerprint = connect()
            http, handshake = request_json(url, "/v1/handshake", token=token, context=context)
            require(http == 200 and handshake.get("agentId") == identity and
                    handshake["certificate"]["fingerprintSha256"] == live_fingerprint == fingerprint and
                    "docker.containers.read" in handshake["capabilities"],
                    f"{phase}: Agent identity, certificate or Docker proxy changed")
            http, _ = request_json(url, "/v1/pair", body={"code": code}, context=context)
            require(http == 401 and retained_state() == snapshot, f"{phase}: pairing state changed")
            print(f"PASS {phase}: persistent identity, TLS, one-time pairing and filtered Docker proxy", flush=True)

        verify_retained("worker install")
        command(package / "scripts" / "start-stop-status", "stop", env=env)
        compose("stop")
        require(not compose("ps", "-q", "agent"), "worker stop left the Agent running")
        compose("start")
        verify_retained("worker stop and restart")
        for phase in ("UPGRADE", "INSTALL"):
            compose("down", "--volumes")
            compose_file.unlink()
            require(retained_state() == snapshot, "project removal changed the DSM data directory")
            install(phase)
            verify_retained("worker upgrade" if phase == "UPGRADE" else "worker uninstall and reinstall")
    finally:
        if compose_file.exists():
            compose("down", "--volumes")


command("docker", "info", "--format", "{{.ServerVersion}}")
try:
    command("docker", "compose", "version")
except RuntimeError:
    command("docker-compose", "version")
with tempfile.TemporaryDirectory(prefix="nastart-spk-") as directory:
    temp = Path(directory)
    spk = Path(sys.argv[1]).resolve() if sys.argv[1] else temp / "test.spk"
    if not sys.argv[1]:
        print(command("scripts/build_spk.sh", spk), flush=True)
    package = temp / "package"
    target = package / "target"
    data = package / "var"
    target.mkdir(parents=True)
    with tarfile.open(spk) as archive:
        archive.extractall(package, filter="data")
    with tarfile.open(package / "package.tgz") as archive:
        archive.extractall(target, filter="data")
    resource_path = package / "conf" / "resource"
    if resource_path.is_file():
        resource = json.loads(resource_path.read_text())
        if "docker-project" in resource:
            verify_dsm_project(temp, package, target, resource)
            sys.exit(0)
    image_file = target / "image"
    image = image_file.read_text().strip()
    version = image.rsplit(":", 1)[1]
    major, minor, patch = version.split(".")
    next_version = f"{major}.{minor}.{int(patch) + 1}"

    # DSM normally uses port 8787. Keep the fixture on loopback and let Docker
    # choose a free port so the user's existing Nastart stack stays available.
    compose_file = target / "compose.yaml"
    config = compose_file.read_text()
    require(config.count('"8787:8787"') == 1, "SPK is missing the normal TCP 8787 mapping")
    compose_file.write_text(config.replace('"8787:8787"', '"127.0.0.1::8787"'))
    name = temp.name
    project = f"{name}-spk"
    volume = f"{project}-data"
    label = f"label=com.docker.compose.project={project}"
    env = dict(os.environ, SYNOPKG_PKGNAME=name, SYNOPKG_PKGDEST=str(target),
               SYNOPKG_PKGVAR=str(data), SYNOPKG_TEMP_LOGFILE=str(temp / "package.log"))
    registry = ""
    candidate = ""
    code_file = data / "pairing-code"

    def hook(script, *args, phase="INSTALL", expected=0, **overrides):
        return command(package / "scripts" / script, *args, expected=expected,
                       env=dict(env, SYNOPKG_PKG_STATUS=phase, **overrides), timeout=240)

    def service_id(service):
        value = command("docker", "ps", "-q", "--filter", label,
                        "--filter", f"label=com.docker.compose.service={service}")
        require(len(value.splitlines()) == 1, f"expected one running {service} container")
        return value

    def verify_live(expected_version):
        hook("start-stop-status", "status")
        agent = service_id("agent")
        published = command("docker", "port", agent, "8787/tcp")
        require(re.fullmatch(r"127\.0\.0\.1:\d+", published), "test port escaped loopback")
        cert = command("docker", "exec", agent, "cat", "/data/tls-cert.pem")
        context = ssl.create_default_context(cadata=cert)
        fingerprint = hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert)).hexdigest()
        url = f"https://{published}"
        http, payload = request_json(url, "/healthz", context=context)
        require(http == 200 and payload == {"ok": True, "version": expected_version},
                f"HTTPS health did not return version {expected_version}")
        return agent, url, context, fingerprint

    def retained_state(agent):
        code = """
import hashlib
from pathlib import Path
for name in ('agent-id', 'pairing-token', 'pairing-code-digest', 'spk-pairing-code',
             'tls-cert.pem', 'tls-key.pem'):
    print(hashlib.sha256((Path('/data') / name).read_bytes()).hexdigest())
"""
        return command("docker", "exec", agent, "python3", "-c", code)

    def retained_client(expected_version, phase):
        agent, url, context, fingerprint = verify_live(expected_version)
        http, response = request_json(url, "/v1/handshake", token=token, context=context)
        require(http == 200 and response.get("agentId") == identity and
                response.get("agentVersion") == expected_version and
                response["certificate"]["fingerprintSha256"] == fingerprint == original_fingerprint and
                "docker.containers.read" in response["capabilities"],
                f"{phase}: original HTTPS client or Docker proxy verification failed")
        http, response = request_json(url, "/v1/diagnostics", token=token, context=context)
        require(http == 200 and original_event in response["events"], f"{phase}: event history lost")
        http, _ = request_json(url, "/v1/pair", body={"code": pairing_code}, context=context)
        require(http == 401, f"{phase}: consumed pairing code was accepted again")
        require(retained_state(agent) == original_state, f"{phase}: persistent files changed")
        require(code_file.read_text().strip() == pairing_code, f"{phase}: package code changed")
        print(f"PASS {phase}: HTTPS {expected_version}, original token, ID, certificate, code state and events", flush=True)

    def assert_down():
        hook("start-stop-status", "status", expected=3)
        for resource, args in (
            ("containers", ("ps", "-aq")),
            ("network", ("network", "ls", "-q")),
            ("proxy socket volume", ("volume", "ls", "-q")),
        ):
            require(not command("docker", *args, "--filter", label), f"project {resource} remain")
        command("docker", "volume", "inspect", volume)

    def cleanup(*args):
        result = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=90)
        if result.returncode:
            raise RuntimeError(f"Cleanup failed for {' '.join(args)}: {result.stderr.strip()}")

    try:
        hook("preinst", expected=1, DOCKER_HOST=f"unix://{temp}/missing.sock", DOCKER_CONTEXT="")
        require("Container Manager" in (temp / "package.log").read_text(), "missing Docker guidance")
        require(not data.exists() and not command("docker", "ps", "-aq", "--filter", label),
                "preinstall failure left resources")
        print("PASS dependency preflight fails cleanly when Docker is unavailable", flush=True)

        hook("preinst")
        hook("postinst")
        agent, url, context, original_fingerprint = verify_live(version)
        running_agent = agent
        hook("start-stop-status", "start")
        require(service_id("agent") == running_agent, "start after postinst recreated the Agent")
        try:
            request_json(url.replace("https://", "http://", 1), "/healthz")
        except (ConnectionError, RemoteDisconnected, URLError):
            pass
        else:
            raise RuntimeError("plaintext HTTP was accepted")
        pairing_code = code_file.read_text().strip()
        require(re.fullmatch(r"[0-9]{6}", pairing_code) and stat.S_IMODE(code_file.stat().st_mode) == 0o600,
                "expected a six-digit code in a private package file")
        require(f"One-time pairing code: {pairing_code}" in command("docker", "logs", agent),
                "Agent container log lacks the package's one-time pairing code")
        http, paired = request_json(url, "/v1/pair", body={"code": pairing_code}, context=context)
        require(http == 200 and paired.get("token") and paired.get("providerHint") == "synology", "pairing failed")
        token, identity = paired["token"], paired["agentId"]
        http, _ = request_json(url, "/v1/pair", body={"code": pairing_code}, context=context)
        require(http == 401, "one-time pairing enforcement failed")
        http, diagnostics = request_json(url, "/v1/diagnostics", token=token, context=context)
        require(http == 200, "diagnostics failed")
        original_event = next(event for event in diagnostics["events"] if event["type"] == "pairing.failed")
        original_state = retained_state(agent)
        retained_client(version, "install and start")

        hook("start-stop-status", "stop", phase="STOP")
        assert_down()
        hook("start-stop-status", "start", phase="START")
        retained_client(version, "stop and restart")

        # Publish a disposable image to a local registry. Its only Agent change
        # is the version in the fixture layer. The checkout and Docker Hub are untouched.
        with socket.socket() as port:
            port.bind(("127.0.0.1", 0))
            registry_address = f"127.0.0.1:{port.getsockname()[1]}"
        # Docker Desktop's daemon is inside a VM. Bind the registry on that
        # loopback, where Docker itself can push and pull, without publishing it.
        registry = command("docker", "run", "-d", "--network", "host",
                           "-e", f"REGISTRY_HTTP_ADDR={registry_address}", "registry:2", timeout=240)
        candidate = f"{registry_address}/nastart-agent:{next_version}"
        command(
            "docker", "build", "-t", candidate, "-", timeout=240,
            stdin=f"""FROM {image}
USER root
RUN sed -i 's/^AGENT_VERSION = .*/AGENT_VERSION = "{next_version}"/' /app/nastart_agent.py
USER nastart
""",
        )
        command("docker", "push", candidate, timeout=240)
        command("docker", "image", "rm", candidate)

        # DSM invokes old stop, new preupgrade, old uninstallation hooks and
        # new installation hooks before postupgrade. Replace target at that boundary.
        hook("start-stop-status", "stop", phase="UPGRADE")
        assert_down()
        launcher = target / "compose.sh"
        old_launcher = launcher.read_bytes()
        launcher.write_text("#!/bin/sh\nexit 42\n")
        try:
            hook("preupgrade", phase="UPGRADE")
        finally:
            launcher.write_bytes(old_launcher)
        print("PASS preupgrade with an empty project and an unusable old launcher", flush=True)
        hook("preuninst", phase="UPGRADE")
        hook("postuninst", phase="UPGRADE")
        assert_down()
        hook("preinst", phase="UPGRADE")
        image_file.write_text(candidate + "\n")
        hook("postinst", phase="UPGRADE")
        assert_down()
        hook("postupgrade", phase="UPGRADE")
        command("docker", "image", "inspect", candidate)
        hook("start-stop-status", "start", phase="UPGRADE")
        retained_client(next_version, "upgrade with a newly pulled image")

        # Run the actual uninstall hooks and then simulate DSM removing package
        # files. Only the external Agent data volume may remain.
        hook("start-stop-status", "stop", phase="UNINSTALL")
        hook("preuninst", phase="UNINSTALL")
        shutil.rmtree(target)
        hook("postuninst", phase="UNINSTALL")
        require(not code_file.exists(), "package still has a pairing-code file after uninstall")
        for args in (("ps", "-aq"), ("network", "ls", "-q"), ("volume", "ls", "-q")):
            require(not command("docker", *args, "--filter", label), "uninstall left Compose resources")
        command("docker", "volume", "inspect", volume)
        print("PASS uninstall removed containers, network, proxy volume and host code; data volume retained", flush=True)

        # Reinstall with an empty package var directory, as after a full removal.
        shutil.rmtree(data)
        target.mkdir()
        with tarfile.open(package / "package.tgz") as archive:
            archive.extractall(target, filter="data")
        compose_file.write_text(config.replace('"8787:8787"', '"127.0.0.1::8787"'))
        image_file.write_text(candidate + "\n")
        hook("preinst")
        hook("postinst")
        retained_client(next_version, "reinstall after removing package data directory")
        hook("preuninst", phase="UNINSTALL")
        hook("postuninst", phase="UNINSTALL")
        assert_down()
    finally:
        # The disposable project label and unique volume name bound all cleanup.
        for args, remove in (
            (("ps", "-aq"), ("rm", "-f")),
            (("network", "ls", "-q"), ("network", "rm")),
            (("volume", "ls", "-q"), ("volume", "rm")),
        ):
            resources = command("docker", *args, "--filter", label).splitlines()
            if resources:
                cleanup(*remove, *resources)
        if command("docker", "volume", "ls", "-q", "--filter", f"name=^{volume}$") == volume:
            cleanup("volume", "rm", volume)
        if registry:
            cleanup("rm", "-fv", registry)
        if candidate and command("docker", "image", "ls", "-q", candidate):
            cleanup("image", "rm", candidate)
print("PASS temporary project, registry and test data volume cleaned up")
PY
