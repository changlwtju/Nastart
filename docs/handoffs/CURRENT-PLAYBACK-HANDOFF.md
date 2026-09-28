# 当前播放任务接续入口

跨账号、白天在单位接手时先读 [2026-09-29 跨账号远程接手卡](2026-09-29-OTHER-ACCOUNT-REMOTE.md)。其中的 07:09 现场与最终包信息晚于本文件下方较早的历史检查点；其 HEAD/工作区描述是推送前快照，接手须重新执行 `git rev-parse HEAD`、`git status --short`。任何 PID、USB 和服务状态也须现场重验。该卡写明 Remote 同账号前提与可直接发给新账号的指令。

更新时间：2026-09-29 早。面向同一台 Mac 上的新会话/另一个用户本人持有的账号；本文件传递工程事实，不负责复制账号会话历史或登录凭据。

## 2026-09-29 早晨最新检查点（优先读）

- 用户已把 iPhone 18 切至蜂窝网络，约 07:00 会带走，iPhone 13 留家中 Wi-Fi。两机 USB 接入本机；iPhone 18 UDID `00008160-001468D401A0000A`，iPhone 13 UDID `00008110-001E543122E0401E`。HEAD 仍为 `a5022d25409f1537f4441142863d3d26801d0c39`，保留现有大量未提交修改。
- Jellyfin 搜索中《碟中谍 2》约 54.92 GB / 64 Mbps、《碟中谍 3》约 54.01 GB / 62.7 Mbps，均为 4K H.265 HDR 高码率片源；它们不比《指环王》更适合在 NAS 曾重启的现场做多路弱网转码。因此本轮没有请求这些影片的视频流。Jellyfin 仅用于进入详情 UI，弱网播放走独立的预编码 Apple HLS 素材。
- 新增 `#if DEBUG` 且仅显式设置 `NASTART_TEST_STATIC_HLS=1` 时启用的静态 HLS 测试入口；高档约 8 Mbps、低档约 1.3 Mbps。Debug 媒体代理限速也仅在带测试环境变量的 Nastart 进程内生效，不改 iPhone 的蜂窝、Wi-Fi 或 VPN 系统设置，不启动 NAS 编码器。Apple 测试素材地址及实测见 [蜂窝记录](2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md)。
- iPhone 18 4G 实测：高档首帧时钟约 6.25 秒；5 秒后开始 2.4 Mbps 限速，实际样本约 2.23 Mbps；播放时钟约 7 秒即请求自动降档。候选于 22:29:47 UTC 解码、22:29:51 UTC 时钟对齐并接手，接手时旧流缓冲约 0.33 秒，新流缓冲约 6.5 秒；新流首帧事件距交接约 86 ms。两路在首帧后的采样均 `accessLogStalls=0`、`bufferEmpty=no`；新流继续至约 62.5 秒、缓冲约 40.6 秒。原始诊断 `/tmp/nastart-v9-followup.plist`，trace `50C76D01`→`10BBEF9D`。这证明可控降速时完成自动交接；没有真人连续观看或外部摄像机证据，不能宣称无感验收完成。
- 测试进程已用不带环境变量的 `devicectl device process launch --terminate-existing` 重启，WDA 核对 iPhone 18 Nastart PID `13339`、`env={}`；Jellyfin 公共接口 HTTP 200。系统网络设置本轮未动。设备文件匹配 Jellyfin HLS 的准备流现在注册清理器，退出/放弃候选时会注销代理并调用 Jellyfin `stopEncodingProcess`；相关 3 条定向测试通过。静态 HLS 的 v9 签名 Debug 构建 `/tmp/nastart-static-hls-v9-build.log` 成功。另有收尾修复的最终编译/两机安装状态见本节后续追加记录；接手须重新核实。
- iPhone 18 WDA 当前本机 `8104→8100`，XCTest/转发 PID 可能随时变化；iPhone 13 WDA `8102→8100`。iPhone 13 已安装清理修复版并启动，最终静态测试版是否同步安装见后续记录。继续调试时优先避免再次向 NAS 发起大影片限速转码；真实 Jellyfin 大片场景仍待 NAS 稳定后单路验证。
- 06:34 收尾：设备文件 HLS 准备响应即使字段无效，也会调用 `stopEncodingProcess` 关闭已创建的服务器会话。最终签名 Debug 包 `/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app` 的 `Nastart.debug.dylib` SHA-256 为 `7d7690a9f788fcc19677a747ccb75858d4aa79dd77d275e228d656e48617e473`；标准 workspace 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-sept29-final-build.log`。该包已安装两机（安装日志 `/tmp/nastart-sept29-final-iphone18-install.log`、`/tmp/nastart-sept29-final-iphone13-install.log`），并以无测试变量正常启动；WDA 核对 iPhone 18 PID `13366`、iPhone 13 PID `45709`，两者 `env={}`。`git diff --check` 通过。静态 HLS 自动交接实测发生在最终编译前的 v9 包；最终源码只多了一处服务器会话清理修复，没有重跑同一真机播放。
- 收尾又停止了 iPhone 18 的 WDA XCTest 与本机 8104 转发，App PID `13366` 仍存活；iPhone 13 的 8102 WDA `/status` 仍为 `ready=true`，方便留家远程调试。Jellyfin 公共接口 HTTP 200。上述“iPhone 18 WDA 当前 8104”仅描述停止前现场；下一会话须重新启动 WDA 才能控制它。

## 2026-09-29 06:54 设备文件安全测试接续

- 继续补设备文件入口的弱网交接。最初把静态 HLS 挂在常规“从头播放”分支；WDA 创建会话后可能重新启动 App，测试环境变量未生效，第一次点播 26 GB《Spider-Man 2》文件时实际进入了约 1.5 Mbps 的 Jellyfin 匹配转码，trace `87223463`。发现播放器显示真实影片标题/时长后立即替换 App 进程停止播放。Jellyfin 公共接口持续 HTTP 200；未取得 NAS 系统日志，不能据此判定 NAS 是否受到额外压力。后续自动化不得以普通播放按钮推定测试隔离已经生效。
- 已将设备文件静态测试改成 **只有 `NASTART_TEST_STATIC_HLS=1` 时才出现的独立 Debug 按钮“静态 HLS 弱网测试”**，常规播放不再被测试代码拦截。必须先在 UI 树确认该按钮出现，再点击；播放页标题须为 `Static HLS fixture`。26 GB 文件详情上按此流程实测，视频请求为 Apple 静态 HLS；没有请求该文件视频流。iPhone 18 4G 下高档 trace `86961AEB` 首帧约 4.89 秒，5 秒后限速到 2.4 Mbps，实测约 2.22 Mbps；约 13.5 秒播放位置发起降档，低档 trace `258309A5` 解码、对齐、接手。旧流交接前约 2.82 秒缓冲，候选约 6.96 秒，新流首帧事件约 54 ms；交接附近两路样本 `accessLogStalls=0`、`bufferEmpty=no`。原始诊断 `/tmp/nastart-sept29-filefixture-t20.plist`。缺真人观看/声音证据，不能定为无感验收。
- 此轮发现 Debug 素材给 `.dsmFile` 候选重复附加时间轴偏移，使 `firstFramePositionSeconds` 报约 37 秒而实际播放器时钟约 24 秒。已将静态素材时间轴偏移固定为 0；最终标准 workspace Debug 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-sept29-filefixture-final-build.log`。最终包 `Nastart.debug.dylib` SHA-256 `96fd636d74080854a11085871f8d0cd0ea44bc959970afdd25b71a034ab58874` 已安装两机，日志 `/tmp/nastart-sept29-filefixture-final-iphone{18,13}-install.log`。时间轴修正后试图复核，App 文件页提示“DSM 当前未连接”，故未继续请求视频；该修正尚未真机重验。
- 已结束所有 iPhone 18 带限速变量的进程，用无变量命令正常启动；WDA 核对 iPhone 18 PID `13536`、iPhone 13 PID `45837`，均 `env={}`。iPhone 18 WDA XCTest 与 8104 转发已停止，iPhone 13 的 8102 WDA 保留。Jellyfin 公共接口 HTTP 200，`git diff --check` 通过。系统 Wi-Fi、蜂窝、VPN 设置均未由本轮改变。下一步先核对 DSM 会话/服务是否稳定，再用独立按钮短测最终包的时间轴和交接；真实大片与设备文件匹配转码仍需 NAS 稳定后单路验证。
- 06:57 最终安全收尾：Jellyfin 详情页也改为独立的 Debug“静态 HLS 弱网测试”按钮，普通播放按钮不再受测试变量拦截。最终签名 Debug 包 `Nastart.debug.dylib` SHA-256 `46df855867b2cc37d25309ae4092eddc4d15cf911d80aceeebdc2dc7158ccb26`，标准 workspace 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-sept29-safe-buttons-build.log`，已安装两机（`/tmp/nastart-sept29-safe-buttons-iphone{18,13}-install.log`）。iPhone 18 用无环境变量命令正常启动，PID `13557`；iPhone 13 WDA 正常启动 PID `45856`、`env={}`。此最终按钮版本只完成构建/安装/启动，未重复视频短测；上段设备文件自动交接实测属于按钮已独立、时间轴偏移尚未修正的前一包。
- 06:58 只读诊断复核：DSM 文件页的“未连接”发生在新进程恢复登录期间；该设备诊断随后记录 Nastart/FileStation 登录成功和资源快照完成，但登录历时约 20–30 秒。不能据那一屏判断 NAS 已离线，也未在登录完成后重试视频。诊断副本 `/tmp/nastart-sept29-dsm-final.plist` 含连接信息，仅留本机。Jellyfin 公共接口依旧 HTTP 200。

## 先读与当前目标

项目：`/Users/lagransun/workspace/Nastart`。

1. [本轮播放就绪度审计](2026-09-28-PLAYBACK-READINESS-AUDIT.md)：回答功能成熟度、开口项和矩阵准入。
2. [常态远程流程](../development/remote-playback-routine.md)、[分层回归](../development/playback-development-workflow.md)：白天 iPhone 13/后续 iPad，晚上用户及 iPhone 18；按修改影响选回归，不每次重跑 76 单元。
3. [唯一任务总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)、[19×4 矩阵](PLAYBACK-FUNCTION-MATRIX.md)、[ADR 0002](../adr/0002-single-playback-optimization-mainline.md)。手动清晰度入口暂缓，不删除、不记通过。Greenfield 唯一优化主线，旧实现保留回退，暂未迁移 Release。

用户最新要求是完成源码审计及双账号远程接续方案；不要把审计表里每个缺口都直接当成本轮全面开发任务。

## 工作区与安装状态

- HEAD `a5022d25409f1537f4441142863d3d26801d0c39`，有大量既有未提交源码、KSPlayer、脚本与文档修改。接手先读 git status/diff；不要 reset、清理或覆盖未知修改。不要只用 commit/0.1.0(1) 判断包是否最新。
- 前序已修复 `AppTabRootView.swift`：iPhone 不再随 horizontalSizeClass 切换根导航。实源码模拟器反例通过；修复包安装 iPhone 13 并确认启动，**真实视频退出尚未复测**。
- 最近有安装记录的包：`/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app`。安装日志 `/tmp/nastart-navigation-return-iphone13-install.log`。不能由此保证当前设备仍是该包，重新核实。
- iPhone 13：UDID `00008110-001E543122E0401E`，上次系统 iOS 16.3.1。已验证 USB/libimobiledevice/ios-deploy；CoreDevice 不支持不等于离线。WDA 常用本机 8102→设备 8100，接手必须检查服务是否运行。
- iPhone 18：交接时尚未核实 USB 接入或安装修复包；本文件下方 20:30 检查点已补实测。iPad 后续接入。
- NAS 先前有重启/资源压力记录；默认单路，先正常短时再长时。不要更改承担远程连接的路由/VPN 来造弱网。

## 最新验证与优先事项

- 前次审计的 generic iOS Release 编译失败，`DevicesView.swift:1215` 引用 DEBUG 专有标识；本文件下方检查点已重跑并通过标准 workspace Release 构建。
- 2026-09-28 晚模拟器测试日志报告 109 项、0 失败，但 xcodebuild 在测试结束后收尾卡住数分钟，采样保留后终止；没有正常完成标记，不算整套工具运行通过。日志 `/tmp/nastart-audit-tests-resumed.log` 与 `nastart-audit-xcodebuild-hang.txt` 已留本机证据目录；下午中断的那次同样不能算整套通过。后续需定位测试工具收尾问题，不能把它当作某个测试断言失败。
- 下一开发工作包：双入口退出回详情与重开；准备中离开/连续选片/旧响应晚到；S01/S03 稳定性与断点。静态风险需复现或用证据排除，不直接宣称已发生。
- 随后 S01/S03/S08 代表片基线，再补弱网候选对齐交接；完整矩阵前规范字段、构建身份及证据索引。HDR+PiP 字幕、自动连播、高级字幕等缺口见审计。
- 不把日志进度增长当实际画面流畅/声音可听/HDR 输出证明。缺人工和设备项目保留待验。

原始日志与源码差异指纹等本机材料：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-28-readiness/`。临时工具的会话 ID、进程 ID 在新会话中不能假定有效。

