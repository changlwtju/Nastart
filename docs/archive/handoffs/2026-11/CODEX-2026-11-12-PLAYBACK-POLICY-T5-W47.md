# 2026-11-12 T5 冷起播换源补测

接续 [W5 与 W10](CODEX-2026-11-12-PLAYBACK-POLICY-T5-W10.md)。iPhone 13 USB、原 Wi-Fi。19:03:47 fresh 核对 iPhone14,5 / iOS 16.3.1、安装回执、500 个 iOS 输入和签名 Debug `6beee7cb…`。HEAD `8db1cc64`，App 构建于 14:24:48，描述文件到 11-15 08:30:17。复用现有签名 WDA 和 8161。未重装、切网或修改产品代码。

## W4 先选轨再服务端跳转

- S19 进程临时设 `NASTART_TEST_STARTUP_HLS_BPS=12000000`。`42381E1D` 内网 `privateIP`、12 Mbps HLS，起点 7224.001182 秒，恢复轨 2 / PGS 9。19:05:30.073 切轨 1 产生 `FBF0D654`，`startTimeTicks=72240011820`。
- 19:05:32.64 冷起播时点前进 15 秒。首个选轨候选 `candidateInvalidated`，原 `42381E1D` 在原位暂停，无本地 `seek_started`。随后唯一替换目标 `B369654C requestReason=sourceTrackSwitch audioStreamIndex=1 subtitleStreamIndex=9 startTimeTicks=72390011820`，同时携带新音轨和跳转目标。19:05:46 只提交一次，`candidateSeconds=7239.0 startsPaused=false`，实际画面可见。W4 合并和提交通过，路线复算 `3 playback(s) with route evidence, 0 to check.`。
- 首次退出尝试未匹配到隐藏的「完成」控件，未发点击，保留 XML/PNG。重新显示控制栏后继续。未独立核验实际听音。

## W7 用户暂停时合并

- 重开时第一次 WDA 点 Jellyfin 唤出上下文菜单，未选择菜单项。退出菜单并重进。首轮 W7 的音轨按钮未在限定时间内出现，未发选轨和跳转，保留失败 XML/PNG 和快照。退出该播放后，以同一 HLS 环境重试。
- `CBF2C6F9` 内网 12 Mbps HLS、轨 1 / PGS 9，起点 7401.5001697 秒。19:11:29.175 原流有 `paused` 和 `control_action action=pause`。19:11:33.239 准备轨 2 候选 `41F7D257`，随后前进 15 秒，`E950BAC9` 仍选轨 2 / PGS 9，`startTimeTicks=74165001697`。19:11:52.046 只提交一次，`candidateSeconds=7416.5 startsPaused=true`。W7 暂停态保持通过。路线复算 `3 playback(s) with route evidence, 0 to check.`。

## W6 换集加载中的旧集控件

- 同一个内网 12 Mbps HLS 进程打开《冰与火之歌》S1E1「凛冬将至」`5550BF50`。点「下一集」前旧集 Slider `enabled=true`。候选 `AD4FA8B0` 在 19:13:42.348 开始准备。19:13:43.804 仍可见旧集标题，Slider 变为 `enabled=false`。对该进度条发触摸并即时保存。19:13:48.023 仍为旧集，字幕菜单中轨 2 为已选，「关闭字幕」未选；触摸「关闭字幕」并即时保存。两次输入的快照写入均早于 19:13:52.042 的候选提交。
- 从下一集准备到提交没有新 `sourceTrackSwitch`、`serverSeek` 或引擎 `seek_started`。下一集 `AD4FA8B0` 仍选 `audioStreamIndex=1 subtitleStreamIndex=2 requestedServerSubtitleIndex=2`，仅一次 `replacement_committed startsPaused=false`，内部首帧 10,171 ms，结果图实际出画。旧集跳转、字幕输入保护通过。此前 iPad 已验证连续点下一集只准备一次。合并窗口路线脚本 `9 playback(s) with route evidence, 0 to check.`。
- 19:14:50 有界窗口退出。App、Runner、8161 与采集核为零，网络设置未改。该窗结束前未另开空环境确认 S19 重开音字幕，继续以正常启动单独核验。私有证据入口 `/tmp/nastart-codex-w47-20261112-current`。
