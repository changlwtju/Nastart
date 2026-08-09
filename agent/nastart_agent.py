#!/usr/bin/env python3
"""Nastart read-only local Agent.

The Agent intentionally exposes only pairing, capability, inventory and safe
diagnostic endpoints. It never accepts arbitrary commands and never mutates
Docker or host state.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import http.client
import http.server
import json
import os
import platform
import secrets
import shutil
import socket
import ssl
import stat
import threading
import time
import uuid
from pathlib import Path
from typing import Any

AGENT_VERSION = "0.1.0"
API_VERSION = 1
DEFAULT_DATA_DIR = Path(os.environ.get("NASTART_DATA_DIR", "/data"))
DOCKER_SOCKET = os.environ.get("NASTART_DOCKER_SOCKET", "/var/run/docker.sock")
PAIRING_ATTEMPT_LIMIT = 5
PAIRING_ATTEMPT_WINDOW_SECONDS = 60


def json_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def stable_agent_id(data_dir: Path) -> str:
    path = data_dir / "agent-id"
    if path.exists():
        value = path.read_text(encoding="utf-8").strip()
        if value:
            return value
    value = str(uuid.uuid4())
    atomic_write(path, value.encode("utf-8"))
    return value


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(payload)
    os.chmod(temporary, stat.S_IRUSR | stat.S_IWUSR)
    temporary.replace(path)


class AgentState:
    def __init__(self, data_dir: Path, pairing_code: str | None) -> None:
        self.data_dir = data_dir
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.agent_id = stable_agent_id(data_dir)
        self.token_path = data_dir / "pairing-token"
        self.pairing_code_digest_path = data_dir / "pairing-code-digest"
        self.token_digest = self._load_token_digest()
        previous_code_digest = (
            self.pairing_code_digest_path.read_text(encoding="utf-8").strip()
            if self.pairing_code_digest_path.exists()
            else None
        )
        requested_code_digest = self._digest(pairing_code) if pairing_code else None
        self.pairing_code = (
            pairing_code
            if pairing_code and (self.token_digest is None or requested_code_digest != previous_code_digest)
            else None
        )
        self.lock = threading.Lock()
        self.failed_pairing_attempts: dict[str, list[float]] = {}
        self.started_at = time.time()

    @staticmethod
    def _digest(value: str) -> str:
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    def _load_token_digest(self) -> str | None:
        if not self.token_path.exists():
            return None
        persisted = self.token_path.read_text(encoding="utf-8").strip()
        if not persisted:
            return None
        if persisted.startswith("sha256:"):
            return persisted.removeprefix("sha256:")
        # Migrate the early plaintext-token format in place.
        digest = self._digest(persisted)
        atomic_write(self.token_path, f"sha256:{digest}".encode("utf-8"))
        return digest

    def pair(self, supplied_code: str, source: str = "local") -> str | None:
        now = time.monotonic()
        with self.lock:
            recent_failures = [
                attempted_at
                for attempted_at in self.failed_pairing_attempts.get(source, [])
                if now - attempted_at < PAIRING_ATTEMPT_WINDOW_SECONDS
            ]
            self.failed_pairing_attempts[source] = recent_failures
            if len(recent_failures) >= PAIRING_ATTEMPT_LIMIT:
                return None
            if not self.pairing_code or not hmac.compare_digest(self.pairing_code, supplied_code):
                recent_failures.append(now)
                return None

            token = secrets.token_urlsafe(32)
            self.token_digest = self._digest(token)
            atomic_write(self.token_path, f"sha256:{self.token_digest}".encode("utf-8"))
            atomic_write(
                self.pairing_code_digest_path,
                self._digest(self.pairing_code).encode("utf-8"),
            )
            self.pairing_code = None
            self.failed_pairing_attempts.pop(source, None)
            return token

    def authenticates(self, authorization: str | None) -> bool:
        if not self.token_digest or not authorization or not authorization.startswith("Bearer "):
            return False
        supplied_token = authorization.removeprefix("Bearer ").strip()
        return hmac.compare_digest(self.token_digest, self._digest(supplied_token))


class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, socket_path: str, timeout: float = 2.0) -> None:
        super().__init__("localhost", timeout=timeout)
        self.socket_path = socket_path

    def connect(self) -> None:
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.socket_path)


def docker_containers() -> tuple[list[dict[str, Any]], str | None]:
    connection: UnixHTTPConnection | None = None
    try:
        connection = UnixHTTPConnection(DOCKER_SOCKET)
        connection.request("GET", "/v1.41/containers/json?all=1")
        response = connection.getresponse()
        payload = response.read()
        if response.status != 200:
            return [], f"docker-http-{response.status}"
        raw = json.loads(payload)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return [], error.__class__.__name__
    finally:
        if connection is not None:
            connection.close()

    containers: list[dict[str, Any]] = []
    for item in raw if isinstance(raw, list) else []:
        names = item.get("Names") or []
        name = str(names[0]).lstrip("/") if names else str(item.get("Id", ""))[:12]
        ports = []
        endpoints = []
        for port in item.get("Ports") or []:
            private_port = int(port.get("PrivatePort", 0) or 0)
            public_port = int(port.get("PublicPort", 0) or 0)
            protocol = str(port.get("Type", "tcp"))
            if public_port:
                ports.append(f"{public_port}:{private_port}/{protocol}")
                if protocol == "tcp":
                    endpoints.append({"scheme": "http", "port": public_port})
            elif private_port:
                ports.append(f"{private_port}/{protocol}")
        state = str(item.get("State", "unknown"))
        containers.append(
            {
                "id": str(item.get("Id", ""))[:12],
                "name": name,
                "image": str(item.get("Image", "")),
                "state": state,
                "status": str(item.get("Status", state)),
                "ports": ports,
                "endpoints": endpoints,
            }
        )
    return containers, None


def memory_summary() -> dict[str, int] | None:
    meminfo = Path("/proc/meminfo")
    if not meminfo.exists():
        return None
    values: dict[str, int] = {}
    for line in meminfo.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ":" not in line:
            continue
        key, raw_value = line.split(":", 1)
        token = raw_value.strip().split(" ", 1)[0]
        if token.isdigit():
            values[key] = int(token) * 1024
    total = values.get("MemTotal")
    available = values.get("MemAvailable")
    if not total or available is None:
        return None
    return {"totalBytes": total, "usedBytes": max(total - available, 0)}


def host_snapshot(state: AgentState) -> dict[str, Any]:
    containers, docker_error = docker_containers()
    disk = shutil.disk_usage("/")
    load = os.getloadavg() if hasattr(os, "getloadavg") else (0.0, 0.0, 0.0)
    return {
        "agentId": state.agent_id,
        "apiVersion": API_VERSION,
        "agentVersion": AGENT_VERSION,
        "timestamp": int(time.time()),
        "host": {
            "hostname": socket.gethostname(),
            "platform": platform.system().lower(),
            "platformRelease": platform.release(),
            "architecture": platform.machine(),
            "loadAverage": [round(value, 3) for value in load],
            "memory": memory_summary(),
            "storage": {
                "totalBytes": disk.total,
                "usedBytes": disk.used,
                "freeBytes": disk.free,
            },
        },
        "containers": containers,
        "inventory": {
            "dockerAvailable": docker_error is None,
            "dockerError": docker_error,
        },
    }


def handshake(state: AgentState) -> dict[str, Any]:
    containers, docker_error = docker_containers()
    return {
        "agentId": state.agent_id,
        "apiVersion": API_VERSION,
        "agentVersion": AGENT_VERSION,
        "hostIdentity": socket.gethostname(),
        "providerHint": os.environ.get("NASTART_PROVIDER_HINT", "generic-linux"),
        "permissionLevel": "read",
        "capabilities": [
            "heartbeat",
            "host.metrics",
            "diagnostics.read",
            *( ["docker.containers.read", "services.detect"] if docker_error is None else [] ),
        ],
        "containerCount": len(containers),
        "startedAt": int(state.started_at),
        "timestamp": int(time.time()),
    }


class AgentHandler(http.server.BaseHTTPRequestHandler):
    server_version = "NastartAgent/0.1"

    @property
    def state(self) -> AgentState:
        return self.server.agent_state  # type: ignore[attr-defined]

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/healthz":
            self.respond(200, {"ok": True, "version": AGENT_VERSION})
            return
        if not self.require_authentication():
            return
        if self.path == "/v1/handshake":
            self.respond(200, handshake(self.state))
        elif self.path == "/v1/snapshot":
            self.respond(200, host_snapshot(self.state))
        elif self.path == "/v1/diagnostics":
            containers, docker_error = docker_containers()
            self.respond(
                200,
                {
                    "timestamp": int(time.time()),
                    "checks": [
                        {"id": "agent", "status": "ok"},
                        {
                            "id": "docker-read",
                            "status": "ok" if docker_error is None else "unavailable",
                            "detail": docker_error,
                            "containers": len(containers),
                        },
                    ],
                },
            )
        else:
            self.respond(404, {"error": "not-found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/v1/pair":
            self.respond(404, {"error": "not-found"})
            return
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip() != "application/json":
            self.respond(415, {"error": "json-required"})
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
            body = json.loads(self.rfile.read(length))
            supplied_code = str(body.get("code", ""))
        except (ValueError, json.JSONDecodeError):
            self.respond(400, {"error": "invalid-json"})
            return
        token = self.state.pair(supplied_code, source=self.client_address[0])
        if not token:
            self.respond(401, {"error": "invalid-or-used-pairing-code"})
            return
        response = handshake(self.state)
        response["token"] = token
        self.respond(200, response)

    def require_authentication(self) -> bool:
        if self.state.authenticates(self.headers.get("Authorization")):
            return True
        self.respond(401, {"error": "unauthorized"})
        return False

    def respond(self, status: int, value: Any) -> None:
        payload = json_bytes(value)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, message: str, *args: Any) -> None:
        print(f"{self.address_string()} - {message % args}", flush=True)


class AgentServer(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], state: AgentState) -> None:
        super().__init__(address, AgentHandler)
        self.agent_state = state


def main() -> None:
    parser = argparse.ArgumentParser(description="Nastart read-only local Agent")
    parser.add_argument("--host", default=os.environ.get("NASTART_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("NASTART_PORT", "8787")))
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--pairing-code", default=os.environ.get("NASTART_PAIRING_CODE"))
    parser.add_argument("--tls-cert", type=Path, default=os.environ.get("NASTART_TLS_CERT"))
    parser.add_argument("--tls-key", type=Path, default=os.environ.get("NASTART_TLS_KEY"))
    args = parser.parse_args()

    pairing_code = args.pairing_code or f"{secrets.randbelow(1_000_000):06d}"
    state = AgentState(args.data_dir, pairing_code)
    server = AgentServer((args.host, args.port), state)
    scheme = "http"
    if args.tls_cert and args.tls_key:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(args.tls_cert, args.tls_key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = "https"

    print(f"Nastart Agent {AGENT_VERSION} listening on {scheme}://{args.host}:{args.port}", flush=True)
    if state.pairing_code:
        print(f"One-time pairing code: {state.pairing_code}", flush=True)
    else:
        print("Pairing is already complete; deploy with a new code to rotate it.", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
