# Agent 第 7 件交接：自动证书——自签证书自动生成与生命周期管理（2026-11-24）

## 目标

Agent 现在默认走明文 HTTP：`--tls-cert` / `--tls-key` 虽然存在，但默认不给证书，Compose 里也没配，token 在局域网里是明文走的。本件让 Agent 自己管证书：首次启动自动生成自签证书并默认用它提供 HTTPS，到期前自动换新，接口里报出证书指纹与到期时间。App 侧不用改代码——App 已有 https + 自签信任（`AgentCertificateTrustDelegate` 经 `CertificatePinStore` 做 TOFU 指纹 pin，首次见面就 pin 住），用户改用 https 重新配对一次即可。

## 现状（已摸清，Codex 不用再探）

- Agent 只在给了 `--tls-cert` / `--tls-key`（或 `NASTART_TLS_CERT` / `NASTART_TLS_KEY`）时才包 TLS（`ssl.SSLContext`，最低 TLSv1.2）；默认不给，走明文 HTTP。Compose 里没有任何 TLS 环境变量。
- 镜像里**没有** openssl 命令行（`python:3.13-alpine` 不带），Agent 不能自己生成证书；Python 标准库只能读证书，不能生成。Mac 上有 openssl（Homebrew 4.1.0），测试可用。
- App 已支持 https + 自签：`AgentClient` 接受 http/https；https 且开了"跳过 SSL 验证"时用 `AgentCertificateTrustDelegate`，经 `CertificatePinStore` 按 `host:port` 做 SHA-256 指纹 pin（首次见面 pin 住，换了就更新 pin 并记一条 pin_rotated 警告）。所以 Agent 只要能拿出证书，App 就能用，不用改 App。
- 配对表单用户输裸地址时默认补 `https://`；第 4 件验收时 App 是用 `http://192.168.1.82:8787` 配对的——本件之后这条旧配对会失效，用户需用 https 重新配对一次（见"迁移提醒"）。
- 镜像发布与升级流程沿用第 3 件（`scripts/publish_agent_image.sh`、`scripts/verify_agent_docker.py`）。

## 本件做

### 1. Dockerfile（加 openssl 命令行）

- `RUN apk add --no-cache openssl`（系统工具，不是 Python 依赖；Agent 保持无 Python 依赖）。其余 Dockerfile 内容不动。

### 2. 证书自动生成与生命周期（`nastart_agent.py`，`main()` 与 `AgentState` 附近）

- 默认证书路径：数据目录下的 `tls-cert.pem` 与 `tls-key.pem`（显式 `--tls-cert` / `--tls-key` 优先，显式给了就用显式的，不自动生成）。
- 启动时：没有显式证书时，检查数据目录的证书——不存在、已过期、或 30 天内到期，就调 openssl 生成一张新的：
  `openssl req -x509 -newkey rsa:2048 -keyout <key> -out <cert> -days 3650 -nodes -subj "/CN=<hostname>" -addext "subjectAltName=DNS:<hostname>,DNS:localhost,IP:127.0.0.1"`（hostname 取 `socket.gethostname()`）。
- 密钥文件权限 0600，证书 0644；写盘用原子写（先写临时文件再 rename，不直接覆盖在用文件）。
- 生成失败或本机没有 openssl 时：往 stderr 记一行警告，**退回明文 HTTP，不 crash**（直接跑 `python3 nastart_agent.py` 的主机没 openssl 也能继续用）。
- 有证书就默认用它提供 HTTPS（`main()` 里现有包 TLS 的逻辑复用，scheme 照常打进启动日志）。

### 3. 接口里报出证书信息

- `/v1/handshake` 加 `certificate` 字段（TLS 生效时）：`{"fingerprintSha256": "<hex>", "notAfter": <unix 秒>, "subject": "<CN>"}`；走明文 HTTP 时 `certificate` 为 null。指纹是证书 DER 的 SHA-256（与 App pin store 算法一致），到期时间与指纹都用 `openssl x509 -in <cert> -noout -enddate -fingerprint -sha256` 读，不手写 X.509 解析。
- `/v1/diagnostics` 的 `checks` 里加一项 `certificate`：`ok`（有效期 > 30 天）、`expiring`（≤ 30 天）、`expired`、`unavailable`（明文 HTTP / 无证书）；detail 写剩余天数或原因。现有两项检查不动。

### 4. 版本

- `AGENT_VERSION` 从 `0.3.0` 升到 `0.4.0`（Agent 代码与 Dockerfile 都变了，镜像内容变了，tag 必须变）。其余版本逻辑不动。

### 5. 测试

- `agent/test_agent.py` 内新增测试类（或新建测试文件）：用测试环境可用的 openssl 生成一张真证书再验（不要只 mock）；指纹与到期时间解析正确；快到期（用 `-days 1` 生成或改系统时间之外的办法——直接造一张短期证书）的证书触发重新生成；openssl 不可用（PATH 里拿掉或 stub 返回失败）时 Agent 退回 HTTP 不 crash；现有测试全过。
- 注意：测试里生成证书不要写进仓库数据目录，用临时目录。

### 6. 文档

- `agent/README.md` 里补 TLS 一节：证书自动生成、默认 HTTPS、指纹/到期在 handshake 与 diagnostics 里、如何显式提供自己的证书。

## 迁移提醒（写给用户与验收，不要漏）

- 本件之后 Agent 默认走 HTTPS。App 里旧的 `http://` 配对会连不上，需用 `https://` 重新配对一次（表单输裸地址默认就是 https），并打开"跳过 SSL 验证"，App 首次见面 pin 住新证书指纹。此后证书 10 年内到期前 Agent 会自动换新，App 换 pin 时记一条 pin_rotated 警告，不用人工干预。

## 不做

- App 代码改动（App 已支持 https + TOFU pin，本件只做 Agent 侧）。
- Let's Encrypt / ACME / 公共域名证书（LAN-only，Agent 没有公共域名）。
- 域名管理（没有公共域名可管；README 里的"domain lifecycle"是指以后的云/官网件）。
- 改配对/token 逻辑。

## 文件

- 改：`agent/nastart_agent.py`（证书生成 + 生命周期 + handshake/diagnostics 字段 + `AGENT_VERSION` 一行）。
- 改：`agent/Dockerfile`（加 openssl）。
- 改：`agent/test_agent.py`（或新建测试文件）。
- 改：`agent/README.md`（TLS 说明）。

## 验收

- Codex 自己跑通新增与现有 Python 测试。
- Muse 复跑：构建并发布 `0.4.0` 镜像（走第 3 件流程），独立 Compose 起栈；`curl -k https://<loopback端口>/healthz` 200 且 version 为 0.4.0，明文 http 请求失败（TLS 握手失败）；配对后 `/v1/handshake` 的 `certificate.fingerprintSha256` 与 `openssl x509 -fingerprint -sha256` 独立算出的一致，`notAfter` 约 10 年后；`/v1/diagnostics` 里 `certificate` 检查为 ok；数据卷里 `tls-cert.pem` / `tls-key.pem` 存在，密钥权限 0600；App（iPhone 13）用 https 重新配对一次，启动台显示"Agent 已连接"。
