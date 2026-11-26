#!/usr/bin/env python3
"""Expose the Agent's single Docker inventory request over a Unix socket."""

import http.client
import http.server
import os
import socketserver
import sys
from pathlib import Path
from urllib.parse import parse_qsl

from nastart_agent import UnixHTTPConnection


def is_allowed(method: str, path: str) -> bool:
    route, separator, query = path.partition("?")
    if method != "GET" or route != "/v1.41/containers/json" or not separator:
        return False
    try:
        return parse_qsl(query, keep_blank_values=True, strict_parsing=True, max_num_fields=1) == [("all", "1")]
    except ValueError:
        return False


class DockerSocketProxyHandler(http.server.BaseHTTPRequestHandler):
    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(2)

    def parse_request(self) -> bool:
        if not super().parse_request():
            return False
        # Check the original target before BaseHTTPRequestHandler's normalization of leading slashes.
        target = self.requestline.split()[1]
        if not is_allowed(self.command, target):
            print(f"{self.command!r} {target!r}", file=sys.stderr, flush=True)
            self.respond(403, b'{"error":"forbidden"}')
            return False
        self.path = target
        return True

    def do_GET(self) -> None:
        connection = UnixHTTPConnection(self.server.docker_socket_path)
        try:
            # Relay the checked method and target only. The client cannot supply Docker headers or a body.
            connection.request(self.command, self.path)
            response = connection.getresponse()
            status, body = response.status, response.read()
        except (OSError, http.client.HTTPException):
            status, body = 502, b'{"error":"bad-gateway"}'
        finally:
            connection.close()
        self.respond(status, body)

    def respond(self, status: int, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        # The denial above is the only request log. Never print unparsed request lines or headers.
        pass


class DockerSocketProxy(socketserver.ThreadingUnixStreamServer):
    def __init__(self, listen_path: str, docker_socket_path: str) -> None:
        self.docker_socket_path = docker_socket_path
        path = Path(listen_path)
        if path.is_socket():
            path.unlink()
        super().__init__(listen_path, DockerSocketProxyHandler)
        try:
            # The socket lives in a volume shared only with the unprivileged Agent.
            path.chmod(0o666)
        except OSError:
            self.server_close()
            raise


if __name__ == "__main__":
    listen_path = os.environ.get("NASTART_PROXY_SOCKET", "/run/nastart-proxy/docker.sock")
    docker_socket_path = os.environ.get("NASTART_DOCKER_SOCKET", "/var/run/docker.sock")
    with DockerSocketProxy(listen_path, docker_socket_path) as proxy:
        proxy.serve_forever()
