# Claude 接续：密码首次编辑替换的因果对照——下一实施批方案

2026-11-02 08:25（Asia/Shanghai）。负责人/实施者：Claude；复核、集成、构建与设备窗口：Codex。依据：用户 08:17 接续指令、[接手单](../../../development/CLAUDE-PRIMARY-DEVELOPMENT-HANDOFF.md)、[推进指令](../../../development/CLAUDE-NEXT-DEVELOPMENT-PROMPT.md)、[第六批审查](2026-11-02-0735-CLAUDE-BATCH6-PASSWORD-CAUSAL-REVIEW.md)（复用其结论，不重复审查）、[选区诊断](2026-11-02-PASSWORD-SELECTION-DIAGNOSTICS.md)、[10-31 事件诊断](../2026-10/2026-10-31-PASSWORD-INPUT-EVENT-DIAGNOSIS.md)、[10-31 表单反例](../2026-10/2026-10-31-CONNECTION-FORM-INTERACTION-AND-PASSWORD-REGRESSION.md)。

**本报告只读产品源码，唯一写入是本报告。没有运行任何编译、测试、模拟器、真机、NAS、凭据读取；Claude 的 Linux 沙箱没有 Xcode 工具链。下文所有“预期”都是判读预案，不是结果；所有“未运行”项如实标明。** 没有比 0735 更新的同任务交付（handoffs 目录与登记 `claudeBatch6` 一致）。

## 0 现场与起止哈希

| 文件 | 起始 SHA-256 | 结束 SHA-256 |
|---|---|---|
| `LibraryViews.swift` | `a8282d4eb5d1e98e3d034f182aa1f9bab039c04a111355f1818eb5bd8f4e0b56` | `a8282d4eb5d1e98e3d034f182aa1f9bab039c04a111355f1818eb5bd8f4e0b56` |
| `PasswordInputDiagnostics.swift` | `e500f40ec7d290380967c9d6b1d5ea379444e62e4be7ea35ba725cedb33acc0d` | `e500f40ec7d290380967c9d6b1d5ea379444e62e4be7ea35ba725cedb33acc0d` |
| `OfflineMediaScene.swift` | `def22c8bdf813eba1682039fdeb0dfae76b2e728611b1df8a63436faad0ddfe6` | `def22c8bdf813eba1682039fdeb0dfae76b2e728611b1df8a63436faad0ddfe6` |
| `OfflineUIScenario.swift` | `7a8bd4d1d2bd4575a98901642d1aa71dcaf378293629294fc57be413aa36044c` | `7a8bd4d1d2bd4575a98901642d1aa71dcaf378293629294fc57be413aa36044c` |
| `OfflineUIScenarioTests.swift` | `232bf390802db49a1d842bf5eaa819729ba1ff565242fd3e00d489cf466375ec` | `232bf390802db49a1d842bf5eaa819729ba1ff565242fd3e00d489cf466375ec` |
| `SourceContext.swift`（只读，未列入可写） | `2c83e033b5a8e47d63b9d8ea4eed381e21ffa4d6dfd1f604fd22b4b59f64594a` | `2c83e033b5a8e47d63b9d8ea4eed381e21ffa4d6dfd1f604fd22b4b59f64594a` |

登记 `AGENT-RESOURCE-STATE.json` updatedAt 2026-11-02T08:08:42+08:00，SHA-256 `314626f30be78d01c9c012f0fa92898ee92e1150fd0bf10f2e9b2b5a44932f3b`。集成目录 HEAD 为旧 4de732d（**不是**最新基线），工作树有 301 条脏项（只记规模）。Claude 额度：未知；Codex 额度：未知（按登记）。起始与结束哈希相同表示审查期间这些文件未变；下一批开始时必须重算，不一致即停并回报。

## 1 要点

