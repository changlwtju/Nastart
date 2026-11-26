# NAS Agent 拆分

**日期**：2026-11-23
**定稿人**：用户 + Muse
**用途**：第 2 号大目标（NAS Agent）的拆件清单，一件一件交接给实现方（Codex），不一次全给。顺序按 `AGENT_DEPLOYMENT_OPTIONS.md` 的近期顺序（Docker 生命周期 → App 配对合并 → 受限 API 权限 → 增量监控/诊断 → SPK 及其他平台安装），再接总纲里的自动证书与正式云/官网。

**Agent 是什么**：NAS 端增强服务（依赖-free Python，`agent/nastart_agent.py`），不是 AI 助手。路由：`GET /healthz`、`GET /v1/handshake`、`GET /v1/snapshot`、`GET /v1/diagnostics`、`POST /v1/pair`。保持 LAN only，不引入云中继依赖。

## 第 1 件：Docker 健康检查与镜像命名（**已验收**，2026-11-23）

- **目标**：Docker 能判断 Agent 容器是否真的健康，且构建出的镜像有名字和版本标签。
- **关键发现**：版本上报已做（`AGENT_VERSION = "0.1.0"`，`handshake` 与 `/healthz` 均返回版本），不用再加；`compose.yaml` 无 `healthcheck:`（假死发现不了）且无 `image:`（镜像无名无版本）。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-01-DOCKER-HEALTHCHECK-2026-11-23.md`
- **文件**：`agent/compose.yaml`（healthcheck + image）；`agent/Dockerfile`（仅当加 HEALTHCHECK 时）；`agent/test_agent.py`（新增用例）；验证脚本。
- **做到**：compose 加 healthcheck（调容器内 `/healthz`，用镜像内已有工具，不加新依赖）；加 `image: nastart-agent:<version>`（与 `AGENT_VERSION` 一致，避免两处写死漂移）；测试验 healthcheck 命令逻辑（服务在跑退出 0，停掉退出非 0）与 Docker 行为（healthy / unhealthy 各一次）。
- **不做**：镜像发布到 registry、升级/回退流程（第 2 件）；SPK、受限 API 权限、App 配对合并、自动证书、正式云/官网。
- **验收**：Codex 自己构建并跑通验证（附 `docker inspect` 的 Health.Status）；Muse 在 Mac 上用 Docker.app 的 CLI（`/Applications/Docker.app/Contents/Resources/bin`，须先 export PATH）复跑构建与健康检查。
- **验收结论（2026-11-23）**：Muse 复跑 4 步全部通过——6 文件 SHA 均 OK、Python 5 项全过、镜像 `nastart-agent:0.1.0`、同一容器 healthy → unhealthy、`/healthz` 与 `/v1/handshake` 均 200。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-23-AGENT-PIECE-01-ACCEPTANCE.md`。另更正：Mac 上有 Docker.app（CLI 不在默认 PATH），交接与拆分里的“Mac 上无 Docker”说法已修正。

## 第 2 件：升级/回退（本地构建版）（**已验收**，2026-11-23）

- **目标**：在已部署 Agent 的主机上升级到新版本；新版本不健康时自动回退到旧版本；升级过程不丢配对数据。
- **关键发现**：现有 `scripts/install_agent_via_ssh.sh` 只是重跑 `up -d --build`，不验新容器是否 healthy、不留旧镜像、不回退；镜像是本地构建（无 registry）；数据在命名卷 `nastart-agent-data` 里（配对 token 持久化）。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-02-UPGRADE-ROLLBACK-2026-11-23.md`
- **文件**：`scripts/install_agent_via_ssh.sh`（扩展）或新增升级脚本；`scripts/verify_agent_docker.py`（扩展）或新增验证脚本；`agent/README.md`（升级/回退用法）。
- **做到**：升级（拷新版文件、构建新镜像、保留旧镜像、停旧启新、等 healthy、验端点与新版本）；回退（新容器超时未 healthy 时自动回旧镜像、验旧容器 healthy 与旧版本、脚本非 0 退出并说明已回退）；数据不碰命名卷，升级后验旧 token 仍有效；回退路径必须实际跑通（用故意不健康的版本触发）。
- **不做**：镜像发布到 registry（第 3 件，需用户选 registry）；SPK、受限 API 权限、App 配对合并、自动证书、正式云/官网。
- **验收**：Codex 在 Mac 本地 Docker 上跑通升级与回退；Muse 在 Mac 上复跑同一流程。
- **验收结论（2026-11-23）**：Muse 复跑 `scripts/verify_agent_upgrade.py`，两笔交易全部通过——升级 0.1.0→0.1.1（healthy、版本为新版、旧 token 仍有效）、故障候选 0.1.2 unhealthy 后 30 秒超时自动回 0.1.1（healthy、版本为旧版、同一卷同一 token）；回退时 exit=1 是预期行为。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-23-AGENT-PIECE-02-ACCEPTANCE.md`。
- **实施记录**：回环 SSH 与 Mac Docker 已跑通成功升级、故障候选 unhealthy、自动回退 healthy 和原 token 校验。 [Codex 交回](../archive/handoffs/2026-11/CODEX-2026-11-23-AGENT-PIECE-02-UPGRADE-ROLLBACK.md)

