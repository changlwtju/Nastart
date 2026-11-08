# 手动调试深起播修正与真实12Mbps深位置接手

时间：2026-10-24 08:25–08:50（Asia/Shanghai）。接[Pad格式与普通触发核对](2026-10-24-IPAD-FORMAT-REGRESSION.md)，[安全结果](../../../testing/results/2026-10/2026-10-24-manual-lab-deep-resume.json)。关联基础播放/候选观测，28需求与76格完整状态保持，编号仅[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。

## 反例、修改与验证

首个旧06:20包窗请求手动lab原流从4000秒启动，实际本窗syslog首帧0.052秒；位置守卫失败，0候选触发，不能当深位置测试。短窗诊断偏好未及时落盘，不能将持久日志无新事件当作没有播放。原始syslog、失败及精确自有会话DELETE204保留，随后恢复旧包普通首页并收尾。

根因：NastartApp的DEBUG手动候选入口验证了candidate duration，但makeRequest只给automaticRetry模式填写totalDurationSeconds。GreenfieldPlaybackBridge依赖已知时长把initialPosition比例换为preferredStartTime；手动原流因时长nil而丢失4000秒意图。最小修正仅让已准入手动配置的时长同时进入原始启动请求；不改桥接、普通入口、自动采样/预算/冷却、Range、缓冲、40秒或NAS。Release没有此Debug入口。

7项定向XCTest正常TEST SUCCEEDED/0失败：新增实际MediaPlaybackRequest→Greenfield启动桥接的4000秒反例及未准入配置不得注入时长的测试；另5项覆盖手动准入/冷注册、自动重试准入/后续闭包/取消。15预检通过。前批45项仅历史记录，不合并称本批47项。普通Debug真机构建正常完成，174输入/29动态库逐个及deep签名、profile目标/期限、IPA CRC/链接均核过。

## 当前包与安装

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty，08:37:48普通Debug/-Onone/Xcode27；iOS diff SHA `ac46cac3a43778651e80d6a4fd7be41f600160d91248763c1eb9c8a60579b690`。IPA SHA `8887b633ecd533c8ca31b6c174eb7ffa3bf5de42ed16b0462c059bdcb69b15ee`。

| 二进制 | SHA-256 |
|---|---|
| Nastart | `34949cf579446c1f8d387d98665b5cb524a0d973d510ea187af73fe65710ff03` |
| Nastart.debug.dylib | `46aeb2ace3d305e5daa6074cae53f0986957ff308eb278235cde6ccc706a291c` |
| KSPlayer | `62a0ab10f21be5ec0e0c83a95889c9099df20a16b0863b44001bcdf16a920964` |

13现场iPhone14,5/iOS16.3.1/USB，08:40:06保留数据覆盖成功，25非诊断偏好安装前后全同；08:40普通空环境/空参数NAS在线首页实图已看。Pad现场iPad12,1/iOS18.3.1/USB，08:48:52保留数据覆盖成功、18非诊断偏好全同；08:49普通首页实图已看，0 Pad媒体。名称/UDID/旧诊断/容器偏好私存，逐设备现场读值，不继承他机回执或同版本号。

私有指针与全局包指针分别为`/tmp/nastart-auto-candidate-continuation-evidence`、`/tmp/nastart-candidate-device-lab-evidence`，现均指本批真实新包根，读取strip。package-before-fix-private-root保留旧06:20冻结根；prior-private-root接Pad格式批。包/原图/偏好/凭据/端点/身份及完整日志均只留仓库外私有区。

## 深位置窗口与边界

新包首次复验08:41首帧4000.148秒，实际原生图1:06:40/飞机海面，深起播修正已生效；但私有截图复核marker晚于45秒等待，流程自动结束，0候选。保留失败/实际有播放/DELETE204，不计候选失败。下一助手移除人工复核等待，保留当前窗口日志深位置断言、原生图、目标2秒新鲜度、唯一点击/效果与总时限。两窗失败原因不同，不将其合成三次候选试验。

08:44:43–08:45:51有效受控窗：1显式Debug原流启动、1候选触发，0普通Play/seek/PiP/Mac媒体GET/限速。原流Static MKV为同源54,005,939,750bytes，初始请求4000秒，实际首帧4000.148/1976ms renderer标记；候选提前私有PlaybackInfo协商StartTime4012.008秒、max12Mbps、H264/AAC/PGS7 Encode。实际源/源轨道/服务身份逐项新核；协商上限不当恒定输出码率。

| 边界 | 本窗内部证据 |
|---|---|
| 完整清单 | 8627ms；master/media各1上游指标+1当前窗VOD缓存命中 |
| 候选创建时 | live4020.884、原流储备3.478秒、lead3.228秒、target4024.112 |
| 首片完成指标 | ordinal1005，5,835,332bytes；等头3550ms/正文5409ms。首解码早于该片完整完成，不将两段与全部准备耗时简单相加 |
| 首候选解码 | 14390ms；candidate4024.112/live4026.644，已落后约2.53秒 |
| 对齐/提交 | 对齐22669ms，candidate4034.991/live4034.921/帧4034.906/储备0.845秒；事件warmup→commit22.826193秒，提交储备0.790秒。未延长40秒 |
| 接手后 | KS起播计数1/801ms保留；AV安装后waiting/toMinimizeStalls、bufferEmpty=yes且clock4034.991未推进，计数1/990ms；随后buffer4.961秒/playing，首推进到4035.502。保留内部实际等待，未测精确屏幕卡顿时长 |

对齐时accessLogStalls69包含准备期，不当69次用户卡顿。replacement_committed.seconds4034.857是旧controls采样值，与对齐时precise live4034.921计时口径不同；源码提交前仍用preciseCurrentSeconds复核，不能拿事件采样差0.134秒冒充精确同步验收或绕过门槛。

实际原生7图（原流ready/按钮前/候选+3、10、30、45/末）已逐张看：不同动作电影画面，末明确Candidate Lab/1:07:38。未采到对白字幕cue，PGS Encode协商不当完整字幕呈现；稀疏图不当全帧、听音或无感切换。此窗是手动真实深位置KS→AV有限证据，不是普通自然自动/真实失败后再协商。旧自然12Mbps/40.005秒失败的清单、首片1002、供给、原流储备和协商时点均不同；本窗1005不做修复或提速A/B。接手后990ms与既有7300ms问题继续开放，不盲调自动等待或缓冲。

## 收尾与设备阻塞

三个窗口各精确自有NAS会话DELETE204/remainingOwnedSessions0（不单证编码进程退出），App WDA1/1、25非诊断偏好全同、新Nastart/WDA/Jetsam报告名0，日志/守卫/本批保活停止。开始/中段/结束自有caffeinate与AC核实，最外层finally有界收尾，未停止13已有非本批WDA。

13于08:46普通空环境NAS首页恢复实图；08:46:58新核174输入/包/自身回执/USB、完整偏好两读稳定、36键轨道/其他24项保持，当前安装后changedBookmarkFields空，Home Wi-Fi无PiP实图已看。Pad原生XCTest复用有效Runner，无WDA构建/安装；08:49:14新核源包/回执/USB、29键轨道/其他17项保持且两读稳定，native App0/Runner0、Home Wi-Fi无PiP已看。本批Pad无媒体，不继承旧06:20格式结果为08:37最新包回归。08:50:41本私有根活动进程0。

18于08:25重新解析已配对服务仍ValueError；系统当前2广播中规范化同目标0，0新设备值/备份/上传/安装/启动，未扫旧IP、重配对或改设置。仅历史00:00包已装，08:37最新仍未装；既有一次解锁保持家庭Wi-Fi请求待反馈，不重复催促或归因锁屏/VPN。无蜂窝测试、音量/网络/NAS改动、卸载/清登录、调度或回合后后台执行。

下一步先核新990ms的等待/储备/安装策略边界，区分实际时钟等待与准备期access log；普通自然自动/真实失败后新协商及同格式第二深片源仍缺。保留旧失败，不重复无触发150秒、两种失败精确滑块或相同已完成窗。18连接变化后先现场身份/最新包、备份再保留数据覆盖/实际普通首页。

## 接续：接手后等待的配置时序（08:58，离线）

本窗7条av_handoff_boundary均已保留。相对助手启动39.140秒时，候选暂停持帧、储备0.790秒、automaticallyWaits=no/forward0.5；39.141改为yes，39.142改forward3，储备未增加；39.223调用继续，39.316进入waiting/toMinimizeStalls，40.293回playing、时钟仍4034.991，40.900首次观测推进。等待发生在replacement_committed及原流暂停之后，不能归到8.627秒清单准备或原KS的801ms起播。

源码安装阶段为预热播放器切换等待/forward策略，预热/就绪门槛仍0.5秒：这里存在“提交门槛与提交后配置”待验证的时序假设，但单窗相关性不能证明唯一原因，稀疏图仍无精确屏幕卡顿时长。0新设备/NAS/媒体请求，未改App或包。

下一确定性反例应在相同供给/40秒预算下比较最终播放配置在准备期与安装期应用的差异，记录旧流停止、候选配置/clock/range/wait及首次推进；若选准备期配置，必须仍保留原流直到解码/对齐/就绪、失败保留旧流和取消/seek/PiP代次隔离。先固定反例再选最小修正，不直接关闭自动等待、放宽储备或拉长40秒。该方案尚未实施，不计修复通过。
