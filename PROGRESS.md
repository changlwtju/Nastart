# 当前进度

2026-11-26 Agent 第 9-4 件更新日志与路线图已完成，记录 0.1.0 内部开发版五项内容和七项计划。390px 与 1280px 浏览器检查通过，其余四页页脚的「更新日志」均能打开本页。 [更新日志](website/changelog.html)

2026-11-26 Agent 第 9-3 件支持页与 FAQ 已完成。Chrome 实测 390px 和 1280px 下两页无溢出、404 或外部加载请求。三个支持入口已实点到 FAQ 对应位置，十题及导航链接均已核对。 [支持页](website/support.html) · [FAQ](website/faq.html)

2026-11-26 Agent 第 9-2 件隐私政策页已完成，复用官网样式和导航。Chrome 实测 390px 与 1280px，无横向滚动、文字溢出、404 或外部请求。生效日期、九项事实及链接均已核对。 [隐私政策](website/privacy.html)

2026-11-26 Agent 第 9-1 件官网静态骨架与落地页已完成。Chrome 实测 390px 和 1280px 布局均无横向滚动或文字溢出，首页仅两个本地请求且均为 200，四个页脚目标核对通过。待 Muse 本地复核。 [落地页](website/index.html)

2026-11-25 Agent 第 8 件 DSM 侧安装完成。DS918+ 用官方 Docker Project Worker 手动安装并启动 `0.4.0-0008`，HTTPS 200、版本 0.4.0，最小测试包不在已安装清单。Mac 模拟生命周期及 23 项单测通过。iPhone 13 重新配对、握手指纹及启动台状态待验。 [验收记录](docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-08-ACCEPTANCE.md)

2026-11-24 Agent 第 7 件完成 0.4.0 自签证书和默认 HTTPS。23 项 Python 测试及本机 Compose 验证通过，Docker Hub 发布镜像已核，待 Muse 复跑和 iPhone 13 用 HTTPS 重新配对。第 1–6 件已由 Muse 验收。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-24-AGENT-PIECE-07-AUTO-CERT.md)

2026-11-23 Cloud 同步第 5 件已完成本地双设备测试 harness。五类验收在 mock 中通过，Xcode 26.6 iOS 30 项、Xcode 27.2 tvOS 24 项通过。测试源码校验与复跑命令已交，待 Muse 复跑。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-23-CLOUD-SYNC-PIECE-05-TWO-DEVICE-HARNESS.md)

2026-11-22 Cloud 同步第 4 件已接 iOS 待同步、首次同步与本地化错误提示。Xcode 26.6 的 iPhone 17e 模拟器构建通过，26 项通过，待 Muse 复跑并覆盖安装验收。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI.md)

2026-11-22 Cloud 同步第 3 件已接入电视服务显示开关、共享记录和旧键迁移。三组真实 DSM 发现夹具双端同键，Agent 单独生成的卡片键仍不同。Xcode 26.6 的 iOS 18 项及 Xcode 27.2 的 tvOS 23 项定向测试通过。待 Muse 复跑与覆盖安装验收。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-03-TV-SERVICES.md)

2026-11-22 Cloud Sync 第 2 件已接入 iOS 待处理与历史事项删除、提醒取消和 30 天 tombstone。Xcode 26.6 模拟器 Debug 和无签名 iPhoneOS Release 构建通过，7 项新增 mock、7 项同步旧用例和 3 项关联回归通过。待 Muse 复跑并覆盖安装验收。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE.md)

2026-11-21 Cloud Sync 第 1 件已接入 iOS 三域记录、独立合并与 v1 标记迁移。Xcode 26.6 的 iOS Debug 模拟器与无签名 iOS Release 构建通过，7 项 mock 和 2 项关联回归通过。待 Muse 按 Debug 包复验。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-21-CLOUD-SYNC-PIECE-01-RECORD-SPLIT.md)

2026-11-21 Muse 确认服务详情三主题信息卡均 1620 pt。另两处窄弹窗「管理显示」「存储与媒体 → 连接管理」已改为 tvOS 整页导航，Xcode 27.2 Build for Testing 通过，18 项离线测试通过。两页可见卡片宽度和返回待 Muse 真机复测。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-MANAGEMENT-PAGES-WIDTH.md)

2026-11-21 Muse 真机确认 Jellyfin 通过、Docker homepage 返回通过（其他容器及列表路径仍待测）。按用户要求仅修电视服务详情宽度：显式按视口设宽，宽度探针定位唯一卡片。17:22 Xcode 27.2 Build for Testing 通过，宽度待 Muse 复测。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-SERVICE-DETAIL-WIDTH.md)

2026-11-21 每次从 Codex 转交 Muse 时，Codex 在回复中附上一段可直接复制的指令，由用户转发。指令写清工作区、源码或补丁、已有验证、Muse 要执行的更新与验收，以及失败时需要回传的证据。Muse 回传结果后，Codex 接续对应的代码修正。

2026-11-21 用户明确分工：Codex 基于 Muse 的反馈做源码修正和优化，完成代码审查、编译与相关离线测试，必要时使用模拟器。用户通过 Muse 负责安装更新和真机调试验收。电视三项修正已交代码，Xcode 27.2 标准构建和测试目标构建通过，Mac HTTP 测试 5 项通过。电视效果待 Muse 实测。 [代码交接](docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-THREE-ISSUES-FIX.md)

2026-11-21 16:56 Xcode 27.2 标准 App 构建及 Build for Testing 均已成功，产出 Apple TV 包和测试描述。当前命令会话签名信任校验失败，本批未安装，三项修后真机验收待续。 [构建记录](docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-THREE-ISSUES-FIX.md)

