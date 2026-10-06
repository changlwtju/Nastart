# 2026-09-29 跨账号远程接手卡

给从单位使用另一 ChatGPT 账号、经 Remote 控制家中 MacBook 的新会话。先读 [当前完整交接](CURRENT-PLAYBACK-HANDOFF.md)，本卡只列 07:09 的现场和首批动作。下方 HEAD/工作区状态是推送前快照；接手请以 `git rev-parse HEAD`、`git status --short` 和设备现场为准。账号聊天记录不作为工程接续来源；不要 reset/clean/覆盖未知文件。

## Remote 前提

- OpenAI 官方 Remote 要求 iPhone 与家中 Mac 桌面端登录**同一 ChatGPT 账号和工作区**。如果 iPhone 18 切到账号 B、Mac 仍是账号 A，B 的 Remote 不会自动看到这台 Mac。家中 Mac 需登录 B，在桌面端 **Settings → Connections → Control this Mac or PC** 启用 Remote，并用 iPhone 18 上的 B 扫码配对；切账号后可能需要重新打开 Remote Control。Mac 要供电、联网、保持唤醒。此跨账号配对**尚未由本会话实测**，不能把本文件当作连通证明。官方说明：https://learn.chatgpt.com/docs/remote-connections 。
- 如果人已经离家且 B 看不到家中 Mac，需要已有的独立远程桌面通道才能在 Mac 上切换账号/完成配对；不能只靠 B 手机上的对话远程更改 Mac 的登录账号。不要公开暴露 Codex app-server 端口或复制认证缓存。
- 在 B 的 Remote 中选择家中 Mac，打开本机项目 `/Users/lagransun/workspace/Nastart` 并启动**新会话**。即使有聊天列表，也以本地文件和重新核实的设备/构建状态为准。

## 07:08 左右最后核实的现场

- HEAD `a5022d25409f1537f4441142863d3d26801d0c39`；源码、KSPlayer、脚本和文档存在大量既有未提交差异。`git diff --check` 已通过。请先跑 `git status --short`，勿清理工作区。
- 07:08 时两机仍由 `idevice_id -l` 检出：iPhone 13 `00008110-001E543122E0401E`，iPhone 18 `00008160-001468D401A0000A`。**07:09 再查时 iPhone 18 已断开，新增一台 iPad `00008030-001168403C43C02E`（iPad12,1 / iPadOS 18.3.1）与 iPhone 13 同时 USB 接入。**这台 iPad 尚未安装/启动 Nastart，也未准备 WDA；不要记为已验证设备。用户会带 iPhone 18 去单位，家中留下仅 Wi-Fi 的 iPhone 13。接手时重新核实 USB；**不要把 iPhone 13 当蜂窝测试机**。iPhone 18 的 WDA XCTest 与 8104 转发已停止；iPhone 13 的 WDA 本机 8102 `/status` 为 `ready=true`，Nastart PID `45856`，WDA 报 `env={}`。PID/会话 ID 会变，不要直接沿用。
- 两机已安装同一个最终签名 Debug 包，已正常启动且未带测试限速变量。持久副本：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-remote-handoff/Nastart.app`，其 `Nastart.debug.dylib` SHA-256 `46df855867b2cc37d25309ae4092eddc4d15cf911d80aceeebdc2dc7158ccb26`。标准 workspace Debug iphoneos 构建成功。iPhone 13 安装需使用 `ios-deploy`；CoreDevice 查不到 iOS 16 设备不等于 USB 离线。
- Jellyfin 公共接口最后返回 HTTP 200。DSM 在 iPhone 18 新进程里曾暂时显示“未连接”，诊断显示后续 Nastart/FileStation 登录及资源快照成功，但登录需要约 20–30 秒；不要凭单屏判断 NAS 故障。用户报告过 NAS/Container Manager 在大文件限速测试时重启，原因未由 NAS 系统日志确定。

## 播放结果和边界

**12:27 本轮补充：** 最新正常 Debug 候选为 `f08bfde1c3f3f9eaa811bb7eb7f4f43b1e31a32c31589b7458b4e17402c11bd2`，持久副本 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-iphone13-continuous/Nastart.app`；已保留数据安装两机，正常无测试变量启动。旧 `37b0…` S01 十分钟持续基线失败（247.710 秒停住），自动 HLS 候选解码后因提前量 11/15 秒未对齐；新候选修正缓冲时提前量，实际解码 XCTest 通过；12:40 最新包 S01 十分钟原画单轮完成、卡顿/丢帧计数 0且已退出，没有触发自动回退，不能据此宣称真实故障恢复或初始停滞根因已解决。`4cdd…` 取消候选双入口原画呈现前有效取消通过；iPad 四接口 proxy=false 仅表示这些 HTTP 请求没有 HTTP 代理，VPN 隧道未排除。测试工具首次启动/随后收尾挂起有采样；实际断言与工具完成分开记录。全部未提交修改保留，禁止大电影限速转码，后续以 [当前完整交接](CURRENT-PLAYBACK-HANDOFF.md) 为准。

