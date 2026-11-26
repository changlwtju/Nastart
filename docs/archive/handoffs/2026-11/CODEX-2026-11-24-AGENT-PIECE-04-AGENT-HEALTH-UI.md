# Agent 第 4 件健康状态与重新配对交接（2026-11-24）

iOS 启动台在设备概览和服务卡片上方显示 Agent 状态，三个启动台主题共用入口。读取 `agentHealth` 的已有状态和失败原因键，只展示当前配对记录的快照。没有快照时没有状态行。到期时刷新状态行，健康状态由同一份 `AgentHealthSnapshot` 重新计算。

失败行只显示中英文可读文案。快照 ID 不符与握手 ID 不符均归为 `unauthorized`，显示「Agent 已更换或配对已失效，请重新配对」，与网络不可达分开。点击「重新配对」打开原 `AgentSetupGuideView`，带入已保存地址和证书开关，沿用原有配对、握手和保存路径。错误地址会在配对表单中显示本地化错误。

## 改动文件

- [AgentClient.swift](../../../../ios/Nastart/Nastart/Core/Stores/AgentClient.swift) · 状态按时间计算和身份错误归类。
- [LaunchpadView.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift) · 服务页状态行与前往配对表单的导航。
- [LaunchpadLayoutViews.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadLayoutViews.swift) · 状态、失败文案与重新配对按钮。
- [LaunchpadConnectionViews.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadConnectionViews.swift) · 原配对表单预填当前地址和证书选项，配对错误使用本地化文案。
- [简体中文](../../../../ios/Nastart/Nastart/zh-Hans.lproj/Localizable.strings) 与 [英文](../../../../ios/Nastart/Nastart/en.lproj/Localizable.strings) · 已连接、身份异常和通用失败文案。
- [NonPlaybackPolicyTests.swift](../../../../ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift) · 7 个新用例。

工作区为 `/Users/lagransun/workspace/Nastart`，源码基于 `main/8db1cc64` 和现有未提交改动。7 个文件可从根目录运行 `shasum -a 256 -c` 校验。 [SHA-256 清单](../../../testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-04.sha256)

## 构建与验证

Xcode 26.6（17F113）Debug，iPhone 17e，iOS 26.5（23F77），arm64。正式工作区的 App 和宿主测试完成编译与链接。定向 XCTest 共 9 项通过，包含 7 项新增和 Agent 合并、地址策略 2 项已有回归。新增用例覆盖三种状态、15 分钟边界、身份异常与网络失败、未知原因的本地化兜底、nil 状态行实际高度为零。定向测试沿用本项目的私有 workspace/scheme 和已固定的 SwiftPM 依赖，排除已有编译问题的 `PlaybackNextCoreTests.swift`。

模拟器 UI 走真实启动台和原配对页面，7 项通过，0 失败，0 跳过。测试在仓库外单独构建，复用已有离线入口，在隔离 store 中注入合成快照和合成配对记录。应用使用本批实际 UI 与本地化源码，测试夹具只进入私有副本。

| 用例 | 模拟器检查 |
| --- | --- |
| 已连接与过期 | 简体中文，状态在服务之前，过期显示 15 分钟说明，两种状态均没有重新配对按钮。 |
| 网络失败 | 简体中文，失败与「Agent 没有响应」同屏，重新配对可点击。 |
| 身份异常 | 英文专属原因。点击 Pair Again 到达原表单，已保存地址和证书开关预填。 |
| 空状态与错误地址 | 空状态保留服务列表，配对表单对测试错误地址显示可读提示。 |
| 到时过期 | 合成快照从第 888 秒开始，前台跨过 900 秒后自动切换为过期。未触发手动刷新。 |

原始构建日志、`AgentHealthUnit.xcresult`、`AgentHealthUI.xcresult`、8 张截图和测试夹具保存在 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-04.6FU2VN/`。专用模拟器已删除。早期日志保留了临时工程产品名、资源链接、无障碍标识和时间调度的修正过程。前台时间线在模拟器未按期触发，已换为随状态行生命周期取消的一次性任务。 [Apple TimelineView 文档](https://developer.apple.com/documentation/swiftui/timelineview/context/date)

## 可转交给 Muse 的指令

```text
请在 /Users/lagransun/workspace/Nastart 接收 Agent 第 4 件源码，校验 docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-04.sha256。Codex 已完成 Xcode 26.6 iOS Debug 构建，9 项定向 XCTest、7 项 iPhone 17e 模拟器 UI 验证均通过。
请按项目规程逐台核对 iPhone 13 和 iPad 的目标身份及最新签名包，保留数据覆盖安装，再用 Mac 上的隔离测试 Agent 验收。打开启动台，配对并刷新后应显示已连接。停止测试 Agent 后刷新，应显示可读网络原因及重新配对入口。恢复同地址的测试 Agent 并更换测试实例身份后复核专属文案。点击入口确认打开原配对页、保存地址已预填，测试错误地址有可读提示。
失败请回传设备和包 SHA-256、复现步骤、状态行与配对页的截图、Agent 是否运行及脱敏诊断。配对码、地址凭据和 token 留在本机。
```
