# 2026-11-12 iPhone 18 最新签名 Debug 更新

Codex 执行，时间为北京时间。06:33 用户报告 NAS 疑似异常关机重启，暂停 NAS 和播放测试，单独授权 iPhone 18 保留数据更新。13 的蜂窝测试已停，原 Wi-Fi 已复核，详见 [T2](CODEX-2026-11-12-PLAYBACK-POLICY-T2.md)。

## 待装包

- 复核 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) 构建，HEAD `8db1cc64`，499 个仓库 iOS 输入（含已有未提交改动）逐项一致，Xcode 27.2 签名 Debug，11-12 03:29:39 构建完成。
- 主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`，dylib `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`。签名验证通过，描述文件覆盖 18 当前目标 UDID，有效至 11-15 08:30:17。打包自同一已签名 App，IPA SHA-256 `8454b2837151fd05b5a411ed80726f3e85268f465d4b4d122d1349accd3f3f03`，CRC 与所有 App 文件内容核对一致。

## 无线预检结果

- 06:34 当前 DNS-SD、既有配对 TCP、实时名称/完整 UDID、iPhone19,7 / iOS 27.0 核实。目标未出现在 USB 清单。
- 06:34:51 直接配对无线 HouseArrest 在读取容器前连接断开，未取得偏好。06:35:49 备选验证收尾，直接无线 installation_proxy 只读查询断开，系统原生无线 RSD 返回 `_RemotePairingError`，已配对 TCP 的 userspace RSD 建立同样断开。
- 安装尚未发送，未上传 IPA、启动 App 或操作 WDA。无 NAS 访问、无 DSM 地址更改，当前实际 DSM 会话和媒体路由本窗不适用。已请用户接 USB 并解锁以继续覆盖。
- 原始证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `iphone18-install/`，完整身份及地址留本机私有目录。

## USB 安装完成

- 用户确认数据线连接并解锁。06:38:11 重新核对 USB、既有配对、CoreDevice wired/paired、完整目标 UDID、iPhone19,7 / iOS 27.0。安装前保存并成功解析 App 容器偏好及其中的诊断。
- 安装前有 Nastart 进程，按该 bundle 的实际可执行路径与 PID 二次核对后精确退出。退出前后偏好全等。随后使用 `devicectl device install app` 保留数据覆盖，06:38:22 收到明确成功回执；fresh 查询确认同 bundle 的新安装路径。安装前后 28 项偏好全部相等，原保存的 DSM 域名＋端口配置保留。
- 完成后原生查询确认 Nastart 进程不在，本轮没有启动 App、WDA 或媒体。实际 DSM 会话地址、正常首页和播放未验，NAS 暂停继续生效。06:38 收窗释放，iPhone 18 归还用户。
