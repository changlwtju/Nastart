# 密码首次输入“替换”(A) 的结论与产品方案（待用户决策，未改代码）

依据：CODEX-2026-11-02-PASSWORD-USF-CONTROL（U/S 各 2 次，F1 共 6+1 次，iPhone17 Pro/iOS27.0，全部 12→1）。

## 结论
- 纯 UIKit 的 UITextField(isSecureTextEntry) 与 bare SwiftUI SecureField 都会在编辑预填值时被替换；正式表单逻辑不是必要条件。A 归为 iOS 安全输入框的系统行为（仅 iOS 27 模拟器 iPhone 已证；iPad、其他 iOS 版本、真机、plain/content-type off 对照未测，不写成通用保证）。
- 显隐切换后失焦(B)是另一个问题，未关闭。

## 方案（待决策）
已保存连接的密码行不直接放可编辑的预填安全输入框，改为：
1. 显示“已保存 · 更改”（不显示点数，也不暴露长度）。
2. 点“更改”后切到空的安全输入框并聚焦；“取消”恢复为已保存状态。
3. 不改动密码存取逻辑；新建连接仍是空输入框。
理由：系统行为无法绕过，让界面如实表达“输入即替换”，避免用户误以为是追加。
影响文件预计：LibraryViews.swift（连接编辑表单）、本地化串、OfflineUIScenario 的 connection-edit 场景及测试。

## 状态
未实施；等用户确认产品方案。B（显隐失焦）可与此一并设计。
