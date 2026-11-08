# 2026-09-29 iPad 环境专项

用户已要求继续 iPhone 13 调试，同时针对 USB 接入的 iPad 独立测试 DSM 经常未连接与 VPN 的关系。保留工作区及设备数据，不改承担远程连接的 Mac/路由器网络，不发起大片转码。

## 已完成：设备及历史凭据核验

- iPad 9 代 `REDACTED-DEVICE-02` / iPadOS 18.3.1，USB 与 CoreDevice 均可见。已有 Nastart 与 WDA，旧包不能仅凭 0.1.0(1) 确认身份。
- 覆盖安装前导出本机 App 偏好和诊断。记录最新到 9 月 27 日；多次手动 DSM 登录成功之后，新进程反复记录 `diagnostics.restore.missing_credentials`。没有 `connect.remember.password` 偏好键；钥匙串内容没有导出。这证明历史自动恢复因无凭据跳过，不能据此认定 VPN 是唯一原因，也不能证明当前 VPN 路径正常。
- 历史还存在 `urlError:-1005` 及 DSM `apiFailure:403`。后者为 DSM JSON API 错误码，不能当成 HTTP 403；与“没有发出恢复请求”分开分析。
- Mac 侧 Jellyfin 局域网及公网公共接口 HTTP 200 / 10.11.11，仅证明 Mac 路径；不代替 iPad 环境连通性。
- iPad WDA 的旧 tidevice 不适配 iOS 18 开发服务；使用已有 xctestrun 在两套本机 Xcode 启动 runner，均失败于 `Timed out while enabling automation mode`。这不是 Nastart 崩溃结论。已请用户保持解锁、处理系统自动化提示，以及在当前包登录一次并开启记住密码；不要在对话中发送密码。

## 接续

用户补充授权：必要时可直接远程解锁 iPad，无需再次询问。具体解锁凭据不记入项目/证据文件。收到授权后重查系统：`passcodeRequired=false`、`unlockedSinceBoot=true`，当前无需输入；不能把既有自动化初始化超时归因于等待开机密码。DSM 保存登录与系统解锁是两个独立检查点，仍以实际 Keychain 恢复日志为准。

本轮失效的 8103 转发已停止，不能直接使用旧端口或 session ID。有效签名的专用 WDA 副本保留在 `~/Library/Application Support/Nastart/WDA/iPad-18.3.1/`，描述文件包含本 iPad、到期 2026-10-03；系统自动化初始化问题没有解决。iPhone 13 的 8102 不受此清理影响。

最终收尾：四份附件逐项确认 DSM-LAN、DSM-public、Jellyfin-LAN、Jellyfin-public 都是 HTTP 200 / json=true / success=true。测试注入包已保留数据覆盖回正常 `37b0…` 持久候选，并清除调用侧 `DEVICECTL_CHILD_*` 后正常启动。最新 WDA 复试仍“开启自动化模式超时”，不能记 ready；未验证 iPad 播放、登录冷恢复或 VPN A/B。需用户在 iPad 正常包登录一次并确认记住密码，随后再验自动恢复；不要将“记住密码默认开启”当作已经有凭据。当前网络成功和无凭据跳过恢复分别记录，不能据一次成功排除所有间歇故障。

09:50 已完成当前 iPad 的四接口测试：只重启该机 testmanagerd，SIGTERM 未换 PID，SIGKILL 后 `4564`→`7690`。原生 XCTest 实际执行 1 项、0 失败、未跳过，四个 DSM/Jellyfin LAN/公网请求均 HTTP 成功且有效 JSON，DSM API 未返回 success=false。同一新进程再次记录无已保存 DSM 凭据。没有切换/读取当前 VPN UI，不能称 VPN A/B 或完全排除间歇性代理故障；这次失败恢复路径没有凭据，本身就没有发出 DSM 登录请求。证据 `endpoint-probe-v3.xcresult` 与导出附件；正在覆盖回无测试注入的正常候选包、恢复 WDA。

09:45:59 新证据：不依赖 UI 自动化的 Nastart 单元测试宿主已正常启动，现场日志再次明确“未找到已保存的 DSM 凭据，跳过会话恢复”。开发模式 Enabled，系统已解锁且背光亮，开发镜像 usable；有效签名/包含该 iPad 的专用 WDA 仍自动化模式初始化超时。现正在同一 iPad App 网络环境内逐个请求 DSM LAN/公网 API Info、Jellyfin LAN/公网公开信息，不携带凭据、不调整 VPN、不请求视频。原生测试附件只记标签、HTTP/JSON 成功与错误域/码。

09:27 已保留数据覆盖安装同一状态诊断候选包并用 CoreDevice 正常启动。导出的偏好仍是 9 月 27 日历史，未捕获新的 UI 登录恢复过程；不能宣称当前无凭据已再次复现。WDA 未 ready，LLDB 未能完成附加，不用它们的失败推断 App 崩溃。保留原始崩溃报告，未见 9 月 29 日 Nastart 报告。正在同步 iPhone 13 的轨道偏好修正候选，身份以最新交接为准。

先同包安装、保存登录、冷启动与后台恢复，再捕获当前 VPN 状态下不带凭据的 DSM query / Jellyfin 请求。失败时先留 App 与代理连接证据，随后才做仅 iPad 的 VPN A/B；不凭“VPN 已开启”推定根因。WDA 未恢复前不能宣称界面、iPad 播放或 VPN 比较已通过。

原始偏好与日志仅在本机私有目录 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-ipad-environment/`，不得提交或上传。

## 12:04 实际请求路径补证

2026-09-29 12:04 iPad 请求路径实测完成：原生设备 XCTest 实际 1 项通过 / 0 失败；DSM API Info 与 Jellyfin Public 的 LAN/公网四地址均 HTTP 200、有效 JSON、API 成功。四次 URLSession 事务 isProxyConnection=false，LAN 使用 HTTP/1.1，公网使用 h2，均未复用连接。此指标只排除这些请求的 HTTP 代理连接，不能证明 VPN 已关闭或排除 IP 隧道/间歇故障。新进程仍报 restore.missing_credentials；UX-05 保持进行中。附件留在本机 continuous/ipad-route.xcresult 与 ipad-route-attachments/，不含请求凭据。

## 12:40 正常包收尾

两机已保留数据安装签名正常 `f08bf…` 包，iPad 通过不带 DEVICECTL_CHILD 注入的 CoreDevice 正常启动，PID 7846。12:26:02 新正常进程再次报无保存 DSM 凭据。四接口/HTTP代理指标结论保持：请求连通且 proxy=false，不能推出 VPN 关闭。无 UI 自动化、登录恢复或播放验收；需要先保存 DSM 登录。用户解锁授权继续有效，凭据不写入项目。
