import hashlib
import http.client
import io
import json
import os
import shutil
import socket
import socketserver
import ssl
import stat
import subprocess
import threading
import tempfile
import time
import unittest
import sys
from contextlib import closing, contextmanager, redirect_stderr, redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

from docker_socket_proxy import DockerSocketProxy, is_allowed
from nastart_agent import (
    AGENT_VERSION,
    AgentHandler,
    AgentServer,
    AgentState,
    advertise_agent,
    discovery_agent_version,
    handshake,
    host_snapshot,
    main,
    pairing_view_authorization,
    pairing_view_key,
    sample_interval_seconds,
    valid_pairing_code,
)


class AgentStateTests(unittest.TestCase):
    def test_pairing_code_requires_six_ascii_digits(self):
        self.assertTrue(valid_pairing_code("123456"))
        self.assertFalse(valid_pairing_code("12345"))
        self.assertFalse(valid_pairing_code("１２３４５６"))
        self.assertFalse(valid_pairing_code("123456 "))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                AgentState(Path(directory), "not-six-digits")

    def test_pairing_code_is_one_time_and_token_is_persisted(self):
        with tempfile.TemporaryDirectory() as directory:
            state = AgentState(Path(directory), "123456")
            token = state.pair("123456")
            self.assertIsNotNone(token)
            self.assertIsNone(state.pair("123456"))
            self.assertTrue(state.authenticates(f"Bearer {token}"))
            token_path = Path(directory) / "pairing-tokens.json"
            persisted = token_path.read_text(encoding="utf-8")
            records = json.loads(persisted)
            self.assertEqual(records[0]["sha256"], AgentState._digest(token))
            self.assertTrue(records[0]["id"])
            self.assertIsInstance(records[0]["createdAt"], int)
            self.assertEqual(stat.S_IMODE(token_path.stat().st_mode), 0o600)
            self.assertNotIn(token, persisted)
            restored = AgentState(Path(directory), None)
            self.assertTrue(restored.authenticates(f"Bearer {token}"))

    def test_pairing_is_rate_limited(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            limited = AgentState(path, "123456")
            for _ in range(5):
                self.assertIsNone(limited.pair("000000", source="192.0.2.1"))
            self.assertIsNone(limited.pair("123456", source="192.0.2.1"))

    def test_restart_rejects_all_issued_codes_including_unused_codes(self):
        path = Path(self.enterContext(tempfile.TemporaryDirectory()))
        state = AgentState(path, "123456")
        first_token = state.pair("123456")
        with patch("nastart_agent.secrets.randbelow", side_effect=[123456, 234567, 345678]):
            self.assertEqual(AgentState(path, "123456").pairing_code, "234567")
            restarted = AgentState(path, "123456")
        self.assertEqual(restarted.pairing_code, "345678")
        for code in ["123456", "234567"]:
            self.assertIsNone(restarted.pair(code))
        second_token = restarted.pair("345678")
        self.assertIsNotNone(second_token)
        restored = AgentState(path, "123456")
        self.assertTrue(restored.authenticates(f"Bearer {first_token}"))
        self.assertTrue(restored.authenticates(f"Bearer {second_token}"))

    def test_migrates_legacy_spk_and_revokes_only_the_selected_token(self):
        path = Path(self.enterContext(tempfile.TemporaryDirectory()))
        legacy = path / "pairing-token"
        original = f"sha256:{AgentState._digest('legacy-token')}"
        legacy.write_text(original)
        (path / "pairing-code-digest").write_text(AgentState._digest("234567"))
        (path / "spk-pairing-code").write_text("123456\n")
        with patch("nastart_agent.secrets.randbelow", side_effect=[123456, 234567, 42]):
            state = AgentState(path, None)
        self.assertEqual(state.pairing_code, "000042")
        self.assertTrue(state.authenticates("Bearer legacy-token"))
        self.assertEqual(legacy.read_text(), original)
        self.assertIsNone(state.tokens[0]["createdAt"])
        new_token = state.pair("000042")
        self.assertIsNotNone(new_token)
        self.assertTrue(state.authenticates("Bearer legacy-token"))
        self.assertTrue(state.authenticates(f"Bearer {new_token}"))

        records = json.loads(state.tokens_path.read_bytes())
        state.tokens_path.write_text(json.dumps([records[1]]))
        restarted = AgentState(path, None)
        self.assertFalse(restarted.authenticates("Bearer legacy-token"))
        self.assertTrue(restarted.authenticates(f"Bearer {new_token}"))
        restarted.tokens_path.write_text("[]")
        self.assertFalse(AgentState(path, None).authenticates("Bearer legacy-token"))

    def test_failed_token_write_preserves_existing_tokens_and_allows_retry(self):
        path = Path(self.enterContext(tempfile.TemporaryDirectory()))
        legacy = path / "pairing-token"
        legacy.write_text(f"sha256:{AgentState._digest('legacy-token')}")
        with patch("nastart_agent.write_pairing_state", side_effect=OSError):
            with self.assertRaises(OSError):
                AgentState(path, None)
        self.assertTrue(legacy.exists())
        state = AgentState(path, None)
        code = state.pairing_code
        with patch("nastart_agent.write_pairing_state", side_effect=OSError):
            with self.assertRaises(OSError):
                state.pair(code)
        self.assertTrue(state.authenticates("Bearer legacy-token"))
        self.assertEqual(len(state.tokens), 1)
        self.assertIsNotNone(state.pair(code))

    def test_damaged_history_is_not_reset(self):
        path = Path(self.enterContext(tempfile.TemporaryDirectory()))
        state = AgentState(path, "123456")
        history = path / "pairing-code-history.json"
        self.assertEqual(stat.S_IMODE(history.stat().st_mode), 0o600)
        history.write_text('["invalid"]')
        with self.assertRaisesRegex(ValueError, "invalid pairing-code-history"):
            AgentState(path, None)
        self.assertEqual(history.read_text(), '["invalid"]')

    def test_startup_log_code_pairs_through_http_handler_after_upgrade(self):
        path = Path(self.enterContext(tempfile.TemporaryDirectory()))
        (path / "pairing-token").write_text(f"sha256:{AgentState._digest('legacy-token')}")
        (path / "pairing-code-digest").write_text(AgentState._digest("123456"))

        def start():
            output = io.StringIO()
            with patch.object(sys, "argv", ["nastart_agent.py", "--data-dir", str(path), "--pairing-code", "123456"]), \
                    patch("nastart_agent.AgentServer") as server, \
                    patch.object(AgentState, "configure_tls", return_value=None), redirect_stdout(output):
                main()
            active_state = server.call_args.args[1]
            code = output.getvalue().split("One-time pairing code: ")[1].strip()
            self.assertTrue(valid_pairing_code(code))
            return active_state, code

        def request(state, method, endpoint, *, body=b"", token=""):
            request_bytes = (
                f"{method} {endpoint} HTTP/1.0\r\n"
                f"Content-Type: application/json\r\nContent-Length: {len(body)}\r\n"
                f"Authorization: Bearer {token}\r\n\r\n"
            ).encode() + body
            response = io.BytesIO()
            transport = SimpleNamespace(
                makefile=lambda *_: io.BytesIO(request_bytes), sendall=response.write, settimeout=lambda _: None,
            )
            with redirect_stdout(io.StringIO()):
                AgentHandler(transport, ("127.0.0.1", 0), SimpleNamespace(agent_state=state))
            headers, payload = response.getvalue().split(b"\r\n\r\n", 1)
            return int(headers.split()[1]), json.loads(payload)

        state, code = start()
        self.assertEqual(request(state, "GET", "/healthz"), (200, {"ok": True, "version": AGENT_VERSION}))
        self.assertEqual(request(state, "POST", "/v1/pair", body=b'{"code":"123456"}')[0], 401)
        body = json.dumps({"code": code}).encode()
        status, paired = request(state, "POST", "/v1/pair", body=body)
        self.assertEqual(status, 200)
        self.assertEqual(request(state, "POST", "/v1/pair", body=body)[0], 401)
        restarted, new_code = start()
        self.assertNotIn(new_code, {"123456", code})
        self.assertEqual(request(restarted, "POST", "/v1/pair", body=body)[0], 401)
        for token in ("legacy-token", paired["token"]):
            status, payload = request(restarted, "GET", "/v1/handshake", token=token)
            self.assertEqual(status, 200)
            self.assertEqual(payload["agentId"], paired["agentId"])

    def test_snapshot_and_handshake_are_read_only_structures(self):
        with tempfile.TemporaryDirectory() as directory:
            state = AgentState(Path(directory), "654321")
            self.assertEqual(handshake(state)["permissionLevel"], "read")
            snapshot = host_snapshot(state)
            self.assertIn("host", snapshot)
            self.assertIn("containers", snapshot)


@unittest.skipUnless(shutil.which("openssl"), "OpenSSL required for HTTPS")
class PairingDisplayTests(unittest.TestCase):
    def setUp(self):
        self.path = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.address = "https://nas.local:8787"
        self.enterContext(redirect_stdout(io.StringIO()))
        self.enterContext(patch.object(AgentHandler, "log_message"))

    def start(self):
        output = io.StringIO()
        with patch.object(sys, "argv", ["nastart_agent.py", "--data-dir", str(self.path), "--pairing-code", "012345"]), \
                patch("nastart_agent.AgentServer") as server, \
                patch.object(ssl.SSLContext, "wrap_socket"), redirect_stdout(output):
            main()
        self.state = server.call_args.args[1]
        self.context = self.state.configure_tls(None, None)
        self.authorization = pairing_view_authorization(pairing_view_key(self.path))
        return output.getvalue().split("One-time pairing code: ")[1].strip()

    @contextmanager
    def tls_connection(self, *, peer="192.168.1.10"):
        client, server = socket.socketpair()

        def handle():
            with server, self.context.wrap_socket(server, server_side=True) as stream:
                AgentHandler(stream, (peer, 43210), SimpleNamespace(agent_state=self.state))

        worker = threading.Thread(target=handle, daemon=True)
        worker.start()
        try:
            with client, ssl._create_unverified_context().wrap_socket(client, server_hostname="localhost") as stream:
                yield stream
        finally:
            worker.join(timeout=2)
            self.assertFalse(worker.is_alive())

    def request(self, method, path, *, headers=None, body=None, peer="192.168.1.10"):
        with self.tls_connection(peer=peer) as stream, closing(http.client.HTTPConnection("nas.local:8787")) as connection:
            connection.sock = stream
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            return response.status, response.headers, response.read().decode()

    def page(self):
        return self.request("GET", "/pairing-info", headers={"Authorization": self.authorization})

    def cli(self):
        output = io.StringIO()
        with self.tls_connection(peer="127.0.0.1") as stream, redirect_stdout(output), \
                patch.object(http.client.HTTPSConnection, "connect", lambda connection: setattr(connection, "sock", stream)), \
                patch.object(sys, "argv", ["nastart_agent.py", "show-config", "--data-dir", str(self.path),
                                           "--address", self.address]):
            main()
        return output.getvalue()

    def pair(self, code):
        status, _, payload = self.request("POST", "/v1/pair", headers={"Content-Type": "application/json"},
                                          body=json.dumps({"code": code}))
        return status, json.loads(payload)

    def test_page_and_cli_follow_the_live_code_across_pairing_and_restart(self):
        code = self.start()
        self.assertEqual(code, "012345")
        original_key = self.authorization
        status, headers, page = self.page()
        self.assertEqual(status, 200)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertIn(self.address, page)
        self.assertIn(f"Pairing code: {code}", page)
        self.assertIn("<svg", page)
        self.assertTrue(self.cli().startswith(f"Agent address: {self.address}\nPairing code: {code}\n"))
        status, paired = self.pair(code)
        self.assertEqual(status, 200)
        self.assertIn("No active pairing code", self.cli())
        self.assertNotIn("<svg", self.page()[2])
        new_code = self.start()
        self.assertNotEqual(new_code, code)
        self.assertEqual(self.authorization, original_key)
        self.assertEqual(self.pair(code), (401, {"error": "invalid-or-used-pairing-code"}))
        self.assertIn(f"Pairing code: {new_code}", self.page()[2])
        self.assertIn(f"Pairing code: {new_code}\n", self.cli())
        status, other = self.pair(new_code)
        self.assertEqual(status, 200)
        for token in (paired["token"], other["token"]):
            self.assertEqual(self.request("GET", "/v1/handshake", headers={"Authorization": f"Bearer {token}"})[0], 200)

    def test_web_key_is_private_and_independent_from_agent_api(self):
        code = self.start()
        self.assertEqual(stat.S_IMODE((self.path / "pairing-view-key").stat().st_mode), 0o600)
        status, headers, body = self.request("GET", "/pairing-info")
        self.assertEqual(status, 401)
        self.assertIn("Basic", headers["WWW-Authenticate"])
        self.assertNotIn(code, body)
        authorization = {"Authorization": self.authorization}
        self.assertEqual(self.request("GET", "/pairing-info", headers=authorization, peer="8.8.8.8")[0], 404)
        self.assertEqual(self.request("GET", "/v1/handshake", headers=authorization)[0], 401)
        self.assertEqual(self.request("GET", "/pairing-info", headers={**authorization, "Host": "nas/invalid"})[0], 400)
        self.state.pairing_view_key = None
        self.assertEqual(self.request("GET", "/pairing-info", headers=authorization)[0], 404)


class AgentDiscoveryTests(unittest.TestCase):
    def test_only_healthy_https_agent_is_advertised_and_withdrawn(self):
        args = SimpleNamespace(mdns_address="192.168.1.10", mdns_name="NAS Home", port=8787)
        stop = threading.Event()
        publisher = Mock()
        listener = Mock(return_value=publisher)
        service_info = Mock()
        module = SimpleNamespace(Zeroconf=listener, ServiceInfo=service_info, IPVersion=SimpleNamespace(V4Only="IPv4"))
        intervals = iter((False, False, False, True))

        def advance(_):
            if next(intervals):
                stop.set()

        with patch.dict(sys.modules, {"zeroconf": module}), \
                patch("nastart_agent.discovery_agent_version", side_effect=[None, "0.5.1", "0.5.1", None]) as probe, \
                patch.object(stop, "wait", side_effect=advance):
            advertise_agent(args, stop)
        self.assertEqual(probe.call_count, 4)
        listener.assert_called_once_with(interfaces=["192.168.1.10"], ip_version="IPv4")
        service_info.assert_called_once_with(
            "_nastart-agent._tcp.local.", "Nastart NAS-Home (8787)._nastart-agent._tcp.local.",
            addresses=[bytes([192, 168, 1, 10])], server="nastart-c0a8010a-8787.local.",
            port=8787, host_ttl=60, other_ttl=60, properties={"host": "NAS-Home", "version": "0.5.1"},
        )
        publisher.register_service.assert_called_once_with(service_info.return_value, allow_name_change=True)
        publisher.unregister_service.assert_called_once_with(service_info.return_value)
        publisher.close.assert_called_once()

    def test_health_check_uses_no_pairing_credentials(self):
        with patch("nastart_agent.http.client.HTTPSConnection") as tls:
            connection = tls.return_value
            response = connection.getresponse.return_value
            response.status = 200
            response.read.return_value = b'{"ok":true,"version":"0.5.1"}'
            self.assertEqual(discovery_agent_version("192.168.1.10", 8787), "0.5.1")
            connection.request.assert_called_once_with("GET", "/healthz")
            response.read.return_value = b'{"ok":true,"version":"<invalid>"}'
            self.assertIsNone(discovery_agent_version("192.168.1.10", 8787))

    def test_advertiser_requires_private_non_loopback_address(self):
        for address in ("127.0.0.1", "0.0.0.0", "192.0.2.20", "203.0.114.20", "example.local"):
            with self.subTest(address=address), self.assertRaisesRegex(ValueError, "LAN IPv4 address"):
                advertise_agent(SimpleNamespace(mdns_address=address, mdns_name=None, port=8787), threading.Event())


class EventHistoryTests(unittest.TestCase):
    def setUp(self):
        self.data_dir = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.state = AgentState(self.data_dir, "123456")

    def sampling_server(self):
        # Drive samples directly to exercise transitions without sleeping.
        with patch("nastart_agent.threading.Thread.start"):
            return self.enterContext(AgentServer(("127.0.0.1", 0), self.state))

    def test_history_keeps_latest_100_entries(self):
        for index in range(105):
            self.assertIsNone(self.state.pair("654321", source=f"192.0.2.{index}"))

        expected_sources = [f"192.0.2.{index}" for index in range(104, 4, -1)]
        self.assertEqual([event["source"] for event in self.state.recent_events()], expected_sources)
        restored = AgentState(self.data_dir, None)
        self.assertEqual(restored.recent_events(), self.state.recent_events())

    def test_history_round_trips_and_corrupt_file_starts_empty(self):
        path = self.data_dir / "events.json"
        self.assertEqual(self.state.recent_events(), [])
        self.state.pair("654321", source="192.0.2.10")
        expected = self.state.recent_events()
        self.assertEqual(json.loads(path.read_bytes()), expected)
        self.assertEqual(AgentState(self.data_dir, None).recent_events(), expected)

        for payload in (b"{incomplete", b"\xff", b"{}", b'[{"type":"pairing.failed"}]'):
            with self.subTest(payload=payload):
                path.write_bytes(payload)
                self.assertEqual(AgentState(self.data_dir, None).recent_events(), [])

    def test_only_changed_container_state_records_event(self):
        server = self.sampling_server()
        running = {"id": "abc123abc123", "name": "example", "state": "running", "status": "Up"}
        unchanged = dict(running, status="Up 10 seconds")
        exited = dict(running, state="exited")
        with patch("nastart_agent.docker_containers", side_effect=[
            ([running], None), ([unchanged], None), ([exited], None), ([exited], None)
        ]):
            server._sample_docker()
            self.assertEqual(self.state.recent_events(), [])
            server._sample_docker()
            self.assertEqual(self.state.recent_events(), [])
            server._sample_docker()
            server._sample_docker()

        [event] = self.state.recent_events()
        self.assertIs(type(event["timestamp"]), int)
        self.assertEqual(event, {
            "type": "container.state",
            "timestamp": event["timestamp"],
            "containerId": "abc123abc123",
            "containerName": "example",
            "from": "running",
            "to": "exited",
        })

    def test_docker_availability_records_each_flip(self):
        server = self.sampling_server()
        with patch("nastart_agent.docker_containers", side_effect=[
            ([], "ConnectionRefusedError"), ([], "FileNotFoundError"),
            ([], None), ([], "ConnectionRefusedError"),
        ]):
            server._sample_docker()
            server._sample_docker()
            self.assertEqual(self.state.recent_events(), [])
            server._sample_docker()
            server._sample_docker()

        events = self.state.recent_events()
        self.assertEqual([(event["type"], event["available"], event["detail"]) for event in events], [
            ("docker.availability", False, "ConnectionRefusedError"),
            ("docker.availability", True, None),
        ])

    def test_sampler_recovers_from_exception_without_holding_state_lock(self):
        server = self.sampling_server()
        stopped = {"id": "abc123abc123", "name": "example", "state": "exited"}
        running = dict(stopped, state="running")
        samples = iter([([stopped], None), ([running], None)])
        state_lock_samples = []

        def read_docker():
            state_lock_samples.append(self.state.lock.locked())
            if len(state_lock_samples) == 2:
                raise RuntimeError("unexpected Docker error")
            return next(samples)

        with patch("nastart_agent.docker_containers", side_effect=read_docker), patch.object(
            server._stop_sampling, "wait", side_effect=[False, False, True]
        ):
            server._sample_docker_loop()

        self.assertEqual(state_lock_samples, [False, False, False])
        [event] = self.state.recent_events()
        self.assertEqual((event["from"], event["to"]), ("exited", "running"))

    def test_failed_pairing_event_contains_only_source_and_timestamp(self):
        self.assertIsNone(self.state.pair("654321", source="192.0.2.5"))
        self.assertIsNotNone(self.state.pair("123456", source="192.0.2.5"))
        [event] = self.state.recent_events()
        self.assertEqual(set(event), {"type", "timestamp", "source"})
        self.assertEqual(event["type"], "pairing.failed")
        self.assertEqual(event["source"], "192.0.2.5")
        self.assertIs(type(event["timestamp"]), int)

    def test_sample_interval_defaults_and_clamps(self):
        with patch.dict(os.environ):
            os.environ.pop("NASTART_SAMPLE_INTERVAL_SECONDS", None)
            self.assertEqual(sample_interval_seconds(), 30)
            for value, expected in (("2", 10), ("10", 10), ("45", 45), ("bad", 30)):
                with self.subTest(value=value):
                    os.environ["NASTART_SAMPLE_INTERVAL_SECONDS"] = value
                    self.assertEqual(sample_interval_seconds(), expected)


@unittest.skipUnless(shutil.which("openssl"), "OpenSSL executable required")
class CertificateTests(unittest.TestCase):
    def setUp(self):
        self.data_dir = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.state = AgentState(self.data_dir, "123456")
        self.cert = self.data_dir / "tls-cert.pem"
        self.key = self.data_dir / "tls-key.pem"

    def new_fixture(self, cert, key, days, common_name):
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-keyout", str(key), "-out", str(cert),
             "-days", str(days), "-nodes", "-subj", f"/O=Nastart Fixture/CN={common_name}"],
            capture_output=True, check=True, timeout=15,
        )

    def test_generates_and_reuses_certificate_with_expected_metadata(self):
        now = time.time()
        self.assertIsNotNone(self.state.configure_tls(None, None))
        info = handshake(self.state)["certificate"]
        pem = self.cert.read_text(encoding="ascii")
        der = ssl.PEM_cert_to_DER_cert(pem)
        self.assertEqual(info["fingerprintSha256"], hashlib.sha256(der).hexdigest())
        self.assertEqual(info["subject"], socket.gethostname())
        self.assertAlmostEqual(info["notAfter"], now + 3650 * 86400, delta=5)
        self.assertEqual(self.state.certificate_check()["status"], "ok")
        self.assertEqual(stat.S_IMODE(self.cert.stat().st_mode), 0o644)
        self.assertEqual(stat.S_IMODE(self.key.stat().st_mode), 0o600)
        certificate_text = subprocess.check_output(
            ["openssl", "x509", "-in", str(self.cert), "-noout", "-text"], text=True, timeout=15,
        )
        for value in ("Public-Key: (2048 bit)", "rsaEncryption", f"DNS:{socket.gethostname()}",
                      "DNS:localhost", "IP Address:127.0.0.1"):
            self.assertIn(value, certificate_text)
        expiry = subprocess.check_output(
            ["openssl", "x509", "-in", str(self.cert), "-noout", "-enddate"], text=True, timeout=15,
        ).strip().removeprefix("notAfter=")
        self.assertEqual(info["notAfter"], ssl.cert_time_to_seconds(expiry))

        restarted = AgentState(self.data_dir, None)
        self.assertIsNotNone(restarted.configure_tls(None, None))
        self.assertEqual(restarted.certificate, info)
        self.assertEqual(self.cert.read_text(encoding="ascii"), pem)

    def test_renews_one_day_certificate_on_startup(self):
        self.new_fixture(self.cert, self.key, 1, "short-lived")
        old_cert = self.cert.read_bytes()
        old_key = self.key.read_bytes()
        self.assertIsNotNone(self.state.configure_tls(None, None))
        self.assertNotEqual(self.cert.read_bytes(), old_cert)
        self.assertNotEqual(self.key.read_bytes(), old_key)
        self.assertEqual(self.state.certificate["subject"], socket.gethostname())
        self.assertEqual(self.state.certificate_check()["status"], "ok")
        self.assertEqual(list(self.data_dir.glob(".tls-*")), [])

    def test_uses_explicit_short_lived_certificate_and_reports_expiration(self):
        cert = self.data_dir / "explicit-cert.pem"
        key = self.data_dir / "explicit-key.pem"
        self.new_fixture(cert, key, 1, "named, fixture")
        original = cert.read_bytes()
        self.assertIsNotNone(self.state.configure_tls(cert, key))
        self.assertEqual(self.state.certificate["subject"], "named, fixture")
        self.assertAlmostEqual(self.state.certificate["notAfter"], time.time() + 86400, delta=5)
        self.assertEqual(self.state.certificate_check()["status"], "expiring")
        with patch("nastart_agent.time.time", return_value=self.state.certificate["notAfter"] + 1):
            self.assertEqual(self.state.certificate_check()["status"], "expired")
        self.assertEqual(cert.read_bytes(), original)
        self.assertFalse(self.cert.exists())
        self.assertFalse(self.key.exists())

    def test_generation_failure_falls_back_without_leaving_partial_files(self):
        log = io.StringIO()
        failure = subprocess.CalledProcessError(1, "openssl")
        with patch("nastart_agent.run_openssl", side_effect=failure), redirect_stderr(log):
            self.assertIsNone(self.state.configure_tls(None, None))
        self.assertIsNone(self.state.certificate)
        self.assertEqual(self.state.certificate_check()["status"], "unavailable")
        self.assertIn("serving plain HTTP", log.getvalue())
        self.assertFalse(self.cert.exists())
        self.assertFalse(self.key.exists())
        self.assertEqual(list(self.data_dir.glob(".tls-*")), [])


