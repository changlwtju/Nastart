# Claude（本地会话）：启动台、设备、事项根页面的离线场景

2026-11-02 19:30（Asia/Shanghai）。用户确认按 [B 批方案](2026-11-02-1750-CLAUDE-UI-BATCH-B.md) 实施。没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## 用法

```text
--offline-ui launchpad-root | devices-root | tasks-root   [--offline-ui-text-size standard|large]
```

- 只在 iOS DEBUG 生效；tvOS 显示“此场景仅适用于 iPhone 与 iPad”。
- 承载正式的 `LaunchpadView`、`DevicesView`、`TasksView`，使用隔离 store：
  - 示例数据（`MockAppDataProvider`）；
  - 临时偏好域 `nastart.offline-ui.roots`，场景创建和销毁时都会清空；
  - 不读写钥匙串，不联网，不排提醒通知，不写 iCloud 同步标记，不读写本机保存的 NAS 快照。
- 底部横幅：“离线界面测试 · 示例数据，不联网、不保存”（`offline.roots.banner`）。

## 实现

| 文件 | 改动 |
| --- | --- |
| `Core/Stores/ManualLaunchpadServiceStore.swift` | 三个小存储加 `init(defaults: UserDefaults = .standard)`，内部改用注入的偏好域 |
| `Core/Stores/LocalTaskStore.swift` | 同上 |
| `Core/Stores/AppStateStores.swift` | 见下方 `AppDataStore` 小节 |
| `Core/Stores/NASConnectionStore.swift` | 见下方 `NASConnectionStore` 小节 |
| `NetworkMedia/OfflineUIScenario.swift`、`OfflineMediaScene.swift` | 新增三个场景；tvOS 分支补齐 switch |
| `Core/Design/AppTheme.swift` | `@MainActor OfflineRootStoresHost` 持有临时域和 5 个 store；`NastartOfflineRootScene` 注入环境对象，并用 `.defaultAppStorage(suite)` 把页面内全部 `@AppStorage` 改到临时域 |

### `AppDataStore`（`AppStateStores.swift`）
- 原 `init(provider:)` 改为便利初始化，委托给私有的指定初始化。小存储默认仍是 `.standard`，正常路径行为不变。
- 新增仅 DEBUG 的 `offlineFixture(defaults:)`。
- 隔离开关 `isOfflineFixture` 下：
  - 刷新、重连、连通性监测、前台刷新、DSM 刷新/激活/恢复/完成、发布文件夹会话、服务健康检查、iCloud 快照应用直接返回；
  - `loadFolder` 只返回本地示例子项；
  - 通知排程、iCloud 本地变更标记、NAS 快照写入/删除统一经私有 helper 跳过。

### `NASConnectionStore`
- 新增仅 DEBUG 的 `init(offlineFixture:)`：不读钥匙串。
- `connectAgent`、`disconnectAgent`、`signOut` 在隔离下不碰钥匙串、不登出 DSM。

### 测试
- 包单测：新增 `testRootScenesAreExplicitAndRejectPasswordFlags`。
- 宿主测试：新增 `OfflineRootFixtureTests`。在隔离 store 上完成一个事项、切换一个服务的可见性、执行健康检查和读取文件夹后：
  - 标准偏好域三个关键键（事项、可见性、NAS 快照）逐字节不变；
  - 写入只落在临时域；
  - 没有健康检查结果，不处于刷新状态；
  - 连接 store 已连接、没有代理连接和 DSM 会话。

| 文件 | 改前 | 改后 |
| --- | --- | --- |
| `Nastart/Core/Stores/ManualLaunchpadServiceStore.swift` | 93bf5804…d972967b | 1df57a2d…10487eee |
| `Nastart/Core/Stores/LocalTaskStore.swift` | aa8b5c46…193728fe | 5cc15ae4…37e09075 |
| `Nastart/Core/Stores/AppStateStores.swift` | b035f7e9…11cca484 | 2c17f996…6447b917 |
| `Nastart/Core/Stores/NASConnectionStore.swift` | a3d96ac1…8bf73e35 | 1c6d4a02…581cf08e |
| `Packages/NetworkMedia/Sources/NetworkMedia/OfflineUIScenario.swift` | 8e4989af…4433c6b5 | 4bc7561e…78f806dc |
| `Packages/NetworkMedia/Sources/NetworkMedia/OfflineMediaScene.swift` | b4d2d275…30082a9d | 1e975741…4a442455 |
| `Nastart/Core/Design/AppTheme.swift` | bc4055fa…1ab7b21b | 936f932e…3c92cc16 |
| `Packages/NetworkMedia/Tests/NetworkMediaTests/OfflineUIScenarioTests.swift` | 5e993c3f…a4f7c41c | 56f0e526…6acce734 |
| `NastartTests/NonPlaybackPolicyTests.swift` | 19d0101f…08833d4e | 22fcb783…42b86c27 |

（路径相对 `ios/Nastart/`。“改前”为本批开始时的值，已包含本会话更早的改动。）

## 验证

- **包单测**：16/16 通过。
- **宿主测试**：
  - 两次都在新建的空白模拟器 `Claude-HostTest` 上运行，跑完即删除，沿用第八批“空白实例才能跑宿主测试”的做法；
  - `NonPlaybackPolicyTests` 189 项：0 失败，1 项原本就跳过。这一组覆盖重连、刷新、健康检查等既有行为，用来确认初始化重构没有改变正常路径；
  - `OfflineRootFixtureTests` 1/1 通过；
  - 首次运行因 `OfflineRootStoresHost` 缺少 `@MainActor` 编译失败，已修复后重跑。新测试第一次误放进了 `NastartShareOutcomeTests` 类，没被执行，挪到独立类后单独跑过。
- **模拟器截图**：`Claude-PW-iphone` 上三个场景 × 标准/大字号共 6 张，三个根页面都正常显示，启动前后标准偏好域哈希一致（证据 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/roots/`）。
- **六配置**：iOS/tvOS × 模拟器 Debug、真机 Debug、真机 Release 全部 BUILD SUCCEEDED。iOS Release 包中没有 `launchpad-root`、`offline.roots.banner`、`nastart.offline-ui.roots`，Debug 包中有。
- **磁盘**：宿主测试期间曾临时降到 4.1GiB，删除临时模拟器后恢复，最后约 8.7GiB。

## 已知限制 / 未执行

- **示例数据**：设备卡显示“未连接”，同时有 CPU/内存/硬盘数值。这来自 `SampleData`，不代表真实连接状态。
- **深层页面**：
  - 已守卫：本地写入、钥匙串、网络刷新、健康检查、通知、iCloud 标记。
  - 未逐一核对：服务详情、文件浏览器等页面里直接创建 `URLSession` 的代码（如 `DevicesView` 文件播放）。离线场景里不要深入点进这些页面；离线截图清单只用根页面。
- **未覆盖**：iPad、横屏、深色模式和其他主题下的根页面截图，真机安装。
- **共享状态**：未改。需要 Codex 同步的事项：新增三个离线场景；核心 store 增加了 DEBUG 隔离入口；构建产物目录再次被覆盖。

证据：
- 宿主测试日志：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-device/hosttest/`
- 六配置日志：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-locallib/six-roots/`