2026-11-21 电视三问题修正候选：补 Jellyfin 标准 token 头与认证诊断，调整容器导航/焦点及子页宽度。Xcode 27.2 工具链编译链接、UI 测试类型检查通过，5 项 Mac HTTP 夹具测试通过。标准签名包与三项修后电视真机验收仍未完成，当前设备查询超时。 [本轮修正及阻塞](docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-THREE-ISSUES-FIX.md)

2026-11-21 已按用户要求整理给 Muse 的完整接续，涵盖开发进展、环境阻塞、四端安装、本批编译与测试、30 项开放需求及待发布工作。用户最新分工为 Codex 主要负责代码优化，拟请 Muse 协助环境与真机验收，尚未代发消息。本次 Jellyfin 修复仍为 0 台安装。 [完整交接](docs/archive/handoffs/2026-11/CODEX-TO-MUSE-2026-11-21-DEVELOPMENT-AND-OPEN-ITEMS.md)

2026-11-21 用户截图确认当前为 ChatGPT Work 窗口。Mac 同时安装 ChatGPT.app 和 Codex.app；直接打开 Codex.app 返回 -10827，已核其可执行文件存在。待用户打开 Codex 本地项目后实测实际执行权限，新会话能否解除限制尚未验证。

2026-11-21 已尝试直接访问客户端界面，当前无桌面点击接口，AppleScript 前台查询失败（-10827），无法代为切换会话权限。本轮终端更新仍为 0。

