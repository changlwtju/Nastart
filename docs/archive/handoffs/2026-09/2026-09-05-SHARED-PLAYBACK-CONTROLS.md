# 新旧架构共用播放控制界面 — 2026-09-05

当前限制：用户明确 NAS 外网访问异常，本轮仅使用局域网。内网 Jellyfin `192.0.2.2:8096` 可达；外网 Wi-Fi/蜂窝测试保持待测，不尝试公网端点。

## 实现范围

撤销上一轮简化的 Greenfield 控制栏，把旧 VLC 播放界面抽成 `SharedBuiltInPlayerView`，通过 `PlaybackUIEngineSession` 接收播放状态和操作。旧 VLC 与新 KSPlayer 共用原控制栏、设置/音轨/字幕/清晰度面板、静音、锁定、方向和亮度手势；增加双击暂停/继续以及 KSPlayer 的适应/裁剪铺满。

Greenfield bridge 保留原始 `MediaPlaybackRequest`，接回轨道、清晰度和服务端 seek 请求 loader；原始直播放流优先按实际轨道 ID 原位切换。异步重新选流可取消，失败不替换当前会话。重建会话保留暂停意图，重置首帧/30 秒诊断状态；进度接回原 `MediaPlaybackTracker`。这些接口接回不等于已通过全部功能验收。

原生 AVPlayer 分支目前仍使用系统 VideoPlayer，其完整控制能力统一、HLS 清晰度/绝对时间线、PiP 往返和退出续播仍需专项回归，不能声明新架构基本功能全部完成。

## 真机发现与修复

1. 共用控制层使用请求 ID 时，DEBUG lab 的父视图刷新会产生新 ID，导致连续重复打开解码器。已固定 Greenfield 会话请求，后续 fixture 启动仅一次 open。
2. 文本字幕 `isEnabled` 表示持续解码缓存，并不表示当前呈现轨道。按它找字幕会一直选第一条英文。改按 `SubtitleInfo.subtitleID` 选择；切换/关闭时清除旧轨道 cue，并立即刷新暂停画面的字幕。真机已看到英文→中文→关闭，播放位置保持 00:04。
3. KSPlayer 暂停时没有周期播放回调，seek 成功后 UI 仍停在旧时间，下一次反向拖动从旧时间计算。改为 seek 完成后读取引擎真实 currentPlaybackTime 刷新；使用 generation 防止过期完成回调覆盖新操作。音轨菜单同样立即读取实际轨道 inventory。已验证 00:04 → 00:39 → 00:11 且保持暂停；进一步发现第二次 seek 的显示帧未刷新，在 KSPlayer 的解码容量回调中补充一次性目标帧呈现，后续截图已确认反向 seek 的画面更新。

## 专项证据与验收纪律

设备 iPhone 13 / iOS 16.3.1，Debug，KSPlayer dynamic framework；fixture 为局域网 Mac 提供的 90 秒 H264/双 AC3/双 SRT MKV。双音轨使用同一音频内容，只能验证轨道选择，不能据此完成 AUD 听测。

私有证据目录 `tmp/playback-20260905/`（不入 Git）：

- `shared-final-interactions.json`、`final-*.xml/png`：字幕修复构建的交互证据。
- `shared-final-export.log`、`shared-final-report.json`：导出的持久诊断及解析；lab 的 traceID 为 `-`，解析器会混入历史决策，必须用 planID 精确核对，不能采用混入的传输结论。
- `build-shared-controls.log`、`install-paused-seek.log`：当前构建/安装。
- `test-seekfixed.out`：暂停 seek 修复回归，待补最终结果。

已观察：双击暂停后 3 秒进度维持 00:04；恢复后的播放时钟推进。首帧的 clock 指标与实际可见帧仍分开；轨道按钮选中、seek 完成回调或一张截图不能独立判定功能通过。

正式 18×4 表仍未更新为通过。按 S01→S18 顺序执行，核心 `LIB/FF/ST/PA/SK/AT/SU/Q/PP/EX/MEM` 和补充 `SUB/AUD` 分开记录。缺少 iPad、听测、PiP 或网络条件时保留 U/NA/TOOL，不把专项 fixture 的结果填入电影单元。

## 验收统计修复

