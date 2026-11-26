#!/bin/zsh
# Validate the persistent iPhone WDA fixture and print the repeatable launch chain.
# This script only reads local artifacts; it does not build, install, reboot, or
# change the device.

set -euo pipefail

if [[ -d /Applications/Xcode-26.6.app ]]; then
  XCODE_APP="${XCODE_APP:-/Applications/Xcode-26.6.app}"
else
  XCODE_APP="${XCODE_APP:-/Users/lagransun/Downloads/Xcode.app}"
fi
WDA_ARTIFACT_ROOT="${WDA_ARTIFACT_ROOT:-/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1}"
WDA_APP="${WDA_APP:-$WDA_ARTIFACT_ROOT/WebDriverAgentRunner-Runner.app}"
XCTESTRUN="${XCTESTRUN:-$WDA_ARTIFACT_ROOT/WebDriverAgentRunner_iphoneos26.5-arm64.xctestrun}"
DDI_ARCHIVE="${DDI_ARCHIVE:-$WDA_ARTIFACT_ROOT/DeveloperDiskImage-16.3.zip}"
PROFILE="${PROFILE:-$WDA_APP/embedded.mobileprovision}"
DEVICE_UDID="${DEVICE_UDID:-00008110-001E543122E0401E}"
LOCAL_PORT="${LOCAL_PORT:-8102}"
DEVICE_PORT="${DEVICE_PORT:-8100}"
EXPECTED_RUNNER_BUNDLE="${EXPECTED_RUNNER_BUNDLE:-com.changliwen.nastart.WebDriverAgentRunner.xctrunner}"
EXPECTED_TEST_BUNDLE="${EXPECTED_TEST_BUNDLE:-com.changliwen.nastart.WebDriverAgentRunner}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v codesign >/dev/null 2>&1 || die 'codesign is required'
command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v python3 >/dev/null 2>&1 || die 'python3 is required'
[[ -d "$XCODE_APP" ]] || die "Xcode not found: $XCODE_APP"
[[ -d "$WDA_APP" ]] || die "WDA Runner app not found: $WDA_APP"
[[ -f "$WDA_APP/Info.plist" ]] || die "WDA Runner Info.plist not found: $WDA_APP/Info.plist"
[[ -d "$WDA_APP/PlugIns/WebDriverAgentRunner.xctest" ]] || die 'WDA test plug-in not found'
[[ -f "$XCTESTRUN" ]] || die "xctestrun not found: $XCTESTRUN"
[[ -f "$DDI_ARCHIVE" ]] || die "iOS 16.3 DeviceSupport cache not found: $DDI_ARCHIVE"
[[ -f "$PROFILE" ]] || die "provisioning profile not found: $PROFILE"

# security cms may require keychain access even for a read-only decode. The
# fallback still verifies the CMS signature; code signing is checked below.
profile_plist=$(security cms -D -i "$PROFILE" 2>/dev/null | plutil -convert xml1 -o - - 2>/dev/null) || {
  profile_plist=$(openssl smime -verify -inform DER -in "$PROFILE" -noverify 2>/dev/null \
    | plutil -convert xml1 -o - -) || die "cannot decode provisioning profile: $PROFILE"
}
profile_expires_at=$(printf '%s' "$profile_plist" | plutil -extract ExpirationDate raw - 2>/dev/null) \
  || die "cannot read provisioning profile expiration: $PROFILE"
profile_expiration_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$profile_expires_at" '+%s' 2>/dev/null) \
  || die "invalid provisioning profile expiration: $profile_expires_at"
(( profile_expiration_epoch > $(date -u '+%s') )) \
  || die "provisioning profile expired at $profile_expires_at: $PROFILE"

runner_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WDA_APP/Info.plist")
test_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WDA_APP/PlugIns/WebDriverAgentRunner.xctest/Info.plist")
test_host_bundle=$(/usr/libexec/PlistBuddy -c 'Print :WebDriverAgentRunner:TestHostBundleIdentifier' "$XCTESTRUN")

