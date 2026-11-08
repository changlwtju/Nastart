# DS One 2.4.5 S03 dynamic continuation - 2026-08-29

Scope: legal runtime observation of DS One 2.4.5 Build 4 on the existing iPhone
13 only. This note does not copy DS One private code, does not use subscription
or crack logic, and does not bypass DRM, certificates, or security checks.

## Device and evidence

- Device: iPhone 13, iOS 16.3.1, UDID `REDACTED-DEVICE-01`.
- WDA: `127.0.0.1:8102`, WDA 16.8.0. The run used multiple short-lived
  sessions because the DS One player, PiP, and SpringBoard surfaces are exposed
  differently by WDA. The final stable evidence session was the default visible
  interface session `6B8403CC-1C04-4630-918A-85591598F751`.
- Sample: S03 `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`.
- Size and media: `50.3 GB`, 4K HEVC, Dolby Vision Profile 7.6 / HDR10
  fallback, 57 Mbps class, TrueHD 5.1.
- Evidence root: `/tmp/nastart-dsone-s03-20260829/`.

## Confirmed runtime observations

- Cold relaunch and navigation reached the S03 detail page. The detail page
  showed `2小时5分`, `碟中谍3`, `HDR`, and `50.3 GB`.
- Resume click was sent at about `2026-08-29 21:05:11 CST`. Screenshot sampling
  showed player UI at `startup-2`, spinner/loading at `startup-3`, and the first
  real video frame at `startup-4`. At this sampling rate, tap-to-first-frame was
  about 3 seconds.
- The player runtime overlay reported `HEVC`, `2160P`, `23FPS`, and
  `57.42mbps`. `startup-5`, `startup-8`, `startup-15`, `startup-30`, and
  `startup-50` are different real video frames, so continuous playback for at
  least 30 seconds was observed.
- Pause was verified with the corrected control coordinate `x=121,y=345`:
  `pause-retry-t0.png` and `pause-retry-t5.png` stayed on the same frame and
  time `1:29:15`; the overlay network readout dropped to `0 B/s`.
- Resume from the same control advanced from `1:29:15` to `1:29:17` within about
  2 seconds (`resume-t2.png`, `resume-t2.xml`).
- Slider seek forward moved from about `1:25:39` to `1:32:58` and restored real
  video output within the 4-second observation window. Slider seek backward moved
  from about `1:33:38` to `1:19:14` and also restored real video output. This
  proves large-file seek is reachable and does not reset to `00:00`, but it does
  not satisfy the matrix requirement for precise +/-15 second seek.
- The audio menu was identified at the lower control group around `x=611..625,
  y=334..345`. It lists four tracks: Cantonese AC-3 6ch 640 Kbps, English AC-3
  6ch 640 Kbps, Mandarin AC-3 6ch 448 Kbps, and English TrueHD 6ch 3.5 Mbps.
  Selecting the TrueHD row did not reset playback; the later readback was around
  `1:23:36`.
- The subtitle menu was identified around `x=658..672,y=334..345`. The embedded
  subtitle list exposes `关闭字幕`, English `HDMV_PGS_SUBTITLE`, multiple Chinese
  `HDMV_PGS_SUBTITLE` rows, and Chinese `ASS` rows. Switching to the first
  visible Chinese ASS row did not interrupt playback. Later screenshots after
  background/PiP recovery showed natural bilingual ASS subtitle frames, including
  `我在IMF會不會暴露了 / Could I be compromised at IMF?`, `達維恩就像雜草 /
  Davian's a weed.`, and the current player frame around `1:43:56` with
  `或許我們可以在同一間牢房 是吧 / maybe we can share a jail cell together, you
  know?`. This is valid visual subtitle evidence for the selected ASS track, but
  the matrix still requires fixed t=3/10/30 plus natural-frame sampling before
  marking `SA=SUB` as fully passed.
