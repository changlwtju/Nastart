#!/bin/zsh
# Mac-only WDA recovery preparation.
# This script validates the historical WDA artifacts and prints the commands
# that would restore them. It intentionally performs no device operation.

set -euo pipefail

XCODE_APP="/Users/lagransun/Downloads/Xcode.app"
DEVELOPER_DIR_PATH="$XCODE_APP/Contents/Developer"
HIST_APP="/tmp/Nastart-WDA-Derived/Build/Products/Debug-iphoneos/WebDriverAgentRunner-Runner.app"
HIST_XCTESTRUN="/tmp/Nastart-WDA-Derived/Build/Products/WebDriverAgentRunner_iphoneos26.5-arm64.xctestrun"
TARGET_UDID="00008110-001E543122E0401E"
EXPECTED_RUNNER_BUNDLE="com.changliwen.nastart.WebDriverAgentRunner.xctrunner"
EXPECTED_TEST_BUNDLE="com.changliwen.nastart.WebDriverAgentRunner"

die() {
  print -u2 "ERROR: $*"
  exit 1
}

[[ -d "$XCODE_APP" ]] || die "Xcode not found: $XCODE_APP"
[[ -d "$HIST_APP" ]] || die "historical Runner not found: $HIST_APP"
[[ -f "$HIST_XCTESTRUN" ]] || die "historical xctestrun not found: $HIST_XCTESTRUN"

runner_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$HIST_APP/Info.plist")
test_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$HIST_APP/PlugIns/WebDriverAgentRunner.xctest/Info.plist")
test_host_bundle=$(/usr/libexec/PlistBuddy -c 'Print :WebDriverAgentRunner:TestHostBundleIdentifier' "$HIST_XCTESTRUN")

[[ "$runner_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "historical Runner Bundle ID changed: $runner_bundle"
[[ "$test_bundle" == "$EXPECTED_TEST_BUNDLE" ]] || die "historical test Bundle ID changed: $test_bundle"
[[ "$test_host_bundle" == "$EXPECTED_RUNNER_BUNDLE" ]] || die "historical TestHostBundleIdentifier changed: $test_host_bundle"

print "Historical WDA artifacts validated (Mac only):"
print "  Runner:    $HIST_APP"
print "  xctestrun: $HIST_XCTESTRUN"
print "  Runner ID: $runner_bundle"
print "  Test ID:   $test_bundle"
print "  Target:    $TARGET_UDID"
print ""
print "No iPhone operation was executed. The following commands are prepared only:"
print ""
print "# Terminal A — restore/test the historical Runner (installs and launches on iPhone; do not run without approval):"
print -r -- "DEVELOPER_DIR='$DEVELOPER_DIR_PATH' xcodebuild test-without-building \\"
print -r -- "  -xctestrun '$HIST_XCTESTRUN' \\"
print -r -- "  -destination 'id=$TARGET_UDID' \\"
print -r -- "  -only-testing:WebDriverAgentRunner"
print ""
print "# Terminal B — only after Terminal A is authorized and running:"
print "iproxy 8100 8100 $TARGET_UDID"
print ""
print "# Verification endpoint after both commands are authorized and running:"
print "curl -fsS http://127.0.0.1:8100/status"