2026-11-21 访问失败已定位到执行策略不一致，本机 Codex 配置为完整访问，当前对话仍以受管沙箱及禁网策略执行，USB 服务文件存在且权限开放。需客户端创建实际允许系统服务访问的本地执行会话，接续签名、设备核对与安装。本次终端更新仍为 0。 [环境复核](docs/archive/handoffs/2026-11/CODEX-2026-11-21-JELLYFIN-PLAYBACK-AND-SESSION.md#执行环境原因复核)

2026-11-21 12:54 安装接续再次受阻，当前会话签名身份不可用、USB/WDA 连接权限被拒、设备列表查询超时；指定可写缓存后 Xcode 仍不能完成依赖解析。本次更新终端为 0，资源登记已更正旧“当前源码已安装”标记。等待具备 Mac 签名与设备服务访问能力的执行会话完成签名包及覆盖。 [接续记录](docs/archive/handoffs/2026-11/CODEX-2026-11-21-JELLYFIN-PLAYBACK-AND-SESSION.md#1254-安装接续复核)

2026-11-21 已完成 Jellyfin 播放与会话修复的源码修改。iOS 和 tvOS App arm64 编译、链接通过，31 项离线测试通过；3 项回环 HTTP 夹具因会话权限超时。完整签名包、iPhone 18 覆盖及 Muse 真机验收待续。 [本批交接](docs/archive/handoffs/2026-11/CODEX-2026-11-21-JELLYFIN-PLAYBACK-AND-SESSION.md)

2026-11-20 18:30 已确认 Mac 用户设置与当前桌面对话的实际执行策略不同。当前会话无法申请 USB/回环权限，WDA 尚未接管。后续把输入验证、调试和收尾留在一次具备权限的工作窗口。 [单机链路记录](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-ONLY-DEBUG-CHAIN.md)

2026-11-20 18:28 按用户要求专查 iPhone 13 WDA。直接读取既有本机转发端口的 /status 在连接阶段均被当前会话拒绝，未建立 WDA 会话。接续优先恢复 WDA 访问与实际触控。 [权限复测](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-ONLY-DEBUG-CHAIN.md#1821-桌面会话复测)

2026-11-20 18:21 桌面会话复测 USB 和本机端口仍为 EPERM，单次只读审批在弹窗前被受管策略拒绝。16:36 包与 647 项源清单一致，系统签名复验仍受阻。未触碰设备。 [桌面复测](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-ONLY-DEBUG-CHAIN.md#1821-桌面会话复测)

2026-11-20 18:12 用户指定改在 Mac 桌面应用调试。已确认桌面 Codex 本地项目的手动审批入口，等待用户切换后复测只读 USB 和回环权限。 [桌面接续](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-ONLY-DEBUG-CHAIN.md#1812-改用-mac-桌面客户端接续)

2026-11-20 18:02 回查 iPhone 13 上午实际触控和 Nastart 实播，确认走可审批会话的现装 Runner、USB XCTest 与转发。当前桌面命令会话复测 usbmuxd 和回环绑定均为 EPERM。已将这条成功路线及优先级补入调试规范，最新包和新一轮触控待在具备权限的执行环境中核验。 [历史对照](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-ONLY-DEBUG-CHAIN.md#1802-历史对照与当前复测)

2026-11-20 17:33 Xcode 已核唯一 USB iPhone 13 并备份 Nastart 容器。WDA 启动预检已区分 USB 权限、端口占用和设备身份，并校验 Runner 配置。当前会话的 USB 与签名信任检查受阻，最新诊断包待覆盖，待验实际触控。 [单机链路记录](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-ONLY-DEBUG-CHAIN.md)

2026-11-20 17:14 已提交 Apple TV 本轮验证码。输入窗口关闭，Device Hub 仍显示不可用，NastartTV 未列出该真机运行目标。 [提交后复核](docs/archive/handoffs/2026-11/CODEX-2026-11-20-PLAYBACK-DEVICE-COMPARISON-AND-TV.md#1714-apple-tv-验证码提交后)

2026-11-20 17:06 Apple TV 已在 Device Hub 新扫描中重新出现并打开新的验证码页，开发连接待验。iPhone 13 的 USB 设备可识别，命令会话仍无 WDA 所需的 USB 服务访问。 [开发连接复查](docs/archive/handoffs/2026-11/CODEX-2026-11-20-PLAYBACK-DEVICE-COMPARISON-AND-TV.md#1706-开发连接复查)

2026-11-20 16:58 iPad 已通过 Xcode 原生 XCTest 完成实际点击及选中状态验证。WDA 曾启动，当前会话访问其 HTTP 端口被拒，临时测试已收尾。iPhone 13 仍卡在 XCTest 启动前的 `Logic Testing Unavailable`。Nastart 诊断版已通过 Xcode 构建，尚未部署。 [设备对照与电视排查](docs/archive/handoffs/2026-11/CODEX-2026-11-20-PLAYBACK-DEVICE-COMPARISON-AND-TV.md)

2026-11-20 16:29 Apple TV 仍待输入 Device Hub 验证码。Jellyfin 降档诊断用固定 Get 依赖定向验证 8 项通过，整包构建停在 SwiftPM 缓存写入权限。iPad 和 iPhone 13 的同条件实播仍待触控通道。 [设备对照与电视排查](docs/archive/handoffs/2026-11/CODEX-2026-11-20-PLAYBACK-DEVICE-COMPARISON-AND-TV.md)

2026-11-20 已核 iPhone 13、iPhone 18 与 iPad 签名包的主程序和播放代码内容相同。13 的 S19 出画后缓冲约 12.8 秒和 9.7 秒，降档匹配失败。iPad 真机已到片源详情，触控和同条件实播待验。Apple TV 在两版 Xcode 均无可运行目标，附近发现为空。 [设备对照与电视排查](docs/archive/handoffs/2026-11/CODEX-2026-11-20-PLAYBACK-DEVICE-COMPARISON-AND-TV.md)

2026-11-20 新查明 iPhone 13/18 既有备份保存相同 Jellyfin 设备 ID（物理 UDID 不同）；13 当前仍相同。Jellyfin 按账号＋设备 ID 重登撤销旧会话，存在互踢缺陷。今天 13 保存公网会话读库 401，未提交密码；具体撤销操作待服务端日志。S19 设备文件续播有画面但缓冲，采样不完整，窗口已收尾。 [诊断与接续](docs/archive/handoffs/2026-11/CODEX-2026-11-20-JELLYFIN-DUPLICATE-DEVICE-ID.md)

2026-11-20 11:30 iPhone 13 WDA 已恢复：最新源包、签名和安装回执复核通过，ready、会话、取图及文件夹打开/返回实测成功。Runner 与转发已退出，29 项偏好一致。后续从可审批的本机会话接续 Wi-Fi 冷启动读库和播放。 [恢复记录](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-WDA-RESTORED.md)

2026-11-20 Xcode 原生 USB 已实测识别 iPhone 13 并取图。后备 XCTest 配置已指向续签 Runner。10:50 USB 和回环访问仍被当前会话拒绝，已核本机 CLI 交互审批接续参数，WDA 自动化待恢复。 [开发通道记录](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-USB-NATIVE-RECOVERY.md)

2026-11-20 HLS 离线报告已能自动识别续播实际首段，重放四个历史 trace 与原证据相符，测试 160 项通过。iPhone 13 已装 WDA，本会话 USB 权限仍受阻，实播待续。 [本轮交接](docs/archive/handoffs/2026-11/CODEX-2026-11-20-HLS-OBSERVED-SEGMENT-REPORT.md)

2026-11-20 iPhone 13 播放预检已核最新 Debug 的 647 个源码输入与包哈希。本会话无 USB 开发服务权限，实播待续。历史 S19 从头窗已交付清单，首段四次请求未见响应头。离线诊断 158 项通过。 [预检与复盘](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-PLAYBACK-PREFLIGHT.md)

2026-11-20 iPhone 13 已通过 USB 保留数据覆盖 Nastart 和 WDA，29 项偏好一致。普通启动见启动台，WDA ready 通过并已收尾。签名至 11-27 07:27，播放待续。 [安装记录](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-USB-APP-WDA-INSTALL.md)

2026-11-20 NAS 已归档旧构建队列核完，四批合计核验并移除 1,599 个 Mac 重复副本，回收 85.44 GiB，收尾可用 74.23 GiB。 [空间清理](docs/archive/handoffs/2026-11/CODEX-2026-11-20-NAS-DEBUG-ARCHIVE-LOCAL-CLEANUP.md)

2026-11-20 Xcode 26.6 已与现有 Xcode 27.2 并排安装，26.6 已通过 USB 识别 iPhone 13。Nastart 待续签及保留数据覆盖。 [工具安装](docs/archive/handoffs/2026-11/CODEX-2026-11-20-XCODE-26.6-INSTALL.md)

2026-11-20 用户确认 iPhone 18 Pro Max 安装包已更新，本轮专注 iPhone 13。13 的 USB、最新源码包已复核，缺目标签名，兼容 Xcode 下载待 Apple 账户页处理。 [iPhone 13 接续](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-APP-UPDATE-FOCUS.md)

2026-11-20 iPhone 18 Pro Max 已通过 Wi-Fi 保留数据覆盖安装 Nastart 和 WDA，27 项偏好一致。00:38 无线 WDA ready 通过，Runner 已退出，App 首页待核。iPhone 13 USB 已确认，兼容 Xcode 下载仍待 Apple 开发者协议。 [安装记录](docs/archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE18-WIRELESS-APP-WDA-INSTALL.md)

2026-11-19 晚 iPhone 18 Pro Max 已回家，配对和 App 容器备份均可走无线，Xcode 仍找不到签名目标。iPhone 13 USB 正常，待兼容 Xcode 或有效描述文件。iPad 由用户使用。 [晚间接续](docs/archive/handoffs/2026-11/CODEX-2026-11-19-IPHONE13-IPHONE18-INSTALL-FOLLOWUP.md)

2026-11-19 A16 iPad 的新签名 Nastart 和 WDA 已保留数据覆盖安装，偏好一致。系统待开发者信任。iPhone 13 缺覆盖设备的新版描述文件，iPhone 18 Pro Max 已离开家中，两个手机待装。 [安装记录](docs/archive/handoffs/2026-11/CODEX-2026-11-19-APP-WDA-SIGNING-AND-INSTALL.md)

2026-11-14 15:32 iPhone 13 同包在 4G 冷启动直接读取 Jellyfin 公网资源库，距恢复约 12 分钟，无需再次认证。原 Wi-Fi 已恢复。待补蜂窝实播。 [公网冷启动](docs/archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-COLD-RESTORE.md)

2026-11-14 iPhone 13 新包 4G 公网读库先失败后通过。首窗 401，次窗 `replacedRejected httpStatus=200` 后实际读库，无需重登。两窗均恢复原 Wi-Fi。 [4G 公网复核](docs/archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-4G.md)

2026-11-14 15:11 iPhone 13 保留数据覆盖新包 `caa776f8…`，30 项偏好一致。旧包重登读库后，新包冷启动直接进入同一内网资源库，无需重登。公网备用项仍 401。 [覆盖对照](docs/archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-VERIFIED.md)

2026-11-14 11:34 iPhone 13 在覆盖安装前已读库 401，登录表单预填新用户名。服务端同窗拒绝令牌，09:36 同账号曾换发。新包已签名，等待旧包建立有效会话做覆盖对照。 [覆盖前基线](docs/archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-BASELINE.md)

2026-11-14 用户补充 Jellyfin 改名后覆盖更新常要重登。现有日志证实保存令牌 401，新用户名重登成功，同包也曾再发 401。公网拒绝后的同账号恢复已接入，7 项定向模拟器通过，真机覆盖前后对照待验。 [认证与恢复](docs/archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-PUBLIC-401-RECOVERY.md)

2026-11-14 Jellyfin 服务端日志在两个 401 窗口均记录令牌无效。昨晚内网失败前约一分钟，服务端撤销旧令牌并为同账号签发新令牌。设备归属待核，隔离夹具已复现旧公网会话挡住恢复。 [服务端日志关联](docs/archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-SERVER-401.md)

2026-11-14 09:29 iPhone 13 原 Wi-Fi 隔夜冷启动，Jellyfin 内网会话直接读库，公网备用项仍 401。设备已释放。11-13 旧内网 401 待服务端日志，实际听音仍待。 [隔夜读库](docs/archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-OVERNIGHT-SESSION.md)

2026-11-13 22:22 Jellyfin 内外网保存会话均曾返回 401。重登后一次冷启动恢复内网资源库，公网备用项仍 401。同份《变形金刚》ISO 补到 19.187 秒续播、内部首帧 3.223 秒、普通退出及资源归零。设备已释放，令牌被拒原因和实际听音待核。 [认证与退出](docs/archive/handoffs/2026-11/CODEX-2026-11-13-JELLYFIN-SESSION-ISO-EXIT.md)

2026-11-13 同一《变形金刚》(2007) UDF ISO 已补 Jellyfin 内网从头、跳转、普通退出和带字幕续播。Jellyfin 续播内部首帧 8.866 秒，驱动截止后原生收尾。22:12 冷启动补验再次 401，设备已释放，普通续播退出与听音仍待。 [双入口对照](docs/archive/handoffs/2026-11/CODEX-2026-11-13-TRANSFORMERS-ISO-JELLYFIN-COMPARISON.md)

2026-11-13 17:45 iPhone 13 原 Wi-Fi Jellyfin 已按用户要求重登，资源库和搜索实际可用，设备窗口已释放。本窗止于登录，ISO 对照可继续。 [重登记录](docs/archive/handoffs/2026-11/CODEX-2026-11-13-JELLYFIN-LAN-RELOGIN.md)

2026-11-13 iPhone 13 原 Wi-Fi 同包补到《碟中谍5》冷续播，70.058 秒起点、内部首帧 7.045 秒、实见中文字幕。《变形金刚2》UDF ISO 主片出画并正常退出。Jellyfin 资源库 401，ISO 对照待 App 内重登。设备已释放。 [补测记录](docs/archive/handoffs/2026-11/CODEX-2026-11-13-ISO-JELLYFIN-MKV-RESUME.md)

2026-11-13 用户已完成补样。iPhone 13 原 Wi-Fi 最新包实测《变形金刚》(2007) UDF ISO 主片、向前跳和带中文字幕续播；《碟中谍5》约 51.3 GiB MKV 已出画和跳转，确认杜比视界 P7 源。实际 Dolby 输出、听音和 Jellyfin 对照待补。 [新样本首轮](docs/archive/handoffs/2026-11/CODEX-2026-11-13-ISO-MISSION-IMPOSSIBLE-SAMPLES.md)

2026-11-13 W10 预热层字幕接入顺序修正，实际预热定向 6/6。iPhone 13 同包实测手动选轨优先，但原片候选未完成对齐，随后独立 HLS 降档提交并保留 PGS 9。原 Wi-Fi 和设备收尾已核，手动接管与现场听音继续开放。 [W10 修正与复测](docs/archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-FIX.md)

2026-11-13 07:06 iPhone 18 已 USB 保留数据装最新签名 Debug `c7cf7671…`，包含 W10 字幕接入顺序修正。28 项偏好相等，DSM 保存配置保留。用户正在下载《变形金刚》ISO，样本就绪后开展独立专项。 [安装记录](docs/archive/handoffs/2026-11/CODEX-2026-11-13-IPHONE18-W10-SUBTITLE-INSTALL.md)

2026-11-13 W10 隔离模拟器复现预热层首次挂载时轨 9 被异步 URL 初始化清空，运行时误报关闭。先初始化再选轨、主动关闭和同 URL 画中画回挂三个对照通过。渲染器修正及修后真机、听音待验。 [字幕隔离验证](docs/archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-SIM.md)

2026-11-13 W10 原切轨慢窗补到初始定位 16.716 秒、首个视频包 31.173 秒。丢字幕窗的旧 KSPlayer 在接管保存时已把 PGS 报为关闭。iPhone 13 两个无切轨降档窗都保留 PGS 9，其中 10 Mbps 窗有字幕实图。两次重叠操作均因 WDA 取控件超时未发送，体验问题和现场听音仍待，设备已释放。 [W10 复核](docs/archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-FOLLOWUP.md)

2026-11-13 T5 的 W1–W10 换源协调行为均有真机证据。W6 在下一集加载中实际触摸旧集进度条和关闭字幕，下一集保持原请求并出画。W10 切轨内部首帧 46.410 秒，随后另一独立降档请求丢字幕。iPhone 13 空环境续播恢复 AC3 2 / PGS 9，实图有字幕，设备已释放。实际听音待现场确认。 [T5 回归结论](docs/archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-READBACK.md)

2026-11-12 18:17 iPhone 18 已通过 USB 保留数据装上最新 T5 签名 Debug `6beee7cb…`。28 项偏好相等，原 DSM 保存配置保留，安装后 App 未启动。 [安装记录](docs/archive/handoffs/2026-11/CODEX-2026-11-12-IPHONE18-T5-INSTALL.md)

2026-11-12 用户确认换集加载期忽略旧一集选轨和跳转。T5 已接线，签名 Debug `6beee7cb…` 装到 iPhone 13 和 iPad。iPad 首窗完成 W8 本地跳转重试及 W6 重复点下一集。iPhone 13 首窗 Jellyfin 401，用户重登后恢复。 [T5](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T5.md)

2026-11-12 T4 复核确认只有一次独立原片试探，系数保持 3.0。 [T4 与 T5 预检](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T4-T5-PREFLIGHT.md)

2026-11-12 iPhone 13 4G 补 V7/V10。《杀死比尔》38.1 Mbps 判定 fits，音轨要求使实际走 12 Mbps HLS，内部首帧 15.897 s。设备文件 S19 命中 10 Mbps 已验证 Jellyfin HLS，内部首帧 4.619 s，实图未确认。Wi-Fi 已复核，自有窗口结束。 [V7/V10](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-V7-V10.md)

2026-11-12 iPhone 13 4G S19 冷续播实图，12 Mbps HLS。新进程恢复 16 样本，33.6 Mbps 分段下界触发原片试探，供给不足后实际降至 10 Mbps，再次续播直接走 HLS。前后 15 秒内部恢复 697 / 784 ms。复算 4 条、0 不符，原 Wi-Fi 已核。 [4G 续测](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-PLAY.md)

2026-11-12 iPhone 13 公网 Jellyfin 已在 4G 重新登录，资源库加载完成，冷启动后同一公网会话再次加载。原 Wi-Fi 已核，13:28 自有资源全部收尾。本次按用户要求止于登录。 [重登记录](docs/archive/handoffs/2026-11/CODEX-2026-11-12-JELLYFIN-PUBLIC-RELOGIN.md)

2026-11-12 iPhone 13 的 4G 公网 Jellyfin 资源库返回 401，App 实见登录失效，未发 S19 续播。原 Wi-Fi 勾选和图标已复核，自有窗口结束。T2 需公网重新登录后继续。 [4G 复核](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-AUTH.md)

2026-11-12 iPad 同签名 Debug 补完 S19 内网 SMB 的普通退出、同进程续播和前后 15 秒。续播起点 22.285 秒，内部恢复 239 / 1,582 ms，三次有实图。Reader 53.26 / 56.32 Mbps，续播 16 KB 尾块排队 104 ms。持续供给卡顿与未配平轨道均留档。08:56 临时索引已撤，设备释放。 [本轮续测](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T3-RESUME.md)

2026-11-12 iPad 已用 WDA 进入 S19 的单影片 SMB 临时索引并出画。Reader 实测 46.4 Mbps，设备文件无背压 HTTP 六窗中位 68.5 Mbps，16 KB 尾部首块排队 192 ms、连接读取 4 ms。临时索引已撤，重试前 4 库和 4 连接相等，文件列表恢复名称升序。续播、跳转和轨道配平待补。已登记 M2TS、ISO 和杜比视界补样建议。 [T3](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T3.md) · [补样](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T3-PREFLIGHT.md)

2026-11-12 用户确认 NAS 恢复。iPhone 13 用同一签名 Debug 在 5G 打开公网 Jellyfin 资源库和 S19 详情，续播准备返回 HTTP 401。跳过原片的判定复算一致，未取得实际 HLS 档位或首帧。原 Wi-Fi 和窗口收尾已核。后续先补 iPad 内网 SMB 读数，T2 余项待公网播放可用。 [续测记录](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-RESUME.md)

2026-11-12 用户报告 NAS 疑似异常重启，播放验证暂停。iPhone 13 公网登录、S19 4/10 Mbps 选路已核，10 Mbps 从头窗 30 秒未出画，原 Wi-Fi 已恢复。iPhone 18 已于 06:38 通过 USB 保留数据装好签名 Debug `8025285b…`，28 项偏好全等，NAS 暂停期间未启动 App。 [T2](docs/archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2.md) · [18 更新](docs/archive/handoffs/2026-11/CODEX-2026-11-12-IPHONE18-LATEST-INSTALL.md)

2026-11-10 17:50 iPhone 13 的旧 Jellyfin 会话读取资源库返回 401。按用户要求用现有 WDA 在 Wi-Fi 下重新登录，已确认资源库实际加载。App 与 WDA 已收尾，设备交回 Claude。

2026-11-10 12:30 iPhone 13 蜂窝复测后，通过现有 WDA 恢复原 Wi-Fi。系统设置连接勾选与状态栏图标均已确认，截图已保存，设备已归还 Claude。

2026-11-10 12:05 iPhone 13 按用户要求用现有 WDA 再次切到蜂窝网络，设置页确认 Wi-Fi 关闭，状态栏显示 4G，已截图并收尾。

2026-11-10 10:22 iPhone 13 蜂窝测试后，已按用户要求通过现有 WDA 恢复原 Wi-Fi。系统设置的连接勾选和状态栏 Wi-Fi 图标均已确认，截图已保存，自有 WDA 已退出。

2026-11-10 08:56 iPhone 13 保持 4G，经用户授权用现有 WDA 登录 Jellyfin 成功，资源库已实际加载并截图。08:57 自有窗口收尾并交回 Claude，待接续蜂窝播放。

2026-11-10 08:35 iPhone 13 按用户要求通过现有 WDA 关闭系统 Wi-Fi，设置画面确认关闭，状态栏实见 4G。Codex 的 WDA 已收尾，设备交回 Claude 开始蜂窝预检；测试完恢复原 Wi-Fi。

2026-11-10 Claude 接续已就绪。iPhone 18 USB 保留数据更新到 `01a6ec56…`，离线前台与全部偏好保留已核。iPad 同包 SMB 起播后缓冲时仍收到约 28 MB 入站载荷，三入口等条件测量未完成，全部测试窗口已释放。 [Claude 接续](docs/archive/handoffs/2026-11/2026-11-10-0645-CODEX-TRANSITION-TO-CLAUDE.md)

2026-11-10 iPhone 13 按用户授权重登 Jellyfin，《护戒使者》原画实际出画、正常退出，冷启动直接恢复登录。iPad 已保留数据更新到同一签名包 `01a6ec56…`，SMB 346.993 秒以 AC3 2 / PGS 9 出画并显示字幕，保留缓冲。临时索引清理，两台自有窗口已关闭。 [本轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-10-IPHONE13-REAUTH-AND-SMB-TRACK.md)

2026-11-10 iPhone 13 原有 Jellyfin 会话用旧、标准认证头分别复测，域名库和内网身份请求均为 401。13 最新签名 Debug `01a6ec56…` 已保留数据安装。iPad `f6b9223f…` 的 S19 Jellyfin 与设备文件同为 346.993 秒、AC3 2 / PGS 9，均实图出画；SMB 有内部首帧，目标字幕未核。临时索引已撤，设备窗口已关闭。 [本轮回归](docs/archive/handoffs/2026-11/CODEX-2026-11-10-JELLYFIN-RECOVERY-HTTP-STATUS.md)

2026-11-09 最新签名 Debug `b9a6e09b…` 已保留数据安装到 iPhone 13 和 A16 iPad。Jellyfin 同账号内网会话恢复规则通过 3 项定向测试，13 的库请求仍是 401。iPad 用现有会话正常播放 S19 并出画；13 用设备文件原画出画，前后 15 秒均记录引擎恢复。22:28:23 两台自有窗口已收尾。 [最新回归](docs/archive/handoffs/2026-11/CODEX-2026-11-09-JELLYFIN-SAME-ACCOUNT-LAN-RECOVERY.md)

2026-11-09 iPhone 13 与 A16 iPad 已保留数据更新到当前签名 Debug `a827696b…`。iPad 在 S19 Jellyfin 原画切 HLS 时确认首段复用有效，但关闭组同样切换成功且略快，开关保持默认关闭。13 的设备文件原画从头出画、前后 15 秒均恢复；Jellyfin 资源库 401，未发出播放请求。两台自有窗口已收尾。 [真机回归](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-CANDIDATE-SEGMENT-DEVICE.md)

2026-11-09 Apple TV 按用户要求暂停。Mac 有匹配的 tvOS SDK 与首选开发镜像，仍无电视开发端点；现有配对和网络保留。 [暂停前记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-APPLE-TV-DEVELOPER-MENU.md)

2026-11-09 默认关闭的 HLS 候选首段复用在模拟器通过七项；同一慢段上游 GET 由 6 降到 1，候选约 2.52 秒对齐，关闭时 12 秒内未解码。未更新真机包。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-CANDIDATE-SEGMENT-RETRY.md)

2026-11-09 本机合成片源已分离原画正文断供、HLS 清单等待和首段等待。原画恢复送数后约 24–32 毫秒退出缓冲；候选首段慢 2.4 秒时约每 2 秒重试，12 秒测试窗未解码；模拟源站只共享首段准备、后段快时，约 2.60 秒解码并对齐。仅模拟器，产品代码与真机包未改。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-RANGE-AND-HLS-TIMING.md)

2026-11-09 iPhone 13 和接回的 A16 iPad 已核同一签名包 `807b3c7e…`。S19 设备文件：13 独立取证确认约 8.04 秒缓冲、随后恢复且触控未断；iPad 冷启动从原书签 382.253 秒续播并实际出画。均已收尾，iPhone 18 已断开，本轮未操作。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-INDEPENDENT-CAPTURE.md)

2026-11-09 iPhone 18 已经 USB 保留数据更新到签名 Debug `807b3c7e…`，正常首页和原域名＋端口的 DSM 会话已核。按用户授权更新了 18 的触控工具。18 的《护戒使者》设备文件原画有实际画面及前后跳转内部恢复，13 同包复测遇缓冲和触控断开，已收尾。iPad 不在本轮范围。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE18-13-S19-USB.md)

2026-11-09 合成 Matroska 已核尾部 Cues 慢读停在定位中，目标 Cluster 慢读则已定位但无帧提交。五窗各正常收尾，正式播放代码未改。A16 iPad 尚未重新接入。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATROSKA-CUES.md)

2026-11-09 合成片源已区分两种起播等待：尾部索引延迟时定位尚未开始，目标正文过慢时定位成功但未接受或提交视频帧；供给较好时均能起播。诊断报告已保留同一会话的未推进退场。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-PLAYER-RANGE.md)

2026-11-09 iPhone 13 的签名包 `807b3c7e…` 用现有 Jellyfin 登录在 App 冷启动后从 1709.641 秒续播《护戒使者》并出画。26.313 秒短断点重开未显示，服务端阈值未核；已收尾。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATCHED-SMB-AND-RANGE.md)

2026-11-09 iPad 的 SMB 在同一临时库内保存 AC3 2 / PGS 9 后，从 346.993 秒实际出画，补齐三入口同起点同轨证据。已收回临时索引。本机 Range 夹具分别模拟短尾段响应延迟和大尾段正文限速。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATCHED-SMB-AND-RANGE.md)

