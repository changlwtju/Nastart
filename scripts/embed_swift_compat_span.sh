#!/bin/sh
set -eu

# Xcode 27 links this compatibility library from Nastart.debug.dylib, but its
# normal Swift embedding phase omits it. iOS 16 does not provide it in dyld.
if [ "${PLATFORM_NAME:-}" != iphoneos ]; then
    exit 0
fi

app_dir="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
binary="${app_dir}/${EXECUTABLE_NAME}.debug.dylib"
if [ ! -f "$binary" ]; then
    binary="${app_dir}/${EXECUTABLE_NAME}"
fi
if ! /usr/bin/otool -L "$binary" | /usr/bin/grep -q 'libswiftCompatibilitySpan.dylib'; then
    exit 0
fi

source_lib=''
swift_tool="$(/usr/bin/xcrun --find swift-stdlib-tool)"
swift_toolchain="$(cd "$(/usr/bin/dirname "$swift_tool")/../.." && /bin/pwd)"
for candidate in "${swift_toolchain}"/usr/lib/swift-*/iphoneos/libswiftCompatibilitySpan.dylib; do
    if [ -f "$candidate" ]; then
        source_lib="$candidate"
    fi
done
if [ -z "$source_lib" ]; then
    echo 'error: libswiftCompatibilitySpan.dylib was linked but not found in the Xcode toolchain' >&2
    exit 1
fi

destination="${app_dir}/Frameworks/libswiftCompatibilitySpan.dylib"
/bin/mkdir -p "${app_dir}/Frameworks"
/bin/cp "$source_lib" "$destination"
/bin/chmod u+w "$destination"
if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$destination"
fi
