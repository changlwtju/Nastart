# 共用跳转执行与离线整合恢复

更新：2026-10-29T09:25+08:00。承接[上一批状态整合](2026-10-29-SHARED-SEEK-AND-HANDOFF-BOUNDARIES.md)及[事件中断记录](2026-10-29-NAS-INCIDENT-AND-DEVELOPMENT-PAUSE.md)；[结构化结果](../../../testing/results/2026-10/2026-10-29-SHARED-SEEK-COMMAND-EXECUTION.json)。用户明确将黑群晖处置留到回家，重新授权继续App播放链路统一，NAS恢复后才做真机性能优化。本批保持6.1，未切Astra、未访问NAS/复用旧凭据/控制或安装真机。

## 实际接受实现

此前选定设备文件/Jellyfin的Greenfield基础：移动三类视频入口进同一Greenfield宿主，TV三类入口进同一TVUnifiedPlaybackView/Session并直接引用移动规划/协调源码。现有PlaybackSessionLifetime统一准备、替换交付和释放；PlaybackSeekState统一连续目标/代次/完成/退出失效；PlaybackHandoffBoundary统一候选当前性。来源层只提供文件定位、鉴权及服务器会话/轨道协商，音频仍为既有音频宿主，后续协议应接现有视频宿主而非另建链。

本批新增同一个`NetworkMedia.PlaybackSeekCommandExecutor`，移动AV、移动KS、TV AV、TV KS四处实际直接调用。统一主线程完成准入、旧命令拒绝、清待完成状态→读取最新播放意图→更新原生时钟/界面顺序。当前性同时核原生player/item或layer身份与代次；同一回调重复到达、退出后或换源后的回调均不再恢复播放，较旧请求也不能清掉最新请求。

| 适配 | 位置 | 继续保留的必要差异 |
|---|---|---|
| 移动KS | GreenfieldKSPlayerRenderer.connectControls | 原字幕seek、暂停画面和时钟 |
| 移动AV | GreenfieldVideoPlayerView.connectAVControls | HLS绝对内容时间到item时间偏移、AV诊断 |
| TV KS | TVNASViews.TVKSPlaybackControls.seek | 遥控UI、KS原生接口 |
| TV AV | TVPlaybackSession.TVPlayerControlsModel.seek | 遥控UI、AV原生接口 |

KS库ready分支会捕获派发时autoPlay，在用户稍后暂停时仍可能完成后play；旧TV源的受控假原生播放器测试已复现（退出65/两断言失败），原红测留存。现从适配层在ready/seekable时以autoPlay=false派发，完成准入后读取layer.wantsPlayback最新意图。未ready/不可seek时直接失败而不写库的待启动autoPlay；不让一次失败跳转改变既有播放意图。原生遥控可绕过界面状态，TV也据layer最新意图同步，避免读取旧Chrome状态。原KS库核心没有修改。

这是异步命令正确性与复用整合，没有调整解码、缓冲、探测、超时、码率或seek性能参数。平台renderer、预热与服务器换源执行仍保留适配，不能把共用命令层描述成所有跨端实现逐行相同或真实性能已经改善。

## 验证与候选包

- 中断的8份源哈希恢复时全部一致，再补TV原生遥控意图用例；原始失败及中断现场保留。
- 共用模块32项全过，新增6项覆盖暂停/继续与最新倍速、旧/重复/离场回调、失败/非法请求。
- TV完整单元61项全过，新增6项使用可控假原生player，不读NAS、不解码视频；包含原红测转绿、最新原生命令、未ready、失败及stop后完成。
- 移动选中34项：33通过、1因模拟器不支持PiP控制器跳过、0失败。既有小型本地视频仅功能回归，不能充当大文件性能对照。
- 移动/TV普通签名Debug与无签名Release编译成功；Release没有签名安装或呈现验收。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`及继承未提交修改保留。430个构建输入逐项SHA冻结、构建后再次一致。完整包路径、命令、日志、xcresult及逐Mach-O签名留本机私有证据，定位`current-shared-seek-execution-validation-private`；root包/输入清单现指本批候选。

| 候选 | 构建时间 | main SHA-256 | debug SHA-256 |
|---|---|---|---|
| 移动 Debug | 2026-10-29T09:20:53.260722+08:00 | `14a868c197855513cb01848b87ed2409476af0d0264373ad2864defc86701279` | `f89c190070c523449426be8fc3ee587a5efe0599c35141629e1e97b4465aaca5` |
| TV Debug | 2026-10-29T09:20:29.917305+08:00 | `3f3109c47a276a00a7adcb9817f61555972b5a465055663de68a1bc87f626ec6` | `c2ca36cc72ccb46609b2a5d0d30bfc289b8f84e63036d7a18e96c2b00c88a1ea` |

30/27个Mach-O逐项签名、deep/strict及TV嵌入库检查通过。候选args=[]、env={}，**均未安装真机**；不冒充当前设备最新包。当前设备仍前批已装版本；恢复时重新现场核身份和包，不能沿用历史设备列表或仅比较0.1.0/1版本号。

## 边界与接续

离线共用核心、会话及命令层已接入并通过上述验证，真实呈现/性能仍待NAS安全恢复。0NAS请求/登录/源写、0设备安装控制、0蜂窝/新性能窗口，114格不增P。13大文件约1MB/s与缓冲、Pad控制/普通退出、ISO、实际音轨字幕切换、PiP、弱蜂窝和Release缺口保留；不据单元测试关闭需求，编号仅在[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)维护。

NAS处置方案、是否关机隔离仍未确认；本批不处理入侵、不探测服务、不触及设备已存登录。旧NAS凭据/SID不可信，恢复真机前须用户确认新环境及授权。届时按fresh设备/包核对、保留数据覆盖、默认正常启动，再以同片/同点/同网络核三入口和三端；核心性能优化任务准备就绪后才提示切Astra6。无定时任务或结束后后台执行。

收尾：430输入再次核同；本批新增/变更行无尾空白，继承原稿保留。文档514份／3090本地链接／0缺链。所有本批构建与测试命令已结束，无自有持续采集或真机任务。