2026-11-09 A16 iPad 签名 Debug `807b3c7e…` 用 S19 的书签数值 346.993 秒定点复测，设备文件、Jellyfin、SMB 均实际出画，未复现设备文件黑屏。设备文件同段尾部交付 0.725 秒，首次黑屏窗约 7.46 秒。SMB 默认轨道与前两路不同。已恢复空环境并收回临时索引。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-S19-FIXED-START.md)

2026-11-09 iPad `fe63a311…` 补完 Jellyfin《护戒使者》内网原流续播、从头和切轨。停止上报和引擎续播均为 350.541 秒，实际出画和中文字幕，AC3/PGS 保留。三入口实际落点尚未配平，离线工具已按同 trace/plan 核引擎起点，145 项播放脚本测试通过。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-S19-JELLYFIN-CONTROLS.md)

2026-11-09 iPad 在签名 Debug `fe63a311…` 用同一部 128.8 GB《护戒使者》核实 Jellyfin、设备文件、SMB 内网原流。SMB 经共享 Reader 验证续播、重播、前后跳转及引擎选轨。设备文件首窗重开约 16 秒仍黑屏缓冲，邻近位置复测实际出画，内部首帧 2.80 秒。下一步固定引擎实际落点并补 Jellyfin 续播和切轨。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-S19-THREE-ENTRY.md)