1. **本批是“归因实验批”，不是修复批。** 产出：A（预填密码首次编辑被替换）由哪一层产生的受控证据 + 产品语义决定的输入。任何修复另批，且以本批证据为前提；不提第三轮延迟聚焦，不改正式密码行的聚焦/提交/存储逻辑。
2. **源码核对出 5 个会让上一版实验设计失效或被误读的事实**（均已对当前源码确认）：
   - 现有诊断只采集/观察 `textContentType == .password` 的 `UITextField`（PasswordInputDiagnostics.swift `observes` 与 native 采集过滤）。凡去掉 content type 的格、以及任何裸 UIKit/SwiftUI 对照格，都会“看不见”被测控件（`native` 数组为空）。**必须先放宽观察谓词，否则对照格全盲。**
   - 已读记录里 A 的出现都发生在**辅助字号**窗口：iPad 候选窗标“大字号”，11-02 诊断窗标“辅助字号2”；手机“追加成功”的窗口未写字号。而 `--offline-ui-text-size large` 实际是 `.accessibility2`，此时 `inputRow` 走 VStack 分支、标准字号走 HStack 分支（LibraryViews.swift:1645–1657；AppTheme.swift:1198）。**设备类型（手机/iPad）与字号/布局路径是混杂的，必须先做环境因子拆分（阶段 0）。**
   - 夹具 `OfflineWebDAVFormScene` 的密码恒为 `"preview-only"`（:1743），没有空/预填开关，也没有“起始可见”入口；“先点眼睛再输入”会把 A 与 B 叠加。
   - `OfflineMediaScene.swift:18` 是**无 default 的穷尽 switch**；新增场景不同步路由会直接编译失败。其余 `switch configuration.scenario`（LibraryViews 603/667/1103、OfflineMediaScene 587）均有 default。
   - AppTheme.swift 把 `.connection*` 显式路由到 `OfflineWebDAVFormScene`，其余场景进 `OfflineMediaScene`：新增探针场景走默认路径，**AppTheme.swift、NastartApp.swift 无需改**。
3. 对照梯分三层：裸 UIKit（U）→ 裸 SwiftUI（S）→ 正式表单（F），再加阶段 0 环境因子；一次差异只定位到“哪一层引入”，**不证明 UIKit 内部根因**。
4. 产品语义分三态（保留/草稿/替换）并给出按归因结果的决策表；默认推荐方向是显式“已保存 · 更改”入口（见 §3），需用户/Codex 产品确认，**不在本批实现**。
5. 完整文件范围 6 个（5 改 1 新增），均限 DEBUG 离线夹具与诊断，正式表单密码行默认行为不变；Release 不得含任何新增标记。
6. 设备请求：**只要 Codex 的模拟器窗口**（一台 iPhone + 一台 iPad，runtime 与已复现窗口对齐）；不碰真机、NAS、真实存储、普通根。

## 2 现象 A 与 B 的分离（在 0735 基础上的增量）

| | A：预填密码首次编辑被替换 | B：点眼睛后键盘/焦点丢失 |
|---|---|---|
| 触发 | 首次屏幕键盘插入；已见于显隐**之前**（11-02 诊断窗，secure 态）；10-31 iPad 候选窗里是显隐**之后**的首次明文插入 | 显隐切换瞬间 |
| 源码/记录已证 | 当时 token1 全程 firstResponder+secure，`clearsOnInsertion/clearsOnBeginEditing` 均 false，选区已知且为空，连续 2 次 `native.change`，SwiftUI 侧无焦点/显隐事件 | `if passwordVisible {TextField} else {SecureField}` 产生两个结构身份（LibraryViews.swift:1589–1591），切换销毁/新建 UITextField；`toggle` 只翻转布尔（:1597），无任何重新聚焦/交接；记录：token2 非 secure 且非 firstResponder → Swift 焦点 none → keyboard.willHide → token1 end |
| 未证 | 谁发起“清除”：UIKit 内部 / SwiftUI 回写 / content type 触发的系统行为；是否随设备类型或字号布局变化 | FocusState 被置 none 的内部原因；任何新写法是否能交接焦点 |
| 本批处理 | **归因**（阶段 0–2） | **不修**；仅用 F6 作叠加对照 |

一个需要在归因后重新评估、但**现在不作结论**的线索：10-31 的“单控件候选”在手机与 iPad 窗口都保持了键盘（即对 B 的目标有效），被判失败的依据是 iPad 窗口出现“首次明文输入替换原值”。若归因显示 A 是不依赖该候选的、原表单也存在的行为，则当时的失败判定混入了 A，B 的验收口径需要拆开（B：键盘/焦点保持且应用代码不改文本；A：另行验收）。候选源码未保留（仅私有区日志），不建议“复活”，只在 B 的方案阶段重新设计。

