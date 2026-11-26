# 2026-11-09 Apple TV 有线现场与十月成功记录

后续补到 21:16 的 Wi-Fi 截图及两窗详细日志：Wi-Fi 与有线均认证成功但没有连上开发隧道；后续以[两窗对照](CODEX-2026-11-09-APPLE-TV-WIFI-WIRED-PAIRING.md)为准，不需要先换回 Wi-Fi。

用户已将电视接入有线网。21:25 的照片显示电视在以太网上自动获取 IPv4、路由和 DNS；同窗 Device Hub 显示 AppleTV14,1 / tvOS 27.2、`Paired`、`Local Network`、`Tunnel State: Disconnected`、`DDI Services: Disabled`。Xcode 27.2（27B52）运行 `devicectl list devices` 成功，列表没有该电视。Mac 直达照片上的电视有线地址，ICMP 2/2，AirPlay、远程配对与 Lockdown 的定点 TCP 端口可达；同一有线 IPv4 所在的 Bonjour 主机还解析出两个 IPv6 地址，两者均能建立 AirPlay TCP，不能用 IPv6 完全不通解释当前故障。旧的 32498 本次超时，未将它当作当前开发隧道端口。21:22–21:29 与电视关联的 Mac 日志有 Bonjour 识别及已配对设备记录，没有看到可归于本次截图的 1005。发现和已配对仍成立，开发隧道未建立；DDI 未启用是当前状态，不能据此认定 Mac 缺开发镜像。

| 日期 | 有证据的设置和结果 |
| --- | --- |
| 10 月 18–19 日 | Xcode 26.6 输入电视验证码，Mac 确认认证成功；Mac Wi-Fi 的 IPv6 为自动，已验证当时的部分 IPv6 服务可达。刷新 Mac 用户级设备服务曾恢复发现，随后仍显示开发未就绪。([18 日](../2026-10/2026-10-18-ORIGINAL-ROUTE-RACE-AND-TV.md) · [19 日](../2026-10/2026-10-19-APPLE-TV-PAIR-RECORD.md)) |
| 10 月 24 日 | 同型号真机、tvOS 18.2，开发连接与 DDI 可用；13:48 安装首个签名开发包，14:15 保留数据覆盖，14:16 核启动画面。([当日交接](../2026-10/2026-10-24-TV-PARITY-AND-DEVICE-REGRESSION.md)) |
| 10 月 29 日 | 同一电视经 LAN 两次保留数据覆盖，06:53:49 最新一次并核正常启动与首页。([当日交接](../2026-10/2026-10-29-TV-DISCONNECTED-PAGES-AND-WIRELESS-UPDATE.md)) |

10 月 24 日的日志从开发连接已经可用开始；未找到 19 日至 24 日之间的恢复动作，也没有证据证明手填 IP/DNS、换线、清缓存或 VPN 改动导致恢复。成功时使用局域网且有覆盖电视的有效开发签名；当时未记载电视实际走网线还是 Wi-Fi。11 月 8 日已另见验证码认证成功后开发隧道不通；22:45 同版 Xcode 27.2 也呈现已配对但不可用。([11 月 8 日晚记录](CODEX-2026-11-08-APPLE-TV-2245-PAIRING.md))

下一窗保留已有配对，保持 IP/DNS 自动，优先同一个主 Wi-Fi 做一次与现有有线连接的对照，确认 IPv6 可用并让电视停在“设置 → 遥控器与设备 → 远程 App 与设备”。同步观察开发隧道日志与定向流量，先验证 CoreDevice 可用，再谈签名安装。Apple 的 [Device Hub 指南](https://developer.apple.com/documentation/Xcode/managing-your-simulated-and-physical-devices-in-device-hub?changes=la_7_9&language=objc) 要求同网且支持 IPv6。没有第二台 Mac，宿主与电视的独立对照仍待；本轮未改配对、设备、VPN、NAS 或路由配置，未发送安装。