2026-11-09 iPhone 13 在同一签名包 `fe63a311…` 用既有 13.0 GB MKV 完成 SMB、WebDAV 直连 Reader 出画、前进 15 秒及普通退出，索引逐项未变。三入口配对工具 13 项通过，下一窗核《护戒使者》同落点与轨道。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-READER-SMB-WEBDAV.md)

2026-11-09 iOS 网络存储 Reader 已接入共享原流代理，正常路径去掉第二个本地监听器，注册失败才启动旧桥接。定向模拟器 14 通过；NetworkMedia 30 通过、6 SMB 夹具跳过。签名 Debug `fe63a311…` 已保留数据安装 iPad 和 13；iPad 同一 13.0 GB 内网 MKV 的 SMB、FTP 都走直接 Reader，出画、前进 15 秒及普通退出成立；13 用原会话完成 Jellyfin 原流短播。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-NETWORK-READER-PROXY.md)

2026-11-09 原流首个 Range 响应接手：本机 20 项定向通过。签名 Debug `a444e8d9…` 保留数据更新 iPad 和 13，两机安装偏好相同。iPad 同包设备文件片头对照，实验交付 14,147 字节、首段只发一次，内部首帧 906/649 ms；13 的 Jellyfin 无 ETag，实验交付 34,441 字节，内部首帧 952/785 ms。每台仅一对，默认复核与收尾已完成。正常启动仍关闭，Reader 去桥接和续播、跳转、音字幕性能对照待续。 [当轮记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-ORIGINAL-RESPONSE-HANDOFF.md)

