# 2026-11-20 iPhone 13 USB 覆盖安装与启动验证

接续 [Xcode 26.6 安装](CODEX-2026-11-20-XCODE-26.6-INSTALL.md) 和 [NAS 归档清理](CODEX-2026-11-20-NAS-DEBUG-ARCHIVE-LOCAL-CLEANUP.md)。用户要求优先更新 iPhone 13。iPad、iPhone 18 Pro Max 未操作。

- 06:54 开工，HEAD `8db1cc64`、167 个未提交路径。11-19 07:30:40 Xcode 27.2 正常 Debug 的 647 个源码输入、HEAD、iOS diff 校验一致。USB 核实时完整 UDID、iPhone14,5 / iOS 16.3.1 (20D67) 和配对。系统默认 Xcode 27.2 保持。
- Xcode 26.6 初次续签被缺少 iOS 平台组件拦截。用该版本的 Components 下载并装好 iOS 26.5.1 SDK 与 iOS 26.5 Simulator。再用独立小目标取得同团队同证书描述文件，分别有效到北京时间 11-27 07:27:01（Nastart）和 07:27:12（WDA）。未改产品源码或原 Runner 工件。
- 下载前已签的正常 Debug 仅重签。主程序 SHA-256 `130f56265e98d719a185ce153881d934003241d21929f9558f47c981bf073604`，Debug dylib `3929988635e08cecf4a02d4224cee7149f7857f5ac7f0910f8222fed4bd52635`，IPA `a9453b76ceb7aae94f944be8f862f6b639b27f2b9ec50fe28242350f55247f8e`，Runner 主程序 `04be22094132981816ef4e25c6f5b0ca490f984c4c997a455075e5e4775d510a`。核设备覆盖、应用及嵌入代码签名、IPA 成员及 CRC。包路径留私有 manifest。
- 先备份偏好和原安装信息。最初保护检查发现 11-16 启动的同项目旧 Runner 后停止，没有下发安装。复核该进程的 PID、启动时间、可执行路径与旧记录一致，USB 下其 WDA 端口无服务，Mac 亦无现用转发/XCTest，再精确结束。私有脚本两次在下发前因作用域和信号参数编码退出，保留失败证据，修正后再核当前进程。其余进程未中断。
- 两次 USB `Install` 完成回执分别为 07:33:21（Nastart）和 07:33:24（WDA），两包后查定位新路径且 `ProfileValidated=true`。全量偏好一致，29 项非诊断键值相等。Nastart 空参数、空测试环境启动，核新包 PID 路径，截图实见启动台、NAS 在线、状态栏 Wi-Fi。Jellyfin 会话与播放本窗未验。
- 07:34 USB XCTest 复验新 Runner，实际收到 `/status ready=true` 且返回项目 bundle，未创建触控会话。收尾核 App、Runner 与本地转发均退出。

设备和构建窗口已释放。原始截图、偏好、安装回执、失败日志与哈希清单在本机私有批次 `/tmp/nastart-codex-renew-all-20261119-current` 指向目录。无源码、NAS 或网络设置改动。无新增播放矩阵验收。
