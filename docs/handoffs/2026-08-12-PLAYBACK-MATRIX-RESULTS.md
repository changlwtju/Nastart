# Nastart 18×4 真机播放验证结果

更新时间：2026-08-14

本表只记录已经在 iPhone/iPad 真机上实际操作并留有证据的结果；`待测` 不代表通过。样本定义见同目录的 `2026-08-12-PLAYBACK-MATRIX-18-SAMPLES.md`。

正式执行按 `S01 → S02 → … → S18` 串行推进。当前样本发现问题时，先记录问题编号、证据、修复和当前样本回归结果，再进入下一个样本；探索性 ISO/电视剧记录不改变基础 18×4 结果。

### 入口边界说明

基础矩阵只有两个业务入口：`Jellyfin 媒体库` 与 `设备文件`。这里的“File Station”不是第三个测试入口，而是 DSM 侧为“设备文件”提供目录列表、会话认证和文件打开 URL 的 API/服务实现：Nastart 的“设备 → 文件”页面通过 `SYNO.FileStation.List` 读取共享目录，再用认证 URL 打开选中的文件。Jellyfin 入口则先通过 Jellyfin 媒体库与 PlaybackInfo 获取媒体资源；源码还保留了 Jellyfin 原始流不可用时尝试 DSM File Station 原文件的兼容回退，但该播放单元仍计为 Jellyfin，不另算一个入口。

## 状态定义

- `待测`：尚未完成该播放单元的完整检查。
- `进行中`：已进入该播放单元，尚未完成全部验收项。
- `通过` / `失败`：完成规定动作后，根据证据判定。
- `链路不可达` / `样本缺失`：记录事实，不计入通过率。

每个 18×4 单元除核心 `LIB/FF/ST/PA/SK/AT/SU/Q/PP/EX/MEM` 外，新增补充项 `SA=SUB/AUD`：分别记录字幕实际显示和音频实际输出。`SA` 不替换 `SU`（字幕切换）或 `AT`（音轨切换），任一子项未测都不能汇总为通过。

## 基础 72 单元

| 样本 | iPhone·设备文件 | iPhone·Jellyfin | iPad·设备文件 | iPad·Jellyfin |
|---|---|---|---|---|
| S01 | 进行中 | 进行中 | 待测 | 进行中 |
| S02 | 待测 | 待测 | 待测 | 待测 |
| S03 | 待测 | 待测 | 待测 | 待测 |
| S04 | 待测 | 待测 | 待测 | 待测 |
| S05 | 待测 | 待测 | 待测 | 待测 |
| S06 | 待测 | 待测 | 待测 | 待测 |
| S07 | 待测 | 待测 | 待测 | 待测 |
| S08 | 待测 | 待测 | 待测 | 待测 |
| S09 | 待测 | 待测 | 待测 | 待测 |
| S10 | 待测 | 待测 | 待测 | 待测 |
| S11 | 待测 | 待测 | 待测 | 待测 |
| S12 | 待测 | 待测 | 待测 | 待测 |
| S13 | 待测 | 待测 | 待测 | 待测 |
| S14 | 待测 | 待测 | 待测 | 待测 |
| S15 | 待测 | 待测 | 待测 | 待测 |
| S16 | 待测 | 待测 | 待测 | 待测 |
| S17 | 待测 | 待测 | 待测 | 待测 |
| S18 | 待测 | 待测 | 待测 | 待测 |

## 链路重复矩阵

这些是对基础单元的重复，不替换基础 72 单元。当前只在真正切换并验证设备链路后填写。

| 设备 | 链路 | 设备文件 | Jellyfin | 状态 |
|---|---|---:|---:|---|
| iPhone | Wi‑Fi + 域名:端口 | 18 | 18 | 待测 |
| iPhone | Wi‑Fi + IP:端口 | 18 | 18 | 待测 |
| iPhone | 蜂窝 + 域名:端口 | 18 | 18 | 待测 |
| iPhone | 蜂窝 + IP:端口 | 18 | 18 | 待确认可达性 |
| iPad | Wi‑Fi + 域名:端口 | 18 | 18 | 待测 |
| iPad | Wi‑Fi + IP:端口 | 18 | 18 | 待测 |

## ISO 专项