## 第 3 件：镜像发布到 Docker Hub（**已验收**，2026-11-23）

- **目标**：镜像能发布到 Docker Hub（公开仓库），NAS 上能直接拉取，不用在目标主机上构建。
- **用户已选**：Docker Hub（2026-11-23，用户原话“发布到 Docker Hub 呗，一般镜像不都发布到 Docker Hub 吗”）。
- **改动前**：镜像为无命名空间的本地构建 `nastart-agent:<version>`，配置了 `pull_policy: never`。本批由用户确认 Docker Hub 命名空间 `changlwtju`。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-03-DOCKERHUB-PUBLISH-2026-11-23.md`
- **文件**：`scripts/publish_agent_image.sh`（新增）；`agent/compose.yaml`、`agent/compose.sh`（镜像命名）；`scripts/install_agent_via_ssh.sh`、`scripts/upgrade_agent_via_ssh.sh`、`scripts/upgrade_agent_on_host.sh`（拉取模式）；`agent/README.md`（发布与拉取用法）。
- **做到**：发布脚本（构建、打 `<namespace>/nastart-agent:<version>` 与 `:latest` 标签、推送；命名空间由环境变量传入，必填、不硬编码）；镜像命名改用带命名空间的形式；部署侧支持从 Docker Hub 拉取（不再在目标主机上构建），仍走第 1–2 件的健康检查与升级/回退逻辑。
- **前置（已确认，2026-11-23）**：Docker Hub 用户名 `changlwtju`；用户已在 Mac 上登录 Docker Hub；仓库默认公开。
- **不做**：SPK、受限 API 权限、App 配对合并、自动证书、正式云/官网。
- **验收**：Codex 交回 Docker Hub 仓库地址、推送与干净拉取的证据；Muse 在 Mac 上复跑拉取并启动验证。
- **验收结论（2026-11-23）**：Muse 复跑 `verify_agent_docker.py --pull`（命名空间 `changlwtju`），19 文件 SHA 均 OK；复跑前清掉本机留存的本批镜像后真干净拉取，摘要 `sha256:18dfe1cb…1373` 与用户给定完全一致；容器 healthy，`/healthz`、`/v1/pair`、`/v1/handshake` 均 200，两个版本字段均为 0.1.0，同一容器 healthy → unhealthy 已验证。过程问题：SSH 会话读钥匙串被拒，改走 GUI Terminal 跑通（SSH 访问钥匙串的固有限制）。配对码与 token 留在本机。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-23-AGENT-PIECE-03-ACCEPTANCE.md`。
- **本批结果**：`0.1.0` 与 `latest` 指向同一 amd64/arm64 镜像索引。Mac 删除本地构建镜像后实测拉取，配对、健康检查与握手通过。 [Codex 交回](../archive/handoffs/2026-11/CODEX-2026-11-23-AGENT-PIECE-03-DOCKERHUB-PUBLISH.md)

## 第 4 件：App 显示 Agent 健康状态与重新配对入口（**已验收**，2026-11-24）

