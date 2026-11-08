# NAS 恢复后的大文件双入口接续

## 授权与包身份

2026-10-07 13:08 起用户确认 NAS 恢复；随后确认 iPad 已停止播放、iPhone13 没有人工操作并可独占调试。恢复自动回归，不沿用 Container Manager 重启前的负载基线。没有变更 NAS 配置或重启服务。

源码 main `4de732dd645b36671becff992cdef1d0163fd1e4`，8 个既有 iOS 未提交文件保留，`git diff -- ios` SHA-256 `fb2f60a61701861c7c8a9a39df8553540e55696d39f33f5cf498f8ae19dc0f01`。本批尚无源码修改。最新普通 Debug -Onone 包构建于 12:33:05，主二进制 `a495e914a3f7894ef4f87bcde7a23db0a28c9ab6e18f92c8f2697d5e4702c33b`，debug dylib `d5245a9e9250523082c583cd5a9d4df398d9afb2a8be96d97a88db802c559765`，KSPlayer `c814c6b3f8d1beaddef93e8c77935aa9d653835244ae7a0b772d9900e709a704`。此前 178 tests/1 skip/0 failures、15 预检、普通构建、29 库及整体签名/链接校验通过；无源码变化不重复声称新增测试。

包及原始身份、UDID、偏好和完整媒体日志仅在本机私有 `DebugEvidence/2026-10-07-083328-dual-entry-session` 下。每机现场核对名称、型号、系统、UDID、USB/配对和包签名，并保存本机路径与哈希：

| 设备 | 本轮身份/安装 | 结论 |
| --- | --- | --- |
| iPhone13 | iPhone14,5 / iOS16.3.1；13:09～13:10 保留数据覆盖 a495/d524，25 偏好一致 | 空环境/空参数正常前台已核，最新包 S19 Jellyfin LAN 有失败证据；后续文件入口进行中 |
| iPad | iPad12,1 / iPadOS18.3.1；13:11 保留数据覆盖同包，16 偏好一致 | 旧 WDA reset 后复用已签名 fixture 免重装恢复；普通启动/逐机安装 gate 完成，S19 文件 LAN 有失败证据 |
| iPhone18 Pro Max | iPhone19,7 / iOS27.0；上批12:57同包保留数据安装/正常启动 | 本批 USB 枚举未连接；不新增该机最新播放/主题通过，详见18安装交接 |

## 最新包大文件基线

素材 S19：《指环王》128,795,641,934 bytes。两机串行，iPhone13 使用原 Wi-Fi ON、Shadowrocket ON/配置规则，未叠加人工限速；本批没有真实弱蜂窝测试结论，也没有确认媒体实际规则命中。iPad 同样未限速。显示截图/遥测不能证明完整连续显示、实际音频或 HDR 输出。

### iPhone13：Jellyfin LAN

- 初次操作边界错误包含约18.18秒守卫，已按实际 W3C touch 纠正并保留原记录。3/10秒截图缺失，最后图约实际触摸后162秒，不能称满180秒。
- 内部首帧事件约1.97秒；实际早期图为 Dolby/片头，不能把内部事件直接当电影内容首帧。
- 原画 trace：30 样本约30.93秒，缓冲0→1，报告9351ms等待、最大6丢帧。约17.45秒请求降档，约31.51秒完成12Mbps HLS接手。
- HLS 接手后仍观测到缓冲0→1、accessLogStalls 1，不能判持续流畅通过。必填 Params 的现场 HTTP400 兼容结论仍需专门证据。
- 普通Done退出时 WDA session失效，退出为TOOL；按runbook拉取崩溃/Jetsam，不能仅归为采集故障。

### iPad：设备文件 LAN

- File Station 实际文件夹可读，进入同一大文件；有界滚动最终找到条目，早期工具超时保留。
- 13:24:44.85 从头播放，3/10/30/60/90/120/180秒均有实际前台截图，最后边界180.596秒；后续可辨人物/地图画面推进。
- 播放中持久化日志停留早期，退出后再次拉取才获得更新，43 遥测跨173.343秒、末位置141.093秒、缓冲0→3、最大8丢帧。诊断store按750ms静默延迟持久化，不能把播放中旧快照当全段无卡顿。
- route明确KSPlayer/original directPlay，未观察到兼容HLS接手；普通Done退出PASS。画面可辨不抵消缓冲失败，字幕/音轨、完整FPS仍未验。

## 系统内存事件与工具恢复

13:22:42 Jetsam 报告将 `backboardd` 标为 per-process-limit，约2099.4 MiB。Nastart该报告没有kill reason，寿命内存峰值约862 MiB；随后独立进程检查已不在运行。未取得同日 Nastart 崩溃栈，不能声称已确认 App 崩溃或已排除 App 对系统内存的影响。先确认手机无媒体进程，再启动 iPad 单独播放。

复原普通空环境 App 后，WDA 出现 nil activeAppInfo/session 404；发现已有 `local.nastart.wda-iphone13` 管理的宿主与本轮手动恢复重复启动。停止本轮重复宿主，恢复单一既有管理链路，不重新安装 WDA。fresh session/source 验证 App 前台后，设备文件 root/video 实际可读。先前无测试输入的导航变化与119会话问题仍未证明根因；本轮 early mainSID/晚到FileStationSID的数据源发布顺序是候选原因，未改源码。

## Agent 后续接入

用户关心后续 Agent 连接是否使已有播放优化失效。审阅当前 Agent 实现和 App 接入：现阶段只是 DSM 信息增强/服务发现，没有视频中转接口，已有服务 endpoint/文件列表优先保留。建议复用现有播放请求/路由边界；纯 Agent 文件入口和媒体中转尚未实现，不能声称已验证。完整迁移边界与后续验收见 [Agent 播放迁移](../../../testing/AGENT-PLAYBACK-MIGRATION.md)。

## 未完成与同步

- 最新包 iPhone13 S19 文件 LAN 回归进行中；随后真实弱蜂窝/原规则VPN和无VPN两入口、MI2/S03、大偏移跳转、十分钟、画质升档与内存隔离。
- File Station 119 早期恢复、iPad日志持久化完整性、主题18最新包回归、S01/代表格式完整L2及所有PX/UX/CB缺口保留。正式竞品配对0。
- 已fetch确认远端main与HEAD 0/0；本批8个iOS改动仍未提交/推送，不将旧提交称为本批Main同步完成。
- 本机私有证据保留；项目仅保存 [脱敏量化](../../../testing/results/2026-10/NAS-RECOVERY-LARGE-PLAYBACK-20261007.json)，不推送原偏好、凭据和第三方未用参考样本。
