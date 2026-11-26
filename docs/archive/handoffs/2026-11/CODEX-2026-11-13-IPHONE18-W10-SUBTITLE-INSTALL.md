# 2026-11-13 iPhone 18 更新 W10 字幕修正版

- 用户明确要求安装最新包，同时正在下载《变形金刚》系列 ISO 作为补样。07:06 至 07:07 仅占用 iPhone 18 的安装窗口。USB 与 CoreDevice fresh 核配对、有线连接、iPhone19,7 / iOS 27.0 和完整 UDID。
- 07:05:28–07:06:39，Xcode 27.2 从 HEAD `8db1cc64` 加现有未提交修改完成 iOS 签名 Debug。500 个源码输入前后一致，签名、30 个嵌入库、IPA CRC 及二进制身份核对通过。主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`，dylib `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`，IPA `f6983feb629b61b992bf25571e0a52376ebbe86934c24a43ba03d2f7b62ae0a1`。描述文件覆盖目标，至 11-15 08:30:17（北京时间）。
- 安装前私有备份偏好与诊断，按旧安装路径、PID 核认并结束 Nastart，停止前后偏好完全一致。07:06:56 `devicectl` 安装成功且 fresh 核对新 bundle 回执。全量 28 项偏好与安装前相等，包括原 DSM 保存域名及端口。安装后 Nastart 未运行，无卸载、清数据、网络切换或 Runner 部署。窗口已释放，实际 DSM 会话及实播留待现场验证。
- 当前 ISO 样本尚未完成下载。按独立 ISO 专项先选一部，以设备文件入口验证 ISO 读取、主标题、实际首帧、跳转、字幕、音轨、正常退出及同位置续播。再按实际可用情况补 Jellyfin。同一个系列的 ISO 可用于容量覆盖，跨格式对照继续用 S19 MKV 和既有 M2TS 样本。 [已有 ISO 回归](../2026-10/2026-10-08-ISO-AUTO-SUBTITLE-LIFECYCLE.md) · [功能矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)

修正内容及模拟器验证见 [W10 字幕修正](CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-FIX.md)。原始包、回执和偏好仅在私有证据入口 `/tmp/nastart-codex-w10-subtitle-fix-20261113-current` 的 `iphone18/`。