日志检查发现，原实现把 `bufferFinished` 也当成 buffering，且会把主动暂停时间混入卡顿统计；已改为明确状态匹配，并在恢复时重置进度基准。连续 30 秒 checkpoint 原来只检查媒体时间是否超过起点 30 秒，seek 会提前触发；现在按连续推进的实际时间累计，暂停、缓冲、seek 和不连续时钟均重置累计。

DEBUG lab 缺少 traceID 时现在生成独立 ID，避免离线报告关联到历史 Jellyfin 决策。修复前 `D2DA4F63` 轨迹的 1 个恢复卡顿样本与过早 checkpoint 不用于通过判定；仅保留为发现问题的证据。

当前统计修复构建：`build-metrics.log` / `install-metrics.log`，正在跑 `test-metrics.py`；最终结果随后补充。

## 统计修复构建最终专项结果

独立 trace `CF91F361` / plan `3A56A227`，LAN directHTTP / KSPlayer：

- 暂停双击保持时间不变；连续两次横向拖动为 39.329 秒和 11.329 秒，两个 seek 请求各对应一个成功恢复。引擎完成+时钟恢复分别为 78/298 ms；这些数值不是显示合成器呈现延迟。
- 恢复播放后的 30 秒 checkpoint 在 resumed 事件后 30.012 秒触发；38 个遥测样本，stallSampleCount=0，无 playbackFailed。
- 当前 clock 首帧指标 578 ms，未取得同条件的新一轮旧架构多次对照，因此不声明本轮首帧提升。
- `metrics2-export.log` / `metrics2-report.json` / `shared-metrics2-interactions.json` 保存最终证据。报告已使用独立 trace，不再混入历史来源/决策。
- 同构建完成了 Debug build、preflight、动态链接校验和 diff whitespace 检查。未声称全量 XCTest 或正式矩阵通过。

字幕与完整控件的前一轮真实画面证据为 `preview-english.png`、`preview-chinese.png`、`preview-subtitles-off.png`，对应暂停位置不变；音轨 B 的选择同时读取引擎 inventory。`preview-seek-back-paused.png` 确认反向 seek 的显示画面已更新。

## 20:13 继续：LAN S01

仅 iPhone 在线，WDA 恢复后手机地址为 192.0.2.4。Jellyfin App 页面确认访问地址仍为局域网 192.0.2.2:8096；媒体搜索找到 S01《哈尔的移动城堡》，H264 688p / AC3 5.1，正在执行当前构建的 Greenfield Auto 启动专项。

旧 VLC 共用 UI fixture 回归：双击暂停后 3 秒时间维持 00:04；后续自动化请求 HTTP 400 中断。暂停 seek 的旧 VLC 进度尚未更新，保留未完成，不据此宣称旧路径全功能回归通过。证据 `test-legacyshared.out`。

S01 LAN 启动/持续专项 trace `986845B5` / plan `EAAE8D07`：KSPlayer directHTTP/sourceURL，clock 启动指标 1327 ms；36 遥测样本、stallSampleCount=0、无播放失败，时间推进到 36.660 秒，30 秒 checkpoint 已记录。真实画面保存 `s01-lan-t3/10/30/35.png`；日志 `s01-lan-export.log` / `s01-lan-report.json`。控制栏有音轨、字幕、清晰度和 PiP；仅入口存在不代表对应功能通过。暂停在约 00:57 后正在验证 Auto→原画重新选流，尚未完成 S01 全项。

S01 清晰度回归发现待修复项：暂停于 57.652 秒后 Auto→原画触发新 trace `D171C7BA` / plan `3A90D663`，路由仍为 LAN directHTTP/KSPlayer；重建后显示 00:57 且保持暂停，但恢复约 3 秒再暂停读到 56.628 秒，未满足从相近位置向前推进的预期。Q 不判通过，暂停 S01 后续样本推进。优先检查初始 startPlayTime、readyToPlay 中暂停 seek 与初始音轨选择触发的内部 seek 顺序，不能只凭重建后 00:57 截图判成功。证据 `s01-quality-export.log`、`s01-quality-original.xml/png`、`s01-quality-resume.xml`。

## 2026-09-06 初始定位修复

已将原始音轨 ID 通过 KSOptions.wantedAudio 映射为引擎音轨列表序号，在 createCodec 时选中，避免 ready 后切换音轨触发额外 seek。另修复 startPlayTime 路径遗漏 accurate-seek 解码边界：demux 初始定位成功后对全部 decoder track 设置目标丢帧边界，避免恢复后输出目标前的关键帧。

