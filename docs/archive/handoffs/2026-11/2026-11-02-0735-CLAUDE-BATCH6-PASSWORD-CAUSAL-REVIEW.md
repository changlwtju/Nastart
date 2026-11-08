# Claude 第六批：密码首次编辑替换与显隐丢焦点的只读因果审查

2026-11-02 07:35（Asia/Shanghai）。依据[第六批分配](../../../development/CLAUDE-BATCH6-ASSIGNMENT.md)。只读源码与已分享文档；**未运行任何代码、未编译、无模拟器/真机/NAS/凭据/私有 trace**。下文“已证”仅指**源码事实**或**已分享记录里已有的观察**；“未证”指我没有证据的推断。没有新的因果证据时如实写未确定，不提第三轮延迟聚焦。

## 起止哈希（审查期间未变）
LibraryViews.swift `a8282d4e…56`、PasswordInputDiagnostics.swift `e500f40e…0d`、OfflineMediaScene.swift `def22c8b…e6`（均与登记一致）；另读 SourceContext.swift `2c83e033…4a`、OfflineUIScenario.swift `7a8bd4d1…6c`。已读：[选区诊断](2026-11-02-PASSWORD-SELECTION-DIAGNOSTICS.md)、[原事件诊断](../2026-10/2026-10-31-PASSWORD-INPUT-EVENT-DIAGNOSIS.md)的文字内容（结构化 JSON 未逐项展开，只核对其存在）。

## 1. 把两个现象分开

**现象 A：预填密码首次编辑被替换（发生在任何显隐之前）。** 已有观察：诊断窗口里初始合成密码在首次点屏幕键盘字符后变为单字符；token1 全程 firstResponder 且 secure；`selectionKnown/selectionEmpty` 为 true、`clearsOnInsertion/clearsOnBeginEditing` 为 false；连续两次 `native.change`；无显隐事件。
**现象 B：点眼睛后焦点/键盘丢失。** 已有观察：显隐后出现 token2（非 secure、非 firstResponder），Swift 焦点回 none，随后 `keyboard.willHide`、token1 `native.end`。

两者**不共享已证的原因**：A 发生在未切换前；B 的控件替换发生在切换时。把 B 的修复（单控件、延迟聚焦、改 clears 参数）用于 A，已被两轮证据否定，本批不再建议。

### A 的因果假设（未定）
- **H1 原生安全输入的首次插入行为**（UIKit 内部先清空再插入）。支持：①发生在 SwiftUI 侧未见任何焦点/State 重置事件之前；②“一次按键两次 `native.change`”与“先清除、再插入”两次文本改动吻合；SwiftUI 对 UITextField 的程序化赋值通常不会触发 `textDidChange`，所以若是 SwiftUI 回写覆盖，不太会表现为两次 native.change（这是我的推断，未运行验证）。反对/矛盾：已分享记录里手机上“单控件候选”在同样预填 12 字符后**追加**成功、iPad 同候选替换，说明并非在所有环境稳定复现，不能下“所有 secure 字段都如此”的结论。`clearsOnInsertion=false` 不能排除这种内部行为，也无法证明它存在。
- **H2 SwiftUI 回写/重建覆盖**：SecureField 的 binding 把旧值再写回。反对：前述两次 `native.change` 与此不太吻合；支持：无。需要“SwiftUI 侧是否观察到中间空值”的事件才能判。
- **H3 `textContentType(.password)`（含相邻 `.username`）触发系统口令/AutoFill 启发式**：两个分支均设置，源码可见（LibraryViews.swift:1592）；是否影响首次插入**无任何证据**，只是尚未被控制变量排除。
- **H4 与预填来源相关**：夹具所有 `connection*` 场景统一 `@State password = "preview-only"`（12 字符，与 iPad 记录的“12 字符”一致），正式编辑器由钥匙串读出，正式“添加”入口为空。两类预填路径是否同一行为**未证**。

