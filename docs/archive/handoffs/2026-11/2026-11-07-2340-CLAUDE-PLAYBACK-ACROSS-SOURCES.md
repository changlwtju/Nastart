# Claude（本地会话）：各入口播放综合调试

2026-11-08 00:30（Asia/Shanghai）。接 [TMDB 交接](2026-11-07-1840-CLAUDE-TMDB-METADATA.md)。

**授权**：用户要求用 iPhone 13、A16 iPad、新搭好的 Jellyfin，加上文件入口和 WebDAV/SMB/FTP，综合调试和优化视频音频播放。iPhone 18、TV 没有操作。

**没有提交，没有改共享状态。**

## 修复的问题

### 网络媒体库播放掉到约 2 帧/秒（已修复）

- **现象**：iPhone 13 上 SMB 和 FTP 播放时，声音和进度正常，画面中位数约 2 帧/秒，累计掉帧数百，WDA 请求也会超时。同一文件走 Jellyfin 是 24 帧/秒。
- **根因**（lldb 采样主线程，20 次里 10 次落在这里）：`NetworkLocalMediaDetail.current` 每次都线性查找库里的 2300 多个文件，比较时还要重新拼接 `DAVPath.key`，每次重算详情页要调用多次。详情页被全屏播放器盖住时仍在反复重算，占满主线程。
- **修复**：`NetworkLibrariesModel.indexedFile` 按路径建字典，`libraries` 变化时清空；海报墙跳转详情时的分组查找也改为比较 `path`。
- **结果**：FTP 从约 2 帧/秒回到 24 帧/秒，40 秒左右掉帧 4 帧；SMB、FTP 完整流程中位数约 24 帧/秒。

**未解决的部分**：详情页为什么在被盖住时持续重算，没有查明。现在只是把每次重算变便宜。

### 网络媒体库缺少“从头播放”（已加）

有进度时，详情页显示“继续观看”和“从头播放”，没有进度时只显示“播放”。之前只有一个按钮，有进度就只能续播。

- `NetworkMediaDestinations` 新增可选的 `resumeSeconds`，TV 没有传，仍是单个按钮。
- `NetworkMediaPlaybackSource` 新增 `startsFromBeginning`，主 App 用 `initialPosition: 0`。
- 英文文案已加。

### WebDAV 读取慢（已优化）

- **现象**：WebDAV 起播 3.3～9.9 秒，定位多次超过 10 秒，缓冲中位数约 2 秒。
- **原因**：每读 1 MiB 就新建 URLSession（新 TCP 连接加一次 401 认证往返）。用户地址 `lagransun.cn:5005` 在家也走公网 IP，Mac 上测单次连接约 220 ms，局域网约 4 ms。
- **修复**：`DAVPlaybackTransport` 让一次播放共用连接池；服务器要求过 Basic 后，后续请求直接带认证头（Digest 服务器不受影响）；连续读取的窗口从 1 MiB 增长到 4 MiB，每次定位重新从 1 MiB 开始。
- **结果**（iPhone 13，同一路径）：缓冲中位数约 2 秒升到 12.6 秒，帧率 24，起播 1.1～2.5 秒，普通定位约 1.4～2.9 秒。
- **注意**：密码仍经明文 HTTP 发送，和修改前一样；现在每次请求都带，修改前每次连接发一次。建议用户改用 HTTPS 或在家用局域网地址，代码没有改这一点。

## 验证结果

每项只有几次，不是预算或 P95。NAS 同时在下载（qBittorrent）和刮削（Jellyfin），部分轮次两台设备同时测，所以慢的数值可能受磁盘争用影响。“带暂停的定位”的恢复时间包含暂停时长，不算定位耗时。

| 入口 | 设备 | 片源 | 首帧 | 帧率中位数 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Jellyfin 直连 | iPhone 13 | 百变星君（HEVC 10bit） | 0.4～4.4 秒 | 24 | 定位大多 1～3 秒 |
| Jellyfin 直连 | iPad | 赌侠（HEVC 10bit） | 0.7～1.8 秒 | 24 | 音轨、字幕切换约 1.5 秒 |
| 文件入口 | iPad | 功夫（HEVC 10bit） | 0.8～2.6 秒 | 23.8 | 音轨、字幕切换约 1～1.5 秒 |
| 文件入口 | iPad | 杀死比尔 m2ts 29 GB（AVC，LPCM） | 2.1～6.0 秒 | 23.6 | 定位约 1.3～5.3 秒 |
| SMB | iPhone 13 | 赌侠 | 1.6～5.3 秒 | 23.9 | 修复后；定位多数 0.8～2 秒 |
| FTP | iPhone 13 | 赌侠 | 1.5～2.3 秒 | 23.8 | 修复后；定位 0.6～5 秒，每次读取都要重新登录 |
| WebDAV | iPhone 13 | 赌侠 | 1.1～3.9 秒 | 24 | 优化后；走公网域名；首次扫描 2292 个文件约 25 分钟 |