状态：18 个冻结电影样本中没有 ISO；新增 `ISO-01` 变形金刚系列真实 `.iso` 候选，待在 NAS/Jellyfin 实际确认文件存在、扩展名和可达性。不能用普通 MKV/MP4 或 REMUX 结果替代 ISO 结论。

## 新增基础体验与电视剧专项

- 所有 72 个基础单元新增 `LIB` 入口资源加载、`ST` 连续流畅硬性验收和 `SA=SUB/AUD` 实际输出检查；`ST` 至少观察 30 秒并记录 `t=3/10/30s`，`SA` 不能只凭控件存在或截图推断音频正常。
- Jellyfin 入口还要记录冷启动媒体库首屏、首批海报/元数据、搜索和详情页加载时间；这些项尚未取得本轮新包真机证据。
- 新增电视剧专项：`TV-01`/`TV-02` 暂待从 Jellyfin 中选择真实连续两集，检查海报/详情、上下集自动跳转、跨集断点和集号正确性；不计入 18×4 电影统计。

## 多终端同时播放专项

状态：已纳入测试规范，正式证据待按 S01 顺序执行。至少记录：

- `MTP-01`：iPhone+iPad 同一样本同步播放；
- `MTP-02`：iPhone+iPad 不同样本同时播放；
- `MTP-03`：双端播放期间的控制项、`SA=SUB/AUD`、Jellyfin 清晰度/PiP/断点操作。

若出现“单端通过、双端失败”，必须先完成问题修复和单端/双端回归，再进入下一个样本。

## 已采集证据

### S01 · iPhone · 设备文件 · 当前域名链路

- 入口：`/video/media/movie/[哈尔的移动城堡].Howl s.Moving.Castle.HDTV.720p.x264.AC3-CMCT/[哈尔的移动城堡].Howl s.Moving.Castle.HDTV.720p.x264.AC3-CMCT.mkv`，设备文件页确认 2.7 GB。
- 首帧探测：点击“预览”后约 1.7 秒的第一次 WDA 状态读取已出现视频画面和播放控件；控件为“暂停”，不是启动即暂停。
- 播放器状态：出现进度 `00:02 / 1:59:25`、快退 15 秒、快进 15 秒、音轨、字幕控件；截图证据：`/tmp/nastart-evidence/iphone-S01-device-file-playing.png`。
- 暂停检查：操作后控件显示“播放”，约 1.6 秒后的进度仍为 `48:10`，暂停位置保持；恢复点击未成功，需在后续轮次用元素级操作重做。
- 稳定性：退出播放器的 WDA 坐标操作触发 Nastart 进程退出，WDA 报告 App 不在运行；已用 WDA 的 App launch 恢复，未重新安装 WDA。该单元暂不能判定通过。
- 连续播放复测：在重新打开后按约 1 秒间隔采集 6 组截图；第 1 组进度为 `00:02`，之后截图持续是黑色画面加片源水印，未观察到电影画面推进。同期截图侧边下载速率仍约为 `72.1 MB/s` 至 `95.7 MB/s`，因此不能归因于“下载速度归零”。
- 复测结论：该单元至少存在“有网络吞吐但画面停滞/黑屏”的失败现象；随后 WDA 对触摸操作报告 Nastart 进程已退出，另有 App 崩溃风险。连续播放流畅度明确未通过。
- 2026-08-13 根因复现：系统日志显示 `Nastart` 达到 `2148374KB` 后被 Jetsam 以 `per-process-limit` 终止。对应工作区版本的本地代理把首个开放 Range 变成整文件渐进式 `200` 响应；现已改为有限 Range 窗口。
- 修正版已在 Xcode 签名构建并安装到 iPhone/iPad。1 MiB 构建同步启动 S01：iPhone 在 t=3/10/30 秒均有真实画面；iPad 在 t=3/10/30 秒均为黑屏。iPad 同期日志显示多个匹配的 `206` 响应，每段 `response_bytes=1048903`，之后发生 `127.0.0.1` 连接重置。S01 仍为“进行中/失败项待拆分”，不能记为通过。

### S01 · iPad · 设备文件 · 1 MiB 修正版同步回归

