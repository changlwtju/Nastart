# DS One 2.4.5 / Nastart 播放对比取证（2026-08-27）

## 范围与设备约束

- Git `HEAD` 与 `origin/main` 均为 `197dba40b0a8bc9e7110f456bf591ec1dd3ac152`，`HEAD...origin/main = 0 0`。
- 工作树原有修改和未跟踪文件均保留，未执行清理、回滚或覆盖。
- 复用了 iPhone 13（iOS 16.3.1，UDID `00008110-001E543122E0401E`）上已有 WDA：`127.0.0.1:8102`，WDA 16.8.0，`ready=true`。
- 未重新安装 WDA，未更新或重启 iPhone。

## DS One 动态证据

### Jellyfin 媒体库 / S01

DS One 2.4.5（Build 4）通过“视频 → Jellyfin 媒体库 → 电影”打开《哈尔的移动城堡》。详情页显示 720P SDR、约 2.8GB、1:59:25；进入播放器后取得真实画面，画面内显示 H264、688P、29FPS、3293kbps，并有字幕和吞吐叠加信息。已验证进入、真实首帧、播放画面、暂停/继续操作路径和关闭回详情页。

### DSM 文件 / S18

通过“首页 → video → downloads → movie → [方世玉续集]”打开真实文件：

`[方世玉续集].The.Legend.of.Fong.Sai.Yuk.2.1993.GBR.BluRay.1080p.x264.FLAC.2.0.2Audios-CMCT.mkv`

DS One 播放器取得真实画面，画面内显示 H264、1036P、23FPS、20.46Mbps，播放时可见约 60.8MB/s 的下载吞吐。t≈3、10、30 的截图均为连续真实画面，不是详情页或加载占位；t≈10/30 截图中的片尾/字幕画面也发生了变化，证明播放时钟在推进。

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

本轮已动态触达的 DS One 代表样本是 S01（Jellyfin）和 S18（DSM）。S03（DV/HEVC/TrueHD/ASS）、S08（HDR HEVC MP4）、S11（10-bit HEVC/TrueHD）已从真机测试需求文档纳入后续格式族回归，但尚未在本轮设备解锁状态下完成全功能闭环。因此不能把 18×4 矩阵、Range、PiP、音轨/字幕实际输出或并发结果标为通过。

待设备解锁后按 `PLAYBACK-DEBUG-RUNBOOK.md` 继续：S18 DSM 全功能 → S01 Jellyfin 全功能 → S03/S08/S11 格式族 → S01 串行/并发 → Nastart 同样样本的首帧、缓冲、seek、状态、PiP 进入/退出和断点恢复。
