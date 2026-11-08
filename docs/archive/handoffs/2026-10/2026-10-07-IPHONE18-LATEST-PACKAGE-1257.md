# iPhone18 最新普通包安装（12:57）

用户报告 NAS Container Manager 意外重启，要求先暂停播放调试，优先安装最新 App 到 iPhone18。此前基线不跨 NAS 重启沿用；重启原因本轮未调查。

现场重新枚举并确认 iPhone18 Pro Max（iPhone19,7 / iOS27.0 / 24A8428），USB 在线、配对与 CoreDevice 有效；完整 UDID、设备元数据和偏好仅在本机私有目录。初次枚举尚未检出，用户连接后重新核对成功。

最新普通 Debug -Onone 包于 2026-10-07 12:33:05 构建，源码基底 `4de732dd645b36671becff992cdef1d0163fd1e4` 加 iOS diff SHA256 `fb2f60a61701861c7c8a9a39df8553540e55696d39f33f5cf498f8ae19dc0f01`。8 项 iOS 修改未提交，未清除其他修改。现场重新核对源差异、构建输入时间、全部二进制哈希、App 与29库签名及目标描述文件；目标授权有效至2026-10-10 22:03:15 UTC。

- 主二进制 SHA256：`a495e914a3f7894ef4f87bcde7a23db0a28c9ab6e18f92c8f2697d5e4702c33b`。
- Debug dylib SHA256：`d5245a9e9250523082c583cd5a9d4df398d9afb2a8be96d97a88db802c559765`。
- KSPlayer SHA256：`c814c6b3f8d1beaddef93e8c77935aa9d653835244ae7a0b772d9900e709a704`。

12:57 保留数据覆盖安装成功，安装前后25项非诊断偏好相同；无测试环境变量或参数正常启动成功，独立进程清单确认同一新进程仍在，启动后25项偏好也一致。原生截图 exit255 为 TOOL，保留私有错误；未核实际前台画面，不声称播放、主题或性能回归通过。没有卸载、清除登录、更新系统或重装 WDA。详见[脱敏安装记录](../../../testing/results/2026-10/IPHONE18-LATEST-PACKAGE-20261007-1257.json)。

iPhone13 与 iPad 先前已逐台安装相同 a495/d524 包；iPad 用户手动观看《指环王》，已暂停该机输入，不作为自动 S01 样本。手机新包大文件准备阶段的入口守卫/触控定位异常为 TOOL，未发起媒体播放；仍需复测判断工具和 App 页面行为。恢复 iPhone13 本轮原 Wi-Fi ON、Shadowrocket 原连接 ON/配置规则（checkmark）和代理日志 OFF，所有人工网络条件 inactive，普通最新 App 前台、WDA idleWait10。iPad 无强制退出。

178 tests（1 skip / 0 failures）、15预检与普通构建通过，属于逻辑/构建证据；最新双入口真机回归尚未完成。旧9143规则VPN真实蜂窝 S19 文件4Mbps、从触摸600秒观察保留为旧包基线；极限250kbps画质失败及提前停止保留，不判十分钟通过。恢复调试后以大文件为主，重新记录 NAS 负载与实际链路，补规则VPN/无VPN、设备文件/Jellyfin、画质及升档缺口。当前本轮新源码尚未同步 main；用户本次要求暂停，未继续提交/推送或网络播放测试。