- 与 iPhone 在时间差不超过 2 秒时同时点击预览；t=3/10/30 秒截图均为黑屏，播放器控件仍可显示，未观察到稳定真实视频帧。
- iPad 日志显示上游连续返回状态 `206`，每个有限 Range 约 `1048903` bytes；随后本地回环连接出现 `Connection reset by peer`。因此当前证据指向 iPad 侧 VLC/解码或 Range 消费行为，不足以证明 NAS 并发把 iPhone 一并拖死。
- 证据：`/tmp/ipad-s01-concurrent-t3.png`、`/tmp/ipad-s01-concurrent-t10.png`、`/tmp/ipad-s01-concurrent-t30.png`；iPhone 对照：`/tmp/iphone-s01-concurrent-t3.png`、`/tmp/iphone-s01-concurrent-t10.png`、`/tmp/iphone-s01-concurrent-t30.png`。

### S01 · iPhone · Jellyfin · 当前域名链路

- 入口：Jellyfin 搜索“哈尔的移动城堡”→“哈尔的移动城堡, 2004 · 1h 59m”→“在 Nastart 中播放”→“预览”。
- 首帧探测：点击预览后约 1.8 秒的第一次 WDA 状态读取已出现播放器；进度 `00:01`，控件为“暂停”，不是启动即暂停；约 2.2 秒时进度为 `00:04`。
- 播放器状态：出现音轨、字幕、快进/快退和进度控制；截图证据：`/tmp/nastart-evidence/iphone-S01-jellyfin-playing.png`。
- 稳定性：点击字幕控件后 iPhone DVT/WDA 连接重置，随后发现 Nastart/WDA 测试进程退出；已重启 DVT 并新建 WDA 会话，未重新安装 WDA。字幕切换、PiP、清晰度、断点等项尚未判定，该单元暂不能判定通过。

#### S01 iPhone Jellyfin 问题与即时修复记录

- 问题编号：`JELLY-S01-IPHONE-PAUSE-01`。
- 首次失败步骤：Jellyfin 详情页点击“在 Nastart 中播放”后，首帧曾正常出现，但随后播放器停在 `00:06 / 1:59:25`，可见按钮变为“播放”；在 `t=10s`、`t=30s` 复采时进度不再变化，未满足连续播放要求。
- 根因判断：Jellyfin 直播放原始流在首段后进入底层 paused；既有恢复逻辑把 `paused` 与用户主动暂停混同，且在低带宽预算下可能没有生成兼容 HLS 回退请求。
- 修复内容：`LaunchpadView.swift` 增加受用户暂停保护的启动重试和异常暂停短延迟恢复；Jellyfin 直播放始终携带受限码率 HLS 回退闭包，并按当前播放位置生成回退请求，避免从头播放；有限 Range 本地代理继续保持 206 窗口传输。
- 构建/安装：current5 无签名构建 `BUILD SUCCEEDED`，随后使用有效临时开发签名重新签名并安装到 iPhone；iPad 已安装上一版包含 HLS 回退与异常暂停恢复的 current5 包。最新 iPhone 包安装后尚需重新完成 `t=3/10/30s`、播放控件和回退切换回归，因此当前单元仍为 `进行中`，不得记为通过。
- 当前证据：旧版失败证据 `/tmp/nastart-evidence-20260814/iphone-formal-s01-jellyfin-t3.png`、`...-t10.png`、`...-t30.png`；最新构建日志 `/tmp/nastart-build-unsigned-current5c.log`。
- 最新回归（current5，2026-08-14）：重装后首读约 `00:01`，约 4 秒后进度到 `00:06`；继续等待后仍为 `00:06` 且按钮为“播放”，未看到自动切换到兼容 HLS 或继续推进。`JELLY-S01-IPHONE-PAUSE-01` 尚未修复闭环，S01 继续阻塞后续样本。
- 随后又扩大异常暂停识别范围（同时覆盖底层 stopped/paused 且播放时钟已前进的状态），current5d 构建再次 `BUILD SUCCEEDED` 并安装到 iPhone；该包尚未取得新的 `t=3/10/30s` 证据，不能提前记为修复成功。

### S01 · iPhone · 设备文件 · 正式顺序复测（2026-08-14）

