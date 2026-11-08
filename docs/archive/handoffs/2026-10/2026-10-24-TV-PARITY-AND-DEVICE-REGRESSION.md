# TV 功能迁移、iPhone18有线更新与双机接续

2026-10-24 本批按用户最新指示：iPhone18地址问题暂缓、后续修复；使用有线iPhone13和新iPad11继续调试，重点完善TV，功能尽可能与手机/平板一致，只有经过验证的平台限制才例外。没有建立定时任务；其他dirty保留，原始设备/端点/偏好/包仅本机私有证据。

## iPhone18结果与明确未解决项

13:50:16有线保留数据覆盖普通Debug完整29库10:57包成功；174源输入/三二进制/IPA/全部动态库/目标签名核对，25非诊断偏好完全一致。IPA SHA `05e0b1c72c8c5aac00b1ba3b7fd6f22ae8584c1f19e198159cb4ec88e069270e`。保存地址为域名，fixed_address原来缺失；Keychain原策略默认false，旧会话可选LAN。用户两次明确反馈更新后仍IP＋端口，**实际固定域名未完成**，不得以偏好保持声称修好。

旧WDA在原生XCTest启动失败；为目标构建有效16.15.3/Xcode27 fixture并保留数据覆盖，Runner SHA `e1798274eb5ae8f486a13d9868d68bbb97b9f886bcf72b3240eb7e95cc16a3a7`，profile至10-31 05:57:39UTC。真实ready/session/source成立，观察到NAS在线首页；只打开设备页，未改DSM字段/Keychain/固定开关，未发媒体。用户暂缓后请求停止本批WDA，宿主会话以ConnectionTerminatedError结束；设备已不在本批USB列表，未证明设备端Runner最终进程状态，不为核对再次控制18。

无线历史复现仍失败：当前DNS-SD广播、实际UDID、配对认证可核；IPv4及2条当前IPv6在existing escrow/TLS后VendContainer断开。USB同类容器备份成功。另隔离Python3.14/OpenSSL与同版本pymobiledevice3 11.1.0后，明确TCP/Wi-Fi备份依然ConnectionTerminatedError，不能归为旧Python/LibreSSL唯一根因。没有重配对、改VPN/网络或发送第二次无线Install。无线及地址问题随用户暂缓，不再置于当前执行首项。

## Apple TV 新包

真实AppleTV14,1 / tvOS18.2 已paired、developer/DDI服务可用；13:48原Jellyfin首版签名安装成功，用户照片确认桌面默认占位图标和Jellyfin登录页。这确实是功能缺项，不能当完整移动端移植。

本批新增正式NAS图标/TopShelf、DSM/JF选择（默认DSM）、独立DSM Keychain SID、密码/OTP POST登录、API Info接口路径与版本发现、配置origin保持、CPU/内存概览、分页目录与当前已加载文件筛选、文件大小、系统文件播放/按服务器+账号+路径隔离的本机断点/退出释放。账号入口可重新连接，DSM/JF分开退出确认。保留JF媒体库/搜索/详情/MP4-HLS/续播与进度清理。没有接入手机KSPlayer/Range代理/全部音字幕/多NAS/服务及任务管理；逐项边界与顺序见[功能对照](../../../project/APPLE-TV-FUNCTION-PARITY.md)，不得将待移植写成tvOS做不到。

14逻辑/协议测试+1普通启动UI测试通过。首次测试编译为测试表达式优先级错误、下一次为URLProtocol转换body后的冗余断言失败，均保留私有xcresult；修正测试边界后全套通过。图标首轮只有1层有效content的actool错误保留，补真实透明前景位图后最终编译无该错误。Xcode测试框架最低17/工程最低16链接警告和无AppIntents元数据提示保留，不等于已在16真机验收。

