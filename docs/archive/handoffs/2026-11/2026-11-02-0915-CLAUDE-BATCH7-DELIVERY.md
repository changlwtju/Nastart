# Claude 第七批交付：密码首次编辑归因实验夹具（补丁已验证到“包编译+单测+Release 排除”，模拟器矩阵未运行）

2026-11-02 09:15（Asia/Shanghai）。负责人/实施者：Claude；构建/脚本执行：Codex（应用户要求代跑两条只读/只构建脚本）。依据：[下一实施批方案](2026-11-02-0825-CLAUDE-CONTINUATION-NEXT-BATCH-PLAN.md)，用户 08:5x 明确授权“立即开始第七批实施”（仅限独立工作区和方案的 6 个文件）。

## 1 结论

- 方案的 6 个文件（5 改 1 新增）已在独立工作区实施，补丁对集成目录 `git apply --check` **通过**（exit 0），未对集成目录写入。
- **已运行并通过**：NetworkMedia 包单测 14/14（`OfflineUIScenarioTests` 8 个含新增 4 个、`WebDAVConnectionFieldsTests` 6 个，0 失败）；包的 iOS/tvOS 模拟器 Debug 与 Release 共 4 个编译全部 `BUILD SUCCEEDED`（Xcode 27.0 27A266a，Swift 6.4）。
- **Release 排除**：Release 链接产物 14 个文件中 6 个标记计数全为 0。初检在 Release **目标文件**里命中 2 处 `OfflinePasswordProbe`，已查明是空编译单元 `OfflinePasswordProbeScene.o` 里的**源文件路径字符串**（`symbols_with_PasswordProbe=0`，iOS/tvOS 各 2 个 .o 各 1 次），不是代码；Debug 对照 6 个标记均出现（正对照成立）。
- **未运行**：完整 App 构建与六配置、模拟器矩阵（阶段 0–2）、真机、Release 完整 App 的 `strings` 检查。**本批没有任何关于“A 由哪一层产生”的运行证据。**

## 2 起止哈希（独立工作区，基线提交 9cd4048f96db01c6a0ad52d52198ee0c5a618975 = 集成目录拷贝，含已接受脏改动）

| 文件（NetworkMedia 包内） | 起始 SHA-256（=集成目录） | 结束 SHA-256 |
|---|---|---|
| Sources/NetworkMedia/LibraryViews.swift | a8282d4eb5d1e98e3d034f182aa1f9bab039c04a111355f1818eb5bd8f4e0b56 | fd15f63fdd9935765ccce13cdd39a1c9a650dd3e3197c435a535b3a782171e07 |
| Sources/NetworkMedia/PasswordInputDiagnostics.swift | e500f40ec7d290380967c9d6b1d5ea379444e62e4be7ea35ba725cedb33acc0d | 207289c3a40b40d6ac012cb103d4d625f24686ea6f58a1e704f07c4f0d180196 |
| Sources/NetworkMedia/OfflineMediaScene.swift | def22c8bdf813eba1682039fdeb0dfae76b2e728611b1df8a63436faad0ddfe6 | 5ad6fc93c09622ff01920f3e61fae54d0802399f94228a41d26f610e2ec22a77 |
| Sources/NetworkMedia/OfflineUIScenario.swift | 7a8bd4d1d2bd4575a98901642d1aa71dcaf378293629294fc57be413aa36044c | 05710a31998376dbc43f74d98ff2c1248212be4293eca2b8db14bcca780da4c1 |
| Sources/NetworkMedia/OfflinePasswordProbeScene.swift（新增） | （无） | 0db4346d360a230e7e88615cc87eca8673460fc9d3b305a012383208a4771d73 |
| Tests/NetworkMediaTests/OfflineUIScenarioTests.swift | 232bf390802db49a1d842bf5eaa819729ba1ff565242fd3e00d489cf466375ec | b18d585d7e8199ddc7691da1ccacdcd1a40454135e830b69071b7343efaddccf |