## 3 产品语义：保留 / 草稿 / 替换

定义（对已保存连接的“编辑 WebDAV”）：
- **保留已存密码**：用户没有主动修改密码 → 保存后凭据与原来一致，任何路径（聚焦、显隐、取消、失败重试、辅助字号切换）都不得无意改写。现状通过“预填=原值”实现，`editConnection` 对相同地址与凭据早返回（LibraryViews.swift:137）；加载方式是 `NetworkConnectionEditor.init` 每次重算都读钥匙串并把明文放进 `@State`（:1969–1971），这是隐私/性能副作用，不是本批问题。
- **编辑草稿**：用户在密码栏开始输入后，`password` 绑定就是草稿；取消/失败不写保险库（现状：仅成功保存才写）。
- **替换已存密码**：用户输入的新值整体取代旧值。

硬规则（不依赖归因结果）：
1. 应用层**不得强制追加**旧密码（不读取旧值再拼接）；也**不得**在聚焦/出现时偷偷清空来“模拟替换”。
2. 若产品需要“替换”语义，必须是**显式 UI 行为**，而不是依赖控件的隐含首插入行为。
3. 密码栏的测试判据用“可观察事件/类别”，不记录内容、长度、偏移。

按归因结果的决策（产品选择，需用户/Codex 确认；Claude 的推荐在最后一行）：

| 归因结果 | 含义 | 产品动作 |
|---|---|---|
| U1、S1、F1 都替换，F5（明文）追加 | 平台安全输入的首插入行为（secure 特异） | 不当应用缺陷；选 ①接受并在密文态提示“重新输入会替换已保存密码，不改请勿输入”，或 ②显式入口 |
| U1 追加，S1 追加，F1 替换 | 引入点在正式表单封装层 | 逐层补格（S2/S3）找到具体修饰/容器，修因；语义不变 |
| U1 追加，S1 替换 | 引入点在 SwiftUI SecureField 桥接 | 评估用显式入口规避，而不是包一层自写 UITextField（B 候选已显示其代价） |
| F3 追加而 F1 替换 | content type（含 username 对）触发 | 评估是否可在编辑场景使用更窄的 content type；需另批与系统 AutoFill 的取舍 |
| 全部不复现 | 环境依赖 | 记录条件；保留探针；不改产品 |
| **推荐** | 无论结果，**显式“已保存 · 更改”入口**让 keep/replace 在任何控件行为下都确定，旧密码不进入显隐，也可去掉每次重算读钥匙串的副作用；代价：不能“查看已保存密码”（若产品要求，需单独决定）。属后续批，不在本批 | |

## 4 受控对照矩阵

固定条件：每格**全新进程**；同一已启动模拟器实例内按序跑，格间 terminate；只用**屏幕键盘**（模拟器关闭 Connect Hardware Keyboard，Codex 记录其状态）；每次只做“点一次密码栏 → 点一个 ASCII 键（q）”；不用自动填充、粘贴、拖选；结果由操作员读屏幕圆点，**只记类别** `replaced / appended / other`，不记数量；不保存密码区域截图；预填值恒为夹具既有合成常量。每格 3 次重复：第 1、2 次带 `--offline-password-trace`，第 3 次**不带**（排除诊断引入，只记类别）。

### 阶段 0：环境因子（只跑 F1：`--offline-ui connection-edit`，预填，secure，content type 开）
2×2：{iPhone, iPad} × {`--offline-ui-text-size standard`, `large`(=accessibility2)}，各 3 次。
- 预期：能指出复现依赖设备类型、字号/布局路径，还是交互。
- 排除：把手机与 iPad 的差异直接归因给设备。
- 不能证明：任何机制；若四格都不复现（0/3），**停止，不进入阶段 1**，报告“不复现”。

### 阶段 1：对照梯（只在阶段 0 复现的环境 E* 内；其余格同 E*）