class DockerHealthcheckTests(unittest.TestCase):
    agent_dir = Path(__file__).resolve().parent

    @contextmanager
    def start_agent(self, data_dir, *, openssl_available=True):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        env = dict(os.environ, NASTART_PORT=str(port))
        env.pop("NASTART_TLS_CERT", None)
        env.pop("NASTART_TLS_KEY", None)
        if not openssl_available:
            env["PATH"] = str(data_dir)
        with (data_dir / "stderr.log").open("wb") as log, subprocess.Popen(
            [sys.executable, str(self.agent_dir / "nastart_agent.py"), "--host", "127.0.0.1",
             "--data-dir", str(data_dir), "--pairing-code", "123456"],
            env=env, stdout=subprocess.DEVNULL, stderr=log,
        ) as agent:
            try:
                yield agent, env, port
            finally:
                if agent.poll() is None:
                    agent.terminate()
                    try:
                        agent.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        agent.kill()
                        agent.wait()

    def compose_health_probe(self):
        compose_lines = (self.agent_dir / "compose.yaml").read_text(encoding="utf-8").splitlines()
        probe_spec = next(line.strip().removeprefix("test: ") for line in compose_lines
                          if line.strip().startswith("test: "))
        mode, executable, *args = json.loads(probe_spec)
        self.assertEqual((mode, executable), ("CMD", "python3"))
        return [sys.executable, *args]

    def wait_for_health(self, agent, probe, env):
        deadline = time.monotonic() + 8
        while True:
            self.assertIsNone(agent.poll(), "Agent exited before the healthcheck succeeded")
            result = subprocess.run(probe, cwd=self.agent_dir, env=env, capture_output=True, text=True, timeout=3)
            if result.returncode == 0:
                return
            if time.monotonic() >= deadline:
                self.fail(f"Healthcheck never succeeded: {result.stderr}")
            time.sleep(0.05)

    def test_compose_probe_succeeds_while_agent_runs_and_fails_after_stop(self):
        probe = self.compose_health_probe()
        with tempfile.TemporaryDirectory() as directory:
            with self.start_agent(Path(directory)) as (agent, env, _):
                self.wait_for_health(agent, probe, env)
            result = subprocess.run(probe, cwd=self.agent_dir, env=env, capture_output=True, timeout=3)
            self.assertNotEqual(result.returncode, 0)

    def test_missing_openssl_serves_http_with_certificate_unavailable(self):
        probe = self.compose_health_probe()
        with tempfile.TemporaryDirectory() as directory:
            data_dir = Path(directory)
            with self.start_agent(data_dir, openssl_available=False) as (agent, env, port):
                self.wait_for_health(agent, probe, env)
                connection = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
                try:
                    connection.request("POST", "/v1/pair", body=b'{"code":"123456"}',
                                       headers={"Content-Type": "application/json"})
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    paired = json.load(response)
                    self.assertIsNone(paired["certificate"])
                    connection.request("GET", "/v1/diagnostics", headers={"Authorization": f"Bearer {paired['token']}"})
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    checks = {check["id"]: check for check in json.load(response)["checks"]}
                    self.assertEqual(checks["certificate"]["status"], "unavailable")
                    self.assertIn("OpenSSL executable not found", checks["certificate"]["detail"])
                finally:
                    connection.close()
            self.assertIn("Warning: OpenSSL executable not found", (data_dir / "stderr.log").read_text())
            self.assertFalse((data_dir / "tls-cert.pem").exists())


