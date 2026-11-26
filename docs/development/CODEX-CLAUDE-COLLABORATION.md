# Codex 与 Claude Code 协作分工

2026-11-21 每次从 Codex 转交 Muse 时，Codex 在回复中附上一段可直接复制的指令，由用户转发。指令写清工作区、源码或补丁、已有验证、Muse 要执行的更新与验收，以及失败时需要回传的证据。Muse 回传结果后，Codex 接续对应的代码修正。

2026-11-21 用户明确分工：Codex 基于 Muse 的反馈做源码修正和优化，完成代码审查、编译与相关离线测试，必要时使用模拟器。用户通过 Muse 负责安装更新和真机调试验收。电视三项修正已交代码，Xcode 27.2 标准构建和测试目标构建通过，Mac HTTP 测试 5 项通过。电视效果待 Muse 实测。

2026-11-21 用户最新分工为 Codex 主要负责代码实现、优化、审查及构建和相关回归，用户拟请 Muse 协助当前环境问题与真机验收。具体设备窗口仍按实际登记和现场授权，未向 Muse 自动发消息或认定其已接手。该分工优先于下方较早批次的默认设备职责。 [Muse 交接](../archive/handoffs/2026-11/CODEX-TO-MUSE-2026-11-21-DEVELOPMENT-AND-OPEN-ITEMS.md)

2026-11-20 新查明 iPhone 13/18 既有备份保存相同 Jellyfin 设备 ID（物理 UDID 不同）；13 当前仍相同。Jellyfin 按账号＋设备 ID 重登撤销旧会话，存在互踢缺陷。今天 13 保存公网会话读库 401，未提交密码；具体撤销操作待服务端日志。S19 设备文件续播有画面但缓冲，采样不完整，窗口已收尾。 [诊断与接续](../archive/handoffs/2026-11/CODEX-2026-11-20-JELLYFIN-DUPLICATE-DEVICE-ID.md)

2026-11-20 Codex 完成用户指定的 iPhone 13 WDA 恢复与实际输入验证。无产品源码或构建修改，Runner/8168 转发已收尾，设备窗口释放。 [恢复记录](../archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-WDA-RESTORED.md)

2026-11-20 Codex 完成 iOS 26.5 平台安装、iPhone 13 App/WDA 续签、USB 数据保留更新和启动验收，设备与构建资源已释放。 [安装记录](../archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-USB-APP-WDA-INSTALL.md)

2026-11-20 Codex 完成 NAS 只读校验与本地旧构建产物清理，候选队列已核完。清理未占用设备窗口。 [空间清理](../archive/handoffs/2026-11/CODEX-2026-11-20-NAS-DEBUG-ARCHIVE-LOCAL-CLEANUP.md)

2026-11-20 Codex 完成 Xcode 26.6 并排安装与 iPhone 13 USB 识别。无设备写操作，构建与设备窗口空闲。 [工具安装](../archive/handoffs/2026-11/CODEX-2026-11-20-XCODE-26.6-INSTALL.md)

2026-11-20 Codex 按用户指示转向 iPhone 13 App 更新，完成 USB 和签名只读预检，未占真机或构建资源。 [iPhone 13 接续](../archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-APP-UPDATE-FOCUS.md)

2026-11-20 Codex 完成 iPhone 18 Pro Max 新签名、无线覆盖安装及 WDA 启动复验，已释放设备、WDA 与构建窗口。iPhone 13 只复核 USB 和签名覆盖，iPad 用户使用中。 [安装记录](../archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE18-WIRELESS-APP-WDA-INSTALL.md)

2026-11-19 晚 Codex 复核 iPhone 13 USB 与 iPhone 18 Pro Max 无线预检，未发送安装；iPad 用户使用中。 [晚间接续](../archive/handoffs/2026-11/CODEX-2026-11-19-IPHONE13-IPHONE18-INSTALL-FOLLOWUP.md)

