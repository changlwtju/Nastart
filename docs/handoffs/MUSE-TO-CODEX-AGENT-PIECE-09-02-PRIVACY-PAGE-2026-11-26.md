# 交接：Agent 第 9-2 件 — 隐私政策页

**日期**：2026-11-26
**来自**：Muse
**给**：Codex
**对应拆分**：`docs/project/AGENT-BREAKDOWN.md` 第 9 件（正式云/官网）第 9-2 小件
**范围依据**：`website/README.md`（官网 App Store 支持页之一：隐私政策）；`cloud/README.md`（云端不存 NAS 凭证等敏感信息明文；V1 云 = iCloud/CloudKit 同步）

## 目标

新建 `website/privacy.html`（隐私政策页），复用 9-1 件的 `website/assets/style.css`，不改样式文件。内容按 Nastart 实际数据实践写（见下），中文，本地可预览，不部署。

## 要实现的代码（只做这些）

### 文件

- `website/privacy.html` — 新建。复用 `website/assets/style.css`（`<link rel="stylesheet" href="assets/style.css">`），不改 `style.css`，不新增样式文件。
- 页眉、页脚与 `index.html` 保持一致（同一 wordmark、同一导航、同一页脚四链接：隐私政策、支持、FAQ、更新日志）。

### 隐私政策内容（中文，按以下事实点写，措辞简洁、不夸大）

页首注明生效日期（写 2026-11-26）与适用范围（Nastart App，iPhone / iPad / Apple TV）。正文必须覆盖以下事实点，每点一段，不遗漏、不编造未列出的事实：

1. **本地优先**：Nastart 是本地优先的 App。NAS 连接信息、媒体库信息、任务与提醒等数据保存在用户自己的设备与 NAS 上。
2. **无账号**：Nastart 不设账号体系，不要求注册，不收集姓名、邮箱、手机号等身份信息。
3. **NAS 凭证**：NAS 账号密码只保存在用户设备本地（iOS 钥匙串），用于连接用户自己的 NAS；不会同步到云端，也不会发给开发者或任何第三方。
4. **Nastart Agent（可选）**：Agent 运行在用户自己的 NAS 上，只在局域网内工作，不经过云中继，不向开发者发送数据。
5. **iCloud/CloudKit 同步（可选）**：如用户开启同步，设置与任务通过用户自己的 iCloud 账号（Apple CloudKit）在其 Apple 设备之间同步；开发者不运营用于同步的服务器，也不经手这份数据。
6. **不收集**：不做行为统计、不接广告、不收集广告标识符；不收集位置信息。
7. **第三方**：除用户主动开启的 Apple iCloud/CloudKit 同步外，不向任何第三方共享数据。
8. **联系方式**：如有隐私问题，通过支持页（`support.html`）联系。不要写具体邮箱地址（尚无公开邮箱），链接到支持页即可。
9. **政策变更**：政策更新时在此页公布并更新生效日期。

### 技术约束（硬性，沿用 9-1 件）

- 纯静态：只用 HTML + CSS，复用 `assets/style.css`；不用 JS 框架、不引入构建工具、不写服务端代码
- 零外部依赖：不引用 CDN 字体、脚本或图片；断网/离线也能完整显示
- 不接入任何统计、埋点或第三方脚本
- 响应式：手机（约 390px 宽）与桌面（约 1280px 宽）下排版都正常，无横向滚动
- 文案：中文、简洁；只写上面列出的事实点，不编造未列出的收集行为或功能

## 不做

- 支持、FAQ、更新日志页（9-3～9-4 件）
- 部署、上线、域名、HTTPS（9-5 件）
- 改 `assets/style.css`（样式以 9-1 件为准；如确需新增样式类，先在交回里说明，由 Muse 决定是否改）
- 改 App（iOS/tvOS）或 Agent 代码
- 自定义云后端、云中继、账号/计费（不在 V1 范围）

## 验收标准（你交回前自己先跑过）

1. 在 `website/` 下起本地静态服务器（例如 `python3 -m http.server`），浏览器打开 `privacy.html` 能正常显示，样式与落地页一致
2. 页面无 404、无外部请求（浏览器开发者工具 Network 里只有本地文件）
3. 手机宽度（约 390px）与桌面宽度（约 1280px）下排版正常，无横向滚动、无文字溢出
4. 页眉、页脚与 `index.html` 一致；页脚四链接指向 `privacy.html` / `support.html` / `faq.html` / `changelog.html`（其中 `support.html` / `faq.html` / `changelog.html` 尚未建，链接本身写对即可）
5. 正文覆盖上面 9 个事实点，无遗漏、无编造
6. 交回：新建/改动文件清单、本地预览方法（命令与地址）、以及一张隐私政策页截图（桌面宽度即可）

## 参考

- `website/index.html`：页眉、页脚与样式的现成模板
- `website/assets/style.css`：全站共用样式（复用，不改）
- `website/README.md` 与 `cloud/README.md`：官网与正式云的范围口径
