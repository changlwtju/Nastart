# 有效视频帧与输出边界分段诊断

更新时间：2026-10-11T17:24:56.939851+08:00。接续[加载反馈修复](2026-10-11-LOADING-FEEDBACK.md)。本轮关联PX-01/PX-02，先读PROGRESS、CURRENT、runbook、分层流程和竞品矩阵。既有未提交修改全部保留，无提交/推送/卸载/清登录数据；网络配置保持原样，18正常UI仍按用户延后。

## 变更卡与代码验证

基线HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS差异 `27adfe361189fac22c586f25648742806f7b179afc5690b5074f9f63fbaf0c9d`。上一轮decodeVideoTime只标记decodeFrame调用返回，videoFrameSubmitted即使取不到drawable/未创建sample也会回调，二者不能确认有效目标帧和真实输出。因此本轮补诊断，不依据缺失证据修改缓冲/定位/解码器策略。

新增线程安全的一次性启动阶段记录：video typed decode callback通过seek帧末尾过滤后记录acceptedFrame，并计首次接受前过滤数量；有pixelBuffer时记outputAttempt；sampleBuffer确实调用enqueue后记API边界，Metal沿用原commit/等待完成流程，仅检查completed状态后记录边界。没有新增GPU等待或更改原失败flush行为。旧video_frame_submitted事件名保留兼容，evidence改为attempt/API boundary而非展示；若首尝试未完成输出，后续首次真实输出允许补一次记录。options重置增加代际，旧解码callback不能填入新会话诊断；主线程截图/内部时钟/提交分开保留。

两新增XCTest覆盖非法时间/非有限PTS、旧代际/reset、重复记录保留首值、过滤帧不算有效帧、尝试不冒充成功提交。它们是诊断规则验证，没有声称运行过旧实现失败基线。最后源码完整320测试/2跳过/0失败、15预检、普通Debug构建通过；修改中的初次构建/测试日志另存，不代替最终源码验证。仅7个源码输入变化：renderer、测试、KSOptions、KSMEPlayer、MEPlayerItemTrack、MetalPlayView、MetalRender。没有改变选流、buffer duration、seek、解码模式、报告策略或2秒checkpoint。

L0上述完成；L1 S01四单元诊断定向完成；L2代表族/AV/HLS和暂停预热等真实运行继续待验。诊断变更不触发L3，但不关闭既有完整矩阵。成功条件为有效帧/输出API/屏幕证据分开可核，非统一首帧速度预算。

## 本轮最新包与逐机状态

新iOS差异 `aba9b086f29c3b5ebf7bf34a92973d8627bc15694c2c71f6712e86ab7dc57776`。173源码输入无晚于产物，普通Debug -Onone，空环境/空参数启动。构建2026-10-11T17:09:18.104568+08:00，冻结2026-10-11T17:11:53.244152+08:00；签名deep及29动态库独立、播放链接和三设备profile授权核验通过，profile到UTC 2026-10-17T22:23:40。

- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-video-output-stages-170732/Nastart-Video-Output-Stages-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-video-output-stages-170732/Nastart-Video-Output-Stages-Normal-Debug.ipa`。
- 主SHA256 `64fd756e6ea5f6ea3a221d35d293ff75aec31504f43318e09728ccb447b80f09`；Debug `072820e1277bace902be54ebf284172ea5c1962fd917a5695779d7330caffbd7`；KS `cb8eb769047e3b1415133fdec5113fd7bd8ae71bad6a9974e293892d855badaf`。
- iPhone13现场iPhone14,5/16.3.1 USB名称/型号/系统/UDID/连接私有重读，2026-10-11T17:12:39.873045+08:00保留数据覆盖成功，25偏好值一致；实际普通空环境首页查看后才播放。
- iPad现场iPad12,1/18.3.1 USB同样核验，2026-10-11T17:12:04.050624+08:00保留数据覆盖成功，16偏好值一致；实际普通空环境首页查看后才播放。每个入口和切换核源码173输入/包哈希/安装回执/现场USB身份。
- iPhone18两次实时DNS-SD发现未取得可验证地址；此前确认地址的只读TCP配对身份重查也TimeoutError。**本轮aba9新包未上传/未安装**，不沿用上轮27ad安装作为最新包。当前名称/系统/UDID服务身份未能现场读取，不推算上轮身份；配对/网络未改，不启动或截图18，UI仍延后。发现失败与直连超时不证明具体VPN、锁屏或配对根因。

## S01串行四单元

按Pad JF→Pad文件→13 JF→13文件，同项单路、普通Wi-Fi，无人为限速/测试环境/缓存清理。各条有序terminate/state1/空环境launch留证；没有比较不同PID，故不补称已证明冷PID。起点不同、关键帧距离和缓存unknown，下表不能横比设备/入口性能或与上轮排名。

表中三个阶段均为**相对引擎prepare的毫秒**；decode是调用返回标记，accepted是通过帧末尾seek过滤的有效帧，API为sampleBufferEnqueued。PTS可略早于请求点但帧覆盖请求点，不等于错误恢复。

| 设备 | 入口 | 续播点/秒 | decode标记/ms | 有效帧/ms | 输出API/ms | 过滤帧数 | 有效帧→API/ms | 已看屏幕边界 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ipad | Jellyfin | 1568.873 | 1293.308 | 1779.511 | 1817.894 | 109 | 38.383 | 黑场t2→电影t3 |
| ipad | device file | 949.883 | 785.422 | 1302.093 | 1307.655 | 152 | 5.562 | 黑场t2→电影t3 |
| iphone13 | Jellyfin | 1600.219 | 310.520 | 362.633 | 368.847 | 24 | 6.214 | 详情t0→电影t1 |
| iphone13 | device file | 1027.006 | 690.911 | 720.762 | 750.627 | 5 | 29.864 | 黑场t1→电影t2 |

四条后续t30均为真实电影，原UI退出回详情/预览实际查看；同素材只更新一书签，轨道偏好保持。早黑/旋转状态保留，13JF的t0是详情而非黑场；截图区间按触摸请求/释放与截图请求/返回保守记录，不能把目标tN当实际拍摄时刻。两JF合计14提交均匹配HTTP成功接受、无报告失败/正续播提前0started；HTTP成功仍不保证服务器耐久。

Pad两条decode调用标记至有效帧分别486.203/516.671ms，同时过滤109/152帧；有效帧到API边界38.383/5.562ms。本次证据支持继续查有效目标帧到达之前的传输/定位/解码过程，没有证明是哪一层的唯一根因，过滤数量也不等同可全部省掉的工作。API完成不是compositor呈现；Metal分支编译/逻辑验证但本轮真实路线均sampleBuffer，实际Metal完成/AV/HLS未覆盖。既有buffer_updated记录为bufferedCount/consumeMs，不将其冒称音视频容量明细。缺后续缓冲容量及完整帧证据，不能据此宣称等待已优化、连续30秒/流畅或竞品胜负。

## 收尾、证据与下一步

13/Pad最新普通空环境首页实际查看、播放器关闭、原生条件active0、WDA idle10/动画2恢复。NAS/DSM/Homepage/JF在线；13Radarr/Sonarr及Pad另Prowlarr警告保留。初次私有配对记录helper参数TypeError发生于网络连接之前，已按实际本机API纠正后执行真实直连超时；不记App故障，失败记录保留。

完整UID/地址/偏好/凭据/PNG/日志仅`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-video-output-stages-170732`。source baseline/final差异、173输入、每机安装/启动/阶段截图、最终条件和helper副本+SHA清单留私有目录。background/loading/stage指针现为本轮；startup/ack等旧指针不得盲用。

下一步先将初始seek、包交付/Range等待、解码callback和音视频容量放入同一时间轴，固定同点重复条件后验证瓶颈，再决定策略优化。补S03/S08代表族与AV/HLS/暂停预热/真实重缓冲/失败取消。18连通后先保留数据覆盖本轮最新包，UI依用户延后；自动Xcode/tunnel/DDI间歇差异继续开放。旧+475.051服务器差异/耐久阈值、FileStation119/会话代际、13真实弱蜂窝旧ordinal0、S19/MTP/L2/L3、完整显示位移与实际声音、Lenna/DS One/Jellyfin/Popcorn以及全部未验PX/UX/CB/Main状态保留。

结构化记录：[VIDEO-OUTPUT-STAGES-20261011.json](../../../testing/results/2026-10/VIDEO-OUTPUT-STAGES-20261011.json)。
