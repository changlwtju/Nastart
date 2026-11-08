# AVPlayer 连续缓冲输入修复

状态：输入修复已实施，双机短窗回归和失败取证已收尾；完整播放验收继续开放。接续 [媒体库补测](2026-10-08-MEDIA-LIBRARY-COMPLETION.md)。

## 本轮变更卡（修改前）

- 问题/关联：PX-01/PX-03，AVPlayer 接手读不到连续储备；独立诊断的未来区间回退可能高估储备。
- 基线：HEAD 4de732dd645b36671becff992cdef1d0163fd1e4，iOS diff256fd7a，普通 e8ef/d283/KSeda1。保留所有其他未提交修改。
- 证据：旧最新99F84087请求availableReserve=unknown，前一诊断1.266秒而候选lead11秒；connectAVControls未设置readRuntimeTelemetry。候选232kbps/500kbps需求及iPad首段-12889另留，不把此次输入修复解释为全部根因。
- 共用规则：只统计包含当前item时间、相接或重叠的区间，不跨洞。有效区间但当前位置未加载=0，无有效范围/时间/item=unknown。诊断与AV回调共用规则，采用item时钟不叠加绝对内容偏移。
- 最小修改：一个纯规则，AV回调连接bufferedAheadSeconds、诊断复用；不添加AV码率/需求估计，不改变提前量、缓冲、seek、连接/超时/重试常数。
- L0：连续/无序/重叠/洞/缺失/非法时间和lead反例；核心及非播放XCTest、preflight、正常设备构建/签名/输入/linkage。
- L1：原13蜂窝S03 HLS接手场景、另一HLS片源与两机S01四单元；正常包空环境实际回归，未触发分支时保留未验。
- L2：S01/S03/S08两设备/两入口及相关功能。未触发L3，无传输窗口/超时/解码模式改动。旧失败/缺失证据不能由短窗覆盖。
- 成功：实际AV回调输入已知连续储备，候选lead不超现有规则边界；gap=0，未知保持未知；两机正常启动/播放及退出不退化。首帧口径分UI请求/内部时钟/实际画面，不设事后速度胜负。
- 执行结果、包身份、时间、回退点与未完成项：见下方本轮执行结果。

## 执行结果（2026-10-08 18:19）

本次先发现并接续 13:55～14:xx 留下的实施/未收尾验证，没有重做或覆盖其他未提交修改。新增的三处播放源码变更为连续缓冲纯规则、AVPlayer 的 `readRuntimeTelemetry` 回调和独立诊断复用；四项测试覆盖相接/重叠/无序区间、洞/过去/未来范围、未知/非法输入、item 时钟与内容偏移及接手提前量。未改变供流、缓冲、seek、超时、重试或质量阈值，未加入 AV 需求码率估计。

### L0 与安装身份

