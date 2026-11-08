# 原流路由等待修复与 Apple TV 首版

更新：2026-10-18 18:02，手机回归已收尾，电视开发连接待完成。最新现场在[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)，需求状态仅在[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。

## 问题、改动与边界

用户报告 iPhone18 蜂窝大文件长时间首帧等待/零速，要求实际改进，并启动 TV 开发安装。此前 Jellyfin 原流探测要结束后才轮到可用的 DSM 文件原流，网络首字节等待可串行挡住另一条已配置路线。本批将同一原文件的两条认证 Range 探测并行，先校验成功者返回，取消另一条；失败的首结果不丢弃剩余候选，两者失败才交回原有后续协商。只在选出胜者后创建代理，未提前生成 HLS/解码器，未改超时、画质、轨道或 seek 精度。复用 warmup 的取消逐层传递；取消的 DSM 探测不写路径不可用缓存。

这仅修正已证明的客户端串行等待，不代表所有零速由该分支引起。HLS 首分片等待、自动接手/旧 cue、大文件吞吐与最终 iPhone18 蜂窝用户体验仍需验证。规则测试覆盖快 DSM/快 Jellyfin、已有探测取消、先失败、双失败、无 DSM、父任务取消与晚 URL；30 项定向测试零失败。未执行完整 Swift 全套，历史五失败不改写。

## 包与真机

普通 Debug/-Onone，Xcode27；最新源码 diff `9a878e3076c493408a7f365a67375f9f8f5dc46afb8b0dd620e29f6655821abf`，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`。173 输入，29 库逐一和 deep/strict 签名、三设备有效 profile 与链接隔离通过。包/原始偏好/UDID/截图都在仓库外私有区，指针 `/tmp/nastart-oct18-routes-evidence`，工具 `/tmp/nastart-oct18-routes-tools`。

三 SHA：
- `Nastart`：`c276f79dbd9ad09b45cc1ec84014f3ee6d3267be09e927f0b378d5e8c0aff9b2`
- `Nastart.debug.dylib`：`82ca70d71f9680564d46aaa04e3618bf3755acdb3b75898f171d1bf6ed08a30a`
- `Frameworks/KSPlayer.framework/KSPlayer`：`11f52e533ddad2b277a10c5d9c0aad0ff8cc22b3f9664a37aeff18064955a1e5`

- iPhone13 USB / iPhone14,5 /16.3.1 与 iPad USB / iPad12,1 /18.3.1 现场名称/UDID重核并保留数据覆盖，25/18偏好逐值保持，空环境首页实际已看。S01 两入口30秒普通退出；Jellyfin胜者均为原流，路由55/156ms，非蜂窝基础功能证据，不是性能配对。
- iPhone18 Wi-Fi / iPhone19,7 /27.0 实时身份与现有配对通过，17:06:30 安装 Complete+lookup，25项非诊断偏好完全保持。首次 RSD 启动 DTX 错误保留；单独启动请求/截图成功，但实际为系统设置 Developer Mode，不能算 Nastart 首页或新包播放验收。
- 导航脚本曾未处理保留的服务详情/搜索页，WDA404/超时保留；双机中途 App/WDA/Jetsam计数未增，不归作媒体失败或丢掉。未卸载/清数据/回写旧书签。

## iPhone18历史真实启动补证

从本次安装前备份的1000条旧日志中按同一playbackTrace匹配三次首帧：7241/8174/5333ms，原流探测1381/2259/493ms，媒体open约707/6575/2205ms；起点分别在3769/1339/1559秒附近，streamInfo约120/57/13ms。这些历史窗口关联的URL metrics均为cellular=no，不能写成用户蜂窝复现；一次尾部索引请求TTFB约3572ms，仅1636bytes，另有约2s/1.4s首字节等待，仍需完整Range/时间轴关联判断客户端顺序和网络端影响。数据说明至少有打开媒体、初始定位/输出容量等阶段等待，不能把所有慢启动归到串行探测，更不能把重叠阶段直接相加。旧安装的二进制身份未在这些历史播放窗口独立重核，明确是故障线索，不是新包回归或网络/服务器根因证明。原始用户内容/身份不导出。

## TV 首版

新增[独立工程](../../../../tvos/README.md)，SwiftUI焦点导航、Keychain独立登录、Jellyfin媒体库/搜索/分页/详情、原生AVKit播放/续播/上报与本会话停止编码。兼容HLS为20Mbps/H.264 1080p，保留可用MP4直放；设备文件、完整音字幕及HDR输出仍未迁移/验收。8规则+1普通启动UI测试通过，模拟器登录画面实际已看，真机平台无签名编译通过。

用户已在Mac输入电视验证码。曾发现真实第三代4K/tvOS18.2但不可用(-29)，后续两版Xcode无可用真实TV。不能把tvOS27模拟器当物理电视。用户提供当前IP后定点确认 remote pairing/companion 广播与端口，原生工具仍不能定位该开发目标；第三方现有配对验证false、没有可用的本客户端记录，不自动重配。最初仅凭临时DH密钥误判的私有观察已由协议完整验证纠正，不能据此声称已通过认证。签名服务报告团队无tvOS设备及无profile，因此只有明确标注无签名的开发产物，尚未发送电视安装。

## 新包真机窗口与等待边界

[结构化结果](../../../testing/results/2026-10/ORIGINAL-ROUTE-RACE-AND-TV-20261018.json)记录14个普通退出窗口；每个仅一轮、缓存未知，非性能验收。S01/S03/S08覆盖两机、两入口的30秒Wi-Fi窗口；S19为13实际4G两入口，从头90秒快照后保留播放再大幅seek，不能把完整运行时长写成90秒。所有实际t30画面及S19定位后画面已逐张查看；稀疏截图不证明完整帧时间、实际听音或全字幕正确。

| 设备 | 样本 / 网络 | 入口 | 触摸后内部首帧事件（秒） | 采样最大stall |
| --- | --- | --- | --- | --- |
| 13 | S19 / 4G | device file | 6.351, 21.676, 40.245 | 2 |
| 13 | S19 / 4G | Jellyfin | 3.282, 22.456 | 2 |
| 13 | S01 / Wi-Fi | device file | 0.935 | 0 |
| 13 | S01 / Wi-Fi | Jellyfin | 1.380 | 0 |
| 13 | S03 / Wi-Fi | device file | 6.299 | 0 |
| 13 | S03 / Wi-Fi | Jellyfin | 1.519, 19.651 | 1 |
| 13 | S08 / Wi-Fi | device file | 3.919 | 0 |
| 13 | S08 / Wi-Fi | Jellyfin | 4.070 | 0 |
| Pad | S01 / Wi-Fi | device file | 1.378 | 0 |
| Pad | S01 / Wi-Fi | Jellyfin | 2.080 | 0 |
| Pad | S03 / Wi-Fi | device file | 7.430 | 0 |
| Pad | S03 / Wi-Fi | Jellyfin | 3.218 | 0 |
| Pad | S08 / Wi-Fi | device file | 6.156 | 0 |
| Pad | S08 / Wi-Fi | Jellyfin | 5.941 | 0 |

S19蜂窝JF原流路线胜出642ms，首次内部帧触摸后3.282秒、兼容接手22.456秒；文件入口内部帧6.351/21.676/40.245秒，仍有后续切换等待。两入口metrics分别65/64项全部cellular=yes。50%深seek为HLS，完成8.093/8.160秒，恢复事件8.407/8.618秒；实际10/30秒截图已是目标片段。seek动作分别发生在触摸后约195.948/176.224秒，含保留播放与准备工具的停留，未冒充连续90秒或十分钟稳态。完成任务正文不是全部网络流量。

这些结果没有支持“蜂窝首帧/零速已完全解决”；JF S03 Wi-Fi仍有二次首帧与stall，不能只选最快事件报告。后续应按同一次trace关联索引Range首字节、媒体打开、初始定位、HLS首分片和候选切换；做同条件交替重复，不把历史Wi-Fi18日志写成蜂窝。

## 最终数据与退出核对

173源码输入、ios diff、三二进制SHA及deep/strict签名重新通过。13/Pad最终仍空环境正常App首页、无播放器，WDA恢复10/2，原生网络条件均0；首页截图初始NAS状态未连接，稍后最终实时源树NAS正常，二者不混淆。13原Wi-Fi ON已恢复。非诊断且非书签24/17项逐值不变；原书签36/29条均保留，五项音字幕字段零改动，自然播放断点分别改变8/6条。AFC前后App/WDA/Jetsam差值均0，保留导出报告，不据此证明无所有内存或资源问题。

只读Jellyfin结束查询两自有DeviceID均无NowPlaying及TranscodingInfo；这不证明服务器全部FFmpeg进程已退出。已停止自有Pad Runner，保留原13服务；本批自启动TV模拟器已关闭。最终有界保活和进程清理记录见结构化结果。

## 电视配对新结果与待完成

用户在电视遥控App与设备页保持开机后，旧Xcode26.6实见“客厅”未开发设置；通用Add向导停Trust，取消该向导后从实际TV的Pair入口出验证码。用户输入并Connect，原生日志17:55:30明确PairAction success/error nil。此结果替代上文“尚未完成开发配对”的现场判断，不代表已可安装。

配对后电视从发现列表消失，两版xcdevice及CoreDevice均无物理TV目标；已配对的27模拟器仍明确排除。新定点TCP62078可连，匿名产品信息为AppleTV14,1/18.2但没有UDID；无当前客户端可用Lockdown记录。native RSD返回RemotePairingError1005：This device does not support tunnel connections。当前广播仍只有remote pairing、没有映射该电视的apple-mobdev2。未重置任何配对、未更新系统，不能据匿名产品信息或单次配对success宣称开发通道/签名/安装完成。用户已确认本次配对后仍没有Developer菜单。后续Mac Wi-Fi IPv6为Automatic、电视IPv6可解析；这不等于端到端开发连接可用。Device Hub未筛掉真实TV，直接以当前原生发现标识查询仍CoreDeviceError1000。native广播当前authState=unauthenticated仅反映该观察端状态，不抹掉之前PairAction成功，也不能当已完成开发认证。按Apple官方配对后未出现的恢复步骤，已请用户仅重启电视一次并回到遥控App与设备页；等待结果，不重置/解除配对/升级。

TV签名注册/真机安装/实际播放仍待完成；unsigned首版不能安装。DSM诊断暂缓，不升级DSM/电视系统、不改NAS/VPN、不做人为限速或并发大片压测。28项既有需求不关闭。


## 无开发者菜单后的离线关联补充

用户确认菜单仍无后，只读核Mac/电视IPv6与当前设备元数据，未重开手机播放器、未更改App源码或安装身份。电视的隧道探测错误只证明该方法不支持，**不是tvOS版本不兼容或网络故障的根因证明**；用户重启电视尚待执行/回复，不能写成已完成。

复用S19既有日志生成逐分片seek报告：JF首新请求在seek后1.943ms发出，首请求响应头4.833秒、首字节回调约4.840秒；同片分片4.031秒重请求，先于原请求获得完整内容。文件入口首新请求3.711ms，首请求响应头5.352秒，约5.391秒取消；同分片4.038秒重请求并完成。均是原日志观察，无新增影片传输。TCP写侧clean EOF与客户端取消保持分列。恢复事件时间差8397/8606ms与此前事件内字段8407/8618ms的计时来源不同（日志时间戳与引擎单调测量），保留两者，不互相覆盖或相加。

只读Jellyfin取9个文本日志约3.69MB，未开始媒体或修改服务；时间/分片序号附近各一条命令：JF startSegment1694、seek6782.776秒、h264_vaapi/libfdk_aac且字幕overlay；文件1688、6758.752秒、相同codec且无overlay。关联时差约0.547/0.378秒，**没有验证服务器会话标识/时钟偏差**，不据此归NAS、PGS或网络根因，更不作两入口同轨同字幕性能对照。详细安全分片结果收录本批结构化结果；原始日志只私存。

## 电视普通重启后与版本问题答复

用户已确认普通重启并回到遥控App与设备页。重启后原生remotepairing状态从unauthenticated变为authenticated，并解析出符合硬件格式的UDID；标识只私存。产品元数据仍AppleTV14,1、tvOS18.2/22K155、DeviceSupportsLockdown=true。此前仅以发现UUID尝试查询与这次硬件UDID是不同标识，不能互相充当实机身份。

两版xcdevice/CoreDevice仍未呈现可安装物理TV；硬件UDID定点查询1000、既有Lockdown记录仍无、native MobileDevice定点发现未含该TV。RSD两种标识尝试均超时，不能重写成版本不兼容证明。新鲜DNS仍映射原电视地址；两个IPv6地址的49152/62078共四次TCP连接均成功约8～40ms，排除本轮所测端口的IPv6完全不通，不证明开发认证/服务启动成功。只重启本轮单独打开的Xcode26.6，旧进程退出、新26.6 Welcome/Devices实见，原27工程进程保留；新版Nearby窗口无目标已取消，没有再发起PIN或重置配对。

用户询问是否tvOS18.2太旧。现场Mac26.7；核[Apple官方支持表](https://developer.apple.com/xcode/system-requirements)：Xcode26.6的Device Support为tvOS15及以上，Xcode27为tvOS17及以上，18.2都在范围内。不能将SDK27或模拟器27误当真机最低系统要求；本TV工程最低16.0。无证据需升级电视，具体工具/系统缺陷也尚未确诊。电视安装仍未发送，下一步是Mac设备服务/开发接入诊断，**不再等待已经完成的重启或重复问菜单**。本轮未改变App源码、媒体播放或安装身份。

## Mac共享服务与双Xcode保留判断

两次显式DEVELOPER_DIR查询分别证实Xcode27.0/27A266a与26.6/17F113，但devicectl及CoreDeviceService均642.16、同一路径同一服务；换两版UI不是完全独立底层设备栈，尚无两版冲突的根因证明。插件inventory无failedPlugins。MobileDevice1860.2.5.100.2；宿主日志见TXT缺identifier、AMDeviceStartSession Unsupported、Mercury1000/kAMDRemoteConnectError与设备元数据未能填充，但设备名/身份被系统私密化，**不能指定这些错误一定属于TV**，没有重启全局服务或删除偏好/配对记录。

用户询问Mac设置能否看配对：现场确认并已打开系统`Paired Devices.app`（配对的设备），实际窗口仍“正在查找设备”、没有TV行；没有点击解除配对。它的空列表不抹掉原生RPD已认证观察；蓝牙/AirPlay可见也不当开发安装通过。

用户确认有27/26.6并询问是否卸载一个。现场重新读USB身份：13仍iPhone14,5/iOS16.3.1，Pad iPad12,1/18.3.1，仅身份读取、未开App或媒体，不是新包回归。Apple支持表27真机支持从iOS17起，26.6从iOS15起；现阶段建议保留26.6用于13旧系统调试、27用于18新系统/当前构建，勿为删除旧Xcode擅自升级手机。目录块统计分别3,868,040/3,928,920KiB（各约3.7GiB）；Downloads另有26.6安装压缩包2.16GiB，可作为后续优先清理候选。本轮没有卸载Xcode、删除压缩包或修改系统默认开发目录。TV仍无可安装开发目标，签名/安装未发送；下一步围绕宿主元数据/开发服务接管继续定位，不再重复配对/电视重启。

## 18:50失败弹窗与19:07正确Xcode路径重验

用户上传弹窗图为系统“配对的设备”App，不是Device Hub；错误-402653169现场通过已装MobileDevice的AMDErrorString解析为0xE800000F/kAMDUnsupportedError。同次18:50:05日志明确AMDeviceCreateSRPConnection失败、接口不支持当前non-WiFi-pairable device ref；这不是验证码错误证据，也不证明整个tvOS版本不支持。取消失败表单后，实际系统窗口已见“客厅—已连接”；第二张图明确tvOS27 Simulator，不是真实18.2。此前将旧工具打开作为辅助查看但未提示接口限制的误导已向用户说明，未在该工具重试/解除配对。

18:56只终止当前用户两个MDRemoteServiceSupport，让其重建；19:02只SIGTERM当前用户CoreDeviceService后由系统重建。两者没有删除记录、修改网络/系统、重启usbmuxd，原13服务前后均可读。第一次刷新后无TV，第二次重发现TV但xcdevice unavailable/-29“not paired for development”。RPD曾authenticated后现unauthenticated与系统“已连接”并列记录，不能按其一覆盖另一项。禁止交互的既有认证检查（requireNonInteractive=true）返回1004“Non-interactive pairing was requested but is not currently available”，没有放出验证码或无提示新配对。

随后在Xcode26.6 Devices实际“客厅”Pair按钮准备具体验证码窗口，向用户解释为何现有认证无法复用；用户完成输入及Connect。19:07:30 Xcode原生日志PairAction完成error nil，RPD authenticated、hardware identity已解析，KVS只有NULL与ldwatch。两列表仍无可安装目标，不能把再次配对成功当安装成功；不再继续重复PIN。Mac本地网络权限页只读，实际列表没有Xcode行，不能据此判deny，未更改开关。Mac未装Apple Configurator，不为排查自动安装或准备/监督电视。

11项TV源码输入逐项核对未变；用Xcode26.6/17F113、普通Debug、generic tvOS、CODE_SIGNING_ALLOWED=NO另建验证成功（19:07:39），并非签名包、也没有在26.6重复执行此前27的9项测试。仅帮助证实这版工具可以编译该App，安装仍因开发目标/profile未就绪而未发送。旧正常手机包与iOS源码未改，未新开手机媒体窗口。

尝试官方devicectl diagnose只指定客厅、关闭host sysdiagnose与Finder、20秒上限；命令退出1并留下partial zip，未当完整采集成功，未同意/发送任何Apple反馈，原始只私存。[安全结果](../../../testing/results/2026-10/APPLE-TV-DEVELOPMENT-CONNECTION-20261018.json)单列此事实。

当前需要排除两版共用宿主服务状态，已向用户询问方便保存其他工作并手动重启Mac一次，**等待回复/执行**。本轮没有自动重启Mac、电视或其他设备，未卸载任何Xcode、清除凭据/偏好或升级DSM/tvOS。若用户暂不方便，转继续离线/移动端授权工作；若Mac重启，先新鲜核所有身份/签名/安装包与原13服务，不沿用旧运行PID和列表。
