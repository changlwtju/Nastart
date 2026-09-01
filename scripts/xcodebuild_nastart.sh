#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT_DIR/ios/Nastart/Nastart.xcworkspace"

find_xcode_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" && -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
    printf '%s\n' "$DEVELOPER_DIR"
    return 0
  fi

  local selected
  selected="$(xcode-select -p 2>/dev/null || true)"
  if [[ -n "$selected" && -x "$selected/usr/bin/xcodebuild" ]]; then
    printf '%s\n' "$selected"
    return 0
  fi

  local app
  for app in \
    "/Applications/Xcode.app" \
    "/Applications/Xcode-beta.app" \
    "$HOME/Downloads/Xcode.app" \
    "$HOME/Downloads/Xcode-beta.app"; do
    if [[ -x "$app/Contents/Developer/usr/bin/xcodebuild" ]]; then
      printf '%s\n' "$app/Contents/Developer"
      return 0
    fi
  done

  return 1
}

developer_dir="$(find_xcode_developer_dir)" || {
  echo "No full Xcode.app was found. Install Xcode or set DEVELOPER_DIR." >&2
  exit 1
}

export DEVELOPER_DIR="$developer_dir"
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
exec xcodebuild -workspace "$WORKSPACE" "$@"
