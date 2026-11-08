# 文件备用流的源轨道继承

本批收尾 2026-10-09T17:07:32.650394+08:00：最终源diff `9dc1942a`、普通包 `8f5c/da56/KSeda1` 已逐机保留数据覆盖iPhone13/iPad。218测试（2跳过/0失败）与15预检通过；新源20常规窗/20实际电影/20普通退出，加2组接手后暂停、+15秒seek、退出、继续观看验证完成。文件四个弱网窗均明确提交并保留真实源轨道，绝对时间轴及断点定向观察未再出现重复偏移。**播放性能仍FAIL：8弱窗全部起播后再缓冲，7常规窗内部起播钟超目标；iPad追加续播再缓冲1→2保留。** 另1次iPad工具定位失败/恢复退出独立保存；最新正常空环境、实际首页及两机条件全inactive已核。全PX/UX/CB/L2整体/竞品/Main未关闭。

安全数值快照：[FILE-TRACK-HANDOFF-20261009.json](../../../testing/results/2026-10/FILE-TRACK-HANDOFF-20261009.json)。第一/第二包失败分别冻结，旧包证据不迁移；完整UDID、偏好、URL、凭据及原始图/诊断仅在本机私有证据目录。

## 开发过程检查点（下述“待验证/进行中”均为当时状态）

问题/关联：PX-03/PX-08/PX-09/PX-21。承接2026-10-09-WIFI-FILE-FALLBACK.md：基线HEAD4de732dd、diff4bdd、普通97a1/77b0，旧包20窗独立保留，四个文件弱Wi-Fi窗口0候选/0接手。旧包S03两机实际audio stream index4、字幕Off；手机MI2实际audio1/subtitle5。第一音轨/Off资格不能覆盖当前真实选择，不能更改用户轨道来凑通过。

最小修改：在已核实FFmpeg原流上记录AVStream.index；严格同文件match按全局index及类型唯一性校验音轨/内嵌字幕，不依赖元数据数组顺序。对未知/歧义或非FFmpeg身份继续原流。协商候选显式请求音轨；内嵌字幕采用服务端Encode并核返回URL轨道/字幕方式；外置字幕保留当前实际URL，Off不恢复旧外置URL。候选、后续降档、菜单、服务器seek与断点继承同一源轨道；已协商请求不再被旧书签的Off/音轨覆盖。取消继续释放晚到资源。自动候选提交门槛/码率/Range/解码/超时不改，不按片名添加策略。

L0：旧4项惰性/拒绝/取消测试适配明确源index，增加非第一音轨/内嵌与动态外置字幕、错类型/重复/未知index、URL协商不一致、runtime外置与Off区分、旧书签覆盖反例；全核心测试/15预检/普通Debug编译。首轮编译发现构造不可变runtime后修改let字段，已改为完整构造，首轮失败日志保留；最终L0尚待运行结果。

L1：新普通包现场逐机验签保留数据覆盖、偏好与正常启动核验后，重复S03/MI2文件与媒体库180秒受控家庭Wi-Fi失败操作；候选准备/提交及实际画面/轨道与退出分别取证。L2：基础S01四单元、S03/S08代表集，涉及字幕另加S19 PGS/S11 TrueHD/S18 FLAC与外置、暂停/seek/退出组合。声音/全字幕cue/画质/十分钟/完整帧/PiP单独验，不能用URL或菜单代替。未触发L3发布/架构迁移，原全部矩阵状态保留。

当前两机重新读取USB：iPhone13 iPhone14,5/iOS16.3.1，iPad iPad12,1/iOS18.3.1；原始UDID/偏好/诊断只留本机私有目录。源码正在修改，设备仍为97a1旧包，尚无本批新源真机回归。当前仅家庭Wi-Fi，真实家庭外Wi-Fi仍待用户接入条件。

记录时间：2026-10-09T15:04:49.225106+08:00

