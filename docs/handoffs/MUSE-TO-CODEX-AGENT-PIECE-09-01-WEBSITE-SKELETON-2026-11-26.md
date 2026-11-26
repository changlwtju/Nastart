# 交接：Agent 第 9-1 件 — 官网静态站骨架与落地页

**日期**：2026-11-26
**来自**：Muse
**给**：Codex
**对应拆分**：`docs/project/AGENT-BREAKDOWN.md` 第 9 件（正式云/官网）第 9-1 小件
**范围依据**：`website/README.md`（官网首版纯静态；App Store 支持页：落地页、隐私政策、支持页、FAQ、更新日志/路线图）

## 目标

在 `website/` 下建一个纯静态官网骨架，并完成落地页（`index.html`）。本地可预览，不部署、不上线。本件只做骨架与落地页，不做其他支持页。

## 要实现的代码（只做这些）

### 文件

- `website/index.html` — 落地页
- `website/assets/style.css` — 全站共用样式（后续 9-2～9-4 的页面复用同一份）
- 如需放图：`website/assets/` 下只放已有的 App 图标或截图；没有现成可用的图就先不放图，不另外生成图片

### 落地页内容（中文为主，App 名与专有名词保留英文）

- 标题：Nastart
- 一句话介绍：本地优先的 NAS / HomeLab 管理 App，支持 iPhone、iPad、Apple TV
- 核心能力（各一句话，不展开）：
  - 群晖 DSM 管理
  - Docker 容器状态（经 NAS 上的 Nastart Agent）
  - Jellyfin 媒体库与播放
  - 文件管理
  - 服务启动台
- 本地优先 / 隐私（一小段）：
  - 数据不出家门；Agent 只在局域网内工作，不经过任何云中继
  - 不把 NAS 账号密码同步到云端
- 获取方式：目前为内部开发版（0.1.0），App Store 尚未上架；写“即将上架 App Store”，不放下载链接
- 页脚导航（链接先指向后续要建的页面，文件尚不存在是正常的，本件不建这些页）：
  - 隐私政策 → `privacy.html`
  - 支持 → `support.html`
  - FAQ → `faq.html`
  - 更新日志 → `changelog.html`

### 技术约束（硬性）

- 纯静态：只用 HTML + CSS，不用任何 JS 框架、不引入构建工具、不写服务端代码
- 零外部依赖：不引用 CDN 字体、脚本或图片；断网/离线也能完整显示
- 不接入任何统计、埋点或第三方脚本
- 响应式：手机（约 390px 宽）与桌面（约 1280px 宽）下排版都正常，无横向滚动
- 设计：干净、克制的大留白版式，与 App 的浅色主题一致，点缀色用 App 的橙色；不要花哨动效
- 文案：中文、简洁、不夸大；不要写尚未实现的功能

## 不做

- 隐私政策、支持、FAQ、更新日志页（9-2～9-4 件）
- 部署、上线、域名、HTTPS（9-5 件）
- 改 App（iOS/tvOS）或 Agent 代码
- 自定义云后端、云中继、账号/计费（不在 V1 范围）
- 生成图片或 App 截图

## 验收标准（你交回前自己先跑过）

1. 在 `website/` 下起一个本地静态服务器（例如 `python3 -m http.server`），浏览器打开落地页能正常显示
2. 落地页无 404、无外部请求（浏览器开发者工具 Network 里只有本地文件）
3. 手机宽度（约 390px）与桌面宽度（约 1280px）下排版正常，无横向滚动、无文字溢出
4. 页脚四个链接指向 `privacy.html` / `support.html` / `faq.html` / `changelog.html`（目标文件本件不建，链接本身写对即可）
5. 交回：新建/改动文件清单、本地预览方法（命令与地址）、以及一张落地页截图（桌面宽度即可）

## 参考

- `website/README.md`：官网最小页面清单与“首版纯静态”口径
- `cloud/README.md`：正式云 V1 = iCloud/CloudKit 同步，不建自定义后端（本件不涉及后端，只作背景）
- App 当前版本 0.1.0（`ios/Nastart/Nastart.xcodeproj`，`MARKETING_VERSION = 0.1.0`）
