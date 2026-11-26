# 2026-11-14 iPhone 13 公网保存会话冷启动

接续 [两次公网认证](CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-4G.md)。距 15:20:25.689 公网会话恢复成功约 12 分钟。15:31 fresh 核 iPhone 13、完整 UDID、iPhone14,5 / iOS 16.3.1、USB、原 Wi-Fi 和无 Nastart/Runner 进程。HEAD `8db1cc64`，开工 161 个未提交路径。647 个冻结源码输入一致，Xcode 27.2 签名 Debug 及已装回执匹配，无重装。11:34:28 构建，包目录和签名原件留本机。

- 主程序 `de5cc10f62ef450b6605a358f2fb4e5bb2f8b64f8ab59a31f2823b2019f8cd2a`，Debug dylib `caa776f868e9b735be43f2bbc2ef79bb8c37343a0cc81ccd2dd42bb6508df07a`，IPA `74a93d2824df4c912ee7ce79b7efaf74f75b5ac75d7c389af174aa95a4d93349`。profile 到 11-15 08:30:17 北京时间。复用已安装 Runner。
- 15:31:57–15:32:59。原 Wi-Fi 勾选及图标核对后，按用户授权用 WDA 切换，15:32:01 验 Wi-Fi 关闭及 4G 状态栏。该地点为用户报告的蜂窝弱信号处，RSRP、RSRQ、SINR 未测。原生空参数、空环境冷启动，无登录输入。
- **本次公网会话冷恢复通过。** 15:32:22.081 `selectedAddressKind=publicDomain`，`restoredCandidateScope candidateScheme=https hasStoredSession=true selectedCandidate=true network=cellular`。15:32:22.293 系统记录蜂窝代次 1→2，15:32:22.347 `library_loaded stage=views`，15:32:24.166 `stage=completed libraries=3`。WDA 实见两张资源库卡片和搜索，未出现登录页。切窗的诊断无 `login_succeeded`、`session_rejected`、`replacedRejected`，证明这次直接用保存会话读库。随后代次进一步变化，资源库仍可见。它不能替代首个过期会话遇到网络变化时的恢复验收。
- 每个动作后立即导出，以时间筛选 1000 条快照。路线复算退出 0，`0 playback(s) with route evidence, 0 to check.`。本窗没有播放、不判 HLS 或首帧。未修改源码、参数、NAS 和服务端配置。未运行新增单测。
- 15:32:44 结束本轮 App，15:32:59 核原 Wi-Fi 已勾选且状态栏图标与基线相符，15:33:00 App、Runner、采集和 8161 均释放。私有证据入口 `/tmp/nastart-codex-jf-public-persist-20261114-current`。

后续将已恢复的公网会话用于原 T2 待验的同片播放，再按原标准核路线与实画面。过期会话恢复期间网络发生变化的失败仍保留独立证据。