- 入口：设备 → 文件 → `/video/media/movie` → `[哈尔的移动城堡]...` → MKV；设备文件页确认 `2.7 GB`，文件名标注 `720p`。
- 首帧/连续播放：点击“预览”后 `t=3s` 已出现真实画面，播放器按钮为“暂停”，进度显示 `00:03 / 1:59:25`；`t=10s` 与 `t≈30s` 截图均为不同真实画面，说明画面在推进，未观察到黑屏或下载速率归零等待。证据：`/tmp/nastart-evidence-20260814/iphone-formal-s01-device-play-t3.png`、`iphone-formal-s01-device-play-t10.png`、`iphone-formal-s01-device-play-now.png`。
- 分辨率/布局：源文件名标注 720p；横屏播放器视频保持宽高比，左右出现与画幅匹配的留边，未观察到拉伸或裁切；当前没有证据证明这是异常“未铺满”，后续继续用 Jellyfin/另一设备对照记录实际区域。
- 其他功能：快进/回退、暂停续播、字幕/音轨和退出重进尚未完成；该单元保持 `进行中`，不得记为通过。

### S01 · 8 MiB Range 窗口实验（2026-08-14）

- 修改：将 `AuthenticatedMediaProxyTransfer.maximumMediaSegmentBytes` 从 `1 MiB` 临时扩大到 `8 MiB`；仍保持有限 `206` Range，未恢复旧的整文件渐进式 `200`。
- 构建/安装：`/tmp/Nastart8MiBDerived` 构建成功；新包已安装到 iPhone（`00008110-001E543122E0401E`）和 iPad（`00008030-001168403C43C02E`）。WDA 通道保持现有会话，未重装。
- iPhone 设备文件：t=3/10/30 秒均为不同真实片帧；另完成暂停→“播放”、继续→“暂停”和“前进 15 秒”（`00:01`→`00:16`）闭环。证据目录：`/tmp/nastart-evidence-20260814-8mb/iphone-t3.png`、`iphone-t10.png`、`iphone-t30.png`、`iphone-paused.xml`、`iphone-resumed.xml`、`iphone-seek-forward.xml`。
- iPad 设备文件：t=3/10 秒出现真实片帧，但约 t=30 秒播放器进度停在 `00:34`，按钮变为“播放”；截图仍为视频画面，不是启动黑屏，但连续播放已停止。证据：`/tmp/nastart-evidence-20260814-8mb/ipad-t3.png`、`ipad-t10.png`、`ipad-t30.png`、`ipad-t30-source.json`。
- 结论：8 MiB 将 iPad 的失败点从约 `00:06` 推迟到约 `00:34`，但未满足 `ST` 30 秒连续播放硬验收（停在 00:34 且处于 paused）。S01 仍未闭环，按规则暂不执行/不判定并发项，也不进入 S02。

### S01 · 32 MiB Range 窗口复测（2026-08-14）

- 修改/构建：在保持有限 `206` Range、禁止整文件渐进式 `200` 的前提下，将临时窗口扩大到 `32 MiB`；构建产物为 `/tmp/Nastart32MiBDerived`，安装到 iPhone `00008110-001E543122E0401E` 和 iPad `00008030-001168403C43C02E`。
- `PD-D` 播放采样：t=0/3/10/30 秒均取得视频帧，t=3/10/30 的截图为不同真实画面，不再复现 1 MiB 的启动黑屏，也未在前 30 秒复现 8 MiB 的 `00:34` 停滞。证据：`/tmp/nastart-evidence-20260814-32mb/pd-d-t0.png`、`pd-d-t3.png`、`pd-d-t10.png`、`pd-d-t30.png` 及对应 `*-source.json`。
- `IP-D` 交互采样：完成暂停/续播、前进/后退 15 秒、音轨选择、关闭字幕；对应控件状态和进度证据在 `/tmp/nastart-evidence-20260814-32mb/ip-d-paused.xml`、`ip-d-resumed.xml`、`ip-d-forward.xml`、`ip-d-back.xml`、`ip-d-audio-selected.xml`、`ip-d-subtitle-disabled.xml`。退出按钮尝试后 WDA 出现陈旧/失联，不能把 `EX` 记为通过；`MEM` 也尚未取得 DVT 级采样。
- 长时风险：iPad 本次播放在约 `01:34` 出现“播放”状态，说明前 30 秒改善，但长时连续播放仍未闭环；因此 `PD-D` 只暂记 `ST` 观察通过、单元整体仍为 `进行中`。
- 安装后复查：为进行设备文件侧的 MTP-01 冷启动，已重新安装同一 32 MiB 包并新建 WDA 会话；两台设备在 Nastart“设备 → 文件”调用 DSM File Station 列目录时只返回 `Backup/chat/docker/drive/home/HomeKit/homes/music/OWdownload/photo/Photos`，未返回规范中的 `/video` 共享目录。证据：`/tmp/iphone-files-root.xml`、`/tmp/ipad-files-root.xml`。这只阻塞设备文件侧的 S01/MTP-01，不代表 Jellyfin 入口依赖 File Station；在 `/video/media/movie` 重新可访问前，不伪造设备文件并发结果，也不进入 S02。
- 当前结论：32 MiB 是一次有证据的传输参数实验，不是 S01 通过；`IP-D` 的 `EX/MEM`、`PD-D` 的交互/长时、`IP-J/PD-J` 以及 MTP-01/02/03 仍未闭环。

