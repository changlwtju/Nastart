# Nastart Playback Audit

Date: 2026-08-06

## Target behavior

| Source | Network | In-app player | Automatic fallback | External player |
|---|---|---|---|---|
| DSM device file | LAN | One MobileVLCKit player reading the validated DSM media URL directly | One software-decoder retry, then one bounded reconnect | Validated DSM HTTP/HTTPS media URL |
| DSM device file | WAN | The same direct player path, with WAN-aware VLC caching | One software-decoder retry, then one bounded reconnect | Validated DSM HTTPS media URL |
| Jellyfin | LAN | One MobileVLCKit player; Direct Play uses the validated DSM or Jellyfin source URL directly | Jellyfin chooses Direct Play, Direct Stream, or HLS before playback | The original negotiated server resource |
| Jellyfin | WAN | The same player UI; use original Range only when the source fits the safe bandwidth budget | Start server HLS immediately when the original exceeds the budget; one lower-bitrate renegotiation remains available | The selected original or negotiated server resource |

Self-signed DSM and Jellyfin HTTPS routes carry their certificate policy with each playback resource. Range probes still validate redirects, credentials, content length, and seek support before MobileVLCKit opens the selected upstream URL directly. Jellyfin HLS and transcoding URLs also remain direct because their playlists and child segments belong to the Jellyfin server.

Jellyfin no longer exposes system and compatibility player modes. The app chooses the transport automatically while keeping one player UI and one set of controls.

All Jellyfin and DSM video requests open in landscape by default, regardless of LAN or WAN transport. Audio requests retain the current device orientation. While playing, the user can still choose automatic rotation, portrait lock, or landscape lock; closing the player restores the phone UI to portrait.

## Playback state machine

The shared UI and MobileVLCKit decoder do not make Jellyfin and DSM the same transport. Each source adapter must produce one authenticated, seekable playback resource before the shared player starts.

1. `preparing`: resolve the Jellyfin PlaybackInfo resource or DSM download route. No duplicate media probe runs after the tap.
2. `opening`: Direct Play opens the validated upstream URL; Jellyfin HLS opens the negotiated server stream. VLC uses source-aware caching and automatic hardware decoding.
3. `playing`: success requires playback-clock progress, not only VLC's `playing` flag.
4. `recovering`: Jellyfin WAN renegotiates one lower-bitrate HLS resource; DSM retries the same Range resource once with software decoding.
5. `failed`: after the one source-specific recovery is exhausted, stop and expose external playback. No fallback can point back to itself.

Jellyfin automatic playback favors the same DSM original-file route for a private IP endpoint and whenever the source bitrate fits the current network budget. A domain-and-port endpoint is treated as WAN regardless of whether the phone currently uses Wi-Fi or cellular. On WAN, an original above that budget is skipped before VLC opens it and Jellyfin HLS is negotiated immediately. DSM never claims server transcoding capability because File Station cannot reduce the source bitrate.

## Frozen main path

The validated DSM direct-Range path is the baseline for both source adapters. Device Files and Jellyfin Direct Play now hand the selected upstream URL to the same `BuiltInMediaPlayerView` and MobileVLCKit session. Do not add a localhost proxy, a second player mode, or per-screen cache/decoder overrides to either main path.

Future quality selection belongs in the Jellyfin source adapter: it requests a different resource through PlaybackInfo, then hands that resource to the same player. It does not require another player implementation. Changes to routing, caching, timeouts, or decoder selection require a reproducible playback-lab/device-matrix failure rather than parameter-only experimentation.

## Fixed failure modes

