# 播放链路统一：核心优化前的准备交接

日期：2026-10-28。范围：源码事实核对、历史证据整理、现有边界测试；未修改播放实现，未进行本轮真机播放或蜂窝切换。

## 接续边界

用户要求先从现有入口的实现与同条件证据中择优，统一播放链路，之后新增来源沿用这一基础；不再每个入口各自优化。既有 [ADR 0002](../../../adr/0002-single-playback-optimization-mainline.md) 已接受 Greenfield／KS 原流优先、AV/HLS 兼容分支，不重新铺开多套长期架构。事实核对不是性能优胜结论。

用户进一步限定：6.1 Sol 完成准备、采集和常规工作；Astra6 仅处理最核心播放链路优化。用户随后明确：真机对照、结果分析和播放链路优选继续由6.1 Sol完成，优选后的核心修改/优化才提示切Astra6；此前提前请求切换不再适用。标准速度、高推理是用户偏好，本文不证明应用设置已生效。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保留。18:23 核对419个冻结源码输入，零漂移；仍为 [连接编辑批](2026-10-28-SAVED-CONNECTIONS-AND-ATOMIC-EDITING.md) 的普通Debug双端包。281条Git状态记录不等于281个播放变更。此次未构建App、未覆盖安装；包身份和设备身份不能沿用来开始未来真机窗口，届时重新核对。Release迁移未验。

## 六条实际路线

| 终端／入口 | 当前实际承载与引擎接线 | 来源及生命周期边界 |
| --- | --- | --- |
| iPhone/iPad设备文件 | `DevicesView` → `MediaPlaybackRequest` → Debug `greenfieldPlaybackCover`；非Debug仍有`BuiltInMediaPlayerView` | 文件认证/兼容请求与ISO准备在入口侧，沿认证代理；不是所有配置均已切新路径 |
| iPhone/iPad Jellyfin | `LaunchpadView`详情 → store的`playbackRequest` → 同一Debug Greenfield全屏承载；非Debug仍有旧承载 | Jellyfin协商、原源轨道ID、服务端seek/换流、上报和释放仍由来源接线提供 |
| iPhone/iPad WebDAV | `NetworkLibraryPlaybackView` → loopback → `NetworkLibraryPlayerPresentation` → Greenfield全屏承载 | 共享模块拥有精确库/文件版本/凭据与桥；交给宿主的只有URL、标题、字节数和close |
| Apple TV设备文件 | `TVNASPlaybackSession` → FileStation媒体URL → `KSVideoPlayerView` | KS强制KSME；书签/prepare/stop在TV自己的会话中 |
| Apple TV Jellyfin | `TVPlaybackSession` → `TVJellyfinClient.prepare` → `AVPlayerItem/AVPlayer` | AV控制、恢复、换轨与Jellyfin上报独立；协商配置仍有20Mbps及H264转码1080p约束 |
| Apple TV WebDAV | 共享网络模块 → loopback → `TVNetworkLibraryPlayer` → `KSVideoPlayerSurface` | 与TV Jellyfin共用`TVPlaybackPresentation`和控制协议；实际引擎、状态与停止仍由独立KS控制对象承担 |

源码定位（本次只读核对）：

- [DevicesView.swift](../../../../ios/Nastart/Nastart/Features/Devices/DevicesView.swift)：`usesGreenfieldPlayer`、`prepare`中的ISO适配与两种呈现。
- [LaunchpadView.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift)：Jellyfin的`playbackRequest`、ISO准备、详情Debug与非Debug呈现。
- [LaunchpadPlaybackCore.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadPlaybackCore.swift)：`MediaPlaybackRequest`默认`.directURL`、运行状态／兼容资源／源轨道请求。
- [GreenfieldPlaybackBridge.swift](../../../../ios/Nastart/Nastart/Playback/GreenfieldPlaybackBridge.swift)：请求转换、origin和network context构造；[PlaybackSessionCoordinator.swift](../../../../ios/Nastart/Nastart/Playback/Core/PlaybackSessionCoordinator.swift)与[PlaybackPlanningPolicy.swift](../../../../ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift)为已有共用基础。
- [LaunchpadLayoutViews.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadLayoutViews.swift)：`NetworkLibraryPlayerPresentation`。
- [TVNASViews.swift](../../../../tvos/NastartTV/Sources/TVNASViews.swift)、[TVPlaybackSession.swift](../../../../tvos/NastartTV/Sources/TVPlaybackSession.swift)、[TVJellyfinClient.swift](../../../../tvos/NastartTV/Sources/TVJellyfinClient.swift)：三条TV实际路线。

## 已确认的差异，尚未判定的因果

1. **共用准备执行器只覆盖准备。** [PlaybackPreparationCoordinator](../../../../ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/PlaybackPreparationCoordinator.swift)处理准入、取消、迟到结果释放；它不统一在播引擎、seek、换轨、断点与服务器生命周期。不能把共用它或共用UI写成完整链路统一。
2. **网络桥交付的来源信息较少。** [网络播放View](../../../../ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/NetworkLibraryPlaybackView.swift)的宿主接口未传来源身份／上游origin、时长、源轨道或书签身份。移动宿主构造默认`.directURL`请求；现有桥有保留origin的能力，但本接口没有交付原WebDAV origin。实际策略影响应由后续确定性反例和同条件诊断核实，不以推断代替真机根因。
3. **WebDAV ISO在UI显式禁用。** [LibraryPosterWall.swift](../../../../ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryPosterWall.swift)的`canPlay`排除`iso`，而`RemoteMediaEntry.isVideo`包含ISO。已有 [ISOPlaybackAdapter.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/ISOPlaybackAdapter.swift)供移动文件/Jellyfin使用。接入网络来源需核其依赖和title读取／释放，不能仅删除禁用条件并将整盘当普通视频。
4. **WebDAV的取流实现与其他入口不同。** [WebDAVMediaResource](../../../../ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAVMediaResource.swift)每次有限读取最大1MiB；[WebDAVPlaybackSession](../../../../ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAVPlaybackSession.swift)逐窗等读取完成再发送；[DAVRequestOperation](../../../../ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAV.swift)每次创建ephemeral URLSession，完成后失效。可能产生建连／认证／等待成本，但本轮没有新吞吐、首帧或seek测量，**不能宣称这是已证实根因或改后已提速**。
5. TV Jellyfin固定AV与TV文件/WebDAV的KS路线，不能仅凭同一按钮或共享FFmpeg依赖判已统一；也不能从引擎名决定谁最快。