| 格 | 场景与参数（均加 `--offline-password-trace`，除第 3 次） |
|---|---|
| F1 | `--offline-ui connection-edit`（基线，与阶段 0 同环境同实例再测） |
| F2 | F1 + `--offline-password-initial empty` |
| F3 | F1 + `--offline-password-content-type off`（同时去掉用户名与密码两个 content type） |
| F5 | F1 + `--offline-password-start-visible visible`（启动即明文，避开切换，隔离 secure 特异性） |
| S1 | `--offline-ui password-probe-swiftui --offline-password-secure secure --offline-password-content-type off` |
| U1 | `--offline-ui password-probe-uikit --offline-password-secure secure --offline-password-content-type off` |

逐格判读：
- **F1**：预期与阶段 0 同。若 F1 此处不复现，整梯作废（不稳定），按 §7 处理。排除：—。不能证明：任何原因。
- **F2（空初值）**：空字段没有可替换内容，结果类别不可判，**只比较 `native.change` 次数与事件顺序是否与 F1 相同**。若 F2 同样 2 次 change → “两次 change”只是首插入的固有签名，削弱 0735 对 H1 的第二条支持；若 F2 为 1 次而 F1 为 2 次 → 2 次 change 与预填内容相关。排除：“两次 change 本身即证明清除”。不能证明：谁发起清除。
- **F3**：F3 追加而 F1 替换 → content type 参与（H3）；F3 仍替换 → 排除 content type。不能证明：`textContentType(nil)` 与“从未设置”等价；也不排除其他系统 AutoFill 入口。
- **F5**：明文态首次插入。F5 追加而 F1 替换 → 与 secure 特异有关（H1 方向）；F5 也替换 → 与 secure 无关，更像选区/封装/宿主，且这不是 B（无切换）。排除：显隐切换在 A 中的作用。不能证明：明文替换就是 SwiftUI 的问题。
- **S1**（裸 SwiftUI `SecureField`，只带必要的 `@State`，无 FocusState/NetworkInputStyle/privacySensitive/页面容器）：S1 替换 → 页面级封装不是必要条件；S1 追加而 F1 替换 → 引入点在正式表单封装层，进阶段 2 的 S2/S3。排除：Form 容器、FocusState、样式、`disabled(busy)`、`privacySensitive`（仅当 S1 替换时）。不能证明：SwiftUI `SecureField` 自身与 UIKit 的差别。
- **U1**（裸 `UITextField`，**无 delegate、无 SwiftUI 绑定回写、无 updateUIView 写文本**，初值只在 `makeUIView` 设一次）：U1 替换 → 裸 UITextField 在该环境就表现为替换；U1 追加而 S1 替换 → 引入点在 SwiftUI 桥接。排除：SwiftUI 对 UITextField 的任何写回。不能证明：U1 仍在 SwiftUI 宿主窗口内，**不是纯 UIKit 应用**；“替换”不证明 UIKit 内部先清再写。

结论对照表（U1,S1,F1,F3,F5 的类别）：

| U1 | S1 | F1 | F3 | F5 | 读法 |
|---|---|---|---|---|---|
| 替换 | 替换 | 替换 | 替换 | 追加 | secure 特异，平台层行为；不属应用缺陷（§3 上表第 1 行） |
| 追加 | 追加 | 替换 | — | — | 正式表单封装层引入，进 S2/S3 |
| 追加 | 替换 | 替换 | — | — | SwiftUI SecureField 层 |
| — | — | 替换 | 追加 | — | content type 参与 |
| 替换 | 替换 | 替换 | 替换 | 替换 | 与 secure/content type 都无关，更像宿主/选区；停，另设计（不得猜延迟） |

### 阶段 2（条件触发，各 3 次）
S2＝S1+两个 content type（含用户名兄弟输入框）；S3＝S2+正式行的完整修饰链与 `FocusState`；U2＝U1+content type；U3＝U1 改明文（secure 特异）；F6＝切换后立即按键（A+B 叠加，用于确认 B 不污染 A 的结论）；F5-IME＝明文态拼音单音节（secure 字段不接受组合输入，故 IME 只测明文），看 `markedTextPresent` 与首插入类别，**不记录候选内容**。

## 5 文件范围、起始哈希、最小改动

