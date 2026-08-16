#!/bin/zsh
# Validate and print the repeatable real-device WDA recovery chain.
# This preparation script deliberately performs no device operation.

set -euo pipefail
setopt null_glob

XCODE_APP="${XCODE_APP:-/Users/lagransun/Downloads/Xcode.app}"
DEVELOPER_DIR_PATH="$XCODE_APP/Contents/Developer"
WDA_DERIVED_DATA="${WDA_DERIVED_DATA:-/tmp/Nastart-WDA-Xcode26-oldid}"
WDA_PROJECT="${WDA_PROJECT:-/tmp/nastart-wda-src.69WNCZ/WebDriverAgent.xcodeproj}"
WDA_APP="${WDA_APP:-$WDA_DERIVED_DATA/Build/Products/Debug-iphoneos/WebDriverAgentRunner-Runner.app}"
XCTESTRUN="${XCTESTRUN:-$WDA_DERIVED_DATA/Build/Products/WebDriverAgentRunner_iphoneos26.5-arm64.xctestrun}"
DEVICE_UDID="${DEVICE_UDID:-00008030-001168403C43C02E}"
LOCAL_PORT="${LOCAL_PORT:-8101}"
DEVICE_PORT="${DEVICE_PORT:-8100}"
EXPECTED_RUNNER_BUNDLE="${EXPECTED_RUNNER_BUNDLE:-com.changliwen.nastart.WebDriverAgentRunner.xctrunner}"
EXPECTED_TEST_BUNDLE="${EXPECTED_TEST_BUNDLE:-com.changliwen.nastart.WebDriverAgentRunner}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -d "$XCODE_APP" ]] || die "Xcode not found: $XCODE_APP"
[[ -d "$WDA_APP" ]] || die "WDA Runner app not found: $WDA_APP"
[[ -f "$WDA_APP/Info.plist" ]] || die "WDA Runner Info.plist not found: $WDA_APP/Info.plist"
[[ -d "$WDA_APP/PlugIns/WebDriverAgentRunner.xctest" ]] || die "WDA test plug-in not found"

if [[ ! -f "$XCTESTRUN" ]]; then
  candidates=("$WDA_DERIVED_DATA"/Build/Products/*.xctestrun)
  (( ${#candidates} == 1 )) || die "expected one xctestrun under $WDA_DERIVED_DATA/Build/Products"
  XCTESTRUN="${candidates[1]}"
fi

runner_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WDA_APP/Info.plist")
test_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WDA_APP/PlugIns/WebDriverAgentRunner.xctest/Info.plist")
test_host_bundle=$(/usr/libexec/PlistBuddy -c 'Print :WebDriverAgentRunner:TestHostBundleIdentifier' "$XCTESTRUN")

[[ "$runner_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "Runner Bundle ID mismatch: $runner_bundle"
[[ "$test_bundle" == "$EXPECTED_TEST_BUNDLE" ]] || die "test Bundle ID mismatch: $test_bundle"
[[ "$test_host_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "xctestrun TestHostBundleIdentifier mismatch: $test_host_bundle"
codesign --verify --deep --strict "$WDA_APP" 2>/dev/null || die "WDA code signature verification failed"

printf '%s\n' 'WDA artifacts validated (no device operation executed):'
printf '  Xcode:     %s\n' "$XCODE_APP"
printf '  Runner:    %s\n' "$WDA_APP"
printf '  xctestrun: %s\n' "$XCTESTRUN"
printf '  Runner ID: %s\n' "$runner_bundle"
printf '  Test ID:   %s\n' "$test_bundle"
printf '  Device:    %s\n' "$DEVICE_UDID"
printf '  Port:      127.0.0.1:%s -> device:%s\n' "$LOCAL_PORT" "$DEVICE_PORT"
printf '\n'

if [[ -f "$WDA_PROJECT/project.pbxproj" ]]; then
  printf '%s\n' '# Terminal A — preferred: Xcode builds, signs, installs and starts the XCTest runner:'
  printf "DEVELOPER_DIR='%s' xcodebuild test -project '%s' -scheme WebDriverAgentRunner -configuration Debug -destination 'platform=iOS,id=%s' -derivedDataPath '%s' DEVELOPMENT_TEAM=5436TB5498 CODE_SIGN_IDENTITY='Apple Development' CODE_SIGN_STYLE=Automatic PRODUCT_BUNDLE_IDENTIFIER=com.changliwen.nastart.WebDriverAgentRunner WDA_PRODUCT_BUNDLE_IDENTIFIER=%s\n" \
    "$DEVELOPER_DIR_PATH" "$WDA_PROJECT" "$DEVICE_UDID" "$WDA_DERIVED_DATA" "$EXPECTED_RUNNER_BUNDLE"
else
  printf '%s\n' '# Terminal A — prebuilt fallback: use the validated UI-test xctestrun:'
  printf "DEVELOPER_DIR='%s' xcodebuild test-without-building -xctestrun '%s' -destination 'platform=iOS,id=%s'\n" "$DEVELOPER_DIR_PATH" "$XCTESTRUN" "$DEVICE_UDID"
fi

printf '\n%s\n' '# Terminal B — keep this process in the foreground:'
printf 'iproxy %s:%s -u %s\n' "$LOCAL_PORT" "$DEVICE_PORT" "$DEVICE_UDID"
printf '\n%s\n' '# Terminal C — do not start UI playback until this returns ready=true:'
printf 'curl -fsS http://127.0.0.1:%s/status\n' "$LOCAL_PORT"
