#!/bin/zsh
# Start the already-installed iPhone WDA fixture without rebuilding it.
# Uses the XCTest runner path; direct app launch is diagnostic-only and is not
# sufficient to establish the WDA testmanagerd session.

set -euo pipefail
unsetopt BG_NICE

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

if (( $# > 1 )) || [[ $# -eq 1 && "$1" != '--check-usb' ]]; then
  die 'Usage: start_wda_iphone.sh [--check-usb]'
fi

# Check the launcher's own access before interpreting an empty USB device list
# or reusing an old Runner. --check-usb does not call developer or XCTest.
command -v python3 >/dev/null 2>&1 || die 'python3 is required'
python3 - "$LOCAL_PORT" "$DEVICE_PORT" <<'PY'
import errno
import socket
import sys

try:
    port, device_port = map(int, sys.argv[1:])
    if not (1 <= port <= 65535 and 1 <= device_port <= 65535):
        raise ValueError
except ValueError:
    sys.exit("LOCAL_PORT and DEVICE_PORT must be in 1..65535")

try:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as usb:
        usb.settimeout(2)
        usb.connect("/var/run/usbmuxd")
except PermissionError as error:
    sys.exit(f"USB developer service access denied in this execution session ({error.strerror}).")
except OSError as error:
    sys.exit(f"Cannot contact the local usbmuxd service: {error}")

try:
    with socket.socket() as loopback:
        loopback.bind(("127.0.0.1", port))
except OSError as error:
    if error.errno == errno.EADDRINUSE:
        sys.exit(f"Loopback port {port} is already in use. Verify ownership and choose a free port.")
    sys.exit(f"Cannot bind the WDA loopback port {port}: {error}")
PY

command -v idevice_id >/dev/null 2>&1 || die 'idevice_id is required'
command -v ideviceinfo >/dev/null 2>&1 || die 'ideviceinfo is required'
usb_devices="$(idevice_id -l)" || die 'USB device enumeration failed'
printf '%s\n' "$usb_devices" | grep -Fxiq -- "$DEVICE_UDID" \
  || die 'Target iPhone is absent from the current USB device list'
usb_udid="$(ideviceinfo -s -u "$DEVICE_UDID" -k UniqueDeviceID)" || die 'Cannot read live USB identity'
[[ "${usb_udid:u}" == "${DEVICE_UDID:u}" ]] || die 'USB target identity changed'
device_name="$(ideviceinfo -s -u "$DEVICE_UDID" -k DeviceName)" || die 'Cannot read device name'
device_model="$(ideviceinfo -s -u "$DEVICE_UDID" -k ProductType)" || die 'Cannot read device model'
device_os="$(ideviceinfo -s -u "$DEVICE_UDID" -k ProductVersion)" || die 'Cannot read device system version'
[[ -n "$device_name" && -n "$device_model" && -n "$device_os" ]] || die 'Incomplete live USB identity'
printf 'USB target verified: %s (%s, iOS %s); loopback port %s available.\n' \
  "$device_name" "$device_model" "$device_os" "$LOCAL_PORT"
[[ "${1:-}" != '--check-usb' ]] || exit 0

[[ -x "$TIDEVICE_BIN" ]] || TIDEVICE_BIN="$(command -v tidevice || true)"
[[ -n "$TIDEVICE_BIN" ]] || die 'tidevice is required'
command -v iproxy >/dev/null 2>&1 || die 'iproxy is required'
command -v curl >/dev/null 2>&1 || die 'curl is required'

umask 077
mkdir -p "$WDA_RUNTIME_DIR"
RUN_DIR="$(mktemp -d "$WDA_RUNTIME_DIR/window.XXXXXXXX")"
printf 'WDA window evidence: %s\n' "$RUN_DIR"
WDA_ARTIFACT_ROOT="$WDA_ARTIFACT_ROOT" DEVICE_UDID="$DEVICE_UDID" \
  LOCAL_PORT="$LOCAL_PORT" DEVICE_PORT="$DEVICE_PORT" \
  EXPECTED_RUNNER_BUNDLE="$WDA_BUNDLE" \
  "$ROOT_DIR/scripts/prepare_wda_recovery.sh" >"$RUN_DIR/preflight.txt"
"$TIDEVICE_BIN" -u "$DEVICE_UDID" developer

iproxy --local --source 127.0.0.1 "$LOCAL_PORT:$DEVICE_PORT" -u "$DEVICE_UDID" \
  >"$RUN_DIR/iproxy.log" 2>&1 &
IPROXY_PID=$!
TIDEVICE_PID=''
cleanup() {
  [[ -n "$TIDEVICE_PID" ]] && kill "$TIDEVICE_PID" 2>/dev/null || true
  kill "$IPROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$TIDEVICE_BIN" -u "$DEVICE_UDID" xcuitest -B "$WDA_BUNDLE" \
  -e "USE_PORT:$DEVICE_PORT" \
  -e "WDA_PRODUCT_BUNDLE_IDENTIFIER:$WDA_BUNDLE" \
  --process-log-path "$RUN_DIR/wda-process.log" \
  --console-log-path "$RUN_DIR/wda-console.log" >"$RUN_DIR/xcuitest.log" 2>&1 &
TIDEVICE_PID=$!

STATUS_FILE="$RUN_DIR/status.json"
for attempt in {1..90}; do
  kill -0 "$IPROXY_PID" 2>/dev/null || die "USB forwarding stopped; inspect $RUN_DIR/iproxy.log"
  kill -0 "$TIDEVICE_PID" 2>/dev/null || die "WDA XCTest runner exited; inspect $RUN_DIR/xcuitest.log"
  if curl --connect-timeout 1 --max-time 3 -fsS "http://127.0.0.1:$LOCAL_PORT/status" >"$STATUS_FILE" 2>/dev/null \
    && /usr/bin/grep -Eq '"ready"[[:space:]]*:[[:space:]]*true' "$STATUS_FILE"; then
    kill -0 "$IPROXY_PID" 2>/dev/null || die 'USB forwarding stopped during readiness check'
    kill -0 "$TIDEVICE_PID" 2>/dev/null || die 'WDA XCTest exited during readiness check'
    reported_bundle=$(plutil -extract value.build.productBundleIdentifier raw "$STATUS_FILE" 2>/dev/null || true)
    [[ "$reported_bundle" == "$WDA_BUNDLE" ]] || die "WDA reports unexpected bundle: $reported_bundle"
    printf 'WDA ready: http://127.0.0.1:%s/status\n' "$LOCAL_PORT"
    printf 'Keep this process in the foreground while collecting UI evidence.\n'
    wait "$TIDEVICE_PID"
    exit $?
  fi
  sleep 1
done

die "WDA did not become ready; inspect $STATUS_FILE and $RUN_DIR/xcuitest.log"
