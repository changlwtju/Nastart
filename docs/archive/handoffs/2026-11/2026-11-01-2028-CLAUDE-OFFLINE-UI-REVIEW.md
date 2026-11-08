# Claude Code 首批：非 NAS 页面静态审查（大字／可访问性／状态说明）

负责人：Claude Code。时间：2026-11-01 20:28–20:45（Asia/Shanghai）。性质：**纯静态源码阅读**。未构建、未运行测试、未启动模拟器或真机、未访问 NAS/凭据/私有证据；唯一写入为本报告。

## 基线

- HEAD `4de732d`，工作区 dirty 289 项（含大量已接受未提交修改）。审查的是当前目录内容，不是 HEAD。
- 所读文件（SHA-256 前 12 位／行数）：
  - `ios/Nastart/Nastart/Features/Mine/MineView.swift` a7120f7e1177／1452
  - `ios/Nastart/Nastart/Core/Design/AppTheme.swift` e80c41ec6d6d／1581（仅 grep 字号/动态字体相关，未通读）
  - `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAVConnectionFields.swift` 6f23dcf60a67／46
  - `tvos/NastartTV/Sources/TVNASViews.swift`（约 51–345 行：设置、连接管理、连接卡片）
  - 另读 `LibraryViews.swift` 1525–1620（WebDAV 表单）与 `TVViews.swift` 的 grep 结果。
- 协作文件／交接／总账哈希：AGENTS b80348a2bb1e、协作文件 d3b7365a37f1、交接 4f78f4694016、总账 c1accb33deb4。
- 未读完：MineView 520–1360 的大部分（Plus/外观/播放/iCloud/隐私/帮助/诊断列表）、AppTheme 主体、TVNASViews 其余部分。下面结论只覆盖已读范围，没有发现 ≠ 没有问题。

证据等级：全部为【静态推测】。无单元、模拟器、真机证据。已有待验项以总账为准，本报告不新建编号。

## 问题清单

### A. 手机「我的」页退出登录旁的信息按钮不可用（建议优先）
- 位置：`MineView.swift` 第 100–112 行 `ContextInfoButton`，使用处第 44 行。
- 现象（静态）：它只是一个 `Image`，**没有 Button、没有点击动作**（全文件无 `onTapGesture`）；说明文字只写在 `.help(...)` 和 `accessibilityValue`。`.help` 在 iOS 触屏上不显示，因此**视力正常的触屏用户看不到“退出登录会怎样”的说明**。VoiceOver 能读到值，但该元素没有 button 特征，也无法聚焦激活说明。
- 次要：图标固定 `.system(size: 17)`、32×32 点击区，不随动态字体变化，也小于 44pt 触控建议。
- 最小修复：改为 `Button` 弹出 popover/alert 显示 `message`，加 `.accessibilityAddTraits(.isButton)` 或直接用 Button；点击区至少 44×44；字号用 `.font(.body)` 之类相对字号。
- 拟改文件：`MineView.swift`（单文件）。
- 需要的验证：模拟器 + accessibility2 截图（点击前后）、VoiceOver 手动；不需要 NAS。

### B. 诊断页三个操作格在大字下会被截断
- 位置：`MineView.swift` 1369–1395 `DiagnosticActionTile`，使用处 1189／1201／1212。
- 现象（静态）：标题 `.font(.caption)` + `lineLimit(1)` + `minimumScaleFactor(0.75)`，三格横排等宽。大字号/英文（“Export Diagnostic Summary”）下很可能被截成省略号，且缩放下限只到 0.75，不足以补偿。操作含“导出／复制／清除”，截断后可能无法区分。`minHeight: 52` 不随字号增长。
- 最小修复：大字号时允许 `lineLimit(2)` 或改纵向排列（`ViewThatFits`／按 `dynamicTypeSize.isAccessibilitySize` 切换）；保证 `accessibilityLabel` 已有（1194/1206/1219 行已有，保留）。
- 拟改文件：`MineView.swift`。验证：模拟器 accessibility2/3，中英各一。

### C. 诊断摘要三列指标在大字下拥挤
- 位置：`MineView.swift` 1398–1432 `DiagnosticSummaryView`、1434–1451 `DiagnosticSummaryMetric`。
- 现象（静态）：三个指标 `HStack` 等宽无换行策略；大字号下“警告／错误”等标题会折行或挤压，数值与标题可能分离。时间行 `.font(.caption)` 并在 1431 行被钉死 `.dynamicTypeSize(.large)`（其它几处 1351／1458 同类写法），即**这些文字故意不随系统字号放大**，与“大字”目标相反。
- 说明：这可能是既有有意取舍（用于离线预览截图稳定）；需要核对该 `.dynamicTypeSize(.large)` 是预览限定还是正式入口也生效。
- 最小修复：正式入口去掉钉死或限定到预览；大字号时指标改纵向。验证同上。

