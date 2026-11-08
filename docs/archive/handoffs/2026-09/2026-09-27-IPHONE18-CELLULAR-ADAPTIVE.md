# iPhone 18 蜂窝 S19 与选档改动（2026-09-27）

## 真机观察

- iPhone 18 Pro Max / iOS 27.0 通过 USB 连接，用户关闭 Wi-Fi 并切到蜂窝网络。WDA 已在该设备安装，Xcode XCTest 与本机 8104 端口返回 `ready=true`；这只证明自动化通道可用。
- Jellyfin 媒体库在播放前记录网络分类 `cellular`，约 1 MiB 的 Jellyfin 测速为 20.7 Mbps，保守上限 12 Mbps。S19 源文件约 128.8 GB、81.9 Mbps。
- 旧策略从头播放 trace `428F6529` 选 `originalFirst` / `localRangeProxy` / `directPlay`。首帧日志约 1.7 秒，19:53:15 至 19:54:33 多次缓冲；截图确认播放器显示等待转圈。部分完整 32 MiB 上游响应约 9.4～11.3 秒且代理回压为零，另有带回压的样本不可当作链路速度。
- 19:54:42 第三次缓冲后发起自动降档，旧固定折半策略向 Jellyfin 请求 6 Mbps HLS 并开始候选预热。用户此时要求停止测试，因此**没有候选交接成功或稳定播放的本轮证据**。已结束 Nastart 播放进程与本轮 WDA 转发/XCTest 会话；WDA 安装保留。
- 原始偏好/诊断 plist 与截图仅保存在 `/tmp/nastart-iphone18-cellular-*`，其中可能含连接信息，不入库。

## 随后代码调整

- 播放前已有 120 秒内可信测速、且片源码率超过实测容量 1.5 倍时，直接选择留有吞吐余量的 Jellyfin HLS 档位；Play 路径不等待新增测速。正常原画路径不受额外等待。弱网直接使用 HLS 可能使首帧比原画慢，需单独验收这个取舍。
- 本机代理记录完成的原画 Range 和 HLS 媒体分段传输；有播放器回压、太短、太小或超过 60 秒的样本不参与选档。对余下样本取较低分位，并与近期 Jellyfin 测速取保守值；档位目标不超过该值的 50%，且每次降档低于当前档位。无可用样本时用保守网络默认值。20 Mbps 的可信容量对应 10 Mbps HLS 档位。
- 当真实传输容量持续明显低于片源码率且播放时钟已推进，提前准备候选；反复卡顿仍可触发。候选预热期间旧流继续播放，仅在候选有解码帧且时钟对齐后交接；失败保留旧流。后台、暂停、seek 不累计自动降档，手动固定清晰度不再自动覆盖。
- 设备文件入口的 Greenfield Debug 路径已新增有条件的 Jellyfin HLS 路线：只在大文件、非明确 Wi-Fi、当前 Jellyfin 账号可访问且唯一媒体源的文件大小、文件名及末两级目录一致时启用；优先用同目录 NFO 标题搜索，预览页后台预查，找不到则保留原文件。现有备用 Range 链路仍只读取原文件。设备文件 HLS 卡顿后的再降档已接入候选预热，但真实交接尚未触发验收。Release 设备文件入口目前没有启用这条路线。
- 本批未增加播放中自动升档。网络恢复后的升档需要独立容量验证、稳定观察期和防反复切换规则；目前重新开播会按新鲜网络样本重新选路。

## 验证边界

