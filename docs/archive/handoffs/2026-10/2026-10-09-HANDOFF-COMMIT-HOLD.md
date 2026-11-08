# 备用流对齐与提交时序接续

问题/关联：PX-03/PX-21，共用自动降档备用HLS对齐后提交资格。基线HEAD4de732dd、iOS diff979f16、普通d839/3481，前批15窗仅属该源码，其他未提交修改保留。

旧实机S03事件（旧dad249源码）：candidate_aligned时candidate15.319858042/live15.293887616/rate1；约10ms后commitRevalidation时candidate15.443470141/live15.321553297，差0.121916844>0.1，正确拒绝提交。缓冲超过1秒，未证明网络等待是这次拒绝的直接原因。支持假设：对齐后candidate未停钟，加上await prepareSession/AV命令异步响应留下漂移窗口；后续以实机复现验证，不由单条事件断言全面修复。

修改前确定性反例采用真实生成MP4/AVPlayer解码：对齐时源由推进变为停钟，在实际会话准备及300ms故障注入等待后candidate rate1/漂移0.586472625，两个断言失败。首次测试有async-autoclosure编译工具错误，已修正并保存，不能当产品失败。

最小方案：会话准备放在最终对齐之前；holdForCommit固定暂停候选并重读暂停后的时间/解码帧/连续半秒储备，保留0.1秒时钟与0.15秒帧门槛、现有取消/seek/轨道资格、原40秒预热期限及旧流持续播放。提交资格失败保留旧流；不改码率、Range、网络或按片参数。

L0：真实AV解码持钟/原暂停与恢复/取消、移动与静止源、已有旧漂移拒绝测试，以及全部核心和非播放规则测试/15预检。L1：最新包逐机核对后S03两个入口自然蜂窝/受控弱链路候选，旧100ms拒绝路径需直接新实机证据，否则修复实机仍未验。L2：S01/S03/S08双机双入口代表集；触及选流对齐规则，未修改解码/传输参数，完整声音、轨道/seek/PiP、十分钟及19×4仍待补；无默认迁移/发布，不触发本批L3。

2026-10-09用户补充弱家庭内Wi-Fi与弱家庭外Wi-Fi大文件调试。纳入独立链路与双入口执行卡；当前USB接在家中Mac的Wi-Fi限速只代表模拟弱链路，真实家庭外Wi-Fi需独立设备/网络证据，不能用公网回环或蜂窝替代。

当前现场两机USB：iPhone13 iPhone14,5/iOS16.3.1/20D67；iPad iPad12,1/iOS18.3.1/22D72。全名/UDID/旧诊断仅本机私有目录。iPhone18未连接。此句为初始修改卡时点；两次后续包门槛及各自独立回归见下文，旧包不算当前包结果。

## 新包与安装门槛

