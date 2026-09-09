# 2026-09-09 大视频清晰度切换与拖动验证

## 样本与环境

- iPhone 13，iOS 16.3.1；真机 Debug 包，Greenfield 新架构。
- 局域网 Jellyfin/NAS：《碟中谍3》，54,005,939,750 bytes（54.0 GB），7524.768 秒，4K HEVC HDR / TrueHD / ASS，源码率约 62.7 Mbps。
- 早期仅 LAN，用户后续明确授权域名/公网路径验证；凭据与带认证的服务端日志仅保存在忽略的 tmp 目录。

## 修改

- 清晰度切换先在静音候选播放器准备并核对解码帧与原播放器时间，原播放器持续播放，准备失败保留旧流。成功时直接接管已准备的播放器，避免重建后重新缓冲。
- AVPlayer 先排队定位，再等待播放器 ready，避免 iOS 16 定位回调早于 ready 时调用 preroll 崩溃。以解码帧代替完整 preroll 完成作为交接条件；预估准备时间并在后台追赶。
- AVPlayer 切换复用播放界面；字幕 URL 变化时更新覆盖字幕。KSPlayer 控制器明确绑定到自己的适配器，旧界面消失时仅清理自身 plan，避免交接后快进/回退失效。
- Greenfield TS HLS 使用一秒分片、一个分片即可启动；1080p/720p/480p 请求同时限制编码尺寸。可外置的文字字幕不强制烧录；图形字幕保持原策略。旧架构的两分片启动策略保留。
- 拖动位置保存在独立进度条视图，松手提交一次；定位未完成时不让旧播放时钟覆盖目标位置。解码队列清理与音频暂停/启动移出手势主线程；完成回调按定位代次过滤。未连接播放器时不接受虚假的 seek。

## 真机结果

以下为单机局域网测量，非性能承诺。清晰度耗时从 replacement_warmup_started 到 replacement_committed；定位恢复为引擎完成并回报目标时钟，并非屏幕光学测量。

| 操作 | 结果 |
| --- | --- |
| 旧的重复 seek/preroll 方案，原画 → 1080p | 约 15.7 秒 |
| 后续实测，原画 → 1080p 20 Mbps | 4.170 秒；首帧准备 3.452 秒；交接时钟差 96 ms |
| 当前方案早期参数，1080p 20 → 12 Mbps | 5.999 秒；交接时钟差 94 ms |
| 1080p → 原画 | 2.676 秒；解码预览与旧时钟差 16 ms |
| HLS 快进 15 秒 / 回退 15 秒 | 151 / 172 ms；主线程提交 0.027 / 0.032 ms |
| 原画拖动到约 1283 / 5221 / 2400 秒 | 282 / 63 / 212 ms；主线程 0.537 / 0.033 / 0.078 ms |

原画拖动跨越数十分钟，逐次截图检查播放恢复。HLS 的交接和交接后定位均额外记录 AVPlayerItemVideoOutput 的 PTS；该输出证明解码帧可用，不等同于屏幕实际呈现时间。持续播放日志中未出现缓冲停顿的样本时间窗须结合对应 trace 核对。

## 验证与证据

- PlaybackNextCoreTests：最终新增至 21 项，tests-public-policy.log 全部通过；覆盖目标进度保持、失败/换会话清理、未连接拒绝定位、编码尺寸，以及 AVAssetWriter 生成真实视频后的 AV/KS 暂停和移动时钟交接。
- 真机编译、模拟器测试、preflight 和 FFmpeg/KSPlayer/VLC 链接隔离检查均通过；最终 Debug 包已覆盖安装至连接的 iPhone，未卸载应用。
- 本机忽略的证据：tmp/playback-20260909/{frame-gate-live.log,predicted-metrics.log,final-metrics.log,direct-metrics.log,direct-drags.log,tests-final.log,build-final.log,preflight.log}；截图与导出的诊断位于 tmp/playback-20260908。

## 边界

冷启动 NAS 转码仍需数秒准备，重复测试中观察到约 4–11 秒波动；本次解决了重复缓冲与 UI/控制器阻塞，不能把所有清晰度切换称为瞬间完成。测试覆盖同一大视频样本的 LAN 与公网域名/IPv6 路径；未推断蜂窝、弱网、所有字幕和设备表现。Greenfield 原有 Debug 入口范围保持不变。