可写（完整）：下列 6 个。**不可写**：AppTheme.swift、NastartApp.swift、MineView、tvos、`NetworkConnectionEditor`/`NetworkLibraryAddView` 的行为、CredentialVault、project.pbxproj（NetworkMedia 是本地 Swift Package，新文件放进 `Sources/NetworkMedia` 即被收录，**该判断未编译验证，列入 Codex 编译检查**）、所有共享文档与登记。

| # | 文件（NetworkMedia 包内） | 起始 SHA-256 | 最小改动 |
|---|---|---|---|
| 1 | `LibraryViews.swift` | `a8282d4eb5d1e98e3d034f182aa1f9bab039c04a111355f1818eb5bd8f4e0b56` | §5 细化 2：DEBUG 事件、起始可见、content type 开关、夹具初值 |
| 2 | `PasswordInputDiagnostics.swift` | `e500f40ec7d290380967c9d6b1d5ea379444e62e4be7ea35ba725cedb33acc0d` | §5 细化 1：放宽观察谓词，新增 role/contentType/cell 字段 |
| 3 | `OfflineUIScenario.swift` | `7a8bd4d1d2bd4575a98901642d1aa71dcaf378293629294fc57be413aa36044c` | §5 细化 3：2 个新场景 + 严格解析的探针选项 |
| 4 | `OfflineMediaScene.swift` | `def22c8bdf813eba1682039fdeb0dfae76b2e728611b1df8a63436faad0ddfe6` | §5 细化 4：穷尽 switch 增 2 个 case |
| 5 | `OfflinePasswordProbeScene.swift（新增）` | 新文件（无） | §5 细化 5：U/S 对照场景 |
| 6 | `OfflineUIScenarioTests.swift` | `232bf390802db49a1d842bf5eaa819729ba1ff565242fd3e00d489cf466375ec` | §5 细化 6 / §6：新增解析与默认值单测 |

细化（均在 `#if DEBUG`；iOS 专属再加 `os(iOS)`）：
1. **PasswordInputDiagnostics.swift**：(a) `observes` 与 native 采集由“`textContentType == .password`”改为“探针窗口内全部 `UITextField`，每次最多 8 个”；(b) 每个控件新增三个布尔/枚举字段：`role`（取 `accessibilityIdentifier` 的末段，仅白名单 `password/username/name/address/port/path/probe`，否则 `other`）、`contentTypePassword`、`contentTypeUsername`；(c) 每行加 `cell`（来自 `OfflineUIConfiguration` 解析后的标签）；(d) 新事件 `swift.password.changed` 沿用 `record`，不带值。**保持**：0600、1024 上限、弱映射、不读 text/placeholder/长度/选区偏移/通知内容、不改 delegate、不加焦点赋值/重试/定时器。字段白名单随之扩大为：原有字段 + `role/contentTypePassword/contentTypeUsername/cell`，Codex 的 JSON 白名单核对需同步。风险 R1：SwiftUI 是否把 `accessibilityIdentifier` 落到 `UITextField` 上**未验证**；若否，`role` 全为 `other`，改用 begin 事件的 token 与 `secure` 区分，不因此扩大读取。
2. **LibraryViews.swift**：(a) 已有 `#if DEBUG && os(iOS)` 块内加 `.onChange(of: password) { _ in passwordTrace("swift.password.changed") }`；(b) `@State private var passwordVisible = Self.initialPasswordVisible`，静态属性在 DEBUG+iOS 读 `OfflineUIConfiguration` 解析结果，其余恒 `false`（默认行为不变）；(c) 密码行 `.textContentType(passwordContentTypeEnabled ? .password : nil)`、用户名同理，计算属性在非 DEBUG 恒 `true`——**默认路径行为与现状相同**；残余风险：Release 里该修饰由字面量变为常量折叠表达式，行为等价但不是逐字节相同；(d) `OfflineWebDAVFormScene`：`password` 初值按 `passwordProbe.initial` 取 `"preview-only"` 或 `""`；既有 `enableOfflinePasswordDiagnostics()` 扩展里同时下发选项。**不动**：`Group{if/else}` 结构、`focused`、`submitLabel`、`onSubmit`、toggle、`busy/onDisappear` 钩子、编辑器与添加入口。
3. **OfflineUIScenario.swift**：新增 2 个场景 `password-probe-swiftui`、`password-probe-uikit`；新增 `PasswordProbeOptions`（`initial prefilled|empty`、`secure secure|plain`、`contentTypes on|off`、`startVisible hidden|visible`、`cell` 标签）与 `OfflineUIConfiguration.passwordProbe`，`init` 增加带默认值的参数，已有调用方不变。解析沿用现有 `value(...)` 严格规则：单次出现、必须有值、值不以 `--` 开头、取值属于枚举，否则整体落 `.invalid`；`secure` 仅限探针场景、`startVisible` 仅限 `connection*` 场景，用错即 `.invalid`；`cell` 仅允许 `^[A-Za-z0-9-]{1,16}$`。默认值＝正式（预填/secure/开/隐藏）。
4. **OfflineMediaScene.swift**：穷尽 switch 增 2 个 case：iOS → `OfflinePasswordProbeScene`；tvOS（该文件含 tvOS 编译）→ 复用现有 `state(...)` 说明“仅适用于 iPhone/iPad”并保持隔离。
5. **OfflinePasswordProbeScene.swift（新增，`#if DEBUG && os(iOS)`）**：纯合成页，顶部可选 `.username` 兄弟输入框（受 `contentTypes` 控制），下方是被测密码控件：SwiftUI 版＝`SecureField`/`TextField`+`@State`；UIKit 版＝`UIViewRepresentable`，**无 binding、无 delegate、`updateUIView` 不写文本**，仅按选项设置 `isSecureTextEntry`/`textContentType`/一次性初值；底部固定标注“离线界面测试 · 合成密码探针 · 归因实验，不是表单验收”；`--offline-password-trace` 时 `.background` 挂既有 `PasswordInputDiagnosticsProbe`。不构造 model/store/vault/client，不读钥匙串。
6. **OfflineUIScenarioTests.swift**：见 §6。

