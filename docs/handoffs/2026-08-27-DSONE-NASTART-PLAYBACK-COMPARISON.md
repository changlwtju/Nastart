# DS One 2.4.5 / Nastart 播放对比取证（2026-08-27）

本轮链路拆解的汇总基线见：[2026-08-27 DS One 视频播放链路证据基线](./2026-08-27-DSONE-PLAYBACK-CHAIN-BASELINE.md)。

## 范围与设备约束

- 本轮开始时 Git `HEAD` 与 `origin/main` 均为 `e759a4507375f018be2174ab9768be438b90abad`，`HEAD...origin/main = 0 0`，工作区干净；上一轮播放诊断与 WDA 恢复改动已纳入该提交。
- 复用了 iPhone 13（iOS 16.3.1，UDID `00008110-001E543122E0401E`）上已有 WDA：`127.0.0.1:8102`，WDA 16.8.0，`ready=true`。
- 未重新安装 WDA，未更新或重启 iPhone。

## DS One 动态证据

### Jellyfin / S03《碟中谍3》大文件补证

同一 iPhone、同一 Jellyfin 入口新采集了 50.3 GB 的 `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`。详情页为 4K HEVC / Dolby Vision / 10-bit / 57 Mbps；播放器真实运行时显示 HEVC、2160P、23FPS、57.42 Mbps。t=0/3/10/30 截图均为不同真实画面，目录见 `/tmp/dsone-s03-dynamic-20260827/`。本轮还触达暂停/恢复、4 条音轨（含 TrueHD）、4 条内嵌字幕（PGS/ASS）及字幕切换；音轨/字幕切换后位置没有回到 00:00。

PiP 已完成自动化进入/退出闭环：在 DS One 播放器右上角第一按钮上用 XPath 定位并点击，主界面隐藏并出现系统 PiP 浮窗，DS One 树出现 `PIPUIView`（`270×152`、`StartsMediaSession`）。随后新建 SpringBoard WDA 会话，点击浮窗中心显示系统控件，再用 `//XCUIElementTypeButton[@name="恢复全屏幕"]` 自动点击退出；屏幕回到 DS One 全屏播放器，播放位置仍在约 `53:36`。证据为 `/tmp/dsone-pip-after-element.png`、`/tmp/wda-springboard-controls-2.json`、`/tmp/wda-pip-restore-xpath-element.json`、`/tmp/wda-after-pip-restore-xpath.png`。此前用 Home 或重新启动 App 的操作只证明后台/断点行为，不能替代 PiP 退出按钮验证。Range/Content-Range、实际音频听测和精确 ±15 秒 seek 仍未取得，因此该样本仍不能标记为完整通过。

### Jellyfin 媒体库 / S01

DS One 2.4.5（Build 4）通过“视频 → Jellyfin 媒体库 → 电影”打开《哈尔的移动城堡》。详情页显示 720P SDR、约 2.8GB、1:59:25；进入播放器后取得真实画面，画面内显示 H264、688P、29FPS、3293kbps，并有字幕和吞吐叠加信息。已验证进入、真实首帧、播放画面、暂停/继续操作路径和关闭回详情页。

### DSM 文件 / S18

通过“首页 → video → downloads → movie → [方世玉续集]”打开真实文件：

`[方世玉续集].The.Legend.of.Fong.Sai.Yuk.2.1993.GBR.BluRay.1080p.x264.FLAC.2.0.2Audios-CMCT.mkv`

DS One 播放器取得真实画面，画面内显示 H264、1036P、23FPS、20.46Mbps，播放时可见约 60.8MB/s 的下载吞吐。t≈3、10、30 的截图均为连续真实画面，不是详情页或加载占位；t≈10/30 截图中的片尾/字幕画面也发生了变化，证明播放时钟在推进。

本轮恢复 WDA 后又补采 S01：播放器状态从约 33:50 继续推进至 34:17，并通过进度条操作改变了播放位置；截图 `/tmp/dsone-s01-repeat-20260827.png` 保留了真实画面、H264/688P/29FPS 和字幕结果。该证据证明 seek 操作可达，但尚不足以替代矩阵要求的 15 秒精确度、seek 后恢复时延和音频听测。

当前条件下尚未把该样本的 HTTP `Range`/`Content-Range` 从设备端导出：`rvictl` 无法建立 rvi0，`idevicesyslog` 只给出系统网络流摘要，不能把吞吐叠加信息误称为 Range 证据。后续需在设备解锁且具备可观测抓包链路时补齐。

## Nastart 构建与播放实现

- 使用本地最新源码、Xcode 26.6（17F113）重新构建成功。
- 新包路径：`/tmp/nastart-derived-20260827-opt/Build/Products/Debug-iphoneos/Nastart.app`。
- 已将该包安装到目标 iPhone；签名为 Apple Development，Bundle ID 为 `com.changliwen.nastart`，entitlement 保留 `audio` 与 `picture-in-picture`。
- 已验证 Debug Playback Lab 能进入 Nastart 内置播放器 UI；实验文件未能从 iPhone 请求到 Mac 上的本地服务，服务端没有收到手机 GET，因此该次不能算作解码失败。需要设备解锁后重做可达性检查。

本轮落地的低风险优化位于 `LaunchpadView.swift`：

1. AVPlayer 记录真实首帧：以 `AVPlayerItem.presentationSize` 从零变为有效作为首帧，而不是把 `readyToPlay` 当作首帧。
2. 缓冲诊断按当前播放点选择 `loadedTimeRanges`，seek 后不再固定使用第一个区间，并记录 buffer ahead、empty 和 likely-to-keep-up。
3. PiP 启动在系统不支持、控制器创建失败或等待窗口耗尽时记录明确的 `unavailable` 状态，便于区分“不支持”与“尚未出帧”。

## 当前矩阵结论

本轮已动态触达的 DS One 代表样本是 S01（Jellyfin）、S03（Jellyfin，大体积 DV/HEVC/TrueHD/ASS）和 S18（DSM）。S03 的 PiP 进入、SpringBoard 控件发现和恢复全屏已通过真机自动化闭环；Range、音频实际输出、精确 seek、并发仍未完成；S08（HDR HEVC MP4）、S11（10-bit HEVC/TrueHD）已从真机测试需求文档纳入后续格式族回归，但尚未完成。因此不能把 18×4 矩阵或其余未完成项标为通过。

待设备解锁后按 `PLAYBACK-DEBUG-RUNBOOK.md` 继续：S18 DSM 全功能 → S01 Jellyfin 全功能 → S03/S08/S11 格式族 → S01 串行/并发 → Nastart 同样样本的首帧、缓冲、seek、状态、PiP 进入/退出和断点恢复。
