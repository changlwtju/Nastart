# 2026-11-12 播放策略 T2 · 4G 公网鉴权复核

- 用户确认 iPhone 13 空闲并授权直接远控。09:01 核当前 USB、iPhone14,5 / iOS 16.3.1、实际安装路径与现装 Runner。HEAD `8db1cc64`，冻结的 499 个 iOS 输入逐项一致。普通签名 Debug 沿用 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)，dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。空启动参数和环境。
- 设置首页的 WDA 页面树两次读取超时，现场原生截图确认「无线局域网」入口后按实际位置进入。09:04 切网前复核原网络勾选和 Wi-Fi 状态栏图标，补齐 [此前补查](CODEX-2026-11-12-PLAYBACK-POLICY-T2-RESUME.md) 未复核的原网络。随后实图见 Wi-Fi 关闭和 4G。无线定量指标未测。
- 09:04:52 打开 Jellyfin 资源库后出现「登录已失效，请重新输入密码」。结束前导出的 38 条本窗诊断包含 `selectedAddressKind=publicDomain network=cellular`、`hasStoredSession=true sameSelectedUser=yes`、`library_failed httpStatus=401 transport=https` 和 `session_rejected stage=library`。本窗被挡在资源库，S19 续播未派发。此前 5G 的 401 发生于 `stage=detailPreparation`，两次失败分开记录。未提交登录信息。
- 复算脚本报告 `0 playback(s) with route evidence, 0 to check.`。无起播路线、档位或首帧可判。V7、V8、V10 和 HLS 控件时序待补。T4 尚无 `explore` 样本，未调系数。无产品代码修改。
- 09:05:01 本轮 App 已停止。09:05:13 核原网络勾选和状态栏 Wi-Fi 图标，09:05:14 App、Runner、采集与转发均结束。证据位于私有指针 `/tmp/nastart-codex-playback-device-20261112-current` 下 `phone/t2-public-recheck/`。登录若需重新提交，由用户在有界蜂窝窗口的 App 内输入。