2026-11-09 10:02 两机原流核对。Jellyfin 的 206 无 ETag，设备文件有强 ETag。iPad 同包并行预读对照未命中，首个请求仍从 0 开始，内部首帧 645/712 ms。临时源码撤回，iPad 保留数据恢复正常包 `e6408d71…` 并启动，13 已是同一正常包。下一步验证预读与正式播放共用首个 Range 响应。 [iPad 对照](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-ASYNC-PREFIX-AB.md) [两机真实响应核对](docs/archive/handoffs/2026-11/CODEX-2026-11-09-ORIGINAL-VALIDATOR-AUDIT.md)。

2026-11-09 08:36 13 签名包 `542e9d2f…` 的 S19 内网默认原流窗未自然降档。独立 Debug 12 Mbps HLS 窗完成 AC3 和字幕关闭替换，确认第二候选采用首窗渲染准备耗时加 150 ms，内部对齐 11.60 / 7.70 秒，两窗条件有差异。普通退出与自有设备窗口收尾已核。自然降档配对、显示/听音及预读待续。 [回归记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-HLS-REPLACEMENT-REGRESSION.md)

2026-11-09 08:20 用户授权在 13 断开旧 Jellyfin 会话并重新登录。旧 401 已复现，新登录及不同进程冷启动均成功加载资源库，仍为签名包 `542e9d2f…`。设备窗口已收尾。[验证记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-JELLYFIN-RESUME.md)

