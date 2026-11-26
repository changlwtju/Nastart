# Jellyfin 互踢仍在发生：13 在修复包上仍掉线（2026-11-20 晚）

## 已核实的现象（带时间戳与截图）
- 22:14：13 登录成功，媒体库正常（截图 nastart-13-after-login-20261120.png）。
- 之后用户在 18 上登录 Jellyfin → 13 掉线（回登录页）。
- 用户在 13 上重新登录 → 18 未掉线（用户当时观察）。
- 22:29：13 又回到登录页（截图 nastart-13-now2-20261120.png，用户名 chang 预填、密码空）。
- 22:31：iPad 仍显示 Jellyfin 已连接、媒体库完整（截图 nastart-ipad-now2-20261120.png）。注意：iPad 可能是缓存界面，未必代表其 token 仍有效。
- 电视：用户已重登一次，但探测第 7 轮（22:21）与第 6 轮完全相同，仍是"登录已失效"（401/403）。见 TV-JELLYFIN-401-LOGIN-EXPIRED-2026-11-20.md。

## 已核实的根因（2026-11-20 21:00 诊断）
- 13 与 18 共用同一个 Jellyfin DeviceId（UserDefaults `jellyfin.client.device-id`，备份恢复时拷过去），Jellyfin 一个 DeviceId 只认一个 token，一台登录即撤销另一台的 token。

## 已上的修复（13，21:24 装机）
- `LaunchpadView.persistentDeviceID()`（LaunchpadView.swift:10271）：读 Keychain（`StoredJellyfinDeviceID`，deviceID+vendorID）；无记录或 vendorID 锚不符就新铸 UUID 存 Keychain，删 UserDefaults 旧键，**绝不沿用可能重复的 UserDefaults 值**。主客户端（LaunchpadView.swift:10245）用它。
- 密码存 Keychain，401 时静默重登（`attemptSilentReauthentication`，LaunchpadView.swift:7095）；仅 401 时清已存密码。
- 21:25 首次启动弹登录页（迁移如预期），22:14 登录成功。

## 修复后仍掉线：已确认的代码缺口
- **DevicesView.swift:1885 与 :2043 两处仍在用旧路径建 Jellyfin 客户端**：
  `deviceID: UserDefaults.standard.string(forKey: "jellyfin.client.device-id") ?? UIDevice.current.identifierForVendor?.uuidString ?? "Nastart"`。
  修复删掉 UserDefaults 旧键后，这两处回退到 identifierForVendor——与主客户端的 Keychain UUID 是**第二个不同的 deviceID**。App 现在向服务器出示两个 deviceID。
- 18 仍是旧包（无修复），继续用 D-shared。

## 未解的问题（需实现方定位，Muse 负责验收）
1. 13 为何仍掉线：主客户端用的是 Keychain 新 UUID，18 的 D-shared 登录理论上不应顶掉它。候选解释：(a) 13 的 Keychain deviceID 不稳定（反复新铸，导致 token 失效）；(b) 服务器不是按 deviceID 限流（单会话/插件）；(c) 掉线与 18 登录只是时间巧合，另有触发源。**判定方法**：在每次登录与每次 401 时打一条诊断日志，记录 deviceID 前 8 位与阶段；下次掉线时凭日志定责。另请用户在 Jellyfin 网页后台"设备"页核对 13/18 的 deviceID 是否相同。
2. 静默重登为何没兜住 13：401 时应先静默重登再回登录页，22:29 却是登录页。检查 `attemptSilentReauthentication` 的调用路径是否覆盖了此次 401 的入口（启动/前台会话校验是否绕过了它），以及密码是否确实已存（22:14 登录成功时应已存）。
3. 电视重登无效：探测第 7 轮仍 401。先确认用户是在电视 App 内重登的（而非 Jellyfin 网页/NAS）；若是 App 内重登仍 401，需查电视的 deviceID 与保存的账号是否被正确覆盖，或账号本身无播放权限（403）。

## 给实现方的任务（转 Claude Code / Codex）
1. 全量收口 deviceID：所有建 Jellyfin 客户端的地方一律走 `persistentDeviceID()`，包括 DevicesView.swift:1885/:2043。
2. 给 18 也装上修复包（目前只有 13 有修复）。
3. 加 deviceID（前 8 位）诊断日志：登录成功、401、静默重登尝试/成功/失败各一条。
4. 电视端：照搬 iOS 的 Keychain 存密码 + 401 静默重登；报错态给"重新登录"入口（见 TV handoff）。
5. 验收（Muse）：13 登录 → 18 登录 → 13 仍在登录态且能读库；反向亦然；电视重登后读库正常。验收不过打回。

## 探测与取证记录
- 13 截图：`~/workspace/nastart-13-after-login-20261120.png`（22:17，登录态）、`~/workspace/nastart-13-now2-20261120.png`（22:29，登录页）。
- iPad 截图：`~/workspace/nastart-ipad-now2-20261120.png`（22:31，登录态）。
- 电视探测：`TVLaunchTests.testJellyfinEntryProbe`，第 6/7 轮结果相同；handoff 见 TV-JELLYFIN-401-LOGIN-EXPIRED-2026-11-20.md。
