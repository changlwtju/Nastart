# 2026-09-30 iPhone 13 原画停滞续查

## 现场和范围

- 接续 [9 月 29 日 S01 持续播放与取消](2026-09-29-CONTINUOUS-CANCEL.md)：旧包 S01 在 247.710 秒停住，自动 HLS 候选已解码却领先 11/15 秒而无法对齐；最新 `f08bf…` 候选修正缓冲时的预热提前量，上一轮十分钟原画未复现停滞，因而真实故障恢复未验。本轮先用同一低负载 S01 寻找原画初始停止读取的原因，不用大电影或人为限速，不改系统网络。
- 开始时 HEAD `9a9941c`；现有源码、文档、KSPlayer 未跟踪内容均保留，`git diff --check` 通过。开始 status/diff 留本机 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-iphone13-stall/`，原始诊断可能含凭据，不提交/上传。
- USB 仅 iPhone 13 `00008110-001E543122E0401E`，WDA 8102 `ready=true`；未见 iPad/iPhone 18。Jellyfin LAN、DSM LAN 无凭据公开接口均 HTTP 200。启动台初始 CPU 43% / RAM 20% / 磁盘 92%；DSM 刚启动时显示暂未连接，需等待原有会话恢复后判断，Jellyfin 服务在线。iPhone 13 只有家中 Wi-Fi。
- 已对已验签名 Debug 包 `f08bfde1c3f3f9eaa811bb7eb7f4f43b1e31a32c31589b7458b4e17402c11bd2` 保留数据覆盖安装（`InstallComplete`），随后明确以 `environment={}`/`arguments=[]` 正常启动，PID 55921。版本号本身不足以识别包；该哈希是安装源 dylib 的身份。

## 10:17 S01 单路十分钟结果

- iPhone 13 家中 Wi-Fi，Jellyfin S01《哈尔的移动城堡》从头原画单路运行，trace `FC0BA914`，本机监测约 603 秒；实际影片画面可见，557 条带时钟遥测从 17.502 推进至 621.598 秒，退出前暂停点 622.089 秒。`bytesRead` 从 14,038,090 增至 251,391,044，卡顿计数最大 0、`stallActive=yes` 样本 0、丢帧/丢包 0；`playback_ended` 1 条，退出回同一详情。没有自动降档请求。诊断与截图在上述私有目录 `day2-*`。本轮没有重现旧包 247.710 秒停滞，因此未获得冻结时解复用线程现场，旧根因和真实故障下候选接手仍未验；没有人工听音结论。
- 此轮媒体虽经 App 本机 `localRangeProxy`，上游实际是 Jellyfin 公网域名 `https://lag…un.cn:8097`，HTTP/2、远端公网 IP；事务指标 `cellular=no`。独立探测的 Jellyfin LAN 接口 HTTP 200 不能等同于这次媒体走 LAN。10:00:48 本次 Jellyfin 库初始化记录 `playback_route_probe result=publicInfoUnavailable`，未验证局域网同服；10:24:38 退出库再进入后记录 `playback_route_verified route=sameServerLAN`。这证明局域网同服验证有暂时失败后成功的现场，解释了本轮媒体选公网路径；不将其归因为旧次停滞（旧次上游为局域网）。下一步给验证失败补有界重试，并保留服务器 ID 相等的安全门槛。
- 播放后 NAS 在 App 中显示在线，CPU 29% / RAM 20% / 磁盘 93% / uptime 1天13小时，DSM 与 Jellyfin 均为绿色；本轮未见 NAS 重启。早期启动台“未连接”是会话恢复阶段，现已恢复。iPad 仍未接 USB，未动 VPN、Wi-Fi 或 NAS 设置，未跑大电影人为限速转码。

## 10:35 局域网验证重试优化与真机短回归

