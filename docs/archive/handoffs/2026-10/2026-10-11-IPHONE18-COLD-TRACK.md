# iPhone18 有效轨道冷续播与历史AV书签身份

更新时间：2026-10-11T19:53:36.883013+08:00。本轮App源码未改；推进上一轮S03轨道差异的普通冷续播和历史身份取证。13/iPad无本轮最新包回归，全部未验PX/UX/CB/L2/L3/Main保留。

## 最新包与现场

本轮重新DNS-SD发现并验证实时既有配对TCP身份：同一用户iPhone18，ProductType=iPhone19,7、系统27.0、当前Wi-Fi可达/USB缺席；设备名、UDID、端点及原始偏好只存私有目录。第一次自动配置选择用了已标为superseded的旧配置，ValueError失败保留；改用live配置后才通过实时发现与身份校验，没有在失败状态播放。

当前HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS差异 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`，173输入/mtime/三二进制/deep签名再次核实，其他dirty保留。本轮使用17:36:31构建、17:38:03冻结的普通Debug/-Onone `Nastart-Startup-Work-Breakdown-Normal-Debug.app`与同名IPA；完整路径/三SHA见[脱敏结果](../../../testing/results/2026-10/IPHONE18-COLD-TRACK-20261011.json)。主程序 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`，Debug `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`，29库签名/profile目标/有效期已核，App profile有效至UTC10月17日22:23:40。无晚于包的源码，不重建同源包。

2026-10-11T19:42:31.221841+08:00～2026-10-11T19:42:42.755173+08:00本轮最新包保留数据覆盖成功，前后25非诊断偏好全一致；未卸载、清登录或清缓存。使用仍ready的既有有效固定WDA，未重装/重建/重启Runner；新建UI session、有序App终止/state1→空env/args启动，实际首页/NAS正常已看。之后播放前再次核源码、签名、包三SHA及实时配对TCP身份。322测试/2跳过/0失败和15预检是此前最终同源结果，本轮未重跑。

## S03普通冷续播

- 上轮正常退出保存1597.289秒，音轨4、字幕关闭；本轮未改写或重置书签。
- 选择原详情“继续观看”，首个合格内部时钟1597.353秒，比保存点+0.064秒；不等于可见首帧测量。t0/1仍准备页，t2实际黑场/spinner及旋转过渡，t3电影无spinner，t5/10/30电影和正常退出详情已人工看原图。
- 请求30秒观察，实际完成请求在触摸后31.665秒；普通UI退出、0/1/3/10/15秒偏好读取完成，保存1627.262秒。仅这一条书签自然更新，音轨4、字幕关闭保持。
- 有效目标帧前过滤23帧；首callback→有效帧152.227ms，调用→首callback95.430ms。内部API/时钟、稀疏PNG不能判逐帧连续流畅、音频可听性或DV/HDR输出；缓存未知、非跨机性能对照。
- 未触发自动HLS候选，不能作为40秒候选deadline回归。普通KS路径有效4/关闭冷保存恢复在本次成立；开启字幕、其他轨道、AV/PiP及历史迁移未验。

## 旧0/0来源取证

上一轮原始S03条目更新时间实际为 **2026-09-30 18:17:20.387337+08:00**。在`2026-09-30-iso-cellular`两份旧私有偏好快照找到完全相同的1506.875827772/音轨0/字幕0开启条目；不是这两轮最新包现场产生的0/0。

以保存时刻附近的playback_ended为锚，严格匹配其plan/trace/route身份，关联到46条历史事件：route_selected=localRemux、AVPlayerLayer.readyForDisplay、AVPlayer seek至1502.510，seek恢复1502.508，结束记录在书签更新后0.015秒。不是仅凭同日所有播放事件猜同一会话。此历史记录仅用于故障分析，不作为本轮包回归证据。

读取9a9941c中的历史保存与AV轨道代码：syncAVTracks用`group.options.enumerated()`的offset作为UI track ID，selected索引亦为组内序号；保存直接写controls.selectedAudioTrackID/selectedSubtitleTrackID。**这些证据支持0/0为历史AV媒体选择组选项序号，不能当成原始文件FFmpeg流索引。** 历史未提交实际设备构建源码未独立取齐，因此不把该Git版本声称为旧设备精确安装身份。

本轮当前直接文件KS路径按源stream index选择；上一轮实际字幕清单5～9，旧0不匹配。旧AV组选项0精确对应哪条原始音轨/字幕的完整映射没有保留下来，迁移不能仅靠数字相等或盲猜第一条；仍需补源轨道/语言/codec身份和缺失偏好回退。旧0/0→4/关闭失败样本保持未验收，本次有效4/关闭恢复成功不覆盖它。

## 原生自动通道与最终状态

19:48:45原生列表/详情读取成功但仍paired、developerMode enabled、tunnel unavailable、DDI=false。19:49:34原生进程查询实际失败，CoreDeviceError4016；保留原始JSON/日志，避免把详情缓存可读当成开发服务可用。随后直接WDA仍ready/固定Bundle匹配。根因未定，不推定VPN、签名或系统版本；网络/VPN/Tailscale/Shadowrocket、配对、系统/remoted/DDI未改。

最终实际空环境普通首页/NAS正常、CPU24%/RAM22%/磁盘63%，其他服务卡片此截图未知；播放器关闭、idle10/动画2恢复。25非诊断键保留，24非书签键一致，仅S03一条书签自然更新；其他书签/登录偏好不变。播放前基线早于触摸，前后只读崩溃清单相同，新增Nastart/WDA/Jetsam均0；不排除延迟报告。

接续：有效开启字幕/非默认音轨的正常冷续播及实际cue/声音；旧AV跨引擎轨道身份的安全兼容；HLS候选完整deadline/分片/read/callback；原生自动隧道独立定位。旧475秒差异、119/真实弱蜂窝、S03/S08/S11/S18/S19代表族、MTP/ISO/TV、AV/PiP/暂停预热、完整帧时间/声音、Lenna及其余竞品和全部未验矩阵保持开放，无性能/竞品或全量PASS。

私有证据：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-iphone18-wireless-playback-194117`。原始偏好/凭据/身份、历史关联ID、设备原图及日志仅留本机；工具已冻结并哈希。此前差异见[上一轮](2026-10-11-IPHONE18-WIRELESS-PLAYBACK.md)。

后续：有效2/5开启冷续播与实际cue见[10月11日下一轮](2026-10-11-IPHONE18-ENABLED-TRACKS.md)；旧0/0失败仍保留。
