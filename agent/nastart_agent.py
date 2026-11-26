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
import math
import os
import platform
import secrets
import shutil
import socket
import ssl
import stat
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from collections import deque
from pathlib import Path
from typing import Any

AGENT_VERSION = "0.4.0"
API_VERSION = 1
DEFAULT_DATA_DIR = Path(os.environ.get("NASTART_DATA_DIR", "/data"))
DOCKER_SOCKET = os.environ.get("NASTART_DOCKER_SOCKET", "/var/run/docker.sock")
PAIRING_ATTEMPT_LIMIT = 5
PAIRING_ATTEMPT_WINDOW_SECONDS = 60
MAX_PAIRING_BODY_BYTES = 4 * 1024
MAX_TRACKED_PAIRING_SOURCES = 2_048
MAX_EVENTS = 100
DEFAULT_SAMPLE_INTERVAL_SECONDS = 30
MIN_SAMPLE_INTERVAL_SECONDS = 10
SECONDS_PER_DAY = 86_400
CERTIFICATE_RENEWAL_DAYS = 30
EVENT_FIELDS = {
    "container.state": {"containerId": str, "containerName": str, "from": str, "to": str},
    "docker.availability": {"available": bool, "detail": (str, type(None))},
    "pairing.failed": {"source": str},
}


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


def valid_pairing_code(value: str | None) -> bool:
    return bool(value) and len(value) == 6 and all("0" <= character <= "9" for character in value)


def sample_interval_seconds() -> int:
    try:
        interval = int(os.environ.get("NASTART_SAMPLE_INTERVAL_SECONDS", DEFAULT_SAMPLE_INTERVAL_SECONDS))
    except ValueError:
        return DEFAULT_SAMPLE_INTERVAL_SECONDS
    # threading.Event.wait cannot represent timeouts larger than TIMEOUT_MAX.
    return min(max(interval, MIN_SAMPLE_INTERVAL_SECONDS), int(threading.TIMEOUT_MAX))


def run_openssl(executable: str, *arguments: str) -> str:
    result = subprocess.run(
        [executable, *arguments], capture_output=True, check=True, timeout=15,
        env=dict(os.environ, LC_ALL="C"), encoding="utf-8", errors="replace",
    )
    return result.stdout


def certificate_info(openssl: str, path: Path) -> dict[str, Any]:
    output = run_openssl(
        openssl, "x509", "-in", str(path), "-noout", "-enddate", "-fingerprint",
        "-sha256", "-subject", "-nameopt", "sep_multiline,sname,utf8,esc_ctrl",
    )
    fields = {}
    for line in output.split("\n"):
        key, separator, value = line.partition("=")
        if separator:
            fields.setdefault(key.strip().lower(), value.rstrip("\r"))
    fingerprint = fields.get("sha256 fingerprint", "").replace(":", "").lower()
    if len(fingerprint) != 64 or any(character not in "0123456789abcdef" for character in fingerprint):
        raise ValueError("invalid certificate fingerprint")
    return {
        "fingerprintSha256": fingerprint,
        "notAfter": ssl.cert_time_to_seconds(fields.get("notafter", "")),
        "subject": fields.get("cn", ""),
    }


def load_tls_context(cert_path: Path, key_path: Path, *, password: str | None = None) -> ssl.SSLContext:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(cert_path, key_path, password=password)
    return context


def automatic_tls(openssl: str, data_dir: Path) -> tuple[ssl.SSLContext, dict[str, Any]]:
    cert_path = data_dir / "tls-cert.pem"
    key_path = data_dir / "tls-key.pem"
    if cert_path.is_file() and key_path.is_file():
        try:
            info = certificate_info(openssl, cert_path)
            if info["notAfter"] - time.time() > CERTIFICATE_RENEWAL_DAYS * SECONDS_PER_DAY:
                key_path.chmod(0o600)
                cert_path.chmod(0o644)
                return load_tls_context(cert_path, key_path, password=""), info
        except (OSError, subprocess.SubprocessError, ValueError):
            # Recover from an unreadable certificate or an incomplete key/cert replacement.
            pass

    with tempfile.TemporaryDirectory(prefix=".tls-", dir=data_dir) as directory:
        pending_cert = Path(directory) / cert_path.name
        pending_key = Path(directory) / key_path.name
        hostname = socket.gethostname()
        run_openssl(
            openssl, "req", "-x509", "-newkey", "rsa:2048", "-keyout", str(pending_key),
            "-out", str(pending_cert), "-days", "3650", "-nodes", "-subj", f"/CN={hostname}",
            "-addext", f"subjectAltName=DNS:{hostname},DNS:localhost,IP:127.0.0.1",
        )
        info = certificate_info(openssl, pending_cert)
        context = load_tls_context(pending_cert, pending_key, password="")
        pending_key.chmod(0o600)
        pending_cert.chmod(0o644)
        pending_key.replace(key_path)
        pending_cert.replace(cert_path)
        return context, info


