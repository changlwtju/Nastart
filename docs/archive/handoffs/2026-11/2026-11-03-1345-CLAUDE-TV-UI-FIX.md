# Claude（本地会话）：Apple TV 界面优化 T1–T5

2026-11-03 13:45（Asia/Shanghai）。按[TV 检查方案](2026-11-03-1130-CLAUDE-TV-UI-REVIEW.md)的建议顺序推进：T1 → T5 → T4 → T2+T3。

- 没有访问 NAS，没有局域网发现；
- 没有启动正常根页面，没碰 TV 真机；
- 只在自建模拟器 `Claude-PW-tv` 上安装和截图。用户已在面板授权，这次用遥控器测了焦点移动。

## 改动

改前文件备份在会话临时目录，没有进仓库。`tvos/` 整个目录在 git 里是未跟踪状态。

| 编号 | 文件 | 改动 |
| --- | --- | --- |
| T1 | `TVNASViews.swift` | `TVServiceInsetStyle` 增加 `padded` 参数，在焦点框里面给文字留横 20、竖 10 的边距。只有连接卡片里的文字按钮（`TVConnectionPanel`）启用；其他用处本来就自带边距，不受影响 |
| T1 | `TVViews.swift` | 离线焦点场景里两处 `.padding(24)` 原来写在按钮外面，改到按钮内容里 |
| T5 | `MediaDetailPresentation.swift` | `MediaDetailFact` 在 tvOS 上改为 `HStack(spacing: 8)` 并合并无障碍元素；iOS 仍用 `Label`，不变 |
| T4 | `NastartTVApp.swift` | `TVAppState` 新增 DEBUG 专用的 `init(offlineFixture:)`：不读钥匙串，不写安装 ID。正式 `init()` 行为不变，只是读取钥匙串的位置从属性默认值移进了 `init` |
| T4 | `NastartTVApp.swift` | `launchpad-root` / `devices-root` / `tasks-root` 场景在 TV 上分流到新场景 `TVOfflineRootScene` |
| T4 | `TVViews.swift` | `TVRootNavigationShell` 新增 `initialTab` 参数 |
| T4 | `TVNASViews.swift` | `TVHomeView` 新增 `initialTab` 参数；新增 `TVOfflineRootHost` 和 `TVOfflineRootScene`（DEBUG） |
| T4 | `OfflineUIScenario.swift` | 只改注释：这三个场景在 tvOS 上也可用 |
| T2 | `TVViews.swift` | `TVType` 放大：标题 34→40、分节 27→32、正文 23→28、说明 20→24 |
| T2 | TV 源码和媒体包 | 写死的文字字号按同一比例改了 63 处（23→28、20→24、22→26、21→25、19→23、18→22、27→32、31→37、34→40）。媒体包里只改了 `#if os(tvOS)` 分支，图标字号和测试外壳不动 |
| T3 | `TVViews.swift` | `TVTileStyle` 选中时放大 1.025→1.05，加阴影（黑 30%，半径 18，下移 10）；开启减弱动态效果时不放大 |
| T3 | `MediaPosterCard.swift` | `MediaPosterFocusFrame`（海报）放大 1.035→1.06，阴影 16%→30% |
| T3 | `SourceContext.swift` | `NetworkTVActionStyle`（仅 tvOS）放大 1.015→1.03，加同样的阴影；`inset` 行不放大也不加阴影 |

### TV 离线根场景的用法

```
--offline-ui launchpad-root --offline-ui-tab launchpad|devices|tasks|mine
```

- **显示内容**：正式的标签栏、启动台、设备、事项、我的，都是“NAS 未连接”状态。
- **账号**：`TVAppState` 不带账号，不读钥匙串。
- **偏好**：写入临时域 `nastart.offline-ui.tv-roots`，启动和销毁时都会清空。里面写入主题、深浅色，和 3 条示例事项。
- **覆盖不到**：NAS 已连接时的启动台和设备页需要 DSM 客户端，不在范围内。
- **注意**：登录表单仍然能打开。离线运行时不要提交，提交会真的联网登录并写入钥匙串。

### 文件指纹（SHA-256 前 8 位…后 8 位）

| 文件 | SHA-256 |
| --- | --- |
| `TVViews.swift` | `fbe0cc43…4ac918af` |
| `TVNASViews.swift` | `b1268d22…9d5850e8` |
| `NastartTVApp.swift` | `ea8b4ab2…9eb48c6e` |
| `MediaDetailPresentation.swift` | `467eb63d…29a6e05d` |
| `MediaPosterCard.swift` | `79a0cc60…a93e2d27` |
| `SourceContext.swift` | `1fdefee5…e0eaeb71` |
| `LibraryPosterWall.swift` | `92a0e715…b7345e6c` |
| `LibraryViews.swift` | `63044740…9f7cc77d` |
| `OfflineUIScenario.swift` | `fb5f9fc1…0e46fafd` |

## 验证

