# 双入口播放与服务浏览修复（2026-09-13）

关联任务：PX-01/PX-02/PX-03/PX-04/PX-20、UX-03/UX-04。用户指定 S19《指环王1》优先，其他待办保留在唯一总账，不用本轮验证替代 19×4 矩阵。

## 产品取舍

- 当前 Jellyfin 新架构默认是自动路由、条件满足优先原画，并非固定原画。内网或通过带宽/解码兼容判断时使用原文件，否则服务端 HLS。设备文件/Jellyfin 原画已经共用 Range 注册、计划与 KS 渲染器，但鉴权准备、字幕选择及上游服务仍有差异。
- 按 9 月 13 日用户要求，新架构收起手动清晰度按钮。保留自动路由、必要兼容回退及内部换流能力；手动切换待同片服务端准备/交接实测达标再恢复，不宣称丝滑。

## 本轮代码

- 服务 WKWebView 改用独立全屏 NavigationStack；底部网页操作栏改为 safeAreaInset，避免推入父导航栈时同时改变 tabBar/bottomBar 可见性。保留顶部关闭/返回、网页菜单、版本切换、简洁浏览。系统浏览器继续原有路径。
- 详情页在 Wi-Fi/私网提前做原文件两字节鉴权探测，播放复用同一条短期结果，不打开解码器或转码会话，不改带宽/原画条件。进度与鉴权仍由 Jellyfin 提供。
- 保留解码器已启用的字幕，连接字幕模型时不先禁用再启用。注意 KS 默认 `isSeekImageSubtitle=false`，因此不能将本项声称为 S19 MKV 首帧空档的已证根因；它避免启用切字幕定位路径时的重复 seek。
- 音频格式切换移除旧 AVAudioSourceNode，串行维护用户播放意图，丢弃过期格式任务；处理 AVAudioEngineConfigurationChange，在系统自动停机后异步恢复仍应播放的引擎，用户暂停时不擅自启动。
- 外置文本字幕缓存当前会话最近四轨，取消向下传递至下载任务，检查最后选择，失败可重试。新架构服务端换轨保留最后待处理选择，释放被后续选择替代的准备资源。

## 已有证据与失败

本地目录 `tmp/playback-20260913/`；日志含设备和认证上下文，仅留本地。

- 服务基线：旧包点击 Homepage 的“App 内打开”后 WDA 页面采集超时。两份 12:06 系统报告是 SwiftUI/AttributeGraph 布局栈上的 watchdog 退出。调试器启动产生的 12:11 SIGTRAP 单列，不能混为服务卡片崩溃。
- 修复包：Homepage 打开，菜单可操作，简洁→展开→简洁后关闭，回到服务详情再返回启动台，TabBar 正常；证据 `fixed-homepage-open.png`、`browser-{expanded,compact-restored,returned-detail,returned-home}.xml`。Homepage 网页自身数据仍显示 Updating，不视为第三方服务所有功能已验收。Jellyfin 系统浏览器也能打开、关闭并进入媒体库。
- 首次 S19 修复包续播 trace `84BDFFAB`：约 5974.418 秒，原画 TrueHD/PGS 8，原文件总长 128795641934；详情探测复用，点击后仍等 416 ms 测速，准备 429 ms。播放器 `first_frame=2978 ms` 是播放时钟口径；renderer submission PTS 5974.385、截图 `s19-resume-start.png` 有画面与双语字幕。不可将它冒充摄像头测得的点击到屏幕首帧。
- 本次线路为公网 IPv4 / HTTP2 / Wi-Fi；首个原文件请求新建连接，TCP 80 ms、TLS 13 ms、requestMs 317 ms。后续读取尾部索引、片头探测、断点簇；数据不足以断言全部零速空档由某一阶段造成。设备入口配对结果待补。
- 同 trace 首次 TrueHD→DTS→TrueHD 在 6031.6 秒处复现停钟，缓冲已完成而播放未推进；暂停/播放后恢复。此失败推动补充引擎配置通知恢复，不能将首轮节点释放修复标为切轨通过。
- 首轮 71 项测试通过；增加引擎配置通知恢复后测试通过（最终数量与真机结果下方追加）。播放库链接隔离、app/framework/dylib 分别签名核验通过。前次 `/tmp` 源码缓存被清理，改复用完整 SourcePackages 和持久 DerivedData 后构建成功；未回退业务修改。

