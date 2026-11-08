<!-- Historical snapshot: superseded on 2026-10-17; use current handoff. -->

# 当前播放任务接续入口

<!-- NEW-SIM-AUTHORIZATION-CURRENT -->
## 2026-10-17 用户已更换电话卡并解除流量限制

最新用户指示：iPhone13已换为流量充足的新SIM，明确要求基于连接的iPhone13与iPad开展Wi-Fi及蜂窝播放调试。此指示覆盖下方历史少流量预算及“蜂窝追加关闭”的执行限制；后续不再因旧20MB/96MiB预算、已知蜂窝接口数据或未完成精确计量而阻止已授权蜂窝播放。旧超额FAIL与计量边界仍保留为历史证据，不改成成功。仍现场核SIM/设备/实际网络、最新包身份，记录字节与首帧/seek/换轨证据，并保留有界任务收尾与故障诊断；原Wi-Fi/用户偏好在测试后恢复。iPad是否有蜂窝硬件以现场型号为准，不把Wi-Fi测试或热点链路写成iPad内置蜂窝。

本批双入口结果及新包状态见下方当前记录；私有指针/tmp/nastart-dual-network-evidence。下方旧预算闸门均为新指示前的历史状态。
<!-- NEW-SIM-AUTHORIZATION-END -->


<!-- DUAL-ENTRY-CELLULAR-CURRENT -->
## 2026-10-17 双入口大文件蜂窝已复现；重复准备修复已双机安装，首帧问题仍开放

- 现场核身份、旧e82c包基线5轮与新a379包追加4轮分列。13实际iPhone14,5/16.3.1；S19约128.8GB、S03约50GB。Pad为iPad12,1/18.3.1 Wi-Fi型，仅作Wi-Fi对照；18本批未操作。
- 修复同一可信公网HTTPS主库、会话/凭据有效且准备前后仍普通蜂窝时，路径代际改变导致重复准备。新a379/11:37:28普通Debug Xcode27，173输入/三SHA/29签名库/IPA核验，7定向及15预检/构建通过。13于11:50、Pad于11:38保留数据覆盖25/18项偏好后普通启动；实际蜂窝4→6触发保留准备且无作废。**分支验证通过，总体首帧仍失败；旧全套5失败不撤销。**
- 新包13 Jellyfin蜂窝S03：准备7.408秒，t10/30/60黑屏；三视频分片各约60秒后HTTP504，非有效影片数据。只读FFmpeg有PGS烧录/h264_vaapi与低于实时编码，但尚未按精确会话关联全部上游，未改服务配置。旧包还复现8.5～60秒首字节等待和大seek迟滞。
- 新包13设备文件蜂窝S03：PlaybackInfo156ms，约37.193秒清单预读超时，37.771秒才转DSM原片localRangeProxy；内部clock47.940秒，t60电影+7.2MB/s缓冲。±15内部恢复1.773/0.720秒，正常退出已看。**DSM原片蜂窝已覆盖，长等待未修复。** 旧包两轮设备文件实际走Jellyfin HLS，不能混称原片。
- 新包13同片Wi-Fi原片：准备45ms，t6/t10电影已看，±15内部恢复3.890/2.412秒；Pad设备文件Wi-Fi原片t10电影，±15为2.136/3.823秒。均正常退出；两种网络链路不同，不能当配对提速或完整流畅PASS。Pad早期服务离线失败及13旧包前台切微信中断保留；用户确认无人使用后已恢复自动调试。
- 收尾13原Wi-Fi ON已恢复，蜂窝ON保持；亮度/VPN/Assist未改。双机24/17非书签偏好保持，36/29原书签零删增/轨变，4/2自然位置变；报告零新增、标准实际拉取均exit0、原生条件0/WDA10/2。精确主动停各自Runner后原生首页/NAS正常/Jellyfin在线已看；13精确会话NowPlaying/TranscodingInfo清空，编码进程退出未证。九播放窗Mac Sleep/Wake0，自有保活已释放。
- 下一步减少设备文件35秒清单预读阻塞，并关联Jellyfin504与分片生成/代理；保持低带宽保护及音轨/字幕一致。字幕/切轨/19×4/竞品完整帧时间/音频/HDR/PiP等未验收项继续开放。

详见[当轮交接](../handoffs/2026-10/2026-10-17-DUAL-ENTRY-CELLULAR.md)。
<!-- DUAL-ENTRY-CELLULAR-END -->

<!-- JELLYFIN-WIFI-BUDGET-CURRENT -->
## 2026-10-17 10:54 Jellyfin S19真机Wi-Fi限额与意外接口停止补证；首轮黑屏仍开放

- 仅13现场USB核身份，10:33:41保留数据覆盖e82c普通Debug/Xcode27、25偏好保持、普通首页已看；173 App输入/三SHA/签名/IPA收尾核验。只改Python计量工具，19检查通过，无App修改/构建/测试重跑。18/Pad未操作，18最新确证仍上批08:43:10 e82c。
- 普通Jellyfin S19约128.8GB：首轮t3/t9黑屏、预读取消前0正文；18.091秒守卫主动停，不写自然超时。第二轮内部firstFrame3.671秒/t6实际电影约8.2MB/s，96MiB触发到终止0.135秒，最终IP105,309,722、超阈4,646,426，捕获延迟约1.09秒。两轮不配对，不称提速。
- 第三轮检测pdp_ip1 12包/6,276 IP bytes，约0.093秒主动停；事后蜂窝开关仍OFF，5项已保存影片metrics均cellular=no。包用途/运营商计费未证，不称影片偷跑或任意忽略。**实际为LAN HTTP/1.1，非此前蜂窝h2；未完成任务正文/普通UI退出不足，蜂窝追加阻断仍保持，原213,439,783 bytes超计划FAIL不撤销。**
- 最终13蜂窝ON/Wi-Fi ON恢复，Assist/VPN/亮度未改；空env普通及主动停固定Runner后原生首页/NAS在线已看。24非书签/36原书签轨道保持，0增删/轨变、1自然位置变；报告0新增/标准拉取exit0、条件0/WDA10/2。仅精确13会话Stopped204/NowPlaying清空，自有保活释放/Sleep0。全部字幕/等待/体验/竞品/完整矩阵与旧App全套5失败保留。

详见[当轮交接](../handoffs/2026-10/2026-10-17-JELLYFIN-WIFI-BUDGET.md)。
<!-- JELLYFIN-WIFI-BUDGET-END -->


<!-- WIFI-PACKET-BUDGET-CURRENT -->
## 2026-10-17 10:30 Wi-Fi逐包计量首层校准通过；蜂窝追加闸门仍关闭

- 仅13现场USB核身份，10:04:42保留数据覆盖e82c普通Debug/Xcode27、25偏好保持、普通首页实际已看。173输入/三SHA/签名收尾复核；无App代码修改/重构建。18/Pad未操作，18最新确证仍上批08:43:10 e82c。
- 新增原始pcapd计量原语，修正vlan枚举、已有Ethernet重复补头和非IP VLAN解析，18项Python检查通过，失败样本保留。受控lab启动例外已记录，不混称普通播放性能。
- 仅Wi-Fi、蜂窝数据实关：正文20,162,249/TCP响应20,162,512（差263含HTTP头），全双向IP21,124,573，解析错误0。4MiB限额触发到主动终止约68ms，尾部共4,746,419 IP bytes，超阈值552,115；捕获延迟约1秒。
- **仍未覆盖Jellyfin实际HTTPS/h2/QUIC/高速突发和蜂窝链路，不能保证严格预算；旧蜂窝追加阻断标记保持，上一批213,439,783 bytes超计划FAIL未撤销。** 不作首帧/seek提速结论。
- 13原蜂窝ON/Wi-Fi ON恢复且图已看，Assist/VPN/亮度未改；普通空env首页、精确主动停Runner后原生首页/NAS在线已看。24非书签/36原书签保持，0增删/轨变/位置变，报告0新增，标准实际拉取末次exit0，条件0/WDA10/2。自有服务/保活释放，Sleep/Wake0。原App全套5失败与全部体验/竞品矩阵缺口继续开放。

详见[当轮交接](../handoffs/2026-10/2026-10-17-WIFI-PACKET-BUDGET-CALIBRATION.md)。
<!-- WIFI-PACKET-BUDGET-END -->


<!-- MANUAL-SUBTITLE-PIPELINE-CURRENT -->
## 2026-10-17 09:12 字幕管线修复已三机安装；S19蜂窝短窗流量超计划，已停止追加

- 新e82c4c41675d/08:23:45普通Debug Xcode27，4/173输入修复手动新字幕选择被旧Off覆盖；9定向/15预检/真机构建通过，原全套5失败保留。三SHA/29库/IPA/profile及173输入收尾复核，未改媒体参数。
- 13/Pad现场USB核身份后保留数据覆盖25/18项保持；S19普通KS→AV及底部简英cue、Pad S01 KS/stall0/正常退出实际已看，不算手动HLS成功换轨验收。Pad自有Runner主动停75、原生普通首页/NAS未连接实际已看；13亮度未改。
- **用户已恢复18操作；08:43:10最新e82c Wi-Fi安装Complete/lookup/空env启动实际首页通过，25项含书签保持。** 旧Bonjour后缀失败经当前同目标广播重新解析后成功。现有Runner曾ready；后地址改变，重发现/RSD实拉报告0新增，自有Runner主动停；最终图为用户Codex聊天，非最终App首页。65原书签0删0增0轨变、3对象变化，非书签保持；未回写旧值。用户18蜂窝首帧/seek慢、几MB/s易缓冲仍开放。
- 13按用户要求S19真实5G续播短窗（初始11591.817秒），t3黑屏/t6实际电影，内部clock信号动作后4.591秒。AFC读失败后独立守卫15.150秒主动停App，非普通退出/自然崩溃，未seek。**11项cellular=yes/h2媒体正文213,439,783 bytes，超过原计划约20MB；连接计数漏媒体流，预算控制FAIL。** 已向用户更正、Wi-Fi恢复且不再追加蜂窝；后续先Wi-Fi校准全字节与独立停止。
- 13最终普通空env首页/NAS未连接实际已看、24非书签/36原书签轨道保持，0删0增/1位置变、AFC清单0新增，标准报告拉取exit1如实保留、条件0/WDA10/2。精确自有13会话Stopped204/NowPlaying清空，未停18。自有保活结束，实际播放窗Sleep/Wake0。
- 旧8e71夹具PGS42.928/Off11.953秒非配对；合并2/手动候选1/提交0，自动旧候选失效与手动-1008(20.073秒)分列。前批自有FFmpeg137退出已证，不据此判断容器重启。所有字幕/等待/完整性能/双入口矩阵缺口保留。

详见[当轮交接](../handoffs/2026-10/2026-10-17-MANUAL-SUBTITLE-PIPELINE.md)。
<!-- MANUAL-SUBTITLE-PIPELINE-END -->

<!-- HLS-CONTROLLED-COALESCING-CURRENT -->
## 2026-10-17 07:37 HLS合并分支补证、保活对照与双机回归；用户暂缓18

- **最新用户指示：iPhone18暂缓，先13/iPad。** 本轮早先Bonjour未解析、未发Install；8e71未装18，最后03:41 cc64。用户指示后未再发现/安装/授权。
- 最新仍8e71c89113fb/06:29普通Debug Xcode27，173输入/三SHA/29库/IPA/profile重核，无App改动/构建/测试重跑；历史8定向/15预检及全套5失败不改。双USB现场身份、诊断/报告基线、保留容器覆盖25/18偏好和实际普通首页后回归。
- 13既有2Mbps一次进程HLS夹具：首轮60秒黑屏后-12889，已失败播放器中两次重复请求实合并、1候选、恢复前0失效/0提交；仅分支观察，正常成功换轨INSUFFICIENT。原选择及书签轨道保持，首次经原生错误完成正常退出。
- 首轮Popen保活提前消失、13实际Sleep，时间/日志超时受混杂；改持续exec断言后两播放窗口0Sleep/Wake。第二次13约13.188秒ready/实际电影，32.932秒再缓冲、t60仍等待；未切轨。退出选择器守卫拒绝后普通进程重置恢复空env，非第二次普通退出。自有13会话Stopped204/NowPlaying清空，**编码进程退出尚未确认，优先追踪**。
- Pad复用有效Runner/Xcode27无新建/显式重装，S01普通60秒实际电影/正常退出已看，KS/current50.565/stall1，早期迟到保留。自有Runner主动停exit75，原生最终首页及18偏好保持；停前NAS正常，重启3秒图为未连接。
- 双机24/17非书签/36/29原书签轨道保持，各1自然位置变，0删0增/0轨变，Nastart/WDA/Jetsam0新增，conditions0、WDA10/2。13最终NAS正常，低亮度未改，自有保活进程均已结束。只读日志低速/迟到与会话归属未闭环，全部原验收缺口保留。

详见[当轮交接](../handoffs/2026-10/2026-10-17-HLS-CONTROLLED-COALESCING.md)及[结构化记录](../../testing/results/2026-10/HLS-CONTROLLED-COALESCING-20261017.json)；私有指针/tmp/nastart-hls-repeat-evidence。
<!-- HLS-CONTROLLED-COALESCING-END -->

<!-- TRACK-REQUEST-COALESCING-CURRENT -->
## 2026-10-17 06:45 重复换轨请求合并已构建并双机安装；HLS去重真机路径仍待覆盖

- 新普通Debug/Xcode27 **8e71c89113fb**，06:29:01包，3/173输入修改tracker/Greenfield队列/测试，其余170保持；重复同轨不再排队使当前候选失效，改选/Off/seek/PiP/结束后重试保持。8定向含3新测试、15预检和真机构建通过；三SHA/29库/IPA/profile收尾核验，未改码率/超时/重试/解码，原全套5失败未撤销。
- 旧/tmp缓存缺包清单/Git元数据，首测依赖解析exit74保留；按原锁定版本改持久DerivedData/SourcePackages后成功，未升级依赖。新路径见运行手册。
- 双USB现场身份/偏好/诊断/报告基线后保留数据覆盖，25/18安装偏好保持，空env/args实际首页已看。13 S19续播t10缓冲/t30/60实际电影帧及底部简英cue已看，60秒KS/stall3，约90秒仍KS/stall4；HLS守卫拒绝、未发重复选择，去重真机项INSUFFICIENT，不称流畅/提速通过。搜索导航失败经实际图校正原生点击保留。
- Pad复用有效固定Runner/Xcode27，无新建/显式安装WDA；S01约60秒自然电影及普通退出图已看，KS/current48.912/stall0。首次不存在“从头播放”按钮守卫拒绝无动作、早期迟到采样保留。末尾主动停本批Runner exit75 intentional，原生最终首页/18项偏好与审计整份保持。
- 双机24/17非书签及36/29原书签轨道保持，0删0增/各1自然位置变化；本轮Nastart/WDA/Jetsam0新增、conditions0、WDA10/2。最终13 NAS正常/Pad卡未连接，实际首页及播放器关闭已看；13亮度未改，临时Mac断言已释放。
- **18本轮Bonjour目标未解析，新8e71未装18**；未沿旧地址或重配，最后确证仍03:41 cc64，XCTest本机授权状态未重核。全部原字幕/等待/切轨/蜂窝/音频/资源/竞品/矩阵缺口保留。

详见[当轮交接](../handoffs/2026-10/2026-10-17-TRACK-REQUEST-COALESCING.md)；新私有指针/tmp/nastart-playback-next-evidence，旧证据未覆盖。
<!-- TRACK-REQUEST-COALESCING-END -->


<!-- NATIVE-PGS-IPHONE18-AUTH-CURRENT -->
## 2026-10-17 04:02 13原生PGS底边及大快进旧cue已取证；18等待本机XCTest授权

- 最新仍cc64de38bfaa/10-16 19:50普通Debug/Xcode27，173输入/三SHA/29库/IPA/profile收尾重核；无App修改/重构建/测试重跑。13/18现场核身份、先存诊断后保留数据覆盖，各25偏好安装保持；Pad本轮未操作，13亮度未改。
- 18 Wi-Fi实时iPhone19,7/27.0，03:41:36 Complete/lookup/启动后25偏好保持；普通启动实际SpringBoard，非本轮首页通过。标准网络报告拉取exit1后RSD实取，Nastart报告0/进程1。固定Runner已安装/profile有效，复用userspace RSD XCTest，无新建/安装WDA；实际出现“为XCTest输入iPhone密码/Enable UI Automation”，已请用户本机授权，未回复，未播放。批末主动停自建XCTest，额外RSD收尾40秒超时，最终UI/进程/偏好/条件未复核，不混称通过。
- 13 S19 KS原生PGS默认index8，01:23带cue实际暂停稳定，控件显隐/横竖图已看；横屏底距33pt、竖屏46pt。大快进实际7332.848秒，首图0.852～1.351秒旧cue已无，t3旧片缓冲、t10/30目标图；引擎完成4.584秒/预览API5.726秒，仍未提速或完整SUB验收。
- 自然播放后自动AV/HLS，后续切字幕原选择已恢复，但旧视频/烧录字幕及缓冲窗口不算原生切换通过。11234ms warmup_failed为恢复选择导致candidateInvalidated，非独立超时；HLS下原生cue助手AssertionError及导航误触旧图均保留为工具边界。
- 13最终普通空env/args实际首页已看/播放器关闭，NAS卡未连接、JF健康绿；24非书签/36原书签轨道保持，0删0增/1自然位置变；本轮Nastart/WDA/Jetsam0新增、conditions0、WDA10/2。临时Mac断言已释放。18用户原故障及全部历史测试/矩阵缺口仍开放。

详见[当轮交接](../handoffs/2026-10/2026-10-17-NATIVE-PGS-AND-IPHONE18-AUTH.md)；私有指针/tmp/nastart-18-regression-evidence。
<!-- NATIVE-PGS-IPHONE18-AUTH-END -->


<!-- IPHONE18-RETURN-WIFI-CURRENT -->
## 2026-10-16 20:31 iPhone18回家后最新包无线安装完成；播放问题继续待验

- 用户确认18已接家庭Wi-Fi，离家暂停解除。现场DNS-SD/已配对TCP核身份：iPhone19,7/iOS27.0，Wi-Fi、USB无目标；20:27:32已收到Install Complete，lookup存在。
- 最新仍cc64de38bfaa、19:50:56普通Debug/Xcode27；173输入/三SHA/29库/IPA/profile及收尾核验通过，无App修改/重构建/测试重跑。安装前后及启动后25项非诊断偏好含完整书签完全一致。
- 空env/args原生RSD启动，实际首页已看：NAS正常/播放器关闭，Jellyfin徽标未知，不当作播放验收。无WDA/重配/网络修改。18不再沿用07:10旧包状态。
- 只读旧S19同窗3日志601989字节，93号从372.372秒启动，服务器主日志与FFmpeg输出身份匹配、输入与前1870相同；客户端会话所有权/历史时钟未证，9.013秒seek/6437ms首字节仍未根治。下轮单路同步服务器会话取证并补18字幕底边/旧cue与换轨。
- 13/iPad本轮未操作，13低亮度保持，Pad仍上批主动停Runner；临时Mac断言已释放。原全套失败及所有播放/竞品/矩阵缺口保留。

详见[当轮交接](../handoffs/2026-10/2026-10-16-IPHONE18-RETURN-WIFI.md)；私有指针/tmp/nastart-segment-origin-evidence。下方离家暂缓均为历史状态。
<!-- IPHONE18-RETURN-WIFI-END -->


<!-- PLAYLIST-BODY-MAC-SLEEP-CURRENT -->
## 2026-10-16 20:09 清单字节诊断已修正；维护睡眠干扰已隔离，Pad恢复并完成短片回归

- 18继续暂缓，13亮度未改。最新cc64de38bfaa普通Debug/Xcode27、19:50:56包；3/173输入改字节/首末回调诊断及测试夹具，KS二进制保持。三SHA/29库/签名/IPA/15预检通过；未改媒体、超时/重试策略。
- 慢清单首轮8过/1超时：墙钟35.289/上游单调21.891秒，同窗Mac维护睡眠15秒，实收655360字节而非原错误0。临时AC防睡眠后同源码9/9过，源32.018秒完成，原30/35截止保留；封装with_awake_mac.sh及3CLI检查。断言窗睡眠0；音频独立探针保活后仍134，历史全套失败未撤销，不称全绿。
- 双USB现场身份/诊断/崩溃基线后保留数据覆盖25/18偏好保持。Pad重用续签Runner/Xcode27，无新建/显式安装；ready/UI操作跨550秒，S01从头60秒自然电影帧及普通退出实际已看。结束主动停本批Runner(exit75 intentional)，原生最终普通首页/NAS正常已看，临时保活已释放；下轮先有界保活重用Runner，非再次断连。
- 13 S19普通续播实际AV/HLS，PGSSUB index8 Encode/无独立原生字幕节点；暂停7504.31→381.19秒大回退AV完成9.013秒，t3旧片/旧烧录字幕，t10/30目标图及不同字幕已看。43请求新指标：目标93首请求首字节6437ms，另一同片请求2159ms+body1169ms；h2复用/背压0，服务端归属待对齐，不称字幕或提速验收。输入异常/意外后台窗口均保留，实拉报告无新增App崩溃。
- 双机最终普通首页/播放器关闭/NAS正常实际已看，原轨/非书签偏好保持、原书签0删0增各1位置变化、现场基线Nastart/WDA/Jetsam0新增、conditions0。全部原矩阵/字幕/换轨/CPU/内存/蜂窝/竞品缺口保留。

详见[本批交接](../handoffs/2026-10/2026-10-16-PLAYLIST-BODY-AND-MAC-SLEEP.md)与[结构化结果](../../testing/results/2026-10/PLAYLIST-BODY-AND-MAC-SLEEP-20261016.json)；最新私有指针/tmp/nastart-prewarm-receive-evidence。
<!-- PLAYLIST-BODY-MAC-SLEEP-END -->


<!-- PLAYBACK-VALIDATION-RECOVERY-CURRENT -->
## 2026-10-16 19:40 音频失败已脱离App复现；Pad自动化仍断开，Phone补普通直放深跳证据

- 18继续暂缓，13亮度未改。173输入/三SHA/签名重核，仍d0ae9dcdb0b9、17:23普通Debug/Xcode27；本轮无App修改/重构建，原全套失败不撤销。
- 原模拟器定向2音频崩溃+VOD35.279秒超时，驱动滞留停止/不完整xcresult保留；另一已有iOS27模拟器原5项0过/5失败。独立AVAudioEngine.outputNode探针无Nastart代码，Mac退出0、模拟器同RemoteIO RPC栈退出134，测试模拟器重启后仍134。音频可独立复现，预热原因另查；未删/跳失败或扩大截止。
- 双USB现场身份/诊断、保留数据覆盖最新包25/18偏好保持后才核普通空env首页。Pad复用已续签Runner，Xcode27短暂ready/首页后Mercury1001/65；原生XCTest两窗也短暂ready后DTX断开，首次缺身份变量守卫拒绝/第二次补齐仍断。各次实际报告0新增，未新建/显式重装Runner，Pad无播放回归。
- Phone普通Jellyfin S19为KSPlayer，实际深跳7488.605秒，引擎开始至完成1.374秒、目标输出API2.632秒；旧片头t3截图与输出时刻重叠，迟到t10实际19.448秒才采/目标画面，t30亦目标。37请求36新阶段记录、迟到窗/工具pause拼写失败保留；不认定HLS或实际呈现提速，跳前无合格cue故字幕未验收。
- 收尾双机普通首页/播放器关闭实际已看，13 NAS正常/Pad未连接，原轨保持；Phone仅1位置变化，Pad18项整份保持，conditions0。Phone报告较上批最终清单0新增（非本轮开始基线），Pad本轮实际报告0新增。原全部验收缺口开放。

详见[本批交接](../handoffs/2026-10/2026-10-16-PLAYBACK-VALIDATION-RECOVERY.md)与[结构化结果](../../testing/results/2026-10/PLAYBACK-VALIDATION-RECOVERY-20261016.json)；私有指针/tmp/nastart-validation-recovery-evidence。
<!-- PLAYBACK-VALIDATION-RECOVERY-END -->


<!-- HLS-REQUEST-PHASES-CURRENT -->
## 2026-10-16 17:42 请求阶段诊断候选已双机安装；全套测试与Pad自动化仍有阻碍

- 18继续暂缓，未发现/安装/播放；13低亮度未改。d0ae9dcdb0b9普通Debug/Xcode27 17:23:50，仅3/173输入改只读请求阶段/headers时序，170保持；三SHA/29库/IPA/签名和15预检通过，播放/网络策略未变。
- 新3反例通过；全套首次415项409过/2跳/4 Audio RemoteIO RPC崩溃，复跑408过/2跳/5失败（原4项+本地HLS预热超时）。真实失败/xcresult/栈均留，设备构建成功；不能称全绿/正式验收。
- 双USB现场身份/诊断后保留数据覆盖25/18安装偏好保持。13空env首页已看；Pad WDA拒绝先拉报告，原生空env启动首页已看。旧canonical配置指过期Runner未启动，改核10-11续签固定fixture后XCTest短暂ready再连接失效/exit65；未新建/显式安装Runner，Pad播放回归受阻。
- Phone受控Apple静态HLS实际深跳357.340秒，AV完成约1.539秒；目标206请求首字节327ms、headers回调329ms、响应体1567ms，h2复用/背压0。35条新阶段证据、迟到采样/先前+15秒seek/自动换源均分列；与旧43秒非配对，不称提速。恢复普通空env后Jellyfin《哈尔》30秒与退出图已看，但为蓝色压制片头，非完整自然电影帧验收。
- 收尾双机最新普通首页/播放器关闭实际已看、原轨/偏好保持、Nastart/WDA/Jetsam0新增、conditions0；13原书签仅1自然位置变化，Pad整份保持。双机NAS仍未连接，服务健康在线分列。全部原字幕/HLS/切轨/CPU/内存/SUB/AUD/显示timing/MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。

详见[本批交接](../handoffs/2026-10/2026-10-16-HLS-REQUEST-PHASES.md)与[结构化结果](../../testing/results/2026-10/HLS-REQUEST-PHASES-20261016.json)；私有指针/tmp/nastart-hls-phases-evidence。
<!-- HLS-REQUEST-PHASES-END -->

<!-- HLS-RECOVERY-INVENTORY-CURRENT -->
## 2026-10-16 13:51 服务清单缓存修复完成；HLS实片/静态源快进等待均有新证据

- 用户携18离家，全部18动作继续暂缓，待回家通知；本轮未发现/安装/播放18。13低亮度保持，本轮未改亮度。
- 修正容器/套件读取失败时只保留内存清单、却把原始不完整快照落盘导致冷启动丢Jellyfin入口的问题。保留失败flags、成功空清单权威删除、manual独立保存；3反例。65bbef286794普通Debug/Xcode27 13:06:25，412测试/2跳过/0失败、15预检；仅2/173输入变化，三SHA/29库/IPA/签名核验。
- 双USB现场身份/诊断后保留容器覆盖最新包25/18项偏好保持、空env实际首页已看。Pad一次普通刷新恢复14容器/47服务及Jellyfin入口，无缓存回灌；强制失败冷启动真机注入未做。
- 旧0df Phone直放S19深跳7390.233秒：首张约0.893秒旧cue已无，10秒目标画面已看，但有自动HLS候选失败/时钟间断，非最新65bb/完整SUB或流畅验收。最新65bb受控Apple静态HLS两次真实AV seek完成43.571/24.611秒，目标未loaded，首Range头约25.557秒；无需Jellyfin也有等待，排队/上游归因未定，结束恢复普通空env。
- 最新65bb Pad S19正常播放后自动AV/HLS，暂停深跳7381.984秒真实native seek；30秒仍旧电影帧/烧录字幕、0KB/s，1841片六请求无响应头，普通退出后routeRevoked。单loading已看，原生ASS cue助手无法匹配烧录保留失败。服务器5日志605225字节未见目标命令，13:33新启动标记、13:51健康200分列，重启/137根因未证。
- 收尾双机空env/args实际首页/NAS正常/播放器关闭、原轨/偏好保持，各1自然书签位置变化、Nastart/WDA/Jetsam0新增、conditions0。全部原字幕/HLS/切轨/CPU/内存/SUB/AUD/显示timing/MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。

详见[本批交接](../handoffs/2026-10/2026-10-16-HLS-RECOVERY-AND-INVENTORY-CACHE.md)与[结构化结果](../../testing/results/2026-10/HLS-RECOVERY-INVENTORY-CACHE-20261016.json)；私有指针/tmp/nastart-hls-recovery-evidence，旧证据未覆盖。
<!-- HLS-RECOVERY-INVENTORY-END -->

<!-- HLS-SEEK-TEARDOWN-CURRENT -->
## 2026-10-16 11:51 退出崩溃已定向修复；双机最新包五次退出正常，18待晚上回家

- 用户携18离家，全部18发现/安装/测试暂缓，待回家通知再现场核身份与最新包。本轮未对18执行动作，最后安装仍07:10 c868。
- 新普通Debug/Xcode27源码0df79c3a7ff5、11:42:47包，409测试/2跳过/0失败及15预检；相对a22仅4/173输入变化，三SHA/29库/IPA/签名核验。双机保留容器覆盖25/18项偏好含书签后才回归。
- S01 Pad退出时84a出现真实SIGABRT，KS UUID匹配，SwiftUI销毁视图→同步Published字幕重置→GraphHost独占访问冲突。修正为延后detach清理、持有stream owner、generation保护重挂并跳过重复空发布；3反例及原PiP/重置测试通过。最终Pad3次、13两次S01/JF从头30秒及退出实际图已看，修复后双机无新增报告；整轮Pad旧候选1崩溃仍留证，不称全局稳定/全矩阵通过。
- 新增只读AV seek区间/完成/等待观测，修正准备/缓冲双loading叠层。旧a22 HLS深seek60秒黑屏仍未修；dce新窗在首帧前进入server-seek、无原生AV事件，目标7420.593秒ready但loadedRange0/无frame，预热失败，初始CoreMedia -12889。分片时间关联非会话归属，不能归因容器或只改重试/超时。
- 收尾双机正常空env首页/播放器关闭、原轨/非书签偏好保持、原书签0删0增各1自然位置变化、conditions0。Pad NAS正常，13仍未连接，Jellyfin播放分列；未改亮度。非空字幕/PiP/文件入口、S19持续缓冲/字幕、CPU/内存及全部MI2/PX/UX/CB/Main/竞品/19×4原缺口保留。

详见[本批交接](../handoffs/2026-10/2026-10-16-HLS-SEEK-AND-TEARDOWN.md)与[结构化结果](../../testing/results/2026-10/HLS-SEEK-TEARDOWN-20261016.json)；私有最终指针/tmp/nastart-teardown-fix-evidence，旧失败窗口仍保留。
<!-- HLS-SEEK-TEARDOWN-END -->

<!-- SUBTITLE-PREPARATION-CURRENT -->
## 2026-10-16 09:07 播放准备提示/取消已验证；双机更新，HLS大跳转60秒不恢复仍待修

- 用户已继续，Container Manager旧暂停解除。a22c8f331de3普通Debug/Xcode27 08:50:45包；404测试/2跳过/0失败及15预检、173输入/三SHA/29库/IPA/签名核验。新增准备状态、取消及分类错误，不改媒体/重试/超时；底部字幕两尺寸像素渲染附件实际已看。
- 13/Pad现场USB身份重核、保留数据覆盖25/18项偏好含书签后才回归。同片《超凡蜘蛛侠2》Wi-Fi双机30秒实际图及退出；Pad后续自动转AV/HLS，不能称全程直放。13受控8秒准备hold核准备/取消、10秒无迟到打开；已恢复空env。双机最终实际首页/NAS正常/播放器关闭、原轨保持、无新增崩溃/压力清单、conditions0；13低亮度约25%保持。
- a22 Pad S19大跳转实际7451.480秒，AVPlayer/HLS t0/10/60仍黑屏缓冲0KB/s，恢复失败保留。跳前无合格旧字幕cue，字幕清除/底边与用户18反馈均未验收，下一步定位清单/目标分片、seek和候选/代理所有权。
- 服务HTTP200、只读6日志约1.55MB，08:10启动；用户07:57请求无会话归属/同窗错误，容器重启根因未证。18目标Bonjour仍未解析、未发Install，最后已核07:10 c868；新包未装18。所有CPU/高内存/SUB/AUD/FPS/MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。

详见[本批交接](../handoffs/2026-10/2026-10-16-SUBTITLE-REGRESSION-AND-PREPARATION-ERRORS.md)与私有指针/tmp/nastart-preparation-evidence。
<!-- SUBTITLE-PREPARATION-END -->

<!-- SCREEN-EDGE-SEEK-PAUSED-CURRENT -->
## 2026-10-16 08:01 字幕底边/seek旧字幕修正已构建；用户因Container Manager重启要求暂停

- 用户已确认iPhone18/Jellyfin字幕偏中与大快进旧字幕残留，新增5G《超凡蜘蛛侠2》准备失败。三项均未验收，暂停真机和服务器操作，等待用户继续；连接失败原因待服务恢复复核。
- 源码79d06f27265c新普通Debug/Xcode27：屏幕底边安全区+12pt、控件留44pt字幕带；seek清空/暂停原生字幕模型、当前generation完成后恢复，暂停PGS缓存失效、刷新解码器。400测试/2跳过/0失败、15预检、173输入/29库/三SHA/IPA核对。
- 13已保留数据覆盖79d，25项安装偏好含完整书签保持；正常空env启动图已采集但尚未审阅/播放回归。Pad未装79d，最后5df；18未装79d/5df，最后07:10 c868。不得沿用同版本号/旧图称最新包验收。
- 大跳转基线工具标签错误导致未送出seek；本地验证守卫中断后直连USB读取正常首页，原失败保留。服务器日志读取失败后用户报告容器重启，不作App/FFmpeg根因判断。25%低亮度意愿继续保留。
- 恢复后先最新包逐机核验，再做底部锚点与大跳转PGS/文本实际画面对照；蜂窝准备失败需同窗App/服务器日志。原CPU/高内存/切轨及全部MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。

