# 2026-11-20 iPhone 13 原生 USB 验证与 WDA 接续

接续 [今早的 App 与 WDA 安装](CODEX-2026-11-20-IPHONE13-USB-APP-WDA-INSTALL.md) 和 [播放预检](CODEX-2026-11-20-IPHONE13-PLAYBACK-PREFLIGHT.md)。用户要求直接恢复开发通道。北京时间约 10:32，打开 Xcode 26.6 的 Devices 窗口，选择 Connected 下的 iPhone。实时页面显示 iPhone 13 / iOS 16.3.1 (20D67)，设备标识与 07:33 回执匹配，网络开发连接选项未启用。已装列表有 Nastart 和 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`。Xcode 实际生成 1170 × 2532 PNG，已从桌面移入本机既有私有证据目录。此结果证实 Xcode 能访问当前这台手机，App 安装列表没有提供新版二进制身份的证据。

当前 Codex 命令进程直连本机 `usbmuxd` 和候选 WDA 回环端口均返回 `EPERM`。仅为 USB 枚举而提出的 `idevice_id -l` 提权请求被会话自动审批策略拒绝。Xcode Devices 窗口中的 `Test` 与 `Test Without Building` 均不可用。没有启动 XCTest、绑定 WDA 会话或派发触控。原生截图和 WDA 自动化须分别验收。

本机固定目录的旧 `.xctestrun` 指向 10-25 到期的 Runner。11-20 新签名 Runner 的文件 SHA-256 `04be22094132981816ef4e25c6f5b0ca490f984c4c997a455075e5e4775d510a` 匹配安装回执，宿主与测试 bundle 标识匹配。描述文件的 CMS 内容签名、目标覆盖和北京时间 11-27 07:27:12 到期字段已核，本会话系统信任链没有重新完成。已在 `/tmp/nastart-iphone13-wda-recovery-20261120-1rnjw2av/` 生成权限为 0600 的 `.xctestrun` 副本，修正 `TestHostPath`、`TestBundlePath` 和依赖产物路径，重读验证文件存在及 plist 格式。副本只作后备，尚未在真机执行。原签名文件、原 `.xctestrun`、手机安装和网络设置均保留。

接续需要具备 Mac USB 开发服务和回环端口访问权限的执行会话。优先使用今早验证过的现装 Runner `tidevice xcuitest` 路线，再核 `/status ready=true` 与目标项目 bundle。开始 Nastart 自动化前仍须 fresh 验当前已装路径、包与签名，按原 Wi-Fi Jellyfin 基线接续。当前没有自有运行进程或播放窗口。

10:50 复测 `usbmuxd` 与 `127.0.0.1:8102`，均仍为 `EPERM`，`idevice_id` 同样无法枚举。当前会话的权限配置受管理，无法在该会话提交 USB 授权。已用本机已安装的 Codex CLI `--help` 核对新建交互式项目会话的参数。可由操作者在 Mac 终端使用 `codex -C /Users/lagransun/workspace/Nastart --sandbox workspace-write --ask-for-approval on-request -c 'approvals_reviewer="user"'`，保持工作区沙箱并逐次审核设备访问。若本机管理策略仍禁用审批，需要管理方允许此类请求。该接续方式尚未启动或验证，无手机操作。