**09:52 后续调试：** 最新正常候选 dylib SHA-256 `37b0fc03e608700b0a2bbe1734e7f4690bbe28b35a5cc7ce5b321e7826656f50`，持久路径 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-iphone13-next/Nastart.app`，已保留数据安装两机。修正 Jellyfin 错误状态推断，以及退出重开丢音字幕偏好；iPhone 13 S01 热重开、冷续播、从头播放均有画面和国语/字幕关闭选中状态，声音尚未人工验收。iPad 原生网络专项实际 1 项通过，DSM/Jellyfin LAN/公网四接口均 HTTP 200 / 有效 JSON，新进程仍无已保存 DSM 凭据；没有 VPN A/B，不能排除间歇代理问题。iPad UI WDA 仍自动化模式初始化超时，需继续补保存登录与 UI 环境。以 [最新交接](CURRENT-PLAYBACK-HANDOFF.md) / [iPad 专项](2026-09-29-IPAD-ENVIRONMENT.md) 为准，下面 `46df…` 是首轮旧基线。

**07:55 白天接手补充：** USB 为 iPhone 13 与同 UDID 的 iPad，iPhone 18 不在；iPad 实际已存在 Nastart/WDA 安装，但包身份、WDA 和播放仍未验收。iPhone 13 WDA ready，无测试变量，已用上述 `46df…` 持久包保留数据覆盖安装并正常启动。S01 两入口各三次退出/热重开，暂停退出及两入口冷启动续播已补；准备中取消未捕获有效窗口、短片头 Jellyfin 续播规则与一次上报 -1017 待查。全部播放已退出，正常 App PID `46268`，公网/局域网 Jellyfin 公共接口 HTTP 200，NAS CPU 44% / RAM 19% / 磁盘 92%。HEAD 被本任务之外的 07:26:57 提交推进至 `9a9941c`，本轮只改三份记录，未提交/清理源码。最新逐项证据及下一步以 [当前完整交接的白天回归节](CURRENT-PLAYBACK-HANDOFF.md) 为准。

- 目标：尽量原画和高画质，同时保证流畅；弱网自动降到符合送达速率的清晰度，尽量让用户感受不到换流。手动清晰度 UI 暂缓，内部接口保留；播放中自动升档**尚未实现**。
- iPhone 18 蜂窝下，Apple 预编码 HLS 静态素材通过 App 内 Debug 限速从约 8 Mbps 档降到约 1.3 Mbps 档，实际送达约 2.2 Mbps。Jellyfin 入口旧流交接时缓冲曾仅约 0.33 秒；设备文件入口从 26 GB 文件详情的**独立测试按钮**进入，旧流交接时约 2.82 秒，候选约 6.96 秒。候选完成解码/时钟对齐，交接附近诊断未记录缓冲空或播放器卡顿。尚缺人眼、声音、实际电影和最终包的真机复核，**不能宣称无感体验已经验收**。
- 一次自动化在测试变量丢失后误点普通“从头播放”，短暂开启真实文件的 Jellyfin HLS 转码；发现后立即结束。现两个入口都用仅在 `NASTART_TEST_STATIC_HLS=1` 时出现的独立 Debug 按钮“静态 HLS 弱网测试”；普通播放按钮不再拦截为夹具。使用夹具前必须在 UI 树看到专用按钮，开播后确认标题 `Static HLS fixture`，否则立即停止。不要直接对《指环王》或《碟中谍》做受控限速转码；它们约 55–129 GB、60–82 Mbps，之前 NAS 有过失联。
- 设备文件夹具的 `.dsmFile` 时间轴诊断曾重复计算偏移；最终包已将夹具偏移固定为 0，构建/安装/正常启动通过。因 DSM 登录未就绪，**该最终修正尚未真机视频复核**。准备流退出/取消时注销代理并请求 Jellyfin `stopEncodingProcess`，3 条生命周期定向测试通过。

## B 账号接手后先做

1. 只读核对 `git status --short`、iPhone 13 USB/WDA/App、NAS/Jellyfin 连通和实际构建哈希；iPhone 18 是否还接在 Mac 上，以现场为准。不要因本卡 PID/状态直接推定当前状态。
2. 以 iPhone 13 家中 Wi-Fi 先做低负载 S01《哈尔的移动城堡》双入口退出回详情、准备中取消、重开及断点回归；先单路 30 秒，再按 [远程流程](../development/remote-playback-routine.md)逐步扩展。若服务 502、NAS 资源异常或重启，停止新增视频请求。
3. 如需补自动降档，优先用**独立静态 HLS 按钮**与仅 App 进程内的限速；先确认按钮/标题，测试后以无测试变量命令重启 App。iPhone 13 的代理限速只验证客户端流程，不能代表真实蜂窝。最终时间轴修正的真机复核留为待办；大影片真实转码待 NAS 稳定后单路进行。
4. 更新 [唯一任务总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md) 的 PX-03 及 [当前完整交接](CURRENT-PLAYBACK-HANDOFF.md)。证据需区分构建、播放器日志、屏幕画面、人耳音频及 NAS 资源，不把其中一种代替另一种。

持久证据目录：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-29-remote-handoff/`，内有最终包、构建/定向测试日志及两轮诊断 plist。plist 可能含账号/地址信息，不要上传或提交仓库。详细 trace、旧结果与局限见 [iPhone 18 蜂窝记录](2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md)。

## 可直接发给 B 账号的新会话

> 我正在单位，通过另一个 ChatGPT 账号的 Remote 控制家中 MacBook。请打开 `/Users/lagransun/workspace/Nastart`，先读 `docs/handoffs/2026-09-29-OTHER-ACCOUNT-REMOTE.md` 和 `docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md`，再核实工作区、iPhone 13 USB/WDA、最终安装包和 NAS/Jellyfin。保留所有未提交修改；不要重跑大电影限速转码。按交接卡的低负载顺序继续播放调试，真实完成一项就更新总账与交接文件。iPhone 18 已随我带走，iPhone 13 只能用家中 Wi-Fi；07:09 新接入一台未验收的 iPad，也请先只读核实。
