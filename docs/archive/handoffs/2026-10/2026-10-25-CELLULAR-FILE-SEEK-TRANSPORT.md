# 蜂窝大文件双入口定位与受信任路线连接复用候选

2026-10-25后续校正：下表18/3为完成回调时的原归属标签，现已证实不可靠，不作准确pinned统计。`finish`释放session后，nil/nil身份比较可反向误标，实际复用标志/时延不受此标签问题影响。按同transferID＋taskIndex的发出记录重关联，早期文件窗pinnedRoute 40复用/1新建；混合文件窗pinnedRoute 6/1、systemShared 67/1；JF窗systemShared 27/1，共144指标62项归属更正、0缺匹配。[校正结果](../../../testing/results/2026-10/2026-10-25-transport-scope-correction.json)与原计数并存，未追填原始日志。此时正常新包正在构建，不能将旧包离线重算当新真机回归。

2026-10-25 13:25阶段交接，性能主问题仍进行中。用户报告iPhone18蜂窝下设备文件播放《指环王》等大文件，seek后速度几K/几十K，JF无同样问题，授权用USB13真实蜂窝优化。18外出仍暂缓安装；此报告不能当13复现。沿28开放/114格，不新增重复编号。

## 基线、条件与保留失败

13现场USB/iPhone14,5/16.3.1，普通Debug空环境/参数，改动前移动基线包主SHA `d1e2aed691409851d541e98acb5b745c2079a109d09b8341e5b655f201fe07d8`、570广义输入/30签名，当前编译移动源0漂移。原Wi-Fi开关/原网Selected/原生Wi-Fi图及全偏好先私有保存。真实4G可见2/4格；归“用户报告弱蜂窝”，RSRP/RSRQ/SINR未知，不用格数冒充定量。无人工限速/VPN/NAS/凭据修改。

S19设备文件根目录实见120GB，同完整文件名/路径归本机；Range完整长度128795641934。正常默认体验先测，文件字幕Off、JF8/PGS和起点不同，不作严格配对排名。

- file-cellular-4：1次正常播放，原publicDomain Range/KS→自动兼容localHLS/AV；初步目标4Mbps来自原策略（本地已存的1MiB网络体probe约10.8Mbps），不是强制注入。+15秒内部恢复4676ms，后实际电影帧已看；后退因AX隐藏缓存未发，非播放器失败。21完成URL metrics全cellular=yes/h2。退出工具失败后主动terminate；finally第一次只确认开关未确认原网，后11:50原生完整Selected/开关和正常首页Wi-Fi图确认恢复，保留原restoreFailure。
- jf-cellular-3：正常S19默认字幕8，原流→自动HLS/AV，+15/-15内部恢复2150/706ms，真实画面及字幕已看，普通回详情；25 URL metrics全yes/h2，finally停止自有App并核原网/设置，完整帧/声音未验。
- file-cellular-buttons-1：正常原流/KS，前进20次、后退20次每次15秒，actual seek_started共40次，正向最终314.076秒、反向15.577秒，分别最后内部恢复7011/1694ms。范围有限，不是80%深段。期间原流体窗口约5.36–39.91Mbps（有数据窗口口径），恢复后重回每秒数MB，未复现持续几KB/s；静默等待时没有体窗口，不据此排除等待。48 URL metrics全yes/h2、proxy背压均0。普通完成控件定位失败，主动terminate，finally原网Selected/原开关/设置恢复。
- 进度条80%/15%及画面pan±300的两种输入实际均落0，已拒绝为远距性能证据，不继续同假设坐标调参；不是已证明产品seek错误。其正常网络/取流留存但不能拿0目标当80%。另有0播放/未切网的Settings前台/超时/工具路径失败，全部保留。现新建非quiescent控制session而不启停既有Runner、不改原50/10/2/auto全局设置。

每窗外层finally停止自有播放，再恢复原网/原生Selected/状态栏Wi-Fi；本轮没有并发媒体。`window-safe.wifiRestored=false`的旧窗以单独恢复回执补充，不能改写旧失败。内部时钟、命令回执、实际画面三者分开，无Release/全字幕/音听/帧时间验收，未称18旧问题修复。

## 连接复用候选与已核边界

原AuthenticatedMediaProxyTransfer：allowsSelfSignedCertificates=false时使用无Cookie/凭据的共享session；true时每transfer新建session，结束即invalidate。13 DSM保留自签证书信任设置，Range连续seek任务metrics均connectionReused=no，JF路线可复用；存在多次DNS/TCP/TLS/头等待。它是有依据的成本差异，尚未证明持续几KB/s唯一根因。

候选DevicesView.swift：每条代理Route创建PlaybackPinnedRouteTransport，仅本route同scheme/host/effectivePort任务共用；不跨route/账号共享TLS决定，跨origin沿原隔离处理；Cookie/环境Credential storage均nil，每请求query/header保持。session delegate调用原CertificatePinStore.credential(expectedHost:)，host不匹配/缺trust沿原规则拒绝；未修改既有CertificatePinStore首次保存/轮换行为，不能称强化证书校验。单transfer finish只cancel自身task；route unregister/六小时过期明确invalidate自己的pool，不能停同服另一route。系统信任原共享路线/Range窗口、回退/40秒/缓冲、码率/字幕/解码保持。新transportScope只记systemShared/pinnedRoute/isolated，原始端点不外放。

8个定向已通过：3个新定向为origin/账号注册隔离与无环境凭据、真实HTTP连续Range复用/撤销不影响peer、Reader reset后替换reader可读；另5个原Range/HLS/取消对照均通过。HTTP夹具不代替真机TLS/pin校验或性能收益。普通新包已在下节逐台安装并完成局部回归；此8项及HTTP夹具不等于全格式/双端并发或蜂窝性能验收。

