# iPhone 13 Greenfield A/B Install

Date: 2026-09-02

## Device

- Device: iPhone 13
- iOS: 16.3.1 (20D67)
- UDID: `00008110-001E543122E0401E`
- USB status: `ios-deploy -c` found the device.

## Build

- Command:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug \
  -destination 'platform=iOS,id=00008110-001E543122E0401E' \
  -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived build
```

- Result: `BUILD SUCCEEDED`
- App bundle:

```text
/tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
```

- Bundle ID: `com.changliwen.nastart`
- Marketing version: `0.1.0`
- Signing: Apple Development team `5436TB5498`
- Approximate app bundle size after KSPlayer/FFmpegKit link: `120M`

## Install

- Command:

```bash
ios-deploy --id 00008110-001E543122E0401E \
  --bundle /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
```

- Result: `InstallComplete`
- Installed app check:

```bash
ios-deploy --id 00008110-001E543122E0401E --exists -1 com.changliwen.nastart
```

- Result: `true`

## A/B Switch Coverage

This Debug build includes `debug.playback.use_greenfield_player`.

The switch is available in:

- Jellyfin media detail playback.
- DSM device file preview for video/audio items.
- Direct URL / Web media launch path.

Expected behavior:

- Switch off: existing `BuiltInMediaPlayerView` path.
- Switch on: `GreenfieldVideoPlayerView` path.
- Current greenfield renderer links the real KSPlayer SwiftPM product. When a plan selects `ksPlayer`, the Debug badge should show the KSPlayer renderer instead of the AVPlayer fallback.

## Notes

- Global `xcode-select` may still point to `/Library/Developer/CommandLineTools`. The repository wrapper uses `/Users/lagransun/Downloads/Xcode.app/Contents/Developer` when available.
- To switch globally, run locally in Terminal and enter the macOS admin password:

```bash
sudo xcode-select -s ~/Downloads/Xcode.app/Contents/Developer
```

- Xcode 26/CoreDevice still reports the known old-device warning for this iPhone 13 / iOS 16.3.1 pair. `ios-deploy` remains the reliable install path.
- KSPlayer pulls FFmpegKit and a Metal shader bundle. The first device build failed until the full Xcode Metal Toolchain component was installed with:

```bash
/Users/lagransun/Downloads/Xcode.app/Contents/Developer/usr/bin/xcodebuild -downloadComponent MetalToolchain
```

## 2026-09-02 Follow-up

- Rebuilt and reinstalled the Debug app after the Jellyfin playback A/B presentation fix.
- Added the missing `GreenfieldVideoPlayerView` full-screen presentation for `JellyfinMediaDetailView`.
- Reduced Jellyfin library entry work by passing deduplicated DSM shared-folder root paths instead of recomputing a larger folder path context.
- A short `idevicesyslog -p Nastart` capture while the app was running showed network deactivation/retransmit activity around service ports including `8096` and local proxy `127.0.0.1:1082`; no crash stack was observed in that sample.

## 2026-09-02 Jellyfin Web Freeze Follow-up

- User retest clarified that qBittorrent `App 内打开` succeeds, while Jellyfin `App 内打开` still freezes.
- Pulled device diagnostics showed qBittorrent on `https://lag...un.cn:8081` used `desktop=off` and completed a rendered login-form probe.
- The Jellyfin Web entry on `https://lag...un.cn:18444` used `desktop=on`, committed and completed navigation, then had no render-check entry in the captured preference log.
- Updated service profiling so Jellyfin detection considers name, subtitle/image, detail, endpoint, alternate endpoint, and common mapped ports `8096`/`8920`.
- Media/Jellyfin Web entries now force mobile Web content mode; Jellyfin also allows the compatibility in-app browser fallback if WKWebView renders blank.
- Web diagnostics now include `profile=<default|media|jellyfin|developer|metacube>` alongside the `desktop` flag.
- Added unit coverage for Jellyfin name/port detection and qBittorrent staying on the default profile.
- Verification:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
# TEST SUCCEEDED

scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug \
  -destination 'platform=iOS,id=00008110-001E543122E0401E' \
  -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived build
