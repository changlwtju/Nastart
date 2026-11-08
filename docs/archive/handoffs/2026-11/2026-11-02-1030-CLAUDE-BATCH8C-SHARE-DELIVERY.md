# Claude 第八批 C：分享完成/取消/失败的可观察结果

2026-11-02 10:30（Asia/Shanghai）。负责人 Claude。**本补充（C）未编译、未运行**；第八批 D+A 的结果见 `1005-CLAUDE-BATCH8-COMPILE-RESULT`，且 Codex/用户后续已运行 `RUN_TESTS=1`：`B4_xctest.log` 记录 9 个新增单测全部 passed、`** TEST EXECUTE SUCCEEDED **`（我读取了原始日志；脚本汇总里没有测试行是我的 grep 格式写错，不影响结果。该次宿主启动是否碰过 NAS 我无法从日志判断）。

## 产品语义（用户 09:27 已定）
不弹“已分享”，只在失败时说明。完成/取消不提示，因为分享目标不一定产生导出，完成不等于送达。

## 改动（在工作区 `Nastart-Claude-Closures-20261102` 的第八批文件之上，不新增文件）
- `MineView.swift`：新增 `NastartShareOutcome`（`init(completed:error:)`：有错误即失败，否则完成/取消）；`NastartShareProbe` 与环境值 `nastartShareProbe`（正式为 `.production`，不模拟不记录）；`NastartShareButton`：点击时才生成文本（原 `ShareLink(item: exportText)` 在每次 body 求值都会生成），以 `.sheet` 承载 `UIActivityViewController`，用 `completionWithItemsHandler` 取结果；失败在面板收起后（`onDismiss`）弹出 `mine.share.failed`。两处 `ShareLink`（数据导出、诊断导出）已替换，外观修饰符与无障碍标识保持。
- DEBUG：`NastartOfflineShareProbeHost`（分段选择“系统面板/完成/取消/失败”，后三者不打开系统面板、走同一条结果处理并计数，`offline.share.outcome`、`offline.share.counts`），挂在离线诊断场景与离线导出预览。
- `AppTheme.swift`：仅在 `exportSelectionPreview` 挂上述 host。两份 `Localizable.strings`：新增 `mine.share.failed`。
- `NonPlaybackPolicyTests.swift`：`NastartShareOutcomeTests` ×4（完成/取消/错误即失败不论 completed 标志/正式探针不模拟）。

## 起止 SHA-256（起＝第八批 D+A 版本）
| 文件 | 起 | 止 |
|---|---|---|
| MineView.swift | e9b80b32a886d5e7e3730f17bfc594cee9d0381ae9d8c1bef7ec4f83571625aa | 0caad2561baaf625762534e3191855441f57cbb045e314802dd712be954528c5 |
| AppTheme.swift | 5f95e81f437f60c158c5666bcd42e2d80dd6a7a8e3bf7312134490d92b948b32 | c8e9b0d6b2908ea647cbd9d9d5b112c4824051ec95e2efad9eee00e35d96ae6d |
| en.lproj/Localizable.strings | 68e954e2ed17ac3402e4bd69feb5d35a129d0dede4ea4e7bf0829edea72658b9 | 42004aa474fd7d54866a287c91f9f383c62ef75dcc456e70e9f15b7d94f1bf12 |
| zh-Hans.lproj/Localizable.strings | 948639deb9a5ac48f176dd30b4292b8b27e3ec81a13ec5cc8bb07e8f27fc0088 | 2007a5fb9a27283c3989a21cea32282327dacb28a2ad688f8498e9137752f1e9 |
| NastartTests/NonPlaybackPolicyTests.swift | 274eacdfeca54075b8a789f2106c59c0f18d6913d2e5aeedfb3b780dae991637 | 19d0101fd5f92b2cadd12d23b71df96810661d8fab4d68747539fe5c08833d4e |
（`AppStateStores.swift` 沿用第八批 b035f7e9…c5fd，本补充未改。）

补丁目录：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch8c/`
- `claude-batch8-all.patch`（D+A+C 合并，相对集成目录基线，36052 字节，sha256 18801345…78e2，`git apply --check` 对集成目录 exit 0）。
- `claude-batch8c-share-only.patch`（仅 C，相对第八批版本，10079 字节，sha256 51b36f7f…79bf）。
- `files/` 完整文件；`run-verify-batch8c.sh`（同第八批：默认只编译；`RUN_TESTS=1` 才跑 `AppearanceStoreInjectionTests/PrivacyCacheCleanerTests/NastartShareOutcomeTests`；Release 标记扫描含 `NastartOfflineShareProbeHost`、`offline.share.*`）。

## 未证明 / 风险（须看真实运行）
- 编译：未知。
- **iPad 与 iPhone 上 `UIActivityViewController` 作为 `.sheet` 内容的表现**（尺寸、是否空白、取消回调是否触发、`presentationDetents` 是否合适）：未验证。这是把 `ShareLink` 换成包装后的主要回归风险；若 iPad 表现不佳，备选是改为 UIKit 直接 present 并设置 popover 锚点，或回退到 `ShareLink`（失败说明就不可得）。
- 点空白/下拉收起面板是否触发 completion：不确定，此时不计结果、不提示。
- 失败路径：真实分享几乎不会失败，只有离线“失败”档（模拟）覆盖了提示展示；真实错误码未测。
- 导出文本内容与以往一致（同一 `exportText`），但生成时机由“渲染时”变“点击时”；未测大文本。
- 无障碍：标识符保持，VoiceOver 对新按钮的播报未测。

## 窗口（待额度/同意，隔离模拟器；不碰真机/NAS）
1. `--offline-ui privacy-export`（iPhone，standard/large）：选“失败”→点导出→应出现“无法完成分享…”，计数失败 1；选“完成/取消”→无提示，计数加 1；选“系统面板”→系统分享面板出现，关闭。
2. `--offline-ui diagnostics`：同上。
3. iPad 模拟器重复 1 的“系统面板”档，记录呈现与关闭是否正常。

## Codex / 用户
一句话：运行 `RUN_TESTS=1 bash ~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch8c/run-verify-batch8c.sh`，把 `RESULT.txt` 与 `logs/B4_xctest.log` 结果告诉我。共享状态更新（claudeBatch8c、UI 标识符 `offline.share.*`、`mine.share.failed`、环境探针）仍由 Codex 独写。

Codex 额度：未知；Claude 额度：未知。NAS 暂停、iPhone18 hands off、Apple TV 签名阻塞不变。
