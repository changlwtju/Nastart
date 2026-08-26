#!/bin/zsh
# Validate the persistent iPhone WDA fixture and print the repeatable launch chain.
# This script only reads local artifacts; it does not build, install, reboot, or
# change the device.

set -euo pipefail

XCODE_APP="${XCODE_APP:-/Users/lagransun/Downloads/Xcode.app}"
WDA_ARTIFACT_ROOT="${WDA_ARTIFACT_ROOT:-/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1}"
WDA_APP="${WDA_APP:-$WDA_ARTIFACT_ROOT/WebDriverAgentRunner-Runner.app}"
XCTESTRUN="${XCTESTRUN:-$WDA_ARTIFACT_ROOT/WebDriverAgentRunner_iphoneos26.5-arm64.xctestrun}"
DDI_ARCHIVE="${DDI_ARCHIVE:-$WDA_ARTIFACT_ROOT/DeveloperDiskImage-16.3.zip}"
PROFILE="${PROFILE:-$WDA_ARTIFACT_ROOT/Provisioning Profiles/3f31c7b8-5004-4aa5-ae34-205e4754cbd0.mobileprovision}"
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
[[ -d "$XCODE_APP" ]] || die "Xcode not found: $XCODE_APP"
[[ -d "$WDA_APP" ]] || die "WDA Runner app not found: $WDA_APP"
[[ -f "$WDA_APP/Info.plist" ]] || die "WDA Runner Info.plist not found: $WDA_APP/Info.plist"
[[ -d "$WDA_APP/PlugIns/WebDriverAgentRunner.xctest" ]] || die 'WDA test plug-in not found'
[[ -f "$XCTESTRUN" ]] || die "xctestrun not found: $XCTESTRUN"
[[ -f "$DDI_ARCHIVE" ]] || die "iOS 16.3 DeviceSupport cache not found: $DDI_ARCHIVE"
[[ -f "$PROFILE" ]] || die "provisioning profile not found: $PROFILE"

runner_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WDA_APP/Info.plist")
test_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WDA_APP/PlugIns/WebDriverAgentRunner.xctest/Info.plist")
test_host_bundle=$(/usr/libexec/PlistBuddy -c 'Print :WebDriverAgentRunner:TestHostBundleIdentifier' "$XCTESTRUN")

[[ "$runner_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "Runner Bundle ID mismatch: $runner_bundle"
[[ "$test_bundle" == "$EXPECTED_TEST_BUNDLE" ]] || die "test Bundle ID mismatch: $test_bundle"
[[ "$test_host_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "xctestrun TestHostBundleIdentifier mismatch: $test_host_bundle"
codesign --verify --deep --strict "$WDA_APP" 2>/dev/null || die 'WDA code signature verification failed'

printf '%s\n' 'WDA iPhone fixture validated (no device operation executed):'
printf '  Xcode:        %s\n' "$XCODE_APP"
printf '  Artifact:     %s\n' "$WDA_ARTIFACT_ROOT"
printf '  Runner:       %s\n' "$WDA_APP"
printf '  xctestrun:    %s\n' "$XCTESTRUN"
printf '  DeviceSupport:%s\n' "$DDI_ARCHIVE"
printf '  Profile:      %s\n' "$PROFILE"
printf '  Runner ID:    %s\n' "$runner_bundle"
printf '  Test ID:      %s\n' "$test_bundle"
printf '  Device:       %s\n' "$DEVICE_UDID"
printf '  Port:         127.0.0.1:%s -> device:%s\n' "$LOCAL_PORT" "$DEVICE_PORT"
printf '\n'
printf '%s\n' '# If the device is unlocked and WDA is not already ready:'
printf "tidevice -u %s developer\n" "$DEVICE_UDID"
printf "tidevice -u %s xcuitest -B %s -e USE_PORT:%s --process-log-path '%s/runtime/wda-process.log' --console-log-path '%s/runtime/wda-console.log'\n" \
  "$DEVICE_UDID" "$EXPECTED_RUNNER_BUNDLE" "$DEVICE_PORT" "$WDA_ARTIFACT_ROOT" "$WDA_ARTIFACT_ROOT"
printf '%s\n' '# In a second terminal, keep usbmux forwarding in the foreground:'
printf 'iproxy %s:%s -u %s\n' "$LOCAL_PORT" "$DEVICE_PORT" "$DEVICE_UDID"
printf '%s\n' '# Gate all UI automation on this response:'
printf 'curl -fsS http://127.0.0.1:%s/status\n' "$LOCAL_PORT"