- Media diagnostics no longer buffer a complete response when a server ignores a two-byte Range request.
- Opening a DSM file shows its details and requires an explicit Preview tap before media preparation begins.
- The removed localhost proxy can no longer amplify VLC's overlapping Range reads into upstream connection churn.
- Range probes reject mismatched source files before playback and cache the selected route for five minutes.
- MobileVLCKit uses the original NAS host, not `127.0.0.1`, to choose LAN or WAN buffering.
- A user pause is no longer classified as an 18 second playback stall.
- Playback progress after a backward seek is measured from the latest observed position instead of the historical maximum.
- Pending reconnect work is cancelled when the user seeks.
- Jellyfin and DSM video playback use one MobileVLCKit execution path instead of switching engines.
- Every Jellyfin video requests PlaybackInfo with a VLC-specific direct-play, transcode, and subtitle profile.
- Jellyfin Direct Play advertises the full VLC static-file capability; WAN measurements decide whether the original is safe to open or HLS must be negotiated before playback.
- Jellyfin uses the one server-negotiated URL for the lifetime of the player session instead of runtime direct/HLS/TS swapping.
- HLS requests at least two segments and keyframe-independent boundaries for startup and seeking.
- DSM caches the validated download route for five minutes while retaining strict non-zero Range validation.
- Playback diagnostics now record preparation, tap-to-first-frame, buffering recovery, and seek recovery times.
- Fileball URLs now strictly encode nested query strings and tokens.
- Infuse receives the exact URL that Nastart selected instead of an unverified HTTPS-to-HTTP port rewrite.
- Jellyfin's pre-play audio and subtitle choices are mapped onto MobileVLCKit's runtime track IDs for Direct Play media.
- Turning subtitles off before playback is preserved when the shared player opens.
- External subtitles are reattached after a bounded VLC reconnect.
- The shared player offers automatic rotation, locked portrait, and locked landscape modes.
- VLC receives filename and external subtitle parameters during external handoff.
- Rejected or unavailable external-player routes fall back to the iOS share sheet.
- WAN bitrate measurements are cached separately for Wi-Fi, cellular, constrained, expensive, and other network paths.
- Cellular and constrained paths apply conservative bitrate ceilings without adding another probe after the user taps Play.
- Remote Jellyfin playback can perform one controlled lower-bitrate PlaybackInfo negotiation after sustained buffering and resumes from the current position.
- The lower-bitrate resource is final and cannot enter a repeated fallback loop.
- Jellyfin request and HLS transcode profiles now consistently target stereo output on iPhone and iPad.
- Jellyfin HLS audio is always transcoded to a single AAC stereo output instead of conditionally copying AC3, EAC3, FLAC, MP3, or Opus into the negotiated stream.
- Jellyfin HLS audio and subtitle panels retain the complete source-track inventory. Selecting a different source track requests one replacement HLS resource, preserves the current position and rate, and swaps after PlaybackInfo returns; the replacement's first decoded frame can still depend on Jellyfin transcode startup.
- A source-track change is forced through server negotiation and cannot probe the original DSM resource or enter the normal playback fallback chain again.
- MobileVLCKit is pinned to stable version 3.7.3, based on libVLC 3.0.23.
- A VLC `playing` state without clock progress is logged as `playbackClockTimeout`, separately from an input load timeout.
- DSM raw media retries once with software decoding when automatic hardware decoding never produces playback progress.
- A valid VLC video output marks the first frame ready immediately, so a visible frame is not covered by the initial loading spinner while waiting for the playback clock to advance.
- Jellyfin Direct Play now uses the same validated direct transport as DSM files, while external handoff retains the real upstream URL.
- Embedded image subtitles such as PGS remain in Direct Play for VLC instead of forcing HLS before playback begins.
- Direct Play uses the container's embedded subtitle track and does not attach a duplicate Jellyfin SRT slave; the external subtitle URL remains available for external handoff and HLS.
- Runtime audio and subtitle selection updates immediately without synchronously enumerating every VLC track.
- Subtitle, audio, speed, and orientation choices use compact in-player panels instead of full-screen system action sheets.
- Orientation localization uses fixed keys, so internal localization identifiers cannot appear in the player.
- Jellyfin and DSM video requests now share the same default-landscape behavior, and the orientation panel reflects that active mode.
- Landscape geometry updates wait for the full-screen player controller to be presented and invalidate every presented controller's orientation mask.
- Horizontal and vertical drags lock to one axis; horizontal controls seeking and vertical controls screen brightness with a compact percentage HUD.
- Natural playback completion is no longer eligible for stall recovery or an unexpected replay.
- A premature VLC `ended` state is no longer mistaken for natural completion: an alternate Jellyfin transport is selected when available, otherwise the direct Range resource gets one bounded reconnect.
- ISO images are no longer treated as text previews that can download an entire disc image into memory.
- Jellyfin diagnostics record the effective request bitrate separately from the current network recommendation and label initial playback, bitrate fallback, server seek, and source-track reconfiguration explicitly.

## ISO boundary