### S01 · iPhone · Jellyfin · 32 MiB 参数复查（2026-08-14）

- 媒体库入口恢复正常：Jellyfin 资源库成功加载，搜索“哈尔的移动城堡”返回 `2004 · 1h 59m`，详情页显示音轨、中文字幕和“在 Nastart 中播放”。
- 播放结果：进入 Nastart 内置播放器后取得真实画面，但进度在约 `01:34` 停止，控件变为“播放”；点击“播放”后仍停在 `01:34`。这与 `PD-D` 在 32 MiB 下的长时停滞一致，不能记为 `ST` 通过。
- Jellyfin 专属项：详情页已确认音轨/字幕入口、`清晰度`、`画中画`控件存在；由于基础连续播放失败，本轮不把这些控件存在误记为 `Q/PP` 通过。证据：`/tmp/nastart-evidence-20260814-32mb/ip-j-stalled.png`、`ip-j-stalled-source.json`。
- 当前结论：`IP-J` 仍为 `进行中/失败待修复`，问题编号沿用 `JELLY-S01-IPHONE-PAUSE-01`；在传输断点与 iPad 长时结果闭环前，不进入 S02。

### S01 · iPad · Jellyfin · 32 MiB 参数复查（2026-08-14）

- 媒体库入口：Jellyfin 资源库成功加载，搜索“哈尔的移动城堡”进入详情页；因设备已有断点，详情页操作为“继续观看”。
- 播放结果：点击“继续观看”后取得真实视频帧；`t=0/10/30` 证据截图均不是黑屏，且 SHA-256 分别为 `7163b6d...`、`706041b...`、`e3e5b05...`，画面内容随采样变化，证明已进入实际视频渲染路径。
- 工具边界：播放器运行期间 WDA `source`/控件树读取多次超时，但 `/screenshot` 仍可成功返回。该超时记录为 `TOOL`，不归类为播放失败；因此本轮尚未取得可核验的精确进度、暂停/续播、快进快退、音轨、字幕、清晰度、PiP、退出和 `MEM` 证据。
- 字幕观察：部分截图同时出现字幕字形方框/缺字和一行正常中文，疑似 VLC 内置字幕与 UIKit 外挂字幕重复渲染；新增待修问题 `JELLY-S01-IPAD-SUBTITLE-DUP-01`，因此 `SU` 不通过/不闭环，`SA=F/U`（音频实际输出尚未单独听测）。
- 初步源码关联：`VLCBuiltInPlayerView` 会对 `request.externalSubtitleURL` 绘制 UIKit 字幕层，同时 `VLCMediaPlayerSession.addExternalSubtitleIfNeeded()` 还调用 VLC `addPlaybackSlave` 加载同一外挂字幕；这与截图中的“双字幕/方框 + 正常中文”现象吻合。当前只完成定位，尚未修改源码或重装，避免未经四单元回归就改变全局字幕路径。
- 音频输出补采集：iPad 系统日志在约 50 秒窗口内连续报告 `node=Speaker-Output`，采样 RMS/peak 均为非零值，未观察到输出路由消失或采样归零；证据：`/tmp/nastart-evidence-20260814-32mb/pd-j-audio-route.log`。这证明播放器已向设备扬声器输出音频信号，但尚未完成主观音质/失真听测，`AUD` 仍暂记 `U`，不把音频信号存在等同于完整“正常”。
- 控件采集：WDA 元素级查询找到 enabled 的“音轨”和“字幕”控件（矩形分别约为 `x=279,y=627,w=25,h=15` 与 `x=559,y=627,w=24,h=15`）；“清晰度”“画中画”在本次兼容播放器会话中未找到，不能据此判定 `Q/PP`。播放器控制层自动隐藏后，WDA `source` 读取超时，直接触摸未能恢复可见控制层，记为 `TOOL`。
- 证据：`/tmp/nastart-evidence-20260814-32mb/pd-j-starter.png`、`pd-j-t0.png`、`pd-j-t10.png`、`pd-j-t30.png`、`pd-j-current.png`、`pd-j-controls-visible4.png`。当前结论：`PD-J` 为 `进行中`，需要修复/回归字幕渲染，并补齐播放器进度、控制项和 DVT 级日志后才能判定该单元。