## 2026-09-28 20:30 接续检查点

- HEAD 仍为 `a5022d25409f1537f4441142863d3d26801d0c39`；既有未提交修改保留。本次仅更新本交接文件，未修改播放源码。两机均由 `idevice_id -l` 识别：iPhone 13 `00008110-001E543122E0401E`（iOS 16.3.1），iPhone 18 Pro Max `00008160-001468D401A0000A`（iOS 27）。Jellyfin 公共信息接口测试前后 HTTP 200。
- 两机已安装同一 Debug 包：`/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app`，其 `Nastart.debug.dylib` SHA-256 为 `fe6b5acd0fe3a5dff0e4774a9689b8c2555bbe8458d8c221c12de87cdc68510d`。iPhone 18 安装日志 `/tmp/nastart-preparation-iphone18-install.log`；iPhone 13 本次 USB 安装日志 `/tmp/nastart-handoff-iphone13-install.log`。iPhone 13 需用 `ios-deploy` 安装，当前 CoreDevice 不能按其 UDID 查到 iOS 16 设备。
- iPhone 18 真机 S01《哈尔的移动城堡》设备文件入口：原有播放画面退出回同一文件预览，点“继续观看”后再次显示真实视频画面。Jellyfin 入口：从搜索结果详情进入新架构，看到真实首屏画面，点“完成”回同一 Jellyfin 详情，点“继续观看”再次看到真实画面，再次退出仍回详情。这只覆盖短路径；未据此证明声音、长时流畅、断点精度、自动降档或完整矩阵通过。截图仅在本机 `/tmp/nastart-handoff-iphone18-jellyfin-s01-{first,reopen}.png` 等处，不纳入仓库。
- Jellyfin S01 后续又完成一次短进出导航（共两次）；第三次尚未开始时微信通知使 WDA 前台快照短暂切为 SpringBoard，App 进程仍在，通知消退后又显示同一详情页。未将自动化中断记作 App 故障，也未计为第三次通过。
- iPhone 18 在先前设备文件重开后，创建新的 WDA 会话时 Nastart 进程退出；未取到对应崩溃报告，原因不明，不能归因于 App。其后普通启动及上述 Jellyfin 往返均成功。测试已退出播放器，没有设置限速环境或改路由/VPN。
- 当前 `PlaybackPreparation` 通过请求 UUID 和取消标识拒绝离开详情后的晚响应及旧请求覆盖；`PlaybackNextCoreTests.swift` 中两条确定性测试本次定向重跑 `2 tests, 0 failures`，xcodebuild 正常以 `** TEST SUCCEEDED **` 结束，日志 `/tmp/nastart-handoff-preparation-tests.log`。真机“准备中离开/连续选片”仍未完成。
- generic iOS Release：直接用 `.xcodeproj` 编译已越过先前 `DevicesView.swift:1215` 错误，但因绕开 Pods workspace 在链接时缺 `MobileVLCKit`。改用标准 `.xcworkspace` 后 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-handoff-release-workspace-build.log`。这只证明当前源码可编译，不代表 Release 真机功能已验。
- iPhone 13 安装后用 `ios-deploy --justlaunch` 启动出现一次 `SIGTRAP` 报告 `/tmp/nastart-handoff-iphone13-crashes/Nastart-2026-09-28-202102.ips`；报告没有可用线程栈，且该路径紧接调试器 `safequit`。随后通过 WDA 常规启动和一次 terminate→launch，Nastart 均显示启动台并保持进程，未生成更新的崩溃报告。不能把该 SIGTRAP 单独认定为普通用户启动闪退；后续仍需无调试器冷启动复测。
- iPhone 13 在同包、家中 Wi-Fi 上又完成 Jellyfin S01 一次新架构播放：屏幕见实际影片画面，点“完成”回《哈尔的移动城堡》详情，“继续观看”出现，Nastart PID `42144` 在退出后仍在。证据截图 `/tmp/nastart-handoff-iphone13-jellyfin-s01-play.png` 与 `...-after-exit.png` 仅留本机；尚未测声音、长时稳定、断点精度或 iPhone 13 设备文件入口。
- 当前 iPhone 13 WDA `8102→8100`、iPhone 18 WDA `8104→8100` 均曾返回 `ready=true`；接手重新核对，不沿用会话 ID。iPhone 13 启动截图 `/tmp/nastart-handoff-iphone13-startup.png`。后续先补 S01/S03 定向稳定性与准备中取消，再做代表片持续播放及弱网自适应；NAS 有过重启记录，保持单路、先短后长。
- 20:34 收尾核对：Jellyfin HTTP 200（约 0.10 秒）；iPhone 13 Nastart PID `42144`、iPhone 18 Nastart PID `10637` 均在，播放器已退出；iPhone 13 无 20:21 后的新 Nastart 崩溃报告。两机截图状态栏均显示 Wi-Fi 图标，本轮不能按蜂窝弱网结果解释。未设置限速，也无网络环境需要恢复。

## 2026-09-28 21:05 蜂窝自动降档检查点

- iPhone 13 在家中 Wi-Fi 上完成设备文件 S01 一次播放、退出、继续观看重开，实际画面可见且进程存活；证据仅在本机 `/tmp/nastart-next-iphone13-file-s01-*.png`。iPhone 18 已切蜂窝 4G，本次 Debug 进程限速 S19 由 4 Mbps HLS 降至约 2.2 Mbps 传输能力，自动请求 1.5 Mbps 候选，第二次候选解码与时钟对齐后实际接手。
- 接手时新播放器缓冲只剩 0.07 秒并停在 2:29，**自动降档尚未通过流畅验收**。源码修复见 `GreenfieldVideoPlayerView.swift`：预热期为追时钟而关闭的 AVPlayer 自动等待，在接手时恢复；预热流接手后保留 3 秒前向缓冲目标，并记录交接时播放意图与缓冲。标准 workspace Debug iphoneos 构建 `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-adaptive-handoff-build.log`；签名包已安装两机。iPhone 18 用无测试变量启动，WDA 显示 PID 11028、`env={}`；iPhone 13 经 WDA 常规激活，PID 42436、`env={}`，安装日志 `/tmp/nastart-adaptive-handoff-iphone13-install.log`。真机降档复验未开始。完整诊断见 [蜂窝测试记录](2026-09-27-IPHONE18-CELLULAR-ADAPTIVE.md)。
- 此轮后 NAS 的 DSM/Jellyfin 局域网与公网入口失联，Mac 路由器和外网仍可用；原因未知，停止真机视频请求。约 21:06 DSM 局域网已恢复 HTTP 200，Jellyfin 局域网连接仍被重置、公网仍返回 502。iPhone 18 限速进程结束，系统网络配置未更改。Jellyfin 恢复后先确认服务与负载，再单路短时复验；不要把候选接手事件当成无感切换通过。
- 21:10 以后 Jellyfin 公网接口在 200 与 503 之间波动、局域网 8096 仍曾连接重置；iPhone 18 的启动台截图显示 4G、NAS CPU 70%、磁盘 92%、Jellyfin 灰点。暂不启动视频转码。只读检查还发现 2.2 Mbps 实际传输能力下安全上限约 1.1 Mbps，但旧策略最低强制选 1.5 Mbps；已补 1 Mbps、750 kbps、500 kbps 档。定向测试 `testAdaptiveTargetFitsCapacityAndStepsDownAgain` 正常 `** TEST SUCCEEDED **`，日志 `/tmp/nastart-adaptive-low-bitrate-test.log`；标准 workspace Debug iphoneos `** BUILD SUCCEEDED **`，日志 `/tmp/nastart-adaptive-low-bitrate-device-build.log`。
- 最新签名 Debug 包已再次安装 iPhone 18 与 iPhone 13；iPhone 13 安装日志 `/tmp/nastart-adaptive-low-bitrate-iphone13-install.log`。两机用无测试变量常规启动，WDA 分别显示 iPhone 18 PID 11075、iPhone 13 PID 42470，`env={}`。新低码率档及交接缓冲修复均未做真机视频复验。
- 约 21:15 Jellyfin 公网接口连续三次 HTTP 200，iPhone 18 启动台显示 4G、Jellyfin 在线、NAS CPU 57%。准备复验时，WDA 的完整 UI 树查询卡住；恢复 WDA 后屏幕显示手机已切到其他个人应用，表明设备当时正在被使用。**没有启动视频或限速**，立即停止界面操作并删除该私人屏幕临时截图。后续真机操作需待用户确认手机空闲并回到 Nastart；WDA 重启日志 `/tmp/nastart-adaptive-wda-restart.log`，新会话 ID 不应沿用。

## 两个账号轮换方案（尚未实机演练）

官方 Remote 要求手机与桌面主机使用同一账号及工作区；切账号会使旧身份的远程会话失效。只在手机换号不能保证接管 Mac。配对从桌面 Settings → Connections → Control this Mac or PC 开始，再用手机扫码和完成身份验证。

因此建议先在家准备一个独立于 ChatGPT 额度的远程桌面访问方式，并用手机外网做完整演练：停止 A 当前修改/设备操作、更新交接文件 → 从独立通道进入 Mac → Mac 和手机均切 B → 检查 B 的 Remote 配对，必要时重建 → 在 B 打开同一项目，新会话读本文件接续。扫码在同一手机远程画面中的可行性及登录验证必须提前实测；不能承诺无人值守自动切换。本轮未配置远程桌面、未切账号。

未找到官方支持把两个账号的额度或历史会话合并后原地接续的流程。工程接续以本机文件为准；不要复制认证缓存或依赖旧账号聊天自动出现在新账号中。单一工作区/单台测试手机同一时间只由一个会话写入和控制；另一个账号先停止后再接手。

每批结束或额度接近用尽时，更新本文件的当前包、实际通过/失败、在跑进程与下一步。这样即使额度突然用尽，也有上一检查点可读；接手还需核对现场，不能假定记录之后没有变化。

官方依据（2026-09-28 查询）：[Remote connections](https://learn.chatgpt.com/docs/remote-connections)、[账号切换使旧远程会话失效的更新记录](https://learn.chatgpt.com/docs/changelog)。

给新账号的起始指令：

> 打开 /Users/lagransun/workspace/Nastart，先读取 docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md 及其中的审计和总账，再核实工作区、设备和当前构建。沿既定播放主线继续，保留未提交修改，按影响范围回归；先报告已完成与待验证的边界，不从头重建方案。
