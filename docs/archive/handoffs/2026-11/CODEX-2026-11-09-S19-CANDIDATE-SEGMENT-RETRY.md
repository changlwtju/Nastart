# 2026-11-09 HLS 候选首段重试复用

源码：`main/8db1cc64` 加当前未提交改动；既有 dirty 改动保留。只在空白 iOS 27 模拟器用 Debug、可解码合成片源和本机 HTTP 源站验证；未读 NAS、未启动或更新 13/iPad/18、没有正式包验收。

`GreenfieldAVPlayerWarmup.prepare` 只在 Debug 显式设置 `NASTART_CANDIDATE_SEGMENT_RETRY_PROBE=1` 后，在清单准备完成时尝试开启。`PlaybackVODPlaylistCache` 提供已缓存的完整 VOD 清单和实际地址。`AuthenticatedMediaStreamProxy` 只允许同路由、同源、已登记的无加密 TS 清单的首个合格完整 GET，重试须匹配同一个分段 URL 和 `X-Playback-Session-Id`。单探针最多四个下游、4 MiB、6 秒；已校验完整的 HTTP 200 才交付，不留完成缓存。Range、条件/认证请求头和允许自签证书的 HTTPS 不纳入；非同一播放会话走原路径。不接受重定向、Vary、Set-Cookie、编码或部分响应。校验或等待读取失败回到原有传输，路由撤销/候选结束取消；下游复位不影响其他读端。默认/Release 行为不变。

最终七项定向通过。含关闭与开启配对的真实 AVPlayer 固定时钟候选窗，以及清单、共享、断开、不同 Range/会话/路由、撤销和响应回退。两窗首段正文延迟同为 2.4 秒，后段正常。关闭：首段 6 次上游 GET，12 秒未解码。开启：AVPlayer 的第二个读端加入进行中的读取，首段 1 次上游 GET，交付 1,058,816 字节，2.493 秒解码，2.516 秒对齐至 4 秒。此前开启窗也达到 2.602 秒；首个严格请求头试验没有覆盖 AVPlayer 的会话头，保留失败。测试直接调用租约，与默认关闭的界面启动路径分开；没有采纳候选、真实屏幕/音轨/字幕或大文件弱网性能结论。

本机源站停止、临时实解码测试源码恢复、专用模拟器删除，常驻定向回归保留。下轮先用明确签名的同源 Debug 包核 13/iPad 的同片对照，再考虑是否改变默认。 [结构化结果](../../../testing/results/2026-11/CODEX-S19-CANDIDATE-SEGMENT-RETRY-20261109.json)
