# 2026-11-20 iPhone 18 Pro Max 无线续签与安装

接续 [两台 iPhone 更新](CODEX-2026-11-19-IPHONE13-IPHONE18-INSTALL-FOLLOWUP.md)。用户指定 iPhone 18 Pro Max 通过 Wi-Fi 更新、iPhone 13 经 USB，继续保留数据覆盖。iPad 在用户窗口，本批未连接操作。

- 开工 HEAD `8db1cc64`，164 个未提交路径。复核 11-19 07:30:40 Xcode 27.2 Debug 的 647 个构建输入，内容一致。未修改源码，使用隔离构建为该机生成同团队描述文件，原有兼容 Runner 原件保留。
- iPhone 18 Pro Max 当窗核实 iPhone19,7、iOS 27.0、完整 UDID 与已有配对。Xcode 识别到它作为签名目标时，CoreDevice 标记 wired。仅用该目标请求签名。App 容器备份、安装、回执、安装后查询及比较都通过重新做身份校验的 Wi-Fi 原生隧道。
- 同团队新签名有效期北京时间 11-27 00:19:38（Nastart）、00:19:55（WDA），均验证覆盖该机，深度验签通过。App 主程序 SHA-256 `a3c56c563039b51434134f0d73a1131a41caeb505e982a47297612071e6de7e3`，Debug dylib `aa04ad51466f47230e8859b7a2f416720a5d6ee730cdbcbaad98cb954ca7f6d3`，IPA `f1b811fe3678def144044c535cd9db772cb3578e20fdf5830b988adbb0f2bd9a`，Runner 主程序 `72df175ef265498ac20bd63de73b56b8e206c9441d90d0817b9e13111ee0515f`。包路径留私有 manifest。
- Nastart 00:21:09、WDA 00:21:12 收到安装完成回执，后查两包安装路径更新且 `ProfileValidated=true`。安装前后 27 个非诊断偏好键值相等，完整偏好也逐值相等。未卸载或清数据。DSM 实际会话地址未核。
- 00:21 无测试环境变量普通启动首次返回 `DTXNsError`。复查发现新安装路径的 Nastart 进程已存在，前台截图是其他 App，Nastart 首页未验证。无线 XCTest 启动后 WDA /status 未在窗口内 ready，Runner 已核退出。已请用户方便时手动打开 Nastart 核对首页或系统提示。未进行播放或网络切换。
- iPhone 13 当窗复核 USB 实时身份 iPhone14,5 / iOS 16.3.1。此次两份新描述文件覆盖 iPad 和 iPhone 18 Pro Max，均未覆盖 iPhone 13。Xcode 27.2 的真机调试支持自 iOS 17 起。可用的 Xcode 26.6 官方下载页仍停在 Apple Developer Agreement，等待用户审阅后继续。未发送 iPhone 13 安装。 [Apple 版本兼容性](https://developer.apple.com/xcode/system-requirements/)

设备、Runner 和构建窗口均已释放。私有证据在 `/tmp/nastart-codex-renew-all-20261119-current` 指向目录内。无源码、NAS 或网络设置变更。播放矩阵及需求编号无新增验收。

00:38 接续复核。iPhone 18 Pro Max 首次复验在 Wi-Fi 身份握手超时，重新发现并认证后，当前源码包校验通过，App 与 Runner 的已装路径和对应回执相等，两者描述文件均已验证。新包 Nastart 进程存在，手机当时前台为其他 App，本窗未抢占前台。经无线 XCTest 启动该 Runner，实际收到 `/status` 的 `ready=true`，返回 bundle 为项目 Runner，未建立触控会话，随后 `runnerStopped=true`。本窗确认 WDA 启动可用，App 首页、DSM 实际会话和播放仍待，设备已释放。iPhone 13 的 Xcode 官方下载页从注册错误重试后仍回 Apple Developer Agreement，Apple CDN 下载入口转回未授权页，没有开始下载或安装。iPad 仍由用户使用。
