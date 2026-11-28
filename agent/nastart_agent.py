#!/usr/bin/env python3
"""Nastart read-only local Agent.

The Agent intentionally exposes only pairing, capability, inventory and safe
diagnostic endpoints. It never accepts arbitrary commands and never mutates
Docker or host state.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import html
import http.client
import http.server
import ipaddress
import json
import math
import os
import platform
import re
import secrets
import shutil
import signal
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
from contextlib import closing
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from qrencoder import QR8bitByte, QRCode, QRErrorCorrectLevel

AGENT_VERSION = "0.5.1"
API_VERSION = 1
DEFAULT_DATA_DIR = Path(os.environ.get("NASTART_DATA_DIR", "/data"))
DOCKER_SOCKET = os.environ.get("NASTART_DOCKER_SOCKET", "/var/run/docker.sock")
PAIRING_ATTEMPT_LIMIT = 5
PAIRING_ATTEMPT_WINDOW_SECONDS = 60
MAX_PAIRING_BODY_BYTES = 4 * 1024
MAX_TRACKED_PAIRING_SOURCES = 2_048
PAIRING_CODE_SPACE = 1_000_000
MAX_EVENTS = 100
DEFAULT_SAMPLE_INTERVAL_SECONDS = 30
MIN_SAMPLE_INTERVAL_SECONDS = 10
SECONDS_PER_DAY = 86_400
CERTIFICATE_RENEWAL_DAYS = 30
PAIRING_VIEW_PATH = "/pairing-info"
PAIRING_VIEW_KEY_FILE = "pairing-view-key"
DISCOVERY_TYPE = "_nastart-agent._tcp.local."
DISCOVERY_NETWORKS = tuple(ipaddress.IPv4Network(network) for network in (
    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16",
))
EVENT_FIELDS = {
    "container.state": {"containerId": str, "containerName": str, "from": str, "to": str},
    "docker.availability": {"available": bool, "detail": (str, type(None))},
    "pairing.failed": {"source": str},
}


def json_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def pairing_view_key(data_dir: Path, *, create: bool = False) -> str:
    path = data_dir / PAIRING_VIEW_KEY_FILE
    if create and not path.exists():
        write_pairing_state(path, secrets.token_urlsafe(32))
    key = json.loads(path.read_bytes())
    if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z0-9_-]{43}", key):
        raise ValueError("invalid pairing display key")
    return key


def pairing_view_authorization(key: str) -> str:
    credentials = base64.b64encode(f"nastart:{key}".encode("ascii")).decode("ascii")
    return f"Basic {credentials}"


def pairing_address(value: str) -> str:
    parsed = urlsplit(value)
    # Validate the host before using it in a QR payload or an HTTP header.
    if (parsed.scheme != "https" or parsed.path not in ("", "/")
            or parsed.query or parsed.fragment or parsed.port == 0
            or not re.fullmatch(r"(?:[A-Za-z0-9.-]{1,253}|\[[0-9A-Fa-f:.]+\])(?::[0-9]{1,5})?", parsed.netloc)):
        raise ValueError("Agent address must be an HTTPS origin")
    return f"https://{parsed.netloc}"


def pairing_qr(address: str, code: str) -> list[list[bool]]:
    qr = QRCode(None, QRErrorCorrectLevel.M)
    qr.addData(QR8bitByte(json_bytes({"v": 1, "address": address, "code": code})))
    qr.make()
    return qr.modules


def pairing_display(address: str, code: str | None, *, plain: bool) -> str:
    message = f"Pairing code: {code}" if code else "No active pairing code. Restart the Agent to issue one."
    if plain:
        text = f"Agent address: {address}\n{message}\n"
        if code:
            modules = pairing_qr(address, code)
            blank = "  " * (len(modules) + 8)
            rows = [" " * 8 + "".join("##" if dark else "  " for dark in row) + " " * 8 for row in modules]
            text += "\n".join([blank] * 4 + rows + [blank] * 4) + "\n"
        return text

    image = ""
    if code:
        modules = pairing_qr(address, code)
        size = len(modules) + 8  # Four white modules on every side.
        path = "".join(f"M{x + 4} {y + 4}h1v1h-1z" for y, row in enumerate(modules) for x, dark in enumerate(row) if dark)
        image = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="320" '
                 f'height="320" role="img" aria-label="Pairing QR code" shape-rendering="crispEdges">'
                 f'<rect width="{size}" height="{size}" fill="white"/><path d="{path}"/></svg>')
    return ("<!doctype html><html lang=\"en\"><meta charset=\"utf-8\">"
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<meta http-equiv="refresh" content="10">'
            '<title>Nastart Agent pairing</title><style>'
            'body{font:1rem system-ui,sans-serif;margin:2rem auto;padding:0 1rem;max-width:28rem}'
            'code{overflow-wrap:anywhere}svg{display:block;max-width:100%;height:auto}'
            '</style><main><h1>Pair Nastart Agent</h1>'
            f'<p>Agent address <code>{html.escape(address)}</code></p><p>{message}</p>{image}</main></html>')


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


def valid_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def write_pairing_state(path: Path, value: Any) -> None:
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", delete=False) as temporary:
        pending = Path(temporary.name)
        try:
            temporary.write(json_bytes(value) + b"\n")
            temporary.flush()
            os.fsync(temporary.fileno())
            temporary.close()
            pending.replace(path)
        finally:
            pending.unlink(missing_ok=True)


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
        self.tokens_path = data_dir / "pairing-tokens.json"
        self.tokens = self._load_tokens()
        self.pairing_code = self._issue_pairing_code(pairing_code)
        self.pairing_view_key: str | None = None
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

    def _load_tokens(self) -> list[dict[str, Any]]:
        try:
            tokens = json.loads(self.tokens_path.read_bytes())
        except FileNotFoundError:
            legacy = self.data_dir / "pairing-token"
            persisted = legacy.read_text(encoding="utf-8").strip() if legacy.exists() else ""
            tokens = []
            if persisted:
                digest = (
                    persisted.removeprefix("sha256:").lower()
                    if persisted.startswith("sha256:") else self._digest(persisted)
                )
                if not valid_sha256(digest):
                    raise ValueError("invalid legacy pairing token digest")
                tokens.append({"id": str(uuid.uuid4()), "sha256": digest, "createdAt": None})
            # The new file, including an empty list, is authoritative after migration.
            # Keep the original file for rollback to 0.4.0.
            write_pairing_state(self.tokens_path, tokens)
            return tokens

        if not isinstance(tokens, list) or any(
            not isinstance(token, dict)
            or not isinstance(token.get("id"), str)
            or not token["id"]
            or not valid_sha256(token.get("sha256"))
            or "createdAt" not in token
            or (token["createdAt"] is not None and type(token["createdAt"]) is not int)
            for token in tokens
        ):
            raise ValueError("invalid pairing-tokens.json")
        if len({token["id"] for token in tokens}) != len(tokens):
            raise ValueError("duplicate pairing token ID")
        return tokens

    def _issue_pairing_code(self, initial_code: str | None) -> str | None:
        history_path = self.data_dir / "pairing-code-history.json"
        try:
            history = json.loads(history_path.read_bytes())
        except FileNotFoundError:
            history = []
        if not isinstance(history, list) or any(not valid_sha256(digest) for digest in history):
            raise ValueError("invalid pairing-code-history.json")
        issued = set(history)
        legacy_digest = self.data_dir / "pairing-code-digest"
        if legacy_digest.exists():
            digest = legacy_digest.read_text(encoding="utf-8").strip()
            if not valid_sha256(digest):
                raise ValueError("invalid legacy pairing code digest")
            issued.add(digest)
        legacy_spk_code = self.data_dir / "spk-pairing-code"
        if legacy_spk_code.exists():
            code = legacy_spk_code.read_text(encoding="utf-8").strip()
            if not valid_pairing_code(code):
                raise ValueError("invalid legacy SPK pairing code")
            issued.add(self._digest(code))
        if self.tokens and initial_code:
            issued.add(self._digest(initial_code))

        if initial_code and not issued and not self.tokens:
            code = initial_code
        else:
            code = self._random_pairing_code(issued)
        if code is not None:
            issued.add(self._digest(code))
        # Reserve the code before it can appear in logs or be accepted by /v1/pair.
        if issued != set(history):
            write_pairing_state(history_path, sorted(issued))
        return code

    def _random_pairing_code(self, issued: set[str]) -> str | None:
        for _ in range(32):
            code = f"{secrets.randbelow(PAIRING_CODE_SPACE):06d}"
            if self._digest(code) not in issued:
                return code
        # A nearly exhausted code space still needs a bounded selection.
        remaining = [f"{number:06d}" for number in range(PAIRING_CODE_SPACE)
                     if self._digest(f"{number:06d}") not in issued]
        return secrets.choice(remaining) if remaining else None

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
            record = {"id": str(uuid.uuid4()), "sha256": self._digest(token), "createdAt": int(time.time())}
            tokens = [*self.tokens, record]
            write_pairing_state(self.tokens_path, tokens)
            self.tokens = tokens
            self.pairing_code = None
            self.failed_pairing_attempts.pop(source, None)
            return token

    def authenticates(self, authorization: str | None) -> bool:
        if not authorization or not authorization.startswith("Bearer "):
            return False
        supplied_token = authorization.removeprefix("Bearer ").strip()
        digest = self._digest(supplied_token)
        matched = False
        for token in self.tokens:
            matched |= hmac.compare_digest(token["sha256"], digest)
        return matched


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
        if self.path == PAIRING_VIEW_PATH:
            self.show_pairing_info()
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

    def show_pairing_info(self) -> None:
        peer = ipaddress.ip_address(self.client_address[0])
        key = self.state.pairing_view_key
        if key is None or not peer.is_private or peer.is_unspecified or peer.is_multicast:
            self.respond(404, {"error": "not-found"})
            return
        supplied = self.headers.get("Authorization", "").encode("latin-1")
        if not hmac.compare_digest(supplied, pairing_view_authorization(key).encode("ascii")):
            self.respond_bytes(401, b"Pairing display key required.\n", "text/plain; charset=utf-8",
                               {"WWW-Authenticate": 'Basic realm="Nastart pairing display"'})
            return
        try:
            address = pairing_address(f"https://{self.headers.get('Host', '')}")
        except ValueError:
            self.respond(400, {"error": "invalid-agent-address"})
            return
        with self.state.lock:
            code = self.state.pairing_code
        plain = self.headers.get("Accept") == "text/plain"
        payload = pairing_display(address, code, plain=plain).encode("utf-8")
        self.respond_bytes(200, payload, "text/plain; charset=utf-8" if plain else "text/html; charset=utf-8", {
            "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'",
            "Referrer-Policy": "no-referrer",
        })

    def respond(self, status: int, value: Any) -> None:
        self.respond_bytes(status, json_bytes(value), "application/json; charset=utf-8")

    def respond_bytes(self, status: int, payload: bytes, content_type: str,
                      headers: dict[str, str] | None = None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
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


def discovery_agent_version(address: str, port: int) -> str | None:
    # The health probe sends no credentials. Only advertise once HTTPS is reachable.
    with closing(http.client.HTTPSConnection(address, port, timeout=2,
                                              context=ssl._create_unverified_context())) as connection:
        try:
            connection.request("GET", "/healthz")
            response = connection.getresponse()
            if response.status != 200:
                return None
            payload = json.loads(response.read(1024))
            version = payload.get("version") if isinstance(payload, dict) and payload.get("ok") is True else None
            if isinstance(version, str) and re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z.+-]{0,31}", version):
                return version
        except (OSError, http.client.HTTPException, ValueError):
            pass
    return None


def advertise_agent(args: argparse.Namespace, stop: threading.Event) -> None:
    try:
        address = ipaddress.IPv4Address(args.mdns_address or "")
    except ipaddress.AddressValueError as error:
        raise ValueError("--mdns-address must be the host's LAN IPv4 address") from error
    if not any(address in network for network in DISCOVERY_NETWORKS):
        raise ValueError("--mdns-address must be a private LAN IPv4 address")
    if not 1 <= args.port <= 65535:
        raise ValueError("--port must be between 1 and 65535")

    try:
        from zeroconf import IPVersion, ServiceInfo, Zeroconf
    except ImportError as error:
        raise ValueError("the advertise command requires python-zeroconf") from error

    label = re.sub(r"[^A-Za-z0-9-]", "-", args.mdns_name or socket.gethostname())[:30].strip("-") or "NAS"
    # A stable address-based target avoids conflicting with the host's own .local. records.
    target = f"nastart-{address.packed.hex()}-{args.port}.local."
    name = f"Nastart {label} ({args.port}).{DISCOVERY_TYPE}"
    current_version = None
    current_service = None
    with closing(Zeroconf(interfaces=[str(address)], ip_version=IPVersion.V4Only)) as publisher:
        while not stop.is_set():
            version = discovery_agent_version(str(address), args.port)
            if version != current_version:
                if current_service is not None:
                    publisher.unregister_service(current_service)
                    current_service = None
                if version is not None and not stop.is_set():
                    current_service = ServiceInfo(DISCOVERY_TYPE, name, addresses=[address.packed],
                                                  server=target, port=args.port, host_ttl=60, other_ttl=60,
                                                  properties={"host": label, "version": version})
                    publisher.register_service(current_service, allow_name_change=True)
                current_version = version
            stop.wait(15)


def show_config(args: argparse.Namespace) -> None:
    key = pairing_view_key(args.data_dir)
    if args.web_key:
        print(key)
        return
    host = "127.0.0.1" if args.host == "0.0.0.0" else args.host
    address = pairing_address(args.address or f"https://{host}:{args.port}")
    certificate = args.tls_cert or (args.data_dir / "tls-cert.pem")
    openssl = shutil.which("openssl")
    if openssl is None:
        raise ValueError("OpenSSL is required to verify the local Agent certificate")
    fingerprint = certificate_info(openssl, certificate)["fingerprintSha256"]
    with closing(http.client.HTTPSConnection(host, args.port, timeout=5,
                                              context=ssl._create_unverified_context())) as connection:
        connection.connect()
        # Pin the locally stored certificate before sending the display key.
        peer = connection.sock.getpeercert(binary_form=True)
        if not hmac.compare_digest(hashlib.sha256(peer).hexdigest(), fingerprint):
            raise ValueError("local Agent certificate does not match")
        connection.request("GET", PAIRING_VIEW_PATH, headers={
            "Host": urlsplit(address).netloc,
            "Authorization": pairing_view_authorization(key),
            "Accept": "text/plain",
        })
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError(f"pairing display returned HTTP {response.status}")
        print(response.read().decode("utf-8"), end="")
    if not args.address:
        print("For another device, rerun with --address https://<NAS LAN address>:8787.", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description="Nastart read-only local Agent")
    parser.add_argument("command", nargs="?", choices=("show-config", "advertise"))
    parser.add_argument("--host", default=os.environ.get("NASTART_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("NASTART_PORT", "8787")))
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--pairing-code", default=os.environ.get("NASTART_PAIRING_CODE"))
    parser.add_argument("--tls-cert", type=Path, default=os.environ.get("NASTART_TLS_CERT"))
    parser.add_argument("--tls-key", type=Path, default=os.environ.get("NASTART_TLS_KEY"))
    parser.add_argument("--address", help="Agent HTTPS origin to encode in the pairing QR")
    parser.add_argument("--web-key", action="store_true", help="print the protected Web page password")
    parser.add_argument("--mdns-address", help="host LAN IPv4 address for advertise")
    parser.add_argument("--mdns-name", help="host name to display in discovery")
    args = parser.parse_args()
    if args.command == "advertise":
        stop = threading.Event()
        signal.signal(signal.SIGTERM, lambda *_: stop.set())
        signal.signal(signal.SIGINT, lambda *_: stop.set())
        try:
            advertise_agent(args, stop)
        except (OSError, ValueError) as error:
            parser.exit(1, f"Could not advertise Agent: {error}\n")
        return
    if args.command == "show-config":
        try:
            show_config(args)
        except (OSError, subprocess.SubprocessError, http.client.HTTPException, ValueError) as error:
            parser.exit(1, f"Could not show pairing configuration: {error}\n")
        return
    if (args.tls_cert is None) != (args.tls_key is None):
        parser.error("--tls-cert and --tls-key must be supplied together")

    try:
        state = AgentState(args.data_dir, args.pairing_code or None)
    except ValueError as error:
        parser.error(str(error))
    except OSError as error:
        parser.error(f"could not load or persist pairing state ({type(error).__name__})")
    try:
        context = state.configure_tls(args.tls_cert, args.tls_key)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        parser.error(f"could not load explicit TLS certificate ({type(error).__name__})")
    server = AgentServer((args.host, args.port), state)
    scheme = "http"
    if context is not None:
        server.socket = context.wrap_socket(server.socket, server_side=True, do_handshake_on_connect=False)
        scheme = "https"
        try:
            state.pairing_view_key = pairing_view_key(args.data_dir, create=True)
        except (OSError, ValueError) as error:
            print(f"Warning: pairing display unavailable ({type(error).__name__})", file=sys.stderr, flush=True)

    print(f"Nastart Agent {AGENT_VERSION} listening on {scheme}://{args.host}:{args.port}", flush=True)
    if state.pairing_code:
        print(f"One-time pairing code: {state.pairing_code}", flush=True)
    else:
        print("All six-digit pairing codes have been issued; pairing is unavailable.", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