- **目标**：用户在 App 里能看到 Agent 是否在线；离线/失败时有明确标记和一键重新配对入口；身份不一致时给出可读原因，不再静默回退到纯 DSM 数据。
- **改动前**：`AgentHealthSnapshot` 已计算 connected、stale 和 failed，启动台尚未显示。握手身份不符归为 `unauthorized`，快照身份不符原先与 API 版本不支持共用错误。配对入口已有 `AgentSetupGuideView`。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-04-AGENT-HEALTH-UI-2026-11-24.md`
- **文件**：启动台/连接区视图（状态行与重新配对入口）；`NonPlaybackPolicyTests.swift`（或新建测试文件）；本地化 strings（新增文案，中英文）。
- **做到**：显示 Agent 健康状态（已连接/过期/失败 + 可读失败原因，不显示原始码）；失败时状态行提供一键重新配对入口（复用 `AgentSetupGuideView`）；身份不一致（`unauthorized`）显示专属文案，与网络不可达区分开。
- **不做**：改合并/去重逻辑（`AgentSnapshotMerger` 不动；若验收时发现重复卡片另立一件）；改配对协议、token 存储；受限 API 权限、自动证书、正式云/官网。
- **验收**：Codex 自己构建并跑通新增测试；Muse 真机验收（13 / iPad）：Mac 上直跑 Agent，配对后显示已连接；停掉 Agent 后显示失败 + 可读原因 + 重新配对入口；点入口能走到配对流程。
- **本批交回**：启动台服务区上方显示已有健康状态，身份不符单独提示，失败入口打开原配对表单并预填保存地址。 [验证与改动清单](../archive/handoffs/2026-11/CODEX-2026-11-24-AGENT-PIECE-04-AGENT-HEALTH-UI.md)
- **验收结论（2026-11-24）**：Muse 在 iPhone 13 与 iPad 上逐台真机验收，五项（13）+ 三项（iPad）全部通过：已连接（状态行 + Agent 主机指标合并）、停服后网络失败（可读原因 + 重新配对入口）、同地址换 Agent 专属提示（"Agent 已更换或配对已失效，请重新配对。"）、重新配对打开原表单并预填地址、错误地址可读提示。两台验收后均已断开测试 Agent 恢复"未连接"，Mac 上测试 Agent 已停、数据目录已删。观察项：运行中下拉刷新未把状态从已连接翻到失败，冷启动才翻（手势/刷新时序假象与产品行为未完全区分，不直接断言是 bug）。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-04-ACCEPTANCE.md`。

## 第 5 件：受限 API 权限（**已验收**，2026-11-24）

- **目标**：Docker socket 的 `:ro` 挂载并不限制 API 写操作，正式部署需最小 API 权限代理或等价隔离。
- **方案**：新增无依赖过滤代理 sidecar（同一镜像、独立容器，`agent/docker_socket_proxy.py`，只用标准库），独占真实 socket，只转发 Agent 唯一需要的 `GET /v1.41/containers/json?all=1`，其余一律 403；Agent 容器删掉真实 socket 挂载，只挂过滤后的 socket（`:ro`，`NASTART_DOCKER_SOCKET` 指过去）。代理以 root 运行（受信守门组件，特权只留最小进程），Agent 保持非 root `nastart`。`AGENT_VERSION` 0.1.0 → 0.2.0。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-05-DOCKER-SOCKET-PROXY-2026-11-24.md`
- **不做**：改 Agent 的 Docker 调用、改配对/token/握手；自动证书、正式云/官网。
- **本批结果**：11 项 Python 测试通过。Mac Compose 中，`/v1/snapshot` 返回两个测试容器，非白名单请求均 403，真实 socket 只在代理容器上。 [验证记录与交回](../archive/handoffs/2026-11/CODEX-2026-11-24-AGENT-PIECE-05-DOCKER-SOCKET-PROXY.md)
- **验收结论（2026-11-24）**：Muse 复跑发布（0.2.0 与 latest 同一摘要 `sha256:56b79cf9…0af58`，双架构）、干净拉取、独立起栈：代理运行（root）、Agent healthy（`nastart`）、配对后 `/v1/snapshot` 200 且 `dockerAvailable=true`、容器列表含 Agent 与代理；`docker inspect` 确认真实 socket 只挂在代理容器，Agent 只有数据卷与只读共享卷；从 Agent 容器内探针：白名单 GET 200，`GET /v1.41/version`、POST stop（虚构 ID）、DELETE、无 `all=1` 的 GET 均 403。11 项 Python 测试复跑全过。过程问题：SSH 读钥匙串被拒，发布与拉取改走 GUI Terminal（与第 3 件同一限制）。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-05-ACCEPTANCE.md`。

## 第 6 件：增量监控/诊断（**已验收**，2026-11-24）

