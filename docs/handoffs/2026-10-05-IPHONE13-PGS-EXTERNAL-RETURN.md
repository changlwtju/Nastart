# 2026-10-05 iPhone 13 外置字幕返回 PGS 回归

用户报告手机已解锁，按现场状态恢复真机工作。先读 PROGRESS、CURRENT、播放 runbook 与竞品矩阵；保留其他未提交修改。此记录覆盖10月4日“手机授权阻碍”和“eef/d0尚未真机回归”状态，历史失败和旧包证据继续保留。

## 当前结论

外置ASS分支会先清空嵌入式provider，原候选因此漏掉已显示PGS的捕获：旧eef/d0在真实UI五次返回均触发冗余同位置seek，0次复用，失败未丢弃。补齐清空前捕获后，最新4148/777正常包六次返回均有复用事件、无新增seek，真实双语一致且保持暂停。第五组完整现场日志覆盖后五次，第一轮磁盘诊断一度陈旧，随后持久化记录补齐六次；不能把陈旧日志的缺项当功能失败。

恢复后630秒采集、583条有效时钟遥测覆盖625.169秒，缓冲计数/活动样本均0，10秒之后最小储备7.882秒；138个上游32MiB有限窗口按期望字节完成，无completion错误。真实t3/10/30与11张分钟图已核，原cue自然替换/消失。**初段丢帧6→101仍保留**，最后一次增长在恢复约64.889秒，随后未增长；2～3fps截图和内部计数不够判逐帧流畅，实际声音未验。本轮只证明该片段没有缓冲，不能关闭系列原画卡顿、PX-03或宣布整体性能胜出。

## 本轮安装门槛

- 现场USB与配对重读：iPhone / iPhone14,5（iPhone13）/ iOS16.3.1（20D67），目标UDID与连接证据在本机私有目录。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，保留全部原有脏工作区；构建时iOS tracked diff SHA256 `347854f9ad6e8ecc46fd142b87ddebaae9a08135c2115629814aaa69ff5bafab`，收尾比对未变。
- 普通Debug `-Onone`，无测试环境变量；2026-10-05 09:43:38 +08构建。包本机私有目录名 `Nastart-PGSExternalReuse-Debug.app`，不是昨日eef/d0，也不是历史302/6e2或优化Debug。
- main SHA256 `4148b9a075664c3d7da815aa7a61b8991675ec9789c75fba58877c21ff642943`；dylib `777ca0b5c76de7fbb166491790b825423ccfa50fda202e00aa55b2e79b9827c1`；KSPlayer `3c32cd682df8318238442b420d6e9a7d0c819ae9ac29c8a86596a2f336199176`。
- 深严格codesign验证、目标profile有效至10月11日06:03:15（北京时间）。09:45保留数据覆盖InstallComplete/退出0，安装前后25项非诊断偏好一致；没有卸载、清登录或续签WDA。
- 普通启动、真实启动台/既有Jellyfin库、MI3题名和片头已核。MI3为约54.0GB/7524.768秒的4K HEVC/HDR、TrueHD5.1，LAN私网HTTP8096、KSPlayer/localRangeProxy/directPlay原画。
- 核心测试结构化xcresult：99 passed / 0 failed / 0 skipped，模拟器iPhone17/iOS26.5；正常设备构建、preflight、脚本语法、diff检查通过。

## 修改范围与字幕证据

`SubtitleModel.rememberPausedImageSubtitle`统一捕获当前真正显示、覆盖精确normalized timestamp的位图；renderer在切入外置ASS或关闭路径清空provider之前调用。原嵌入式分支也复用同一入口；plan/seek token、track与精确时刻守卫不放宽，不改缓冲、窗口、解码或服务器策略。新测试覆盖外置provider清空与两级delay，保留已有反例。

最新从头播放约87.049秒显示已知简英PGS双语后暂停，PGS→外置ASS→PGS六次视觉与逻辑对应。后五次共同请求/截图边界的保守响应区间依次0～1351、0～1323、0～1264、0～1323、0～1322ms，每次至少6秒保持；不能将2ms逻辑dispatch、截图轮询或请求结束直接当显示耗时，也不与旧包上下界宣称速度提升或P95。

进一步在实际繁英PGS“二 / Two.”、91.072秒暂停：关闭后消失，返回恢复同cue、无新seek、保持6秒，隐藏控制后完整显示。自然播放推进、真实slider/±15秒跳转以及未曾显示的PGS轨道均走重新seek，没有错误带回87秒旧cue。暂停真seek后87.863/90.965秒的空白样本保留，精确cue区间与字幕重读尚未核齐，**fresh-cue恢复为INSUFFICIENT，不能算负例整项通过**；恢复自然播放后PGS可见。真正点击完成、返回MI3详情、playback_ended及viewDisappear均已取证，退出前恢复原简英PGS7。

## 连续播放测量限制

