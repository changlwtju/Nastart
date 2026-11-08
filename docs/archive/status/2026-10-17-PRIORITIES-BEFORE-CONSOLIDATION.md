<!-- Historical snapshot: superseded on 2026-10-17; use current handoff. -->

# 播放体验优先级

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

## 2026-10-13 Jellyfin 切网播放已恢复，蜂窝 seek 与续播仍开放

- 当前 dirty 源8979d86352（HEAD 4de732dd），普通Debug 21:54:50；370测试/2跳过/0失败，15预检、构建、173输入、29库独立签名/deep/profile/IPA三SHA核对。任务局部不可变独立认证上下文统一准备/字幕/播放/上报/清理；不搬token，不临时全局换client，不改媒体参数或原书签身份算法。内网传输失败仅触发当前公网自己的认证，公网正响应必须属于当前网络/登录/凭据。
- 最新包13 21:56:55、Pad21:56:49保留数据覆盖，25/18项安装偏好保持，空env/args正常实际首页；现场身份/包门槛逐窗执行。13原WiFi详情→蜂窝S11/S03已取得真实片头/影片，内部首帧从外层触摸约6.125/6.476秒；不能用内部1569/1898ms代替用户完整等待。±15引擎恢复S11 12396/14249ms、追加S03 8163/6943ms，有实际转圈/等待，性能仍未验收。
- S01双机双入口4窗，以及受影响S03/S08/S11/S18 Jellyfin双机8窗：30秒稀疏采样/实际PNG/普通退出完成。S08两机t10仍黑、t30影片；Pad S18首次工具误用“方世玉2”，实际标题“方世玉续集”，原TOOL和crash pull留证后补测。不是完整L2/连续流畅/全SUB/AUD/HDR/听音或速度排名。
- 追加S03“resume-seek”目录实际只有普通播放按钮，从0开始，不能计续播；旧原S03书签未变，其他既有源书签自然变化，需相同MediaSource身份再核冷续播/服务端持久保存。最终24/17非书签偏好逐值不变，各6自然书签变化、原S03文件/JF轨保持；WiFi恢复ON、正常首页/播放器关闭/idle10动画2/原生条件active0；Nastart/WDA/Jetsam实际报告集合0新增。保留最新13 22:02的2条119，最终滚动日志0不覆盖早期失败，0logout只属于捕获范围。
- iPhone18用户重新授权并完成亮屏同WiFi后，当前既有无线TCP配对身份iPhone19,7/27.0可核实，但HouseArrest/用户态隧道断开；保存故障后独立尝试保留数据覆盖，AFC在创建传包暂存目录时断开，清理再报ConnectionReset，IPA未上传且Install命令未发送、未见InstallComplete/lookup，本包仍未装18。最后确证已装仍为f58/20:34:43且UI未验，不把本候选元数据当安装事实；未改Mac VPN/配对记录，未重装WDA。
- 8864/1cc4/028f/147d失败候选全部保留，路径等待或等值比较不是原故障单独根因修复。下一步蜂窝seek目标分片与媒体源一致的续播配对；18服务恢复后覆盖最新；119、PadTS02、旧13Network物理内存、增长TS、旋转、全SUB/AUD/HDR/PiP、竞品完整帧、弱RF/外部WiFi/十分钟/S19/MTP/19×4/PX/UX/CB/Main/L3旧账全保留。

详见[本轮交接](../handoffs/2026-10/2026-10-13-AUTHENTICATED-PLAYBACK-CONTEXT.md)。

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


## 2026-10-13 播放器圆形按钮轮廓修复

- 更新时间：2026-10-13T03:39:55.631036+08:00。对照用户照片同一R02抖音直播录制MP4，USB13旧最新3e3aa7包已复现：黑色半透明圆底跨到黑色留边时融入，左右外圆边缘不可见。叉号/44点点击区域完整；不是本窗实际裁切证据。旧字体/位置候选未被认定为根因。
- 仅改LaunchpadView.swift：共享圆形按钮加1点白色24%边框，三个点复用同helper，边框不截获点击；布局/字体/安全区/播放引擎不变。HEAD4de732dd、dirty源e82a5bde，普通Debug主6113a756/Debuga2f7a36a/KSe68d7420。173输入/29逐库签名/深验/profile/IPA/链接和最终三SHA核验；本轮实际344测试、2跳过、0失败及15预检。
- USB13和Pad R02横竖屏实际原图圆环完整，两机更多菜单打开/取消与关闭返回详情正常；S01文件/Jellyfin四入口选定实际画面与完整圆环、普通关闭已核。13旧/新留边边缘同像素RGB0→61补强对照，非帧性能证据；未验EOF、反向横屏、物理圆角及大字体等其他裁切场景，不作全播放/音频/HDR/性能PASS。
- 03:28:07 USB13、03:26:51 USBPad、03:29:23既有配对无线18保留数据覆盖同最新包成功，安装时25/18/25项非诊断偏好不变；现场名称/型号/系统/UDID/连接逐机重核，原始身份/凭据/偏好/图仅私有。18本轮未启动/实际UI与自动隧道仍待验，不因安装成功关闭这些项。
- 最终USB13原24/Pad原17非书签偏好逐值不变，各3个R02/S01文件/JF书签自然保存，原S03文件/JF整条未动；两机空env/args实际首页/NAS正常/播放器关闭，idle10动画2。初始baseline工具准入拒绝及纠正保留；本轮未取崩溃清单，不宣称0新崩溃。其他dirty/网络/系统/登录/NAS录制配置未改，无卸载/清数据/手写偏好。
- 下一步回到增长TS旧尾部等待、追加后恢复与时长刷新/录制结束/替换文件负例，再HDR PiP/历史字幕原句和代表集。全SUB/AUD/HDR/蜂窝/完整帧Lenna与DS One、全PX/UX/CB/Main/MTP/L2/L3、475/119/HLS等旧总账保留；S01本轮只有UI控制层检查，不能替代完整播放矩阵。

详见[本轮交接](../handoffs/2026-10/2026-10-13-PLAYER-CHROME-CIRCLE.md)。


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


2026-10-10T20:33:24.364644+08:00 前台刷新入口取消定向收尾：8受控场景基线2场景/5断言失败，两个入口检查取消；最终298测试/2跳过/0失败、15预检/18工具测试。正常刷新复用原dataSource/client，90秒冷却/五分钟新鲜度未改。源5ec2da72普通ba52/5e0c、173输入/29库，13/iPad/18保留数据更新与25/16/25安装偏好一致。双机四正常前台返回、六目录重开、四S01双入口60秒窗/四正文/四原退出，24新目录success、0目录API失败、0读取失败；取消/POSIX信号不丢弃、采样计数不判流畅。最终双机实际NAS/DSM/JF在线、播放器闭合/空环境/active0/idle10/动画2。18新包无线安装成功，4016/InvalidService阻塞正常启动及实际UI；不验18播放。中间测试接口包2d10两iPad窗单列，不沿用。119服务端原因/保存收敛/原弱网/旧ordinal0/完整帧/Lenna、监控及服务健康专用归属和全部PX/UX/CB/L2/L3/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-10-FOREGROUND-OWNERSHIP.md)。

2026-10-10T18:07:39.303464+08:00 前台刷新入口取消修复进行中：8受控场景、2场景/5断言基线失败，两个入口检查Task.isCancelled；最终298测试/2跳过/0失败、15预检/18工具测试。新源2d10普通bc17/85e1（173输入/29库）已构建验签，逐台安装与L1前台恢复/S01双入口回归待完成。18现场仍仅无线，本批安装/启动尚未完成；119/保存收敛/弱网/帧/竞品及正式全矩阵仍开放。 见[本批交接](../handoffs/2026-10/2026-10-10-FOREGROUND-OWNERSHIP.md)。

2026-10-10T17:31:46.140538+08:00 显式退出登录尾部保护定向收尾：5受控HTTP场景基线3失败，按角色重核当前会话后全通过；最终290测试/2跳过/0失败、15预检/18工具测试。源08e7普通4272/ed72、173输入/29库，13/iPad/18保留数据更新与25/16/25偏好一致。双机各三目录重开、S01/S03双入口八60秒窗/八正文/八原退出，38新目录success、0目录API失败、0读取失败；启动传输取消/POSIX及方向更新信号不丢弃，采样计数不判流畅。最终双机实际NAS/DSM/JF在线、播放器闭合/空环境/active0/idle10/动画2；其他服务橙警告保留。18新包无线安装成功，4016/InvalidService使正常启动及实际UI未验，无18播放。已发出logout的服务端顺序、119原因/手机保存收敛/旧退出异常/原弱网/ordinal0/帧/Lenna及全部PX/UX/CB/L2/L3/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-10-SIGNOUT-OWNERSHIP.md)。

2026-10-10T17:14:48.282562+08:00 显式退出登录尾部保护进行中：5受控HTTP场景基线3失败，最小改用当前会话按角色重核，290测试/2跳过/0失败、15预检/18工具测试；新源08e7普通4272/ed72逐机保留数据更新13/iPad/18，25/16/25偏好一致。13/iPad正常空环境实际启动已核，iPad三目录重开完成，S01/S03双入口串行回归中，前包窗口不沿用。18正常启动/实际UI仍因4016/InvalidService受阻。已发送logout的服务端顺序、119/旧退出异常/弱网/帧/Lenna及全矩阵继续开放。 见[当前批次](../handoffs/2026-10/2026-10-10-SIGNOUT-OWNERSHIP.md)。

2026-10-10T16:37:04.403393+08:00 NAS恢复/手动登录任务归属定向收尾：7反例19失败断言与缓存失效4失败断言先行；20新场景，最终285测试/2跳过/0失败、15预检/18工具测试。仅6源码文件，新源c511普通f260/0649/KSeda1，173输入/29库/签名，13/iPad/18保留数据更新；13/iPad25/16偏好及实际普通启动已核。双机各三次目录重进、四S01双入口60秒/四正文/四原退出、24新目录success，0采样stall不判流畅；Pad一次SocketError重试/启动POSIX及取消事件保留。双机最终NAS/DSM/JF绿、播放闭合/空环境/active0/idle10/动画2，其他橙警告保留。18无线安装成功/25偏好一致，4016/InvalidService使正常启动及实际UI未验。中间包桌面退出未知原因、误导航及1002ms等待独列。显式signOut挂起logout与新登录SID重用、119根因/手机保存收敛/原弱网/旧ordinal0/完整帧/Lenna和全部PX/UX/CB/L2/L3/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-10-RESTORE-OWNERSHIP.md)。

2026-10-10T15:29:46.969028+08:00 文件续播按钮刷新收尾：持久完成/锁释放后主线程通知，文件页订阅同store；仅3源码文件改变，173输入/29库，新源53b6c222普通5de9/05cf/KSeda1。本轮265测试/2跳过/0失败、15预检/18工具测试；13/iPad保留数据覆盖及25/16偏好、空环境实际启动已核。8完整窗/8原退出，6文件出口立即/稳定继续观看、6正文/2暗开场未定；冷续播最新保存与首钟差手机0.115342/Pad0.122秒。手机前出口45.503→冷前58.286的保存收敛边界未核。手机KS2900/6300ms、AV211ms、Pad3003ms及两无完整结束等待保留，Pad1次SocketError原窗重试保留；41新目录success不闭119。双机最终实际NAS/DSM/JF绿/播放闭合/空环境参数/active0/idle10/动画2，其他橙警告不称全绿。18无线AFC新包保留数据安装成功/25偏好一致，原生4016/DVT InvalidService/截图不可用使启动实际画面未核；USB误判已纠正，无18播放验收。恢复尾部所有权受控反例、原弱网/旧ordinal0/帧/Lenna及全部PX/UX/CB/L2/L3/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-10-RESUME-PREVIEW-REFRESH.md)。

2026-10-10T14:09:31.294484+08:00 目录来源与页面取消定向回归收尾：本轮未改App源码，同源21e8797a/普通2418、2aaa逐机重核173输入/29库及签名，保留数据覆盖13/iPad，25/16偏好安装及正常启动后一致。每机两次受控弱网MI2详情、三次目录重开；新目录响应47/41均成功，44个FS发布均已有同登录来源准备，0未关联/浏览来源错配。本轮12完整播放窗/12原普通退出、10正文图及2开场/黑场待解释；首推进前194/1500/2029ms等待及手机S03观测中断/独立恢复重试均保留。S19冷重开保存58.74/58.992→首钟58.856/59.125→最终100.946/101.408，iPad退出按钮仍显示预览待查，非已证实进度丢失。两机最终实际NAS/JF在线、播放器闭合、空环境/参数、active0/idle10/动画2；18同包13:11安装证据独立，本轮未接入。262测试/2跳过/0失败、15预检/18工具测试引用前一冻结源码批次，当前未重跑。完整恢复尾部所有权/119根因、原弱网等待/旧ordinal0、完整帧/Lenna/全部PX/UX/CB/L2/Main仍开放。见[本批交接](../handoffs/2026-10/2026-10-10-FOLDER-SOURCE-UI.md)及[接续脱敏报告](../../testing/results/2026-10/FOLDER-SOURCE-UI-RESUME-20261010.json)。

2026-10-10T13:11:34.062969+08:00 用户插入18安装已完成：当前源21e8797a普通2418/2aaa/KSeda1现场173输入/29库/签名/设备profile重核，保留数据覆盖18成功，25偏好/无测试启动/实际NAS和JF在线/同进程已核。目录来源和取消页面10反例、262测试/2跳过/0失败及15预检完成，13两弱详情/三重开；iPad USB掉线TOOL及网络条件清理未确认，S01/S03本批未开始。下一步先恢复iPad条件/核包再接续，119、弱网/全矩阵/竞品/Main开放。见[18安装](../handoffs/2026-10/2026-10-10-IPHONE18-LATEST-INSTALL.md)和[目录接续](../handoffs/2026-10/2026-10-10-FOLDER-SOURCE-UI.md)。


2026-10-10T12:27:04.689778+08:00 登录代际诊断收尾：4鉴权反例，252测试/2跳过/0失败、15预检/18工具测试；源e19a9932普通042a/0221双机逐项验签保留数据覆盖，173输入/25与16偏好/空环境实际启动已核。六弱网MI2详情、四S01 90秒/四原退出/四电影图；51目录响应全关联28成功登录，0本批119/读失败/播放错误。来源同步窗口手机1.824～3.720s、iPad2.289～3.142s已观察但119因果未证实；iPad文件首观察推进4.243s保留。最终NAS/JF在线、播放器闭合、active0/idleWait10，18前包；未改鉴权/缓存/发布/取消UI/重试或播放器策略。下一步受控恢复所有权/FS来源同步/取消UI再决定单次账号绑定恢复；弱网/旧ordinal0及所有矩阵/竞品仍开放。见[本批交接](../handoffs/2026-10/2026-10-10-AUTHENTICATION-GENERATION.md)。

