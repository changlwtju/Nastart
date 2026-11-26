# 2026-11-09 Apple TV 开发者设置与 Mac 前置核查

用户确认 Apple TV 的“设置”首页没有“开发者”。[Apple 的 tvOS 说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device?changes=_8)说明 tvOS 没有单独的开发者模式开关，开发者设置会在使用 Device Hub 配对后出现。结合已有验证码认证成功、Mac 原生设备服务没有该电视端点，当前不能把配对回执当作可用的开发配对。没有菜单是现象，不能凭此判断故障在哪一端。

21:58–22:00 Mac 只读核对：Xcode 27.2（27B52）具有真机 tvOS 27.2 SDK，CoreDevice 成功列出 tvOS 首选开发镜像（27B52）。Mac“本地网络”列表中 Xcode/Device Hub 没有单列开关，同窗权限日志也没有相关的局域网拒绝记录；这不等于逐进程权限完全排除。Mac 上有活动 VPN 配置，但电视当前 IPv4、两条 IPv6 路由均指向 `en0`，上一窗同地址的配对 TCP 可达。Apple 说明某些网络过滤配置会妨碍设备通信，但是否适用于本机仍未对照。Mac 上次启动为 11 月 8 日 15:48，配对后故障已在其后多次复现。未修改 VPN、网络、配对、系统或安装；原始诊断留在私有证据区。

暂无第二台 Mac。继续优先安排单一变量对照：如用户愿意且现有连接可短暂停用，由用户自行暂停并恢复 Mac VPN；期间保留电视网线和配对，比较前后 Xcode 开发设备列表及实际硬件详情。仍无端点时保留结论，优先独立 Mac 或 Apple 开发工具诊断，不重复清缓存、重启、配对。 [上一窗现场](CODEX-2026-11-09-APPLE-TV-LIVE-TUNNEL-DISCOVERY.md) · [Apple 的设备通信排查](https://developer.apple.com/documentation/technotes/tn3158-resolving-xcode-15-device-connection-issues?changes=lat_8)
