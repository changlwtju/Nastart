#!/bin/zsh
# Start the already-installed iPhone WDA fixture without rebuilding it.
# Uses the XCTest runner path; direct app launch is diagnostic-only and is not
# sufficient to establish the WDA testmanagerd session.

set -euo pipefail

ROOT_DIR="${0:A:h}/.."
DEVICE_UDID="${DEVICE_UDID:-00008110-001E543122E0401E}"
LOCAL_PORT="${LOCAL_PORT:-8102}"
DEVICE_PORT="${DEVICE_PORT:-8100}"
WDA_BUNDLE="${WDA_BUNDLE:-com.changliwen.nastart.WebDriverAgentRunner.xctrunner}"
WDA_ARTIFACT_ROOT="${WDA_ARTIFACT_ROOT:-/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1}"
TIDEVICE_BIN="${TIDEVICE_BIN:-/Users/lagransun/Library/Python/3.9/bin/tidevice}"
WDA_RUNTIME_DIR="${WDA_RUNTIME_DIR:-$WDA_ARTIFACT_ROOT/runtime}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -x "$TIDEVICE_BIN" ]] || TIDEVICE_BIN="$(command -v tidevice || true)"
[[ -n "$TIDEVICE_BIN" ]] || die 'tidevice is required'
command -v iproxy >/dev/null 2>&1 || die 'iproxy is required'
command -v curl >/dev/null 2>&1 || die 'curl is required'

WDA_ARTIFACT_ROOT="$WDA_ARTIFACT_ROOT" DEVICE_UDID="$DEVICE_UDID" \
  LOCAL_PORT="$LOCAL_PORT" DEVICE_PORT="$DEVICE_PORT" \
  EXPECTED_RUNNER_BUNDLE="$WDA_BUNDLE" \
  "$ROOT_DIR/scripts/prepare_wda_recovery.sh" >/tmp/nastart-wda-iphone-preflight.txt

existing_status=$(curl --connect-timeout 1 --max-time 3 -fsS "http://127.0.0.1:$LOCAL_PORT/status" 2>/dev/null || true)
if printf '%s' "$existing_status" | /usr/bin/grep -Eq '"ready"[[:space:]]*:[[:space:]]*true'; then
  existing_bundle=$(printf '%s' "$existing_status" | plutil -extract value.build.productBundleIdentifier raw - 2>/dev/null || true)
  [[ "$existing_bundle" == "$WDA_BUNDLE" ]] \
    || die "Ready WDA reports $existing_bundle; verify and stop that runner before restarting with $WDA_BUNDLE"
  printf 'WDA already ready at http://127.0.0.1:%s\n' "$LOCAL_PORT"
  exit 0
fi

mkdir -p "$WDA_RUNTIME_DIR"
"$TIDEVICE_BIN" -u "$DEVICE_UDID" developer

iproxy "$LOCAL_PORT:$DEVICE_PORT" -u "$DEVICE_UDID" &
IPROXY_PID=$!
TIDEVICE_PID=''
cleanup() {
  [[ -n "$TIDEVICE_PID" ]] && kill "$TIDEVICE_PID" 2>/dev/null || true
  kill "$IPROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

"$TIDEVICE_BIN" -u "$DEVICE_UDID" xcuitest -B "$WDA_BUNDLE" \
  -e "USE_PORT:$DEVICE_PORT" \
  -e "WDA_PRODUCT_BUNDLE_IDENTIFIER:$WDA_BUNDLE" \
  --process-log-path "$WDA_RUNTIME_DIR/wda-process.log" \
  --console-log-path "$WDA_RUNTIME_DIR/wda-console.log" &
TIDEVICE_PID=$!

STATUS_FILE="$WDA_RUNTIME_DIR/status.json"
for attempt in {1..90}; do
  if curl --connect-timeout 1 --max-time 3 -fsS "http://127.0.0.1:$LOCAL_PORT/status" >"$STATUS_FILE" 2>/dev/null \
    && /usr/bin/grep -Eq '"ready"[[:space:]]*:[[:space:]]*true' "$STATUS_FILE"; then
    reported_bundle=$(plutil -extract value.build.productBundleIdentifier raw "$STATUS_FILE" 2>/dev/null || true)
    [[ "$reported_bundle" == "$WDA_BUNDLE" ]] || die "WDA reports unexpected bundle: $reported_bundle"
    printf 'WDA ready: http://127.0.0.1:%s/status\n' "$LOCAL_PORT"
    printf 'Keep this process in the foreground while collecting UI evidence.\n'
    wait "$TIDEVICE_PID"
    exit $?
  fi
  if ! kill -0 "$TIDEVICE_PID" 2>/dev/null; then
    die "WDA XCTest runner exited; inspect $WDA_RUNTIME_DIR/wda-process.log"
  fi
  sleep 1
done

die "WDA did not become ready; inspect $STATUS_FILE and $WDA_RUNTIME_DIR/wda-process.log"