2026-10-10T10:19:22.443151+08:00 目录缓存/119传播修复收尾：11确定性反例，248测试/2跳过/0失败、15预检/17安全工具测试；源d727b94a普通0811/f185逐机验签保留数据覆盖13/iPad，173输入、25/16偏好及正常空环境实际启动已核。六次受控弱网MI2详情成功（无播放），53新响应成功，旧包事件ID排除；四S01 90秒窗/四原退出/四电影开场，iPad文件355ms首推进前等待与手机一次SocketError重连保留，不判性能PASS。最终双机最新空环境/实际首页NAS及Jellyfin在线、播放器关闭、原生active0/idleWait10；18未连接前包，119服务端原因/真实鉴权代际、弱网等待、全部矩阵/竞品/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-10-FOLDER-SESSION-ISOLATION.md)。

2026-10-10T07:41:29.356692+08:00 客户端读侧观测与定向回归收尾：237测试/2跳过/0失败、15预检/17安全分析测试；源aac15c3c普通3f59/3e90逐机验签保留数据覆盖13/iPad，25/16偏好和实际正常启动已核。10个90秒窗/10原退出，117正常分片EOF均完整完成，19缺读侧事件保持unknown；18取消迟到metrics/完成0～3ms齐全。弱六窗原KS 1/1/1与2/1/1仍FAIL，新首候选ordinal1不替代旧慢ordinal0回归；61目录响应中手机6次119（snapshot2/browserFolder4）再现，首导航失败保留。最终两机新源空环境/实际首页NAS及Jellyfin在线、播放器退出、原生active0/idleWait10；18未连接前包，全部矩阵/竞品/Main开放。下一步会话代际/119隔离与候选身份/探测/协商、旧第0段同点证据。 见[本批交接](../handoffs/2026-10/2026-10-10-PROXY-CLIENT-READ-END.md)。

2026-10-10T06:58:26.000+08:00 首分片取消诊断收尾：233测试/2跳过/0失败、15预检/16安全分析测试；源3e4b4851普通0446/99b8逐机验签保留数据覆盖13/iPad，25/16偏好及实际正常启动已核。10个90秒基线+2个30秒控件窗/12原退出，20取消均迟到metrics/完成可见（0～6ms），慢首段requestMs9582及重复请求仍保留；弱六窗原KS各1次等待，手机/iPad请求至提交中位7.661/8.687秒，不作性能PASS。68目录响应成功/旧119未关闭；两控件未确认/TOOL保留后一次实际暂停32→32/恢复35→40成立，旧反馈未宣称修复。最终两机最新空环境首页/NAS正常、播放器退出/条件active0/idleWait10，18仍前包，全矩阵/竞品/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-10-PROXY-CANCELLATION-DIAGNOSTICS.md)。

2026-10-10T05:27:55.425322+08:00 备用流分段/目录来源本批收尾：229测试/2跳过/0失败、15预检/14安全分析测试；新源2e6a5d05普通0f5c/ef79双机验签保留数据覆盖，25/16偏好与实际正常启动已核。10完整窗/10原退出（6MI2正文、4S01开场），弱六窗均原流首推进后等待；手机请求→提交中位9.780/范围8.093～22.431秒、iPad8.797/7.908～8.831，首手机首分片三请求及两client失败保留，不作因果速度PASS。54目录来源响应成功，旧2次119未复现/会话代际原因未闭环；1读取SocketError恢复、iPad文件play.fill反馈待核。最终两机最新空环境实际首页/NAS正常、播放器退出/条件active0/idleWait10，18仍前包，全矩阵/竞品/Main开放。见[本批交接](../handoffs/2026-10/2026-10-10-CANDIDATE-PREPARATION-AND-FOLDER-ORIGIN.md)。

2026-10-09T23:24:40.608375+08:00 文件原流预测输入修复收尾：229测试/2跳过/0失败、15预检/安全分析工具10测试；新源9f10a247/普通4299、f2d6、KSeda1双机保留数据覆盖、25/16偏好及实际正常启动已核。最终22完整窗/22原退出、18电影；6弱窗5次提前请求但原KS仍停顿（13计数1/1/2，iPad1/1/1），3候选起播前等待保留；16普通Wi-Fi窗采样计数0不作性能PASS。目录93成功/2次API119（HTTP200）保留，旧invalidResponse原因未闭环。两机最终正常空环境/实际首页/播放器关闭/idleWait10/条件active0；18仍前包，全部矩阵/竞品/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-09-ORIGINAL-PREDICTION-GATES.md)。


2026-10-09T21:51:14.981046+08:00 AV首推进诊断收尾：221测试/2跳过/0失败，15预检及分析工具8测试通过；新源cde080f2/普通1047、9c0c、KSeda1双机保留数据覆盖/25与16偏好及实际正常启动已核。14完整窗/14原普通退出，6候选首钟遥测playing及7配置边界齐全；6弱窗原流停顿和首手机目录invalidResponse保留，诊断正确性修正不当性能通过。两机最终最新正常空环境/实际首页/播放器关闭/原生条件active0已核，全矩阵/竞品/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-09-AV-ACTIVATION-BOUNDARIES.md)。


2026-10-09T18:27:59.346277+08:00 分阶段定位收尾：同源9dc/正常8f5c双机逐机覆盖、25/16偏好及正常实际启动核实；6个90秒MI2文件弱家庭受控窗/6电影/6原退出/6接手，均复现原流停顿，3候选等待位于其首实际时钟推进前，FAIL保留。首手机SSL工具不完整窗/恢复独列，后6窗读取0失败；分析工具7测试通过，App参数未改。双机最终最新正常空环境/实际首页/播放器关闭/原生条件active0已核，全矩阵/竞品/Main开放。 见[本批交接](../handoffs/2026-10/2026-10-09-STARTUP-HANDOFF-PHASES.md)。


2026-10-09 17:07 最新检查点：文件严格源轨道协商/Off表示确认与绝对HLS时间轴已修正；218测试/2跳过/0失败与15预检，普通8f5c/da56两机保留数据更新/25与16偏好及正常实际启动已核。最终源20常规窗/20电影/20普通退出，4文件弱窗明确接手且源轨道保留；2组暂停/+15seek/退出/继续观看定向观察完成。8受控家庭Wi-Fi窗全部起播后再缓冲，7常规窗内部起播超目标、iPad续播1→2缓冲仍FAIL；独立iPad AX工具失败和恢复/重测保留。原生40/33Mbps、双向1ms/0丢包只代表家庭LAN受控上限，真实弱信号/弱蜂窝/家庭外Wi-Fi未由此验证。双机最新正常首页/空环境/播放器关闭/条件active0已核。全部原PX/UX/CB/19×4/竞品/Main开放，未借本批关闭。[本批交接](../handoffs/2026-10/2026-10-09-FILE-TRACK-HANDOFF.md)。


2026-10-09 12:34 接续：Wi-Fi文件原流补惰性协商候选，保守第一音轨/已知字幕Off无外置字幕；211测试/2跳过/0失败及15预检，普通97a1/77b0/KSeda1（diff4bdd）逐机保留数据覆盖13/iPad、25/16偏好和实际正常启动已核。独立20窗/20可辨电影/20普通退出（12普通60秒、8受控家庭Wi-Fi180秒），另原截图会话TOOL及DSM目录invalidResponse/重测独立保留。文件S03手机4/iPad5、MI2手机9/iPad7次缓冲，四窗各2次runtimeTracks拒绝，0个文件候选准备/提交，L1仍FAIL；媒体库弱6次+普通PadS03两次提交后再缓冲，7窗起播钟超目标保留。两机最新正常/空环境/实际启动台/播放器关闭/idleWait10及原生条件全部inactive已核。下一步严格轨道/外置字幕继承与原失败新包回归；声音画质/十分钟/PiP/完整帧、S19/弱蜂窝/真实弱信号/家庭外Wi-Fi、全部PX/UX/CB/竞品/Main仍开放。 见[本批交接](../handoffs/2026-10/2026-10-09-WIFI-FILE-FALLBACK.md)。
2026-10-09 11:04 接续：当前f6ef10源码/普通fe7c、61c8、KSeda1已逐机保留数据安装13/iPad，25/16偏好一致；207测试/2跳过/0失败及15预检。第二包独立28窗（12普通30秒+12正文60秒+4受控弱Wi-Fi180秒），20窗可辨电影、8片头/天空短窗保留未验；27原时点普通退出，另一iPad S03文件30秒退出TOOL后普通恢复独列。弱Wi-Fi媒体库手机1/iPad2实际持钟接手，文件总计手机6/iPad5次缓冲（首钟后各5次）及iPad媒体库再缓冲仍FAIL；10普通/2弱窗内部起播钟超目标。S01媒体库同序列原生/WDA方向补证已核，旧倒置不全面关闭。两机最新普通/空环境实际首页/播放器关闭/idleWait10与新鲜条件全inactive已核，无无线设置改动。下一项独立修正Wi-Fi文件请求协商候选；MI2/S19/真实弱信号/家庭外Wi-Fi、声音/画质/十分钟/PiP/完整帧及全PX/UX/CB/竞品/Main仍开放。 见[本轮卡](../handoffs/2026-10/2026-10-09-HANDOFF-COMMIT-HOLD.md)。

2026-10-09新增范围：弱家庭内Wi-Fi及真实弱家庭外Wi-Fi的大文件播放，MI2/S03/S19文件与Jellyfin双入口，关联PX-03/PX-21；真实弱信号/公网与系统限速模拟分列，现有家中USB环境不冒充外部Wi-Fi。执行卡见[弱链路双入口](../../testing/WEAK-CELLULAR-LARGE-FILE-DUAL-ENTRY.md)。状态均待验，不关闭原蜂窝/PX/UX/CB缺口。

2026-10-08 21:44 接续：当前979f16源码、普通d839/3481/KSeda1，207测试/2跳过/0失败及15预检；13/iPad现场重核、29库验签/137输入、保留数据覆盖与25/16偏好/实际正常启动已核，iPad此前联网开发者验证阻塞已解除。本批未改App源码。最新源15播放窗（2蜂窝/13Wi-Fi，覆盖12个双机三片双入口单元）实际电影/普通退出已核；7窗内部起播超目标FAIL、KS丢帧0～6/AV未知，iPadS01方向及手机此前45秒黑场未解决。收尾两机最新普通/空环境/正常首页/idleWait10、手机原Wi-Fi ON与条件inactive已核；旧源证据/TOOL保留，全部PX/UX/CB/L2/竞品/Main仍开放。见[本批交接](../handoffs/2026-10/2026-10-08-LATEST-DEVICE-RESUME-2120.md)。

2026-10-08 20:56 接续：文件匹配的标题提示空/错结果有界回查已实现，严格大小/文件名/父路径身份与完整性/歧义门槛保留；206测试/2跳过/0失败及15预检、普通10e2/46ec/KSeda1、diff dad249、137输入/29库验签，两机保留数据安装与25/16偏好/正常前台已核。新包S03/S19真实蜂窝文件180秒电影及媒体请求57/57、56/56已核，S03再缓冲且候选提交0.122秒漂移拒绝、S19起播等待仍FAIL；搜索直接命中，不归因回查分支。双机三片双入口短窗及全部TOOL保留，手机S03媒体库普通退出受工具阻塞/强退恢复未验；收尾同最新普通/空环境/退出、原Wi-Fi ON与条件inactive恢复。全PX/UX/CB/L2/竞品/Main/18缺口保持。 见[本轮交接](../handoffs/2026-10/2026-10-08-FILE-MATCH-SEARCH-HANDOFF.md)。

2026-10-08 18:19 接续：AVPlayer 连续储备回调与诊断规则已接通，201测试/2跳过/0失败、15预检；普通74a6/3cf3/KSeda1、diff fa2029 两机重新验签/137输入、保留数据安装及25/16偏好/正常前台核对。真实蜂窝S03候选储备25.353/28.341秒；MI2储备0.728秒→lead0.478秒自然边界已核。S01/S03/S08两机双入口12个Wi-Fi短窗覆盖及3个蜂窝窗口保留全部失败；S03媒体库40.327秒起播/两次40秒候选放弃，文件30.102秒起播、180秒末图仍停片头（最后遥测154.188秒时位置10.484秒/2缓冲/4丢帧），均未解决；MI2起播29.402秒、旧iPad首段-12889/实施阶段丢帧44等保留。iPad WDA观测连接重置已按有效既有XCTest恢复，TOOL不删除。收尾两机最新正常空环境/退出/idleWait10、原Wi-Fi ON/条件inactive已核；18未连接，全部PX/UX/CB/L2/竞品/Main仍开放。 见[本轮交接](../handoffs/2026-10/2026-10-08-AV-RESERVE-HANDOFF.md)。

2026-10-08 13:29 接续：同一普通 e8ef/d283/KSeda1、diff256f 重新核对两机并保留数据覆盖，137输入/29库签名/25与16偏好/实际正常前台已核；未改iOS源码。补齐S01/S08媒体库两机45/60秒实际播放/退出，13真实蜂窝1/1与2/2 metrics；iPad两片保留3/2丢帧。iPad S03进入HLS后90秒无首钟、首段约60秒等待及CoreMedia -12889 FAIL，旧-1001/候选40秒失败保留；S08旧导航标题匹配TOOL另列。AV接手读储备unknown而独立诊断1.266秒/候选lead11秒反例已固定，补输入实现待下一批；首段失败另查。收尾两机NAS正常/Jellyfin在线、普通空环境/播放器退出/idleWait10、手机原Wi-Fi ON/条件inactive已核。L2/PX/UX/CB/竞品/Main/18缺口保持。 见[本轮交接](../handoffs/2026-10/2026-10-08-MEDIA-LIBRARY-COMPLETION.md)。

2026-10-08 12:16 接续：修正HLS供流估计遗漏请求等待，保留Range正文口径；197测试/2跳过/0失败、15预检，普通e8ef/d283/KSeda1、diff256f，137输入/29库签名及两机25/16偏好保留覆盖/正常前台已核。13真实蜂窝S03双入口50/46分片metrics采用完整耗时，媒体库500kbps候选40.018s未对齐及再缓冲保留，文件初始后无新增缓冲。S01/S03/S08文件两机已观察；S08手机旧蜂窝TOOL、iPad冷DSM未就绪及暖会话另列，丢帧不删除。NAS运行时长/服务列表中途变化，iPad媒体库-1001、4个媒体库单元未执行；收尾两机NAS正常/Jellyfin在线入口重新出现，不替代播放验证。最新正常包/空环境/播放器退出/idleWait10及手机Wi-Fi原ON恢复，条件inactive；18离线旧65f6，L2/PX/UX/CB/竞品/Main仍开放。 见[本轮交接](../handoffs/2026-10/2026-10-08-HLS-CAPACITY-BOUNDARY.md)。

