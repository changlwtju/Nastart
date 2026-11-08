# ASS→PGS保存的离线边界审查

2026-10-22。复核[15:39历史包竖屏批次](2026-10-21-PORTRAIT-VISIBLE-PANEL.md)的原始日志、动作与完整磁盘快照，对照当前源码；零设备请求/媒体/新App源码/构建/安装/重复测试。[安全提取结果](../../../testing/results/2026-10/2026-10-22-track-save-offline-boundary.json)。原始证据仍在`/tmp/nastart-portrait-panel-evidence`指向的私有目录。当前最新包仍19:52，与这些历史窗口分开。

## 新核对结果

失败窗16:30:53.468819切回PGS触发seek，16:30:53.747210确认completed=true；正常关闭派发16:30:56.529985，即完成后2.782775秒，16:30:57.431957 playback_ended。关闭前日志还显示pendingSeek=false、播放时钟继续推进。因此“此窗退出时seek从未完成/仍由这个pending请求阻止保存”不能作为充分解释。旧磁盘仍subtitleTrackID=5、updatedAt在切回之前的失败保留，不重新写为成功。

成功边界窗16:48:00.775113 seek开始、16:48:01.395396完成，正常关闭派发16:48:08.724738（完成后7.329342秒）。该窗PGS活跃/正常关闭3秒/10秒及停止后磁盘均7，但ASS活跃快照仍为选择前PGS，无法证明它已先存ASS。两窗不只是单一等待变量，不能据此规定“等8秒即可修复”。

## 实际源码边界与缺口

- [GreenfieldVideoPlayerView](../../../../ios/Nastart/Nastart/Playback/GreenfieldVideoPlayerView.swift)的saveLocalProgress在clock变化时至多每2秒调用，closePlayer/onDisappear/原生生命周期另有force；force跳过频率限制，但仍要求非directURL、localResumeKey及canPersistResumeProgress，不是无条件写入。当前没有保存成功/跳过原因和同key内存entry的边界证据。
- [GreenfieldKSPlayerRenderer](../../../../ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift)的canPersistResumeProgress要求ready、无pending seek/暂停预览、初始resume时钟已到达。PGS刷新走正常seek；completed=true会清pendingSeekPosition，但暂停预览等其他状态不能仅凭一条completed日志假定。当前选轨、外置URL与sourceRuntime字段需要同一时刻快照，不能只读菜单。
- persistLocalProgress按runtime的外置URL精确反查源字幕，或源索引/ordinal推导后调用[LocalPlaybackResumeStore](../../../../ios/Nastart/Nastart/Playback/GreenfieldPlaybackBridge.swift)。store在锁内读取/更新/编码并defaults.set，解锁后才通知UI；这证明源码调用顺序，不提供iOS磁盘完成确认。外部HouseArrest plist、同进程defaults.data/entry和下一进程冷读是三种证据，不能互相替代。

现有PlaybackNextCoreTests已有sidecar→bitmap状态、已确认时钟/seek禁止覆盖书签、重复选轨与LocalResume读回等反例；本批未重跑或声称它们属于19:52的136项NonPlaybackPolicyTests范围。重复测试这些规则不能补上历史窗没有的内存事实。

后续最小可辨别证据应在一次真实保存边界同时记录不含key/URL/凭据的：调用原因、返回/跳过门槛、当前engine/完整归属校验结果、选轨推导结果、写入后同key内存entry是否一致；再与正常完成后的外部磁盘/冷读比较。仍保持原进度保护、已确认选择和账号/文件隔离，不先添加synchronize、频繁同步写盘、额外等待或直接覆盖用户偏好。没有此证据前保留“未提交或磁盘暂不可见”未知，不继续同条件媒体等待试验。

本批仅否定一个过宽解释并明确取证边界，不算保存修复或字幕/PiP整项验收。13现场已由[本地清单批次](2026-10-22-LOCAL-MEDIA-PLAYLIST-BOUNDARY.md)正常收尾；Pad/18未触碰，28项开放不变。