207测试/2跳过/0失败（现有真实解码测试加入推进源持钟反例），15预检通过；预检首次脚本无执行权限属TOOL，bash调用通过。普通Debug -Onone，构建2026-10-09T07:18:03.041758+08:00，iOS diff `2a4373a0954d653662b5d720048cdf80714cc66206b186181e122c10c866ef7b`，包路径 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-handoff-commit-071437/Nastart-Handoff-Hold-Normal-Debug.app`，29库/deep签名、137输入与链接通过；三二进制SHA-256 `{"Nastart": "1d08fd2dd7be4752fc9a97ceb71af72a9214325fa6598653ca0aee02ed9c8769", "Nastart.debug.dylib": "004102b3a4b5ea4c31850e2e7d6d1f838d7e86252f01883b63f7d51567031657", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}`。

两机现场重核目标/配对/有效profile后保留数据覆盖：13 25项、iPad16项非诊断偏好安装后/普通空环境启动后一致，实际启动台已核。完整名称/系统/UDID与执行时间、原始偏好仅私有目录；两机后续基线与定向回归归新1d08/0041，不能移用昨晚15窗。iPad WDA夜间宿主退出/连接重置已复用有效fixture恢复，未重装WDA。

用户后续确认：目前只有家庭Wi-Fi，真实家庭外Wi-Fi验证稍后补；本轮家庭内正常与受控弱链路继续，不把模拟或公网回环标为外部验证。

## 第一包实机结果与追加反例（10:00）

第一包1d08/0041独立保留16窗：12普通家庭Wi-Fi（S01/S03/S08两设备双入口）及4个S03受控40Mbps/33Mbps、双向1ms/0丢包的180秒窗；实际上游均privateIP且cellular=no。全部末图已核电影；15窗原时点普通退出，iPad弱Wi-Fi媒体库原退出TOOL，09:59使用现场有界完成按钮普通恢复退出，不能移作180秒窗口原退出通过。初始iPad文件导航TOOL保留，修正操作工具对侧栏Cell支持后补单元。两机条件已分别07:44:38/07:51:47恢复全inactive，无App测试环境。

第一包手机弱Wi-Fi媒体库两次candidate rate0且replacement_committed，iPad首次rate0/commit成立。iPad第二次对齐candidate38.147013403/live38.208194116，而诊断快照已读到live38.251682277；约1.9ms后commit candidate38.148492273/live38.252646257，差0.104153984秒，原门槛正确拒绝。此处方向是旧流前进超过持钟候选，与旧候选自身rate1超前不同；最后核验后warmupMetrics的accessLog/range/clock同步采集耗时留下旧快照，需先准备诊断快照再读最终时钟/资格。所有失败和候选放弃保留，不标全面修复。

普通窗6个、弱Wi-Fi媒体库iPad1个内部时钟超过已有路线目标，弱网4窗均有首钟后缓冲：手机文件5次/14丢帧，iPad文件5次/8丢帧，媒体库AV各自计数不跨引擎相减、AV丢帧未知。文件入口详情预查verifiedTranscodeSource与独立original解析exactPathMatches0/ambiguousOrUnavailable分属不同查找；无候选请求的源码缺口见下节，不能把它归因于转码匹配失败。S01文件同轮原生/WDA都正向片头，无法关闭S01媒体库倒置样本。音频/画质/十分钟/完整帧时间/竞品未验，正式配对0。

脱敏数据：[第一包结果](../../../testing/results/2026-10/HANDOFF-COMMIT-HOLD-20261009-PHASE1.json)。第一包不移用作下一包最新回归；追加快照顺序修正与真实解码时钟阶跃反例正在验证。

## 追加修改卡：诊断快照后的最后对齐

第一包iPad第二接手0.104153984秒拒绝支持最后核验之后不应再采集同步accessLog/range/liveClock。修改只将这些采集放到最后读钟之前，最终记录的candidate/current/liveSeconds统一使用最后核验快照，不放宽资格、期限/码率或引入片名参数。真实MP4解码时注入源时钟在诊断读取时前进0.2秒：旧顺序candidate0.6/live0.85，原canCommit断言失败（1 failure）；先前两种注入未触及最后快照，仅为测试设计样本，不冒充失败。一次模拟器启动Busy属TOOL，正常启动后反例成立。新207测试/构建/预检与逐机最新包门槛随后独立执行，第一包16窗仅属第一包。

## 第二包门槛（10:10）

207测试/2跳过/0失败及15预检、普通Debug -Onone构建通过；追加反例新candidate0.7772805/live0.85符合原100ms门槛，旧0.25秒差失败保留。HEAD4de732dd+iOS diff `f6ef10b4a984ccb850b631cb3acd305943b7dcae302aeff1de4b202f8e62da28`；构建时间 `2026-10-09T10:07:50.085563+08:00`，新包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-handoff-snapshot-100336/Nastart-Handoff-Snapshot-Normal-Debug.app`，SHA-256 `{"Nastart": "fe7ccd68847d835c8fb04c097a44487002a83831c3e0ed0559680be8fe856801", "Nastart.debug.dylib": "61c8ff6c09184867e22d405d4bc884379d61c80bf7a471563f99fa517894db07", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}`。两机现场重核/137输入/29库与profile后保留数据覆盖，13 25项/iPad16项偏好一致、空环境实际启动台已核；第二包回归独立进行，不沿用第一包16窗。

计划先两机S03双入口各180秒受控弱Wi-Fi，再S01/S03/S08双机双入口12个30秒正常Wi-Fi窗。短窗为正确性/资格回归，不做跨包速度排名，原十分钟/听音/完整帧要求保留。

## 后续独立缺口：Wi-Fi文件入口没有协商候选

第一包两机受控弱Wi-Fi文件入口均出现5次首钟后缓冲、无automatic_downshift_requested。源码DevicesView.prepareMediaPlayback仅在fileNetwork.cacheKey不为wifi时使用已验证JellyfinMatchedFileStream，Wi-Fi下直接original MediaPlaybackRequest只有Range/software资源回退，没有compatibilityFallbackRequestLoader；播放器共用降档任务因此不启动。日志中verifiedTranscodeSource属于详情页预查，ambiguousOrUnavailable属于独立original路由解析，不能把两个查找混为同一个失败，也不能由exactPathMatches0认定转码匹配失效。下一独立变更应保持严格身份资格，为原文件请求提供可用的协商候选；正常家庭Wi-Fi默认原画、无法匹配不强转码/不换片、用户暂停/seek/轨道/取消与资源释放需回归。弱信号、MI2/S19、实际家庭外Wi-Fi、长窗/画质和健康升档仍未验。本批快照修正不混入该新规则，以当前新包基线保留。

## 第二包独立回归收尾（2026-10-09 11:04）

