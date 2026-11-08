# TV 原始轨道目录与候选接手

核对：2026-10-25。接续[总交接](2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)的原始音字幕阶段。[结构结果](../../../testing/results/2026-10/2026-10-25-TV-SOURCE-TRACK-CATALOG-AND-HANDOFF.json)。原始身份、地址、包、偏好、完整日志及截图留私有 `/tmp/nastart-tv-source-tracks-evidence`，最终包与实播在其 `final/`。本批未改移动源码，保留原 dirty。

## 当前接受实现

TVModels 新增 PlaybackInfo 的原始 MediaStreams、默认绝对索引及 TVSourceSelection；详情只读 TVDetailStream 继续独立。TVJellyfinClient 切轨请求固定 MediaSourceId，并发送 AudioStreamIndex/SubtitleStreamIndex，StartTimeTicks 仍为0、维持绝对播放器时钟。显式选择关闭静态 DirectPlay/DirectStream 捷径，沿既有20Mbps/H2641080方案重新协商；校验返回源、目录与实际URL中的轨道索引，不拿 AVMediaSelectionGroup 的数组序号冒充源索引。服务端按协议省略 Off 的-1时，先拒绝冲突，再把-1明确写入候选URL。错误候选只清理本次协商会话。

TVPlaybackSession 持有同一 controls，菜单读取源目录；候选 AVPlayer 保持暂停，ready 后按当前绝对位置 seek，核对世代和最新用户意图版本后接手。保留暂停/继续、倍速、静音和待提交 seek；失败不替换旧播放器，同轨重复选择不发新协商。协商使用原20秒网络超时，候选 ready/seek 另有20秒独立守卫及取消清理；这不是移动40秒策略的变更，也不是性能优化验收。进度上报携带源轨索引；固定 AVPlayerLayer 继续使用，未接移动完整 Intent/Plan/Route、Range 或文件 KS 控制。

## 验证及实际边界

- 最终普通 Debug：510 输入/27签名 Mach-O，主SHA `86cb61994c8195e40c62e7e32f997e87c668df8fb87c6e0e5be4939fae3beb97`，2026-10-25T21:50:48.128696+08:00 保留数据覆盖 AppleTV14,1/tvOS18.2。现场名称/UDID/连接及 profile/AppID/Keychain组均核过，正常空参数/空环境首页实看；后续再次启动自动化不冒认普通启动。最终47逻辑＋11无媒体UI完整退出0。
- S01/JF：最新包0/3/10/30秒实图；原目录3音轨、字幕4。暂停换音轨、Off/重复Off/On、1.5倍速、原位置和播放中再换音轨已有实际候选提交与后续画面/时钟。未听音；On截图此时未见对白cue，不能据菜单/请求把 SUB/AUD 汇总为P。
- S03/JF：4原音轨、ASS5/6和PGS7/8/9目录。实际暂停5953.45秒，Off与ASS5同画面/同时间，ASS后可见中英字幕，1.25倍速/暂停/音轨1保持；这是实际字幕单cue切片。选择→接手内部19.508秒，保留慢等待，非首帧/流畅通过。PGS只列目录，实际切换和取消专项未执行；用户随后追加只读网络媒体库与设备任务，本轮保存现场后转入新工作。
- MP4多轨初始选择、外置/编码族、快速连续选择/seek/退出取消、真实音频连续性、长播/帧时间和Release仍待验。原28开放／114格保持；不能用本批关闭手机或TV整项。

## 测试失败与修正

初窗重复选择已经选中的字幕4，脚本误等第二次提交而超时；产品没有多余重协商。第二窗 AX 报未选字幕按钮 focused=false，几何定位脚本继续按键落入进度条并多seek90秒；该窗后续不作位置/性能对照。无媒体真实视图夹具改采逐次 UIFocusSystem 提交，证明 Down 已到字幕4而 AX.hasFocus 仍false，不能将其记为产品焦点错误。未奏效的 focusSection 尝试已完全撤回；最终测试按原生提交验入口/往返及所有中间项，普通实播定位读取 DEBUG FocusState 诊断，两种证据分开。

早期10UI用例报告过但结果封装卡住，保留日志并停止自有进程；最终关闭冗余失败系统诊断采集，47＋11 sealed xcresult 完整成功，不把旧未封装报告算门禁。夹具 allowlist 首版漏接导致的失败亦保留。

S01最终脚本曾因全屏下仍可见的详情AX节点误判退出，未发Menu；复核服务器发现仍在播放后立即补返回。最终stop事件在1092.02秒、服务端0活动媒体已核，初次错误断言和额外播放保留，不称即时清理成功。收尾改为主动发送本轮退出并核 stop/服务器，不能只看底层页面节点。S03换流后实际面板已关闭，脚本再发Menu导致普通退出，stop及服务端0已核；此失败不等于ASS解码失败，也未覆盖PGS。全批0蜂窝/未修改网络、VPN、NAS或凭据。

## KS 文件控制接续的事件归属

现行 TVNASPlayerView 外层“完成”/onExit 与 KSVideoPlayerView 内部 playView/onMove、mask、controller/info焦点、自动隐藏共同参与事件；后者 controller opacity=0 仍保留子树。不能把整套 KSVideoPlayerView 再包进另一套 chrome，重做此前两轮失败。KSVideoPlayer 是可独立挂载的 renderer，detach 有代次保护；但使用共享字幕几何的 VideoSubtitleViewport 当前 private，直接替换会丢实际字幕层。下一批先建立同一字幕层的 renderer-only 入口，再由唯一应用控制层拥有遥控器/面板/隐藏；KS源轨用 decoder/SubtitleInfo 身份，不能套 JF 服务端索引。此处是已核源码归属与迁移边界，尚未实现文件控制统一。

播放批各自有Runner均已停；最后普通包未回退。第二最终Runner到时结束，事后原设置GET曾不可达；后续竞品批用新自有session恢复原三项并GET核实，不能追认前轮即时GET。最新竞品/手机状态归当前交接，不把后续活动混为本播放窗。完整实际听音、PGS和文件双入口仍开放。
