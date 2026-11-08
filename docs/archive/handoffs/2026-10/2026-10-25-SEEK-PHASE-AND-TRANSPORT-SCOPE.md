# 大文件seek分段与连接归属校正

2026-10-25接续，当前真实蜂窝系统日志窗口进行中，未作为新的速度改善结论。先读[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。用户18外出；当前USB13与新Pad均现场重核，旧任务/未提交修改保留，28开放/114格不关闭。

## 为什么校正上一轮计数

`AuthenticatedMediaProxyTransfer.diagnosticContext`用`pinnedTransport?.session === session`判断scope。`finish`将session释放为nil后，既可能把pinned误记systemShared，也可能因nil/nil身份相等把systemShared误记pinned；这只影响标签，不改实际URLSession指标的connectionReused、真实画面或时延。旧18/3不能作为准确pinned计数，不能据此进一步推断取流端点切换。

新`testCancelledProxyMetricsRetainSelectedTransportScope`使用真实HTTP夹具，等待上游请求→本地reader reset→实际late metrics；分别验证系统共享和route pool。旧代码1测试2断言失败，修正后同测试及8项原Range/HLS/复用/取消对照共9执行0失败。当前修正仅start选定时保存selectedTransportScope，finish不清除；没有修改下载/Range/取消/缓冲/码率/解码策略。

按旧原始日志同transferID＋upstreamTaskIndex的`upstreamRequestIssued`关联，144完成metrics中62个完成scope不一致、0缺匹配。早期文件pinned 40复用/1新建；混合文件pinned6/1、systemShared67/1；JF systemShared27/1。旧日志与原计数完整保留，安全结果添加校正字段；不能称这些离线重算为当前新包真机验收。[校正JSON](../../../testing/results/2026-10/2026-10-25-transport-scope-correction.json)。

## 当前新包及待补证据

同HEAD 4de732dd加原dirty，普通Debug：实际构建13:39:55，主SHA `1ee98aea825174fb05db71b186300340fa67db6776cce1c7bba498d865d59079`，570输入/30签名及目标profile/deep/AppID/Keychain核过；13 13:41:14、Pad以后续回执为准保留数据安装，安装完整偏好均0变化。两机普通空参数/空环境首页实际图已看，Pad原VPN不改，无新增Pad Runner。

下一步13单独S19真实蜂窝，最外层finally停本轮媒体及自有syslog，再恢复原网/完整Selected/Wi-Fi图，之后才做长时间日志关联。采已有普通Debug `KSPlayer seek ... elapsed`、`decodeTrace`与应用事件，既不注入实验环境，也不修改源码补一个未验证的计时语义。需要分开：主线程提交、seekQueue/旧read/底层av_seek、flush、首解码接受、packet/frame容量与实际画面。已有应用完成时延无法单独区分这些阶段，不先放宽缓存门槛。

私有文本指针`/tmp/nastart-seek-phase-current-evidence`；原始syslog、设备/包/偏好/UDID/端点/截图只在仓库外。完整音听、帧时间、十分钟、格式族/双端并发、18安装及Pad浮窗仍待验。


## 文件HLS运行态丢身份：明确缺陷与修正

诊断包13:44窗真实localHLS/AV起播，控制点击6次，0 native seek_started，随后原生实图“无法准备播放”；后来控件定位失败是次生工具异常，不能吞掉产品错误。syslog已采但此窗没有KS route，不能当缺少KS日志或原流seek时延样本。媒体/自有syslog已停，原网完整Selected＋Wi-Fi图已看。

实际代码链：SharedBuiltInPlayerView.runtimeStateForSourceChange重新构造MediaPlaybackRuntimeState时只复制source catalog ordinals，丢sourceAudioStreamIndex、sourceSubtitleStreamIndex、activeExternalSubtitleURL。文件HLS serverSeekRequestLoader→requestForVerifiedRuntime→verifiedTracks严格要求绝对源ID，丢失后立即nil→GreenfieldVideoPlayerView.replaceSource报告准备失败；JF重建另用ordinal/default，因此两入口不等价。不能通过降低verifiedTracks校验绕过。

先将旧UI逻辑逐字语义提取到MediaPlaybackRequest.runtimeStateForSourceChange并实际回接UI，2新测试8断言失败（Off/embedded/sidecar以及未知/重复身份）。再统一由请求目录构造完整运行态：保留position/rate/orientation、目录ordinal、唯一非负audio源ID、embedded subtitle源ID或外挂URL；Off独立、未知/重复不猜。对应10项原校验/初始轨道/时间轴/诊断定向通过；前批诊断9项亦过，独立组不能误称全量测试。

13:56:52普通新包主SHA `7b82344b8e7b0552b4ca23ff6b5ba675299e326af75717fac459d45974615d90`，570输入/30签名，13 13:58:00、Pad 13:59:22保留数据安装，完整安装偏好0变化、正常空env/args首页已核。当前单次早期+15秒真实蜂窝验证进行中；尚不能称准备弹窗真机修好，更不等于持续几KB/s/6–10秒KS等待根因解决。TV不编译这些移动Core/View/代理源码，本批没有TV包/控制逻辑修改。


## 起播/缓冲的播放意图不能变成暂停

14:00–14:02轨道修正版新窗：单次早期+15确实重新协商HLS并replacement_committed/普通回详情，原准备弹窗未出现。warmup约23.55秒，commit startsPaused=true；实际50秒图停01:43/播放三角/0KB。此0KB是本窗误暂停现象，不等同用户18持续几KB/s网络瓶颈已复现。该窗仅AV，没有KS demux调用是预期，不能拿来拆旧KS 4040ms。

source替换原先以oldControls.isPlaying判断是否暂停；冷起播/缓冲会actual=false但AV现有avWantsPlayback仍true，因此将候选错误设为startsPaused。修正引入controls只读readPlaybackIntent/wantsPlayback，AV绑定现有avWantsPlayback、KS绑定KSPlayerLayer现有私有isAutoPlay的新增只读wantsPlayback；handoff、替换初态/最终暂停依据意图，取消连接时释放reader，KS toggle也按原意图而非传输瞬时值。无Range/码率/缓存阈值变化。先保留旧语义提取2测试5断言失败；第一次green因为直接读取KS私有属性编译失败，原失败留存，改只读接口后12定向0失败。当前intent-candidate待普通构建/逐机安装及真机回归，不能称误暂停已实机解决。

共享KS只读接口使TV源码指纹发生变化；TV本批尚未重建/安装，11:14仅为最后已验安装包，不能将其当本批新源码回归。TV调用方没有使用新getter或新移动runtime helper，功能行为无本批直接改动，但下一次TV调试仍须新包核对。


## 意图新包真机收尾

普通Debug14:52:11，主SHA `a4477a45399a651a9954ffc2e564fdd9fb4008e08c9f3d13999859276161428d`，570输入/30签名/目标profile/deep/AppID/Keychain已核；13 14:54:11、新Pad安装时间见安全JSON，逐台保留数据安装/全安装偏好0变化，空env/args正常首页实看。13 14:57–14:58单次早期+15，真实localHLS/AV；replacement warmup11.744→19.879秒/约8.14秒，commit startsPaused=false，随后实际片段变化及内部时钟推进到162秒，无新增stall样本，普通回详情成功。首个旧窗准备弹窗与第二窗暂停/0KB仍保留，不能把8.14与23.55秒当同条件速度提升比例。

三窗最外层finally均停自有媒体及syslog、恢复原Wi-Fi原网完整Selected/原生图标实看。13原50/10/2/auto及未知Runner未改；Pad无新Runner，原VPN不改。最新13仅自然续播/诊断变动，Pad仅诊断变动，其他偏好不变，终核源0漂移。没有本批Release、完整音听/逐帧/十分钟/格式族/双端并发验收；旧KS 6–10秒及18持续几KB仍未关闭。[结构化结果](../../../testing/results/2026-10/2026-10-25-seek-source-state-and-playback-intent.json)。

用户随后追加TV量身适配：简介仅长文折叠、演员跳转价值、重播图标、隐藏顶端关闭/静音、减轻进度焦点框、三端豆瓣评分。下一阶段先核数据来源与当前TV代码/真机，手机本批播放已收尾；不把UI任务当取消旧播放性能缺口。
