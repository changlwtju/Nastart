#!/bin/zsh
# Install the persistent iPhone WDA fixture once. Later runs only validate it.
# This never builds WDA and never changes iPhone system settings.

set -euo pipefail

ROOT_DIR="${0:A:h}/.."
DEVICE_UDID="${DEVICE_UDID:-00008110-001E543122E0401E}"
WDA_BUNDLE="${WDA_BUNDLE:-com.changliwen.nastart.WebDriverAgentRunner.xctrunner}"
WDA_ARTIFACT_ROOT="${WDA_ARTIFACT_ROOT:-/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1}"
WDA_APP="${WDA_APP:-$WDA_ARTIFACT_ROOT/WebDriverAgentRunner-Runner.app}"
PROFILE="${PROFILE:-$WDA_APP/embedded.mobileprovision}"
RECEIPT="${WDA_INSTALL_RECEIPT:-$WDA_ARTIFACT_ROOT/install-receipt.txt}"
TIDEVICE_BIN="${TIDEVICE_BIN:-/Users/lagransun/Library/Python/3.9/bin/tidevice}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -x "$TIDEVICE_BIN" ]] || TIDEVICE_BIN="$(command -v tidevice || true)"
[[ -n "$TIDEVICE_BIN" ]] || die 'tidevice is required'
[[ -d "$WDA_APP" ]] || die "WDA fixture is missing: $WDA_APP"
[[ -f "$PROFILE" ]] || die "WDA provisioning profile is missing: $PROFILE"

WDA_ARTIFACT_ROOT="$WDA_ARTIFACT_ROOT" WDA_APP="$WDA_APP" PROFILE="$PROFILE" \
  DEVICE_UDID="$DEVICE_UDID" EXPECTED_RUNNER_BUNDLE="$WDA_BUNDLE" \
  "$ROOT_DIR/scripts/prepare_wda_recovery.sh" >/tmp/nastart-wda-iphone-preflight.txt

mkdir -p "$WDA_ARTIFACT_ROOT/runtime"
installed_info="$($TIDEVICE_BIN -u "$DEVICE_UDID" appinfo "$WDA_BUNDLE" 2>/dev/null || true)"
if [[ -n "$installed_info" ]] && print -r -- "$installed_info" | rg -q "'ProfileValidated': True"; then
  printf 'WDA already installed and ProfileValidated=true; no reinstall performed.\n'
else
  # The profile is already trusted on this device. Install it only when the
  # app is absent or invalid; this is an app/profile operation, not a system
  # update or reboot.
  ideviceprovision -u "$DEVICE_UDID" install "$PROFILE"
  "$TIDEVICE_BIN" -u "$DEVICE_UDID" install "$WDA_APP"
fi

runner_sha256="$(shasum -a 256 "$WDA_APP/WebDriverAgentRunner-Runner" | awk '{print $1}')"
profile_sha256="$(shasum -a 256 "$PROFILE" | awk '{print $1}')"
if [[ ! -f "$RECEIPT" || "${FORCE_WDA_RECEIPT:-0}" == '1' ]]; then
  apply_patch <<PATCH
*** Begin Patch
*** Add File: $RECEIPT
+installed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
+device_udid=$DEVICE_UDID
+runner_bundle=$WDA_BUNDLE
+runner_sha256=$runner_sha256
+profile_sha256=$profile_sha256
+artifact_root=$WDA_ARTIFACT_ROOT
+install_method=tidevice-or-existing-validated-install
+system_changes=none
*** End Patch
PATCH
fi

printf 'WDA fixture installed/validated. Receipt: %s\n' "$RECEIPT"
