# 2026-11-20 iPhone 13 单机调试链路

用户已断开 iPad，本轮仅使用 iPhone 13。北京时间 17:24–17:33，Xcode 26.6 Devices 的 Connected 下唯一手机为 iPhone 13（iPhone14,5 / iOS 16.3.1，20D67）。设备名为 iPhone，完整 UDID 与今早安装回执一致；iPad 在 Disconnected。未测试 iPad、iPhone 18 或 Apple TV。

## 安装门槛与原生通道

- Xcode 的已装列表读取到 Nastart 及既有 WDA。已用原生 Download Container 保存 Nastart 容器并解析偏好文件，确认对应 bundle、30 项偏好和现有本地诊断可读。备份及原始证据位于 Mac 仓库外权限 0700 的本轮目录。备份不包含系统钥匙串。
- 当前源码为 `8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加原有 dirty。按现有 647 项清单重算，和 11-19 构建清单有差异的产品文件为 `DevicesView.swift`（两个路径别名）。当前 iOS diff SHA-256 `12a6af072d6a21ba717070ac4ea6ab3f49d380159ca99ff66f1de9b862df2d60`。私存清单和完整差异。现有 647 项中没有晚于下述构建的输入；Xcode 用户界面状态文件较新，不属于编译输入。
- 最新本地候选为 Xcode 27.2 的 11-20 16:36:24 Debug-iphoneos 构建，位于该工作区 DerivedData 的 `Build/Products/Debug-iphoneos/Nastart.app`。冻结产物绝对路径私存。主程序 SHA-256 `4ed3910f540da35336bcc0c9bb6e4bccbb60173c6ca619874557d0b1ee2c79de`，Debug dylib `5c51e0fef8bd5766db1d859b4773e0feb8caf02f59b567556046ece05e98369b`。描述文件 CMS 内容签名通过，含 iPhone 13，Apple Development profile 到期北京时间 11-27 07:27:01。系统 `codesign --verify --deep --strict` 返回 `CSSMERR_TP_NOT_TRUSTED`，未通过完整签名复验。
- 上一个实际装包回执仍是 07:33 的 Debug dylib `39299886…`，早于诊断变更。Xcode 的版本列不能重验当下的二进制身份。未发送安装、未启动 Nastart 或 Runner。

## WDA 链路检查

- 真机存在已由 Xcode 原生通道和容器下载证实。当前命令会话的 usbmuxd 套接字返回 `EPERM`，`idevice_id` 无法枚举。只读命令的 sandbox 提权请求被会话自动审批策略拒绝。下午在同一设备已记录 Xcode 26.6 原生 XCTest 启动前 `Logic Testing Unavailable`，保留该失败，本轮无新触控结果。
- `start_wda_iphone.sh --check-usb` 现在可独立检查 USB 服务权限、回环端口及当前目标的 USB 身份。完整启动先过相同预检，再使用本轮独立日志目录。已有占用须核归属，不凭同 bundle 的旧回环响应接管。新转发绑定当前 USB 标识与 127.0.0.1。
- `prepare_wda_recovery.sh` 优先定位本机 Xcode 26.6 安装，检查描述文件的目标和 Runner bundle，以及 `.xctestrun` 实际宿主和测试 bundle 路径。使用当日上午修正的私有描述文件和现装 Runner 候选时，上述检查进入最终 codesign 阶段，当前会话在信任检查处仍失败。
- 两个脚本语法检查及 70 项既有 WDA 测试通过。另用合成夹具验证 11 项，覆盖权限拒绝、服务缺失、端口占用、目标缺失、身份变化、只读预检成功、正确夹具、错误宿主、错误测试包、设备不在 profile、过期 profile。当前会话的真实命令复现 USB 权限拒绝。

## 收尾与下一窗

Xcode 容器下载已退出忙碌状态。本轮无自有 Runner、端口转发、播放、网络切换或媒体流量，无启动前台测试环境。已释放本轮 iPhone 13；播放矩阵与需求状态未发生变化。

接续使用能访问本机 USB 开发服务、回环端口和系统签名验证的 Mac 会话。先跑 `--check-usb` 并重新核包和设备，验签通过后保留数据覆盖，核正常首页和偏好。随后复用已装 Runner，按 ready、会话、当前前台、截图及实际点击确认触控，再进入 App 功能回归。现有接续路线和权限限制见 [原生 USB 与 WDA 接续](CODEX-2026-11-20-IPHONE13-USB-NATIVE-RECOVERY.md)。

## 18:02 历史对照与当前复测

- 09-10 已验证过同一 iOS 16.3.1 的 USB 兼容链。CoreDevice 当时显示 unavailable，`idevice_id`、配对和 `ios-deploy` 仍可用，现装 Runner 经 tidevice XCTest 和 iproxy 就绪。 [历史兼容链](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md#2026-09-10ios-16-在线状态判断纠正)
- 11-12 曾有确证的设备端开发服务故障。DTServiceHub 日志报 `kqueue(): 24`，经用户批准重启、解锁并重挂同一镜像后，原 Runner 恢复、Nastart 读库。当前命令在 Mac 连接 usbmuxd 与绑定回环端口时均返回 `EPERM`，还没到设备端 XCTest，无法确认是否存在同类设备端故障。 [11-12 恢复记录](CODEX-2026-11-12-IPHONE13-WDA-RECOVERY.md)
- 11-20 11:28:03 的原始状态和输入记录相符。允许交互审批的本机会话使用现装 Runner、tidevice XCTest 和 USB 转发 8168，实际打开文件夹并按 Home 返回。Runner 和转发在 11:30 正常收尾。11:40 再核包后，11:56:38 的 Nastart 续播有实际画面，持续采样不完整。 [触控记录](CODEX-2026-11-20-IPHONE13-WDA-RESTORED.md) [实播记录](CODEX-2026-11-20-JELLYFIN-DUPLICATE-DEVICE-ID.md)
- 当前最早且可独立复现的阻塞为命令会话权限。Xcode 原生 USB 的识别、取图和备份成立。下午 `Logic Testing Unavailable` 属于 Xcode 直接启动测试的失败，现有证据不足以定位该报错的内部原因。16:36 App 候选签名验收和覆盖待续，单独管理。

本轮仅对照记录与复测 Mac 本地连接/绑定权限，无设备进程操作。最短接续路径是恢复获准访问 USB 和回环的执行环境，复用上午的 Runner/USB 路线，同时遵守最新 App 的安装门槛。未取得新的 WDA 或播放结果。

## 18:12 改用 Mac 桌面客户端接续

用户确认上午的成功发生在 Mac 终端，现在要求在桌面客户端内调试。桌面 **Codex → Nastart → Local / This computer** 可使用当前项目目录及未提交源码。输入框下方选择 **Ask for approval**。该模式保留工作区沙箱，由用户审批符合条件的单次访问请求。若客户端或管理策略禁止该模式或禁止发出审批请求，需记录显示的具体限制。 [Codex 运行环境](https://learn.chatgpt.com/docs/environments/modes) [桌面权限模式](https://learn.chatgpt.com/docs/permission-modes)

当前会话的界面控制无法打开 ChatGPT/Codex 自身窗口，尚未观察本机权限菜单，也未更改模式。用户在桌面应用中选好模式并发起接续后，先在 Nastart 本地目录执行 `scripts/start_wda_iphone.sh --check-usb`。常规沙箱返回 `EPERM` 时，以该只读预检请求单次审批。记录 USB 身份和回环绑定结果，之后才进入验签、保留数据覆盖及现装 Runner 触控对照。此轮无设备操作。

## 18:21 桌面会话复测

当前会话执行只读 `LOCAL_PORT=8168 scripts/start_wda_iphone.sh --check-usb`，访问 usbmuxd 返回 `EPERM`。独立尝试绑定 `127.0.0.1` 临时端口同样返回 `EPERM`。再次提交同一个只读预检的单次审批请求，工具明确返回当前受管策略中 `sandbox_approval=false`、`request_permissions=false`，请求在弹窗前被拒。无法从该返回值判断用户当前权限菜单的选择。

16:36 Debug 的 647 项源码清单和两份主二进制哈希均与记录一致。此前候选描述文件覆盖目标；本轮系统 `codesign` 仍报 `CSSMERR_TP_NOT_TRUSTED`。未取得新的设备身份、签名验收或安装回执，未启动 App 或 WDA。当前需要确认权限菜单已选 Ask for approval 的 Nastart 本地 Codex 对话是否能发出审批，再执行相同预检。若该对话仍返回受管拒绝，记录实际菜单和策略返回值以确定客户端侧阻塞。

## 18:30 实际权限与接续范围

Mac 用户 Codex 配置已设置完整访问，当前桌面对话的实际执行策略仍禁止沙箱审批及权限请求。再次提交只读 USB 预检，在运行前明确被拒。客户端项目接口未返回可用项目。未改权限、设备设置或 App。接续将现装 WDA 启动、实际输入验证、获准调试与收尾作为同一个工作窗口，避免反复要求用户接续预检。