### S01 · 字幕重复路径修复后的同包回归（2026-08-14）

- 修复：`ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift` 的播放启动和重连路径不再调用 `addPlaybackSlave` 加载已由 `CJKSubtitleOverlay` 绘制的同一外挂字幕；`makeMedia()` 保留 `:no-spu`，避免 VLC 内置字幕与 UIKit 字幕双重渲染。该改动针对 `JELLY-S01-IPAD-SUBTITLE-DUP-01`，不是新增入口。
- 构建：`DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer` 下 `Nastart` Debug `iphoneos` 构建成功；产物 `/tmp/NastartS01SubtitleFixDerived/Build/Products/Debug-iphoneos/Nastart.app`，由 `Apple Development: 1432665996@qq.com (43G669CX74)` 签名。该同一包已安装到 iPhone `00008110-001E543122E0401E` 和 iPad `00008030-001168403C43C02E`；WDA 未重装，仅重建会话。
- `IP-D`：同包重新进入规范路径 `/video/media/movie/.../哈尔...mkv`，t=0/10/30 截图均为真实画面且 SHA-256 不同（`cdfa7046...`、`23e27792...`、`aa73f859...`）；播放器可见字幕/音轨入口，暂停菜单、音轨菜单和字幕菜单均可打开，字幕菜单包含“关闭字幕/中文字幕”。证据目录：`/tmp/nastart-s01-iphone-postfix/`。设备扬声器路由和非零音频采样记录在同目录 `audio.log`；`PA/EX/MEM` 仍未达到可签收证据标准。
- `PD-D`：同包重新进入 `/video/media/movie/.../哈尔...mkv`，t=0/10/30 截图均为真实且不同画面（`6b66d9...`、`0f147b...`、`a7cc5b...`）；t=0 控件显示 `00:02 / 1:59:25`，字幕/音轨菜单均可打开并保持播放位置。字幕菜单实际出现“关闭字幕/中文字幕”，已完成关闭后重新选回中文字幕的操作证据；暂停后续播仍受 WDA 元素可见性时序影响，`PA/EX/MEM` 不提前记通过。证据目录：`/tmp/nastart-s01-ipad-postfix/`。
- `IP-J/PD-J`：同包按“媒体库→详情→继续观看/播放”正确进入，iPhone 和 iPad 均取得 t=0 与 t=30 的不同真实视频帧；iPad 同包日志持续出现 `node=Speaker-Output` 的非零 RMS/peak（`/tmp/nastart-s01-ipad-postfix/audio.log`）。字幕重复路径已完成源码修复，但尚未取得四单元均满足 `SUB/AUD`、控制项、Q/PiP/断点和 `MEM` 的完整签收证据；原有约 `01:34` 长时停滞风险仍需单独回归。

### S01 · MTP-01 冷启动批次（2026-08-14）

- 已恢复 `/video` 目录并在两端重新走到同一 S01 MKV。iPhone 点击“预览”时间 `1786716141.317240`，iPad 点击时间 `1786716142.747539`，间隔 `1.430299s`，满足规范的 2 秒冷启动窗口。
- 两端均出现同一片源的真实视频画面；证据：`/tmp/nastart-mtp01-clean-iphone/now.png`、`/tmp/nastart-mtp01-clean-ipad/now.png`，及对应 `controls2.xml`。iPad 控件树在约 `01:07`→`01:27` 继续推进，并识别到“暂停/音轨/字幕/1:59:25”。
- 本批次原定 t=3/10/30 截图因采集函数误把局部变量命名为 `path`，覆盖 shell 的 `PATH`，导致截图命令未执行；该批次因此只记为 `MTP-01` 部分证据，不能伪造为完整通过，需用修正后的采集脚本补齐时间点和双端控制/SA证据。

#### MTP-01 修正采集重跑