- **TV 模拟器**：用 Debug 包，ad-hoc 签名后装到 `Claude-PW-tv`。证据在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/tvfix/`，对比图 `TV优化-T1到T5-改前改后.jpg`。
  - **T1**：连接卡片里的按钮被选中时，焦点框和文字之间有边距，首字完整。
  - **T5**：“★ 8.2”“112 分钟”的图标紧跟数值。
  - **T4**：四个根标签页都能离线打开。三种主题、深浅色都截了图。
  - **T2**：根页面、设置、连接、海报墙、详情、剧集都截了图，没看到截断或重叠。
  - **T3**：选中卡片明显浮起，和相邻卡片不重叠。“历史”分段按钮放大后略超出内容列的右边线，但仍在页面边距内。
- **遥控器焦点**：
  - 连接管理：左右移动正常；
  - 启动台：从标签栏向下能移到卡片；
  - 事项页：能在分段按钮和模板卡片之间移动。
  - 模拟器的截图会比按键慢一步，第一下按键有时会被吞掉。
- **包单测**：`NetworkMedia` 305 项全部通过。
- **六配置**：全部 BUILD SUCCEEDED，日志在 `tvfix/six/`。
  - 日志里出现的 `error:` 字样只是告警和源码片段，比如 KSPlayer 的 `finish(player:error:)`。前几批的日志里也有。
- **iOS 侧复查（14:35 补）**：新 Debug 包装到 `Claude-PW-iphone` 和 `Claude-PW-ipadpro13`，截图在 `tvfix/ios/`。
  - **iPhone**：和旧截图逐像素对比，下面这些页面只有状态栏不同：
    - 媒体库、剧集、演职人员；
    - 大字号海报列表、分类回退；
    - 连接页。
  - **iPhone 详情页**：只多了第一批 #9 的灰色播放按钮，是预期内的变化；“★ 8.2”“112 分钟”标签和改前一样。
  - **iPad**：详情、媒体库、启动台两列都正常，没看到变化。

## 未执行 / 已知

- ~~事项页的“待办”“历史”列表~~：14:40 已补测。
  - 遥控器 `return` 键能选中，只是生效要晚一步。
  - “待办”列表显示 2 条示例，“历史”列表显示 1 条已完成，排版正常。
  - 证据：`tvfix/tasks-pending.png`、`tasks-history.jpg`。
- ~~可用按钮被选中时的样子~~：14:40 已补测。
  - 用 `network-focus-files` 场景里同样式（`MediaDetailActionStyle`）的可用按钮看了深色和浅色：强调色底配黑字，清晰。
  - 证据：`tvfix/action-focus*.jpg`。
- **大字号**：TV 的字号都是写死的，大字号下和标准字号一样。
  - tvOS 系统本身不提供“更大字体”设置，真实用户不会进入大字号状态，所以不做适配。
  - 用户同意后，改做了下面两项（15:40）。
- **粗体文本检查（15:40）**：
  - **新增 DEBUG 开关 `--offline-ui-bold`**：`NastartTVApp.swift` 里的 `TVOfflineBoldText` 通过窗口场景的 `traitOverrides.legibilityWeight = .bold` 模拟系统“粗体文本”，只在离线场景生效。
  - 最初用 SwiftUI 环境值 `legibilityWeight` 做，只对没有导航容器的页面生效；导航容器会从系统特征里重新读取，所以改用窗口特征。
  - **结果**：“我的”、启动台、详情、海报墙、连接管理加粗后都正常，没有新的截断。海报长标题原本就是两行省略。
  - 证据：`tvfix/std-*.jpg`、`bold-*.jpg`。
  - 没有改模拟器的系统设置。
- **测试外壳大字号重叠（15:40）**：
  - **改动**：`OfflineMediaScene.swift` 在 tvOS 上去掉导航标题“离线媒体测试”。页面内已有“离线界面测试”字样，iOS 不变。
  - **原因**：遥控器焦点让内容滚动后，这个标题会浮在内容上；大字号下更明显。
  - **仍然存在**：右上角“更多”按钮在强制大字号下显示为“⊝…”。这是系统导航栏自己的截断，试过把标签改成只显示图标也没用，已经撤回。真实 TV 用户进入不了大字号，只有测试外壳会遇到。
  - 证据：`tvfix/large-library.jpg`。
- **15:40 这批的构建**：`NetworkMedia` 305 项通过；六配置全部 BUILD SUCCEEDED，日志在 `tvfix/six2/`。这次也覆盖了 iPad 批次里温度单位的改动。
- **TV 真机**：没装。签名受阻。
- ~~“我的”页设置宫格图标偏小~~：15:00 已改。
  - **改动**：`AppTheme.swift` 里 `NastartSettingsItemLabel` 的 tvOS 分支，改成和 `TVFeatureTile` 一样左侧 76pt 图标块、右侧文字；iOS 分支不变。
  - **验证**：TV 模拟器 Debug 构建成功；三种主题截图正常，证据 `tvfix/grid-*.jpg`。
  - **六配置**：后来在 [iPad 宽屏批次](2026-11-03-1450-CLAUDE-IPAD-WIDE-LAYOUT.md)里一起跑过，全部成功。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。需要同步：

- TV 的 T1–T5 视觉变更；
- 新的 TV 离线根场景和 `--offline-ui-tab` 参数；
- `TVAppState` 的初始化方式调整。
