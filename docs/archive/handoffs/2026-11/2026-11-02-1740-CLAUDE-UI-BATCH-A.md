# Claude（本地会话）：UI 清单 A 批（三个小修）

2026-11-02 17:40（Asia/Shanghai）。对应 [UI 清单](2026-11-02-1735-CLAUDE-UI-INVENTORY-IPHONE-PORTRAIT.md) 的 #3、#4、#5。没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## 结果

| 清单 # | 问题 | 处理 |
| --- | --- | --- |
| 3 | 真实详情页顶部有灰色空带 | **已修，已复验** |
| 4 | 从详情返回后约 10pt 上漂 | **未改**；后经[返回保位专项](2026-11-02-1900-CLAUDE-RETURN-POSITION.md)测量确认不是缺陷 |
| 5 | 更新时显示“已发现 0 个视频文件” | **已修，已复验** |

### #3 详情页灰带
- 根因：没有背景图时，`NetworkDetailBackdrop` 用固定 16:9 比例的海报兜底，并按 `.fit` 适配宽度。详情页顶部区域比 16:9 高，图片垂直居中，上下各留一条空带；下方那条被暗色渐变盖住，所以只看得到顶部灰带。
- 修复（`LibraryPosterWall.swift`）：兜底海报改用顶部区域的实际宽高比，铺满整块区域。高度为 0 时仍用 16:9。
- 复验：`示例电影 002` 详情顶部无空带（证据 `16-detail-fixed.jpg`）。

### #4 返回上漂（未改）
- 假设：海报墙用了 `.searchable`。进入详情时导航栏里的搜索栏收起，返回时恢复，内容随之偏移约一个搜索栏的高度。
- 没有测量证据，按项目规则不猜参数，这批不改；返回保位专项中先做多次可重复测量再定方案。

### #5 “已发现 0 个视频文件”
- 根因：编辑连接触发的更新（`NetworkLibrariesModel.editConnection`）开始时把计数清零，之后不再上报进度，所以整个过程都显示“已发现 0 个视频文件”，读起来像失败。
- 修复（`LibraryViews.swift`，`NetworkLibraryActivityContent`）：计数为 0 时显示“正在读取文件夹”，大于 0 时仍显示“已发现 N 个视频文件”。正常计数的扫描不受影响。
- 复验：`library-updating` 显示“正在读取文件夹”，`library-scanning` 仍显示“已发现 149 个视频文件”（证据 `17-*.jpg`）。

## 文件

| 文件 | 改前 SHA-256 | 改后 SHA-256 |
| --- | --- | --- |
| `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryPosterWall.swift` | 79b4ea39…e569（含上一批海报卡修复） | 8ed1cbe0…1109 |
| `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift` | b0d81db0…b5f5（与 Codex 已保存密码集成后的值一致） | 47b7e4e7…43e0 |

## 验证

- iOS 模拟器 Debug（ad-hoc 签名）增量构建通过，仍借用 Codex 闲置的 SavedPassword 产物目录。debug.dylib `8ecf7f27a65612a71259876249f3267a042a3dc16e64d9c589a227b35e9dd579`。剩余磁盘约 6.8GiB。
- 包单测 15/15 通过（这两处都是 iOS/tvOS 代码，macOS 单测不覆盖它们）。
- **未执行**：tvOS 构建（两处改动都会编进 tvOS）、六配置全量、Release 检查、大字号/横屏/iPad 复验。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。本机证据：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-locallib/`。