详见[暂停交接](../handoffs/2026-10/2026-10-16-SCREEN-EDGE-SEEK-PAUSED.md)与[检查点](../../testing/results/2026-10/SCREEN-EDGE-SEEK-PAUSED-20261016.json)；私有指针/tmp/nastart-subtitle-fix-evidence。
<!-- SCREEN-EDGE-SEEK-PAUSED-END -->

<!-- BRIGHTNESS-BITMAP-CURRENT -->
## 2026-10-16 亮度已保持25%；字幕位图优化完成，用户新报底部位置/seek残留优先处理

- 13实际亮度设约25%，c868及5df两次S19播放退出后保持。初始控制中心读0%，未找到启动强制拉满，历史高亮原因未定；后续保留用户低亮度，不重置。
- CPU可信调用栈定位PGS PNG转换及多矩形过大行缓冲，删除PNG往返、使用系统对齐RGBA。仅3输入变化；新普通Debug/Xcode27于07:38:13构建，source5df8e033fabd；397测试/2跳过/0失败及15预检，173输入/三SHA/29库/IPA核验。
- 13/Pad保留数据覆盖5df后才回放；原25/18安装偏好保持。13新采样不再出现PNG路径，单窗不称整体提速；Pad峰physical footprint952.081MiB、同PID首页后中位121.737MiB，仍有自动降档和stall1，高内存/CPU问题未关闭。
- 双机选定图已看及正常空env首页/原轨/偏好/崩溃/active0已核。18本轮无线双端口超时未核身份、未发Install，当前5df未安装；最后已核仍07:10 c868。
- 用户随后明确反馈字幕仍偏中及大幅快进旧字幕残留，位置验收未通过；正在独立重放并优先修复。全部旧MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。

详见[本批交接](../handoffs/2026-10/2026-10-16-BRIGHTNESS-BITMAP-CPU.md)及[结构化记录](../../testing/results/2026-10/BRIGHTNESS-BITMAP-CPU-20261016.json)；最新私有指针为/tmp/nastart-bitmap-evidence，不修改旧证据。
<!-- BRIGHTNESS-BITMAP-END -->

<!-- IPHONE18-INSTALL-CPU-REFERENCE-CURRENT -->
## 2026-10-16 07:10 iPhone18最新包Wi-Fi覆盖完成；CPU普通包参考补齐

- 用户要求优先安装iPhone18，现场DNS-SD/既有配对TCP重新核到iPhone19,7/27.0，07:10:53.805191收到Install Complete、lookup存在。保留容器覆盖；安装后、启动后和最终读取25项非诊断偏好含完整书签逐值保持，无卸载/清登录/配对/网络/WDA改变。
- App源码仍c868、173输入/三SHA/IPA CRC/29库/deep/profile核对，最新有效包为10-15 18:56:47普通Debug/Xcode27；无App改动/重构建/测试重跑，396项/2跳过/0失败及15预检仍属原同源构建批。
- 首次6秒图为其他App，单独补一次启动核验、未重复安装；1秒实际图确为Nastart启动台/播放器关闭，空env/args为请求证据。早期NAS标未连接，后续截图前台又已变化；不声称NAS稳定连接/播放通过，原始失败观察全留私有证据。
- 原CPU任务继续只读：资源报告两条App帧UUID匹配后仅符号化为main入口，不当具体热点。旧普通包三轮S19启动CPU中位64.800～72.370单核%、采样最大134.486～153.024；同PID回首页后中位0.122～0.150。与带Allocations的63%资源报告未配对，不归因开销比例，不判稳定或提速。
- 本轮13/Pad无新安装/播放；CPU资源风险、内存对象归属、换轨等待及全部MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。下步取得可核对分配和CPU采样调用栈，确认热点后修改。

详见[本轮交接](../handoffs/2026-10/2026-10-16-IPHONE18-WIFI-INSTALL-AND-CPU-REFERENCE.md)、[安装记录](../../testing/results/2026-10/IPHONE18-WIFI-INSTALL-20261016.json)及[CPU参考](../../testing/results/2026-10/CPU-REFERENCE-20261016.json)。本批独立指针未改旧current/stage/background/memory/alignment证据。
<!-- IPHONE18-INSTALL-CPU-REFERENCE-END -->

<!-- HANDOFF-ALIGNMENT-CURRENT -->
## 2026-10-16 换轨等待已细分；补Allocations记录，CPU资源警告保留

- c868普通Debug/Xcode27、173输入/三SHA/签名仍一致，未改App/重构建；396项/2跳过/0失败及15预检仅引用10-15 18:56同源批。新增离线对齐分析及16反例/CLI测试，既有报告工具合计60项通过。
- 旧20ab的S19六次字幕首次decoded均存在时钟超0.1秒及缓冲不足0.5秒；最慢落后5.645秒，decoded至aligned7.521秒。最终c868 S03兼容音轨两窗decoded至aligned2.704/2.485秒，aligned至committed0.000770/0.002073秒。旧新/素材/入口分列；离散快照不当完整因果、屏幕/声音或提速验收。
- 13/Pad现场USB身份重核，13仅身份读取；Pad06:37保留数据覆盖最新包、18项安装偏好保持后才诊断。Allocations有效120.498秒完整覆盖播放动作至t60，但未覆盖退出/回首页释放；同PID回首页由WDA另核，选定图已看。CLI仍无allocation类别schema，内存对象归属未定。首次元数据遗漏和第二次WDA超时均在播放前失败，全部保留。
- 新鲜直连USB及临时转发完成恢复/采集，临时转发已关闭，原转发06:51也ready；不能单凭异时探测断言唯一故障组件。无Runner重装、网络/配对/系统改变。Pad最终普通空env首页实际已看，idle10/cool2/active0；17非书签偏好及28原书签轨道保持，0删/0增、1自然位置更新。
- 收尾新增1份Nastart报告，确认为对应诊断进程的bug_type202 CPU资源警告、Action taken:none；本轮新增exception crash0/WDA0/Jetsam0，但CPU风险不关闭，不将Allocations开销结果当普通播放基线。18最新安装仍为10-15 21:49 Wi-Fi成功批，本轮无新操作。

详见[本轮交接](../handoffs/2026-10/2026-10-16-HANDOFF-ALIGNMENT-AND-ALLOCATIONS.md)及[结构化记录](../../testing/results/2026-10/HANDOFF-ALIGNMENT-ALLOCATIONS-20261016.json)。下一步读取可信分配类别/调用栈并补普通包CPU对照；换轨继续分开首分片、连续缓冲和追赶，PX-20及全部MI2/PX/UX/CB/Main/竞品/全矩阵缺口保留。
<!-- HANDOFF-ALIGNMENT-END -->

<!-- MEMORY-LIFECYCLE-CURRENT -->
## 2026-10-15 iPhone18安装身份复核；iPad启动高内存已补重复观测

- iPhone18已按21:49无线成功批次完成最新c868安装；本轮新鲜DNS-SD/配对连接probe-only核到目标、签名包和可读容器，无重复安装/新播放。13仅现场USB身份/偏好/崩溃只读保存，不称新回归。
- App源码未改、未重构建；c868普通Debug/Xcode27、173输入/三SHA/签名再核。Pad约21:59保留数据覆盖后才测试，18项安装偏好保持；396项/2跳过/0失败及15预检明确引用18:56同源批，未重跑。
- Pad Jellyfin三次有效S19从头60秒，physical footprint采样峰值927.252～949.565MiB，同PID退出回首页后10～30秒中位120.619～122.479MiB；S01单轮峰值155.064MiB。不是冷缓存/同片排名/无泄漏或旧压力已修复；旧846MiB为resident估算，两种指标分列。初次导航工具失败窗口保留且不计三轮。
- 独立120秒Activity Monitor+VM Tracker完成，App仍Xcode27普通包，记录工具Xcode26.6；实际见VM曲线，但CLI无VM分类schema、对象归属未定。两次Xcode27附加失败及首次包装器确认文本错误保留，不计App故障。
- 旧20ab六次字幕切换离线关联五次命令/一次未匹配；最慢首分片约12.916秒响应头、13.672秒候选解码、21.194秒提交，未证会话所有权/服务端分段，不能当最终c868提速结果。没有猜测性调参。
- 22:27:52 Pad普通空env首页实际已看，NAS正常/播放器关闭/active0；17项非书签偏好及28个原书签轨道保持，0删除/0新增、2自然位置变化，Nastart/WDA/Jetsam均0新增。内存归属、字幕等待及全部PX/UX/CB/Main/MI2/竞品/全矩阵原缺口继续开放。

详见[本轮交接](../handoffs/2026-10/2026-10-15-MEMORY-LIFECYCLE-AND-SUBTITLE-LATENCY.md)及[结构化记录](../../testing/results/2026-10/MEMORY-LIFECYCLE-20261015.json)。下一步定位高峰内存类别/分配对象与候选生命周期，再做同条件对照；独立私有证据窗口未改其他任务current指针。
<!-- MEMORY-LIFECYCLE-END -->

<!-- IPHONE18-WIFI-UPDATE-CURRENT -->
## 2026-10-15 iPhone18最新包Wi‑Fi更新完成，链路已文档化

- 当前c868/普通Debug18:56包于21:49:20经实时DNS-SD、已有配对TCP、HouseArrest既有escrow、AFC/installation_proxy Install完成覆盖；Complete/lookup已核，空env/args RSD/DVT启动后实际Nastart首页/NAS正常已看。安装及启动后25项非诊断偏好含完整书签均逐值保持。
- 173输入/HEAD/dirty diff、三SHA/IPA CRC/29库/deep/profile前后重核；本安装任务未改App/重构建/重跑App测试，同源396项/2跳过/0失败及15预检明确引用18:56批。无线工具11项通过；早期断连、错误provider服务名和测试loop夹具失败均保留。
- 新增持久化无线安装工具与操作手册，README/播放runbook/CLI均有入口；安装/正常启动原生截图不依赖WDA，不以Xcode自动发现为前提。Mac网络/VPN/配对/系统/WDA未改，不卸载/清登录；此次成功不表示自动Xcode/WDA或18播放性能验收。
- 13/Pad换轨回归及MI2/PX/UX/CB/Main/全矩阵等全部未完成项继续；10GB仍非蜂窝测试预算。下次18操作先重核实时连接与当前包，不沿用这次成功。

详见[无线更新执行记录](../handoffs/2026-10/2026-10-15-IPHONE18-WIFI-UPDATE.md)及[可重复操作手册](../../development/IPHONE18-WIFI-UPDATE.md)。
<!-- IPHONE18-WIFI-UPDATE-END -->

<!-- LIVE-TRACK-HANDOFF-CURRENT -->
## 2026-10-15 换轨准备保持播放已实现；最终包双机定向观测，18 无线安装受阻

- 最终 c868 / 普通 Debug 18:56:47，实际 Xcode27 构建；396 项/2 跳过/0 失败、15 预检、173 输入/三 SHA/29 库/IPA 核验。13/Pad 18:58 保留数据覆盖、普通空环境首页已核；4/173 输入变化、169 保持，媒体常量未改。
- 最终 S01 四窗、S03 ASS 双入口与 S11 TrueHD/S18 FLAC 代表音轨、双机 S19 原生 PGS 一往返实际选定图已看。Pad S03 AV 两次 9.083/9.746 秒准备期间旧时钟继续推进；暂停 Off 实际可见加载/速度、7.706 秒暂停提交。20ab S19 三往返 8.217～21.194 秒及取消/暂停/seek/Off 证据单列，不能冒充最终包或版本提速。
- 21:43 双机源码/包/普通首页、原轨/非书签偏好保持、原书签 0 删除/0 新增、各 5 自然位置变化；Nastart/WDA 0 新增崩溃、active0。Pad 新增 1 系统压力记录，S19 原画启动时 Nastart 单快照约 846 MiB、未见终止；分配趋势/同条件旧包未验，稳定性继续开放。
- 18 同 LAN Wi-Fi 实时身份可读、用户已解锁且手机显示现有 Mac 配对。明确用 Xcode27 Device Hub/原生安装重试仍不可用（CoreDevice4016，无受信 RSD）；21:48 原生再核 paired/enabled、tunnel unavailable；没有 InstallComplete/最新启动，最后已核仍 07:29 f5。未取消配对、未清数据；安装未完成。
- 慢样本、无效动作、两种菜单守卫/工具与审计前置失败均保留；完整 SUB/AUD/连续帧/严格配对/PX-20、内存压力及所有原缺口继续开放。详见[当轮交接](../handoffs/2026-10/2026-10-15-LIVE-TRACK-HANDOFF.md)及[结构化记录](../../testing/results/2026-10/LIVE-TRACK-HANDOFF-20261015.json)。
<!-- LIVE-TRACK-HANDOFF-END -->

<!-- SERVER-SUBTITLE-CORRELATION-CURRENT -->
## 2026-10-15 字幕等待已补同窗服务器日志；新增可重复关联工具

- 本轮只读分析上一轮6次操作，没有App修改/新构建/安装/真机播放回归。db873普通Debug11:39的173输入/三SHA/deep签名保持；394 XCTest/2跳过/0失败和15预检未重跑。现场USB13/Pad身份重新读取，上一轮17:08安装/首页/轨道/偏好/崩溃/conditions证据不冒充本轮回归。
- 现有Jellyfin10.11.11会话日志API可读，取得8份同窗日志3.87MB。6次均各找到唯一同首分片序号服务器命令，h264_vaapi+AAC+overlay烧入；每次第一分片都2次请求、间隔约4.05秒，不能据此称2次转码重启或断言它造成约10秒等待。
- 时间+序号仅支持关联，未证明会话所有权；当前服务器时钟约快0.12～0.14秒，不回填历史。仍缺探测/解码/烧入/编码/首分片生成分段，延迟未修复。
- 新增脱敏离线关联脚本与14项反例测试，另18 phase+12 trace共44项通过；初始小数/命令转义解析失败保留。18历史地址/新鲜服务3候选仍未核到在线目标，未发Install、最后07:29 f5旧包。全部未完成项保留。

详见[本轮交接](../handoffs/2026-10/2026-10-15-SERVER-SUBTITLE-CORRELATION.md)及结构化记录；当前私有窗口server-latency，下一轮实机操作先重新核包。
<!-- SERVER-SUBTITLE-CORRELATION-END -->

<!-- USB-AUDIO-OUTPUT-CURRENT -->
## 2026-10-15 播放中切字幕：兼容流等待已分段，文本对照完成

- 源码db873/普通Debug11:39未改，173输入/三SHA/29库/deep/IPA再核；13/Pad16:42～16:43保留数据覆盖及正常空env首页实际已看。394测试/2跳过/0失败和15预检为11:39同源结果，本轮未重跑。
- 13 S19先因deliveryBelowSourceBitrate自动转AV/HLS；随后6次PGS往返实际为服务器字幕替换，点击至提交9.008～10.594秒，首分片约1.1～1.5秒请求/6.2～6.7秒收到响应头。旧图转圈及后续图保留，缺同期服务端日志，不将等待全归NAS/网络，不判首显/实际听音/完整SUB。
- Pad S03原画ASS一轮往返保持KSPlayer、无换流/seek事件；out2.175秒cues加载记录及选定实际文字已看，原PGS恢复。非同设备同片同点对照，不称版本提速或所有影片通过。
- USB muxed端口虽列vide/soun，两次实际采集均0buffer且WDA守卫失败，已停止；中间一次旧session404未启动采集。无麦克风输入/无实际PCM结论/无Runner重装，工具与App结论分列。
- 双机最终普通空env首页/原轨/偏好/崩溃/conditions已核；18旧地址及新鲜服务3候选仍不可核在线，未发Install，最后07:29 f5旧包。PX-20/实际听音/服务端等待/严格配对及所有原PX/UX/CB/Main/MI2/PGS/完整矩阵保留开放。

详见[本轮交接](../handoffs/2026-10/2026-10-15-PLAYING-SUBTITLE-ROUTES.md)及结构化记录；本批采集结束，私有current为audio-output-capture窗口，下一轮先重核设备与包。
<!-- USB-AUDIO-OUTPUT-END -->

<!-- FIXED-POINT-AUDIO-CURRENT -->
## 2026-10-15 固定暂停点基线已补；实际听音/18安装仍待完成

- 源码仍db873普通Debug11:39:36，173输入/三SHA/29库/签名/IPA再核；本轮未改App/构建/重跑测试，394项/2跳过/0失败与15预检明确复用上一批同源结果。
- 现场USB13/Pad16:20～16:21保留数据覆盖，25/18安装偏好保持，空env/args正常首页实际图已看。每机3轮定位+音轨out/back共12次切轨，每次1条共享seek且保持暂停；13六次音轨目标均69.680秒、Pad均69.495秒。两机实际目标不同，不能冒充跨设备同点。
- 分开记录demux完成与目标预览输出边界，均不当实际出声或屏幕首帧；没有旧新版本配对/冷缓存/完整SUB或播放中切轨验收。Pad首远点t3黑屏转圈→t10电影帧、启动包装器播放前失败均留证；未添加参数。
- 最终16:35:17双机正常首页/退出/空env，13/Pad非书签24/17项保持，原书签35/28全部五轨道字段0变化/0删除，各1自然位置变化/0新增；Nastart/WDA/Jetsam0新增、active0。两窗WiFi metrics160/蜂窝0，不换算流量。
- Mac所列手机输入为麦克风，未录环境或改音频路由；实际听音仍待可信通道。18旧地址/新鲜服务3候选均未核到目标，未发Install，最后确认07:29 f5旧包。全部原未完成项及上一批36次证据保持。

详见[本轮交接](../handoffs/2026-10/2026-10-15-FIXED-POINT-AUDIO-BASELINE.md)及结构化记录；私有current指针已换track-fixed-point窗口，上一批另存。采集已结束，下一轮重核设备与包。
<!-- FIXED-POINT-AUDIO-END -->

<!-- NATIVE-AUDIO-SHARED-SEEK-CURRENT -->
## 2026-10-15 原生音轨共用seek；双USB观测收尾，18待连接

- 当前普通Debug11:39:36，源码差异`db8730452eaa…`；本批4/173输入变化、169保持，394测试/2跳过/0失败、15预检和设备构建通过，29库/deep/profile/三SHA/IPA核对完成。只复用已有seek恢复生命周期，没有新增传输、解码或按片名参数。
- 13/Pad11:40～11:41保留数据覆盖新包。最新源36次音轨选择均1条共享seek；S01四基础窗、S03 ASS双入口及S11 TrueHD/S18 FLAC交叉入口代表窗、S19播放/暂停组合均采集并看选定图。Pad约01:18可见PGS同cue的显隐旋转/暂停音轨往返已看，t3/t10仍显示并保持暂停；不等于全SUB/AUD或流畅验收。
- 13 S19三次/方向引擎缓冲恢复out中位0.916/back0.775秒；旧2012源4.225/3.991秒，但播放点/缓存未配对，不判版本提速或实际出声。新包t3转圈、Pad暂停seek等待、无cue窗口、早暂停触摸未生效、菜单/退出404和分析工具失败均保留；S03 JF深位置恢复与30秒启动分列。
- 最终13:58:49双机现场USB/源码/包/空env首页与退出已核；13/Pad非书签24/17项保持，原书签35/28的五轨道字段0变化、0删除，各8自然位置变化/0新增；Nastart/WDA/Jetsam0新增、active0。18新源捕获窗（含失败输入窗）WiFi metrics542/蜂窝0，不推算月流量。
- 18现场仍未取得实时已配对目标，未发新包Install；最后07:29 f5不含两批功能。PX-20/实际听音/严格配对/PGS独立时表继续开放；MI2及全部原未完成PX/UX/CB/Main/竞品/网络/MTP/19×4等保留。

详见[本轮交接](../handoffs/2026-10/2026-10-15-NATIVE-AUDIO-SHARED-SEEK.md)及其结构化记录；本批采集已结束，下一轮须重核设备与包。
<!-- NATIVE-AUDIO-SHARED-SEEK-END -->

<!-- PLAYER-STATUS-SUBTITLE-CURRENT -->
## 2026-10-15 实时状态/缓冲速度与稳定字幕；13/Pad最新包，18连接受阻

- 新普通Debug10:23:26，源码差异 `2012608ee0f6…`，相对f5仅8/173输入变化、165保持；390测试/2跳过/0失败、15预检，三SHA/IPA CRC/签名/29库/profile均核。
- 顶部时间/实收下载速度/网络类型/电量与充电、转圈下同一实时速度已实现；单一采样器、无额外测速请求。固定字幕锚点，文本字幕在途请求按含token URL合并，同一已提交音轨避免重复准备；未调传输/解码参数。
- 13/Pad10:23～10:24保留数据覆盖最新包；S01四基础窗、S19 JF ±15速度、双机原生PGS/文本ASS同cue显隐旋转实际图已看。最终10:48正常空env首页/播放器关闭/原轨0变化/非书签24与17项保持/原书签0删除/崩溃0新增/active0。离散图不证明连续帧、听音或全SUB。
- 18本轮实时已配对连接不可用，历史地址和新鲜服务均无可核目标，未发Install；最后07:29 f5包不含本批功能，不称最新安装完成。
- S19较早32e6源三暂停+三播放轮仍有音轨t3等待、内部时钟恢复1.797～3.340秒；不冒充最终2012源性能或实际听音。PX-20仍进行中。MI2临时探针证明4741.904秒原始输出前buffer已坏，独立Mac同PTS正常；探针已精确撤回、13/Pad恢复普通包，根因未定。
- 来电/会话失效/AFC失败/未真实暂停/cue过期/取样范围遗漏全部留证。PX-09可调偏移、MI2、原PGS/Pad等待/预热/HLS/NAS/全音画字幕/PiP/竞品完整帧/19×4等旧项全部保留开放。

详见[本轮交接](../handoffs/2026-10/2026-10-15-PLAYER-STATUS-SUBTITLE-AND-SEEK-EVIDENCE.md)及[结构化记录](../../testing/results/2026-10/PLAYER-STATUS-SUBTITLE-20261015.json)。
<!-- PLAYER-STATUS-SUBTITLE-END -->

<!-- IPHONE18-INSTALL-MI2-BASELINE-CURRENT -->
## 2026-10-15 iPhone 18 已装最新包；MI2 花屏旧包同目标复现

- 当前源码仍f5d06b2c9a89/普通Debug10-14 20:56，173输入/源码差异/包新旧、三SHA/IPA SHA及CRC/29库/deep/profile重核；无App源码改动/新构建/重跑测试。385测试/2跳过/0失败及15预检明确属10-14同源结果。
- 18开工USB无/CoreDevice unavailable，经已有配对无线实时核名/UDID/iPhone19,7/27.0后，10-15 07:29:50成功保留数据覆盖最新f5、lookup存在；普通空env/args启动请求，实际Nastart正常首页/NAS正常已看，安装后及启动后25项非诊断偏好含书签完全保持。收尾再次TCP连接6秒超时，新鲜服务3候选未核到目标；不称末尾再次核偏好或18播放验收，后续须重核连接。
- 13最新包重复小时→分钟→小时，三实际目标与上轮一致；第三4741.904337秒t3/t20同种严重花屏，恢复普通播放t3选定图正常。日志demux0/flush5→6/前关键包PTS4741.32/key=true/12包send0/96帧error0仍与实际坏图并存；generation0和key标志不证明逐seek所有权或NAL随机访问类型。
- 明确历史ce53普通包、独立目录/门槛/核签覆盖后，在同一第三实际4741.904337目标t3/t15/t20也花屏，故此类故障早于跨小时标签修正。旧包第一目标4666.460269与最新4719.714853不同、第二3588.048522相同；第三补偿名义4803.254585才配齐，不能称完整同条件序列/版本失败率。无旧包有效解码trace，根因和最初引入仍待查。
- 13已07:40:19再覆盖最新f5、25项安装偏好保持，实际首页/播放器关闭/空env/args、idle10/cool2/active0；24非书签偏好与34个原书签五轨道字段保持、1自然位置变化/0删除，Nastart/WDA/Jetsam0新增。新/旧两捕获窗WiFi metrics24/21、蜂窝均0，不推算月流量。
- iPad本轮仅现场清单/偏好保存，无新安装/播放回归。整体播放仍未通过，无猜测性App修复；下一步独立源帧、CRA/IDR/RASL及解码参考/输出所有权。原PGS、精确目标、Pad暂停等待、预热alignment、10.544秒换流/HLS23.943秒与NAS日志、S03双入口seek/冷续播、S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3及其余PX/UX/CB/Main全部保留开放。

详见[本轮交接](../handoffs/2026-10/2026-10-15-IPHONE18-INSTALL-MI2-BASELINE.md)。
<!-- IPHONE18-INSTALL-MI2-BASELINE-END -->

<!-- STABLE-TIMELINE-CLOCK-CURRENT -->
## 2026-10-14 跨小时进度条布局修正；MI2花屏仍开放

- 基线ce53的时间Text从34→45pt使iPad滑块x72/w925→x83/w914。改用总时长格式占位，保持可见时间及动态字号；只2个iOS输入变化、其他171保持，seek/字幕/媒体/网络参数未改。旧等价Text2测试5断言失败/0unexpected已保留。
- 最终dirtyf5d06b2c9a89、普通Debug20:56:00；本轮385测试/2跳过/0失败、15预检/构建/173输入/三SHA/29库/deep/profile/linkage/IPA均核。双USB现场核包后20:57保留数据覆盖25/18项偏好保持，空env/args实际首页已核；18未装f5。
- 两机MI2原生KS小时→分钟→小时各3次，滑块21个原生边界观测/机保持同一位置。**13第三次暂停目标t3/t15/t20花屏**保留FAIL_VIDEO，原因/引入未定，不判整体播放无回归。坐标目标误差13约-30.285～+8.049秒、Pad约-17.969～+15.006秒仍在，不做精确字幕对时/速度/全SUB验收。
- S01四基础单元/S03 JF双机启动与普通退出选定图已看；S01文件补±15。S03实际PGS，ASS专项未完成。13诊断读取86.406秒、Pad首次回退t0后AFC挂起180秒均单列TOOL，独立UI及有界补采另存，原失败不丢；只改私有采集socket上限，App网络参数未改。
- 最终13/Pad24/17非书签偏好、全部原轨保持，各4项自然位置变化、0删除；实际正常首页/播放器关闭/空env/args/idle10动画2/active0，Nastart/WDA/Jetsam集合0新增。最新8窗WiFi metrics90/蜂窝0；10GB月额度不是预算。
- 下一步先同序列关键帧/codec flush/代际复现花屏，再继续独立PGS时表。原PGS残留/独立cue时表、精确触摸对时、Pad暂停大seek等帧、历史自动预热alignment失败、10.544秒切流/HLS23.943秒与同期NAS日志、S03双入口seek/冷续播、S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX05/06/其余UX/CB/Main仍开放。18未装f5，不用旧包验当前源码。

详见[本轮交接](../handoffs/2026-10/2026-10-14-STABLE-TIMELINE-CLOCK.md)。
<!-- STABLE-TIMELINE-CLOCK-END -->

<!-- PGS-SEEK-LIFECYCLE-CURRENT -->
## 2026-10-14 PGS暂停seek：原生与烧入分路取证

- 同ce538bed01f2/普通Debug18:19:28，173输入未改；本轮双USB现场身份/包/签名核对、19:16保留数据覆盖，空env/args实际首页已看。383测试/2跳过/0失败及15预检为之前同源结果，本轮未构建/重跑。
- MI2共15次暂停±15：13 JF原生KS7次、Pad JF AV4次、Pad文件早暂停保留KS4次。目标/自然播放/显隐旋转/退出选定图已看；原同句残留未稳定复现，Pad原生缺可核预期PGS cue，恢复自然播放后AV字幕不能冒充原生恢复。不判全SUB/性能/连续帧通过，未做假设性源码改动。
- 暂停导致seek_recovered101.009/45.646秒含等待再次播放，保留事件但不计seek延迟；单报引擎完成和输出预览。Pad原生大seek黑屏转圈→后续目标图仍开放；第二定位实际1:20:44，ratio不证明精确重放旧目标。
- 首次position部分原图被同名第二采集覆盖；先前已看contact和剩余PNG保留，明确不称完整原始帧。私有工具已加动作/写入前防复用拒绝，受控验证原窗口全部文件哈希不变。菜单/标签/隐藏控件/依赖步骤工具失败保留。
- 13最终24/Pad17非书签偏好、全部原轨保持；自然书签1/2项变化，0删除，实际首页/播放器关闭/空env/args/idle10动画2/active0，真实Nastart/WDA/Jetsam集合0新增。四窗WiFi metrics226/蜂窝0，10GB月额度不是测试预算。
- 下一步独立PGS cue/显示集代际反例、滑块实际目标及Pad暂停等帧；同期NAS首分片日志仍缺。历史自动预热alignment失败、10.544秒切流/HLS23.943秒、S03双入口seek/冷续播、S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX05/06/其余UX/CB/Main仍开放；18未装ce53，不以旧包验证当前源码。

详见[本轮交接](../handoffs/2026-10/2026-10-14-PGS-SEEK-LIFECYCLE.md)。
<!-- PGS-SEEK-LIFECYCLE-END -->

<!-- COMPATIBLE-WARMUP-PHASES-CURRENT -->
## 2026-10-14 自动兼容预热与AV慢seek：双USB重复取证

- 仍为ce538bed01f2/普通Debug18:19:28，173输入未改；现场身份/包/签名核对、双USB保留数据覆盖、实际空env/args首页已核。383测试/2跳过/0失败及15预检为上一轮，本轮不重复。
- MI2/原PGS/从头/每台3个75秒不操作窗口，全部选定图及普通退出已看。Pad3次自动候选提交，对齐内部21.473～23.245秒、中位23.157；13三次均原生KS未请求候选，不能以0失败关闭历史alignment失败。无速度/全程流畅/全SUB/AUD验收。
- 每机另大幅定位及暂停±15各3次。Pad AV大seek13.089秒；分片16ms发出、约10.6秒才响应头，两个读者/取消及6.19MB完整交付均保留，13.1秒引擎完成。前进中位3.271秒/后退2.059秒是内部边界。URLSession requestMs=请求到响应开始，responseMs=响应体交付，不能颠倒；TCP读FIN不作整连接取消。
- 13原生PGS两暂停目标保留同一句，尚缺原cue时表，疑似残留待查，不判SUB通过。Safari DSM日志检索/前台文件选择未取得可验证下载，服务端同步未完成，单列TOOL；不改NAS/网络/播放参数。
- iphone13最终24项非书签偏好/全部原轨保持、1项自然书签变化，实际首页/播放器关闭/空env/args/idle10动画2/active0，Nastart/WDA/Jetsam真实集合0新增。
- ipad最终17项非书签偏好/全部原轨保持、1项自然书签变化，实际首页/播放器关闭/空env/args/idle10动画2/active0，Nastart/WDA/Jetsam真实集合0新增。
- 六窗WiFi metrics非蜂窝266/蜂窝0。下一步同期服务端首分片准备/排队及PGS已知cue复验；历史预热失败、10.544秒切流/HLS23.943秒、S03双入口seek/冷续播、S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX05/06/其余UX/CB/Main仍开放。18未装ce53。

详见[本轮交接](../handoffs/2026-10/2026-10-14-COMPATIBLE-WARMUP-PHASES.md)。
<!-- COMPATIBLE-WARMUP-PHASES-END -->

<!-- PENDING-SEEK-PRESENTATION-CURRENT -->
## 2026-10-14 暂停seek等待反馈及共享字幕时序：双USB定向验证

- 接续f03，复核旧iPad慢窗：seek本身约6.44秒，不能仅归因于显示迟到。现发布pending seek边界；暂停KSME视频等目标预览被输出API接受，期间显示等待并隐藏共享文字；失败回实际时间，恢复/替换/断开清理。不改网络/媒体参数。5输入修改、其他168保持。
- 最终dirtyce538bed01f2，普通Debug18:19:28；本轮383测试/2跳过/0失败、15预检、构建/173输入/三SHA/29库/deep/profile/linkage/IPA核对。旧代码受控负例2测试5失败/0unexpected，原失败及中间版保留。
- USB13 18:20:22/Pad18:20:04保留数据覆盖、25/18安装偏好保持；空env/args逐窗核对。MI2 ASS暂停±15截图捕获旧图转圈/共享文字隐藏，目标图及单层字幕恢复并保持暂停；原PGS轨道恢复。另6个S01双入口/S03 JF基础窗，S01文件各补±15，实际图/普通退出已核；全部WiFi、metrics蜂窝0。
- iphone13最终24项非书签偏好/全部原轨保持、4项自然书签变化，实际正常首页/播放器关闭/空env/args/idle10动画2/原生active0，真实Nastart/WDA/Jetsam新增{'Nastart': 0, 'WebDriverAgent': 0, 'JetsamEvent': 0}。
- ipad最终17项非书签偏好/全部原轨保持、4项自然书签变化，实际正常首页/播放器关闭/空env/args/idle10动画2/原生active0，真实Nastart/WDA/Jetsam新增{'Nastart': 0, 'WebDriverAgent': 0, 'JetsamEvent': 0}。
- 13 S01文件后退首图旧图且未见转圈，取图区间跨输出信号、t1已更新，未精确核屏幕呈现先后；继续逐帧取证。
- 未证明seek/网络速度或连续帧性能改善；本轮MI2两机路径/缓存不同，Pad原生KS、13兼容AV。Pad候选随手动seek的candidateInvalidated已记录，历史自动预热alignment失败、旧AV慢seek/10.544秒换流、S03双入口seek/冷续播/HLS23.943秒及S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main仍开放。18未装ce53，不能以旧包验当前源码。

详见[本轮交接](../handoffs/2026-10/2026-10-14-PENDING-SEEK-PRESENTATION.md)。
<!-- PENDING-SEEK-PRESENTATION-END -->

