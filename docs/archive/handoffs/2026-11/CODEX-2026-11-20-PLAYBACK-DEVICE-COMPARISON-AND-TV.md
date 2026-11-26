# 2026-11-20 三机包对照、iPhone 13 播放及 Apple TV 排查

用户反馈 iPhone 18 播放较顺滑，iPhone 13 卡顿，并接入 A16 iPad 作对照。11-19 07:30:40 完成的 Xcode 27.2 Debug 同一次构建分设备签名。三份清单的 HEAD 和 iOS diff 哈希相等。直接比较有文件内容的 Mach-O 段，三份主程序的 UUID 和 11 个段相等，三份 Debug dylib 的 UUID 和 49 个段相等。签名后的整文件哈希不同。iPhone 13 在本日 11:40 的真机预检仍匹配实装回执。iPad 和 iPhone 18 使用最新安装回执，本次没有重新读出其设备上的二进制，也没有操作 iPhone 18。

## iPhone 13 与 iPad

复核 [已收尾的 iPhone 13 Wi-Fi 窗口](CODEX-2026-11-20-JELLYFIN-DUPLICATE-DEVICE-ID.md)。S19 由 DSM File Station 设备文件走原流、localRangeProxy、KSPlayer。`3F9EE268/CBFDE353` 续播目标 67.092 秒，内部首帧 6.285 秒。截图在 10 秒观察点出画并显示缓冲。出画后诊断两次缓冲，记录时长分别约 12.8 秒和 9.7 秒。请求自动降档时，同窗响应正文采样估值 47.85 Mbps，播放器所需估计 76.28 Mbps，前向缓冲约 0.42 秒。Jellyfin 媒体匹配失败后记录 `automatic_downshift_abandoned`，没有观察到降档接管。该次媒体匹配错误未记录明确 HTTP 状态，与独立读库 401 分开判断。30 秒截图、连续帧时间和有证据的普通退出缺失。

Device Hub 读到已连接的 A16 iPad / iPadOS 26.6 和已装 Nastart、WDA。原生 App 启动操作后，12:08 Xcode 26.6 真机截图实见 Nastart 前台《指环王1：护戒使者》详情、继续观看和从头播放，Wi-Fi 及 VPN 状态图标可见。Device Hub 提示该 OS 不支持其屏幕共享。Accessibility Inspector 可选 iPad，但未取得可用于开始播放的控件操作；未建立有效 WDA 触控通道，未派发播放。相同片名不证明实际入口、续播点、音字幕轨或网络路径相同，双设备同条件对照还未完成。

## Apple TV

Xcode 27.2 Device Hub 留有 `Appletv` / tvOS 27.2 条目，显示 Currently Unavailable。切换到 Pair Nearby Device → Apple TV 后，持续显示 Searching，列表空，Next 不可用。Xcode 26.6 普通 Devices 列表无电视。当前执行会话的 `dns-sd` 调用返回 Service Not Running，`devicectl` 也未返回设备列表，不能以此推断真实电视的 Bonjour 广播、网络或配对状态。Mac 原生投屏发现入口未返回有效结果。本窗没有重新配对、删除已有设备记录、改系统网络或安装 App。

接续时让电视停留于「设置 → 遥控器与设备 → 远程 App 与设备」，在该页开启期间复查附近设备，记录何时出现于发现列表和可运行目标。iPad 与 iPhone 13 待从同一 DSM 设备文件样本、相同播放起点、轨道和已核实际网络条件作串行测试，比较吞吐、前向缓冲和连续播放表现。暂不据跨设备主观体验归因硬件、解码或版本。

## 当日下午接续

13:52 Device Hub 普通设备视图仍将电视标为 Currently Unavailable。新一轮 Pair Nearby Device → Apple TV 已找到 `Appletv`，选中后进入电视验证码页。没有移除已有配对或发起安装。待用户提交验证码后确认是否出现可运行目标，当前只确认发现与请求验证码成功。USB 应用服务仍返回 `EPERM`，WDA 的 iPad 与 iPhone 13 本机端口均拒绝连接。本轮没有发出追加播放请求。

回看 `3F9EE268` 的降档时序：11:56:45.746 请求降档，11:56:48.172 设备文件的 Jellyfin `GetItems` 匹配记录 `Get.APIError`，11:56:48.173 放弃降档。旧包在此只保存 `NSError.code=0`，没有 HTTP 状态。独立媒体库 401 与这里的 HTTP 响应单列。当前源码已让媒体匹配的失败事件沿用 `JellyfinHTTPStatus` 记录真实响应状态，仅记录有可识别状态的错误。未改选路、重试、登录或匹配标准。Swift 语法解析及 160 项离线播放工具测试通过。诊断修改尚未构建或安装，三机之前实装的同构建包继续作为基线。