开发过程失败保留：第二轮测试编译缺@MainActor，已修正；第三轮未知字幕反例发现无源字幕index仍先执行match，增加提前拒绝。验证重跑曾与未完成测试同时启动，已停止本任务两次运行，结果不采纳并改为串行验证；普通构建首次成功仅为修改前产物，待最终源码重建。预检脚本缺可执行权限的首尝试exit126保留，改用bash执行、不改文件权限。

2026-10-09 15:10：217测试/2跳过/0失败及15预检；新普通a145/4bb0/KSeda1（diff f8d248ec9ad5d1f491a7f465d0c3a554653565e72620b42609b7c23d6aed2e69）29库/deep签名、137输入/链接已核，双机保留数据覆盖、25/16偏好与真实正常启动已核。新源真机播放尚待完成，旧20窗不移用。

最新包路径：/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-file-track-handoff-141330/Nastart-File-Track-Handoff-Normal-Debug.app；构建 2026-10-09T15:08:18.836162+08:00；完整二进制SHA-256：{"Nastart": "a145d4fe2420405eba3bfa6904e86eab76fedc9f8725012ac468ad9972d7aee1", "Nastart.debug.dylib": "4bb03a63aac9c6758d600fff10ffb392919e1b6d405d4fb32d4962dc64c7afc6", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}。

## 第一包反例与协商表示修正

