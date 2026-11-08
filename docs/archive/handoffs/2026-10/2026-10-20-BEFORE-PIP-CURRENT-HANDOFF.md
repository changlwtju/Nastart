# 历史当前交接快照（已被本日 PiP 批次替代）

# 当前播放与 Apple TV 任务接续

更新：2026-10-20。最新[输出关联诊断](2026-10-20-CLIENT-OUTPUT-CORRELATION.md)为当前接续，早期下文包与结果保留历史。[最新诊断批次](2026-10-20-SEGMENT-DURATION-COUNTEREXAMPLE.md) / [结构化结果](../../../testing/results/2026-10/SEGMENT-DURATION-COUNTEREXAMPLE-20261020.json)。先读[规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)、[分层流程](../../../development/playback-development-workflow.md)、[功能矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)/[竞品矩阵](../../../testing/COMPETITOR-DEVICE-MATRIX.md)；编号仅[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)，28项开放。

## 当前占用与用户约束

进行中：当前普通包06:48:25，iOS差异`35df7015b08ee4d929683983de8ac59d2d7111f94615bf85f38894fc25ae66ed`，173输入29库核验/5项iOS定向/15预检；私有指针`/tmp/nastart-output-correlation-evidence`。13/Pad已覆盖并核实际空环境首页，18有线安装/25项偏好/正常首页已完成；18已随用户离家，不再操作。13/Pad重新接回Mac，下一次动作先现场重核身份/安装receipt与源码。13 S03蜂窝双入口21/34metrics准确匹配唯一编码任务，内部8.583/6.909秒、maxStall1，预算/字幕不同，非性能修复。所有蜂窝已停App/恢复原SSID且独立图实际见Wi-Fi；三次原20秒工具实采到30秒的问题保留并已修私有时限。Pad临时Runner已主动停、尚未新包播放。下一步两入口基础回归，再做primer并行准备的离线取消/续播反例；不重做AV等待/删零seek。

19日预算批、[20日S19普通LAN补窗](2026-10-20-S19-LAN-COMPARISON.md)及[分片时长协议对照](2026-10-20-SEGMENT-DURATION-COUNTEREXAMPLE.md)及[初始零定位/主日志补证](2026-10-20-AV-ZERO-SEEK-AND-SERVER-LOG.md)均已收尾，无自有媒体、loopback服务或保活占用；源码未改。13今日核身份并覆盖同一22:20包，双入口45秒/KS原流，普通退出/原SSID及实际Wi-Fi图标/空环境首页/轨道偏好/零新增崩溃已核。JF t45不同位置内容cue待查，不标SUB通过。Phone持久WDA/既有转发保留，Pad临时Runner此前已停。

协议共10次尝试：S03首片4→2→2→4、等4.004秒媒体2→4→4→2及S19的4→2（第二窗清单守卫失败后停止剩余计划）。S03短片等媒体取齐1.961/1.979秒，相比4秒2.416/2.566秒有局部收益；S19完整2秒清单5,666,291bytes超过工具3MiB，未取媒体。所有尝试精确停止204、各组自有会话0，11份保存TS的SPS尺寸S03 852×480/S19 1920×1080；不当解码/蜂窝验收。旧蜂窝media清单仅单次上游，0.582/0.709秒、未见响应编码且接收计数近正文；App本就允许清单压缩协商，不重做假修复或盲改segment4/min1。计时衍生报告修正传输和/墙钟跨度口径，原始保留。

私有指针：LAN `/tmp/nastart-s19-lan-evidence`、工具`/tmp/nastart-s19-lan-tools`；协议`/tmp/nastart-segment-duration-evidence`、各组脚本在私有目录。未改手机网络/用户缓存/NAS/VPN或产品源码，全部包装任务已退。本机5窗否定简单删除零定位：零定位/省略定位均首片单GET、约5.11～5.21秒推进，2.25秒续播仅取片1。主日志与旧蜂窝FFmpeg候选输出stem对应，各窗只见一次编码命令，尚缺客户端PlaySession直接绑定；假设UA的公式匹配0/9，停止猜测。一个Mac loopback URLSession case可从metrics取得与服务端一致的UA哈希，但不等于iOS/反代保值或已完成绑定。下一步补慢窗首片可读/请求归属的最小观测，不重复零定位删除、AV等待、无新条件大片窗或盲改参数。

18用户已确认解锁，22:40安装前备份仍断开；独立只读RSD在CoreDeviceProxy断开。20日00:04新DNS-SD/身份匹配，installation_proxy只读lookup与AFC均立即ConnectionReset。22:20包未发送；不再询问同一解锁条件/盲重试，服务条件变化后再按备份门槛接续。完整失败见最新批次。周期调度已删，执行内完成阶段直接接下一项。