2026-11-19 Codex 串行完成 iPad App 与 WDA 覆盖安装，后续待设备上确认信任。两部 iPhone 未发安装，构建与本批设备窗口已释放。 [安装记录](../archive/handoffs/2026-11/CODEX-2026-11-19-APP-WDA-SIGNING-AND-INSTALL.md)

2026-11-14 Codex 完成同包 iPhone 13 公网保存会话的 4G 冷启动读库，原 Wi-Fi 与设备资源已收尾。 [公网冷启动](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-COLD-RESTORE.md)

2026-11-14 Codex 完成新包 iPhone 13 的两次 4G 公网主入口认证。首窗失败，次窗恢复读库，原 Wi-Fi 与设备资源均已收尾。 [4G 公网复核](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-4G.md)

2026-11-14 Codex 完成 iPhone 13 同一内网会话的覆盖安装前后对照，原 Wi-Fi 和真机窗口已释放。 [覆盖对照](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-VERIFIED.md)

2026-11-14 Codex 已完成 iPhone 13 覆盖前读库基线与新签名包验证。旧包已经 401，先交回用户重登，构建与真机资源已释放。 [覆盖前基线](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-BASELINE.md)

2026-11-14 Codex 完成 Jellyfin 公网会话恢复源码与定向模拟器验证，已释放独立模拟器和构建窗口，未占真机。 [认证与恢复](../archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-PUBLIC-401-RECOVERY.md)

2026-11-14 Codex 通过已有 DSM 会话只读取证，关联 Jellyfin 401 与令牌撤销及签发时间线，并在本机夹具复现旧公网会话阻塞恢复。未占真机与构建窗口。 [服务端日志关联](../archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-SERVER-401.md)

2026-11-14 Codex 完成 iPhone 13 Jellyfin 隔夜读库，设备、Runner 和采集已释放。未占新构建资源，旧 401 待服务端日志。 [隔夜读库](../archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-OVERNIGHT-SESSION.md)

2026-11-13 Codex 完成《变形金刚》同份 ISO 双入口取证。Jellyfin 后续冷启动再次 401，设备和测试资源已释放。 [双入口对照](../archive/handoffs/2026-11/CODEX-2026-11-13-TRANSFORMERS-ISO-JELLYFIN-COMPARISON.md)

2026-11-13 Codex 补完 MKV 冷续播及第二部 UDF ISO 出画。Jellyfin 401 后已释放设备，用户在 App 内重登后再开对照窗。 [补测记录](../archive/handoffs/2026-11/CODEX-2026-11-13-ISO-JELLYFIN-MKV-RESUME.md)

2026-11-13 Codex 完成用户补样的 iPhone 13 内网设备文件首轮，ISO 主片与续播、MKV 原片出画与跳转已有证据，设备窗口已释放。 [新样本首轮](../archive/handoffs/2026-11/CODEX-2026-11-13-ISO-MISSION-IMPOSSIBLE-SAMPLES.md)

2026-11-13 Codex 完成 W10 字幕接入顺序修正、定向模拟器验证及最新签名包。iPhone 18 仅安装，iPhone 13 实播保留手动候选未对齐的失败证据，设备与构建窗口均已释放。ISO 等待样本。 [W10 修正与复测](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-FIX.md)

2026-11-13 Codex 在同源独立副本复现 W10 预热层字幕清空，专用模拟器已释放。主工作区未开启产品修正批，真机窗口未占用。 [字幕隔离验证](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-SIM.md)

2026-11-13 Codex 完成两次 W10 有界复跑和旧证据复算，iPhone 13 窗口已释放。下一次取证范围是预热渲染器接入的字幕状态及切轨耗时，未开启新产品实施。 [W10 复核](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-FOLLOWUP.md)

2026-11-13 Codex 已汇总 T5 的 W1–W10 真机行为证据，iPhone 13 已在原 Wi-Fi 上复核正常续播并释放窗口。受控限速下的 W10 切轨耗时和后续独立降档丢字幕留作体验问题，未开启新的产品实施或设备窗口。 [T5 回归结论](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-READBACK.md)