补丁：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch7/claude-batch7.patch`，28128 字节，SHA-256 `34d7d73b17669ee8c071f2f26a2f725f550bcdc8cf82967b8dda311916acfdd0`；6 个结束文件副本在同目录 `files/`。diffstat：6 files，+279 −11。起始哈希在脚本运行时与集成目录一致（apply --check 通过）。

## 3 实际改动

1. **OfflineUIScenario.swift**：新增场景 `password-probe-swiftui`、`password-probe-uikit`；新增 `PasswordProbeOptions`（initial prefilled|empty、secure secure|plain、content-type on|off、start-visible hidden|visible、modifiers bare|form、cell 标签）与 `OfflineUIConfiguration.passwordProbe`（`init` 新参数有默认值，AppTheme/NastartApp/Mine/TV 调用方未改）。解析严格：单次出现、必须有值、值不以 `--` 开头、取值属枚举；任何其他 `--offline-password-*`（含 `=` 形式）、用错场景（`secure`/`modifiers` 仅探针场景，`start-visible` 仅 connection* 表单场景，`connection-actions` 不接受）、非法 `cell`（须 1–16 位 ASCII 字母数字或 `-`）一律落 `.invalid`；无 `--offline-ui` 时仍返回 nil。默认值＝正式表单。
2. **PasswordInputDiagnostics.swift**：观察谓词由“`textContentType == .password`”放宽为探针窗口内全部 `UITextField`（每次至多 8 个）；每个控件新增 `role`（仅取 `accessibilityIdentifier` 末段，白名单 password/username/name/address/port/path，否则 other）、`contentTypePassword`、`contentTypeUsername`；每行新增 `cell`。**字段白名单需同步**：原有字段 + `role/contentTypePassword/contentTypeUsername/cell`。0600、1024 上限、弱映射、不读 text/placeholder/长度/选区偏移均保持。
3. **LibraryViews.swift**：表单 DEBUG+iOS 块内新增 `.onChange(of: password)` → `swift.password.changed`（仅事件名）；`passwordVisible` 的 DEBUG 起始值经既有 `enableOfflinePasswordDiagnostics(_:)` 下发；密码/用户名 `textContentType` 改为 `contentTypesEnabled ? .password : nil`（Release/默认恒 true）；`OfflineWebDAVFormScene` 的密码初值由选项决定。**未动**：`if/else` 结构、`focused`、`submitLabel`、`onSubmit`、toggle、`busy/onDisappear`、编辑器与添加入口。
4. **OfflineMediaScene.swift**：穷尽 switch 增 1 组 case（iOS→探针场景；tvOS→隔离说明）。
5. **OfflinePasswordProbeScene.swift（新增，`#if DEBUG && os(iOS)`）**：合成探针页；SwiftUI 版（bare / form 两档修饰链）与 UIKit 版（`UIViewRepresentable`，无 binding、无 delegate、`updateUIView` 不写文本、初值只在 `makeUIView` 设一次；`isSecureTextEntry` 先于 `text` 设置——SwiftUI 内部顺序未知，属残余差异）；底部标注“归因实验，不是表单验收”。
6. **OfflineUIScenarioTests.swift**：新增 4 个测试（无离线根时参数不生效；所有场景默认等于 production；合法参数解析；16 类误用均为 invalid，边界 16 位 cell 合法）。

**与方案的偏差**：多了 `--offline-password-modifiers bare|form`（仅探针场景），用于一次覆盖阶段 2 的 S3（正式修饰链+FocusState，无页面容器/样式/显隐按钮），避免再构建一轮。

## 4 命令与未运行项

已运行（由 Codex 在用户要求下于 Mac 执行，本方 Linux 沙箱无 Xcode）：`swift test --filter OfflineUIScenarioTests --filter WebDAVConnectionFieldsTests`（09:00，exit 0）；包 scheme `NetworkMedia` 的 `xcodebuild … -configuration Debug|Release -destination generic/platform=iOS Simulator|tvOS Simulator`（4 个，exit 0）；`run-verify.sh`（09:00:15–09:01:57）与 `run-verify2.sh`（09:08:23–09:08:26）。独立 DerivedData：`~/Library/Developer/Xcode/DerivedData/Nastart-Claude-Batch7-Pkg`；SwiftPM scratch：`~/Library/Caches/Nastart/Claude-Batch7-PkgTests`。工作区可用空间运行前 13 GiB。注意：`run-verify.sh` 在设备上是**不含补丁导出段的旧版**，补丁导出由 `run-verify2.sh` 完成。

