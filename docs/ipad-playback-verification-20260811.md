# iPad 播放真机核验记录

日期：2026-08-11  
设备：iPad 9th generation，iPadOS 18.3.1  
入口：DSM `/video/media`、Jellyfin 媒体库  

## 已实际操作的样本

| 入口 | 样本 | 真机操作 | 结果 |
| --- | --- | --- | --- |
| DSM `/video/media` | `[哈尔的移动城堡].Howl s.Moving.Castle.HDTV.720p.x264.AC3-CMCT.mkv` | 进入 `/video` → `/video/media` → `movie`，打开文件预览并点击“预览” | 播放器实际打开；iPad 停在加载/错误画面，诊断为 `MobileVLCKit loadTimeout`。代理路径在收到约 32KB 后出现 `NSURLError -1005`/Broken pipe；改为 File Station 认证直连后仍超时。 |
| Jellyfin | 方世玉续集（1993） | 从“继续观看”进入播放器 | 历史位置显示约 23:34，断点数据保留；未出现可确认的视频帧，仍无法判定播放通过。 |
| Jellyfin | A计划（1983） | 从 Jellyfin 详情点击“在 Nastart 中播放” | 播放器实际打开；画面停在 0:00，显示“无法播放媒体/等待媒体数据超时”。 |

## 入口与数据加载核验

- DSM 根目录首次显示为空；修复后 iPad 实时显示 12 个共享目录，并可继续进入 `/video`、`/video/media`。
- `/video/media` 的真实目录内容已在 iPad 上加载，包括 `movie`、`TV`、`anime`、`music` 等目录。
- Jellyfin 资源库曾出现 429/460/595/超时；重试后实际加载出 36 部电影、36 部剧集和 20 个继续观看项目。
- 方世玉详情中的历史播放位置、音轨和字幕元数据均能加载；播放器帧输出仍失败。

## 18 样本矩阵状态

18 个 DSM 样本与 18 个 Jellyfin 样本的完整“逐项打开、播放、记录”矩阵尚未完成，原因是 iPad 播放失败后 WDA 真机控制服务会在退出播放器时失去响应；已重启过 WDA 并保留上述真实失败证据。未完成的样本不计为通过，也没有用 Mac 文件扫描替代真机测试。
