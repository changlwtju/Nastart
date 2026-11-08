# DS One 2.4.5 / Nastart 播放对比取证（2026-08-27）

本轮链路拆解的汇总基线见：[2026-08-27 DS One 视频播放链路证据基线](2026-08-27-DSONE-PLAYBACK-CHAIN-BASELINE.md)。

## 范围与设备约束

- 本轮开始时 Git `HEAD` 与 `origin/main` 均为 `e759a4507375f018be2174ab9768be438b90abad`，`HEAD...origin/main = 0 0`，工作区干净；上一轮播放诊断与 WDA 恢复改动已纳入该提交。
- 复用了 iPhone 13（iOS 16.3.1，UDID `REDACTED-DEVICE-01`）上已有 WDA：`127.0.0.1:8102`，WDA 16.8.0，`ready=true`。
- 未重新安装 WDA，未更新或重启 iPhone。

## DS One 动态证据

### Jellyfin / S03《碟中谍3》大文件补证

同一 iPhone、同一 Jellyfin 入口新采集了 50.3 GB 的 `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`。详情页为 4K HEVC / Dolby Vision / 10-bit / 57 Mbps；播放器真实运行时显示 HEVC、2160P、23FPS、57.42 Mbps。t=0/3/10/30 截图均为不同真实画面，目录见 `/tmp/dsone-s03-dynamic-20260827/`。本轮还触达暂停/恢复、4 条音轨（含 TrueHD）、4 条内嵌字幕（PGS/ASS）及字幕切换；音轨/字幕切换后位置没有回到 00:00。

2026-08-29 续采见
[2026-08-29-DSONE-S03-DYNAMIC-CONTINUATION.md](2026-08-29-DSONE-S03-DYNAMIC-CONTINUATION.md)：同一 50.3 GB 样本重新验证约 3 秒首帧、30 秒连续播放、5 秒暂停定帧、恢复、进度条前跳/回跳、TrueHD 选择、PGS/ASS 字幕列表和 PiP 入口。PiP 退出被设备锁定阻塞；Proxyman 未出现新流量；清晰度菜单在本轮播放器控制层未找到；Range/Content-Range 仍需服务端或代理日志补齐。

同日后续解锁后，DS One 在默认可见界面 WDA session 中恢复到 S03 全屏播放器，位置约 `1:42:07` 至 `1:43:56`，并保留 `HEVC / 2160P / 23FPS / 57.42mbps` 叠加信息和 ASS 双语字幕实际渲染。另一次 PiP 进入截图显示 iOS 系统 PiP 浮窗及恢复/关闭/快退/暂停/快进控件；但本续采没有通过 SpringBoard XPath 明确点击 `恢复全屏幕`，所以只能作为 PiP/后台恢复强证据，不能替代矩阵要求的完整 `PP=P` 闭环。

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

2026-08-31 追加：本地最新工作区先构建并安装到同一 iPhone 13，产物为
`/tmp/NastartEngineOptIPhoneDerived/Build/Products/Debug-iphoneos/Nastart.app`，
Bundle ID `com.changliwen.nastart`，版本 `0.1.0 (1)`，签名 Team `5436TB5498`，安装
结果为 `InstallComplete`。随后聚焦播放器底层，不扩展 PiP：S03 详情页确认默认音轨为
`英语 - English - TRUEHD - 5.1 - 默认`，字幕为 `繁英雙字 - Chinese - ASS`，源文件为
`Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`，大小
`54.01 GB`。Nastart 协商层新增一个独立策略：当原始文件路由为私网或码率安全、默认
音轨会触发服务端 HLS 且同源存在可直放音轨时，初始播放先选择可直放音轨打开原始文件，
进入 compatibility engine；用户显式切回 TrueHD、字幕烧录需求或直放失败仍走既有
Jellyfin HLS 协商/降级。

同轮 WDA 证据：Nastart session `D8BC681A-36F0-4756-87E9-16000FB4593A` 成功启动到
`bundleId=com.changliwen.nastart`；点击 S03 后出现真实视频帧和 ASS 双语字幕，截图
`/tmp/nastart-engine-opt-s03-now.png` 与 `/tmp/nastart-engine-opt-s03-later.png` 的
SHA-256 不同，后者画面自然推进。syslog 中出现 `MobileVLCKit` player instance 创建；
同时也出现 AVPlayer 初始化日志，这是当前 SwiftUI `MediaPlayerSession` 被无条件创建的
副作用，不代表本次可见画面由 AVPlayer 输出。由于首次采样脚本的环境变量错误，精确
tap-to-first-frame 秒数未在本轮闭合，需下一轮从冷启动重采。

2026-08-31 继续：Nastart 已将 `AVURLAsset`/`AVPlayerItem` 创建延迟到系统播放器实际
播放时，compatibility 初始路由不再同步准备 AVPlayer 媒体项。该版本安装到 iPhone 13
后重采 S03：第一次自动化点击暴露详情页播放按钮中心与底部 tab bar 重叠，样本无效；
改用按钮上沿点击后，`t=2.3s` 进入播放器 loading，`t=3.2s/4.2s` 已在播放界面但画面近黑，
`t=6.2s` 出现可辨认真实视频帧，`t=8.3s/12.3s` 画面继续推进。syslog 在起播阶段记录
`MobileVLCKit` player instance；仍有 AVFoundation 偏好读取和一次空 AVPlayer rate=0
日志，但未见 `AVURLAsset`/`AVPlayerItem` 媒体加载关键字。

同日后续又修复 MobileVLCKit 内置播放器控制层：自动隐藏后，单击视频画面必须重新显示
控制条。新包 `/tmp/NastartTapControlsIPhoneDerived/Build/Products/Debug-iphoneos/Nastart.app`
已安装到 iPhone 13；WDA session `66B27E04-DEC4-459D-A8C9-30F57280F274` 播放 Jellyfin
样本《哈尔的移动城堡》后，隐藏态只保留 `显示或隐藏播放控制` 命中层，单击视频区域后
`完成`、`锁定播放控制`、`更多播放控制`、`后退 15 秒`、`暂停`、`前进 15 秒`、`音轨`、
`字幕` 重新可见。证据截图为 `/tmp/nastart-controls-hidden.png` 与
`/tmp/nastart-controls-after-tap.png`。该验证只覆盖控制层手势，不替代 S03 大文件首帧、
Range 或 seek 性能矩阵。

## 当前矩阵结论

本轮已动态触达的 DS One 代表样本是 S01（Jellyfin）、S03（Jellyfin，大体积 DV/HEVC/TrueHD/ASS）和 S18（DSM）。S03 的 PiP 进入、SpringBoard 控件发现和恢复全屏已通过真机自动化闭环；Range、音频实际输出、精确 seek、并发仍未完成；S08（HDR HEVC MP4）、S11（10-bit HEVC/TrueHD）已从真机测试需求文档纳入后续格式族回归，但尚未完成。因此不能把 18×4 矩阵或其余未完成项标为通过。

待设备解锁后按 `PLAYBACK-DEBUG-RUNBOOK.md` 继续：S18 DSM 全功能 → S01 Jellyfin 全功能 → S03/S08/S11 格式族 → S01 串行/并发 → Nastart 同样样本的首帧、缓冲、seek、状态、PiP 进入/退出和断点恢复。