<!-- SUBTITLE-BURNIN-TRANSITION-CURRENT -->
## 2026-10-14 烧入字幕切换双层修复：双USB定向验证

- 接续本机未交接的702普通包，本轮现场复现iPad PGS烧入流叠加ASS。改为仅clean sidecar/明确Off且无准备中替换时快速切文字；其余交既有source回调，先去旧烧入层再显示文字，原画KS仍可本地切轨。只1个iOS输入及预检检查修改，其他172输入保持。
- 最终dirtyf03a7f2f3fdd，普通Debug17:32:33，本轮实际380测试/2跳过/0失败、15预检/构建、173输入/三SHA/29库/deep/profile/linkage/IPA核对。原预检、AFC、空cue、控制查找及误用等待工具失败均保留。
- USB13 17:33:20/Pad17:32:56保留数据覆盖，25/18安装偏好保持，空env/args实际首页/逐窗门槛。Pad MI2烧入PGS→ASS请求服务端-1，内部10.544秒提交且保留暂停/位置，实际单层字幕/显隐/旋转已看；Off/ASS恢复及暂停seek另取证。13原画KS单层ASS、本地切换和重复选轨无换流、暂停+15及普通退出已看；原自动兼容候选预热失败保留。
- 另6个S01双入口/S03 JF基础启动与普通退出新窗口，全部WiFi/metrics蜂窝0。最终24/17非书签偏好及全部原书签轨道字段保持，两机实际正常首页/播放器关闭/空env/args、WDA idle10动画2/原生active0，真实Nastart/WDA/Jetsam0新增。10GB月额度不是测试预算。
- 换流约10.5秒、Pad暂停seek t3旧画面/t10更新、13自动预热失败与恢复PGS暂停cue、S03双入口seek/冷续播/HLS23.943秒及既有S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main继续开放。18不在本轮范围，未装f03；不沿用旧包为当前源码验收。

详见[本轮交接](../handoffs/2026-10/2026-10-14-SUBTITLE-BURNIN-TRANSITION.md)。
<!-- SUBTITLE-BURNIN-TRANSITION-END -->


<!-- SUBTITLE-TIMELINE-CLEARANCE-CURRENT -->
## 2026-10-14 字幕避让修复：双USB验证，18新包待无线连接

- 用户记得MI2截图为Jellyfin，设备/触发未知、原句未复现。13旧5b同暂停PGS画面控制栏显隐确证上移；改按44pt进度条触摸区上缘+8pt避让、绑定viewport丢弃旋转旧尺寸，保留淡出/触摸目标。只3输入修改，其他170保持；媒体/网络/轨道/书签算法未改。
- 最终dirty1f380efabe36，普通Debug08:54:35，实际380测试/2跳过/0失败、15预检/构建、173输入/三SHA/29库/deep/profile/linkage/IPA核对；698初版滑块靠近和中间测试夹具失败均保留，不能当最终验收。
- USB13 08:58:47/Pad08:58:37最终包保留数据覆盖，25/18安装偏好保持，正常空env/args实际首页/逐窗身份包门槛。MI2 JF实际双语PGS13 1:19:37/Pad1:20:05，固定暂停显隐/实际横竖及恢复横屏位置已看，字幕在进度条上方/避开滑块；6个S01双入口/S03 JF片头及普通退出已看。非全SUB/AUD/HDR/性能/连续帧验收，早期空字幕图不计通过，Pad原label工具失败保留。
- 全部WiFi、8窗metrics全no；13实际WiFiON，10GB月额度不是测试预算。最终24/17非书签偏好/原S03及全部原轨保持，自然书签变化4/4；正常首页/播放器关闭/idle10动画2/active0、实际Nastart/WDA/Jetsam0新增。
- 18当前既有地址/新服务无法核实时身份/容器，Install未发、最终1f字幕包未安装；最后确证旧5b今天07:23:06。仅无线、Mac网络/VPN/配对/WDA未改；不要沿用旧“18最新安装成功”认定当前源已装。
- 下一步WiFi补MI2文件/ASS/外部与暂停seek cue、S03双入口转圈/冷续播；原ASS/PGS时序、HLS23.943秒、S19、119/PadTS02/13Network、增长TS/全旋转/SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main仍开放。

详见[本轮交接](../handoffs/2026-10/2026-10-14-SUBTITLE-TIMELINE-CLEARANCE.md)。
<!-- SUBTITLE-TIMELINE-CLEARANCE-END -->

<!-- WIFI-PRIORITY-REPEAT-CURRENT -->
## 2026-10-14 10GB月流量约束：WiFi优先，18无线更新成功

- 用户暂停蜂窝后已恢复WiFi并取消旧未执行窗口；后明确流量包已开通、月总量仅10GB、谨慎避免超额。恢复调试授权收到，本批后续全部WiFi，不把10GB当测试预算。必要蜂窝先有限请求预算/实际计量，避免大文件持续播放；运营商剩余额度未核。
- 本批生产源码未改，dirty5b8afe21d0ce普通Debug06:06:17，173输入/三SHA/29库签名/deep/profile/IPA及最终源核对。377测试/2跳过/0失败、15预检/构建是上一批，本批未重跑。
- USB13 07:09:39/Pad07:10:02现场保留数据覆盖，25/18安装偏好保持，正常空env/args首页/逐窗门槛。18现场NETWORK iPhone19,7/27.0，07:23:06无线InstallComplete+lookup，25/25安装/启动后偏好保持；启动实际截图为当前对话，本批Nastart首页未验，自动Xcode/WDA/无线播放仍开放。无需数据线。
- 暂停前13 S03蜂窝R1/R2启动内部5.691/5.163秒，R1±15恢复2435/1195ms、R2前进1683ms；R2回退前工具nil对象500/前台其他App，回退未发，真实crash0新增，原失败保留。R1有电影/字幕/正常退出，R2未正常退出；50/29 metrics全yes，仅完成媒体payload下界1443.8/782.5MiB，不是运营商总计。
- 后续13/Pad S03 JF WiFi内部首帧1.614/2.933秒，71/77 metrics全no；13未seek、普通退出。Pad±15内部4266/3149ms但实际约3.85/4.12秒仍转圈、t20继续画面，普通退出；内部恢复不等于显示/转圈消失，仍需查，不判性能/全SUB/AUD/HDR/FPS PASS。验证码按用户请求读出，原短信及验证码不入仓库。
- 最终USB原24/17非书签偏好保持，各1自然书签变化/原S03两入口轨保持，实际正常首页/WiFi/播放器关闭/空env/args/idle10动画2/active0，实际Nastart/WDA/Jetsam0新增。下一步WiFi定位转圈时序/补双入口seek续播；历史HLS23.943秒、S19、119/PadTS02/13Network、增长TS/旋转/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main仍开放。

详见[本轮交接](../handoffs/2026-10/2026-10-14-WIFI-PRIORITY-REPEAT-SEEK.md)。
<!-- WIFI-PRIORITY-REPEAT-END -->

<!-- WIFI-ONLY-PAUSE-CURRENT -->
## 2026-10-14 流量包已开通：WiFi优先，蜂窝需限量

- 用户先因流量耗尽暂停蜂窝，后明确告知流量包已开通、本月总量仅10GB并要求谨慎避免超额。恢复调试授权已收到；本轮仍仅WiFi，不把10GB视为测试可用预算，不进行大文件持续蜂窝播放。后续必要蜂窝取证须有明确请求上限及实际用量记录；运营商剩余额度未实测。手机WiFi已核实ON，旧未执行R2回退/R3及文件蜂窝窗取消，不补跑。
- 本轮仍为dirty5b8afe21d0ce普通Debug06:06:17，源/173输入未改。USB两机已现场保留数据覆盖；iPhone18既有无线身份现场核实，当前最新包InstallComplete+lookup成功，25/25偏好逐值保持，实际启动截图为当前对话，本批Nastart首页未验。
- 蜂窝已完成R1及R2启动/前进证据保留；R2回退未执行，工具前台信息nil对象500，独立取图显示其他App、Nastart状态2，无新增实际App/WDA/Jetsam报告，不把该窗口写成正常回退完成。后续WiFi结果和收尾待本轮交接。
<!-- WIFI-ONLY-PAUSE-END -->

<!-- OVERLAPPING-ORIGIN-PROOF-CURRENT -->
## 2026-10-14 蜂窝认证准备重叠已实现，三机最新包已安装

- 本批仅3输入新增修改，其他170保持；dirty5b8afe21d0ce、普通Debug06:06:17，实际377测试/2跳过/0失败、15预检/构建、173输入/29库签名/deep/profile/IPA三SHA及最终源核对。
- 私有与首个已保存公网自身身份探测重叠，但内网正响应优先；transport失败、同服务器账号、当前网络/登录/两端凭据均保持发布门槛。取消清理两个请求、原两次尝试预算保持；6异步边界测试通过，不改媒体参数/NAS/Mac网络/canonical轨道书签。
- USB13 06:08:27/Pad06:08:18、无线18 06:09:43当前5b包保留数据覆盖，25/18/25安装偏好逐值保持；三机普通空env/args实际正常首页均看过。18 InstallComplete+lookup及userspace启动证据已完，自动Xcode/WDA/无线全播放仍开放。
- 12个WiFi基础窗（S01双入口双机+S03/S08/S11/S18仅JF双机）实际选定图和普通退出已看；2个13蜂窝150秒窗口实际metrics/图与普通退出已留证。S03认证3036ms vs旧约3596ms、内部信号5.608vs6.113秒，单窗网络/缓存未配对，不认定稳定速度收益或全L2/3/SUB/AUD/HDR/FPS通过，旧HLS23.943秒仍开放。
- iphone13原24项非书签偏好逐值保持，6项自然书签变化，原S03两入口轨道保持；ipad原17项非书签偏好逐值保持，6项自然书签变化，原S03两入口轨道保持；两USB最终正常首页/播放器关闭/空env/args、WiFi恢复ON、idle10动画2、原生active0、真实Nastart/WDA/Jetsam集合0新增。未删除任何历史失败。
- 下一步重复同条件蜂窝首帧/seek/续播，并在HLS慢窗同步服务器与交付；S19、旧119/PadTS02/13Network、增长TS、旋转、全SUB/AUD/HDR/PiP、竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main继续保留。

详见[本批交接](../handoffs/2026-10/2026-10-14-OVERLAPPING-ORIGIN-PROOF.md)。
<!-- OVERLAPPING-ORIGIN-PROOF-END -->

<!-- HLS-SERVER-STARTUP-CURRENT -->
## 2026-10-14 三机最新包已核对，首分片等待继续分阶段排查

- 本批生产源码未修改，dirty24007d408f /普通Debug02:29:13；173输入、三二进制SHA及签名重核。371测试/2跳过/0失败、15预检与构建属于上一批实际完成，本批未重复运行。
- USB13 04:32:44 /Pad04:32:53保留数据覆盖，25/18安装偏好逐值保持；无线18现场既有配对 NETWORK 身份iPhone19,7/27.0，04:48:29 InstallComplete+lookup成功，25/25偏好逐值不变。18 RSD/DVT空env/args普通启动与原生截图实际Nastart正常首页已验；自动Xcode/WDA/无线全播放仍开放。旧交接“240未装18”已被本批成功证据更新，原失败保留。
- 服务器10.11.11/FFmpeg7.1.4现场日志已取得；历史S03首分片请求后0.288秒即启动对应转码，响应头仍等23.943秒，VAAPI硬件编码/图形字幕叠加已启用，后续速度5.44×。不把四舍五入speed推导的准备时间当精确测量。
- 同文件probe A-B-B-A：原200M/1G为1337/871ms，10M/64M为53/52ms，全部exit0/12轨；但缩小预算丢失已选PGS7和PGS8尺寸，不能部署为全局优化。当前probe-only不能单独复现历史24秒等待。独立/tmp同管线测试保留全部先导超时，排除后台终端stdin后原预算首个非空TS约1848/1844ms，较小预算1031/1035ms；文件开始写出不等于完整分片或实际出画。追加按第11段已打开的保守完成边界，原预算2567/2562ms、较小预算1851/1751ms，四窗首段均H264852×480/AAC6声道、时长4.046656秒；不能替代手机蜂窝交付或字幕实际内容验证。
- 两USB最终空env/args实际正常首页、播放器关闭、idle10/动画2、原生条件active0；24/17非书签偏好逐值保持，各1自然书签变化、原S03两入口轨道不变；Nastart/WDA/Jetsam真实集合0新增。追加13真蜂窝S03从头150秒、Pad同源WiFi30秒，普通退出/实际PNG已看；内部首帧自外层点击6.113/2.288秒，32/32 metrics蜂窝与4/4非蜂窝，均KS原始流/0HLS请求。不是同网络/缓存的性能排名，13 maxStall1不能当全程无卡顿，旧HLS24秒未复现；捕获574/128事件0新119/logout仅属本窗。
- 13首帧前约4.53秒尚在准备，0.474到4.070秒认证上下文串行探测是明确下一优化入口：评估同一网络/登录/凭据归属的独立并行探测，保留可达内网优先、当前公网自身凭据与取消/重试边界；同时继续旧HLS慢窗同步取证。首帧/seek性能尚未验收。旧119、PadTS02/13Network、增长TS、旋转、S19、全SUB/AUD/HDR/PiP、竞品完整帧、弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main仍全部保留。

详见[本批交接](../handoffs/2026-10/2026-10-14-HLS-SERVER-STARTUP.md)。
<!-- HLS-SERVER-STARTUP-END -->

<!-- PROXY-REVOCATION-CURRENT -->
## 2026-10-14 旧播放流释放已修复：双USB回归完成，蜂窝加载仍开放

- 当前dirty源24007d408f（HEAD4de732dd），普通Debug02:29:13；本轮实际371测试/2跳过/0失败、15预检/构建、173输入、29库独立签名/deep/profile/IPA三SHA及03:20最终源核对。本批只改DevicesView活动传输释放与一项隔离回归测试，其他171输入不变；精确token+监听端口终止自己的既有读者，与上游回调串行，清理迟到缓存，不取消共享session/其他route，不改媒体预算/Range/轨道/书签身份。旧代码受控负例1测试2失败（含1unexpected，5.744秒）及新0.066秒通过均保留。
- 最新普通包USB13 02:30:59、Pad02:31:11保留数据覆盖，25/18项安装偏好逐值保持、空env/args实际正常首页。逐窗现场姓名/型号/系统/UDID/USB与源/三SHA/安装门槛；S01四窗及受影响S03/S08/S11/S18双机双入口16窗，共20个30秒稀疏采样与普通退出，实际选定PNG已看。不是完整L2/L3、连续帧/听音/HDR或速度排名；S08 t10黑场（Pad文件已有字幕）不能单独判加载失败，Pad S03文件t3旋转状态文字残留保留。
- 13真实WiFi详情→蜂窝S11/S03启动有画面；旧原始流在兼容流commit时routeRevoked/取消请求已捕获，后续±15真实影片/字幕与退出已看。S11/S03外层触摸→内部首帧5.826/6.274秒；后续AVPlayer恢复2106/730、734/721ms，发生于225/247、209/231秒，不能与基线KSPlayer不同时间/缓存直接排名。S03首个HLS分片从63.465到87.408秒才有响应头，期间同分片三读者重发；列表993ms，约23.943秒分片等待仍待核服务器准备/传输，不把TCP读FIN当整连接取消。第一次调控制栏TOOL伴随转圈，实际crash pull/原故障保留，之后同播放器恢复后才补seek。
- Pad新增原生中段→普通退出→正常冷启动→实际“继续观看”阳性：S03当前canonical库/账号/条目/源/容量身份保持，保存1545.217秒、冷启动1545.079秒（差0.138秒），轨道不变，实际t3黑屏转圈25:45/t10影片仍转圈/t30新影片与普通退出已看。位置正确，不是加载速度/蜂窝/异常杀进程耐久验收。最新共24启动窗；原S03旧身份长书签与原轨保留，不把另一个旧MediaSource位置强行回写到当前源。
- 最终两机原24/17非书签偏好逐值不变，各10自然书签变化，原S03文件/JF轨不变；13 WiFi恢复ON，两机空env/args实际正常首页/播放器关闭、idle10动画2、原生条件active0；真实Nastart/WDA/Jetsam报告集合均0新增。最新包捕获事件并集13/Pad均0新119/logout（4065/2685事件；93/56上报HTTP接受、0捕获上报失败），不抵消上一轮13的2条119或更早失败。
- 18现场既有无线配对身份iPhone19,7/27.0可读，官方开发连接仍unavailable；HouseArrest断开，最新覆盖在AFC创建PublicStaging前后断开，IPA未上传、Install未发、无InstallComplete/lookup。本包未装18，最后确证仍是历史f58安装且UI未验；保留故障，Mac VPN/网络/配对/WDA未动。安装受阻不算最新包回归。
- 下一步先核S03兼容首分片23.943秒等待的服务器就绪与传输/重复读者，再一致引擎/时点/源的蜂窝seek与冷启动性能；当前源普通冷续播已有一项阳性，低比例服务器策略/其他源/蜂窝/异常终止仍开放。旧119、PadTS02花屏/幽灵seek、13Network物理内存、增长TS尾部、旋转/18UI/全SUB/AUD/HDR/PiP、完整帧竞品、真实弱RF/外部WiFi/十分钟/S19/MTP/完整19×4/PX/UX/CB/Main/L3全部保留。

详见[本轮交接](../handoffs/2026-10/2026-10-14-PROXY-ROUTE-REVOCATION.md)。
<!-- PROXY-REVOCATION-END -->

<!-- AUTHENTICATED-CONTEXT-CURRENT -->
## 2026-10-13 Jellyfin 切网播放已恢复，蜂窝 seek 与续播仍开放

- 当前 dirty 源8979d86352（HEAD 4de732dd），普通Debug 21:54:50；370测试/2跳过/0失败，15预检、构建、173输入、29库独立签名/deep/profile/IPA三SHA核对。任务局部不可变独立认证上下文统一准备/字幕/播放/上报/清理；不搬token，不临时全局换client，不改媒体参数或原书签身份算法。内网传输失败仅触发当前公网自己的认证，公网正响应必须属于当前网络/登录/凭据。
- 最新包13 21:56:55、Pad21:56:49保留数据覆盖，25/18项安装偏好保持，空env/args正常实际首页；现场身份/包门槛逐窗执行。13原WiFi详情→蜂窝S11/S03已取得真实片头/影片，内部首帧从外层触摸约6.125/6.476秒；不能用内部1569/1898ms代替用户完整等待。±15引擎恢复S11 12396/14249ms、追加S03 8163/6943ms，有实际转圈/等待，性能仍未验收。
- S01双机双入口4窗，以及受影响S03/S08/S11/S18 Jellyfin双机8窗：30秒稀疏采样/实际PNG/普通退出完成。S08两机t10仍黑、t30影片；Pad S18首次工具误用“方世玉2”，实际标题“方世玉续集”，原TOOL和crash pull留证后补测。不是完整L2/连续流畅/全SUB/AUD/HDR/听音或速度排名。
- 追加S03“resume-seek”目录实际只有普通播放按钮，从0开始，不能计续播；旧原S03书签未变，其他既有源书签自然变化，需相同MediaSource身份再核冷续播/服务端持久保存。最终24/17非书签偏好逐值不变，各6自然书签变化、原S03文件/JF轨保持；WiFi恢复ON、正常首页/播放器关闭/idle10动画2/原生条件active0；Nastart/WDA/Jetsam实际报告集合0新增。保留最新13 22:02的2条119，最终滚动日志0不覆盖早期失败，0logout只属于捕获范围。
- iPhone18用户重新授权并完成亮屏同WiFi后，当前既有无线TCP配对身份iPhone19,7/27.0可核实，但HouseArrest/用户态隧道断开；保存故障后独立尝试保留数据覆盖，AFC在创建传包暂存目录时断开，清理再报ConnectionReset，IPA未上传且Install命令未发送、未见InstallComplete/lookup，本包仍未装18。最后确证已装仍为f58/20:34:43且UI未验，不把本候选元数据当安装事实；未改Mac VPN/配对记录，未重装WDA。
- 8864/1cc4/028f/147d失败候选全部保留，路径等待或等值比较不是原故障单独根因修复。下一步蜂窝seek目标分片与媒体源一致的续播配对；18服务恢复后覆盖最新；119、PadTS02、旧13Network物理内存、增长TS、旋转、全SUB/AUD/HDR/PiP、竞品完整帧、弱RF/外部WiFi/十分钟/S19/MTP/19×4/PX/UX/CB/Main/L3旧账全保留。

详见[本轮交接](../handoffs/2026-10/2026-10-13-AUTHENTICATED-PLAYBACK-CONTEXT.md)。
<!-- AUTHENTICATED-CONTEXT-END -->


## 2026-10-13 公网当前认证已证明：蜂窝仍误用内网，切网播放回退待实现

- 本批三文件只增加认证响应/归属验证、DEBUG后台自身会话Users/Me及4项反例；dirty f58e2171、普通Debug20:32:10，主f05996a2/Debug13c41cab/KS855ae304。实际363测试/2跳过/0失败、15预检/构建、173输入/29库/deep/profile/IPA三SHA最终核对。初次MainActor编译65修正后全套通过，失败留证；没有改变播放选路/媒体参数/登录首选，其他dirty保留。
- 最新包13 20:34:20/Pad20:34:38/无线18 20:34:43保留数据覆盖，25/18/25项安装偏好逐值保持；双USB正常空env/args首页/逐窗身份与包门槛。18既有配对实时直连→InstallComplete/lookup成功，RSD/DVT返回PID但实际其他App，Nastart前台UI/WDA/自动隧道未验；MacVPN及网络未动。
- 双USB真实WiFi两origin各用自己的token认证Users/Me均200/同服务器与预期账号。13原WiFi详情→实际蜂窝S03：公网HTTPS8097自身认证200，内网HTTP8096超时-1001；同服务器比较参考同RAM登录21.093秒前WiFi主认证，不能当当前蜂窝主可达证明。实际仍选libraryEndpoint/privateIP8096，60.347秒t3/10/30/60黑屏spinner/00:00、0内部首帧/metrics/seek，普通退出；原启动FAIL保留，未开始无效seek、未判速度改善。
- S01双USB双入口四个30秒采样/普通退出及t3/10/30/关闭实际图：内部13文件493/JF648、Pad文件1706/JF994ms，各2metrics全no；不算连续流畅/精确显示首帧/听音/全SUB/HDR或性能排名。最终13 WiFi ON、原24/17非书签偏好完全相同、各2自然S01书签、原S03文件/JF轨道不变；正常首页/空env/args/播放器关闭/idle10动画2/原生条件active0，Nastart/WDA/Jetsam实际0新报告。
- 下一步一致的独立公网播放请求/上报client与网络/认证/取消守卫，保持canonical书签身份/原轨并保留合法VPN可达内网；再原S03与另一源蜂窝真实首帧/HLS目标分片和±15配对。旧119/PadTS02/13Network物理内存/增长TS/旋转/18/全SUB/AUD/HDR/PiP/完整帧竞品/真实弱RF/外部WiFi/十分钟/S19/MTP/S11S18JF/L2/19×4/PX/UX/CB/Main/L3全部开放。

详见[当轮交接](../handoffs/2026-10/2026-10-13-AUTHENTICATED-ORIGIN-PROOF.md)。


## 2026-10-13 Jellyfin 公网独立会话已定位：本批观测完成，切网回退待实现

- 仅LaunchpadView DEBUG诊断，dirty dceba30041、普通Debug20:08:48，主8a048d2e/Debug7459a67d/KS855ae304；本次359测试/2跳过/0失败、15预检/构建、173输入/29库/deep/profile/IPA三SHA及最终源核对。无认证/会话顺序/选路/媒体参数变化，其他dirty保留。
- 最新包13 20:09:36/Pad20:10:02/无线18 20:10:35保留数据覆盖，25/18/25项偏好安装逐值不变；双USB空env/args实际首页。18既有配对实时直连身份→InstallComplete/lookup正常，RSD/DVT启动返回PID但实际锁屏，前台UI/WDA/自动隧道仍未验，网络/VPN保持。
- 双USB各6候选，内网HTTP8096与公网HTTPS8097 root各有独立非空存储会话、userID相同，恢复仍选内网。Mac匿名两个已配置origin均200且Server ID相同；尚不证明手机蜂窝可达/备用会话有效。下一步各地址自己的认证当前用户/服务器证据→网络/认证代次守卫→保持书签身份和轨道的最小回退，再原失败蜂窝启动/实际HLS分片seek；不复制内网token。
- S01双机双入口四个30秒采样/普通退出，t3/10/30及关闭原图已核；内部首帧13文件540/JF552、Pad文件2374/JF978ms，各2metrics全no。Pad文件t3黑屏spinner/00:00、t10片头、t30天空；不判连续30秒、精确显示首帧、全SUB/AUD/HDR/流畅或性能改善，缓存/轨道不同不排名。原蜂窝失败与L2/L3未验保留。
- 最终13原24/Pad17非书签偏好不变，各2自然S01书签，S03文件/JF原轨保持；空env/args实际正常首页/播放器关闭/idle10动画2/原生条件active0，真实报告集合0新Nastart/WDA/Jetsam。0新119/logout仅本捕获范围，旧119/PadTS02/13Network物理内存/增长TS/旋转/18/全字幕音频HDR/PiP/竞品帧/真实弱RF/外部WiFi/十分钟/S19/MTP/S11S18JF/L2/19×4/PX/UX/CB/Main/L3全部开放。

详见[当轮交接](../handoffs/2026-10/2026-10-13-ENDPOINT-SESSION-INVENTORY.md)。


## 2026-10-13 LAN 验证绑定网络代次：最新包三机已装，蜂窝入口仍待修复

- 仅在5aa基线之上修改LAN验证缓存/网络代次、所选地址分类与4项测试；保留当前蜂窝/VPN新鲜验证，无认证/token迁移、Range/超时/重试/缓冲/轨道/解码/seek改动。最终dirty源16c358c3，普通Debug18:38:52，主fd134885/Debuga7538831/KS6be1f678；本批实际359测试/2跳过/0失败、15预检/正常构建及173输入/29库/deep/profile/IPA三SHA，19:54最终重核。其他dirty保留。
- 最新签名包USB13 18:40:31、Pad18:48:42、无线18 19:50:33保留数据覆盖，25/18/25偏好安装逐值不变。双USB空env/args实际首页及逐播放窗现场身份/包核对；18实时既有配对直连身份成功后安装/lookup证据完备，用户态RSD/DVT启动返回PID，但实际屏幕仍为其他App，前台Nastart UI/WDA/自动隧道未验，MacVPN未动。
- 历史Pad119首snapshot发生于FS成功attach后104ms，请求代次匹配刚发布FS；原snapshot/root各4条119、四次root重试仍同FS代次、捕获区间0logout。5aa本批双USB各3次冷根目录及Pad原S03文件→JF→冷S08文件→JF恢复正常，不证明119根因已修复；不是16c最新包回归。
- 原WiFi详情→原生WiFi OFF→S03 JF：5aa观察210.667秒、16c119.699秒均t60黑屏spinner/00:00、0内部首帧/0metrics/无seek事件；不能以观察时长或无效控件尝试算速度改善。新16c在蜂窝pathGeneration3拒绝旧LAN验证，仍选privateIP/8096的libraryEndpoint。配置另有HTTPS/domain/8097，是否有其自身有效会话/同服务器账号待核，原启动未修复。
- 最新S01四窗与S03/S08两机双入口八恢复窗共12个普通30秒采样/正常退出，另13 S03文件完整重复及JF t7后WDA断连/404的不完整TOOL窗均保留；Pad两次home reset及代表初次开窗前reset实际crash pull/原生App在Runner不在留证，既有fixture/新空session恢复。选定PNG已看；Pad S03接手有t15黑屏spinner/t30黑屏，不判连续播放/听音/HDR/流畅或完整L2。
- 19:54终核13原24/Pad原17非书签偏好不变，各6书签自然变化，S03文件/JF原轨选择均保留；两机原生条件active0/空参数实际NAS正常首页/播放器关闭/idle10动画2，13 WiFi1；Nastart/WDA/Jetsam报告集合0新增。下一步备用公网入口的独立会话/服务器身份/网络所有权，再原蜂窝启动与HLS目标分片配对；119/PadTS02/旧Network物理内存/增长TS/旋转/18UI/全SUB/AUD/HDR/PiP/竞品帧/弱RF/十分钟/S19/MTP/S11S18JF/L2/19×4/PX/UX/CB/Main/L3旧账全部开放。

详见[当轮交接](../handoffs/2026-10/2026-10-13-LAN-PATH-VERIFICATION.md)。

## 2026-10-13 目录传输失败回退候选：三轮约8.6秒，119会话失败仍待查

- 仅DSMClient目录浏览在URLError后停止API兼容变体，保留既有同请求重试/HTTP-API-JSON回退/119/取消/随后主动重试/snapshot；无Range、缓冲、轨道、解码或seek改动。dirty源5aa9070d，普通Debug17:13:23，主4904f0f2/Debug4ec96d31/KS6be1f678；355测试/2跳过/0失败、15预检/构建及173输入/29库/deep/profile/IPA三SHA核对。首次354测试22断言失败为fixture漏掉既有重试，失败保留并修正，其他dirty未动。
- 17:14:04 USB13、17:14:56 USBPad保留数据覆盖最新，25/18偏好安装逐值相同、空env/args实际首页；逐播放窗现场身份/包核对。S01四窗、S03/S08两机双入口及S11/S18两机文件入口共15基础/代表普通退出窗，选定实际PNG已看；S11/S18 JF、MTP/十分钟等未验，不标完整L2/听音/HDR/流畅PASS。
- 旧29d三轮S03蜂窝目录33787/16514/16638ms、准备期间timeout变体记录4/2/2；新5aa8574/8577/8589ms、各1失败记录。内部首帧旧51.181/28.777/29.983秒、新21.844/14.380/14.675秒；媒体metrics全部蜂窝yes，每窗14保存样本全源4/5/开启/普通退出。目录pending复用、LTE/5G及旁路字幕/HLS缓存不同（新后两轮匹配0ms，旧约6秒），仅分段观察，不算三组严格独立冷请求/完整速度验收。WiFi OFF未确认的旧工具失败窗排除，原WDA断连和恢复分别留证。
- Pad准备S08曾真实文件根目录HTTP200/API119，browserRoot attempt1停止；原生重试和首页刷新后重试各15秒仍失败。新空参数session/普通启动后的活动会话S08文件/JF恢复窗成功，119失效原因未修复，原失败不能被恢复抵消。
- 17:49终核原24/17非书签偏好不变，各8书签自然更新；手机原生恢复4/nil/Off后，两机S03文件/JF原轨一致。手机WiFi1、原生条件active0、实际正常首页/空参数/播放器关闭/idle10动画2、0新增App/WDA/Jetsam；MacVPN未动。18广告地址既有配对探测超时，无本轮可信身份，当前候选未装/UI未验。
- 下一步查Pad119当前会话代次、目录cache/pending归属及独立配对计时，再查剩余匹配流/HLS分片与蜂窝seek。PadTS02花屏、旧13 Network/物理内存、增长TS尾部、18、全SUB/AUD/HDR/PiP/旋转/完整帧竞品/真实弱信号/外部WiFi/十分钟/S19/MTP/完整L2/19×4/PX/UX/CB/Main/L3全部旧账仍开放。

详见[当轮交接](../handoffs/2026-10/2026-10-13-FOLDER-TRANSPORT-FALLBACK.md)。

## 2026-10-13 初次HLS源轨阳性与准备计时：蜂窝目录等待33.8秒，速度问题仍开放

- 本轮先核79e基线，再仅DevicesView及中英文日志增加DEBUG准备分段计时。HEAD4de732dd、最新dirty源29d6c775、普通Debug16:03:53；主fe024838/Debug26b6545f/KS6be1f678，实际351测试/2跳过/0失败、15预检及构建；173输入/29库/deep/profile/三SHA现场与最终核对，其他dirty保留。
- USB13（iPhone14,5/iOS16.3.1）16:05:55、Pad（iPad12,1/iPadOS18.3.1）16:07:19保留数据覆盖新包；安装时25/18项偏好逐值相同，空env/args实际首页及逐窗设备/最新包核对。最新S01双设备/双入口四窗30秒+普通退出/实际PNG已核，内部首帧13文件/JF0.742/1.963秒、Pad2.368/1.618秒，各2metrics全no；轨道/缓存不同，不作性能排名或全字幕听音/HDR/流畅PASS。
- 79e本轮基线13原生选回源4/5/开启后蜂窝初次HLS及自动降档接手均保留；内部首帧49.705秒、65.012秒接手，±15秒引擎恢复722/723ms，79metrics全yes。旧WDA断连/session404窗口TOOL不完整、真实crash pull/App存活及新空参数session恢复分列，不能把恢复覆盖原失败。
- 最新29d手机预览自然停留>578秒后实际WiFi OFF，S03从头90秒：49metrics全yes、15保存采样全源4/5/开启，初次verifiedJellyfinHLS阳性已覆盖；目录33819ms/四次API失败、旁路字幕15ms、匹配流6186ms、41.898秒交播放器、49.408秒内部首帧；t30准备/t60片头/t90电影。此窗未seek/无降档接手，错误码未可靠解析。Pad新包S03原文件路由1272ms/LAN Range39ms、内部首帧3.340秒/6metrics全no/普通退出，非配对比较。
- 最终16:35源码/包/双USB重核；原24/17非书签偏好不变，各3书签自然更新，手机原生菜单恢复S03 Off后两机S03文件/JF原轨与当轮开始一致。正常空env/args实际首页/NAS正常、播放器/PiP关闭/idle10动画2、原生条件active0；0新增Nastart/WDA/Jetsam。WiFi原生W3C恢复1，失败element click与JF覆盖底层AX导致误报NAS未就绪均留TOOL，不归为NAS/App失败；Mac VPN未动。18无线没有本轮身份，未安装当前候选/UI未验。
- 下一步对目录传输失败继续版本变体/可选元数据阻塞建负例和最小修复，保持119认证、取消、账号隔离/真实外置字幕/文件身份，再同文件同轨同位置三组配对；原文件LAN探测/HLS目标分片代次继续定位。PadTS02花屏、13旧Network/物理内存、增长TS尾部、18、全SUB/AUD/HDR/PiP/完整帧竞品/弱信号/十分钟/S19/MTP/L2/19×4/PX/UX/CB/Main全部旧账仍开放，尚无速度修复或性能验收。