## 6 验证与 Release 排除

必须通过（Codex 运行；**我未运行**）：
- 既有 `OfflineUIScenarioTests` 4 项（其中“每个场景都有隔离配置”会自动遍历新增场景）、`WebDAVConnectionFieldsTests`（上次 6/6）不回退。
- 新增单测（无 UIKit 依赖，macOS 主机可跑）：①带 `--offline-password-*` 但无 `--offline-ui` → 仍为 `nil`（不请求离线根，也不回落任何登录/NAS）；②各参数的重复/缺值/未知值/值以 `--` 开头 → `.invalid`；③`secure` 用在 `connection*`、`startVisible` 用在探针场景 → `.invalid`；④默认 `passwordProbe == .production`，且 `connectionEdit` 的默认配置不带任何探针差异；⑤`cell` 标签合法/非法；⑥新增场景 + 严格参数的 `requested(arguments:)` 不产生 `.invalid`。
- 六配置编译（沿用前几批口径）：移动/TV 模拟器 Debug、移动/TV 设备 Debug 无签名、移动/TV Release 无签名。
- **Release 排除**：Release 移动与 TV 主二进制 `strings` 中不得出现 `--offline-password-`、`password-probe`、`OfflinePasswordProbe`、`swift.password.changed`、`Nastart-Offline-Password`、`contentTypePassword`；旧 `PasswordInputDiagnostics` 标记原本就不含。
- 诊断 JSONL 核对：权限 0600、事件 ≤1024、字段在扩大后的白名单内、**不含**合成字面量（`preview-only`、`preview-user`、主机、路径）；关闭 trace 的重复无文件产生。
- 无法由单测覆盖：UIKit/SwiftUI 实际插入行为只能靠 §4 的窗口；不得把窗口结果写成“测试通过”。

## 7 停止条件

- 阶段 0 四格均 0/3 复现 → 停，报告“不复现”，保留探针，不扩梯。
- 同一格 3 次类别不一致 → 记“不稳定”，最多再做 1 轮 3 次；仍不一致则停，不下因果结论（沿用“两轮无改进即停”）。
- 需要改正式密码行的聚焦/提交/存储逻辑，或要加延迟/重试/定时器 → 停止，回报，**不提第三轮延迟聚焦**。
- 需要读文本、长度、选区偏移才能判断 → 停止，另请决定。
- 编译失败两轮无进展 → 交源码、失败、未验项。
- 任何需要真机、NAS、真实存储、普通根、剪贴板、粘贴或自动填充的动作 → 停止并书面请求。
- 事件达到 1024 上限 → 记截断，不扩容。