The bundled MobileVLCKit 3.6.0 binary was built with `dvdread`, `dvdnav`, and `bluray` disabled. Nastart therefore does not claim full DVD/Blu-ray navigation. It now parses ISO9660 directory records with authenticated HTTP Range requests and exposes the largest DVD title or embedded video through a tokenized localhost Range proxy, avoiding a full-image download. UDF-only images, Blu-ray structures, and disc menus retain authenticated external-player handoff.

Full disc navigation remains a separate engine project: either ship and validate a custom VLCKit build with the disc libraries, or add a server-side remux/extraction adapter. The built-in adapter intentionally covers main-title and embedded-file playback rather than menus.

## Delivery order

1. Pass the LAN/WAN by Jellyfin/DSM playback matrix for startup, uninterrupted playback, seeking, authentication, and bounded recovery.
2. Stabilize the shared landscape controls, compact audio/subtitle panels, manual orientation modes, and external-player handoff.
3. Add and validate Picture in Picture only on a VLC release that exposes a supported PiP output, without replacing the stable compatibility route.
4. Add quality selection on top of Jellyfin PlaybackInfo negotiation; DSM originals must not claim server-side quality variants.

## Automated checks

Run:

```bash
bash scripts/preflight.sh
swiftc -frontend -parse $(rg --files ios/Nastart/Nastart -g '*.swift')
DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer \
  xcodebuild -workspace ios/Nastart/Nastart.xcworkspace \
  -scheme Nastart -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer \
  xcrun swift scripts/generate_playback_fixture.swift /tmp/nastart-playback-fixture.mp4
python3 scripts/playback_lab.py /tmp/nastart-playback-fixture.mp4 \
  --latency-ms 120 --kbps 4000
```

The preflight includes playback routing invariants for PlaybackInfo negotiation, VLC capability profiles, measured WAN bitrate, Range behavior, pause-safe reconnect behavior, timing diagnostics, external URL routes, and `LSApplicationQueriesSchemes`.

The Debug-only `NASTART_PLAYBACK_LAB_*` launch environment bypasses NAS sign-in and sends either a DSM or Jellyfin-labeled resource through the production unified player. The Range server exposes `/dsm/`, `/jellyfin/`, and `/media/` routes and can add latency, bandwidth limits, Basic authentication, or an intentional disconnect.

On 2026-08-06 the controlled H.264 fixture produced visible frames for DSM LAN, Jellyfin LAN, DSM WAN (120 ms latency and 4 Mbps), and Jellyfin WAN starting at 50%. Every route used HTTP 206 Range responses. The supplied `RPReplay_Final1785886424.MP4` also completed its Range reads, but VideoToolbox in the iOS 26.5 simulator returned `-12906`.

The connected iPhone 13 on iOS 16.3.1 then verified the real NAS path with the same 62.7 Mbps MKV. With the configured domain-and-port endpoint over home Wi-Fi, Device Files and Jellyfin both selected the DSM File Station Range URL through the unified MobileVLCKit player; tap-to-first-frame was 1.514 seconds and 1.614 seconds respectively. VLC confirmed audio changes in 20-23 ms and subtitle changes in 22-49 ms. Closing either full-screen player restored portrait orientation. This batch demonstrated fast DNS-hairpin transport, but by product definition it remains a WAN endpoint; the corrected policy therefore still applies its measured bandwidth budget.

On cellular, the same Device Files original took 7.420 seconds to first frame. Two long seeks had not recovered after more than 9 and 19 seconds, confirming the physical limit of streaming a 62.7 Mbps original over that carrier path. Jellyfin measured 22.4 Mbps raw throughput and selected a 12 Mbps safe budget, but the previous route policy ignored that result, opened the 62.7 Mbps original, failed, and reached HLS only after 81.6 seconds. The corrected policy retains original DSM Range on private-IP routes, but immediately negotiates HLS when a domain-and-port source exceeds the measured budget.

The final device batch used a different Device Files sample at the user's request: a 2.7 GB MKV under `/video/media`. Its validated DSM Range route reached the first frame in 1.287 seconds. Brightness, horizontal seek, audio selection, subtitle selection, and portrait restoration all remained functional; the audio and subtitle control actions completed in 95 ms and 100 ms respectively.

For a domain endpoint over home Wi-Fi, the 9.59 Mbps Jellyfin MKV `百变星君` used the same validated DSM Range and MobileVLCKit path as Device Files. Two runs reached the first frame in 1.519 and 2.058 seconds. Playback continued for more than five minutes after a long horizontal seek without an unexpected reconnect; audio and subtitle selection completed in 89 ms and 91 ms. The shared mute, lock, 1.25x rate, brightness, seek, and exit-to-portrait controls were also exercised.

