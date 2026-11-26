# Agent 第 6 件验收记录：增量监控/诊断——事件历史（2026-11-24）

## 结论：通过

Muse 复跑发布、干净拉取、独立起栈与全流程事件验证：采样基线建立后无假事件；停/启测试容器先后记下两条 `container.state`；停/启代理先后记下 `docker.availability` false 与 true；重启 Agent 后同一 token 仍可用、4 条历史逐条一致且最新在前、运行时长重新计数。18 项 Python 测试复跑全过。

## 核对

- 7 文件 SHA-256 均 OK（清单 `docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-06.sha256`）。
- Docker 29.9.2 + Compose v5.6.1。
- Python 测试复跑：18 项全过（11 项现有 + 7 项新事件历史测试）。

## 发布

- 完整工作区运行 `NASTART_DOCKERHUB_NAMESPACE=changlwtju scripts/publish_agent_image.sh`，`0.3.0` 与 `latest` 均指向同一摘要 `sha256:532a0bf0b9972a80811522daa0e35d9ec9329c07d5329d7ffb27f766b2ea4530`（双架构 amd64/arm64）。
- 发布与拉取经 GUI Terminal 跑（SSH 会话读 macOS 钥匙串被拒，Docker 凭证助手拿不到 Docker Hub 凭证；与第 3、5 件同一限制）。发布前清掉本机留存的 `0.3.0`/`latest`，再经 GUI Terminal 干净拉取，摘要与发布时完全一致。

## 独立起栈验证（项目 `agent-verify-06-7b54a5cb`，临时 loopback 端口，临时卷，采样间隔 10 秒）

- 代理容器运行中（root）；Agent 容器 healthy（`nastart`），镜像均为 `changlwtju/nastart-agent:0.3.0`。
- `GET /healthz` 200（`{"ok": true, "version": "0.3.0"}`）；配对 200（bearer 已签发）；`GET /v1/snapshot` 未在本轮重复验（第 5 件已覆盖）。
- 基线：起栈后采样建立基线，`/v1/diagnostics` 200，`events=[]`、`eventCount=0`、`uptimeSeconds=53`、`checks` 两项均在（agent ok、docker-read ok、3 个容器），无假事件。
- 停测试容器（`agent-verify-06-7b54a5cb-victim`，本机镜像起的 `sleep 600`）：5 秒内出现 `container.state`（running → exited，ts 1795494062）。
- 再启测试容器：出现 `container.state`（exited → running，ts 1795494083），`eventCount=2`，最新在前。
- 停代理容器：出现 `docker.availability`（available=false，detail=`ConnectionRefusedError`，ts 1795494103），此时 checks 里 docker-read 为 unavailable、容器数为 0；`eventCount=3`。
- 再启代理容器：出现 `docker.availability`（available=true，detail=null，ts 1795494123），checks 恢复 ok、3 个容器；`eventCount=4`，`uptimeSeconds=131`。
- 重启 Agent 容器：**动态端口变了**（127.0.0.1:54653 → 127.0.0.1:54703），重新查询端口后用同一 token 查 diagnostics 得 200；4 条历史逐条一致且最新在前（时间戳降序）；`uptimeSeconds` 从 131 重计为 31。

## 过程问题（已解决）

- SSH 会话拉取失败：Docker 凭证助手读钥匙串被拒（与第 3、5 件同一限制）。发布与干净拉取改走 GUI Terminal 跑通。
- 测试容器镜像：`alpine:latest` 本机没有，SSH 拉取又撞钥匙串限制。改用本机已有的 `changlwtju/nastart-agent:0.3.0` 镜像、`--entrypoint sleep` 起 `sleep 600` 作测试容器。
- 验收驱动脚本首次写 state 文件时在 victim 步骤崩了，`base_url` 没写进去；按当轮输出重建了 state（pairing code 在文件里），并重新核对了端口与容器状态。
- 重启后端口变了（54653 → 54703），与 Codex 交接里提醒的一致；重新查询端口后才查诊断，旧端口已失效。

## 收尾

- 测试容器已删，测试栈已 `docker compose down --volumes`，容器与临时卷已删；配对码与 token 留在本机，未外传。
- 已发布镜像 `changlwtju/nastart-agent:0.3.0` 与 `latest` 留在 Docker Hub 与本机，供后续升级流程使用。
- Agent 第 6 件已验收通过。下一步按拆分走第 7 件（自动证书），等用户发话再定。
