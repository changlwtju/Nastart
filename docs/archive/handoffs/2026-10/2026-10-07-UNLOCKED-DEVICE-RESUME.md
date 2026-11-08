# 无锁屏密码双设备接续（本轮检查点已记录，整体未验收）

2026-10-07 07:02：已读取PROGRESS、当前交接、调试规范、分层流程、PX/UX总账和竞品矩阵。用户报告已取消iPhone13和iPad锁屏密码；现场USB两台、配对成功。iPhone13/iPhone14,5/iOS16.3.1/20D67；iPad9/iPad12,1/iPadOS18.3.1/22D72。iPhone18仍CoreDevice unavailable且不在usbmux枚举，未安装或测试。

当前源码HEAD 9a9941cd4ec82625f680b5193b3a0f66797eb851，保留全部既有未提交修改；iOS diff SHA256 303411ba71c8ed306824efe6eac61161928957f7f5f6611912c5268665aea501，与上一轮135核心测试源码一致。复用06:10:51普通Debug -Onone签名包Nastart-ManifestQuery-Debug.app，main ac5dbba6355893bccb90e0a901c99e9e5a5a76eb837eeda5eb7054075bc9bca2，debug dylib bf0bfadee6177e6dbe7640a4d897235b707eea31fcda78751b9ac72816234491，KSPlayer c814c6b3f8d1beaddef93e8c77935aa9d653835244ae7a0b772d9900e709a704。29动态库逐个验签、双方profile资格和有效期核验。两台先保存诊断，均保留数据覆盖安装成功、25/14项非诊断偏好一致、空环境普通启动/实际前台XML及PNG已取证；完整UDID/包路径/原始偏好只留本机私有目录。

上轮06:23 USB断连导致manifestWeakBigLatestS03及finally恢复中断，不能沿用为完成结果。历史manifestNormalBigLatestS03遥测88.887秒0缓冲/3丢帧，内部首帧3.503秒；manifestWeakLatestS01清单预热18.424秒、内部首帧23.414秒，首帧后96.492秒缓冲计数无新增。仍非完整显示/听音验收。清单master数值Params压缩已生效但仅726→684 query bytes；media原始体积1,407,448 bytes，1790段，较旧1,482,628 bytes下降约5%，等待仍长，不能判修复。回放和编码预算/轨道身份仍待细核。

本轮iPhone13实际condition groups inactive已核；iPad未注入限速，完整条件组复核未单独留证；iPhone设置初次读取早于页面加载，保留TOOL；复读后明确Wi-Fi ON且已连网，本轮原无线状态以此记录。两机WDA恢复曾ready/unlocked，iPad源码树采集发生远程连接失效，Nastart进程仍在，先保留工具日志/崩溃报告再复用已安装同一Runner及历史Xcode恢复，未重装WDA。不得把工具恢复推断为App回归。

当前：iPhone13正常LAN MI2 120秒自然回归；iPad显示采样预检ready，但实际滚动/Lenna和新的完整显示证据尚未采集。PX/UX/CB全部历史缺口保留，正式竞品配对0。下一步闭环最新LAN/弱蜂窝大文件及控制，推进iPad/Lenna滚动；失败与超时全部保留。


07:09 检查点：169个App/项目源码资源文件mtime无晚于06:10:51产物项。最新iPhone13 LAN MI2 119.399秒遥测0缓冲/1丢帧，首帧内部2.432秒，t=10/30/60/90/120实际画面变化、普通退出PASS；不是逐帧全局流畅验收。最新弱蜂窝S03（120秒动作边界）清单19.149秒、media 1,607,998 bytes/1880段，下载17.112秒、重写43ms；相对旧未压缩1,726,438 bytes少约6.9%，同250kbps总预算/122kbps视频/AAC，服务端缓存unknown，不能做因果首帧改善声明。内部首帧27.564秒，屏幕t30黑场、t60/90/120真实电影与字幕可见；首帧后90.508秒缓冲计数无新增、初始stallCount1，AV丢帧unknown。首次可辨电影帧的稀疏上界60秒；内部事件不当屏幕精确首帧。设备条件全inactive、Wi-Fi ON及最新普通启动台恢复完成。随后同包弱蜂窝S01+暂停seek/恢复串行取证中。

iPad r1实际仅7次手势/6次位移，180秒录制先结束，保留INSUFFICIENT。记录已正常传回，非App播放/滚动FAIL。工具改进：WDA源码查询跳过未用于门槛的accessible属性；实际复核保留visible、坐标/名称而无accessible，单次查询10.822秒。每轮最多24次尝试，到12次真实位移停止，边界回弹保留为无效动作；不降低12次有效/显示30Hz及50ms连续性门槛。新增“保留回弹后补够12次位移”反例，16项工具测试通过。r2将录制预算扩到300秒，完整显示结果待验。实际iPad Lenna仍1.0.16(539)、Jellyfin1.5.0(5.5.0.0)。正式竞品配对仍0。


