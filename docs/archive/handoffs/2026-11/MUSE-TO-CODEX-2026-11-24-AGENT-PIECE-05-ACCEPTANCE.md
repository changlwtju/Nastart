# Agent 第 5 件验收记录：受限 API 权限——Docker socket 过滤代理（2026-11-24）

## 结论：通过

Muse 复跑发布、干净拉取、独立起栈与全部负向探针：代理只转发白名单调用，Agent 容器里没有真实 Docker socket，过滤后的 socket 对读以外的请求一律 403。11 项 Python 测试复跑全过。

## 核对

- 12 文件 SHA-256 均 OK（清单 `docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-05.sha256`）。
- Docker 29.9.2 + Compose v5.6.1。
- Python 测试复跑：11 项全过（5 项现有 + 6 项新代理测试：白名单解析、拒绝不达后端且不记 body、转发原样返回、后端状态/body 保留、stale socket 清理与显式权限、后端不可用返回 502）。

## 发布

- 完整工作区运行 `NASTART_DOCKERHUB_NAMESPACE=changlwtju scripts/publish_agent_image.sh`，`0.2.0` 与 `latest` 均指向同一摘要 `sha256:56b79cf96e7e62f0fe229873e6ea7cb2849b01e8a4d7faca0da6c12c5f60af58`（双架构 amd64/arm64）。
- 发布与拉取经 GUI Terminal 跑（SSH 会话读 macOS 钥匙串被拒，Docker 凭证助手拿不到 Docker Hub 凭证；与第 3 件同一限制）。发布前清掉本机留存的 `0.2.0`/`latest`，再经 GUI Terminal 干净拉取，摘要与发布时完全一致。

## 独立起栈验证（项目 `agent-verify-05-23cef125`，临时 loopback 端口，临时卷）

- 代理容器运行中（用户 root）；Agent 容器 healthy（用户 `nastart`），镜像均为 `changlwtju/nastart-agent:0.2.0`。
- `GET /healthz` 200（`{"ok": true, "version": "0.2.0"}`）；配对 200（bearer 已签发）；`GET /v1/handshake` 200（agentVersion 0.2.0、apiVersion 1、permissionLevel read）。
- `GET /v1/snapshot` 200：`inventory.dockerAvailable=true`、`dockerError=null`，容器列表含 Agent 与代理两个容器（均 running，镜像均为 0.2.0）。
- 挂载（`docker inspect`）：Agent 只有数据卷与只读共享卷（`/run/nastart-proxy`），**没有**真实 docker.sock；代理挂有真实 `/var/run/docker.sock`（bind，`:ro`）与共享卷。真实 socket 只在代理容器。
- 过滤 socket 探针（从 Agent 容器内，`NASTART_DOCKER_SOCKET=/run/nastart-proxy/docker.sock`）：
  - `GET /v1.41/containers/json?all=1` → 200（返回真实容器列表）
  - `GET /v1.41/version` → 403
  - `POST /v1.41/containers/deadbeef0000/stop`（虚构容器 ID）→ 403
  - `DELETE /v1.41/containers/deadbeef0000` → 403
  - `GET /v1.41/containers/json`（无 `all=1`）→ 403

## 过程问题（已解决）

- SSH 会话拉取失败：Docker 凭证助手读钥匙串被拒（与第 3 件同一限制）。发布与干净拉取改走 GUI Terminal 跑通。
- 验收时一次断言写错层级：`dockerAvailable`/`dockerError` 在快照的 `inventory` 子对象里，不在顶层；数据本身正确（`dockerAvailable=true`），已按实际结构核对。
- 清理时一次 `docker` 不在 PATH（heredoc 里 Docker 路径 export 晚了一步），重跑清理成功。

## 收尾

- 测试栈已 `docker compose down --volumes`，容器与临时卷已删；配对码与 token 留在本机，未外传。
- 已发布镜像 `changlwtju/nastart-agent:0.2.0` 与 `latest` 留在 Docker Hub 与本机，供后续升级流程使用。
- Agent 第 5 件已验收通过。下一步按拆分走第 6 件（增量监控/诊断），等用户发话再定。
