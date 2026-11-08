# 可直接发给Claude Code的后续开发推进指令

2026-11-08 接续入口已转为[Claude→Codex阶段总交接](../archive/handoffs/2026-11/2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md)，Codex[接收核对](../archive/handoffs/2026-11/CODEX-2026-11-08-TRANSITION-INTAKE.md)已完成。当前Codex接手全部待办，下文旧Claude推进批只作历史，后续参与先读资源登记重新分配。

2026-11-02。复制下面全文到现有Nastart项目会话即可。本文件只是生成指令，不代表已发送/接收/实施；实际状态以最新登记为准。

```text
请在 /Users/lagransun/workspace/Nastart 接续 Nastart App 的开发。

协作原则：你与Codex共同开发，不固定由任何一方长期主导。
每批按双方实际可确认的剩余额度、任务连续性和资源情况安排负责人；
双方都可以承担产品实现、架构和优化。看不到额度就如实写未知，
不要把Codex线程Goal状态当会员余额。Codex当前继续维护集成/共享状态，
并默认发起iPhone13、iPad及恢复后的Apple TV真机远控。
这次请你接续下面的有界任务，不因此获得永久主导权或设备权限。

先读取：
1. AGENTS.md、CLAUDE.md、PROGRESS.md；
2. docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md；
3. docs/development/CODEX-CLAUDE-COLLABORATION.md；
4. docs/development/AGENT-RESOURCE-STATE.json；
5. docs/project/APP-DEVELOPMENT-OVERVIEW-2026-11-02.md；
6. docs/development/CLAUDE-PRIMARY-DEVELOPMENT-HANDOFF.md；
7. docs/project/PLAYBACK_EXPERIENCE_PRIORITIES.md，按需读实际播放架构。
8. 需要真机支持时读 docs/development/PHYSICAL-DEVICE-REMOTE-CONTROL.md，
   先区分安装/原生退出与截图/WDA输入；向设备负责人提交明确窗口请求，
   不直接沿用历史UDID/端口/Runner，不把新A16 Pad当旧Pad或把TV模拟器当真机。

当前事实：第五批WebDAV四文件已集成/释放，相关类型测试6/6过；
第六批密码因果审查已交付，但密码首次编辑/显隐失焦尚未修复。
TV第二轮四项模拟器确认框测试通过，不代表TV真机或真实NAS退出通过。
13/iPad现装包早于第五批，需Codex按最新源码重新核包/构建/保留数据安装。
仓库有大量已接受但未提交内容，旧HEAD和旧a087a486独立目录都不是最新基线；
先读最新现场，若这些事实已变化以最新证据为准，不重复已有交付。

直接复用已交付审查：
docs/archive/handoffs/2026-11/2026-11-02-0735-CLAUDE-BATCH6-PASSWORD-CAUSAL-REVIEW.md。
重点核对当前源码：
- ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift
- ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/PasswordInputDiagnostics.swift
- ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/OfflineMediaScene.swift
按实际引用再读场景枚举/测试；旧报告中的行号与哈希不替代当前文件核对。
若已有更新的同任务交付，先核其内容与源码是否仍适用，不再产出重复审查。

本次先完成一个可落地的密码对照/实施准备批：
- 复用第六批审查，分开“预填密码首次编辑替换”和“显隐切换失焦”；
  不再写同样的泛审查，不猜第三个延迟参数，不强行拼接旧密码。
- 阅读当前真实表单/诊断接线，提出最少有鉴别力的空/预填、原生字段/
  正式表单、secure/plain、contentType及有/无trace对照；区分ASCII/IME。
- 给完整可写文件清单、基线哈希、拟实现的最小变更、匿名事件、失败反例、
  必要测试和Release排除；不采密码原文/长度/精确选区或真实凭据。
- 给Codex明确的设备/构建请求：源码配置、目标设备、合成输入、动作、
  时间上限、判定边界、清理/偏好保持。单次相关性不能冒充内部根因证明。
- 在 docs/archive/handoffs/2026-11/ 新增独有的
  YYYY-MM-DD-HHMM-CLAUDE-CONTINUATION-NEXT-BATCH-PLAN.md，
  写实际完成、源码起止哈希、失败/未知、文件范围、资源请求和下一步。

交付必须能让Codex直接准备下一实施批：逐文件列目的、必要性及风险，
每组对照写预期观察、能排除什么、仍不能证明什么，以及停止条件。
不要沿用第六批“单次对照差异即证明UIKit/contentType根因”的判读；
先明确保留既有秘密、修改草稿、替换秘密的产品语义，不使用真实账号。

当前登记尚未授予新产品写入/构建/设备窗口，所以这一批只读产品源码、
只新增上述报告，不自授权限。交接同源独立工作区和完整文件后，应直接
实施已明确授权的最小修复与必要回归，不循环审查，也不等用户反复说继续。
按最新登记，已授权独立工作可继续；需要设备/文件窗口时保留现场和明确请求。
后续依次考虑设置/真实偏好、媒体返回保位、连接/分享/缓存取消等离线闭环。
NAS恢复后的大文件/首帧/seek/弱网主线仍保持优先级，具体负责人按额度调整。

边界：NAS仍恢复，暂停发现、连接、登录/logout、目录/图片/媒体/服务探针；
不启动会恢复旧NAS的普通根；只用已核安全离线入口/合成夹具/本机loopback。
iPhone18 hands off。同一完整文件、真机、Runner、端口和重构建窗口不能并发抢占。
不改共享PROGRESS/当前交接/资源登记/需求状态，不清用户数据、回滚dirty、
卸载App、改NAS/VPN/系统/依赖签名或发布。原始设备证据/凭据留本机私有区。

额度接近限制时先保存源码/补丁、已执行验证与失败、未完成项和资源清理，
形成可接续交接；额度变化不等于设备/文件锁已释放。不要声称未跑的测试通过、
未发送的消息已同步，或回合结束后仍有后台开发。完成阶段后继续现有授权内
下一项，有人工依赖则保存现场并继续独立工作。
```