07:16 检查点：iPad r2只完成4次真实位移，第5次source期间Instruments报告Device got disconnected、XCTest remote process连接失效；现场usbmux/CoreDevice随即仍在线，Nastart仍在，无新Nastart崩溃报告证据。保留TOOL/INSUFFICIENT，不能声称物理拔线或App卡滞，未重装Runner。正常结束并传回139.454秒部分trace，TOC可导出。再次复用同一已安装WDA/current Xcode恢复ready及session。Lenna同设备1.0.16(539)实际进入已有“我的 Jellyfin”，开始同坐标/同脚本自动采样，current Xcode环境与前两轮Downloads主机不同，均仅探索，正式配对0。

弱S01内部首帧26.287秒、清单16.619秒，首帧后92.983秒无新增缓冲、初始计数1/AV丢帧unknown。暂停01:47保持、+15s seek实际新画面及02:02在首张截图出现，seek completion=true、控制122.532/输出PTS122.522，画面更新上界1.215秒（从触摸释放）。但约seek后33.334秒播放器回详情、playback_ended，无明确关闭操作或错误原因证据；原因未判定。旧控制工具仅核App前台，随后“播放”误点同名详情按钮，实际创建新trace/KSPlayer黑屏，不能把它记作原AV播放恢复失败。保留该工具失效/意外退出；新控制重复增加播放器实际存在守卫，防止同名按钮串页，弱S01同条件独立重跑中。原旧seek黑屏/暂停长期退出问题不关闭。


07:33 本轮结果检查点：弱S01独立守卫重测`weakPauseSeekGuardedS01`内部首帧20.816秒，清单16.534秒；82遥测/102.451秒，首帧后98.497秒计数无新增（初始1，AV丢帧unknown）。暂停01:53→+15s至02:08，新画面截图上界1.220秒、目标画面至少保持36.722秒；恢复新画面上界4.512秒，实际时钟02:11，播放器保持呈现、普通完成退出已核。原意外返回详情未复现于这个样本，原因仍未确定，旧失败和音频/精确落点缺口不关闭。

iPad/Lenna滚动：r1 7尝试/6位移，超出录制；r2 4位移后开发者连接失败，USB仍在线；r3尚未动作，SwiftUI同名Other/Button页面标识歧义，TOOL保留。工具改为“当前类型/name/rect + displayed=true”唯一绑定，跳过无用全树accessible/visible计算，保留全部检查时间与原始树，最多24尝试补到12真实位移；18工具测试通过。r4确实12次/12位移、129.177秒，但录制报配置缺失和Failed starting ktrace session，INSUFFICIENT。Lenna1.0.16(539) r1 21尝试/12位移；124.129秒动作窗口超过120.428秒trace，195唯一vsync时间仅0.351–7.548秒，后续动作没有显示覆盖。即使hitch16.762ms且表面比率低，也不能判流畅。环境/缓存/端点/构建资格不齐，正式配对0，不排名。

iPad同最新普通包新增`unlockedPadMI2LAN120`，每轮现场设备/源码/二进制/独立安装收据复核，新普通进程空环境启动。t3自然黑场，t10标志、t30城市、t60人物及Bellerophon双语字幕、t90动作、t120人物与双语字幕，画面已目视核对；仅证明稀疏画面变化。读取到的诊断文件最新时间仍为07:13:13.991，早于07:28:32.267播放请求；t60/t120、退出静置和普通重启复读一致，无本轮播放计数。保留原始日志/偏好，不解释为0缓冲/0丢帧。遥测持久化/读取与实际引擎路由身份缺口待定位，不能沿用旧记录。首次关闭使用完成作为name发生TOOL；现场XML核实name=xmark/label=完成并实时displayed核对后正常退出，结果已取证。

收尾：两机最新普通Nastart启动台、空环境、无播放器，WDA ready/unlocked及idleWait10；iPhone13限速/热条件全部inactive、原Wi-Fi ON已恢复，iPad本轮未注入限速或更改无线。覆盖安装立即25/14偏好一致；播放后手机仅本地续播条目有变化，iPad14项复读一致（不据此推断没有播放）。所有原始UDID、偏好、连接/凭据、设备日志仍本机私有目录；仓库只有脱敏标量。App源码本轮未改，仍同135核心测试对应源码/06:10普通产物，未把工具改动当播放器性能修复。

下一步优先：定位iPad诊断记录不刷新与可用显示采样；继续弱蜂窝长VOD清单实际传输/编码预算和旧暂停seek/意外返回详情；恢复完整共同计时后补Lenna及DS One Jellyfin/DSM各条件至少五组，以及音轨/字幕精确cue、PiP/HDR/代表格式/设备矩阵。全部PX/UX/CB保持未验收，iPhone18仍离线，本轮未安装或回归。脱敏结果见[本轮量化](../../../testing/results/2026-10/UNLOCKED-DEVICE-RESUME-20261007.json)。


07:36 用户追加范围强调：弱蜂窝下大体积《碟中谍》《指环王》必须继续推进，设备文件与Jellyfin入口同步优化和独立回归。已把MI2/S03/S19及双入口缺口写入[执行卡](../../../testing/WEAK-CELLULAR-LARGE-FILE-DUAL-ENTRY.md)，下一轮先补设备文件与S19最新弱蜂窝；保留本轮S03部分证据和所有未验收项。此处只更新范围与优先级，未新增真机测试或App修改。