## 可用证据与缺口

| 证据 | 可以说明 | 不能说明 |
| --- | --- | --- |
| [10-25蜂窝传输窗](2026-10-25-CELLULAR-FILE-SEEK-TRANSPORT.md)与[归属校正](2026-10-25-SEEK-PHASE-AND-TRANSPORT-SCOPE.md) | 文件／JF均有实际蜂窝和连接复用证据，仍有长等待 | 起点、字幕Off/PGS、KS/AV路线不同；1543/733ms与6009/9443ms是内部恢复，不能作公平入口排名或呈现恢复 |
| 同上144指标、62项scope校正 | 可按transferID＋taskIndex重新关联，0缺匹配 | 不再采用旧完成时标签18/3作为准确pinned统计；完成回调快不证明NAS旧任务已释放 |
| [10-28准备取消批](2026-10-28-SHARED-PREPARATION-COORDINATOR.md) | 13 WebDAV／TV两来源有限出画、退出、准备取消有证据 | Pad普通退出、完整控制／声音／帧时间／弱蜂窝未全验；不是419最新包性能对照 |
| 本次26个现有边界测试 | 准备准入/取消/迟到清理及WebDAV范围、版本、认证、重定向、停止等现有规则通过 | 不测试真实NAS吞吐、解码、显示、音频或完整播放优化 |

本次测试18:24:34–18:24:48，Mac独立私有scratch目录重新构建NetworkMedia，选择`PlaybackPreparationCoordinatorTests|PlaybackPreparationGateTests|WebDAVMediaResourceTests|WebDAVMediaHTTPTests`，26/26、零失败。HTTP仅本机fixture，零NAS媒体读取。首次`--skip-build`因包默认目录无测试二进制而失败，保留原日志；后续显式独立目录构建才通过，未将首次失败抹除。没有必要重复全部215测试；无源码改动。

前轮13准备窗口Settings的WDA取树25秒超时，没有切换Wi-Fi或启动媒体。独立原生图已见原网络已连接及Wi-Fi图标；18:19已恢复并读回原WDA设置、普通启动台出现、删自有HTTP会话，原Runner保留。此为前轮收尾证据，不作为本轮fresh设备可用性确认；无蜂窝流量遗留。本轮未触碰13/Pad/TV，也未发现或控制离家的18。

## 进入核心优化前的最小输入

优选需覆盖的问题（6.1 Sol继续真机取证和优选，核心实现优化再交Astra）：

1. 基于已有Intent／Plan／Route／Session与KS主线，明确唯一会话及选流/引擎切换的责任边界；怎样让六条路线接入它，同时保留认证、Jellyfin协商与必要AV兼容，避免再造一套核心。
2. 明确来源适配器必须交付的身份、版本、真实origin、时长、轨道、断点与释放能力；复用已有ISO读标题能力，并保持只读及精确scope约束。
3. 在共用核心上设计可测的首帧、供给、seek、取消分段，确定最小修改和反例，再判断WebDAV逐窗会话是否需要调整；不先盲增窗口、缓存、超时或放宽文件版本/账号隔离。

核心修改后的回归准备遵循[分层流程](../../../development/playback-development-workflow.md)：L0规则与取消竞态；L1原失败＋同技术片、S01四单元，并补WebDAV/TV受影响路线；L2 S01/S03/S08/S11/S18、S19压力和ISO专项。默认迁移／删除旧实现触发L3，不能用26测试代替。

性能比较先固定同设备、同文件版本、同起点、同源音字幕、冷/热、网络和实际端点；每条件至少3次探索重复，含失败/超时，报中位数和范围。画面首帧、内部时钟与解码回调分列；连续30秒、代表片10分钟、暂停/±15秒/换轨/退出续播及源释放按影响覆盖。WebDAV缺少的服务端转码能力单列，不能把不同转码结果当同一条件。对照只按明确问题选代表入口，不重复整套旧架构矩阵。

蜂窝窗口现场重新核13身份、最新包、原Wi-Fi、LTE/5G和信号；射频定量未知就留未知。每窗最外层finally先停自有媒体/采集，再以原生已连原网及Wi-Fi图标确认恢复，之后才作长分析或等待模型切换。不要提前关闭Wi-Fi等待Astra。

## 结果与后续

关联现有PX-01/PX-03/PX-20/PX-21及UX-09，不新增重复任务。30项14进行中/5待验/11未开始、114播放格不变；无新真机PASS。FTP/SMB、Pad退出、Release与蜂窝大文件问题继续开放。

原始源码清单、测试日志、前轮设备收尾和安装证据留仓库外私有证据区，沿`current-webdav-latency-private`定位；不公开凭据、UDID、媒体路径或原始偏好。安全摘要见[结构化结果](../../../testing/results/2026-10/2026-10-28-PLAYBACK-UNIFICATION-PREPARATION.json)。下一步由6.1 Sol继续真机配对、结果分析和优选；确定统一基础后，才提示用户切换Astra6进行核心修改和优化。
