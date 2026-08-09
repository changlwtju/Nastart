import tempfile
import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from nastart_agent import AgentState, handshake, host_snapshot


class AgentStateTests(unittest.TestCase):
    def test_pairing_code_is_one_time_and_token_is_persisted(self):
        with tempfile.TemporaryDirectory() as directory:
            state = AgentState(Path(directory), "123456")
            token = state.pair("123456")
            self.assertIsNotNone(token)
            self.assertIsNone(state.pair("123456"))
            self.assertTrue(state.authenticates(f"Bearer {token}"))
            persisted = (Path(directory) / "pairing-token").read_text(encoding="utf-8")
            self.assertTrue(persisted.startswith("sha256:"))
            self.assertNotIn(token, persisted)
            restored = AgentState(Path(directory), None)
            self.assertTrue(restored.authenticates(f"Bearer {token}"))

    def test_pairing_is_rate_limited_and_consumed_code_stays_disabled_after_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            limited = AgentState(path, "123456")
            for _ in range(5):
                self.assertIsNone(limited.pair("000000", source="192.0.2.1"))
            self.assertIsNone(limited.pair("123456", source="192.0.2.1"))

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            state = AgentState(path, "654321")
            self.assertIsNotNone(state.pair("654321"))
            restarted = AgentState(path, "654321")
            self.assertIsNone(restarted.pair("654321"))
            rotated = AgentState(path, "111111")
            self.assertIsNotNone(rotated.pair("111111"))

    def test_snapshot_and_handshake_are_read_only_structures(self):
        with tempfile.TemporaryDirectory() as directory:
            state = AgentState(Path(directory), "654321")
            self.assertEqual(handshake(state)["permissionLevel"], "read")
            snapshot = host_snapshot(state)
            self.assertIn("host", snapshot)
            self.assertIn("containers", snapshot)


if __name__ == "__main__":
    unittest.main()
