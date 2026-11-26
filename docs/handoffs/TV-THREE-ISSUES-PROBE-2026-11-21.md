# Apple TV 三个问题：XCTest 探测结论（给 Codex）

**日期**：2026-11-21 下午（15:52–16:10）
**背景**：用户 13:38 在旧包上反馈三个电视问题；Muse 当日 13:52 已装上含 Codex 2026-11-21 改动的电视新包（Xcode 27.2 标准构建，`BUILD SUCCEEDED`，dylib SHA `370f7443…15b174`，描述文件到 2026-11-27 12:58），用户 15:47 确认“几个问题都还存在”。Muse 随即用 XCTest 探针（`tvos/NastartTV/UITests/TVLaunchTests.swift`，新增 `testJellyfinEntryProbe` 已在 11-20、`testConnectionsCompressionProbe`、`testDockerBackButtonProbe`、`testSubpageWidthProbe` + `focusAndSelect` 辅助）在真机电视上复现并量化。**结论：三个问题在新包上全部复现，两个已用探针硬证据确认，一个已量化到帧宽。**

---

## 问题 1：从“存储与媒体”进 Jellyfin，依旧刷不出页面（读库 401/登录已失效）

**探针**：`testJellyfinEntryProbe`（2026-11-21 15:53 跑，新包）

**探针结果原文**：
```
PROBE jellyfin: target=tv.open.networkLibrary opened=true mediaEntryExists=true
mediaOpened=true needsConnect=false libraryTitles=["继续观看"]
errorHints=["失败", "登录已失效"]
```

**解读**：
- 入口能打开（`opened=true`）、媒体入口存在且能打开（`mediaEntryExists=true, mediaOpened=true`），账号显示已连接（`needsConnect=false`）。
- “继续观看”一行能显示（`libraryTitles=["继续观看"]`），说明不是完全空白。
- 但页面同时出现“失败”和“登录已失效”两个错误提示（`errorHints`）。这是 11-20 定位的同一症状：登录成功并未修复读库，读库被服务器 401/403 拒绝（见 `docs/handoffs/TV-JELLYFIN-401-LOGIN-EXPIRED-2026-11-20.md`）。
- **Codex 2026-11-21 的电视会话改动（`TVAccountVault.swift` Keychain 存密码、`TVJellyfinClient.swift` 401 静默认证、首选 `/UserViews`）没有解决此问题。** 静默认证要么没触发，要么触发后仍拿不到有效会话，要么 401 来自另一个原因（账号权限 / 端点 / 会话未被更新）。

**给实现方的任务**：
1. 在电视上复现后抓实际 HTTP 状态：读库请求到底返回 401 还是 403，是哪个端点（`/UserViews` 还是旧端点），请求头里的 token 是旧 token 还是已刷新。
2. 核查 `TVJellyfinClient` 的 401 静默认证是否真的走了：401 后是否调用了重登、重登是否成功、新 token 是否写回并用于重试。
3. 若重登成功但读库仍 401，查账号在 Jellyfin 侧的权限 / 设备授权状态（电视 deviceID 是电视独有 UUID，`tv.installation.id`，与手机不共享，排除互踢）。
4. 验收：从“存储与媒体”进 Jellyfin，电影/电视剧/继续观看三行都出数据，全页无“失败”“登录已失效”提示；退出重进一次仍正常。

**相关文件**：`tvos/NastartTV/Sources/TVJellyfinClient.swift`、`TVAccountVault.swift`、`NastartTVApp.swift`、`TVNASViews.swift`（`TVStorageEntry` / `TVJellyfinEntry`）。

---

## 问题 2：进 Docker（点进 Jellyfin 的 Docker 容器）后按返回键无效，只能强制退出 App

**探针**：`testDockerBackButtonProbe`（2026-11-21 15:52 跑，新包；容器直接列在启动台上，`tv.service.item.container:<hash>`）

**探针结果原文**：
```
PROBE docker-back: containerExists=true containerLabel=homepage、运行中
detailOpened=true onDetailBeforeMenu=true menuPressed=true
onDetailAfterMenu=true backOnLaunchpad=false
```

**解读**：探针点进 `homepage` 容器详情页（`detailOpened=true`、`onDetailBeforeMenu=true`），按一次 Menu（`menuPressed=true`），3 秒后仍在详情页（`onDetailAfterMenu=true`），没有回到启动台（`backOnLaunchpad=false`）。**返回键在容器详情页上确实无效，复现用户反馈。**

