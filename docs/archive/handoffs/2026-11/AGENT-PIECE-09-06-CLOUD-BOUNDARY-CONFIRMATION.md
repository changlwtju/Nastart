# 确认：Agent 第 9-6 件 — 云边界确认

**日期**：2026-11-26
**执行**：Muse（本件不交 Codex）
**对应拆分**：`docs/project/AGENT-BREAKDOWN.md` 第 9 件（正式云/官网）第 9-6 小件
**范围依据**：`cloud/README.md`（正式云 V1 边界）

## 结论

`cloud/README.md` 的四条边界与 App / Agent / 官网的实际行为一致，无偏差。**9-6 已确认通过。**

## 逐条核对

### 1. V1 优先 iCloud/CloudKit 同步（Apple 设备间连续性）

- **实际**：App 用 Apple CloudKit 同步，容器 `iCloud.com.changliwen.nastart`（`Nastart.entitlements`），三条 v2 记录：`NastartServices`、`NastartTasks`、`NastartPreferences`（`CloudSyncRecord.swift`）。
- **结论**：一致。V1 就是 CloudKit 同步，无其他同步通道。

### 2. 不建自定义 Nastart Cloud 后端

- **实际**：App 代码里无 Nastart 自有服务器地址；同步直接走 Apple 的 `CKDatabase`（`CloudSyncDatabase` 协议由 `CKDatabase` 实现）。App 内唯一的网络地址是用户自己的 NAS（DSM / Jellyfin / Agent）、IMDb/TMDB 影片资料外链。
- **结论**：一致。无自定义后端。

### 3. 不做云中继

- **实际**：Agent 只在局域网内工作（默认监听 `0.0.0.0:8787`，App 直连 NAS 地址或经用户自设的端口转发/Tailscale）；Agent 代码无对外 HTTP 调用，仅用 `http.client` 连本地 Docker socket 与 `127.0.0.1` 自检；官网为纯静态 HTML+CSS，无服务端代码。
- **结论**：一致。无云中继。

### 4. 云端不存 NAS 凭证等敏感信息明文

- **实际**：NAS 凭证、Jellyfin 会话/密码/设备 ID、Agent 连接信息均只存 iOS 钥匙串（`KeychainStore.swift`：`saveNASCredential`、`saveJellyfinSession`、`saveJellyfinPassword`、`saveJellyfinDeviceID`、`saveAgentConnection`）。CloudKit 三条记录的载荷只含服务、任务、偏好（`CloudSyncServices`：手动服务与可见性覆盖；`CloudSyncTasks`；`CloudSyncPreferences`），同步代码中无 password/credential/secret/token 字段。
- **结论**：一致。凭证不出钥匙串，不进 CloudKit。

## 备注

- `cloud/README.md` 列的“未来可能职责”（加密同步、推送通知、账号与计费、备份恢复、多设备连续性）是远期方向，不在 V1 范围；本次只确认 V1 边界，不做这些。
- 同步的服务记录含用户手动添加的服务地址（`endpointString`），不含凭证；隐私政策页（9-2）已按此口径写（NAS 凭证只存设备本地，不同步到云端）。
