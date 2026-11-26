# Agent 第 5 件交接：受限 API 权限——Docker socket 过滤代理（2026-11-24）

## 目标

Agent 容器不再直接挂载真实的 Docker socket。新增一个最小、无依赖的过滤代理（sidecar 容器），它独占真实 socket，只把 Agent 唯一需要的读调用转发给 Docker 守护进程，其余一律拒绝。即使 Agent 进程被攻破，攻击者也拿不到 Docker 写权限（停/删/建容器、挂载宿主机目录）。

## 现状（已摸清，Codex 不用再探）

- Agent 对 Docker 只发**一个**调用：`GET /v1.41/containers/json?all=1`（`agent/nastart_agent.py` 的 `docker_containers()`，被 `/v1/snapshot` 与 `/v1/diagnostics` 调用；`/healthz` 与 `/v1/handshake` 不碰 Docker）。`NASTART_DOCKER_SOCKET` 环境变量已可改 socket 路径（默认 `/var/run/docker.sock`），改路径不需要改 Agent 代码。
- 现行 `agent/compose.yaml` 把 `/var/run/docker.sock:/var/run/docker.sock:ro` 直接挂进 Agent 容器。**`:ro` 只让 socket 文件本身不可写，并不限制通过它调用的 Docker API**——拿到 socket 就能调任意写接口（停、删、建容器，等价宿主机 root）。这是本件要堵的口子（规划文档 `docs/project/AGENT_DEPLOYMENT_OPTIONS.md` 第 7 行已写明）。
- Agent 是无依赖 Python（只用标准库），容器以非 root 用户 `nastart` 运行，`read_only: true`、`no-new-privileges:true`、`cap_drop: ALL`。代理沿用同一套约束（只用标准库）。
- 代理必须是**独立容器**，不能是 Agent 容器里的第二个进程：真实 socket 一旦挂进 Agent 容器，被攻破的 Agent 进程就能绕过任何进程内过滤直接打开它。只有"真实 socket 只在代理容器里、Agent 容器里只有过滤后的 socket"才是有效边界。
- 镜像发布与升级流程沿用第 3 件（`scripts/publish_agent_image.sh`、`scripts/upgrade_agent_on_host.sh`、`scripts/verify_agent_docker.py`，后者从 compose.yaml 读镜像名与版本，会自动跟上新版本）。

## 本件做

### 1. 过滤代理 `agent/docker_socket_proxy.py`（新建，只用标准库）

- 监听一个 Unix socket（路径由环境变量 `NASTART_PROXY_SOCKET` 给，默认 `/run/nastart-proxy/docker.sock`）；真实 Docker socket 路径由 `NASTART_DOCKER_SOCKET` 给（默认 `/var/run/docker.sock`），复用 Agent 现有的 `UnixHTTPConnection` 写法连真实 socket。
- 白名单只有一条：**方法 `GET`、路径 `/v1.41/containers/json`、查询参数仅 `all=1`**（解析查询串，只含 `all=1` 一个参数才放行）。其余方法、路径、参数一律返回 403（短 JSON，如 `{"error": "forbidden"}`），不转发。
- 放行的请求原样转发给真实 socket，把后端的状态码与 body 原样回给调用方；连不上后端时返回 502（这样 Agent 的 `dockerError` 能正常反映代理/后端不可用，Agent 本身不改）。
- 启动时先 unlink 已存在的 socket 文件（防止旧容器留下的 stale socket），再 bind；socket 文件权限要让 Agent 用户能连上（见下面"权限"）。
- 拒绝时往 stderr 记一行日志，只记方法与路径，不记 body（body 可能含敏感内容）。
- 结构要能被测试 import：暴露 `is_allowed(method, path) -> bool`，以及一个可注入后端 socket 路径的请求处理函数/类，测试用假后端验证转发与拒绝。

### 2. 权限（有意为之，不是疏忽）

