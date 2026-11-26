# Agent 第 1 件交接：Docker 健康检查与镜像命名（2026-11-23）

## 目标

Docker 能判断 Agent 容器是否真的健康（不只是进程在跑），且构建出的镜像有名字和版本标签，升级/回退有据可依。

## 现状（已摸清，Codex 不用再探）

- Agent 是 NAS 端增强服务（依赖-free Python，`agent/nastart_agent.py`，450 行），不是 AI 助手。路由：`GET /healthz`、`GET /v1/handshake`、`GET /v1/snapshot`、`GET /v1/diagnostics`、`POST /v1/pair`。
- **版本上报已做，不用再加**：`AGENT_VERSION = "0.1.0"`、`API_VERSION = 1`（`nastart_agent.py:30-31`）；`handshake()` 已返回 `agentVersion` / `apiVersion`；`/healthz` 已返回 `{"ok": true, "version": AGENT_VERSION}`。
- **`compose.yaml` 无 `healthcheck:`**：Docker 无法发现假死（进程在、服务不响应）的容器；`restart: unless-stopped` 只处理进程退出。
- **`compose.yaml` 用 `build: .` 但无 `image:`**：构建出的镜像无名无版本，无法区分版本、无法回退。
- 现有测试 `agent/test_agent.py`（4 个方法）：配对码校验、配对一次有效 + token 持久化、限流 + 已消费配对码重启后仍禁用、快照/handshake 只读结构。无 Docker 生命周期测试。
- Mac 上有 Docker.app（CLI 在 `/Applications/Docker.app/Contents/Resources/bin`，不在默认 PATH 里，须先 export PATH）；Muse 可在 Mac 上直接验证 Docker 行为。

## 本件做

### 1. `compose.yaml` 加 `healthcheck:`

调容器内 `/healthz`，用镜像内已有工具（python3 或 wget），不为此加新依赖。`interval` / `timeout` / `retries` / `start_period` 按 Agent 启动速度定（服务启动快，给合理值）。若同时在 `Dockerfile` 加 `HEALTHCHECK`，说明与 compose 二选一或并存的理由，不要两处各写一套不一致的值。

### 2. `compose.yaml` 加 `image:`

`image: nastart-agent:<version>`，版本号与 `AGENT_VERSION` 一致。避免两处写死漂移（做法由 Codex 定，如环境变量默认值或构建参数），并在交回里说明版本号的唯一来源。

### 3. 测试

- `agent/test_agent.py` 加用例：healthcheck 命令的逻辑——服务在跑时命令退出 0，服务停掉后命令退出非 0（用直接启动的 `nastart_agent.py` 进程验证，不依赖 Docker）。
- 另附一个可跑的验证脚本（或扩展 `scripts/agent_smoke_test.py`）：构建镜像、启动容器、等到 `docker inspect` 的 Health.Status 为 healthy、`GET /healthz` 与 `GET /v1/handshake` 均 200；模拟不健康（停掉服务进程）后状态变 unhealthy。

## 不做

- 镜像发布到 registry、升级/回退流程（下一件）。
- SPK、受限 API 权限、App 配对合并、自动证书、正式云/官网。
- 改 `AGENT_VERSION` 的值。

## 文件

- `agent/compose.yaml`（healthcheck + image）。
- `agent/Dockerfile`（仅当决定加 HEALTHCHECK 时）。
- `agent/test_agent.py`（新增用例）。
- `scripts/agent_smoke_test.py` 或新增验证脚本（Docker 行为验证）。

## 验收

- Codex 自己构建镜像、启动容器并跑通上述验证，交回 `docker inspect` 的 Health.Status（healthy 与 unhealthy 各一次）与 `/healthz` / `/v1/handshake` 的响应。
- `agent/test_agent.py` 全部通过。
- Muse 验收：在 Mac 上用 Docker.app 的 CLI 复跑构建与健康检查（healthy → unhealthy）、校验 compose.yaml 配置、复跑 `test_agent.py`。
