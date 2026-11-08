# B 海报墙“返回保位”评估（只读，不改代码）

2026-11-02 10:40。承接 `0925-CLAUDE-OFFLINE-CLOSURES-PLAN` §4。只读 `LibraryPosterWall.swift`、`MediaWallSelection.swift`、`OfflineMediaScene.swift`、`LibraryViews.swift:329`；未编译、未运行。

## 结论：现在不实施 B，也不加探针
1. **离线现有“海报墙”不是正式墙。** `OfflineMediaScene.library`（约 393 行）是 `VStack + NavigationLink` 的结构孪生，用 `OfflineMediaFixture.items`；正式墙是 `NetworkLibraryPosterWall`（`GeometryReader > ScrollView > LazyVStack`，`Button` 置 `selected/selectedSeries`，`.navigationDestination(isPresented:)` 推入详情）。在孪生上测滚动保位只能证明 SwiftUI 默认行为，**不能证明 App 的墙**。
2. **正式墙没有可注入的离线座位。** `NetworkLibrariesModel` 只在 `LibraryViews.swift:329` 以 `@StateObject … = NetworkLibrariesModel()` 构造；包内没有其他构造点或测试替身。要在离线里承载正式墙，必须先给模型做可注入入口（会触及我未读过的模型/扫描代码，且与第七批同文件范围相邻），收益只是“能观察”，不是“能修复”。
3. **源码上没有看到必然丢位的写法。** 墙视图在 push 后保留在导航栈中；选中、分类、搜索都在其 `@State`；`onDisappear` 只清 `localReadRetry`。可能的丢位来源只有：身份重建（上层 `.id`/整树替换）、`catalog`/`library` 数据整体重载使 `LazyVStack` 内容变化、分类回落（`retainCategory`）把 `category`/`supplementsExpanded` 重置。这些都需要真实数据与真实运行才能区分。
4. **可靠证据来自真机/可用模拟器的真实库**：滚到深处→打开详情→返回，对比前后可见区间与分类。NAS 暂停且 13/iPad 安装包早于当前源码，**目前没有可用窗口**。

## 若以后要做（恢复 NAS 或有本机可读媒体库后）
- 先做证据：在 DEBUG 下给墙加匿名诊断（可见首项 id 的粗分类、返回次数），不记录路径/标题；再决定是否需要 `ScrollViewReader` 显式保位。
- 需要的改动文件预计：`LibraryPosterWall.swift`、可能 `LibraryViews.swift`/`OfflineUIScenario.swift`（与第七批相邻，须在第七批接入后排）。
- 停止条件：证据显示未丢位（关闭 B）；或丢位但来源在模型整体重载（转为模型层问题，不在墙内修）。

## 状态
B：**搁置，等真实库窗口**。未做任何修改；未碰 NAS/设备。Codex/Claude 额度：未知。
