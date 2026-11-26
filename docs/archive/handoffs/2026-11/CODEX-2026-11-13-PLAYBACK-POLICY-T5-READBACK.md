# 2026-11-13 T5 换源回归结论

iPhone 13（iPhone14,5 / iOS 16.3.1）USB 控制，沿用原 Wi-Fi，设备独占。HEAD `8db1cc64`，开窗时工作区 144 个未提交路径。签名 Debug 构建于 2026-11-12 14:24:48，500 个冻结 iOS 构建输入逐项一致，包内 Debug dylib SHA-256 `6beee7cbe77e5b842112351366bdcf80de007527e6004e0ae32107b31a2c533e`，主程序 `a46a22ee13e75d357a82592c0ad933784ac3e36cc527a8e32a1ebd5a1df5d1f6`，签名描述文件有效至 11-15 08:30:17（北京时间）。iPhone 13 已装 App 路径及可用安装字段与 11-12 保留数据安装一致，复用现装 Runner，未重装。本轮只操作 iPhone 13。

## W1–W10 行为核对

- W1/W2/W3/W9 分别有单次提交、最后一次选轨提交、回原轨取消和原流接管小窗的真机证据。iPhone 13 受控 12 Mbps HLS 窗复算 `6 playback(s) with route evidence, 0 to check.`。iPad W8 本地跳转后重试提交并出画，所在窗复算 8 条、0 不符。 [基础回归](CODEX-2026-11-12-PLAYBACK-POLICY-T5.md)
- W4 合并服务端跳转与选轨后单次提交，W5 先提交服务端跳转再提交选轨，W7 在用户暂停时合并并以 `startsPaused=true` 提交。三个子窗各复算 3 条、0 不符。 [W4/W7](CODEX-2026-11-12-PLAYBACK-POLICY-T5-W47.md) · [W5](CODEX-2026-11-12-PLAYBACK-POLICY-T5-W10.md)
- W6 有两台设备的互补证据。iPad 反复点下一集只准备和提交一次，复算 2 条、0 不符。iPhone 13 下集 `AD4FA8B0` 加载时旧集进度条已禁用，实际触摸旧进度条及「关闭字幕」后无新 `serverSeek`、`seek_started` 或 `sourceTrackSwitch`，下一集保持轨 1 / PGS 2 并单次提交出画。W4/W7/W6 合并窗复算 9 条、0 不符。 [W6 旧输入证据](CODEX-2026-11-12-PLAYBACK-POLICY-T5-W47.md)
- W10 实际在自动降档候选 `F9EF784B` 加载中选择轨 3，原候选 `candidateInvalidated` 后记录 `automatic_downshift_abandoned`，选轨 `2DB219B6` 只提交一次并出画。顺序通过，复算 4 条、0 不符。 [W10 现场](CODEX-2026-11-12-PLAYBACK-POLICY-T5-W10.md)

## W10 未通过体验验收

- iPhone 13 原 Wi-Fi，S19 在进程级受控 45 Mbps 限速（延迟 5 秒，持续 70 秒）。手动切轨 `2DB219B6` 的内部首帧 46.410 秒。18:53:19.811 启动 KSPlayer 候选，18:53:58.594 才有 `replacement_candidate_opened preview=7118.194`，耗时 38.783 秒。18:53:59.585 `replacement_candidate_seek_completed target=7125.673 completed=true`，18:54:06.176 对齐，随后提交。日志能定位等待主要发生在第一份候选预览前，无法分配到具体读取或解码阶段。
- 手动候选准备仍为 `subtitleStreamIndex=9`，提交时 `audio_session_ready mediaSubtitleDisabled=false mediaSubtitleID=9 requestSubtitleID=9 requestSubtitleMode=embedded`，实际轨道状态记录 `subtitle_track_changed requestedTrackID=9`，该时刻字幕是否可见未核。随后的独立降档 `64F8AC9C` 准备阶段已为 `subtitleStreamIndex=none requestedServerSubtitleIndex=-1`，18:54:33.888 接管后详情显示「关闭字幕」。证据将字幕丢失定位到这次降档的请求阶段。原片降档加载器会按运行时字幕快照决定是否保留选择，本次缺少同窗快照以确认具体分支。结束前在播放器内把 AC3 2 / PGS 9 恢复，`CEA1B7AF` 实际提交。之后 W7 仍记录轨 2 / 9。
- W10 私有原始证据入口 `/tmp/nastart-codex-w10-20261112-current`，含 `w10-final-entries.json`、`w10-result-entries.json` 和逐动作取证。W6 私有入口 `/tmp/nastart-codex-w47-20261112-current`。设备偏好、端点和原图仅留在本机证据目录。

## 原 Wi-Fi 正常续播回读

- 00:35:21–00:36:02 首窗 WDA 建会话超时。原生截图随后确认 Nastart 首页及 Wi-Fi 图标，按已装可执行路径和本轮启动时间认领超时留下的 App，保存诊断及偏好后于 00:38:59 精确结束。00:39:31–00:40:13 次窗原生空参数、空环境启动成功并附加 WDA，启动台 Jellyfin 卡片触控出现「从启动页隐藏」菜单，未选菜单项、未发播放，保存现场后释放。
- 00:41:34–00:44:03 复测沿用原生正常启动再附加 WDA。按当前卡片内的标签区域短触后，Jellyfin 库和 S19 详情正常打开。点击续播前，详情为 English compatibility track（Dolby Digital 5.1）及简体中文字幕（PGSSUB）。`6606E93A` 从 7416.500 秒以 `verifiedSameServerLAN selectedAddressKind=privateIP mode=jellyfinOriginalDirectPlay transport=localRangeProxy` 续播，`audioStreamIndex=2 subtitleStreamIndex=9`，`first_frame tapToFirstFrameMs=4343`。第 10 秒图有画面，第 30 秒图可见简体中文字幕，`audio_track_changed engineTrackID=2`、`audio_session_ready outputs=Speaker`。现场听音待核。
- 约 28 秒时正常窗口也触发自动降档，`0BC11D9F mode=serverNegotiatedHLS fromBitrate=20000000 toBitrate=12000000 audioStreamIndex=2 subtitleStreamIndex=9 requestedServerSubtitleIndex=9`，本次降档请求保留字幕。00:43:44 点「完成」，候选在清单准备阶段记录 `cancelled=true`，未接管。回详情后仍显示同一音轨和字幕。复算 `2 playback(s) with route evidence, 0 to check.`。
- 网络设置未改，结束截图有原 Wi-Fi 图标及系统主屏幕。00:44:03 确认 App、Runner、8161 和采集已停止。私有证据入口 `/tmp/nastart-codex-t5-normal-tap-20261113-current`，前两次取证入口分别为 `/tmp/nastart-codex-t5-normal-20261113-current` 和 `/tmp/nastart-codex-t5-normal-attach-20261113-current`。

## 范围

本轮无产品代码或参数变更。T5 实现批的模拟器结果为 694 通过、2 跳过、1 个已知基线 Range 失败，预检输出逐行相同。W1–W10 的换源协调行为有证据，W10 切轨耗时和字幕保持单独保留，实际扬声器听音仍待现场确认。T2 既有冷起播慢或黑屏、严格配对 V8 和 HLS 音轨时序仍留在原交接。T4 保持 3.0，未开展可选 T6。