普通a145/4bb0/diff f8d248手机S03文件180秒：真实电影t180/普通退出和条件恢复已核；最大5次缓冲，两次audio4/Off协商被URL校验拒绝，0新文件准备/提交。该单窗与完整安装证据独立冻结在第一阶段私有目录，不归最终源码。协议核对发现Jellyfin明确在ToUrl中省略SubtitleStreamIndex=-1，PlaybackInfo的DefaultSubtitleStreamIndex仍可明确确认Off。见[Jellyfin StreamInfo源代码](https://github.com/jellyfin/jellyfin/blob/master/MediaBrowser.Model/Dlna/StreamInfo.cs)及[MediaInfoHelper](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Helpers/MediaInfoHelper.cs)；官方当前源码仅说明协议表示，现场服务器版本不由此推断。

修正只允许“URI明确-1”或“URI未带字幕index且本次PlaybackInfo明确返回-1”；缺少URI及响应确认、与响应冲突或重复参数仍拒绝，不改写服务端URL、不放宽音轨/同文件身份门槛。另增加安全数值诊断（返回audio/subtitle index及URI值、无URL/token）。需最终源码重测、重建签名逐机保留数据覆盖，随后重复该失败及其他轨道样本。

2026-10-09 15:18 最终协议修正L0：217测试/2跳过/0失败、15预检/普通Debug -Onone构建通过。HEAD 4de732dd645b36671becff992cdef1d0163fd1e4；diff f679909551f6064dfb8f6b74910eeda5f48a6cfc0810168622e291f5ab9095ea；包 /Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-file-track-final-151543/Nastart-File-Track-Handoff-Normal-Debug.app；构建 2026-10-09T15:16:10.415427+08:00；29库/deep签名、137输入及链接已核；SHA-256 {"Nastart": "6b04d6eeaa09c536ee24c4827a2f5671812e3e3ec57ba29ad23f884d8193c66b", "Nastart.debug.dylib": "89079ad8c8e0d63f31c91e7c48c469cb79256cb62c9c42a91b1b20466d18eb45", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}。两机重新覆盖与最终新源回归继续，第一a145单窗独立保留。

2026-10-09 15:19：最终源diff f679909/普通6b04、8907、KSeda1已逐机现场验签保留数据覆盖，25/16偏好与正常空环境启动及实际启动台核实；217测试/2跳过/0失败和15预检通过。新源播放回归开始；第一a145单窗与旧97a1的20窗分列。

15:28 最终f679第一S03文件窗已有originalFallbackPrepared/audio4/Off和明确提交、实际电影/普通退出；原KS及接手AV各最大1次缓冲。随后发现文件入口仍将完整HLS时间轴加timelineOffset，断点轨道4/Off虽保留，但位置出现重复相加风险，不能验收。已停止后续阶段的调度进程，仅让当前手机三窗完成原观察/普通退出和条件清理；iPad新源播放尚未开始。下一步显式标记协商流为绝对内容时间轴，并重核最新包及原反例。

2026-10-09 15:41 时间轴修正：明确资源相对/源绝对时间轴，协商HLS与复制请求保留源绝对语义，模型不再重复加服务端起播偏移；218测试/2跳过/0失败及15预检。普通Debug -Onone，HEAD 4de732dd645b36671becff992cdef1d0163fd1e4；diff 9dc1942a4d410f7c50197237f8f79f9ce3b1395eab3f9502a34dd5e24d41b6b2；构建 2026-10-09T15:41:08.876661+08:00；包 /Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-file-track-timeline-153652/Nastart-File-Track-Handoff-Normal-Debug.app；SHA-256 {"Nastart": "8f5c5ab47b1102ce11b6fb8c74124d18b6afac7457e74b267503783bd3815ecd", "Nastart.debug.dylib": "da5658c6c85082e5d63ae4b51ddb0c84bd4f5758c6ad764af4beae5b0be918fc", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}；29库/deep签名/137输入及链接通过。两机新包安装核对进行中；6b04阶段仅手机4窗，缓冲及断点反例保留，不能当本源回归。

2026-10-09T15:42:51.658635+08:00：两机最新8f5c/da56/KSeda1普通包现场USB/配对/型号系统/签名/安装核对完成，保留数据覆盖，25/16项非诊断偏好一致，空环境正常启动与实际正常启动台已逐机核实；iPhone14,5/iOS16.3.1及iPad12,1/iOS18.3.1；完整UDID在私有安装证据。新源手机S03文件180秒复测开始，未将旧包播放算入。

2026-10-09T15:57:23.905758+08:00：新源手机S03文件/媒体库与MI2文件已保存退出证据；两文件分别audio4/Off、audio1/sub5明确提交，接手video_output底层/界面时钟差均0（S03 60.546668667，MI2 13.036689084），实际t180电影及MI2双语字幕已核。该样本不证明完整声音/字幕/画质/帧时序；起播后缓冲仍FAIL。手机最后媒体库窗完成、条件清理后已开始iPad逐机新源定向回归，仍无整项验收。

2026-10-09T16:22:57.969271+08:00：新源受控弱Wi-Fi双机八窗已完成、8电影/8普通退出/原生条件恢复核实；4文件均严格源轨道继承并明确提交（13 S03 audio4/Off、MI2 audio1/sub5；iPad S03 audio4/Off、MI2 audio2/sub5），共9次两个入口候选提交。接手采样未见数十秒重复偏移；iPad异步界面/底层采样差-0.0505/-0.1022秒，不作为提交门槛或显示帧证据。八窗起播后缓冲仍FAIL，iPad三窗内部起播超目标。手机普通六窗已完成，iPad普通代表六窗进行中；暂停/seek/继续观看组合未执行，整项不验收。

2026-10-09T16:49:18.222067+08:00：新源二十个常规窗（8弱180秒+12普通60秒）已完整保存/逐图看电影/20普通退出，8弱窗起播后缓冲、7窗内部首钟超目标仍FAIL。手机S03追加120秒接手后暂停109.354→暂停seek124.353，普通退出断点124.353333及audio4/Off一致；普通Wi-Fi继续观看初始KS clock124.353，暂停真实显示02:32保持，等待落盘断点152.116/audio4/Off。两秒闭页原始磁盘快照仍138.078且最后遥测151.198先于暂停；补读证实落盘滞后与旧遥测口径，不计App断点FAIL，原快照保留。iPad追加MI2首轮在暂停注入前被TOOL AX名称/标签守卫挡住（name=pause.fill,label=暂停），120秒窗口/原非正常观察退出保留；拉取报告仅见12:03旧源Nastart报告，当前App/movie前台存活；条件已恢复/普通恢复退出另记。修正私有定位规则后iPad独立重跑操作窗，不修改App源码，不覆盖失败。

## 最终包身份、逐机核对与收尾

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留当前未提交修改；iOS未提交diff SHA-256 `9dc1942a4d410f7c50197237f8f79f9ce3b1395eab3f9502a34dd5e24d41b6b2`。普通Debug `-Onone`，无测试启动环境变量、无性能构建；构建 2026-10-09T15:41:08.876661+08:00。包路径 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-file-track-timeline-153652/Nastart-File-Track-Handoff-Normal-Debug.app`。137受检输入无晚于产物、29库及deep签名/链接已核，描述文件有效至 2026-10-10T22:03:15 UTC。

| 二进制 | SHA-256 |
|---|---|
| Nastart | `8f5c5ab47b1102ce11b6fb8c74124d18b6afac7457e74b267503783bd3815ecd` |
| Nastart.debug.dylib | `da5658c6c85082e5d63ae4b51ddb0c84bd4f5758c6ad764af4beae5b0be918fc` |
| Frameworks/KSPlayer.framework/KSPlayer | `eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52` |

| 设备现场名称/型号/系统 | 覆盖安装及偏好 | 最终正常启动/实际首页 |
|---|---|---|
| iPhone（iPhone13） / iPhone14,5 / iOS16.3.1 (20D67) | 2026-10-09T15:41:34.790734+08:00，USB/配对/有效签名及目标UDID已现场核对；保留数据安装success，25项非诊断偏好一致 | 2026-10-09T16:55:24.041942+08:00，新鲜身份/三二进制一致；实际进程env={}/args=[]、播放器关闭、实际首页已看 |
| iPad / iPad12,1 / iOS18.3.1 (22D72) | 2026-10-09T15:42:19.591956+08:00，USB/配对/有效签名及目标UDID已现场核对；保留数据安装success，16项非诊断偏好一致 | 2026-10-09T16:55:30.895136+08:00，新鲜身份/三二进制一致；实际进程env={}/args=[]、播放器关闭、实际首页已看 |

iPhone18未连接，未安装本8f5c新包，不声称完成其最新源回归。私有证据 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-file-track-timeline-153652`；完整设备身份、原始偏好、媒体位置/URL及凭据仅留这里。每个播放窗都有现场设备读取/本包二进制/源码witness，初始普通实际启动证据与逐窗观察独立。收尾条件重新读取均activeCount0，idleWait10/animationCoolOff2恢复，WDA ready/未重装，未卸载或清登录，无无线/NAS/路由器/VPN配置修改。

## 最终源回归结果与限制

20个常规窗口：8个S03/MI2 × 文件/Jellyfin × 双设备受控家庭Wi-Fi180秒，12个S01/S03/S08 × 双入口 × 双设备普通家庭Wi-Fi60秒。20个实际电影与20个普通退出均逐图/界面核实。受控原生SlowNetworkWiFi现场40Mbps下行/33Mbps上行、双向各1ms、0丢包；只证明家庭LAN下受控网络上限，不证明弱无线信号、家庭外Wi-Fi/外部路由或蜂窝性能。当前用户只提供家庭Wi-Fi，真实外部验证后补。

8弱窗全部起播后新增缓冲，L1性能FAIL。各渲染trace的最大计数如下，按时间顺序列出；换引擎计数会重置，不能跨引擎相减。AV丢帧unknown，不用未知当0：

| 设备 | 样本/入口 | 各trace最大缓冲 | 各trace最大丢帧 | 结果 |
|---|---|---|---|---|
| iphone13 | mi2-file | 2 / 0 | 4 / unknown | FAIL：起播后缓冲增加 |
| iphone13 | mi2-jellyfin | 1 / 1 | 0 / unknown | FAIL：起播后缓冲增加 |
| iphone13 | s03-file | 1 / 1 | 3 / unknown | FAIL：起播后缓冲增加 |
| iphone13 | s03-jellyfin | 0 / 1 | 0 / unknown | FAIL：起播后缓冲增加 |
| ipad | mi2-file | 1 / 1 | 5 / unknown | FAIL：起播后缓冲增加 |
| ipad | mi2-jellyfin | 1 / 1 | 7 / unknown | FAIL：起播后缓冲增加 |
| ipad | s03-file | 1 / 1 | 5 / unknown | FAIL：起播后缓冲增加 |
| ipad | s03-jellyfin | 0 / 1 / 1 | 12 / unknown / unknown | FAIL：起播后缓冲增加 |

7个常规窗内部起播钟超过既有route目标：iPad弱S03文件/媒体库、弱MI2文件，以及双设备普通S08两入口。12个普通60秒窗内未见起播后计数增加，不作为十分钟、音频、显示帧或完整画质PASS。缓存/NAS负载/VPN控制不严格，不做因果提速或竞品排名。

四个文件弱窗的当前源轨道与明确接手：手机S03 audio4/Off、MI2 audio1/sub5；iPad S03 audio4/Off、MI2 audio2/sub5。8个弱窗两入口共9次明确replacement_committed（iPad S03媒体库2次）。首文件接手videoOutput raw/control：手机S03 60.546669/60.546669，MI2 13.036689/13.036689；iPad S03 67.025489/66.975002、MI2 11.482185/11.380001。iPad为异步采样差-0.05049/-0.10218秒，不用此采样或旧replacement_committed缓存UI秒数评判实际提交门槛，也不作为呈现帧证据；本改动未放宽100ms持钟/150ms帧/500ms储备门槛。

## 暂停、seek、断点和继续观看定向验证

- 手机S03文件：本源独立120秒弱网窗明确接手后暂停109.354秒保持，+15秒paused seek至124.353秒保持/电影画面改变，普通退出保存124.353333及audio4/Off。恢复普通Wi-Fi后同文件继续观看初始KS clock124.353匹配断点；再次暂停实际02:32保持，落盘保存152.116/audio4/Off。两秒退出后磁盘原快照138.078保留，补读显示NSUserDefaults落盘延迟；最后遥测151.198早于暂停，不据此判App断点错误。
- iPad MI2文件：首独立120秒窗在暂停注入前因AX `name=pause.fill,label=暂停` 与工具仅匹配name不符而TOOL失败；原普通退出false、条件自动清除后普通恢复退出true分列。保留全部Traceback/快照，拉取17份报告中唯一Nastart12:03旧源报告，现有报告未发现本次对应App crash；这不证明报告目录以外无crash。修正私有观察定位为name或label，无App源码变更，另开独立120秒重试，原失败不覆盖。
- iPad独立重试：接手后实际暂停01:34，+15秒seek目标109.403114，raw/control109.401667、输出PTS109.400956，实际01:49电影/双语cue保持，普通退出保存109.401667/audio2/sub5。普通Wi-Fi继续观看初始109.402匹配，实际02:17电影保持/本时点无cue，退出保存137.232/audio2/sub5；续播KS缓冲1→2仍FAIL，轨道/断点一致不等于流畅。

最终23个有界播放窗口（20常规+3追加）均有实际电影检查，22原普通退出+1原TOOL失败后的独立恢复退出；另2个继续观看链各正常退出。不得合并计成25个等价基线，120秒后操作与后续续播数据也不混入有界窗口的起播/网络计数。两条暂停/seek/断点链只是定向功能观察，声音、完整字幕/帧序列、强杀重启持久性、手动轨道组合、活动外置字幕、HDR准确性/PiP/长后台/十分钟仍待验。私有工具38文件和SHA清单已冻结，原失败Traceback保留；只存最终工具版本，不伪称重建首次失败版本。

## 下一步（未关闭项目）

优先对同一源码的8弱窗按原流、候选冷启动和接手后HLS供流分段，定位起播/再缓冲的具体请求及储备耗尽；保留失败窗口与原服务端响应，再提出最小修改。下一次源码变动必须重新构建/核签并逐机保留数据覆盖后重测这些失败，不能直接沿用本包。之后补S19大偏移/尾索引、真实弱蜂窝/弱家庭无线与家庭外Wi-Fi；轨道手动切换、活动外置、S11/S18/S19字幕音频格式及大seek、音频/完整字幕/画质/十分钟/PiP/完整显示帧。Lenna主对照与其余竞品按原矩阵同条件同计时/完整位移帧证据补测，正式配对0。全部PX01–21/UX01–06/CB26/19×4及Main保持开放，未提交或推送。