Debug build、preflight 和动态链接校验通过，已安装 iPhone；本轮继续 LAN S01 的暂停→原画→恢复回归，结论待实际日志验证。


### 启动边界修复的首轮失败及修正

09:34 首轮初始定位修复触发真实崩溃，不能算质量切换通过。`Nastart-2026-09-06-093429.ips` 显示 `AsyncPlayerItemTrack.seek(time:)` 断言：启动阶段尚未创建 `decodeOperation`，不能调用交互 seek。已为 track 增加 `prepareInitialSeek(time:)`，启动阶段只设置 accurate-seek 丢帧边界，保留交互 seek 的队列 flush 流程。

修正构建 `build-initial-boundary.log` 已成功安装（`install-initial-boundary.log`），preflight、FFmpeg 动态链接隔离校验通过。首轮截图实际为系统主屏，原始日志停于 8.116 秒暂停，未错误计入通过。继续同一 S01 LAN 回归。


### 09:41–09:46 S01 LAN 实测结果

- Auto→原画：暂停 seek 至 147.413 秒，切换 trace `375F8556` / plan `9F73ECDE` 后保持暂停；恢复首次推进 147.508 秒，再暂停为 152.969 秒。实际画面同步更新，未复现倒退。
- 原画→Auto：暂停反向 seek 至 57.435 秒，切换 trace `FDFA3929` / plan `F618B94C` 后恢复首次推进 57.524 秒，32 秒后暂停为 90.377 秒。此段 34 遥测样本、stallSampleCount=0，无 playback failure。证据 `boundary-final-export.log` / `boundary-final-report.json` / `boundary-repeat-*.png`。
- 两轮均保持 LAN directHTTP/KSPlayer/sourceURL。新启动 trace `715C1834` 的 clock 启动指标 1033 ms；切换轨迹的 5519/5362 ms 包含人为保持暂停的时间，不纳入启动性能比较。音轨 inventory 确认为请求 ID 1，但未完成听测。
- PiP：09:43:01 请求小窗，随后通过 home 按键回主屏，小窗有持续变化的实际画面，再用小窗返回按钮回 Nastart 全屏继续播放；最后暂停时间为 268.382 秒。证据 `s01-pip-request.png`、`s01-pip-background.png`、`pip-controls.png`、`pip-returned.png`、`pip-final-export.log`。初次 homescreen API 返回 500，改用 WDA pressButton home 完成；不把工具错误算播放失败。尚缺 PiP 音频听测与内存评估，因此不把整个 PP/MEM 单元判全通过。
- 57 秒切换后第一段 32 秒未发出 continuous checkpoint；随后恢复播放在 09:43:29 发出。发现连续统计会在重复时钟回调时清零，已改为短于 2.5 秒的重复回调保留上次推进采样；停滞超过阈值或倒退仍清零。该统计修正构建已成功，需继续真机核对。

仍只完成 S01 的局域网专项。Q 的 Auto/原画保位子项已取得正向证据，HLS 画质切换、完整 AT/SU/AUD/SUB/EX/MEM，以及旧架构同条件对照和 S02–S18 尚未全部完成，18×4 矩阵不整体改为通过。

### 2026-09-06 13:19 续测：连续计时与首帧指标单位

恢复 WDA 后 iPhone LAN 地址为 192.0.2.5，NAS 健康检查仍为 LAN 192.0.2.2:8096。未使用外网或蜂窝网络。

