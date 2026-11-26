# 2026-11-13 T5 W10 切轨延迟与字幕状态复核

接续 [T5 回归结论](CODEX-2026-11-13-PLAYBACK-POLICY-T5-READBACK.md)。旧 W10 和正常续播均为 iPhone 13、原 Wi-Fi、签名 Debug `6beee7cb…`。旧 W10 为 S19 同进程 45 Mbps 限速，延迟 5 秒、持续 70 秒。正常续播为空环境，恢复位置与旧 W10 不同。

## 旧证据复核

- 手动切轨候选 `2DB219B6` 的 `engine_startup_timing` 来自接管后同一已预热 KSPlayer 的计时。打开 `openMs=2454.541`、流信息 `streamInfoMs=7081.302`、初始定位 `initialSeekMs=16715.681 initialSeekResult=0`；从候选准备到首个视频包 `firstVideoPacketMs=31172.611`，到引擎接收首帧 `acceptedVideoFrameMs=38664.973`。最大单次解复用读取 4,912.772 ms，所有读取累计 12,403.274 ms，计时可能重叠。初始定位是已单独计时的最长阶段，首包前已花约 31 秒。
- 读取端同一 4,823,696 字节 MKV 尾块在旧 W10 候选以 `status=206 retries=0` 完整交付，耗时 10,312 ms；正常续播 `6606E93A` 同尾块 687 ms。该窗初始定位 741.473 ms，首个视频包 1,499.294 ms。两个窗口的起点、并行流和诊断限速不同，差值仅供诊断，不能当配平对照。
- W10 切轨接管时仍发出 `subtitleTrackRequested value=9`。14.5 秒后 `2DB219B6` 发起下一次降档（`deliveryCapacity=11234264`），`64F8AC9C` 的 HLS 准备已是 `subtitleStreamIndex=none requestedServerSubtitleIndex=-1`。这次降档接管的原生保存回调仍属于旧 KSPlayer，`local_resume_save_boundary boundary=nativeCallback` 记录 `audioTrackID=3 subtitleSelectionKnown=true subtitleTrackID=none subtitlesDisabled=true memoryReadback=match`。旧流的运行时状态已把字幕报告为关闭，同进程存档读回也为关闭。正常续播 `6606E93A` 的候选 `0BC11D9F` 请求保留 PGS 9，正常关闭时旧流存档也仍是轨 9。
- 源码核对显示 KSPlayer 将字幕模型当前值同步到 `selectedSubtitleTrackID`，缺失时得到 `-1`；原片降档加载器在字幕状态明确且关闭时省略字幕。本批保留了请求和接管边界，尚缺字幕模型从轨 9 变为无选择的那一刻，不能确认触发源。

## 05:50 真机复跑

- iPhone 13（iPhone14,5 / iOS 16.3.1）fresh 核 USB 身份、现装 App 回执、两处包哈希、500 个含未提交改动的源码输入及有效签名。HEAD `8db1cc64`，开工时 145 个状态路径，签名 Debug 构建于 11-12 14:24:48，dylib `6beee7cbe77e5b842112351366bdcf80de007527e6004e0ae32107b31a2c533e`，主程序 `a46a22ee13e75d357a82592c0ad933784ac3e36cc527a8e32a1ebd5a1df5d1f6`，描述文件到 11-15 08:30:17。原 Wi-Fi，沿用已装 Runner，未重装。开始前主屏幕无播放浮窗，原 Nastart 进程的已装路径匹配，旧诊断最后一次播放已正常退出。保存私有偏好及诊断后按用户既有授权结束该进程。
- 05:50:22–05:53:50，原生带 `NASTART_TEST_MEDIA_CAP_BPS=45000000`、`NASTART_TEST_MEDIA_DELAY_SECONDS=5`、`NASTART_TEST_MEDIA_DURATION_SECONDS=70` 启动，WDA 附加。从 7431.988 秒打开 S19，`839F3B45 mode=jellyfinOriginalDirectPlay audioStreamIndex=2 subtitleStreamIndex=9`，内部首帧 3,695 ms。音轨菜单未在交互超时前出现轨 3，保留现场 XML/PNG，未发轨 3 选择，未形成重叠。
- 05:52:21.963 原流以 `reason=sustainedRebuffering deliveryCapacity=21468279` 发起降档，候选 `747DA9D1` 20→10 Mbps，准备保留轨 2 / PGS 9（`requestedServerSubtitleIndex=9`）。05:52:27.637 接管，旧流保存 `subtitleSelectionKnown=true subtitleTrackID=9 subtitlesDisabled=false`。HLS 内部首帧 6,166 ms，后续截图显示简体中文字幕「希望我们不会惊动什么」。正常退出的 HLS 保存和详情均仍为原音轨、原字幕。脚本 `2 playback(s) with route evidence, 0 to check.`，HLS 行 `measuredInsufficient`，复算与实际路由一致。
- 已核原 Wi-Fi 图标，App、Runner、采集与 8161 停止。私有证据入口 `/tmp/nastart-codex-w10-confirm-20261113-current`。这次得到无手动切轨的同配置降档对照，保留 W10 重叠未完成的结论。