详见[当轮交接](../handoffs/2026-10/2026-10-13-SOURCE-TRACK-PREPARATION-PHASES.md)。

## 2026-10-13 初次兼容流源轨/位置候选：新包双USB覆盖，首帧等待仍未解决

- 本轮接续容器重启后工作，仅 DevicesView.swift/PlaybackNextCoreTests.swift 增加初次匹配HLS的源轨/Off/外置字幕与续播位置验证，未知索引/无法映射拒绝快捷分支；没有解码/Range/缓冲/seek策略改动。HEAD4de732dd，dirty源79e77091，普通Debug08:55:41，主b1b87716/Debug2108343c/KS6be1f678；实际351测试/2跳过/0失败及15预检/构建，173输入/29库签名/deep/profile/三SHA现场和最终重核。
- 08:57:14 USB13、08:58:18 USBPad保留数据覆盖最新候选，25/18偏好安装时逐值一致；逐窗现场身份/连接和空env/args重核。S01两机文件/JF四窗30秒采样+普通退出、选定实际片头/详情图已看；3项metrics/窗全no，不算全矩阵/音频/HDR/流畅PASS。初次JF按钮错误、Pad目录刷新及手机工具接口缺失独立保留。
- 旧ac8基线Pad S19文件WiFi内部首帧7.950秒，前后/深段引擎恢复6073/4194/4366ms，HLS候选8618ms对齐失败，无接手。13旧蜂窝S19准入约75秒失败；候选准备窗WiFi也失败，双机首页09:17未连接、09:19同App自行恢复，未证明容器稳定或全NAS重启。
- 新候选13当前会话WiFi备S03详情→实际蜂窝从头：9项metrics全yes，KS原流，内部首帧16.065秒（内部tap3849ms），t10准备/t60电影+spinner；21.1秒候选准备，61.4秒窗无接手，未seek。原全屏关闭及WiFi确认TOOL失败留证，后原生系统PiP关闭/实际WiFi1恢复。早先“60秒未进入”点评已按t60/诊断更正；没有首帧/seek性能改善PASS，初次HLS原失败阳性分支仍未覆盖。
- 最终原24/17非书签偏好不变，各3条书签自然保存；13 S03文件音轨旧0→源4、字幕仍Off，不是原4/5开启恢复，JF/Pad原轨保留；无手写偏好。空env/args实际首页/NAS正常/播放器与PiP关闭/idle10动画2，原生条件active0，0新增Nastart/WDA/Jetsam；Mac VPN未动。18无线无当轮身份，候选未安装/UI未验。
- 下一步原失败源4/5/开启的初次HLS阳性复验、准备阶段约12秒的分段计时与HLS目标分片/代次定位，同文件同轨同位置配对再最小等待修复；PadTS02花屏、旧13 Network/物理内存、增长TS尾部、18、L2/S19/MTP/SUB/AUD/HDR/PiP/完整帧竞品/19×4/PX/UX/CB/Main全部旧账继续开放。

详见[当轮交接](../handoffs/2026-10/2026-10-13-INITIAL-COMPATIBLE-SOURCE-TRACKS.md)。

## 2026-10-13 大文件真实蜂窝：首帧及HLS跳转等待已留证，容器恢复待核

- 更新时间：2026-10-13T08:36:43.937193+08:00。用户反馈18蜂窝《碟中谍》《指环王》，版本/时长未明；本轮优先USB13/Pad，18未连接/当轮包身份与UI未核。无iOS源码改动；沿用ac8f176e普通Debug07:29:18（主7cc99e07/Debug0e2bae07/KS6be1f678），173输入/29库签名/deep/profile/三SHA现场和最终重核。348测试/2跳过/0失败及15预检仅引用上轮同源。
- 08:00:39/08:01:07双USB逐机身份重核后保留数据覆盖最新，25/18偏好安装时逐值一致、空env/args实际首页已看。13实际关闭WiFi、VPN未连接/无人工限速，S03文件续播/从头内部首帧8.576/7.802秒；JF续播3.326秒但起点/引擎不同，不排名。各66/43/42项metrics全cellular=yes；PadWiFi文件2.937秒/50项全no，不能算蜂窝或完整性能PASS。
- JF首次兼容流40037ms对齐失败，第二次39723ms/触摸起算150.382秒接手；后两次15秒seek各20秒无engine完成/恢复，t20旧画面+spinner，目标分片重复请求，根因尚未知。普通文件按钮13恢复280～591ms/Pad1964～2425ms只是引擎时钟，不是精确显示；原控制TOOL失败及恢复独列。
- 13文件兼容流首窗将S03原轨4/5/字幕开启自然写成0/nil/关闭，JF与Pad原轨保留，待查源轨/渲染轨持久化；非书签24/17项仍逐值不变。NAS运行时长骤降/JF入口消失，用户确认Container Manager意外重启并要求稍等，未确认全NAS重启；13JF从头NAS恢复-1001/PadJF缺入口均未播放，S19未执行，不把服务中断当播放器成功或统一根因。
- 08:37原生App刷新后13重新出现Jellyfin入口，但状态仍未知；08:39媒体库搜索及S19详情实际恢复；文件服务/容器稳定性和中断后播放未验，按用户要求等待，不判全面恢复。已恢复13WiFi ON、双机原生条件active0/空env/args实际首页/播放器关闭/idle10动画2；0新Nastart/WDA/Jetsam报告，旧Network崩溃和PadTS花屏未关。等容器服务恢复后另建同位置/轨道基线，补S19/JF从头与HLS请求定位再最小修复。全部原增长TS/S01/L2/MTP/18/SUB/AUD/HDR/竞品/19×4/PX/UX/CB/Main缺口继续保留。

详见[当轮交接](../handoffs/2026-10/2026-10-13-CELLULAR-LARGE-FILE-TRIAGE.md)。


## 2026-10-13 TS 解码观测：硬解已确认，iPad 暂停花屏仍待修

- 更新时间：2026-10-13T07:49:39.666356+08:00。仅FFmpegDecode.swift增加DEBUG限量包/帧/flush元数据，没有解码/seek/Range/缓冲策略修复；HEAD4de732dd、dirty源ac8f176e、普通Debug07:29:18，主7cc99e07/Debug0e2bae07/KS6be1f678。最新源码实际348测试/2跳过/0失败、15预检/构建，173输入/29逐库签名/deep/profile/链接/IPA及最终三SHA重核。18本轮未操作/当前包未核。
- USBPad/13逐机现场身份重核后保留数据覆盖最新包，18/25项偏好安装时逐值不变，空环境实际首页已看。双机各四拖动+8按钮/暂停t3/10/30/恢复90秒请求窗/普通关闭；13选定图未见旧大片花屏。Pad拖动后14:45图较清晰，按钮后同目标885.455980/报告PTS886.859在t10/30明显方块重影，FAIL仍在，恢复/退出不抵消。
- 两机原始输出158/hwFrames=true，依赖头文件宏值确认VideoToolbox实际硬解；Padepoch8/24首12包及17帧数值字段分别相同，但图像质量不同且错误位0。源帧身份/输入内容/输出像素摘要仍缺，具体根因未确定。采样Pad60、13为64个发送UNKNOWN(-1313558101)，两机均有，不能等同根因；没有采到EAGAIN。12次seek各24flush，generation0不是seek身份，未判重复flush致错。
- 旧35ed原生滑块请求885实际897.354637/PTS898.759，不计同位置参考；长名称元素404/13工具缺方法/宏include错误已纠正留TOOL。初版e434日志包只Pad安装未开窗，最终ac8覆盖后采集；隔离Mac PyAV仅准备，独立源帧未取得。
- 最终原24/17非书签偏好不变，各1个TS02书签自然更新，原S03文件/JF整条不变；空env/args实际首页/NAS正常/播放器关闭/idle10动画2。双机Nastart/WDA/Jetsam报告集合0新增，旧13 Network崩溃/物理内存未关闭。下一步输入/输出摘要及真实seek所有权、同源软硬解对照再最小修复；S01四单元/L2代表族/S19/MTP、增长尾部、SUB/AUD/HDR/竞品/蜂窝/19×4/PX/UX/CB/Main/L2/L3全部旧账保留。

详见[当轮交接](../handoffs/2026-10/2026-10-13-TS-DECODE-TRACE.md)。


## 2026-10-13 TS 连续跳转扩展验证：iPad 暂停花屏两次，待修

- 更新时间：2026-10-13T07:13:20.422868+08:00。现场双USB身份/连接重核，源码仍35ed118b普通Debug（主18970d8d/Debug16193dda/KSba329d9e、04:45:34构建），173输入/29库签名/deep/profile/IPA三SHA重核。本轮没有iOS源码改动；348测试/2跳过/0失败与15预检仅引用上轮同源，本轮未重跑。18未操作/更新。
- 06:45:14 USB13、06:48:36 USBPad保留数据覆盖成功，25/18非诊断偏好安装时逐值一致，空env/args实际首页已看后开窗。初始tidevice传输停滞、Pad devicectl协调冲突3002/IX48及PMD70秒超时保留，最后原生覆盖成功；未卸载/清数据/重装WDA。
- 第二源TS02实际mpegts/HEVC Main 1080p 8bit30fps/AAC，1126170624 bytes/1802.641677秒、206/video-mpeg；不是S05交错H264/>24h原点，也不计当前增长尾部验收。MI2实际MKV不冒充TS，旧R01行缺失/首次行触摸无效及实际重试均留TOOL。
- USB13一次连续中段→85%→25%→中段拖动、8次前后15秒按钮，恢复90秒请求窗与正常退出；选定暂停/恢复图清晰，不能判逐帧精度/声音/内存/流畅PASS。Pad相同连续操作首轮最终885.455980秒/PTS886.859与重复893.388436/PTS894.793，选定暂停图两次方块花屏；首轮t10/30持续。单次888.430667/PTS890.093图清晰，但目标不同，不能确认竞态或排除源帧。后续按钮和恢复画面清晰不能抵消暂停失败，L1扩展尚未通过。
- 实际模式ffmpegVideoToolboxEligible，源码对应FFmpegDecode，不是自定义videoToolboxAsync；真实硬解上下文尚缺证据。下一步同位置内容/串行参考及包→帧→flush代次观测，确认共用缺陷后最小修复与原失败双USB回归，暂不扩大格式验收掩盖失败。
- 最终原24/17非书签偏好不变，各1个TS02书签自然新增/更新，S03文件/JF原整条书签不变；空环境实际首页/NAS正常/播放器关闭/idle10动画2恢复。前后完整报告集合Nastart/WDA/Jetsam均0新增；旧13 Network崩溃未关闭，未测物理footprint/长压。全部L1 S01四单元、L2代表族/S19/MTP、真实增长TS/SUB/AUD/HDR/竞品性能/蜂窝/19×4/UX/CB/Main旧总账保留。

详见[当轮交接](../handoffs/2026-10/2026-10-13-TS-SEEK-EXPANDED.md)。



## 2026-10-13 暂停 TS 时间戳跳转：S05候选定向有效，扩大回归待验

