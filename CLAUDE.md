# Nastart：协作开工入口

2026-11-08当前接续以[Claude阶段总交接](docs/archive/handoffs/2026-11/2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md)和[Codex接收核对](docs/archive/handoffs/2026-11/CODEX-2026-11-08-TRANSITION-INTAKE.md)为总入口。用户说明Claude额度将耗尽，本阶段后续由Codex接手，原Claude第一步代理接入与13/Pad回归也转入Codex队列。

开工依次读取[AGENTS](AGENTS.md)、[PROGRESS](PROGRESS.md)、[当前交接](docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md)、[资源登记](docs/development/AGENT-RESOURCE-STATE.json)、[协作分工](docs/development/CODEX-CLAUDE-COLLABORATION.md)。各旧批授权/任务只代表当时范围，下一次并行实施先登记完整文件和含dirty的同源独立目录。

NAS业务已由用户恢复，FTP/SMB真实13流程与Jellyfin/设备文件/WebDAV播放背景见总交接。所有远端文件和配置保持项目只读边界，安全收尾和73个可疑文件的处置由用户另行决定。播放链路按实际网络环境统一，协议只适配字节供给，FTP/SMB限LAN。当前共享代理第一步受Range语义/lease/诊断前置约束，启动预读默认观察IO不物化字节，真实预读实现另批验证。

最新Codex批次见[Range与两机基线](docs/archive/handoffs/2026-11/CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)。上批13/Pad均安装正常bb4d并实看首页。最新第一阶段正常97b3已在13安装并通过FTP短播/跳转，iPad尚未接回。见[阶段记录](docs/archive/handoffs/2026-11/CODEX-2026-11-08-NETWORK-SOURCES-SHARED-PROXY-PHASE1.md)，profile至11-15 08:30+08；有限基线/失败及两机收窗见报告。旧4744/11-08到期只属历史，18未装本批bb4d。所有后续仍先逐机核最新源/包/签名和资源，TV无运行窗口。未知8101旧转发不接管。

密码和TMDB令牌只由用户在App内输入，测试操作不读取用户实际Keychain凭据、不点密码眼睛、不猜测或重复旧密码。iPad的network.library.source合成点击会弹出移除长按菜单，沿用避免该输入路线的限制。TMDB默认关闭、真实API/UI仍待验证。SMB采用libsmb2及放宽严格选根为用户已选择方案，保留拒绝链接与版本校验边界。

当前main HEAD 4de732dd，309个状态路径含接受中的旧基线。NetworkMedia/LibSMB2均整体未跟踪，完整纳入后续审查/备份/暂存。先保存现场，逐批审查接入，保留所有未知修改。Codex单写共享摘要、当前交接、需求/矩阵及资源登记，Claude再次参与时写本方月度交接，按本批权限执行。双方未来分工仍按额度/连续性动态安排，具体余额未知。