[[ "$runner_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "Runner Bundle ID mismatch: $runner_bundle"
[[ "$test_bundle" == "$EXPECTED_TEST_BUNDLE" ]] || die "test Bundle ID mismatch: $test_bundle"
[[ "$test_host_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "xctestrun TestHostBundleIdentifier mismatch: $test_host_bundle"

printf '%s' "$profile_plist" | python3 -c '
import plistlib
import sys

profile = plistlib.loads(sys.stdin.buffer.read())
if sys.argv[1].upper() not in [uid.upper() for uid in profile.get("ProvisionedDevices", [])]:
    sys.exit("WDA provisioning profile does not cover the requested device.")
if not profile.get("Entitlements", {}).get("application-identifier", "").endswith("." + sys.argv[2]):
    sys.exit("WDA provisioning profile does not match the Runner bundle.")
' "$DEVICE_UDID" "$runner_bundle"

python3 - "$XCTESTRUN" "$WDA_APP" <<'PY'
import plistlib
from pathlib import Path
import sys

test_run, runner = map(lambda value: Path(value).resolve(), sys.argv[1:])
with test_run.open("rb") as file:
    target = plistlib.load(file)["WebDriverAgentRunner"]

def product_path(key):
    value = target.get(key, "")
    path = value.replace("__TESTROOT__", str(test_run.parent)).replace("__TESTHOST__", str(runner))
    return Path(path).resolve() if Path(path).is_absolute() else None

if product_path("TestHostPath") != runner:
    sys.exit("xctestrun TestHostPath points to another Runner. Use the matching xctestrun.")
if product_path("TestBundlePath") != (runner / "PlugIns/WebDriverAgentRunner.xctest").resolve():
    sys.exit("xctestrun TestBundlePath points to another test bundle.")
PY

codesign --verify --deep --strict "$WDA_APP" || die 'WDA code signature verification failed'

printf '%s\n' 'WDA iPhone fixture validated (no device operation executed):'
printf '  Xcode:        %s\n' "$XCODE_APP"
printf '  Artifact:     %s\n' "$WDA_ARTIFACT_ROOT"
printf '  Runner:       %s\n' "$WDA_APP"
printf '  xctestrun:    %s\n' "$XCTESTRUN"
printf '  DeviceSupport:%s\n' "$DDI_ARCHIVE"
printf '  Profile:      %s\n' "$PROFILE"
printf '  Expires:      %s\n' "$profile_expires_at"
printf '  Runner ID:    %s\n' "$runner_bundle"
printf '  Test ID:      %s\n' "$test_bundle"
printf '  Device:       %s\n' "$DEVICE_UDID"
printf '  Port:         127.0.0.1:%s -> device:%s\n' "$LOCAL_PORT" "$DEVICE_PORT"
printf '\n'
printf '%s\n' '# If the device is unlocked and WDA is not already ready:'
printf "tidevice -u %s developer\n" "$DEVICE_UDID"
printf "tidevice -u %s xcuitest -B %s -e USE_PORT:%s -e WDA_PRODUCT_BUNDLE_IDENTIFIER:%s --process-log-path '%s/runtime/wda-process.log' --console-log-path '%s/runtime/wda-console.log'\n" \
  "$DEVICE_UDID" "$EXPECTED_RUNNER_BUNDLE" "$DEVICE_PORT" "$EXPECTED_RUNNER_BUNDLE" "$WDA_ARTIFACT_ROOT" "$WDA_ARTIFACT_ROOT"
printf '%s\n' '# In a second terminal, keep usbmux forwarding in the foreground:'
printf 'iproxy %s:%s -u %s\n' "$LOCAL_PORT" "$DEVICE_PORT" "$DEVICE_UDID"
printf '%s\n' '# Gate all UI automation on this response:'
printf 'curl -fsS http://127.0.0.1:%s/status\n' "$LOCAL_PORT"
