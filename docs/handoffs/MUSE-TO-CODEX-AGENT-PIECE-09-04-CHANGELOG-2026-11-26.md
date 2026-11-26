# 交接：Agent 第 9-4 件 — 更新日志/路线图页

**日期**：2026-11-26
**来自**：Muse
**给**：Codex
**对应拆分**：`docs/project/AGENT-BREAKDOWN.md` 第 9 件（正式云/官网）第 9-4 小件
**范围依据**：`website/README.md`（官网 App Store 支持页之一：更新日志/路线图）；`docs/project/BIG-TARGETS-ROADMAP.md`（大目标总纲，路线图内容来源）

## 目标

新建 `website/changelog.html`（更新日志/路线图页），复用 9-1 件的 `website/assets/style.css`，不改样式文件。内容按下面列出的事实写，中文，本地可预览，不部署。

## 要实现的代码（只做这些）

### 文件

- `website/changelog.html` — 新建。复用 `website/assets/style.css`，不改样式文件。
- 页眉、页脚与 `index.html` / `privacy.html` / `support.html` / `faq.html` 保持一致（同一 wordmark、同一导航、同一页脚四链接）。

### changelog.html 内容

分两部分：更新日志（已发布版本）与路线图（计划中）。只写下面列出的事实，不编造版本号、日期或功能；不写具体上线日期，路线图条目标“计划中”。

**更新日志**

- **0.1.0 — 内部开发版（2026-11-26）**，一句话说明“当前内部开发版，尚未上架 App Store”，然后列以下已实现内容（各一句话）：
  - 群晖 DSM 服务管理：启动台、容器列表、文件浏览
  - Jellyfin 媒体库与播放
  - iCloud/CloudKit 同步：设置与任务在 Apple 设备间同步（本地部分）
  - Nastart Agent 增强数据：Docker 容器列表与 NAS 实时指标（CPU、内存、硬盘）
  - Apple TV 支持

**路线图（计划中，不承诺日期）**

- App Store 上架
- Plus 与发布
- 其他媒体服务
- SFTP/FTP 闭环
- 事项与通知
- 电视对照
- 播放打磨

每条一句话说明是什么，不写日期、不写版本号。

### 技术约束（硬性，沿用 9-1 / 9-2 / 9-3 件）

- 纯静态：只用 HTML + CSS，复用 `assets/style.css`；不用 JS 框架、不引入构建工具、不写服务端代码
- 零外部依赖：不引用 CDN 字体、脚本或图片；断网/离线也能完整显示
- 不接入任何统计、埋点或第三方脚本
- 响应式：手机（约 390px 宽）与桌面（约 1280px 宽）下排版都正常，无横向滚动
- 文案：中文、简洁；只写上面列出的事实点，不编造未列出的版本号、日期、功能或价格

## 不做

- 部署、上线、域名、HTTPS（9-5 件）
- 改 `assets/style.css`（样式以 9-1 件为准；如确需新增样式类，先在交回里说明，由 Muse 决定是否改）
- 改 App（iOS/tvOS）或 Agent 代码

## 验收标准（你交回前自己先跑过）

1. 在 `website/` 下起本地静态服务器（例如 `python3 -m http.server`），浏览器打开 `changelog.html` 能正常显示，样式与落地页、隐私政策页、支持页、FAQ 一致
2. 页面无 404、无外部请求（浏览器开发者工具 Network 里只有本地文件）
3. 手机宽度（约 390px）与桌面宽度（约 1280px）下排版正常，无横向滚动、无文字溢出
4. 页眉、页脚与其它四页一致；页脚四链接指向 `privacy.html` / `support.html` / `faq.html` / `changelog.html`，且四页页脚互相链通（落地页、隐私政策页、支持页、FAQ 的页脚“更新日志”链接现在能点到本页，不再 404）
5. 正文覆盖上面列出的更新日志（0.1.0 五项）与路线图（七项），无遗漏、无编造、无具体日期承诺
6. 交回：新建/改动文件清单、本地预览方法（命令与地址）、以及一张更新日志页截图（桌面宽度即可）

## 参考

- `website/index.html`、`website/privacy.html`、`website/support.html`、`website/faq.html`：页眉、页脚与样式的现成模板
- `website/assets/style.css`：全站共用样式（复用，不改）
- `docs/project/BIG-TARGETS-ROADMAP.md`：大目标总纲，路线图内容来源
