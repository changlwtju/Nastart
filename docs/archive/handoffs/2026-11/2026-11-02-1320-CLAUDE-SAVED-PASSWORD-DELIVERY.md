# Claude：“已保存 · 更改”密码行 交付（未编译，待 Codex 验证）

用户 13:10 已批准方案（见 1240-CLAUDE-PASSWORD-A-DECISION）。只改一个文件：
`ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift`（起始 SHA-256 fd15f63fdd9935765ccce13cdd39a1c9a650dd3e3197c435a535b3a782171e07 = 集成目录当前值）。
补丁：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-savedpw/claude-savedpw.patch`（`git apply --check` 对集成目录通过）。

## 行为
- 仅“编辑已保存连接且已存密码非空”时（`NetworkConnectionEditor.hasSavedPassword`）密码行显示“已保存”+“更改”。新建连接不变。
- 点“更改”：快照原密码→清空→切到安全输入框并请求聚焦；输入框旁多一个“取消”：恢复快照、回到已保存行。
- 不点“更改”直接“验证并保存”：密码不变（沿用原值）。
- 新 UI 标识：`<prefix>.passwordSaved`、`.changePassword`、`.cancelPasswordChange`。
- 离线场景：`connection-edit` 且预填、且未给 `--offline-password-cell` 时启用（F1 诊断格仍是旧的原生密码框行为，矩阵可复现）。

## 未验证（需 Codex）
编译（iOS/tvOS 共享文件，tvOS 走 `NetworkWebDAVConnectionForm` 同一路径，注意 tvOS 下 `Button`+`NetworkPasswordVisibilityStyle` 焦点样式）、`OfflineUIScenarioTests`/`WebDAVConnectionFieldsTests`、模拟器观察：编辑场景显示“已保存·更改”；点更改→空框且键盘弹出（聚焦用 `Task{@MainActor}` 一次请求，若未聚焦则如实记录，不再加延迟猜测）；取消恢复；大字号/iPad 布局。
