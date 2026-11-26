# 2026-11-14 iPhone 13 Jellyfin 公网主入口 4G

接续 [覆盖安装对照](CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-VERIFIED.md)。现场 USB 核 iPhone 13 名称、UDID、iPhone14,5 / iOS 16.3.1。647 项冻结源、HEAD `8db1cc64`、开工 160 个未提交路径、安装回执匹配签名 Debug `caa776f868e9b735be43f2bbc2ef79bb8c37343a0cc81ccd2dd42bb6508df07a`。主程序 `de5cc10f62ef450b6605a358f2fb4e5bb2f8b64f8ab59a31f2823b2019f8cd2a`，IPA `74a93d2824df4c912ee7ce79b7efaf74f75b5ac75d7c389af174aa95a4d93349`，构建 11:34:28，门槛通过，沿用 15:11 安装。旧包验证脚本内的构建时间断言因产物后续 mtime 不同触发，原私有签名清单重新验证包内容、签名和源码哈希全一致。App profile 至 11-15 08:30:17。沿用 Runner，空参数、空环境启动。原始包、路径与样本保留于私有证据入口 `/tmp/nastart-codex-jf-public-cell-20261114-current`。

## 结果

- 设置页初次读取时 Wi-Fi 开关还未出现在无障碍树。复核后原 Wi-Fi 已勾选且状态栏有 Wi-Fi 图标，再按用户已有授权用 WDA 关闭 Wi-Fi。15:16:15 实图 4G，用户报告此处蜂窝偏弱，未测 RSRP、RSRQ、SINR。未变更蜂窝数据或 VPN。
- 15:16:35.611 `restoredCandidateScope network=cellular candidateScheme=https hasStoredSession=true selectedCandidate=true`，主入口为 `selectedAddressKind=publicDomain`。15:16:35.731 `storedLibraryRecovery result=waitingForIdentity`，当时没有可接手的内网候选。15:16:36.370 系统观测同是 `cellular`，网络代次 1→2。15:16:36.467 `library_failed httpStatus=401 transport=https`、`session_rejected stage=library`。WDA 实见登录页，未见资源库或搜索。未重登或开始播放，公网主入口自动恢复本次失败。
- 未出现 `crossEndpointRestore result=replacedRejected`，也没有替代令牌的 401 或身份不符证据。源码核对新路径在两次探测前后检查精确网络代次，条件失效会直接返回，和本窗代次切换时间吻合。现有日志缺少明确丢弃阶段，不能证明具体是哪一步取消，也不能判定内网令牌在公网是否有效。
- 每个动作后导出，窗口内筛选 1000 条快照。路线脚本退出 0，`0 playback(s) with route evidence, 0 to check.`，无起播路线、码率或体验样本。本窗没有产品代码、参数或测试改动。
- 15:16:54 只结束本轮 App，15:17:09 核原 Wi-Fi 勾选且状态栏 Wi-Fi 图标吻合基线。15:17:10 App、Runner、采集、8161 均释放。

## 同包第二个 4G 窗口

- 第一窗收尾后，本机用当前纯 Swift 身份守卫跑六个断言。代次不变可发布，同为 cellular 的 1→2 使旧证明失效，新代次可接受新证明，转 Wi-Fi、会话改变和取消时均拒绝。夹具未发网络请求。结果在首窗私有目录 `path-proof-safe.txt`。
- 15:19–15:21 fresh 核相同手机 USB 身份、647 个源输入、签名与同一安装回执。原生原 Wi-Fi 勾选与状态栏图标已核，再确认 Wi-Fi 关闭及 4G 状态栏。启动同一签名 Debug，空参数、空环境。
- 15:20:24.965 选中公网 HTTPS 已保存会话。15:20:25.174 `storedLibraryRecovery result=waitingForIdentity` 后进入公网恢复。15:20:25.689 `crossEndpointRestore result=replacedRejected httpStatus=200 sourceAddressKind=privateIP network=cellular`。15:20:25.927 才观测蜂窝网络代次 1→2。15:20:26.062 取得资源库，15:20:27.288 `library_loaded stage=completed libraries=3`。WDA 实见两张资源库卡片、搜索入口，无登录表单或新登录提交。第二窗首次进库已通过，因此没有执行同进程再进库分支。
- 逐操作导出，路线复算退出 0，`0 playback(s) with route evidence, 0 to check.`。15:20:47 结束本轮 App，15:21:00 复核原 Wi-Fi 勾选与状态栏图标，15:21:01 自有 Runner、转发及采集结束、进程归零。证据入口 `/tmp/nastart-codex-jf-public-repeat-20261114-current`。

同包同地点两次均为 4G，第一次在恢复窗口内看到代次变化并停在 401，第二次在变化前完成验证并读库。公网主入口恢复功能已有一次实证，网络变化时的稳定恢复、持久性及蜂窝实播保持开放。本批没有改代码或调参，也没有测试会触发服务端重新签发的显式登录。