- 连续统计修正构建实测：S01 Greenfield Auto（Force original 关闭），trace `E0D827CD` / plan `D8635ECF`，KSPlayer / directHTTP / sourceURL。13:20:30 首次时钟推进，13:21:00 产生连续 30 秒 checkpoint，13:21:05 暂停于 35.188 秒；暂停前 34 遥测样本、0 stall 样本、无 playback failure。证据 `continuity-current-export.log`、`continuity-current-report.json`、`continuity-current-t3/10/30/35.png` 和暂停 XML。该结果补齐上一轮因 WDA 503 中断的统计验证。
- 同条件旧架构单次对照：trace `5B6EEA72`，MobileVLCKit / sourceURL / LAN，13:22:02 ready，13:22:37 暂停，UI 00:35；日志启动指标 1190 ms，信号 `videoOutput+playbackClock`。新路径本次 1135 ms，信号仅 playbackClock。采样口径不同、各只有一次，不能据此声明性能提升；旧路径也没有新路径同等的 stall 遥测，不能填 0。证据 `legacy-current-export.log`、`legacy-current-t3/10/30/35.png`、`legacy-current-paused.xml`。
- 发现并修正首帧指标单位错误：coordinator 的 `firstFrameMs` 实际写入媒体位置秒数（例如 0.222 或 147.508），报告错误命名为 rendererFirstFrameMs，并可能由此推断渲染前耗时。现在日志输出 `firstFramePositionSeconds` 和 `firstFrameSignal=playbackClock`；报告按秒兼容读取历史字段，未测得的 renderer latency 保留 null。首帧仍缺显示合成器测量，不将时钟推进冒充可见首帧。
- 新增 `scripts/test_playback_trace_report.py` 三项回归，覆盖历史字段不会导致快速渲染误判、续播位置单位、缺失测量保持未知。3/3 通过；`build-first-frame-units.log`、preflight、动态链接隔离校验通过，`install-first-frame-units.log` 已安装。继续采集本构建暂停→保持→恢复后的连续统计与新字段。

下一优先项仍为 S01 全功能：HLS/AVPlayer 路径尚未共用完整播放控制、HLS 切换保位和暂停意图、真实音频输出、退出续播与 MEM；随后按顺序推进其他样本。当前 directHTTP 专项不能替代有限上游 206 / 连续 proxy 的传输验收，也不能替代四入口与三类网络条件的完整矩阵。

本轮最终安装构建回归：trace `D45A3FF7` / plan `0DF7ACD9`，S01 LAN Greenfield Auto / KSPlayer / directHTTP。新日志字段实机确认 `firstFramePositionSeconds=0.073`、`firstFrameSignal=playbackClock`、tapToFirstFrameMs=1107；报告 rendererFirstFrameMs=null。暂停于 5.108 秒，两次 UI 读取均为 00:05；恢复时钟恢复 100 ms，恢复事件后 **30.009637 秒** 才产生 continuous checkpoint，最后暂停于 37.812 秒。37 个遥测样本、0 stall 样本、无 playback failure。已对持久日志断言 checkpoint 在恢复后 30–32 秒、新字段单位及无失败，全部通过。证据 `units-final-export.log`、`units-final-report.json`、`units-interactions.json`、`units-*.xml`、`units-final.png`。暂停实际持续约 10.987 秒（含 WDA 查询耗时），不按脚本 sleep 3 秒冒充真实暂停时长。

设备停留在 S01 新架构播放器暂停状态。未完成项和矩阵边界沿用上段，不将本次专项验证扩大成全功能通过。

### 2026-09-06 架构入口收敛（用户已决定）

后续执行以 [ADR 0002](../../../adr/0002-single-playback-optimization-mainline.md) 为准：集中优化新架构，旧架构仅作回退与关键对照，验收完成后删除旧架构及选择器。Jellyfin、设备文件、直接链接共用“新架构 / 旧架构”两项选择器；默认新架构并保存主动选择，移除 Force original UI 和偏好读取。原始流/代理/HLS 为内部路由分支，不再作为第三种架构操作。

`build-architecture-picker.log` 构建成功，preflight、动态链接隔离与 whitespace 检查通过；`install-architecture-picker.log` 已安装 iPhone。WDA 旧 session 404 后重建会话成功，S01 LAN 实测旧架构 trace `736C16ED` 确认为 MobileVLCKit，随后新架构 trace `661E6499` 确认为 KSPlayer/directHTTP；两者均启动并暂停于 UI 00:05。最终返回详情页且持久偏好为新架构。证据 `picker-detail.png`、`picker-*.xml`、`test-architecture-picker.out`、`picker-export.log`。此次为入口/回退冒烟验证，不替代完整播放矩阵；另外两个入口使用相同组件并通过构建，未声称本轮逐一真机操作验证。

### 2026-09-06 新架构 HLS 共用控件与时间轴修正（续测中）

工作区已有 AVPlayer 共用 `SharedBuiltInPlayerView`、独立 AV/KS 控制适配状态、AVPlayerLayer/PiP、初始 seek 完成后恢复播放或保持暂停、音字幕选择与绝对时间 seek 的实现。此前 `build-av-preroll.log` 已安装，但不能把实现存在视为验收通过。