2026-11-09 最新签名 Debug `542e9d2f…` 已保留数据装 13 和 iPad。iPad 冷启动恢复 Jellyfin 并完成 S19 续播、从头播放、跳转及选轨。13 已恢复正确账号，Jellyfin 仍返回 401，设备文件同片续播和跳转成立。HLS 候选计时已拆分，实际替换回归待补。两机窗口收尾。18 07:22 已 USB 更新至 `cef05828…`，用户带去单位。[真机回归](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-JELLYFIN-RESUME.md)

2026-11-09 继续视频优化：三入口共同准备已接真实设备网络路径，五项定向测试通过。正常签名 Debug `892228ff…` 已保留数据安装13/Pad，安装全偏好同。Pad以同一128.8GB S19实际核Jellyfin、设备文件、SMB三入口的Wi-Fi共享原流路线，覆盖起播/续播/从头/跳转/轨道选择；13文件入口补验，JF401待用户重登。仍有缓冲，内部首帧不当显示首帧，不作入口速度排名。临时索引恢复、所有自有窗口已停。下一步按同落点/音字幕取证，推进公共ByteReader和可消费预读，再补外网/弱蜂窝。[本批记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-SHARED-NETWORK-PLAYBACK.md)

2026-11-09 用户确认 iPhone 18 已解锁后复查。无线身份与配对认证通过，IPv4/IPv6 的 App 备份仍断开，安装查询服务也断开。尚未上传或发送安装。下一步定位无线 App 服务断开原因。[解锁后记录](docs/archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE18-UNLOCKED-WIFI-UPDATE.md)

