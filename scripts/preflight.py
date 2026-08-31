#!/usr/bin/env python3
"""Local static checks for the Nastart iOS prototype.

This script intentionally avoids Xcode-only tooling so it can run on the NAS
workspace. It is not a Swift compiler; it catches the common issues that have
already cost us time during device builds.
"""

from __future__ import annotations

import json
import plistlib
import re
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "Nastart" / "Nastart"
PROJECT_FILE = ROOT / "ios" / "Nastart" / "Nastart.xcodeproj" / "project.pbxproj"
PODFILE = ROOT / "ios" / "Nastart" / "Podfile"
PODFILE_LOCK = ROOT / "ios" / "Nastart" / "Podfile.lock"
THIRD_PARTY_NOTICES = ROOT / "ios" / "Nastart" / "THIRD_PARTY_NOTICES.md"
APP_ICON_CONTENTS = IOS_ROOT / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json"
LOCALIZATION_FILES = {
    "en": IOS_ROOT / "en.lproj" / "Localizable.strings",
    "zh-Hans": IOS_ROOT / "zh-Hans.lproj" / "Localizable.strings",
}
LAUNCHPAD_VIEW = IOS_ROOT / "Features" / "Launchpad" / "LaunchpadView.swift"
DEVICES_VIEW = IOS_ROOT / "Features" / "Devices" / "DevicesView.swift"
INFO_PLIST = IOS_ROOT / "Info.plist"
APP_ENTRY = IOS_ROOT / "App" / "NastartApp.swift"
NAS_MODELS = IOS_ROOT / "Core" / "Models" / "NASModels.swift"
APP_STATE_STORES = IOS_ROOT / "Core" / "Stores" / "AppStateStores.swift"
DSM_CLIENT = IOS_ROOT / "Core" / "Stores" / "DSMClient.swift"
DIAGNOSTIC_STORE = IOS_ROOT / "Core" / "Stores" / "DiagnosticLogStore.swift"
LOCAL_TASK_STORE = IOS_ROOT / "Core" / "Stores" / "LocalTaskStore.swift"
NETWORK_ERROR_CLASSIFICATION = IOS_ROOT / "Core" / "Stores" / "NetworkErrorClassification.swift"


@dataclass
class CheckResult:
    name: str
    errors: list[str]
    warnings: list[str]

    @property
    def ok(self) -> bool:
        return not self.errors


def run_command(name: str, command: list[str]) -> CheckResult:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if completed.returncode == 0:
        return CheckResult(name, [], [])
    output = completed.stdout.strip() or f"{' '.join(command)} failed"
    return CheckResult(name, [output], [])


def swift_files() -> list[Path]:
    return sorted(IOS_ROOT.rglob("*.swift"))


def strip_swift_comments_and_strings(source: str) -> str:
    output: list[str] = []
    i = 0
    state = "code"
    block_depth = 0

    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if state == "code":
            if ch == "/" and nxt == "/":
                state = "line_comment"
                output.append(" ")
                i += 2
                continue
            if ch == "/" and nxt == "*":
                state = "block_comment"
                block_depth = 1
                output.append(" ")
                i += 2
                continue
            if ch == '"':
                state = "string"
                output.append('"')
                i += 1
                continue
            output.append(ch)
            i += 1
            continue

        if state == "line_comment":
            output.append("\n" if ch == "\n" else " ")
            if ch == "\n":
                state = "code"
            i += 1
            continue

        if state == "block_comment":
            output.append("\n" if ch == "\n" else " ")
            if ch == "/" and nxt == "*":
                block_depth += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_depth -= 1
                i += 2
                if block_depth == 0:
                    state = "code"
                continue
            i += 1
            continue

        if state == "string":
            output.append(" " if ch != "\n" else "\n")
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                state = "code"
                output.append('"')
            i += 1

    return "".join(output)


def check_swift_balanced_delimiters() -> CheckResult:
    errors: list[str] = []
    pairs = {"{": "}", "(": ")", "[": "]"}
    closing = {v: k for k, v in pairs.items()}

    for path in swift_files():
        source = strip_swift_comments_and_strings(path.read_text(encoding="utf-8"))
        stack: list[tuple[str, int]] = []
        line = 1
        for ch in source:
            if ch == "\n":
                line += 1
                continue
            if ch in pairs:
                stack.append((ch, line))
            elif ch in closing:
                if not stack or stack[-1][0] != closing[ch]:
                    rel = path.relative_to(ROOT)
                    errors.append(f"{rel}:{line}: unexpected '{ch}'")
                else:
                    stack.pop()
        if stack:
            rel = path.relative_to(ROOT)
            opener, opener_line = stack[-1]
            errors.append(f"{rel}:{opener_line}: unclosed '{opener}'")

    return CheckResult("Swift delimiter balance", errors, [])


def check_ios16_static_patterns() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []
    blocked_patterns = [
        (re.compile(r"\.buttonBorderShape\(\s*\.circle\s*\)"), "Use an iOS 16-safe shape, not .buttonBorderShape(.circle)."),
        (re.compile(r"\bSection\(\s*\""), "Use Section { ... } header: { Text(...) } to avoid SwiftUI overload issues."),
        (re.compile(r"@Observable\b"), "Observation/@Observable is iOS 17-era; keep the iOS 16 target safe."),
        (re.compile(r"\.sensoryFeedback\s*\("), ".sensoryFeedback is iOS 17+."),
        (re.compile(r"\.symbolEffect\s*\("), ".symbolEffect is iOS 17+."),
        (re.compile(r"\.contentMargins\s*\("), ".contentMargins is iOS 17+."),
        (re.compile(r"\.containerBackground\s*\("), ".containerBackground is iOS 17+."),
    ]
    warn_patterns = [
        (re.compile(r"#Preview\b"), "#Preview requires newer Xcode tooling; Xcode 14 users may need PreviewProvider."),
    ]

    for path in swift_files():
        source = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(source.splitlines(), start=1):
            for pattern, message in blocked_patterns:
                if pattern.search(line):
                    rel = path.relative_to(ROOT)
                    errors.append(f"{rel}:{line_number}: {message}")
            for pattern, message in warn_patterns:
                if pattern.search(line):
                    rel = path.relative_to(ROOT)
                    warnings.append(f"{rel}:{line_number}: {message}")

    return CheckResult("iOS 16 static API guard", errors, warnings)


