# Apple TV 升级 tvOS 27.2 后的 Device Hub 日志

2026-11-08，北京时间。用户报告更新电视系统后 MacBook 仍未识别电视。以 Xcode 27.0（27A266a）和 CoreDevice 642.16 的 macOS 统一日志为主，回查 10:42 以来的事件。NastartTV 的 Xcode 项目目录中没有保留 `.xcactivitylog`，设备连接失败的可用证据来自 Device Hub、CoreDeviceService 与 remotepairingd。新鲜的「客厅」AirPlay 广播及两次失败的设备遥测均确认 AppleTV14,1 / tvOS 27.2，遥测构建号 24K122。同一发现窗口也解析到与该电视 AirPlay 同主机的 RemotePairing 广播。

| 时间 | 已关联到同一目标的记录 |
| --- | --- |
| 13:08:44.800–.816 | 远程配对服务确认认证成功，CoreDevice 的配对动作返回成功。 |
| 13:08:45.925–.942 | Mac 记录发出隧道申请，约 16 ms 后 CoreDevice 返回 4000，内层 RemotePairing 1005。 |
| 13:09:19.053–.068 | 再次认证成功，配对动作返回成功。此轮配对的硬件身份与更新前保存的真机一致。 |
| 13:09:20.144–.151 | 同一 CoreDevice 标识的隧道申请约 7 ms 后再次以 4000/1005 失败。 |
| 13:11:17.596 | 本轮配对产生的设备记录转为 Unavailable，随后移出 CoreDevice。 |
| 13:14 后 | 以已核真机标识只读查询仍返回 CoreDevice 1000。 |

两次申请时，CoreDevice 只找到一个可尝试的设备表示，都是无线配对入口。内层错误文本为 “This device does not support tunnel connections.”。两次失败发生在配对成功之后，早于设备记录转为 Unavailable。系统日志只显示 Mac 组件提交申请和返回错误，未确认隧道申请是否发到电视或由哪端作出能力判定。18.2 与 27.2 均出现相同直接错误，10 月 24 日同一电视曾成功接通并安装，见[旧诊断及历史](CODEX-2026-11-08-APPLE-TV-TUNNEL-1005-DIAGNOSIS.md)。

Apple 的 Device Hub 指南注明系统升级后需要重新配对，本次两次配对成功已确认。Apple 支持表将 Xcode 27 的真机支持列为 tvOS 17 或更高，Xcode 27.2 提供同版本 tvOS 27.2 SDK。单凭 SDK 与电视版本号差异无法解释 1005。下次有复现窗口时，优先同步记录 Mac 隧道日志与该电视的定向网络流量，核实申请阶段是否发生网络往返。独立 Mac 暂不可用。[Apple 配对文档](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub) · [Xcode 支持表](https://developer.apple.com/xcode/system-requirements/)。

本轮只读回查，无新配对、系统设置修改、签名、构建、安装或媒体测试。原始系统日志与设备标识保存在 `/tmp/nastart-codex-tv-update-1108-path` 指向的私有目录。

## 16:18 截图中的配对失败

用户提供的 Device Hub 截图显示「Appletv」、`DeviceKitError 5000`，下层两个 `-1`。用截图内的设备标识核对到 16:18:07 和 16:18:22 两次 PairAction。Mac 从 Bonjour 解析到手动配对端口 TCP 55747，两个 IPv6 地址和一个 IPv4 地址上的连接都从 Wi-Fi 接口收到 `Connection refused`（POSIX 61）。两次控制通道都在准备约 10 秒后被取消，配对动作返回 CoreDevice -1，内层 RemotePairing -1。该设备条目未建立控制通道，因此本次未进入验证码认证或开发隧道申请，与 13:08/13:09 配对成功后收到 1005 的记录分开。网络日志的外层路径曾显示代理接口，失败的实际地址连接记录为 `en0`，目前无法将拒连归因于特定 VPN 或网络过滤。

16:21 只读复核，「Appletv」的 AirPlay 与手动配对广播解析到同一台 AppleTV14,1，AirPlay 报 tvOS 27.2。广播仍列 55747，该端口在三个地址上仍拒连，而同一主机的 AirPlay 7000 在三个地址都可连接。证据定位到当时公布的手动配对端口，无法单凭 Mac 日志确定是电视未监听，还是路径上返回拒绝。下一次可先退出再进入电视的「遥控器 App 与设备」页，核对新的广播与端口是否可连，再决定是否进入配对。没有执行新配对、重启或安装。[Apple 配对入口](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)。本批原始设备标识、地址和日志仅在 `/tmp/nastart-tv-devicekit-5000-1108-path` 指向的私有目录。
