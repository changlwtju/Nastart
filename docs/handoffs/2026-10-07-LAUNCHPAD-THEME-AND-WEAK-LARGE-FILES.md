# 2026-10-07 启动台主题及弱蜂窝大文件接续

2026-10-07 08:07 开始；按用户报告优先处理主题，继续设备文件/Jellyfin弱蜂窝大文件。原PX/UX/CB、字幕音轨、竞品及全格式矩阵均未整体验收。

## 主题问题与改动

用户在iPhone18和iPhone13点击“应用主题”后仍见原样。本轮旧ac5d/bf0b普通包在iPhone13显示三主题实际变化，未稳定复现精确失效，不能将其宣布为已定位根因。确认旧流程应用后只回主题列表；三个主题共用不透明的顶部设备面板，“栈列”的实际指标侧轨、“流光”的顶部材质与预览不一致。

改为启动台与外观设置/列表/详情共用AppearanceStore，去掉主题的重复AppStorage写入；应用后直接选择启动台，在保持各Tab NavigationStack稳定的前提下展示结果。栈列设备面板使用指标侧轨，流光使用regularMaterial，清流保持原布局。未更改播放选流、传输或解码参数。

## 当前普通包与逐台门槛

- 构建源HEAD `2f00aac13efebcc7a9cca48147cea8fe4e9c7732` + iOS工作区差异SHA-256 `f30458fabae515bd0c83a02c86129a6e70c7fd6c5e3fb9030af4abd85260ef32`；原其他127个未跟踪上游参考文件保留，未纳入App变更。
- 普通Debug -Onone，构建时间 `2026-10-07T07:55:49.711897+08:00`；包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-07-074917-launchpad-theme/Nastart-LaunchpadTheme-Debug.app`。
- 主二进制 `412ba50ad4877e65696f910da310e96cdd896d7e2a1009885954489c17a3483a`；debug dylib `a21a52be3bbd24104e6be7f68f5f6899ddef8fed0e7549243e69d53be4858ef7`；KSPlayer `c814c6b3f8d1beaddef93e8c77935aa9d653835244ae7a0b772d9900e709a704`。App及29动态库逐项严格验签/完整deep verify、FFmpeg链接隔离通过。
- iPhone13：现场iPhone14,5/iOS16.3.1(20D67)/UDID00008110-001E543122E0401E，USB/配对及哈希核验。保留数据覆盖安装成功，25非诊断偏好安装前后相同；空环境/参数正常启动及实际前台截图已核。
- iPhone13：新包清流→栈列→流光→栈列，逐项应用自动回启动台及普通重启后设置标题/实际布局一致。最后恢复原栈列；24项偏好不变，1项iCloud本地变更时间戳因主题操作有意更新。初次工具失败均保留：即时冷启动XML未就绪，以及House Arrest plist晚于CFPreferences；以有界页面就绪和普通重启后的实际设置/布局取证，不把即时磁盘快照误判为App回滚。
- iPad：现场iPad12,1/iOS18.3.1(22D72)/UDID00008030-001168403C43C02E。Xcode默认test-without-building尝试安装旧Runner时系统返回No space left on device；未另行重建/重签/卸载。按本机xcodebuild.xctestrun手册UseDestinationArtifacts复用已安装同一有效签名Runner恢复ready。新Nastart保留数据覆盖安装同样被系统PromiseStaging/NSPOSIX28阻止；App tmp/Caches均为空，不删除用户文件。保留旧ac5d/bf0b正常空环境启动与原偏好，明确不能作为主题新包回归。
- iPhone18：本轮USB列表未检出。上轮ac5d/bf0b已更新；本轮412b/a21a尚未安装/回归，待重连。

## 验证与播放接续

设备构建成功；NonPlaybackPolicyTests 35 executed/1 skipped/0 failures（公共端点未配置跳过）；15项preflight通过。真实主题截图只证明实际样式与操作，未获得完整帧时间，不能宣布滚动流畅PASS。

手机真实Wi-Fi OFF、5G上游及SlowNetwork3G 0.78Mbps下行/0.33Mbps上行、两向100ms、0丢包已记录。通过设备→文件→video/media/movie导航至S19加长版MKV，文件入口显示120 GB（不同容量口径，不据此认定与128.8GB Jellyfin版本不同）；开始从头播放、自然180秒取证。待补Jellyfin同片及完整长度/大于4GiB Range与控制/十分钟观察，两入口分开判定。

原始UI、plist、设备/安装/签名日志与网络条件仅本机私有 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-07-074917-launchpad-theme`。脱敏量化：[本轮记录](../testing/LAUNCHPAD-THEME-WEAK-LARGE-20261007.json)。Main同步结果随后追加。

## 08:14 S19设备文件结果及条件恢复

DSM原流206重核当前完整长度128,795,641,934 bytes。首窗为 `bytes 0-33554431/128795641934`；尾索引为 `bytes 128795625367-128795641933/128795641934`，16,567 bytes完整返回。这确认大于4GiB偏移与文件身份，不能代替深位置seek/续播验收。

新普通主题包、Wi-Fi OFF起始、SlowNetwork3G及上游cellular标记下，代理准备2.293秒；引擎内部首次clock事件26.979秒、位置0.052秒。t3/10载入，t30为00:01黑画面，t60/90/120/180黑画面，无可辨电影画面。144遥测覆盖177.631秒，播放位置最大及末值1.844秒、缓冲计数1/丢帧1；首内部帧后149.991秒计数增加1。原流停滞FAIL，不能按一个计数声称稳定。

设备入口日志为 `noStoredJellyfinSession`，走DSM HTTPS5001公网原流/localRangeProxy，没有可持续HLS回退。设备匹配只直接查询service endpoint/alternate；Jellyfin库另查配置入口及/jellyfin、/emby候选，规则存在差异。尚未确认当前保存会话对应的真实候选，原偏好快照无service override；不宣布URL差异就是根因，未盲改凭据、端口或播放规则。

普通退出脚本INSUFFICIENT，随后正常启动即时页面守卫失败，稍后真实启动台可见。Jellyfin对照开始时activeAppInfo/source返回500 nil object，而WDA ready/unlocked、截图可用；实际截图已是其他App且Wi-Fi ON。不能继续归因Nastart异常退出/崩溃。即时拉取776报告，未见10月7日Nastart新报告，但不能证明全部退出原因。Jellyfin未进入播放，十分钟、控制、音字幕仍待测。

其他App前台及无线变化的精确时间未知，不保证最后截图前始终同一蜂窝承载；条件及已有cellular标记分别记录，不作公平性能排名。已停止手机输入、关闭本轮条件并核验所有组inactive；Wi-Fi实际ON与原ON一致。已询问iPhone13是否可继续/iPhone18能否重连。S19设备文件停滞及会话匹配、S19 Jellyfin、MI2/S03设备文件弱蜂窝与全部PX/UX/CB/竞品保留。

## Main源码同步已完成

主题源码及脱敏交接12文件已提交 `ce3ca945cf5bd660020cad72ae5bd7c76580daeb` 并推送origin/main，独立ls-remote与本地HEAD一致。iPhone13已安装包的iOS内容精确对应此提交；保留原构建HEAD2f00aac+iOS差异f30458f身份，不把提交元数据变化伪称重新构建。原127未使用上游参考文件仍在本机，不纳入提交。后续文档确认不改App源码。
