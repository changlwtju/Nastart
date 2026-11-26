#!/usr/bin/env python3
"""Serve one media file with HTTP Range, latency, throttling, and fault controls."""

from __future__ import annotations

import argparse
import base64
import mimetypes
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


RANGE_PATTERN = re.compile(r"bytes=(\d*)-(\d*)$")


class PlaybackLabHandler(BaseHTTPRequestHandler):
    server_version = "NastartPlaybackLab/1.0"

    def do_HEAD(self) -> None:
        self._serve(send_body=False)

    def do_GET(self) -> None:
        self._serve(send_body=True)

    def _serve(self, send_body: bool) -> None:
        settings = self.server.settings
        if not self._is_authorized(settings):
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Nastart Playback Lab"')
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        request_path = unquote(urlsplit(self.path).path)
        if request_path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", "2")
            self.end_headers()
            if send_body:
                self.wfile.write(b"ok")
            return
        if not request_path.startswith(("/dsm/", "/jellyfin/", "/media/")):
            self.send_error(404)
            return

        file_size = settings.file.stat().st_size
        parsed_range = self._parse_range(self.headers.get("Range"), file_size)
        if parsed_range is None and self.headers.get("Range"):
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{file_size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        start, end = parsed_range or (0, file_size - 1)
        content_length = end - start + 1
        apply_fault = settings.fault_range_start is None or (
            send_body and parsed_range is not None and start == settings.fault_range_start
        )

        if apply_fault and settings.latency_ms:
            time.sleep(settings.latency_ms / 1000)
        self.send_response(206 if parsed_range else 200)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header(
            "Content-Type",
            mimetypes.guess_type(settings.file.name)[0] or "application/octet-stream",
        )
        self.send_header("Content-Length", str(content_length))
        self.send_header("Cache-Control", "no-store")
        if parsed_range:
            self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
        self.end_headers()
        if not send_body:
            return

        remaining = content_length
        sent = 0
        chunk_size = 64 * 1024
        bytes_per_second = settings.kbps * 1000 // 8 if apply_fault else 0
        disconnect_after = settings.disconnect_after if apply_fault else 0
        started_at = time.monotonic()
        try:
            with settings.file.open("rb") as media:
                media.seek(start)
                while remaining:
                    if disconnect_after and sent >= disconnect_after:
                        self.close_connection = True
                        return
                    chunk = media.read(min(chunk_size, remaining))
                    if not chunk:
                        return
                    self.wfile.write(chunk)
                    remaining -= len(chunk)
                    sent += len(chunk)
                    if bytes_per_second:
                        expected = sent / bytes_per_second
                        delay = expected - (time.monotonic() - started_at)
                        if delay > 0:
                            time.sleep(delay)
        except (BrokenPipeError, ConnectionResetError):
            return

    @staticmethod
    def _parse_range(header: str | None, size: int) -> tuple[int, int] | None:
        if not header:
            return None
        match = RANGE_PATTERN.fullmatch(header.strip())
        if not match:
            return None
        start_value, end_value = match.groups()
        if not start_value:
            suffix = int(end_value or 0)
            if suffix <= 0:
                return None
            return max(size - suffix, 0), size - 1
        start = int(start_value)
        end = int(end_value) if end_value else size - 1
        if start >= size or end < start:
            return None
        return start, min(end, size - 1)

    def _is_authorized(self, settings: argparse.Namespace) -> bool:
        if settings.username is None:
            return True
        expected = base64.b64encode(
            f"{settings.username}:{settings.password}".encode("utf-8")
        ).decode("ascii")
        return self.headers.get("Authorization", "") == f"Basic {expected}"

    def log_message(self, format: str, *args: object) -> None:
        sys.stdout.write(
            f"{self.log_date_time_string()} {self.command} {self.path} "
            f"range={self.headers.get('Range', '-')} {format % args}\n"
        )
        sys.stdout.flush()

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--latency-ms", type=int, default=0)
    parser.add_argument("--kbps", type=int, default=0)
    parser.add_argument("--disconnect-after", type=int, default=0)
    parser.add_argument("--fault-range-start", type=int,
                        help="Apply latency, throttling and disconnect only to GET ranges starting at this byte")
    parser.add_argument("--username")
    parser.add_argument("--password", default="")
    settings = parser.parse_args()
    if settings.fault_range_start is not None and settings.fault_range_start < 0:
        parser.error("--fault-range-start must be nonnegative")
    return settings


def main() -> None:
    settings = parse_args()
    settings.file = settings.file.expanduser().resolve()
    if not settings.file.is_file():
        raise SystemExit(f"media file not found: {settings.file}")
    server = ThreadingHTTPServer((settings.bind, settings.port), PlaybackLabHandler)
    server.settings = settings
    host, port = server.server_address
    print(f"serving {settings.file} at http://{host}:{port}/media/{settings.file.name}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