### B 的因果（源码已证 + 记录已证）
源码已证：LibraryViews.swift:1589–1593
```
Group { if passwordVisible { TextField(…) } else { SecureField(…) } }
  .textContentType(.password).focused($field, equals: .password)…
```
`if/else` 在 ViewBuilder 中产生两个不同结构身份的分支；切换时 SwiftUI 销毁一个 UITextField 并创建另一个。`toggle` 只翻转 `passwordVisible`（1597），**没有任何代码**在切换后把 `field` 重新指向 `.password`，也没有与新控件的焦点交接。已有观察（token1→token2、Swift 焦点 none、willHide/end）与此一致。**已证**：控件被替换且焦点未交接；**未证**：SwiftUI 内部为什么把 FocusState 置 none（是移除时重置，还是别的路径），以及换成别的写法是否会交接。

## 2. State/binding/身份重置点（正式 vs 夹具）
- **未发现重置 password 的代码**：全仓 `password =` 赋值只有——夹具取消按钮 `password = ""`（OfflineWebDAVFormScene toolbar）、添加/保存后 `password = ""`、`NetworkConnectionEditor` 保存成功后 `password = ""`。均不在编辑途中触发。
- `NetworkConnectionEditor.init`（LibraryViews.swift:1968–1971）用 `State(initialValue:)` 预填；SwiftUI 只在身份首次创建时采用，父视图重算不会重置值（但每次重算 init 都会再读一次钥匙串——性能/隐私副作用，非本问题）。
- 正式表单三个入口（编辑器、添加 `NetworkLibraryAddView`、夹具）共用同一个 `NetworkWebDAVConnectionForm`，所以密码行结构相同；**差别仅在预填**：编辑器预填（钥匙串）、添加为空、夹具全部预填 `"preview-only"`。因此夹具**不能**区分“空 vs 预填”，也不能区分正式编辑器与添加入口。
- `onChange(of: busy){ if $0 { passwordVisible = false } }`、`onDisappear { passwordVisible = false }` 只改显隐，运行期间在未 busy 的编辑中不会触发。
- `inputRow` 在辅助字号时换用 VStack/HStack 分支（SourceContext/LibraryViews inputRow）：**字号在编辑中变化**会替换整行身份，属另一条丢焦点路径；已记录的窗口是启动时固定字号，不是本现象的原因，仅作记录。
- 夹具与正式差异：夹具由 `OfflineWebDAVFormScene` 包装并多一行底部合成标注、`NetworkConnectionFormActions` 的提交只做格式校验；密码行代码**完全相同**（同一个 `NetworkWebDAVConnectionForm`）。诊断 Probe 经 `.background` 加入，不改变密码行身份。

## 3. 预填安全字段首次编辑的产品语义
现有证据**不足以**判断“首次编辑替换已有密码”是原生安全编辑的正常行为还是应修缺陷：既没有原生对照，也没有产品契约（编辑页文案未说明“点击密码框即重新输入”）。需先回答：①纯 UIKit 对照是否同样替换；②产品期望：编辑已保存连接时，点密码框输入应当“整体替换”还是“在原值上编辑”。需要强调：替换本身**不等于**存储丢失（保存要点“验证并保存”），但若用户先点眼睛再改一字，预期是在可见原值上编辑，此时静默替换会造成键入丢失感；这与 B 的键盘丢失一起仍是**开放反例，不能因“可能是原生行为”关闭**。

## 4. 最小且有鉴别力的受控实验方案（未运行）
目的：回答“A 的替换由谁产生”，同时给 B 提供对照。**结果用屏幕可见的圆点数由操作员人工读取，不记录长度/内容/偏移**；记录仅用匿名事件。禁止用更易通过的宿主冒充表单验收，下列纯 UIKit 对照只用于“归因”，不得写成验收。

