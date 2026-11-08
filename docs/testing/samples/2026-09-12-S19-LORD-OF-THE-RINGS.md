# S19《指环王 1》大文件播放专项

用户于 2026-09-12 指定加入测试矩阵，报告文件超过 100 GB。状态：样本已登记，正在核实规格及可达入口；未取得证据的字段保持未知。本轮优先测试该文件，保留 S01～S18 的未完成项。

## 样本身份

| 字段 | 值 / 证据 |
| --- | --- |
| 样本 ID | S19 |
| 用户提供片名 | 指环王 1；Jellyfin 确认为《指环王1：护戒使者》（2001） |
| 用户报告容量 | 100 GB 以上；Jellyfin 文件信息显示 **128.8 GB**，精确字节数待原流响应核对 |
| NAS 实际路径 / 文件名 | `The.Lord.of.the.Rings.The.Fellowship.of.the.Ring.2001.Extended.Edition.UHD.BluRay.Remux.2160p.HEVC.DoVi.HDR.TrueHD.7.1-CMCT.mkv`；DSM 完整路径待核实 |
| Jellyfin item / media source / 路径 | 待核对，与设备入口必须为同一版本同一文件 |
| 文件稳定性 | 待确认下载完成，测试前后文件字节数不变 |
| 时长、容器、视频编码、分辨率、位深 | 详情页 3h48m、MKV、4K H.265 HDR；位深待实际轨道核实 |
| 平均 / 峰值码率 | 服务端源码率 **81,851,565 bps**（界面 81.9 Mbps）；峰值未知 |
| DV Profile / 基础层 / HDR | Jellyfin 结构化诊断：DV Profile 7、Level 6、基础层兼容 ID 6；不是实际输出验收 |
| 音轨与字幕清单 | 默认流 1：English TrueHD + Dolby Atmos 7.1，历史结构化 AudioSpatialFormat=DolbyAtmos；流 2：AC3；默认字幕流 8：Chinese (Simplified)&English PGSSUB。2026-11-08 [真机音轨菜单](../../archive/handoffs/2026-11/CODEX-2026-11-08-LORD-OF-THE-RINGS-PLAYBACK.md)另外确认流 3 为普通话 DTS，未切轨或听音；其余轨道待补齐。 |
| 当前应用版本 | 第一批原流探测并行 + 限制性 Wi-Fi 测速复核；34 项播放测试通过，真机待验证 |

## 四入口状态

状态：U 未测、P 通过、F 失败、N/A 不适用、NA 不可达、TOOL 工具失效。每个 P 必须关联运行记录和证据；菜单存在不代表切换成功。

| 验收项 | iPhone 设备文件 | iPhone Jellyfin | iPad 设备文件 | iPad Jellyfin |
| --- | --- | --- | --- | --- |
| 入口及文件身份 LIB | U | U | U | U |
| 从头首帧 FF | U | U | U | U |
| 深位置退出再续播 EX | U | U | U | U |
| 连续播放 ST | U | U | U | U |
| 暂停/恢复 PA | U | U | U | U |
| 邻近 / 远距离定位 SK | U | U | U | U |
| 音轨切换 AT | U | U | U | U |
| 字幕切换 SU | U | U | U | U |
| 真实字幕 / 可听声音 SA | U | U | U | U |
| 自动画质及手动往返 Q | N/A | U | N/A | U |
| PiP 完整往返 PP | U | U | U | U |
| 内存、断流、进程稳定性 MEM | U | U | U | U |

## 操作与计时

