# Agent 第 4 件交接：App 显示 Agent 健康状态与重新配对入口（2026-11-24）

## 目标

用户在 App 里能看到 Agent 是否在线；离线/失败时有明确标记和一键重新配对入口；身份不一致时给出可读原因，不再静默回退到纯 DSM 数据。

## 现状（已摸清，Codex 不用再探）

- 配对与身份校验已做：`AgentClient.pair`（`AgentClient.swift`）、`handshake` / `snapshot` 均校验 `agentId == connection.agentID`（不匹配抛 `AgentClientError.unauthorized`）与 `apiVersion == 1`；token 存 Keychain（单槽位，`KeychainStore.saveAgentConnection`）。
- 健康状态已算出但**从未显示**：`AgentHealthSnapshot`（`AgentClient.swift:24`）有 `state`（connected / stale / failed，15 分钟未见为 stale）与 `failureReasonKey`；`AppDataStore` 已发布 `agentHealth`（`AppStateStores.swift:829`），`loadSnapshot` 在 Agent 失败时返回带失败健康快照的 DSM 数据；但**没有任何 View 读 `agentHealth`**（Features/ 与 App/ 里无引用，只有一处 `agentHealth: nil` 的预览）。
- 合并与去重已做：`AgentSnapshotMerger.merge`（`AgentClient.swift:312`）按名称（去空格、不区分大小写）或端点 host+port 去重，匹配则 enrich、不匹配则追加；本件不动它。
- 配对入口已做：`AgentSetupGuideView`（`LaunchpadConnectionViews.swift:1001`）有配对/修复/断开（地址 + 配对码 + 自签证书开关）；本件复用它的配对流程，不重写。
- 失败原因已有本地化键：`AgentClientError.healthReasonKey` 与 `NetworkErrorClassification`（`AgentClientError.unauthorized` 已归类为 authentication）；本件复用，不新发明错误码。

## 本件做

### 1. 显示 Agent 健康状态

在启动台（或设备/连接区，按实际视图结构定，必须是用户看服务时能直接看到的位置）显示 Agent 健康状态：已连接（正常）、过期（15 分钟未见）、失败（失败 + 可读失败原因，只显示本地化文案，绝不显示原始错误码或诊断码）。用已有的 `agentHealth.state` 与 `failureReasonKey`，不要另起一套状态。

### 2. 失败时的一键重新配对入口

`state == .failed` 时，在该状态行提供“重新配对”入口，跳到 `AgentSetupGuideView` 的配对流程（复用现有配对逻辑）。身份不一致（`unauthorized`，即该地址上的 Agent 已更换）时显示专属文案（如“Agent 已更换，请重新配对”），与网络不可达区分开。

### 3. 测试

新增用例（按实际测试结构，`NonPlaybackPolicyTests.swift` 内或新建文件）：健康状态三种分支的文案映射、失败原因映射（`unauthorized` 与网络失败各一）、`agentHealth` 为 nil 时不显示状态行。

## 不做

- 改合并/去重逻辑（`AgentSnapshotMerger.matches` / `enrichedService` 不动）；若验收时发现重复卡片，另立一件，不在本件顺手改。
- 改配对协议、token 存储、Keychain 结构。
- 受限 API 权限、自动证书、正式云/官网。
- 改 `AGENT_VERSION`。

## 文件

- 启动台/连接区视图（显示状态行与重新配对入口，按实际结构定）。
- `ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift`（或新建测试文件，新增用例）。
- 本地化 strings（新增文案，中英文）。

## 验收

- Codex 自己构建并跑通新增测试；iOS 模拟器上跑通健康状态三种分支的显示。
- Muse 真机验收（iPhone 13 / iPad）：在 Mac 上直跑 `nastart_agent.py`（或 Docker 容器）作 Agent，App 配对后状态显示已连接；停掉 Agent 后状态显示失败 + 可读原因 + 重新配对入口；点重新配对能走到配对流程；改一个错的 Agent 地址后配对失败有可读原因。