2026-11-12 用户将播放策略真机验证、调试和有界调参交给 Codex，按 [本轮总交接](../archive/handoffs/2026-11/2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md) 执行。T0 由 Codex 串行装包和核验，窗口均已释放。本批 Claude 设计交付为输入，双方额度未知。 [T0 记录](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)

2026-11-10 用户安排下一阶段调试接续 Claude，入口为 [Codex → Claude 接续](../archive/handoffs/2026-11/2026-11-10-0645-CODEX-TRANSITION-TO-CLAUDE.md)。Codex 本轮占用已释放，仍由 Codex 单写共享摘要；Claude 的下一批优先 SMB Reader 与缓冲诊断，实际文件、构建与设备窗口依登记逐批分配。

2026-11-08 [Range与两机基线](../archive/handoffs/2026-11/CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)由Codex单写完成。产品增量DevicesView/测试文件；第一/二代理及真实预读继续由Codex接续。两机先627c基线，最终bb4d再次保留安装；不把旧包播放当最终包验收。共享摘要仍仅Codex维护，没有新Claude文件/设备授权。

2026-11-08 最新[阶段接续](../archive/handoffs/2026-11/2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md)和[Codex接收核对](../archive/handoffs/2026-11/CODEX-2026-11-08-TRANSITION-INTAKE.md)已生效。Claude本阶段结束，后续实现/审查/包与13-Pad验证由Codex单写接手，上一条“Claude第一步”分工为历史方案。Claude未授新实施/设备窗口；再次并行按含dirty同源目录及完整文件重分配。NAS业务恢复及18仅按用户要求安装的边界按总交接执行，凭据仅用户输入、禁止读取实际Keychain或点密码眼睛。

2026-11-08 当前安排见[共享代理审查](../archive/handoffs/2026-11/CODEX-2026-11-08-SHARED-PROXY-PLAN-REVIEW.md)。本批Claude承担第一步/13-Pad顺序对照，Codex承担Range前置、第二步公共接口/代理和预读排查。28文件基线与当前dirty源已核，独立同源目录和完整文件/设备登记后激活实施。当前没有产品写入lease或真机窗口，额度均未知。11-07恢复后NAS/Jellyfin播放背景及用户三机4744前缀陈述已收到，旧NAS暂停/11-04包与设备授权表属于历史，现场仍按本批身份/签名/只读源/独占要求执行。

2026-11-04 当前接续：[目录逐级返回](../archive/handoffs/2026-11/CODEX-2026-11-04-FOLDER-PICKER-INTEGRATION.md)已追加精确Claude原件与独立DEBUG夹具提交；最终源/六配置/新包/两机保留安装完成。用户明确授权仅两台Runner重签/部署，已执行；iPad交互过、13超时仍未验收，各窗资源已收尾释放。共享摘要由Codex更新；不转授新Claude文件/设备/重构建权限，额度未知，NAS/18边界保持。旧“Runner过期未部署”是历史结论。

2026-11-03补充：[18无线更新](../archive/handoffs/2026-11/CODEX-2026-11-03-IPHONE18-WIRELESS-UPDATE.md)由用户新请求单独授权Codex、现已收尾；不转授Claude，不扩大到NAS/普通根/持续设备控制。此前hands-off为当时限制，本次有界覆盖及结果读新报告/登记。

2026-11-03 当前批次：[第二次UI交付](../archive/handoffs/2026-11/2026-11-03-1945-CLAUDE-INTEGRATION-REQUEST-2.md)已由Codex[核对集成](../archive/handoffs/2026-11/CODEX-2026-11-03-CLAUDE-UI-INTEGRATION-2.md)，四文件与单文件手机标题修正追加到原审查分支；主HEAD/index/其它dirty保留。最终六配置、签名包及13/Pad保留安装完成，12个有限离线静态窗实看，完整交互因有效Runner缺失仍待。源码/构建/设备窗口已释放，无自动新批许可；双方额度未知。下文早期“新包待/未回归”只代表当时历史，以最新登记为准。