### D. 主题画廊卡片
- 位置：`MineView.swift` 195–250 附近。
- 现象（静态）：描述 `lineLimit(2)` 在大字号下会截断主题说明；整张卡片是 `NavigationLink`，**未见 `accessibilityElement(children: .combine)`／显式标签**，装饰性预览图（`LaunchpadThemePreviewArtwork`，大量固定 caption2 小字）在文件内未见 `accessibilityHidden`，读屏可能逐个读出预览里的“Nastart NAS / DSM / 指标”等假内容。
- 最小修复：预览 artwork 加 `.accessibilityHidden(true)`；卡片合并标签并包含“当前使用／Plus”状态；大字号放宽 `lineLimit`。
- 需要验证：VoiceOver 读序（仅真机或模拟器手动）。**这是未证实推测，未见 grep 命中不等于没有写在别处**（例如 artwork 内部或修饰器里）。

### E. WebDAV 连接表单的错误文案为硬编码中文，且不本地化
- 位置：`WebDAVConnectionFields.swift` 38–41 行 `errorDescription`；表单标签/占位在 `LibraryViews.swift` 1531 起大量字面中文。
- 现象（静态）：NetworkMedia 包整体没有 Localizable 资源（目录中未见 Resources），英文系统下该页仍是中文，与主 App 的 en/zh 本地化不一致。需确认这是否已在总账中作为既定范围。
- `FieldError.host` 同时用于“URL 解析不出 scheme/host”（第 14 行）和“地址栏格式不对”，两种情形显示同一句“地址栏只填写域名或 IP…”，对**编辑已有连接**时的失败原因有误导。
- 最小修复：错误枚举拆分一项 `.invalidSaved`；本地化若在范围内另议。验证：纯逻辑单元测试（不需要 App）。
- 良好之处（保留）：端口 1–65535 校验、IPv6 括号处理、拒绝 userinfo/路径混入主机，表单字段各有 `accessibilityLabel/Hint`，密码显隐按钮有标签，错误区 `accessibilityElement(children: .combine)`。

### F. TV 设置／连接页
- 位置：`TVNASViews.swift` 51–110（设置）、111–150（连接管理）、288–306（连接卡片）。
- F1：`disconnectError`／`error` 设置后**没有任何清除路径**，再次操作成功后旧红字仍留在页面上；且直接显示 `error.localizedDescription`，可能是系统英文原文（与“只读、简明中文说明”的风格不一致）。最小修复：每次操作前清空；映射为简短中文。
- F2：`TVConnectionPanel` 的按钮行是固定 `HStack(spacing:18)`，卡片为两列。TV 上用户可调大字时，“更换连接 + 断开连接”两个按钮可能超出卡片；说明文字 `minHeight: 54` 固定、`lineLimit(2)` + 中间截断，长地址只剩两端（有意，但读屏是否读全地址未核）。验证：TV 模拟器或真机，但 TV 真机现被签名阻塞，仅能模拟器。
- F3：`TVSettingsView` 没有 `onExitCommand`，而 `TVConnectionsView` 有 `onExitCommand { dismiss() }`；返回行为两页不一致，是否为导航栈默认已覆盖需真机遥控验证（已有历史合成遥控证据，不能代替当前包）。
- F4：命名小问题：`TVConnectionsView` 的标题上挂 `accessibilityIdentifier("tv.connections.back")`，标识与实际元素（标题）不符，可能误导 UI 测试。
- 良好之处：`TVSavedConnectionSummary` 注释和文案明确“已保存配置≠可达”，状态用“已保存登录配置／已保存授权”，没有冒充在线状态。

## 与既有待验项的关系

- 密码显隐、真实分享完成、完整读屏、缓存取消等已在总账为开放项；本报告 A–E 中**A、B、D 未在交接中见到对应记录**，不确定是否已在别处登记，请 Codex 对照总账决定是否登记。本报告不改任何编号。
- 当前交接提到“accessibility2 两静态窗已看，三开关/完整说明/按钮均在初始视口”——那是导出 Form 页，不含 A–D 涉及的组件；因此不矛盾。

## 建议的实施批（由 Codex 分配后再做，Claude 暂不改代码）

| 批 | 内容 | 文件（需完整文件独占） | 验证 |
| --- | --- | --- | --- |
| 1 | A＋B＋C（手机「我的」页） | `MineView.swift` | 模拟器 accessibility2/3 截图 + 现有 UI 测试；不连 NAS |
| 2 | E（错误枚举拆分，纯逻辑） | `WebDAVConnectionFields.swift` + 其单元测试 | Swift Package 单元测试 |
| 3 | F1＋F4（TV 小修） | `TVNASViews.swift` | TV 模拟器；不碰真机 |

D、F2、F3 需要先有更多证据（读屏／遥控），建议放到设备窗口再验，不先改。

## 资源与清理

- 未创建进程、未占用设备、未写缓存；仅对工作区新增本报告。
- 源码文件审查前后哈希见开头；结束时已复核（见下行）。

复核：见本文件末尾追加的“结束哈希”。

## 结束哈希（20:45 复核）

MineView.swift a7120f7e1177、AppTheme.swift e80c41ec6d6d、WebDAVConnectionFields.swift 6f23dcf60a67，与开头一致，审查期间这三个文件未变化。TVNASViews.swift 未记录起止哈希，审查期间可能被 Codex 改动，引用行号以实际文件为准。
