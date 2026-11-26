# 2026-11-12 播放策略 T2 · 4G 中码率与设备文件

- 13:46–13:50，iPhone 13（iPhone14,5 / iOS 16.3.1 / USB）。fresh 核设备、现装 App 和 Runner。普通签名 Debug 同 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)，dylib `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。HEAD `8db1cc64`，499 个 iOS 输入逐项一致。两次正常冷启动。原 Wi-Fi 勾选与图标实证之后切换到 4G。该位置先前由用户报告蜂窝偏弱，本窗未测 RSRP、RSRQ、SINR。公网会话正常，未重新登录。

## V7 《杀死比尔》2003

- Trace `69E7F11D`，从头。当前 App 诊断 `sourceBitrate=38059232 playbackCapacity=38656662 capacitySource=playbackDelivery capacityBoundsBothSides=true renditionLowerBound=30761837 restoredSamples=23 originalVerdict=fits`。1 MiB 预探测 `probeCapacity=40581135 bodyMs=206`。中码率样本的 `fits` 判定通过。
- 音轨 1、字幕 8，实际 `mode=originalRangeSkipped reason=audioTranscodeRequired`，服务端协商 HLS 12 Mbps，`renditionCeiling=12000000`。复算输出 `69E7F11D ... fits server 12.0 ok`，`1 playback(s) with route evidence, 0 to check.`
- 内部首帧 `tapToFirstFrameMs=15897`，23 秒实图已出画，正常退出。起播体验保留慢样本。此前 S19 的从头 HLS 窗 30 秒仍未出画，本轮 V7 冷起播再次偏慢，保留不同影片、网络和音轨条件。对应处理按总交接第八节交回。 [历史记录](CODEX-2026-11-12-PLAYBACK-POLICY-T2.md)

## V10 设备文件 S19

- 正常重启 App 后从设备文件进入此前确认的 S19 路径，逐步保存诊断。准备 trace `7B215F22 phase=verifiedStreamMatch result=matched`。播放 trace `BF2DFD97` 的 `preview_stream_started transport=verifiedJellyfinHLS sourceBitrate=75218094 probeCapacity=22081207 bitrate=10000000`。片源大于 1.5 倍探测，`min(12 Mbps, 22.081207 / 2 Mbps)=11.0406035 Mbps`，最高合格档 10 Mbps，路线规则通过。Jellyfin 入口复算脚本对设备文件无独立主记录，最终仍报告 V7 一条、零不符。
- 内部首帧 4,619 ms、位置 14.001 秒；3 秒有加载界面，10 秒显示播放位置推进至约 18 秒，三张取证图都未确认影片画面，24 秒图为黑屏。保留为实际显示未通过，未把内部时钟用作显示证据。正常退出。

两窗合计只有 [此前 S19](CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-PLAY.md) 1 次 `explore`，T4 样本不足，系数保持 3。V8 已验证样本恢复与使用，严格重启前后配对以及 HLS 音轨时序待补。T5 未接线。本批无产品代码、参数、NAS 配置或远端文件修改。

13:50:27 原 Wi-Fi 的连接勾选和状态栏图标复核通过，13:50:29 App、Runner、转发和采集归零。私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `phone/t2-medium-files/`。
