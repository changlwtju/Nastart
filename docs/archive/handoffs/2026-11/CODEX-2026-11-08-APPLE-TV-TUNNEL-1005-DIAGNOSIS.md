# Apple TV 配对后的开发隧道错误 1005

2026-11-08（北京时间）。接续[配对、重启及接线记录](CODEX-2026-11-08-JELLYFIN-LOGIN-AND-APPLE-TV-CONNECTION.md)。范围限 Apple TV 的只读开发连接诊断。结构化证据见[安全结果](../../../testing/results/2026-11/CODEX-APPLE-TV-TUNNEL-1005-DIAGNOSIS-20261108.json)。

已将失败定位到 **CoreDevice 为已配对的「客厅」申请开发隧道时，RemotePairing 返回 1005**。两条错误由「客厅」名称、临时 CoreDevice 标识与 action invocation 关联，均为 CoreDevice 4000 内嵌 `com.apple.dt.RemotePairingError` 1005，文本为 “This device does not support tunnel connections.”。请求到失败约5–7ms。电视为何在这两次会话被判定无法建立隧道，系统没有给出更深的可见原因。

| 时间 | 同目标证据 |
| --- | --- |
| 09:47:30 | RemotePairing 及 Device Hub 确认手动配对成功。 |
| 09:47:31 | CoreDevice 从「客厅」的 RemotePairing 设备表示申请隧道，收到4000/1005。 |
| 09:48:23 | 手动配对广播消失，暂存设备记录由 Paired 转为 Unavailable。 |
| 10:20:03 | 同日另一轮配对成功由既有系统日志回溯确认，本次诊断未发起配对。 |
| 10:20:05 | 同一设备再次收到4000/1005。 |
| 10:22:01–02 | 已认证的配对控制通道失效，暂存设备转为 Unavailable。 |
| 10:26:52 | `remotepairingd` 将 Bonjour 广播匹配到已配对的客厅硬件身份。 |

## 广播端口与实际连接

按新鲜 DNS-SD 解析重新对照同一目标的 IPv4、IPv6 链路本地和另一 IPv6 地址。AirPlay `7000`、RemotePairing `49152` 三个地址均建立 TCP，旧式 `_apple-mobdev2._tcp` 广播的 `32498` 三个地址均返回 ECONNREFUSED，标准 Lockdown `62078` 均建立 TCP。上次把32498直接称为开发端口过于宽泛。它属于传统设备发现，当前日志没有证据表明 CoreDevice 申请隧道使用该端口，或由该端口的拒绝触发1005。无法仅凭 SYN 结果区分广播与监听不一致的具体成因。此前在62078读到匿名型号/系统，未形成认证开发会话。[Apple 端口说明](https://support.apple.com/en-us/103229) · [RemoteXPC 协议实测说明](https://github.com/doronz88/pymobiledevice3/blob/master/misc/RemoteXPC.md)。

在 macOS26.7（25G229）用 Xcode27.0、26.6 逐一对真实电视硬件标识执行详情查询，两者共用 CoreDevice 642.16，均返回1000找不到设备。32秒只读 `remotepairingd` 事件观察收到 `allCurrentDevicesListed`，未出现该电视的开发端点。`remotectl list` 和 USBMux 当前枚举均无目标。1000是后续查询现象，1005是此前关联到本机请求的直接失败。日志同窗出现 CPU 架构解析警告，缺少证据将它作为1005成因。

同一台 AppleTV14,1、同一 tvOS18.2 在10月24日已通过开发/DDI并完成真实安装。两版本 Xcode 的官方支持范围也包含 tvOS18.2。当前错误不足以把问题归为机型永久不支持或 tvOS 版本低于要求。两版 Xcode 共用宿主组件，换版本查询结果不能当独立 Mac 对照。IPv6 的实测可达也无法单独判定隧道阶段的 VPN 影响。[同设备历史安装](../2026-10/2026-10-24-TV-PARITY-AND-DEVICE-REGRESSION.md) · [Xcode 支持范围](https://developer.apple.com/xcode/system-requirements/) · [Apple 连接过滤诊断](https://developer.apple.com/documentation/technotes/tn3158-resolving-xcode-15-device-connection-issues)。

后续优先用另一台同网 Mac 建立独立对照，并比较配对成功后实际的隧道申请结果。若只能用本机，需在用户安排的独立窗口对照 Mac 网络过滤或共享设备服务状态。接着按开发连接、签名、安装的顺序重新过门槛。无新配对、安装、启动或配置改动。没有媒体回归，本批不变更播放验收。原始身份、端点、设备日志只在 `/tmp/nastart-codex-tv-root-cause-1108-path` 指向的私有目录。

## 独立 Mac 对照

用户指定用第二台实体 Mac。10:41:47 原宿主复核（macOS 26.7，Xcode 27.0 27A266a）仍报 CoreDevice 1000，配对后隧道申请的原宿主对照基线采用上面两次 4000/1005。当前会话只接入原宿主，第二台 Mac 尚未实测。

保持「客厅」Apple TV 的有线连接、路由器和系统版本一致。第二台 Mac 接入同一局域网，记录 macOS 和 Xcode 版本。电视保持在「设置 → 遥控器与设备 → 遥控器 App 与设备」，第二台 Mac 用 Xcode Device Hub 完成配对，若出现 PIN 由现场用户在第二台 Mac 输入。配对后在 Device Hub 查看实际真机详情，也可查询 `xcrun devicectl device info details --device '客厅' --timeout 10`。核对目标型号、tvOS 版本和开发连接状态。查询失败时记录阶段与错误码。只读验证，无需安装 App 或移除原 Mac 配对。[Apple Device Hub 配对步骤](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)。

- 第二台 Mac 建立开发连接并读到该电视详情，问题范围收窄到原 Mac 或原 Mac 与电视的配对状态。
- 第二台 Mac 也在配对成功后申请隧道时报 4000/1005，问题可跨宿主复现。电视端状态、共用的网络条件及 Apple 开发组件仍待区分。
- 第二台 Mac 无法发现、无法配对，或只见 1000，均未对照到原来的隧道失败阶段，根因仍待确认。

用户随后确认目前没有第二台 Mac，独立对照暂缓。原 Mac 对已匹配的 RemotePairing 目标做只读路由查询，IPv4、IPv6 链路本地及另一 IPv6 地址均走局域网接口 `en0`。路由结果只说明当前这些目标地址的出口，应用层连接或隧道阶段仍可能受过滤影响。回查两次失败时的 `com.apple.dt.remotepairing:connectabledevice` 日志，Mac 组件记录发送隧道申请后约 5–7ms 上报 1005。该日志未提供线上请求和电视端响应的证据，仍无法确定能力判定出自哪一端。下次复现时可同步记录一次配对后的请求日志和该电视的定向网络流量，以确认隧道申请阶段是否有网络往返。现有配对和网络设置均保留。