每轮蜂窝finally先停播放/下载/自有采集，再自动恢复原Wi-Fi，实际核原生网络勾选和Wi-Fi图标后才能长时分析/结束。13本批两轮初次恢复图仍4G，后续已实际见Wi-Fi图标才记完成；不改蜂窝/VPN。Pad为Wi-Fi-only。18仅19:37旧候选有安装Complete历史，当前未重新核已运行包，不挪用该事实验收22:20源码。

## 历史22:20源码、包与设备（最新以页首和诊断批次为准）

最新候选[恢复次数保护](2026-10-19-PREDICTIVE-ATTEMPT-BUDGET.md)，[结果](../../../testing/results/2026-10/PREDICTIVE-ATTEMPT-BUDGET-20261019.json)。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加原修改；ios差异`75fedb94550c8be0d2eb439745c139d7eccaf2c83a3a1c0fa6fcab17e5d375d2`。22:20:11普通Debug/-Onone/Xcode27新包冻结，173输入/29签名库/链接及清洁IPA核验；28相关测试/15预检通过。不是Release或性能验收。19:37包保留历史，不代表新源码。

当前指针`/tmp/nastart-predictive-budget-evidence`，工具`/tmp/nastart-predictive-budget-tools`。真实设备/偏好/包/日志仅私有；profile UTC10月24日22:23:57到期，沿用现有三设备注册。13/Pad新包身份已核，18覆盖未派发；跨日再次操作设备前仍重核现场/源码，不用昨日列表代替。

此前19:37包Pad已S03文件/S01双入口，13 S01双入口及S03蜂窝双入口、S19蜂窝JF均有界普通退出；所有蜂窝已停流/实际核原Wi-Fi，新增崩溃0、原轨道/偏好保持。18旧候选安装Complete及偏好保持、实际前台截图阻塞。新包的设备结论单列，不移用旧成绩。

## Apple TV 最新现场

[19日照片与连接复核](2026-10-19-APPLE-TV-PAIR-RECORD.md)：电视列表有Mac配对记录；两版Xcode仍无真实TV目标，单目标只读返回AppleTV14,1/tvOS18.2。当前是配对后的开发接入未就绪，不是用户没配对；未发安装。原生元数据未给硬件UDID，不冒充完整身份；旧广播实例未见不证明离线。后续查认证复用/服务发现接管，不重复PIN、重启、升级或当前无变化探测；手机主线独立继续。

## 最新发现与下一步

1. 共用撤回规则/有界恢复次数保护已实现，28产品相关测试/15预检及19日22:20构建；不要重做实现或把31项报告测试计入产品测试。新包Pad S03 8.215秒请求/23.654秒提交，原流reserve约12.4秒后耗减、容量证据后续过期；尚未证明达到健康恢复撤回条件，不为强行通过而放宽保护。S01四单元出画不等于原失败族收益验收。
2. 13固定初始2Mbps PGS7/音轨1/0秒45秒诊断内部起播6.391秒、首片h2复用等头2321ms/正文312ms/744480bytes；46完成metrics均蜂窝。Off两次工具失败未播放，停止同工具循环，先解决稳定可见语义选轨后再配对。此非默认/Release，不证明旧15秒等头修复。真实无线RSRP/RSRQ/SINR未知，不用格数证明定量弱网。
3. 新包13 S19文件/JF内部推进8.695/7.912秒；文件实际2Mbps/最大854×480约束，JF实际10Mbps/H264声明9.36Mbps/PGS8 Encode，实际输出尺寸未知，不作严格配对。文件同trace/local child首片两GET：首次4542ms等头后发送失败，重请求316ms头+208ms正文；JF单GET 2652ms头+400ms正文。两窗h2均复用，EOF并不代表取消。首片后还在取后续片/初始定位，缓冲评估转playing本窗仅约15/24ms，不把所有余时叫解码或重复AV等待实验。复用新增startupSegmentAttempts报告及已有14协议窗，下一步绑定同窗服务端任务/首片创建时刻，再决定最小共用修复；没有归属不猜NAS/无线根因。深seek/字幕/听音仍开放。
4. 精确seek两原生输入候选均失败，不再像素/比例补偿；旧[输入审计](2026-10-19-SEEK-INPUT-SNAPSHOT-AUDIT.md)保留。禁止延后恢复AV automatic waiting、将仅协议探索直接固化为segment4/min1改动、NAS/VPN/IPv6及并发大片压测。TV开发连接条件未具备，不反复问PIN/重启；DSM/引导/驱动/套件/电视更新均禁止。

## 核验和历史边界

相关安装工具13项通过，不因本批设备证据重复既有92项。最新文档链接/差异检查见批次收尾。Mac顺序IPv6建连干扰仅适用于[协议探针](2026-10-19-PGS-FIRST-SEGMENT-PROTOCOL.md)，不能解释旧手机复用h2等头；FIN/RST fixture、派发前旧片排除、暂停/seek/PiP/轨道隔离继续保留。内部clock不等于精确可见首帧/听音/完整字幕/逐帧P。原生条件本批未重测，无新注入，不写active=0。
