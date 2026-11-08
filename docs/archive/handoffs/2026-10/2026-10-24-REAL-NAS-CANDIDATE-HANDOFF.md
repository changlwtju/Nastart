# 真实NAS原流与PGS候选并行接手

2026-10-24 07:32接[真实HLS与格式回归](2026-10-24-REAL-HLS-AND-FORMAT-REGRESSION.md)，先读PROGRESS/交接/规范。补PX-03有限证据，28开放与76格完整通过率保持，不新增编号。详[安全JSON](../../../testing/results/2026-10/2026-10-24-real-nas-candidate-handoff.json)。

## 基线与范围

没有App、KSPlayer或仓库主机工具源码修改，无构建/安装/新增测试。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty；最新仍06:20:01普通Debug/-Onone/Xcode27、174输入/29签名库，iOS diff SHA `a6dffa97d9301537a7a104d2700d72854e33040e94c1f267b0c024`，IPA SHA `76ebb89a8b390d650f9b5eb7cf9556f8c945b56ebccf22037cad1426b50bc4b7`。三二进制/deep签名/profile设备授权与期限/IPA CRC/链接随验证器新核；45 XCTest/15预检为前批结果。

每窗现场新核iPhone13名称/UDID/iPhone14,5/iOS16.3.1/USB及其自身06:20:53安装回执，不以版本号替代。原始身份、偏好、凭据/URL、截图、片源前缀和包仅本机私有；指针`/tmp/nastart-candidate-wait-audit-evidence`，package-private-root指真正06:20冻结根，全局包指针不改。

本批增加真实原片KS仍播放时准备AV候选的拓扑。私有协议实时核同服/Item/MediaSource/字节与音字幕轨，再新协商独立DeviceId+PlaySessionId的2Mbps H264/AAC/PGS Encode候选；原片从0开始，首次内部帧信号后留图并等8秒，再单次点显式Debug候选按钮。沿既有replaceSource/完整VOD预热/AV解码/对齐/提交，不限速、不改40秒/NAS。协商提前在App外完成，不是普通入口协商计时或自然自动降档；Debug原片轨道不替代普通偏好验收。每窗1 lab启动/1候选按钮，0普通Play/seek/PiP/选轨/蜂窝，同窗Mac媒体GET为0。

媒体互斥与主机进程先核，原片与本次候选属于同一受控用例。AC、自有caffeinate PID/断言始中末均核；独立220秒守卫、260秒主截止及finally只停自有App、精确NAS会话、日志/守卫/保活，保留已有非本批WDA。

## 两个接手窗口

| 项目 | S03 | S19 |
|---|---|---|
| 窗口 | 07:38:44–07:39:53 | 07:43:41–07:44:47 |
| 源字节/时长 | 54,005,939,750 / 7524.768秒 | 128,795,641,934 / 13698.368秒 |
| 候选 | 音轨1/PGS7 Encode/H264 AAC≤2Mbps | 音轨1/PGS8 Encode/H264 AAC≤2Mbps |
| 清单准备内部elapsed | 918ms | 1010ms |
| 已解码内部elapsed | 3854ms | 5074ms |
| 已对齐内部elapsed | 6364ms | 5992ms |
| warmup_started→committed事件差 | 6.524秒 | 6.090秒 |
| 对齐候选/原流位置 | 18.115 / 18.036秒 | 17.513 / 17.417秒 |
| 提交候选储备 | 13.834秒 | 6.427秒 |
| master/media | 各1上游+1缓存命中 | 各1上游+1缓存命中 |
| 缓存原文字节 | 781 / 1,350,438 | 781 / 2,460,059 |
| 分片上游请求 | 12 | 11 |
| 首个完成分片 | 5.ts等头2669ms/正文97ms | 5.ts等头3771ms/正文46ms |

内部elapsed与持久事件墙钟各自保留，非物理点击或屏幕接手时长。5.ts不可与前批直接AV的0.ts或旧12Mbps/深位置/不同储备的40.005秒失败做提速A/B。两窗均见decoded/aligned/committed和后续AV trace，无本次warmup_failed，只证声明条件下真实供给和接手；普通自然触发/失败后再协商仍待验。