41构建输入逐项冻结，普通Debug/Xcode27真机签名构建成功，主程序SHA `d25567c883f59baca2d68b1cf8e533665bbecd926e0706dc8d6058e8e22ece08`、debug dylib `0e087a8668429c75b14b3dfc8b40df4455f8672c2293df33f522a8bc20b12a3a`、preview `447b8c916cd3f66ddb58214eea2bc018e02be05df58af070c6946e8a501985ab`，2库独立/深严格签名通过，tvOS profile含真实电视、至10-31 05:46:14UTC，新旧app identifier/keychain groups保持。

14:15:34保留数据覆盖exit0，Assets.car/CFBundleIcons存在；14:16空env/args正常启动PID及3/10秒原生截图，已查看10秒真实DSM/JF新登录页。桌面图标实际显示、DSM真实登录/概览/目录/播放、JF电视播放尚未验收。已一次请求用户在电视输入NAS账号；不从手机复制凭据，不在用户登录期间重启/覆盖电视。

## 双机回归

现场USB为iPhone14,5/iOS16.3.1、新iPad15,7/A16/iPadOS26.6，逐台实际UDID私核；iPhone18/旧Pad9不在当前USB名单。iOS 174输入与10:57/12:23两目标变体保持，TV修改不改变手机源码。13因没有足够的旧installed路径对照，14:11再次备份保留数据覆盖完整29库包，25偏好一致；14:13普通空env/args NAS在线首页原生截图已看。新Pad已装12:23普通目标包28库/IPA `616c8cd33b6affe387a1b0fe958a6b3f7cf566a0f9010252b87b961783c4243a`，源/签名/自身安装回执及本轮路径/容器一致，未重装Nastart或WDA。

新Pad正式复用WDA。首次helper假定已有session而失败0播放，随后“搜索Jellyfin”嵌套按钮选择不唯一失败0播放；均保留，改按实际层级唯一按钮。14:19:41–14:20:45普通JF/S01一次在Nastart播放、3/10/30秒原生图、普通完成回原影片详情。已查看10/30秒为不同真实片头/字幕画面；新书签1→2，原轨道变化0、其他偏好保持、崩溃增量0。结束App state1/1、守卫/日志/临时保活停止，已请求停止自有Runner；无蜂窝操作。

13新S01/JF首轮搜索项全标签在查询时失配0播放，保留。改按稳定标题及当前唯一父按钮，14:24:20–14:25:28新窗S01/JF一次普通播放，10/30秒原生不同片头/字幕画面已看，普通完成回原详情。36书签保持/1条正常进度更新，原轨道变化0、其他偏好保持、崩溃增量0，App1/1/自有守卫日志保活停止。双机新日志各新增1条first_frame，含KSPlayer/localRangeProxy标识；不是单独凭日志声称出画。新Pad自有Runner停止回读0（14:22），13非本批WDA保持。本批有限截图不等于完整声音/字幕/逐帧流畅、性能竞品或整格PASS。

## 证据与后续

私有入口 `/tmp/nastart-tv-parity-evidence`；本批Pad媒体细节位于新Pad接入证据的ipad11-nas-regression/s01-jf子目录，由本批结果引用。iPhone18USB及历史无线复现各有独立私有入口。可分享结果见[安全JSON](../../../testing/results/2026-10/2026-10-24-tv-parity-and-device-regression.json)。不导出原始名称/UDID/域名/偏好/凭据。

先继续TV真实登录—目录—基础播放与桌面图标；再按功能对照迁移设备/服务/任务/历史及兼容播放。双机保持源包门槛、继续代表格式/PGS同cue/普通自动与竞品；旧失败、旧76+新Pad38格和28项开放状态不因本批关闭。iPhone18按用户暂缓，恢复时才处理原域名的Keychain固定策略/实际session与视频路线，并另查无线服务断连。

末14:32逐台新鲜USB/源包/安装lookup及完整偏好两读稳定复核通过；13 App state1/设置auto10/2，新Pad自有Runner停止0。两台最终原生桌面Wi-Fi图标/无PiP已看，未改VPN或网络。TV41构建输入仍匹配已装包；一次不启动/不导航的只读图为屏保/AirPlay信息，未确认用户NAS已登录，不重复催促。文档检查425份/本地链接无缺失，差异空白检查通过。