# BUILD SUCCEEDED

ios-deploy --id 00008110-001E543122E0401E \
  --bundle /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
# InstallComplete
```

## 2026-09-02 KSPlayer + Jellyfin Browser Follow-up

- Added the KSPlayer SwiftPM dependency to the Nastart app target and linked the `KSPlayer` product.
- Resolved and pinned:
  - `KSPlayer` `2.3.4`
  - `FFmpegKit` `6.1.4`
- Updated the greenfield renderer availability check so tests verify that KSPlayer is linked in the current build.
- Switched Jellyfin `App 内打开` from the custom `WKWebView` container to an in-app `SFSafariViewController` path. This keeps qBittorrent and other Docker Web entries on the existing Web container while isolating Jellyfin from the WKWebView freeze path seen on device.
- `SFSafariViewController` emits `diagnostics.web.started`, `diagnostics.web.completed`, and `diagnostics.web.closed` with `engine=SFSafariViewController`.
- Verification:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -onlyUsePackageVersionsFromResolvedFile test
# TEST SUCCEEDED

scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug \
  -destination 'platform=iOS,id=00008110-001E543122E0401E' \
  -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived \
  -onlyUsePackageVersionsFromResolvedFile build
# BUILD SUCCEEDED

ios-deploy --id 00008110-001E543122E0401E \
  --bundle /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
# InstallComplete

ios-deploy --id 00008110-001E543122E0401E --exists --bundle_id com.changliwen.nastart
# true
```

## 2026-09-02 Exported Diagnostics Follow-up

- Read the exported app diagnostics at `/Users/lagransun/Downloads/文本-32AEC09D0BCA-1.txt`; treated the file as diagnostic evidence only.
- The log shows two separate greenfield playback failure stages:
  - Before KSPlayer was linked, DSM file playback selected `decodeEngine=ksPlayer` but failed with `stage=ksPlayerNotLinked`.
  - After KSPlayer was linked, DSM file playback selected `decodeEngine=ksPlayer`, reported `ksPlayerLinked=true`, then produced no `first_frame` event and returned quickly. This suggests the remaining failure is in actual renderer startup/state handling, not dependency resolution.
- Replaced the greenfield KSPlayer path from the high-level `KSVideoPlayerView` wrapper to lower-level `KSVideoPlayer`, wired state/play/buffer/finish callbacks into Nastart diagnostics, and forced the first KSPlayer engine to `KSMEPlayer` with `KSAVPlayer` as fallback.
- Added Jellyfin mapped ports `8097` and `18444` to service detection. The exported logs show real Jellyfin access through both ports, while older Jellyfin Web entries lacked a `profile=jellyfin` marker.
- Added entry-point diagnostics for Jellyfin media library presentation and App-internal Web presentation so the next exported log can distinguish “button tap did not route” from “route presented but downstream view froze”.
- Rebuilt and reinstalled the Debug app to the connected iPhone 13:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug \
  -destination 'platform=iOS,id=00008110-001E543122E0401E' \
  -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived \
  -onlyUsePackageVersionsFromResolvedFile build
# BUILD SUCCEEDED

ios-deploy --id 00008110-001E543122E0401E \
  --bundle /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
# InstallComplete

ios-deploy --id 00008110-001E543122E0401E --exists --bundle_id com.changliwen.nastart
# true
```

- Verification:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/NastartGreenfieldABSimulatorDerived \
  -onlyUsePackageVersionsFromResolvedFile test
# TEST SUCCEEDED

git diff --check
# clean
```

## 2026-09-02 Retest Failure Follow-up

- User retested the installed build and reported:
  - Jellyfin still freezes.
  - DSM file playback with the Greenfield player still fails.
- The new diagnostics confirmed KSPlayer is now linked and receiving callbacks:
  - `state=preparing`
  - `state=initialized`
  - `state=error`
  - failure: `ksPlayerFinished:AVFoundationErrorDomain:-11828`
