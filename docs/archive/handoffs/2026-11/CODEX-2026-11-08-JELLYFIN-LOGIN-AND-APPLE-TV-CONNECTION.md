# 13 Jellyfin 恢复与 Apple TV 开发连接

2026-11-08（北京时间）。关联[前批最新包与基线](CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)及[结构化结果](../../../testing/results/2026-11/CODEX-JELLYFIN-LOGIN-AND-APPLE-TV-CONNECTION-20261108.json)。

## iPhone 13

用户在 App 内重登。09:24:39 fresh 确认 iPhone14,5 / iOS16.3.1 / USB，完整名称和 UDID 私存。源为 main `4de732dd645b36671becff992cdef1d0163fd1e4` 加既有未提交内容，542 输入与冻结包清单同。09:15:50 冻结的正常 Debug `-Onone` 包 main `384be2453843e34fa463b6f75f6aa8232c669f87abbf5b6dfdbf6cc40a65fdff`，dylib `bb4defd4dcd424acfe0b7e3c540da8f0869d0d8b52cabec510a2e01e242c7c39`，App profile 到 11-15 08:30:17+08。包路径由私有清单指向上批 `normal-package-final/Payload/Nastart.app`。保存当前诊断/偏好，保留数据覆盖安装于09:25:27成功，fresh lookup，29项非诊断及全部偏好安装前后相同。两次对照重开前均重查 USB/包源/签名和已装路径，匹配这次经核实的安装。使用有效既有 Runner，正常空参数、空环境启动。

Jellyfin 资源库真实显示已连接、分类与海报加载、搜索《赌侠》并读到1990版详情。首轮原流 DirectPlay 使用局域网私有地址、既有 localRangeProxy 与 KSPlayer。206 和请求范围已见，内部播放时钟到26.889秒，首个 sample buffer 提交约351ms（内部引擎计时）。首轮约5/16/31秒截图分别为暗屏带控制、实际片头、近黑画面。早期口头“截图仍是黑画面”漏看了中段，现已纠正。预读仍为 `0 / bytesNotMaterialized`。未见资源库401再次出现。

第一次取图对照在存储页异步加载后误入 SMB 列表，观察到目的页不符即停，无该窗播放。等待列表稳定后复核，同包同影片的 WDA 两张与原生 DVT 一张均见不同片头画面（从发送播放命令起约9.2、10.0、19.0秒）。详情按钮显示「在 Nastart 中播放」，未形成续播证据。近黑帧的具体来源未定，短时画面已成立。仍待核实际首帧时间、声音、字幕、seek及普通关闭。App/Runner均为0，自有8102与采集退出，未知8101未动。播放窗仅诊断与本地续播偏好变化。Wi-Fi保持，未执行蜂窝窗或更改NAS原文件/配置。

## Apple TV

初始 Xcode 两版 CLI 无客厅真机，Mac 可见同名 AirPlay。用户打开电视「远程 App 与设备」后，Device Hub 发现「客厅」。提交用户提供的一次性码后 Mac 日志09:47:30显示认证与配对成功，Device Hub 列出「客厅」tvOS18.2，但显示 Currently Unavailable。配对日志私下记下真实目标 UDID。CoreDevice 精确详情失败，native RSD 报找不到该 UDID。两个 AppleTV14,1 模拟器不属于本次设备。用户重启电视并回到发现页后，上述开发状态仍未恢复。

重启后同一 Bonjour 主机的 AirPlay、RemotePairing 均在已解析的 IPv4 与 IPv6 地址上建立 TCP；`_apple-mobdev2._tcp` 能解析，但其广播端口在这些地址上均拒绝 TCP。同一主机的标准 Lockdown 端口62078可达，禁自动配对的查询读出「客厅」、AppleTV14,1 / 18.2。该通道没有认证会话且没有返回UDID，不能代替真实开发连接。用当前主机DNS名查询CoreDevice同样失败。故障缩小到配对认证完成后的开发服务可用性。具体进程、设备侧策略或 Mac/电视配对记录的原因仍未证实。保留本次配对，未发起第二次配对、TV安装或运行。已有独立 tvOS 签名缺口仍待实际开发连接恢复后重核。用户随后接入同一路由器网线。10:15:17复查，AirPlay与远程配对端口仍可达，广播开发端口仍在IPv4/IPv6拒绝。CoreDevice和RSD仍找不到目标，Device Hub正常列表和附近Apple TV列表均未显示客厅，未再提交配对。接线由用户确认，Mac只验证已发现的同目标地址。Mac路由查询将三个目标地址均指向en0，系统同时报告两个已连接VPN会话，隧道影响仍未证。后续可在同网另一台Mac进行交叉确认，或经用户授权安排隔离Mac网络过滤的窗口。[Apple Device Hub 官方说明](https://developer.apple.com/documentation/Xcode/managing-your-simulated-and-physical-devices-in-device-hub) · [Apple 开发连接排查说明](https://developer.apple.com/documentation/technotes/tn3158-resolving-xcode-15-device-connection-issues)。

共享结果无凭据、原始地址、配对码或设备标识。私有指针为 `/tmp/nastart-codex-jellyfin-login-recheck-path` 与 `/tmp/nastart-codex-tv-discovery-1108-path`。保留首轮暗帧、误导航和重启后开发通道失败。需求30项、矩阵114格无新整格通过。
