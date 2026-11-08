# 首个有效目标帧之前的工作分段

更新时间：2026-10-11T17:53:54.326308+08:00。接续[有效帧/输出API诊断](2026-10-11-VIDEO-OUTPUT-STAGES.md)，关联PX-01/PX-02。PROGRESS/CURRENT、播放runbook、分层流程及竞品矩阵已读；其他dirty保留，无提交/推送/卸载/清登录数据。用户指定现有网络配置保持、18正常UI稍后验证，本轮遵守。

## 变更与验证

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，基线iOS差异 `aba9b086f29c3b5ebf7bf34a92973d8627bc15694c2c71f6712e86ab7dc57776`。上轮Pad调用返回至有效帧约486/517ms且过滤109/152帧，但不能归因网络或解码。本轮只补诊断：首次调用前时间、成功回调进入seek过滤前时间、截至有效目标帧的demux/视频decodeFrame/音视频putPacket调用墙钟、路由packet数量/字节/PTS/首key PTS，首次isPlayable及首次取出输出帧后的音视频packet/frame/max/fps容量。未改seek精度、缓冲阈值、选流、解码模式、Range/网络、报告或2秒checkpoint。

recordWork按独立lane记录完成调用；调用跨accepted边界时只取之前区间，迟到完成仍可计该部分，当前未完成调用未计入，workCoverage明确completedCallsOnlyInFlightUnmeasured。demuxRead包含解复用和潜在I/O，并非纯网络；decodeFrame墙钟可能含同步callback/过滤/队列push，并非纯CPU/硬解码时间；putPacket可能同步解码。各lane可重叠，禁止求和作为总启动时间。路由计数在putPacket之前，不冒称网络字节或成功入队；PTS按解码顺序而非单调展示顺序。容量来自真实track读取，音视频读取非跨线程原子快照，firstOutput在pop之后。

新增两项规则测试覆盖跨边界截断/迟到返回/重叠lane、非法时间/媒体/尺寸/容量、首次去重、reset/旧generation。首次编译的转换歧义/Int32问题日志保留并修正；中间验证后规范容量媒体名称，最终源码重新执行完整**322测试/2跳过/0失败、15预检、普通Debug构建**，不引用中间结果作为最终验证。只有5输入变更：renderer、测试、KSOptions、MEPlayerItem、MEPlayerItemTrack。

## 最新包与设备门槛

最终iOS差异 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`，173输入无晚于产物；普通Debug -Onone，空环境/参数。构建2026-10-11T17:36:31.155727+08:00、冻结2026-10-11T17:38:03.703738+08:00；deep/29库独立验签、链接和三设备profile授权通过，有效期UTC 2026-10-17T22:23:40。

- App `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.app`；IPA `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.ipa`。
- 主SHA256 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`；Debug `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`；KS `9764ba65bd197b17931a6fff5220d2883cab665daf93bcaaaa99a972de5f2c6b`。
- iPad现场名称/型号iPad12,1/系统18.3.1/UDID/USB重新核，2026-10-11T17:38:29.011676+08:00保留数据覆盖成功，16偏好值一致；普通空环境真实首页已看。即刻服务卡片未知，不当全部在线。
- iPhone13同门槛现场iPhone14,5/16.3.1/USB，2026-10-11T17:44:19.393354+08:00覆盖成功，25偏好一致，普通空环境真实首页已看。每次切换/入口另核173输入、iOS差异、包哈希、安装回执及现场身份。
- 18两轮只读发现未取得可验证端点，旧确认地址直连TimeoutError，当前设备身份未取得；**本轮c692包未上传/未安装**。旧27ad安装不能算最新。本轮不启动/截图/播放18，不改配对、网络或安全设置，失败根因未知。

## S01四单元与定位结果

串行Pad JF→Pad文件→13 JF→13文件；同账号素材无中途另一端播放。普通有序terminate/state1/空环境launch，不声称不同PID或清缓存，cache unknown。续播点不同、关键帧距离未固定，禁止跨设备/入口排名。阶段均相对引擎prepare毫秒；work列为独立完成调用的截至accepted墙钟。

