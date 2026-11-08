# Claude Code 第二实施批：TV断开操作的旧错误反馈

**状态：第二批已交付并接入，原写入授权已结束。** [集成记录](../archive/handoffs/2026-11/2026-11-02-CLAUDE-BATCH2-INTEGRATION.md)含三配置及实际动作代码隔离证据；原生UI仍待验。以下为历史分配，不授权续写。

2026-11-02，Codex分配。开工/交付前必须读**当前集成目录** `/Users/lagransun/workspace/Nastart` 的[资源登记](AGENT-RESOURCE-STATE.json)、[当前交接](../handoffs/CURRENT-PLAYBACK-HANDOFF.md)；复制目录里的旧许可不生效。首批已集成，不能继续旧目录写入。

## 同源独立目录与完整文件权限

- 目录：`/Users/lagransun/workspace/Nastart-Claude-TVFeedback-20261102`，独立Git仓库（不是worktree），无remote。
- 分支：`claude/tv-feedback-batch2`；本地接受基线：`2a2f002380316dd36e498e098694607e805bbcc9`，父HEAD4de732dd。446接受输入与当前集成目录逐个SHA一致，包含首批和Codex实际组件宿主，iOS diff b9463286；原集成HEAD/index未改。此基线已有未提交成果的快照，不算本批新增。
- **只授此完整产品文件在该独立目录写入：** `tvos/NastartTV/Sources/TVNASViews.swift`。
- 起始文件SHA-256：`900abea3000eb1a6aacace90b41fa356fd218615284c92b7a3245a751b73d730`。
- Codex在交付/释放前不改该完整文件。不得改Mine/AppTheme/本地化/NetworkMedia/TVAppState、凭据、认证、存储、播放、工程、依赖、签名或共享进度/登记；不批量格式化该文件其它区域。

## 实施范围与证据边界

依据[首批审查F1](../archive/handoffs/2026-11/2026-11-01-2028-CLAUDE-OFFLINE-UI-REVIEW.md)。Codex核当前源码：TVSettingsView的disconnectError和TVConnectionsView的error只在catch中赋值，没有清除路径。前次断开失败后重试成功会保留旧红字，这是**静态可达状态问题**，尚无正式宿主运行失败图。

最小改动仅覆盖三处已确认操作：设置页断开NAS、连接页断开DSM、连接页移除影音授权。在确认按钮实际执行新尝试之前清除旧错误，失败仍呈现本次localizedDescription；成功不能继续显示前次错误。取消确认保持当前状态，不执行断开；仅打开确认/连接sheet不冒充操作成功。保留原Task/await/throws和实际signOut/signOutNAS调用及先后顺序、角色、文案、禁用、导航和确认流程。

本批**不做**F1中文错误映射或自由文本改写，不隐藏本次失败；不扩大到busy/并发重试协议或登录/退出实现，不改F2布局、F3返回、F4标识。F4 `tv.connections.back` 即使命名不理想，也可能影响外部自动化，先不改。E“invalidSaved”不能直接照搬：编辑宿主已用try?回落，额外错误枚举不等于用户能见到正确反馈，留待单独追踪。

## 运行与构建资源

本批仅源码小修与静态交付，**未授任何编译、模拟器、真机、Runner或网络窗口**。Claude上批报告Linux无Xcode，不能再把“建议编译”记成已执行；如工具可用条件变化，写本方报告申请明确窗口，不能自行拿资源。无需准备/解析/复制新依赖。Codex接入检查点负责编译和有界安全状态验证。

普通TVAppState/signOutNAS会触及真实凭据并可能发送NAS logout，**不得为验证本批直接运行它们**；NAS仍恢复，完全暂停。iPad有未知进程且新包准备阻塞；iPhone13由Codex统一调度，TV开发连接/签名未恢复，18用户使用，均不接管。

## 交付

相对上述本地基线导出**仅本批文件补丁**，仓库外本方独有目录保存，提供最终文件/补丁SHA、逐处修改理由、静态检查方法与真实返回值、全部失败、未运行项；不要把继承基线当成果，不新建镜像实现的形式测试。若最小改动无法满足范围，先报告具体原因，不扩大权限。

唯一允许在集成目录新增的本批报告：`docs/archive/handoffs/2026-11/YYYY-MM-DD-HHMM-CLAUDE-BATCH2-DELIVERY.md`，不得覆盖既有文件。原始设备资料、凭据与Codex私有证据不读取。无可用编译工具如实标未编译，不因此声称无法交付源码。报告明确没有设备/NAS/后台任务及释放文件写入权，由Codex审查接入、更新共享总账；不直接安装未集成候选或关闭需求编号。
