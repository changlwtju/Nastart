# Claude（本地会话）：仅 DEBUG 离线场景 `local-library`

2026-11-02 16:28（Asia/Shanghai）。按[本地开工单](../../../development/CLAUDE-LOCAL-START-HERE-2026-11-02.md)第 2 步执行。本批没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## 改动（主目录，5 个文件；第 5 个为交互中发现的海报卡修复）

- `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryPosterWall.swift`：改前 e6a9dd46…0835 → 改后 79b4ea39…e569。

| 文件 | 改前 SHA-256 | 改后 SHA-256 |
| --- | --- | --- |
| `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/OfflineUIScenario.swift` | 05710a31…a4f0 | 8e4989af…33c6b5 |
| `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/OfflineMediaScene.swift` | 5ad6fc93…a77 | b4d2d275…2a9d |
| `ios/Nastart/Nastart/Core/Design/AppTheme.swift` | c8e9b0d6…6d | bc4055fa…b21b |
| `ios/Nastart/Packages/NetworkMedia/Tests/NetworkMediaTests/OfflineUIScenarioTests.swift` | b18d585d…ccf | 5e993c3f…c41c |

- 新增 `Scenario.localLibrary = "local-library"`，带说明注释：仅 iOS；承载真实“存储与媒体”页；与其他场景不同，它使用本安装的正式媒体库存储。
- `AppTheme.swift`：`NastartOfflineUIRoot` 在 iOS 上把 `local-library` 路由到新的私有视图 `NastartOfflineLocalLibraryScene`，内容为 `NavigationStack { networkMediaLibraryView(nas: nil, appearance: …) }`，不传 `services`、`destinations`，因此没有 NAS 媒体入口、文件入口和播放目标；底部横幅“离线界面测试 · 仅连接手动添加的本机 WebDAV”（`private-host-1.example.invalid-library.banner`）。
- `OfflineMediaScene.swift`：switch 无 default，补 `.localLibrary` → “此场景仅适用于 iPhone 与 iPad”（tvOS 会走到这里）；顶部“从不构造 NetworkLibrariesModel”的注释改为说明 `local-library` 是唯一例外，且在 iOS 上由 App 根承载、不进入此视图。
- 测试：新增 `testLocalLibrarySceneIsExplicitAndRejectsPasswordFlags`（显式参数解析、密码参数误用落 invalid、非 `--offline-ui` 不进入）。原 allCases 循环自动覆盖新场景。
- 开工单列出的 `LibraryViews.swift:603/667/1103` 三处 switch 均有 `default`，无需改动；tvOS `NastartTVApp.swift` 只用 `==`/`contains`，也无需改。

## 验证

- 包单测（macOS，独立 scratch）：`OfflineUIScenarioTests` 9 + `WebDAVConnectionFieldsTests` 6 = **15/15 通过**。
- iOS Simulator Debug 构建：**通过**。磁盘只剩约 7.3GiB，经用户在本会话明确同意，借用 Codex 已闲置的 `DerivedData/Nastart-Codex-SavedPassword-20261102/mobile` 及其 SourcePackages 做增量构建，**覆盖了 Codex 那份模拟器 Debug 产物**（新产物 = 其源码 + 本批 4 文件）。首次（无签名）主二进制 `0225d23a…95f0`、debug.dylib `591bbef0…262c`；最终（ad-hoc 签名＋海报修复）debug.dylib `4558cfb1b38882bd27731c6aca0d477119180c83e09bb76e589ca50571a3111c`。构建后剩余约 7.3GiB。
- 装到自建模拟器 `Claude-PW-iphone`（iPhone 17 Pro / iOS 27.0），`--offline-ui local-library` 启动：显示真实“存储与媒体”页（连接管理、添加媒体文件夹、只读说明），底部横幅正常，没有 NAS 入口。截图在本机证据目录 `01-home-empty.png`。
- 17:08–17:14 用户批准模拟器操控后补做交互（证据 `03`–`15`）：
  - 表单 HTTP / `127.0.0.1` / `8089` / 匿名 →“连接并选择文件夹”列出 电影/动漫/剧集 → 加入根目录 → 媒体库显示“92 个视频文件”，与夹具一致。
  - **首次加入失败**“无法读取或保存本机媒体库”：诊断 `credential-add` OSStatus **-34018**（errSecMissingEntitlement）。原因是 `CODE_SIGNING_ALLOWED=NO` 的模拟器包无钥匙串权限，**不是产品缺陷**。改用 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`（Sign to Run Locally）增量重建后成功。之后在模拟器上测钥匙串路径都应 ad-hoc 签名。
  - 海报墙：电影/电视剧/动漫分类、缺海报占位“暂无封面/暂无剧集海报”、超长标题两行省略且行对齐，均正常。
  - 详情：NFO 片（013）显示年份、标签、简介；无 NFO 片（014）无简介；“此来源暂不能播放”符合本场景不传播放目标。
  - 返回保位：从第 4–6 行进入详情后返回，仍在同一行，约 10pt 上漂（轻微，待返回保位专项）。
  - **发现并修复 P2**：iOS 海报卡第二行（年份/“2 季 · 8 个视频文件”/“待确认”）首字被左下圆角裁掉（“2099”显示为“ʔ099”）。根因 `NetworkPosterCardStyle` 对整张卡（海报+标题+副标题）做 13pt 圆角 `clipShape`。修复：海报卡不再整卡圆角裁切（海报图自身已有圆角裁切），聚焦底色改用自身圆角形状绘制；非海报行与 tvOS 海报聚焦样式不变。重建复验首字完整、海报圆角保留（`15-wall-fixed.jpg`）。
  - 发现未修（P3）：详情页顶部背景图上方有一条灰色空带（`10`/`12`）；端口在切到 HTTP 自动填“80”时首次输入的“8089”曾丢失、最终为“80”（可能与自动化输入时序有关，待人工复现）。
- **未执行**：tvOS 构建（海报卡修复也编进 tvOS，但 tvOS 海报走 `MediaPosterFocusStyle`，理论上不受影响，未验证）、真机构建、六配置全量、Release 中 DEBUG 标记检查、大字号/横屏/iPad 下的海报墙复验。

## 风险与说明

- 本场景写入模拟器上该 App 的正式媒体库存储与 Keychain（匿名 WebDAV 不存凭据）。只应在自建模拟器上用；勿在真机带此参数启动。
- 共享状态（PROGRESS、当前交接、资源登记、需求总账）未改，由 Codex 汇总。需要 Codex 同步：资源登记里 `Nastart-Codex-SavedPassword-20261102/mobile` 的产物已被本批覆盖。

本机证据：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-locallib/`（构建日志、产物哈希、截图）。
