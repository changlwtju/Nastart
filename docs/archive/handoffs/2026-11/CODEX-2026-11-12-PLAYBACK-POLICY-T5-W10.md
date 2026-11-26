# 2026-11-12 T5 自动降档与服务端跳转补测

接续 [T5 接线与第一轮](CODEX-2026-11-12-PLAYBACK-POLICY-T5.md)。iPhone 13 `iPhone14,5` / iOS 16.3.1，USB 和原 Wi-Fi，fresh 设备身份、现装回执、500 个 iOS 输入、T5 签名包 `6beee7cb…` 和既有 WDA 核对通过。HEAD `8db1cc64`。App 仍为 14:24:48 签名 Debug，描述文件到 11-15 08:30:17。现装已确认，未重装。测试临时环境只在受控进程使用，未切网。

- W10 沿用此前相同的进程级 45 Mbps 交付上限、5 秒开始、70 秒时长。S19 内网 `95D13CBD` 原片，AC3 2 / PGS 9，内部起播 10,476 ms。音轨面板在降档前就绪。18:53:10.332 的 `automatic_downshift_requested reason=deliveryBelowSourceBitrate` 产生 20→10 Mbps 候选 `F9EF784B`。18:53:19.765 用户点选轨 3 后，该候选 `candidateInvalidated`，接着记录 `automatic_downshift_abandoned`。
- 手动 `2DB219B6 requestReason=sourceTrackSwitch audioStreamIndex=3 subtitleStreamIndex=9`，18:54:06.177 唯一相应的 `replacement_committed startsPaused=false`。W10 竞争顺序通过。新流走 `jellyfinOriginalDirectPlay` / KSPlayer，内部首帧 46,410 ms。其后另一次降档候选携带 `subtitleStreamIndex=none`，后续实图有画面及转圈，退回详情后为 DTS-HD 3 / 关闭字幕。留为切轨慢和字幕状态变化的证据，听音未核验。详情菜单改回 AC3 2 / 简体 PGS 9 后当时显示已恢复，冷重开仍选 DTS-HD 3 / 关闭字幕，随后在播放器内实际恢复，见下。
- 路线复算 `4 playback(s) with route evidence, 0 to check.`。原片、被放弃的降档候选、选轨和后续独立降档均保留。没有调参或改产品代码。私有证据入口 `/tmp/nastart-codex-w10-20261112-current`。

## W5 服务端跳转后选轨

- 重开同一签名 App，以 `NASTART_TEST_STARTUP_HLS_BPS=12000000` 进入 S19，WDA 创建会话请求返回超时，fresh 查询确认唯一现有会话和 Nastart PID 后接管，未重复发起。`BD5C4F12` 内网 `privateIP`、12 Mbps HLS。冷起播约 3 秒，在 AVPlayer 可本地跳转前发前进 15 秒。
- 19:00:46.513 `AF015ABC requestReason=serverSeek`，`startTimeTicks=71493162239 audioStreamIndex=3`。19:00:50.749 选轨 1，当时跳转仍在准备。19:01:00.834 第一次 `replacement_committed` 到 `candidateSeconds=7149.315 startsPaused=false`，随后 `24A3CD94 requestReason=sourceTrackSwitch audioStreamIndex=1 startTimeTicks=71493162239`，19:01:09.472 第二次 `replacement_committed`。W5 顺序通过。跳转候选内部首帧 14,627 ms，切轨候选 9,212 ms；实际听音和连续画面未测。路线复算 `3 playback(s) with route evidence, 0 to check.`。
- 播放中恢复原音字幕，先选 AC3 2，随后选 PGS 9。前一恢复候选在 `manifestPreparation` 退出；`CEA1B7AF` 以 `audioStreamIndex=2 subtitleStreamIndex=9 requestedServerSubtitleIndex=9` 准备，19:02:06.317 提交。19:02:22 核 App、Runner、8161 与采集归零。网络设置全程未改。W4/W7 继续使用冷起播分支取证。