class RecordingDockerHandler(socketserver.StreamRequestHandler):
    def handle(self):
        request_line = self.rfile.readline().decode("ascii").rstrip("\r\n")
        headers = []
        while header := self.rfile.readline():
            if header == b"\r\n":
                break
            headers.append(header)
        self.server.requests.append((request_line, headers))
        self.wfile.write(
            f"HTTP/1.0 {self.server.status} Test\r\n"
            f"Content-Length: {len(self.server.body)}\r\n\r\n".encode("ascii") + self.server.body
        )


class DockerSocketProxyTests(unittest.TestCase):
    allowed_path = "/v1.41/containers/json?all=1"
    denied_requests = (
        ("POST", "/v1.41/containers/fixture/stop"),
        ("DELETE", "/v1.41/containers/fixture"),
        ("GET", "/version"),
        ("GET", "/v1.41/version"),
        ("GET", "/v1.41/containers/json"),
        ("GET", "/v1.41/containers/json?all=1&foo=bar"),
        ("GET", "/v1.41/containers/json?all=1&all=1"),
        ("GET", "/v1.41/containers/json?all=0"),
        ("GET", "//v1.41/containers/json?all=1"),
        ("PATCH", allowed_path),
        ("HEAD", allowed_path),
    )

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        backend_path = self.directory / "backend.sock"
        self.proxy_path = self.directory / "proxy.sock"
        self.backend = socketserver.UnixStreamServer(str(backend_path), RecordingDockerHandler)
        self.backend.requests = []
        self.backend.status = 200
        self.backend.body = b'[{"Id": "fixture", "Names": ["/fixture"]}]\n'
        self.start_server(self.backend)
        self.proxy = DockerSocketProxy(str(self.proxy_path), str(backend_path))
        self.start_server(self.proxy)

    def start_server(self, server):
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(thread.join, 3)
        self.addCleanup(server.shutdown)

    def request(self, method, path, body=None, headers=None):
        request_headers = {"Host": "localhost", **(headers or {})}
        if body is not None:
            request_headers["Content-Length"] = str(len(body))
        lines = [f"{method} {path} HTTP/1.1", *(f"{key}: {value}" for key, value in request_headers.items())]
        request = "\r\n".join([*lines, "", ""]).encode("ascii")
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(2)
            connection.connect(str(self.proxy_path))
            # Send the whole fixture before the proxy can close on a denied header.
            connection.sendall(request + (body or b""))
            with http.client.HTTPResponse(connection, method=method) as response:
                response.begin()
                return response.status, response.read()

    def test_allowlist_parses_exactly_one_all_parameter(self):
        self.assertTrue(is_allowed("GET", self.allowed_path))
        self.assertTrue(is_allowed("GET", "/v1.41/containers/json?all=%31"))
        for method, path in self.denied_requests:
            with self.subTest(method=method, path=path):
                self.assertFalse(is_allowed(method, path))

    def test_forwards_allowed_request_and_returns_body_unchanged(self):
        status, body = self.request("GET", self.allowed_path, headers={"X-Fixture": "local-only"})
        self.assertEqual((status, body), (200, self.backend.body))
        (line, headers), = self.backend.requests
        self.assertEqual(line, f"GET {self.allowed_path} HTTP/1.1")
        self.assertNotIn(b"X-Fixture: local-only\r\n", headers)

    def test_preserves_backend_status_and_body(self):
        self.backend.status = 503
        self.backend.body = b'{ "message": "Docker is temporarily unavailable" }\n'
        self.assertEqual(self.request("GET", self.allowed_path), (503, self.backend.body))
        self.assertEqual(len(self.backend.requests), 1)

    def test_denials_never_reach_backend_and_do_not_log_body(self):
        log = io.StringIO()
        with redirect_stderr(log):
            for method, path in self.denied_requests:
                with self.subTest(method=method, path=path):
                    self.assertEqual(self.request(method, path, body=b"local-only-fixture"),
                                     (403, b"" if method == "HEAD" else b'{"error":"forbidden"}'))
                    self.assertEqual(self.backend.requests, [])
        self.assertEqual(log.getvalue().splitlines(),
                         [f"{method!r} {path!r}" for method, path in self.denied_requests])

    def test_unavailable_backend_returns_502(self):
        self.proxy.docker_socket_path = str(self.directory / "missing.sock")
        self.assertEqual(self.request("GET", self.allowed_path), (502, b'{"error":"bad-gateway"}'))

    def test_replaces_stale_socket_with_explicit_permissions(self):
        stale_path = self.directory / "stale.sock"
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as stale:
            stale.bind(str(stale_path))
        with DockerSocketProxy(str(stale_path), self.proxy.docker_socket_path):
            self.assertTrue(stale_path.is_socket())
            self.assertEqual(stat.S_IMODE(stale_path.stat().st_mode), 0o666)


if __name__ == "__main__":
    unittest.main()