- 更新时间：2026-10-13T05:06:27.227672+08:00。旧860f普通Debug双USB S05复现50分钟控件与片头提交画面不一致；13恢复后04:32:02发生真实SIGTRAP/Network分配崩溃，报告已保存，虚拟MALLOC6.7GiB不是物理footprint。具体内存持有者与旧帧竞态尚未确定，崩溃未关闭。
- 仅共享精确seek选路及2项测试：精确跳转采用时间戳，不按平均码率/旧包位置估算字节；非精确旧能力规则保留，未改Range/缓冲/解码模式。旧规则提取2测试3断言失败，候选全348测试/2跳过/0失败、15预检/构建成功。
- HEAD4de732dd、dirty源35ed118b，普通Debug主18970d8d/Debug16193dda/KSba329d9e，04:45:34构建，173输入/29逐库签名/deep/profile/IPA三SHA/链接重核。04:46:53 Pad、04:47:34 USB13保留数据覆盖，18/25偏好逐值一致，空env/args实际首页已看，窗口身份重核。18本轮未操作/未更新候选。
- S05中间暂停拖动→暂停前进15秒两机画面不再退到片头，PTS接近控件目标；恢复播放90秒请求窗选定t30/90实际电影与普通关闭已看，两机清单无候选新增Nastart报告。片尾重复两机约5995/5998→前进15秒均有不同末尾实际电影/新提交帧，恢复90秒请求窗最后自然EOF、Play及普通关闭已看；尾部窗口包含EOF，不记90秒连续播放。四窗候选清单无新增Nastart/WDA/Jetsam报告，旧13崩溃仍保留；不是完整逐帧精度/物理内存/长期压力/声音/全字幕/HDR/性能PASS。
- 同特征第二源、真实增长尾部/时长刷新、共享seek L2代表集/深偏移S19/MTP、Pad横屏过渡轮廓及全部历史SUB/AUD/HDR/性能/竞品/蜂窝/19×4/PX/UX/CB/Main/L2/L3保留。原始身份/凭据/偏好/图/报告只在本机私有证据：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-13-paused-ts-seek-042439`。

详见[当轮交接](../handoffs/2026-10/2026-10-13-PAUSED-TS-ACCURATE-SEEK.md)。
- 最终双USB身份/173输入/包三SHA/deep/source重核，原24/17非书签偏好逐值不变，各1个S05书签自然更新且EOF约6094.6秒保留，原S03文件/JF轨选择保持；空环境实际首页/NAS正常/播放器关闭/idle10动画2已恢复。只记S05声明范围有效，下一步同特征第二源/快速及反向seek、物理内存压力与规定L2/深偏移/并发，再真实增长尾部；未接受逐帧精度或关闭崩溃。


## 2026-10-13 TS 临时尾部续播位置保护：限定范围已验证

- 更新时间：2026-10-13T04:22:08.923777+08:00。HEAD4de732dd、dirty源860f4704，普通Debug主4f662129/Debug1b9f34cb/KSe68d7420；173输入/29库签名/深验/profile/IPA三SHA/链接与最终源核验。本轮实际346测试、2跳过、0失败和15预检；旧逻辑两项反例6断言失败，失败与初次测试参数顺序编译错误均保留。
- 仅续播存储规则及2项测试改动：已校验TS在临时尾部或旧时长之外保留真实位置，保存时长至少覆盖位置。内容身份不代表录制已结束，完整TS也保守保留片尾书签；普通MP4/MKV完播规则不变。不改引擎/Range/缓冲/尾部等待。
- USB13 S05尾部退出6068.478233→空环境冷启动相同位置→片尾退出6094.580733；Pad6080.857989→相同位置→6094.577611，旧时长6094.6，两机实际片尾字幕滚动与EOF Play图已看，音轨1/nil字幕开启保留。暂停seek后旧画面停留、时钟已变，画面精度未验；非真实增长尾部验收。
- S01两机文件/Jellyfin四入口30秒请求窗、S03的13 Jellyfin和Pad文件两入口，选定t3/10/30原图与普通退出/自然保存已核，Pad S03 t3仍准备/旋转过渡且圆环部分不可见，t10/30实际电影；新诊断无记录播放错误。非完整字幕/听音/HDR/逐帧性能/全矩阵PASS。
- 最新包保留数据覆盖：03:52:20 USB13、03:50:29 USBPad、03:52:48既有配对无线18，安装时25/18/25偏好逐值一致；现场身份/连接逐窗重核。最终13原24/Pad原17非书签偏好逐值不变，各4个书签自然保存，原S03文件/JF音轨/字幕/关闭选择保持；两机空env/args实际首页/NAS正常/播放器关闭、idle10动画2。18仅安装，当前实际UI/启动与自动隧道未验；本轮未取崩溃清单，不称0新崩溃。
- 13首拖动无效、目录AM/PM解析失败均保留；修正目录工具只查看当前页旧MP4，不能声称最新文件/增长TS。其他dirty、登录、网络/VPN、系统、NAS录制保持，无卸载/清数据/手写偏好。下一步真实增长尾部等待/追加恢复/时长刷新及暂停seek画面精度，S19/MTP、历史字幕原句/HDR与全部PX/UX/CB/Main、SUB/AUD/竞品性能/蜂窝/19×4/L2/L3未验总账继续保留。

详见[本轮交接](../handoffs/2026-10/2026-10-13-RECORDING-TAIL-BOOKMARK.md)。


## 2026-10-13 iPhone18 用户截图边界核对

- 更新时间：2026-10-13T03:40:54.861300+08:00。用户确认iPhone18更新后提供R02横屏截图：退出和更多的圆环完整，部分跨过视频左右边缘进入黑色留边，但没有跨出所提供截图的屏幕边界。视频内容边界不同于播放器/屏幕边界，留边仍为可见屏幕区域；本图不构成圆环被屏幕裁切的证据。
- 此次仅基于用户图像核对及更新记录，没有设备连接/启动/播放操作、安装或源码修改，不将用户截图等同于当轮安装身份现场核验、触摸/物理屏幕圆角/全部方向实测。iPhone18这张用户画面可证明本图圆环可见，自动隧道与其他实际操作回归仍待验；旧总账保留。后续继续增长TS尾部与时长刷新。


## 2026-10-13 播放器圆形按钮轮廓修复

- 更新时间：2026-10-13T03:39:55.631036+08:00。对照用户照片同一R02抖音直播录制MP4，USB13旧最新3e3aa7包已复现：黑色半透明圆底跨到黑色留边时融入，左右外圆边缘不可见。叉号/44点点击区域完整；不是本窗实际裁切证据。旧字体/位置候选未被认定为根因。
- 仅改LaunchpadView.swift：共享圆形按钮加1点白色24%边框，三个点复用同helper，边框不截获点击；布局/字体/安全区/播放引擎不变。HEAD4de732dd、dirty源e82a5bde，普通Debug主6113a756/Debuga2f7a36a/KSe68d7420。173输入/29逐库签名/深验/profile/IPA/链接和最终三SHA核验；本轮实际344测试、2跳过、0失败及15预检。
- USB13和Pad R02横竖屏实际原图圆环完整，两机更多菜单打开/取消与关闭返回详情正常；S01文件/Jellyfin四入口选定实际画面与完整圆环、普通关闭已核。13旧/新留边边缘同像素RGB0→61补强对照，非帧性能证据；未验EOF、反向横屏、物理圆角及大字体等其他裁切场景，不作全播放/音频/HDR/性能PASS。
- 03:28:07 USB13、03:26:51 USBPad、03:29:23既有配对无线18保留数据覆盖同最新包成功，安装时25/18/25项非诊断偏好不变；现场名称/型号/系统/UDID/连接逐机重核，原始身份/凭据/偏好/图仅私有。18本轮未启动/实际UI与自动隧道仍待验，不因安装成功关闭这些项。
- 最终USB13原24/Pad原17非书签偏好逐值不变，各3个R02/S01文件/JF书签自然保存，原S03文件/JF整条未动；两机空env/args实际首页/NAS正常/播放器关闭，idle10动画2。初始baseline工具准入拒绝及纠正保留；本轮未取崩溃清单，不宣称0新崩溃。其他dirty/网络/系统/登录/NAS录制配置未改，无卸载/清数据/手写偏好。
- 下一步回到增长TS旧尾部等待、追加后恢复与时长刷新/录制结束/替换文件负例，再HDR PiP/历史字幕原句和代表集。全SUB/AUD/HDR/蜂窝/完整帧Lenna与DS One、全PX/UX/CB/Main/MTP/L2/L3、475/119/HLS等旧总账保留；S01本轮只有UI控制层检查，不能替代完整播放矩阵。

详见[本轮交接](../handoffs/2026-10/2026-10-13-PLAYER-CHROME-CIRCLE.md)。


## 2026-10-13 播放器关闭叉号裁切反馈：定位中

- 更新时间：2026-10-13T00:30:13.294704+08:00。用户插入关闭叉号显示不全反馈，当前优先定位，TS尾部与全部旧总账保留。
- 未修改iOS源码；复核同最新3e3aa7b7普通Debug（主db592e17/Debug2a88b452/KSe68d7420）、173输入/签名/三SHA及现场USB13/Pad身份。两机保留数据覆盖成功，25/18偏好安装时不变，正常空env/args首页实际已看。344/2跳过/0失败和15预检引用上轮同源，本轮未重跑。
- S01文件普通继续观看/暂停/横竖屏往返/实际关闭，两机所采图叉号完整，关闭返回详情正常，但未复现用户报告。不能用矩形截图排除另一设备/物理圆角/反向横屏/文字大小/退出动画；固定44点+动态title3仅候选，尚未验证或认定。反向旋转TOOL失败、Pad末尾拖动INVALID_ACTION、13首次上传/短超时均保留；实际EOF未验，18未操作。
- 最终13原24/Pad原17非书签偏好不变，各1书签自然更新，原S03文件/JF条目保持，播放器关闭/空环境首页/idle10动画2恢复。下一步对照具体设备、方向及裁切画面，复现后修共享控制栏；不声称已修。

详见[本轮交接](../handoffs/2026-10/2026-10-13-PLAYER-CLOSE-LAYOUT.md)。

## 2026-10-13 正在增长的 TS 冷续播身份修复

- 更新时间：2026-10-13T00:09:33.249551+08:00；本轮从10月12日23:39接续，USB13/Pad优先，无线18另更新。现场名称/型号/系统/UDID/连接逐窗重核；原始身份/凭据/偏好/原图仅私有。HEAD4de732dd、dirty源3e3aa7b7，普通Debug主db592e17/Debug2a88b452/KSe68d7420；173输入/29逐库签名/深验/profile/IPA/链接及最终三SHA核验；实际344测试、2跳过、0失败及15预检。其他dirty及网络/系统/配对保留。
- 上轮4e36 R01旧失败保留：保存130.6754后增长换metadata key，冷启动initialPosition0。新版本TS/m2ts/mts先验证64KiB文件头与此前已写入区间，长度不减/mtime不退且checkpoint匹配才恢复；持久化仅哈希/偏移/长度/时间。相同文件头而旧checkpoint改变、截短、mtime倒退、身份响应错误/短数据均拒绝旧位置与轨道；普通文件revision key不变，旧TS仅精确metadata匹配才迁移，旧书签保留。三个源文件、7项新回归，未改缓冲/decoder/尾部等待策略。
- 双USB串行R01真实30秒请求窗→普通退出→空env/args冷启动/刷新→继续观看30秒→普通退出。13同key见证长度1186201600→1243611136，保存42.270066667→启动相同42.270066667→退出83.166066667；Pad1319108608→1492385792，40.517611111→启动相同40.517611111→78.330944444，轨道1/nil开启保留。两机冷窗t3仍黑底spinner，t10/30实际画面已看；首帧速度/完整流畅/声音未验，不能用startup临时0占位判成从头。
- Pad固定S05旧769.469611原key完整保留，新内容身份正常迁移，真实启动769.469611/initialSeek0/t30电影/普通退出794.613611；非完整精确seek/电影总矩阵通过。Pad首次目标行离屏、首次reveal底部排除过严导致TOOL失败，原图与失败脚本保留；核对实际末行后按App边界修正，冷窗4次有界滚动后打开，无排序偏好改变，不计性能PASS。
- 23:48:09/19双USB与23:49:22无线18同最新包保留数据覆盖成功，安装时25/18/25偏好不变；USB空env/args实际首页已核，18未本轮启动/实际UI与自动隧道待验。最终13原24/Pad原17非书签偏好逐值不变，各1/2书签自然新增/更新，S03文件/JF原位置与原轨未动、0新崩溃、播放器关闭、idle10动画2。未手写设备偏好/书签、清登录、卸载、修改NAS录制或网络。
- 下一步先增长文件尾部等待/追加后恢复与时长刷新、录制结束/替换文件真实负例，再旧主线HDR PiP/历史字幕原句与代表集。两段采样不是整文件哈希，保留两段都相同但中间改写的身份限制；本轮不证明全部替换情形。18实际UI、全SUB/AUD/HDR/性能/蜂窝/Lenna及所有旧PX/UX/CB/Main/MTP/L2/L3、475/119/HLS等未验总账保留。

详见[本轮交接](../handoffs/2026-10/2026-10-13-RECORDING-TS-COLD-RESUME.md)。


## 2026-10-12 设备文件 TS 时间轴与正在录制文件打开修复

- 更新时间：2026-10-12T23:29:18.640414+08:00。USB13/Pad优先，配对无线18更新；每设备/窗口名称、型号、系统、UDID及连接重核，原始身份/凭据/偏好/图只在本机私有。HEAD4de732dd、dirty源4e362e83；普通Debug主c64595d9/Debuge023a1ce/KSe68d7420，173输入/29逐库与深验/profile/IPA/链接及最终三SHA核验；实际337测试、2跳过、0失败和15预检。其他dirty/网络/系统/配对保留。
- 完整电影TS旧包24:09:59错误时钟：保留合法>24h/负FFmpeg原点，初始seek使用时间单位且不带字节标志，媒体丢帧使用相对原点；6项回归。首修1a62冷续播0帧/EOF/无法播放真实失败保留，二修1e81及最终4e36 Pad S05冷续播实际电影与正常时钟、普通退出769.469611已核。
- 用户最新目录持续变化，先发现MP4，再找到正在增长R01 TS；最终Pad列表80216064→实际162267136、13列表165412864→实际371458048 bytes，206/video-mpeg。TS/m2ts/mts只允许追加长度；其他文件仍严格等长、缓存隔离、截短/HTML/JSON/401/416拒绝。本轮未改缓冲/decoder/probe-size。两机串行90秒请求窗实际画面变化，Pad拖动约58秒后恢复有画面；非精确seek/完整帧/音频/直播尾部通过。
- 新发现R01冷续播失败：13正常退出保存130.6754，冷启动刷新448790528→461635584 bytes后入口变预览，initialPosition=0，普通退出42.7394。书签身份含长度和mtime，增长会换key；不得声称录制文件续播已修。下一步安全识别同一追加录制与替换文件、补冷续播，然后增长尾部等待/时长刷新/录制结束恢复。
- 最终USB23:00:38/48及无线18 23:11:16保留容器覆盖同包成功，安装时25/16/25偏好逐值不变；USB普通空env/args实际首页已看，18未本轮启动/实际UI仍待验。无线Bonjour探测超时/既有端点重新核对成功均保留，不声称Xcode自动隧道修复。
- 最终13原24/Pad原15非书签偏好不变，各5/2书签自然更新、S03文件/JF原轨及位置未动、无新崩溃，正常首页/播放器关闭/idle10动画2已核。Pad查最新目录的UI排序实会持久化，已正常UI恢复名称升序；额外2个默认排序key保留并明确记录，不能声称偏好总字典完全一致。未手写设备偏好/清登录/卸载。HDR PiP、历史重复原句、全SUB/AUD/HDR/性能/蜂窝/Lenna及全部PX/UX/CB/Main/MTP/L2/L3、475/119/HLS等未验总账保留。

详见[本轮交接](../handoffs/2026-10/2026-10-12-DEVICE-FILE-TS-RECORDING.md)。


## 2026-10-12 画中画播放状态与暂停字幕归属

- 更新时间：2026-10-12T22:06:32.541731+08:00。USB13/Pad优先，既有配对无线18另更新；每设备/窗口现场名称、型号、系统、UDID及连接重核，原始身份/凭据/偏好/原图仅私有。HEAD4de732dd、最终dirty源ea2f11eb，普通Debug主3ecb4173/Debugd3e7abcb/KSbaaeb6e0；173输入、29逐库签名/深验/profile/IPA/链接及最终三SHA核验。本轮实际331测试、2跳过、0失败及15预检；其他dirty、网络、系统、配对保留。
- 修正KS界面/切换按钮读取过期layer.state的问题，改读真实引擎并仅在变化时同步；外置覆盖按已提交字幕状态解析URL，暂停换PGS/Off无需等下一clock。中间d640版真实AV初始外置字幕被误清，已留证并补齐AV初始sidecar种子及第三项回归，最终ea2包已复验白双语。增加PiP返回时引擎/控件/时钟快照，不强制自动播放。
- 新鲜d640证据确认旧工具第二次点击浮窗中心实际命中系统暂停；暂停先于restore_requested。历史5519冻结同样工具模式仅作疑因，原失败未删除。最终13同PID系统返回：播放窗5982.574→5993.069且引擎/控件true；明确系统暂停窗3/10/15均6074.114、引擎/控件false且实际Play按钮，保留用户暂停。暂停窗首轮自动返回未接通，直接实际Restore补验成功；TOOL失败和重试保留。
- 最终Pad真实自动KS→AV/localHLS提交，外置请求server=-1，响应index=none/method=Encode（不能说服务端已承诺关闭烧录）；1288cue及白双语已看。暂停同句“不 / No.”切PGS7后真实AV startsPaused提交，30秒已看仅灰黄PGS、旧白层消失。启动3/10秒spinner与PGS初始准备保留；历史“Remember / I can figure…”原句未重放，不能解除历史SUB=F或宣称全SUB通过。
- 21:47:05/21:47:14两USB及21:49:28无线18保留容器覆盖成功，25/16/25偏好逐值一致；USB空env/args实际正常首页已看，18本轮未启动/前台UI待验。最终两13PiP窗16fresh帧、8有文本：有文本均hdrPQPreserved/分配未尝试/4K PQ，HDR外置浮窗字幕仍F；无候选提交跨过本次PiP，但完整竞态未验。
- 原JF PGS7经正常UI恢复；最终13JF6128.139、PadJF5860.423337333334均1/7开启，S03文件原轨及位置未动；24/15非书签偏好一致、各1JF书签自然更新、0新崩溃、普通空env实际首页/播放器关闭/idle10动画2。下一步重放历史重复原句与HDR保真方案，再最新源S01四入口/代表族、18实际界面及完整帧Lenna/DS One；全SUB/AUD/HDR/性能/蜂窝/MTP/L2/L3及全部旧PX/UX/CB/Main/475/119/HLS未验总账保留。

详见[本轮交接](../handoffs/2026-10/2026-10-12-PIP-RESTORE-SUBTITLE-STATE.md)。

## 2026-10-12 字幕服务端选择与画中画候选归属
- 更新时间：2026-10-12T21:04:09.700998+08:00。USB13/Pad优先，配对无线18另更新；每设备现场名称/型号/系统/UDID/连接重核，原始身份、凭据、偏好、原图只在私有目录。新源5a1e70c5普通Debug主e74c7ffe/Debug477aedc5/KSbaaeb6e0；173输入/29逐库签名/深验/profile/IPA/链接/最终三SHA核验，实际328测试/2跳过/0失败、15预检。其他dirty及网络/系统/配对保留。
- 旧6939日志确认KS PiP启动后自动AV候选仍提交；新代码以PiP启动代次守卫所有候选准备/提交。外置文本及Off明确请求服务端字幕-1，PGS源索引保留，增加实际协商诊断与2项回归测试；真实新包HLS候选未触发，旧重复原句未复验，不宣称根因全解/全SUB通过。
- 20:26:43/20:27:19两USB及20:33:11无线18保留容器覆盖成功，25/16/25偏好逐值不变；USB空env实际首页已核，18本轮未启动/前台UI待验。双USB外置ASS实际PiP→同会话系统恢复→同PID全屏；19fresh字幕帧中7有文本，均hdrPQPreserved/分配未尝试/4K PQ，外置HDR浮窗字幕仍F。13返回后clock5519.171在3/10/15停住，手动恢复后推进；Pad返回10/15单白双语且clock推进，限本窗证据。
- Pad暂停ASS→PGS菜单采样仍有白与灰黄重叠，SUB=F；后续10/30仅PGS，持续时长未定。详情未就绪的13伪90秒窗、Pad重复xmark/HTTP404工具失败、文件入口两机t3仍预览/准备全部留证；文件10/30实际电影与普通退出已核，非首帧/全SUB/性能通过。
- 原JF PGS7通过正常UI恢复，最终13JF5815.383/PadJF5877.583均1/7开启；S03文件原轨保留，24/15非书签偏好一致/各2书签自然更新/无新崩溃/实际普通空env首页/播放器关闭/idle10动画2。未写偏好、清登录或改网络。
- 下一步先修13PiP返回停播和Pad暂停双层、重放历史原句/真实新HLS，再HDR保真与S01四入口/代表族、18实际界面、完整帧Lenna/DS One。全SUB/AUD/HDR/性能/蜂窝/MTP/L2/L3及全部旧PX/UX/CB/Main/475/119/HLS等未验总账保留。
详见[本轮交接](../handoffs/2026-10/2026-10-12-SUBTITLE-PIP-OWNERSHIP.md)。

## 2026-10-12 iPhone18 最新包无线覆盖
- 更新时间：2026-10-12T19:55:10.749599+08:00。用户确认18回到局域网Wi-Fi并授权更新；现场DNS-SD与既有配对TCP核对设备名称/型号/系统/UDID，iPhone19,7/iOS27.0/无线且USB缺席，端点与原始身份仅私有。未改网络、VPN、配对、remoted或DDI；13/Pad本轮未操作。
- 源码未改，最新69395e7c普通Debug（主7d9c741f/Debug593b5bfb/KSdf76e71d）173输入/三SHA/29逐库与深度签名/profile目标及有效期/IPA核验，源码无新输入，无需重建。326测试/2跳过/0失败和15预检引用此前17:55同源结果，本轮未重跑。
- 19:51:38.133实际InstallComplete/安装lookup成功，保留容器覆盖；安装前后及启动检查后25偏好（含全部书签）逐值一致，登录未清。直接无线RSD/DVT正常空env/args launch返回PID并截图；实际原图已看，前台仍其他App，因此最新Nastart正常UI未核，不记启动/播放回归PASS。已停止额外前台操作。
- 下一步18方便时补新包实际界面；调试主线继续USB13/Pad白黄重复字幕与HDR PiP。HDR功能尚未修，全SUB/AUD/HDR/性能/蜂窝/竞品/MTP及全部旧PX/UX/CB/Main/475/119/HLS/L2/L3未验项保留。
详见[本轮交接](../handoffs/2026-10/2026-10-12-IPHONE18-LATEST-WIRELESS.md)。

## 2026-10-12 画中画合成原因与全屏重复字幕
- 更新时间：2026-10-12T19:44:24.700665+08:00。只操作 USB13/Pad，18 用户带走/未连接安装测试。新源69395e7c普通Debug主7d9c741f/Debug593b5bfb/KSdf76e71d；本轮只增加一文件的PiP拒绝原因、当帧transfer/像素格式/尺寸/CV分配诊断，HDR保护和SDR渲染策略保留，其他dirty及网络/系统/配对保持。实际326测试/2跳过/0失败、15预检；173输入/29签名/IPA/链接/最终三SHA核验。
- 17:56:54/17:57:05 两机保留数据覆盖最新包，25/16偏好一致、空env/args实际首页已核；每设备/窗口现场USB名称/型号/系统/UDID与当前源码安装身份重核，原始身份仅私有。Pad S01 SDR实际浮窗中文字幕，122fresh帧中46outputCreated/status0，BT.709/1280×688；同WDA会话实际系统恢复按钮→同PID全屏→普通退出补齐。
- 13 S03文件HDR嵌入字幕8fresh帧中2有文本，明确hdrPQPreserved、分配未尝试、4K PQ；HDR字幕仍未修。外置ASS两机采样共22fresh均noCue（13=4、Pad首7/续11），不得用嵌入样本替代外置定因。13JF恢复15秒实图同一句白/黄双层重复，SUB=F，根因/修复待做；系统弹窗与工具失败保留，无账号写入项目。
- 原PGS7经正常UI恢复；Pad误选从头和首轮约15.2秒两机短重叠留作TOOL，非单路/MTP/性能通过。Pad用原生滑杆近似定位+自然播放/实际关闭恢复至5650.009（此前新保存5476.244），未写偏好；13JF5984.26，均1/7开启。最终24/15非书签偏好一致/各2书签更新/原轨全保留/无新崩溃/实际普通首页/播放器关闭/idle10动画2。
- 下一步优先同cue白黄重复层修复和HDR外置PiP有cue补证，再HDR保真方案、手动失败回滚/13真实AV、代表族及完整帧Lenna/DS One。非全SUB/音画/HDR/性能/蜂窝/MTP/L2/L3；全部旧PX/UX/CB/Main/475/119/HLS等未验总账保留。
详见[本轮交接](../handoffs/2026-10/2026-10-12-PIP-COMPOSITION-REASON.md)。

## 2026-10-12 冷续播字幕内容补证与画中画缺口
- 更新时间：2026-10-12T17:49:29.746915+08:00。只操作USB13/Pad，18未连接/安装/测试；本轮iOS源码未改，继续59070481普通Debug（主63821b63/Debug2f5eee64/KSdf76e71d），173输入/三SHA/29签名/IPA/链接及最终源码核验。326测试/2跳过/0失败和15预检是此前同源结果，本轮未重跑。17:12两机保留数据覆盖最新包，25/16偏好及空环境实际首页已核，其他dirty与网络/系统/配对保留。
- 13普通自然90秒保持KS/localRangeProxy，0freshAV遥测/0候选提交/0预热失败；3/10/30/60双语画面、90无cue，ASS正常退出4724.87存1/5开启。Pad本次也是KS，原生Off后无AV提交；手动PGS检查因AV前置守卫停止，未提交PGS候选、不算准备失败负例。原失败/超时全部保留。
- Pad外置ASS原生45秒正常退出4831.382存1/5开启；普通冷启动/未重选字幕的45秒续播10/45实际白双语、菜单ASS5和fresh1288cue已核，补齐冷续播内容。实际播放器PiP按钮→桌面3/10/30浮窗电影；42fresh字幕帧事件中17条有文本但全部composited=false，PiP字幕未通过。S03 HDR元数据与代码PQ/HLG保护是候选原因，尚未读取当帧transfer/分配结果，不能定因或删除HDR保护。返回App同PID仍浮窗；临时SpringBoard会话后浮窗消失/控件查找StopIteration，恢复全屏及该窗普通退出未验，不冒充通过。
- 两机原PGS7经正常详情选择/30秒播放/普通退出恢复；最终13JF4749.478、PadJF5114.004734646均1/7开启，S03文件未动；24/15非书签偏好一致/各1书签更新/无新崩溃/实际无挡空环境首页/播放器关闭/idle10动画2。两机恢复PGS3秒spinner留证，10/30有电影但无自然PGS cue；NAS/JF在线，其他服务警告保留。
- 下一步先补PiP合成拒绝原因/当帧transfer与分配结果、SDR字幕对照和实际系统恢复按钮验证；手动准备失败回滚/13真实AV仍未触发，再代表族与完整帧Lenna/DS One。非全SUB/音画/HDR/性能/蜂窝/MTP/L2/L3；全部旧PX/UX/CB/Main/475/119/HLS等未验总账保留。
详见[本轮交接](../handoffs/2026-10/2026-10-12-COLD-EXTERNAL-PIP-GAP.md)。

## 2026-10-12 自动候选结束后的字幕选择一致性修复
- 更新时间：2026-10-12T17:03:26.581406+08:00。只操作USB13/Pad，18用户带走/未连接安装测试。新源59070481普通Debug主63821b63/Debug2f5eee64/KSdf76e71d，173输入/三SHA/29签名/IPA/链接及最终源码核验；实际326测试/2跳过/0失败、15预检，16:32两机保留数据覆盖25/16偏好一致/空env实际首页已核，其他dirty与网络系统配对保留。
- 基线8322 Phone自动AV准备早于Off11.377秒，成功原生Off使候选失效，旧request错误重开ASS菜单/覆盖但退出存off；三文件改为已提交renderer状态同步。最新13Off菜单/实际无字幕/退出4496.868与冷续播4520.13保持1/nil/off，重新ASS5/恢复原PGS7正常保存。该自动失效不算手动准备失败回滚负例。
- Pad最新真实AV关闭提交约20.040秒/startsPaused，原生外置ASS菜单/3、10秒白双语/1288cue/41freshAV遥测/45秒正常退出4577.965195893存1/5开启已核；冷续播实际KS保存4607.833/1/5，无自然cue不算冷内容通过。两机S03JF/文件共7短时窗口+2专窗/正常退出，原轨恢复；13 WDA中断t15窗口保留不完整，恢复后普通退出4879.701再补采，无新增崩溃。准备/spinner、旧工具等待AV/HTTP404/错断言及系统登录弹窗均保留分类；最终24/15非书签偏好一致/各2书签更新/无新崩溃/实际无挡普通首页/关闭/idle10动画2。
- 下一步手动失败回滚、13真实AV、Pad冷续播cue/PiP与代表族，再完整帧和Lenna/DS One。非全SUB/音画/HDR/性能/蜂窝/MTP/L2/L3；所有旧PX/UX/CB/Main/475/119/供流等未验总账保留。
详见[本轮交接](../handoffs/2026-10/2026-10-12-COMMITTED-SOURCE-SELECTION.md)。

## 2026-10-12 外置字幕冷启动与续播身份修复
- 更新时间：2026-10-12T11:52:43.972971+08:00。只操作USB13/Pad，18用户带走/未连接安装测试。新源832259d1普通Debug主7b48bcc4/Debugf8f2b30e/KSa8b150bb，173输入/三SHA/29签名/IPA/链接与最终源码重核；最终实际324测试/2跳过/0失败、15预检。首轮1失败未安装，补齐第二处守卫后全套通过。11:25两机保留数据新包覆盖25/16偏好一致、普通空env/args实际首页已看；其他dirty和网络/系统/配对保留。
- 旧9fe5 S03JF ASS5规范化SRT被旧嵌入关闭标记误关闭，fresh overlay为0、退出4119.071保存nil/off；修正Greenfield/共享覆盖/PiP初始化语义，唯一URL映射源ID保存，未知/歧义不猜。两机新包实际白双语、fresh1288 cues、正常退出和冷续播均保持1/5开启，原PGS7已通过正常UI恢复；仅KS基础外置通过，AV/PiP与真实失败回滚未验。
- 最新源12个串行短时窗口（S03JF选ASS/冷续播/恢复PGS、S03文件、S01四入口）/实际3/10/30及ASS45原图/普通退出齐全。13ASS10秒spinner、两机S03文件3秒准备/旋转黑屏保留；Pad两次未进播放器、13旧按钮断言、旧包取消候选/错等待KS路由/重叠流均分类留证、不冒充通过。最终24/15非书签偏好一致/各4书签更新/原轨恢复/无新增崩溃/稳定普通首页/关闭/idle10动画2。非蜂窝/全SUB/音画/动画/HDR/性能/MTP/竞品/L2/L3；全部原未验总账保留。下一步AV外置和失败回滚、代表格式，再完整帧和Lenna/DS One。
详见[本轮交接](../handoffs/2026-10/2026-10-12-EXTERNAL-SUBTITLE-STARTUP.md)。

## 2026-10-12 AV字幕菜单提交一致性修复
- 更新时间：2026-10-12T09:33:29.794015+08:00。只操作USB13/Pad，18用户带走/未连接安装测试。新源9fe56dbe普通Debug主9f952eeb/Debug1a354fb8/KSa981b6ce、173输入/三SHA/29签名/IPA/链接核验；最终实际322测试/2跳过/0失败、15预检。09:20–09:21两机保留数据新包覆盖25/16偏好一致、普通空env/args实际首页核对；其他dirty与网络/系统/配对保持。
- Pad现场575947关闭→PGS7后菜单仍off，PGS→ASS5后菜单才7，实际画面/commit/原图保留；1ed0 request.id观察器第一版真机仍失败，已撤回，失败包/截图/正常off恢复保留。ece5菜单正确但暂停off退出仍ASS5，保存失败保留。最终AV控制界面按plan.id重建，和KS相同，已验证ready候选按实际量化clock建立保存门槛，cold保护保留；9fe5真实AV暂停PGS7/ASS5/off三次commit后的菜单勾选逐一已核，ASS自然3/10/30/普通退出原4/off保存成功。真实失败准备回滚仍未验，嵌入ASS不是外置字幕。
- 13真实PGS7菜单/自然3/10/30/恢复原4/ASS5最终保存已核；退出4秒首读仍7/约38.1秒后再读5，失败断言和延迟留证，非即时保存通过；S01四入口串行30秒基础画面与正常退出齐全。最终24/15非书签偏好一致/无新增崩溃/普通稳定首页/播放关闭/idle10动画2。非蜂窝/全SUB/音画/动画/HDR/性能/MTP/L2/L3/竞品验收；全部原PX/UX/CB/Main缺口保留。下一步真实失败回滚、外置与代表字幕/13AV/S03JF，再完整帧与Lenna/DS One。详见[本轮交接](../handoffs/2026-10/2026-10-12-AV-TRACK-MENU-COMMIT.md)。

## 2026-10-12 双USB暂停换字幕候选对齐修复
- 更新时间：2026-10-12T08:23:04.833385+08:00。用户将18带去上班，本轮只操作USB13/Pad，18未连接/安装/测试、当前575947新包待更新。HEAD4de732dd、dirty源57594712；普通Debug主4bb4262b/Debugfd438ccf/KSa981b6ce、173源输入/三SHA/29签名/链接及IPA核验，本轮实际322测试/2跳过/0失败、15预检。两机07:57最新包保留数据覆盖25/16偏好一致、空env/args实际首页已看；网络/系统/配对未改。
- AV暂停候选此前在decoded后尚未ready/无储备就提前放弃；改为保持暂停并在原deadline等待，不放宽门槛。Pad暂停578.665秒PGS7 decoded5502→aligned6544ms，实际双语已看；显式AV分支648.65秒PGS5341→6985/关闭4931→6302ms、两次7.9209秒储备/startsPaused，真实cue出现→消失及普通退出off已核。退出648.652342842→最终延后保存648.6516686666666差0.674ms留证，轨道4/off一致；本轮无偏好写入。共享菜单复位到提交request已实现，真实失败准备回滚负例仍待验。
- 13纠正同名字幕误选后真实PGS7/自然3/10/30原图已看，恢复原4/ASS5后普通退出465.332；首次误中5不算PGS通过。Pad提前退出取消/冷重试KS路线误等待AV/AFC工具失败均保留并分类。S01四入口串行30秒基础画面/正常退出齐全；24/15非书签偏好一致，各3条书签自然更新/崩溃无新增，最终普通稳定首页/关闭/idle10动画2。非蜂窝/完整SUB/声音/HDR/动画/性能/竞品或L2/L3验收；全部旧PX/UX/CB/Main缺口保留。下一步真实失败回滚、外部/代表字幕及13AV/JF，再帧时间与Lenna/DS One对照。详见[本轮交接](../handoffs/2026-10/2026-10-12-USB-AV-PAUSED-ALIGNMENT.md)。

## 2026-10-12 PGS缩放修复与iPad AV字幕失败
- 更新时间：2026-10-12T07:47:41.349285+08:00。USB13/Pad优先、无线18其次。新源a4be368b正常Debug主036fea1f/Debug2b45b668/KSa981b6ce，173输入/mtime/三SHA/29签名/链接核验；本轮实际322测试/2跳过/0失败、15预检。KS位图缩放按完整播放区域，底部控制避让移入布局，其他未提交修改保留；三机最新包保留数据覆盖25/16/25偏好一致，空env实际首页已看。18用户解锁后新包首页已补，原生仍paired/tunnel unavailable、末次WDA超时，本轮未播放/网络未改。
- 本轮基线实日志确认S03轨5/6 ASS、7/8/9 PGS。13新包轨7同句暂停364.244、显隐/锁定/ASS切回PGS已看，英文行OCR宽度差由约53.2%降至0.185%；自然3/10/30图已看、UI恢复5、退出398.185，24非书签偏好一致/仅S03更新/无新崩溃/最终普通稳定首页与idle10动画2。稳态布局通过，完整动画/SUB/AUD/HDR/性能未验；本轮Wi-Fi非蜂窝。
- Pad实际准备失败保留，AV候选alignment两次失败、冷续播实际systemAVPlayer/localHLS/localRemux；无字幕暂停cue不算PGS布局。关闭字幕UI/图标与保存不一致，末次退出542.298781仍7开启；已终止App后仅回滚测试改动的S03轨道字段到4/off，保留自然位置及账号/其他偏好，精确回读和普通重启后确认。该清理不能算功能通过。15其他偏好一致/无新崩溃/最后正常首页。下一步优先Pad AV字幕候选对齐与失败提交一致性，再双USB格式/外部/动画及18播放；旧AV/HLS/475/119/蜂窝/竞品与全部未验总账保留。详见[本轮交接](../handoffs/2026-10/2026-10-12-PGS-SCALE-AND-AV-TRACK-FAILURE.md)。

## 2026-10-12 iPad安装恢复与双机字幕轨回归
- 更新时间：2026-10-12T06:05:37.537521+08:00。App源未改，仍615edbaa普通Debug主ab816cec/Debug1e4912d5/KSa981b6ce，173输入/mtime/三SHA/29库签名重核；322测试/2跳过/0失败及15预检引用02:24同源结果，本轮未重跑。现场USB13/Pad及配对无线18身份重查，05:46/48/48最新包保留数据覆盖，25/16/25偏好一致；13/Pad取消或延后现场系统弹窗后，无挡普通空env/args实际首页已看。
- Pad储存仍满、剩475MB，但图标恢复正常，本次原生覆盖成功、IX48未再出现，不证明低空间或全部根因已解。S03原4/off→正常UI轨5、12次逐步+15秒核clock到350、同cue暂停；首偏好354.907延迟，随后显隐/锁定/方向快照稳363.664，已看选取原图无遮挡，非完整动画。退出工具沿用旧字幕图标失败保留，按captions.bubble.fill恢复原off并普通退出442.469，实际播放超过名义45秒；15非书签偏好一致/仅S03更新/崩溃清单无新增，最终普通首页/空env/关闭/idle10动画2。
- 13 S03第二同名字幕实际轨7，暂停/隐藏/重现363.486与原图已核，未见遮挡；codec未核、不算bitmap全验。AFC旧连接BrokenPipe保留，每次新建读连接续采；原UI恢复轨5、3/10/30图及长句观察/退出396.809，首恢复偏好仍7延迟保留，24非书签偏好一致/仅S03更新/崩溃无新增，最终普通首页/空env/关闭/idle10动画2，本轮Wi-Fi非蜂窝。18无线新包成功但WDA中断，复用已装Runner正式RSD/XCTest恢复ready、随后Locked拒绝普通启动；最新UI/播放与原生自动隧道仍待验，网络未改。下一步USB格式/外部字幕、轨7codec及完整动画，再18解锁首页；旧AV/HLS/475/119/蜂窝/Lenna及全部未验总账保留。详见[本轮交接](../handoffs/2026-10/2026-10-12-IPAD-RECOVERY-SUBTITLE-TRACKS.md)。

## 2026-10-12 字幕控制栏显隐过渡与设备门槛
- 更新时间：2026-10-12T02:40:34.154546+08:00。13/Pad USB优先、18无线其次。新源615edbaa普通Debug主ab816cec/Debug1e4912d5/KSa981b6ce，173输入/mtime/三SHA/29库签名链接核验；本轮实际322测试/2跳过/0失败、15预检。字幕底距即时更新、隐藏延后300ms释放避让，重新显示取消旧任务；其他未提交修改保留。初始依赖缺失exit74保留，从本机恢复22个确切锁定版本checkout后构建/测试成功，未改依赖锁文件。
- 13最新包02:26保留数据覆盖25偏好一致、空env/args实际普通首页已核。S03逐次普通后退15秒定位上轮同cue，暂停362.430；隐藏/重现各7图、快速切换、锁定/解锁、横竖/恢复稳态已看且暂停位置一致，采样未见重叠。普通恢复3/10/30/45原图/退出409.662，音轨4/字幕5开启保持；24非书签偏好一致，仅S03自然更新、崩溃清单无新增，最终02:37普通首页/NAS正常/空env/关闭/idle10动画2。截图延迟数百毫秒，完整动画/声音/流畅/全SUB未验；本轮Wi-Fi非蜂窝。
- Pad现场USB/WDA ready，但基线包覆盖仍CoreDevice3002/IX48；系统储存满与“正在安装”已实看，AFC剩512MB且上传临时目录无大文件可清。615e最新包未安装/未回归，待用户释放自行选择内容并保留Nastart数据。18现场配对无线重核，02:27已安装615e新包25偏好一致；FBS Locked拒绝普通启动，最新UI/播放未验，待解锁，原生自动隧道未重测/网络保持。下一步Pad安装恢复、13长cue/bitmap/外部字幕与完整动画，再18启动；旧AV/HLS/475/119/蜂窝/Lenna及全部未验总账保留。详见[本轮交接](../handoffs/2026-10/2026-10-12-SUBTITLE-TRANSITIONS.md)。

## 2026-10-11 USB优先字幕控制栏布局
- 更新时间：2026-10-11T21:04:05.022954+08:00。按13/Pad USB优先、18无线其次。新源2946c84b普通Debug主7ec01c72/Debug17f17700/KS042a3eca，173输入/mtime/三SHA/29库签名与链接核验；本轮实际322测试/2跳过/0失败、15预检通过，两处共享字幕/控制栏布局修改，其他未提交修改保留。
- 13最新包保留数据覆盖25偏好一致、空env实际正常首页已核。S03同一句双语字幕旧包遮挡对照→新包暂停285.545在t0/3/10稳定、普通恢复45秒退出332.734；稳定字幕位于控制栏上方，3/10/30/45自然原图已看。短时重新显示过渡图仍重叠留证，稳定隐藏/重现补查通过，动画/完整SUB/AUD/性能未验收。最终364.873/轨道4与5开启、24非书签偏好一致/崩溃清单无新增、普通首页/空env/关闭/idle10动画2；本轮仍Wi-Fi，非蜂窝。
- Pad现场USB/正式有效WDA已恢复，但最新App覆盖被系统协调安装占用（CoreDevice3002/IX48；替代InstallationProxy90s超时保留）；**未完成当前包安装/启动/回归**，等待设备图标状态，不卸载/清数据。18重新无线发现和身份重核、当前新包安装成功25偏好一致；启动明确Locked，等待解锁，**最新包界面/播放未验**。原生自动隧道仍待查，现有网络不改。下一步13显隐动画/方向与外部字幕、Pad安装恢复优先，再18启动；旧AV/HLS/475/119/蜂窝/Lenna与全部未验总账保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-USB-SUBTITLE-CONTROLS.md)。


## 2026-10-11 iPhone18开启字幕/非默认音轨冷续播
- 更新时间：2026-10-11T20:25:16.390564+08:00。App源未改，c6922e99普通Debug主c86667ef/Debugee937c56/KS9764ba65，173输入/mtime/三SHA/签名重核；322测试/2跳过/0失败与15预检引用此前同源，本轮未重跑。18现场Wi-Fi iPhone19,7/iOS27.0/同UDID/USB缺席，最新包保留数据覆盖25偏好一致、state1/空环境实际首页已核，13/Pad无本轮回归。
- 起始WDA拒绝连接，复用有效签名Runner重建正式无线XCTest未重装；恢复期2份WDA初始化SIGABRT单独留证、未归媒体。S03实际国语2/简英双字5选择→正常保存1728.254→冷续播合格时钟1728.382(+.128)→45秒/原退出1773.545，2/5开启保持；3/10/30/45原图已看，控制显示时英文与按钮重叠、隐藏时自然cue可读，完整SUB/AUD/流畅/HDR未验收。
- 最终普通首页/关闭/空env/idle10动画2，24非书签偏好一致/仅S03自然更新；播放前后无新崩溃，整轮恢复期2WDA失败保留。原生仍tunnel unavailable/DDI=false、实际进程查询4016，直接WDA ready、网络未改。下一步同cue控制/字幕布局、声音/旧AV兼容、HLS完整候选/分片/read/callback、原生自动通道；旧475/119/蜂窝/代表族/竞品与全未验矩阵保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-IPHONE18-ENABLED-TRACKS.md)。



## 2026-10-11 iPhone18有效轨道冷续播与旧AV身份
- 更新时间：2026-10-11T19:53:36.883013+08:00。App源未改，c6922e99普通Debug主c86667ef/Debugee937c56/KS9764ba65，173输入/mtime/三SHA/签名重核；322测试/2跳过/0失败与15预检引用此前同源，本轮未重跑。18实时Wi-Fi iPhone19,7/iOS27.0/同UDID/USB缺席，最新包保留数据覆盖25偏好全一致、新UI session/有序state1/空环境实际首页已核，WDA复用未重装，13/Pad无本轮回归。
- S03有效4/关闭普通冷续播1597.289→合格时钟1597.353（+.064）→原退出保存1627.262，轨道保持；t2黑/spinner旋转、t3/5/10/30电影原图保留并实看，无流畅/声音/HDR验收。旧0/0条目更新于9月30日18:17，与同plan/trace/route的AVPlayer localRemux结束及历史组选项offset保存代码相符，原始流映射仍缺；旧差异样本不改PASS。
- 最终普通首页/关闭/空env/idle10动画2，24非书签偏好一致/仅S03书签自然更新、崩溃清单无新增。原生paired/tunnel unavailable/DDI=false且实际进程查询4016失败，直接WDA仍ready、网络未改。下一步有效开启字幕/非默认轨冷回归及旧身份兼容、HLS完整deadline/分片/read/callback、原生自动通道；旧475/119/蜂窝/代表族/竞品与全部未验矩阵保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-IPHONE18-COLD-TRACK.md)。


## 2026-10-11 iPhone18无线S01/S03播放与轨道差异
- 更新时间：2026-10-11T19:38:28.590016+08:00。App源未改，c6922e99普通Debug主c86667ef/Debugee937c56/KS9764ba65，173输入/三哈希/签名重核；322测试/2跳过/0失败与15预检为此前同源结果，本轮未重跑。18现场iPhone19,7/iOS27.0/同UDID/Wi-Fi TCP/USB缺席，19:18最新包保留数据覆盖、25偏好一致、普通空环境实际首页已核；13/Pad无本轮最新包回归。
- 旧XCTest后续ConnectionTerminated已留证，复用有效WDA重建正式无线会话，未重装WDA/未改网络。S01 1091.988→1123.572、S03 1506.876→1597.289实际30/90秒观察与原UI退出完成；前者轨道保持，后者旧0/0开启→4/关闭，实际字幕清单5-9，旧身份来源未确认、恢复未PASS。出画仍spinner/旋转/暗电影和工具失败保留；S03未触发自动HLS候选，不能算完整deadline或性能/连续流畅验收。
- 最终普通首页/关闭/空环境/idle10动画2、24非书签偏好一致/仅两书签自然更新已核，崩溃清单无新增；19:34WDA ready而原生tunnel unavailable/DDI=false仍开放。下一步有效4/off冷续播及旧身份、HLS候选完整deadline/分片/read/callback；旧475/119/蜂窝/代表族/竞品及全部未验矩阵保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-IPHONE18-WIRELESS-PLAYBACK.md)。


## 2026-10-11 iPhone18无线WDA恢复与实际首页验证
- 更新时间：2026-10-11T19:16:12.865586+08:00。App源未改，c6922e99普通Debug主c86667ef/Debugee937c56/KS9764ba65，173输入/哈希/签名重核；322测试/2跳过/0失败、15预检为此前同源结果，本轮未重跑。18重新发现/现场iPhone19,7/iOS27.0/同UDID/USB缺席，最新Nastart保留数据覆盖和最终25偏好一致，13/Pad无本轮回归。
- 使用有效至北京时间10月18日06:28的已有续签固定WDA，13签名对象验证后无线覆盖；实际CoreDeviceProxy/RSD/testmanagerd/XCTest授权与plan执行、status ready和UI请求成功。用户报告旧WDA过期，但旧profile日期未提取，lookup true不当成充分证明。19:12 state1后普通空env/args实际Nastart首页/NAS正常/播放器关闭已看，其他服务未知，idle10动画2恢复；18界面基础验证已完成，非播放/性能验收。
- WDA就绪后原生Xcode仍paired/developerMode enabled/tunnel unavailable/DDI=false；直接DVT启动返回PID但系统截图45秒超时失败保留。网络/配对/remoted/DDI未改，活跃18 XCTest仅用于后续UI，不自动播放。下一步18无线播放与原生隧道独立排查、HLS完整deadline/分片/read/callback；旧475/119/蜂窝/代表族/竞品和全部未验矩阵保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-IPHONE18-WDA-RECOVERY.md)。


## 2026-10-11 无线服务名称更新与S03长窗口接续
- 更新时间：2026-10-11T19:03:22.361212+08:00。App源未改，仍c6922e99普通Debug主c86667ef/Debugee937c56/KS9764ba65，173输入/签名重核；322测试/2跳过/0失败、15预检为此前同源结果，本轮未重跑。Pad保留数据覆盖/16偏好一致/实际空环境启动；13现场USB只读，无本轮最新包回归。
- 18用户当前Wi-Fi地址直连同UDID/iPhone19,7/iOS27.0成功，18:55最新包无线保留数据安装完成/25偏好一致，UI仍延后；无线CoreDeviceProxy/RSD/DVT实际会话成功。旧私有Bonjour服务名与设备当前名不同，更新为现场读取名称后DNS-SD发现及配对身份核对成功；网络/配对未改。原生Xcode tunnel unavailable/DDI=false仍开放，不等同直接开发服务不可用。
- Pad S03起点77.787音轨4/字幕关闭，普通90秒/原退出保存164.667；t6实际电影仍spinner、t7/t30/t60/t90电影无spinner，未触发自动HLS候选，不计40秒deadline结果或连续播放/性能PASS。历史S03补查：media清单1.386MB读完/194347字节重写/1880分片，29.584秒分片请求，33.007秒取消后36.529秒才有500，因果未定；798仅master上游字节。Pad最终实际正常首页/关闭/空环境/active0/idle10动画2已核。下一步候选完整deadline/分片生命周期和read/callback/容量，18UI/原生隧道/旧475/119/蜂窝/代表族/竞品及全部未验矩阵保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-WIRELESS-HLS-FOLLOWUP.md)。


## 2026-10-11 固定续播点三次重复与S03候选边界
- 更新时间：2026-10-11T18:46:31.125694+08:00。本轮App源未改，仍c6922e99/主c86667ef/Debugee937c56/KS9764ba65普通Debug；173输入/三哈希/deep签名重核。322测试/2跳过/0失败、15预检为上轮最终同源结果，本轮未重跑。Pad现场USB身份与保留数据覆盖/16偏好一致/空环境实际首页已核；13仅现场只读身份，无本轮回归；18发现/直连未核实，c692未上传安装、UI延后、网络未改。
- Pad S01文件1791与JF1631同轨同点各三次串行。文件18过滤稳定/callback→有效帧30～35ms，但首调用333～1404ms；JF202过滤稳定，第三轮首调用2539ms、单次demux1388ms。文件归一化slider漂移校准轮保留并排除组，窗口外正常UI重置同点。JF23提交全部匹配HTTP接受，无提前0started；书签轨道保持。稀疏实际画面/黑场/出画仍spinner保留，不作性能排名。
- S03实际4K预览/10bit/DV profile7声明补测：14过滤、首调用2889ms/容量差1197ms，t30电影；11秒自动请求调整、18.8秒创建AV/HLS候选，t30仍无出帧/无loaded ranges/未commit，33秒普通退出取消准备，不能算HLS或L2通过。7有限媒体206与798字节清单200分列，取消错误保留。Pad最终正常首页/关闭/空环境/active0/idle10动画2已核，其他卡片未知。下一步细分read/异步callback/队列与HLS候选准备；18/旧475/119/蜂窝/代表族/帧/声音/竞品和全部未验PX/UX/CB/L2/L3/Main保留，无性能PASS。详见[本轮交接](../handoffs/2026-10/2026-10-11-STARTUP-FIXED-POINT.md)。


## 2026-10-11 首个有效目标帧之前的工作分段
- 更新时间：2026-10-11T17:53:54.326308+08:00。5输入只补读包/路由/调用/回调与音视频容量，原策略保持。最终322测试/2跳过/0失败、15预检、普通Debug/173输入/29库签名链接通过；源c6922e99，主c86667ef/Debugee937c56/KS9764ba65。
- 13/Pad现场USB身份/保留数据覆盖/25与16偏好一致，空环境实际首页与S01四入口串行采集/原退出已核。Pad JF首callback→有效帧970.792ms/207过滤、首key距目标6.924秒；Pad文件callback→有效帧29.998ms/17过滤，但首调用前1510.808ms/单次demux最长978.255ms，且output→isPlayable容量间隔400.677ms。两个JF14提交全部匹配HTTP接受、无提前0started；书签/轨道保持。 完成调用墙钟可能重叠/在途未计，不归纯网络或CPU，不作不同点性能排名。
- 18发现/旧地址直连仍未核实，本轮新包未上传/安装、UI延后、网络未改。双机最终正常首页/空环境/播放关闭/active0/idle10动画2已核。下一步同轨同点重复与另一格式族后决定策略；18/AV/HLS/旧475/119/蜂窝/完整帧/声音/竞品和全部未验PX/UX/CB/L2/L3/Main保留，无性能PASS。详见[本轮交接](../handoffs/2026-10/2026-10-11-STARTUP-WORK-BREAKDOWN.md)。

## 2026-10-11 有效视频帧与输出边界诊断
- 更新时间：2026-10-11T17:24:56.939851+08:00。新增generation隔离/一次性有效帧、过滤数量、实际输出API边界诊断，保留原播放策略；7输入变化，其他dirty保留。最终本轮320测试/2跳过/0失败、15预检、普通Debug构建/173输入/29库签名链接通过；源aba9b086，主64fd756e/Debug072820e1/KS cb8eb769。
- 13/Pad现场USB身份重核、保留数据新包覆盖，25/16偏好一致、实际空环境首页与S01四入口串行30秒采集/原退出完成。Pad JF/文件decode标记→有效帧486.203/516.671ms、过滤109/152帧，有效帧→API38.383/5.562ms；起点/缓存不同不作设备性能比较。两JF14提交匹配HTTP接受、无提前0started，书签/轨道保持，早黑/旋转/13JF详情未出画保留。
- 18两次发现及旧已验证地址直连未通过，本轮aba9包未上传/未安装，UI仍延后；现有网络未改。13/Pad最终正常首页/播放关闭/空环境/active0/idle10动画2已核。API≠实际展示，无性能/竞品PASS。下一步定位有效帧前包交付/定位/解码及音视频容量；代表族/AV/HLS/18/旧475/119/蜂窝/完整帧/Lenna与全部未验PX/UX/CB/L2/L3/Main保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-VIDEO-OUTPUT-STAGES.md)。

## 2026-10-11 缓冲加载反馈修复与三机更新
- 更新时间：2026-10-11T16:14:16.437256+08:00。ready不再提前隐藏真实transport等待，transport变化独立发布且相同值去重，共享chrome明确显示资格；仅3源码输入变化，其他dirty保留。基线3新测试全失败/6断言，修后本轮完整318测试/2跳过/0失败、15预检及普通Debug构建通过；源27adfe36，主2bbb9f4a/Debug fae73a0f/KS8e6b，173输入/29库签名/链接通过。
- 三机保留数据覆盖最新包、13/Pad/18偏好25/16/25一致；13/Pad普通空环境实际首页核验，18实时配对Wi-Fi识别并无线安装成功，UI仍按用户延后、网络配置未改。
- S01双机×文件/JF四单元串行：黑场缓冲有加载提示、出画后消失，t30电影/原退出实际查看；JF13提交匹配HTTP接受，无提前0 started，书签/轨道保持。13文件另补实际暂停17:02保持/恢复17:05无多余spinner，旧按钮名工具失败与超出30秒的播放保留，不混入首帧测量。
- 双机最终最新普通首页/播放器关闭/空环境/active0/idle10动画2已核。反馈定向完成，首帧真实等待/AV/HLS/暂停预热与后续重缓冲、代表集/18正常UI及自动无线通道/旧475差异/119/真实弱蜂窝/完整帧/Lenna与全部未验PX/UX/CB/L2/L3/Main继续开放，无性能/竞品PASS。详见[本轮交接](../handoffs/2026-10/2026-10-11-LOADING-FEEDBACK.md)。


## 2026-10-11 iPad启动黑场取证与18无线更新
- 更新时间：2026-10-11T15:47:58.337100+08:00。App源未改，仍a7f69445普通4b4f086c/6a1abcf3/KS8e6b，173输入/签名/哈希重核；315/2跳过/0失败及15预检为此前同源结果，本轮未重跑。Pad保留数据覆盖最新包/16偏好一致/实际空环境启动，13仅只读现场USB身份与WDA，无新包回归。
- 18实时Wi-Fi配对身份/四只读服务恢复，15:35最新a7包无线保留数据安装成功、25偏好一致，UI仍延后。15:45直接无线CoreDeviceProxy/RSD同身份及DVT实际会话成功；原生详情仍tunnel unavailable/DDI=false可能缓存，自动通道差异和间歇断开未解释，网络/配对未改。
- Pad S01文件/JF各普通终止/启动后新详情→实际30秒采集/原退出，密集截图边界与六条同源时序留证。文件bufferFinished2.344/合格时钟2.519，JF3.735/3.965；JF t3仍黑、t4电影，文件早黑/后电影；各t30电影及退出实看。JF6提交全部匹配HTTP接受、无提前0started；书签/轨道保持，不判连续30秒、性能或竞品。
- 加载反馈缺口定位：ready把isBuffering清除并hasStarted=true，忽略仍在buffering的状态，本轮尚未修。decodeVideoTime/first_frame只证解码调用/合格时钟，非实际可见首帧；后续先受控状态反例再改反馈，补目标帧/展示/容量后优化等待。Pad最终首页/播放器关闭/空环境/active0/idle10动画2；18UI/原生自动通道及全部既有未验项保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-STARTUP-BLACK-WIRELESS.md)。


## 2026-10-11 续播确认前0秒报告修复
- 更新时间：2026-10-11T15:19:17.683414+08:00。初始续播确认/pending seek/ready统一保护服务器started和progressed，使用当前引擎实际绝对时钟；从头/确认回退0仍有效，早退未开始不报告且资源释放一次。七新测试基线7失败/16断言，修后完整315/2跳过/0失败、15预检；源a7f69445，普通主4b4f086c/Debug6a1abcf3/KS8e6b，173输入/29库签名/链接通过，其他dirty保留。
- 13/Pad USB现场身份重读、保留数据新包覆盖、25/16偏好一致、实际空环境启动。JF各普通退出→不同PID冷详情/实际续播完成，四正续播均无提前0秒started，25报告匹配HTTP接受；冷首帧对退出上报13+.074/Pad+.139秒。Pad两t3黑场保留，不判流畅；同书签/轨道/冷稳定。
- S01文件双机普通退出/冷续播实看完成，冷首帧对本地保存13+.150/Pad+0.150秒，四次t30电影及原退出核实，Pad冷轮t3黑场保留，不判连续30秒或流畅。四入口仅本源定向；真实AV/HLS/S03/S19/MTP/L2/L3继续待验，不混入旧SIGKILL或承诺2秒耐久。
- 18实时无线身份可识别，但两容器与独立安装lookup服务断开，最新a7包未上传/未安装；已请亮屏解锁后重查，UI仍由用户延后。15:00原生tunnel unavailable/DDI=false，原因未知，现有网络保持。双机最终正常首页/播放器关闭/空环境/active0/idle10动画2；旧+475秒、119/真实蜂窝/帧/Lenna与其余PX/UX/CB/Main全部保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-CONFIRMED-SERVER-START.md)。


## 2026-10-11 Jellyfin续播请求与HTTP回执取证
- 更新时间：2026-10-11T14:35:59.850646+08:00。新增详情/请求位置与trace/report关联提交和HTTP成功诊断，列表刷新失败单独归类；未改播放策略/队列/节流/2秒保存。本轮实际308测试/2跳过/0失败、15预检，173输入/29库签名/链接通过，新源9cb0da7d普通e5a5b304/f580ea7d/KS8e6b。
- 三机保留数据更新、25/16/25偏好一致；13/Pad新包普通空环境实际启动。18当前DNS-SD实时配对Wi-Fi身份/无线安装成功，界面由用户延后；14:27原生tunnel unavailable/DDI=false仍开放，现有网络未改。
- 双机按设备顺序各“普通30秒退出→不同PID冷启动→新详情→实际30秒冷续播/原退出”完成。28提交均匹配HTTP成功回执，新详情=此前stop位置：13 1269.065→首帧1269.214（+.149），Pad1327.291→1327.419（+.128）；同书签/轨道/冷稳定。Pad两t3黑场保留，不判流畅。HTTP成功不证服务器耐久，旧+475.051仍未解释。
- 四次正续播均先出现0秒started的HTTP接受，再补正位置，已定位最早时钟回调tracker资格缺口，下一步受控初始seek/失败/快速退出/从头播放负例再修；本轮仅补诊断、未修该行为。13系统账号弹窗原图及工具失败保留，选择“以后”后实际首页重核；最终双机NAS/DSM/JF在线、播放器关闭/空环境/active0/idle10动画2。18UI/原生无线、AV/不同相位、119/真实蜂窝/完整帧/Lenna与全PX/UX/CB/L2/L3/Main继续开放；无全局性能/竞品PASS。详见[本轮交接](../handoffs/2026-10/2026-10-11-JELLYFIN-ACK-ORIGIN.md)。


## 2026-10-11 长间隔取证与同源文件SIGKILL
- 更新时间：2026-10-11T12:29:27.068269+08:00。未改App源，仍22c667aa普通0ed1/d2aa/KS8e6b，173输入/签名/哈希及有效profile重核；308测试/2跳过/0失败、15预检为上轮同源结果，本轮未重跑。13/Pad USB现场身份重读、保留数据覆盖同一最新包，25/16偏好全一致、实际普通空环境启动。
- 上轮Pad长间隔新增15诊断、0播放时钟/首帧、本地书签0变化，668.133秒未变；独立first_frame确认实际1143.184，+475.051差异保留。服务器ACK/更新来源/外部客户端与请求快照未取得，不指认根因或宣称修复。
- 当前源双机S01文件KS播放中SIGKILL→不同PID普通冷启动→同一书签实际30秒续播/原UI退出完成，具体值见表；非自发crash/jetsam或最大2秒耐久保证。最终首页/播放器关闭/空环境/active0/idle10动画2已核。
- 18只读DNS-SD实时身份/配对/直接Wi-Fi成功、USB缺席；12:21原生tunnel unavailable/DDI=false仍待查；本轮无18安装/启动/UI，用户延后界面与现有网络要求不变。接续JF差异/ACK、AV/其他相位、119、真实弱蜂窝/完整帧/Lenna与全PX/UX/CB/L2/L3/Main；无性能/竞品PASS。详见[本轮交接](../handoffs/2026-10/2026-10-11-COLD-GAP-FILE-SIGKILL.md)。


## 2026-10-11 Jellyfin暂停/PiP报告与冷续播
- 更新时间：2026-10-11T12:02:10.826003+08:00。新源22c667aa，普通Debug主0ed1b8ea/Debug d2aafd6c，173输入/29库/签名/链接通过；本轮实际308测试/2跳过/0失败及15预检。暂停/非活动/后台/PiP/强制保存向当前活动tracker提交已确认精确位置，周期本地2秒保持，不混淆本地保存和服务器权威续播。
- 三机保留数据更新，13/Pad/18偏好25/16/25一致；18直接Wi-Fi安装最新源成功，用户稍后验界面，新包不计正常启动/回归；原生tunnel unavailable/DDI=false根因开放，网络配置不变。双机最新空环境首页/原生active0/idle10动画2/播放器关闭。
- 13/Pad新源Jellyfin中段暂停与自动PiP→有序XCTest终止→冷启动→实际30秒续播/原UI退出四条链顺序完成，结果见本轮表，偏好保持；旧13中段2.133秒回退与Pad早段归零失败、新源Pad长间隔+475.051秒差异独立保留，阈值/其他客户端/服务器变化不作已定根因。取最大clock的后退seek误判已保留并按最后事件更正。
- 接续：18界面延后；原生无线、同源AV/JF阈值/ACK/其他终止相位、119/真实弱蜂窝旧ordinal0/完整帧/Lenna与全PX/UX/CB/L2/L3/Main开放，无性能/竞品或硬2秒耐久PASS。详见[本轮交接](../handoffs/2026-10/2026-10-11-JELLYFIN-BOUNDARY-REPORTING.md)。


## 2026-10-11 异常终止checkpoint与18无线发现
- 更新时间：2026-10-11T07:45:28.864093+08:00。新源6bbe470c，普通Debug主5b3cb2ce/Debug41f8c0ef，173输入/29库/签名/链接通过；本轮重跑306测试/2跳过/0失败、15预检，无线发现3工具测试通过。旧包13冷书签621.033/最后633.833，实际首帧621.182确认至少12.8秒回退，定时保存15→2秒，保留强制边界及启动保护。
- 三机新包保留数据覆盖，13/Pad/18偏好25/16/25一致；13/Pad最新普通空环境正常启动。新包S01文件KS各一SIGKILL冷保存680.148/743.333→实际冷首帧680.244/743.408，真实30秒和普通退出已核，未复现旧13秒回退；无硬性2秒耐久或性能保证，JF/AV及新包暂停/PiP继续待验。双机最终正常首页/NAS DSM JF在线、其他警告保留、播放关闭/空环境/active0/idle10动画2。
- 18先USB更新，用户设备端信任开发者并拔线后，Wi-Fi实时身份/既有配对、RSD容器、DVT重新正常启动和真实首页已核。系统DNS-SD能找到目标，旧Python浏览漏目标及Address描述文字问题已定位，新增只读发现与实时身份工具并拔线实测通过。原生Device Hub/CoreDevice tunnel unavailable/DDI=false仍待查，WDA/LLDB/性能未验；按用户要求保持Tailscale/Shadowrocket配置，VPN根因未知。
- 接续：新工具先核18当前端点及最新包，继续原生连接定位、新源JF/AV/暂停/PiP/不同终止相位、119/真实弱蜂窝/完整帧与Lenna及全部PX/UX/CB/L2/L3/Main；无全局性能/竞品PASS，未提交推送。详见[本轮交接](../handoffs/2026-10/2026-10-11-CHECKPOINT-WIRELESS-DISCOVERY.md)。


## 2026-10-11 有效签名续签与iPad暂停/PiP冷续播
- 更新时间：2026-10-11T07:01:51.277945+08:00。本轮未改App源，仍a56c92d3/173输入；normal Debug增量续签主309d3e69/Debug acb8c819、29库签名/链接通过，App有效至10月18日06:23:40。306测试/2跳过/0失败及15预检引用同源此前执行，本轮未重跑。
- 13/iPad USB现场身份、保留数据覆盖续签包与正常空环境启动已核，25/16偏好一致；固定WDA续签到10月18日06:28:19并逐台安装、正式XCTest/新session恢复，持久fixture更新/旧副本保留。
- iPad暂停保存623.451=最后时钟，冷首帧623.579；自动PiP稳定保存654.576=最后时钟，冷首帧654.715；补PiP保存716.229对最后716.880差0.651秒（此点未再重放）。全部普通Wi-Fi功能边界，实际系统PiP/电影/普通退出已核，无性能PASS。
- 即时磁盘638.224对649.840的-11.616秒初判及错误预期首帧断言保留；后续新播放前稳定冷偏好和同plan回调证明原断言用了旧磁盘文件，未修改App或注入保存。收敛时延/异常终止仍待验。控件名称、Home单键及横屏导航中断、t3黑场不丢弃，工具路径已修正。
- 18本轮目标无线未发现/未确认身份，旧地址超时，**续签包未安装**；已请用户提供当前Wi-Fi IP，等待身份核对后直接无线安装，USB不是前提。双机最终正常首页/NAS DSM JF在线、其他警告保留、播放关闭/空环境/active0/idle10动画2。119根因/弱蜂窝/帧/Lenna与全部未验账目保留。详见[本轮交接](../handoffs/2026-10/2026-10-11-SIGNATURE-RENEWAL-IPAD-REGRESSION.md)。

## 2026-10-11 后台保存修复、三机最新包与18无线启动
- 更新时间：2026-10-11T01:20:12.188787+08:00。最终 normal Debug v3 主程序 `c9435d29e16ec25bb35e10c1461349433dc1c11835c2efbf331d3553fb0b5710`、差异 `a56c92d3fd10dae04b2a5c50e8e4f09c4fdc7587441b8dbae01726b968b3743c`；306测试/2跳过/0失败，15预检，173源输入与29库签名核验通过。13/iPad USB、18无线逐台保留数据覆盖安装并实看启动成功；完整身份留私有证据。
- 修复自动PiP未绑定delegate及保留页面遗漏暂停/后台保存：13最新包暂停保存误差0秒，自动PiP约0.555秒；两次冷续播首帧与保存点相差约0.096/0.064秒，实际30秒电影与普通退出已查看。旧失败9.686/12.416/12.587秒独立保留。
- 18已有配对的直接无线安装、userspace RSD/DVT启动/截图已实证；最终NAS在线。原生devicectl仍tunnel unavailable/DDI=false；无线WDA/LLDB/性能尚未完成。
- iPad最新包已安装启动，后台回归未完成：读证据中断后正常关闭，再浏览返回FileStation API119，重试/刷新仍失败，正常重连要求NAS 2FA。已保留iPad连接窗口，等待用户设备端填写，不清除凭据。下一步先完成此项再补iPad暂停/PiP/冷续播。
- 13/iPad自动化等待已恢复10/2，正常环境、性能条件无active；本轮Wi-Fi书签检查无帧性能/蜂窝/竞品PASS。App签名将在今日06:03:15中国时间到期，后续必须重核/续签。详见[本轮交接](../handoffs/2026-10/2026-10-11-LIFECYCLE-RESUME-WIRELESS.md)。

## 2026-10-11 即时冷启动续播、iPad恢复与18无线服务分界

更新时间：2026-10-11T00:03:38+08:00。先读[本批真机交接](../handoffs/2026-10/2026-10-10-RESUME-IMMEDIATE-COLD.md)及[机器摘要](../../testing/results/2026-10/RESUME-IMMEDIATE-COLD-20261010.json)，覆盖下方23:31“Pad离线/18不可读”的当前状态判断；此前历史记录保留。

本轮未改App源码，仍是源120c092e、普通9e8f21ec/2c3a2ca0/KSeda1。173输入/29库签名已重核；13与USB iPad逐机保留数据覆盖、25/16非诊断偏好完全一致、空环境实际正常启动。13关闭后立即XCTest终止再冷启动，151.508秒书签保留，冷续播151.582秒；Pad普通续播60.784→88.272秒，冷首钟88.272秒，轨道偏好保持，t3黑场留证。只完成普通Wi-Fi文件KSPlayer定向L1，不能判crash/jetsam/PiP/AV/蜂窝/逐帧性能通过。

00:03现场重查13/iPad身份、USB配对、WDA ready与正常空环境前台；最终正常首页实际图已核，NAS正常，其他服务卡片未知；播放器关闭、原生条件active0、idle10/动画2已恢复。iPad使用现有有效固定Bundle ID fixture恢复WDA，已安装profile仍有效；旧本地iPad fixture过期与已安装Runner有效区分。原始标识/偏好/证书只在本机私有目录；exact helper与SHA存本批证据helpers。不要让旧全局临时指针把本批证据写入历史目录。

18直接Bonjour身份及Mac既有配对现已验证，IPv4/IPv6容器服务均在收发时断开；CoreDeviceProxy服务创建成功，但userspace隧道第一协议握手仍断开、未接RSD。最新9e8/2c3包未上传/未安装/未做最新包启动，不沿用旧5ec2/ba52安装。此前未输新六位码即未配对的判断已撤回；保留既有配对，不修改网络，不把数据线当无线调试前提。下一步定位容器/开发服务数据链路，恢复后保留数据更新、核正常启动/UI，再接入18调试。

本批开始于10月10日23:42、收尾跨11日；App/WDA现有profile北京时间10月11日06:03:15/06:05:26到期，后续开工现场重核，过期则按runbook续签/保留数据安装。继续后台/PiP/异常终止保存、119、原弱蜂窝旧ordinal0、完整帧/Lenna/DS One与全部PX/UX/CB/L2/L3/Main；同源306测试/2跳过/0失败、15预检是此前结果，未重跑，未提交推送。


## 2026-10-10 启动续播书签保护与无线配对判断更正
- 更新时间：2026-10-10T23:31:26.984874+08:00
- 做了什么：确认手机截图中的Mac就是本机，撤回未输入新六位码即配对未完成的判断，保留配对刷新用户开发服务；修复初始续播seek到达前提前覆盖书签，8受控场景基线4场景/10断言失败，修复后306测试/2跳过/0失败、15预检、普通Debug构建及签名/链接通过。
- 做到哪：当前源120c092e、普通9e8f21ec/2c3a2ca0、KSeda1，173输入/29库已核。13保留数据更新/25偏好一致、S01早退出及两30秒正常续播/冷重开实际画面/原退出已核，91.422保存→91.508冷首钟，音轨字幕保留；第二次退出磁盘3秒旧/10秒新，延迟仍待优化。最终13最新正常首页/空环境/条件active0/idle10/动画2。18已配对但原生tunnel/DDI仍阻塞，最新无线枚举缺目标，当前新包未安装；Pad离线，旧5ec2/ba52证据不计新包回归。
- 接下来干什么：18亮屏解锁打开App后重核无线通道，恢复则保留数据更新/正常启动；Pad重连逐机更新；补保存收敛即时冷退出/119/真实弱蜂窝旧ordinal0/完整帧与Lenna及全部PX/UX/CB/L2/L3/Main。见docs/archive/handoffs/2026-10/2026-10-10-RESUME-STARTUP-SAVE.md；本轮不作性能验收、未提交推送。


## 当前工作环境：MacBook + iPhone13

2026-10-05 10:25 最新接续：用户报告手机已解锁，现场iPhone13/iOS16.3.1 USB/配对恢复；固定WDA由独立launchctl宿主持有、ready，无循环重启，Mac有界防休眠仍运行，但不保证24小时iOS免授权。eef/d0旧候选真实外置ASS返回PGS五次失败已保留；补齐provider清空前捕获，99核心测试/正常Debug构建/preflight通过，最新4148b9a0/777ca0b5已验签保留数据安装、25项偏好一致、正常无变量启动。六次已知PGS暂停cue返回均正确复用、无新seek，关闭/返回繁英PGS也正确。恢复后583有效遥测覆盖625.169秒，无缓冲、138有限32MiB窗口完成；初段丢帧6→101保留，未判整体流畅。真实seek后PGS fresh-cue精确区间仍不足，不关闭全局PX/UX。正常退出/结束事件已核，WDA继续保留；Lenna/DS One最新安装元数据重读，竞品接续中，正式受控配对仍0。先读[本轮回归及剩余项](../handoffs/2026-10/2026-10-05-IPHONE13-PGS-EXTERNAL-RETURN.md)。

2026-10-04 19:37 人员约束：用户在外地，10月7日才能回家，此前按无人能现场操作手机安排。XCTest本机授权/首次蓝牙Pair无已验证远程输入通道，不循环重启WDA或重复要求手机端确认；可推进既有日志、代码、模拟器验证。回家后先现场授权并验证备用输入通道，再按下文最新包身份门槛恢复真机。此约束不改变候选未验收、竞品正式配对0的事实。

2026-10-04 18:59 最新：现场iPhone13/iOS16.3.1/USB/配对通过，WDA跨轮进程结束后复用恢复，但原生截图再次是XCTest本机密码页；HTTP未ready，有界尝试已清理，未重装WDA。继续完成“暂停同位置切回已显示PGS”的冗余seek候选：仅同轨/同归一化时刻/同plan及seek代次复用已知图，其他情况仍原路径；98结构化XCTest/正常设备Debug构建/preflight/diff通过。最新eefefaed…/d0ee7e8a…及KS568a9c04…（18:52:03）已深严格验签、保留数据InstallComplete/退出0，25项非诊断偏好一致。**本轮App正常启动与最新包UI回归未完成**，仍待手机本机授权，不能把旧302/6e2的5/5和626秒归给新包，也不能称卡顿已修。正式竞品配对0、PX/UX状态保留。先读[本轮候选与授权门槛](../handoffs/2026-10/2026-10-04-IPHONE13-PAUSED-PGS-REUSE.md)，再继续受控“保留轨道/切回PGS”对照及负例。

2026-10-04 16:11 最新覆盖：普通Debug30210177/6e2a2c5c最新包和93核心测试有效，未再修改App源码。新S03原画LAN无切轨trace7F24240D，实际字幕PGS7/TrueHD1，586带时钟遥测覆盖626.086秒、1.225→627.316秒，缓冲计数/活动样本0，丢帧1→2、最小稳态储备7.923秒；11张定时实际图及t3/10/30已核，139个已完成上游窗口足长且无任务错误。仅该区间稳定，不代表逐帧FPS/音频/全片通过。5次暂停PGS切回功能回归通过，但另次同位置seek后4501ms原画缓冲仍待修；正式竞品有效配对0。此前ASS只确认会话实际显示，重开轨道偏好未验，新从头运行实际PGS不可写ASS。最新包保持，真正退出到详情、playback_ended已证实；WDA和Mac防休眠任务仍可用。见[最新基线与变更卡](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md#1611-最新包十分钟无切轨基线)及[机器摘要](../../testing/results/2026-10/IPHONE13-PGS-REGRESSION-20261004.json)。

2026-10-04 15:46 最新覆盖：iPhone13/iOS16.3.1/USB及配对重新核对，当前普通Debug最新main30210177…/dylib6e2a2c5c…（15:23:51）深严格验签并保留数据覆盖安装InstallComplete/退出0，无变量PID97411、真实启动及既有库已验。有效字幕过滤及暂停解码通知修正，93核心测试/设备构建/preflight通过；实际已知PGS暂停cue切回5/5，响应中位上下界486～1602ms、最大上界1881ms，仅同App功能回归。恢复播放32.244秒再次原画LAN缓冲4501ms后恢复，连续性FAIL，整体卡顿未解决。当时会话切回ASS（持久偏好未验）并真正退出到详情，playback_ended已证实。Lenna/DS One已实播且媒体公网端点与Nastart私网端点不同，NAT回环未知，正式有效配对0；音频、完整显示采样及代表集待验。优先隔离同位置字幕seek清空音视频队列后的储备与供流。详见[最新检查点](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md#1546-最新包pgs暂停回归与原画再次缓冲)、[脱敏量化记录](../../testing/results/2026-10/IPHONE13-PGS-REGRESSION-20261004.json)及[扩展对照](../../testing/results/2026-10/IPHONE13-COMPETITOR-EXPANDED-20261004.md)。

2026-10-04 15:15 最新覆盖：USB/固定WDA已恢复，目标iPhone13/iOS16.3.1、普通Debug最新ad238335…/64cd008f…（15:09:57）保留数据安装InstallComplete退出0，无变量PID97315/启动台和既有Jellyfin库已验。新增有效字幕跨seek过滤修正，92个核心测试、设备构建/preflight通过；新包同暂停PGS回归进行中。4c3e包ASS暂停真实关闭/恢复及短段播放属于历史包；Lenna/DS One Jellyfin媒体公网IP8097、DS One DSM公网5001、Nastart大流私网8096已由进程TCP元数据证实，公网端点不证明WAN、NAT回环待核。正式有效配对0、整体卡顿/音频/完整滚动未验收。详见[最新批次](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md)和[扩展对照](../../testing/results/2026-10/IPHONE13-COMPETITOR-EXPANDED-20261004.md)。


2026-10-04 14:32 最新安装覆盖13:46：跳转恢复诊断修正，88核心测试/构建/preflight通过；正常Debug main4c3ecf20…/dylib308b3969…已保留数据安装、无变量启动及真实启动台核实。WDA恢复且普通锁屏已实际解锁；DS One DSM MI3真实播放/ASS双语/暂停/退出取证，字幕切换生效时间仍待隔离。新包MI3前进/暂停回退诊断反例实证，见[本轮交接](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md)。

2026-10-04 13:46 最新状态：USB配置恢复且固定WDA ready；已保留数据恢复正常Debug b2a/6ab并确认无变量启动及真实启动台，覆盖下方12:16阻碍。手机切换控制已真实确认关闭。DS One MI2从头可见缓冲6.658～8.711秒后恢复，首可辨识画面含自然黑场，暂不排名。音轨、字幕、DSM直播放及Lenna共同计时继续补，正式配对仍0。先读[本轮恢复与竞品记录](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md)。

2026-10-04 12:16 最新状态覆盖下方11:49构建描述：标准Release9b…实播为旧VLC，校准样本排除Greenfield排名；优化Debug-O/DEBUG main415f…已签名保留数据安装并普通启动，Greenfield实播未开始。USB原生录屏-11805后USB/WDA失效，目标USB重枚举API成功但调试服务仍无设备，正常Debug收尾恢复未完成；Mac未锁屏，原因未知。竞品范围已扩展CB-01～26，DS One2.4.5(4)既有DSM登录/Jellyfin库可进，有效播放配对0。先读[本轮最新阻碍](../handoffs/2026-10/2026-10-04-IPHONE13-POST-AUTH.md)，连接恢复后先核对/恢复正常包，再继续实测。

2026-10-04 11:49 授权后接续：先读[本轮真机记录](../handoffs/2026-10/2026-10-04-IPHONE13-POST-AUTH.md)。XCTest/WDA已恢复；最新正常Debug安装后MI3回退后段600秒无新增缓冲，MI2原画两次等待仍失败、自动12Mbps HLS接手后约298秒计数0。Nastart/Lenna各12位移，但显示表仅覆盖前段，两者INSUFFICIENT、不排名。用户新增DS One双入口与全面量化，见[执行卡](../../testing/results/2026-10/IPHONE13-COMPETITOR-EXPANDED-20261004.md)。DS One2.4.5(4)既有DSM登录/Jellyfin入口已核；无iCloud权限Release优化构建9b454ee…保留数据安装/普通启动/真实启动台已验，播放基线与配对待补，结束须恢复正常Debug。PX/UX状态保持。

2026-10-04 06:14 其他远程操作方式核查：新增[KeyPad官方设置](https://bluetooth-keyboard.com/setup/)候选，Mac模拟蓝牙键盘/鼠标；官方要求手机设置→蓝牙及手机上Pair确认，鼠标需[AssistiveTouch](https://bluetooth-keyboard.com/for/iphone/)。同开发者[Screen Mirror & Control](https://toolbunch.com/screenmirror/)是USB显示+蓝牙输入，同样需手机侧初始化，不能凭软件宣传证明XCTest密码页可操作。本轮只查资料，未安装/配对/改设置/启动WDA；当前无人触碰手机下仍无已验证可用新路线。Apple镜像iOS18+门槛仍不满足，保持不升级系统与放弃切换控制约束。两包续签及当前授权阻塞以续签交接为准。

2026-10-04 06:11 两包续签已完成：先读[续签交接](../handoffs/2026-10/2026-10-04-IPHONE13-SIGNATURE-RENEWAL.md)。Nastart正常Debug新main b2a72e…/dylib6ab619…、保留数据覆盖安装及无变量启动PID93033/真实启动台确认，25项非诊断偏好全部一致；WDA复用固定fixture重新签名并覆盖安装。手机实际profile逐字节对应包，Nastart北京时间10月11日06:03:15、WDA06:05:26到期。WDA本机XCTest密码授权仍未完成，HTTP有界超时并清理本轮Runner/转发，收尾无WDA进程。脚本默认读取当前包embedded profile，避免旧UUID旁文件误判。无新播放/滚动/竞品PASS，后续不得沿用旧af8dd6…包验收。

2026-10-04 06:00 签名到期复核：现场USB确认iPhone13/iPhone14,5/iOS16.3.1，同UDID连接；两App仍已安装，手机实际profile由昨日9份变7份，两App匹配profile不再列出，也没有新有效匹配项。昨日精确匹配两profile期限为北京时间10月4日00:26:35（Nastart）、00:28:33（WDA），本轮约已过期5.5小时。安装元数据ProfileValidated=true不视作当前有效期限证明；未发现续签证据。用户本轮询问状态，仅只读核查，未重新安装/卸载/输入凭据/新App回归。后续须新有效签名保留数据覆盖安装、核对最新包与启动；XCTest授权仍独立验证。原始仅本机私有2026-10-04-signature-check-055844。

2026-10-03 11:45 取消密码请求：用户已表达关闭iPhone13解锁密码的意图；本轮只读USB核对iPhone14,5/iOS16.3.1，实时截图仍XCTest两位未知输入/两位空、外部切换警告，WDA HTTP不可连接。当前无手机设置输入通道，未发送密码或执行关闭。电脑控制工具要求认证凭据变更最终输入、确认、提交由用户接手；指导现场人员可直接设置→面容ID与密码→关闭密码，无需先恢复WDA。关闭将降低数据保护并停用Apple Pay付款卡，依手机提示由用户决定。原始证据仅本机私有2026-10-03-passcode-handoff-114142。完成后需实测WDA并更新有效签名/安装身份，不能预先报告恢复或新包回归成功。

2026-10-03 11:40 授权周期重要修正：[Apple开发工具工程师](https://developer.apple.com/forums/thread/693273)说明iOS UI自动化在设备设有密码时大约每天需手动输入一次，且无官方支持的自动输入方式。续签与此设备授权独立，不应承诺“找人完成一次即可后续数日无人值守”。本机10月1日同包WDA重启曾无新提示，10月2日又提示，未定位精确触发时间；续签后是否当即提示须实测。建议先更新有效签名，再现场授权与重启验证；没有实际续签/改变密码。此修正优先于此前笼统的一次授权恢复建议。

2026-10-03 11:33 签名到期核验：从USB iPhone13只读复制实际描述文件，安装元数据精确匹配各自application-identifier，唯一对应profile与最近安装包embedded身份一致。Nastart北京时间2026-10-04 00:26:35、WDA00:28:33到期，11:32核查均余约13小时；证书到2027-07-27，先到期的是七天profile。尚未续签/安装/操作App，原XCTest授权独立未完成。WDA后续若profile过期已属于runbook允许签名恢复分支，仍须固定Bundle ID/宿主/Team且不反复盲装。私有证据2026-10-03-signature-expiry-113156。

2026-10-02 20:44 实时截屏：USB身份再次核实iPhone13/iOS16.3.1，新截图仍XCTest两位填充/两位空，顶部找不到外部切换警告再次可见；20:38关闭Mac后的警告消失只是当时证据，未重新核对Mac开关，不推断自动恢复原因。本轮只读、不重启用户已放弃方案；原图仅本机私有2026-10-02-iphone13-live-204351。

2026-10-02 20:40 最新接续：用户放弃切换控制，纠正客户端名称为VNC Lite（开发商未核实，不再沿用Mocha界面假设）。Mac临时切换控制已原生关闭并确认off，手机警告消失但两位未知密码输入仍在。官方替代核查：iPhone镜像要求iOS18+、当前16.3.1不适用；Typeeto需iOS端发起连接且本机未安装，XCTest密码页支持未测；AnyDesk/TeamViewer iOS仅查看限制。未找到当前无人操作条件下已验证可行的新输入路线，不安装付费软件/升级系统/重启WDA循环，不再重复该方法。手机授权及原App回归仍待恢复；原始蓝牙/截图仅本机私有2026-10-02-remote-alternatives-203821。

2026-10-02 20:35 最新只读核验：新USB截图仍同一XCTest页（两位已填/两位空、找不到外部切换）。设备全进程枚举未见WebDriverAgentRunner，Nastart PID74540、assistivetouchd PID79748；提示留屏不代表正在运行的测试服务或授权完成。本轮未发输入/重启服务/新增App回归。私有证据2026-10-02-auth-check-203323。

2026-10-02 20:30 只读复核：新USB截图仍为同一XCTest授权状态（两位填充、两位空，找不到外部切换），8102不可连接；未发送输入或开始App回归。证据仅本机私有2026-10-02-auth-recheck-202947。

2026-10-02 20:25 最新接续：用户要求再查看，现场USB iPhone13/iOS16.3.1与原生截图确认授权页仍两位已填/两位空、数字键盘缺失、找不到外部切换；没有可见清除/授权变化，8102 HTTP不可连接。本轮只读、未发输入/凭据/重启WDA或进行App回归。下一步仍需可靠清空未知输入并恢复XCTest授权，不把Mac连接或普通App启动当授权成功。私有证据2026-10-02-switch-recheck-202410。见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 11:48 最新接续：用户说明未输入数字、可能误按其他键；11:46 USB截图仍两位密码填充/无数字键盘/找不到外部切换。电脑工具一次BackSpace后两位未变，已请用户经Mocha普通键盘退格一次作两位→一位对照；输入验证前不补齐或提交、不重新拉起WDA。无新App回归，keepawake仍运行。详见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 11:14 最新接续：用户按一次Space后，Mac日志11:09:27明确Forwarding switch event按下/释放（配置空格→选择项目），首次证实真实开关已转发。USB手机两次截图仍警告找不到外部切换，XCTest页变为两位密码填充/无数字键盘；两位来源未知，已暂停按键并询问是否还有数字输入，不盲目补齐/提交。未启动WDA、8102无监听，无授权完成或新App回归。详见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 11:03 最新接续：用户按Shift后USB截图新出现“切换控制，找不到外部切换”；四个密码圆点仍空。Mac设置及只读偏好核实唯一选择开关为空格(keycode49)，Shift未绑定；没有修改开关映射。10:59:04再次进入Connected As Forwarder，连接目标此前手机接收证据已核实，实际选择动作仍待验；用户反馈找不到空格，已按官方帮助与既有截图指引底部第一个QWERTY键盘按钮打开普通键盘后按空格；此次Space对照尚未发生。保持当前切换控制连接。没有重新启动WDA或新增App回归。见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 10:58 最新接续：用户第一次空格后手机回到Nastart启动台，但固定WDA重启又出现XCTest密码页、HTTP未恢复，超时后自己的Runner/转发已清理。USB手机syslog的assistivetouchd确实接收本Mac连接数据，目标iPhone13已核实；当前仅dummy/心跳，没有真实选择动作证据。再次现场对照时用户反馈Mocha已断开；Mac原生UI仍可访问、keepawake运行。待Mocha重连后验证一次选择动作，不输入未确认目的地的密码，不报告新App回归。详见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 10:50 最新接续：针对用户“连接后无窗口”，私有系统日志已确认10:38:55进入 `Connected As Forwarder`，无镜像窗口不能据此断言连接失败。10:45与10:49实际USB iPhone13仍为XCTest密码页、四个空圆点、无扫描框；工具一次空格没有可见响应，已请用户Mocha发送一次空格作对照。发现多个同名iPhone，目标与输入须继续核定；未输入密码、未完成授权、无新App回归。七天有界keepawake仍running/PID52029。详见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 10:36 最新接续：用户已点击iPhone连接，但工具仍读到“iPhone／返回／连接”，实际iPhone13未见扫描框；固定WDA已拉起XCTest密码提示、HTTP仍未就绪，超时后本轮进程/转发已清理。未输入密码，待用户确认Mocha实际连接状态；不能把discovery Peer Connected当手机可操作。最新af8dd6…包/USB/配对重核无变化，无新App回归。见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 10:21 最新状态：用户Mocha手动开启后，切换控制主面板已实证出现，系统agent running，更新此前未启动结论；电脑工具仍读不到浮动主面板按钮，已请用户缩小/右移手机视口，点“位置”右侧“设备”检查家里iPhone并连接，等待结果。手机XCTest授权尚未完成、未输入凭据。本轮USB/配对及正常af8dd6…包签名/哈希再核无变化，无新播放回归；屏保永不和七天有界keepawake已处理。详见[续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。

2026-10-02 10:13 最新接续：详见[解锁后记录的远程输入/再次锁屏续记](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。切换控制主面板/设备发现尚未取得，XCTest授权未完成；临时开关已恢复关闭，待用户Mocha手动点击对照。09:41再次锁屏已定位为20分钟闲置屏保触发；旧caffeinate在09:22提前退出。Mac已再次解锁，屏保自动启动已设永不并保存复核，独立七天有界keepawake LaunchAgent运行/电源断言已验证。正常af8dd6…包签名/哈希核实，无新源码/安装/播放回归；MI2原画供流不足及完整滚动/竞品仍待真机输入恢复。

2026-10-02 07:38 最新接续：先读 [Mac 解锁后接续记录](../handoffs/2026-10/2026-10-02-IPHONE13-POST-UNLOCK.md)。Mac 已解锁、Instruments 目标枚举及实际八秒录制/导出恢复；手机启动 UI 自动化时仍需本机 XCTest 密码授权，WDA HTTP 未就绪。本轮减少播放轮询中未变化元数据的 SwiftUI 发布，87 项核心测试、构建/签名/链接/preflight 通过；最新正常 Debug dylib `af8dd6beb0…` 已保留数据覆盖安装、无变量启动与真实启动台确认。本轮未完成播放/滚动/竞品回归，不沿用下面旧包的性能结果。四小时 caffeinate 临时保持唤醒已验证；原有接电不休眠/密码永不/自动注销关闭均已现场确认，本次历史锁屏原因仍未知。

用户已暂停Codex CLI专项，未来几天通过VS Code插件和ChatGPT客户端继续单机优化。优先读 [单机环境及本轮记录](../handoffs/2026-10/2026-10-01-IPHONE13-TRAVEL-BASELINE.md)。iPad/iPhone18专项保留待验，不阻塞iPhone13独立工作；回老家后网络与媒体上游须现场确认。底层成功脚本继续复用。


## 2026-10-02 iPhone 13 Jellyfin 大文件优先修复

Tailscale补充：本机客户端Running/Online，既有屏幕共享5900在监听，通过本机Tailscale IPv4已取得正常RFB握手；可让用户从同一tailnet的外部设备尝试屏幕共享登录。仅验证本机服务连通，不代表外部ACL/账户认证或Mac解锁成功；未修改远程访问或安全设置。连接信息私有存本机`2026-10-02-tailscale-remote-*`。iPhone XCTest本机授权与Mac解锁分开验收。

07:20远程接续：Mocha外部连接已实证；此前三次Mac密码校验成功却因remote management权限level0拒绝。用户执行仅lagransun控制/观察授权后，naprivs=-2147483646，07:17:04/07:17:56认证成功。首次桌面代理端口报错并断开，随后重连开始数据发送、代理running；07:19系统仍锁屏，待用户远程完成锁屏密码输入。认证/画面发送不等于Mac解锁；未重启Mac或改其他账号/关闭认证。日志私有存`2026-10-02-vnc-auth-071155`和`2026-10-02-vnc-disconnect-071918`。

06:48远程接续补充：用户外出数日无法现场操作；Mac锁屏已由系统会话确认，电脑控制工具自动解锁失败且未暴露密码输入入口。USB/配对仍有效，只读下载诊断与原生截图成功；最新正常包签名/哈希、源码时间再次核对未变，但固定WDA启动后手机明确出现“为XCTest输入iPhone密码 / Enable UI Automation”，Runner进入test plan而HTTP拒绝连接。须按runbook本机授权分支恢复，不能宣称UI回归可继续；本轮未操作App、未安装新包/重装WDA、未修改安全设置，自己的WDA/转发已停止。原始证据私有存`~/Library/Application Support/Nastart/DebugEvidence/2026-10-02-locked-mac-usb-064750/`。可独立继续日志/源码/构建检查；Mac锁屏与Instruments枚举故障因果仍未证实。

先读 [本轮复现与修复](../handoffs/2026-10/2026-10-02-IPHONE13-JELLYFIN-STALL.md)。已在现场USB iPhone13/iOS16.3.1正常包复现S03局域网54GB原画频繁缓冲，未发现CLI残留强制原画证据。LAN首帧后储备提高至4秒/上限16，并修正回退仍参照最初续播位置导致储备无法恢复的确定缺陷；86项核心测试、设备构建/签名/链接隔离/preflight通过。最新正常Debug `-Onone` dylib `8a3e77e1…`，保留数据安装成功且无变量启动；私有持久包路径见本轮记录。S03同6144.551回退目标观察638秒：最初28秒2次缓冲，随后610秒无新增活动缓冲、保持原画LAN，末计数4（含启动/seek）、丢帧13。仅此缺陷与原故障区间闭环，不能报整片零卡顿/关闭PX-03。

WDA旧宿主中途结束，原生截图继续取得真实画面，固定runner重启ready后新session已恢复。Downloads Xcode设备枚举需先xcdevice刷新，预检ready；后续已补S01双入口有限持续/退出/热续播，均无缓冲且每轮0～2累计丢帧；MI2原画实际供流约35Mbps低于片头约90Mbps，仍2次缓冲，自动12Mbps候选成功接手、约287秒后正常退出，不能算原画通过。Lenna已核对1.0.17(610)、同名详情和默认真实播放/退出，实际路由/轨道/缓存未对齐，有效配对0。正式滚动0手势/INSUFFICIENT：当前Instruments缺目标，Mac锁屏阻止GUI排查，待用户解锁。ios-deploy后段枚举超时已以新只读VendContainer脚本恢复诊断，不意味着采样或安装身份自动恢复。收尾Nastart正常启动台/PID73932，自己的WDA/syslog停止；详情见本轮记录。iPad/iPhone18仍待设备接入，不沿用历史安装身份。

## 2026-10-01 20:33 iPhone 13 页面保护与现场接续

先读 [本轮记录](../handoffs/2026-10/2026-10-01-IPHONE13-SCROLL-PAGE-GUARD.md)。已现场核对同一 iPhone13，并通过设备暂存二进制回读哈希与原生安装完整回执完成最新正常 Debug `a79ae773…` 保留数据覆盖安装；无变量启动及真实启动台确认。本会话 Downloads Xcode 预检仍为空，WDA/截图可用。随后动作观察前页面已变成横屏《碟中谍3》播放器，5次动作后前台切到系统桌面，整轮排除滚动验收；已停止自动化并询问设备是否空闲，等待确认。新增正式滚动页面标识/视口保护，15项工具测试通过；本轮WDA启动进程已停止。无滚动PASS、无Lenna有效配对，不沿用之前会话采样成功作为本轮通过。未改App源码或PROGRESS.md。

## 2026-10-01 CLI 观测恢复（本轮）

先读 [本轮记录](../handoffs/2026-10/2026-10-01-CLI-OBSERVATION-RECOVERY.md) 与 [可复制命令手册](../../testing/CLI-DEVICE-OBSERVATION.md)。视频截图与逐帧采样独立推进，不互设前置。本轮最新包S01真实30秒截图及退出取证完成，历史源帧匹配离线复验一致。显式使用 Downloads Xcode26.6后，iPhone13 Instruments录制与TOC/display/hitch导出均成功（374条display/16条hitch）；逐帧覆盖和正式滚动仍待验。不要沿用下午“所有采样不可用”或中途“设备发现仍失败”的结论。

## 2026-10-01 17:32 CoreProfile 原始事件流取得进展

见 [原始事件探测记录](../handoffs/2026-10/2026-10-01-COREPROFILE-RAW-PROBE.md)。iPhone 13 USB/配对现场正常；WDA 8102 本轮不可达，未重装。本轮只探测采样服务，未核对 App 安装身份或操作 UI。定位 tidevice 对 `DTKTraceTapMessage` 解码失败后，临时保留原始 payload，8 秒取得 52 块约 33 MB；42 个压缩块全部按声明长度解压，kdebug v2 解析得到 1,898,765 个事件。显示事件映射、timebase、丢事件/覆盖率与 App 归属仍待建立，不能称完整帧采样恢复或滚动 PASS。下一轮从本机私有原始证据继续映射验证，再完成当轮包核对及 UI/Lenna 取证；iPad 仍暂缓。未写 PROGRESS.md。

## 2026-10-01 17:16 DVT 替代采样取得数据

见 [替代采样记录](../handoffs/2026-10/2026-10-01-DVT-SAMPLER-ALTERNATIVE.md)。已通过 USB/DVT 实测设备图形 FPS 数据流，两次分别取得 14 / 8 条样本，新增有界诊断脚本 `scripts/device_graphics_probe.py`。约 1 Hz 的全设备聚合数据可用于诊断，不能代替逐帧证据；完整滚动验收仍 INSUFFICIENT。本轮仅采样服务能力探测，未做 App 包身份复核、UI 回归或竞品对照。不要继续称所有采样不可用，也不要误称完整帧采样已恢复。未写 PROGRESS.md。

## 2026-10-01 17:06 采样环境对照待补

见 [本轮环境核查](../handoffs/2026-10/2026-10-01-IPHONE13-SAMPLER-ENVIRONMENT.md)。iPhone 13 在线、配对正常，本机正常 Debug `a79ae773…` 的签名/哈希/源码时间重新核实；本轮尚未重新确认设备安装身份，未开始 UI 回归。采样预检仍为三项能力缺失、INSUFFICIENT、0 手势。当前会话受沙箱限制且禁止提权，已请求用户在普通 Terminal 执行只读 `xcrun xctrace list instruments`，用于区分当前执行环境与宿主 Instruments 问题，待输出。不要重复重装 WDA或将上轮安装回执视为本轮回归；恢复采样后再过安装门槛，继续滚动与 Lenna 配对。未修改 PROGRESS.md。

## 2026-10-01 17:02 iPhone 13 安装回执恢复与采样预检

先读 [本轮安装与采样预检记录](../handoffs/2026-10/2026-10-01-IPHONE13-SAMPLER-PREFLIGHT.md)。固定 WDA 恢复 ready；正常 Debug `a79ae773…` 包验签、设备暂存二进制回读哈希一致，以 Developer `.app` 目录方式保留数据覆盖安装取得 `InstallComplete 100% / Complete` 完整回执。无变量启动、真实启动台及收尾 PID 68158 已核对；进程检查须用 `ps --all --json`，默认列表的 isApplication 过滤会漏掉本轮 App。Instruments 不仅无设备，还无 instruments/Animation Hitches 模板，本机录制及历史导出也失败。采样工具新增动作前预检、超时证据和提前保存元数据；13 项测试通过，现场 INSUFFICIENT、0 手势。本轮未播放视频或操作 Lenna，无滚动验收/竞品排名。下一轮恢复宿主采样能力，再继续逐页滚动和 Lenna 配对；iPad 暂缓，未写 PROGRESS.md。

## 2026-10-01 16:10 iPhone 13 显示采样门槛续查

先读 [本轮工具与门槛记录](../handoffs/2026-10/2026-10-01-IPHONE13-FRAME-GATE.md)。固定 WDA 已重新恢复 ready，App 收尾 PID 67785 存活；两套 Instruments 无设备，历史 trace 导出也失败。正常 Debug a79ae773… 包/IPA 验签与哈希核实，但本轮覆盖安装缺完整回执，最新包回归未开始。滚动工具新增逐拖动显示采样连续性检查及异常 INSUFFICIENT 持久化，11 项工具测试通过；实际录制开始前失败，0 手势，无滚动 PASS/播放回归/Lenna 配对。下一轮优先完成安装回执和显示采样恢复。iPad 仍暂缓，未写 PROGRESS.md。

## 2026-10-01 15:56 iPhone 13 WDA 恢复与短回归

先读 [本轮恢复与短回归](../handoffs/2026-10/2026-10-01-IPHONE13-RECOVERED.md)。iPhone 13 USB/配对现场核实，最新正常 Debug `a79ae773…` 验签/IPA 哈希一致，保留数据覆盖安装取得完整完成回执，无变量启动与持续进程/真实截图已确认。固定 WDA 不重装恢复 ready；启动脚本补身份变量并核对 ready 服务身份，重启及复用实测成功。S01 Jellyfin 新架构原画从头约 52 秒、热续播约 41 秒，真实画面和两次退出回同一详情齐全；热续播启动有 1 次缓冲计数、累计丢帧 1，不能报整轮零卡顿。Instruments 仍未枚举设备，滚动自动结果 INSUFFICIENT；Lenna 已进入同名 S01 详情，但片源/路径/轨道/缓存及共同计时未对齐，无性能排名。收尾正常 App PID 67681、WDA Runner PID 67680，视频全部退出，syslog 已停止；下一轮现场重验。iPad 继续暂缓，未写 PROGRESS.md。

## 2026-10-01 15:28 XCTest 授权阻塞定位

先读 [本轮定位记录](../handoffs/2026-10/2026-10-01-IPHONE13-WDA-AUTH.md)。iPhone 13 USB/配对正常，固定 WDA Runner 已进入 test plan 但 HTTP 未监听；15:24 原生截图显示“为 XCTest 输入 iPhone 密码 / Enable UI Automation”，已请求用户在设备本机完成授权。启动脚本超时退出，下次授权后重启固定 XCTest 链路，不重装 WDA。本轮本地正常 `a79ae773…` 包验签/哈希通过，但覆盖安装没有完整回执，不能声称最新包回归完成；App 无变量启动截图已取得，进程持续证据未完成。无滚动/播放/Lenna PASS，iPad 继续暂缓。

## 2026-10-01 15:12 iPhone 13 单机接续

用户已明确暂缓 iPad；下一轮只处理 Mac 已连接 iPhone 13。先读 [单机接续记录](../handoffs/2026-10/2026-10-01-IPHONE13-NEXT.md)：USB/配对现场核实，最新正常 `a79ae773…` 包再次保留数据安装成功，无测试变量启动 PID 67371、真实启动台截图已取得。WDA HTTP 仍 reset，Instruments 枚举无录制设备；未完成滚动/播放/Lenna 验收。WDA preflight 的 CMS 解码权限阻塞已修正并实际通过，启动脚本增加可写日志目录参数和 HTTP 超时；不宣称服务已恢复或 App 性能改善。先恢复 iPhone 工具链，不等待 iPad 接入。

## 2026-10-01 下午最新接续

先读 [14:48～14:59 双机接续记录](../handoffs/2026-10/2026-10-01-DEVICE-RESUME.md)。iPhone 13 已现场核实 USB、保存原诊断、保留数据覆盖安装正常 Debug `a79ae773…` 包并无变量启动；iPad 本轮枚举不可见，安装身份未完成核对，不能沿用早晨设备状态。WDA/帧采样工具未就绪，本轮无真机回归通过结论。滚动工具已从 ≥10 次请求加强为 ≥12 次逐滑实际位移/前台/完整动作时间验证，9 项工具测试通过；07:34 启动台的旧 PASS 缺逐滑位移，不作为加强规则验收。用户确认连接与解锁后继续 iPad 包核对、逐页滚动及 Lenna 配对；现有源码修改全部保留。

跨账号、白天在单位接手时先读 [2026-09-29 跨账号远程接手卡](../handoffs/2026-09/2026-09-29-OTHER-ACCOUNT-REMOTE.md)。其中的 07:09 现场与最终包信息晚于本文件下方较早的历史检查点；其 HEAD/工作区描述是推送前快照，接手须重新执行 `git rev-parse HEAD`、`git status --short`。任何 PID、USB 和服务状态也须现场重验。该卡写明 Remote 同账号前提与可直接发给新账号的指令。

更新时间：2026-10-01 07:35；上一轮收尾时间为 2026-09-29 12:40 双入口准备取消、iPad 请求路径实测完成。面向同一台 Mac 上的新会话/另一个用户本人持有的账号；本文件传递工程事实，不负责复制账号会话历史或登录凭据。

## 2026-10-01 iPad 自动滚动验收与竞品矩阵（进行中）

优先读 [今日实机记录](../handoffs/2026-10/2026-10-01-IPAD-SCROLL-COMPETITORS.md)。已复现海报严重卡滞和静止详情持续布局；仅编译优化无效，导航根隔离显著降低主线程活动。正式 iPadOS 18 自适应 TabView/侧栏候选 `a79ae773…` 正常 Debug 包已装 iPad/iPhone 13，逐页 Instruments 自动回归进行中，尚未通过。不要把上一轮能滑动的结论当成流畅验收。

用户指定 Lenna 为两机主对照，DS One/Jellyfin/网易爆米花为扩展；[CB-01～20 竞品矩阵](../../testing/COMPETITOR-DEVICE-MATRIX.md) 与 JSON 模板已新增，涵盖首帧、续播、轨道实际生效、滚动和网络/资源指标。对照结果尚待采集，不给速度排名。

## 2026-09-30 21:56 真机包核对门槛与 iPad 滚动

**每次换设备或开始真机调试，必须先按根目录 [AGENTS.md](../../../AGENTS.md) 核对最新安装包。** 无法确认身份时保存诊断后保留数据覆盖安装，不能凭 0.1.0(1) 判定最新。

iPhone 13/iPad 已先更新 ISO 基线包，再更新本轮滚动优化 `dd26df8f…` 最新包并正常启动。默认启动台改惰性布局，海报后台预解码并按真实像素内存计缓存。设备构建/签名/preflight 通过，iPad WDA 8103 本轮恢复。性能量化/长期流畅尚未验收，见 [iPad 滚动专项](../handoffs/2026-09/2026-09-30-IPAD-SCROLL.md)。iPhone 18 未装本轮包，下次调试先更新。

## 2026-09-30 21:47 iPhone 18 ISO 错误修复

已读取用户连接设备后的诊断：双入口五次 ISO 打开失败均零读取、同一本机端口；发现并修复 ISO 监听失效仍复用旧端口、并发启动与重建后资源释放问题。3 项代理集成测试、设备构建/签名/preflight 通过。最新 `343f0b3a…` 包已保留数据安装 iPhone 18 并无测试变量启动，PID 3935。**旧端口为强嫌疑，真实蜂窝 ISO 播放及切网复测仍待验**。详见 [ISO 蜂窝诊断及修复](../handoffs/2026-09/2026-09-30-ISO-CELLULAR.md)。本节包比下方 17:58 包新。

## 2026-09-30 17:58 iPhone 18 安装

已确认 iPhone 18 Pro Max USB 接入；将当前最新签名 Debug 包 `cbfff361…` 保留数据安装并正常启动，PID 2178，启动后进程持续存在。仅完成安装与启动，不含该设备的播放回归；细节及签名到期时间见 [iPhone 18 安装记录](../handoffs/2026-09/2026-09-30-IPHONE18-INSTALL.md)。

## 2026-09-30 下午 iPhone 13 与 iPad 接续

- iPhone 13：早上签名包 `86f6c8eb…` 在家中 Wi-Fi 用 Jellyfin S01 原画 LAN 上游单路运行 trace `99B41B69`，650 条遥测覆盖约 701 秒，时钟 0.073→700.574 秒、读取 1,874,559→278,581,897 bytes，卡顿计数/活动状态及可用丢帧样本均为 0；上游实际为 `192.0.2.2:8096` HTTP/1.1，正常退出回详情。将 LAN 探测两次有界重试与同服判定提为可测试策略，2 项定向模拟器 XCTest、最终 Debug 设备构建/签名、preflight 与 diff 检查通过。最终包 dylib `cbfff361…` 已保留数据装到 iPhone 13、正常无变量启动 PID 57920；续播短回归 trace `999FBE0C` 时钟 700.809→776.414 秒、LAN 上游、退出事件 1，首帧前一次约 301 ms 缓冲，首帧后无新增卡顿。长播属于 `86f6…`，不移作 `cbfff…` 的长播结论；旧 247.710 秒停滞根因、真实回退和真机失败后重试仍未验。详见 [当日 iPhone 13 续查](../handoffs/2026-09/2026-09-30-IPHONE13-STALL.md)。
- iPad 今日重新接 USB。14:52 现场 DSM 主会话/File Station 登录成功；旧日志有 `urlError:-1005`、DSM API `403` 和多次无保存凭据跳过恢复。保存登录后两次正常冷启动均重新登录、发现 LAN、刷新 47 个服务条目；最新签名正常包 `cbfff361…` 当前 PID 8238。iPad 原生设备测试 1 项通过，DSM/Jellyfin LAN/公网四接口 HTTP 200、有效 JSON、事务 HTTP `proxy=false`。iPad WDA 8103 未 ready，UI 可见状态、后台恢复、VPN A/B 与间歇故障原因仍未验。见 [iPad 环境续查](../handoffs/2026-09/2026-09-30-IPAD-ENVIRONMENT.md)。
- 两台设备播放均已退出。全部已有未提交修改与 KSPlayer 未跟踪内容保留，新增源码/测试/文档仍未提交；原始诊断仅在本机私有证据目录，不上传。下一批先围绕 iPad 真正复现时的日志区分凭据、DSM API、网络与 UI 延迟；iPhone 13 继续低负载 S01 追原画冻结现场。PX-03、UX-05 状态按唯一总账。

## 2026-09-30 iPhone 13 停滞续查

已重新核实 USB/iPhone WDA/签名包与 NAS/Jellyfin；iPad 今日未接入。iPhone 13 旧 f08bf… 包 S01 单路原画监测约 603 秒完成，trace `FC0BA914`，557 条实际时钟遥测到 621.598 秒，卡顿/丢帧 0，退出回同一详情；没有复现旧次 247.710 秒停滞，真实故障恢复未验。此轮媒体上游走公网域名 HTTP/2（`cellular=no`），因为 10:00:48 局域网同服验证暂报 `publicInfoUnavailable`；重进库后 10:24:38 同服 LAN 验证成功。已给这种暂时不可用加 2/6 秒有界重试，保留服务器 ID 相等门槛。新 Debug 包 dylib `86f6c8eb…` 构建/签名/preflight 通过，保留数据安装并无变量启动 PID 56199；DSM 恢复，10:33:15 局域网同服验证成功，新包 S01 LAN 原画 trace `B2246D1A` 约 37 秒实际画面/时钟、卡顿/丢帧 0、退出事件 1。失败后重试分支和新包十分钟 LAN 稳定性尚未实机验收；不能把公网十分钟成功归因于旧 LAN 停滞修复。现场和证据边界见 [当日交接](../handoffs/2026-09/2026-09-30-IPHONE13-STALL.md)。PX 状态按唯一总账。

## 2026-09-29 继续调试（历史记录）

- 12:41 收尾刷新资源快照：NAS 在线，CPU 49% / RAM 20% / 磁盘 92% / uptime 15小时41分钟（开播前15小时25分钟），未见本轮重启；Jellyfin LAN/公网均 HTTP 200 / 10.11.11。正常 iPhone App PID 48256、WDA ready，播放已全部退出。

- 2026-09-29 12:40 本批收尾：最新正常 f08bf… 包已保留数据安装两机、明确无测试变量启动。iPhone 13 S01 Jellyfin 原画 trace 14B2F3F7 单路观察 606 秒完成，实际画面、时钟和读取持续推进至 601.310 秒，556 条相关遥测，卡顿/丢帧计数均 0，停止事件 1、上报失败 0；没有自动回退请求。这只证明该包本轮十分钟未重现，不证明旧包原始停滞根因已解决，也不能代替真实故障下的回退恢复或人工听音。旧 37b0… 的持续停滞与两次候选对齐失败证据保留，修正了“缓冲仍按播放意图提前预热”的回退缺陷，实际解码反例通过。4cdd… 候选双入口原画呈现前取消有效窗口通过。iPhone 13 WDA ready、正常 App PID 48256、所有视频已退出；USB 仍为 iPhone 13+iPad，无本轮新 Nastart 崩溃（最新仍 9月28日20:21）。iPad 正常 f08bf… PID 7846，新进程12:26:02仍无保存 DSM 凭据；四接口/HTTP代理指标已验，UI/登录恢复未验。全部未提交修改保留，未改 VPN/Wi-Fi/NAS、未跑大电影限速转码。

- 2026-09-29 12:25 设备文件 S01 有效取消窗口通过：4cdd… 包准备本地原画后 held(8秒)，返回原文件夹使 released(cancelled=yes)，等待超过原延迟仍在原文件夹，无迟到播放器/首帧。与 Jellyfin 原画一起补双入口呈现前取消证据，不扩大到 HLS 或完整资源矩阵。最新 f08bf… 回退候选 Debug 构建/签名通过；其 Release 无签名编译也通过，现有 iCloud 签名限制仍保留。

- 2026-09-29 12:21 缓冲回退修正 L0 通过：预热提前量现在独立参考实际推进状态；缓冲中保留用户播放意图、候选从冻结的旧时钟开始，正常推进/暂停逻辑保持。模拟器实际 1 项解码 XCTest 通过，包含冻结时钟的候选首帧/对齐/恢复播放、暂停候选、正常推进候选及 KS 原画预热。设备 Debug 构建通过，正常签名候选 f08bfde1c3f3f9eaa811bb7eb7f4f43b1e31a32c31589b7458b4e17402c11bd2 待实机。首次测试卡在模拟器启动已留采样并终止，单设备重跑通过；不是断言失败。准备取消钩子对应的 Release 签名被现有 profile 缺 iCloud 权限阻止；CODE_SIGNING_ALLOWED=NO 的该版 Release 编译通过，只证明编译、不证明可安装的 Release。最新缓冲回退改动待补 Release 编译。单设备 XCTest 已报告 1 项 Passed，但 xcodebuild 收尾仍挂起，采样后终止；不记整个工具正常完成。

- 2026-09-29 12:18 Jellyfin S01 有效取消窗口通过：取消候选 4cdd… 包，准备 trace AAC904DA 已建立本地 Range；诊断 held(8秒)→返回搜索列表→2.662秒后 released(cancelled=yes)，等待超过原延迟仍在同一搜索页，无播放器/首帧/开播事件。截图与实际请求 ID 完整；这项仅覆盖原画已准备、呈现前离开，不覆盖 HLS/连续选片/全部资源回收。WDA activeAppInfo 的 env={} 来自其 XCUIApplication 对象，不能用于证明实际进程环境；本次等待确由 App held 日志证明生效，收尾须终止后明确无变量启动。

- 2026-09-29 12:13 持续播放失败补证：37b0… 包 S01 Jellyfin 原画 trace 25F1BD23，监测 606 秒已退出，但播放器在 247.710 秒起持续 buffering，末段时钟和 bytesRead 均不再推进，stallCount=1，最终 stallDuration 约 439 秒；不能记十分钟稳定通过。局域网接口持续 HTTP 200。自动回退两次准备/解码 HLS 成功但候选起点领先停住的时钟 11/15 秒，alignment 均被拒绝，未接手。正在修正“想播放但正在缓冲”被误当持续推进的预热提前量；原画停止读取的初始原因仍待取证，不将回退修正称为原始故障根因。仅 S01 自动回退发生转码，没有大电影/人为限速。

- 2026-09-29 12:04 iPad 请求路径实测完成：原生设备 XCTest 实际 1 项通过 / 0 失败；DSM API Info 与 Jellyfin Public 的 LAN/公网四地址均 HTTP 200、有效 JSON、API 成功。四次 URLSession 事务 isProxyConnection=false，LAN 使用 HTTP/1.1，公网使用 h2，均未复用连接。此指标只排除这些请求的 HTTP 代理连接，不能证明 VPN 已关闭或排除 IP 隧道/间歇故障。新进程仍报 restore.missing_credentials；UX-05 保持进行中。附件留在本机 continuous/ipad-route.xcresult 与 ipad-route-attachments/，不含请求凭据。

- 12:02 用户要求继续下一批。两机 USB/iPhone WDA/无变量 App/Jellyfin 可用，S01 原画 trace `25F1BD23` 十分钟基线正在进行；本次开始后先不覆盖安装运行中的 App。Debug 准备结果等待已构建、3 项取消测试通过，真机受控取消窗口待验；iPad 正在补真实请求代理指标，未改 VPN。以 [持续播放与取消专项](../handoffs/2026-09/2026-09-29-CONTINUOUS-CANCEL.md) 为本轮详细记录，尚无十分钟/取消真机通过结论。

- 用户已授权必要时直接远程解锁 iPad，不重复询问；具体凭据不保存于项目/日志。补查仍 `passcodeRequired=false` / `unlockedSinceBoot=true`，当前无需输入。DSM 无保存凭据及 UI 自动化初始化超时分别继续跟踪，不将系统解锁授权记成 DSM 登录恢复通过。

- 最后现场复核：iPhone 13 WDA `ready=true`、正常 App PID `47083` / `env={}` / `args=[]`；刷新已结束，NAS CPU 47% / RAM 20% / 磁盘 92% / uptime 12小时54分钟。USB 两机仍在。iPad WDA 未 ready，已停掉本轮失效的 8103 转发，iPhone 8102 保留；有效的 iPad WDA 副本在 `~/Library/Application Support/Nastart/WDA/iPad-18.3.1/`，profile 到期 2026-10-03，未来仍需重新核实。`git diff --check` 通过。

- 本轮收尾：两机保留数据安装/启动正常 `37b0…` 包；iPad 测试注入包已覆盖回持久正常包，CoreDevice 无 `DEVICECTL_CHILD_*` 注入启动成功。iPhone 13 无变量回启动台，所有视频已退出。iPad 四接口附件明确为 HTTP 200 / json=true / success=true；WDA 最后仍超时，不能当 ready 使用。工作区 HEAD `9a9941c`，本轮源码/测试/记录未提交，既有修改及 KSPlayer 未跟踪内容全部保留。8 项定向检查、最终相关 2 项复测、iPad 1 项实际环境测试、设备构建/preflight 通过；不能合并这些证据冒充全矩阵或听音验收。
- 下一入口：iPad 需在正常包登录一次并确认记住密码（现 Keychain 恢复无凭据），再补冷启动/后台恢复。系统 UI 自动化初始化问题需继续单独处理；当前屏幕亮/已解锁、Developer Mode Enabled、DDI usable，重启测试守护进程只恢复了原生单元测试。没有当前 VPN UI 状态或开/关 A/B，不改家中远程网络。iPhone 13 下一批仍以 S01 为限，补准备取消受控窗口、单路十分钟/听音与双入口基线，禁止大电影限速转码。

- 09:50 设备网络实测完成：仅重启 iPad 上挂起的 testmanagerd（SIGTERM 后未换 PID，SIGKILL 后 `4564`→`7690`），不改 Mac/路由器/VPN。原生测试实际 1 项 Passed / 0 失败，四个无凭据 DSM/Jellyfin 局域网/公网 API 均成功返回 JSON；当前 VPN 状态尚未由界面确认，不算 VPN 开/关 A/B。该测试进程再次报无 DSM 保存凭据。证据 `ipad-environment/endpoint-probe-v3.xcresult`。正在恢复正常包和 WDA。
- iPhone 13 最终轨道修正实机闭环：热重开 trace `8D996A55` 首帧 762.782 秒；冷续播 `75817272` 首帧 770.697 秒；从头 `4D56A7BC` 首帧 0.073 秒。三次国语选中/字幕关闭均保持、实际画面与停止事件齐全，无本轮新 Nastart 崩溃报告；听音、完整矩阵仍待验。用户偏好与位置现是分别验证，未宣称全部 PX 验收。

- 09:46 最新实机补证：最终 `37b0…` 包 S01 Jellyfin 冷启动续播确认国语/字幕关闭保持，位置约 12:58 且有真实画面；热重开已通过同项。听音、双入口完整矩阵仍待验。iPad UI 自动化仍超时，单元测试宿主已运行，并在 09:45:59 新日志再次报 `restore.missing_credentials`；四接口设备网络测试进行中。

- 09:44 最新候选是 `37b0fc03e608700b0a2bbe1734e7f4690bbe28b35a5cc7ce5b321e7826656f50`（同 `iphone13-next/Nastart.app` 路径），`74f…` 已留作 `Nastart-track-v1.app`。第一版被详情默认 selection 覆盖，最终修正详情加载与停止后的偏好同步，不覆盖详情中用户刚手动选择的轨道。S01 热重开已确认国语/字幕关闭选中与约 12:50 位置；冷启动复测进行中，未听音。最终设备构建与相关测试复测通过。

- 09:33 新发现/修复：S01 Jellyfin 原画暂停 +15/-15 秒时钟恢复 92/369 ms，国语切轨/字幕关闭后退出重开丢失轨道偏好（位置保留）。原因是本地保存只覆盖 `.dsmFile`。已给 Jellyfin 使用服务器/用户/媒体源/文件大小隔离键，在准备前读取有效轨道，保存源轨道而非 HLS 解码器索引；Jellyfin 位置仍使用服务器记录，显式 selection 不被旧偏好覆盖。设备构建和 7 项定向 XCTest 通过，真机复测进行中。新候选包 dylib SHA-256 `74f647ee36c955ef93d55681105fc0e9049037190e3003e87d08d4895c1e5ca5`，路径同下；状态诊断单独版本已留为 `Nastart-status-only.app`。下一会话不可将下面旧 `7f74…` 当最新包。

- 用户已要求 iPad 专项实际测试，早期“仅核实 iPad”范围不再是本轮限制。iPad USB/CoreDevice 可见，安装前诊断确认多次手动登录后重启因无保存凭据跳过恢复；VPN 因果尚未证明。两次 WDA 系统自动化初始化超时，需解锁/确认系统提示。见 [iPad 环境专项](../handoffs/2026-09/2026-09-29-IPAD-ENVIRONMENT.md) 与总账 UX-05。
- Jellyfin `httpStatus` 诊断及登录错误分类不再扫描描述中的任意数字，改用 Get SDK 明确的 `APIError.unacceptableStatusCode`。设备 Debug 构建、2 项错误反例 XCTest 通过；保留数据安装及 S01 回归进行中。新持久包 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-iphone13-next/Nastart.app`，dylib SHA-256 `7f74b29fb1441f8ac4c52b543f8cbecb3aa1f30148f5b0257a80f77c739ace5e`。不将此修正视为已解决 -1017 网络响应问题。
- HEAD 仍 `9a9941c`；全部既有未提交修改保留，本轮新增源码/测试与记录未提交。只使用 S01，禁止大电影限速转码。