2026-11-08 S19 中段跳转。13 同落点 A/B 将缓冲目标从 1 秒提高到 2.5 秒，首次恢复由 5.606 秒延至 9.715 秒，两轮均再次缓冲，候选已撤回并覆盖回正式签名包。iPad 正式包另一个中段落点约 2.714 秒恢复，后续约 27 秒未再次缓冲。iPhone 18 无线身份和签名已核，备份连接断开，安装尚未发出。下一轮优先查上游正文供给。[大幅跳转对照](docs/archive/handoffs/2026-11/CODEX-2026-11-08-S19-DEEP-SEEK-AB.md)

2026-11-08 S19 内网接续。A16 iPad 已保留数据覆盖为与 13 相同的签名 Debug `3ac44312…`。《护戒使者》128.8 GB 在 Pad 的设备文件、SMB、FTP 均实际原流出画和正常退出。设备文件开头 200 秒，Pad 记录 0 次缓冲，13 历史窗 1 次。Pad 中段定位恢复 3.052 秒，SMB 短窗 0 次缓冲，FTP 短窗 1 次。临时索引清理完成。NAS 同窗负载、实际 HDR/音频输出及 Pad 十分钟稳定性仍待。见[iPad 对照](docs/archive/handoffs/2026-11/CODEX-2026-11-08-S19-IPAD-LAN-COMPARISON.md)及[13 十分钟窗口](docs/archive/handoffs/2026-11/CODEX-2026-11-08-LORD-OF-THE-RINGS-PLAYBACK.md)。

2026-11-08 共享代理第一步已接入，最终6项隔离测试通过，签名正常Debug包 `97b35832…` 已装13。LAN FTP《赌侠》实际出画、206与桥接交付标签齐、前进15秒恢复约19.35秒。普通退出仍待，原生已停本窗。A16 iPad未在USB清单出现，尚未装该包，当前仍为上批bb4d。见[阶段记录](docs/archive/handoffs/2026-11/CODEX-2026-11-08-NETWORK-SOURCES-SHARED-PROXY-PHASE1.md)。

13 用户重新登录后，Jellyfin 资源库、搜索、详情及短时原流画面已在 bb4d 确认。2026-11-08 用户另确认了当前 Jellyfin 用户名，安装交接已记录本机私有备忘位置。

2026-11-08 Apple TV tvOS 27.2。22:45 PIN 认证成功，Device Hub 仍显示开发隧道断开。AirPlay 和 RemotePairing 在 IPv4/IPv6 可达，CoreDevice 和原生服务仍找不到可用开发目标。16:18 的配对前拒连和更早的隧道 1005 为历史分支。[22:45 现场](docs/archive/handoffs/2026-11/CODEX-2026-11-08-APPLE-TV-2245-PAIRING.md)。

此前 97b3 真机结果对应 main/4de732dd 加当时未提交改动。NetworkMedia 350 项中 344 通过、6 跳过，文档链接通过；静态预检仍有失败项。第二步公共 ByteReader 与可消费预读仍待，《指环王》本轮同样观测到预读 0 字节。补 iPad、SMB/WebDAV、真实帧时间、声音字幕及长时，30 项/114 格状态保持。