1. 固定设备、系统、安装包、网络路径、文件、音轨、字幕和起始位置，记录当前 NAS 负载；自动模式若进入 HLS，单独列组，不能与设备原画混算。
2. 从头播放分别测冷客户端与重复打开；t=0/3/10/30 保存实际画面。播放器时钟与渲染器提交时间单列，不能代替屏幕首帧。探索性每组至少 3 次，记录中位数及范围；不从 3 次计算可靠 P95。
3. 在时长约 10% / 50% / 90% 处暂停、退出播放器、重新打开；再执行一次正常退出 App 后重开续播。记录请求位置、实际首帧位置与误差，不能用播放中 seek 冒充退出续播。设备文件若未实现进度保存，按真实产品缺口记 F 并关联 PX-01/PX-02，不将从头打开当作续播通过。
4. 分别测试 ±15 秒、20%→80%、80%→15% 和未访问过的位置；区分首次读取与重复定位缓存命中。播放中和暂停中各测，检查恢复后音画同步。
5. 在非零时间点切换所有可用音轨，覆盖有损/无损组合；确认音轨实际变化、声音连续、无意外回到片头。记录切换耗时和输出路由，听音证据不足保持 U。
6. 切换所有可用字幕及关闭/恢复；找到自然对白段观察双语、ASS/PGS/文本等实际存在的格式，检查乱码、重复、残留、裁切和同步。没有某格式时记缺样本，不伪造覆盖。
7. Jellyfin 测自动实际选流、原画→20 Mbps→12 Mbps→原画，以及暂停时换流；按当前可用档位调整并记录。分开记录请求准备、服务器首片、候选解码、对齐和交接完成，旧流是否持续播放、绝对时间/暂停状态/音字幕是否保留。自动化不承诺秒切。
8. 至少连续 30 秒，并补一段 10 分钟稳定性观察；记录缓冲、Range 跨窗口/大于 4 GiB 偏移、真实完整长度、短 EOF/重试、内存和 Jetsam。100 GB 文件不能整部下载到内存来换取单样本通过。
9. 补充 PiP 启动、返回主屏幕、恢复全屏和关闭；HDR 字幕与 DV/Atmos 输出证据单独记录。S19 即使包含杜比，也不能替代其他 Profile / 音频格式样本。

## 本轮记录

- 自动化/构建基线：`/tmp/nastart-20260911-cache-tests.log`（34 passed）、`/tmp/nastart-20260911-cache-device.log`、`/tmp/nastart-20260911-cache-preflight.log`。签名已对 app 及全部 3 个 dylib 单独核验，FFmpeg 链接隔离通过。
- 设备连接：USB 检出 iPhone 13（`REDACTED-DEVICE-01`），复用 WDA，`/status` 为 ready；仅表示工具可用，不代表 S19 播放通过。
- 本轮工作目录：`tmp/playback-20260912/`。安装、样本规格、测试数据和异常在下方追加；暂停/中断后先读此记录继续，不能遗忘未测项。

### 首帧差异定位（正在回归）

- 用户手动播放日志 `s19-manual-baseline-diagnostics.json`，trace `DE38AC64`：起点 0；实测 Wi-Fi 原始带宽 95,387,406 bps，保守转码预算 76,309,924 bps，但原画预算被固定上限截断至 80 Mbps，低于源 81,851,565 bps，`largeRemoteOriginalRisk=yes`，进入 20 Mbps HLS。请求准备 1304 ms，播放器首帧时钟事件 11250 ms；后者不是从点击到屏幕呈现的完整计时。用户同时报告设备文件明显更快，尚无该次设备首帧日志可严格配对。
- 修复 1：Greenfield Wi-Fi 原画以成功实测原始吞吐为预算，不继承转码固定上限，也不乘 1.25 放大；大文件守卫与原画选择共用同一预算。蜂窝、失败测速、未知网络保留保守策略，明确低档位继续转码。
- 首轮修复包仍暴露另一问题，trace `CA2AEB80`：`bandwidthWait=0`，使用 Wi-Fi 8 Mbps 默认预算进入 HLS；586 ms 后实际 Wi-Fi 测速才完成（57.17 Mbps）。代码中等待和调度分别读取网络快照，初始 unknown→Wi-Fi 时可等待错字典 key。这个样本的实际吞吐也不足以证明原画可稳定播放，不能仅凭取消上限强制判定原画可用。
- 修复 2：媒体库建立时提前启动网络观察；测速调度与等待共用捕获的网络快照；`bandwidthWait` 补充 network 字段用于核对。两项修复最终代码已通过 36 项播放测试、设备构建及 preflight；日志 `/tmp/nastart-20260912-network-snapshot-{tests,device}.log`、`/tmp/nastart-20260912-snapshot-preflight.log`。
- 修复包的真机原画、连续播放、深位置续播和各项切换仍须补齐；不能将构建通过或策略测试通过记为 S19 功能通过。文件信息证据 `tmp/playback-20260912/s19-file-info.xml`；实时播放诊断 `tmp/playback-20260912/live.log`。