## 2026-09-29 白天 iPhone 13 低负载回归（最新现场）

**收尾摘要：** 同一 `46df8558…` 包，iPhone 13 家中 Wi-Fi，S01 双入口各三次退出/热续播，暂停退出、暂停 seek/恢复和两入口冷启动断点均已补实际执行证据。准备中取消未捕获有效窗口；人工声音/连续流畅、静态 HLS 最终时间轴与 iPad 仍待验。播放器全部退出，App 正常启动台、无测试变量；下一批先补准备取消及短片头续播规则/上报响应核查，再考虑单路 S01 10 分钟基线，不进入大电影限速转码。

- 开始只读核对时 HEAD 为 `a5022d25409f1537f4441142863d3d26801d0c39`，既有内容保留，开始时 `git diff --check` 通过；本任务之外后续提交使当前 HEAD 变为 `9a9941c`，见本节记录。起始 status 与 tracked diff 已留本机证据目录。
- USB 实查仅 iPhone 13 `[UDID仅留本机私有证据]`（iPhone14,5 / iOS 16.3.1）和 iPad `[UDID仅留本机私有证据]`（iPad12,1 / iPadOS 18.3.1）；iPhone 18 不在。iPad 实际已存在 Nastart 0.1.0(1) 和 WDA Runner，早晨卡片的“尚未安装”不能继续当作现场事实；未核实其包哈希、WDA ready、登录或播放，仍未验收，本轮不操作其界面。
- iPhone 13 本机 8102 WDA `ready=true`。初始 Nastart PID `45856`、`env={}`、`args=[]`。持久交接包签名验证通过，`Nastart.debug.dylib` SHA-256 `46df855867b2cc37d25309ae4092eddc4d15cf911d80aceeebdc2dc7158ccb26`。由于设备版本号不能唯一识别二进制，本轮用该包经 ios-deploy 覆盖安装（未卸载、保留数据），安装 `InstallComplete`；随后 WDA 无测试变量正常启动。没有重新构建源码。
- Jellyfin 局域网 `System/Info/Public` HTTP 200（10.11.11）；初始 App 资源卡为 CPU 30%、RAM 19%、磁盘 92%（既有空间警告）。重启 App 后 DSM 登录恢复待核实，不能以初始“未连接”判 NAS 故障。下一步等待登录后补资源/实际路径，再 S01 单路 30 秒，禁止大电影限速转码。
- 本轮持久证据：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-iphone13-lowload/`。原始 UI/诊断只留本机，不提交。
- 完成 Jellyfin S01 三次进入/退出同一详情，后两次为“继续观看”；截图实际画面可见，三路均有 `playback_ended`。首轮约 51.9 秒，trace `A1F0CBB3` 首帧时钟 0.052 秒、点击至时钟事件 1260 ms；第二轮 trace `E1F4D0E8` 首帧位置 50.910 秒，末轮 `2CEC7436` 首帧位置 112.116 秒，证明本轮热重开恢复位置。第二轮约 63 秒日志含 `stallCount=1`：发生在首帧前 1043→1834 ms（约 791 ms），首帧后未增加；不记三轮全程零卡顿；声音、人工连续流畅、重启持久化尚待验。媒体实际走本机 Range → NAS 局域网 8096，元数据/上报为公网域名，不能按蜂窝解释。
- Jellyfin 本轮有 `playback_report_failed`（NSURLError -1017 / 无法解析响应，日志 httpStatus=281），但详情继续按钮、重开和 App 存活正常；服务前后 HTTP 200。保留为上报路径待查，不认定服务器断点已保存成功。退出后某些 WDA 完整 UI 树查询超时，截图和点按仍成功；无证据将其归因于 App 崩溃。实际截图及 `jf-final-confirmed/` 诊断留本机。下一步设备文件 S01，再准备中离开与 App 重启断点。
- 设备文件 S01 同一 2.7 GB MKV：完成从头播放约 34.6 秒、退出回同一文件预览、两次继续观看重开及退出，共三次往返；第二轮补暂停后退出。真实画面截图、暂停截图及 `file-final3/` 诊断已留本机。首轮 trace `F0C1503F` 首帧时钟 0.073 秒、点击至时钟事件 622 ms，退出时卡顿计数 0；实际原画上游为局域网 DSM FileStation 5000，不代表与 Jellyfin 首帧的严格 A/B。同条件基线、听音/音画同步、重启断点仍待验。复制真机 Nastart 崩溃报告保留设备原件，最新仍为 9 月 28 日 20:21，没有本轮新报告。
- 设备文件补充诊断（`file-full-final/`）：第二轮 trace `62930273` 首帧 34.121 秒、暂停 89.31 秒、停止；第三轮 `8103139A` 首帧 89.460 秒、停止，恢复误差约 0.15 秒（播放器时钟事件，不是帧级听音验收）。准备中取消尝试先点击“从头播放”再返回，但截图已是播放器呈现/旋转，之后真实进入播放；没有捕获准备中离开，已退出清理，**不得计为取消通过或取消失败**，该项继续待验。此尝试确实播放了 S01，不是静态素材，也没有大文件转码。
- 冷启动短断点核对：设备文件持久化值 15.582 秒，重启 App 无测试变量/DSM 恢复登录后，trace `A4381270` 首帧时钟为 15.646 秒（差约 0.064 秒），点击至时钟事件 3775 ms；3 秒时的首张截图仍是黑屏/启动状态，后续日志推进到约 33.8 秒并有停止事件，未取得冷启动首帧之后的真实视频截图，视觉闭环仍待补。Jellyfin 冷启动详情没有继续按钮，trace `66BF11B2` 从 0.137 秒开始，短片头断点跨进程没有恢复；尚未核对服务器续播规则，不能直接认定是客户端丢断点。正在补约十分钟位置的暂停 seek→播放→退出→冷启动对照。
- 工作区复核发现本任务之外于 07:26:57 提交了 `9a9941cd4ec82625f680b5193b3a0f66797eb851`（37 个文件，原播放/脚本/文档修改进入该提交）；本任务没有执行 commit/reset/clean。起始只读检查时为 `a5022d2`，持久快照采集时已提交，所以 `git-diff-start.patch` 为零字节。当前仅本轮三份记录文件为 tracked 差异，原 KSPlayer 未跟踪目录仍保留，播放源码本轮没有修改。不能继续把“全部既有修改尚未提交”当当前现场。
- 上报日志中的 `httpStatus=281` 未经 HTTP 响应核实：现有 `httpStatusCode(for:)` 会从错误描述任意数字推断状态，故该字段本轮只能当原日志值；确定的错误是 NSURLError -1017。后续需核对真实响应及服务器保存结果，不以 281 判定 NAS 故障。
- Jellyfin 深位置断点对照完成：S01 暂停后 slider 定位到 624.415 秒，`23CDB28A` 引擎完成/时钟恢复约 1475 ms，恢复播放截图见约 10:26，退出前末个 tick 627.785 秒；再次无变量重启 App 后详情显示“继续观看”，trace `DC9225F1` 首帧 628.510 秒（点击至时钟事件 1086 ms），真实影片画面可见并已退出。由此本轮**十分钟位置的跨进程续播成功**；两分钟短片头从头开始的原因尚未核对服务器配置，不能写成普遍断点丢失。该暂停 seek/恢复是单次探索性回归，不代替三对性能基线或听音验收。
- 设备文件冷启动视觉复核补齐：再次无变量重启 App，持久化 S01 位置 34.036 秒，trace `B73C6427` 首帧时钟 34.110 秒（差约 0.074 秒，点击至时钟事件 2127 ms），8 秒时截图见真实城堡画面，退出回同一预览并有停止事件；证据 `last-cold-file-{detail,play,exit}.png` 与 `final/` 诊断。此前黑屏启动截图的限制由此轮后续视觉闭环补齐，不代表所有冷启动首帧统一耗时。
- 07:55 收尾：iPhone 13 与 iPad USB 仍在；iPhone 13 WDA ready，Nastart PID `46268`，`env={}`/`args=[]`，前台为正常启动台。Jellyfin 局域网及公网公共接口均 HTTP 200。刷新后 NAS CPU 44%、RAM 19%、磁盘 92%，运行时间 10小时57分钟（初始 10小时25分钟），本轮没有观察到运行时间重置；未取 NAS 系统日志，不作重启原因结论。再次保留原件复制 Nastart 崩溃报告，最新仍是 9 月 28 日 20:21。WDA 为避免动画等待在本轮设置 `waitForIdleTimeout=0`、`animationCoolOffTimeout=0`；这些是自动化会话设置，App/系统网络没有调整。
- 本轮仅修改三份记录文件（本文件、跨账号卡、唯一总账），源码未改、未重建、未执行 git commit/reset/clean。初轮导航/断点结果不等于 PX 项整体已验收；PX-01/PX-02/PX-03/PX-20/PX-21 状态保持进行中，其他所有编号状态保留。原始证据、包身份与本轮索引在上述持久目录，禁止上传含连接信息的 plist。

## 2026-09-29 早晨最新检查点（优先读）

- 用户已把 iPhone 18 切至蜂窝网络，约 07:00 会带走，iPhone 13 留家中 Wi-Fi。两机 USB 接入本机；iPhone 18 UDID `[UDID仅留本机私有证据]`，iPhone 13 UDID `[UDID仅留本机私有证据]`。HEAD 仍为 `a5022d25409f1537f4441142863d3d26801d0c39`，保留现有大量未提交修改。
- Jellyfin 搜索中《碟中谍 2》约 54.92 GB / 64 Mbps、《碟中谍 3》约 54.01 GB / 62.7 Mbps，均为 4K H.265 HDR 高码率片源；它们不比《指环王》更适合在 NAS 曾重启的现场做多路弱网转码。因此本轮没有请求这些影片的视频流。Jellyfin 仅用于进入详情 UI，弱网播放走独立的预编码 Apple HLS 素材。
- 新增 `#if DEBUG` 且仅显式设置 `NASTART_TEST_STATIC_HLS=1` 时启用的静态 HLS 测试入口；高档约 8 Mbps、低档约 1.3 Mbps。Debug 媒体代理限速也仅在带测试环境变量的 Nastart 进程内生效，不改 iPhone 的蜂窝、Wi-Fi 或 VPN 系统设置，不启动 NAS 编码器。Apple 测试素材地址及实测见 [蜂窝记录](../handoffs/2026-09/2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md)。
- iPhone 18 4G 实测：高档首帧时钟约 6.25 秒；5 秒后开始 2.4 Mbps 限速，实际样本约 2.23 Mbps；播放时钟约 7 秒即请求自动降档。候选于 22:29:47 UTC 解码、22:29:51 UTC 时钟对齐并接手，接手时旧流缓冲约 0.33 秒，新流缓冲约 6.5 秒；新流首帧事件距交接约 86 ms。两路在首帧后的采样均 `accessLogStalls=0`、`bufferEmpty=no`；新流继续至约 62.5 秒、缓冲约 40.6 秒。原始诊断 `/tmp/nastart-v9-followup.plist`，trace `50C76D01`→`10BBEF9D`。这证明可控降速时完成自动交接；没有真人连续观看或外部摄像机证据，不能宣称无感验收完成。
- 测试进程已用不带环境变量的 `devicectl device process launch --terminate-existing` 重启，WDA 核对 iPhone 18 Nastart PID `13339`、`env={}`；Jellyfin 公共接口 HTTP 200。系统网络设置本轮未动。设备文件匹配 Jellyfin HLS 的准备流现在注册清理器，退出/放弃候选时会注销代理并调用 Jellyfin `stopEncodingProcess`；相关 3 条定向测试通过。静态 HLS 的 v9 签名 Debug 构建 `/tmp/nastart-static-hls-v9-build.log` 成功。另有收尾修复的最终编译/两机安装状态见本节后续追加记录；接手须重新核实。
- iPhone 18 WDA 当前本机 `8104→8100`，XCTest/转发 PID 可能随时变化；iPhone 13 WDA `8102→8100`。iPhone 13 已安装清理修复版并启动，最终静态测试版是否同步安装见后续记录。继续调试时优先避免再次向 NAS 发起大影片限速转码；真实 Jellyfin 大片场景仍待 NAS 稳定后单路验证。
- 06:34 收尾：设备文件 HLS 准备响应即使字段无效，也会调用 `stopEncodingProcess` 关闭已创建的服务器会话。最终签名 Debug 包 `/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app` 的 `Nastart.debug.dylib` SHA-256 为 `7d7690a9f788fcc19677a747ccb75858d4aa79dd77d275e228d656e48617e473`；标准 workspace 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-sept29-final-build.log`。该包已安装两机（安装日志 `/tmp/nastart-sept29-final-iphone18-install.log`、`/tmp/nastart-sept29-final-iphone13-install.log`），并以无测试变量正常启动；WDA 核对 iPhone 18 PID `13366`、iPhone 13 PID `45709`，两者 `env={}`。`git diff --check` 通过。静态 HLS 自动交接实测发生在最终编译前的 v9 包；最终源码只多了一处服务器会话清理修复，没有重跑同一真机播放。
- 收尾又停止了 iPhone 18 的 WDA XCTest 与本机 8104 转发，App PID `13366` 仍存活；iPhone 13 的 8102 WDA `/status` 仍为 `ready=true`，方便留家远程调试。Jellyfin 公共接口 HTTP 200。上述“iPhone 18 WDA 当前 8104”仅描述停止前现场；下一会话须重新启动 WDA 才能控制它。

## 2026-09-29 06:54 设备文件安全测试接续

- 继续补设备文件入口的弱网交接。最初把静态 HLS 挂在常规“从头播放”分支；WDA 创建会话后可能重新启动 App，测试环境变量未生效，第一次点播 26 GB《Spider-Man 2》文件时实际进入了约 1.5 Mbps 的 Jellyfin 匹配转码，trace `87223463`。发现播放器显示真实影片标题/时长后立即替换 App 进程停止播放。Jellyfin 公共接口持续 HTTP 200；未取得 NAS 系统日志，不能据此判定 NAS 是否受到额外压力。后续自动化不得以普通播放按钮推定测试隔离已经生效。
- 已将设备文件静态测试改成 **只有 `NASTART_TEST_STATIC_HLS=1` 时才出现的独立 Debug 按钮“静态 HLS 弱网测试”**，常规播放不再被测试代码拦截。必须先在 UI 树确认该按钮出现，再点击；播放页标题须为 `Static HLS fixture`。26 GB 文件详情上按此流程实测，视频请求为 Apple 静态 HLS；没有请求该文件视频流。iPhone 18 4G 下高档 trace `86961AEB` 首帧约 4.89 秒，5 秒后限速到 2.4 Mbps，实测约 2.22 Mbps；约 13.5 秒播放位置发起降档，低档 trace `258309A5` 解码、对齐、接手。旧流交接前约 2.82 秒缓冲，候选约 6.96 秒，新流首帧事件约 54 ms；交接附近两路样本 `accessLogStalls=0`、`bufferEmpty=no`。原始诊断 `/tmp/nastart-sept29-filefixture-t20.plist`。缺真人观看/声音证据，不能定为无感验收。
- 此轮发现 Debug 素材给 `.dsmFile` 候选重复附加时间轴偏移，使 `firstFramePositionSeconds` 报约 37 秒而实际播放器时钟约 24 秒。已将静态素材时间轴偏移固定为 0；最终标准 workspace Debug 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-sept29-filefixture-final-build.log`。最终包 `Nastart.debug.dylib` SHA-256 `96fd636d74080854a11085871f8d0cd0ea44bc959970afdd25b71a034ab58874` 已安装两机，日志 `/tmp/nastart-sept29-filefixture-final-iphone{18,13}-install.log`。时间轴修正后试图复核，App 文件页提示“DSM 当前未连接”，故未继续请求视频；该修正尚未真机重验。
- 已结束所有 iPhone 18 带限速变量的进程，用无变量命令正常启动；WDA 核对 iPhone 18 PID `13536`、iPhone 13 PID `45837`，均 `env={}`。iPhone 18 WDA XCTest 与 8104 转发已停止，iPhone 13 的 8102 WDA 保留。Jellyfin 公共接口 HTTP 200，`git diff --check` 通过。系统 Wi-Fi、蜂窝、VPN 设置均未由本轮改变。下一步先核对 DSM 会话/服务是否稳定，再用独立按钮短测最终包的时间轴和交接；真实大片与设备文件匹配转码仍需 NAS 稳定后单路验证。
- 06:57 最终安全收尾：Jellyfin 详情页也改为独立的 Debug“静态 HLS 弱网测试”按钮，普通播放按钮不再受测试变量拦截。最终签名 Debug 包 `Nastart.debug.dylib` SHA-256 `46df855867b2cc37d25309ae4092eddc4d15cf911d80aceeebdc2dc7158ccb26`，标准 workspace 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-sept29-safe-buttons-build.log`，已安装两机（`/tmp/nastart-sept29-safe-buttons-iphone{18,13}-install.log`）。iPhone 18 用无环境变量命令正常启动，PID `13557`；iPhone 13 WDA 正常启动 PID `45856`、`env={}`。此最终按钮版本只完成构建/安装/启动，未重复视频短测；上段设备文件自动交接实测属于按钮已独立、时间轴偏移尚未修正的前一包。
- 06:58 只读诊断复核：DSM 文件页的“未连接”发生在新进程恢复登录期间；该设备诊断随后记录 Nastart/FileStation 登录成功和资源快照完成，但登录历时约 20–30 秒。不能据那一屏判断 NAS 已离线，也未在登录完成后重试视频。诊断副本 `/tmp/nastart-sept29-dsm-final.plist` 含连接信息，仅留本机。Jellyfin 公共接口依旧 HTTP 200。

## 先读与当前目标

项目：`/Users/lagransun/workspace/Nastart`。

1. [本轮播放就绪度审计](../handoffs/2026-09/2026-09-28-PLAYBACK-READINESS-AUDIT.md)：回答功能成熟度、开口项和矩阵准入。
2. [常态远程流程](../../development/remote-playback-routine.md)、[分层回归](../../development/playback-development-workflow.md)：白天 iPhone 13/后续 iPad，晚上用户及 iPhone 18；按修改影响选回归，不每次重跑 76 单元。
3. [唯一任务总账](../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)、[19×4 矩阵](../../testing/PLAYBACK-FUNCTION-MATRIX.md)、[ADR 0002](../../adr/0002-single-playback-optimization-mainline.md)。手动清晰度入口暂缓，不删除、不记通过。Greenfield 唯一优化主线，旧实现保留回退，暂未迁移 Release。

用户最新要求是完成源码审计及双账号远程接续方案；不要把审计表里每个缺口都直接当成本轮全面开发任务。

## 工作区与安装状态

- HEAD `a5022d25409f1537f4441142863d3d26801d0c39`，有大量既有未提交源码、KSPlayer、脚本与文档修改。接手先读 git status/diff；不要 reset、清理或覆盖未知修改。不要只用 commit/0.1.0(1) 判断包是否最新。
- 前序已修复 `AppTabRootView.swift`：iPhone 不再随 horizontalSizeClass 切换根导航。实源码模拟器反例通过；修复包安装 iPhone 13 并确认启动，**真实视频退出尚未复测**。
- 最近有安装记录的包：`/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app`。安装日志 `/tmp/nastart-navigation-return-iphone13-install.log`。不能由此保证当前设备仍是该包，重新核实。
- iPhone 13：UDID `[UDID仅留本机私有证据]`，上次系统 iOS 16.3.1。已验证 USB/libimobiledevice/ios-deploy；CoreDevice 不支持不等于离线。WDA 常用本机 8102→设备 8100，接手必须检查服务是否运行。
- iPhone 18：交接时尚未核实 USB 接入或安装修复包；本文件下方 20:30 检查点已补实测。iPad 后续接入。
- NAS 先前有重启/资源压力记录；默认单路，先正常短时再长时。不要更改承担远程连接的路由/VPN 来造弱网。

## 最新验证与优先事项

- 前次审计的 generic iOS Release 编译失败，`DevicesView.swift:1215` 引用 DEBUG 专有标识；本文件下方检查点已重跑并通过标准 workspace Release 构建。
- 2026-09-28 晚模拟器测试日志报告 109 项、0 失败，但 xcodebuild 在测试结束后收尾卡住数分钟，采样保留后终止；没有正常完成标记，不算整套工具运行通过。日志 `/tmp/nastart-audit-tests-resumed.log` 与 `nastart-audit-xcodebuild-hang.txt` 已留本机证据目录；下午中断的那次同样不能算整套通过。后续需定位测试工具收尾问题，不能把它当作某个测试断言失败。
- 下一开发工作包：双入口退出回详情与重开；准备中离开/连续选片/旧响应晚到；S01/S03 稳定性与断点。静态风险需复现或用证据排除，不直接宣称已发生。
- 随后 S01/S03/S08 代表片基线，再补弱网候选对齐交接；完整矩阵前规范字段、构建身份及证据索引。HDR+PiP 字幕、自动连播、高级字幕等缺口见审计。
- 不把日志进度增长当实际画面流畅/声音可听/HDR 输出证明。缺人工和设备项目保留待验。

原始日志与源码差异指纹等本机材料：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-28-readiness/`。临时工具的会话 ID、进程 ID 在新会话中不能假定有效。