生效：2026-11-01（Asia/Shanghai）。用户要求两者共同开发 Nastart，并明确划分代码、真机和环境职责。本文件规定协作方式；实际进度读 [PROGRESS](../../PROGRESS.md)、[当前交接](../handoffs/CURRENT-PLAYBACK-HANDOFF.md)，资源状态读 [资源登记](AGENT-RESOURCE-STATE.json)。用户的新指示优先。

2026-11-02最新澄清：双方共同开发，**按每批实际剩余额度、任务连续性和资源情况动态分工，不固定任何一方长期主导**。Codex当前继续集成、共享状态、工具链和默认真机远控支持；双方均可承担产品代码/架构/优化。[全面盘点](../project/APP-DEVELOPMENT-OVERVIEW-2026-11-02.md)、[协作接续单](CLAUDE-PRIMARY-DEVELOPMENT-HANDOFF.md)及[可直接转发的推进指令](CLAUDE-NEXT-DEVELOPMENT-PROMPT.md)已同步。第三/五批已接入且写入释放，第六批只读审查已交；TV模拟器4/4过，非真机/NAS事务验收。13/Pad现装包早于第五批，新包待。当前Claude接续任务仍是只读形成下一批完整范围方案/独有报告，无新产品/构建/设备许可；实施前登记含dirty同源目录与完整文件。权限提示由用户处理，Codex不代点，本轮只生成指令未发送。

## 按额度动态安排负责人

1. 每批记录任务负责人、实施者、复核/集成者、完整文件和资源窗口；双方都能主导代码与架构，不按“Claude开发、Codex只操作设备”固定分层。
2. 依据用户告知或本方实际可见的额度/限制和预计工作量安排。记录来源与时间；不能读取另一产品余额时记未知，不编造百分比、恢复时间或自动查询能力，也不要求提供账号/密钥。线程Goal的usageLimited只说明该线程状态，不证明会员额度耗尽。
3. 当前Claude接续指令仅是这一批的安排，不授予永久主导权；两方都可提出后续批次，选额外重读/切换成本较低且有足够额度的一方完成有界任务。未知额度不阻止已有授权的独立工作，不必每个小步再问用户。
4. 额度接近限制时先保存当前源码身份、补丁、已执行命令、失败/未验项及资源清理；让有额度且具备上下文的一方接续。不能因额度/会话退出自动解除文件/设备占用，须核实际释放再登记交接。
5. Codex当前仍是共享状态单一写入者和默认真机操作者；产品负责人调整不自动转移这些资源，也不改变NAS暂停、18 hands off或保留数据要求。需要设备/重构建的一方提交明确请求，其余工作继续。

## 当前自动接续与消息授权（2026-11-02用户明确要求）

用户已要求完成一项后自动进入当前交接的下一项，本线程曾启动Goal以支持跨回合接续；不是定时任务，不恢复旧heartbeat。2026-11-02本轮工具返回Goal为usageLimited，授权仍保留，但不能声称当前仍有后台自动执行。目标只覆盖当前已授权的NAS无关阶段，完成标准看实际实现/验证和阻塞审计，不把整个App或受暂停的NAS功能写成已完成。

用户同时明确授权Codex在Mac既有Nastart的Claude对话发送已分配任务/必要继续指令，**仅限消息发送，不对Claude做其他操作**。定位现有对话/输入框、发送及核实提交属于此动作；不改设置/模式、创建会话或操作其它任务。无须每条再向用户请求相同许可。每次先落盘文件范围和资源登记，再发一条自足指令；同批进行中不重复催发，不以“继续”替代明确授权范围。发送成功与对方实施/完成分别记录，不声称自动互斥或对话记忆同步。

第三至六批均已有交付（只读批与实施批分列），第五批已实际接入；此前“第五批排队”只是历史。用户本轮保留权限提示不撤销既有交付，也不自动授新实施/设备窗口。双方资源边界不因Goal或消息授权扩大。