- 修正脚本后补齐两端 t=0/3/10/30 截图与 XML。iPhone 帧哈希：`4122d4a5...`、`d20f26cf...`、`eee6e11c...`、`6b05a580...`；iPad 帧哈希：`62be9af2...`、`3d88c402...`、`b016ed69...`、`170c10e2...`，均为非重复真实视频帧。证据：`/tmp/mtp01-retry-iphone-t{0,3,10,30}.png`、`/tmp/mtp01-retry-ipad-t{0,3,10,30}.png` 及同名 XML。
- iPad t=30 控件树明确为 `01:34 / 1:59:25`、按钮“播放”，并保留“音轨/字幕”控件；说明本次双端批次在 iPad 约 1 分 34 秒再次停播，`ST` 和 `MTP-01` 均失败。iPhone 本批次控制层自动隐藏，WDA 只返回“显示或隐藏播放控制”，该端控制项记 `TOOL`，不影响其帧推进证据。
- 当前 MTP-01 结论：`F`（iPad 长时停播），不是 WDA 采集缺失；应先修复 iPad 约 1:34 的 Range/播放器停播，再重跑 MTP-01，之后才进入 MTP-02/03。

### S01 · 128 MiB Range 窗口回归（2026-08-14）

- 修改：将 `AuthenticatedMediaProxyTransfer.maximumMediaSegmentBytes` 从 `32 MiB` 调整为 `128 MiB`，仍保持有限 `206` Range，未恢复会导致 Jetsam 风险的整文件 `200`。
- 构建/安装：构建日志 `/tmp/nastart-s01-range128-build.log`，产物 `/tmp/NastartS01Range128Derived/Build/Products/Debug-iphoneos/Nastart.app`；已安装到 iPhone `00008110-001E543122E0401E` 与 iPad `00008030-001168403C43C02E`，WDA 未重装。
- `PD-D`：启动后 t≈30 秒仍为真实画面；继续观察并显示控件后，进度已到 `02:31`，按钮为“暂停”，未再复现 32 MiB 版本在 `01:34` 的“播放”停播。证据：`/tmp/range128-ipad-t0.png`、`/tmp/range128-ipad-t30.png`、`/tmp/range128-ipad-mid.xml`、`/tmp/range128-ipad-mid.png`。
- `IP-D`：同一 128 MiB 包当前仍显示真实视频帧，证据 `/tmp/range128-iphone-now.png`；iPhone 控件树自动隐藏，控制项读取记为 `TOOL`，但不是黑屏/停播证据。
- 当前判断：128 MiB 已通过“跨越约 01:34 边界”的定向回归，但 `PA/SK/AT/SU/EX/MEM` 和 `SA=SUB/AUD` 尚未在该新包四单元完整补齐；不能据此直接把 S01 标记为通过，也尚未进入 S02。

### 2026-08-15 通用续段修复后的验证边界

- 源码修复不再继续放大某个样本的 Range 窗口：标准 `bytes=` 解析、每个上游窗口独立的交付计数/长度、精确偏移续段和连续 chunked 客户端响应已纳入统一策略；诊断脱敏也已修正 Bearer token 顺序。
- 自动验证：preflight 通过；`NastartTests` 15/15 通过；iphoneos Debug 最终签名包构建通过，包内 Nastart 二进制 SHA-256 为 `0e34e830097371fd19ac055c7301653dfc63cbdb99efae4f21302b82607f91d3`。
- 播放实验室验证：12 秒 H.264 fixture 在 20 ms 延迟/4 Mbps 条件下，`bytes=0-32767` 与 `bytes=32768-65535` 均返回匹配 `206`/`Content-Range`；`bytes=abc-` 返回 `416`，服务端日志记录了三次请求。
- 真机包已安装到 iPhone `00008110-001E543122E0401E` 与 iPad `00008030-001168403C43C02E`，未更新系统。WDA 已按标准 XCTest 链路恢复 iPad：`xcodebuild test` → XCTest runner → `iproxy 8101:8100 -u UDID` → `/status ready=true`；直接 `devicectl process launch` 仍只作为诊断，不能替代该链路。
- iPad WDA 恢复后已重新执行 S01 设备文件入口，证据 `/tmp/nastart-s01-wda-retry/t0.png`、`t3.png`、`t10.png`、`t30.png`：均为真实视频画面且内容变化。该证据只恢复了工具并证明首帧/持续渲染可采集，不改变 S01 四单元的完整功能验收状态。
- iPhone 的标准 Xcode 26.6 XCTest 通道仍报告 `DVTBuildVersion` 空值和 `Logic Testing Unavailable`，但已按历史路径恢复：正确 WDA Bundle ID `com.changliwen.nastart.WebDriverAgentRunner.xctrunner` 通过隔离 `pymobiledevice3 developer dvt launch` 启动，`iproxy 8102:8100 -u 00008110-001E543122E0401E` 后 `/status` 返回 WDA 16.1.5、`ready=true`；已建立 session `AB1C81CC-3053-4F4F-9EEA-DFBEA7E3645E`，完成 `/source`、`/screenshot`、设备页和文件页读取。该结果只恢复了工具，不改变 S01 四单元未签收状态。

