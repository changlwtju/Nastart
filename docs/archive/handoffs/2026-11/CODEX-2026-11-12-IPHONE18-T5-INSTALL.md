# 2026-11-12 iPhone 18 安装 T5 签名 Debug

用户明确要求把最新 App 安装到 iPhone 18，并继续播放调试。先核 iPad T5 前一窗口已收尾，再单独开 iPhone 18 USB 覆盖安装窗口。时间为北京时间。

- 复核 [T5](CODEX-2026-11-12-PLAYBACK-POLICY-T5.md) 包，HEAD `8db1cc64` 加当前未提交输入，Xcode 27.2 签名 Debug 于 14:24:48 完成。500 个 iOS 路径、当前源码差异、31 个 Mach-O、IPA CRC、主程序和 Debug dylib 逐项复核。dylib `6beee7cbe77e5b842112351366bdcf80de007527e6004e0ae32107b31a2c533e`，IPA SHA-256 `0fdd0b4e34fe03566744c6c5e1e84ed37accf8430abaa1676321d1de0679bbc9`。描述文件覆盖目标设备，有效至 11-15 08:30:17。
- 现场双核 iPhone19,7 / iOS 27.0 / USB 有线且已配对。安装前保存 App 容器偏好和诊断，精确核对旧 Nastart 安装路径和 PID 后结束该进程。退出前后偏好一致。18:17:17 `devicectl device install app` 返回成功，fresh lookup 核对同 bundle 新安装路径。覆盖前后 28 项偏好全部相等，包括原有 DSM 域名和端口的保存配置。
- 安装完成时 Nastart 进程不存在，设备窗口释放。iPhone 18 本次只覆盖安装，实际 DSM 会话地址和实播尚未在该机验收。无 WDA 部署、网络切换、远端配置或文件改动。私有包和回执在 `/tmp/nastart-codex-playback-t5-20261112-current` 的 `iphone18/`。
