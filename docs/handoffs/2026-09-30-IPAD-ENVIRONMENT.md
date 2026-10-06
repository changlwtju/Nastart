# 2026-09-30 iPad NAS 环境续查

## 范围与现场

- iPad 9 代 `00008030-001168403C43C02E` / iPadOS 18.3.1 今日重新接 USB。iPhone 13 也接入；iPad WDA 8103 当前无服务，故本轮不以 UI 自动化判断屏幕状态。保留 App 数据、钥匙串与系统网络设置，未切换 VPN，也未改 Mac/路由器/NAS 网络。
- 使用 iPad 原生 XCTest 宿主发起四个无凭据公开接口请求，因此请求确实从 iPad 的 URLSession 与当前设备网络环境出发，不以 Mac `curl` 代替。测试无需 WDA UI 自动化或视频转码。
- 原始偏好、诊断、测试结果、附件和安装日志只在本机私有目录 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-environment/`；偏好可能包含账号及环境信息，不提交/上传，未读取或导出钥匙串密码。

## 诊断结论

- 9 月 26 日历史日志中，旧地址先出现 `urlError:-1005`，发现局域网地址后 DSM 登录 API 返回 `apiFailure:403`，恢复失败；这是 DSM JSON API 错误码，不能写成 HTTP 403，具体凭据/服务器原因仍未确定。随后多次新进程记录 `diagnostics.restore.missing_credentials`，表明那些启动没有已保存的 DSM 凭据，因此连自动登录请求也没有发出。此段不能归因于 VPN。
- 今日 14:52（北京时间）iPad 现场记录用户登录：DSM 主会话与 File Station 登录成功，发现 LAN 地址、完成快照并刷新 47 个服务条目。App 的“记住密码”使用系统钥匙串；偏好中无对应键只是默认值，不能单凭键缺失判断未保存。之后正常终止 App 并冷启动，15:02 新进程再次完成两次登录、LAN 发现和 47 条刷新，未出现新的 `missing_credentials`。这证明今日凭据在首次冷启动中可恢复。
- 原生设备 `testDeviceEnvironmentPublicEndpoints` 重新构建并实际执行 1 项 / 0 失败；DSM LAN、DSM 公网、Jellyfin LAN、Jellyfin 公网四个请求均为 HTTP 200、有效 JSON、API `success=true`。四个 URLSession 事务 `isProxyConnection=false`；LAN 为 HTTP/1.1，公网为 h2。`proxy=false` 仅排除这些事务的 HTTP 代理连接，不能证明 VPN 已关闭，也不能排除 IP 隧道或间歇故障。
- 首次 `test-without-building` 在启动前因本地 `NastartTests.xctest` 构建产物缺失而退出，没有执行设备测试，也不是断言失败；补 `build-for-testing` 后，同一 iPad 上的测试正常通过。有效结果在 `endpoint-probe-v2.xcresult` 和导出附件中。
- 测试后以保留数据方式装回正常签名 Debug 包 `cbfff361…`，无 `DEVICECTL_CHILD_*` 注入正常启动，当前 iPad App PID 8238。15:08 新进程再次完成 DSM/File Station 登录、LAN 发现和 47 条刷新。两次正常冷启动均恢复成功；UI 可见状态、后台恢复、VPN 开关 A/B 及长期稳定性仍未验。

## 下一项

UX-05 保持进行中。若“NAS 无连接”再次出现，先导出该 iPad 当时 App 诊断，分清 `missing_credentials`、DSM API 错误、URLSession 传输错误或 UI 会话恢复延迟；同时记录当前设备 VPN 状态和实际网络路径，再做仅 iPad 的同条件对照。当前日志只支持“保存登录后两次冷启动恢复成功、四个公开接口可达”的有限结论。历史入口见 [9 月 29 日 iPad 专项](2026-09-29-IPAD-ENVIRONMENT.md)。
