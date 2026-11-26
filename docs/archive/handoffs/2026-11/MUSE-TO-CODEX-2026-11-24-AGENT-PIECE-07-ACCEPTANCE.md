# Agent 第 7 件验收记录：自动证书——自签证书自动生成与生命周期管理（2026-11-24）

## 结论：通过

Muse 复跑发布、干净拉取、独立起栈与真机 https 重新配对：Agent 默认提供 HTTPS，明文被拒；握手指纹与独立 openssl 算出的一致，到期约 10 年；diagnostics 里 certificate 检查为 ok；PEM 权限正确。iPhone 13 用 https:// 重新配对（开"跳过 SSL 验证"），启动台显示"Agent 已连接"。23 项 Python 测试复跑全过。

## 核对

- 13 文件 SHA-256 均 OK（清单 `docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-07.sha256`）。
- Docker 29.9.2 + Compose v5.6.1。
- Python 测试复跑：23 项全过（18 项现有 + 5 项新证书测试）。

## 发布

- 完整工作区运行 `NASTART_DOCKERHUB_NAMESPACE=changlwtju scripts/publish_agent_image.sh`，`0.4.0` 与 `latest` 均指向同一摘要 `sha256:9fcf79c3ef02e1338039987a0412154a6901cc1249d6a3f9c20b52517a873d96`（双架构 amd64/arm64）。
- 发布经 GUI Terminal 跑（SSH 会话读 macOS 钥匙串被拒，Docker 凭证助手拿不到 Docker Hub 凭证；与第 3、5、6 件同一限制）。

## 独立起栈验证（`python3 scripts/verify_agent_docker.py --pull`，发布镜像，VERIFY_EXIT=0）

- 镜像 `changlwtju/nastart-agent:0.4.0`；Agent healthy。
- `HTTPS GET /healthz` 200（`{"ok": true, "version": "0.4.0"}`）；同一端口明文 HTTP 被拒。
- 配对 200；`GET /v1/handshake` 200，`certificate.fingerprintSha256`、`notAfter`（2110862725，约 2036-11-21）、`subject`（容器主机名）与独立 `openssl x509` 算出的一致。
- 数据卷权限：`tls-key.pem=0600`、`tls-cert.pem=0644`。
- `GET /v1/diagnostics` 200，`certificate` 检查为 ok（detail "3650 days remaining"）。
- 同一容器 healthy → unhealthy 已验证；测试栈已清理（容器、卷、网络均删）。

## 持久 Agent（Mac，供 App 配对）

- 项目 `nastart-agent-https`，镜像 `changlwtju/nastart-agent:0.4.0`，端口 8787（Mac 局域网 192.168.1.82:8787），命名数据卷，Agent 与代理均运行中，Agent healthy。
- 证书：`tls-cert.pem` 0644、`tls-key.pem` 0600；指纹（SHA-256）`025a1e4fdb90e791c5615a7b35e6d2da2a811e14c90f80873572a1526613163e`；到期 2036-11-21；CN=容器主机名 `cf8424d04af1`。
- 配对码为新生成的一次性码（已用过、已消耗），token 与私钥留本机。Agent 留在运行状态供 App 连接（与第 4 件测试 Agent 验收后清理不同——本次是用户要用的 https 迁移）。

## iPhone 13 真机验收

- 设备：iPhone 13（UDID `00008110-001E543122E0401E`），WDA 16.1.5（端口 8168）。
- 已装包：`com.changliwen.nastart`，版本 0.1.0（第 4 件装的包，含 Agent 健康状态 UI 与 https 支持；本件不改 App，无需重装）。
- 配对前基线：启动台无 Agent 状态行，设备卡为 DSM 数据（CPU 7%、内存 17%、硬盘 15%）。
- 配对：在"设备 → Nastart Agent → 配置 Nastart Agent"表单里填 `https://192.168.1.82:8787`，输入新一次性配对码，打开"跳过 SSL 验证"，点"配对 Agent"。表单显示"已连接主机 cf8424d04af1"、"Agent 已配对并验证"。
- 配对后：启动台顶部出现"✅ Agent 已连接"状态行；设备卡换成 Agent 主机指标（CPU 8%、内存 9%、硬盘 0%）。
- 过程问题：WDA `setValue` 往地址栏追加而非替换，第一次把地址打成乱码；用 `clear` 端点清掉后重填正确。配对码在 WDA 源码输出里出现过一次（工具回显），已消耗失效，不再复述。

## 观察项

- 设备卡硬盘显示 0%：Agent 跑在 Docker 里，磁盘指标读的是容器文件系统（Docker Desktop 虚拟机盘），不是 Mac 主机盘。第 4 件原生跑在 Mac 上时显示的是 Mac 磁盘 97%。这是 Docker 部署的指标口径差异，不是第 7 件的回归；NAS 上部署时以 NAS 磁盘为准。

## 收尾

- 持久 Agent（`nastart-agent-https` 项目）留在 Mac 上运行，App 保持 https 配对连接。配对码与 token 留在本机，未外传。
- 已发布镜像 `changlwtju/nastart-agent:0.4.0` 与 `latest` 留在 Docker Hub 与本机，供后续升级流程使用。
- Agent 第 7 件已验收通过。下一步按拆分走第 8 件（SPK 及其他平台安装），等用户发话再定。
