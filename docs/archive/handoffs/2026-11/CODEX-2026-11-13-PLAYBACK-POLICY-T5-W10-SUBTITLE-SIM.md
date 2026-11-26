# 2026-11-13 W10 预热播放器字幕状态隔离验证

接续 [W10 真机复核](CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-FOLLOWUP.md)。本批用仓库外独立源码副本和新建 iPhone 17 / iOS 27.0 模拟器，验证预热播放器首次接入时的字幕状态。没有操作真机、切网或访问 NAS/Jellyfin 媒体。主工作区起始 HEAD `8db1cc64`，146 个未提交路径，500 个冻结构建输入与真机包 `6beee7cb…` 一致。

## 验证方法

- 06:40:11 开始。含未提交改动的同源副本、已缓存依赖、单独 DerivedData，Xcode 27.2 的未签名 Debug。宿主使用 `--offline-ui empty`，专用模拟器启动前没有 App 数据容器。首次构建漏复制工程引用的三份 Agent 资源，保留构建失败日志，补复制原文件后重试。
- 夹具在副本中调用实际 `KSVideoPlayer.Coordinator.makeView`、`SubtitleModel` 和 `GreenfieldPlaybackControls.runtimeState`。使用本地虚拟路径、未启动的播放器层及轨 9 测试替身，按生产 `syncTracks` 的 ID 转换把模型变化传给 controls。夹具控制接入和选轨的顺序。
- 比较预热层首次接入时先选轨、URL 已初始化后再选轨和用户明确关闭字幕。另跑已有的同 URL PiP 重新挂载测试作为对照。夹具不解码媒体，不能测字幕实际渲染、HLS 降档或听音。

## 结果

| 场景 | 观测与判定 |
| --- | --- |
| 预热层第一次挂载，URL 初始化完成前选轨 9 | 同一个 layer 被复用。排空主队列后，`before=Optional(9) after=nil known=true off=true disableCalls=1`。保留轨 9 和不得误报关闭的两项断言失败，同一个测试用例计 1 个失败。 |
| 先初始化 URL 再选轨 9 | 同一个 layer 保留轨 9，`track=Optional(9) known=true off=false`，没有禁用轨道，测试通过。 |
| 用户明确关闭字幕 | `track=nil known=true off=true`，测试通过。 |
| 同 URL PiP 重新挂载 | 现有测试通过，既有轨道保留。 |

首次完整测试结果为 4 个用例、3 个通过、1 个复现失败、0 个跳过。单独重跑失败用例两次，均复现相同的轨道清空和关闭状态。重跑的结果包按唯一用例汇总为 1 个失败，两轮分别见 XCTest 日志。包装脚本在测试结束后写退出码时使用了 zsh 的只读变量，改从两个完整结果包和逐轮日志核对。没有运行已知基线 Range 失败项。本批没有新增播放路线样本，路线复算沿用上一批的各 2 条、0 不符。 [真机对照](CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-FOLLOWUP.md)

已验证首次挂载的异步 URL 初始化可清空刚选的字幕，运行时快照随之成为「明确关闭」。机制与 W10 真机中 `subtitleTrackRequested value=9`、随后降档请求 `requestedServerSubtitleIndex=-1`、旧流保存 `subtitlesDisabled=true` 一致。真机尚未在同窗直接采到 URL 初始化与轨道状态变化。后续渲染器修正可验证把初始化移到预热准备阶段，并用同一用例和用户主动关闭对照防止回归。切轨耗时和现场听音仍待独立验收。主工作区未改产品、测试、播放模型或调参。 [KSPlayer 挂载](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/AVPlayer/KSVideoPlayer.swift) · [字幕模型](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/Subtitle/KSSubtitle.swift)

06:46:09 关闭并删除本轮专用模拟器，核设备清单和数据目录均已释放。私有证据入口 `/tmp/nastart-codex-w10-subtitle-sim-20261113-current`，含夹具、构建与测试日志及两个 XCTest 结果包。
