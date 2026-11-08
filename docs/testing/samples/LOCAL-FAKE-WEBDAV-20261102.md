# 本机合成 WebDAV 媒体库样本

2026-11-02，用户已批准。资产在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-fakelib/`；只导出其中 `library/`。根地址 `http://127.0.0.1:8089/`，匿名、只读，不绑定LAN／IPv6。

| 类别 | 作品数 | 视频数 |
| --- | --- | --- |
| 电影 | 40 | 40 |
| 剧集 | 6 | 48（每部2季，每季4集） |
| 动漫 | 4 | 4 |

50部作品共45张600×900渐变文字海报、45份虚构movie.nfo，剧集额外有6份tvshow.nfo用于剧名识别。92个视频是空MKV占位：未发现ffmpeg，使用用户允许的fallback，不能用于播放／首帧／吞吐验收。

- 缺海报：movie-001／011／021／031，series-003（5/50）。
- 缺全部NFO：movie-004／014／024／034，anime-002（5/50）。
- 超长中文名：movie-007／019／036，series-002，anime-004。
- 精确路径、字节数、SHA与缺失标记见本机manifest.json；全部标题／简介／海报为合成内容。

仅接受OPTIONS／PROPFIND／GET／HEAD；provider只读，禁用锁／属性持久化，文件0444／目录0555。协议与目录已验证，尚未在App连接／导入／展示／播放，不替代NAS或真机验收。用夹具目录start.sh／stop.sh启停。[本批交付](../../archive/handoffs/2026-11/CODEX-2026-11-02-LOCAL-FAKE-WEBDAV.md)。