## 8 给 Codex 的设备/构建请求（模拟器，无真机）

- 窗口：一台 iPhone 模拟器 + 一台 iPad 模拟器，新建实例；runtime 须与已复现窗口一致——11-02 诊断窗为“A16/iOS27 模拟器”、10-31 iPad 窗的具体型号/runtime 我只在文字里读到“iPad 大字号”，**请 Codex 从私有结果 JSON 取出并对齐，我没有读这些 JSON 的结构化内容**。
- 源码配置：本批补丁应用到含脏改动的同源独立工作区后的 Debug 模拟器构建；独立 DerivedData；占用 1 个重构建位，不与 Codex 其他构建并行。
- 合成输入：仅夹具既有常量；每次启动：terminate → 带参数启动 → 等页面 → 点密码栏一次 → 屏幕键盘点 `q` 一次 → 读圆点类别（不存图）→ 取匿名 JSONL 摘要 → terminate。
- 动作量：阶段 0 共 12 次启动；阶段 1 共 18 次；阶段 2 至多 18 次。每次启动 ≤2 分钟，总窗口 ≤90 分钟；超时记未完成。
- 通过/判定：本批无产品“通过”判定。完成标准＝每格有 3 次一致类别或标“不稳定”，且 §6 的 JSONL 核对成立。结论只写到 §4 的“读法”，不写 UIKit 内部根因。
- 清理：finally terminate；删除自建模拟器；删除临时 JSONL；偏好哨兵不变；不动用户其他模拟器/缓存；不接触 13/Pad/TV/18、NAS、VPN、系统与签名；无网络需求。
- 仍待 Codex 先做：第五批后的新正常包与 13/Pad 的身份/签名/保留数据安装，不属本批窗口。

## 9 流程与交接

1. Codex 先准备含脏改动的同源独立工作区，并登记 §5 的 6 个文件（5 改 1 新增）与起始哈希；我开工前重算六个哈希，不一致即停。
2. 登记完成后我**直接实施**，无需用户再说“继续”；不触碰共享摘要/登记/需求状态。
3. 交付：`…-CLAUDE-BATCH7-DELIVERY.md`（起止哈希、完整改动、命令、未运行项、风险）+ 补丁导出到 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch7/`（对集成目录先 `git apply --check`）；结束时声明写入释放。
4. 需要 Codex 同步（我不改）：PROGRESS 与当前交接中“第六批后下一步”改为本批方案；登记新增 `claudeBatch7`（若采用）；JSONL 白名单核对脚本同步新字段；记录“归因实验≠表单验收”。
5. 额度不足时：交源码/补丁/失败/未验项与清理，由有额度一方接续；额度变化不自动释放文件。

## 10 之后的顺序

密码归因结果到手后，按 §3 决策（B 的方案在其后）；与密码文件**互不重叠**的离线闭环可并行排队，各自读源码后再出完整文件范围，本报告不预设文件：真实设置/偏好、返回位置保留、分享完成/取消、缓存取消。NAS 恢复后的大文件/首帧/seek/弱网优化仍是高优先级，待 NAS 恢复并由用户确认后再排窗口；当前不触碰 NAS 及任何服务探测。

## 11 未证 / 未运行

- 全部实验、编译、测试：**未执行**。H1–H4（见 0735）仍未证。
- “手机追加、iPad 替换”是否由字号/布局路径造成：未证（阶段 0 解决）。
- `accessibilityIdentifier` 是否落到 `UITextField`、`textContentType(nil)` 与未设置是否等价、新文件被包自动收录：未验证。
- 钥匙串来源预填与夹具字面量预填是否等价：离线夹具**不能**验证（不得读钥匙串）；两者都经 `State(initialValue:)`，等价只是推断，留给后续真实编辑窗口。
- 没有读取或记录任何密码明文、长度、精确选区、真实凭据；无设备/构建/NAS 占用；仅新增本报告。