技术依据：Apple 明确指出硬件通道数或采样率变化会停止并反初始化引擎，应用需处理配置变化，且不要在通知内部队列同步销毁引擎：[AVAudioEngineConfigurationChange](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange)。Jellyfin 格式不兼容和烧录字幕可触发服务器转换：[Codec Support](https://jellyfin.org/docs/general/clients/codec-support/)。

## 后续音轨与字幕修正

- 音频配置恢复包：72 项测试通过。S19 trace `B92C11FA` 原画续播 6185.33 秒，准备 123 ms，`first_frame=2445 ms`（播放时钟口径）。TrueHD/AC3/DTS 九次交替，节点数量保持 4；配置通知后记录 `recovered running=true`，后续时钟持续推进。切换中仍有短暂缓冲，不能写成零卡顿或实际听音通过。
- 压测截图发现切回 PGS 后同时显示多条旧台词，未将首轮字幕切换判为通过。位图字幕改为原子消费当前时间以前的显示组，只保留最新一组（包含清屏）；释放跳过的旧帧，避免无限结束时间的旧字幕叠加。
- 用户反馈字幕小：原覆盖层按视频分辨率缩放位图，遗漏字幕独立画布；新增解码器画布尺寸传递，全屏和 SDR PiP 按字幕画布换算。多个位图矩形合成时裁掉外围透明区域，并保存原位置。未提供手动字号滑杆，PX-08 的偏好/重置要求继续保留。
- 切入未启用的 PGS 轨道，通过已有播放器定位流程补读当前位置；保留暂停状态和完成回调代次检查。已启用的初始轨道不额外定位。
- 最终字幕修正包 74 项播放/非播放测试通过，设备构建、独立签名、播放库链接检查及 preflight 通过。日志 `/tmp/nastart-20260913-subtitle-{tests,device}.log`。真机屏幕回归在下方追加。

## 字幕包真机回归与入口差异

- 最终字幕包 iPhone 13 / iOS 16.3.1：S19 文件原流与 Jellyfin 原流均核对 Content-Range 总长度 128795641934。设备完整路径为 `/video/media/movie/The Lord of the Rings - The Fellowship of the Ring (2001)/The.Lord.of.the.Rings.The.Fellowship.of.the.Ring.2001.Extended.Edition.UHD.BluRay.Remux.2160p.HEVC.DoVi.HDR.TrueHD.7.1-CMCT.mkv`。
- 文件入口 `ABA6CEB0` / `AE18BDDC` 从头、默认字幕关闭，播放时钟首帧分别 1462 / 907 ms。前者远距离定位到 6267.146 秒，完成回调 529 ms；暂停定位到 6316.332 秒，454 ms。后者并非续播：退出重开回到 0，且字幕也回到关闭。这是已确认的双入口功能缺口，不计入续播对照。
- Jellyfin `8E28553B`，默认 TrueHD 1 / PGS 8，6578.8 秒续播，准备 123 ms、时钟首帧 2005 ms；`82041BEA` 在约 6183.4 秒续播，时钟首帧 3073 ms。两者都走原画，不能与文件从头、无字幕成绩直接计算优化比例。
- 新包再次进行九次 DTS/TrueHD/AC3 与 PGS 9/关闭/PGS 8 交替。PGS 补读完成回调 79～233 ms；过程中有短缓冲，切完后时钟继续推进。证据 `final-stress-steps.json`、`s19-final-stress-end.{xml,png}`。
- 暂停切 PGS 后按钮仍为“播放”，定位后仍暂停。播放恢复后 `s19-final-dialogue.png` 显示一组清楚的中英双语台词，没有此前多句旧字幕叠加；字幕保持片源颜色。`s19-files-subtitles-visible.png` 保留片头多区域人物标注。截图不证明全部字幕时刻及实际音频输出。
- 暂停定位后立即退出，还暴露 Jellyfin 停止上报沿用旧播放回调位置。补充退出时传入控制器当前位置，覆盖 tracker 中的旧断点，并测试 0 秒、前跳/后跳及重复 stop；最终构建/回归结果下方补记。
- 原流的网络路径仍有差别：DSM HTTPS 5001、Jellyfin HTTPS 8097；同时首播字幕策略、断点信息不同。两入口虽共用 Range 和 KS，但不能把“零下载速度”全部归咎于 Jellyfin，也不能仅靠去掉清晰度菜单保证同速。当前尚缺严格同轨同点冷/热交替矩阵。
- 诊断注意：普通 idevicesyslog 在本次捕获中停在旧时间点，后续改用 `--syslog-relay`，证据 `final-relay.log`；不能把日志无新增视为应用没有播放。

## 最后构建

75 项播放/非播放回归通过；`/tmp/nastart-20260913-final-tests.log`、`/tmp/nastart-20260913-final-device.log`、`/tmp/nastart-20260913-final-preflight.log`。最终 app/Framework/dylib 签名和 FFmpeg 链接检查通过，已覆盖安装到原 iPhone，保留应用数据；安装记录 `tmp/playback-20260913/install-final.log`。

## 尚未验收

S19 两入口同轨同位置的重复首播/深位置退出续播、最终包压力切轨后的实际声音与字幕、iPad 与双设备、10 分钟稳定性；PX 及 UX 其余项全部保留。单元测试、菜单选中和时钟推进均不替代实际听音或屏幕字幕完整性验收。

## 继续推进 PX-21

- 设备文件增加本地断点与轨道保存：按 NAS 配置主端点、账号、完整路径、字节数和修改时间计算身份摘要；不持久化认证 URL/SID。最多保留 128 条，忽略非有限时钟；播放结束后下次从头开始并保留轨道偏好。
- 新架构播放每 15 秒及关闭/进入后台时保存，未就绪或定位未完成不写入。设备“预览”在存在断点时显示“继续观看”，另有“从头播放”；后者只重置位置，保留音字幕。Jellyfin 有断点时也增加显式“从头播放”，通过零进度副本准备请求，不先修改服务端观看状态。
- 78 项测试覆盖账号/文件/版本隔离、认证参数不入身份、存储重开、容量上限、无效时钟、结束处理、轨道恢复、显式从头优先以及 Jellyfin HLS 不受本地恢复影响。日志 `/tmp/nastart-20260913-local-resume-tests.log`。Jellyfin 显式入口后的回归与实机结果继续追加。

### PX-21 首轮真机证据

设备文件 `D0ED59F7` 从 6311.8 秒恢复，菜单确认为国语 DTS 3；`D8AD2323` 点“从头播放”回到 0 秒，音轨 TrueHD 1、PGS 8 保留，时钟首帧 1224 ms。前者时钟首帧 5863 ms，慢样本保留，不以原先无字幕从头的速度替代续播。

第一次在音轨切换后马上暂停并定位，4 秒内尚未取得定位完成回调便退出，记录保护逻辑保留了此前有效断点；截图 `file-bookmark-before-exit.png` 的进度条已到 1:44:27，但画面仍在片头。这次不能作为完成定位后恢复失败，也不能宣称“所有定位已快速完成”。随后稳定播放时同目标定位 660 ms，画面抵达会议场景，证据 `file-resume-seek-settled.png`。切轨、暂停与定位连续组合的尾部延迟继续归 PX-02/PX-20。

截图和菜单证据：`file-bookmark-confirmed-resume.png`、`file-bookmark-confirmed-audio.xml`、`file-bookmark-from-head.png`、`file-bookmark-head-subtitle.xml`。78 项最终回归和设备构建通过：`/tmp/nastart-20260913-entry-parity-{tests,device}.log`。同组字幕全部台词/实际听音仍待验收。

### 详情页断点与退出崩溃追查

- 当前详情页增加停止位置快照，在本次播放退出后立即采用最新位置，无须等服务端重新加载。78 项回归、正常设备构建及覆盖安装通过：`/tmp/nastart-20260913-detail-progress-{tests,device}.log`，`install-detail-progress.log`；详情页真机连续重开仍待验证。
- Jellyfin `F0ED2028` 从头 0 秒，TrueHD 1 / PGS 8 / 原画，准备 244 ms、时钟首帧 1605 ms。文件此前对应一次为 1224 ms；两轮间隔较长，只保留单次观测，不计算中位数或改善比例。
- 20:44:41 退出后出现进程重启，复制系统报告确认 `EXC_BAD_ACCESS / SIGBUS`，后台 `JSONDecoder.decode` 析构字典时访问 `0x0000003000000000`。12:41:18 报告也在 JSON 解码字典桥接中访问同一地址。与 12:06 服务网页 SwiftUI watchdog 分开记录，根因未定，不能将栈顶 JSONDecoder 直接视为内存破坏源。
- 报告保存在 `tmp/playback-20260913/crashes-latest/`。内存诊断构建使用独立 `/tmp/NastartPlaybackASanDerived`，显式补充 C 包 ASan 链接参数后构建及签名通过；日志 `/tmp/nastart-20260913-asan-device.log`。该包仅用于诊断，不计入首帧性能样本。

### 用户要求推送时的检查点

用户在内存诊断期间要求将最新项目推送 main，暂停真机操作。正常构建已通过 78 项测试、设备构建、签名/链接检查与 preflight。诊断包已安装，随后显式终止并重启应用以确保加载新包；重启后的退出压测尚未完成。此前 `B055B116` 可能仍属于覆盖安装前保留的旧进程，不视为 ASan 阴性证据，不能据此验收最新详情快照。恢复任务先完成崩溃捕获，再覆盖回正常构建进行性能对照。

本次推送包含应用与本地 KSPlayer 修改、测试及任务总账；下载第三方源码时附带的未使用 Demo、上游工作流和文档留在本地。依赖锁恢复为与全部 11 个已测试 checkout 完全一致的版本。临时日志、认证上下文、签名材料及安装包位于被忽略的 tmp 目录。
