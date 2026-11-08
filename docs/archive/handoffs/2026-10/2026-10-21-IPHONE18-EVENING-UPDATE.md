# iPhone 18 回家后最新包更新

2026-10-21 18:33–18:39，用户确认已连接家庭 Wi-Fi，撤销白天“离家先不操作”的设备条件限制。随后用户选择“稍后，先继续其他工作”，因此正常首页及播放回归继续暂缓，不再切换其前台或催促。原始发现、设备名/UDID、端点、偏好、日志、截图仅存 `/tmp/nastart-iphone18-home-latest-evidence` 指向的本机私有目录；[安全结果](../../../testing/results/2026-10/2026-10-21-iphone18-evening-update.json)。

## 安装身份与数据保持

系统 DNS-SD 现场解析、现有配对 lockdown 实时核同一 iPhone19,7 / iOS27.0、目标不在 USB、直接 Wi-Fi TCP 可达，不沿用旧地址或重新配对。173 输入、HEAD/dirty iOS diff、29 库及深签名/profile目标/有效期、三二进制与 IPA CRC/AppleDouble 均核；沿用最新 15:39 正常 Debug/-Onone 包，未构建或修改源码。diff `6fd78d20f8d406a7794686d7e92c5316274b707ac12cac8a4a7dd52563d8d6e7`，IPA SHA `e0c196cf2195de31426041d4acfe7175298c06f1c1e618d6fbd903747ae2c877`，三 hash 见安全结果及[构建批次](2026-10-21-AUTH-AMBIGUOUS-RESPONSE.md)。

18:34:37 开始保存完整偏好，备份成功后用既有项目安装工具发送保留容器 Install；18:34:56.370429 收到 Complete，lookup 存在。安装前后、正常启动请求后，以及 18:38:09 只读跟进均为 25 项完整非诊断偏好逐值一致，包含整个书签对象，不卸载、不直接回写偏好。该设备已从旧 05:31 包更新为当前 15:39 包，不能继续把它记作旧包。

安装回执在本次私有 `install/summary-safe.json`；最新包指针仍为 `/tmp/nastart-auth-response-evidence`，不能把本观测/安装目录当成重新构建的包。

## 正常启动与 UI 边界

经已配对 CoreDeviceProxy/userspace RSD 再核同一目标，明确请求 environment={} / arguments=[] 的正常启动。6 秒后的原生截图实际是其他用户 App 前台，不是 Nastart 首页，actualForegroundUIVerified 保持 false；不因 PID/请求成功或安装成功把首页及播放记通过，也不把其他 App 内容写入项目结果。未重发启动打断用户。

已一次请求用户方便时打开 Nastart 首页；用户选择稍后、先继续其他工作。设备当前已解锁，不能重复要求解锁或声称仍锁屏。接下来等用户主动提供首页可验证条件，再完成这台设备的正常 UI 门槛及原截图的 NAS/竖屏/PiP 回归。

## 本次已保存的连接日志

对启动后已保存日志离线配对：仅一个启动窗口，无重叠 pending 登录，Nastart started→succeeded 日志跨度 1.772693 秒，FileStation 为 1.184784 秒，均成功。FileStation 同一 auth/fileStation pair 第一次 connectionPublished 后 4.962581 秒又发布，符合已接受的提前发布实现；不把这个间隔当作整体提速。原始代次仅私存，安全结果只导出配对结论。

这些是同次启动内部日志边界，不是点击到连接或首页就绪时延；没有实际首页、严格冷启动重复或 DS One 配对，不宣称连接性能验收，也不证明旧长 POST 超时的根因已解决。此前恢复状态/绝对18秒及异常响应修复均已随本次包带入，原失败证据仍保留。

CoreDevice 当前只读清单仍 paired / tunnel unavailable / DDI unavailable；直接 RSD 启动能力与 Xcode 自动开发隧道分别记录。没有重试已被 Security 拒绝的 WDA、重签/重装 Runner 或改网络/系统。安装不依赖 WDA，该支线仍需有效目标签名和实际 UI 会话，不把已装/已配对当可控。

本批零 Play/PiP/媒体采集，安装/只读命令与临时 awake 均已结束；没有自有媒体流或周期调度。网络/SSID/蜂窝/VPN均未改，实际原生图 Wi-Fi 图标可见。后续优先等用户可用时补首页，再复核原片；当前继续独立的 13 工具/播放任务。28 项需求保持开放。