## 2026-09-28 20:30 接续检查点

- HEAD 仍为 `a5022d25409f1537f4441142863d3d26801d0c39`；既有未提交修改保留。本次仅更新本交接文件，未修改播放源码。两机均由 `idevice_id -l` 识别：iPhone 13 `[UDID仅留本机私有证据]`（iOS 16.3.1），iPhone 18 Pro Max `[UDID仅留本机私有证据]`（iOS 27）。Jellyfin 公共信息接口测试前后 HTTP 200。
- 两机已安装同一 Debug 包：`/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app`，其 `Nastart.debug.dylib` SHA-256 为 `fe6b5acd0fe3a5dff0e4774a9689b8c2555bbe8458d8c221c12de87cdc68510d`。iPhone 18 安装日志 `/tmp/nastart-preparation-iphone18-install.log`；iPhone 13 本次 USB 安装日志 `/tmp/nastart-handoff-iphone13-install.log`。iPhone 13 需用 `ios-deploy` 安装，当前 CoreDevice 不能按其 UDID 查到 iOS 16 设备。
- iPhone 18 真机 S01《哈尔的移动城堡》设备文件入口：原有播放画面退出回同一文件预览，点“继续观看”后再次显示真实视频画面。Jellyfin 入口：从搜索结果详情进入新架构，看到真实首屏画面，点“完成”回同一 Jellyfin 详情，点“继续观看”再次看到真实画面，再次退出仍回详情。这只覆盖短路径；未据此证明声音、长时流畅、断点精度、自动降档或完整矩阵通过。截图仅在本机 `/tmp/nastart-handoff-iphone18-jellyfin-s01-{first,reopen}.png` 等处，不纳入仓库。
- Jellyfin S01 后续又完成一次短进出导航（共两次）；第三次尚未开始时微信通知使 WDA 前台快照短暂切为 SpringBoard，App 进程仍在，通知消退后又显示同一详情页。未将自动化中断记作 App 故障，也未计为第三次通过。
- iPhone 18 在先前设备文件重开后，创建新的 WDA 会话时 Nastart 进程退出；未取到对应崩溃报告，原因不明，不能归因于 App。其后普通启动及上述 Jellyfin 往返均成功。测试已退出播放器，没有设置限速环境或改路由/VPN。
- 当前 `PlaybackPreparation` 通过请求 UUID 和取消标识拒绝离开详情后的晚响应及旧请求覆盖；`PlaybackNextCoreTests.swift` 中两条确定性测试本次定向重跑 `2 tests, 0 failures`，xcodebuild 正常以 `** TEST SUCCEEDED **` 结束，日志 `/tmp/nastart-handoff-preparation-tests.log`。真机“准备中离开/连续选片”仍未完成。
- generic iOS Release：直接用 `.xcodeproj` 编译已越过先前 `DevicesView.swift:1215` 错误，但因绕开 Pods workspace 在链接时缺 `MobileVLCKit`。改用标准 `.xcworkspace` 后 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-handoff-release-workspace-build.log`。这只证明当前源码可编译，不代表 Release 真机功能已验。
- iPhone 13 安装后用 `ios-deploy --justlaunch` 启动出现一次 `SIGTRAP` 报告 `/tmp/nastart-handoff-iphone13-crashes/Nastart-2026-09-28-202102.ips`；报告没有可用线程栈，且该路径紧接调试器 `safequit`。随后通过 WDA 常规启动和一次 terminate→launch，Nastart 均显示启动台并保持进程，未生成更新的崩溃报告。不能把该 SIGTRAP 单独认定为普通用户启动闪退；后续仍需无调试器冷启动复测。
- iPhone 13 在同包、家中 Wi-Fi 上又完成 Jellyfin S01 一次新架构播放：屏幕见实际影片画面，点“完成”回《哈尔的移动城堡》详情，“继续观看”出现，Nastart PID `42144` 在退出后仍在。证据截图 `/tmp/nastart-handoff-iphone13-jellyfin-s01-play.png` 与 `...-after-exit.png` 仅留本机；尚未测声音、长时稳定、断点精度或 iPhone 13 设备文件入口。
- 当前 iPhone 13 WDA `8102→8100`、iPhone 18 WDA `8104→8100` 均曾返回 `ready=true`；接手重新核对，不沿用会话 ID。iPhone 13 启动截图 `/tmp/nastart-handoff-iphone13-startup.png`。后续先补 S01/S03 定向稳定性与准备中取消，再做代表片持续播放及弱网自适应；NAS 有过重启记录，保持单路、先短后长。
- 20:34 收尾核对：Jellyfin HTTP 200（约 0.10 秒）；iPhone 13 Nastart PID `42144`、iPhone 18 Nastart PID `10637` 均在，播放器已退出；iPhone 13 无 20:21 后的新 Nastart 崩溃报告。两机截图状态栏均显示 Wi-Fi 图标，本轮不能按蜂窝弱网结果解释。未设置限速，也无网络环境需要恢复。

## 2026-09-28 21:05 蜂窝自动降档检查点

- iPhone 13 在家中 Wi-Fi 上完成设备文件 S01 一次播放、退出、继续观看重开，实际画面可见且进程存活；证据仅在本机 `/tmp/nastart-next-iphone13-file-s01-*.png`。iPhone 18 已切蜂窝 4G，本次 Debug 进程限速 S19 由 4 Mbps HLS 降至约 2.2 Mbps 传输能力，自动请求 1.5 Mbps 候选，第二次候选解码与时钟对齐后实际接手。
- 接手时新播放器缓冲只剩 0.07 秒并停在 2:29，**自动降档尚未通过流畅验收**。源码修复见 `GreenfieldVideoPlayerView.swift`：预热期为追时钟而关闭的 AVPlayer 自动等待，在接手时恢复；预热流接手后保留 3 秒前向缓冲目标，并记录交接时播放意图与缓冲。标准 workspace Debug iphoneos 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-adaptive-handoff-build.log`；签名包已安装两机。iPhone 18 用无测试变量启动，WDA 显示 PID 11028、`env={}`；iPhone 13 经 WDA 常规激活，PID 42436、`env={}`，安装日志 `/tmp/nastart-adaptive-handoff-iphone13-install.log`。真机降档复验未开始。完整诊断见 [蜂窝测试记录](../handoffs/2026-09/2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md)。
- 此轮后 NAS 的 DSM/Jellyfin 局域网与公网入口失联，Mac 路由器和外网仍可用；原因未知，停止真机视频请求。约 21:06 DSM 局域网已恢复 HTTP 200，Jellyfin 局域网连接仍被重置、公网仍返回 502。iPhone 18 限速进程结束，系统网络配置未更改。Jellyfin 恢复后先确认服务与负载，再单路短时复验；不要把候选接手事件当成无感切换通过。
- 21:10 以后 Jellyfin 公网接口在 200 与 503 之间波动、局域网 8096 仍曾连接重置；iPhone 18 的启动台截图显示 4G、NAS CPU 70%、磁盘 92%、Jellyfin 灰点。暂不启动视频转码。只读检查还发现 2.2 Mbps 实际传输能力下安全上限约 1.1 Mbps，但旧策略最低强制选 1.5 Mbps；已补 1 Mbps、750 kbps、500 kbps 档。定向测试 `testAdaptiveTargetFitsCapacityAndStepsDownAgain` 正常 `** TEST SUCCEEDED **`，日志 `/tmp/nastart-adaptive-low-bitrate-test.log`；标准 workspace Debug iphoneos `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-adaptive-low-bitrate-device-build.log`。
- 最新签名 Debug 包已再次安装 iPhone 18 与 iPhone 13；iPhone 13 安装日志 `/tmp/nastart-adaptive-low-bitrate-iphone13-install.log`。两机用无测试变量常规启动，WDA 分别显示 iPhone 18 PID 11075、iPhone 13 PID 42470，`env={}`。新低码率档及交接缓冲修复均未做真机视频复验。
- 约 21:15 Jellyfin 公网接口连续三次 HTTP 200，iPhone 18 启动台显示 4G、Jellyfin 在线、NAS CPU 57%。准备复验时，WDA 的完整 UI 树查询卡住；恢复 WDA 后屏幕显示手机已切到其他个人应用，表明设备当时正在被使用。**没有启动视频或限速**，立即停止界面操作并删除该私人屏幕临时截图。后续真机操作需待用户确认手机空闲并回到 Nastart；WDA 重启日志 `/tmp/nastart-adaptive-wda-restart.log`，新会话 ID 不应沿用。