- 2026-09-28：用户看到手动点开 WDA Runner 图标后立即退出。iPhone 18 仍已安装 WDA；经 Xcode `test-without-building` 启动同一 XCTest fixture，本机 `8104/status` 再次返回 `ready=true`（WDA 16.1.5），设备进程列表出现 Runner。故手动点图标的现象不能作为 WDA 安装故障证据，后续自动化继续通过 XCTest 启动并以 `/status` 验证。验证后已停止本轮 XCTest 与端口转发，保留安装。
- 本轮变更后的模拟器 `PlaybackNextCoreTests` 通过，generic iOS Simulator 构建与 preflight 通过；最终三项选档、样本过滤与启动路由定向测试再次通过。
- 后续用户重新授权继续真机测试并安装新包。iPhone 18 蜂窝 S19：Jellyfin trace `A26C8A79` 在约 19 Mbps 测速下开播选 8 Mbps HLS，首帧时钟事件 7505 ms，播放超过 10 分钟至 628 秒，`accessLogStalls=0`。屏幕截图确认出画面与双语字幕。深位置 seek 的自动化手势没有被接收，未验收。
- 同文件的设备文件原流 trace `8ABDDE8D` 首帧事件 1747 ms，但约 5.6 秒位置缓冲 7100 ms；完整 32 MiB Range 上游约 7 秒。新映射路线先后解决了首次网络分类未就绪、全库前 500 项查不到目标和两服务挂载前缀不同的问题。NFO 搜索返回唯一的同大小、同文件名源，再核对末两级目录。蜂窝约 5 Mbps 时 trace `13620BDE` 开播选 2 Mbps HLS，首帧事件 11934 ms，10 分钟播放至 601 秒，`accessLogStalls=0`；截图确认中文字幕。
- 最后安装的预查版在文件详情页后台完成 NFO/媒体身份和测速；约 19 Mbps 下设备文件 trace `1C617517` 选 8 Mbps HLS，点播准备 788 ms，首帧事件 7023 ms。该包播放至约 160 秒，`accessLogStalls=0`、缓冲余量约 52 秒；不能用上一包的 10 分钟结果替代最终包长时验收。真机事件来自播放时钟，不是外部摄像机测量的屏幕首帧或音频连续性。
- PX-03 保持进行中：未验证突然降速后的自动交接是否无感，也未实现播放中自动升档；设备文件匹配不到已验证 Jellyfin 源时只能用原流，弱网下仍可能卡顿。原始诊断与截图只在 `/tmp/nastart-iphone18-*`，可能含连接信息，不入库。

## 2026-09-28 蜂窝自动降速复测

- 只在显式 `devicectl` 启动参数下启用 Debug 媒体代理限速，延迟 20–35 秒后限制所有媒体分段的合计送达速率，150–180 秒后自动解除；没有改 iPhone 的 Wi-Fi、蜂窝或 VPN 系统设置。原始 plist 留在 `/tmp/nastart-iphone18-throttle-*.plist`。
- 首轮从 10 Mbps HLS 限到 4 Mbps，分段实际约 3.7 Mbps；trace `AC81C8D6` 在约 115 秒位置出现 `accessLogStalls=1`，未自动降档。诊断发现 SwiftUI 报 `scenePhase=background`，尽管播放时钟推进、WDA 报 Nastart 为前台，因此原有后台门槛挡住了降档。现改以实际播放状态判断是否可尝试候选。
- 第二轮在 Debug 测试参数下固定从 4 Mbps HLS 开播，再限到 2.4 Mbps，分段实际约 2.2 Mbps。trace `2BBDDAF0` 在缓冲未空时发起自动降档，Jellyfin 生成 1.5 Mbps 候选；候选已解码，但 40 秒预热窗口内未与旧流时钟对齐，记录 `replacement_warmup_failed stage=alignment`，旧流随后仍出现一次卡顿。此轮证明预测触发，**不证明无感交接成功**。同时修正预测使用当前 HLS 档位，而非 81.9 Mbps 原片码率；将初始候选预热提前量调到 11 秒并记录失败时双时钟，尚待实机复验。
- 第三轮装入上述候选改动后，Jellyfin 资源库搜索返回 `NSURLErrorDomain -1004`，DSM 登录超时，Mac 同一 Jellyfin 地址返回 HTTP 502，无法取得影片流；未把这轮计为播放通过。已结束带限速参数的 Nastart 进程，并用**不带任何测试环境变量**的 `devicectl` 命令重新启动 App；限速器仅存在于 Debug 进程内，系统网络设置始终未变。本轮 WDA/XCTest、USB 转发和 syslog 采集均已停止，WDA 安装保留。
- 用户随后报告 Jellyfin 已恢复访问。再次在 iPhone 18 蜂窝网络下通过 WDA 打开 Nastart 的 Jellyfin 资源库并点“重试”，诊断连续两次记录 `httpStatus=502`、`Get.APIError`，界面显示“无法载入 Jellyfin 资源库”；Mac 对 App 配置的 `https://lagransun.cn:8097/System/Info/Public` 也仍返回 Synology nginx 的 HTTP 502。此时 App 进程未带测试限速环境变量，未开始新一轮播放/降速测试。已询问用户恢复时使用的确切访问入口，以便核对 App 地址。
- 后续 Jellyfin 与 DSM 均恢复 HTTP 200，用户报告调试期间 NAS 的 Container Manager 重启。未取得 NAS 系统日志，不能确定重启原因。一次准备短测时，iPhone 18 实际已连回 Wi-Fi，原 Debug 测试起播档位只对非私网生效，trace `051F119E` 因而误选 `192.0.2.2:8096` 的 81.9 Mbps 原画；发现后立即终止播放，未进入受控限速阶段。现把 Debug 起播参数改成即使发现私网也强制请求限定码率 HLS，以免测试时再次误读原画。
- 用户再将 iPhone 18 切回蜂窝，状态栏显示 4G。短测前 NAS 卡片显示 CPU 68%、磁盘 92%；考虑到刚发生的重启，没有启动新一轮视频转码。已用无测试环境变量的命令重启 Nastart，并通过 WDA `activeAppInfo` 核对 `env={}`；系统 Wi-Fi、蜂窝与 VPN 设置未由本轮自动化修改。WDA/XCTest 与 USB 转发已结束。最新候选提前 11 秒的版本仍**没有**受控降速交接验收。