2026-10-08 11:00 接续：用户13蜂窝已可用。固定连续诊断750ms批次保存及KSPlayer初始seek/打开/解析/解码阶段观测，未改播放参数；193测试/2跳过/0失败、15预检，普通7779/0187/KSeda1、diff e942，137输入/29库签名/链接通过，13+iPad逐机保留数据覆盖及25/16偏好/实际正常启动已核。13真实5G/Wi-Fi OFF两个S03入口均URL metrics cellular=yes：Jellyfin时钟29.571秒/再缓冲FAIL，文件续播11.871秒/约120秒窗口初始后未新增缓冲；码率/位置不同不排名。iPad ISO两入口实际中文及退出已核，文件续播初始seek2.288秒、时钟5.492秒，Jellyfin补证丢帧26保留，不声称提速或流畅。系统磁盘刷新/1000条裁剪仍有边界，TOOL和client NWError全部保留。手机Wi-Fi原ON恢复，两机最新普通启动台/空环境/idleWait10/WDA ready；18离线旧65f6，正式竞品0，PX/UX/CB/L2/Main仍开放。 见[交接](../handoffs/2026-10/2026-10-08-DEVICE-RESUME-DIAGNOSTICS.md)。

2026-10-08 07:09 接续：文件入口未知字幕被当 Off 的反例已修，发现模型就绪后按偏好选一次，保留主动 Off/已保存选择；两个入口 ISO 生命周期释放及数字耗时补齐。190测试/2跳过/0失败、15预检/29库签名/128输入通过，普通65f6/a339/KS5fa4、diff372e逐机保留数据安装13/iPad，25/16偏好和正常前台已核。iPad无目录无历史首开实际中文、Off重开保留/收尾恢复中文；手机保存英语及Jellyfin中文即时续播已核。普通退出路由数量1→0、实际详情可读；只证明定向正确性。iPad文件续播内部时钟等待15.008/12.514秒及中间包点击20.623秒FAIL保留，不声称速度改善；日志延迟/裁剪、目录重试/TOOL保留。两机普通退出/idleWait10，无网络改动；18未连接未更新、正式竞品0、L2/Main和全部PX/UX/CB原缺口开放。 见[本轮接续](../handoffs/2026-10/2026-10-08-ISO-AUTO-SUBTITLE-LIFECYCLE.md)。

2026-10-08 05:33 接续：13 默认字幕反例已定位为 Jellyfin ISO 早返回请求遗漏轨道目录/所选 ID；修正后普通 6fba/4867/KS5fa4、diff2f37，185测试/2跳过/0失败及15预检、验签/128输入检查，13/iPad保留数据覆盖及25/16偏好/正常前台已核。13 Chinese 自动显示与主动 Off 保留通过，iPad现有 Chinese 自动显示及约123秒断点恢复已核；启动4.626秒黑屏、15.295秒电影仍待速度优化。iPad大S03最新140遥测/146.069秒、stallCount0/丢帧3、60/90秒电影/双语及退出详情正常，30秒黑场图保留；旧 -1008/长首帧条件未复现，不关闭旧FAIL。两机普通退出/idleWait10，无网络限速改动；18离线51ae、文件入口ISO/L2/全PX/UX/CB/Main开放。见[ISO字幕接续](../handoffs/2026-10/2026-10-08-ISO-DEFAULT-SUBTITLES.md)及[脱敏摘要](../../testing/results/2026-10/ISO-DEFAULT-SUBTITLES-20261008.json)。

2026-10-08 01:06 接续：用户补充异常发生于播放后退出；当时最新823e/758d在13 S03实播约30秒后普通退出，6秒实际图复现黑色遮挡，00:30正常入页不能证明修复。详情正文增加不透明系统背景/zIndex；最新普通a6f7/21ae/KS5fa4、diff b07d、185测试/2跳过/0失败及15预检、29库验签通过，13/iPad逐机核验保留数据覆盖及正常前台，25/16偏好一致。手机4次/iPad2次实际播放退出布局均可读，涵盖MI2/S03；另iPad S03补测30秒黑屏、备用流-1008和输入未确认保留，后恢复实播及原生普通关闭详情正常，不计暂停回归通过。两机播放已退出，18断开保留51ae；默认字幕、后台/PiP、共享播放L2及Main继续开放。见[本轮退出卡](../handoffs/2026-10/2026-10-08-PLAYBACK-EXIT-DETAIL.md)及[脱敏摘要](../../testing/results/2026-10/PLAYBACK-EXIT-DETAIL-20261008.json)。

2026-10-07 23:56 最新接续：用户真蜂窝确认 18 的 51ae 包 DSM 可连，旧 906e 失败保留、根因未断言；18 已断开。当前默认字幕兜底新源码 diff485e、普通包823e/758d/KS5fa4，185测试/2跳过/0失败、15预检/29库验签，13/iPad现场核对后保留数据覆盖、25/16偏好一致及正常实际前台已核。新包媒体库两端失败；Mac实际公开信息接口502、内网reset，Safari DSM会话失效，已请求用户登录查容器，不重启/改网络。字幕真机/L2尚未验，18当前不是新源码包。前一份51ae的13大S03候选本轮成功、接手后279.5秒遥测0缓冲、真实双语/正常退出；旧候选分片500和等待仍FAIL、完整Range后来过1GB，无固定256MiB上限证据。MTP及Main仍待门槛。继续 [最新变更卡](../handoffs/2026-10/2026-10-07-CELLULAR-CONNECTION-AND-DEFAULT-SUBTITLES.md) 与 [机器摘要](../../testing/results/2026-10/CELLULAR-AND-DEFAULT-SUBTITLES-20261007.json)，此前185以下样本不归823e最新回归。

2026-10-07 18:57 用户新增：外部播放器Infuse当前报错；“其他App”系统分享不能选择Fileball等播放器，须检查已安装专用入口、协议/认证、目标App真实首帧及回跳，系统接受URL不算播放通过。13+iPad用于后续自动调试，18已由用户带走。最新同包已安装三机；iPad详情菜单实际列出Infuse/Fileball，需覆盖设备文件/播放器内部入口及三机差异。多端争用按调试规范MTP-01～03独立执行，先单播再同片/异片并发并分别记录带宽、转码、缓存、缓冲和停止隔离，不通过降低统一默认画质掩盖问题。iPad当前海报不再覆盖简介，但底部/原文片名被裁切，仍未验收；外部凭据确认弹层仅7点高，新增展示问题待修。

2026-10-07 用户范围更新：移除App新/旧架构选择，暂存旧实现，开发完成时按[ADR 0002 收尾清单](../../adr/0002-single-playback-optimization-mainline.md)删除专属代码/设置/依赖并迁移正式Release。记录[Apple TV工程与安装准备](../../development/APPLE-TV-PREPARATION.md)：现有工程仅iOS，tvOS target及真机验收尚未实施；现在可准备，播放器接入承接移动端共用正确性。多NAS/同NAS多账号已获范围确认，账号/凭据/缓存/播放记录隔离仍待实现。18后台无法续播、13PiP字幕、默认字幕、iPad海报重叠/Transformers续播、LAN-IP/规则VPN大文件双入口均保留未关闭。新PiP生命周期候选见[变更卡](../handoffs/2026-10/2026-10-07-PIP-LIFECYCLE-AND-LATEST-PACKAGE.md)，当前不能标全局通过。

2026-10-07 08:14 接续：新普通主题包iPhone13三主题即时应用/重启保存已核；S19设备文件144遥测/177.631秒原流停于1.844秒，noStoredJellyfinSession待查，当前完整长度及大偏移尾索引已核。其他App前台/无线变化使后续退出/对照不可验，条件全关；S19 Jellyfin与MI2/S03双入口、全部PX/UX/CB/竞品开放。iPad新包空间错误受阻、18待重连。见[本轮记录](../handoffs/2026-10/2026-10-07-LAUNCHPAD-THEME-AND-WEAK-LARGE-FILES.md)。

2026-10-07 07:46 安装与同步：iPhone18已重连，最新ac5d/bf0b普通包逐项验签保留数据覆盖，25偏好安装/启动后一致、普通进程46.3秒后仍在；截图TOOL，播放/性能尚未回归。当前App源码/测试/脚本及脱敏交接已以9410d80推送GitHub main并核验远端与已安装包iOS内容一致，41工具测试/15预检通过；未使用第三方参考文件与私有诊断留本地。继续优先弱蜂窝《碟中谍》《指环王》大文件及设备文件/Jellyfin双入口，全部PX/UX/CB保持未验收。见[本轮安装同步](../handoffs/2026-10/2026-10-07-IPHONE18-INSTALL-MAIN-SYNC.md)。

2026-10-07 07:36 用户强调：优先补实际弱蜂窝下《碟中谍》（MI2/S03）及《指环王》（S19，100GB以上）大文件；设备文件与Jellyfin入口同步优化、分别取证回归。最新S03仅Jellyfin部分证据，MI2弱蜂窝、S19最新弱蜂窝及设备文件对应单元仍待补，不能由小片或单入口推断通过。执行[弱蜂窝大文件双入口卡](../../testing/WEAK-CELLULAR-LARGE-FILE-DUAL-ENTRY.md)，既有矩阵状态保留。

2026-10-07 07:35 最新接续：用户取消iPhone13/iPad锁屏密码后，逐台现场重核、验签保留数据覆盖ac5d/bf0b最新普通包；App源码未改，沿用同源码135核心测试与06:10产物。本轮优化滚动页面可见性核对和边界位移补足，18工具测试通过。手机LAN119.399秒0缓冲/1丢帧；弱S03清单19.149秒/内部首帧27.564秒，S01独立控制新画面/恢复上界1.220/4.512秒，旧意外返回详情及长期seek失败仍未关闭。iPad120秒真实电影/双语画面变化和普通UI退出已核，但诊断文件仍早于本轮播放，计数INSUFFICIENT；Nastart r4已12实际位移/129.177秒但ktrace录制失败，Lenna也缺全程显示覆盖，正式配对0、不排名。收尾两机最新普通启动台/空环境/WDA ready/unlocked/idleWait10，手机条件全关/原Wi-Fi ON；18离线。本轮只新增受限证据，不关闭任何PX/UX/CB。优先定位iPad遥测与显示采样、弱网长清单传输、旧seek/意外关闭，再补精确字幕/音轨和共同条件竞品五组、完整设备格式矩阵。见[本轮交接](../handoffs/2026-10/2026-10-07-UNLOCKED-DEVICE-RESUME.md)与[脱敏量化](../../testing/results/2026-10/UNLOCKED-DEVICE-RESUME-20261007.json)。

2026-10-07 05:37 最新接续：连续Range供流资格修正，受控旧反例失败/新132核心测试与15预检通过；850d/06d9普通包本机验签保留数据覆盖及25偏好/前台核验。LAN三轮119.441/119.934/119.650秒0缓冲、丢帧0/1/0，供流变量/缓存unknown不作因果修复声明；正常蜂窝119.096秒0/0，弱蜂窝默认初始250kbps HLS首帧22.923秒、首帧后155.489秒无新增计数，暂停seek新画面上界1.954秒/恢复1.936秒单样本。弱网原画body资格未实机覆盖，旧候选/36秒seek失败仍未关闭；清单准备18.154秒待优化。限速全inactive、原Wi-Fi ON恢复、最新正常首页/WDA ready/unlocked；iPad断开、18离线、正式竞品配对0，全部PX/UX/CB保留。 见[本轮交接](../handoffs/2026-10/2026-10-07-IPHONE13-RANGE-SUPPLY.md)。

2026-10-07 最新接续：保留停滞位置/连续储备及提交复核/预热origin网络绑定修正，延后自动等待实验两轮暂停FAIL已撤回。128核心/15预检、最新93a1/6a0a普通包验签保留数据安装及25偏好核验通过；新包40Mbps仍首卡/接手等待FAIL，但持续实播恢复；正常LAN5150ms缓冲、弱蜂窝两次候选失败及暂停seek旧画面36.324秒FAIL；正常蜂窝119.238秒0计数，只适用各单样本。所有限速关闭、本轮无线原状态恢复，最新正常启动台/WDA ready/unlocked。正式竞品配对0，iPad断开、18离线，全部PX/UX/CB缺口保留。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-STALLED-HANDOFF.md)。


2026-10-06 20:20 最新接续：加入原画206 Range两段合格body供流估计、6秒有效期与初始3秒预测宽限，完成122核心测试/15预检、普通Debug构建验签及iPhone13保留数据安装；最新包LAN、40Mbps控制供流、真实弱蜂窝及正常蜂窝串行回归。 LAN MI2/S01遥测179.937/119.640秒0缓冲，丢帧1/0、无降档；40Mbps分支6.356秒提前触发，但15551ms首卡仍FAIL，候选17.876秒接手。最新弱蜂窝首帧27.403秒、首帧后151.483秒无新增计数，单次暂停seek新画面上界1.885秒、精确落点待验；最新正常蜂窝首帧2.593秒、遥测119.531秒。iPad用户确认已断开，18离线，未更新c46；正式竞品配对0。收尾最新正常包/限速全关/原无线状态恢复。 优先隔离原画与HLS候选共享供流、缩短候选准备接手及健康爬升/高储备误降档边界；重复弱蜂窝暂停seek历史黑屏与长清单等待，再补字幕音轨/精确cue、Lenna及DS One Jellyfin/DSM至少五组量化和全部PX/UX/CB缺口。 见[本轮接续](../handoffs/2026-10/2026-10-06-IPHONE13-EARLY-SUPPLY.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-EARLY-SUPPLY-20261006.json)。旧包/TOOL/失败保留；不关闭全局验收。


2026-10-06 19:10 最新接续：完成真实5G及SlowNetwork3G蜂窝专项；修复初始VOD清单晚到失败、加入375/250kbps自动档、缓冲内候选seek及早期供流诊断。119核心测试/15预检通过，e52/f6f普通包双机保留数据安装、逐台身份及启动核验。 最新正常5G首帧2.884秒、118.568秒0缓冲/丢帧；弱蜂窝两轮首帧23.943/21.948秒，首帧后154.502/96.495秒无新增缓冲。弱网暂停seek黑屏仍慢；iPad最新LAN MI2再现7550ms/14丢帧，HLS29.571秒接手后133.672秒无新增。失败/TOOL/未验音频保留，竞品配对0，18离线旧e855。两机正常收尾/Wi-Fi原状/限速全关闭。 优先验证首个完整Range前供流窗口与预测宽限、健康误降档边界，以及弱蜂窝暂停seek黑屏/长清单等待；继续字幕音轨/精确旧cue、Lenna及DS One Jellyfin/DSM五组量化和全部PX/UX/CB缺口。 见[本轮蜂窝及LAN交接](../handoffs/2026-10/2026-10-06-IPHONE13-CELLULAR-VOD-PREWARM.md)和[脱敏量化](../../testing/results/2026-10/IPHONE13-CELLULAR-VOD-PREWARM-20261006.json)。旧包证据不移用为最新回归；不作竞品排名或全矩阵验收。


