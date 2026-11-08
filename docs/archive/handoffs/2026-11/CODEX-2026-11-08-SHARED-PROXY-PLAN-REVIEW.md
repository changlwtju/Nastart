# 11-08 网络来源共用代理方案审查

2026-11-08，Asia/Shanghai。审查[Claude只读方案](2026-11-08-0100-CLAUDE-NETWORK-SOURCES-SHARED-PROXY-PLAN.md)及[11-07播放背景](2026-11-07-2340-CLAUDE-PLAYBACK-ACROSS-SOURCES.md)。审查基线为 main `4de732dd645b36671becff992cdef1d0163fd1e4` 加当前未提交修改。28个相关产品/测试/工程文件已冻结哈希并结束复核。原始清单和探针放 `/tmp/nastart-codex-shared-proxy-review-path` 指向的本机私有目录。

结论是方向可行，第一步有条件接受。原方案的“两处改动”需要增加明确的所有权、Range正确性与诊断交付条件。Claude负责第一步和13/Pad顺序实测，Codex负责共享Range前置问题、第二步公共接口/代理及启动预读排查。分工依据本批上下文连续性，双方额度未知。

## 用户原则与现有实现

11-08原则已接受。以实际网络环境决定共享播放策略，在同环境、同媒体条件下，Jellyfin、设备文件、SMB、FTP、WebDAV使用共同的规划/读取调度/重试/缓冲/seek/切轨链路，协议适配限于字节供给及其认证/版本校验。FTP和SMB的使用范围为LAN。

当前入口确实有差异。`NetworkLibraryPlayerPresentation`直接传桥接URL，`registerOriginalStream`尚未接入该入口。`routeKind=localRangeProxy`只说明规划器看见loopback，不能单独证明具体代理注册。现有`networkSource.originURL`与`stableID`已将网络策略/书签身份与本地播放URL分开，第一步必须继续传同一个`networkSource`。实际网络class当前主要由地址种类或显式private标志推导，公网域名常落unknown，expensive/constrained初值false。将来需接真实路径信息，不能把loopback或“FTP入口”直接当作网络环境证据。

## 第一步的必要修订

### P1　接入前修正共享Range语义

`DevicesView.swift`的`MediaRangePolicy.boundedRange`不能直接作为新入口的完整Range契约。将当前枚举原样提取并运行Swift探针，结果如下。

| 输入 | 当前实际输出 | 审查结果 |
| --- | --- | --- |
| `bytes=0-` | `bytes=0-33554431` | 上游32MiB窗口 |
| `bytes=100-199` | 原值 | 普通闭区间保持 |
| `bytes=-500` | `bytes=0-33554431` | 后缀请求被改为文件头，错误区域 |
| `bytes=100-99` | `bytes=100-100` | 非法范围被静默变成合法读取 |
| `bytes=0-0,999-999` | `bytes=0-0` | 只取首范围，需明确多范围策略 |

桥接`MediaLocalHTTPRequest`本来支持正确的后缀范围，且已有`testLoopbackSeekHeadAndInvalidRequestsDoNotReadOtherFiles`覆盖后缀、非法范围与416。接共享代理会把它置于有缺口的上游规范化之后。Codex先修这项，并补原始请求经共享代理及桥接组合后的测试。检查`start + maximumLength - 1`的溢出边界，避免极大偏移触发算术trap。整数溢出风险为源码判断，本次未执行trap用例。

