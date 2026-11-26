# Agent 第 3 件 Docker Hub 发布交接（2026-11-23）

Mac 已把 `changlwtju/nastart-agent:0.1.0` 与 `changlwtju/nastart-agent:latest` 推到公开仓库。两个标签指向同一 OCI 镜像索引，包含 `linux/amd64` 和 `linux/arm64`。以匿名请求读取两标签 manifest 均返回 HTTP 200。 [Docker Hub 仓库](https://hub.docker.com/r/changlwtju/nastart-agent)

## 实现

- 发布脚本用 Buildx 构建双架构镜像，先推版本标签，再推 `latest`。发布、Compose 和 SSH 工具均要求调用方提供 `NASTART_DOCKERHUB_NAMESPACE`。Compose 包装脚本从 `nastart_agent.py` 的 `AGENT_VERSION` 读版本，当前为 `0.1.0`。
- SSH 安装和升级默认 `--pull`，先显式拉取版本镜像，再执行 `up --no-build --pull never`。`--build` 保留本地构建，安装脚本在无 Compose 时可通过此选项使用原有 Python 方式。Compose 文件的 `pull_policy` 从 `never` 改为 `missing`，供直接使用 Compose 时按本地镜像是否存在决定。SSH 安装等到容器 `healthy` 才报就绪，已有容器交升级脚本处理。
- 升级在旧容器运行时准备候选镜像，验证候选的健康、版本和原 token。支持从第 1–2 件的无命名空间镜像迁移。失败时使用原部署文件和旧的本地镜像回退，回退命令同样使用 `--no-build --pull never`。

## Mac 证据

Docker Desktop 4.98.0，Engine 29.9.2，Compose 5.6.1。首次构建的 Docker Hub 认证请求 TLS 超时，重试时为 CLI 使用 Mac 既有 HTTPS 代理，随后构建和推送成功。

两次 `docker push` 的结果行

```text
The push refers to repository [docker.io/changlwtju/nastart-agent]
0.1.0: digest: sha256:18dfe1cb216fff62b8ea25f988a77a8dafe7bd3ff75558d0b7401256c0311373 size: 1609
The push refers to repository [docker.io/changlwtju/nastart-agent]
latest: digest: sha256:18dfe1cb216fff62b8ea25f988a77a8dafe7bd3ff75558d0b7401256c0311373 size: 1609
```

删除构建产生的本地版本标签、`latest` 标签及镜像 ID 后，三项 `docker image inspect` 均找不到目标。Compose 从 Docker Hub 拉取，返回相同索引摘要。此次使用独立项目、回环端口和新数据卷，Docker 复用了本机共有层缓存。

```text
Image changlwtju/nastart-agent:0.1.0 Pulled
Pulled RepoDigests=["changlwtju/nastart-agent@sha256:18dfe1cb216fff62b8ea25f988a77a8dafe7bd3ff75558d0b7401256c0311373"]
docker inspect 76a7d996011e Health.Status=healthy Running=True
GET /healthz 200 {"ok": true, "version": "0.1.0"}
POST /v1/pair 200 (bearer token issued)
GET /v1/handshake 200 (agentVersion=0.1.0)
```

- 回环 SSH 默认安装拉取成功，待 `healthy` 才报就绪。一次性配对首次 200，重复提交 401，原 token 握手 200。
- 回环 SSH 从旧的无命名空间索引迁移到公开版本。替换临时 Compose 夹具的健康探针后，拉到的同一镜像进入 `unhealthy`，24 秒超时触发回退，脚本返回 1。旧容器恢复 `healthy`，原 token、Agent ID、命名卷和四份部署文件一致。随后使用正常探针重新拉取升级，`0.1.0` 的健康和握手均 200，配对数据完整。
- 本地构建回归也覆盖了无命名空间到新命名空间的升级、故障候选和新命名空间的回退。5 项 Python 测试通过。双架构分别在 Mac 的 Docker Engine 运行 Python 校验版本和容器内源码哈希，amd64 使用模拟执行。测试容器、网络和临时卷均已清理。验收范围为 Mac Docker 和回环 SSH，实际 NAS 部署待验。

私有证据目录为 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-03-2026-11-23/`，含 `docker-push.log`、`clean-pull.log`、`public-manifests.log`、`ssh-pull.log`、`platform-smoke.log` 和首次超时日志。

更新文件及镜像构建输入可从工作区根目录用 `shasum -a 256 -c` 校验。 [SHA-256 清单](../../../testing/results/2026-11/CODEX-2026-11-23-AGENT-PIECE-03.sha256)

## 可转交给 Muse 的复跑指令

```text
请在 Mac 工作区 /Users/lagransun/workspace/Nastart 验收 Agent 第 3 件。源码、推送摘要和私有日志位置见 docs/archive/handoffs/2026-11/CODEX-2026-11-23-AGENT-PIECE-03-DOCKERHUB-PUBLISH.md。
先从工作区根目录运行 shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-23-AGENT-PIECE-03.sha256。
Codex 已推送 0.1.0 和 latest，且完成 Mac 干净拉取与回环 SSH 安装、升级和回退验证。请在 Docker Desktop 上使用已发布镜像复跑，跳过发布命令。若本地存在无人使用的本批镜像，可先移除对应版本、latest 标签及该镜像 ID，再确认它们不存在。
运行 NASTART_DOCKERHUB_NAMESPACE=changlwtju python3 -u scripts/verify_agent_docker.py --pull。确认拉取摘要为 sha256:18dfe1cb216fff62b8ea25f988a77a8dafe7bd3ff75558d0b7401256c0311373，容器先 healthy，/healthz、/v1/pair、/v1/handshake 均 200，两个版本字段均为 0.1.0，并核对临时容器、卷、网络已移除。
如失败，请回传 SHA 校验差异、Docker Engine/Compose 版本、pull 输出和摘要、容器健康状态、HTTP 状态与脱敏响应；配对码和 bearer token 留在本机。请保留并回传失败阶段的日志。
```