- **目标**：Agent 的增量监控与诊断能力。
- **方案**：事件历史——`AgentState` 里有界（100 条）事件环形缓冲，持久化到数据目录 `events.json`（重启不丢）；daemon 采样线程每 30 秒（`NASTART_SAMPLE_INTERVAL_SECONDS`，默认 30、最小 10）调 `docker_containers()`，容器 state 变了或 Docker 可用性翻转就记事件（首次采样只建基线不记）；配对失败也记事件（不记码本身）。`/v1/diagnostics` 加 `events`（最新在前）、`eventCount`、`uptimeSeconds`，现有 `checks` 不动。`AGENT_VERSION` 0.2.0 → 0.3.0。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-06-EVENT-HISTORY-2026-11-24.md`
- **不做**：App 显示事件历史（以后一件）；资源趋势采样；日志保留/查询接口；自动证书、正式云/官网。
- **验收结论（2026-11-24）**：Muse 复跑发布（0.3.0 与 latest 同一摘要 `sha256:532a0bf0…ea4530`，双架构）、干净拉取、独立起栈（采样间隔 10 秒）：基线建立后 `events=[]` 无假事件；停/启测试容器先后记下 running → exited 与 exited → running 两条 `container.state`；停/启代理先后记下 `docker.availability` false（`ConnectionRefusedError`）与 true；重启 Agent 后动态端口变了（重新查询后用同一 token 查得 200），4 条历史逐条一致且最新在前，`uptimeSeconds` 从 131 重计为 31。18 项 Python 测试复跑全过。过程问题：SSH 读钥匙串被拒，发布与拉取改走 GUI Terminal（与第 3、5 件同一限制）。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-06-ACCEPTANCE.md`。

## 第 7 件：自动证书（**已验收**，2026-11-24）

- **目标**：Agent 的证书与域名生命周期自动管理（README 已列为初始职责之一）。
- **方案**：Agent 首次启动自动生成自签证书（Dockerfile 加 `apk add openssl`，Agent 保持无 Python 依赖），默认用它提供 HTTPS；证书 10 年有效，30 天内到期自动换新；`/v1/handshake` 报 `certificate.fingerprintSha256` / `notAfter` / `subject`，`/v1/diagnostics` 加 `certificate` 检查（ok/expiring/expired/unavailable）。显式给了 `--tls-cert`/`--tls-key` 就用显式的；没 openssl 或生成失败时记警告并退回明文 HTTP，不 crash。`AGENT_VERSION` 0.3.0 → 0.4.0。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-07-AUTO-CERT-2026-11-24.md`
- **迁移提醒**：本件之后 Agent 默认 HTTPS，App 里旧的 `http://` 配对会失效，需用 `https://` 重新配对一次（表单输裸地址默认就是 https）并开"跳过 SSL 验证"，App 首次见面 pin 住新证书指纹。
- **不做**：App 代码改动（App 已支持 https + TOFU pin）；Let's Encrypt / ACME / 公共域名证书；域名管理；正式云/官网。
- **验收结论（2026-11-24）**：Muse 复跑发布（0.4.0 与 latest 同一摘要 `sha256:9fcf79c3…73d96`，双架构）、干净拉取、`verify_agent_docker.py --pull` 全过：HTTPS `/healthz` 200（0.4.0）、明文被拒、握手指纹与独立 openssl 一致、到期约 10 年（2036-11-21）、diagnostics 里 certificate 检查为 ok、PEM 权限 0600/0644。iPhone 13 用 https:// 重新配对（开"跳过 SSL 验证"），启动台显示"Agent 已连接"，已连接主机与证书 CN 一致。23 项 Python 测试复跑全过。过程问题：SSH 读钥匙串被拒，发布改走 GUI Terminal（与第 3、5、6 件同一限制）；WDA `setValue` 往地址栏追加而非替换，用 `clear` 端点清掉后重填。持久 Agent（`nastart-agent-https` 项目，Mac 192.168.1.82:8787）留在运行状态供 App 连接。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-07-ACCEPTANCE.md`。

## 第 8 件：SPK 及其他平台安装（已验收，2026-11-25）

