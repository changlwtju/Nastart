#!/usr/bin/env python3
"""Simulate Nastart's Jellyfin playback route policy without an iOS device."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass


AUDIO_TRANSCODE_CODECS = {
    "truehd",
    "mlp",
    "ac4",
    "dts-hd",
    "dtshd",
    "dts-hd ma",
    "eac3-joc",
    "atmos",
}

BURN_IN_SUBTITLE_CODECS = {
    "dvbsub",
    "dvb_subtitle",
    "pgssub",
    "hdmv_pgs_subtitle",
    "dvdsub",
    "dvd_subtitle",
    "xsub",
}

PRESETS: dict[str, dict[str, object]] = {
    "jellyfin-external-large-mkv": {
        "source_mbps": 62.7,
        "measured_mbps": 10.8,
        "network": "cellular",
        "expensive": True,
        "container": "mkv",
        "size_gb": 54.0,
        "audio_codec": "truehd",
        "subtitle_codec": "ass",
        "subtitle_selected": True,
        "device": "iphone",
    },
    "jellyfin-wifi-unmeasured-large-mkv": {
        "source_mbps": 62.7,
        "measured_mbps": None,
        "network": "wifi",
        "expensive": False,
        "container": "mkv",
        "size_gb": 54.0,
        "audio_codec": "truehd",
        "subtitle_codec": "ass",
        "subtitle_selected": True,
        "device": "iphone",
    },
    "jellyfin-mission-impossible-iii-remux": {
        "source_mbps": 62.7,
        "measured_mbps": 154.6,
        "network": "wifi",
        "expensive": False,
        "container": "mkv",
        "size_gb": 54.0,
        "audio_codec": "truehd",
        "subtitle_codec": "ass",
        "subtitle_selected": False,
        "device": "iphone",
    },
    "jellyfin-remote-4k-mkv": {
        "source_mbps": 64.0,
        "measured_mbps": 33.7,
        "network": "cellular",
        "expensive": False,
        "container": "mkv",
        "size_gb": 54.0,
        "audio_codec": "truehd",
        "subtitle_codec": "ass",
        "subtitle_selected": True,
        "device": "iphone",
    },
    "jellyfin-lan-original": {
        "source_mbps": 62.7,
        "measured_mbps": 200.0,
        "network": "wifi",
        "private_route": True,
        "audio_codec": "aac",
        "subtitle_codec": "srt",
        "subtitle_selected": False,
        "device": "iphone",
    },
}


@dataclass
class PolicyResult:
    route: str
    engine: str
    play_method: str
    reason: str
    maximum_bitrate: int
    direct_play_budget: int
    source_bitrate_fits_direct_budget: bool
    route_can_attempt_original: bool
    large_remote_original_risk: bool
    audio_transcode_required: bool
    subtitle_burn_in_required: bool
    device_compatibility_transcode: bool
    experimental_original: bool
    warnings: list[str]


def mbps(value: float | None) -> int | None:
    return None if value is None else int(value * 1_000_000)


def label(bits: int | None) -> str:
    return "-" if bits is None else f"{bits / 1_000_000:.1f} Mbps"


def normalized(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip().lower()
    return value or None


def normalized_choice(value: str) -> str:
    return value.strip().lower()


def network_defaults(network: str, expensive: bool) -> tuple[int | None, int]:
    if network == "wifi":
        return 80_000_000, 8_000_000
    if network == "cellular":
        return (12_000_000 if expensive else 16_000_000), 2_000_000
    if network == "constrained":
        return 6_000_000, 2_500_000
    if network == "unknown":
        return (10_000_000 if expensive else 20_000_000), (
            3_500_000 if expensive else 6_000_000
        )
    return 20_000_000, 6_000_000


def bitrate_decision(
    *,
    private_route: bool,
    network: str,
    measured_bitrate: int | None,
    expensive: bool,
) -> tuple[int, int, str]:
    if private_route:
        return 360_000_000, 360_000_000, "privateRoute"

    cap, fallback = network_defaults(network, expensive)
    if measured_bitrate is not None:
        safe_bitrate = min(max(int(measured_bitrate * 0.80), 1_500_000), cap or 80_000_000)
        if network == "wifi":
            direct_play = min(max(int(measured_bitrate * 1.25), safe_bitrate), cap or 80_000_000)
        else:
            direct_play = safe_bitrate
        return safe_bitrate, direct_play, "measured"

    fallback_bitrate = min(cap or fallback, fallback)
    return fallback_bitrate, fallback_bitrate, "networkFallback"


def large_remote_original_risk(args: argparse.Namespace, source_bitrate: int | None) -> bool:
    if args.private_route:
        return False
    containers = {
        value.strip().lower()
        for value in (args.container or "").split(",")
        if value.strip()
    }
    if not ({"mkv", "matroska", "webm"} & containers):
        return False
    high_bitrate = source_bitrate is not None and source_bitrate >= 40_000_000
    large_file = args.size_gb is not None and args.size_gb >= 20.0
    return high_bitrate or large_file


def simulate(args: argparse.Namespace, experimental_original: bool) -> PolicyResult:
    source_bitrate = mbps(args.source_mbps)
    measured_bitrate = mbps(args.measured_mbps)
    maximum_bitrate, direct_budget, basis = bitrate_decision(
        private_route=args.private_route,
        network=args.network,
        measured_bitrate=measured_bitrate,
        expensive=args.expensive,
    )
    max_hls_bitrate = maximum_bitrate if args.private_route else min(maximum_bitrate, 20_000_000)
    audio_codec = normalized(args.audio_codec)
    subtitle_codec = normalized(args.subtitle_codec)
    audio_transcode = audio_codec in AUDIO_TRANSCODE_CODECS
    subtitle_burn = args.subtitle_selected and subtitle_codec in BURN_IN_SUBTITLE_CODECS
    device_compat = args.device == "ipad" and audio_codec == "flac"
    fits_direct = source_bitrate is not None and source_bitrate <= direct_budget
    large_remote_risk = large_remote_original_risk(args, source_bitrate)
    auto_fits_direct = fits_direct and not large_remote_risk
    route_can_attempt = args.private_route or args.force_original or experimental_original or auto_fits_direct
    startup_audio_adjusted = audio_transcode and route_can_attempt and not args.forced_server
    if startup_audio_adjusted:
        audio_transcode = False
    prefers_remote_original = auto_fits_direct and not audio_transcode
    should_attempt_direct = (
        not args.forced_server
        and (not audio_transcode or experimental_original)
        and (not device_compat or experimental_original)
        and (not subtitle_burn or experimental_original)
        and (
            args.private_route
            or args.force_original
            or prefers_remote_original
            or experimental_original
        )
    )
    warnings: list[str] = []
    if source_bitrate and measured_bitrate and source_bitrate > measured_bitrate:
        warnings.append(
            "source bitrate is above measured throughput; direct original may start but is unlikely to stay smooth"
        )
    if startup_audio_adjusted:
        warnings.append("direct original video uses a compatible startup audio track")
    if experimental_original:
        warnings.append(
            "experimental original uses localRangeProxy continuous-range transport with seekable MKV startup"
        )
    if experimental_original and subtitle_burn:
        warnings.append("experimental mode bypasses server subtitle burn-in protection")
    if large_remote_risk and not experimental_original and not args.force_original:
        warnings.append("large remote MKV/REMUX is routed through Jellyfin HLS for first-frame reliability")

    if should_attempt_direct:
        return PolicyResult(
            route="localRangeProxy" if experimental_original and not args.private_route else (
                "directHTTP" if args.private_route else "localRangeProxy"
            ),
            engine="ksPlayer",
            play_method="directPlay",
            reason="experimentalOriginal" if experimental_original else "originalAllowed",
            maximum_bitrate=max_hls_bitrate,
            direct_play_budget=direct_budget,
            source_bitrate_fits_direct_budget=fits_direct,
            route_can_attempt_original=route_can_attempt,
            large_remote_original_risk=large_remote_risk,
            audio_transcode_required=audio_transcode,
            subtitle_burn_in_required=subtitle_burn,
            device_compatibility_transcode=device_compat,
            experimental_original=experimental_original,
            warnings=warnings,
        )

    if args.forced_server:
        reason = "forcedServer"
    elif large_remote_risk and not args.force_original and not experimental_original:
        reason = "largeRemoteOriginalRisk"
    elif not route_can_attempt:
        reason = "automaticBitrateBudget"
    elif audio_transcode:
        reason = "audioTranscodeRequired"
    elif device_compat:
        reason = "deviceCompatibilityTranscode"
    elif subtitle_burn:
        reason = "serverSubtitleRendering"
    else:
        reason = "routeUnavailable"

    return PolicyResult(
        route="localHLS",
        engine="systemAVPlayer",
        play_method="localRemux",
        reason=reason,
        maximum_bitrate=max_hls_bitrate,
        direct_play_budget=direct_budget,
        source_bitrate_fits_direct_budget=fits_direct,
        route_can_attempt_original=route_can_attempt,
        large_remote_original_risk=large_remote_risk,
        audio_transcode_required=audio_transcode,
        subtitle_burn_in_required=subtitle_burn,
        device_compatibility_transcode=device_compat,
        experimental_original=experimental_original,
        warnings=warnings,
    )


def render(result: PolicyResult, title: str) -> list[str]:
    lines = [
        title,
        f"  route: {result.route} / {result.play_method} / {result.engine}",
        f"  reason: {result.reason}",
        f"  hls_max_bitrate: {label(result.maximum_bitrate)}",
        f"  direct_play_budget: {label(result.direct_play_budget)}",
        f"  source_fits_direct_budget: {'yes' if result.source_bitrate_fits_direct_budget else 'no'}",
        f"  route_can_attempt_original: {'yes' if result.route_can_attempt_original else 'no'}",
        f"  large_remote_original_risk: {'yes' if result.large_remote_original_risk else 'no'}",
        f"  audio_transcode_required: {'yes' if result.audio_transcode_required else 'no'}",
        f"  subtitle_burn_in_required: {'yes' if result.subtitle_burn_in_required else 'no'}",
    ]
    for warning in result.warnings:
        lines.append(f"  warning: {warning}")
    return lines


def apply_preset(args: argparse.Namespace) -> None:
    if args.preset:
        for key, value in PRESETS[args.preset].items():
            current = getattr(args, key)
            if current is None or current is False:
                setattr(args, key, value)
    if args.network is None:
        args.network = "unknown"
    if args.device is None:
        args.device = "iphone"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--preset",
        choices=sorted(PRESETS),
        help="fill arguments from a named validation target",
    )
    parser.add_argument("--source-mbps", type=float)
    parser.add_argument("--measured-mbps", type=float)
    parser.add_argument(
        "--network",
        choices=["wifi", "cellular", "constrained", "unknown"],
        default=None,
        type=normalized_choice,
    )
    parser.add_argument("--expensive", action="store_true")
    parser.add_argument("--private-route", action="store_true")
    parser.add_argument("--audio-codec")
    parser.add_argument("--subtitle-codec")
    parser.add_argument("--subtitle-selected", action="store_true")
    parser.add_argument("--container")
    parser.add_argument("--size-gb", type=float)
    parser.add_argument("--device", choices=["iphone", "ipad"], default=None, type=normalized_choice)
    parser.add_argument("--force-original", action="store_true")
    parser.add_argument("--forced-server", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    apply_preset(args)
    if args.source_mbps is None:
        parser.error("--source-mbps is required unless --preset is used")

    auto = simulate(args, experimental_original=False)
    experimental = simulate(args, experimental_original=True)
    if args.json:
        print(
            json.dumps(
                {"auto": asdict(auto), "forceOriginalKSPlayer": asdict(experimental)},
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    print("\n".join(render(auto, "Auto policy")))
    print()
    print("\n".join(render(experimental, "Force original KSPlayer")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