2026-10-06 16:04 最新接续：补HLS分段/请求/取消数字关联，114核心测试和15预检通过；6f58/7881普通包双机验签保留数据覆盖，25/14偏好一致，双机串行自然180秒及控制退出补验。 iPad178.296秒0缓冲/4丢帧；iPhone原画5737ms缓冲/33丢帧，HLS请求至接手37.548秒，接手后120.113秒无新增计数。首段4被重复请求、未取0已证实；手机完成退出单次通过，iPad慢采集仍INSUFFICIENT、暂停补验PASS。根因未闭环、竞品配对0，18离线保留旧e855。 优先首个32MiB完成前供流/储备与预测首卡窗口、同段重试/取消；补精确字幕cue及控制，再推进Lenna/DS One Jellyfin/DSM五组量化及全部PX/UX/CB缺口。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-IPAD-SEGMENT-ASSOCIATION.md)。


2026-10-06 15:31 最新接续：按用户打断要求，现场重核刚接入iPhone18 Pro Max/iOS27.0，将同源码e855/38ce最新普通包验签后保留数据覆盖；正常系统启动成功、约69.8秒后同进程仍在，安装及启动后25项偏好一致，WDA未重装。 iPhone18已从旧d84f更新到当前e855；本轮只安装及进程启动核验，原生截图TOOL、实际前台UI/播放性能未验。iPhone13既有宿主ready时恢复一次no-launch session，13/iPad正常启动台重核；无新源码或播放采样。 返回iPhone13/iPad原画供流和HLS首段等待/取消关联、健康预测边界与控制/字幕，再推进Lenna/DS One Jellyfin和DSM全面量化；保留所有PX/UX/CB未验收项。 见[安装续记](../handoffs/2026-10/2026-10-06-IPHONE18-LATEST-APP.md)及[供流排查](../handoffs/2026-10/2026-10-06-IPHONE13-IPAD-UPSTREAM-LOADING.md)。


2026-10-06 15:01 最新接续：补候选每秒加载/访问日志与Jellyfin编码协商诊断；113核心测试/15preflight通过，e855/38ce普通包双机验签保留数据覆盖；两机串行自然重复与竞品安装清单重核。 合格iPhone13遥测119.318秒0缓冲/1丢帧；iPad首轮原画3缓冲/5丢帧，两次HLS请求至接手25.601/35.543秒，接手后计数无新增。首段慢请求/Broken pipe取消保留；一手机晚切设备gate与一iPad预导航TOOL单列。卡顿未闭环，正式竞品配对0；两台普通启动台/视频结束/WDA ready/unlocked。 继续原画供流/储备与HLS首段等待/取消、健康预测边界和40秒失败；补旧精确cue、控制退出与Lenna/DS One Jellyfin/DSM五组量化，保留音频/完整滚动显示、格式/双设备、所有PX/UX/CB缺口。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-IPAD-UPSTREAM-LOADING.md)。


2026-10-06 14:03 最新接续：接入iPad并保留数据安装App/固定WDA；双设备复现原画缓冲，修正AV候选把大准备迟滞误当seek，113核心测试/15preflight通过；最终500f/eeb6包逐台验签覆盖、普通启动及短段实测。 最终iPhone13遥测59.591秒0缓冲/1丢帧，iPad59.401秒3缓冲/3丢帧；iPad候选落后14.120秒仍继续至40.013秒期限，但未对齐接手。手势试验撤回；正常UI退出未验，收尾已停止视频并空环境重启至启动台/WDA ready/unlocked。根因未闭环、竞品配对0；iPhone18离线保留旧d84f。 优先原画供流/储备与HLS空缓冲/期限对齐重复、真实失效边界及控制输入/退出；补最新HLS旧失败cue、Lenna/DS One Jellyfin/DSM五组同条件量化，保留声音/完整滚动、格式/双设备和全部PX/UX/CB缺口。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-IPAD-CANDIDATE-VALIDITY.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-IPAD-CANDIDATE-VALIDITY-20261006.json)。180秒中间包与最终60秒证据分开；不提供竞品排名、整体改善百分比或全矩阵PASS。

2026-10-06 09:59 最新接续：修复快速进入搜索/详情后丢失晚到DSM局域网上下文，最新d84f/a389普通包验签保留数据安装、25偏好一致；113核心测试/15项preflight通过，补旧公网MI2十分钟、新私网MI2完整五分钟及S03两分钟自然实播。 新包两次冷启动均收到晚到候选并验证同服务器LAN，实际媒体私网HTTP8096；MI2/S03数值遥测303.311/124.096秒，0缓冲、丢帧1/0。新首轮AFC工具错误及2丢帧完整保留，未完成计划300秒；历史间歇卡顿/HLS同失败cue仍未闭环，正式竞品配对0。 收尾最新正常启动台/视频退出/手机unlocked，既有WDA ready/idleWait10及Mac有界keepawake保留，无一天免授权保证。 优先补同私网MI2自然首卡和候选重复/HLS精确失败cue，再建立Lenna/DS One Jellyfin及DSM同条件至少五组全面量化；声音、完整显示滚动、代表格式、iPad/iPhone18最新包回归及全部PX/UX/CB缺口保留。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-LATE-LAN-CONTEXT.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-LATE-LAN-CONTEXT-20261006.json)。旧公网与新私网结果分别记录，不提供因果改善比例、竞品排名或全矩阵验收。

2026-10-06 09:13 最新接续：真机触发储备耗尽预测并修正HLS固定11秒未来目标超出可用储备；112核心测试/15项preflight通过，最终4743/8027普通包验签保留数据安装、25偏好一致；补三段限速诊断、最新S03正常120秒及DS One DSM暂停观察。 新分支与提前量真机生效；两轮诊断请求至提交17.226/11.938秒，条件不同不作因果改善，首卡仍在。正常S03遥测118.594秒零缓冲/丢帧；中间包旧失败字幕句完整，最终包同cue未捕获。DS One实际01:18画面保持31.137秒、错过字幕；正式配对0，根因未闭环。 收尾普通Nastart PID24629/实际启动台/视频退出，手机unlocked，既有WDA70500 ready/idleWait10和Mac有界keepawake保留，无一天免授权保证。 优先补最新包自然MI2首卡及候选重复取证、HLS精确同失败cue，再统一Lenna/DS One Jellyfin与DSM条件各做至少五组；声音/完整显示滚动、代表格式及iPad/iPhone18最新包回归、全部PX/UX/CB缺口保留。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-RESERVE-BOUNDED-HANDOFF.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-RESERVE-BOUNDED-HANDOFF-20261006.json)。下方旧包轨迹属于历史证据，不移用为最终包结果；不提供竞品排名或全矩阵验收。

2026-10-06 08:08 最新接续：新增运行需求/低储备下降预测候选，110核心测试及15项preflight通过；最新普通c2d4/edc9包验签保留数据安装、25偏好一致，完成MI2自然300秒、限速诊断及恢复后的S03正常120秒回归。 正常MI2/S03遥测294.115/117.195秒零缓冲、丢帧1/0、无误降档；限速轮13651ms缓冲保留，既有持续缓冲规则HLS请求至接手15.607秒，新预测分支未真机触发。1607历史样本反事实重放不证明首卡预防；根因未闭环，正式竞品配对0。 收尾最新正常Nastart PID23203/启动台/视频退出、手机unlocked、既有WDA ready/idleWait10及Mac有界keepawake保留，无一天免授权保证。优先补新预测分支真机触发/候选提前量和最新HLS同失败cue；继续Lenna/DS One Jellyfin与DSM至少五组同条件对照、声音/完整显示滚动、格式及iPad/iPhone18最新包回归，保留全部PX/UX/CB未验收项。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-RESERVE-PREDICTION.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-RESERVE-PREDICTION-20261006.json)。下方旧包轨迹属于历史证据；本轮不提供竞品排名或全矩阵验收。

2026-10-06 07:13 最新接续：重核iPhone13最新普通baa9/bddf包、保留数据覆盖安装及25偏好一致；补两段自然原画观察、70秒有缺口CPU/内存、失败与健康供流/储备轨迹交叉核验，以及DS One DSM不切轨暂停字幕对照。 本轮215.723/282.091秒零新增缓冲（丢帧1/0），既有5200ms失败保留。新线索为64.05Mbps全片估算未覆盖约89～96Mbps短时需求、失败轮慢供流导致储备耗尽；策略未改、根因未闭环。DS One 01:16双语暂停保持至32.454秒，仅单次控制；正式配对0、HLS同失败cue及全部PX/UX缺口保留。 收尾最新正常Nastart/视频退出/手机unlocked/既有WDA ready/idleWait10及Mac有界keepawake仍可用，无一天免授权保证。 优先验证实时需求/储备斜率预测的健康轮误降档边界及自然HLS候选诊断；DS One同精确暂停点重复对照，再推进Lenna/DS One Jellyfin与DSM五组受控配对、声音/完整显示滚动、代表格式及其他设备最新包回归。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-PEAK-DEMAND-PAUSE-CONTROL.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-PEAK-DEMAND-PAUSE-CONTROL-20261006.json)。本轮未改iOS策略；旧失败保留，稀疏截图与有缺口CPU采样不证明完整流畅。

2026-10-06 04:49 最新接续：重核iPhone13最新包并完成两段自然十分钟MI2观察；新增候选阶段/期限/缓冲错误诊断和transferID窗口关联，普通Debug构建、验签、25偏好保留安装及15项preflight通过。 前段599.183秒零缓冲/丢帧，最新诊断包再次5200ms缓冲及丢帧4，根因未解决；供流初段慢且无backpressure，不能归因CLI/NAS。HLS同失败cue仍未触发验证，正式配对0及全部PX/UX缺口保留。最新普通包/视频退出/WDA既有宿主ready/idleWait10。 优先定位初段储备耗尽及候选自然准备/对齐；补新诊断实际分支与HLS同字幕cue，再补DS One不切轨暂停对照和Lenna/DS One Jellyfin/DSM五组同条件配对、声音/完整滚动显示、格式及其他设备。 见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-WARMUP-DIAGNOSTICS.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-WARMUP-DIAGNOSTICS-20261006.json)。旧包结果不归给最新baa9/bddf；此前竞品探索值不作本轮正式样本。

2026-10-06 02:58 最新接续：重核iPhone13及d62b/53a2最新普通包，保留数据安装/25偏好一致/无变量启动；补原画167.728秒和41完整供流窗口，Lenna及DS One Jellyfin/DSM三路实播、原生USB首画面/控制/路由证据；新增前台与坐标守卫W3C输入工具，15项preflight及负例通过。 本轮原画零新增缓冲/丢帧计数1，但既有间歇卡顿未解决；三个竞品探索首画面区间已量化，实际公网端点与Nastart私网不同，正式配对0。DS One暂停字幕瞬态消失保留INSUFFICIENT。iOS源码未改，新包HLS同失败cue/完整音频显示及全部PX/UX仍待验。收尾最新Nastart PID17700/播放器退出/手机unlocked/WDA70500 ready/idleWait10，有界keepawake保留。 优先隔离同私网MI2供流/储备耗尽及HLS候选准备对齐，补最新包HLS同字幕cue；竞品先补不切轨暂停对照和统一路线/文件/方向/构建资格，再做五组受控配对，继续字幕音轨、完整滚动/显示、代表格式及iPad/iPhone18。 详见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-SUPPLY-NATIVE-CONTROLS.md)及[脱敏量化](../../testing/results/2026-10/IPHONE13-SUPPLY-NATIVE-CONTROLS-20261006.json)。下方旧轮包/状态为历史记录，不移用为本轮结果；正式竞品配对仍0。

2026-10-06 02:11 最新接续：普通Debug最新d62b/53a2已验签、保留数据安装、25项偏好一致且无变量启动；修正全屏Home指示条遮挡字幕，真机隐藏及返回普通页恢复均已核。旧3663/f76a私网MI2再次复现，12Mbps自动HLS本轮实际对齐接手；Lenna MI2实播/双语已补，首帧采集连接中断保留TOOL，既有WDA宿主自动恢复后一次no-launch session恢复。 旧包原画两次7902/3727ms缓冲FAIL；最新UI改动包173.294秒计数零缓冲/零丢帧，仅证明该区间，不能覆盖既有失败或归因UI优化。AV bufferEmpty活动时49→50→51秒时钟推进，保留显示风险而不冒充已确认画面停滞。新包HLS原失败字幕cue仍待重放，正式竞品配对0，所有原PX/UX缺口保留。收尾手机unlocked、最新Nastart PID17307、视频已退出、WDA ready/宿主70500/idleWait10，Mac有界keepawake保留，不保证一天免授权。 继续原画窗口交付/储备耗尽与候选准备/对齐波动隔离，先补新包HLS同字幕cue；恢复稳定共同采样后做Lenna/DS One Jellyfin与DSM五组受控配对，再补字幕音轨响应、完整滚动/显示、代表格式与iPad/iPhone18最新包回归。 详见[本轮交接](../handoffs/2026-10/2026-10-06-IPHONE13-AUTO-HANDOFF-HOME.md)及[最新量化](../../testing/results/2026-10/IPHONE13-AUTO-HANDOFF-HOME-20261006.json)。本轮仅正常设备构建、15项preflight和定向真机验证；105核心测试属于此前源码，未在UI改动后重跑。下方10月5日及更早记录为历史包/历史状态，不归给当前d62b/53a2。

2026-10-05 21:43 最新接续：修正观察型I/O伪造缓存/预加载完成及失败任务未清理，旧实现3反例失败、105核心测试通过；新增分类LAN路由诊断。最新普通3663/f76a保留数据安装、25项偏好一致、无变量启动和定向真机回归已执行；DS One DSM大文件/真实双语字幕补证，普通锁屏通过现有已授权WDA恢复，未重装Runner或改安全设置。 同实际私网MI2三轮旧包仍6139/4999/2999ms缓冲FAIL；最新包一轮176.691秒无缓冲，补跑两次9300/9400ms及HLS候选对齐失败，卡顿未解决。正式竞品配对0，PiP/声音/完整显示及全部PX/UX缺口保留。收尾手机unlocked、Nastart普通PID14260、视频退出、WDA idleWait10与Mac有界防休眠保留，不保证一天免授权。 详见[本轮交接](../handoffs/2026-10/2026-10-05-IPHONE13-PRIVATE-PATH-PRELOAD.md)及[最新量化](../../testing/results/2026-10/IPHONE13-PRELOAD-EVIDENCE-20261005.json)。优先定位供流及候选对齐，全部未验收编号保持。下方19:59及更早记录为历史包/历史状态，不归给当前3663/f76a。