- **目标**：群晖 SPK 套件（包结构、权限、启停升级及机型/DSM 兼容验收）及其他平台安装。
- **前置**：Agent API 稳定后建设（已满足，0.4.0 默认 HTTPS）。
- **方案**：SPK 内含 Compose 与生命周期脚本，由 Docker Project Worker 管理项目、拉取 0.4.0 镜像和执行容器启停。Agent 在 DSM 永久套件目录保存证书及配对状态。另附通用 Linux systemd 安装。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-08-SPK-INSTALL-2026-11-24.md`
- **当前验收**：DS918+、DSM 7.4.1-90080 Update 1、Container Manager 24.0.2-1706 已手动安装并启动 `0.4.0-0008`，HTTPS 200、版本 0.4.0，最小测试包不在已安装清单。iPhone 13 已配对到 NAS Agent（https://192.168.1.64:8787，主机 63b7d538e462，与证书 CN 一致，指纹 e6fca921…已核），启动台显示「Agent 已连接」，实时指标 CPU 8%、内存 21%、硬盘 3%。 [验收记录](../archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-08-ACCEPTANCE.md)

## 第 9 件：正式云/官网（进行中，2026-11-26 拆分）

- **目标**：正式云与官网。仍保持 LAN only，不引入云中继依赖。
- **范围依据**：`website/README.md`（官网：App Store 支持页——落地页、隐私政策、支持页、FAQ、更新日志/路线图；首版纯静态）与 `cloud/README.md`（正式云 V1 = iCloud/CloudKit 同步，已在 Cloud 同步大目标完成；不建自定义 Nastart Cloud 后端、不做云中继、云端不存 NAS 凭证等敏感信息明文）。
- **拆件（官网为主，云只做边界确认）**：
  - **9-1 官网静态站骨架与落地页（已验收，2026-11-26）**：`website/` 下建纯静态站（HTML + CSS，无构建步骤、无外部依赖），落地页介绍 Nastart（本地优先 NAS 管理、核心能力、局域网隐私），本地可预览，不部署。交接 `docs/handoffs/MUSE-TO-CODEX-AGENT-PIECE-09-01-WEBSITE-SKELETON-2026-11-26.md`。Muse 复跑通过：`index.html` 与 `assets/style.css` 均 200、零外部请求、两宽度（500px 与 1280px 实测，Chrome 强制最小视口 500px，390px 与 500px 同属 560px 以下移动端布局）无横向溢出、页脚四链接指向正确（目标页为 9-2～9-4，404 属预期）。
  - **9-2 隐私政策页（已验收，2026-11-26）**：`website/privacy.html`，按 App 实际数据实践写（本地优先、无账号、CloudKit 同步可选、NAS 凭证不出设备、不存云端明文）。Muse 复跑通过：`privacy.html` 200、复用 `style.css`（未改动，仍为 9-1 版本）、零外部请求、两宽度（500px 与 1280px）无横向溢出、页眉页脚与落地页一致（子页导航用 `./#` 指回落地页锚点）、正文 9 点齐全、生效日期 2026-11-26、无邮箱地址。
  - **9-3 支持页与 FAQ（已验收，2026-11-26）**：`website/support.html` + `website/faq.html`（安装、配对、常见故障）。Muse 复跑通过：两页均 200、复用 `style.css`（未改动）、加载时仅请求本地 `style.css`（FAQ 内 Docker Hub 链接为纯超链接，不产生加载请求）、两宽度（500px 与 1280px）无横向溢出、页眉页脚一致、支持页三入口链到 FAQ 现有锚点（#installation/#pairing/#playback）、FAQ 10 问齐全且事实准确、无邮箱地址。
  - **9-4 更新日志/路线图页（已验收，2026-11-26）**：`website/changelog.html`（版本记录与路线图）。Muse 复跑通过：页面 200、复用 `style.css`（未改动）、加载时仅请求本地 `style.css`、两宽度（500px 与 1280px）无横向溢出、页眉页脚一致、五页页脚“更新日志”链接全部通（不再 404）、正文更新日志 5 项与路线图 7 项齐全、无具体日期承诺。
  - **9-5 官网部署**：把静态站部署到选定主机（待用户选：GitHub Pages / Cloudflare Pages / 自有 VPS），配域名与 HTTPS。
  - **9-6 云边界确认（已确认，2026-11-26，Muse 负责，不交 Codex）**：核对 `cloud/README.md` 的边界与 App 实际行为一致（CloudKit 同步即 V1 云、无自定义后端、无中继、无明文敏感信息），只做文档确认，不建后端。Muse 已逐条核对代码并确认通过：CloudKit 容器 `iCloud.com.changliwen.nastart` 三条 v2 记录、无 Nastart 自有服务器地址、Agent 无对外调用且官网纯静态、凭证只存 iOS 钥匙串不进 CloudKit。确认记录 `docs/archive/handoffs/2026-11/AGENT-PIECE-09-06-CLOUD-BOUNDARY-CONFIRMATION.md`。
- **不做**：自定义云后端、云中继、账号/计费系统（均不在 V1 范围）；改 App 或 Agent 代码。