## 用户追加反馈后的修复

用户要求检查清晰度切换后的其他功能，并反馈切换音轨导致双重字幕。

- 根因：共同覆盖层已选择外置文字字幕时，音轨切换回调又启用了相同的内嵌字幕。直接音轨切换和初次接管统一遵循外置/内嵌互斥选择，并保留源音轨、字幕选择状态。
- 补充了放弃预热和正常停止时的精确转码会话释放。未真正开始播放的预热只释放编码资源，不上报虚假的播放位置；释放幂等。
- 播放中的 HLS 候选使用静音立即解码，暂停候选仍使用 preroll；就绪和实际解码帧检查保留。
- 外置字幕的网络读取改为异步 URLSession，并记录解析条数；补充真实 SRT 中英双语/ASS 样式清理、切换后保留和关闭测试。

真机连续操作日志：immediate-validation.log，原画 → 1080p 20 → 1080p 12 → 暂停切回原画，包含清晰度选中项核对、快进/回退、暂停保持。该轮 15 秒快进/回退分别 174/147 ms。仍需结合字幕屏幕证据核对，不把无字幕画面算作双字幕问题已验证。

## 域名与公网 IPv6 路径

用户后续将 NAS 配置为域名＋端口，授权在内网与外网访问方式下优化。

- 验证域名的真实 A/AAAA；Mac 系统 DNS 受代理影响返回虚拟地址，因此地址验证使用同一域名/SNI和真实 AAAA，未关闭证书验证。DSM 5001、Jellyfin HTTPS 8097 均成功连接。
- 54 GB 同一影片偏移 0 / 27,000,000,000 / 53,000,000,000 分别读取 256 KiB。LAN 和公网 IPv6 各三次均 206、长度正确。IPv6 TTFB 54.23 / 68.34 / 54.46 ms；总 87.95 / 91.05 / 87.38 ms。仅证明地址路径与随机读取，不代表蜂窝网络吞吐。
- 手机实际连接日志有 utun5 / 127.0.0.1:1082 代理，Wi-Fi 在用。因此手机测试记作公网域名＋代理，不能标成纯 IPv6 或蜂窝外网。
- 修复本地代理把公网流误判为 LAN：保留 renderer 的 loopback URL，但网络策略/诊断使用真实 upstream 域名/IPv6及端口；显式非私网标记不再被 loopback 覆盖。
- 正常证书的代理请求复用 URLSession/TCP/TLS，每任务独立 delegate；无共享 cookie/credential storage；完成只取消自身任务。自签名证书仍使用原独立校验会话。
- 新增真实本地 HTTP Range 服务集成测试：两次独立代理请求均流式返回正确 206/内容，服务端只建立一条连接。新增公网域名/IPv6 经 loopback 仍保留非 LAN 策略测试。
- 最新证据：network-address-validation.json、tests-public-policy.log、build-public-policy.log、install-public-policy.log、domain-final-live.log。

18:42 最新包真机连接指标已确认：publicDomain / networkClass=unknown（不再错误标记 local），URLSession 的 remoteAddress 为 NAS 公网 IPv6，protocol=h2，cellular=no。主播放列表首次 TCP 16 ms / TLS 13 ms，下一播放列表 connectionReused=yes、TCP/TLS 无重复建立。之前观察到的 VPN/代理接口应按各轮日志分别解释，不能把所有轮次混为同一网络路径。


## 域名首次播放无声、画中画及切换后状态

