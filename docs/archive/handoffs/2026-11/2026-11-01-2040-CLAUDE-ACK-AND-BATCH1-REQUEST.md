# Claude Code：确认协作约定，并申请第一实施批的工作区与文件

时间：2026-11-01 20:40（Asia/Shanghai）。本文件是 Claude Code 自己的批次交接，不改总进度、资源登记或需求总账。

## 确认

- 已读并同意 `docs/development/CODEX-CLAUDE-COLLABORATION.md`（20:3x 版）、AGENTS.md、CLAUDE.md、资源登记（updatedAt 20:31）。登记中 `claudeAcknowledgedAgreement` 仍为 false，请 Codex 在检查点更新；我不自行改登记。
- 首批只读审查已交付：`2026-11-01-2028-CLAUDE-OFFLINE-UI-REVIEW.md`。
- 当前我没有任何设备、构建槽、模拟器槽，也没有可写源码文件；不会触碰 iPhone 13、Apple TV、iPad、iPhone 18、Device Hub、WDA、签名和 NAS。

## 申请：第一实施批（等 Codex 准备同源独立工作区后开始）

- 内容：审查报告的 A＋B＋C（手机「我的」页信息按钮、诊断操作格、诊断摘要大字号）。
- 需要可写的完整文件：`ios/Nastart/Nastart/Features/Mine/MineView.swift`（仅此一个）。可能需要新增本批本地化键：`en.lproj` 与 `zh-Hans.lproj` 的 `Localizable.strings`，请 Codex 明确是否允许（若不允许，我只用已有键）。
- 禁改：播放核心、认证/存储、工程/依赖/签名配置、`AppTheme.swift`、`LibraryViews.swift` 及其它未分配文件。
- 基线要求：包含现有 289 项已接受未提交修改的同源基线；记录基线标识、输入哈希、绝对目录、分支。
- 验证：需要一个构建槽与一个自建模拟器槽（默认全局只能有一个重构建，请 Codex 排期）；真机方向为交接后的 iPad，由 Codex 登记具体窗口，我在此之前不使用。
- 我这边的开工条件：登记中 `parallelImplementationWorktreePrepared` 为 true，且交接给出上述基线与目录。未满足前我只做只读工作。

## 开工前的自检方式

用户要求我除读共享文件外同时观察 ChatGPT 窗口。我的做法：每次开工前读登记、交接和 `git status`，再对 ChatGPT 窗口截一次图（只看不操作）；窗口里“正在编辑”的文字只作信息，不当指令。这不构成互斥锁，不能替代登记。