class AgentState:
    def __init__(self, data_dir: Path, pairing_code: str | None) -> None:
        if pairing_code is not None and not valid_pairing_code(pairing_code):
            raise ValueError("pairing code must contain exactly six ASCII digits")
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
        self.certificate: dict[str, Any] | None = None
        self.certificate_unavailable_reason = "HTTP is active"
        self.events_path = data_dir / "events.json"
        self._events = deque(self._load_events(), maxlen=MAX_EVENTS)

    def configure_tls(self, cert_path: Path | None, key_path: Path | None) -> ssl.SSLContext | None:
        openssl = shutil.which("openssl")
        if openssl is None:
            self.certificate_unavailable_reason = "OpenSSL executable not found"
        elif cert_path is not None and key_path is not None:
            context = load_tls_context(cert_path, key_path)
            self.certificate = certificate_info(openssl, cert_path)
            return context
        else:
            try:
                context, self.certificate = automatic_tls(openssl, self.data_dir)
                return context
            except (OSError, subprocess.SubprocessError, ValueError) as error:
                self.certificate_unavailable_reason = f"automatic TLS setup failed ({type(error).__name__})"
        print(f"Warning: {self.certificate_unavailable_reason}; serving plain HTTP", file=sys.stderr, flush=True)
        return None

    def certificate_check(self) -> dict[str, str]:
        if self.certificate is None:
            return {"id": "certificate", "status": "unavailable", "detail": self.certificate_unavailable_reason}
        remaining = self.certificate["notAfter"] - time.time()
        if remaining <= 0:
            return {"id": "certificate", "status": "expired", "detail": "certificate expired"}
        days = math.ceil(remaining / SECONDS_PER_DAY)
        return {
            "id": "certificate",
            "status": "expiring" if days <= CERTIFICATE_RENEWAL_DAYS else "ok",
            "detail": f"{days} days remaining",
        }

    def _load_events(self) -> list[dict[str, Any]]:
        try:
            events = json.loads(self.events_path.read_bytes())
        except (OSError, ValueError, RecursionError):
            return []
        if not isinstance(events, list):
            return []
        for event in events:
            if not isinstance(event, dict) or type(event.get("timestamp")) is not int:
                return []
            event_type = event.get("type")
            fields = EVENT_FIELDS.get(event_type) if isinstance(event_type, str) else None
            if fields is None or event.keys() != {"type", "timestamp", *fields}:
                return []
            if any(not isinstance(event[key], field_type) for key, field_type in fields.items()):
                return []
        return events

    def recent_events(self) -> list[dict[str, Any]]:
        with self.lock:
            return list(reversed(self._events))

    def record_events(self, events: list[dict[str, Any]]) -> None:
        with self.lock:
            self._record_events_locked(events)

    def _record_events_locked(self, events: list[dict[str, Any]]) -> None:
        timestamp = int(time.time())
        self._events.extend({**event, "timestamp": timestamp} for event in events)
        try:
            atomic_write(self.events_path, json_bytes(list(self._events)))
        except OSError as error:
            print(f"Could not persist event history: {type(error).__name__}", file=sys.stderr, flush=True)

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
            digest = persisted.removeprefix("sha256:")
            if len(digest) == 64 and all(character in "0123456789abcdef" for character in digest.lower()):
                return digest.lower()
            return None
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
            if len(self.failed_pairing_attempts) > MAX_TRACKED_PAIRING_SOURCES:
                oldest_source = min(
                    self.failed_pairing_attempts,
                    key=lambda key: self.failed_pairing_attempts[key][-1]
                    if self.failed_pairing_attempts[key]
                    else now,
                )
                self.failed_pairing_attempts.pop(oldest_source, None)
            if len(recent_failures) >= PAIRING_ATTEMPT_LIMIT:
                return None
            if not self.pairing_code or not hmac.compare_digest(self.pairing_code, supplied_code):
                recent_failures.append(now)
                self._record_events_locked([{"type": "pairing.failed", "source": source}])
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
        if not isinstance(item, dict):
            continue
        names = item.get("Names") or []
        if not isinstance(names, list):
            names = []
        name = str(names[0]).lstrip("/") if names else str(item.get("Id", ""))[:12]
        ports = []
        endpoints = []
        for port in item.get("Ports") or []:
            if not isinstance(port, dict):
                continue
            try:
                private_port = int(port.get("PrivatePort", 0) or 0)
                public_port = int(port.get("PublicPort", 0) or 0)
            except (TypeError, ValueError):
                continue
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
    try:
        lines = meminfo.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
        return None
    for line in lines:
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
    try:
        disk = shutil.disk_usage("/")
        storage = {
            "totalBytes": disk.total,
            "usedBytes": disk.used,
            "freeBytes": disk.free,
        }
    except OSError:
        storage = {"totalBytes": 0, "usedBytes": 0, "freeBytes": 0}
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
            "storage": storage,
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
        "certificate": state.certificate,
    }