2026-10-09 11:04 接续：当前f6ef10源码/普通fe7c、61c8、KSeda1已逐机保留数据安装13/iPad，25/16偏好一致；207测试/2跳过/0失败及15预检。第二包独立28窗（12普通30秒+12正文60秒+4受控弱Wi-Fi180秒），20窗可辨电影、8片头/天空短窗保留未验；27原时点普通退出，另一iPad S03文件30秒退出TOOL后普通恢复独列。弱Wi-Fi媒体库手机1/iPad2实际持钟接手，文件总计手机6/iPad5次缓冲（首钟后各5次）及iPad媒体库再缓冲仍FAIL；10普通/2弱窗内部起播钟超目标。S01媒体库同序列原生/WDA方向补证已核，旧倒置不全面关闭。两机最新普通/空环境实际首页/播放器关闭/idleWait10与新鲜条件全inactive已核，无无线设置改动。下一项独立修正Wi-Fi文件请求协商候选；MI2/S19/真实弱信号/家庭外Wi-Fi、声音/画质/十分钟/PiP/完整帧及全PX/UX/CB/竞品/Main仍开放。

第二包28窗逐窗新鲜USB身份与f6ef10/fe7c包记录核对，iOS源码/产物在整个回归期间未变。先完成12短窗，发现8窗仍是片头/天空，补齐同代表集12个60秒窗；原短窗与工具失败均保留。下表是实际已观察的60秒普通及180秒受控弱Wi-Fi单窗，不作性能排名。首钟为内部时钟，非可辨首帧时间；各引擎首钟后计数独列，AV丢帧未知。

| 设备/入口/样本 | 秒 | 内部首钟ms | 各阶段首钟后缓冲增量 | 可辨电影/原普通退出 | 保留失败 |
|---|---:|---:|---|---|---|
| iPhone13 受控弱Wi-Fi S03 文件 | 180 | 1361 | 5 | 是/是 | 首钟后缓冲计数增加 |
| iPhone13 受控弱Wi-Fi S03 媒体库 | 180 | 999 | 0/0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPhone13 普通Wi-Fi S01 文件 | 60 | 479 | 0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPhone13 普通Wi-Fi S01 媒体库 | 60 | 535 | 0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPhone13 普通Wi-Fi S03 文件 | 60 | 693 | 0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPhone13 普通Wi-Fi S03 媒体库 | 60 | 867 | 0/1 | 是/是 | 首钟后缓冲计数增加 |
| iPhone13 普通Wi-Fi S08 文件 | 60 | 2974 | 0 | 是/是 | 内部起播钟超目标 |
| iPhone13 普通Wi-Fi S08 媒体库 | 60 | 3227 | 0 | 是/是 | 内部起播钟超目标 |
| iPad 受控弱Wi-Fi S03 文件 | 180 | 1984 | 5 | 是/是 | 内部起播钟超目标, 首钟后缓冲计数增加 |
| iPad 受控弱Wi-Fi S03 媒体库 | 180 | 1756 | 0/1/1 | 是/是 | 内部起播钟超目标, 首钟后缓冲计数增加 |
| iPad 普通Wi-Fi S01 文件 | 60 | 870 | 0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPad 普通Wi-Fi S01 媒体库 | 60 | 722 | 0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPad 普通Wi-Fi S03 文件 | 60 | 1260 | 0 | 是/是 | 本窗未触发所列失败；非完整验收 |
| iPad 普通Wi-Fi S03 媒体库 | 60 | 1538 | 0 | 是/是 | 内部起播钟超目标 |
| iPad 普通Wi-Fi S08 文件 | 60 | 4436 | 0 | 是/是 | 内部起播钟超目标 |
| iPad 普通Wi-Fi S08 媒体库 | 60 | 4624 | 0 | 是/是 | 内部起播钟超目标 |

实际rate0、最终current/liveSeconds一致的候选后出现replacement_committed共5次；本第二包commitRevalidation拒绝0次，只证明观测到的候选，第一包0.104秒和更早0.122秒失败保留独立反例。iPad S03文件30秒观察后退出按钮未捕获属TOOL，保留原窗口ordinaryExit=false；10:37新鲜有界完成按钮恢复退出单列，不回填原窗通过。操作工具加强退出按钮重新显露与有界采样，未改App退出逻辑。

S01 iPad媒体库正文约46.346–47.412秒原生/WDA同城堡序列（相邻帧不同）方向一致，60秒羊群/房屋正文正向；不是精确同帧比较，也不关闭旧倒置样本。所有原始图、偏好、UDID、地址和故障诊断只在本机私有目录。第二包[脱敏28窗摘要](../../../testing/results/2026-10/HANDOFF-COMMIT-HOLD-20261009.json)与[第一包16窗](../../../testing/results/2026-10/HANDOFF-COMMIT-HOLD-20261009-PHASE1.json)分开。

下一独立修正卡：保持家庭Wi-Fi健康原画默认路线，为原文件请求提供惰性的严格已验证候选loader；仅在既有储备/供流/缓冲策略实际触发时协商，不把Range/software资源回退当转码。保留相同文件身份、runtime位置/轨道/暂停/主动Original、取消和失败资源释放；未知/歧义/取消继续原流。先固定Wi-Fi文件原请求缺loader反例，再做同样本同源普通与受控弱Wi-Fi双入口回归。此项尚未实现；真实弱RF/外部网络与画质恢复升档另需证据。