**代码侧线索**（Muse 读源码，未改）：
- 详情页是 `TVServiceDetailView`（`TVNASViews.swift:1465`），末尾确有 `.tvPageTheme().tvNavigationBack().accessibilityIdentifier("tv.service.detail")`。
- `tvNavigationBack()`（`TVViews.swift:146`）= `TVBackNavigation` 修饰器，内部是 `content.onExitCommand { dismiss() }`，`dismiss` 取自 `@Environment(\.dismiss)`。
- 详情页经 `TVServiceGroup` 里的 `NavigationLink`（`TVNASViews.swift:1356`）压入 `NavigationStack`。按说 `onExitCommand + dismiss()` 应弹出，但实测无效。可能原因（待实现方验证，二选一）：
  - (a) `onExitCommand` 与 `NavigationStack` 内置的 Menu 回退冲突/互相吞掉：自定义 `onExitCommand` 拦截了 Menu，但 `dismiss()` 拿到的是错误的 presentation 上下文（不是压入详情页的那个 NavigationStack），于是什么都没发生；
  - (b) 详情页内有某个可获焦元素/`.focusable()` 消费了 Menu 事件，导致 `onExitCommand` 根本没触发。
- 注意：`TVServiceDirectory`（容器列表页）本身也有 `.tvNavigationBack()`，且列表页的返回是正常的（探针里从详情页按 Menu 无效，但从列表页按 Menu 能回启动台——见 `testSubpageWidthProbe` 里 `XCUIRemote.shared.press(.menu)` 后成功回到启动台并点开容器）。**故障只发生在详情页这一层。**

**给实现方的任务**：
1. 在详情页复现：确认 `onExitCommand` 是否触发、触发后 `dismiss()` 是否执行、执行后导航栈是否真的 pop。
2. 修复方向（二选一，以实测为准）：去掉详情页自定义的 `onExitCommand`、让 `NavigationStack` 的内置 Menu 回退接管；或把 `dismiss()` 换成显式的导航栈 pop（`@Environment(\.dismiss)` 在 NavigationLink 压栈场景下应能 pop，若不行则改用 `presentationMode` / 路径绑定）。
3. 验收：启动台 → 任一容器 → 详情页 → 按 Menu → 回到容器列表；再按 Menu → 回到启动台；连续进出三个不同容器都正常；不要出现按 Menu 后页面无反应。

**相关文件**：`tvos/NastartTV/Sources/TVNASViews.swift`（`TVServiceDetailView:1465`、`TVServiceGroup:1328`、`TVServiceDirectory:1676`）、`tvos/NastartTV/Sources/TVViews.swift`（`TVBackNavigation:146`）。

---

## 问题 3：连接管理及管理提示等选项下的子页面及后续跳转页面都被压缩了

**探针**：`testSubpageWidthProbe`（2026-11-21 16:08 跑，新包）+ `testConnectionsCompressionProbe`（多次尝试，见“探针局限”）

**探针结果原文**：
```
PROBE subpage-width: storageOpened=true storageViewport=(0.0, 0.0, 1920.0, 1080.0)
storageWidestButtonWidth=1548.09 storageWidestLabel=浏览文件、Synology DSM
containerExists=true detailOpened=true detailOnPage=true
detailWidestButtonWidth=211.0 detailWidestLabel=启动台
```

**解读**：
- 视口是满屏 1920×1080（`storageViewport`）。
- “存储与媒体”页最宽按钮 1548pt（`浏览文件、Synology DSM`），约占可用宽度（1920 − 左右各 70pt inset = 1780pt）的 87%，**不压缩，正常**。
- **Docker 服务详情页最宽按钮只有 211pt，且是顶栏的“启动台”tab 按钮**——详情页自己的内容按钮（“在手机上管理”等）全部窄于 211pt。也就是说详情页内容被压成一小条，与用户说的“子页面被压缩”一致。**压缩不是全站的，是某些子页面（至少服务详情页）独有的。**
- 连接管理页本身探针没能量到（见下节“探针局限”），但用户亲眼确认它也被压缩；服务详情页的实测数据已证明同类子页面存在压缩缺陷，根因大概率相同。

**代码侧线索**（Muse 读源码，未改）：
- 子页面普遍用 `ScrollView + VStack + .tvPageInsets()`（`TVViews.swift:202`：`padding(.horizontal, 70).padding(.top, 24).padding(.bottom, 40)`），理论上应占满 1780pt。
- `TVServiceDetailView`（`TVNASViews.swift:1465`）的结构是 `ScrollView { VStack { TVPageHeading; ForEach(managementEndpoints) { Button(TVFeatureTile) }; VStack { ... }.padding(30).frame(maxWidth: .infinity).tvCardSurface } }.tvPageInsets()`。`frame(maxWidth: .infinity)` 在 `ScrollView` 里若缺少明确宽度约束，子视图可能按内容固有宽度收窄而非撑满——这是 tvOS 上 `ScrollView + maxWidth: .infinity` 的经典坑。
- 另一个嫌疑：`TVInformationLayout`（`TVViews.swift`）按主题 `commandCenter` 开启 `tvCompactInformation`，会让信息卡片走紧凑布局；若当前主题或环境值被误传到子页面，也会把内容压窄。需实现方在详情页实测时确认当前主题与 `tvCompactInformation` 的值。
- 对照：`TVStorageEntry`（存储与媒体）同为 `ScrollView + VStack + .tvPageInsets()`，却能量到 1548pt，说明不是 `.tvPageInsets()` 本身的问题，而是详情页内部某个 `frame` / `VStack` / `TVFeatureTile` 的宽度约束不同。

