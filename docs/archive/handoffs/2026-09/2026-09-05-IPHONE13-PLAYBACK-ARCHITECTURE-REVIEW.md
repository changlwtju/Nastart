# 2026-09-05 iPhone 13 播放链路修复与架构迁移门槛

本轮以 `551f7de` 为源码起点，在 iPhone 13 / iOS 16.3.1 上构建、安装并验证。属于首帧与引擎隔离专项，不覆盖既有 18×4 正式矩阵，不把 S03 专项结果填入尚未完成的 S01 顺序回归。

## 决策建议

研发主线聚焦新架构；旧架构暂时冻结为可运行的对照和回退，不再双线增加功能。现在不删除旧架构，也不据本轮结果切换 Release 默认路径。

新架构是统一的 source resolver / plan / IO / engine / tracks / diagnostics 合同，不等于所有内容都强制使用 KSPlayer。KSPlayer 负责复杂原文件的候选主路径，AVPlayer 继续承载系统兼容 HLS、PiP/AirPlay 等能力。旧 session、UI 和 fallback 决策不搬回新 coordinator。

当前不能删除旧架构的直接证据：新架构强制代理的 S03 已经能出画，但随后约 14 秒停滞；同设备同源旧 VLC 直连可以推进到 03:10。传输路径不同，因此这不是“VLC 比 KSPlayer 更好”的引擎结论，而是新链路尚未达到替代门槛。

## 已修复：新旧 FFmpeg ABI 混用

历史问题：FFmpeg 识别 `matroska,webm streams=12`，却报告 duration=0、bitrate=4051325618387248229，KSPlayer 最终 `tracks selected video=no audio=no all=[]`。

本轮检查历史设备包的 `Nastart.debug.dylib`，`nm -m` 明确显示：

```text
(undefined) external _av_read_frame (from MobileVLCKit)
(undefined) external _avformat_open_input (from MobileVLCKit)
```

Swift 使用 FFmpegKit 的结构体头文件，但这些调用被链接到了 MobileVLCKit 内部的 FFmpeg。不能继续把异常结构体数据解释成 Matroska 格式兼容问题或增加缓存参数。

修复内容：

- KSPlayer SwiftPM product 显式 `type: .dynamic`，在自身动态框架中完成 FFmpeg 链接。
- Nastart 工程显式嵌入并签名 KSPlayer.framework。
- 新增 `scripts/verify_playback_linkage.py`，检查嵌入、关键 FFmpeg 符号及禁止绑定 VLC 的条件；iPhone 安装脚本在安装前执行检查。
- DEBUG Greenfield Auto 对无需证书兼容处理的私网原文件不再强制增加本地代理；公网、证书兼容和 Force 原画实验保留代理。Release 调用不启用这个 DEBUG fast-start 标志。
- DEBUG playback-lab 支持 `NASTART_PLAYBACK_LAB_ARCHITECTURE=greenfield`；不传时保留 legacy 入口，便于同 URL 对照。
- 当前 Xcode 26 显式 PCM 构建出现 Libavutil/libavutil 相关缺失/失效模块错误。`xcodebuild_nastart.sh` 对整个调用设置 `SWIFT_ENABLE_EXPLICIT_MODULES=NO`，覆盖 SwiftPM target；可以由调用者后置 build setting 覆盖。不要依赖手工修改缓存目录中的 FFmpeg 头文件。

