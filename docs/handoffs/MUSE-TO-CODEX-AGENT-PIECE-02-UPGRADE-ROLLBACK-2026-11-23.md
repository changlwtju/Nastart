# Agent 第 2 件交接：升级/回退（本地构建版）（2026-11-23）

## 目标

在已部署 Agent 的主机（NAS 或 Mac）上，把 Agent 升级到新版本；新版本不健康时自动回退到旧版本。升级过程不丢配对数据。

## 现状（已摸清，Codex 不用再探）

- 现有部署是 `scripts/install_agent_via_ssh.sh`：经 SSH 把 4 个文件（`nastart_agent.py`、`Dockerfile`、`compose.yaml`、`compose.sh`）拷到目标主机的 `~/.nastart-agent`，再跑 `compose.sh up -d --build`（无 Docker 时回退 nohup Python）。**没有升级/回退逻辑**：重跑就是直接重建重启，不验新容器是否 healthy、不留旧镜像、不回退。
- 镜像是本地构建（无 registry）；`compose.yaml` 的 image 标签由 `compose.sh` 从 `AGENT_VERSION` 派生（第 1 件）；数据在命名卷 `nastart-agent-data` 里（配对 token 持久化，`agent/nastart_agent.py` 的 `AgentState` 读写该卷）。
- `compose.yaml` 有 `restart: unless-stopped` + healthcheck（第 1 件），但 `up -d --build` 本身不检查新容器是否 healthy。

## 本件做

### 1. 升级

新增升级脚本（或扩展 install 脚本加 `upgrade` 子命令，按实际结构定）：经 SSH 把新版 4 个文件拷到目标主机，构建新镜像（`nastart-agent:<新版本>`），保留旧镜像（`nastart-agent:<旧版本>`），停止旧容器、启动新容器，等 healthcheck 变 healthy，验 `/healthz` 与 `/v1/handshake` 均 200 且版本为新版本。

### 2. 回退

新容器在超时内未 healthy（或端点验失败）时，自动停掉新容器、用旧镜像重新启动，验旧容器 healthy 且版本为旧版本；升级脚本以非 0 退出并说明已回退。回退时镜像标签的取法由 Codex 定（注意 `compose.sh` 是从当前 `nastart_agent.py` 的 `AGENT_VERSION` 派生标签的，直接重跑会得到新版本标签，须另想办法指定旧版本）。

### 3. 数据

升级/回退均不碰命名卷 `nastart-agent-data`（配对 token 不丢）；升级后验一次旧配对 token 仍有效（用旧 token 调 `/v1/handshake` 应 200）。

### 4. 测试

在 Mac 本地 Docker 上跑完整升级/回退流程并附验证脚本：升级（旧版→新版，healthy，版本为新版，旧 token 仍有效）；回退（用一个故意不健康的版本触发回退，新版不健康→自动回旧版，healthy，版本为旧版）。回退路径必须实际跑通，不只验 happy path。

## 不做

- 镜像发布到 registry（需用户选 registry，另立一件）。
- SPK、受限 API 权限、App 配对合并、自动证书、正式云/官网。
- 改 `AGENT_VERSION` 的值。

## 文件

- `scripts/install_agent_via_ssh.sh`（扩展）或新增升级脚本（按实际结构定）。
- `scripts/verify_agent_docker.py`（扩展）或新增验证脚本（升级/回退流程验证）。
- `agent/README.md`（升级/回退用法）。

## 验收

- Codex 在 Mac 本地 Docker 上跑通升级（旧版→新版，healthy，版本为新版，旧 token 仍有效）与回退（新版不健康→自动回旧版，healthy，版本为旧版），交回各步的 `docker inspect` 健康状态与端点响应。
- Muse 在 Mac 上复跑同一升级/回退流程（用 Docker.app 的 CLI，`/Applications/Docker.app/Contents/Resources/bin`，须先 export PATH）。