**给实现方的任务**：
1. 在服务详情页与连接管理页实测：抓各内容块的实际 frame（标题、按钮、卡片），确认是哪一层把宽度压到 ~200pt。
2. 修复：让子页面内容撑满 `.tvPageInsets()` 后的可用宽度（1780pt），与“存储与媒体”页一致；重点检查 `TVServiceDetailView` 内 `VStack` / `frame(maxWidth:)` / `TVFeatureTile` 的宽度约束，以及 `tvCompactInformation` 是否被误开启。
3. 验收：连接管理页、存储与媒体子页、服务详情页、设备各子页（资源概览/服务资源/容器/套件/文件/网络/证书）内容宽度与“存储与媒体”页一致（最宽内容 ≥1400pt），无肉眼可见的压扁；换主题（清流/栈列/流光）后仍正常。

**相关文件**：`tvos/NastartTV/Sources/TVNASViews.swift`（`TVServiceDetailView:1465`、`TVConnectionsView:116`、`TVServiceDirectory:1676`、`TVDeviceOverview` 等）、`tvos/NastartTV/Sources/TVViews.swift`（`tvPageInsets:202`、`TVInformationLayout`、`TVFixedFeatureGrid`、`TVFeatureTile`）。

---

## 探针局限（实现方复现时注意）

- **连接管理页探针没能量到**：`testConnectionsCompressionProbe` 三次尝试均卡在入口导航。原因：连接管理不在启动台上——启动台（已连接态）只有 `tv.open.networkLibrary`（存储与媒体）、服务分组与容器行，没有连接管理入口；连接管理在“我的”tab（`TVSettingsView`，`tv.settings.connections`，`TVNASViews.swift:57/77`）。XCTest 的 `focusAndSelect` 方向扫掠与向上按 8 次都无法可靠把焦点移到顶栏 tab（`tv.tab.mine` 存在但 `hasFocus` 始终为 false），所以探针到不了该页。**用户用实体遥控器能正常进连接管理页，探针到不了是探针的导航局限，不是 App 缺入口。** 实现方在真机上用遥控器复现即可。
- **探针本身无害**：三个探针只做导航、截图、读 frame，不改数据、不点“断开/移除”等破坏性按钮。`testDockerBackButtonProbe` 点进的是 `homepage` 容器详情（只读），未做任何写操作。
- **探针代码位置**：`tvos/NastartTV/UITests/TVLaunchTests.swift` 末尾（`testJellyfinEntryProbe`、`testConnectionsCompressionProbe`、`testDockerBackButtonProbe`、`testSubpageWidthProbe`、`focusAndSelect`）。注意：2026-11-21 16:0x 期间该文件曾因一次错误的 Python 替换被写坏（122MB），Muse 已从 git HEAD 恢复并按 11-20 原文重建了 `testJellyfinEntryProbe` 与 `focusAndSelect`，再补上三个新探针；现文件 1030 行、括号 147/147 平衡。复用前请先 `git diff` 核对。

## 环境与证据

- 电视：Apple TV 4K (3rd gen)，tvOS 27.2，UDID `00008110-000235903E99801E`，`available (paired)`（2026-11-21 13:49 重启 Mac 后恢复）。
- 新包：Xcode 27.2 标准构建 `BUILD SUCCEEDED`，`NastartTV.debug.dylib` SHA `370f7443b802108645cb3e84fdce1cb1dd42fe161e0a3c45ce3dcacedc15b174`，Team `5436TB5498`，描述文件到 2026-11-27 12:58；`devicectl device install app` 5 秒保留数据覆盖安装成功。
- 探针日志：`/tmp/nastart-tv-probes-20261121.log`（第一轮三探针）、`/tmp/nastart-tv-probes2-20261121.log`（第二轮）、`/tmp/nastart-tv-probes3-20261121.log`（第三轮 Docker）、`/tmp/nastart-tv-probes4-20261121.log`（第四轮连接管理）、`/tmp/nastart-tv-probes5-20261121.log`（第五轮宽度测量）。探针截图以 `XCTAttachment` 形式挂在测试结果里。
- iPhone 13 WDA 8168 就绪；iPad WDA 经 Wi-Fi 直连 `192.168.1.26:8100` 就绪（iproxy 8169 暂不可用，因 iPad 当前未接 USB，`idevice_id -l` 只看到 13）。
- A1 监控运行中（PID 1668/1670），与电视工作无关。

## 交回要求（沿用既定规则）

实现方改完后必须自己编过（Xcode 27.2，tvOS）、跑过相关测试再交回，不交“看着对但没编过”的代码。交回时说明：改了哪些文件、是否编过、测试结果（三个问题是否都复测通过）。Muse 随后在真机电视上按本文件“验收”条验收，失败写回本文档打回重改。