固定：同一模拟器型号/系统、全新实例、无普通根/真实存储；每格全新进程；只用屏幕键盘；每格只做“点密码框 → 按一个 ASCII 键”，另做一格组合输入（拼音）与已提交 ASCII 对照；显隐前后各测一次。

| 格 | 控件 | 初始密码 | textContentType(.password) | 状态 |
|---|---|---|---|---|
| N1 | 纯 UIKit `UITextField`（DEBUG 对照场景） | 预填 | 无 | secure |
| N2 | 同上 | 空 | 无 | secure |
| N3 | 同上 | 预填 | 无 | 非 secure（对照 secure 特异性） |
| F1 | 正式表单（当前 Group 条件分支） | 预填 | 有（现状） | secure |
| F2 | 正式表单 | 空 | 有 | secure |
| F3 | 正式表单 | 预填 | **去掉**（仅此格） | secure |
| F4 | 正式表单 | 预填 | 有 | 先点眼睛使其可见，再按键 |

观察（匿名）：每次按键的 `native.change` 次数与顺序、`markedTextPresent`、`selectionEmpty`，以及新增的 DEBUG-only 事件 `swift.password.changed`（仅事件，不含值）。判读：
- N1 替换且为 2 次 native.change，N2 追加，N3 追加 → **H1（原生 secure 首次插入）成立**，A 非代码缺陷，转入产品契约讨论。
- N1 追加而 F1 替换 → 问题在 SwiftUI/封装层；再看 F1 的 `swift.password.changed` 次数，若无“中间值”事件而只有最终，倾向 UIKit 先清再写；若出现额外回写事件，倾向 H2。
- F3 追加而 F1 替换 → H3（content type）成立。
- F2 无替换（本来为空，只能看有无 2 次 native.change 的签名）→ 校准“两次 change”是否本就是 secure 首插入的固有签名。
- F4 可检验“可见后首次输入”与 B 是否叠加。
- 每格各取一次“有诊断/无诊断”，排除诊断引入。

## 5. 若需要新增事件或桥接（本批不实施）
拟改完整文件（均为 DEBUG/#if iOS 范围，Release 不得含）：
1. `PasswordInputDiagnostics.swift`：新增匿名事件 `swift.password.changed` 记录入口（不读值）。
2. `LibraryViews.swift`：`NetworkWebDAVConnectionForm` 在 `#if DEBUG && os(iOS)` 内增加 `.onChange(of: password)` 仅调用 `passwordTrace`；`OfflineWebDAVFormScene` 增加可控“初始密码空/预填”开关；F3 需一个**仅 DEBUG** 去除 `textContentType` 的开关（正式默认不变）。
3. `OfflineUIScenario.swift`、`OfflineMediaScene.swift`、`OfflineUIScenarioTests.swift`：新增场景枚举及路由、测试枚举同步（含非法参数不回落普通根）。
4. 纯 UIKit 对照场景放入新增 DEBUG 文件，不进入正式表单。
必须保留：正式表单密码行代码默认不变、不增加聚焦赋值/定时器/重试、不读文本长度或偏移、0600 临时 JSONL 与 1024 事件上限、Release 不含 marker。风险：对照/夹具改动易被误当验收；每份结果须标明“归因实验”。

## 结论
- **已证（源码/已有记录）**：B 的触发是 `if/else` 造成控件替换且无焦点交接；A 发生在显隐前、SwiftUI 侧无焦点/State 重置事件；夹具预填恒为 `"preview-only"`，不能区分空/预填；未发现编辑途中重置 password 的代码。
- **未证**：A 的发起方（UIKit 内部 vs SwiftUI 回写 vs content type）；“原生安全字段首次插入替换”是否成立；FocusState 置 none 的内部原因。
- **未运行**：全部实验；本报告无新运行证据，也不由大括号计数或旧报告冒充。
- 没有占用设备/构建/NAS/后台任务；本批仅新增本报告，不改共享摘要。