| 设备 | 入口 | 请求点/秒 | 首调用/ms | 首成功回调/ms | 有效帧/ms | 过滤数 | demux墙钟/ms | decode调用墙钟/ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ipad | Jellyfin | 1631.177 | 614.684 | 668.612 | 1639.404 | 207 | 1168.661 | 450.532 |
| ipad | device file | 980.357 | 1510.808 | 1552.438 | 1582.436 | 17 | 1049.300 | 52.510 |
| iphone13 | Jellyfin | 1662.384 | 345.007 | 366.719 | 449.485 | 73 | 194.242 | 104.276 |
| iphone13 | device file | 1057.524 | 473.111 | 510.251 | 588.182 | 64 | 154.510 | 114.806 |

本轮不同续播点的等待分布不同，不能概括为所有启动都被同一层阻塞。

- Pad JF：首 key packet PTS 1624.253，距请求点 6.924 秒；首次成功回调到有效目标帧 970.792ms，过滤 207 帧。demux 完成调用累计 1168.661ms，decode 调用 450.532ms，两条 lane 可能重叠，禁止相加；有效帧后约 125.783ms 才记录首次 isPlayable。
- Pad 文件：首调用 1510.808ms、首回调 1552.438ms、有效帧 1582.436ms，回调之后约 29.998ms，过滤 17 帧。首 key 距请求点 0.580 秒；demux 累计 1049.300ms、最大单次 978.255ms。read 内潜在 I/O 与解复用尚未细分，不能称纯网络瓶颈。
- 13 JF：首 key 距请求点 2.462 秒，回调到有效帧 82.766ms，过滤 73 帧；有效帧后约 50.032ms 记录首次 isPlayable。
- 13 文件：首 key 距请求点 2.138 秒，回调到有效帧 77.931ms，过滤 64 帧；有效帧后约 43.712ms 记录首次 isPlayable。

Pad JF 的前置 key 距离、过滤数量及回调到有效帧间隔共同支持继续检查准确 seek 前置帧的读取/解码，过滤帧不能直接当成可省工作。所有时刻来自引擎单调计时，非屏幕首帧。

Pad 文件第一次 output 的 video 队列 9 帧/0 包、audio 22 帧/0 包；首次 isPlayable 为 video 16 帧/30 包、audio 32 帧/30 包，两个容量记录相隔 400.677ms，说明首帧取出与储备资格需独立核对。队列读取非原子，不证明声音或展示，也不能单凭音频帧数指认唯一原因。下一步固定同轨/同点重放，并联动有限 Range 完成/请求时刻；当前仍缺 read 内 I/O 细分、在途调用和完整显示证据。

屏幕实际：Pad 两条 t2 黑场有 spinner、t3 电影无 spinner；13 JF t0 详情禁用按钮/t1 电影（方向过渡），13 文件 t1 黑场 00:00 有 spinner/t2 电影 17:38。四条 t30 电影及原退出已看。tN 仅为采集排程，实际请求/返回边界留存；早黑和方向过渡保留。两个 JF 各 7 提交/7 匹配 HTTP 接受/0 失败/一个正 initial started，不证明服务器耐久。


各t30实际电影及原UI退出已看，单书签更新/轨道偏好保持；早期黑场/旋转/详情未出画保留。两个JF的提交/HTTP接受配对和实际位置见JSON，HTTP成功仍不证明服务器耐久。实际API均sampleBufferEnqueued；API、推进时钟与屏幕分列。稀疏截图不能证明完整30秒连续播放、逐帧流畅、声音或竞品表现；没有性能PASS。L1只是四单元诊断定向；L2 S03/S08/AV/HLS等继续开放，不触发L3也不关闭历史验收。

## 收尾与后续

双机最终普通空环境首页真实查看、播放器关闭、active0、WDA idle10/动画2恢复，服务状态按实际图保留。完整设备标识/地址/偏好/凭据/PNG/日志仅`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240`；源差异、173输入、逐机安装/启动、四窗、final和helper+SHA清单留存。

下一步按已定位边界固定同轨/同点至少3次探索重复，并补另一技术族，确认关键帧距离、解码callback或音频容量是否决定启动等待再改策略。18恢复后先保留数据覆盖最新包，UI按用户延后；Xcode自动tunnel/DDI间歇差异、旧+475.051耐久/阈值、FileStation119/账号代际、真实弱蜂窝旧ordinal0、S19/MTP/L2/L3、声音/完整帧/位移、Lenna/DS One/Jellyfin/Popcorn及全部未验PX/UX/CB/Main保留。

结构化：[STARTUP-WORK-BREAKDOWN-20261011.json](../../../testing/results/2026-10/STARTUP-WORK-BREAKDOWN-20261011.json)。