后缀范围代表文件尾部。以10000字节文件为例，`bytes=-500`对应9500—9999，不能改读开头。多范围可以制定单范围服务契约，但应保留合法的响应语义并明确拒绝/处理不支持的格式。[RFC 9110 §14](https://www.rfc-editor.org/rfc/rfc9110.html#section-14.1.2)

还需更正“有限范围响应”的描述。`registerOriginalStream(...usesGreenfieldPlayback:true)`限制的是每次上游任务的32MiB窗口。客户端请求`bytes=0-`时，现有`clientUsesContinuousRangeResponse`向客户端声明从起点到文件尾的完整长度，并串接多个上游窗口。测试必须跨过32MiB边界、核长度/内容/尾部/回退seek，不能只测首窗。

### P1　显式撤销路由并处理取消竞争

已有`AuthenticatedMediaStreamProxy.unregister`会撤销路由、取消该路线transfer、清理VOD缓存及独有pinned transport，第一步应复用。当前六小时逻辑是在下一次register时按创建时间扫旧条目，既非后台定时失效，也非播放所有权。仅等待桥接关闭，会留下失效路由和可能的重试/诊断噪音，后续直接Reader路由还会延长Reader及凭据所有者的驻留。

在`LaunchpadLayoutViews.swift`本文件内持有一次播放的代理lease/owner，复用现有准备代次与释放约定。明确覆盖注册完成前取消、完成后迟到、准备失败、用户关闭、替换及最终owner释放。先停止/脱离解码器，再撤销本次代理及桥接。全屏覆盖准备页、PiP和短暂onDisappear期间保留所有权。只用`.onDisappear`撤销会破坏现有`NetworkPlaybackOwner`专门保留的生命周期。

失败退回桥接地址只适用于注册/本地监听准备失败。取消按取消处理，迟到返回的代理地址必须撤销。注册成功后的读失败通过正常失败/重试契约处理，不能静默重新播放桥接或跨过文件版本/认证错误。禁止把`try?`吞掉取消后继续创建播放器。

### P1　关联诊断、媒体身份与测量边界

注册前生成一次playbackTraceID，同时传入代理注册及MediaPlaybackRequest。当前入口没有显式trace，Greenfield桥接稍后自行生成短ID，仅给代理一个空trace会继续造成传输与plan无法关联。诊断至少记录注册结果、`sharedProxyViaBridge`或`bridgeFallback`、协议种类、上游类型及测量边界。原始URL、能力token、文件路径与凭据保留既有私有/脱敏规则。

代理filename使用带原始扩展名的安全名称，并显式传`fileExtensionOverride=source.fileExtension`。元数据title可能没有扩展名，不能拿它替代容器提示。保留原`networkSource`、byteCount、stableID、originURL和从头/续播意图。

外层URLSession的DNS/TCP/TLS指标对应loopback桥接，无法拆出NAS鉴权/真实远端连接阶段。body统计也受Reader先聚合1—4MiB、随后本机突发发送的影响。现有代理会将body/任务采样送入`PlaybackRecentThroughputStore`与下载计量，所以本次接入同时会影响自适应估计。新增诊断须标明`measurementBoundary=bridgeDelivery`，并检查把该样本作为源端供给估计的资格。真实远端阶段需要Reader侧同trace事件。以代理外层字节作为交付字节，避免再与Reader字节相加造成重复计数。

### P2　并发用有界4，保留取消和背压

桥接2个客户端限制与代理4连接配置确有不匹配，第一步建议明确上限4，再以测量决定后续。`httpMaximumConnectionsPerHost=4`是单URLSession的HTTP/1.1配置，其他session及关闭中的旧请求仍可能使总占用更高，所以4并不保证永不拒绝。超过预算的请求应有可诊断的拒绝/有界等待，核四并发GET、HEAD、连续seek旧请求释放和第五请求的行为。[Apple接口说明](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpmaximumconnectionsperhost?changes=_3)

每路已有最大4MiB的DAV聚合窗口和代理4MiB高水位。保留流式deliver/背压，测峰值内存与取消延迟。SMB的同一worker串行使用连接，提高HTTP入场数并不等于远端读取并行四倍。

FTP尤其需要单列。当前`FTPMediaResource.stream`每次调用登录一次，原桥接可能维持一次长stream，接代理后每个32MiB续窗会重新调用stream，从而增加登录次数。记录每GiB登录数、控制/数据连接数、窗口切换耗时与seek取消。性能回退按有界实验规则保留/撤回。FTP控制连接复用安排在Reader专项，独占借用控制会话、REST偏移复位、ABOR/结束响应排空、认证失败与单任务取消隔离都须验证，不能让并发任务共用同一有状态控制连接。

## 第二步接口与主导

由Codex主导，Claude审查并承担后续有界Reader优化。复用已有public `NetworkMediaByteReader`，将声明从`WebDAVMediaResource.swift`移到同包中性的`NetworkMediaByteReader.swift`。iOS App和TV已经依赖NetworkMedia，包继续只依赖底层协议库，保持单向依赖。

共享代理核心建议放`NetworkMedia/Sources/NetworkMedia/MediaStreamProxy.swift`，承载来源无关的Range、流式发送、背压、取消及重试规则，并在内部区分HTTP能力与Reader能力。抽取/复用现有已测语义，平台宿主提供脱敏诊断sink与已有HTTP认证/证书策略适配，Jellyfin的HLS清单逻辑继续通过宿主适配接入。逐步迁移原流到同一个核心，避免留下两个独立Range实现。当前`DevicesView.swift`依赖UIKit，TV工程也没有编入该文件，直接把Reader enum加在这里只能完成iOS局部接线。

Reader保持凭据和版本校验。路由持有不可变的来源/版本身份，露出的仍为可撤销播放能力。Reader路由不采用HTTP地址重写、`?u=`覆盖或HLS子资源映射。关闭lease取消全部本次任务、阻止新读，并释放本次Reader引用，不能取消另一条路线拥有的会话。协议错误需区分取消、过期文件、认证失败、范围错误和可重试传输中断，错误不能统一吞为EOF。复用现有`stream(offset:count:deliver:)`，正常返回必须恰好交付count字节，队列/Data内存有界。

FTP/SMB在本批使用LAN样本。协议构造器当前允许公网host，内网约束不能由入口名称或127.0.0.1推导。第二步供给边界需定义按实际连接端点/路径验证LAN的规则，涵盖域名解析、IPv4/IPv6和重连，保留用户保存地址。源侧HTTP、FTP、SMB的连接复用仍由各Reader维护，属于“怎么拿字节”的适配范围。

## 启动预读的源码结论

这是已记录的观察适配器行为，同时表明真实共享字节预读尚有实现缺口。调用链已核到生产入口。

`GreenfieldVideoPlayerView.prepareSession` → `PlaybackSessionCoordinator`默认工厂 → `ObservingPlaybackIOContext` → 空的`preload` → `isRangeCached=false` → `PreloadCoordinator.schedule=0` → `preload_cancelled/bytesNotMaterialized`。

`RangeCacheStore`只保存范围元数据和命中计数，没有Data/文件页内容。现有`testObservationOnlyIODoesNotInventCachedBytes`及`testObservationOnlyStartupReportsZeroActualPreload`明确要求这个结果。[现行链路说明](../../../architecture/VIDEO_PLAYBACK_PIPELINE.md)第5节也已记录同样边界。因此“当前已经有所有入口共用的真实范围缓存/启动预读”需要撤回为“已有策略/调度模型，生产默认IO观察器不物化字节”。

Codex负责后续排查/方案。优先按IO能力显式区分跳过、真实开始、真实完成，减少把意图当取消工作的诊断歧义。真实预读须与解码器读取共享可消费的字节存储，并按来源版本/范围/代次失效。禁止仅markCached、填4MiB计数或额外下载一份解码器用不到的数据。首帧优先策略仍应生效，`first_frame_priority`与`bytesNotMaterialized`分别记因。0字节本身没有提供大文件起播慢的因果证据，需同源有/无真实预读对照后判断。

## 分工、文件范围与资源状态

本轮是本机只读产品审查。当前登记没有Codex活跃产品写入，且本轮产品哈希保持一致，因而与本线程正在实施的代码无冲突。登记仍停留11-04，不能用它排除外部会话的未登记写入。含dirty同源独立目录准备、哈希复核与完整文件登记完成后，才激活下一实施批。

| 批次 | 负责人 | 完整可写范围与交接条件 |
| --- | --- | --- |
| Range前置修复 | Codex | `ios/Nastart/Nastart/Features/Devices/DevicesView.swift`及`ios/Nastart/NastartTests/PlaybackNextCoreTests.swift`，先补单范围/后缀/非法/溢出及双层组合用例 |
| 第一步接入 | Claude | `ios/Nastart/Nastart/Features/Launchpad/LaunchpadLayoutViews.swift`、`ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAVPlaybackSession.swift`、`ios/Nastart/Packages/NetworkMedia/Tests/NetworkMediaTests/WebDAVMediaHTTPTests.swift`。宿主测试如需改PlaybackNextCoreTests，先按完整文件串行移交。可在Layout本文件内放所需私有owner，不扩散改Bridge/引擎/策略 |
| 第二步公共代理 | Codex | 拟为`DevicesView.swift`、同上宿主测试、`NetworkMedia/Sources/NetworkMedia/NetworkMediaByteReader.swift`和`MediaStreamProxy.swift`、现有`WebDAVMediaResource.swift`、`NetworkMediaPlaybackSource.swift`、`NetworkLibraryPlaybackView.swift`、桥接退出迁移及两端宿主适配。正式实施前交完整确切清单和同源目录，第一步文件释放后接手 |
| 预读排查 | Codex | 当前先审`Playback/Core/PlaybackSessionCoordinator.swift`、`Playback/IO/PlaybackIOContext.swift`、`PreloadCoordinator.swift`、`RangeCacheStore.swift`、`Playback/Core/PlaybackPlanningPolicy.swift`、`Playback/GreenfieldVideoPlayerView.swift`及宿主测试。接口和性能实验单独交可写方案 |
| Reader优化 | Claude | FTP控制连接复用/SMB/DAV读取器作为另一个完整文件批次，先交清单与取消/错误/版本契约，不续用第一步写入范围 |

表中第二步/预读是本批计划范围，尚未构成跨目录的新产品写入lease。共享摘要/当前交接/需求总账/矩阵/资源登记继续由Codex维护。Claude只写本方月度结果。原方案“Codex长期维护所以固定主导”改为本批分工，后续依额度/连续性调整。

第一步Claude可负责13与A16 Pad的顺序实测。执行前fresh核空闲/用户操作/Runner与所有原生采集，逐台登记独占窗口。单一syslog读者，另一方做本机审查。NAS负载、缓存冷热、样本/网络/实际端点与Debug配置一致，按A/B交错对照，失败/超时照录。每协议仅一轮不足以宣称收益，帧率中位数也不能替代完整显示帧时间证据。覆盖取消/关闭/迟到、PiP/后台、深seek、跨窗、第五连接/恢复、同版文件内容与内存，保护凭据及所有NAS源文件。

iPad背景报告称SMB/FTP未配置、WebDAV凭据可能失效，开始时fresh确认；缺配置的项目明确阻塞并继续独立可测项。设备准备需要用户输入凭据时由用户处理。18与TV继续按各自窗口单独登记。

当前包按用户11-08最新陈述记录为13/Pad/18均已装 `4744df402a1897c3`。这是背景中Debug dylib前缀，完整二进制SHA、产物路径和当前源清单尚待安装前现场核对。11-07报告原称18较旧，已用本次用户更新覆盖当前摘要，历史报告保留。报告中的App profile到11-08 09:08+08，测试时重新核有效期/目标覆盖并按需要准备有效签名正常包，不能只按0.1.0/1确认。

本轮只执行源码探针、读取工程/报告与维护共享文档，真机操作0、NAS请求0、全量构建0。前批350测试/六配置/24fps等为Claude交付陈述，当前审查仅对代码和上述独立探针负责。现有需求状态和114格播放验收保持，各历史失败继续保留。
