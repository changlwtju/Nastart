# 2026-11-08 Apple TV 22:45 配对后断开

用户截图显示 AppleTV14,1、tvOS 27.2、`Paired`、`Tunnel State: Disconnected` 和 `DDI Services: Disabled`。Mac 当前为 Xcode 27.2（27B52）。用设备标识把截图与 CoreDevice 日志关联，硬件标识及原始日志保存在本机私有证据区。

| 时间（北京时间） | Mac 端观察 |
| --- | --- |
| 22:45:03 | Bonjour 解析同一台已知 Apple TV，IPv6 TCP 59101 建立配对控制连接。父路径带代理标签，实际就绪的子 socket 走 Wi-Fi `en0`。 |
| 22:45:10 | PIN 认证成功，配对状态进入 `Paired`。Device Hub 的 `PairAction` 成功回执已显示 `Disconnected`，未见该目标成功建立开发隧道。 |
| 22:47:07 | 配对控制连接失效，系统日志对原因作私密隐藏。此控制连接与开发隧道是两个阶段。 |
| 22:46 至 22:49 | `devicectl list devices` 未列出 Apple TV；用本次截图关联的 CoreDevice 标识直接查询，返回 1000（找不到指定设备）。Mac 的 preferred DDI 清单有 tvOS 条目。 |
| 22:49 | 同一电视 AirPlay TCP 7000 和 RemotePairing TCP 49152 经 IPv4/IPv6 均可连，旧式广播 TCP 32498 两族都拒绝。观察窗未发现该电视的手动配对广播。按真实硬件标识单次尝试原生开发连接，系统服务在查找设备阶段返回无匹配目标。 |

22:45 这次手动配对的控制通道和验证码已通过。此前 16:18 的拒连发生在配对前，早先的 1005 发生在申请开发隧道时。本轮可见日志和定向查询未复现同一个 1005。当前最早可证实的阻塞是配对身份没有成为 Mac 可用的开发目标，尚不能定位到电视、Mac 或中间网络的具体组件。`DDI Services: Disabled` 为当前设备连接状态，无法据此归因为 Mac 缺 DDI。下一窗口对同一已配对设备同步采集目标广播、开发注册与隧道请求，比较成功认证前后，不重复清配对记录。[Apple Device Hub 指南](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
