# 候选失败资源关联与清单收发诊断

2026-10-21。关联PX-01/PX-03；状态仍只在[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。接[上一窗失败归属](2026-10-21-PIP-FAST-INPUT-ROUNDTRIP.md)，不重播旧包，也不改变字幕/PiP/选流/超时/重试/清单交付策略。

## 变更卡与实现

旧15:39普通包的S03/JF/PGS窗口，原KS原流持续缓冲，AV/localHLS候选在媒体清单仅上游收170692/1527158bytes时item报-1008，失败后才撤route。旧日志缺具体AV错误资源和代理请求绑定；`deliveredBytes`在清单分支实际是上游已收字节。没有证据支持加等待、改流式重写或调字幕。

本批接受的实现仅补观测：

- `PlaybackDiagnostics.swift`新增每route独立、最多64请求的精确URI摘要比较；只输出随机诊断route/transfer、角色与child ID，不导出URI、摘要、主机、凭据或原始errorComment。重试多匹配、历史截断、跨route、不存在URI均明确unknown/ambiguous，不挑最新请求冒充唯一归属。
- `AuthenticatedMediaStreamProxy`在原接收位置登记当前请求；AV失败查找限定最初候选root的token和端口，已经撤销的route不回退到其他route。原传输ID与关联ID统一，传输行为保持。
- `GreenfieldAVPlayerWarmup.prepare`在原失败分支、清理player及撤route之前快照末4项errorLog（保留总数）、accessLog最后资源和原root。只保留受限错误域、数值码/日期及安全关联，明确candidateCurrent；原代次/取消/就绪/对齐条件和40/20秒deadline保持。`decodedFrame`仍是等待帧阶段，不是解码成功。
- 清单原发送回调仅在成功完成后记录header/body完成计数；终止增加`playlistUpstreamBodyReceivedBytes`、`playlistClientHeaderSendCompleted`、`playlistClientBodySendCompletedBytes`，旧字段保留并注明上游含义。NW发送完成只证明本地发送完成，不代表AV已解析/解码；`clientReadEnded`仍仅对端写方向EOF，不改变取消规则。

不新增媒体请求、参数或重试，不更改正常/失败撤销顺序；不把诊断视为播放性能或功能修复。完整源差异及修改前四文件快照保存在仓库外，其他dirty保持。

## L0 与正常包

7项新增反例覆盖空errorLog、末4项/总数、凭据/任意域过滤、跨route/重复URI不选最新、64条截断、缺失/非HTTP URI、撤销/错端口及部分清单收发不混淆。正常NonPlaybackPolicyTests132项：131通过、1项既有设备端点配置缺失跳过、0失败；Xcode正常退出。15项preflight通过。

首轮19:36:57.046115+08正常Debug/-Onone/Xcode27一次构建成功；HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty，iOS diff `0f68321dd95486927f50fa1114fdf1a5dd3b83881778812f25515342383f8e69`。173输入、29库逐签/深签、profile/目标授权、IPA CRC/AppleDouble/三二进制及链接检查通过。IPA SHA-256 `5905c072bf0db4651ef5acb588d4f743c4abc0dd6b8906abc173cb29631d6838`。

首轮包和私有证据指针`/tmp/nastart-candidate-request-diagnostics-evidence`；旧`/tmp/nastart-auth-response-evidence`只属15:39历史包。当前最新为下文19:52 NSError补充包，指针`/tmp/nastart-candidate-error-chain-evidence`。三二进制SHA及包路径、身份/偏好/原始日志/画面仅私有manifest保存。

## 安装与验证范围

13现场iPhone14,5/iOS16.3.1/USB确认后保留数据覆盖，25项完整非诊断偏好逐值一致。19:39空环境/空参数首页实际NAS在线图已看，Home/Wi-Fi无PiP及原生无App、WDA设置恢复已核。无WDA构建/安装。

Pad本批未操作，仍15:39包，不声称是最新包或已回归。18按用户“稍后，先其他工作”约束不切前台、不询问；18:34保留数据安装15:39的回执仍有效，但本批19:36新包更新及实际首页/原图场景待用户方便，不声称18仍为最新或已完成正常首页验证。

## 第一窗实际结果及信息边界

19:42:38–19:44:19已执行13正常空环境/原PGS7、1 Play/0 PiP，播放派发后70秒观察预算、独立100秒守卫。现场安装/源码/包和其他媒体任务已核，不是性能比较，也不重做PiP操作。完整[安全结果](../../../testing/results/2026-10/2026-10-21-candidate-request-diagnostics.json)。

主KS/directPlay再次触发自动降档；候选AV/localHLS的master上游876bytes，在7.691秒后完整发送重写233bytes，新的header/body完成计量实际成立。随后media仅上游收437124/1529038bytes，header完成=false/body完成=0；27.811秒后仍在等decodedFrame，itemStatus2、NSURLErrorDomain/-1008，剩余deadline12.188秒、cancelled=false、target8.905/live23.092。媒体清单20.061秒终止/-999发生在item失败后routeRevoked，不能倒置为原因。根resource精确绑定master transfer，不等于定位失败media URI。

此次errorLog总数0、accessLog最后URI缺失，明确保存未知。proxy trace原值是既有8位十六进制，首实现只接受UUID使该诊断字段unknown；transfer精确绑定仍成立，不能事后把未知字段当已记录。失败采样原生图为黑场，不能仅此认定具体呈现原因或字幕问题；实际普通退出回原PGS详情、最终Home/Wi-Fi无PiP已看。36原书签全部轨道、零增删/仅本片自然进度、其他非诊断偏好一致；App/自有采集/守卫已停，WDA设置恢复，零新增App/WDA/Jetsam清单项。没有真实播放修复或新增矩阵P。

## 针对缺字段的第二阶段

新证据证明不能只依赖AV errorLog，因此下一补充只读同item的NSError及最多4层NSUnderlyingErrorKey，尝试typed failingURL/stringURL关联；不导出任意userInfo、描述或errorComment，不增加请求或改变等待参数。修正既有8位hex trace准入，仅UUID或严格8hex可输出。旧窗及空日志结果保留，第二次补证若仍无失败资源，不继续第三轮同条件媒体。

NSError补充源码和四项反例完成，136项L0为135通过/1既有跳过/0失败、Xcode正常退出，15预检通过。19:52:09.809163+08正常Debug构建/签名/173输入/29库/三二进制/IPA/链接复核通过，diff `da592296d39ab73cb840c918dc1740fd8a7ca063c997903ff7fe019631dfc26f`，IPA `da39e97c922ffd7a2e7c239b38996286ca0dc1c98c376c193acc6a847767e26f`；profile授权有效。第二次必要构建由实际空errorLog证据触发，不是无变化重复构建。仍仅13保留数据覆盖，25完整偏好一致、19:54空环境首页/NAS在线已看；Pad/18均未操作、仍15:39历史包。

19:56:13–19:57:30第二窗1 Play/0 PiP，同PGS7/空环境/70秒预算/100秒守卫，正常退出。master上游876bytes/重写233bytes完整发送、2.382秒；media上游1224124/1529038bytes、header完成=false/body完成=0，无候选分片请求。候选warmup22.460秒即item失败、仍余17.539秒，NSURLError/-1008→CoreMedia/-12884，两层NSError均无typed失败URI、链正常到叶且未截断，errorLog仍0/access URI缺。短trace已正确保留，原root精确绑定master transfer；不能把root绑定当已定位具体失败media资源，错误码含义未从不受控描述推断。

同一media request的写方向EOF约20.002秒、routeRevoked终止约20.017秒；与第一窗/旧窗约20秒附近结束构成边界线索，不证明固定AV超时、40秒warmup超时或网络/NAS/字幕根因。第二窗失败采样实际片头+转圈/1.8MB/s，普通退出回PGS详情已看；字幕、音频和帧时间不新增P。20:01复核最新173输入/包/签名均未变、WDA auto/10/2 GET回读、两批owned构建/播放进程零遗留；Home无PiP/Wi-Fi原生已看、网络未改、36原轨道/其他偏好一致、零新增崩溃清单项。

本批合计两次有依据的诊断构建/13保留数据安装、两次空环境首页检查及两媒体窗2 Play/0 PiP；没有参数调整或播放修复。第二轮仍缺失败URI，已停止第三轮同条件NAS真片。第二窗[安全结果](../../../testing/results/2026-10/2026-10-21-candidate-error-chain.json)保留完整未知项及新计量，原始NSError/身份/偏好/画面仅本机。

## 下一步与保留项

改用受控本地媒体清单头/正文到达边界，区分“清单未完整可交付”与系统消费者错误；这是media playlist供给反例，不能重复旧4.5秒首片/codec/片长fixture或直接改产品等待/流式重写。先固定可区分的成功/失败条件、捕获真实请求/发送/错误链；若本地也无可控反例，转独立支线，不无限补日志。18等待用户方便，系统X关闭、保存边界、完整SUB/AUD、性能/长稳/Release验收与28项保持开放。
