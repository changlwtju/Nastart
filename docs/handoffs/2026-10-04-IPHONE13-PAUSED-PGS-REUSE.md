# iPhone 13 暂停 PGS 返回复用候选（2026-10-04）

## 18:59 检查点与设备门槛

- 新开工读取PROGRESS、当前交接、runbook与竞品矩阵，保留全部原未提交修改。现场设备iPhone / iPhone14,5（iPhone13）/ iOS16.3.1 20D67 / UDID `00008110-001E543122E0401E` / USB，配对通过。
- HEAD仍为`9a9941cd4ec82625f680b5193b3a0f66797eb851`。开工源码与上轮302/6e2构建快照一致，后续加入下述候选后重新测试、构建、验签、保留数据覆盖安装。安装前后原始偏好只在本机私有目录，25项非诊断偏好逐项一致，没有卸载/清登录数据。
- 上轮WDA主机进程结束，8102返回503；复用已有固定Runner恢复，test plan已开始、Runner PID99125，但HTTP一直未ready。原生USB截图确认“为XCTest输入iPhone密码”，四位均空。90次有界等待结束，脚本清理其Runner和转发；没有重装WDA、输入密码、开启切换控制或修改手机设置。安装后18:58截图仍是该授权页。已请求本机授权，当前未收到完成反馈；不把普通USB/配对视作自动化可用。

## 确定缺陷与候选范围（PX-02/20）

旧包在同一暂停的已知PGS cue上切到ASS、再切回PGS，字幕已真实显示过，但`popLatest`消耗了显示队列，`SubtitleModel`又清掉切换前的parts。返回PGS时一律重新seek同位置，清空音视频队列并重用启动缓冲；旧traceFFF892FE随后约4.5秒缓冲，未切轨trace7F24240D在同片段保持9.7～16秒储备并推进。这证明有可移除的冗余seek，不证明整个卡顿只有这个根因。

候选不调整窗口、启动/稳态缓冲或解码策略。只在暂停、当前模型有实际位图cue时，记录当前轨道的一个已知显示集及归一化时刻、plan/seek-generation token；切回同一轨道对象、精确同一时刻及同token时，通过原字幕provider恢复该图，跳过重复的完整seek。新PGS/无已知图/播放中/位置或代次变化继续原seek与暂停解码通知路径。缓存每轨至多一个位图引用，不复制像素；时间推进、token不匹配、有效期改变或新的解码显示/清除集会使复用失效。外置字幕、普通seek、音轨及服务器配置未扩展改动。

涉及文件：

- `ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift`：暂停已显示cue捕获、匹配后跳过冗余seek，事件`subtitle_paused_display_reused`仍只是逻辑证据，不冒充屏幕显示。
- `ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/MEPlayer/EmbedDataSouce.swift`：有锁的单cue状态、精确时刻/token检查、原provider重放与新显示集优先。
- `ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/MEPlayer/FFmpegAssetTrack.swift`：每轨持有其复用状态，生命周期随原媒体轨道。
- `ios/Nastart/NastartTests/PlaybackNextCoreTests.swift`：五项新增反例，直接使用真实FFmpegAssetTrack/SubtitleModel与显示队列；覆盖切换清旧语言后的同图恢复、无限cue不能移到其他位置、plan/seek/轨道隔离、过期/未来/文本/被后续解码改结束的cue以及新clear集盖掉旧图。

## L0、包身份与安装结果

- XCTest结构化xcresult：**98 passed / 0 failed / 0 skipped**，含五个新测试；标准输出只列97个通过名字，缺行已核对，不用stdout漏行误报97或推断失败。模拟器iPhone17/iOS26.5，Xcode测试路径为Downloads版本。
- 正常Debug设备构建`BUILD SUCCEEDED`，Xcode路径Applications版本；preflight通过、git diff --check通过。没有测试环境变量启动，因为本轮App启动尚未执行，不将构建与安装当作启动验证。
- 18:52:03二进制，私有持久`Nastart-PausedPGSReuse-Debug.app`深严格签名验证。main SHA256 `eefefaeda73af08ceb473793699baac9af2aa4af026022a8040f3949cb9f019c`；debug dylib `d0ee7e8a6cb2abc4cbd36dabd5b6fd4c9773ae65c71a3ab16a9f260c8c0219b1`；KSPlayer框架 `568a9c04fe749c41718204be43839f3830e9786b282377c5199255863556e284`。
- 源码差异SHA256 `c991a9e272e95386cc27119eae17bf644c98c24fe22b1bedddd985ee41eced80`，与构建后快照一致。设备新包InstallComplete、ios-deploy退出0、安装后实际App元数据已读取。**正常无变量启动、实际启动画面和本轮最新包UI回归未完成**，仍待本机XCTest授权；没有新包首帧、字幕耗时或卡顿通过结论。
- 上轮302/6e2的暂停PGS5/5与626.086秒稳定观察全部保留为旧包证据；eef/d0不能引用它们作为自己的回归。整体系列原画卡顿未解决，Lenna/DS One双入口正式受控配对仍0，全部PX/UX原未验收状态保留。

## 恢复后的受控回归队列

1. 现场重读设备/USB/配对，核对上述包及源码；固定WDA ready后建立新无App session，记录session-id到私有`startup/session-id`，不能沿用上轮已失效会话。正常无测试变量启动并先取得真实启动/既有库证据。
2. S03原画LAN，先让真实PGS显示再暂停在已知cue；按同条件交替“保留轨道→恢复”和“PGS→ASS→PGS→立即恢复”，至少3次探索、5次功能重复。记录实际字幕、暂停位置、复用事件与完整seek事件（复用场景不应触发seek）、t3/10/30帧、储备/卡顿、Range边界、后续十分钟。
3. 反向与负例：关闭/返回、位置变化或真正seek后回PGS、未曾显示过的PGS、新plan、自然clear/结束、播放中切换；这些不能错误复用旧画面或旧语言。没有减少总等待/卡顿的受控证据前，不宣布性能改善。
4. 按音字幕共用范围补S01四单元、S03 ASS、S19 PGS、S11/S18音轨和iPad；缺失设备/素材单列。若后续扩到传输/解码策略，再执行runbook对应代表格式与双设备门槛。
5. 实际声音、完整帧时间/滚动与CB-01～26竞品继续排队，路线/配置/缓存未统一不得排名；不改用户竞品登录/服务器/缓存来伪造公平条件。

原始证据只留本机私有`DebugEvidence/2026-10-04-pgs-reserve-183835`，包含设备门槛、未提交源码前后快照、授权截图、WDA失败日志、测试/构建/安装/验签和偏好对照；旧基线由其`previous-evidence-path`指向上轮私有目录。脱敏机器记录见[本轮候选](../testing/IPHONE13-PAUSED-PGS-REUSE-20261004.json)。