- HEAD：`4de732dd645b36671becff992cdef1d0163fd1e4`，iOS 全部未提交差异 SHA-256：`fa2029aaa4caed35873f90e9bb2f5182d60e5054120a476202b00098924564a4`。保留全部现有修改，未提交/推送 Main。
- 普通配置：`normal Debug -Onone; empty launch environment`；构建时间：`2026-10-08T13:59:14.648804+08:00`；所有正常启动请求为空环境/空参数，不是性能构建或注入测试条件。
- 包路径：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-07-083328-dual-entry-session/network-background-profiles-175119/av-reserve-handoff-20261008-135520/Nastart-AVReserve-Normal-Debug.app`。
- 主二进制 SHA-256：`74a645e4373f3f1f401d8e24d5f59f76620f3ca85e5c1902ae9565099ddeab80`。
- 调试二进制 SHA-256：`3cf3b090d26e8673fa43b59f065969b9ba4737288abcbfe2e8cf8ebdb31231eb`。
- KSPlayer SHA-256：`eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`。
- 13:57 完成同一源码的 201 项 XCTest（核心 157、非播放 44，各 1 跳过，合计 2 跳过/0 失败），15 项 preflight 通过。基线反例：未来区间旧诊断 8 秒→新 0，连续合并旧 2 秒→新 8；储备 1.266 秒时 lead 11→1.016。该源码随后没有改变，未把旧 197 项验证冒充新结果。
- 29 库逐一/deep 严格签名、描述文件包含两机且未到期、137 个源码输入未晚于构建、链接检查通过。每次换机/回归重新核对现场设备与同一包。

| 设备 | 现场型号 / 系统 / UDID | 本次包门槛完成时间 | 保留数据与正常启动 |
| --- | --- | --- | --- |
| iPhone 13，现场名 iPhone | iPhone14,5 / 16.3.1 (20D67) / REDACTED-DEVICE-01 | 2026-10-08T17:46:55.038828+08:00 | 覆盖安装成功，25 项非诊断偏好在安装及正常启动后相同；实际正常前台已核 |
| iPad，现场名 iPad | iPad12,1 / 18.3.1 (22D72) / REDACTED-DEVICE-02 | 2026-10-08T17:57:16.270417+08:00 | 覆盖安装成功，16 项非诊断偏好相同；WDA 恢复后完成空环境正常启动/实际前台核对 |

两机本次现场 USB 枚举/配对有效。iPad App 安装成功后自动观测连接重置，保存安装/偏好和诊断，导出 11 个崩溃报告（文件名未找到 Nastart，不能据此排除全部 App 失败）；原生截屏服务无效另记 TOOL。9 月旧 WDA fixture 描述文件已过期，未启动；改用上轮可用且签名/描述文件有效的 XCTest fixture 恢复现有宿主，`ready=true` 后才开始新包播放。保留原始 TOOL，不把安装受阻与观测受阻混为一谈。iPhone 18 本轮未连接，未更新。

### L1：真实蜂窝回调输入与未解决故障

- iPhone 13 实际 Wi-Fi 开关关闭、无人工限速，S03 媒体库 `C6A74F32` 35/35、文件 `F889BEBB` 1/1、MI2 媒体库 `E14A57D6` 25/25 URLSession metrics `cellular=yes`。既有 VPN 配置未改，规则命中/直连代理归属未知，不能标成无 VPN 或受控弱网配对。
- S03 AVPlayer 两次请求已读到 `bufferedAheadSeconds` 22.459/26.154 秒，候选准备时 `availableReserveSeconds` 25.353/28.341 秒（现有 lead 11/15 秒），证明原来的缺输入已接通；不将不同采样时刻的储备混为同一读数。
- MI2 AVPlayer 自然小储备边界：候选 `availableReserveSeconds=0.727610322`，`preparationLeadSeconds=0.477610322`，符合原规则减 0.25 秒的边界，未沿用未知输入时 11 秒。120 秒正常退出时候选仍准备中，属于观测结束取消，不能称候选对齐成功或 40 秒超时。真实洞/未知分支未现场构造，L0 已分别验证。
- S03 媒体库内部首钟 40.327 秒，两次候选约 40 秒后放弃，实际末图电影/双语字幕已核；当前首片 0 metrics 总耗时 4.281 秒（请求 2.491 秒/正文 1.789 秒），744480 字节供流完成。它不同于旧 iPad 60 秒无首片/-12889失败，不能用这次成功片段关闭旧失败或证明全部 40 秒由首片造成。
- S03 文件从头播放内部首钟 30.102 秒，180 秒观察窗口；最后可用遥测为 elapsed154.188 秒、时钟 10.484 秒、储备 0.459 秒、缓冲 2/正在缓冲约 65.599 秒、丢帧 4；末图停在片头标志，记 FAIL，不能以有解码图或播放器可关闭判播放通过。Wi-Fi 同入口随后独立补测，不覆盖该蜂窝失败。
- MI2 首钟 29.402 秒/120 秒末实际电影，初始缓冲计数 1；启动过慢仍 FAIL。短片段及内部时钟不等于完整首帧/声音/画质/稳态性能验收。

### L2：同包双机、双入口短窗

实施阶段的五个正常包单元保留原始时间、安装身份和本次实际图复核；本次接续补齐七个正常 Wi-Fi 单元，另列三条真实蜂窝窗口。合并覆盖 S01/S03/S08 × 两机 × 两入口的十二个 Wi-Fi 单元，只说明定向观察覆盖，不关闭 L2 全功能或性能验收。NAS 单路播放，串行执行；缓存冷热、服务负载/路线有变化，不能合并排名。所有首次失败、超时、丢帧和 TOOL 留存。

| 阶段 / 设备 / 网络 | 样本与入口 | trace | 窗口秒 | 内部首钟 ms | 最大缓冲 / 丢帧 | 结果 / 未满足条件 |
| --- | --- | --- | ---: | ---: | --- | --- |
| 实施阶段 iphone13 Wi-Fi | S03 媒体库 | 94CD24AB | 90 | 1742 | 0 / 44 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET；HANDOFF_CANDIDATE_ABANDONED |
| 实施阶段 iphone13 Wi-Fi | S08 文件 | 451A7485 | 45 | 3116 | 0 / 0 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 实施阶段 iphone13 Wi-Fi | S08 媒体库 | 93819C62 | 45 | 3928 | 0 / 0 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 实施阶段 ipad Wi-Fi | S01 媒体库 | 29AA97ED | 45 | 822 | 0 / 5 | 定向画面/退出已观察 |
| 实施阶段 ipad Wi-Fi | S03 媒体库 | F2777996 | 90 | 1819 | 0 / 8 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 本次接续 iphone13 蜂窝 | MI2 媒体库 | E14A57D6 | 120 | 29402 | 1 / 未知 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 本次接续 iphone13 蜂窝 | S03 文件 | F889BEBB | 180 | 30102 | 2 / 4 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET；REBUFFERING_OR_STALL_ACTIVE_AT_END |
| 本次接续 iphone13 蜂窝 | S03 媒体库 | C6A74F32 | 180 | 40327 | 1 / 未知 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET；HANDOFF_CANDIDATE_ABANDONED |
| 本次接续 iphone13 Wi-Fi | S01 文件 | 372CA26B | 45 | 633 | 0 / 0 | 定向画面/退出已观察 |
| 本次接续 iphone13 Wi-Fi | S01 媒体库 | 0B8B3AAE | 45 | 658 | 0 / 0 | 定向画面/退出已观察 |
| 本次接续 iphone13 Wi-Fi | S03 文件 | 6DEB40FF | 90 | 947 | 0 / 0 | 定向画面/退出已观察 |
| 本次接续 ipad Wi-Fi | S01 文件 | FF6331D3 | 45 | 2059 | 0 / 0 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 本次接续 ipad Wi-Fi | S03 文件 | 8E4A0D1D | 90 | 1818 | 1 / 2 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 本次接续 ipad Wi-Fi | S08 文件 | 9ADE93C1 | 60 | 4935 | 0 / 0 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |
| 本次接续 ipad Wi-Fi | S08 媒体库 | E2C0357F | 60 | 5326 | 0 / 3 | STARTUP_CLOCK_EXCEEDS_ROUTE_TARGET |

上表首钟为内部 `playbackClock`，失败阈值使用各次路由原有 `firstFrameTargetMs`；真实可辨画面仅有稀疏截图边界，不能替代端到端首帧测量。即使没有计数缓冲，缺完整帧时间/音频仍不判流畅、声音或完整 PASS。实施阶段手机 S03 候选放弃及丢帧 44、iPad S01/S03 丢帧 5/8不删除。AV 未有掉帧计数时写未知。磁盘保存/裁剪和采样边界保留：S03 媒体库最后可用遥测 elapsed149.628 秒，文件154.188 秒，不能把它们当成180秒精确末点或完整覆盖。iPad S03 闭后约1秒图片尚在旋转过渡，不作为稳定退出布局通过；最后 S08 文件另补延迟截屏，详情已稳定可读。

实施阶段真实蜂窝搜索连接错误/DSM 未就绪、iPad 冷 DSM 间歇登录失败保留为入口前失败。此前脚本统一打印 `navigation TOOL` 不准确，服务错误属于服务/会话失败，自动导航匹配或观测连接失败另列 TOOL。本次一轮四单元 batch 因 iPad session 文件缺失终止初始化，未对 iPad 发送播放动作，手机 S01 两项结果仍有效。

### 收尾、回退点与下一步

- 已恢复手机原实际 Wi-Fi ON，三个条件组均 inactive；两机最新普通包空环境启动、播放器退出、WDA ready、idleWait 10/coolOff 2 与实际正常启动台已核。NAS/Jellyfin 最终状态见实际收尾图和脱敏收尾记录。
- 未卸载、清登录、改 NAS/VPN/系统配置，未做大电影人为限速转码或并发压测。原偏好、凭据、完整诊断/设备信息仅在本机私有目录。
- 回退点：修改前 iOS diff256fd7a、普通 e8ef/d283/KSeda1 包保存在实施阶段私有证据；回退须只恢复本批三处播放改动/四项新增测试，不覆盖其他未提交源码，重新构建验签/安装/回归，不能直接把旧包当最新。
- 下一步优先分解 S03/MI2 HLS 启动与候选未对齐；另查 S03/S19 文件原流耗尽时匹配服务/回退可用性。补旧 iPad 首片失败同条件复现，十分钟稳态、轨道/暂停/seek/后台 PiP，再完整滚动与 Lenna/DS One 同条件五组配对。全部 PX/UX/CB、19×4 格式、L2 全功能与 Main 仍开放；正式竞品配对 0，没有性能胜负结论。

脱敏报告：[AV 输入修复与回归](../../../testing/results/2026-10/AV-RESERVE-HANDOFF-20261008.json)。
私有证据：实施阶段 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-07-083328-dual-entry-session/network-background-profiles-175119/av-reserve-handoff-20261008-135520`；接续 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-07-083328-dual-entry-session/network-background-profiles-175119/av-reserve-handoff-20261008-174443`。日志 `/tmp/nastart-avreserve-tests.log`、`/tmp/nastart-avreserve-preflight.log`、`/tmp/nastart-avreserve-counterexample.log` 及逐单元观测/安装/恢复记录均留存。
