#!/usr/bin/env python3
"""Small Nastart Agent connectivity check for Mac/NAS handoff.

The script intentionally uses only Python's standard library so it can run on a
Mac, Synology shell, or the NAS development workspace without extra packages.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


def endpoint(base_url: str, path: str) -> str:
    parsed = urllib.parse.urlparse(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("base URL must look like http://host:8787 or https://host:8787")
    base_path = parsed.path.rstrip("/")
    return urllib.parse.urlunparse(parsed._replace(path=f"{base_path}{path}", query="", fragment=""))


def request_json(
    base_url: str,
    path: str,
    *,
    token: str | None = None,
    body: dict[str, Any] | None = None,
    timeout: float = 8,
) -> tuple[int, dict[str, Any]]:
    headers = {"Accept": "application/json"}
    payload: bytes | None = None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        payload = json.dumps(body, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(endpoint(base_url, path), data=payload, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            data = response.read()
            value = json.loads(data.decode("utf-8")) if data else {}
            return response.status, value
    except urllib.error.HTTPError as error:
        data = error.read()
        try:
            value = json.loads(data.decode("utf-8")) if data else {}
        except json.JSONDecodeError:
            value = {"error": data.decode("utf-8", errors="replace")}
        return error.code, value


def require_status(label: str, status: int, payload: dict[str, Any], expected: int = 200) -> None:
    if status != expected:
        detail = payload.get("error") or payload
        raise RuntimeError(f"{label} failed with HTTP {status}: {detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Check a Nastart Agent endpoint")
    parser.add_argument("--base-url", required=True, help="Agent URL, for example http://192.168.1.20:8787")
    parser.add_argument("--pairing-code", help="Pair once and use the returned token")
    parser.add_argument("--token", help="Existing Agent bearer token")
    args = parser.parse_args()

    try:
        status, health = request_json(args.base_url, "/healthz")
        require_status("healthz", status, health)
        token = args.token
        print(f"healthz: ok version={health.get('version', '-')}")

        if args.pairing_code:
            status, paired = request_json(args.base_url, "/v1/pair", body={"code": args.pairing_code})
            require_status("pair", status, paired)
            token = str(paired.get("token") or "")
            if not token:
                raise RuntimeError("pair response did not include a token")
            print(
                "pair: ok "
                f"agentId={paired.get('agentId', '-')} "
                f"host={paired.get('hostIdentity', '-')}"
            )

        if not token:
            print("authenticated checks skipped: provide --pairing-code or --token")
            return 0

        status, handshake = request_json(args.base_url, "/v1/handshake", token=token)
        require_status("handshake", status, handshake)
        capabilities = handshake.get("capabilities") or []
        print(
            "handshake: ok "
            f"api={handshake.get('apiVersion', '-')} "
            f"agent={handshake.get('agentVersion', '-')} "
            f"capabilities={','.join(capabilities)}"
        )

        status, snapshot = request_json(args.base_url, "/v1/snapshot", token=token)
        require_status("snapshot", status, snapshot)
        inventory = snapshot.get("inventory") or {}
        containers = snapshot.get("containers") or []
        host = snapshot.get("host") or {}
        print(
            "snapshot: ok "
            f"host={host.get('hostname', '-')} "
            f"docker={inventory.get('dockerAvailable', False)} "
            f"containers={len(containers)}"
        )
        return 0
    except Exception as error:
        print(f"agent smoke test failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
