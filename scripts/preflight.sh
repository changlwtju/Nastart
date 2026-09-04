#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"
python3 -m py_compile \
  "${SCRIPT_DIR}/preflight.py" \
  "${SCRIPT_DIR}/playback_trace_report.py" \
  "${SCRIPT_DIR}/playback_policy_simulator.py" \
  "${SCRIPT_DIR}/playback_compare_runs.py" \
  "${SCRIPT_DIR}/agent_smoke_test.py"
python3 "${SCRIPT_DIR}/preflight.py"