2026-10-05 19:59 最新接续：修复相对跳转采用精确引擎/待跳目标，102核心测试通过，最新普通Debug7dd0/ad7d已核签名、保留数据安装与无变量启动。S03已知PGS7/88.308秒真实15秒往返5/5恢复、10个seek成功且无缓存复用；恢复后171遥测/181.887秒无缓冲，完整显示/声音仍不足。MI2首轮私网原画5039ms缓冲FAIL保留；同源码优化轮实际走公网HTTPS8097，前后普通轮走私网HTTP8096，比较INVALID，不能归因编译/CLI或宣布修复。19:38恢复普通包，视频全部退出，WDA独立宿主ready、idleWait恢复10，Mac有界防休眠保留。正式竞品配对仍0，本轮无新竞品样本。先读[本轮接续](../handoffs/2026-10/2026-10-05-IPHONE13-RESUME-ISOLATION.md)和[脱敏量化](../../testing/results/2026-10/IPHONE13-RESUME-AND-MI2-20261005.json)；继续实际路由一致的MI2供流定位及Lenna/DS One双入口全面配对。

2026-10-05 11:02 收尾补证：Lenna与DS One Jellyfin/DSM双入口均已新实播并退出，四入口默认片头可辨画面请求区间及菜单能力已量化。正式同条件配对仍0；坐标动作失败/字幕cue不足继续保留，不能排名。最新正常Nastart回前台、WDA独立宿主仍ready；无iOS新修改。见[本轮交接](../handoffs/2026-10/2026-10-05-IPHONE13-PGS-EXTERNAL-RETURN.md)。

日期：2026-09-11。用户已授权按批次实施，并明确要求不得遗漏任何优化项。本文是本轮唯一任务总账；状态与证据以此处为准，详细设计见后文。继续遵循 ADR 0002 的 Greenfield 单一优化主线。

## 分批任务总账

2026-10-05 10:25 最新接续：用户报告手机已解锁，现场iPhone13/iOS16.3.1 USB/配对恢复；固定WDA由独立launchctl宿主持有、ready，无循环重启，Mac有界防休眠仍运行，但不保证24小时iOS免授权。eef/d0旧候选真实外置ASS返回PGS五次失败已保留；补齐provider清空前捕获，99核心测试/正常Debug构建/preflight通过，最新4148b9a0/777ca0b5已验签保留数据安装、25项偏好一致、正常无变量启动。六次已知PGS暂停cue返回均正确复用、无新seek，关闭/返回繁英PGS也正确。恢复后583有效遥测覆盖625.169秒，无缓冲、138有限32MiB窗口完成；初段丢帧6→101保留，未判整体流畅。真实seek后PGS fresh-cue精确区间仍不足，不关闭全局PX/UX。正常退出/结束事件已核，WDA继续保留；Lenna/DS One最新安装元数据重读，竞品接续中，正式受控配对仍0。先读[本轮回归及剩余项](../handoffs/2026-10/2026-10-05-IPHONE13-PGS-EXTERNAL-RETURN.md)。

2026-10-04 18:59 接续覆盖16:11最新包：暂停同位置切回已知PGS的冗余seek候选已实现，98核心测试/正常设备构建/preflight/diff通过；eef/d0最新包保留数据安装，25项偏好一致。新开工WDA重启再次出现本机XCTest密码授权，最新包正常启动/屏幕回归未执行；只完成L0/构建/安装，不能把旧包PGS5/5与626秒稳定归给新包或宣布卡顿修复。原画根因/受控切轨对照、音频、完整滚动和Lenna/DS One正式配对0仍保留，全PX/UX原状态不变。详见[本轮候选交接](../handoffs/2026-10/2026-10-04-IPHONE13-PAUSED-PGS-REUSE.md)。