单元测试：`NetworkMedia` 350 项全部通过。六配置全部 BUILD SUCCEEDED。`NonPlaybackPolicyTests` 未执行。TV 只构建。

Jellyfin 硬件转码由用户在 NAS 上验证：日志有 `hwaccel vaapi` 和 `h264_vaapi`，HEVC 10bit 转 720p H264 约 8.75 倍速。

## 未解决

- **定位偶发长等待**：iPhone 13 上有一次（Jellyfin，目标 556 秒）视频解码器 7.6 秒没有输出，期间视频包积到 677 个，音频也要 4 秒才有数据。只出现一次，没有复现，也没有查到原因。
- **`first_frame` 日志经常缺失**：同一批 `sampleIndex` 也有缺号，说明是系统日志丢行，不是 App 没发。测速脚本已改为同时认 `video_frame_submitted`。
- **WDA 退出**：iPhone 13 的 WDA 中途退出过一次（`WebDriverAgentRunner quitted`），和 App 无关，原因没查。

## 未执行

- **已不在索引里的文件**：SMB 索引还有 118 个已移走的文件，点开时的提示没有测。
- **声音实听**：所有结论都来自日志和画面。音轨切换只确认事件。
- **音乐文件**：NAS 的 `music` 共享文件夹目前是空的，没有样本。
- **4K、杜比视界、DTS、TrueHD**：《碟中谍3》《好东西》《哈尔的移动城堡》目录是空的。用户说大文件下载要等。
- **iPad 上的 SMB、FTP、WebDAV**：iPad 没有配置 SMB、FTP；WebDAV 还没有扫描过，密码也可能仍失效（之前 401），需要用户本人更新。这几项的修复只在 iPhone 13 上验证过。
- **长时播放、弱网、PiP、后台**：这轮没跑。
- **TMDB 真实接口**：仍待用户粘贴令牌验证。

## NAS 现状（和播放相关）

- 用户移走了 118 个损坏文件，所以 FTP 和 WebDAV 是 2292 个，SMB 索引还是旧的 2410 个，SMB 刷新后应该一致。
- 还有 73 个可疑视频留在媒体库，用户尚未决定。
- 多个电影目录是空的，比如《The Expendables (2010)》。

## 工具

- 测速脚本：scratchpad `mx.py`（基于 `scripts/b2.py`，支持 Jellyfin 和网络库的按钮）、`q.py`（快速采帧率）、`tl.py`（时间线）。证据目录 `~/Library/Application Support/Nastart/DebugEvidence/2026-11-06-claude-nas-debug/`。
- **iPhone 13 主线程采样**：`pymobiledevice3 developer debugserver start-server --local-port 9333` 加 `xcrun lldb`（`platform select remote-ios`、`process connect`、`process attach --pid`）可用，当前 Xcode 的 xctrace 看不到 iOS 16 设备。iPad 可用 xctrace。
- WDA 的 `pymobiledevice3 syslog` 只能有一个读者，上一轮的孤儿进程会让新日志收不到内容。

## 请 Codex 处理（如果用户安排）

审查集成 `LibraryViews`、`LibraryPosterWall`、`NetworkLibraryPlaybackView`、`NetworkMediaPlaybackSource`、`SourceContext`、`LaunchpadLayoutViews`，以及这批和 TMDB 的英文文案。

## 包

dylib `4744df402a1897c3`：iPhone 13、A16 iPad 已保留数据安装。安装后回归：iPhone 13 的 SMB、FTP 和 iPad 文件入口都是约 24 帧/秒（各 20 秒左右）；WebDAV 的优化数据来自同样源码的上一个包 `b6eacb3cabbbf48d`。iPhone 18 还是 `581c5cfe68eb2f39`，不含这次修复。描述文件 2026-11-08 09:08（+08）到期。
