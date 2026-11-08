# Claude（本地会话）：网络存储接入共享播放链路的方案（只读调研）

2026-11-08 01:00（Asia/Shanghai）。接 [各入口播放调试](2026-11-07-2340-CLAUDE-PLAYBACK-ACROSS-SOURCES.md)。

**用户原则（11-08）**：播放链路按网络环境区分，不按入口区分。同一网络环境下，Jellyfin、设备文件、SMB、FTP、WebDAV 用同一条链路，只有“怎么拿到字节”这一层不同。FTP、SMB 只在内网使用。

**本轮只读代码，没有改代码，没有提交，没有改共享状态。**

## 现状（读代码和 11-07 日志得出）

| 层 | Jellyfin、设备文件 | SMB、FTP、WebDAV |
| --- | --- | --- |
| 入口取址 | 各自解析出 HTTP 地址 | `NetworkLibraryPlaybackView` 起一个本地桥接 `WebDAVPlaybackSession`，读取器把各协议转成 HTTP |
| 共享代理 `AuthenticatedMediaStreamProxy`（`DevicesView.swift`） | 入口调用 `registerOriginalStream` 注册后走代理；11-07 日志里 Jellyfin 有 165 次代理传输 | **没有注册**。`LaunchpadLayoutViews.NetworkLibraryPlayerPresentation` 直接把桥接地址交给播放器，代理传输次数为 0 |
| 播放计划、KSPlayer、缓冲、跳转、切轨、诊断 | 共用 | 共用 |

日志里两边的 `routeKind` 都是 `localRangeProxy`，这只是播放计划按“本机地址”给的标签，不代表经过了共享代理。

**更正（11-07 晚上的说法）**：我当时说接上共享代理就能得到“范围缓存和预读”，读代码后发现不对。

- **共享代理提供的是**：有限范围响应（Greenfield 用）、断线续传（`proxy_transfer_retry`）、自签名证书固定、HLS 清单预热，以及统一的传输诊断（字节数、耗时、错误码）。
- **范围缓存和预读**：在 `Playback/IO`（`RangeCacheStore`、`PreloadCoordinator`），属于播放器自己，所有入口本来就共用。

## 顺带发现：启动预读在所有入口都没有生效

11-07 日志里，Jellyfin、SMB、WebDAV 每次起播都是 `preload_started`（4 MiB）后立刻 `preload_cancelled`，原因是 `bytesNotMaterialized`，预读到 0 字节（`PlaybackSessionCoordinator.preloadStartupWindow`）。也就是说，共享链路里的启动预读目前是空转。这和“大文件起播慢”可能有关，原因还没查，属于共享链路，不是网络存储独有的问题。

## 方案

### 第一步：网络存储注册到共享代理（改动小，先验证收益）

播放器 → 共享代理 → 本地桥接 → SMB/FTP/WebDAV 读取器

1. **`LaunchpadLayoutViews.NetworkLibraryPlayerPresentation`（共享，主 App）**：拿到 `source.playbackURL` 后先 `registerOriginalStream(upstreamURL:filename:allowsSelfSignedCertificates: false, usesGreenfieldPlayback: true, playbackTraceID:)`，失败时退回原桥接地址，和 Jellyfin 的写法一致（`LaunchpadView.swift` 约 8818 行）。
2. **`WebDAVPlaybackSession.accept`（NetworkMedia）**：现在最多 2 个并发连接，代理对同一主机最多开 4 个（`httpMaximumConnectionsPerHost = 4`），要放宽到不少于 4，否则多出来的连接会被直接断开。
3. **桥接响应头已经兼容**：只支持单一范围、`Content-Type: application/octet-stream`、`Connection: close`，代理用标准 URLSession 请求，`Host` 是 `127.0.0.1:端口`，符合桥接的校验。
4. **生命周期**：代理路由保留 6 小时，桥接在关闭播放时就撤销。关闭后代理再请求会得到连接失败，不会读到别的文件。

**预期收益**：传输诊断统一（可以和 Jellyfin 用同一口径拆分慢在哪里）、断线续传。**不会**带来缓存命中，性能是否变好要实测，不能预设。

**验证**：用 11-07 的同一套脚本（`mx.py`）在 iPhone 13 上跑 SMB、FTP、WebDAV 各一轮，对比首帧、跳转恢复、缓冲中位数和帧率，并确认日志出现代理传输记录。

### 第二步：让代理直接读取协议读取器（正式统一）

在共享代理的路由里加“上游类型”：HTTP 地址或 `NetworkMediaByteReader`。读取器在代理内部直接按范围取字节，去掉本地桥接。之后各协议只维护“按范围读字节”和凭据，其余全部共用。

- **凭据边界**：读取器持有凭据，代理和播放器拿不到。
- **FTP**：每次读取都要重新登录，代理续传和并发会放大这个问题，第二步前后要改成复用控制连接。
- **跨模块**：代理在主 App，读取器在 NetworkMedia 包，接口要放在两边都能引用的位置，并确保 TV 也能编译。

## 分工建议（请用户和 Codex 确认）

- 共享代理和 `LaunchpadLayoutViews` 是 Codex 长期维护的共享代码。建议一方集中修改，另一方审查，避免同时修改。
- **Claude 可以承担**：第一步全部改动（2 个文件）以及 iPhone 13、iPad 上的对比实测；NetworkMedia 包里桥接、读取器、FTP 连接复用的改动。
- **建议 Codex 主导或审查**：共享代理的路由结构（第二步），以及启动预读空转的排查，因为它影响 Jellyfin 和设备文件的主线。
- **开工前**：按 `AGENT-RESOURCE-STATE.json` 登记可写文件和设备窗口。