## 两个账号轮换方案（尚未实机演练）

官方 Remote 要求手机与桌面主机使用同一账号及工作区；切账号会使旧身份的远程会话失效。只在手机换号不能保证接管 Mac。配对从桌面 Settings → Connections → Control this Mac or PC 开始，再用手机扫码和完成身份验证。

因此建议先在家准备一个独立于 ChatGPT 额度的远程桌面访问方式，并用手机外网做完整演练：停止 A 当前修改/设备操作、更新交接文件 → 从独立通道进入 Mac → Mac 和手机均切 B → 检查 B 的 Remote 配对，必要时重建 → 在 B 打开同一项目，新会话读本文件接续。扫码在同一手机远程画面中的可行性及登录验证必须提前实测；不能承诺无人值守自动切换。本轮未配置远程桌面、未切账号。

未找到官方支持把两个账号的额度或历史会话合并后原地接续的流程。工程接续以本机文件为准；不要复制认证缓存或依赖旧账号聊天自动出现在新账号中。单一工作区/单台测试手机同一时间只由一个会话写入和控制；另一个账号先停止后再接手。

每批结束或额度接近用尽时，更新本文件的当前包、实际通过/失败、在跑进程与下一步。这样即使额度突然用尽，也有上一检查点可读；接手还需核对现场，不能假定记录之后没有变化。

官方依据（2026-09-28 查询）：[Remote connections](https://learn.chatgpt.com/docs/remote-connections)、[账号切换使旧远程会话失效的更新记录](https://learn.chatgpt.com/docs/changelog)。

给新账号的起始指令：

> 打开 /Users/lagransun/workspace/Nastart，先读取 docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md 及其中的审计和总账，再核实工作区、设备和当前构建。沿既定播放主线继续，保留未提交修改，按影响范围回归；先报告已完成与待验证的边界，不从头重建方案。

2026-10-09T15:42:51.658405+08:00：两机最新8f5c/da56/KSeda1普通包现场USB/配对/型号系统/签名/安装核对完成，保留数据覆盖，25/16项非诊断偏好一致，空环境正常启动与实际正常启动台已逐机核实；iPhone14,5/iOS16.3.1及iPad12,1/iOS18.3.1；完整UDID在私有安装证据。新源手机S03文件180秒复测开始，未将旧包播放算入。