### 2026-08-15 字幕漏检与通用传输崩溃回归

- **字幕漏检已复现。** 历史 S01 iPad 设备文件截图 `/tmp/nastart-s01-wda-retry/t10.png` 及裁剪 `/tmp/nastart-s01-wda-retry/t10-subtitle-crop.png` 确实包含方框/缺字；这不是“字幕按钮没找到”或单纯 WDA 问题。此前只验证了字幕控件、菜单和部分正常画面，漏掉了“逐帧检查每个可见字形”的硬门槛，原先把字幕重复路径修复写成闭环过早。
- **本轮先发现了真实 App 崩溃。** iPad 报告 `/tmp/nastart-ipad-crash/Nastart-2026-08-15-092108.ips` 的 faulting thread 位于 `AuthenticatedMediaProxyTransfer.urlSession(_:dataTask:didReceive:)`，栈落在 `Data.append`/`DataStorage.ensureUniqueBufferReference`；因此之前的长时采样会把“App 已退出”误判为 WDA/播放失效。
- **通用修复已落地。** `ios/Nastart/Nastart/Features/Devices/DevicesView.swift` 将 URLSession 回调中的单个可变大 `Data` 改为独立 `Data` chunk 队列，并按实际字节数 drain；没有增加 S01 专用视频参数。错误的 `.xcodeproj` 直编译曾漏掉 CocoaPods XCFramework 阶段，改用 `.xcworkspace` 后新包构建成功：`/tmp/NastartS01ProxyFixWorkspaceDerived/Build/Products/Debug-iphoneos/Nastart.app`。
- **新包 iPad 回归结果。** 包已安装到 `00008030-001168403C43C02E`；WDA `16.2.0` `/status` 返回 `ready=true`。S01 MKV 已重新播放，采样 `/tmp/nastart-ipad-proxyfix-play8.png`、`/tmp/nastart-ipad-current-after-controls.png`、`/tmp/nastart-ipad-proxyfix-sample-1.png`；字幕菜单明确显示“中文字幕”已选中，关闭菜单后 `/tmp/nastart-ipad-proxyfix-subtitle-complete.png` 的实际字幕帧为完整中文“莱蒂 口克蛋糕烤好了”，无方框/截断。播放约 8 分钟后 WDA 仍可用，新的崩溃报告目录没有出现 2026-08-15 09:21 之后的 Nastart 崩溃。
- **当前结论仍不是 S01 通过。** 新包已证明 iPad 当前路径具备真实播放和至少一个完整字幕帧，且未复现该 `Data.append` 崩溃；但历史 `t10` 方框样本尚未在新包中以同一时间点和字幕切换动作完成闭环，`PD-D.SUB` 暂记 `U/回归中`，`MEM` 也只完成短时无新崩溃观察。S01 四单元未签收，S02→S18 不启动正式推进。

## 单元记录格式

完成一项后补充：设备、入口、样本、实际链路、首帧秒数、源/播放器分辨率、设备方向与视频显示区域、正常宽高比留边或异常未铺满/拉伸/裁切、连续播放/卡顿、快进快退、暂停续播、字幕/音轨、`SA=SUB/AUD` 实际字幕与音频输出、清晰度（Jellyfin）、PiP（Jellyfin）、错误信息、截图或 WDA 日志证据路径。

发现问题时追加：问题编号、首次失败步骤、复现条件、根因、修改文件/方案、构建验证、当前样本回归结果、受影响范围和后续风险；未完成当前样本闭环前不得开始记录下一个样本为正式执行结果。