- `JellyfinLibraryStore.verifyLANPlaybackEndpoint` 在公网同服信息或 LAN 信息暂不可用时，最多延迟 2 秒、再延迟 6 秒重试；验证成功取消待执行重试。只有公网与 LAN 的服务器 ID 相等才采用 LAN；ID 不同直接拒绝，绝不以 HTTP 200 代替同服校验。此优化只影响后续媒体选路，不声称修好旧次原画停止读取。改动位于 `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift`，未动 KSPlayer 静态怀疑点。
- Debug iphoneos 构建签名、`codesign --verify --deep --strict`、preflight 与 `git diff --check` 通过。新包保存在本机私有证据目录 `Nastart-lan-retry.app`，dylib SHA-256 `86f6c8eb58eeb95040fff8ceebd5b1af7fe9af80f4997884692b4822b6e48b3b`；保留数据安装 `InstallComplete` 后显式无变量启动，PID 56199。启动约 25 秒后 DSM 在线、CPU 28% / RAM 20% / 磁盘 93%，Jellyfin 绿色。
- iPhone 13 新包打开 Jellyfin 库，10:33:15 记录 `playback_route_verified route=sameServerLAN`。S01 从头原画单路短回归 trace `B2246D1A`，36 条带时钟遥测到 36.766 秒、卡顿/丢帧 0，实际画面、退出回同一详情及 `playback_ended` 1 条；Range 上游 `192.168.1.64:8096`、HTTP/1.1、`cellular=no`。这证明新包在正常可验证状态会选择局域网并能短时播放；本轮没有人为使首次验证失败，故**重试分支本身尚无真机故障注入证明**。完整十分钟只针对旧 f08bf… 包的公网路线，不能移作新包的十分钟 LAN 稳定性结论。

## 下一项

## 14:30–15:09 接续：局域网长播、重试决策与最终包

- 仅 iPhone 13 家中 Wi-Fi、Jellyfin S01 单路原画。早上的 `86f6…` 局域网重试包从头播放 trace `99B41B69`：650 条遥测覆盖约 701 秒，带时钟样本由 0.073 推进至 700.574 秒，`bytesRead` 由 1,874,559 增至 278,581,897；650 条 `stallCount=0` / `stallActive=no`，可用丢帧/丢包样本均为 0，退出回同一详情并有 `playback_ended` 1 条。实际影片画面截图已留本机。Range 上游事务是 `192.168.1.64:8096`、HTTP/1.1、`cellular=no`；这次**是新包局域网原画超过十分钟的单次成功**，与早上的旧包公网十分钟分开记录。没有重现旧包 247.710 秒停滞，也没有触发自动回退或人工听音验收。
- 将有界重试与同服 ID 判定提到 `JellyfinLANPlaybackProbePolicy`，使公网信息暂不可用、LAN 信息暂不可用、两次延时耗尽、同服成功、不同服拒绝可在无 NAS 故障注入时确定性检验。已有待执行重试时不消耗额外次数。两项定向模拟器 XCTest 实际通过，最终 Debug iphoneos 构建、签名核验、preflight、`git diff --check` 通过。此测试证明决策逻辑，**未**在真机人为制造探测失败或证明异步定时回调在故障现场恢复。
- 最终签名包 `Nastart-lan-probe-policy.app` 的 dylib SHA-256 为 `cbfff361a80cc472afe19ec20c37843fdecfdd195c7dbfc3c95970827fc44ef8`，保留数据安装 iPhone 13 后通过 WDA `environment={}` / `arguments=[]` 正常启动，PID 57920。S01 续播短回归 trace `999FBE0C`：带时钟样本从 700.809 到 776.414 秒，73 条遥测、局域网 `192.168.1.64:8096` HTTP/1.1，上报退出 1 条。首帧前一次约 301 ms 缓冲，首帧约 1491 ms；首帧后未再增卡顿次数。该包没有重新跑十分钟，不将上条十分钟结果移作此哈希的长播验收。
- 两包、测试日志、导出的诊断及截图在本机私有目录 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-iphone13-stall/`，可能包含环境信息，不提交/上传。iPhone 13 播放已退出；iPad 的同日环境专项见 [2026-09-30 iPad 环境续查](2026-09-30-IPAD-ENVIRONMENT.md)。

## 下一项

PX-03 仍进行中。旧次原画停止读取的根因、真实停滞时自动候选接手、真机失败后重试定时路径与人工听音仍未验；若再停住，先保留读取线程与传输现场，再区分原画读取和候选交接。继续低负载 S01，不改家中网络，不启动大电影人为限速转码。
