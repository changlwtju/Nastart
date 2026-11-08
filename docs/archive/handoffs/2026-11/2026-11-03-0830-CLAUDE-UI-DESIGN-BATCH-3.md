# Claude（本地会话）：设计项第三批（#8 大字号海报墙）

2026-11-03 08:30（Asia/Shanghai）。按[设计项方案](2026-11-03-0000-CLAUDE-UI-DESIGN-PROPOSALS.md)的顺序推进。没有访问 NAS、没有局域网发现。真实海报墙只连本机只读假媒体库（127.0.0.1:8089）。

## 改动

**文件**：`Packages/NetworkMedia/Sources/NetworkMedia/MediaPosterCard.swift`，改后 SHA-256 `6e01a476…c91b49a6`。

- **触发条件**：只在 iOS 上，同时满足无障碍字号（`isAccessibilitySize`）和紧凑宽度（iPhone）时生效。
- **新样式**：`MediaPosterCard` 改为横排列表行：
  - 左侧 88pt 宽海报，保持原宽高比和进度条；
  - 右侧标题和副标题，可多行完整换行。
- **网格**：不用改。`MediaPosterGridLayout.mobile` 在这种情况下本来就是 1 列，所以只改卡片一处。
- **其他情况保持原样**：标准字号、iPad 宽屏、tvOS 都不受影响。
- **覆盖范围**：卡片是共用组件，下面所有海报墙都会生效：
  - 本地 WebDAV 媒体库（`LibraryPosterWall`）；
  - 剧集（`SeriesViews`）；
  - 启动台 Jellyfin 海报墙（`LaunchpadView` 两处）；
  - 离线测试场景。
- **重构**：卡片主体拆成 `poster` 和 `caption` 两个属性，竖排和横排共用，没有复制第二份卡片设计。

## 验证

- **离线场景**：模拟器 `Claude-PW-iphone`，iOS 27。截图在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/batch3/iphone/`。
  - `library`、`missing`、`wall-category-fallback` 大字号：一屏从 1 部作品变为约 3.5 部，长中英文标题完整换行。
  - `wall-read-ready` 深色大字号：正常。
  - 标准字号的 `library`、`wall-category-fallback`：仍是 3 列网格，和改动前一致。
- **真实海报墙**：`local-library` 大字号，92 个视频文件，显示为列表行。
- **返回保位**：按[返回保位专项](2026-11-02-1900-CLAUDE-RETURN-POSITION.md)的方法复测：
  - 滑到中段，等列表停稳 4 秒后截“进入前”图；
  - 点进“示例电影 006”详情再返回；
  - 位移 **0 像素**。
  - 证据在 `batch3/retpos/`。
- **包单测**：`NetworkMedia` 305 项全部通过。
- **六配置**：全部 BUILD SUCCEEDED，日志在 `batch3/six/`。
  - 本批的后台通知和构建监控事件，曾在构建还在运行时报“全部成功”。最终以日志逐项读取为准，在构建脚本确实结束后核对。
- **iPhone 13 真机（iOS 16.3.1）**：
  - **安装**：签名 Debug 包，深度严格验签通过。
  - **安装前**：App 正在运行（PID 61998，路径为第一批安装的 `63A03E57-…`），先备份了偏好。
  - **偏好**：用 `ios-deploy` 保留数据覆盖安装后，偏好 SHA-256 前缀都是 `e32b3846fdc72f48`，逐字节一致。
  - **截图**：`library` 标准和大字号、`missing` 大字号，显示和模拟器一致。
  - **收尾**：核对 PID 和路径（`FBE9811B-…`）后结束了自己启动的进程。
- **对比图**：`batch3/大字号海报墙-第三批.jpg`，已发给用户。
- **补充观察**：第一、二批结束进程后，iPhone 13 和 iPad 上的 App 都曾被再次启动，路径为我安装的包，启动来源未知。

## 未执行

- **返回保位**：只测了 1 次。没测更深层级（季、集）的连续返回。
- **Jellyfin 海报墙**：没有在真实 Jellyfin 下看，NAS 暂停中。
- **tvOS**：tvOS 不生效，没有截图。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。需要同步：#8 的视觉变更，覆盖所有 iOS 海报墙的大字号 iPhone 显示。