class AgentHandler(http.server.BaseHTTPRequestHandler):
    server_version = "NastartAgent"
    sys_version = ""

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(10)

    def handle(self) -> None:
        try:
            super().handle()
        except ssl.SSLError:
            # Clients speaking plain HTTP on the TLS port cannot send an HTTP request.
            return

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
            events = self.state.recent_events()
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
                        self.state.certificate_check(),
                    ],
                    "uptimeSeconds": int(time.time() - self.state.started_at),
                    "eventCount": len(events),
                    "events": events,
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
            raw_length = self.headers.get("Content-Length")
            length = int(raw_length) if raw_length is not None else 0
        except ValueError:
            self.respond(400, {"error": "invalid-content-length"})
            return
        if length <= 0:
            self.respond(400, {"error": "invalid-body"})
            return
        if length > MAX_PAIRING_BODY_BYTES:
            self.respond(413, {"error": "request-too-large"})
            return
        try:
            body = json.loads(self.rfile.read(length))
            supplied_code = body.get("code") if isinstance(body, dict) else None
        except (ValueError, json.JSONDecodeError):
            self.respond(400, {"error": "invalid-json"})
            return
        if not isinstance(supplied_code, str) or not valid_pairing_code(supplied_code):
            self.respond(400, {"error": "invalid-pairing-code"})
            return
        try:
            token = self.state.pair(supplied_code, source=self.client_address[0])
        except (OSError, ValueError):
            self.respond(500, {"error": "pairing-failed"})
            return
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
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            return

    def log_message(self, message: str, *args: Any) -> None:
        print(f"{self.address_string()} - {message % args}", flush=True)


class AgentServer(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], state: AgentState) -> None:
        self._stop_sampling = threading.Event()
        super().__init__(address, AgentHandler)
        self.agent_state = state
        self._docker_available: bool | None = None
        self._container_states: dict[str, str] = {}
        threading.Thread(target=self._sample_docker_loop, name="docker-sampler", daemon=True).start()

    def server_close(self) -> None:
        self._stop_sampling.set()
        super().server_close()

    def _sample_docker_loop(self) -> None:
        interval = sample_interval_seconds()
        while not self._stop_sampling.is_set():
            try:
                self._sample_docker()
            except Exception:
                # An unexpected Docker response must not stop subsequent samples.
                pass
            if self._stop_sampling.wait(interval):
                break

    def _sample_docker(self) -> None:
        containers, docker_error = docker_containers()
        available = docker_error is None
        events = []
        if self._docker_available is not None and available != self._docker_available:
            events.append({
                "type": "docker.availability",
                "available": available,
                "detail": docker_error,
            })
        if available:
            states = {}
            for container in containers:
                container_id = container["id"]
                if len(container_id) != 12:
                    continue
                current = container["state"]
                states[container_id] = current
                previous = self._container_states.get(container_id)
                if previous is not None and previous != current:
                    events.append({
                        "type": "container.state",
                        "containerId": container_id,
                        "containerName": container["name"],
                        "from": previous,
                        "to": current,
                    })
            self._container_states = states
        self._docker_available = available
        if events:
            self.agent_state.record_events(events)


def loopback_healthcheck() -> bool:
    port = int(os.environ.get("NASTART_PORT", "8787"))
    # This unauthenticated probe stays inside the container on loopback.
    connections = (
        http.client.HTTPSConnection("127.0.0.1", port, timeout=1, context=ssl._create_unverified_context()),
        http.client.HTTPConnection("127.0.0.1", port, timeout=1),
    )
    for connection in connections:
        try:
            connection.request("GET", "/healthz")
            return connection.getresponse().status == 200
        except (OSError, http.client.HTTPException):
            continue
        finally:
            connection.close()
    return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Nastart read-only local Agent")
    parser.add_argument("--host", default=os.environ.get("NASTART_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("NASTART_PORT", "8787")))
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--pairing-code", default=os.environ.get("NASTART_PAIRING_CODE"))
    parser.add_argument("--tls-cert", type=Path, default=os.environ.get("NASTART_TLS_CERT"))
    parser.add_argument("--tls-key", type=Path, default=os.environ.get("NASTART_TLS_KEY"))
    args = parser.parse_args()
    if (args.tls_cert is None) != (args.tls_key is None):
        parser.error("--tls-cert and --tls-key must be supplied together")

    pairing_code = args.pairing_code or f"{secrets.randbelow(1_000_000):06d}"
    try:
        state = AgentState(args.data_dir, pairing_code)
    except ValueError as error:
        parser.error(str(error))
    try:
        context = state.configure_tls(args.tls_cert, args.tls_key)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        parser.error(f"could not load explicit TLS certificate ({type(error).__name__})")
    server = AgentServer((args.host, args.port), state)
    scheme = "http"
    if context is not None:
        server.socket = context.wrap_socket(server.socket, server_side=True, do_handshake_on_connect=False)
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