## 当前环境与共同边界

- NAS 仍在恢复。两方均暂停 NAS 发现、登录、连接、目录/图片/影片读取、播放和服务探针；普通 App 入口可能自动恢复会话，也不能作为离线测试入口。只使用经过源码核对的隔离入口、合成夹具或本机 loopback。
- iPhone 13 与新接入的 iPad（A16，iPadOS26.6）是当前设备；Apple TV 正在恢复开发连接。另一台旧 iPad 不可用，不混作本次目标。iPhone 18 今晚由用户使用，两方都不控制、安装、启动或采集。
- 最新移动正常包与当前接受源码的身份见当前交接。TV 没有完成最新包安装/回归；模拟器、旧包或电视开机均不能替代该结论。
- 遵守根目录 [AGENTS.md](../../AGENTS.md)，尤其保留数据覆盖、最新包门槛、蜂窝收尾、只读 NAS、私有证据及历史失败保留。任何一方都不擅自卸载、清登录、重置网络、改 NAS/VPN、升级系统或发布。

## 职责分配

| 工作 | Codex | Claude Code |
| --- | --- | --- |
| 集成与任务协调 | 当前维护集成工作区、登记文件/资源范围、审查接入及证据；也可按批主导产品任务 | 按批承担任务方案/实施/复核，交实际修改、验证与失败记录 |
| 真机与开发连接 | 默认统一发起13/Pad/恢复后的TV远控、包安装与取证 | 提交动作/配置/窗口请求，未明确交窗不操作设备/Runner |
| 当前主要任务 | 全面盘点、第五批后新包准备及设备支持；TV连接待环境变化 | 复用第六批，按接手单给密码对照的完整实施范围与验证请求，不重复旧只读审查 |
| 后续产品开发 | 可主导或协作UI、播放、架构和底层优化，按额度及完整文件分工 | 同样可主导或协作产品实现/优化，按额度及完整文件分工，无永久主导权 |
| 共用核心及工程配置 | 协调影响面、实际构建/签名和跨端验证 | 可提出并实施明确登记的源码改动；未分配前不改认证迁移、工程/依赖/签名 |
| 项目总进度与需求状态 | 单一写入者，汇总双方结果 | 在本方批次交接报告进展，不直接覆盖总进度或关闭需求 |

这不是按模型能力划高低。默认分工用于避免当前设备和大文件重叠；每批可调整。修改文件粒度优先于“手机/电视”或“前端/后端”标签，因为三端共用大量 Swift 文件。

## 首批只读任务（历史，已交付）

**任务：审查非 NAS 页面的大字、可访问性与状态说明，先交付问题和补丁计划。**