本轮复测发现真实内容与显示时间不符：S01 KS 暂停约 49.958 秒后切换 HLS，界面保持 00:49；恢复约 4 秒后显示 00:54，但实际画面出现开头 Walt Disney 字样。trace `03E94C7C` / plan `7A402D3A` 中 AVPlayerLayer readyForDisplay 和 paused preroll 均完成，因此不能仅凭 ready 或时间文字判断保位成功。证据 `preroll-current-paused.png/xml`、`preroll-resumed.png`、`preroll-current-export.log`。

根因是新适配器沿用了旧请求中转码起点的 offset，把 Jellyfin VOD HLS 当成裁切后的流：seek 到 raw=0，再人为加起点显示。Jellyfin 官方客户端 [playbackmanager.js](https://github.com/jellyfin/jellyfin-web/blob/master/src/components/playback/playbackmanager.js) 在 HLS 分支保持 transcodingOffsetTicks=0，仅在非 HLS 且不保留时间戳的转码分支设置偏移。本次新架构修正为 Jellyfin m3u8 使用绝对时间 seek/显示，保留请求起点供初始定位使用；旧架构代码不随此修改。

另修正 AV 遥测：主动暂停时即使 bufferEmpty 也不计 stall，进入 playing 时重置推进基准，避免把暂停时间判成恢复卡顿；实际 waiting 状态仍保留记录。此前 `av-first-final-report.json` 的暂停空缓冲样本不能用于稳定性通过判断。

`build-av-hls-timeline.log` 构建成功，preflight 和动态链接隔离校验通过，`install-av-hls-timeline.log` 已安装。接下来对约 95 秒切换前后画面、保持暂停、恢复 32 秒和反向 seek 进行同机 LAN 验证；本段不提前声明 Q/SK/ST/PP 通过。

HLS 时间轴修正首轮：trace `C1FBB5AA` / plan `F7FD4922`，S01 LAN，KS 暂停 seek 到 95.150 秒后切 HLS，AV raw clock 也定位 95.150 秒，显示 01:35 并保持暂停；恢复推进至 127.847 秒，连续 30 秒 checkpoint 已记录，暂停后反向 seek 为 112.846667 秒（请求 112.847322，恢复 145 ms）。32 遥测样本中 1 个 waiting 样本（恢复阶段 evaluatingBufferingRate），accessLogStalls=0，无 playback failure；主动暂停空缓冲样本 stallActive=no。不得把此结果写成 0 等待或将含人工暂停的 11949 ms 纳入冷启动比较。证据 `hls-timeline-export.log/report.json`、`hls-timeline-*.png/xml`。

画面验收仍有未关闭项：切换前后的 01:35 截图场景不同（KS 为帽店，AV 为火车街景），不能只凭相同 clock 判精确保位通过。后退 15 秒后的 AV 画面已更新。HLS→Auto 切回 KS 后界面仍显示前次 KS 的 01:35，而不是当前 HLS 的 01:52，发现 KS 控制适配器未在新 plan 建立时刷新初始时间，暂停状态又缺连续 tick。已补 plan start/duration 初始化及暂停初始 seek 完成后的 engine clock 刷新；`build-cross-engine-clock.log` 构建成功、preflight/链接隔离通过，正在安装复测。精确画面位置还需独立对照，不提前关闭 Q。

最终安装构建回归（`build/install-cross-engine-clock.log`）：KS 启动 `EB947DBD` clock 885 ms；HLS `0572B289` / plan `4C9F93EB` 保持 01:35 暂停，恢复至 02:07，反向 seek 请求 112.663733 秒、实际 112.663333 秒，91 ms engineCompletionAndClock 恢复。34 个 HLS 遥测样本含 1 个恢复 waiting 样本、accessLogStalls=0，无 playback failure，并产生连续 30 秒 checkpoint。切回 KS `81F1B1CE` / plan `C5EFD246` 后现在显示 01:52 且保持暂停，恢复后推进到 116.212 秒 / UI 01:56，旧控件时间残留已复测消失。含人为保持暂停的切换 firstFrameMs 不作启动性能结论。

最终证据：`cross-final-export.log/report.json`、`test-cross-final.out`、`cross-final-*.png/xml`。注意脚本最初仍写入 hls-timeline 图片前缀，首轮同名视觉文件被覆盖，已把最终轮文件复制到 cross-final 前缀；两轮导出日志未覆盖，不将这些图片错误归属首轮。

仍未关闭：相同时间位置在 KS 与 AV 的画面有可见差异（01:52 AV 女子进门，KS 帽店近景），需要独立核对源帧 PTS/分段定位和暂停 preview，Q 精确内容保位不判 P。另发现跨引擎恢复的 pauseDurationMs 还沿用前次 KS 暂停时间（82 秒），需重置会话交互计时；不能把它当本次人为暂停时长。下一步集中解决这两项，不扩展旧架构优化。AV PiP 完整往返、听测、字幕/轨道与 MEM 等仍需按矩阵补测。

### 2026-09-06 15:28 新架构跨引擎会话计时修正

遵循 ADR 0002，仅修改新架构。GreenfieldPlaybackControls 新增 beginSession：在每个 KS/AV plan 接入时清空之前的 pause/resume/seek 计时，增加 seek generation 使旧回调失效；disconnect 同样使 pending seek 失效。替换时保持暂停的计划从本计划接入时间计算暂停段，不再复用同一适配器上一次 KS 会话的暂停起点。AV startsPaused 在接入控件后才清除，避免丢失初始化暂停意图。

`build-session-timers.log` 构建成功，preflight、动态链接隔离与 whitespace 检查通过；`install-session-timers.log` 已安装 iPhone。实际 S01 详情为继续观看，本轮不固定使用此前 95 秒起点。

- 初始 KS trace `70D64EE5` / plan `57404997`：暂停 416.137 秒，6 次 +15 秒到 506.137 秒。
- HLS trace `543CAAB3` / plan `DBB89377`：保持 08:26 暂停，恢复后到 538.501 秒并产生连续 30 秒 checkpoint；反向 seek 目标 523.773744 秒、clock 523.773333 秒，恢复 145 ms。34 遥测样本，1 个恢复 waiting 样本，accessLogStalls=0，无 playback failure。恢复 pauseDurationMs=11427、resumeRecoveryMs=525。
- 切回 KS trace `59F0A45F` / plan `F15A2409`：保持 08:43 暂停，恢复至 527.316 秒 / UI 08:47；pauseDurationMs=9493、resumeRecoveryMs=200。6 遥测样本、0 stall 样本、无 playback failure。根据事件精确时间减去 pauseDurationMs 与 resumeRecoveryMs，断言两个替换计划的暂停起点均位于各自计划事件范围内，且不包含之前 KS 暂停段，断言通过。

证据：`session-timers-export.log/report.json`、`test-session-timers.out`、`session-timers-*.png/xml`。本次暂停时长定义含新计划准备期间的保持暂停时间，不等同于脚本 sleep 时长，也不是首帧耗时。

Q 内容保位仍有阻塞：506.137 秒切换前 KS 画面为木箱，切换后 AV 为木箱前两位人物，同一时钟的画面不一致。系统 syslog 本轮未采到可用 KS 解码 preview PTS，不能宣称已排除解码/预览或分段定位问题。下一步需要原始流参考帧及实际输出帧 PTS 的独立证据，区分 KS 暂停预览与 HLS 分段映射；不能把时钟一致或 readyForDisplay 当作内容保位通过。没有修改旧架构，没有扩大矩阵通过范围。设备最终停留在新架构 KS 播放器暂停状态。

### 2026-09-06 帧 PTS 定位与精确 demux seek 修正（验收中）

沿 ADR 0002 新架构主线继续。新增 KSOptions.videoFrameSubmitted 回调，在 MetalPlayView 向显示层/Metal 提交帧后通知；App 按 plan 记录首个提交帧和 forced preview 的 PTS，标记 evidence=rendererSubmissionNotPresentation，不把提交等同于 compositor 显示。无逐帧持久日志，仅首帧和预览帧。

`build/install-frame-pts.log` 实机 trace `610D656C` / plan `1349AEE7` 独立揭示偏差：连续暂停 +15 秒后，controlSeconds=543.340/558.340/573.340/588.340/603.340/618.340，而实际提交 framePTSSeconds=545.410/560.325/573.939/594.092/607.105/621.386。由此不能再把这些暂停预览判为内容保位通过；其中最大提前 5.752 秒。证据 `frame-pts-export.log`、`frame-pts-*.png/xml`、`test-frame-pts.out`（该诊断轮 HLS 恢复仅等待 4 秒，文件名 after32 不表示 32 秒持续验收）。

发现 avformat_seek_file 的时间范围允许目标之后的关键帧，accurate-seek 解码丢弃边界无法修正已经跳过的目标内容。修正初始和交互精确 timestamp seek：max_ts 限制为目标，min_ts 放宽至 Int64.min，保留字节 seek 分支；交互 timeStamp 直接按目标秒数换算微秒，避免整数秒截断。`build-accurate-demux.log` 成功、preflight/动态链接隔离通过，`install-accurate-demux.log` 已安装。当前继续 S01 同场景帧 PTS 与画面回归，暂不关闭 Q。

精确 demux 修正最终实机结果（同一已安装构建）：

- 初始 KS `AE8DA96A` / plan `7C3454A9`：初始 607.936665 秒预览 PTS=607.906；六次暂停 +15 秒目标 627.745–702.745，提交 PTS 偏差分别 -19/-4/-23/-8/-26/-11 ms。
- HLS `F9DD21A6` / plan `49A6EF0D`：保持 11:42 暂停，恢复 32 秒后产生 continuous checkpoint，后退 15 秒至 720.441667 秒。33 遥测样本、1 个等待/卡顿样本、accessLogStalls=0，无 playback failure；不写成 0 等待。
- 返回 KS `0C6F59DF`：初始目标 720.441667 秒/PTS=720.418，保持暂停后恢复推进。再执行三次暂停 -15 秒，目标 708.988/693.988/678.988，PTS=708.974/693.959/678.977。6 遥测样本、0 stall 样本、无 playback failure。
- 对两个 KS 计划全部 11 个提交预览帧做断言，PTS 与目标控制时间最大绝对差 30.665 ms，均低于 23.976 fps 的一帧时长。此前 2–5.752 秒提前的暂停 seek 偏差在本轮正向、反向与初始定位采样中消失。证据 `accurate-demux-final-export.log/report.json`、`test-accurate-demux.out`、`accurate-demux-*.png/xml`。

Q 精确内容保位仍不判通过：对比切换前 KS 702.745 秒和 HLS 同时钟画面，均为同一房间老妇人，但姿态/取景不同。KS PTS 已收敛并不证明 HLS 输出内容正确；下一步优先取得 HLS 实际输出帧 PTS/源帧对照，区分 HLS 分段时间映射与 AV 暂停 preroll 的显示。不要回到仅检查 UI 时间或 readyForDisplay 的验收方式。当前只改新架构 KS 精确 seek 和必要观测，没有扩展旧架构优化。

最终 preflight、3 项报告回归、动态链接隔离、构建安装及 diff whitespace 检查通过；未运行/宣称全量 XCTest 或四入口矩阵通过。手机停在新架构 KS 暂停 11:18。


### 2026-09-06 HLS 输出与独立源帧诊断（继续中）

AVPlayerItemVideoOutput 在 DEBUG 下绑定到当前 item，初始/交互 seek 与 paused preroll 后限时采样，记录原始 clock、输出 PTS 与 UI 时间；保留系统渲染，采样结果明确不代表 compositor 呈现。任务绑定 item 与 seek generation，stop 取消。

trace `6F6709B2` / plan `0BF0AB97`：HLS 初始目标/clock 1057.026667 秒，输出 PTS 1057.022597；反向 seek clock 1046.665 秒，输出 PTS 1046.645585。独立 Mac FFmpeg 使用相同 LAN 原始流提取 1057.026667 秒参考帧，与 KS 图像内容一致；HLS 同时钟显示的稻草人近景在源 1053–1054 秒附近，仍有数秒内容偏移。证据 `av-output-final-export.log`、`av-output-pts-*.png/xml`、`source-reference-1057.png`、`source-reference-grid.png`。继续核对实际 HLS 分段，不加样本专用固定时间补偿。

源文件探测补充：H.264 1280×688，起始时间 0，名义帧率 **29.97 fps**；前段一帧阈值采用 23.976 不准确。此前最大 30.665 ms 仍低于 29.97 fps 的 33.367 ms，但后续以实测源时间基与帧 PTS 为准，不继续沿用 23.976 假设。