六轮字幕诊断导致暂停约7.5分钟。恢复开头32秒高密截图；随后每分钟一张图和只读偏好快照。恢复阶段额外原生syslog订阅在约136.49秒停止，未改播放/WDA；丢帧主要在此前约37～65秒增长，但不是严格负载开关对照，不能据此认定工具或播放器根因。偏好遥测经常滞后5～10秒，按条目时间统计覆盖与时钟，不能把截图墙钟与陈旧条目差值当停顿。

KSClock按上次媒体更新时间外推的暂停恢复路径也需受控隔离；本轮只读分析，没有为猜测增加缓冲或改时钟。先做同包无切轨短暂停/长暂停、低采集负载对照，再决定下一项修复。

## XCTest持续运行与下一步

WDA固定Runner未重装，已用独立launchctl宿主 `local.nastart.wda-iphone13` 持有当前会话，无自动循环重启，App覆盖安装和各次测试未结束宿主。脚本ready检测改用系统grep，避免独立宿主缺rg路径。Mac原有七天有界caffeinate仍运行；收尾WDA ready，继续保留宿主供下轮使用。

**不能保证至少24小时免授权**。[Apple开发工具工程师说明](https://developer.apple.com/forums/thread/693273)：设密码的设备通常约每天需手动授权，没有官方支持的自动输入方式。独立宿主降低会话意外结束的机会，不改变iOS授权期限，USB、手机或Mac重启仍可影响连接。未改安全设置、未输入密码、未创建定时轮询或自动重装任务。

继续优先：隔离恢复初段丢帧和真实seek的PGS fresh-cue；补代表格式/iPad门槛与实际音频、完整显示/滚动采样。Lenna1.0.17(610)、DS One2.4.5(4)本轮已重新读取安装元数据；全面CB01～26、DS One Jellyfin/DSM两入口继续接续，正式受控配对仍0。上轮公网8097/5001与Nastart私网8096路径差异不能忽略，AppStore与普通Debug不作公平性能排名。全部PX/UX未整项验收状态保留。

原始仅本机私有 `DebugEvidence/2026-10-05-pgs-reuse-regression-093031`：设备/source/build/test/package/安装门槛、失败eef候选、返回与连续播放截图、原生诊断和各采集失败；完整私有绝对包路径见package JSON。项目仅保存[脱敏机器摘要](../testing/IPHONE13-PGS-EXTERNAL-RETURN-20261005.json)。

## 11:02 竞品默认入口接续

本轮重新核对竞品安装版本，实际Lenna Jellyfin、DS One Jellyfin、DS One DSM直访均进入同S03/MI3的片头，前一播放器退出后才切下一条。DSM文件50.3GiB的四舍五入大小与Nastart54,005,939,750 bytes相符，但跨App source-ID/文件哈希未对齐，仅题名/格式/片头相符不能证明逐字节同源，HEVC2160P/57.42Mbps/2:05:24；“23FPS”等播放器标签只算展示元数据，不作为显示流畅证据。Lenna默认竖屏，另外三条默认横屏；没有改系统方向、竞品账号、服务器或缓存。

下面为每入口**一条默认体验**，计时用请求/截图区间，人工确认“可辨片头云层”，排除海报/控件并包含影片自然黑场。不是首个解码帧的精确耗时；上下界重叠、配置与准备/缓存未对齐，不能排名或报P95。

| 入口 | 可辨云层请求区间（ms） | 默认条件 |
|---|---|---|
| Nastart Jellyfin | 1929～5300 | landscape / privateIP:8096 |
| Lenna Jellyfin | 2304～4912 | portrait / publicIP:8097 |
| DS One Jellyfin | 3798～7377 | landscape / publicIP:8097 |
| DS One DSM direct | 4106～7322 | landscape / publicIP:5001 |

手机进程归属TCP元数据新采集确认：Lenna/DS One Jellyfin大流公网地址8097，DS One DSM公网5001，Nastart私网8096；不保存载荷，不将12秒TCP字节量当链路容量/播放器排名，也不将公网端点等同离开LAN。Lenna菜单含ASS/PGS简繁英、搜索/导入/设置，英语TrueHD5.1当前选中；DS One含字幕边框/颜色/尺寸/偏移/延迟/外挂/嵌入，以及英语PGS、两条中文PGS、中文ASS。

DS One在02:23已有ASS双语时请求PGS，后续HUD02:26，暂停保持/精确cue没有对齐，字幕正确性与响应速度留U，不能把缺字当竞品FAIL或报切换毫秒。此前恢复/退出坐标动作未匹配界面，保留INVALID_ACTION并排除计时；之后以逐阶段真实原生元素恢复ASS，白色双语实证。NAS表格坐标滑动没有位移，后用原生表格swipe取得真实位移；这是导航证据，仍未达到完整滚动性能门槛。Lenna、DS One各播放器已实际退出，DSM返回同文件目录；最新正常Nastart回前台，WDA宿主继续保留。

正式受控配对仍0，CB01～26其余缺口和PX/UX总账保留；参见[本轮默认样本](../testing/IPHONE13-COMPETITOR-DEFAULT-20261005.json)。
