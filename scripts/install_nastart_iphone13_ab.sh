#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_UDID="${DEVICE_UDID:-00008110-001E543122E0401E}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/NastartGreenfieldABiPhone13Derived}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/Nastart.app"

command -v ios-deploy >/dev/null 2>&1 || {
  echo "ios-deploy is required to install on the connected iPhone." >&2
  exit 1
}

"$ROOT_DIR/scripts/xcodebuild_nastart.sh" \
  -scheme Nastart \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

ios-deploy --id "$DEVICE_UDID" --bundle "$APP_PATH"

printf 'Installed Nastart Debug A/B build to %s\n' "$DEVICE_UDID"
printf 'App bundle: %s\n' "$APP_PATH"