### 网络快照修复包：已回收的单次原画记录

- 导出 `tmp/playback-20260908/s19-snapshot-final-diagnostics.json`，trace `0736113E`。原始实测 108,492,782 bps，等待 360 ms，原流探测 364 ms 与测速重叠；原画预算 108,492,782 bps，`largeRemoteOriginalRisk=no`，最终 `jellyfinOriginalDirectPlay` / `localRangeProxy`，准备 396 ms。
- 首帧时钟事件 `tapToFirstFrameMs=1550`，`firstFramePositionSeconds=0.094`。这是播放器事件口径，不是摄像头测得的点击到屏幕首帧，也不能和准备时间未经核对直接相加。此前误进 HLS 的单次事件为 11250 ms；两次测速不同，不能当成受控 A/B 改善百分比。
- 上游 Content-Range 确认文件精确长度 **128,795,641,934 bytes**，能读取文件尾部索引。片源 DV P7、10 bit，TrueHD 解码 PCM；实际 Dolby Vision/Atmos 输出仍为 unverified。
- 结论：取消错误上限与统一网络快照后，这次大文件自动原画成功，支持继续同条件对照；PX-01/PX-02 仍进行中，深位置续播、音轨字幕/画质切换及持续稳定性不因这一条记录自动通过。

### 本地 PGS 与切轨优化（2026-09-12 后续批次）

- 旧包基线 `s19-track-prior-errors-diagnostics.json`：当前测速 51.79 Mbps，低于源 81.85 Mbps，使用 20 Mbps HLS 有带宽依据，不属于上轮 80 Mbps 固定上限错误。trace `6D70C91E` 在约 54:47 选择 PGS 8，进入新的服务器烧录会话。trace `2482A78C` 明确选择原画仍被 `requiresBurnIn` 拒绝，界面出现“无法准备播放”，已复现。
- 修正：Greenfield 查询已链接的 PGS/DVD/DVB 字幕解码器，能本地解码时不要求服务端烧录，也不为首帧关闭所选字幕；保留未知/未确认格式的原有回退。KSOptions 增加可选内嵌字幕 ID，在首包读取前启用指定轨道，默认 nil 不改变其他调用方。
- 同一音轨/字幕重复选择不重复调用引擎；音轨切换保留不变的字幕，关闭字幕和新会话重新应用仍有效；外置字幕无需在容器字幕清单中匹配 ID 才能留在原画。新增分发耗时与当前字幕 parts 诊断，明确不是实际声音恢复或屏幕呈现耗时。
- 详情页读取完成后提前调度已有的有界测速，仍复用网络/源码率缓存规则，不提前创建代理或解码器。
- 39 项播放测试通过：`/tmp/nastart-20260912-tracks-tests.log`；设备构建与 preflight 通过：`/tmp/nastart-20260912-tracks-{device,preflight}.log`。已独立签名验证 app/所有 dylib，并安装 `tmp/playback-20260912/Nastart-Tracks.app`，日志 `install-tracks.log`。真机回归记录在下方追加；当前不将 S19 整组改为通过。

### 2026-09-13 继续：入口一致性与压力切轨

用户再次要求以 S19 对齐设备文件/Jellyfin；手动清晰度暂缓，新架构收起入口。续播、首帧分阶段证据和已复现的切轨停钟见 [9 月 13 日修复记录](../../archive/handoffs/2026-09/2026-09-13-ENTRY-PARITY-AND-WEB.md)。原 19×4 未测项不变，不因代码通过标为整组通过。