2026-10-04 16:11 最新补证：同302/6e2正常包，S03原画LAN从头无切轨实际PGS7，586条遥测/626.086秒，缓冲计数0/活动0、丢帧1→2，真实定时画面/双语及真正退出已核；只证明该十分钟区间，不覆盖原PGS切换后4501ms缓冲或整片/音频/逐帧流畅。新运行86～92秒储备9.7～16秒，原同位置seek后储备耗至0.0614秒，支持优先隔离队列重建，但准备/缓存不同不称因果A/B。此前ASS会话显示已验，重开偏好未验，最新实际轨道PGS；全部PX/UX原未验收状态及正式竞品配对0保留。见[最新基线与变更卡](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md#1611-最新包十分钟无切轨基线)。

2026-10-04 15:46 接续覆盖15:15待回归状态：PGS有效seek过滤+暂停解码通知修正，93核心测试/正常设备构建/preflight通过，最新30210177/6e2a2c5c保留数据安装并无变量启动。实际已知PGS暂停cue切回5/5，中位可见响应区间486～1602ms、最大上界1881ms，字幕关闭及完整双语/正常退出已核；只有此功能场景通过，代表格式与双设备未验收。随后32.244秒原画LAN再缓冲4501ms，连续性FAIL恢复，整体卡顿未解决；优先隔离同位置字幕seek清空队列与供流/储备。Lenna/DS One双路线已实播，路径差异使正式配对仍0；全部PX-01～21/UX-01～06状态保留。见[最新批次](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md#1546-最新包pgs暂停回归与原画再次缓冲)和[量化记录](../../testing/results/2026-10/IPHONE13-PGS-REGRESSION-20261004.json)。

2026-10-04 15:15 接续：USB和WDA恢复、正常包恢复完成；seek诊断/有效字幕跨目标过滤两个具体缺陷已改，92核心测试、正常设备构建/preflight通过，最新ad23/64cd保留数据安装启动，PGS真机回归进行中。竞品双入口实播/字幕能力和进程级路径已实证，但Lenna/DS One媒体公网IP端点与Nastart私网媒体不同，NAT回环未知，正式配对仍0。ASS暂停同cue可见开关粗粒度计时已补，声音生效及显示滚动完整性仍不足。全部PX-01～21/UX-01～06原未验收状态保留，不能称系列原画已解决；[本批记录](../handoffs/2026-10/2026-10-04-IPHONE13-USB-RECOVERY-COMPETITORS.md)覆盖旧USB阻碍和旧优化包收尾状态。


2026-10-04 12:14 接续：最新正常Debug b2a…/6ab…先保留数据安装；MI3回退后563遥测/600.385秒无新增缓冲，但起播/seek等待仍在；MI2原画两次约6.5/6.7秒等待，12Mbps HLS接手后220遥测/298.247秒活动0，不能声称系列原画已解决。Nastart/Lenna网格各12实际位移，显示采样仅前段，两者INSUFFICIENT，不排名。用户增加DS One Jellyfin/DSM两入口全面量化，范围CB-01～26；DS One2.4.5(4)登录/入口已核，有效播放配对0。标准Release旧播放器校准排除Greenfield对照，优化Debug415f…已安装启动、实播未开始。USB屏幕采集-11805后调试连接失效，唯一目标重新枚举USB API成功但服务未恢复；正常Debug收尾恢复受阻。PX-01～21/UX-01～06所有原状态保留，未新增全局验收。见 [本轮记录](../handoffs/2026-10/2026-10-04-IPHONE13-POST-AUTH.md) 和 [扩展对照](../../testing/results/2026-10/IPHONE13-COMPETITOR-EXPANDED-20261004.md)；先恢复连接及正常包门槛，再实测对照/修完整采样。

2026-10-02 接续：用户优先要求局域网碟中谍大文件。本轮正常Debug实机复现S03频繁缓冲，修正LAN储备及回退后用旧续播锚点无法恢复储备的确定缺陷。86核心测试/设备构建/签名/preflight通过，正常包 `8a3e77e1…` 保留数据安装且无变量启动；原故障位置回退后观察638秒，最初28秒2次缓冲，随后610秒无新增活动缓冲，原画LAN/末计数4/丢帧13。PX-01/02/03/20/21保持进行中，真实回退缺陷已闭环不等于整片或全格式族验收；S01双入口持续/退出/热续播已补，MI2仍供流不足而自动12Mbps接手恢复（后段不算原画）；UX-06正式采样INSUFFICIENT/0手势，Mac锁屏阻止GUI排查；Lenna默认真实播放/退出已观察但有效配对0。详见 [本轮记录](../handoffs/2026-10/2026-10-02-IPHONE13-JELLYFIN-STALL.md)。

2026-10-01 17:32 接续核对：PX-01～21、UX-01～06 未验收状态全部保留。UX-06 采样新增 USB/DVT CoreProfile 原始事件及解压解析证据，但显示帧映射、完整性与真实滚动仍未验；Lenna 配对未完成。本轮未操作 App 或核对设备安装身份，无新增功能通过结论。详见 [采样接续](../handoffs/2026-10/2026-10-01-COREPROFILE-RAW-PROBE.md)。

状态只使用：待开始、进行中、待验收、受阻、已验收。写完代码不能直接标为已验收；受阻项必须保留原因和下一步，不可从总账移除。后续每次恢复任务先读本表，每批结束逐项核对所有编号，更新本批证据与下一批入口。新增需求追加编号，拆分任务保留原编号关联，取消或调整范围需记录用户决定。

| 编号 | 批次 | 用户需求 / 交付范围 | 状态 | 完成条件 / 当前缺口 |
| --- | --- | --- | --- | --- |
| PX-01 | 1 | Jellyfin / 设备文件首帧一致性 | 进行中 | 同片、同轨、同字幕、同网络交替测试；记录冷/热启动中位数与慢样本，确认额外等待消除 |
| PX-02 | 1 | 快进、回退与远距离 seek 响应 | 进行中 | 区分缓存命中和未缓存定位；2026-09-29 S01 Jellyfin 暂停后定位 624.415 秒、恢复播放单次通过（时钟恢复约 1475 ms），双入口定位/听音及重复基线仍待补 |
| PX-03 | 1 | 自动画质、原画优先、必要回退 | 进行中 | iPhone 18 蜂窝 S19：稳定蜂窝下 Jellyfin 8 Mbps HLS、设备文件匹配后 2 Mbps HLS 各播放 10 分钟且记录 0 卡顿；设备文件原流曾复现 7.1 秒缓冲，Release 设备文件入口尚未启用转码路线。2026-09-28 受控降速暴露后台门槛误拦和候选对齐失败，已修正预测门槛与候选预热。2026-09-29 iPhone 18 蜂窝用 Apple 预编码静态 HLS 和 App 进程内限速，Jellyfin 与设备文件两个 Debug 入口均完成高档到低档的解码、时钟对齐和自动接手，交接附近无播放器卡顿记录；设备文件入口旧流接手前约 2.82 秒缓冲。2026-09-29 iPhone 13 S01 原画十分钟基线失败（247.710 秒持续停滞），自动回退候选解码后提前 11/15 秒而未对齐；已修正缓冲时的预热提前量，L0 解码反例通过；最新包 S01 十分钟原画单轮卡顿/丢帧计数 0，未触发回退，真实故障恢复及原始停滞根因仍待验。没有真人音画无感验收，最终包的测试素材时间轴修正尚待 DSM 会话恢复后实机复核。真实大片转码曾伴随 NAS/Container Manager 重启，暂不继续限速压测。播放中自动升档未实现；手动固定档位不被自动覆盖。证据见 [iPhone 18 蜂窝记录](../handoffs/2026-09/2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md) |
| PX-04 | 1 | 清晰度切换耗时与资源隔离 | 待开始 | 2026-09-13 用户要求暂缓；9 月 14 日再次明确只隐藏入口，不移除清晰度相关代码、请求接口与换流能力，保留自动原画判断和必要回退；后续按需要并经验证恢复 App 入口 |
| PX-05 | 2 | 点击 PiP 后回到系统主屏幕的体验 | 待开始 | 核对竞品实际操作与公开 API 可行路径；无法等价实现时记录具体边界，不以收起播放页冒充完成 |
| PX-06 | 2 | PiP 后台、恢复全屏、关闭与旋转 | 待验收 | 已有实现；补齐新包在 iPhone/iPad 的连续播放与恢复闭环，不能只测启动 |
| PX-07 | 2 | HDR / Dolby PiP 字幕 | 待开始 | 修复 PQ/HLG 跳过字幕合成；同时验证色彩、位深、元数据及音画同步 |
| PX-08 | 3 | 字幕大小缩放 | 进行中 | 9 月 13 日先修位图画布缩放错误；手动可调、重置、偏好保存及全屏/PiP 文本/位图分别验收仍待完成 |
| PX-09 | 3 | 字幕垂直偏移 | 待开始 | 可调、可重置，横竖屏及双语不裁切；全屏/PiP 一致 |
| PX-10 | 3 | 字幕显示延迟 | 待开始 | 支持提前/延后，方向明确，按视频保存，seek/切轨后仍正确 |
| PX-11 | 3 | 本地字幕导入 | 待开始 | 文件选择、读取、语言/编码、切换与持久访问；失败可恢复 |
| PX-12 | 3 | 播放器内部选季、选集 | 待开始 | 显示当前集与观看进度；不退详情页，保留偏好，快速连续选集不串源 |
| PX-13 | 4 | 当前时间设为片头 | 待开始 | 明确片头结束/区间；支持编辑、删除及按季应用，兼容冷开场 |
| PX-14 | 4 | 当前时间设为片尾 | 待开始 | 明确片尾开始；不同片长、下一集、彩蛋及自动跳过偏好验证 |
| PX-15 | 4 | 视频章节显示与跳转 | 待开始 | 使用实际章节数据，标明当前章节，准确跳转，数据加载不阻塞首帧 |
| PX-16 | 4 | 在线字幕搜索与下载 | 待开始 | 确定提供商后匹配语言/版本/季集；下载、失败处理与时间校准验证 |
| PX-17 | 5 | 投屏入口与播放恢复 | 待开始 | AirPlay 优先、DLNA 单独评估；接收端访问、认证、字幕和断开恢复全部验收 |
| PX-18 | 5 | Dolby Vision 支持与点亮识别 | 进行中 | 已有片源识别；P5/P8/P7 分开验证实际元数据/显示链路，证据不足不点亮 |
| PX-19 | 5 | Dolby Atmos 支持与输出识别 | 进行中 | 已有片源识别；DD+ JOC/TrueHD Atmos 和不同输出端分开验证，PCM 不冒充 Atmos |
| PX-20 | 1 | 原画音轨、字幕切换响应 | 进行中 | c868普通Debug/Xcode27同源396项/2跳过/0失败及15预检；兼容换轨保留旧播放、暂停Off反馈及原格式族证据保留。10-16离线8窗显示decoded后仍需缓冲/追赶，S03两次aligned→commit日志0.8～2.1ms，不当屏幕/听音提速；分析工具16项/报告总60项通过。Pad旧普通包三轮物理峰值927～950MiB、退出后约121～122MiB；新Allocations覆盖启动60秒但不覆盖释放，新增CPU资源警告Action:none，归属/稳定性仍开放。18已10-16 07:10 Wi-Fi覆盖最新同源包、25项偏好保持、实际启动台已核；NAS/播放未验。实际AUD/完整SUB/严格配对及9～21秒等待继续，见 [最新交接](../handoffs/2026-10/2026-10-16-HANDOFF-ALIGNMENT-AND-ALLOCATIONS.md) |
| PX-21 | 1 | 设备文件断点与轨道偏好对齐 | 进行中 | 已按 NAS/账号/文件版本保存恢复断点及音字幕；两入口补从头播放，78 项测试通过；文件真机已恢复 6311.8 秒及 DTS 轨道，从头保留 PGS。Jellyfin 详情停止快照已补；既有 JSON 解码崩溃根因仍待查；2026-09-29 iPhone 13 S01 两入口各三次退出回原详情及热续播成功，设备文件暂停退出和 Jellyfin 十分钟位置冷续播已补，两入口原画呈现前准备取消受控窗口已通过；HLS 取消/连续选片、文件变更、双设备及人工音画仍待验，关联 PX-01/PX-20 |
| UX-01 | 补充 | Jellyfin 相似作品标题裁切 | 待验收 | 已修正卡片固有高度；待真机核对两行标题、副标题、横向浏览与动态字体 |
| UX-02 | 补充 | 设备文件排序 | 待验收 | 排序/映射测试通过，真机已见日期和新菜单；待同目录交互复核，目录不递归统计大小 |
| UX-03 | 补充 | 服务网页扩大可用区域 | 待验收 | 已隐藏 TabBar，默认简洁浏览保留返回与菜单；待核对退出服务后导航恢复 |
| UX-04 | 补充 | 网页模式含义与有效性 | 待验收 | 已分开版本与简洁浏览，切换重载当前页；待真机验证页面版本与历史保持 |
| UX-05 | 补充 | iPad DSM 登录恢复与 VPN 环境专项 | 进行中 | 2026-09-30 iPad 现场登录后两次正常冷启动均完成 DSM/File Station 自动登录、LAN 发现及 47 条刷新；原生设备测试 1 项通过，DSM/Jellyfin 局域网/公网四接口 HTTP 200 / 有效 JSON，HTTP proxy=false。历史存在 `urlError:-1005`、DSM API 403 及无凭据跳过恢复；当前成功不能排除间歇故障或 VPN 隧道。WDA 8103 于 21:50 恢复 ready，UI/后台恢复与 VPN A/B 待验；见 [当日 iPad 环境续查](../handoffs/2026-09/2026-09-30-IPAD-ENVIRONMENT.md) |
| UX-06 | 补充 | iPad 启动台与海报滑动卡滞 | 进行中 | 默认服务列表惰性布局、海报后台预解码及真实像素缓存计费已实现，最新 `dd26df8f…` 包已安装 iPhone 13/iPad；构建签名/preflight 和初步界面操作通过，同条件帧时间及长期流畅待验。见 [滚动专项](../handoffs/2026-09/2026-09-30-IPAD-SCROLL.md) |
| UX-07 | 补充 | 播放状态与缓冲实时速度 | 进行中 | 时间/实收速度/网络/电量及转圈下速度已实现，2012源正常包13/Pad安装与选定图核对通过；18连接受阻待装；全性能/音画验收仍开放。见 [本轮交接](../handoffs/2026-10/2026-10-15-PLAYER-STATUS-SUBTITLE-AND-SEEK-EVIDENCE.md) |

批次顺序为 1 → 2 → 3 → 4 → 5。第 5 批的格式识别、技术核验可提前收集证据，但不抢占第 1 批基础播放优化；PiP 字幕涉及 HDR 时同步核验 PX-18。iPhone/iPad、连续播放、暂停/恢复、退出续播、音轨和双语字幕是各批共用回归项，不能因新功能而删减。L3 正式电影矩阵仍按 runbook 的 S01 → S18 推进并补齐 S19；日常 L0/L1/L2 按 [分层开发与回归流程](../../development/playback-development-workflow.md) 的影响范围执行，探索性数据单列。批次 1 内先稳定共用生命周期，再建立代表集性能基线；不以单片压力测试替代跨格式回归。

## 当前批次记录

- 2026-09-30 21:47 ISO 专项：iPhone 18 双入口零读取失败共用旧本机端口；补 ISO 监听自检/失效重建/并发注册及资源释放，3 项定向 XCTest 通过，签名包 `343f0b3a…` 已安装启动。真实蜂窝 ISO 播放与切网复验待完成，不能据此关闭 PX-03。见 [ISO 专项记录](../handoffs/2026-09/2026-09-30-ISO-CELLULAR.md)。

- 2026-09-30 15:09 PX-03 / UX-05 接续：iPhone 13 `86f6…` 包 S01 局域网原画 trace `99B41B69` 超过 701 秒、时钟推进至 700.574 秒、650 条遥测卡顿/丢帧 0，局域网 Range 上游 HTTP/1.1，退出回详情；有界重试和同服拒绝决策 2 项定向 XCTest 通过。最终签名 `cbfff361…` 包已装两机；iPhone 短续播首帧前一次 301 ms 缓冲、首帧后无新增卡顿，不能把前包长播归给最终哈希。iPad 今日保存登录后两次冷启动恢复，原生四接口请求均成功、HTTP proxy=false；旧间歇故障、真机重试故障注入、人工音画和 VPN A/B 仍待验。详见 [iPhone 13 续查](../handoffs/2026-09/2026-09-30-IPHONE13-STALL.md) 与 [iPad 环境续查](../handoffs/2026-09/2026-09-30-IPAD-ENVIRONMENT.md)。

- 2026-09-30 10:35 PX-03 路由优化与新包短回归：Jellyfin 同服 LAN 信息暂不可用时加 2/6 秒最多两次异步重试，仍必须公网/LAN 服务器 ID 相等才走 LAN，ID 不同拒绝。Debug iphoneos 构建签名、preflight、diff 检查通过；新包 dylib `86f6c8eb…` 保留数据安装 iPhone 13 并无变量启动。DSM 恢复，10:33:15 LAN 同服验证成功，S01 trace `B2246D1A` 原画约 37 秒实际画面/时钟到 36.766 秒，36 条遥测卡顿/丢帧 0、停止事件 1，上游 `192.0.2.2:8096` HTTP/1.1。未人为触发首次验证失败，重试故障分支尚缺真机证明；新包也未跑 LAN 十分钟。旧包 247.710 秒停滞根因/真实回退仍待取证，PX-03/PX-21 均进行中，见 [当日停滞续查](../handoffs/2026-09/2026-09-30-IPHONE13-STALL.md)。

- 2026-09-30 10:24 iPhone 13 S01 低负载十分钟续查完成：同一已验 f08bf… 包从头单路原画 trace `FC0BA914`，监测约 603 秒，557 条带时钟遥测推进至 621.598 秒、读入增至 251,391,044 bytes，卡顿/丢帧 0、停止事件 1，实际画面与回详情已确认，未触发自动降档。旧次 247.710 秒停滞未重现，根因/真实故障接手仍待取证。此次代理上游实际走 Jellyfin 公网域名 HTTP/2（Wi-Fi，`cellular=no`）：10:00:48 同服 LAN 验证报 `publicInfoUnavailable`；10:24:38 重进库后 LAN 验证成功，发现暂时失败后缺少重试的优化点。NAS 后续在线 CPU 29% / RAM 20% / 磁盘 93% / uptime 1天13小时，DSM 恢复；iPad 未接 USB。PX-03/PX-21 仍进行中，下一项仅给 LAN 验证补有界重试和定向回归，见 [当日停滞续查](../handoffs/2026-09/2026-09-30-IPHONE13-STALL.md)。

- 2026-09-30 iPhone 13 下一批开始：USB 仅 iPhone 13，WDA ready；HEAD 9a9941c 和所有未提交改动保留。Jellyfin/DSM 局域网公开接口 HTTP 200，已保留数据安装已验 f08bf… 正常包并无变量启动，启动台 CPU 43% / RAM 20% / 磁盘 92%，DSM 新进程恢复中。按 [当日停滞续查](../handoffs/2026-09/2026-09-30-IPHONE13-STALL.md) 只用 S01 低负载取证，PX-03/PX-21 保持进行中。

- 12:41 收尾刷新资源快照：NAS 在线，CPU 49% / RAM 20% / 磁盘 92% / uptime 15小时41分钟（开播前15小时25分钟），未见本轮重启；Jellyfin LAN/公网均 HTTP 200 / 10.11.11。正常 iPhone App PID 48256、WDA ready，播放已全部退出。

- 2026-09-29 12:40 本批收尾：最新正常 f08bf… 包已保留数据安装两机、明确无测试变量启动。iPhone 13 S01 Jellyfin 原画 trace 14B2F3F7 单路观察 606 秒完成，实际画面、时钟和读取持续推进至 601.310 秒，556 条相关遥测，卡顿/丢帧计数均 0，停止事件 1、上报失败 0；没有自动回退请求。这只证明该包本轮十分钟未重现，不证明旧包原始停滞根因已解决，也不能代替真实故障下的回退恢复或人工听音。旧 37b0… 的持续停滞与两次候选对齐失败证据保留，修正了“缓冲仍按播放意图提前预热”的回退缺陷，实际解码反例通过。4cdd… 候选双入口原画呈现前取消有效窗口通过。iPhone 13 WDA ready、正常 App PID 48256、所有视频已退出；USB 仍为 iPhone 13+iPad，无本轮新 Nastart 崩溃（最新仍 9月28日20:21）。iPad 正常 f08bf… PID 7846，新进程12:26:02仍无保存 DSM 凭据；四接口/HTTP代理指标已验，UI/登录恢复未验。全部未提交修改保留，未改 VPN/Wi-Fi/NAS、未跑大电影限速转码。

- 2026-09-29 12:25 设备文件 S01 有效取消窗口通过：4cdd… 包准备本地原画后 held(8秒)，返回原文件夹使 released(cancelled=yes)，等待超过原延迟仍在原文件夹，无迟到播放器/首帧。与 Jellyfin 原画一起补双入口呈现前取消证据，不扩大到 HLS 或完整资源矩阵。最新 f08bf… 回退候选 Debug 构建/签名通过；其 Release 无签名编译也通过，现有 iCloud 签名限制仍保留。

- 2026-09-29 12:21 缓冲回退修正 L0 通过：预热提前量现在独立参考实际推进状态；缓冲中保留用户播放意图、候选从冻结的旧时钟开始，正常推进/暂停逻辑保持。模拟器实际 1 项解码 XCTest 通过，包含冻结时钟的候选首帧/对齐/恢复播放、暂停候选、正常推进候选及 KS 原画预热。设备 Debug 构建通过，正常签名候选 f08bfde1c3f3f9eaa811bb7eb7f4f43b1e31a32c31589b7458b4e17402c11bd2 待实机。首次测试卡在模拟器启动已留采样并终止，单设备重跑通过；不是断言失败。准备取消钩子对应的 Release 签名被现有 profile 缺 iCloud 权限阻止；CODE_SIGNING_ALLOWED=NO 的该版 Release 编译通过，只证明编译、不证明可安装的 Release。最新缓冲回退改动待补 Release 编译。单设备 XCTest 已报告 1 项 Passed，但 xcodebuild 收尾仍挂起，采样后终止；不记整个工具正常完成。

- 2026-09-29 12:18 Jellyfin S01 有效取消窗口通过：取消候选 4cdd… 包，准备 trace AAC904DA 已建立本地 Range；诊断 held(8秒)→返回搜索列表→2.662秒后 released(cancelled=yes)，等待超过原延迟仍在同一搜索页，无播放器/首帧/开播事件。截图与实际请求 ID 完整；这项仅覆盖原画已准备、呈现前离开，不覆盖 HLS/连续选片/全部资源回收。WDA activeAppInfo 的 env={} 来自其 XCUIApplication 对象，不能用于证明实际进程环境；本次等待确由 App held 日志证明生效，收尾须终止后明确无变量启动。

- 2026-09-29 12:13 持续播放失败补证：37b0… 包 S01 Jellyfin 原画 trace 25F1BD23，监测 606 秒已退出，但播放器在 247.710 秒起持续 buffering，末段时钟和 bytesRead 均不再推进，stallCount=1，最终 stallDuration 约 439 秒；不能记十分钟稳定通过。局域网接口持续 HTTP 200。自动回退两次准备/解码 HLS 成功但候选起点领先停住的时钟 11/15 秒，alignment 均被拒绝，未接手。正在修正“想播放但正在缓冲”被误当持续推进的预热提前量；原画停止读取的初始原因仍待取证，不将回退修正称为原始故障根因。仅 S01 自动回退发生转码，没有大电影/人为限速。

- 2026-09-29 12:04 iPad 请求路径实测完成：原生设备 XCTest 实际 1 项通过 / 0 失败；DSM API Info 与 Jellyfin Public 的 LAN/公网四地址均 HTTP 200、有效 JSON、API 成功。四次 URLSession 事务 isProxyConnection=false，LAN 使用 HTTP/1.1，公网使用 h2，均未复用连接。此指标只排除这些请求的 HTTP 代理连接，不能证明 VPN 已关闭或排除 IP 隧道/间歇故障。新进程仍报 restore.missing_credentials；UX-05 保持进行中。附件留在本机 continuous/ipad-route.xcresult 与 ipad-route-attachments/，不含请求凭据。

- 2026-09-29 12:02 下一批开始：两机 USB/iPhone WDA/App/Jellyfin 核验完成，既有修改保留；S01 trace `25F1BD23` 原画单路持续播放进行中，不能记十分钟完成。Debug 准备结果受控等待已构建，3 项取消/迟到/旧请求保护测试通过，真机窗口待验；iPad 正在补实际网络代理指标。PX/UX 原状态保留，详见 [持续播放与取消专项](../handoffs/2026-09/2026-09-29-CONTINUOUS-CANCEL.md)。

- iPad 补充授权核验：用户授权必要时远程解锁，凭据未写入项目；现场已解锁、无需输入。UX-05 的 DSM 保存登录/冷恢复与 UI 自动化缺口保持，不因解锁授权而提升验收状态。

- 最后现场：iPhone 13 刷新结束后 NAS 47% CPU / 20% RAM / 92% 磁盘 / uptime 12小时54分钟，正常 App PID 47083、无变量、WDA ready；两机 USB 仍在。iPad 无效 8103 转发已清理，正常包启动成功，UI WDA 仍未 ready。源码/文档差异检查通过，未提交或清理未知文件。

- 2026-09-29 本轮收尾：两机已覆盖回正常 `37b0…` 候选包并启动，无新增大电影播放/转码，未改 VPN/Wi-Fi/NAS；全部既有未提交修改及 KSPlayer 未跟踪文件保留。本轮新增 HTTP 状态诊断修正、Jellyfin 轨道偏好/详情同步、可显式配置的设备无凭据网络专项 XCTest。8 项定向检查、最终相关 2 项复测、iPad 1 项真实四接口专项、设备构建与 preflight 通过。iPhone 13 S01 热/冷/从头选轨状态闭环完成；听音、准备中取消有效窗口、十分钟基线及双设备播放未验，PX 状态不升为已验收。iPad 缺保存登录，UI 自动化超时仍待处理，UX-05 不作登录恢复验收。

- 2026-09-29 09:50 iPad 专项四接口实测完成：重启仅该设备 testmanagerd 后，iPad 18.3.1 原生单元测试实际执行 1 项、0 失败；DSM LAN/公网 API Info 与 Jellyfin LAN/公网公开信息均成功返回 API JSON。同一新进程仍报 `restore.missing_credentials`，当前未连接不能直接归因于网络/VPN。没有切换 VPN，当前 VPN 是否开启仍待界面核实，间歇故障也未排除。UX-05 保持进行中，待保存登录一次及冷启动/后台恢复。iPhone 13 最终包还补从头播放首帧 0.073 秒、国语与字幕关闭保持；热/冷续播首帧 762.782/770.697 秒，三路均有停止事件及实际画面，无新增 Nastart 崩溃报告；PX-20/PX-21 保持进行中，听音未验。

- 2026-09-29 09:46 PX-20/PX-21 冷启动补证：最终候选 iPhone 13 S01 Jellyfin 热重开、终止后无变量冷启动续播均确认国语音轨/字幕关闭仍选中，冷续播显示约 12:58 与实际画面。不能替代听音、完整矩阵或双端验收。iPad 不依赖 UI 的测试宿主已正常启动，最新日志再次出现“未找到已保存的 DSM 凭据，跳过会话恢复”，现已不只是历史证据；四个无凭据网络接口测试进行中，VPN 尚未归因。

- 2026-09-29 09:44 PX-20/PX-21 修复复测：第一候选仍被详情页默认 selection 覆盖，未记通过；最终候选补详情加载/停止后的偏好同步并保留用户手动选择优先。最终设备构建、2 项相关回归复测及原 7+1 项定向检查通过。iPhone 13 S01 热重开 UI 已确认国语选中、字幕关闭选中，位置约 12:50 保留；冷启动复测进行中，实际听音未验。包哈希 `37b0fc03e608700b0a2bbe1734e7f4690bbe28b35a5cc7ce5b321e7826656f50`。iPad 开发模式 Enabled、已解锁/背光亮、开发镜像 usable；有效签名的专用 WDA 仍自动化初始化超时，转做不依赖 UI 的设备网络测试。

- 2026-09-29 09:33 PX-20/PX-21 新反例：iPhone 13 S01 原画在暂停中 +15/-15 秒恢复时钟分别约 92/369 ms，国语切轨及关闭字幕分发成功；退出热重开却恢复日语/默认中文字幕（trace `3282F9D0`→`02F1FDA8`），位置仍恢复。源码定位：原本只为设备文件保存本地轨道，Jellyfin 每次采用默认值。已补按 Jellyfin 服务器/账号/媒体源/文件大小隔离的偏好键，保存源轨道 ID，失效轨道回默认，明确关闭字幕保留；Jellyfin 位置仍由服务器续播负责，显式轨道切换优先于旧偏好。设备构建与 7 项定向 XCTest 通过，真机修复复测进行中。历史声音/字幕实际呈现与完整矩阵未因此验收。

- 2026-09-29 09:24 继续调试：用户新增 iPad 环境专项，追加 UX-05，已完成安装前偏好/历史诊断核验，确认存在无凭据跳过恢复；尚未将 VPN 认定为根因。iPhone 13 正常进程无测试变量，Jellyfin 两地址 HTTP 200。修正 Jellyfin 从任意错误描述数字推断 HTTP 状态的问题，改为 SDK 类型明确的响应错误；设备 Debug 构建和 2 项真实状态/传输错误反例测试通过，准备保留数据安装及 S01 回归。其余全部 PX/UX 状态保留。

- 2026-09-29 07:55 首轮收尾：设备文件冷启动已补真实画面，保存 34.036 秒→首帧时钟 34.110 秒（差约 0.074 秒），停止事件和回原预览截图齐全；结合 Jellyfin 十分钟位置冷续播，S01 两入口导航/热重开/冷断点的本轮有限闭环已完成。准备中取消有效窗口、短片头规则及一次上报响应、人工音画、长期基线仍待验；PX-01/PX-02/PX-03/PX-20/PX-21 均保持进行中。当前 iPhone 13 无变量正常启动台，WDA ready，Jellyfin 公网/局域网 HTTP 200，NAS 44% CPU / 19% RAM / 92% 磁盘；iPad 未验收。未请求大电影视频或限速转码，未改网络。证据索引及后续入口见 [当前交接](../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。

- 2026-09-29 Jellyfin 深位置对照完成：S01 暂停后定位 624.415 秒，时钟恢复事件约 1475 ms；恢复播放/退出/无变量冷启动后续播首帧 628.510 秒，实际画面可见。这排除了本轮“所有跨进程断点都丢失”的推断；短片头规则及一次上报 -1017 仍待查。PX-02/PX-21 增加该单次证据，保持进行中，不作完整矩阵或听音验收。

- 2026-09-29 冷启动短断点：设备文件已保存 15.582 秒、首帧时钟恢复 15.646 秒，但冷启动后视频画面截图尚缺；Jellyfin 短片头断点重启后从 0.137 秒开始，待核对服务器续播规则与回写结果，正在补约十分钟位置对照。上报 -1017 确实存在，日志的 281 是描述数字推断，未确认真实 HTTP 状态。PX-21 不记冷启动双入口验收完成。另 HEAD 已被本任务之外的 07:26:57 提交推进到 `9a9941c`；本任务只更新记录，未清理或提交源码。详见最新交接。

- 2026-09-29 设备文件续播证据补齐：暂停位置 89.31 秒，下次首帧时钟 89.460 秒（约 0.15 秒差）；三次已取到停止事件。准备中离开尝试实际赶上播放器呈现，已退出，未捕获准备窗口，不计取消通过/失败；继续待验。PX-21 保持进行中，冷启动断点正在补核实，详见交接。

- 2026-09-29 白天设备文件 S01：iPhone 13 家中 Wi-Fi / 同一交接包，首轮从头约 34.6 秒（原画 DSM 局域网上游）后退出同一预览；补两次续播往返，第二轮暂停后退出，画面及诊断留本机。首轮卡顿计数 0，无本轮新 Nastart 崩溃报告；双入口各三次导航闭环已补，准备中离开、冷启动断点及人工声音仍待验，PX-01/PX-02/PX-03/PX-20/PX-21 状态不变。见 [最新交接](../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。

- 2026-09-29 白天 Jellyfin S01：iPhone 13 / 同一 `46df8558…` 包 / 家中 Wi-Fi，三次播放后退出均回原详情，后两次续播显示真实画面，恢复首帧位置 50.910 秒、112.116 秒；三路停止事件已导出。首轮约 52 秒无卡顿计数，第二轮一次计数发生在首帧前约 791 ms，首帧后未增加；不作零卡顿或音画验收。元数据/上报走公网，原画 Range 上游为 NAS 局域网；另有上报 -1017 / httpStatus=281 待查。PX-01/PX-03/PX-21 保持进行中，未证明服务器断点保存或重启恢复。见 [最新交接](../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。

- 2026-09-29 白天接手环境核验完成：HEAD/既有修改保留，diff 检查通过；iPhone 13 USB/WDA ready，以 `46df8558…` 交接包保留数据覆盖安装、无测试变量启动，Jellyfin 局域网 HTTP 200。iPhone 18 不在 USB；iPad 已有 Nastart/WDA 安装但包身份及功能未验收。NAS 初始 CPU 30%、RAM 19%、磁盘 92%，登录恢复及刷新后资源仍需确认；按交接先 S01 单路短播，禁止大电影限速转码。PX-01/PX-02/PX-03/PX-20/PX-21 均保持进行中，无新增播放通过结论。逐项现场见 [当前交接](../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。

- 2026-09-27 夜间：iPhone 18 Pro Max 蜂窝 S19 旧包 `428F6529` 约 1.7 秒首帧后反复缓冲，约 93 秒内三次缓冲，19:54:42 发起旧固定 6 Mbps HLS 候选；按用户要求停止真机测试，未证明交接成功。随后按“高画质且流畅、切换不明显”调整 Jellyfin 策略与单元测试；设备文件仍无服务端清晰度流。见 [iPhone 18 蜂窝选档记录](../handoffs/2026-09/2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md)。PX-03 继续进行中。

- 2026-09-27 晚间续查：iPhone 13 Jellyfin S19 自动降档已实机交接到 10 Mbps HLS，跳到约 29 分钟后 2 分钟无新缓冲；交接前原画仍缓冲且约耗 25 秒，PX-03 继续进行中。iPhone 18 蜂窝场景双入口出现播放器 24–69 ms 零字节报错，诊断指向本机播放代理未接收请求；新增回环自检、监听器失效重建及诊断点，iPhone 13 回归首帧通过，iPhone 18 蜂窝切换尚待复现。iPad 重启 DSM 未连接查明为未保存自动登录凭据，新连接默认保存至钥匙串并澄清卡片状态；iPad 断开，尚未安装这轮包。证据见 [iPhone 13 S19 缓冲记录](../handoffs/2026-09/2026-09-27-IPHONE13-S19-BUFFER.md)。

- 2026-09-27 续查：用户手动复现 Jellyfin 局域网 S19 原画在约 26 秒内 6 次缓冲，推翻短样本“已流畅”的推断。修正 30 秒内 3 次短缓冲的自动降档门槛，加入代理暂停下载时间诊断；HLS 候选此前 20 秒预热失败，仍未证实能解决卡顿。iPad 9 代已安装当时最新 Debug 包，静止页无持续 CPU/主线程挂起证据；滑动卡顿待实际滑动轨迹和优化编译对照。见 [iPhone 13 S19 缓冲记录](../handoffs/2026-09/2026-09-27-IPHONE13-S19-BUFFER.md)。PX-03 保持进行中。

- 2026-09-27 初始阶段 iPhone 13：S19 设备文件公网原画复现频繁缓冲。公网上游经本机 Range 代理时，首帧后才把 KSPlayer 稳态缓冲目标增至 4 秒，seek 前恢复短目标；该阶段安装包前进/回退与退出真机可操作。跨位置/网络样本不可作受控性能结论，约 80 秒仍有 3 次缓冲且最长约 8.7 秒，PX-01/PX-02/PX-03 均保持进行中。该阶段 Jellyfin 自动降档候选关闭，杜比实际输出未验收。证据和后续对照见 [iPhone 13 S19 缓冲记录](../handoffs/2026-09/2026-09-27-IPHONE13-S19-BUFFER.md)。

- 2026-09-21 GitHub 接续：按用户要求同步 main，自动降档候选默认关闭，保留原流实测基线；蜂窝 S19 已复现两入口缓冲，跨时段/不同轨道记录不做性能比率，详见 [蜂窝实测](../handoffs/2026-09/2026-09-20-CELLULAR-S19.md)。下一步继续同条件 Jellyfin 重复及回压/缓冲观测，不把源码/测试通过视为真机验收。

- 2026-09-20 弱网：用户明确流畅优先于清晰度，原画作为健康网络默认路径，必要时允许服务端降码率。新增 Greenfield Jellyfin 运行时卡顿降档，复用已有候选预热/交接；设备文件现有备用地址仍是原流，不能降码率。杜比实际输出仍未验收。策略、验证与缺口见 [弱网接续记录](../handoffs/2026-09/2026-09-20-ADAPTIVE-PLAYBACK.md)，PX-03 保持进行中，PX-04 手动入口仍隐藏，其余 PX/UX 状态不变。

- 2026-09-20 Mac：已修复 ASan 捕获的退出时字幕 AVStream 悬空引用（先清理选中字幕，再释放播放器；新增幂等反例测试）。9 月 19 日 S03 ASan 记录 8 次结束，覆盖字幕退出、快速重开、暂停定位与切音轨，未捕获 ASan 报错。Greenfield Jellyfin 改为默认原始流优先，跳过启动测速及码率/大文件门槛，保留能力回退与清晰度接口；最终设备构建、96 项 XCTest、23+4 项 Python、preflight、签名/链接检查通过，正常包已安装启动。06:03 仅重启设备端 testmanagerd 后 WDA 已恢复，会话/页面树/设备与启动台点击验证通过；新策略真机播放回归及配对性能仍待验；9 月 13 日 SIGBUS 不据此宣告解决。全部 PX/UX 状态不变。见 [接续记录](../handoffs/2026-09/2026-09-20-MAC-CONTINUATION.md)。

- 2026-09-15：用户要求将 Mac 项目与接续记录推送 GitHub main，转至黑群晖继续。使用 [9 月 15 日接续指南](../handoffs/2026-09/2026-09-15-NAS-CONTINUATION.md)，本轮没有新增生产源码改动；优先补受控时序/退出崩溃的可复现证据，暂停继续扩大核心并发改造，正确性稳定前不比较速度。所有 PX/UX 原状态保留。

- 2026-09-14 Mac：已验证 NAS `4ccb161` 的正常设备构建与 94 项 Swift 测试，包含新增 16 项，全部通过；preflight、23+4 项 Python 测试及签名/链接检查通过。最新 ASan 包已安装并显式重启，通话后已完成 S01 Jellyfin 从头画面、时钟推进及 00:26 暂停观察；退出/重开/切轨/暂停定位及受控 SDK 集成仍待验，SIGBUS 未解决，未开始性能比较。见 [Mac 验证记录](../handoffs/2026-09/2026-09-14-MAC-VALIDATION.md)。PX-21/PX-20/PX-02/PX-01 和其他 PX/UX 状态不变。

- 2026-09-14 NAS 第六批：PX-01/PX-02 继续进行中。新增 playback_compare_entries.py，按 manifest 校验同片版本/轨道/断点/设备/网络/正常构建/冷热，至少三组独立双入口配对；拒绝失败、缺字段、重复 trace 和混合引擎/播放方式，不输出误导性聚合。新增 11 项 Python 测试，全部 23 项及 preflight 通过；使用 [三组模板与比较说明](../handoffs/2026-09/2026-09-14-NAS-PAIRED-COMPARISON.md)。无真实播放性能结论，16 项 Swift 待验项保留。

- 2026-09-14 NAS 第五批：PX-01/PX-02 继续进行中。离线报告按 trace/plan 严格归属，拒绝跨会话准备/测速回退和旧计划串写；缺失/歧义事件列行号，旧日志标注兼容模式。新增 9 项 Python 测试，全部 12 项及 preflight 通过。仅工具/文档修改，无新增性能或真机结论，见 [日志归属变更卡](../handoffs/2026-09/2026-09-14-NAS-TRACE-ASSOCIATION.md)。

- 2026-09-14 NAS 第四批：增加实际播放 tracker 的本地更新资格，预热不抢占；旧快照/旧 stopped 触发的刷新在新播放开始后失效。新增 4 项 XCTest，四批累计 16 项均待 Mac。preflight、3 项诊断测试、4 项 Agent 测试通过；源码确认 Jellyfin 请求/资源 timeout 配置 20/60 秒，未调整参数。详见 [活动播放身份变更卡](../handoffs/2026-09/2026-09-14-NAS-ACTIVE-PLAYBACK.md)。PX-21/PX-20 仍进行中；下一步为 Mac 编译/集成检查点，服务端跨 tracker 顺序和 SIGBUS 未解决。

- 2026-09-14 NAS 第三批：PX-21/PX-20 继续进行中；单 tracker 回调按登记顺序交付，网络使用单 worker 有界队列，合并旧进度并保留最终 stop，本地退出快照不等网络。新增 4 项 XCTest，三批累计 12 项新增均待 Mac。preflight、3 项诊断测试、4 项 Agent 测试通过；跨 tracker 顺序、请求超时及原 SIGBUS 尚待验证，详见 [上报顺序变更卡](../handoffs/2026-09/2026-09-14-NAS-REPORT-ORDERING.md)。

- 2026-09-14 NAS 第二批：PX-21/PX-20 继续进行中。上报捕获准备时 client/认证会话，替换账号后旧事件与响应失效；继续观看刷新只发布当前会话最新请求，首页和详情增加旧账号响应保护。新增 4 项 scope XCTest（两批共 8 项新增均待 Mac 执行）；preflight、3 项诊断测试、4 项 Agent 测试通过。具体变更卡、适用边界及 L1/L2 清单见 [NAS 会话隔离](../handoffs/2026-09/2026-09-14-NAS-SESSION-ISOLATION.md)。同会话 HTTP 上报顺序和 JSON 解码崩溃仍未解决，不改变其他任务状态。

- 2026-09-14 用户要求结合下一阶段目标与既定矩阵优化开发方式。已采用 [共用逻辑优先、四层回归及明确退出条件](../../development/playback-development-workflow.md)，将所有 PX/UX 映射到原批次；S19 转为相关压力样本，完整 76 单元和历史状态保留。本次仅调整流程，未新增真机验收结论。下一步先补上报顺序/会话隔离的反例和证据，再在 Mac 验证并建立正常构建代表集基线。

- 2026-09-14 NAS 首批（`work/nas-20260914`）：PX-21/PX-02/PX-20 继续进行中。已修改未开始播放即取消后的迟到事件保护、详情停止快照与异步元数据分离、无效时钟及 tick 越界保护，新增 4 项 Swift 回归用例。新增 Swift 尚待 Mac 编译/XCTest/真机验证，JSON 解码崩溃根因仍未确认；独立上报任务交错、账号切换及旧列表响应隔离仍待核查。源码时序、边界和 Mac 清单见 [NAS 生命周期分析](../handoffs/2026-09/2026-09-14-NAS-PLAYBACK-LIFECYCLE.md)。其余 PX/UX 状态全部保留。

- 2026-09-14 白天转至单位黑群晖开发，无 Xcode/真机条件。当前修改及接续指南随 Mac 基线推送 main；源码排查、离线诊断和测试编写按 [NAS 接续指南](../handoffs/2026-09/2026-09-14-NAS-DAYTIME-CONTINUATION.md) 推进，Swift 新改动留待 Mac 编译/设备验证，不改变本表未验收项状态。首先追查退出后 JSON 解码崩溃与断点生命周期。

- 2026-09-13 用户再次明确：以 S19《指环王1》对齐设备文件/Jellyfin 播放体验，先修首帧、续播及压力切轨下丢声音/字幕；清晰度不能保证流畅时先不提供手动入口。PX-01/PX-02/PX-20 继续进行中；PX-04 暂缓，不取消。UX-03/UX-04 追加服务卡片卡死回归。其余 PX-05～PX-19 和 UX-01/UX-02 原状态与需求全部保留，不因本轮调整视为完成。
- 9 月 13 日续测：75 项回归通过并安装最终包；位图字幕画布缩放、旧显示组叠加、音频配置恢复及退出断点已修正。新增 PX-21 记录设备文件重开不续播/不保留字幕的已复现差异。PX-01/PX-20 仍待严格同条件对照、实际听音和完整字幕验收，详见下方手记。
- 本轮证据及剩余项见 [2026-09-13 双入口与服务浏览修复](../handoffs/2026-09/2026-09-13-ENTRY-PARITY-AND-WEB.md)。


- 2026-09-12 继续 S19：新增 PX-20 单列音轨字幕切换。复现 HLS+PGS 切原画被旧烧录判断拒绝；本批改为查询 KS 实际位图字幕解码能力、提前选择默认内嵌字幕、同轨选择幂等、外置字幕不要求内嵌轨道 ID。详情页提前调度已有测速。39 项播放测试、设备构建和 preflight 通过，新包安装；真机结果见 S19 专项。HLS 本身仍需要服务器生成新音轨/烧录字幕，不能用本地切换结果冒充 HLS 秒切。

- 2026-09-12 新增 UX-01～UX-04，详见 [非播放体验修正](../handoffs/2026-09/2026-09-12-NONPLAYBACK-UX.md)。排序、卡片布局和网页模式已修改，65 项播放/非播放测试、设备构建及 preflight 通过；真机交互核对后更新状态。新增项不替代任一 PX 编号。

- S19 已查出可复现的策略问题：81.9 Mbps 源被 80 Mbps 原画固定上限排除，虽然那次实测为 95.4 Mbps；同时发现首次网络快照切换可造成等待错测速任务。当前修复与真机待验项见 [S19 首帧差异定位](../../testing/samples/2026-09-12-S19-LORD-OF-THE-RINGS.md)。不将首轮仅修改等待并行就算作 PX-01 完成。

- 2026-09-12 用户补充：优先用新下载的 100 GB 以上《指环王 1》压力测试，登记为 S19，矩阵扩展至 19×4。首帧、深位置续播、未缓存远距离 seek、音轨/字幕/清晰度切换按 [S19 专项](../../testing/samples/2026-09-12-S19-LORD-OF-THE-RINGS.md) 逐项记录，关联 PX-01～PX-04、PX-06～PX-07、PX-18～PX-19；其余 PX 项继续保留。
- 前一轮缓存复核改动已完成源码与构建验证：当 Greenfield 自动原画候选在 Wi-Fi 上被不足/失败的测速限制时，30 秒后下一次播放可重新测量；充足样本仍复用 10 分钟，蜂窝和非原画候选不增加该复核。只改变后续播放的样本复核，不在播放中擅自升档。最终 34 项播放测试通过，设备构建与 preflight 通过；日志 `/tmp/nastart-20260911-cache-{tests,device,preflight}.log`。新包安装与 S19 结果见专项记录。

- 批次 1，2026-09-11：正在移除“先测速、再原流认证探测”的串行依赖。仅 Greenfield 自动播放、非私网 Wi-Fi 且音字幕具备原画候选条件时并行执行两字节 Range 探测；最终网络预算和兼容判断保持有效，选中原画才注册代理。取消或转入 HLS 时取消原流探测；增加 `originalRouteProbe.probeMs/overlapsBandwidth` 诊断。代码验证及实机结果完成后追加，当前不宣称已缩短屏幕首帧。
- 现有基线与证据：[9 月 10 日原画真机记录](../handoffs/2026-09/2026-09-10-ORIGINAL-PLAYBACK-DOLBY.md)。此前 32 项测试及单次 Jellyfin 原画观测不等同于本批 A/B 验收。
- 下一步：完成本次构建/回归与真机对照，依据分阶段耗时继续处理 PX-01/PX-02，再实施 PX-03。后续所有未验收条目继续保留在本表。

## 首要约束

首帧、seek、连续播放优先于手动清晰度切换。用户接受简化为自动画质；暂停将手动切换“秒切”作为主要优化目标。2026-09-13 已按用户最新取舍收起新架构手动清晰度入口；内部换流能力与自动路由仍保留，旧架构仅作历史回退。

两个入口虽已共用原画 Range 注册和 KS 渲染器，上游仍分别是 DSM 文件服务与 Jellyfin 原流，认证、重定向、端点响应、字幕和路由决策仍可能不同。9 月 20 日本地改动将 Greenfield 默认播放改为原始流优先，移除启动测速等待及预算/大文件门槛；显式码率请求、能力不足或原流不可用仍可进入 HLS。该新策略的真机双入口回归尚待完成。换流候选预热在替换时启动，不能未经测量将它归因于所有日常 seek 的延迟。

## P0：自动原画优先与同条件对照

- 同一文件、音轨、字幕、断点、网络及安装包交替测试设备文件和 Jellyfin；分离原画与 HLS、冷启动与热启动、邻近缓存与远距离未缓存 seek。重复测试记录中位数与较慢尾部，并保留屏幕证据。先确认差异，再改对应阶段。
- 将点击到请求就绪、路由/认证探测、上游首字节、解复用、定位、解码及呈现分开计时。区分实际内容请求与预先测速；进度上报等非必要操作不得阻塞视频路径。
- 设计目标为自动选择可稳定播放的最高质量，原画优先。按用户最新要求，Greenfield 默认在所有网络尝试 KSPlayer 原始流，不等待测速；预算保留给服务端回退，兼容检查仍有效。尝试原流不等于证明网络带宽充足，持续播放能力仍需真机验收。
- 后台测量及真实播放吞吐服务于回退判断。持续缓冲不足才触发降档；seek、暂停和短暂抖动不能触发自动降档。换流需冷却、避免反复升降，并保留失败时旧流继续播放能力。自动策略不会自行消除转码延迟。
- 画质选择、字幕搜索、剧集和章节数据按需加载，不能成为首帧前置条件。

## P1：PiP、字幕基础设置与播放器内选集

- PiP：验证点按启动、用户返回主屏幕后持续播放、恢复全屏、关闭及旋转。当前只收起应用内播放呈现，不能等同于回到系统主屏幕。竞品“一键回桌面”的触发条件与公开 API 可行性需单独核验，不以测试工具 Home 指令冒充产品实现。
- HDR / Dolby PiP 字幕缺失列为实际缺陷。现有 SDR 合成器跳过 PQ/HLG；改进必须同时验证色彩、位深和动态元数据，不能以画面出现或字幕出现替代正确 HDR 输出。
- 字幕先做大小、垂直位置、时间偏移、重置及本地导入；延迟正值明确表示字幕晚显示，逐视频保存同步偏移，样式可全局记忆。全屏与 PiP 使用一致偏好；ASS/PGS 位图样式能力需分别处理。
- 播放器内选季/选集，标明当前集和观看进度，复用现有上一集/下一集换源能力，保留倍速和语言偏好。选集清单异步读取，切集取消旧请求，防止过期结果覆盖新选择。

## P2：片头片尾、章节与字幕搜索

- “当前位置设为片头结束”与“当前位置设为片尾开始”明确区间含义，可编辑/删除；片头并非一定从 0 秒开始，支持冷开场后的自定义区间。跨集复用按剧/季显式应用，片尾可使用距结束时长，避免不同片长机械套用时间戳。默认显示跳过按钮，自动跳过由偏好控制；考虑片尾彩蛋。
- 有真实章节时显示名称、时间及当前章节，点击调用现有 seek；先复用容器/服务端数据，无章节时不伪造。章节数据异步载入。
- 字幕在线搜索安排在本地导入之后：匹配剧季集、语言、版本与文件信息，下载后立即可调同步。提供商、认证、失败回退另行确定。

## P2 并行能力验证：杜比与投屏

- 杜比信息分为“片源包含”“设备及路线支持”“本次输出证据充分”三层。普通 HDR 资格、片名、DV profile 或竞品图标本身均不足以证明本次正确显示 Dolby Vision。先记录真实解码格式、位深、逐帧元数据、显示路径和回退状态，再用已知参考样本验证；未知保持未知，不能统一点亮。
- DV P5 / P8 / P7 分开验证。现有 KS PCM 音频输出不能作为 Atmos 对象保留的证明；DD+ JOC 与 TrueHD Atmos 分别验证。详见 [杜比路线](../../project/DOLBY_PLAYBACK_ROADMAP.md)。
- 投屏先评估系统 AirPlay，DLNA 单独立项。接收端是否能访问 NAS、认证如何处理、格式与字幕是否可用、断开后如何恢复，都属于验收条件；手机 localhost 代理地址不可直接交给电视。杜比在外部接收端需重新验证。

## 技术边界依据

- [Jellyfin 转码说明](https://jellyfin.org/docs/general/post-install/transcoding/)：原画、重封装、音频转码、视频转码具有不同成本。按需生成新画质需要服务器生产可播放数据；这不意味着现有 15 秒换流已达到极限。
- [Apple HLS 格式要求](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/)：多档流需要对齐分段。预先编码并对齐的多档流与当前临时启动新转码会话不同，不能直接承诺相同切换延迟。
- [Apple 自定义播放器 PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player) 与 [标准播放器 PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player)：启动 PiP、应用进入后台、恢复界面是不同生命周期事件。
- [Apple HDR 资格](https://developer.apple.com/documentation/avfoundation/avplayer/eligibleforhdrplayback) 与 [Dolby Vision 指南](https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf)：设备资格不等同于当前输出；指南中的 DV 8.4 支持不可外推到所有 Profile。
