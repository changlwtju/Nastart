# S01 局域网 HLS 内容映射修复

日期：2026-09-06，接续 NEXT-CHAT-PLAYBACK，遵循 ADR 0002。

## 结论与边界

新架构 Jellyfin 的 H.264/AAC HLS 协商改用 TS 分段。S01/iPhone 13/LAN 的秒级内容落后已不再复现；前进、后退、切回 KS、第二次切入 HLS 及 30 秒连续播放取得新增证据。没有修改 UI 时间偏移、KS seek 或旧架构配置，也没有加入影片专用秒数补偿。

**不把完整 Q 或整套矩阵改为通过。** 第二次切换的动画重复帧存在约一至两帧的图像匹配歧义；尚不足以宣称每次切换都与源逐帧完全一致。音频听测/声画同步、音字幕完整往返、PiP、其它样本及其它设备仍待验收；只有 LAN 数据。

## 根因证据

通过已有授权在 LAN `/System/Logs` 和 `/System/Logs/Log` 读取实际转码日志，未修改 NAS 配置。Jellyfin 10.11.11 的本次 H.264 VAAPI fMP4 转码命令确实包含 `-ss ... -noaccurate_seek ... -copyts`，同参数 TS 转码没有 `-noaccurate_seek`。

用新的 PlaySessionId 分别从不同 index 启动，下载 init/分段，离线解码；从同一 LAN 原始流提取源帧，按灰度缩略图绝对误差匹配内容。以下时间不是仅拿 TS 绝对 PTS 作差：

| 分段类型 | 启动 index | 检查 index | 源内容相对清单时间 |
| --- | --- | --- | --- |
| fMP4 | 344 | 344、345 | 约落后 2.004 秒 |
| fMP4 | 351 | 351、352 | 约落后 1.637 秒 |
| fMP4 | 346 | 346、351 | 约落后 1.837 秒 |
| TS | 344 | 344、345 | 约超前 31 毫秒 |
| TS | 351 | 351、352 | 约超前 31 毫秒 |
| TS | 346 | 346、351 | 多数约超前 31 毫秒，重复动画帧有匹配歧义 |

每段检查首、中、尾帧。源名义帧率 29.97 fps，一帧约 33.367 ms；压缩和动画重复帧使最小图像误差并不等于唯一帧身份。fMP4 的内容起点随 seek 前关键帧变化，清单却按请求分段时间累计，说明固定秒数修补不成立。TS 自身约 10 秒复用 PTS 偏移被容器/播放器映射处理，不应手动减入 UI。

## 实现

`LaunchpadView.swift` 的 `playbackRequest` 新增默认 false 的 `usesGreenfieldPlayback`，由已选架构显式传入，并由画质、音字幕、server seek、码率回退闭包继承。协商前选择 profile 的 HLS segment container：新架构 `ts`，旧架构 `mp4`。该 profile 的输出仍是 H.264/AAC，不推广到 HEVC/其它编码器；保留认证 HLS proxy、播放会话及源音字幕索引传递。

`preflight.py` 更新原有 profile 调用检查，并检查上述架构分支。没有新增重复的播放器实现或重跑已经完成的 KS seek/ABI 问题矩阵。

## 真机证据

设备：iPhone 13 / iOS 16.3.1；NAS 192.0.2.2:8096；新构建已安装。

- HLS trace `171CE653` / plan `880DA78D`：proxy 日志确认 `pathExtension=ts`。
- 初始目标/raw clock 1054.580，AV output PTS 1054.553478。首次截图在 7 秒时仍是加载中，因此**不能用该截图验收**；稍后 paused preroll 才完成。
- 后退目标 1039.580，AV output PTS 1039.571867；稳定截图匹配源 1039.570/1039.603（动画相近帧），不再落后数秒。
- 前进回 1054.580，AV output PTS 1054.553478；截图最佳匹配源 1054.585（约 +5 ms）。切回 KS 最佳匹配同一源时间。
- 再由 KS 切入 HLS trace `C65B0333` / plan `84F83537`：目标约 1069.580，raw clock 1069.578333，AV output PTS 1069.568467。截图匹配源 1069.600/1069.633，无法据缩略图唯一判定重复帧，保留严格逐帧验收边界。
- 第二次 HLS 恢复播放后记录实际连续推进 30.000 秒 checkpoint；报告有 32 个 telemetry 样本、一次启动 waiting、accessLogStalls=0、failureStages 为空。播放后画面匹配源约 1104.301，证明内容推进；不是仅看时钟。
- 全程暂停意图保留。报告里的 playbackClock 首帧时间包含人为暂停，不能当作本轮 renderer 首帧延迟；未知 compositor latency 仍未知。

## 构建和清理

- `build-clean-reference-probe.log` / `install-clean-reference-probe.log`：先完成移除临时 URL 导出探针的清理安装。
- `build-hls-content-fix.log` / `install-hls-content-fix.log`：本轮最终候选修复构建安装成功。
- `verify_playback_linkage.py` 通过，`preflight-hls-content-fix.log` 通过，`git diff --check` 通过。没有重跑未受改动影响的 trace-report 三个回归或全量 XCTest。
- 设备两个精确缓存文件 `/Library/Caches/playback-reference.json`、`/Library/Caches/hls-reference.json` 已删除；不卸载 App、不清空其它数据。
- Package.resolved 按 HEAD 原字节恢复；IDE 会再次删除，结束前复核。

## 私有证据索引

以下均在 `tmp/playback-20260905/`，不入 Git；带 `private-` 的日志可能含源路径、凭据，不得直接输出。

- `private-transcode-{2,3,5,7}.log`：本次及历史实际转码命令。
- `probe-content-mapping.py`、`probe-start346-mapping.py`；`content-mapping-results.json`、`content-mapping-start346.json`：分段内容匹配。
- `mapping-{mp4,ts}-*.{mp4,ts}`：离线分段。
- `match-device-content.py`、`match-device-second.py`；`device-content-match.json`、`device-content-second-match.json`：源流帧与 iPhone 稳定截图匹配。第二脚本会覆盖首脚本的源灰度临时文件，按相应脚本重新生成即可。
- `content-fix-*.png/xml`：KS、HLS 初始加载、稳定 seek、第二次切换、连续播放截图。`content-fix-av.png` 是未完成加载的截图，**不可当成功证据**。
- `content-fix-final-export.log` / `content-fix-final-report.json`：真机日志与报告。

下一步先补齐 S01 的声画同步/音字幕/PiP 等剩余基本功能验收；严格逐帧 Q 如需关闭，应选有唯一帧身份的动态源或采集解码输出内容证据，不能依赖动画重复帧的单一最佳缩略图匹配。不要再重复定位此处已证实的 fMP4 关键帧前滚机制。