For the same domain endpoint over cellular, `百变星君` remained eligible for original playback because its 9.59 Mbps source fit the 12 Mbps cellular budget; first frame took 6.368 seconds on the observed carrier path. The 64.0 Mbps `碟中谍2` correctly skipped the original and requested 12 Mbps HLS. When that stream failed its startup clock check, the complete request automatically renegotiated at 4 Mbps, retained the absolute 1:01:18 position, and produced a frame 8.9 seconds later. A later server-side scrub prepared its replacement request in 289 ms, retained the 4 Mbps effective bitrate and absolute target time, and produced its first frame in 7.966 seconds.

The 62.7 Mbps multi-track `碟中谍3` also selected HLS over cellular. Initial PlaybackInfo preparation took 1.239 seconds and the first frame took 15.219 seconds on the weak carrier path. All four Jellyfin source audio tracks and the source subtitle remained selectable. Replacing the selected audio stream prepared a new PlaybackInfo request in 281 ms, but the Jellyfin container plus VLC needed another 11.130 seconds to produce the replacement's first frame. This delay is specific to server-transcoded HLS: changing an embedded source track requires a new Jellyfin transcode session. Direct DSM/Jellyfin original playback changes tracks inside VLC in about 0.1 seconds. Forcing this HLS reconfiguration down to 4 Mbps would reduce image quality for the remainder of the session and is therefore not silently applied; future quality controls should make that tradeoff explicit.

External-player protocol checks cover strict nested URL encoding, callback actions, the selected DSM/Jellyfin resource, and fallback to the iOS share sheet. Infuse 8.1.8 was installed on the connected phone and therefore appeared as an eligible target. Fileball was not installed, so its `filebox://` receiver could not be truthfully counted as a real-device pass; only the producer-side URL contract is covered in this batch. A release gate should still record target-app acceptance and first frame for both installed receivers.

## Required device matrix

Classify the configured NAS route independently from the phone's current transport. A literal private IP and port is a LAN route; a domain and port is a WAN route whether the phone currently uses Wi-Fi or cellular. Record Wi-Fi versus cellular as a separate transport dimension because it changes the measured bandwidth budget, startup time, and seek recovery without changing route classification.

Test iPhone and iPad with a private-IP route and a domain route, covering LAN HTTP, LAN self-signed HTTPS, domain over Wi-Fi, and domain over cellular where the environment permits it.

For each route, use MP4/H.264/AAC, MKV/HEVC/AC3, MKV/ASS, MKV/PGS, and a source whose bitrate exceeds the WAN uplink. Record:

1. Tap-to-first-frame time.
2. Three consecutive 15 second forward jumps.
3. Three consecutive 15 second backward jumps.
4. A scrub from 10% to 70%, then from 70% to 20%.
5. Recovery time after each seek.
6. Five minutes of uninterrupted playback and the number of visible stalls.
7. Audio and subtitle track switching.
8. Default-landscape entry, automatic rotation, locked portrait, locked landscape, and portrait restoration on exit.
9. Infuse and Fileball acceptance, first-frame time, and seek behavior.

Suggested pass targets are under 2 seconds to first frame on LAN, under 5 seconds on WAN, under 2 seconds to recover from a LAN seek, and under 4 seconds from a WAN seek. A test is an automatic failure on HTTP/authentication errors, an endless loading state, an unexpected reconnect while paused, a restart from zero, or a missing byte range after seek.

## Physical limits

DSM File Station has no transcoding service. WAN playback of a DSM original file can only be stall-free when sustained NAS uplink and client throughput exceed the source bitrate with headroom. Jellyfin WAN routes can stay smooth under lower bandwidth because PlaybackInfo receives the measured safe bitrate and may select HLS transcoding. Final guarantees therefore require measurements from the real NAS, reverse proxy, carrier path, iPhone/iPad, and media samples.

MobileVLCKit is the shared broad-format engine for Jellyfin and DSM. The AVPlayer path can use the system Picture in Picture controller, but Picture in Picture is not currently claimed for the MobileVLCKit path; it needs a separately validated rendering/lifecycle implementation before it belongs in the device pass matrix.
