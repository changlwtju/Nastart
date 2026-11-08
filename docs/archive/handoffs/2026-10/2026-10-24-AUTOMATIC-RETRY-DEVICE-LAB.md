# 自动失败后重试的真机验证

2026-10-24 05:06开工，接[上一批实现](2026-10-24-FAILED-CANDIDATE-RETRY.md)。关联PX-03，28开放项和76格完整通过率保持；编号仅[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。

## 变更卡

- 基线：HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty，00:00普通Debug已在三台安装；原S03/S19自然150秒窗均attempt0，不能验失败后重试，不继续同条件重播。
- 缺口：既有Debug本地候选按钮只走单次手动replaceSource，无法证明自动采样任务选择失败候选的后续loader。
- 最小验证入口：仅DEBUG的PlaybackLabLaunchRequest增加显式AUTOMATIC_RETRY标志、同源HTTP(S)候选m3u8与有限时长配置，互斥手动候选/预热代理模式。原流附加自动协商loader；调用现有PlaybackAdaptiveBitratePolicy与候选trace的真实ThroughputStore，URL的ceiling只交给本机fixture选择故障响应。每次返回的候选继续捕获自己的上限/trace；无网络读取的冷注册，原tracker释放注销路线。普通空环境没有该入口，Release不编译，不更改自动触发/冷却/尝试预算/40秒/就绪/对齐/Range或NAS。
- L0：3新增测试覆盖显式同源准入/普通关闭、两种来源的实际MediaPlaybackRequest闭包在资源释放后继续降档及trace更新、取消协商返回nil。连同前批37，共40 XCTest正常通过/0失败。模拟器保活wrapper及中段AC快照已留，非完整三段性能计时。真机构建使用自有子断言/AC开始中段结束核验。
- L1计划：iPhone13现场核身份及最新包，先保留数据覆盖和空环境正常NAS首页，再以显式Debug配置运行本地连续H264/AAC MKV→HLS。本机原流限供给，第一档VOD的分片返回HTTP503，较低档分片正常；不注入capacity/强制触发/修改门槛，不使用NAS或蜂窝。要求实际自动请求1→失败→保存候选上下文→自动请求2协商更低档，失败路线释放、原流保留；若提交则另外核实图，不把日志时钟当连续呈现。最外层停止App/自有服务/日志/独立守卫并恢复空环境普通启动。
- 成功范围：只验证自动重试接线/资源/原预算，不等于真实NAS/PGS/弱蜂窝性能、声音/完整帧时间或Release验收。失败保留，不能为凑PASS放宽门槛；同条件两轮无改善停止试探。

## 执行现场

05:05:07普通Debug/-Onone/Xcode27新包已构建冻结；174输入、iOS diff SHA `651473ca741de5118a916b47777bf98943082f0af4393f5a51eb5723131c1c61`、IPA SHA `e871defaaa3ec0d35da7bf2e3a054360e370a781b46acb7edf7e70e652fb48c6`，三二进制/29独立库及deep签名/profile/IPA CRC/链接核过。私有指针`/tmp/nastart-automatic-retry-device-evidence`，当前包指针已同根。13实际iPhone14,5/iOS16.3.1/USB名称与UDID逐窗私存，WDA ready/session现场有效，已保留25完整非诊断偏好覆盖及普通空环境NAS在线首页实图核过。

### 两个本地真机窗口

- 第一窗05:08:02–05:10:15，1次显式lab启动、0手动候选/seek/PiP、0 NAS媒体；本机原流在1MiB突发后128kbps限速。05:08:31.977原自动规则因持续再缓冲请求attempt1，容量未知，20→8Mbps；原trace `971581B3`，候选 `124BAEC9`。第一候选有效VOD、9次故障分片503，30.732秒decodedFrame阶段失败，剩余9.267秒，candidateCurrent=true/cancelled=false，未提交；原KS会话保留并继续推进。失败事件后保存8Mbps候选后续loader。
- 05:09:48.123原规则请求attempt2（距第一次76.146秒，保留原60秒冷却和非合格期间保护，不修改等待）；第二次fromCeiling=8Mbps、sourceTrace=失败候选`124BAEC9`，toCeiling=4Mbps、新trace `7735B269`，容量仍未知，按原保守梯度继续降档，未回原20Mbps。05:09:49.118提交，candidate22.8427/live22.793、储备1.091秒；实际后续图有00:41.833与末标题Automatic Retry Candidate Lab/00:44。清单实际请求8/4两值分别对上，第二候选健康分片8次读取完成。第一故障路线末读取在失败事件后约75ms内，随后不再有其请求；注销由源码及实际MediaPlaybackRequest资源释放后404的L0覆盖，**未在真机直接探测退休route的404**，不扩大成全部路线资源原子性验收。
- 这里的8/4Mbps是协商上限状态，HLS为同一预编码连续H264/AAC素材，**没有真的重新编码两档画质**；不是NAS/PGS切换或画质/声音/全帧性能验收。该窗只证明实际自动采样→失败上下文→下一次更低协商→提交接线成立。
- 取消窗05:11:21–05:12:03：同一原规则attempt1，20→8Mbps。分片故障回应改为有界等待，准备期间点一次完成（显式lab根视图，仅验证closePlayer取消任务，不声称普通详情退出）；5.497秒decodedFrame失败、cancelled=true，窗内无retry_context_updated、第二协商或commit。fixture记录分片连接在5.442秒于发送头前被客户端关闭。原图保留后立即停止自有App/服务/日志/守卫。只观察取消后短窗，非无限期无重试证明。
- 两窗各25完整非诊断偏好保持、新增Nastart/WDA/Jetsam报告名0，App WDA状态1/1、自有服务/日志/独立守卫均停止；AC与确切自有caffeinate断言开始/中段/收尾核过。持久诊断包含前窗历史，聚合按每窗精确开始/结束时间过滤再核source/candidate trace；不得直接把整个容器计数当取消窗结果。首次离线聚合混入历史，已在原始历史保留后修正过滤，不修改原始诊断。

### 普通基线与最终收尾

05:13:37–45恢复空环境/空参数普通NAS在线首页，25完整非诊断偏好保持并看实图。05:16:35–05:17:42执行S01/JF普通30秒窗口：1 Play、0 seek/PiP，启动环境与参数为空，原详情标题现场核过；3/10/30秒不同片头、末00:30以及回原详情实图已看。实际路线KSPlayer/directPlay/localRangeProxy，34遥测末stall0，窗内新增Debug自动协商0。36书签键与轨道/其他24偏好保持，1自然进度条目变化，新增报告名0；App状态1/1、日志/独立守卫停，AC和确切自有断言开始/中段/结束核过。不是声音/完整字幕/完整帧时间或整格验收。

05:19:24–32再次空环境普通NAS首页并看实图，25完整非诊断偏好前后保持，随后仅停止自有前台App。05:20:46最终核174输入/当前包/自身安装回执与实际USB设备，完整非诊断偏好两读稳定、原36书签键轨道及其他24项保持，仅positionSeconds/updatedAt自然变化。原生Home有Wi-Fi图标、无PiP实图已看，WDA App状态1/1及原设置恢复；自有App/fixture/日志/守卫/安装助手均停。本批0蜂窝，未改NAS/网络/VPN/音量，未卸载清登录。

### iPhone18安装受阻与Pad范围

18重新实时DNS-SD/名称/UDID/既有配对核过，实际iPhone19,7/iOS27.0/NETWORK，目标包签名/哈希已核。05:14更新在savingPreferences阶段HouseArrest连接中断，容器备份未完成，故未上传、未发送安装指令、未见Complete，未请求启动。后续只读检查连接重置，无原生截图，不能断言锁屏。已一次请求亮屏解锁并保持家庭Wi-Fi，待回复，不重复催促/抢前台。当前仅确认00:00包于00:08:57 Complete/lookup，05:05包尚未安装；不能把前批成功继承为最新包成功。原始失败与只读检查均私存，恢复可用后先重新核身份/包并完成备份再安装。

Pad本批0设备命令，仍00:00包；前批普通首页及S01双入口有限结果不能继承05:05包。下次Pad调试先按最新包门槛保留数据更新，再有界XCTest启动原有效Runner。

### 接续：真实请求生成的源码核对（05:29，无新增设备操作）

离线逐项核真实两入口，而不是重复本地播放或无触发原流：

| 路径 | 当前源码事实 | 验收边界 |
| --- | --- | --- |
| Jellyfin候选后续loader | LaunchpadView.swift:7828–7878，transcode候选捕获自身maxBitrate及新playbackTraceID；保留该候选协商时的源音轨/字幕index，避免把单输出轨道ordinal当源index；起点来自本次live runtime position | 仅源码核对，尚无真实第二次请求/PGS音画证据 |
| Jellyfin重新生成 | 同文件:8137–8190，adaptiveFallbackRequest按候选trace近期吞吐及当前网络有效测量选更低上限，再调用普通playbackRequest；makePlaybackRequest生成新trace，transcode请求保存自身ceiling/源轨道。外层context/cancellation校验未通过时释放已准备资源 | 不证明真实服务端更快；未发新NAS请求 |
| 文件候选后续loader | DevicesView.swift:2491–2600，每个新请求生成trace并捕获自身bitrate；verified-runtime路径按稳定源index验证音轨、字幕/外置字幕及有效live position，再以lower创建下一请求；结束取消时释放 | 未复测真实文件自动重试；不把原流>=16GiB准入误当所有文件都可降档 |
| 共用失败记录/释放 | GreenfieldVideoPlayerView.swift:437–470选择已保存loader；replaceSource在原会话/取消/seek/PiP/轨道条件仍有效时回调，defer释放未提交候选资源。后续闭包不依赖候选播放器存活 | 真机退休route的直接404与专门预算耗尽仍未验；L0有限覆盖保持 |

本次静态核对未发现需要新增源码修正的依据，不新建包或修改NAS/门槛。下一实测必须区分协商输入、真实输出码率、首段可用与实际字幕/音画；源码核对不能替代这一缺口。174输入及iOS diff最终仍同05:05包。

[结构化安全结果](../../../testing/results/2026-10/2026-10-24-automatic-retry-device-lab.json)。真实PGS40.005秒候选失败及旧7300ms不因此关闭；完整预算耗尽/第三次准备拒绝在L0覆盖，本批真机没有专门耗尽预算，不声称该设备场景通过。

本批结果与逐台安装/现场收尾已补录；原始身份/偏好/包/日志仅仓库外私有证据区。下一步继续真实NAS候选的供给成本与后续loader轨道/runtime归属，不重复同条件原流或已完成本地窗口；真实编码码率收益仍待验。来源范围和已验/待验分开记录，不改NAS/VPN/网络/音量、不卸载清登录，不建调度。
