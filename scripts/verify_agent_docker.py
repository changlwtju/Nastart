#!/usr/bin/env python3
"""Verify the Agent Compose healthcheck against a local Docker engine."""

from __future__ import annotations

import argparse
import json
import os
import secrets
import ssl
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from agent_smoke_test import request_json, require_status


AGENT_DIR = Path(__file__).resolve().parents[1] / "agent"
SERVICE = "nastart-agent"


def command(*args: str, capture: bool = False, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(args, check=True, text=True, capture_output=capture, env=env, timeout=300)
    return result.stdout.strip() if capture else ""


def wait_for_health(container: str, expected: str) -> dict:
    deadline = time.monotonic() + 60
    while True:
        state = json.loads(command("docker", "inspect", "--format", "{{json .State}}", container, capture=True))
        health = state.get("Health") or {}
        status = health.get("Status")
        if not state["Running"]:
            raise RuntimeError(f"Container exited while waiting for {expected} (exit {state['ExitCode']})")
        if status == expected:
            print(f"docker inspect {container[:12]} Health.Status={status} Running={state['Running']}")
            return state
        if time.monotonic() >= deadline:
            raise RuntimeError(f"Expected {expected}, got {status}. Health evidence: {json.dumps(health)}")
        time.sleep(0.5)


def verify(*, pull: bool = False) -> None:
    project = f"nastart-agent-check-{secrets.token_hex(5)}"
    pairing_code = f"{secrets.randbelow(1_000_000):06d}"
    env = dict(os.environ, NASTART_PAIRING_CODE=pairing_code)
    if not pull:
        env["NASTART_DOCKERHUB_NAMESPACE"] = project
    config = json.loads(command("sh", str(AGENT_DIR / "compose.sh"), "-p", project,
                                "config", "--format", "json", capture=True, env=env))
    service = config["services"][SERVICE]
    service.pop("container_name", None)
    # Use a disposable data volume and an ephemeral host port on loopback.
    service["volumes"] = [mount for mount in service["volumes"] if mount["target"] != "/var/run/docker.sock"]
    service["ports"] = [{"target": 8787, "host_ip": "127.0.0.1", "protocol": "tcp"}]
    image = service["image"]
    image_name, version = image.rsplit(":", 1)
    if image_name != f"{env['NASTART_DOCKERHUB_NAMESPACE']}/{SERVICE}":
        raise RuntimeError(f"Unexpected Compose image name: {image}")

    with tempfile.TemporaryDirectory(prefix=project) as directory:
        config_path = Path(directory) / "compose.json"
        config_path.write_text(json.dumps(config), encoding="utf-8")
        compose = ("docker", "compose", "-p", project, "-f", str(config_path))
        container = ""
        suspended = False
        try:
            if pull:
                command(*compose, "pull", "--policy", "always", SERVICE)
                digests = command("docker", "image", "inspect", "--format", "{{json .RepoDigests}}", image, capture=True)
                print(f"Pulled RepoDigests={digests}", flush=True)
            else:
                command(*compose, "build", SERVICE)
            command(*compose, "up", "-d", "--no-build", "--pull", "never", SERVICE)
            container = command(*compose, "ps", "-q", SERVICE, capture=True)
            actual_image = command("docker", "inspect", "--format", "{{.Config.Image}}", container, capture=True)
            if actual_image != image:
                raise RuntimeError(f"Expected image {image}, container uses {actual_image}")
            print(f"Image={actual_image}")
            healthy = wait_for_health(container, "healthy")
            host_port = command(*compose, "port", SERVICE, "8787", capture=True)
            certificate_path = "/data/tls-cert.pem"
            certificate = command("docker", "exec", container, "cat", certificate_path, capture=True)
            context = ssl.create_default_context(cadata=certificate)
            base_url = f"https://{host_port}"

            status, health = request_json(base_url, "/healthz", context=context)
            require_status("healthz", status, health)
            if health != {"ok": True, "version": version}:
                raise RuntimeError(f"Unexpected health response: {health}")
            print(f"HTTPS GET /healthz {status} {json.dumps(health, sort_keys=True)}")
            try:
                request_json(f"http://{host_port}", "/healthz")
            except OSError:
                print("Plain HTTP on the HTTPS port was rejected")
            else:
                raise RuntimeError("The HTTPS listener accepted plain HTTP")

            status, paired = request_json(base_url, "/v1/pair", body={"code": pairing_code}, context=context)
            require_status("pair", status, paired)
            token = paired.get("token")
            if not isinstance(token, str) or not token:
                raise RuntimeError("Pairing did not return a bearer token")
            print(f"POST /v1/pair {status} (bearer token issued)")
            status, handshake = request_json(base_url, "/v1/handshake", token=token, context=context)
            require_status("handshake", status, handshake)
            if handshake.get("agentVersion") != version:
                raise RuntimeError("Handshake version does not match the Compose image tag")
            print(f"GET /v1/handshake {status} {json.dumps(handshake, sort_keys=True)}")
            openssl_fields = dict(line.split("=", 1) for line in command(
                "docker", "exec", container, "openssl", "x509", "-in", certificate_path,
                "-noout", "-enddate", "-fingerprint", "-sha256", capture=True,
            ).splitlines())
            fingerprint = next(value for key, value in openssl_fields.items() if key.lower() == "sha256 fingerprint")
            expected_fingerprint = fingerprint.replace(":", "").lower()
            tls_info = handshake.get("certificate") or {}
            not_after = ssl.cert_time_to_seconds(openssl_fields["notAfter"])
            if (tls_info.get("fingerprintSha256") != expected_fingerprint
                    or tls_info.get("notAfter") != not_after
                    or tls_info.get("subject") != handshake.get("hostIdentity")
                    or not 3649 * 86_400 < not_after - time.time() <= 3650 * 86_400):
                raise RuntimeError("Handshake certificate does not match the generated OpenSSL certificate")
            print("Handshake matches the OpenSSL SHA-256 fingerprint, expiration and host CN")
            mode = command("docker", "exec", container, "stat", "-c", "%a",
                           "/data/tls-key.pem", certificate_path, capture=True)
            if mode.splitlines() != ["600", "644"]:
                raise RuntimeError(f"Unexpected TLS key and certificate modes: {mode}")
            print("Data volume permissions: tls-key.pem=0600 tls-cert.pem=0644")
            status, diagnostics = request_json(base_url, "/v1/diagnostics", token=token, context=context)
            require_status("diagnostics", status, diagnostics)
            check = next((item for item in diagnostics.get("checks", []) if item["id"] == "certificate"), {})
            if check.get("status") != "ok":
                raise RuntimeError(f"Unexpected certificate diagnostics: {check}")
            print(f"GET /v1/diagnostics {status} {json.dumps(check, sort_keys=True)}")

            command("docker", "kill", "--signal=STOP", container, capture=True)
            suspended = True
            unhealthy = wait_for_health(container, "unhealthy")
            if (healthy["Pid"], healthy["StartedAt"]) != (unhealthy["Pid"], unhealthy["StartedAt"]):
                raise RuntimeError("Agent restarted between the two health checks")
            print("Verified healthy -> unhealthy in the same running container")
        finally:
            try:
                if suspended:
                    command("docker", "kill", "--signal=CONT", container, capture=True)
            finally:
                try:
                    command(*compose, "down", "--volumes", "--timeout", "3")
                finally:
                    if not pull and subprocess.run(["docker", "image", "inspect", image], stdout=subprocess.DEVNULL,
                                                   stderr=subprocess.DEVNULL).returncode == 0:
                        command("docker", "image", "rm", image)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pull", action="store_true", help="Pull the versioned image from Docker Hub.")
    try:
        verify(pull=parser.parse_args().pull)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        sys.exit(f"Agent Docker verification failed: {error}")
