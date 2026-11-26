# 电视 Jellyfin 进启动台不出媒体库：token 已失效（401/403）

2026-11-20 22:21，XCTest 探测（TVLaunchTests.testJellyfinEntryProbe，第 6 轮）结论。

## 现象（用户原话）
- 电视上 DSM 已登录；NAS 网页与 Jellyfin 网页里也都登录了。
- 但从启动台进 Jellyfin，媒体库出不来。

## 探测结果
```
target=tv.open.networkLibrary opened=true
mediaEntryExists=true mediaOpened=true
needsConnect=false
libraryTitles=["继续观看"]
errorHints=["失败", "登录已失效"]
```
- 电视有已保存的 Jellyfin 账号（saved-media 入口 `network.browse.media` 存在），所以不弹"连接 Jellyfin"登录页，直接进媒体库视图。
- 媒体库视图能渲染"继续观看"栏目标题，但同时出现报错文案，含"失败"与"登录已失效"。
- 报错文案来源：`TVModels.swift:162`，`code == 401 || code == 403 ? "登录已失效或账号没有播放权限，请重新登录。" : "服务器请求失败（\(code)），请稍后重试。"`——即读库请求被服务器以 401/403 拒绝。

## 根因
- 电视的 Jellyfin token 已失效（过期或被服务器侧作废），读库每次都 401/403。
- **不是 iPhone 13/18 那种双机共用 DeviceId 互踢**：电视的 deviceID 是 `NastartTVApp.swift:30-37` 生成的 UUID，存在 UserDefaults（`tv.installation.id`），与手机不共享。13/18 登录不会顶掉电视的 token。
- 电视 token 失效的具体历史原因未定位（可能：服务器侧会话被撤销、密码变更后会话作废、或设备 ID 被重置后旧 token 失效）。

## 用户侧修复（需用户在电视上操作）
1. 电视 → 连接管理 → 断开 Jellyfin（`tvDisconnectConfirmation(.jellyfin)`，TVNASViews.swift:155）。
2. 重新登录 Jellyfin（服务器、用户名、密码；支持 iPhone 键盘通知输入）。
3. 回启动台进 Jellyfin，媒体库应恢复。

## 给实现方的改进（转 Claude Code / Codex，验收标准）
1. 电视端照搬 iOS 的修复：密码存 Keychain，401 时先静默重登再回登录页（iOS 见 KeychainStore.save/loadJellyfinPassword 与 LaunchpadView.attemptSilentReauthentication）。
2. 媒体库报错态目前只有"刷新/重试"（`tv.media.refresh`、`homeRetryAction`），401 时重试必然再败；报错弹窗应直接给"重新登录"入口。
3. 探测方法已留在 `TVLaunchTests.testJellyfinEntryProbe`（故意 XCTFail 输出 PROBE 行，便于从 xcodebuild 日志直接读结论）。注意：tvOS 的 XCUIElement 没有 tap()/click()，必须用 XCUIRemote 移动焦点 + press(.select)；新测试文件需进工程引用（该工程不用目录同步），直接往 TVLaunchTests.swift 里加方法最稳。
4. xcresult 的 Info.plist 在探测跑后有时缺失，附件导不出；结论以 xcodebuild 日志里的 PROBE 行为准。

## 附：探测路径
- 已连接状态的启动台是 TVNASOverview，没有 `tv.open.jellyfin` 入口；Jellyfin 在"存储与媒体"（`tv.open.networkLibrary`）→ 已保存媒体（`network.browse.media`）→ TVJellyfinEntry。
- 第 5 轮只进到存储与媒体就量结论，量的是目的地列表页，不算数；第 6 轮多进一层才是有效结论。

## 更新（22:36–22:37，用户确认 + 探测第 8 轮）
- 用户确认：已在电视 App 内（他的 tab 下）重新登录 Jellyfin，界面提示"登录成功"。
- 探测第 8 轮（22:37，登录成功后立即跑）结果与第 6/7 轮完全相同：`needsConnect=false libraryTitles=["继续观看"] errorHints=["失败", "登录已失效"]`。
- 结论：登录成功并未修复读库——登录后读库仍 401/403。这与"token 过期"不是同一回事，是**登录成功但会话未生效 / 保存的会话未被更新 / 账号无播放权限**三类可能之一。需实现方查：登录成功后保存的 token 是否真正覆盖了旧会话；读库用的 token 与登录拿到的是否为同一条；以及该账号在服务器上的播放权限。
- 另需确认用户登录时用的服务器地址与用户名（是否与电视已存账号一致）。
