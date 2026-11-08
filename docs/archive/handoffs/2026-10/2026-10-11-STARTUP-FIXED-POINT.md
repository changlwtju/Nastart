# 固定续播点重复与S03启动边界

更新时间：2026-10-11T18:46:31.125694+08:00。接续[工作分段](2026-10-11-STARTUP-WORK-BREAKDOWN.md)，关联PX-01/PX-02。已读PROGRESS/CURRENT、runbook、分层流程及竞品矩阵。**本轮没有修改App源码或播放策略**，其他dirty保留；未提交/推送/卸载/清登录数据。网络、配对及系统安全设置保持。18正常UI仍按用户延后。

## 包身份与逐机范围

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS差异 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`。173输入哈希与当前源码逐项一致，无新输入晚于产物；普通Debug -Onone，环境`{}`/参数`[]`。构建`2026-10-11T17:36:31.155727+08:00`，冻结`2026-10-11T17:38:03.703738+08:00`。本轮逐入口现场源/三二进制/安装回执/目标USB身份门槛及最终deep验签通过；29库/链接/三设备profile授权为这个同源冻结包的核验，有效期UTC `2026-10-17T22:23:40`。**322测试/2跳过/0失败及15预检为上一轮最终同源结果，本轮未重跑**。本轮私有测量工具变更不计App源变更。

- App `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.app`；IPA `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.ipa`。
- 主SHA256 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`；Debug `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`；KS `9764ba65bd197b17931a6fff5220d2883cab665daf93bcaaaa99a972de5f2c6b`。
- iPad现场名称、iPad12,1、18.3.1、UDID与USB重新核对，18:14:43开始/18:14:47保留数据覆盖成功，16偏好键值一致；实际普通空环境首页查看后才回归。最终18:40现场身份/173输入/三哈希/正常空环境首页/播放器关闭/idle10动画2恢复已核，原生性能条件active0、未注入条件；NAS正常，其他可见服务卡片未知。
- iPhone13本轮18:15仅只读现场身份iPhone14,5/16.3.1/USB与WDA可用性；不启动/播放/覆盖、不声称本轮最新包回归或最终首页核验。私有目录复制的17:44安装回执只属上一轮。
- iPhone18本轮18:15直接旧已验证地址重核TimeoutError，当前DNS-SD目标未解析，未取得可验证身份/开发通道；**c692当前包未上传、未安装**。不能以旧27ad安装代替最新包核对，未操作其App/UI，也未修改网络、配对或把USB作为无线能力前提；VPN根因仍未知。

## 如何固定与计时

同账号素材串行，只在Pad播放。S01文件组audio1/subtitle4/字幕开启，JF组audio1/字幕关闭；组间轨道条件不同，禁止跨入口速度排名。通过普通UI暂停、进度条归零，再从新鲜边界内拖动thumb到固定位置、普通退出，让App正常保存；没有写偏好或测试环境变量。文件比例0.25保存1791.000秒，JF比例0.228保存1631.000秒。每次30秒采集后才重置同点，重置和随后15秒退出取证在测量窗口外；这些有意的0秒seek不是初始续播提前0 started。

直接XCTest normalized slider设置0.25曾有偏移：文件第一轮请求1803.220、退出后1795.241。该轮作为校准单独保留，**不混入固定点三次组**；后续零点加几何拖动才稳定1791。准备过程和失败证据不丢弃。JF准备1791后又正常UI移到1631，属于准备，不当性能样本。

每轮普通终止/空环境重开；JF及S03首页记录state1，S01文件导航helper未单独记录终止态。没有不同PID/媒体冷缓存证明，缓存未清、温度/OS/NAS负载未统一。三次是探索重复，不能作正式性能验收。HouseArrest连接重试/失败日志留存。截图排程tN与实际请求/截图返回/偏好读取边界都留存，不将tN直接当出画秒数。

## 引擎工作分布

首调用和有效帧为prepare相对毫秒；callback→有效帧为差值。demux/decode列是截至有效帧的完成调用墙钟，lane可重叠、在途调用未计，不能相加或归纯网络/CPU。有效帧经过frame-end seek过滤，PTS可重叠目标；API enqueue不是屏幕展示。

| 轮次 | 请求秒 | 首调用ms | callback→有效帧ms | 有效帧ms | 过滤帧 | demux累计ms | 单次demux最大ms | decode累计ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fixed-file-r1 | 1803.22 | 1594.874 | 491.261 | 2128.623 | 108 | 981.146 | 449.196 | 249.131 |
| fixed-file-r2 | 1791.0 | 332.904 | 34.936 | 468.762 | 18 | 225.285 | 90.166 | 65.531 |
| fixed-file-r3 | 1791.0 | 674.179 | 29.637 | 770.369 | 18 | 519.254 | 422.664 | 95.991 |
| fixed-file-r4 | 1791.0 | 1403.759 | 33.317 | 1483.719 | 18 | 659.980 | 579.984 | 79.736 |
| fixed-jf-r1 | 1631.0 | 458.664 | 598.026 | 1087.190 | 202 | 751.283 | 160.512 | 395.819 |
| fixed-jf-r2 | 1631.0 | 463.695 | 501.674 | 1034.898 | 202 | 604.558 | 117.392 | 425.084 |
| fixed-jf-r3 | 1631.0 | 2539.128 | 1122.985 | 3738.275 | 202 | 2581.509 | 1387.667 | 375.016 |
| fixed-s03-file | 63.451 | 2889.190 | 899.765 | 4411.861 | 14 | 2000.004 | 477.711 | 42.112 |

