# ASS→PGS同进程保存与外部偏好同窗核对

2026-10-22 05:34:34–05:35:47，关联PX-08/PX-21。承接[保存观测接线](2026-10-22-RESUME-SAVE-OBSERVATION.md)与[配置地址恢复正常首页](2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md)，没有新源码/构建/安装。最新05:26普通Debug/-Onone的173输入、包、签名/profile/安装回执与13现场名称/型号/iOS/UDID/USB均重新核对；空环境正常启动。Pad/18未操作，18仍用户暂缓。

## 变更卡与执行边界

问题：旧15:39 ASS切回PGS后外部plist仍ASS，seek完成后2.783秒已派发关闭，缺当时内存提交证据。本窗只观察真实新Debug强制保存路径，未加synchronize/等待/存储修改，不试候选播放参数。成功条件是同key、owner、门槛、源轨道和entry参考秒可区分内存与磁盘，不以字幕菜单或一条偏好替代。

同项目其他任务均notLoaded，主机无其他媒体/采集/构建进程后串行执行。13/S03/Jellyfin原流，当前详情原PGSSUB已核，选择简英ASS后单次Play，3/10/20秒采图；正常选择回原简英PGS，再正常完成退出。1 Play/0 PiP/无系统播放命令，独立100秒停止守卫及最外层finally覆盖，未重发动作/候选请求或改网络。

## 实际观察

| 同一私有resume key | 音轨 / 字幕 | position | updatedAt（Apple参考秒） |
| --- | --- | --- | --- |
| 测试前 | 1 / 7 PGS | 49.524 | 813920182.501888 |
| ASS播放后的外部plist | 1 / 5 ASS | 12.638 | 814311321.018010 |
| 切回PGS、关闭前外部plist | 1 / 7 PGS | 22.354 | 814311331.342281 |
| 正常关闭后、收尾外部plist | 1 / 7 PGS | 25.533 | 814311334.532995 |

强制边界`close`与`viewDisappear`均KSPlayer、同一个完整owner UUID、ready=true、resumeTimelineConfirmed=true、pendingSeek/pendingSeekPosition/waitingForPausedPreview=false，推导audio1/subtitle7、external=false/selectionKnown=true。两次saveOutcome=submitted、memoryReadback=match；close entry参考秒814311333.909189，disappear为814311334.532995，最终外部同key entry时间与后者逐值完全相同。`durabilityEvidence=sameProcessOnly`保持，不推算冷启动/掉电耐久。

这两条事件在本窗实时syslog中没有出现，随后从本窗保存的`diagnostics.entries.v1`找到，原始偏好与时间已交叉核对；没有因syslog缺行重播或追加诊断构建。结论是本窗内存与外部偏好一致、旧故障本窗未复现；不将正常一窗当旧故障根因或已修复。完整字段与[安全结果](../../../testing/results/2026-10/2026-10-22-track-save-memory-window.json)对应，原始key/偏好/图片/日志只在`/tmp/nastart-track-save-window-evidence`，prior为配置地址恢复批次。

ASS10实际星空片头、切回PGS前关闭图实际Paramount片头/00:23已看；该段无活跃字幕cue，只有3/10/20及关闭前图，没有30秒/听音/完整帧采样，不作为SUB/AUD/完整ST/PiP通过。保存观察与实际字幕内容验收分列。

## 收尾与下一步

36书签未增删，全部原音字幕/关闭状态保持，只有目标一条进度更新；其他非书签偏好逐值一致。正常完成回原详情，App/自有syslog/守卫已停、原生App不在，开闭窗崩溃清单没有新增Nastart/WDA/Jetsam报告名（只是本窗清单差异，不作全局无崩溃承诺）。最终原生Home无PiP/Wi-Fi图标已看，网络/蜂窝/SSID/VPN未改；当前13有效session为本私有目录session-id，已恢复auto/idle10/cool2，先前05:29 session被替换。原始偏好未直接写回。

停止重复同条件保存/候选影片。旧15:39错误原因、不同seek位置/字幕格式及冷启动恢复仍开放；后续优先按相同包核Pad正常NAS入口，18待用户方便。28项保持开放，未提高正式矩阵基础格/完整SUB或PiP状态。