def parse_localizable(path: Path) -> tuple[dict[str, str], list[str]]:
    key_values: dict[str, str] = {}
    errors: list[str] = []
    key_pattern = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$')

    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        match = key_pattern.match(line)
        if not match:
            errors.append(f"{path.relative_to(ROOT)}:{line_number}: invalid .strings entry")
            continue
        key, value = match.groups()
        if key in key_values:
            errors.append(f"{path.relative_to(ROOT)}:{line_number}: duplicate key '{key}'")
        key_values[key] = value

    return key_values, errors


def check_localizations() -> CheckResult:
    errors: list[str] = []
    parsed: dict[str, dict[str, str]] = {}

    for locale, path in LOCALIZATION_FILES.items():
        if not path.exists():
            errors.append(f"Missing localization file: {path.relative_to(ROOT)}")
            continue
        parsed[locale], locale_errors = parse_localizable(path)
        errors.extend(locale_errors)

    if len(parsed) == len(LOCALIZATION_FILES):
        all_keys = set().union(*(values.keys() for values in parsed.values()))
        for locale, values in parsed.items():
            missing = sorted(all_keys - set(values.keys()))
            if missing:
                preview = ", ".join(missing[:10])
                suffix = "" if len(missing) <= 10 else f" ... +{len(missing) - 10}"
                errors.append(f"{locale} missing {len(missing)} localization keys: {preview}{suffix}")

    return CheckResult("Localization parity", errors, [])


def check_localization_references() -> CheckResult:
    errors: list[str] = []
    defined_keys: set[str] = set()
    for path in LOCALIZATION_FILES.values():
        if path.exists():
            values, _ = parse_localizable(path)
            defined_keys.update(values)

    call_patterns = [
        re.compile(
            r'\b(?:Text|Label|Button|TextField|SecureField|Toggle|Picker|LabeledContent)'
            r'\(\s*"((?:\\.|[^"\\])*)"'
        ),
        re.compile(r'\.(?:navigationTitle|alert|confirmationDialog)\(\s*"((?:\\.|[^"\\])*)"'),
        re.compile(r'\bNSLocalizedString\(\s*"((?:\\.|[^"\\])*)"'),
    ]

    for path in swift_files():
        source = path.read_text(encoding="utf-8")
        for pattern in call_patterns:
            for match in pattern.finditer(source):
                key = match.group(1)
                if "\\(" in key or "." not in key or key in defined_keys:
                    continue
                line = source.count("\n", 0, match.start()) + 1
                errors.append(f"{path.relative_to(ROOT)}:{line}: undefined localization key '{key}'")

    return CheckResult("Localization references", sorted(set(errors)), [])


def parse_size(size: str, scale: str) -> tuple[int, int]:
    width, height = [float(part) for part in size.split("x")]
    scale_number = int(scale.rstrip("x"))
    return round(width * scale_number), round(height * scale_number)


def png_dimensions(path: Path) -> tuple[int, int, int] | None:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


def check_app_icon_asset() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []

    if not APP_ICON_CONTENTS.exists():
        return CheckResult("AppIcon asset", [f"Missing {APP_ICON_CONTENTS.relative_to(ROOT)}"], [])

    contents = json.loads(APP_ICON_CONTENTS.read_text(encoding="utf-8"))
    images = contents.get("images", [])
    seen_filenames: set[str] = set()
    for image in images:
        filename = image.get("filename")
        size = image.get("size")
        scale = image.get("scale")
        idiom = image.get("idiom")
        if not filename:
            errors.append(f"AppIcon entry for {idiom} {size}@{scale} has no filename")
            continue
        seen_filenames.add(filename)
        icon_path = APP_ICON_CONTENTS.parent / filename
        if not icon_path.exists():
            errors.append(f"Missing app icon file: {icon_path.relative_to(ROOT)}")
            continue
        dimensions = png_dimensions(icon_path)
        if dimensions is None:
            errors.append(f"{icon_path.relative_to(ROOT)} is not a valid PNG")
            continue
        width, height, color_type = dimensions
        expected_width, expected_height = parse_size(size, scale)
        if (width, height) != (expected_width, expected_height):
            errors.append(
                f"{icon_path.relative_to(ROOT)} is {width}x{height}, expected {expected_width}x{expected_height}"
            )
        if color_type in {4, 6}:
            warnings.append(f"{icon_path.relative_to(ROOT)} appears to contain an alpha channel")

    pngs = {path.name for path in APP_ICON_CONTENTS.parent.glob("*.png")}
    unreferenced = sorted(pngs - seen_filenames)
    if unreferenced:
        warnings.append("Unreferenced AppIcon PNGs: " + ", ".join(unreferenced))

    return CheckResult("AppIcon asset", errors, warnings)


