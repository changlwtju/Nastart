# 2026-11-12 T2 iPhone 13 蜂窝预检

Codex 执行，时间为北京时间。依据 [总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md)。前置 [T1](CODEX-2026-11-12-PLAYBACK-POLICY-T1.md) 的路线与档位规则已核，保留连续播放缓冲。

- 03:54:33 fresh 确认 iPhone 13（iPhone14,5 / iOS 16.3.1）、USB、目标完整 UDID 和 Nastart 安装路径。匹配 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) 签名 Debug `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`。HEAD 和包、源清单均复核。
- 依用户已给授权，对 iOS 16 兼容 Runner 副本用现有同团队描述文件续签。核当前 UDID 覆盖、原 host/test ID、iOS 最低版本、arm64、entitlements、deep/strict 和 12 个嵌套签名。Runner 主程序 SHA-256 `f6c6980ec906869faf5cc5ff250bad38b50f9f38e2af7a8b8f6e56b43358bb16`，profile 到 11-16 19:51:31。03:55:19 USB installation_proxy 保留数据覆盖成功，fresh lookup 的 Runner 路径已更新，Nastart 路径及全部偏好一致。随后 XCTest 经本机 8161 取得 `ready=true`。
- WDA 只打开设置作观察，首次树读取超时，原生 USB 图已确认设置首页的已连接 Wi-Fi 行和状态栏 Wi-Fi 图标。原网络信息仅私存。已结束设置会话，向用户一次说明先切至蜂窝、测试停流后再连回原 Wi-Fi，切换由用户手动执行。
- 03:59 原生截图复核原 Wi-Fi 仍连接、图标仍在。蜂窝窗口未开启，V3–V8、V10 均未派发，未产生播放、流量或复算结果，无调参和代码修改。
- 03:59:34 自有 XCTest、Runner、8161 转发已结束。03:59:59 fresh 原生复核 Runner 不在，设备有一个本轮未启动的 Nastart 进程，保留该进程，设备占用已释放；续接前再核独占、实际 App 状态和网络。V3 仍需冷启动，按现行约定在拿到测试窗口后保留诊断并核 PID / bundle 路径。
- 私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `phone/t2/`，含签名及安装回执、原生图、设置树超时和收尾日志。T3–T6 未执行。
