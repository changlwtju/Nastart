# 当前播放与 Apple TV 任务接续

最新：primer真机未获可靠收益，两个普通入口已停用；09:47:40恢复包/ios差异`39b0bdc21ea6e43e8c357d1c26ae78f8f87f63b69c301ae20d8b5ba717a45591`已覆盖13/Pad并核空环境首页/实际Wi-Fi，7定向0失败再次通过。候选09:06四窗及S03蜂窝两窗保留历史，未冒充当前性能验收。当前无自有媒体/蜂窝流量，原SSID/图标已实际核实；Pad临时Runner已结束。下一步优先复用[本批首片客户端顺序](2026-10-20-STARTUP-SEGMENT-PRIMER.md)及旧Mac4.5秒无重请求反例，核手机特定请求边界；不继续盲调primer/AV等待，不操作离家18。私有指针`/tmp/nastart-startup-primer-evidence`；下文候选状态均为历史。

当前执行：[单字节首片候选](2026-10-20-STARTUP-SEGMENT-PRIMER.md)，私有指针`/tmp/nastart-startup-primer-evidence`。09:06包/ios差异`0d54a71cf005386dad2485805d78af9ca36bd2a2c08a7c6981083513b3f806bf`，7定向/30工具/15预检通过，13已保留数据覆盖/25偏好保持/空环境首页/实际Wi-Fi及S01 JF出画普通退出；Pad暂未覆盖、18离家不动。当前正在做S01文件及后续新包回归；下方06:48结果保留历史，不冒充本候选。普通媒体均串行，蜂窝finally恢复原Wi-Fi。

更新：2026-10-20。先读[调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)、[分层流程](../../../development/playback-development-workflow.md)、[功能矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)/[竞品矩阵](../../../testing/COMPETITOR-DEVICE-MATRIX.md)。编号仅[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)，28项仍开放。

## 当前设备、包与占用

普通Debug/-Onone/Xcode27包构建于06:48:25，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加原修改，iOS差异`35df7015b08ee4d929683983de8ac59d2d7111f94615bf85f38894fc25ae66ed`。173输入/29库/三二进制/清洁IPA已核，5项iOS定向、28项报告工具及15预检通过；完整旧测试失败不覆盖。私有指针`/tmp/nastart-output-correlation-evidence`，包/凭据/设备ID/原始证据只留私有区，profile UTC10月24日22:23:57到期。

13/Pad重新接回Mac后已现场核名称/型号/系统/UDID/USB及安装receipt、当前源码与二进制；13 iPhone14,5/iOS16.3.1，Pad iPad12,1/iPadOS18.3.1 Wi-Fi-only。13/Pad均用当前包/空环境完成S01两入口30秒普通退出。18已[有线覆盖/25项偏好/普通首页核实](2026-10-20-IPHONE18-USB-INSTALL.md)，后随用户离家，勿再探测/操作。

本批媒体均已停止，两机独立原生截图实见桌面无PiP/Wi-Fi；非断点偏好与原轨道保持，断点自然推进。自有Pad临时Runner/保活主动停，13既有持久WDA不动。后续再次开始/换设备/改源码仍现场重核，不能用本页替代。

## 最新发现

[重新连接/PiP专项](2026-10-20-RECONNECTED-PIP-ROUTES.md)及[结构化结果](../../../testing/results/2026-10/RECONNECTED-PIP-ROUTES-20261020.json)：S01四窗内部推进1.357/1.716/2.702/2.337秒，Pad文件stall1保留，非完整性能/音字幕P。13 S19/JF原流KSPlayer/PQ当前复现：25.545/30.558秒有1张字幕位图却`hdrPQPreserved`，PiP图无字幕；Pad两窗自动回退12Mbps H264/AAC/PGS8 Encode→AV PiP有字幕，不能替代原流。完整恢复受系统辅助功能控件观测阻塞，不再猜坐标/完整源树重试。用户只确认JF入口，设备文件PiP未测。

HDR合成器仍SDR输出，PQ/HLG保护未改。Mac32×32/10-bit/线性BT2020原型可保持PQ/HLG测试高亮，尚未App实现/iOS真机/DV元数据/4K资源验收。系统PiP没有公开自定义拖动条接口；App内小窗另评估，未承诺产品交付。

[输出关联诊断](2026-10-20-CLIENT-OUTPUT-CORRELATION.md)：Params实际请求槽位已补，13 S03真实蜂窝JF/文件21/34请求精确对应唯一编码任务；内部8.583/6.909秒、首片等头2.717/2.199秒，10/2Mbps及PGS/Off不同，不作严格提速比。三次旧20秒工具实采30秒失败保留，私有时限已修；所有蜂窝已停流、恢复原SSID并独立实际见Wi-Fi。

已直接完成[首片重叠边界离线复核](2026-10-20-STARTUP-OVERLAP-BOUNDARIES.md)：派发前3.902/3.086秒，完整清单后primer仅有1.172/0.471秒排程重叠上限；前缀方案最早乐观约2.186/2.126秒且URI到达未知。非产品收益，反例清单仍待执行，别承诺消除全部等待。

## 直接接续顺序

1. 蜂窝双入口大片仍最高优先级。复用已绑定任务/首片/后续供给证据，先做首片1字节primer与清单准备重叠的本地取消、续播/nonzero片序、Range忽略、端点/身份/请求代次反例。既有Mac协议1字节206后全GET变快只证可行，未实现或证明用户提速；不能猜首片0、合成整份VOD或并发起转码。
2. 形成具体有反例的最小共用修复后L0→最新签名普通包→S01四单元/受影响格式/真实蜂窝S03/S19与LAN；每轮finally先停自有媒体和采集，恢复原生原Wi-Fi且核图标再分析。保留原蜂窝/VPN，不人工限速或并发大片压测。用户报告弱蜂窝，RSRP/RSRQ/SINR未知不冒充定量弱信号。
3. PiP字幕独立继续10-bit/色彩空间/资源上限/元数据验证，覆盖原流SDR/PQ/HLG/DV、文本/PGS/外置与烧录反例。不要删HDR保护换8-bit假修；恢复控件工具有新可靠路径才补完整往返，失败已留档。
4. 精确深seek输入两候选失败、旧cue/菜单/听音仍开放；不重做延后恢复AV automatic waiting、删零seek、盲改segment时长或同阻塞重试。

## 既有反例与约束

[同片LAN](2026-10-20-S19-LAN-COMPARISON.md)、[分片时长反例](2026-10-20-SEGMENT-DURATION-COUNTEREXAMPLE.md)、[零定位/主日志反例](2026-10-20-AV-ZERO-SEEK-AND-SERVER-LOG.md)、[有界恢复次数](2026-10-19-PREDICTIVE-ATTEMPT-BUDGET.md)保留历史，不把内部clock/ready/selected当实际画面/听音/完整字幕/逐帧验收。此前完整接续细节留[本日旧快照](2026-10-20-BEFORE-PIP-CURRENT-HANDOFF.md)。

[TV](2026-10-19-APPLE-TV-PAIR-RECORD.md)有Mac配对记录，开发接入/安装目标未就绪；不重复PIN/重启/升级。DSM排查暂停，严禁更新DSM/引导/驱动/套件/电视，不改NAS/VPN。周期调度已删，当前执行内完成一项直接接下一项；不得声称回合结束后仍在后台执行。