动态库声明使用 [SwiftPM 官方 library product API](https://docs.swift.org/swiftpm/documentation/packagedescription/product/library%28name%3Atype%3Atargets%3A%29/)。隔离效果以实际二进制检查和真机结果为准。

## 真机结果与口径

设备 UDID：`REDACTED-DEVICE-01`。WDA 复用已安装 XCTest fixture，未升级 iOS、未重装 WDA。安装包位于 `/tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app`。

### 本地 fixture：同一 MKV / 同一 HTTP Range 服务

使用仓库 generator 生成 45 秒 H264 640×360/30fps 动态画面，remux 为 MKV 并加入 48 kHz AC3 正弦音。大小约 3 MB，媒体码率约 0.568 Mbps。服务器 `scripts/playback_lab.py`，HTTP 206，局域网，无人工限速。交替重启 App，未清空 NAS/系统缓存；不称为全链路冷缓存测试。

| 路径 | 三次已有启动指标（ms） | 中位数 | 连续播放证据 |
|---|---|---|---|
| Greenfield / KSPlayer / directHTTP | 572 / 531 / 576 | 572 | 第一轮 30 秒 checkpoint；40 个遥测样本、stallSamples=0；实际画面 |
| Legacy / MobileVLCKit / sourceURL | 1049 / 956 / 1062 | 1049 | 第一轮 UI 00:36/00:45、实际画面；后两轮仅起播采样 |

新架构另有 MP4 fixture 712 ms、30 秒 checkpoint。MKV 轨道日志为 video=yes/audio=yes、duration=45，正常的 H264/AC3 参数。

这些数值是现有应用的启动指标：Greenfield 依据合理的播放时钟前进，VLC 依据 videoOutput + playbackClock。不是统一的屏幕合成器首帧测量；不同起点和回调频率也可能带来差异。因此不得据此发布“真实首帧提升 45%”或 P95 结论。

### S03《碟中谍3》约 54 GB / HEVC / 多音轨 / ASS

本轮最初公网地址 TLS 连接失败；后续 App 已使用可达的 NAS 局域网地址。以下数据都是局域网结果，不与 09-04 公网 Auto/HLS 的 7791 ms 直接比较。

| 路径 | Trace | 已有启动指标 | 连续播放 |
|---|---|---|---|
| Greenfield Force / localRangeProxy / KSPlayer | 76319584 | 1648 ms | **失败**：约 currentSeconds=14.068 停滞，32 个遥测样本中 16 个 stall 样本 |
| Legacy / sourceURL / MobileVLCKit | BA7A4820 | 1465 ms | 已观察推进至 00:50，随后 UI 03:10；不等于长播/完整功能验收 |

Force 新路径已成功识别 `streams=12`、duration=7524.768、正常码率，构造 HEVC/TrueHD/AC3/ASS/PGS 轨道并出真实画面。曾阻塞首帧的链接问题得到直接回归验证。

但代理传输记录显示：先探测文件头与尾部，随后从 259795 开始读取；第二个上游任务在累计 39175680 bytes 后结束，日志 result 为 NSURLErrorDomain -1005、retries=0，播放器稍后耗尽缓冲。当前日志不能严格区分上游中断和客户端 NWConnection 状态被映射成 -1005；下一轮必须补充 finish 来源和逐任务边界，不能仅凭此错误码认定 NAS 断流。

同时出现轨道一致性风险：计划选择 AC3 stream=2，KSPlayer track-selection 日志却显示 stream=4 enabled；需验证并修复 plan 到 runtime track 的映射。字幕和音频实际听测未闭合，不标 SA=P。t=10 截图有系统通知覆盖，仍可辨认视频，但不作为完整画面布局或字幕验收依据。

### 不同起播位置的补充结果

修改 Auto 路由之前，关闭 Force 的新架构仍被强制送入本地代理。Trace `DE5503CC` 从约 467 秒断点续播，启动指标 1832 ms，30 秒 checkpoint 通过，42 个遥测样本、stallSamples=0。这与从头播放的 `76319584` 不是同一起点，因此不用于宣称性能提升，也说明代理故障不能被描述为每次必现。

## 竞品参考的使用方式

以已有 [DS One 静态分析](../2026-08/2026-08-17-DSONE-STATIC-ANALYSIS.md) 和 [Lenna 静态分析](2026-09-01-LENNA-1.0.17-STATIC-ANALYSIS.md) 为证据：参考媒体源决策、独立 IO/cache/preload、按能力选引擎、轨道管理与系统播放能力的分层。它们支持新架构方向，但静态符号不证明某个片源的性能，也不能推出缓存/缓冲阈值。

竞品只在相同片源、编码、音轨/字幕、网络、设备、缓存状态和清晰度下做体验参照。重转码的更快首帧不能等同于原画更快；画质、持续流畅度、资源消耗必须一起报告。本轮没有新增竞品动态评分。

### 最终 DEBUG Auto 私网直连验证

最终构建将 Greenfield Auto 的普通局域网原文件恢复为已验证 sourceURL 直连，同时保留 Force 代理实验和实际 HTTPS 证书兼容代理。全局允许自签名证书不能让普通 HTTP 地址无条件进入代理。

Trace `9326BF97`：`directHTTP / directPlay / ksPlayer`、`experimentalOriginal=no`、`transport=sourceURL`，同样从约 467 秒断点起播。启动指标 **1599 ms**，30 秒 checkpoint 通过，55 个遥测样本、stallSamples=0；t=3/10/30/45 均保留原始截图和采样偏移。与上一条代理续播均为单次数据，不能据此宣称稳定的百分比收益；从头起播的代理故障也未因此解决。

最终构建与安装日志：`build-direct-auto-final.log` / `install-direct-auto-final.log`。证据：`mi3-direct-final-export.log` / `mi3-direct-final-report.json` / `mi3-direct-final-checkpoints.json` / `mi3-direct-final-t*.png`。

## 指标可信度的现有缺口

`ObservingPlaybackIOContext` 当前 read 返回空 Data，preload 只更新区间模型，没有真正读取媒体字节。因此它的 preload/cache 事件不能被用作真实缓存命中或吞吐证明。现阶段真实传输依据仍是播放器读取、代理逐任务日志和 HTTP 服务端证据。替代旧架构前必须补齐实际 IO 数据面，以及首帧呈现、轨道选择和播放计时的统一语义。

## 评测合同：速度、正确性和稳定性分开

以下补充既有 [18×4 功能矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md) 和 [调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)，不替代它们。数值目标先由同条件 baseline 建立；未测项保持 U，不用总分抵销硬失败。

| 维度 | 必须采集的指标/证据 | 判定重点 |
|---|---|---|
| 启动 | tap→resolver→route→HTTP首字节→probe→engineReady→首个实际视频呈现；成功率、P50/P95、失败/超时次数 | 建立统一 monotonic clock 和 request ID；首帧不能由尺寸、ready 或 seek 跳时钟代替。3 次只给中位数，不报可信 P95 |
| 连续播放 | 重缓冲次数/总时长/最长时长、播放期重缓冲占比、buffer ahead、实际进度与 wall time、异常结束 | 30 秒仅 smoke；代表格式再做 10–30 分钟长播和接近片尾/跨窗口检查 |
| seek | ±15秒、任意拖动、跨缓存/未缓存、接近片尾；松手→正确画面恢复；目标误差、音画恢复 | 同时测准确性和速度；不能用 seek 后时钟跳变冒充首帧 |
| 音视频正确性 | 实际选中源/引擎轨道 ID、语言、声道、音画同步偏差及漂移、音轨切换恢复 | 无声、错轨、失真、切换重头播放是硬失败；截图不证明有声 |
| 字幕 | ASS/SSA/SRT/PGS、内嵌/外挂、开关/切换、时间同步、完整字形、安全区域 | 重复、乱码、缺字、残留或裁切不能被首帧速度抵销 |
| 画质与渲染 | 源与输出分辨率、帧率、丢帧、HDR/DV/SDR映射、方向、比例 | 不靠降清晰度、软件解码或错误色彩换取速度；确认是否改变了输出品质 |
| 传输/弱网 | HTTP状态/Content-Range总长、每个任务请求/收到/交付字节、首字节耗时、重试、缓存命中、限速/断连恢复 | 精确字节续传，禁止整文件200、短EOF吞掉和无限重试；分开客户端取消与上游失败 |
| 资源 | 峰值/稳态内存、播放与退出后内存趋势、CPU/GPU、热状态/能耗、缓存磁盘上限、包体与启动成本 | Crash/Jetsam/无限缓存为硬失败；动态框架增加的包体单独量化 |
| 操作与生命周期 | 暂停恢复、倍速、后台/锁屏/打断、耳机/蓝牙路由、PiP/AirPlay、退出/恢复、连续下一集 | 状态、进度、轨道及音频路由都应保持符合产品定义 |
| 来源/格式覆盖 | iPhone+iPad、设备文件/Jellyfin、LAN/WAN、S01→S18、ISO/电视剧独立专项、双端并发 | 一部小 MKV 或单设备通过不推导全局通过 |

## 删除旧架构的阶段门槛（建议）

1. **现在：新架构主开发，旧架构冻结。** 保留显式 A/B 开关与独立引擎链接，优先解决首次出画、连续流、轨道映射和统一计时。新功能只进新合同。
2. **默认迁移：** 同一构建通过关键功能硬门槛和已有格式/设备/来源矩阵；代表样本多轮统计稳定，长播、恢复和资源指标无实质回退；回退路径可靠且可观测。先切换已验证范围，不把未支持格式静默纳入。
3. **删除旧会话/UI：** 新入口覆盖原来的全部必需能力，连续验证期间不再依赖旧会话恢复；在代码与测试中确认没有业务依赖旧路由/状态机。
4. **删除 MobileVLCKit 依赖：** 单独确认没有仍需 VLC 的格式/音轨/字幕/系统能力，再做依赖与包体清理。切换默认入口不等于可以立即删库。

## 本轮验证与证据

- 普通 wrapper Debug device build 成功；安装完成；实际 iPhone 播放通过引擎隔离验证。
- linkage verifier：旧 static 包按预期失败；新包通过。
- preflight 和 `git diff --check` 通过。未声称全量 XCTest、iPad、18×4、HDR/音画同步、听测、PiP或长时间能耗通过。
- 工作区私有证据目录：`tmp/playback-20260905/`（已加入本地 `.git/info/exclude`，其中 Preferences 含账户状态，禁止当公开附件提交）。
- 构建/签名：`build-final.log`、`install-fixed.log`、`linkage-before.txt`、`linkage-after.txt`。
- 对照：`fixture-runs.log`、`fixture-report.json`、`mkv-*-repeat*.png`、`mkv-legacy-after30.png`、`mkv-repeat-after30.png`。
- S03：`mi3-greenfield-export.log`、`mi3-force-report.json`、`mi3-legacy-export.log`、`mi3-*-checkpoints.json` 与 t3/10/30/35 截图；旧架构 `mi3-legacy-progress50.png`。

下一步把从头播放、断点续播和 seek 作为不同场景固定起点复测，优先补充逐任务结束原因并复现 14 秒停滞，再做轨道映射和统一首帧呈现计时。Auto 直连的续播 smoke 不替代代理修复，也不替代 S01 四入口、iPad 和后续格式族回归。不要回退已验证的动态链接隔离，或继续仅凭缓存大小推断根因。


## 10:05 续轮：代理结束来源与逐段证据

已在 `AuthenticatedMediaProxyTransfer` 补齐诊断，不改变窗口、超时、重试或连续响应策略：

- `finishSource` 区分 `clientCancelled`、`clientFailed`、`clientHeaderSend`、`clientBodySend`、`clientTerminalSend` 和上游回调；保留原始 `errorDomain/errorCode`，不再把 NWConnection 的取消/失败统一伪装为 `NSURLErrorDomain -1005`。
- 每个续段响应记录 `stage=continuationResponse`、Range、Content-Range、Content-Length 与累计接收字节。
- 每个上游任务完成记录 `stage=upstreamTaskCompleted`、`taskReceivedBytes`、`cumulativeReceivedBytes`、期望字节和错误。历史 `deliveredBytes` 实际是 URLSession 接收计数，不能当作已发送到播放器或已渲染字节。

iPhone 真机 Force 回归 trace `EB157F5B`，仍从约 467 秒断点开始：启动指标 1964 ms，30 秒 checkpoint 通过，t=3/10/30/45 有真实画面。末次导出遥测 48 个样本，stallSamples=0。

本轮首次把关闭与续段区分开：头部探测的短连接结束报告 `clientFailed/clientBodySend`（Network.NWError），尾部探测完整交付并 `clientTerminalSend` 完成；实际起播从 `3309116237` 开始，后续 Range 起点依次为 `3342670669`、`3376225101`、`3409779533`、`3443333965`，每段 33554432 bytes，收到的 206 总长保持 `54005939750`，前几段完成无上游错误。该证据证明这一轮的续段正常，**不证明从零起播的 14 秒停滞已修复**，也不能反推历史 -1005 的真实来源。

证据：`build-proxy-provenance.log`、`install-proxy-provenance.log`、`preflight-provenance.txt`、`proxy-provenance-decoded.log`、`provenance-force-export.log`、`provenance-force-report.json`、`provenance-force-checkpoints.json`、`provenance-force-t*.png`，均在上述私有证据目录。普通 wrapper 真机 Debug 构建、安装、linkage verifier 和 preflight 通过。

下一轮必须固定从零与断点两个起播位置分别复测，再定位客户端何时停止读流、暂停/取消上游及解码读线程状态。既有 stream=2 与 runtime stream=4 的音轨不一致、字幕与听测缺口仍未解决。