## 2026-09-28 晚蜂窝交接复现

- iPhone 18 状态栏为 4G，Jellyfin 与 DSM 开播前可用。仅在本次 Debug App 进程中注入测试参数：4 Mbps HLS 起播，35 秒后代理总速率上限 2.4 Mbps，150 秒后自动解除。实际完成的分段速率约 2.2 Mbps。没有修改系统 Wi-Fi、蜂窝或 VPN。
- S19 trace `7CCB60C3` 的第一次预测降档请求获得 1.5 Mbps 候选解码帧，但与当前时钟未对齐，按预期放弃。第二次候选于约 149 秒位置有解码帧并完成时钟对齐；新 trace `ABB7A7A0` 接手，证明自动降档交接路径确实被执行。
- **本次交接没有达到流畅验收**：候选交接时缓冲仅约 0.07 秒，随后 `timeControlStatus=paused`，屏幕进度停在 2:29，用户会感觉到明显停播。预热候选为了追时钟关闭了 `automaticallyWaitsToMinimizeStalling`，接手时未恢复；现已在接手安装时恢复自动等待，并给预热候选保留 3 秒前向缓冲目标，同时记录交接时的播放意图与候选缓冲量。该修复尚待新的真机限速复验，不能宣称已实现无感切换。
- 同一轮估得 2.2 Mbps 实际送达能力，选档策略乘 0.5 后安全上限约 1.1 Mbps，但旧档位最低为 1.5 Mbps，因此强行回退到 1.5 Mbps，违反安全目标。现补 1 Mbps、750 kbps、500 kbps 档，2.2 Mbps 样本选择 1 Mbps；定向测试验证此边界。最低档下仍无法保证极弱网络流畅，且新档位的 Jellyfin 实际输出码率需要真机验收。
- 测试后 DSM/Jellyfin 在 Mac 局域网与公网入口均不可用；路由器及普通外网正常。NAS 故障原因未查明，停止了视频请求。已结束带测试参数的进程，用不带测试环境变量的命令重启 Nastart；WDA 所示新进程 `env={}`。原始日志在本机 `/tmp/nastart-next-iphone18-*.plist`，可能含连接信息，不入库。

