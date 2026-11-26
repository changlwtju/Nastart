# 2026-11-12 播放策略 T4 结论与 T5 接线前复核

按[总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md)完成 T4，并复核第七节第 3 项。HEAD `8db1cc64`，本批开始时 139 个变更路径。本批仅查已有诊断和更新交接，无新真机窗口、构建、参数调整或产品代码变更。引用的 T2 窗使用 [T0 签名 Debug](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)，dylib `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`。iPhone 13 的既有窗口 13:36–13:43、13:46–13:50，设备核对和原 Wi-Fi 恢复见各窗记录。

## T4 样本不足，系数保持 3.0

- 复查 13 份 T2 App 控制台导出，`originalVerdict=explore` 的两条记录同属 `6E7E223A`，计作一次起播。S19 在 4G 恢复 16 条样本，`renditionLowerBound=33616603`，原片内部首帧 6,645 ms，约 8 秒触发 `automatic_downshift_requested`，随后实际提交 10 Mbps HLS。只有这一部影片和一个同窗信号条件，未达到至少五次且覆盖不止一部影片或一种信号条件的门槛。[4G 续测](CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-PLAY.md)
- 两个最近 T2 窗沿用当场 `playback_route_decision_report.py` 输出，`4 playback(s) with route evidence, 0 to check.` 和 `1 playback(s) with route evidence, 0 to check.`。设备文件 V10 另按 `preview_stream_started` 的探测和档位复核，10 Mbps 与规则一致，24 秒实图为黑。反复冷起播偏慢已按总交接第八节交回。V8 的严格重启配对及 HLS 换音轨时序仍待取证。[V7/V10](CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-V7-V10.md)

## T5 已有证据

按事件日期、键名及详情去重，11 月 10 日历史 iPhone 13 导出有 8 次 `sourceTrackSwitch`、0 次 `serverSeek`，11 月 9 日另一批有 3 次 `sourceTrackSwitch`、0 次 `serverSeek`。T2 的 `420FD6C8` 两次是引擎跳转。核对提交时用旧流 `playbackTraceID` 与候选准备记录关联，候选自行失败不计作重叠。历史包仅提供复现线索，W1–W10 均待接线后用新包验证。

| 总交接问题 | 导出复核 |
| --- | --- |
| 1 选轨被服务端跳转丢掉 | 缺 `serverSeek` 签名。历史出现了引擎跳转重叠：PGS 9 候选 `3FF43771` 开始约 3.5 秒后，旧流 `73CE673F` 有 `seek_started`、`replacement_warmup_failed stage=candidateInvalidated`，随后在 528.752 秒引擎完成，未见该候选提交。稍后包的 PGS 9 候选再次被引擎跳转打断，`source_track_retry_after_seek` 后 `8DC7691B` 在 602.531 秒准备并提交。优先验证 W8 以及使用服务端跳转的 W4。 |
| 2 跳转被选轨丢掉 | 缺 `serverSeek` 候选，无法比较两次 `playback_prepared.startTimeTicks` 及第一候选的提交。留 W5。 |
| 3 同一集加载两次 | 导出中的 `initialPlayback` 未找到能关联到同一播放器内同一集重复请求的组合。留 W6。 |
| 4 两次暂停式替换之间旧流恢复后又暂停 | 未找到两个连续的暂停式候选及其间旧流的 `paused`。留 W5/W6 观察旧流时钟。 |
| 5 切轨时暂停，服务端跳转后自动播放 | 缺带用户暂停的 `serverSeek` 和相应提交。T2 的 `startsPaused=false` 属于自动降档。留 W7。 |
| 6 换到同一条流 | 11 月 9 日两次可完整关联的 HLS 提交，`417B83CB` → `EFE23228` 的音轨为 1 → 2，`EFE23228` → `578ED8D1` 的字幕为 9 → `none`、服务端字幕为 9 → -1。两次均有实际变化。其余缺完整三字段的候选不作等同判断。留 W3。 |

私有原始诊断位于 `DebugEvidence/claude-s19-proxy-timing-20261110/phone/` 的 `jellyfin-bookmark-closed-preferences-private.plist`、`ct-sub-preferences-private.plist` 等诊断快照，以及 `/tmp/nastart-jellyfin13-hls-current` 指向的 `phone/`。本批只取其中播放诊断字段。[11 月 10 日实测](CLAUDE-2026-11-10-S19-PROXY-READER-TIMING.md) · [11 月 9 日实测](CODEX-2026-11-09-IPHONE13-HLS-REPLACEMENT-REGRESSION.md)

## 接续条件

总交接第九节第 5 项待用户确认。换集已开始加载时，是否忽略对旧一集的选轨和跳转，并继续加载下一集。确认后单独接线，优先核 W4、W8，再核 W5、W6、W7 的变化及 W3 取消，补完 W1、W2、W9、W10。每步即时导出。W6 另核对加载中对旧一集的操作。相同场景连续两轮失败时按总交接撤回视图接线并保留证据。T6 可选脚本未启动。[状态机接线与回归表](CLAUDE-2026-11-11-SOURCE-CHANGE-STATE-MACHINE.md)