- DSM file playback was still entering the Greenfield path with `transport=https` and `routeKind=directHTTP` for `https://lag...un.cn:5001`. This bypassed the existing authenticated local Range proxy on public-domain DSM routes.
- Updated DSM media playback so DEBUG Greenfield video requests always pre-register the authenticated local Range proxy before presenting KSPlayer. The next diagnostic for this path should show:
  - `greenfield=on`
  - `transport=localRangeProxy`
  - `routeKind=localRangeProxy`
- Updated Jellyfin `App 内打开` again: services that use the system in-app browser now open through a button-driven full-screen `SFSafariViewController` presentation instead of pushing the Safari controller inside a `NavigationLink` destination.
- Added route-request diagnostics before Web and media-library navigation so the next log can distinguish tap/routing failures from downstream view freezes:
  - `diagnostics.web.route_requested`
  - `diagnostics.jellyfin.library_route_requested`
- Verification:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug \
  -destination 'platform=iOS,id=00008110-001E543122E0401E' \
  -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived \
  -onlyUsePackageVersionsFromResolvedFile build
# BUILD SUCCEEDED

ios-deploy --id 00008110-001E543122E0401E \
  --bundle /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
# InstallComplete

ios-deploy --id 00008110-001E543122E0401E --exists --bundle_id com.changliwen.nastart
# true

scripts/xcodebuild_nastart.sh -scheme Nastart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/NastartGreenfieldABSimulatorDerived \
  -onlyUsePackageVersionsFromResolvedFile test
# TEST SUCCEEDED

git diff --check
# clean
```

## 2026-09-02 Crash Guard and Library Routing Follow-up

- User retested on the connected iPhone 13 and reported:
  - DSM device-file playback crashes the app when the DEBUG Greenfield player is enabled.
  - Jellyfin `App 内打开` now opens normally.
  - Jellyfin media library still freezes.
- Pulled device crash reports with `idevicecrashreport`. The DSM playback crash is not a catchable player error in Nastart UI code:
  - Crash reports: `/tmp/nastart_crashes/Nastart-2026-09-02-071744.ips`, `/tmp/nastart_crashes/Nastart-2026-09-02-071757.ips`, `/tmp/nastart_crashes/Nastart-2026-09-02-071825.ips`
  - Main playback crash signature: `EXC_BREAKPOINT / SIGTRAP`
  - Faulting thread: `KSPlayer_MEPlayerItem_open`
  - Stack includes `FFmpegAssetTrack.__allocating_init(stream:)`, `MEPlayerItem.createCodec(formatCtx:)`, `MEPlayerItem.openThread()`, `MEPlayerItem.prepareToPlay()`
  - This points to an internal KSPlayer/FFmpeg stream-track assertion for the current DSM MKV/local proxy path.
- Added a DEBUG crash guard for DSM device-file Greenfield playback:
  - Extensions currently guarded: `mkv`, `m2ts`, `mts`, `ts`, `avi`, `wmv`, `flv`, `rmvb`
  - Guarded files record `diagnostics.playback.next.ksplayer_guarded`.
  - Guarded files fall back to the existing compatibility player instead of entering the KSPlayer crash path.
  - MP4 and other unguarded formats can still exercise the Greenfield/KSPlayer route.
- Converted the media-library action in `ServiceDetailView` from a `NavigationLink` to button-driven full-screen presentation:
  - The tap now records `diagnostics.jellyfin.library_route_requested` before `MediaLibraryView` is constructed.
  - The library view is presented in an isolated `NavigationStack` with an explicit close button.
  - This should make the next exported diagnostic log distinguish route/tap failures from downstream Jellyfin library initialization freezes.
- Rebuilt and reinstalled the Debug app to the connected iPhone 13:

```bash
scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug \
  -destination 'platform=iOS,id=00008110-001E543122E0401E' \
  -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived \
  -onlyUsePackageVersionsFromResolvedFile build
# BUILD SUCCEEDED

ios-deploy --id 00008110-001E543122E0401E \
  --bundle /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
# InstallComplete

ios-deploy --id 00008110-001E543122E0401E --exists --bundle_id com.changliwen.nastart
# true

git diff --check
# clean
```