## 2026-09-29 早：NAS 无转码负载的受控降速

- 用户建议改用《碟中谍》大文件。Jellyfin 片库中第 2、3 部约 55 GB、54 GB，片源码率约 64、62.7 Mbps，仍可能让 NAS 同时维持转码源和候选。为避免复现 NAS 失联，本轮只在详情页借用 UI 入口，播放源由显式 Debug 环境变量换为 Apple 已编码 HLS 示例：高档 `bipbop_adv_example_hevc/v9/prog_index.m3u8`（估计约 8 Mbps），低档 `v4/prog_index.m3u8`（约 1.3 Mbps）。静态媒体取自 Apple CDN，不向 NAS 取视频或开启编码。
- iPhone 18 处于 4G。以 `NASTART_TEST_STATIC_HLS=1`、`NASTART_TEST_MEDIA_CAP_BPS=2400000`、`NASTART_TEST_MEDIA_DELAY_SECONDS=5`、`NASTART_TEST_MEDIA_DURATION_SECONDS=120` 启动单个 Debug App 进程。真实首帧播放时钟事件 6248 ms；限速实测 2,229,015 bps。高档 trace `50C76D01` 在 7 秒播放位置预测送达速率不足并请求降档，低档 trace `10BBEF9D` 已解码且与旧时钟对齐，约 11 秒后接手。交接旧流缓冲 0.327 秒、候选缓冲 6.50 秒；新流首帧事件 86 ms，之后进度由约 18.6 秒推进到 62.5 秒，末次缓冲约 40.6 秒。首帧后两路采样均未记录缓冲空或 `accessLogStalls`。这些是播放器诊断事件，不等于人眼、音频连续性和显示帧级无感验收。
- 原始诊断 `/tmp/nastart-v9-followup.plist`，测试构建日志 `/tmp/nastart-static-hls-v9-build.log`。测试完成后用无测试环境变量的命令替换进程，WDA 核对 `env={}`；没有修改系统网络。Jellyfin 公共信息接口随后 HTTP 200。后续如需更严的主观验收，可在真实观看时重复相同静态素材短测；不应直接以这一轮替代真实 Jellyfin 与设备文件大影片的 NAS 稳定性验收。

## 2026-09-29 设备文件入口静态素材补测

- 为同一 Apple 静态 HLS 素材补设备文件入口。最初在常规“从头播放”中按 Debug 环境变量截取请求；WDA 会话启动后该环境变量未保留，一次点击意外启动了 26 GB 文件的 Jellyfin 匹配 HLS 转码。播放器显示真实文件标题及时长后立即结束该进程；随后改成独立的 Debug 测试按钮，只在环境变量实际生效时显示。自动化须先确认按钮和播放页 `Static HLS fixture` 标题，普通播放按钮绝不能当作隔离测试入口。
- iPhone 18 4G、26 GB《Spider-Man 2》设备文件详情，经独立按钮播放时没有读取 NAS 视频。高档 trace `86961AEB` 首帧时钟事件 4891 ms，代理限速 2.4 Mbps 后实际约 2.22 Mbps；约 13.5 秒位置请求降档，低档 trace `258309A5` 解码、对齐后接手，旧流缓冲约 2.82 秒、候选约 6.96 秒，首帧事件约 54 ms。交接附近 `accessLogStalls=0` 且缓冲未空。原始诊断 `/tmp/nastart-sept29-filefixture-t20.plist`。没有人眼/听音证据；不宣称无感验收。
- 测试素材的 `.dsmFile` 候选出现时间轴偏移重复计算，使诊断首帧位置与实际播放时钟不一致；已修正静态素材时间轴偏移。最终 Debug 包已编译并安装两机，但复核时 App 的 DSM 文件页提示会话未连接，未继续播放。该修正尚未真机复验。测试变量已清除、App 正常启动，iPhone 18 WDA 已停止，Jellyfin 公共接口 HTTP 200；详情见 [最新接续记录](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。