[Apple认证挑战说明](https://developer.apple.com/documentation/foundation/handling-an-authentication-challenge)明确TLS信任在session范围生效，因此不能把已批准自签信任直接接到进程级共享session；这里只尝试同注册范围复用。该文用于委托语义，真实局部复用证据与完整性能验收分开。

私有根由`/tmp/nastart-cellular-seek-current-evidence`指向，含原始设备/偏好/URL/凭据/报告/图/包；不放仓库。下一步先按同实际路线/目标/轨道区分请求等待与KS seek完成/缓存及输出阶段；匹配条件不足不排名，无改善两轮停止盲调。随后补格式族与并发专项，保持完整验收开放。


## 当前普通包与逐机核对

普通Debug，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留的原dirty；本批只改移动`Features/Devices/DevicesView.swift`与对应`PlaybackNextCoreTests.swift`，TV不编译该传输实现。12:50:16构建，570输入及30个Mach-O签名/主包deep/profile目标/AppID/Keychain组已核；主SHA `f453254b97a6e68d0fc3ed790b28049b36492b7c9d57c1bac6f86da41f9c2525`，Debug dylib SHA `e4af1401d01453e868854dfb5c303c6e7ef18c4587548da9ac6e164ac950c84c`。免费profile至UTC10月31日23:30:06。13 USB/iPhone14,5/16.3.1于12:51:23、新Pad USB/iPad15,7/A16/26.6于13:02:17保留数据覆盖，安装前后全偏好均0变化，正常空环境/参数首页已实看。源码至13:24终核仍0漂移。18随用户外出暂停，不把13/Pad安装算18完成。

## 新包真实蜂窝与实际限制

以下均1次普通Play、真实4G、公开域名路线、无注入、同S19；保留用户报告弱蜂窝分组，射频定量未知。各自起点/字幕/自动KS与AV路线不同，不构成旧新或双入口严格性能排名。数据窗口是有正文到达时的bit/s，不包括没有数据的等待；内部恢复不是呈现恢复。

| 窗口 | 实际seek | 最终正/反目标（秒） | 最后内部时钟恢复（毫秒） | 完成URL指标/蜂窝yes | 连接复用 |
|---|---|---|---|---|---|
| file-cellular-pinned-buttons-2 | 正20＋反20次，每次15秒 | 349.500/54.001 | AV 9832/1451 | 75/75 | pinnedRoute 18 yes；systemShared 55 yes/2 no |
| file-cellular-pinned-early-1 | 10秒开始正20＋反20次 | 366.114/67.851 | KS 6009/9443 | 41/41 | pinnedRoute 3 yes；systemShared 37 yes/1 no |
| jf-cellular-pinned-single-1 | 正/反各1次15秒 | 9499.547/9508.501 | AV 1543/733 | 28/28 | 以安全JSON原指标为准 |

两轮文件实际出画已看，普通完成回详情均成功；JF原生实际电影帧已看。file-cellular-pinned-buttons-1是0播放的Wi-Fi开关定位工具失败，原网已恢复，不能丢弃也不算产品播放失败。S01 Wi-Fi脚本控制台沿用旧“S19 cellular”打印，但window元数据/实际片名/蜂窝no与原网Selected明确为S01家庭Wi-Fi，不能按控制台标签改网络分组。

新两轮文件的有数据窗口分别约6.31–42.43Mbps、5.09–32.57Mbps；尚未稳定复现用户18持续几KB/s。复用后仍有长等待，不能说总体seek已加速：第一轮混合路线首字节最大13.434秒/上游暂停累计最大7.291秒；早期KS窗首字节最大3.325秒/上游暂停最大414毫秒。取消已请求至URL完成回调两窗最大1毫秒，不能把这些样本的等待归为取消回调排队；也不能由此证明服务器无旧任务。TCP/TLS复用成立，仅证明省去部分建连成本。

早期KS窗最后回退：引擎seek完成4040毫秒、容量playable约9186毫秒、内部时钟恢复9443毫秒；flush后首解码回调1301毫秒/首接受帧1931毫秒，最后视频帧队列16帧跨度0.666秒/并集0.656秒，容量报告含packet约1.001秒并满足原1秒门槛。这些信号不是视频呈现证明，不能认定单一网络或解码根因。下一阶段应区分请求提交/flush前等待、数据供应、解码/队列就绪与实际画面，不先改既有缓存门槛或码率。

## 同包小片双入口与收尾

13 S01/JF、设备文件各一窗，3/10/30采样，±15秒各一次与普通完成回详情成功，实际电影像素已看；Pad S01同两入口各30秒实际电影与普通回详情成功。Pad仍呈桌面浮窗式播放，隐藏AX控制不能代替全屏控制像素，此呈现差异继续开放。未补并发/十分钟/S03/S08/S11/S18格式族/完整SUB/AUD/HDR/PiP；不能固化为全局性能通过或Release交付。

每个蜂窝窗外层finally停止自有App/媒体，原Wi-Fi开关及完整原网Selected已核，最终原生状态栏Wi-Fi图已实看；之后小片回归在原Wi-Fi完成。13原50/10/2/auto全局设置GET不变，既有未知Runner不启停；Pad自有Runner13:14:58实际核停，原设置GET恢复，正常空参数App重开。两机本批最终偏好仅自然playback.localResume/diagnostics变化，登录/主题/地址等其他值未改；原Pad VPN图标保持。无自有播放/下载/采集遗留。

[可分享结构化结果](../../../testing/results/2026-10/2026-10-25-cellular-file-seek-transport.json)只含白名单计数、时延和包身份，完整任务、端点、UDID、偏好及图片仅本机私有证据区。28开放/114格保持，未新增重复编号。
