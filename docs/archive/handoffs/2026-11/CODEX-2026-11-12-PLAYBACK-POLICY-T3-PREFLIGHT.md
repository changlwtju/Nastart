# 2026-11-12 播放策略 T3 · iPad 预检

- 07:12:07 经当前 USB 与 CoreDevice 核 A16 iPad 名称、iPad15,7 / iPadOS 26.6、完整 UDID、配对及有线状态。签名、到期和现装路径核对 [T0 回执](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) 通过。Debug dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。HEAD `8db1cc64` 对照开工 499 个 iOS 输入均未漂移。
- 原生实图见 iPad 系统主屏、Wi-Fi 图标。现有 Nastart 进程 1，Runner 0。保留该进程，预检只读，无 App 启停、触摸、网络切换或媒体请求，随后释放占用。私有证据由 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `pad/t3/`。
- 已请用户手动从已保存的 SMB 媒体库进入 S19《护戒使者》详情并停在那里。iPad `network.library.source` 为手动入口。用户打开后重新登记设备，连接现有普通 App 会话，确认内网路径，逐步保存起播、续播和前后 15 秒诊断，随后同窗跑 HTTP 30 秒。三项正式读数待采。
- 无产品代码或参数修改。现有 Reader 报告与路线复算脚本测试各 6 项通过。

## 07:24，WDA 入口复核

按用户要求复用已核签的 iPad Runner 和现有 Nastart，WDA 实际打开「存储与媒体」。当前页面的已保存 SMB 媒体库通过 `network.library.source` 进入，源码也只在该处构造对应的 `NetworkLibraryFilesView`；「浏览文件」是设备文件，「连接管理」的文件夹行是编辑入口。未合成点击来源行，未发出 SMB 播放。保存了每步诊断、页面树和实图。用户已收到一次针对原限制的明确确认请求。

07:26 用户明确授权本次及后续调试均可由 Codex 自行用 WDA 操作该行。已同步项目指令和远控手册。

07:28 WDA 对已确认的「我的 SMB」行完成短点，实际进入海报库。中文 `护戒使者` 和英文 `Fellowship` 均无匹配。只读检查本机媒体索引，已存 SMB 库 2,292 个文件中没有对应文件名或精确长度；原 3 库、4 连接的完整基线已私存。07:30 已退出第一段 WDA，会话与 Runner、转发收尾核对通过。T3 正式窗使用同一已保存连接下的单影片临时本机索引。

07:32–07:35 单影片目录准备首试。通过已有 SMB 连接到达「添加媒体文件夹」，首次 WDA 页面树超时，自动化未提交 `network.folder.select` 或播放。收尾发现新增一项空的 SMB `media` 本机索引，原 3 库和 4 连接逐项相等。该索引来源未确认，保留它并把当前 4 库作为重试基线。CoreDevice 进程查询超时，07:35:37 以 RSD 核本轮精确 App PID 和路径，保存诊断后结束该进程，确认 App/Runner 均为 0、转发与采集已结束。证据在 `pad/t3-reads/`。

## 大文件、杜比视界和 ISO 覆盖核对

- 当前有精确长度实证的 100 GB 以上压力样本为 128,795,641,934 字节的 S19 MKV。历史还有约 50–54 GB 的 S03 MKV 和《杀死比尔 2》38,626,369,536 字节的 H.264/LPCM M2TS。后者 WebDAV 有实图且见缓冲，历史跳转未获恢复；两部当前可达性均待复核。V7 可先核固定样本 TV04（历史元数据 24.8 Mbps）是否仍在库中。大文件压力扩展优先选接近 S19 体积、码率及时长的 M2TS/BDMV 片源，尽量同片或条件接近。覆盖参见 [功能矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md) 与 [M2TS 真机记录](../2026-10/2026-10-28-PLAYBACK-ROUTE-SELECTION.md)。
- iPad 已存 SMB 索引的整理时间为 11-08 07:26。索引内最大两项是《杀死比尔 2》38.63 GB 和《杀死比尔 1》31.61 GB 的 M2TS；其余已知容量低于 14 GB，未收录 ISO 或 ≥100 GB 文件。这是本机索引清单，另有 S19 的真实设备文件证据。
- S19 已识别为 Dolby Vision P7，历史原画可出画；实际显示走杜比视界还是 HDR10 底层仍无验收证据。P5 候选 TV05《繁花》S1E23 历史元数据已确认、待核可达与实播；P8 待选并核验。实际输出按 P5、P7、P8 分别取显示路径证据。 [S19 真机记录](CODEX-2026-11-08-LORD-OF-THE-RINGS-PLAYBACK.md)
- 历史《变形金刚》真实 ISO 已在 Jellyfin 和设备文件做过主标题、续播和字幕专项，存在续播等待。现装包未重跑 ISO，当前可达性未核。网络媒体库详情对 ISO 不提供原生播放；ISO 专项先验 Jellyfin 与设备文件的真实镜像、主标题、Range、跳转、音字幕和退出。 [历史 ISO 真机记录](../2026-10/2026-10-08-ISO-AUTO-SUBTITLE-LIFECYCLE.md) · [现行播放管线](../../../architecture/VIDEO_PLAYBACK_PIPELINE.md)

用户愿意少量补样。下载清单建议两份：60–90 GB 单文件 M2TS，优先 4K HEVC、HDR10、双音轨和 PGS；25–50 GB 可直接读取的蓝光 ISO，优先 1080p H.264、章节、双音轨和 PGS。易取得时可补一段已确认 Dolby Vision P8.1 的 HEVC MP4 短片。P7 继续用 S19，P5 先复核现有 TV05。