- PiP entry was triggered through the known top-right first player button around
  `x=618,y=80`. DS One source then contained `PIPUIView` with `270x152` and
  `StartsMediaSession`, so the DS One-side PiP entry is confirmed in this run.
  In a fresh unlocked attempt, `pip-fresh-after-enter-dsone.png` captured the
  iOS system PiP window on the Home screen with close, restore/fullscreen,
  -10/pause/+10 controls and a progress bar at about `1:41:45`.
- After PiP/session recovery, the default visible-interface WDA session captured
  DS One back in the full-screen player at about `1:42:07` to `1:43:56`, with
  the S03 title, `HEVC / 2160P / 23FPS / 57.42mbps`, and subtitle rendering
  preserved. Because the SpringBoard restore button was not clicked by XPath in
  this continuation, this is strong PiP/background recovery evidence but not the
  exact automated PiP-exit closure required by the matrix.
- `tidevice perf` collected 1,984 CPU/memory samples and 2,469 FPS samples during
  the run. App CPU averaged about `22.16%` and peaked at `53.15%`; memory value
  averaged about `818 MB` and peaked at `973 MB`; RSS averaged about `184 MB` and
  peaked at `268 MB`; FPS averaged about `54.4` and peaked at `60`.

## Tool or evidence gaps

- PiP exit was not completed as a matrix pass in this continuation because
  creating the explicit SpringBoard WDA session returned `session not created`
  with device state `Locked`. The device was later manually unlocked and playback
  was recovered, but the SpringBoard-side `恢复全屏幕` button was not clicked through
  the required XPath flow in that recovered state.
- After that failed SpringBoard session creation, WDA itself still reported
  `ready=true`, but the original DS One session became invalid. The next run can
  recreate sessions against the existing WDA; reinstalling WDA is not required.
- After the device was manually unlocked at about `21:51 CST`, DS One could
  create a new session and then recovered to the S03 full-screen player. This is
  useful background/PiP resilience evidence, especially because the playback
  position and selected subtitles survived, but the SpringBoard `恢复全屏幕` step
  still needs a controlled fresh unlocked run for matrix-grade `PP=P`.
- The default visible-interface session XML reported the active application as
  `SpeedGG` / `local.pid.313` while the screenshot clearly showed the DS One
  player. This should be treated as a WDA/runtime wrapper or process-label
  artifact, not as a replacement for the confirmed DS One Bundle ID
  `com.cz.DSCloudStorage`.
- Proxyman was running on the Mac, but no fresh DS One/Jellyfin flows appeared.
  The phone was not confirmed to be routed through the proxy. Device Wi-Fi proxy
  or certificate settings were not changed during this run.
- App Launch instrumentation against DS One was blocked by normal iOS
  debuggability restrictions (`get-task-allow` unavailable). No bypass was
  attempted. System-level Activity Monitor and `tidevice perf` were used instead.
- The system log filter did not expose useful DS One playback logs in this run.
  `/tmp/nastart-dsone-s03-20260829/logs/dsone-syslog.txt` only contains the
  capture termination marker.
- HTTP `Range`, `Content-Range`, actual upstream window size, retry sequence,
  and server-side Range logs are still not available from this run.
- Actual audible output after audio switching was not verified by human listening
  or equivalent route-level evidence.
- Jellyfin quality switching was not found in the exposed S03 player controls in
  this run. The mapped lower control group was: playlist/related item, audio,
  subtitle, danmaku settings, and playlist. This should be recorded as "not
  found in current UI state", not as proof that DS One lacks the capability.

## Nastart implication

For Nastart, this run strengthens the same independent implementation targets:

- keep startup and first-frame telemetry separate from "player view opened";
- pause should stop unbounded upstream work and preserve reusable buffer state;
- seek must cancel obsolete reads, resume from the requested position, and never
  reset the session to `00:00`;
- track and subtitle selection must preserve current position;
- large 50 GB class HEVC/TrueHD samples should be first-class Jetsam and Range
  regression fixtures.

No new Nastart playback code should be derived from DS One private implementation
details. The missing Range evidence means concrete window sizes and buffer
thresholds remain unproven.