- 首次 AVPlayer 播放未初始化 AVAudioSession，而 LAN 先启动 KSPlayer 时会间接初始化。18:42 日志明确出现 `AVAudioSession indicates PIP is unavailable for this audio session`。入口统一设置 playback/moviePlayback/longFormVideo 并激活；18:53 真机确认 Speaker 路由，用户最终明确反馈“有声音了”。不能将更早的“仍然无声”回复算作通过。
- 清晰度切换会 disconnect 控件，但复用的 AVPlayerSurface 不再调用 makeUIView，导致画中画按钮失去回调。updateUIView 重新绑定当前 controller；屏幕与系统日志均验证多次切换后 PiP 可启动。
- HLS 定位后按最新播放意图恢复播放或保持暂停；旧播放器 timeControl KVO 不得污染新播放器。真实视频回归覆盖播放/暂停定位。
- 19:02 域名路径连续快进/回退恢复 153/188/181/162 ms，后续 `playbackTick` 均 rate=1、playing。自动化曾因控件自动隐藏误报暂停，随后以持续播放时钟与可见控件交叉复核；保留失败记录，不删除证据。
- 画中画第一次、清晰度切换后、返回主屏幕的连续截图均已检查。19:09 主屏幕可见 app 图标及系统悬浮视频，后台时钟继续推进；小窗无需只局限于 Nastart 内。应用不会用私有 API 强制退出到桌面。

## 减少片头无用转码

- 服务端日志确认 18:53 首先启动片头转码，随后才启动约 1:23 的续播转码，首次时钟推进耗时 11.459 秒。
- 给 Greenfield 本地 HLS 代理的完整、从零开始的 VOD 媒体列表加 `EXT-X-START:TIME-OFFSET=...,PRECISE=YES`，在创建 AVPlayerItem 前指定实际起点。候选预热设置其预测起点；master/live/sliding、非法或超范围偏移保持不变。
- 使用真实 HTTP fixture 验证经代理后的标签及子 URL 重写。19:00 服务器只记录一条带正确 `-ss` 的转码启动，首次时钟推进 7.118 秒。
- 该轮 20→12 Mbps 预热约 6.9 秒、12→20 约 6.55 秒，首帧分别 5.251/5.833 秒。前景旧流继续播放；仍未达到瞬时清晰度切换。远距离跳转到未缓存转码位置的样本约 3.53 秒，不能用缓冲内的 0.2 秒结果代替。
- `tests-vod-start.log` 24 项通过；build/install/preflight-vod-start 及链接隔离检查通过。后续原画兼容修复另见最新日志，不能把不同安装版本混为同一轮。

参考：音频会话配置按 [Apple 媒体播放配置](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)；VOD 起点标签按 [RFC 8216 §4.3.5.2](https://www.rfc-editor.org/rfc/rfc8216.html#section-4.3.5.2)。


## 原画真实性与有字幕画面回归

- 原画曾因沿用 MobileVLCKit 的 TrueHD 音频限制而仍返回 20 Mbps HLS，却显示原画选中。显式 Greenfield 原画现在查询已链接 KSPlayer/FFmpeg 的实际音频解码器；未知/视频解码器不可用于音频放行，自动网络策略和旧架构保持原范围。
- 19:13 域名真机确认 KSPlayer 接管原始 HEVC/TrueHD 文件，候选从打开到交接约 3.7 秒，选择原画到脚本观察交接约 5.2 秒；片源音轨 id=1 选中。
- 19:14 在 2584.982 秒（43:04）实际对白处，截图确认从 TrueHD 切到国语 AC3 前后均只有一组中英字幕。关闭字幕后相同画面无字幕，重新选择恢复；播放中切到英语 AC3，43:06 截图仍只有同一组字幕。两行中英是片源双语字幕，不是双重渲染。
- 证据：tmp/playback-20260908/subtitle-exact-{cue,after-audio}.png、subtitle-{off-clean,restored-clean,playing-audio-switch}.png。截图原始方向为 portrait 像素、内容为横屏，未修图。
- 原画下也验证了系统 PiP 返回主屏幕，截图 original-pip-home.png。
- 最新 tests-original-codec.log：25 项通过；build-original-codec、install-original-codec、preflight-original-codec 完成，KSPlayer/FFmpeg 与 VLC 链接隔离通过。最新真机进程 67797；功能/播放时钟证据仍在 domain-final-live.log 中，按进程与 trace 区分不同安装版本。

19:16 补充：原画从桌面 PiP 恢复全屏后，系统 didStop 回调完成；等待转场结束后检查 original-pip-restored-settled.png，播放继续。final-test-summary.json 确認 25 passed / 0 failed / 0 skipped。
