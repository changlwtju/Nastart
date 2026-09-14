# Nastart 视频播放调试总规范

2026-09-14 执行更新：按 [分层开发与回归流程](../development/playback-development-workflow.md) 区分 L0 逻辑、L1 定向、L2 代表集与 L3 完整矩阵。本文继续定义真机证据及传输硬门槛；逐片全验收顺序适用于 L3，日常修复按影响范围执行 L1/L2。S19 保留压力回归，不再作为所有优化的唯一入口。

更新时间：2026-08-15（Asia/Shanghai）

本文定义后续真机播放调试的证据与安全约束；测试层级和触发条件以最新分层流程为准。交接、源码优化、真机回归和结果复核都必须先读取本文，再读取当轮交接文档。本文记录全局链路和历史故障；单个视频的偶发现象不能覆盖这些约束。

2026-09-11 起，播放优化需求和分批状态统一维护在 [PX-01～PX-21、UX-01～UX-04 任务总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。用户已授权分批实施，要求不得遗漏；恢复任务及每批结束必须核对全部未验收编号，受阻项目保留原因和下一步。本规范继续约束验收，历史手动清晰度秒切优先级由总账中的“基础播放优先、自动画质”取代。

2026-09-12 用户新增 **S19《指环王 1》100 GB 以上文件**，并要求优先用于首帧、续播及音轨/字幕/画质切换测试。当前矩阵为 19×4，按 [S19 专项](2026-09-12-S19-LORD-OF-THE-RINGS.md) 执行本轮大文件压力测试；下文历史 S01→S18 顺序保留，其未完成项不得因新增专项删除。不得按 S19 单独硬编码缓冲/解码参数。

设备手动签名补充：无签名构建的 app 根目录可能包含 `Nastart.debug.dylib`、`__preview.dylib`，必须与 Frameworks 中所有动态库一起签名，并对每个动态库独立执行签名验证。只验证 app 外壳或链接隔离不足以排除启动时 DYLD 签名失败。2026-09-11 已遇到并修正该打包故障，不能将其计作播放器失败。

## 2026-08-15 本轮通用修复门槛

- 本轮已修正标准 `bytes=start-end` 与 `bytes=start-` 请求解析；不得只测试非标准的 `bytes start-` 形式。
- 本地代理对客户端保持一条连续 chunked 响应，对上游每个任务使用有限 `206` Range；每个上游窗口必须单独记录 `Content-Length`、结束偏移和实际交付 bytes。
- 续段或断流恢复必须从“响应起点 + 本次传输累计交付 bytes”继续；不能拿首段长度判断后续窗口是否完成，也不能把窗口边界当作 EOF。
- 任何只改变窗口大小、超时、重试次数或解码模式的样本实验都不能单独固化；必须先通过标准 Range 单测、fixture/WAN playback-lab、S01 双设备回归和 S03/S08/S11/S18 格式族回归。
- `Content-Range`、完整媒体总长、chunked 客户端响应、窗口序列、短 EOF/重试都必须进入诊断证据；只看到进度条推进不能替代传输证据。
- 本轮自动测试已通过 15/15。2026-08-15 已验证 iPad WDA，并以历史 DVT 链路恢复 iPhone WDA；两台设备的 `/status` 均已取得 `ready=true`。iPhone 仍需单独补齐 S01 播放证据，不能把工具恢复推断为播放通过。

### 本轮新增的两个硬门槛

- **字幕必须验内容完整性。** 找到“字幕”按钮、看到字幕菜单或看到一条正常中文都不等于 `SUB=P`。在 `t=3/10/30s` 及至少一个后续自然字幕帧逐帧看实际画面；只要出现方框、缺字、乱码、重复层、残留、被底部裁切或切换后字幕消失，`SUB=F`，并保留原图和裁剪图。历史失败样本必须重放，不能用另一个正常句子替代。
- **先排除 App 崩溃，再判断 WDA/播放失败。** 若截图突然回到桌面、WDA session 失效或播放窗口消失，立即用 `idevicecrashreport -u "$UDID" -e -k "$CRASH_DIR"` 拉取报告，并以崩溃时间、faulting thread 和源码栈为准分类；不能把进程退出记成“WDA 采集失败”或继续调整视频参数。

## WDA 真机安装、启动与验证固定链路

WDA 不是普通 App：直接用 `devicectl device process launch` 启动 Runner 只能做诊断，不能替代 XCTest 建立 `testmanagerd` 会话；出现 `com.apple.testmanagerd ... No such process` 时，不要先改播放参数，也不要把它归因于媒体失败。正式链路固定为：

1. 固定 WDA 工程、Xcode、Team、Bundle ID 和 DeviceSupport。当前可用历史 ID 是 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`（host）与 `com.changliwen.nastart.WebDriverAgentRunner`（test）；不得在 Runner、test bundle、`.xctestrun` 和 provisioning profile 之间混用 `WDARunner` 与 `WebDriverAgentRunner`。
2. 优先运行标准工程命令，让 Xcode 完成构建、签名、安装、启动 XCTest：
   `DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer xcodebuild test -project "$WDA_PROJECT/WebDriverAgent.xcodeproj" -scheme WebDriverAgentRunner -configuration Debug -destination "platform=iOS,id=$UDID" -derivedDataPath "$WDA_DERIVED_DATA" DEVELOPMENT_TEAM=5436TB5498 CODE_SIGN_IDENTITY='Apple Development' CODE_SIGN_STYLE=Automatic PRODUCT_BUNDLE_IDENTIFIER=com.changliwen.nastart.WebDriverAgentRunner WDA_PRODUCT_BUNDLE_IDENTIFIER=com.changliwen.nastart.WebDriverAgentRunner.xctrunner`
3. 已有完整且未过期的 `.app/.xctestrun` 时，才使用 `xcodebuild test-without-building` 回退；不要添加会触发当前 Xcode 误判的 `-only-testing:WebDriverAgentRunner`。先用 `scripts/prepare_wda_recovery.sh` 校验 Bundle ID、test host、签名和路径。
4. XCTest 进程稳定运行后再启动前台 `iproxy`，语法固定为 `iproxy LOCAL_PORT:8100 -u UDID`；iPhone 使用本地 `8102`，iPad 使用本地 `8101`，不能用旧版 `iproxy 8100 8100 UDID` 语法，也不能两台设备共用本地端口。
5. 只有 `curl -fsS http://127.0.0.1:$LOCAL_PORT/status` 返回 `ready: true`，并且 `productBundleIdentifier` 与当前包一致时，才开始建立 UI session 和真机播放采集。WDA `/status`、XCTest 日志、`iproxy` PID 和设备 UDID 必须写入当轮证据。

故障分支固定如下：`testmanagerd` 错误先重跑标准 `xcodebuild test`；`Connection reset` 先检查 Runner 是否退出及 `iproxy` 端口映射；`destination unavailable` 检查 USB 配对、`xctrace list devices`、DeviceSupport 和 Xcode/CoreDevice 状态；只有签名校验失败、包缺失或 XCTest 明确报告安装/验证失败时才重新构建/安装 WDA。WDA 不按样本、按参数或按天重复安装。

本次恢复证据：iPad `00008030-001168403C43C02E` 的 WDA `16.2.0` 返回 `ready: true`；S01 设备文件入口截图目录为 `/tmp/nastart-s01-wda-retry/`，t=0/3/10/30 均取得真实视频帧。iPhone `00008110-001E543122E0401E` 已于 2026-08-15 用历史 Bundle ID + DVT 复原，`127.0.0.1:8102/status` 返回 WDA `16.1.5`、`ready: true`，并成功建立 session、读取启动台和“设备→文件”页面；这只证明工具链恢复，不替代 iPhone 播放回归。

### iPhone 历史可用链路的复原思路

iPhone iOS 16 的历史成功证据不是“直接启动 Runner App”，而是 USB/usbmux 的 DVT/XCTest 链路：精确复用历史 WDA `.app`、`.xctestrun`、`TestHostBundleIdentifier`、test bundle ID、签名团队和 `DYLD_INSERT_LIBRARIES`，再用 `pymobiledevice3 developer dvt launch` 启动历史 host，最后用 `iproxy LOCAL_PORT:8100 -u "$UDID"` 暴露 WDA。当前机器若没有该工具，先在隔离环境固定安装：`python3 -m venv /tmp/nastart-pymobiledevice3-venv && /tmp/nastart-pymobiledevice3-venv/bin/python -m pip install pymobiledevice3`。`devicectl device process launch` 只能证明进程能被拉起，不能替代 `testmanagerd` 会话。

固定复原顺序：

1. 先用 `idevicepair validate`、`ios-deploy -c`、`xcrun xctrace list devices` 验证配对、USB 和 DeviceSupport；不要先重装 WDA。
2. 从历史产物读取并核对四个 ID：host `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`、test `com.changliwen.nastart.WebDriverAgentRunner`、xctestrun 的 test host，以及 provisioning profile 的 application-identifier；任一处变成 `WDARunner` 都先视为链路不兼容。
3. 标准 `xcodebuild test` 在新 Xcode 对旧 iOS 报 `DVTBuildVersion`/`Logic Testing Unavailable` 时，保留失败日志，切换到与设备匹配的历史 Xcode 或历史 DVT 包；不要反复生成另一套 Bundle ID 的 Runner。
4. WDA 启动后才建立 `iproxy`，再依次验证 `/status`、`/session`、`/source`、`/screenshot`、元素点击和拖动；所有端口、UDID、WDA bundle ID 和进程 PID 写入证据。若用 DVT 单独启动 Nastart 进行诊断后 WDA 连接被 reset，重新启动历史 WDA 并复查 `/status`，不要重装或改播放参数。

这条链路的目的是把“安装包、测试宿主、测试服务、usbmux 转发、WDA HTTP”拆开验证，避免每次遇到 iPhone 失效都从头猜测。

## 不可变约束

- 不更新 iPhone/iPad 系统。
- 不按样本或按天重复安装 WDA。WDA 失效时按上面的固定顺序先检查 XCTest/DVT runner、iproxy 和 `/status`；只有包缺失、签名/描述文件失效或 XCTest 明确报告安装验证失败时才重建/安装。
- 不为了某个样本直接增加“特殊视频参数”。任何 Range 窗口、超时、重试或解码策略修改，都必须说明对 18 部样本和两种入口的全局影响，并至少完成 S01 的 iPhone+iPad 串行和并发回归。
- Range 窗口只能是传输实现的资源上限，不能成为某个样本的播放参数：客户端看到的媒体响应必须保持一条连续、可定位且带完整总长度的响应；上游有限窗口结束时，代理必须从精确字节偏移继续请求，不能把窗口边界当成媒体结束，也不能退回整文件渐进式 `200`。
- 任何传输策略改动都必须记录客户端响应模式（`206`/chunked）、上游窗口序列、首段与续段的 `Content-Range`、总长度、实际交付 bytes、短 EOF/重试次数；至少在 S01 以及 S03/S08/S11/S18 的格式族回归后才能固化。若只通过某一个样本，不能判定策略具有普适性。
- 不把黑屏、转圈、进度停滞、App 退出、WDA 断连、链路不可达混写成“卡顿”。每种状态必须单独记录。
- 未有截图、进度、系统日志或源码诊断证据的结论只能写“未判定”。
- 连续流畅是所有入口的硬性验收项：至少 30 秒进度持续推进，不能出现可感知卡顿、重复黑屏或假播放；缓冲必须记录起止时间和恢复后状态。
- Jellyfin 媒体库加载是独立验收项：记录冷启动到列表、首批海报/元数据和详情页可用的时间；媒体库加载慢不能被视频首帧结果掩盖。
- 分辨率与画面布局是独立验收项：核对媒体源/详情页标注的分辨率、播放器报告的轨道分辨率和实际画面；同时记录是否正确铺满可用播放区域、是否存在拉伸、裁切、错误缩放或异常黑边。符合源视频宽高比的正常留边不能误判为分辨率错误，但必须记录设备方向、视频区域尺寸和黑边情况。
- 字幕显示与音频输出是新增的独立补充验收项 `SA=SUB/AUD`：`SUB` 检查实际字幕内容、编码、重复/残留和切换结果；`AUD` 检查设备实际音频路由、可听性、连续性、静音/断续/失真和音轨切换结果。不能用“有字幕/音轨按钮”替代实际显示或听测。
- ISO 和电视剧是独立专项，不改变 18×4 电影矩阵的样本数量和通过率。

## 多终端同时播放专项

`iPhone+iPad` 同时播放是独立专项，不能用两台设备分别单独播放的结果替代。该专项用于确认共享 NAS、Wi‑Fi、蜂窝网络、代理连接、服务端并发和播放器资源竞争不会破坏单终端已经通过的行为。

- `MTP-01`：两台设备冷启动后，在不超过 2 秒的时间差内播放同一个样本，至少覆盖 S01；记录两端首帧、t=3/10/30s 进度、实际画面、缓冲起止、下载/上行速率、Range/HTTP 请求和 App 进程状态。
- `MTP-02`：两台设备同时播放不同样本，优先覆盖格式或码率差异明显的样本；记录是否出现单端单播时没有的卡顿、黑屏、速度归零、首帧延迟、断流、Jetsam 或 WDA/App 退出。
- `MTP-03`：双端播放期间分别执行快进/回退、暂停/继续、字幕/音轨切换，并记录两端 `SA=SUB/AUD`；Jellyfin 还要执行清晰度切换、PiP 进入/退出和断点续播，确认一端的操作不会导致另一端重头播放或异常中断。
- 多终端专项发生失败时，立即暂停样本推进，建立问题记录并先做当前组合的修复回归；至少重新验证受影响样本的单端 iPhone、单端 iPad 和双端组合后才能继续。

结论必须区分：单端通过/双端失败、带宽或链路不可达、NAS/服务端拒绝、代理断流、播放器解码失败和工具失效。专项结果独立记录，不覆盖 18×4 基础单元结论。

## 串行执行、即时修复与记录纪律

以下为 L3 正式验收纪律：原 18 部按 `S01 → S02 → … → S18` 顺序执行，另补 S19，不能为提高通过率跳过失败。L1/L2 可按影响映射选择样本，原失败仍须修复回归；无关功能或缺失设备条件保留待验，不阻止独立取证。L3 每个样本按以下闭环处理：

1. 先完成该样本在当前阶段要求的全部设备、入口和链路检查；记录 `t=0/3/10/30s`、截图、WDA/DVT 日志、Range/HTTP 证据和功能操作结果。
2. 发现问题后立即暂停推进下一个样本，建立问题编号，记录首次出现步骤、复现条件、影响范围和初步根因。
3. 修复源码或测试工具后，先完成构建检查，再回归当前失败样本的失败步骤及该样本此前已通过的步骤；涉及传输、播放器、字幕、音轨、PiP 或清晰度的全局改动，必须同步回归当前样本的 iPhone/iPad 与设备文件/Jellyfin 对照项。
4. 只有当前样本的修复回归完成并形成“测试记录 + 问题修复记录 + 回归证据”后，才能进入下一个样本。未完成项保留为 `进行中`，不得记为通过。

每个样本必须同时维护两类记录：

- 测试记录：设备、系统、构建/commit、入口、链路、样本文件、首帧耗时、连续播放、卡顿/黑屏、控制项结果、证据路径和最终状态。
- 问题修复记录：问题编号、发现样本/步骤、现象、复现条件、日志或截图、根因、修改文件/方案、构建验证、当前样本回归结果、受影响样本和待办风险。

探索性专项（例如 ISO、电视剧）可以并行收集，但不得改变当前 `S01→S18` 正式顺序，也不得把探索性结果填入未完成的基础单元。

## 播放手势约定

- 视频画面双击：暂停/继续播放。这是最常见的播放器快捷手势，作用于内置 VLC 播放器。
- 视频画面单击：只显示/隐藏播放控制栏，不改变播放状态。
- 视频画面横向拖动：快进/快退；纵向拖动：亮度调节。拖动优先于点击识别，松手时只提交一次 seek。
- 播放控制栏的暂停按钮、系统耳机/锁屏媒体控制仍保持原有行为。手势验收必须记录暂停后进度是否停止、再次双击后是否从相近位置恢复。

## 历史播放链路（旧架构参考）

下文 VLC 默认路线描述保留历史风险背景；当前 Greenfield/KSPlayer 主线及 HLS/AVPlayer 兼容分支以 ADR 0002 和当前源码为准，不按此段恢复旧默认策略。

### 设备文件

1. 从 DSM/File Station 会话解析文件的认证 URL。
2. 选择实际可达候选 URL，并依据 host 分类链路。
3. 私网地址或字面 IP 的视频：先注册认证本地 Range proxy，再交给 MobileVLCKit。
4. 域名/公网地址的视频：优先直连 URL；直连启动失败或后续停滞时，最多执行一次兼容性 fallback，切换到认证本地 Range proxy。
5. 本地 proxy 对每个媒体请求必须发送有限 `Range`，上游必须返回匹配请求起点的 `206`；禁止把 `bytes=0-` 转成整文件渐进式 `200`。
6. 对客户端的开放媒体请求，proxy 必须在首个有限上游窗口之外继续发送同一个 chunked 响应，并在响应头暴露完整 `Content-Range` 总长度；上游窗口切换不得触发 VLC 的自然结束或重建播放会话。
7. 上游提前断流时，只能从已交付偏移继续请求有限 Range；重试次数必须有限，不能形成无限重试。
8. MobileVLCKit 是 MKV/原始设备文件的默认引擎；软件解码 fallback 是兼容性路径，不得按单个片源硬编码。

### Jellyfin

1. 通过 PlaybackInfo 协商原始直播放流，优先复用同一 MobileVLCKit 控制层。
2. 原始直播放流在 watchdog 内没有首帧、提前结束或明确失败时，最多切换一次 Jellyfin 兼容 HLS/转码资源。
3. HLS/系统兼容资源可由 AVPlayer 承载，用于 PiP、AirPlay 和系统后台播放；清晰度切换必须保留时间点、音轨、字幕和倍速状态。
4. 设备文件和 Jellyfin 的 UI 控件验收相同；只有 Jellyfin 入口增加清晰度/转码/PiP 检查。

## 已冻结的全局风险

| 编号 | 已知问题 | 证据/影响 | 后续防回归约束 |
|---|---|---|---|
| R01 | iPhone S01 曾在首个开放 Range 上暴露整部 2.7 GB MKV 的渐进式 200 | 进程达到约 2,148,374 KB，被 iOS Jetsam 以 `per-process-limit` 终止 | 任何媒体请求都必须有限 Range + 起点匹配的 206；禁止恢复开放 200 |
| R02 | iPad 对 32 KiB 媒体窗口不够宽容 | 收到 `206` 后约 14,480 bytes 即断开，播放器在 00:00 超时 | 窗口必须大于 Matroska 头部探测需要；不能只按“远端常在 32 KiB 断流”固定参数 |
| R03 | iPad 使用 8 MiB 窗口可推进到约 00:34，但远端在约 6,724,975 bytes 后断流，画面仍未稳定出帧 | 说明“窗口更大”不是完整修复，且远端链路存在提前断流/并发影响 | 必须记录上游实际交付量、断流点、是否出帧；不能用进度单独判定通过 |
| R04 | iPad 播放等待数据时，用户观察到 iPhone 同时出现同样超时 | 已完成 1 MiB 构建双端同步回归：iPhone 在 t=3/10/30 秒有真实画面，iPad 同时黑屏；当前不能证明 iPad 故障必然连带 iPhone | 保留双端并发回归；后续若再次出现双端同时超时，必须用同一时间线和两端日志重新确认 |
| R05 | 仅调整窗口会在不同视频/链路间产生反效果 | 小窗口可能不够探测，大窗口可能延长断流和内存占用 | 参数必须作为传输策略验证，至少覆盖 S01/S03/S08/S11/S18 的格式/容量差异后才能固化 |

## 每次真机回归的固定采集

每个单元至少记录：

- 设备、系统版本、App 构建时间/commit、入口、样本 ID、实际 URL 分类、是否走 proxy。
- 点击预览时间、播放器出现时间、首个真实视频帧时间、10 秒和 30 秒时的进度与截图。
- 画面状态：真实帧、黑屏、灰屏、转圈、片源水印、启动即暂停、进度是否推进。
- 分辨率/布局：源分辨率、播放器显示分辨率、设备方向、视频画面区域、正常宽高比留边或异常未铺满/拉伸/裁切。
- Range：请求 Range、响应状态、Content-Range、实际收到 bytes、断流/重试次数和最后错误。
- 进程状态：App 是否仍在运行、Jetsam/崩溃/系统内存相关日志。
- 交互项：暂停/继续、快进/快退、音轨、字幕、字幕实际显示与音频实际输出（`SA=SUB/AUD`）、清晰度、PiP、退出和断点续播。
- 媒体库项：Jellyfin 冷启动列表、首批海报/标题/年份/时长、搜索/详情加载；电视剧还要记录上下集自动跳转和集号/断点。

固定时间点：`t=0`、`t=3s`、`t=10s`、`t=30s`；若在更早阶段失败，记录失败时间并停止无意义等待。

### 串行与并发顺序

1. 先 iPhone 单独播放 S01。
2. 再 iPad 单独播放 S01。
3. 两台设备同时从冷启动播放 S01，时间差不超过 2 秒。
4. 只有串行和并发都完成证据采集，才能判断问题属于设备、播放器、代理、NAS 服务端还是共享网络链路。

并发回归要额外记录：同一时间段的两端首帧/超时、每个本地 proxy 连接、NAS 端并发请求数、HTTP/2 或 HTTP/1.1、服务端断流点。不得只看某一台设备的 WDA source。

## 结论状态词

- `通过`：首帧、连续播放和该单元要求的所有功能均有证据。
- `失败`：有可重复的功能失败或播放器错误。
- `进行中`：有部分证据，但关键验收项未完成。
- `不可达`：网络/服务本身不可达，未进入播放器验证。
- `工具失效`：WDA/DVT/采集工具失效，不能推断播放器结果。
- `样本缺失`：没有可重复访问的素材。
- `不适用`：该入口不提供该功能，例如设备文件没有 Jellyfin 清晰度切换。

`SA` 必须分别写 `SUB/AUD`；任一子项为 `U` 或 `TOOL` 时，不能把 `SA` 汇总为通过。

## 相关文件

- 18 部样本：[2026-08-12-PLAYBACK-MATRIX-18-SAMPLES.md](./2026-08-12-PLAYBACK-MATRIX-18-SAMPLES.md)
- 结果表：[2026-08-12-PLAYBACK-MATRIX-RESULTS.md](./2026-08-12-PLAYBACK-MATRIX-RESULTS.md)
- 功能验收矩阵：[PLAYBACK-FUNCTION-MATRIX.md](./PLAYBACK-FUNCTION-MATRIX.md)
- 当前续接记录：[2026-08-12-CONTINUE-REAL-DEVICE-DEBUG.md](./2026-08-12-CONTINUE-REAL-DEVICE-DEBUG.md)

## WDA iPhone 固化链路（2026-08-27，已在真机验证）

### 2026-09-10：iOS 16 在线状态判断纠正

不能仅凭 `devicectl list devices` 的 `unavailable` 判定这台 iPhone 离线。本轮 CoreDevice 仍显示 unavailable，`system_profiler SPUSBDataType` 也返回空列表，但 `idevice_id -l` 正常列出设备、`idevicepair validate` 通过、`ideviceinfo` 返回 iOS 16.3.1，`ios-deploy -c -t 5` 明确报告 iPhone 13 `connected through USB`。既有 tidevice XCTest / iproxy 链路随后取得 WDA ready。

对这台 iOS 16 设备，应先交叉检查 usbmux 枚举、配对、设备信息和 ios-deploy，再判断是否需要用户处理数据线或信任状态。CoreDevice 状态异常与设备物理离线分开记录；不要让单一工具误报阻止已经授权的真机安装与验证。

这条链路已在 iPhone 13 / iOS 16.3.1（UDID `00008110-001E543122E0401E`）上验证通过，未升级、重启或修改系统。WDA host Bundle ID 固定为 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`，test Bundle ID 固定为 `com.changliwen.nastart.WebDriverAgentRunner`。

- 持久化包目录：`/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1`
- WDA 包：`WebDriverAgentRunner-Runner.app`，WDA 源码版本 16.8.0
- 使用的 XCTest 兼容包：Xcode 26.6（build 17F113），设备端精确 iOS 16.3 开发者镜像
- 持久化内容还包括 `.xctestrun`、provisioning profile、iOS 16.3 DDI 压缩包和安装 receipt
- 本轮真实验证：`/status ready=true`、DS One session、`/source`、`/screenshot`；截图为 1170×2532 PNG，界面树长度约 3462 字节

以后优先执行以下脚本，不按样本或按天重装 WDA：

```sh
scripts/prepare_wda_recovery.sh
scripts/install_wda_iphone_once.sh
scripts/start_wda_iphone.sh
```

`install_wda_iphone_once.sh` 检测到设备中已有 `ProfileValidated=true` 时只做校验，不重新安装；`start_wda_iphone.sh` 使用 XCTest `tidevice xcuitest` 建立 testmanagerd 会话，再以 `iproxy 8102:8100` 暴露 WDA。只有 `ready=true` 后才开始 UI 自动化。设备必须处于解锁状态；解锁是使用 DVT/开发者服务的前置条件，不代表需要改动系统。

本轮 WDA 运行时日志保存在上述目录的 `runtime/` 下；安装摘要在 `install-receipt.txt`。若 WDA 已在 8102 端口运行，启动脚本会直接复用，不会再次安装。

## DS One PiP 自动化进入与退出（2026-08-27，已在 S03 真机验证）

PiP 的播放器入口和系统退出控件属于两个不同的 UI 会话，必须分别操作：DS One 会话只负责进入，SpringBoard 会话负责 PiP 浮窗控件。不能在 DS One 会话中直接寻找或点击系统 PiP 的退出按钮。

### 进入 PiP

1. 在 DS One 播放同一待测视频并显示播放器控制层。2.4.5 Build 4 的播放器右上角第一按钮由 XCUI 树定位为 `x=603..633, y=68..92`；优先使用元素 XPath `//XCUIElementTypeButton[@x="603"]` 获取后立即点击，不要使用失效的元素 ID。
2. 等待约 1–2 秒，保存 DS One 的 `/source` 和 `/screenshot`。进入成功的证据是主播放器窗口隐藏，树中出现 `PIPUIView`（约 `270×152`，`StartsMediaSession`），屏幕出现带视频画面的系统浮窗。
3. 不要把“按 Home 后出现浮窗”当作播放器入口按钮验证；Home 只可作为后台/PiP 行为的补充场景。优先记录真正的播放器按钮点击时间。

### 退出 PiP / 恢复全屏

1. PiP 出现后建立一个临时 SpringBoard WDA session。当前已验证的 W3C 请求形式为：

   ```json
   {"capabilities":{"alwaysMatch":{"platformName":"iOS","appium:bundleId":"com.apple.springboard","appium:noReset":true}}}
   ```

   这一步只切换 WDA 的自动化目标，不安装 WDA、不更新或重启设备。
2. 用 SpringBoard session `/source` 确认 `PIP-SBInteractionPassThroughView`，其已验证几何为 `x=110, y=47, width=270, height=152`。点击浮窗中心（约 `245,123`）显示 PiP 控件。
3. 重新读取 `/source`，不要猜坐标；系统树会暴露：`关闭画中画`、`恢复全屏幕`、`向后跳10秒钟`、`暂停`、`向前跳10秒钟`。用 XPath `//XCUIElementTypeButton[@name="恢复全屏幕"]` 获取元素并立即点击。
4. 退出成功的证据是 SpringBoard 树不再出现 `PIP-SBInteractionPassThroughView`，截图回到 DS One 全屏播放器，播放位置继续推进且没有回到 `00:00`。同时保存点击前后的 wall-clock、两个 session 的 `/source` 和截图。

### 坐标与会话陷阱

- DS One session 的 `window/size` 可能仍是横屏 `844×390`，而原始截图是竖屏 `1170×2532`；不要把截图像素直接当作 DS One 的坐标。
- PiP 控件属于 SpringBoard；DS One 树中的 `PIPUIView` 可能是 `visible=false`，这不表示 PiP 不存在。
- 自动点击失败时，先区分“控件不在当前会话树”和“元素点击失败”，不能通过重新启动 DS One 代替 PiP 退出验收。完整复现记录见 [DS One 视频播放链路证据基线](./2026-08-27-DSONE-PLAYBACK-CHAIN-BASELINE.md)。