文件r2/r3/r4都请求1791，首key PTS1790.385，距离0.615秒，均过滤18帧；回调后的约30～35ms相近，而首调用前等待从332.904增至1403.759ms。r3首output→首isPlayable相隔450.220ms，audio18→32帧及video容量共同变化；快照非原子，不能单凭音频数量定唯一原因。

JF r1/r2/r3都请求1631，首key PTS1624.253、距离6.747秒、均过滤202帧。第三次首调用前2539.128ms，单次demux1387.667ms、callback→有效帧1122.985ms，而decode完成调用累计375.016ms并未同步变大；前两次callback→有效帧598.026/501.674ms。这支持先细分read与异步回调/队列等待，不能仅按过滤帧数降低seek精度或缓冲阈值。

有限Range时序已与窗口归属联动；S01各轮6个mediaRange响应均有限206且长度正，取消、短交付、32/54客户端关闭与-999上游取消全部保留，不能当整个传输无错误。代理完成时间不是逐次av_read_frame内I/O时间，诊断wall与prepare单调时钟没有精确对齐保证。

## 屏幕与报告

实际查看最后无电影/首个电影/t30/暂停重置/原退出PNG。文件固定三轮分别t0详情→t1电影、t1黑→t2电影带spinner、t2黑→t3电影；JF分别t1黑→t2电影、t0详情→t1电影、t4黑→t5电影带spinner（t6无spinner）。黑场、方向过渡和“出画但仍缓冲”均保留。结构化JSON给出截图请求/响应构成的观测区间；稀疏截图不能排除更早的瞬时帧，不能测准确首帧、声音、完整帧、滚动位移或连续30秒。

JF三轮8/8、8/8、7/7提交均按私有report ID、phase、ticks匹配HTTP接受，无报告失败、各一个正初始started；HTTP接受不证明服务器耐久。八测量轮各一个正常保存书签更新、音轨/字幕偏好保持；S01窗口外重置后同点保存、S03普通退出保存63.451→77.787秒。

## S03补充：候选路线不等于已切换

实际预览文件与样本矩阵匹配S03 2160p MKV REMUX HEVC/DV/TrueHD。本轮capabilities报告10bit、DV profile7/level6/EL1，audio源ID4/decodedPCM、字幕关闭、KSPlayer ffmpegVideoToolboxEligible；**不证明实际TrueHD/Atmos/DV/HDR画质或声音输出**（HDR eligible=false，DV/Atmos output=unverified）。

首key距63.451请求点仅0.597秒、过滤14帧，却在首调用前2889.190ms、首成功callback前另622.906ms；首output容量audio14/256、video0/16，首isPlayable audio45/256、video16/16，相隔1197.315ms。t0～t2仍准备详情、t3方向过渡黑场、t4～t6黑/spinner、t7/t8电影带spinner、t30电影无spinner。初始KS诊断仅归初始计划，不将t30截图声称连续稳定直播放。

11.064秒已有普通策略请求自动调整，reason=deliveryBelowSourceBitrate；当时bodyWindow容量22997457bit/s、源估算57416722bit/s、runtimeDemand28149249bit/s、ahead1.261秒。18.804秒创建systemAVPlayer/localHLS/localRemux**候选**，18.9开始预热；到t30仍framePTS=pending、itemStatus0、loadedRangeCount0，没有replacement_committed。33.007秒普通关闭令warmup cancelled=true，14.065秒已用、deadline仍余25.934秒：**这是本轮关闭取消未完成准备，不是40秒准备超时/成功切换**；候选尚无可见出画证据。

S03有7个mediaRange有限206，另1个798字节finitePlaylist的200。最初把所有带contentRange字段的事件合查206得到false，现已明确按类型分开：有限播放清单200不是开放大电影200；原53事件、取消和失败都保留。候选HLS后续媒体交付/seek/出帧/commit/取消清理、原流重缓冲与吞吐判断还待独立查证；本轮不改策略，不标AV/HLS或L2通过。

## 接续

优先补初始read的I/O/解复用边界、异步解码回调及队列等待诊断，保留同点组；结合S03候选无加载区间/无出帧定位HLS准备，不用选流或缓冲参数掩盖等待。源改动前完成变更卡与对应规则反例，改后重测最新普通包和代表族。

18服务恢复后重新取得现场身份并保留数据更新最新包，UI仍按用户延后；Xcode自动tunnel/DDI间歇差异、旧+475.051书签耐久/阈值/外部客户端、FileStation119/账号代际、13真实弱蜂窝旧ordinal0/协商、S03其余入口/S08/S11/S18/S19/MTP/ISO/TV、暂停/预热/后续重缓冲/失败/取消/真实Metal、声音/完整帧/位移、Lenna/DS One/Jellyfin/Popcorn和全部未验PX/UX/CB01～26/L2/L3/Main保留。**无性能/竞品/全局PASS。**

私有原始证据/设备身份/偏好/地址/截图及helper+SHA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-fixed-point-181435`。结构化：[STARTUP-FIXED-POINT-20261011.json](../../../testing/results/2026-10/STARTUP-FIXED-POINT-20261011.json)。本轮手机13只读、18受阻，不把之前双机收尾复制为本轮结论。

## 后续完整尾部补查

2026-10-11约19:00补查上轮原始退出后尾部，发现media清单在29.438秒读完、29.584秒发分片，36.529秒分片500晚于33.007秒退出取消。798仅master上游字节；media上游1386158/重写194347字节、1880分片。前文仅以有限t30摘要不能排除这些事件，也不能把退出后的500指认为原始原因。详见[2026-10-11-WIRELESS-HLS-FOLLOWUP.md](2026-10-11-WIRELESS-HLS-FOLLOWUP.md)。本次补查未改变前文33秒取消、候选未commit和非deadline失败的结论。