**未运行**：App 工程（`Nastart` scheme）的模拟器/设备/Release 六配置；TV 目标完整编译（仅包的 tvOS 编译）；阶段 0–2 模拟器矩阵；任何设备、WDA、NAS、真实存储。

## 5 给阶段 0–2 的启动参数（Codex 或后续窗口使用；均加 `--offline-ui` 与 `--offline-password-trace`，每次 fresh 进程；`<cell>` 为配对标签）

- 阶段 0（F1，2×2）：`--offline-ui connection-edit --offline-ui-text-size standard|large --offline-password-cell <cell>`
- F2：+ `--offline-password-initial empty`；F3：+ `--offline-password-content-type off`；F5：+ `--offline-password-start-visible visible`
- S1：`--offline-ui password-probe-swiftui --offline-password-secure secure --offline-password-content-type off`；U1：同上换 `password-probe-uikit`
- 阶段 2：S2＝S1 且 `--offline-password-content-type on`；S3＝S2 + `--offline-password-modifiers form`；U2＝U1 且 content-type on；U3＝U1 且 `--offline-password-secure plain`；F6＝F1 后先点显隐再按键；F5-IME＝F5 + 拼音单音节
- 探针页与 F 系列须使用阶段 0 得出的**同一字号**；第 3 次重复不带 `--offline-password-trace`，只记 replaced/appended/other 类别，不存密码区截图。JSONL：应用容器 tmp 下 `Nastart-Offline-Password.jsonl`（0600，≤1024 事件）。

## 6 风险与残余

- R1：`accessibilityIdentifier` 是否落到 `UITextField` 未验证；否则 `role` 全为 other，改靠 token/secure 区分。
- R2：`textContentType(nil)` 与“从未设置”是否等价未验证（F3 只比较同一代码内 nil 与 .password）。
- R3：UIKit 对照仍在 SwiftUI 宿主窗口内，不是纯 UIKit 应用；“替换”不证明 UIKit 内部先清再写。
- R4：Release 中 `textContentType` 修饰由字面量变为常量折叠表达式，行为等价但非逐字节相同；已通过编译，未做完整 App Release 行为核对。
- R5：夹具/探针均**不是表单验收**；任何结果须标“归因实验”。
- 其他：钥匙串预填与夹具字面量预填是否等价仍不可离线验证。

## 7 写入释放与现场状态

- 本方写入仅：独立工作区 `/Users/lagransun/workspace/Nastart-Claude-PasswordCausal-20261102`（分支 `claude/password-causal-batch7`，基线提交 9cd4048）、`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch7/`、本报告。**集成目录 Nastart 只读未改**。**写入已释放**；我没有启动任何进程、模拟器、设备、WDA、后台任务。
- 独立工作区 `.git` 内留有**陈旧锁文件**（`HEAD.lock`、`packed-refs.lock`、若干 `refs/**/*.lock`、`gc.pid`、`maintenance.lock`、`objects/*/tmp_obj_*`）：本方沙箱无权删除目录内文件，且 git 在拷贝时自动 gc 失败所致；之后若要在该工作区 `git commit`，需先由 Codex/用户确认无 git 进程后清理。另 `run-verify*.sh` 在工作区执行过 `git add -N`（仅新增文件的 intent-to-add）。
- 本方 Mac 文件 shell 在 08:45 前后连续失败 5 次后被判定卡死（可能源于此前对 `~/Library` 的一次超时 `ls`），之后只经暂存/提交通道读写；未使用 Xcode/终端的电脑控制（终端/IDE 为只能点击的层级）。

## 8 需要 Codex 同步 / 下一步

1. 审查并（如接受）`git apply` 补丁到集成目录；SHA 与 `apply --check` 见 §2。
2. 完整 App 的六配置构建与新正常包仍待（额度恢复后）；之后一次安排阶段 0–2 的模拟器窗口（§5 参数，方案 §8 的清理/预算/时限）。
3. 同步 PROGRESS/当前交接/登记：新增 `claudeBatch7` 条目；JSONL 白名单核对加入新增 4 个字段；注明“Claude 主导产品代码、Codex 支持集成/构建/设备”（用户 08:30 意向，待 Codex 确认写入）。
4. Codex 额度：未知（界面显示本周剩余约 10%，11 月 4 日重置，仅作现场记录）；Claude 额度：未知。