原片max reported stall均0，候选各1/accessLogStalls0；S03内部stall54ms，S19为1524ms，不抹除、不直接等同屏幕卡顿。S19末持久候选遥测51.008秒，实际末图00:58；持久化缺口不推断停播，实际图不替代完整帧时间。

## 实际图与黑场

两窗各7张原生播放图已看。内部ready时仍是源片头00:00黑场，不能称ready图已出电影；候选前和触发后3秒分别见不同Paramount/New Line动画。10秒S03黑场/00:20、S19 New Line presents/00:20；30秒S03电影、S19绿色中英/精灵文字幕；45秒不同PGS对白；末图分别演员和《指环王》标题/00:58。底部英文仍受lab Home指示条遮挡，不判完整SUB/AUD；沿前批Debug根页面/普通hosting差异，不盲改普通布局。

全部手机媒体和自有会话停止后，S03另核同服/同Item/同MediaSource/54,005,939,750 bytes，以Static MKV有限206取前96MiB，Content-Range/长度/实际100,663,296 bytes一致、约1.800秒，无整文件200/新转码。离线解码30.03秒，FFmpeg无网络。源相关黑场19.728–21.980秒；18秒logo、20/21.5秒黑场、23秒文字四参考图已看，手机黑图邻近遥测20.002/21.501秒，符合源转场，不建立持续接手黑屏。末尾29.154–30.03区间受停止截断，不当完整黑场结束。稀疏采样不能证明精确显示帧或排除所有间歇问题。

## 1524ms计数的离线核对

S19 helper+20.689秒waiting/evaluatingBufferingRate、current17.478；20.707秒已playing/current17.530，但bufferEmpty=yes/stallActive=yes。21.178秒仍playing/current18.001/stallActive=yes；22.195秒current19.002/empty=no才结束计数并记1524ms。两条playing+stallActive=yes之间墙钟与媒体时钟均约推进0.471秒。

`PlaybackDiagnostics.swift.sampleAVPlayer`以`waiting || (playing && bufferEmpty)`更新stall；此跨度含playing且empty标志仍在，不能等同1.524秒时钟完全停滞、网络饥饿或屏幕卡住。`GreenfieldVideoPlayerView.installPlayerItem`确将预热automaticallyWaits从false恢复true、forwardBuffer从0.5改3秒，但关联不能证明该配置导致实际卡顿。保留原计数、时钟/标志及图，不盲调策略；完整视频/音频呈现仍待验。本段零新设备请求/源码，不构成性能修复。

## 逐台与资源收尾

- **13**：两窗完整非诊断偏好各自全同，新增Nastart/WDA/Jetsam报告名0；App状态1/1、auto/10/2恢复，自有日志/守卫停。两次精确DeviceId+PlaySessionId DELETE204/remainingOwnedSessions0，HTTP不单证FFmpeg进程退出。S03后07:41普通空环境NAS首页已看并收尾，再跑S19；S19后07:45普通空环境/参数NAS在线首页已看，仅停该自有前台PID。07:46:38新核源包/自身回执/USB、完整偏好两读稳定，36原键轨道/其他24项保持，仅先前自然positionSeconds/updatedAt差异。Home Wi-Fi无PiP实际已看，07:49:08私有根活动进程0。
- **18**：已配对实例解析失败；浏览2条广播、规范化同目标0。0备份/上传/安装/启动，未读新实际设备值，不归因锁屏/设置，不扫旧IP/重配对。仅历史00:00包于00:08:57安装确认，06:20包仍未装；此前一次解锁保持家庭Wi-Fi请求待反馈，不重复催促。恢复后先新身份/包，再容器备份/保留数据覆盖/普通首页。
- **Pad**：本批0操作，沿前批06:20包/06:26:16保留数据安装与正常收尾，不继承13结果，下次新核。

优先补普通自动候选及旧深位置失败的同条件证据，分开首片/清单正文/原流储备/接手后状态；不重复同条件150秒无触发或两种失败精确滑块动作，不放宽40秒。Pad代表格式、声音/完整字幕/PiP、用户报告弱蜂窝和竞品帧时间依唯一总账。蜂窝退出停自有流量并恢复原SSID/核原生Wi-Fi及图标，不新建调度，不声称回合后后台执行。
