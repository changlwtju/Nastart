# 交接：Agent 第 9-3 件 — 支持页与 FAQ

**日期**：2026-11-26
**来自**：Muse
**给**：Codex
**对应拆分**：`docs/project/AGENT-BREAKDOWN.md` 第 9 件（正式云/官网）第 9-3 小件
**范围依据**：`website/README.md`（官网 App Store 支持页之一：支持页、FAQ）

## 目标

新建 `website/support.html`（支持页）与 `website/faq.html`（FAQ），复用 9-1 件的 `website/assets/style.css`，不改样式文件。内容按下面列出的事实写，中文，本地可预览，不部署。

## 要实现的代码（只做这些）

### 文件

- `website/support.html` — 新建。复用 `website/assets/style.css`，不改样式文件。
- `website/faq.html` — 新建。复用 `website/assets/style.css`，不改样式文件。
- 页眉、页脚与 `index.html` / `privacy.html` 保持一致（同一 wordmark、同一导航、同一页脚四链接）。

### support.html 内容

- 标题：支持
- 一句话：遇到问题，先看 FAQ；FAQ 没覆盖的，按下面方式联系。
- 三块支持入口（各一两句话，并链到 FAQ 对应条目）：
  - 安装与部署：App 与 Agent 的安装方式，链到 FAQ 安装部分
  - 配对与连接：App 与 Agent 配对、Agent 未连接，链到 FAQ 配对与连接部分
  - 播放与媒体库：Jellyfin 播放相关，链到 FAQ 播放部分
- 联系方式：不写具体邮箱地址（尚无公开邮箱）。写“App 上架后，支持邮箱将在 App Store 应用信息页公布；目前为内部开发版”，并链到 FAQ。

### faq.html 内容

按下面问题与事实点写问答，中文，每题一段答案，只写列出的事实，不编造。分三组，组标题为“安装”、“配对与连接”、“常见故障”。

**安装**

1. **Nastart App 现在能下载吗？**
   - 目前为内部开发版（0.1.0），尚未上架 App Store；上架后在此页更新下载方式。
2. **Nastart Agent 怎么装？**
   - Agent 是跑在 NAS/服务器上的增强服务（Docker 镜像 `changlwtju/nastart-agent`，见 Docker Hub）；支持 Docker Compose、群晖 SPK、通用 Linux systemd 三种装法；默认端口 8787。
3. **Agent 需要什么配置？**
   - 一台能跑 Docker 的 NAS 或 Linux 主机；Agent 默认提供 HTTPS（自签证书），App 配对时需开“跳过 SSL 验证”。

**配对与连接**

4. **怎么把 App 和 Agent 配对？**
   - App 里进“设备 → 配置 Nastart Agent”，地址填 `https://<NAS 地址>:8787`；从 Agent 容器日志里取一次性配对码填入；确认“跳过 SSL 验证”为开；点“重新配对”。
5. **配对码在哪里找？**
   - Agent 容器日志最新一行 `One-time pairing code:` 后面就是；每个码只能用一次。
6. **配对码提示无效怎么办？**
   - 码是一次性的，用过即失效；重启 Agent 容器可生成一条新码，再用新码配对。

**常见故障**

7. **App 显示 Agent 未连接怎么办？**
   - 先确认 Agent 容器在运行、地址与端口填对、手机与 NAS 在同一局域网（或外网端口转发已通）；如果 Agent 被更换或重装过，需用新配对码重新配对。
8. **遇到证书 / SSL 提示怎么处理？**
   - Agent 默认用自签证书，App 配对时把“跳过 SSL 验证”打开即可；App 首次连接会记住该证书指纹。
9. **在外网怎么连 Agent？**
   - 路由器上把外部 TCP 8787 转发到 NAS 的 8787，App 里地址改成 `https://<域名>:8787`；或用 Tailscale 等 VPN，不把端口暴露到公网。
10. **换了 NAS 或重装 Agent 后要重新配对吗？**
    - 要。Agent 身份变了，App 会提示“Agent 已更换或配对已失效，请重新配对”，用新配对码重新配对即可。

### 技术约束（硬性，沿用 9-1 / 9-2 件）

- 纯静态：只用 HTML + CSS，复用 `assets/style.css`；不用 JS 框架、不引入构建工具、不写服务端代码
- 零外部依赖：不引用 CDN 字体、脚本或图片；断网/离线也能完整显示
- 不接入任何统计、埋点或第三方脚本
- 响应式：手机（约 390px 宽）与桌面（约 1280px 宽）下排版都正常，无横向滚动
- 文案：中文、简洁；只写上面列出的事实点，不编造未列出的功能、价格或联系方式；不写具体邮箱地址

## 不做

- 更新日志页（9-4 件）
- 部署、上线、域名、HTTPS（9-5 件）
- 改 `assets/style.css`（样式以 9-1 件为准；如确需新增样式类，先在交回里说明，由 Muse 决定是否改）
- 改 App（iOS/tvOS）或 Agent 代码

## 验收标准（你交回前自己先跑过）

1. 在 `website/` 下起本地静态服务器（例如 `python3 -m http.server`），浏览器打开 `support.html` 与 `faq.html` 均能正常显示，样式与落地页、隐私政策页一致
2. 两页无 404、无外部请求（浏览器开发者工具 Network 里只有本地文件）
3. 手机宽度（约 390px）与桌面宽度（约 1280px）下排版正常，无横向滚动、无文字溢出
4. 页眉、页脚与 `index.html` / `privacy.html` 一致；页脚四链接指向 `privacy.html` / `support.html` / `faq.html` / `changelog.html`（其中 `changelog.html` 尚未建，链接本身写对即可）；支持页到 FAQ 的站内链接能点到对应位置
5. FAQ 覆盖上面 10 个问题，无遗漏、无编造；支持页不写具体邮箱地址
6. 交回：新建/改动文件清单、本地预览方法（命令与地址）、以及两页截图各一张（桌面宽度即可）

## 参考

- `website/index.html` 与 `website/privacy.html`：页眉、页脚与样式的现成模板
- `website/assets/style.css`：全站共用样式（复用，不改）
- `agent/README.md` 与 Docker Hub `changlwtju/nastart-agent`：Agent 安装方式与镜像名