16:25–16:29 复验：Device Hub 的 `Appletv` 六个验证码输入框仍为空。USB 开发服务仍返回 `EPERM`，iPad 与 iPhone 13 的 WDA 端口仍未监听。没有另发配对、安装、播放或网络设置动作。使用 `Package.resolved` 固定版本 Get 2.2.1 与当前源码原样提取的 HTTP 状态诊断逻辑，独立编译运行 8 项通过。401、403、429、503 均保留实际状态。连接超时、无法连接、非 HTTP 错误代码 401、无效状态 999 均不生成 `httpStatus`。

无签名 iOS Debug 构建尝试未进入应用编译：Xcode CLI 拒绝打开原工作区和隔离副本，改用隔离 `.xcodeproj` 进入依赖解析后，SwiftPM 的 ManifestLoading 诊断缓存写入返回 `Operation not permitted`。已指定临时 `-packageCachePath`，SwiftPM 仍请求写系统缓存。保留 `/tmp/nastart-lookup-http-build.KvUAiF/` 失败日志，没有修改共享缓存。诊断源码尚未形成可安装新包，之前 iPhone 13 媒体匹配失败的实际状态仍未知。

## 16:36 至 16:58 原生构建与触控验证

- 16:36 使用 Xcode 27.2 原生界面以 A16 iPad 为目标，在 Nastart 工作区完成诊断版构建。只执行了 Build。新包尚未核对安装身份或部署。媒体匹配失败的实际 HTTP 状态仍待实测。
- 两台现装来源的 WDA 续签产物通过 `codesign --verify --deep --strict`，描述文件覆盖各自设备。16:41 A16 iPad 原生 XCTest 成功执行 `UITestingUITests.testRunner`，Runner 日志公布 WDA HTTP 服务。当前 Codex 命令会话访问该地址返回 `EPERM`，没有取得 WDA `/status` 或 HTTP 操作会话。已从 Xcode 停止本轮 WDA。
- 16:56 iPad 同一原生 XCTest 通道使用独立 Runner 验证实际触控。时钟 App 原在「世界时钟」，测试点击「秒表」、断言选中状态改变，再点回「世界时钟」并返回主屏幕，测试通过。首轮 Spotlight 手势未观察到预期界面。另一带独立宿主的验证因免费签名安装数量上限未进入点击。已卸载本轮临时 Runner，并在 Xcode 安装列表确认原 Nastart 和原 WDA 仍在。
- iPhone 13 在 Xcode 26.6 中同期核到 iOS 16.3.1 和现装 Nastart、WDA。通过原生 `Test Without Building` 复用续签 Runner 时，启动前报 `Logic Testing Unavailable`。使用带 `TEST_TARGET_NAME` 的标准宿主 UI 测试再次报同一错误，未启动测试或安装探针。Accessibility Inspector 可选该设备，本轮未返回可执行的元素动作。此会话的 `usbmuxd` 仍拒绝访问，未能复用上午已实测成功的 USB XCTest 通道。
- 本轮无 Nastart 播放点击、无新性能数据。Apple TV 的原生验证码窗口保留，未提交验证码。

## 17:06 开发连接复查

- 在 Device Hub 关闭旧的验证码窗口并重新开始附近发现。`Appletv` 在新扫描中出现，可进入新的六位验证码页。Xcode 26.6 同时在 Discovered 下显示该设备。本轮未解除原配对，待在 Mac 输入电视现场显示的验证码后验证能否进入 Connected 和 tvOS 真机运行目标。
- Xcode 26.6 的 Connected 列表仍显示 USB iPhone 13 / iOS 16.3.1，可查现装 WDA 和截图入口。当前 Codex 命令会话对 `usbmuxd` 的访问仍返回 `EPERM`，未启动 Runner 或派发触控。Mac 的原生「切换控制」当前关闭，本轮在启用前等待用户确认。

## 17:14 Apple TV 验证码提交后

用户在电视看到新验证码。已在 Mac Device Hub 提交，验证码窗口随即关闭。提交后多次查看 Apple TV 的详情，`Appletv` / tvOS 27.2 仍显示 Currently Unavailable。Xcode 26.6 的设备列表此时也未显示电视。原生打开 NastartTV 工程检查运行目标，出现通用 tvOS 构建目标和模拟器类别，未出现 `Appletv` 真机。已确认验证码提交后未建立可用开发连接，本次无独立认证成功或失败日志，也未发安装。
