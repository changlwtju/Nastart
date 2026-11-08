# S01 新架构源轨道状态与 HLS PiP

日期：2026-09-06，接续 HLS-CONTENT-MAPPING；只运行 iPhone 13 / iOS 16.3.1 / NAS LAN。

## 已修复

复现：在新架构 HLS 里开启外挂中文字幕，再切 Auto 回 KS，字幕菜单回到关闭。AV 控制适配器仅在会话建立时缓存源选择；外挂字幕不进入 AVPlayer 的 legible group，选择后缓存未更新，后续请求继承旧的关闭状态。

共用 UI 新增 `runtimeStateForSourceChange()`，对 Greenfield 使用当前源音字幕菜单的选择生成 runtime ordinal/disabled/known，保留原来的位置、速率和方向；覆盖画质、轨道、seek、兼容回退等重建调用。`PlaybackUIEngineSession.usesSourceTrackSelectionForRuntimeState` 默认为 false，仅 Greenfield 为 true，所以旧 VLC 仍返回原引擎 runtime state。没有重做播放器 UI 或修改 HLS 时间映射。

## 新增真机结果

- 中文字幕开启：KS → HLS → KS 三处菜单的 selected value 均为 1，位置保持约 1108.45 秒，暂停意图保持。
- 国语音轨：KS 选择后切 HLS，再回 KS，两处均选中国语；服务端请求日志确认 audioStreamIndex=2。
- 关闭字幕：HLS 中关闭后回 KS 仍关闭，服务端请求 subtitleStreamIndex=none；开启时为 4。
- 以上六处选择状态通过 XML 自动断言。证据在 `tmp/playback-20260905/test-source-selection.out`、`test-audio-pip-next.out` 和 `source-selection-*.xml/png`。
- HLS trace `16D223C4` 开启源字幕 4，KS `CF7076DF` 仍为 4；HLS `0F51C0CA` 为 audio=2/subtitle=4，`7DDD531D` 为 audio=2/subtitle=none，KS `0395E989` 仍 audio=2/subtitle=none。
- HLS trace `031D1A02` / plan `27E3BB11` 请求 PiP 后，iPhone 主屏两张间隔截图的小窗有明确不同场景，证明 HLS 小窗在后台显示推进。`source-selection-pip-home-a/b.png`。
- 首次尝试返回全屏时 WDA 仍锁定后台 App，源树与系统屏幕不一致；重新创建带 bundleId 的 session 会重启 App，该次操作不能作为成功的 PiP 返回。不要重复用新建 session 处理活跃 PiP。

源轨道选择保持不等于字幕实际呈现、听到正确配音或声画同步；未收到人工听测结果前 AUD 保持未验证。源字幕片段已通过 LAN 提取至 `s01-subtitle-window.srt`（时间是相对源 1100 秒），可继续定位实际字幕出现时刻。

## 构建

`build-source-selection.log` / `install-source-selection.log` 成功，动态链接隔离检查通过；`preflight-source-selection.log` 通过（更新原有 runtime snapshot 调用的文本检查）。未重跑 KS seek、HLS 内容映射或 trace-report 的已有无关测试；未跑全量 XCTest。

下一步：完成 HLS PiP 返回/关闭的稳定操作证据，实际字幕呈现/声画同步、退出续播及 MEM；保留严格逐帧 Q 和其余矩阵未通过边界。

## PiP 后续已完成（20:53）

通过现有 WDA session 的 `/appium/settings` 设置 `defaultActiveApplication=com.apple.springboard`，即可读取系统小窗的“恢复全屏幕”按钮。仍使用横屏触摸坐标；系统 source 的 frame 可能是竖屏，不可直接照搬。回到 App 后设回 `com.changliwen.nastart`。不新建 session。

HLS `30FCC514` / plan `4BE85B7E` 已完成小窗→全屏，以及同一计划的主屏→小窗→全屏往返；两次返回后可正常暂停，日志位置分别为 1446.509725、1472.500689 秒。`pip-hls-return-success.xml/png`、`source-selection-pip-final-home.xml/png`、`source-selection-pip-final-return.xml/png` 和 `source-pip-final-export.log/report.json` 为证据。该计划没有 failureStages；不能将工具定位失败算播放器失败。

HLS PiP 的中文字幕已实际显示，截图 `source-selection-pip-semantic-start.png`、“火在说话”；`pip-w3c-controls.png`、“跟魔鬼做交易？”；`pip-portrait-coordinates.png`、“所以就被关在这里做牛做马”。字幕在小窗持续随剧情变化，补充了 SUB 可见性证据，尚未做全段逐句同步或音频听测。

PP 的视觉进入/后台推进/恢复全屏子项已取得证据；音频听测和 MEM 仍未通过，不将整个矩阵改 P。
