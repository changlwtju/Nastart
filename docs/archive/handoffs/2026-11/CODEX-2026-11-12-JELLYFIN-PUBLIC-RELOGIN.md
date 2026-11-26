# 2026-11-12 iPhone 13 公网 Jellyfin 重登

- 用户明确授权使用历史聊天中提供的登录信息，本次范围为登录。13:25 实地复核 iPhone 13（iPhone14,5 / iOS 16.3.1 / USB）、现装路径和 Runner。HEAD `8db1cc64`，冻结的 499 个 iOS 输入逐项一致。沿用 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) 签名 Debug，dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。正常启动环境。
- 原 Wi-Fi 勾选和状态栏图标复核后，13:26 切到蜂窝。原生图见 Wi-Fi 关闭、4G。公网地址 `selectedAddressKind=publicDomain network=cellular` 的旧会话再次出现 `library_failed httpStatus=401` 和 `session_rejected stage=library`。仅在 Nastart 界面提交一次用户授权的登录信息，13:27:31 `login_succeeded`，同端点身份校验 `serverIDRecorded httpStatus=200`，13:27:33 `library_loaded stage=completed`，实见资源库卡片。
- 保持同一 4G 窗口，结束本轮已确认的 Nastart 进程后，空环境重新启动。13:28 现有公网会话直接返回 `library_loaded stage=completed`，再次实见资源库卡片，无第二次提交。该结果验证当时的冷启动会话恢复。
- 13:28:35 原 Wi-Fi 勾选及状态栏图标复核通过。13:28:36 App、Runner、转发和采集归零。私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `phone/t2-authorized-public-login/`。两次目录核验和捕获独立保存，导航步骤共用同名标签，重开覆盖了首轮导航文件。旧会话 401 与重登结果均有同窗独立捕获的诊断。
- 播放事件为 0，未运行后续播放回归。无产品代码、调参、NAS 配置或远端文件修改。
