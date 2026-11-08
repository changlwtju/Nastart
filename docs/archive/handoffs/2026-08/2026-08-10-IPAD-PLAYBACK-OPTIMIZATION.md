# iPad 播放优化交接记录

日期：2026-08-11

设备：iPad 第 9 代，iPadOS 18.3.1，当前 Xcode 仅连接此 iPad。

## 2026-08-11 双设备最新包同步

本轮最新工作区构建已统一安装到两台设备：

- iPhone 13，iOS 16.3.1，UDID `REDACTED-DEVICE-01`：安装成功并确认 Nastart 进程启动。
- iPad 9，iPadOS 18.3.1，CoreDevice `EB93D3F4-14A6-5E68-B381-FC093C0305BA`：安装成功并启动。

两台设备使用同一份 `/tmp/Nastart-latest-device/Build/Products/Debug-iphoneos/Nastart.app`，包含 UIKit CJK 外部字幕叠加渲染、VLC 外部字幕去重、音频启动重试，以及上一轮 Jellyfin HLS/PiP 路由调整。

说明：iPhone 的 USB 与 `ios-deploy` 安装链路正常；当前 Xcode 26 的 `devicectl` 将 iOS 16 设备标为 unavailable，历史 WDA 的 `xcodebuild test-without-building` 又因临时测试 scheme 无 test bundle 失败。后续 iPhone 触控回归需要恢复兼容 XCTest/WDA 启动链路，不能把 WDA 未启动误判为 Nastart 未安装。

## 用户现场问题

- 重新打开 Jellyfin 媒体库中的《方世玉续集》后，字幕仍然异常。
- 本问题先记录为未解决，不把上一次“ASS/SSA 外部字幕已归一化”提交误认为现场已通过。
- 下一轮需要在同一片源上记录：字幕编码、字幕格式（ASS/SSA/SRT/PGS）、实际轨道 ID、是否出现重复字幕/方框/乱码/不显示，以及切换前后播放位置。

## 本轮代码调整

- Jellyfin 远端端点在 Wi‑Fi 下，如果源码率落在已测直读预算内，优先尝试原画 Range 直读；只有不满足预算、需要音频转码或原画路由失败时才建立 HLS。这样普通片源不再无条件承担服务器转码首帧等待。
- VLC 外部归一化字幕加入后，增加“唯一新增字幕轨道”兜底选择，并过滤无效轨道 ID，避免字幕加入成功但没有被选中。
- 保留当前播放会话、当前位置、音轨、字幕和倍速继承逻辑；没有增加第二套播放器或 localhost 主播放代理。
- Jellyfin HLS 默认显示引擎改为 MobileVLCKit，避免 AVPlayer 在 iPadOS 上出现“状态已播放但画面黑”；进入 PiP 时仍单独准备系统兼容 HLS。
- PiP 辅助 `AVPlayerLayer` 不再使用透明层，避免 PiP 捕获黑帧；AVPlayer HLS 首帧 watchdog 从 8 秒缩短为 4 秒。
- 设备文件/Jellyfin 音频播放增加按文件扩展名的 `avformat` demux 提示，网络/文件缓存与视频直读保持一致，并记录实际 demux 与缓存值。
- VLC 原始流在启动阶段若处于 buffering 但没有保持 play 状态，只允许一次自动重发 play，避免用户手动点播放才能开始。

## 当前 iPad 真机证据（2026-08-10）

- Xcode 仅识别并安装到 iPad 9（iPadOS 18.3.1）；没有操作 iPhone。
- 《方世玉续集》真实 Jellyfin 播放：视频可出画面，ASS 下载已归一化为 UTF-8 SRT，VLC 外挂轨道也确实被选中；截图仍为中文方框。因此 CJK 最终可见 glyph 仍未通过，不能宣称已解决。
- 真实日志出现过原始流停在 buffering、需要手动点播放才继续的情况；本轮已加入一次受控自动重发 play，但尚未用新包再次完成稳定性长测。
- PiP 入口点击后本轮没有获得系统画中画窗口的可复核证据，真实进入/退出仍不通过。
- 当前 DSM 根目录可见的 `/music` 目录为空，未找到可用于“设备文件音频播放”的真实音频样本；音频代码已修复 demux/cache 路由，但音频界面尚未完成真实首帧与声音验证。

## 18 项验证矩阵状态

| 项目 | 当前状态 |
| --- | --- |
| Jellyfin 原画 MKV/H.264/HEVC、HLS 兼容流、快进回退、音轨切换、字幕切换、清晰度切换、进度继承 | 部分通过；已有历史样本，当前 HLS 黑屏/PiP 需重新闭环 |
| 设备文件常见视频、远程 Range、软件解码回退 | 有历史 iPad 证据，需本轮新包复测 |
| 设备文件 MP3/M4A/FLAC/WAV/APE/WMA/ALAC/Opus | 未完成；当前 iPad 可见音频样本不足，代码已补 `avformat` |
| Jellyfin HLS 黑屏 | 未通过；已改默认 VLC 显示路径，待真机复测 |
| 真实 PiP 进入/退出、进入后继续播放、退出后不回头 | 未通过；本轮未取得系统 PiP 窗口证据 |
| 后台恢复、前后台切换、网络切换、蜂窝 | 未完成；当前 iPad 本轮没有可复核蜂窝环境 |
| ISO9660、UDF-only、Blu-ray 结构与菜单 | ISO9660 代码支持；UDF/Blu-ray 没有真机样本，未通过 |
| CJK glyph、长时间播放、18 样本全量回归 | 未完成；不得用历史记录替代本轮全部证据 |