1. 依次阅读根 `CLAUDE.md`、`AGENTS.md`、本文件、进度、当前交接、[唯一需求总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。核实目录是当前集成工作区，先记录 HEAD、dirty 状态和所读文件哈希。
2. 只读审查 `ios/Nastart/Nastart/Features/Mine/MineView.swift`、`ios/Nastart/Nastart/Core/Design/AppTheme.swift`、`ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAVConnectionFields.swift` 和 `tvos/NastartTV` 中相关设置/连接页面。按已有待验项找可说明的缺陷，保留既有测试失败，不把计划写成已修。
3. 区分正式入口与合成预览，重点检查辅助字号、长文截断、控件标签、禁用/忙碌状态、焦点和返回边界。静态推测、单元证据、模拟器和真机呈现分别标记。
4. 首批不修改产品/测试源码，不运行全量构建、不启动模拟器或真机、不访问私有设备证据/凭据、不运行 NAS 或媒体探针。允许在下面独有报告路径写审查结果。
5. 交付 `docs/archive/handoffs/2026-11/YYYY-MM-DD-HHMM-CLAUDE-OFFLINE-UI-REVIEW.md`；可分享结果可放 `docs/testing/results/2026-11/` 下同名文件。列出问题、源码位置、现有证据、最小修复、拟修改文件和真正需要的验证；没有发现也如实记录，不凑问题。已有需求只引用唯一总账，不另建一套编号。

iPad最新包准备及信任后实际静态图见[设备交接](../archive/handoffs/2026-11/2026-11-01-IPAD-REJOIN-AND-COLLABORATION.md)；原19偏好保持、测试进程已停。该首批可与 Codex 的设备恢复同时进行，不需要等待 TV。完成后由 Codex 在集成检查点读取报告并分配一个有明确文件清单的实施批；不把两者都留在只读审查阶段。Claude 实施后的首个真机方向为 iPad 辅助字号、横竖布局及非 NAS 交互；这不预先宣称这些功能有缺陷，也不取消最新包/独占窗口门槛。

## 代码与分支：共享成果，隔离修改

- 当前工作区有大量已接受但未提交的改动，HEAD 本身不是最新 App。**不能直接从 HEAD 新建 Claude worktree 后就声称使用当前基线。**
- 首批只读审查可以读取当前目录，唯一写入是自己的新报告。若审查期间相关文件变化，记录起止哈希并重读受影响部分；报告不能混淆两版。
- 开始并行实施前，由 Codex 保存当前状态，在不清理/丢弃用户修改的前提下准备包含已接受修改的明确基线和 Claude 独立工作区。交接必须记基线标识、输入哈希、绝对工作目录、分支、可写文件、禁改文件和验证命令；尚未准备完成就不开始写产品代码。本文件创建时还没有为 Claude 建新 worktree。
- 每批只给一个写入者；即使同文件不同段也不同时编辑。`MineView.swift`、`AppTheme.swift`、`LibraryViews.swift`、本地化文件及工程文件尤其按完整文件分配。
- Claude 不在 Codex 当前工作区 checkout、reset、stash、clean 或批量格式化；不回滚不了解的修改。独立分支只交本批补丁，不能把继承 dirty 全部混作自己的提交。
- 集成由 Codex 串行执行：核基线 → 审差异/测试 → 接入 → 冻结新源码与包 → 安排设备回归。分支合并仍可能有语义冲突，worktree 不能保证自动无冲突。

## 真机：同一时段只有一个操作者

**同一设备不能由两个会话同时调试，即使测试不同页面或不同功能。** 安装、launch/terminate、WDA 会话、截图/帧采集、遥控/触摸、偏好读取及恢复都属于该设备窗口；“只是截图”或“另一台 Mac 窗口”也不是豁免。

当前设备安排：

| 设备 | 当前安排 | Claude Code 当前权限 |
| --- | --- | --- |
| iPhone 13 | Codex 统一调度；上轮离线测试已停，原数据保留 | 不安装、不启动、不切页、不采集 |
| 客厅 Apple TV | Codex 与用户恢复开发连接；验证码由用户在 Device Hub 输入，最新包仍受签名条件限制 | 不接管配对窗口、不启动 Runner/App；用户关电视后不反复唤醒 |
| iPad（A16） | 最近有线/配对正常，56d9/26b8安装与主题静态窗已结束；该包早于第五批。默认由Codex按新源码核包与远控，仍需fresh现场 | 旧预留不是当前许可；仅明确交出具体独占窗口后使用 |
| 旧 iPad / iPhone 18 | 旧 iPad 不可用；iPhone 18 今晚由用户使用 | 不连接/安装/启动/采集，不沿历史许可操作 |

申请与交接：

1. 需要设备的一方给出设备别名、目的、源码/包、操作清单、时间上限、网络影响和收尾办法，写本方独有的 `CLAUDE-RESOURCE-REQUEST` 批次交接，由 Codex 在检查点读取。未获明确分配前继续独立工作。
2. Codex 先核实际空闲、用户是否操作、其他项目任务及既有采集，更新资源登记并明确交出；设备不空闲就排队，不能直接抢占。用户手动输入/复现期间暂停自动化。
3. 获得窗口后仍执行当轮 fresh 设备身份/最新安装包核对，不能沿用另一会话版本号或收据。测试条件、失败、超时均记录。
4. finally 停止自己发起的播放、下载、App/Runner/采集，恢复本轮改动，核实实际结果后交出；蜂窝窗口还须按 AGENTS 核原 Wi-Fi 及状态栏图标。不能停止未知或另一会话进程。
5. 到期、会话消失或登记过时都**不代表设备已空闲**。先核进程/流量与现场，再由协调者解除占用；不静默接管。无法确认时记未知并转独立任务。

资源登记是协作约定，不是操作系统强制锁；双方必须在动作前检查并遵守。当前没有自动设备锁、后台调度或跨产品消息通道，不能声称已自动互斥。

默认13/Pad/恢复后的TV操作仍由Codex发起，当批产品负责人提交所需动作；负责人按额度动态安排。旧“Claude长期用iPad”只是预留，不是当前设备许可。确有必要交窗仍可单独登记，每台逐窗独占并核包。NAS恢复后的任务还共享服务器和带宽，须另排媒体窗口，不能仅按设备不同并发取片。

## Mac 上也要分开资源

- Xcode 27 当前用于主构建/Device Hub；26.6 在项目历史中承担 iPhone 13/iOS16 的 WDA、Instruments 兼容路线。当前两者都保留，不把“开了两个窗口”当成已证实冲突，不自行删除任一套。
- 命令显式记录 Xcode 路径与版本，必要时仅对子命令设置 `DEVELOPER_DIR`；不全局切换 `xcode-select`。两版 Xcode 仍可能共享系统设备服务，不能分别打开就并发控制同一台设备。
- 每个实施批使用自己的 DerivedData、SwiftPM scratch、xcresult、原始日志/输出目录和自建模拟器 UDID。禁止共写现有 `Nastart-Playback-Oct17` / `Nastart-TV` 或删除对方缓存、包、模拟器。
- 共享 SourcePackages 缓存只在已明确只读的解析/构建条件下复用；依赖下载、resolve、更新/清理互斥。不能默认 `Package.resolved` 不变就没有缓存写入。
- 当前空间有限，**默认只有一个重构建/模拟器批次**；另一方做阅读/轻量审查。模拟器创建沿项目既有空间门槛（移动6GiB、TV3.8GiB，运行保留2GiB），不足先保存现场；不自动批量清缓存或删旧工具链。
- 不共用 WDA 端口、HTTP 会话、test runner 或私有证据目录。真机 Runner 按设备窗口分配；本机服务要登记自己的监听端口与 PID，未知占用不杀。

## 交付、同步与验收

每批交付包含：负责人/任务、起始基线/文件哈希、实际变更文件、命令/Xcode配置、测试通过和失败/超时、证据路径、未验项、资源清理及下一步。未运行写未运行，不能把静态代码审查写成 UI 通过、把预览写成普通登录回归、把模拟器写成真机、把内部时钟写成真实帧时间。

并行期间，`PROGRESS.md`、当前交接、`DEVELOPMENT_STATUS.md`、唯一需求总账、播放矩阵、本协作文件及资源登记由 Codex 单一写入。Claude 只写自己的批次报告，提出需要同步的条目；Codex 集成时更新，避免双方覆盖“当前状态”。用户另指定 Bot 维护 PROGRESS 时按其规则。播放链路若接入修改，仍同批更新架构映射。

两者没有自动共享对话记忆。开始一批、基线变化、申请资源和完成交付时重新读共享文件，通过报告与补丁同步；不靠猜测对方最新聊天，不新建定时轮询/heartbeat，不声称回合结束后仍在工作。Claude已提交审查与确认，具体第一实施批已分配；这不证明它已经在新目录实施或完成构建，须读取后续交付。

技术依据：[OpenAI worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees)、[Claude Code 并行工作区](https://code.claude.com/docs/en/common-workflows#run-parallel-sessions-with-worktrees)。上面的人员分工、资源独占和验收口径是本项目约定，不是厂商提供的自动跨工具协调能力。