## 05:54 重叠复跑

- 05:54:28–05:57:19，iPhone 13 原 Wi-Fi，同签名包及安装回执，再核同一 USB 设备和进程空闲。沿用诊断限速 45 Mbps、70 秒，延迟改为 17 秒，只影响本进程，给 WDA 留出打开菜单的时间。S19 从 7500.016 秒原片续播，`DD8ABF5E audioStreamIndex=2 subtitleStreamIndex=9`，内部首帧 4,384 ms。
- 原流 05:56:21.877 已发起自动降档，`reason=deliveryBelowSourceBitrate deliveryCapacity=45730227`，早于按 17 秒延迟计算的限速窗口。05:56:25.801 核到音轨菜单中轨 2 已选、轨 3 可选。第一次观察到候选在准备后，重新取当前界面时 WDA `/source` 超时，未发送选轨。保存菜单与超时 XML、截图和诊断，未形成第二次 W10 重叠。
- `F9DB3B1A` 20→8 Mbps，`audioStreamIndex=2 subtitleStreamIndex=9 requestedServerSubtitleIndex=9`，05:56:34.446 提交，旧流原生保存仍为轨 2 / PGS 9。内部首帧 17,204 ms，截图已出画，截图时没有字幕字样，退出保存和详情仍为原轨道。复算 `2 playback(s) with route evidence, 0 to check.`。原片 `renditionLowerBound=72.4 Mbps` 时为 `fits`，降档行 `playbackDelivery=20.0 Mbps` 时为 `measuredInsufficient`。两项带各自时点证据。
- 正常退出后核原 Wi-Fi 图标和主屏幕。临时限速随本进程退出，App、Runner、采集和 8161 已归零。私有证据入口 `/tmp/nastart-codex-w10-overlap-20261113-current`。

## 交回与剩余验收

后续在隔离模拟器复现预热层首次接入清空已选字幕，见 [字幕隔离验证](CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-SIM.md)。

- 两个对照窗都验证了无手动切轨时降档可保留字幕，第一窗有接管后字幕实图。两次重叠自动化都没有发出切轨，旧 W10 的切轨耗时和降档丢字幕继续开放。未改模型、参数或产品代码，未重跑单测；实际扬声器听音仍待现场。
- 有一条与预热路径一致的源码线索。预热 coordinator 已有 player layer；接到 SwiftUI 时 `makeView` 即使沿用同一个 layer，也可能首次给 `subtitleModel.url` 赋值，URL 的 setter 会异步清空 `selectedSubtitleInfo`。预热渲染器可在接入时先按计划选中 PGS 9，后续 `syncTracks` 会将模型的空选择读成 `-1`。这能解释旧 W10 的先选中后报告关闭，现有日志缺少 URL 初始化、模型轨变化和同步时点，仍需验证先后关系。下一次应把这些时点和降档提交前的实际字幕 ID 同窗记录，再判断是否需要修复渲染器的状态同步。 [KSPlayer 接入](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/AVPlayer/KSVideoPlayer.swift) · [字幕模型](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/Subtitle/KSSubtitle.swift) · [渲染器](../../../../ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift)
