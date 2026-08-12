# Nastart 18 部共同电影样本与真机验证矩阵

更新时间：2026-08-12

## 样本规则

本轮基础矩阵固定为同一 18 部电影，分别从以下四个单元播放：

1. iPhone → 设备文件
2. iPhone → Jellyfin 媒体库
3. iPad → 设备文件
4. iPad → Jellyfin 媒体库

因此基础播放单元为 18 × 4 = 72。iPhone 还要在 Wi‑Fi/域名、Wi‑Fi/IP、蜂窝/域名等实际可达链路重复验证；iPad 覆盖 Wi‑Fi/域名和 Wi‑Fi/IP。链路重复不替换基础样本。

## 冻结的 18 部共同样本

| ID | 设备文件入口的实际文件/目录 | 已确认容量/格式特征 | Jellyfin 对应条目 | 覆盖目的 |
|---|---|---|---|---|
| S01 | `/video/media/movie/[哈尔的移动城堡].Howl s.Moving.Castle.HDTV.720p.x264.AC3-CMCT` | 2.7 GB；MKV；720p；H.264 | 哈尔的移动城堡（2004） | 小文件、720p、H.264 |
| S02 | `/video/media/movie/[杀死比尔].Kill.Bill.Vol1.2003.Blu-ray.1080p.AVC.LPCM5.1-CMCT` | 1080p；AVC；LPCM 多声道 | 杀死比尔（2003） | 1080p、AVC、无损音频 |
| S03 | `/video/media/movie/碟中谍3 4K原盘REMUX [杜比视界] [国英双语] [内封简英双字]` | 50 GB；MKV；2160p；DV；HEVC；TrueHD | 碟中谍3（2006） | 超大 REMUX、HDR、HEVC、多音轨/ASS |
| S04 | `/video/media/movie/好东西.Her.Story.2024.2160p.WEB-DL.H265.HQ.DTS5.1-HHWEB` | 17 GB；MKV；2160p；HEVC | 好东西（2024） | 大文件、4K WEB-DL、HEVC |
| S05 | `/video/media/movie/南方车站的聚会 (2019)` | 1080i；H.264；实际文件名含 `HDTV.1080i.H264` | 南方车站的聚会（2019） | 交错扫描、H.264 |
| S06 | `/video/media/movie/B for Busy (2021)` | 12 GB；MKV；2160p；HEVC；DDP5.1 | 爱情神话（2021） | 4K、HEVC、多声道 |
| S07 | `/video/media/movie/Black Coal, Thin Ice (2014)` | 11 GB；MKV；1080p；H.264 | 白日焰火（2014） | 中大文件、1080p、H.264 |
| S08 | `/video/media/movie/Black.Panther.Wakanda.Forever.2022.2160p.Pad-HDR.UHD.BluRay.AAC.2Audio.x265-10bit-HDSPad` | 5.2 GB；MP4；2160p；HEVC；HDR；双音轨 | 黑豹：瓦坎达万岁（2022） | MP4、4K、HDR、相对小容量 |
| S09 | `/video/media/movie/Castle in the Sky (1986)` | 12 GB；MKV；1080p | 天空之城（1986） | 动画、1080p、中大文件 |
| S10 | `/video/media/movie/Doctor.Strange.in.the.Multiverse.of.Madness.2022.1080p.BluRay.x265.10bit.DTS-WiKi` | 7.2 GB；MKV；1080p；HEVC 10-bit | 奇异博士2：疯狂多元宇宙（2022） | 10-bit HEVC、1080p |
| S11 | `/video/media/movie/Fantastic Beasts and Where to Find Them (2016)` | 16 GB；MKV；2160p；HEVC 10-bit；TrueHD 7.1；双音轨 | 神奇动物在哪里（2016） | 4K、10-bit、TrueHD、多音轨 |
| S12 | `/video/media/movie/Fantastic Beasts The Crimes of Grindelwald (2018)` | 5.3 GB；MKV；1080p | 神奇动物：格林德沃之罪（2018） | 1080p、中小容量 |
| S13 | `/video/media/movie/If You Are the One (2008)` | 4.8 GB；MKV；1080p | 非诚勿扰（2008） | 小容量、1080p |
| S14 | `/video/media/movie/Infernal Affairs (2002)` | 12 GB；MKV；1080p | 无间道（2002） | 中大容量、1080p、多音轨候选 |
| S15 | `/video/media/movie/Oppenheimer (2023)` | Jellyfin 显示 3h；大容量/长时长样本 | 奥本海默（2023） | 长时长、长时间缓冲/拖动 |
| S16 | `/video/media/movie/Project A (1983)` | 电影文件；Jellyfin 显示 1h45m | A计划（1983） | 老片、短时长、断点/拖动 |
| S17 | `/video/media/movie/Project A Part II (1987)` | 电影文件；Jellyfin 显示 1h46m | A计划续集（1987） | 与 S16 同系列对照 |
| S18 | `/video/downloads/movie/[方世玉续集].The.Legend.of.Fong.Sai.Yuk.2.1993.GBR.BluRay.1080p.x264.FLAC.2.0.2Audios-CMCT` | 1080p；H.264；FLAC 2.0；双音轨 | 方世玉续集（1993） | H.264、FLAC、多音轨、设备文件另一目录 |

文件名、路径、容量和格式均以真机设备文件页面或 Jellyfin 文件信息页面为准；不能从标题推断的字段在播放首轮补采集，不以猜测替代证据。

## ISO 专项

目前已检查 `/video`、`/video/media/movie` 和 `/video/downloads/movie` 的可见文件入口，并在 Jellyfin 搜索中查询 `ISO`，没有找到可重复打开的 ISO 电影样本。ISO 不会被伪造为 18 部共同样本中的某一部。

一旦 NAS 上出现可访问 ISO，将增加独立 ISO 专项：优先 Jellyfin 入口，检查 ISO9660 主标题、Range 读取、首帧、拖动、音轨/字幕和断点；若设备文件入口也能直接打开，再增加四入口对照。当前 ISO 能力只能标记为“样本缺失，未验证”。

## 每个播放单元的验收项

- 首帧时间、是否出现“速度归零/像在下载”的长等待、是否黑屏或启动即暂停。
- 连续播放是否卡顿、缓冲是否恢复、是否崩溃或退出播放器。
- 快进、快退响应时间，以及是否保持绝对时间点。
- 普通暂停/继续的断点位置。
- 字幕切换、音轨切换：响应时间、画面是否重置、是否从头播放。
- Jellyfin 清晰度切换：切换后继续播放且保持时间点。
- Jellyfin 画中画进入/退出，以及 PiP 中断点续播。
- 实际连接链路：iPhone Wi‑Fi/域名、Wi‑Fi/IP、蜂窝/域名；iPad Wi‑Fi/域名、Wi‑Fi/IP；不可达组合记录为链路不可达，不记为播放器失败。

未完成、链路不可达、样本缺失和真机工具失效均单独记录，不计为通过。
