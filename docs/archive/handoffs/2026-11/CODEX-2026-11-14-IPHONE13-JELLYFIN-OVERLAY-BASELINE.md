# 2026-11-14 iPhone 13 Jellyfin 覆盖前基线与签名包

接续 [覆盖更新后认证排查](CODEX-2026-11-14-JELLYFIN-PUBLIC-401-RECOVERY.md)。HEAD `8db1cc64`，开工 158 个未提交路径，本批保留。所有时间为北京时间。

## 安装前基线

- 11:33 现场 fresh 核对 iPhone 13 设备名称、iPhone14,5 / iOS 16.3.1、完整 UDID、USB 与现装回执，原 Wi-Fi 图标可见。旧包仍为 11-13 07:08 覆盖安装的签名 Debug，主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`，dylib `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`。11:34:07–11:34:47 仅做安装前对照。先保存偏好和诊断并结束既有后台进程，原生空参数、空环境冷启动，沿用已签 WDA。
- 11:34:31.097 进入原入口的资源库，App 记录 `library_failed httpStatus=401`，随后 `session_rejected stage=library`。内外网探测 `primaryHTTPStatus=401 candidateHTTPStatus=401`，恢复 `waitingForIdentity` 与 `candidateIneligible`。实见登录表单、无资源库和搜索，表单预填的是用户现在使用的新用户名。未提交用户名或密码。
- DSM 只读下载当日日志，11:34 同窗三次认证挑战、六条 `Invalid token`。09:29 内网冷恢复成功后，09:36:35.559 记录认证成功和撤销一枚旧令牌，09:36:35.560 为与昨晚 22:18 相同的账号签发新令牌。记录未带可关联的设备/请求标识，历史上是哪台设备触发、撤销的是哪个 App 会话仍未确认。本次已直接证明 401 在本轮覆盖安装前发生。
- 每个页面动作后立即导出，使用窗口时间过滤 1000 条诊断。偏好与控制台路线复算均退出 0，`0 playback(s) with route evidence, 0 to check.`，本轮没有播放。已复核回到主屏幕、原 Wi-Fi 图标、App、Runner、采集和 8161 收尾。

## 新签名包

11:33:14–11:34:28，Xcode 27.2，普通 iOS 签名 Debug。冻结 647 个输入，覆盖上次 500 个输入及额外受 Git 追踪或未跟踪的 iOS/Agent 文件；上次清单内三处变化对应此次认证恢复源码及测试。核验签名 `deep --strict`、30 个嵌入库、目标设备覆盖、App ID、调试 entitlement、IPA CRC 和二进制对照。描述文件有效至 11-15 08:30:17。

- 主程序 SHA-256 `de5cc10f62ef450b6605a358f2fb4e5bb2f8b64f8ab59a31f2823b2019f8cd2a`。
- Debug dylib SHA-256 `caa776f868e9b735be43f2bbc2ef79bb8c37343a0cc81ccd2dd42bb6508df07a`。
- IPA SHA-256 `74a93d2824df4c912ee7ce79b7efaf74f75b5ac75d7c389af174aa95a4d93349`。首次仅打包了符号链接，校验拒绝；改为打包实际 App 文件并重新核验，失败包未发往设备。

本批无新代码或调参，沿用前批七项定向模拟器结果。签名包和原始证据均留本机，由 `/tmp/nastart-codex-jellyfin-overlay-20261114-current` 定位。NAS、远端文件和配置只读。到本批记录时新包未向设备发送。把旧包交还用户在 App 内重登，确认当前会话在未更新的旧包读库通过后，再做原 Wi-Fi、无重登的保留覆盖成对试验。