- 代理容器以 **root** 运行（compose 里 `user: root`，只给代理服务）。理由：代理是受信的守门组件（约百行标准库代码，只解析请求行、不监听任何 TCP 端口），它需要读真实 docker.sock 并在共享卷里建 socket；Agent（对外暴露 8787、攻击面大）保持非 root `nastart` 不变。这是标准做法——特权只留在最小的守门进程里，不留在对外服务里。
- 代理建出的 socket 文件权限须让 Agent（`nastart` 用户）能连上（如 mode 0660 并 chgrp 到 nastart 组，或 0666；二选一，代码里显式 chmod，不要依赖 umask 默认值）。

### 3. `agent/compose.yaml`（改）

- 新增服务 `nastart-agent-proxy`：用**同一镜像**（不另建镜像），`entrypoint: ["python3", "/app/docker_socket_proxy.py"]`；挂载真实 socket `/var/run/docker.sock:/var/run/docker.sock:ro`；挂载共享命名卷；`restart: unless-stopped`；与 Agent 同样的加固（`read_only: true`、`no-new-privileges:true`、`cap_drop: ALL`、`user: root` 例外见上）。
- Agent 服务：**删掉**真实 docker.sock 挂载；共享卷以 `:ro` 挂进 Agent（Agent 只需连 socket，不需建）；加环境变量 `NASTART_DOCKER_SOCKET=/run/nastart-proxy/docker.sock`；加 `depends_on: [nastart-agent-proxy]`（只定启动顺序，不加健康条件——代理未起时 Agent 会正常报 `dockerError`，不 crash）。
- 新增命名卷（如 `nastart-agent-proxy-sock`），两容器挂到同一路径（如 `/run/nastart-proxy`）。

### 4. `agent/Dockerfile`（改）

- 加一行 COPY 代理脚本（与 `nastart_agent.py` 同级），权限同现有脚本（0555）。

### 5. 版本

- `AGENT_VERSION` 从 `0.1.0` 升到 `0.2.0`（镜像内容变了，tag 必须变，不能让 `:0.1.0` 指向不同内容）。其余版本逻辑不动（`compose.sh` 从代码读版本，发布/升级脚本自动跟上）。

### 6. 测试

- `agent/test_agent.py` 内新增代理测试类（或新建测试文件）：用假 Docker 后端（一个 Unix socket HTTP 服务，记录收到的请求）+ 代理实例，验证：
  - `GET /v1.41/containers/json?all=1` 被转发到后端且响应原样返回；
  - `POST /v1.41/containers/<id>/stop`、`DELETE /v1.41/containers/<id>`、`GET /v1.41/version`、`GET /v1.41/containers/json`（无 `all=1`）、`GET /v1.41/containers/json?all=1&foo=bar` 各自返回 403，**且后端没收到任何请求**。
- 现有测试（`AgentStateTests`、`DockerHealthcheckTests`）须继续全过。

## 不做

- 改 Agent 的 Docker 调用（仍是那一个 GET）、改配对/token/握手逻辑。
- 自动证书、正式云/官网。
- 不给代理加除白名单外的任何端点（不加 `/healthz` 之类；代理的存活由 `docker ps` 与 Agent 的 `dockerError` 反映，不另开检查口）。

## 文件

- 新建：`agent/docker_socket_proxy.py`。
- 改：`agent/compose.yaml`、`agent/Dockerfile`、`agent/nastart_agent.py`（仅 `AGENT_VERSION` 一行）。
- 测试：`agent/test_agent.py`（或新建测试文件）。

## 验收

- Codex 自己跑通新增与现有 Python 测试。
- Muse 复跑：构建并发布 `0.2.0` 镜像（走第 3 件流程），用 compose 起整栈；Agent 的 `/v1/snapshot` 仍能返回容器列表（证明白名单调用走通）；直接对过滤后的 socket 发 `GET /v1.41/version` 与 `POST /v1.41/containers/<id>/stop` 均返回 403；`docker inspect` Agent 容器确认**没有**真实 docker.sock 挂载；代理容器在运行。