- Jellyfin HLS 清晰度/音轨/PGS 字幕切换仍受服务器重新生成分段的客观延迟限制，但必须保持绝对时间点，不得回到开头。

## 2026-08-11 iPad 最终回归（最新安装包）

设备：iPad 9，iPadOS 18.3.1，CoreDevice `EB93D3F4-14A6-5E68-B381-FC093C0305BA`。本轮已重新构建、安装并启动最新 Nastart；构建使用 `xcodebuild`，结果为 `BUILD SUCCEEDED`。

### 已由真机复核通过

- Jellyfin《方世玉续集》：原始 MKV 在 6 秒 watchdog 后自动切换到服务器 HLS，诊断记录了 `serverNegotiatedHLS`、`player_state=playing` 和首帧约 10.4 秒；截图为可见视频，不再是黑屏。
- 同一 HLS 画面实际显示中文句子“手掌可否给我看看”，为真实 CJK glyph，不是方框。直接播放失败后保留 Jellyfin 的字幕轨道索引，避免 HLS 回退时丢失字幕。
- 快退/快进：真机时间轴从约 17:27 操作后分别落在 17:52、17:59 的连续位置，未回到 00:00；这里的时间变化包含操作期间自然播放推进。
- Jellyfin 清晰度：打开“清晰度”菜单并选择 `1080p、12 Mbps`，切换后仍有可见画面，时间轴约保持在 19:37，未从头播放。
- 真实系统 PiP：实际捕获到 iPad 系统 PiP 浮窗和“此视频正在以画中画播放”提示；PiP 内画面可见，退出后返回全屏播放器且时间点仍在约 22:45。不是仅调用 API 或应用内模拟窗口。
- PiP/质量切换后的请求跟踪已调整为优先保存活动兼容请求的 tracker，避免 direct-play 请求被 HLS 替换时离开播放器保存错误会话。

### 本轮代码修复

- Jellyfin 原始流首帧 watchdog：私网原画 6 秒、公网 5 秒；设备文件私网 8 秒、公网 6 秒，避免长时间黑屏后才触发回退。
- Jellyfin direct-play 携带外部字幕时，HLS fallback 和清晰度请求保留原字幕流索引；仅在没有服务器字幕资源时才清除“原生字幕禁用”状态。
- 播放器离开时无条件优先保存当前活动兼容请求的进度跟踪器，覆盖 direct-play → HLS 的替换路径。

## 18 样本矩阵：本轮的准确卡点

仓库现有记录只有 4 个可定位 Jellyfin 片源（《碟中谍2》《百变星君》《A计划续集》《超凡蜘蛛侠2》），没有 18 个样本的文件清单、Jellyfin item ID 或可供本机逐一打开的 18 个媒体入口。因此“18 样本完整矩阵”此前一直不能诚实地标为完成；这不是代码测试命令缺失，而是测试夹具/样本清单不足。

当前可执行的 18 类覆盖如下：

| 类别 | 当前结论 | 阻塞原因 |
| --- | --- | --- |
| Jellyfin 原画 MKV/H.264、原画 HEVC、MPEG-TS、HLS | 已覆盖部分，HLS 本轮通过 | 现有服务器只可定位上述 4 个片源 |
| Jellyfin PGS、ASS/SSA、外部 SRT、CJK glyph | ASS/SRT/CJK 本轮通过，PGS 有历史记录 | 缺少可重复打开的独立 PGS 样本入口 |
| Jellyfin 音轨切换、字幕切换、清晰度切换 | 菜单和单轨状态已真机确认；清晰度切换通过 | 《方世玉续集》当前只有一条可选音轨/字幕轨，无法证明多轨切换 |
| Jellyfin 快进、快退、断点恢复 | 本轮通过 | 无 |
| 设备文件 MP3、M4A、FLAC、WAV、APE、WMA、ALAC、Opus | 代码路径已修复，未作真实声音验证 | 当前 DSM `/music` 目录为空 |
| 设备文件常见视频、远程 Range、软件解码 | 有历史 iPad 证据 | 当前“设备文件”目录没有可打开视频样本 |
| ISO9660 主标题 | 代码边界已实现，未取得本轮 ISO 文件 | 当前设备文件区没有 ISO 样本 |
| UDF-only、Blu-ray 结构、Blu-ray 菜单/导航 | 当前实现不支持，不能宣称通过 | MobileVLCKit 当前能力和样本均不足 |
| PiP 进入、PiP 播放、PiP 退出、退出后恢复 | 本轮真实系统窗口闭环通过 | 无 |
| 后台恢复 | PiP 路径已证明系统兼容播放器可继续播放 | iPad WDA 无可用系统 Home endpoint，未能独立采集普通后台切换证据 |
| Wi-Fi 网络切换 | 当前连接 Wi-Fi 播放已通过 | iPad 当前没有第二个可切换网络 |
| 蜂窝网络切换 | 未执行 | iPad 为 Wi-Fi-only 机型 |
| 长时连续播放 | 未执行完整长测 | 本轮受限于设备占用时间，不能用短测冒充长测 |

以上没有把“没有样本/没有第二网络/硬件不支持的格式”伪装成通过；代码能在当前 iPad 完成的路径已先完成，剩余项目均标明了具体外部条件。拿到 18 个样本清单、音频文件、ISO/UDF/Blu-ray 文件或第二网络后，可按本表直接继续，不需要重新猜测卡点。