def check_project_settings() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []

    if not PROJECT_FILE.exists():
        return CheckResult("Xcode project settings", [f"Missing {PROJECT_FILE.relative_to(ROOT)}"], [])

    text = PROJECT_FILE.read_text(encoding="utf-8")
    deployment_targets = sorted(set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", text)))
    if not deployment_targets:
        errors.append("IPHONEOS_DEPLOYMENT_TARGET is not set")
    elif deployment_targets != ["16.0"]:
        errors.append(f"Expected iOS deployment target 16.0, found: {', '.join(deployment_targets)}")

    if "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" not in text:
        errors.append("AppIcon asset catalog is not assigned to the target")

    test_file = ROOT / "ios" / "Nastart" / "NastartTests" / "NonPlaybackPolicyTests.swift"
    required_test_fragments = {
        "Swift unit-test target is missing": "productType = \"com.apple.product-type.bundle.unit-test\";",
        "Swift unit tests must depend on the app target": "TestTargetID = 060606060606060606060001;",
        "Swift unit-test source is not included": "NonPlaybackPolicyTests.swift in Sources",
        "Swift unit tests must link XCTest": "XCTest.framework in Frameworks",
    }
    for message, fragment in required_test_fragments.items():
        if fragment not in text:
            errors.append(message)
    if not test_file.exists():
        errors.append(f"Missing {test_file.relative_to(ROOT)}")

    for filename in (
        "DSMClient.swift",
        "LANDiscoveryService.swift",
        "ManualLaunchpadServiceStore.swift",
        "ServiceHealthProbe.swift",
        "DiagnosticLogStore.swift",
        "LocalTaskStore.swift",
        "NASConnectionStore.swift",
        "KeychainStore.swift",
        "NetworkErrorClassification.swift",
    ):
        source_path = IOS_ROOT / "Core" / "Stores" / filename
        if not source_path.exists():
            errors.append(f"Missing {source_path.relative_to(ROOT)}")
        if f"{filename} in Sources" not in text:
            errors.append(f"{filename} is not included in the Xcode Sources phase")

    swift_versions = sorted(set(re.findall(r"SWIFT_VERSION = ([0-9.]+);", text)))
    if not swift_versions:
        warnings.append("SWIFT_VERSION is not set")

    if 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG NASTART_NO_ICLOUD";' not in text:
        errors.append("Debug builds without CloudKit entitlements must define NASTART_NO_ICLOUD")

    script_sandboxing = re.findall(r"ENABLE_USER_SCRIPT_SANDBOXING = (YES|NO);", text)
    if "YES" in script_sandboxing:
        errors.append("User script sandboxing must be disabled for CocoaPods to embed MobileVLCKit")
    elif script_sandboxing.count("NO") < 2:
        errors.append("User script sandboxing must be disabled in Debug and Release configurations")

    vlc_version = "3.7.3"
    dependency_files = {
        "Podfile": PODFILE,
        "Podfile.lock": PODFILE_LOCK,
        "THIRD_PARTY_NOTICES.md": THIRD_PARTY_NOTICES,
    }
    for label, path in dependency_files.items():
        contents = path.read_text(encoding="utf-8") if path.exists() else ""
        if "MobileVLCKit" not in contents or vlc_version not in contents:
            errors.append(f"{label} must pin MobileVLCKit {vlc_version}")

    return CheckResult("Xcode project settings", errors, warnings)


def check_transport_security_configuration() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []
    if not INFO_PLIST.exists():
        return CheckResult("Transport security configuration", [f"Missing {INFO_PLIST.relative_to(ROOT)}"], [])

    try:
        plist = plistlib.loads(INFO_PLIST.read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        return CheckResult("Transport security configuration", [f"Could not parse Info.plist: {error}"], [])

    ats = plist.get("NSAppTransportSecurity", {})
    if not isinstance(ats, dict):
        return CheckResult("Transport security configuration", ["NSAppTransportSecurity must be a dictionary"], [])
    if ats.get("NSAllowsArbitraryLoads") is True:
        errors.append("ATS must not allow arbitrary network loads")
    if ats.get("NSAllowsArbitraryLoadsInWebContent") is True:
        errors.append("Web content must not bypass ATS globally")
    if ats.get("NSAllowsLocalNetworking") is not True:
        warnings.append("Local networking ATS exception is not declared")
    return CheckResult("Transport security configuration", errors, warnings)


def check_playback_routing_invariants() -> CheckResult:
    errors: list[str] = []
    launchpad = LAUNCHPAD_VIEW.read_text(encoding="utf-8")
    devices = DEVICES_VIEW.read_text(encoding="utf-8")
    app_entry = APP_ENTRY.read_text(encoding="utf-8")
    nas_models = NAS_MODELS.read_text(encoding="utf-8")
    stores = APP_STATE_STORES.read_text(encoding="utf-8")
    dsm_client = DSM_CLIENT.read_text(encoding="utf-8") if DSM_CLIENT.exists() else ""
    diagnostic_store = DIAGNOSTIC_STORE.read_text(encoding="utf-8") if DIAGNOSTIC_STORE.exists() else ""
    local_task_store = LOCAL_TASK_STORE.read_text(encoding="utf-8") if LOCAL_TASK_STORE.exists() else ""
    store_sources = "\n".join((stores, dsm_client, diagnostic_store, local_task_store))

    required_launchpad_fragments = {
        "Media probes must stream bounded data instead of buffering full media responses": (
            "let (bytes, response) = try await session.bytes(for: request)"
        ),
        "Jellyfin and DSM must expose one compatibility-backed player strategy": (
            "if request.source == .jellyfin || request.source == .dsmFile { return true }"
        ),
        "Playback must retain the last real-device validated VLC cache window": (
            "return isPrivateRoute ? 900 : 1_500"
        ),
        "Finite media playback must retain VLC HTTP file semantics": (
            '"httpMode": "file"'
        ),
        "Direct playback must not be restarted by the HLS stall fallback": (
            "guard request.fileExtensionHint == \"m3u8\", hasAlternateTransport else { return }"
        ),
        "VLC time callbacks must be coalesced before publishing SwiftUI state": (
            "minimumTimeStateSyncInterval: TimeInterval = 0.25"
        ),
        "Playback jump controls must not retain the old 180ms input delay": (
            "deadline: .now() + 0.06"
        ),
        "Finite MPEG-TS Range playback must retain the fast avformat demux path": (
            'if usesAVFormatDemux {\n            media.addOption(":demux=avformat")'
        ),
        "VLC video output must not observe and rebind on every player update": (
            "private struct VLCPlayerSurface: UIViewRepresentable {\n    let session: VLCMediaPlayerSession"
        ),
        "Automatic compatibility recovery must be bounded to two attempts": (
            "compatibilityFallbackAttemptCount < 2"
        ),
        "Jellyfin resume must wait until VLC has opened the input": (
            "let inputIsReadyForInitialSeek = isPlaying\n            || player.state == .esAdded"
        ),
        "Jellyfin original playback must use the proven DSM stall tolerance": (
            "return isPrivateHost ? 18 : 30\n        case .dsmFile:"
        ),
        "System-compatible Jellyfin streams must expose native Picture in Picture": (
            '|| request.source == .jellyfin'
        ),
        "Jellyfin playback must always submit a VLC device profile": (
            "deviceProfile: Self.vlcPlaybackProfile(maxBitrate: maxStreamingBitrate)"
        ),
        "Jellyfin playback negotiation must make direct play an explicit policy": (
            "enableDirectPlay: allowsDirectPlay"
        ),
        "Jellyfin compatibility HLS must not create unstable copied-video transcoded-audio streams": (
            "allowVideoStreamCopy: false"
        ),
        "Jellyfin automatic playback must resolve the preferred original route": (
            "preferredOriginalPlaybackRoute(for: entry, client: client)"
        ),
        "Jellyfin automatic playback must use an adaptive route policy": (
            '"defaultMode": "adaptiveAuto"'
        ),
        "Jellyfin original playback must prefer the server static Range endpoint": (
            'diagnosticStage: "jellyfinRange"'
        ),
        "Jellyfin original playback must retain DSM FileStation as a fallback": (
            'diagnosticStage: "jellyfinDSMRange"'
        ),
        "Jellyfin DSM playback must derive FileStation paths from Jellyfin metadata": (
            "dsmFileStationPathCandidates("
        ),
        "Containerized Jellyfin paths must be mapped against DSM shared folders": (
            "dsmSharedFolderPaths: dataStore.files"
        ),
        "Jellyfin DSM path candidates must be verified against the source file size": (
            "expectedContentLength: entry.mediaSize"
        ),
        "Jellyfin playback must retain HLS as a final compatibility fallback": (
            "prepared = try await negotiatedVideoPlayback("
        ),
        "Jellyfin and DSM must share the authenticated Range route validator": (
            "AuthenticatedMediaPlaybackResolver.firstPlayableURL("
        ),
        "Jellyfin original streams must be Range-validated before playback": (
            'diagnosticStage: "jellyfinRange"'
        ),
        "Jellyfin direct play must not inherit the WAN transcode bitrate cap": (
            "maxStaticBitrate: 360_000_000"
        ),
        "VLC-compatible image subtitles must remain embedded for direct play": (
            "imageSubtitles.map {\n                SubtitleProfile(format: $0, method: .embed)"
        ),
        "The Jellyfin bitrate downshift must disable direct play": (
            "allowsDirectPlay: false"
        ),
        "Jellyfin must measure and cache WAN bitrate": (
            "Paths.getBitrateTestBytes(size: testSize)"
        ),
        "Jellyfin playback must start without waiting for a bitrate probe": (
            "scheduleBitrateMeasurementIfNeeded(client: client)"
        ),
        "Jellyfin bitrate probes must be deduplicated in the background": (
            "bitrateMeasurementTasks[cacheKey] = Task"
        ),
        "Jellyfin bitrate cache must be isolated by active network class": (
            'let cacheKey = "\\(originKey)|\\(network.cacheKey)"'
        ),
        "Constrained networks must have a conservative bitrate cap": (
            'cacheKey: "constrained",\n                    bitrateCap: 6_000_000'
        ),
        "Cellular HLS startup must use a weak-network fallback": (
            'cacheKey: "cellular",\n                    bitrateCap: path.isExpensive ? 12_000_000 : 16_000_000,\n                    fallbackBitrate: 2_000_000'
        ),
        "Remote Jellyfin playback must expose a complete-request bitrate downshift": (
            "compatibilityFallbackRequestLoader: compatibilityFallbackRequestLoader"
        ),
        "Remote automatic Jellyfin HLS must use the fast-start transcoding ceiling": (
            ": min(directPlayBudget, 20_000_000)"
        ),
        "A bitrate downshift must renegotiate through PlaybackInfo": (
            "adaptiveFallbackRequest("
        ),
        "A bitrate downshift must preserve the requested server bitrate": (
            "forcedServerBitrate: fallbackBitrate"
        ),
        "A bitrate downshift must preserve the absolute playback time": (
            "forcedStartTimeTicks: startTimeTicks"
        ),
        "The player must distinguish a stalled clock from an unopened input": (
            'player.isPlaying ? "playbackClockTimeout" : "loadTimeout"'
        ),
        "An ended HLS input must not receive grace solely because it once exposed tracks": (
            'let hasActiveInput = player.isPlaying\n            || state.contains("elementarystreamadded")'
        ),
        "A playlist that ends before its first frame must fall back immediately": (
            'fail(reason: "prematureEndBeforeFirstFrame")'
        ),
        "A rendered VLC video frame must dismiss the initial loading indicator": (
            "let hasVideoOutput = player.hasVideoOut"
        ),
        "Jellyfin external handoff must use the negotiated resource": (
            "externalHandoffResource: prepared.externalHandoffResource"
        ),
        "Jellyfin direct play must keep the validated upstream URL for handoff": (
            "url: directRoute.handoffURL,\n                    fileExtensionOverride: extensionHint,\n                    subtitleURL: directSubtitleSourceURL"
        ),
        "Jellyfin remote direct play must use a loopback Range proxy in-app": (
            'url: directURL,\n                    fileExtensionOverride: extensionHint'
        ),
        "Jellyfin direct play must normalize text subtitles before VLC renders them": (
            "subtitleURL: directSubtitleURL"
        ),
        "Jellyfin negotiated direct play must reuse its normalized subtitle resource": (
            "subtitleURL: externalHandoffResource.subtitleURL"
        ),
        "Jellyfin playback resources must retain route-specific certificate trust": (
            "allowsSelfSignedCertificates: directRoute.allowsSelfSignedCertificates"
        ),
        "Jellyfin HLS and external players must retain the server URL": (
            "externalHandoffResource: externalHandoffResource"
        ),
        "Playback diagnostics must report the upstream instead of localhost": (
            "DiagnosticLogStore.redactedURL(playback.networkOriginURL)"
        ),
        "Jellyfin HLS must wait for the same two-segment startup window as Swiftfin": (
            "minSegments: 2"
        ),
        "Jellyfin compatibility HLS must avoid unstable HEVC video-copy plus audio-transcode streams": (
            'type: .video,\n                    videoCodec: "h264"'
        ),
        "Jellyfin compatibility HLS must preserve multichannel audio layout": (
            'maxAudioChannels: "8"'
        ),
        "HLS must support keyframe-independent segment boundaries": (
            "isBreakOnNonKeyFrames: true"
        ),
        "Playback diagnostics must measure tap-to-first-frame": "tapToFirstFrameMs",
        "Playback diagnostics must measure seek recovery": "recoveryMs",
        "Seek diagnostics must wait for the requested timeline region": (
            "abs(currentSeconds - $0) <= 1.5"
        ),
        "Paused compatibility playback must not trigger reconnect": "player.state != .paused",
        "HLS that stops during opening must fail over without waiting for the load timeout": (
            'previousState.contains("opening")\n                || previousState.contains("buffering")'
        ),
        "Compatibility caching must classify the upstream rather than localhost proxy": (
            "request.isPrivateNetworkRoute"
        ),
        "Infuse callback must use its documented play action": (
            'scheme: "infuse",\n                action: "play"'
        ),
        "VidHub callback must use its documented play action": (
            'scheme: "open-vidhub",\n                action: "play"'
        ),
        "Supported external players must receive completion callbacks": (
            'name: "x-success"'
        ),
        "Fileball callback must use the filebox play route": (
            'simplePlaybackURL(scheme: "filebox", endpoint: endpoint)'
        ),
        "Simple external player URLs must strictly encode nested credentials": (
            'components.percentEncodedQuery = "url=\\(encodedEndpoint)"'
        ),
        "Jellyfin HLS must let VLC adopt its transient negotiated audio output": (
            "preferredAudioTrackOrdinal: prepared.playMethod == .transcode\n                    ? nil"
        ),
        "Jellyfin HLS must expose every source audio track": (
            "sourceAudioTracks: entry.audioTracks.map"
        ),
        "Jellyfin HLS must expose every source subtitle track": (
            "sourceSubtitleTracks: entry.subtitleTracks.map"
        ),
        "Text subtitles must switch through VLC without rebuilding Jellyfin video HLS": (
            "session.selectExternalSubtitle(sourceTrack?.externalURL)"
        ),
        "Image subtitles must remain on the Jellyfin burn-in path": (
            "Self.requiresBurnIn(subtitleCodec: track.codec)"
        ),
        "Jellyfin source track changes must renegotiate while retaining runtime state": (
            "return replacement?.applyingRuntimePreferences(runtimeState)"
        ),
        "Jellyfin source track changes must not probe the original route again": (
            "forcedServerBitrate: maxBitrate"
        ),
        "Jellyfin diagnostics must distinguish effective and network bitrates": (
            '"networkMaximumBitrate": "\\(bitrateDecision.maximumBitrate)"'
        ),
        "Jellyfin direct play must use the measured route budget instead of the HLS ceiling": (
            "let directPlayBudget = bitrateDecision.directPlayMaximumBitrate"
        ),
        "Wi-Fi direct play must tolerate short throughput-sample variance": (
            "max(Int(Double(cached.rawBitrate) * 1.25), cached.bitrate)"
        ),
        "Automatic remote HLS must retain the fast-start server ceiling": (
            "min(directPlayBudget, 20_000_000)"
        ),
        "Jellyfin Picture in Picture must prepare a system-compatible stream in place": (
            'let replacement = await loader("12000000", runtimeState)'
        ),
        "VLC subtitles must select an iOS CJK font": (
            '"/System/Library/Fonts/Hiragino Sans GB.ttc"'
        ),
        "VLC subtitle decoding must be deterministic": (
            ":subsdec-encoding=GB18030"
        ),
        "VLC subtitle decoding must auto-detect UTF-8 before the GB18030 fallback": (
            ":subsdec-autodetect-utf8=1"
        ),
        "VLC diagnostics must expose the active subtitle font and encoding": (
            '"subtitleFont": Self.cjkFontPath ?? "default"'
        ),
        "Jellyfin automatic playback must gate remote original attempts by route or direct budget": (
            "let routeCanAttemptOriginalPlayback = playbackRouteIsPrivate\n            || forcesOriginalPlayback\n            || sourceBitrateFitsDirectBudget"
        ),
        "Jellyfin remote original playback must require the source bitrate budget": (
            "let prefersRemoteOriginalPlayback = sourceBitrateFitsDirectBudget\n                && !Self.requiresAudioTranscode(audioCodec: selectedAudioCodec)"
        ),
        "Jellyfin automatic metadata must retain the highest-bitrate original source": (
            "return sources.max { lhs, rhs in"
        ),
        "Jellyfin automatic fallback must preserve a resume position before VLC has a clock": (
            "Double(requestedStartTimeTicks) / 10_000_000"
        ),
        "Jellyfin source-track requests must identify their reconfiguration reason": (
            'forcedServerReason: "sourceTrackSwitch"'
        ),
        "Jellyfin server seeks must identify their reconfiguration reason": (
            'forcedServerReason: "serverSeek"'
        ),
        "Jellyfin bitrate fallback must identify its reconfiguration reason": (
            'forcedServerReason: "bitrateFallback"'
        ),
        "Jellyfin HLS must use deterministic AAC audio": (
            'allowAudioStreamCopy: false'
        ),
        "Jellyfin HLS profile must not advertise variable output audio codecs": (
            'audioCodec: "aac"'
        ),
        "Jellyfin runtime reconfiguration must start at the absolute server time": (
            "startTimeTicks: requestedStartTimeTicks"
        ),
        "Jellyfin HLS seeking must request a replacement server stream": (
            "serverSeekRequestLoader: serverSeekRequestLoader"
        ),
        "Jellyfin HLS timelines must retain their absolute offset": (
            "timelineOffsetSeconds: timelineOffsetSeconds"
        ),
        "Wi-Fi throughput sampling must be long enough for route selection": (
            "case \"wifi\": testSize = 4 * 1024 * 1024"
        ),
        "The shared player must provide one-tap mute": "func toggleMute()",
        "The shared player must provide an accidental-touch lock": (
            "accessibilityKey: \"player.controls.lock\""
        ),
        "Every video playback request must default to landscape": (
            "initialOrientationMode: PlayerOrientationMode = .landscape"
        ),
        "The player must apply the request's initial orientation": (
            "initialMode: request.initialOrientationMode"
        ),
        "Closing the player must restore the app orientation policy": (
            "PlayerOrientationController.setPlayerActive(false)"
        ),
        "The orientation panel must reflect the applied initial mode": (
            "State(initialValue: request.initialOrientationMode)"
        ),
        "VLC must map Jellyfin selections onto runtime track IDs": (
            "applyInitialTrackSelectionIfNeeded("
        ),
        "Runtime subtitle selection must update without a synchronous track rescan": (
            "selectedSubtitleTrackID = track.id"
        ),
        "Runtime audio selection must update without a synchronous track rescan": (
            "selectedAudioTrackID = track.id"
        ),
        "Runtime track changes must stay on the player-owning thread": (
            "player.currentAudioTrackIndex = track.id\n        scheduleTrackSelectionCheck(kind: .audio)"
        ),
        "Jellyfin home shelves must publish before secondary collections": (
            '"stage": "primaryShelves"'
        ),
        "Jellyfin posters must use the persistent image pipeline": (
            'diskPath: "nastart-jellyfin-images"'
        ),
        "Unknown Jellyfin durations must not render as zero minutes": (
            "guard ticks > 0 else { return nil }"
        ),
        "VLC reconnects must reattach external subtitles": (
            "self.didAddExternalSubtitle = false"
        ),
        "Jellyfin direct play must advertise AV1 when VLC supports it": (
            '"av1", "dirac", "dv"'
        ),
        "Known HDR streams must be left to server tone mapping": (
            'value: "SDR|Unknown"'
        ),
        "Fallback playback must restore the runtime rate and track state": (
            "runtimeState?.playbackRate ?? initialPlaybackRate"
        ),
        "VLC failures must capture runtime state before transport fallback": (
            "compatibilityFailed(session.runtimeState(orientationMode: orientationMode))"
        ),
        "External handoff must pause compatibility playback": (
            "session.pauseForExternalHandoff()"
        ),
        "Playback pan gestures must lock onto one axis": (
            "private enum VLCPlayerPanMode"
        ),
        "Vertical playback gestures must adjust screen brightness": (
            "UIScreen.main.brightness = targetBrightness"
        ),
        "Natural playback completion must not trigger stall recovery": (
            "let naturalEndToleranceSeconds = min(max(durationSeconds * 0.01, 3), 10)"
        ),
        "A finite VLC input that reaches ended must not trigger compatibility fallback": (
            'let finiteInputEnded = player.state == .ended\n            && request.fileExtensionHint != "m3u8"'
        ),
        "VLC external handoff must preserve subtitle URLs": (
            'scheme: "vlc-x-callback",\n                action: "stream",\n                endpoint: endpoint,\n                filename: filename,\n                subtitleURL: subtitleURL'
        ),
        "Rejected player handoffs must fall back to system sharing": (
            "sharePayload = ServiceSharePayload(url: pending.request.url)"
        ),
        "External player picker must wait for the settings panel to dismiss on iPad": (
            "try? await Task.sleep(nanoseconds: 300_000_000)\n                            openExternal()"
        ),
        "External player picker must use an in-player panel on iPad": (
            "if showExternalPicker {\n                externalPlayerPicker"
        ),
        "Credential handoff warning must use an in-player panel on iPad": (
            "if showCredentialHandoffWarning {\n                credentialHandoffWarning"
        ),
    }
    for message, fragment in required_launchpad_fragments.items():
        if fragment not in launchpad:
            errors.append(message)

    forbidden_launchpad_fragments = {
        "Jellyfin must not bypass PlaybackInfo through a local proxy": "localDirectProxy",
        "Jellyfin must not retain the old runtime TS fallback": "compatibilityTransportStream",
        "Jellyfin must not retain the forced-HLS preparation path": "transcodedHLSPlayback",
        "Jellyfin playback must not synchronously wait for a bitrate test": (
            "let maxBitrate = await negotiatedMaximumBitrate"
        ),
        "Jellyfin must not enable an arbitrary first subtitle": "?? subtitleStreams.first?.index",
        "Jellyfin direct-play negotiation must not claim stereo-only audio": (
            "maxAudioChannels: 2,"
        ),
        "Jellyfin original playback must not be gated by a bitrate estimate": (
            "bitrateDecision.allowsDirectPlay"
        ),
        "Cellular routes must not unconditionally attempt original playback": (
            'bitrateDecision.networkKey == "cellular"'
        ),
        "Jellyfin posters must not fall back to uncached AsyncImage loading": "AsyncImage(url:",
        "Finite media playback must not enable VLC's live HTTP helper": (
            'media.addOption(":http-continuous")'
        ),
    }
    for message, fragment in forbidden_launchpad_fragments.items():
        if fragment in launchpad:
            errors.append(message)

    required_device_fragments = {
        "Authenticated media proxy must keep client-facing open responses continuous": (
            "Transfer-Encoding: chunked"
        ),
        "Authenticated media proxy must continue finite upstream windows": (
            "continueChunkedMediaResponseIfNeeded()"
        ),
        "Authenticated media proxy must count each upstream window independently": (
            "let deliveredBytesInTask = max(deliveredBodyBytes - bodyBytesAtTaskStart, 0)"
        ),
        "Authenticated media proxy must reset per-window expectations": (
            "expectedBodyBytes = nil\n        responseEndOffset = nil"
        ),
        "Authenticated media proxy must expose the complete media length": (
            'Content-Range: bytes \\(start)-\\(total - 1)/\\(total)'
        ),
        "Authenticated media proxy window policy must be sample-independent": (
            "static let upstreamWindowBytes"
        ),
        "DSM file details must retain an explicit preview action": "previewFile()",
        "DSM playback must use the prepared playback route": (
            "url: playbackURL,\n                    title: item.name"
        ),
        "DSM direct playback must retain self-signed certificate trust": (
            "allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true"
        ),
        "DSM input failures must not restart the same URL with software decoding": (
            "compatibilityFallbackResource: MediaPlaybackResource("
        ),
        "DSM video must default to landscape without rotating audio": (
            "initialOrientationMode: item.kind == .video ? .landscape : .automatic"
        ),
        "DSM validated playback routes must be cached": "MediaPlaybackRouteCache.shared",
        "ISO images must use the dedicated Range playback adapter": (
            "case .discImage:\n            prepareDiscImagePlayback(from: url)"
        ),
        "Non-zero seek ranges must be validated upstream": "validatedPartialResponse",
        "Range retries must validate the active retry offset": "activeRequestedRangeStart",
        "The proxy must not advertise byte ranges that upstream omitted": (
            'response.value(forHTTPHeaderField: "Accept-Ranges") == nil'
        ),
    }
    for message, fragment in required_device_fragments.items():
        if message.startswith("The proxy must not advertise"):
            if fragment in devices:
                errors.append(message)
        elif message.startswith("DSM input failures must not restart"):
            if fragment in devices:
                errors.append(message)
        elif fragment not in devices:
            errors.append(message)

    if "didAutoStartMedia" in devices:
        errors.append("DSM media preview must require an explicit user action")
    premature_end_fragments = {
        "A VLC ended state must distinguish a premature end from the natural end": (
            "let endedPrematurely = player.state == .ended"
        ),
        "A premature VLC end must prefer the complete alternate transport": (
            'fail(reason: "prematureEnd")'
        ),
        "A premature VLC end without an alternate transport must reconnect": (
            'scheduleReconnect(reason: "prematureEnd")'
        ),
        "Only completed finite or near-duration playback may be marked naturally finished": (
            "if completedNaturally\n            && (player.state == .ended || player.state == .stopped)"
        ),
    }
    for message, fragment in premature_end_fragments.items():
        if fragment not in launchpad:
            errors.append(message)
    if ".fullScreenCover(item: $playbackRequest, onDismiss:" not in devices:
        errors.append("DSM playback dismissal must restore portrait after the cover closes")
    if launchpad.count(".fullScreenCover(item: $playbackRequest, onDismiss:") < 3:
        errors.append("Every launchpad playback cover must restore portrait after dismissal")
    if "value.code == NSURLErrorCancelled" not in devices:
        errors.append("Cancelled playback-route races must not be reported as failures")
    if 'if ext == "iso" { return .discImage }' not in store_sources:
        errors.append("ISO images must not be downloaded as ordinary text previews")
    if "case discImage" not in nas_models:
        errors.append("File kinds must distinguish ISO disc images")
    if "let data = try await postFormCall(" not in store_sources:
        errors.append("DSM authentication secrets must be sent in a POST form body")
    if "let data = try await call(path: request.0, queryItems: request.1, timeout: 60)" in store_sources:
        errors.append("DSM authentication secrets must never be placed in a request URL")

    required_orientation_fragments = {
        "Playback must offer automatic orientation": "case automatic",
        "Playback must support a portrait lock": "case portrait",
        "Playback must support a landscape lock": "case landscape",
        "Manual orientation choices must update the supported mask": (
            "applyPlayerOrientationMode(_ mode: PlayerOrientationMode)"
        ),
        "Orientation updates must retry across full-screen transitions": (
            "retryDelays: [0, 150_000_000, 350_000_000, 700_000_000]"
        ),
        "Stale orientation transitions must be cancelled": (
            "revision == updateRevision"
        ),
        "Orientation updates must reach the presented player controller": (
            "markOrientationUpdate(in: viewController.presentedViewController)"
        ),
        "Video orientation support must be set before full-screen presentation": (
            "prepareForPresentation(_ mode: PlayerOrientationMode)"
        ),
        "Closing the player must request portrait on every iOS device": (
            "NastartAppDelegate.supportedOrientations = .portrait\n        updateScenes(\n            preferredOrientation: .portrait"
        ),
    }
    for message, fragment in required_orientation_fragments.items():
        if fragment not in app_entry:
            errors.append(message)
    if "<key>UIRequiresFullScreen</key>\n\t\t<true/>" not in INFO_PLIST.read_text(
        encoding="utf-8"
    ):
        errors.append("iPad must run full screen so player orientation requests are honored")

    required_route_fragments = {
        "Playback route classification must recognize private literal addresses": (
            "enum NetworkHostClassifier"
        ),
    }
    for message, fragment in required_route_fragments.items():
        if fragment not in nas_models:
            errors.append(message)
    if "getaddrinfo(" in nas_models or "NetworkRouteClassificationCache" in nas_models:
        errors.append("Domain-and-port playback routes must not be reclassified by DNS")
    if "NetworkHostClassifier.isPrivate((playbackEndpoint ?? endpoint).host)" not in launchpad:
        errors.append("Jellyfin LAN/WAN policy must classify the configured host literally")

    if "ExternalPlaybackCallbackHandler.handle(url)" not in app_entry:
        errors.append("The app must receive external-player callback URLs")
    if "#if DEBUG\nprivate enum PlaybackLabLaunchRequest" not in app_entry:
        errors.append("The playback lab entry point must remain Debug-only")

    with INFO_PLIST.open("rb") as handle:
        info = plistlib.load(handle)
    schemes = set(info.get("LSApplicationQueriesSchemes", []))
    required_schemes = {"infuse", "filebox", "open-vidhub", "vlc-x-callback", "outplayer"}
    missing_schemes = sorted(required_schemes - schemes)
    if missing_schemes:
        errors.append("Missing external player query schemes: " + ", ".join(missing_schemes))

    callback_schemes = {
        scheme
        for entry in info.get("CFBundleURLTypes", [])
        for scheme in entry.get("CFBundleURLSchemes", [])
    }
    if "nastart" not in callback_schemes:
        errors.append("Missing Nastart callback URL scheme")

    return CheckResult("Playback routing invariants", errors, [])


def check_file_browser_performance_invariants() -> CheckResult:
    errors: list[str] = []
    stores = APP_STATE_STORES.read_text(encoding="utf-8")
    dsm_client = DSM_CLIENT.read_text(encoding="utf-8") if DSM_CLIENT.exists() else ""
    diagnostic_store = DIAGNOSTIC_STORE.read_text(encoding="utf-8") if DIAGNOSTIC_STORE.exists() else ""
    local_task_store = LOCAL_TASK_STORE.read_text(encoding="utf-8") if LOCAL_TASK_STORE.exists() else ""
    store_sources = "\n".join((stores, dsm_client, diagnostic_store, local_task_store))
    devices = DEVICES_VIEW.read_text(encoding="utf-8")

    required_store_fragments = {
        "File Station API metadata must be reused between folder requests": (
            "cachedFileStationAPIInfo"
        ),
        "Snapshot discovery must warm the File Station API cache": (
            "cacheFileStationAPIInfo(apiInfo)"
        ),
        "Folder results must have a bounded memory cache": (
            "folderCacheLifetime: TimeInterval = 5 * 60"
        ),
        "Concurrent requests for the same folder must be coalesced": (
            "folderLoadTasks[normalizedPath]"
        ),
        "Folder caches must be isolated by NAS and account": (
            "prepareFolderCache(for: dataSource)"
        ),
        "Folder diagnostics must include request duration": (
            '"durationMs"'
        ),
        "Diagnostic persistence must coalesce rapid playback events": (
            "pendingPersistenceTask = Task"
        ),
        "Diagnostic encoding must run outside the main actor": (
            "persistenceQueue.async"
        ),
    }
    for message, fragment in required_store_fragments.items():
        if fragment not in store_sources:
            errors.append(message)

    required_device_fragments = {
        "Folder lists must expose pull-to-refresh": ".refreshable {",
        "Pull-to-refresh must bypass the memory cache": "forceRefresh: true",
    }
    for message, fragment in required_device_fragments.items():
        if fragment not in devices:
            errors.append(message)

    if '["real_path", "size", "time", "type"]' in stores:
        errors.append("Folder listing must not request unused modification-time metadata")

    return CheckResult("File browser performance invariants", errors, [])


def check_persistence_invariants() -> CheckResult:
    errors: list[str] = []
    local_tasks = LOCAL_TASK_STORE.read_text(encoding="utf-8") if LOCAL_TASK_STORE.exists() else ""
    stores = APP_STATE_STORES.read_text(encoding="utf-8")
    tests = (ROOT / "ios" / "Nastart" / "NastartTests" / "NonPlaybackPolicyTests.swift").read_text(
        encoding="utf-8"
    )

    required_fragments = {
        "Task history must have a bounded retention policy": "maxHistoryCount = 500",
        "Task persistence must normalize pending and completed state": "normalizedState(pending: pending, history: history)",
        "Cloud sync must normalize task payloads": "LocalTaskStore.normalizedState(pending: tasks, history: completedTasks)",
        "Task retention behavior must have a regression test": "testLocalTaskStateDeduplicatesAndBoundsHistory",
    }
    source = "\n".join((local_tasks, stores, tests))
    for message, fragment in required_fragments.items():
        if fragment not in source:
            errors.append(message)
    return CheckResult("Persistence invariants", errors, [])


def check_cloud_sync_invariants() -> CheckResult:
    errors: list[str] = []
    cloud_sync = IOS_ROOT / "Core" / "Stores" / "CloudSyncStore.swift"
    tests = ROOT / "ios" / "Nastart" / "NastartTests" / "NonPlaybackPolicyTests.swift"
    source = "\n".join(
        (
            cloud_sync.read_text(encoding="utf-8") if cloud_sync.exists() else "",
            tests.read_text(encoding="utf-8") if tests.exists() else "",
        )
    )
    required_fragments = {
        "Cloud sync must prevent overlapping sync operations": "isSyncInFlight",
        "Cloud sync must retry a bounded number of times": "maxSyncAttempts = 3",
        "Cloud sync must handle server record conflicts": "serverRecordChanged",
        "Cloud sync must reject incompatible remote snapshots": "incompatibleRemoteSnapshot",
        "Cloud sync must preserve changes made during sync": "localChangesDuringSync",
        "Cloud sync merge policy must have a regression test": "testCloudSyncMergePolicyProtectsNewerLocalChanges",
    }
    for message, fragment in required_fragments.items():
        if fragment not in source:
            errors.append(message)
    return CheckResult("Cloud sync invariants", errors, [])


def main() -> int:
    checks = [
        run_command("Git whitespace", ["git", "diff", "--check"]),
        check_swift_balanced_delimiters(),
        check_ios16_static_patterns(),
        check_localizations(),
        check_localization_references(),
        check_app_icon_asset(),
        check_project_settings(),
        check_transport_security_configuration(),
        check_persistence_invariants(),
        check_cloud_sync_invariants(),
        check_playback_routing_invariants(),
        check_file_browser_performance_invariants(),
    ]

    print("Nastart local preflight")
    print("=" * 24)
    failed = False
    for result in checks:
        status = "PASS" if result.ok else "FAIL"
        print(f"[{status}] {result.name}")
        for warning in result.warnings:
            print(f"  WARN: {warning}")
        for error in result.errors:
            print(f"  ERROR: {error}")
        failed = failed or not result.ok

    if failed:
        print("\nPreflight failed.")
        return 1

    print("\nPreflight passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
