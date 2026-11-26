# Agent 第 6 件交接：增量监控/诊断——事件历史（2026-11-24）

## 目标

Agent 现在只会回答"此刻怎么样"，不记得"刚才发生了什么"。容器半夜停了又起来、Docker 短暂断过、有人试错配对码，这些事一过就没了痕迹。本件让 Agent 记住它们：一个有界、可持久化的事件历史，后台定期采样发现变化就记下来，`/v1/diagnostics` 能查到。App 现在不改显示（以后一件再接），本件只做 Agent 侧的记录与接口。

## 现状（已摸清，Codex 不用再探）

- `/v1/snapshot`、`/v1/handshake`、`/v1/diagnostics` 全是瞬时值：`/v1/diagnostics` 只有两项检查（agent ok、docker-read ok/unavailable + 容器数），没有历史。`AgentState` 只留了 `started_at`、`failed_pairing_attempts`（内存里，仅用于配对限流）和 token/配对码摘要；重启后失败记录就丢了。
- `docker_containers()` 只调一个接口 `GET /v1.41/containers/json?all=1`，返回每容器的 12 位 id、name、state、status、ports。`host_snapshot` 里 `inventory.dockerAvailable` 由 `docker_error is None` 决定。
- `threading` 已 import，`AgentState` 已有 `threading.Lock`，`AgentServer` 是 `ThreadingHTTPServer`（`daemon_threads = True`）。数据目录已有 `atomic_write`（token 持久化用的同款写法）。
- iOS App 目前**不调** Agent 的 `/v1/diagnostics`（grep 确认过，App 里的 diagnostics 字样是它自己的内部诊断分类）。给 diagnostics 加字段不会破坏 App。
- 镜像发布与升级流程沿用第 3 件（`scripts/publish_agent_image.sh`、`scripts/verify_agent_docker.py`）。

## 本件做

### 1. 事件环形缓冲（`AgentState` 里，有界 + 持久化）

- `AgentState` 维护一个内存事件列表，上限 100 条，超了丢最旧的。事件是带 `timestamp`（Unix 秒，与现有 `timestamp` 字段一致）的 dict。
- 持久化到数据目录 `events.json`，用现有的 `atomic_write` 写；启动时读回（文件不存在或损坏时从空开始，不 crash）。每次新增事件后写盘。
- 只记三种事件，字段固定（以后 App 显示按这个形状解析，不要另发明）：
  - `container.state`：`{"type": "container.state", "timestamp": <int>, "containerId": "<12位>", "containerName": "<name>", "from": "<旧state>", "to": "<新state>"}`
  - `docker.availability`：`{"type": "docker.availability", "timestamp": <int>, "available": <bool>, "detail": "<dockerError 或 null>"}`
  - `pairing.failed`：`{"type": "pairing.failed", "timestamp": <int>, "source": "<来源地址>"}`
- 配对失败事件**绝不记配对码本身**（只记 source 与时间）。`pair()` 里已有的失败限流逻辑不动，只在失败分支追加记事件。

### 2. 后台采样线程（只做这一件新增的常驻行为）

- `AgentServer` 启动一个 daemon 采样线程，每 30 秒调一次 `docker_containers()`（间隔由环境变量 `NASTART_SAMPLE_INTERVAL_SECONDS` 给，默认 30，最小 10，小于 10 按 10 算）。
- 采样线程只与"上次见到的状态"比较：首次采样只建基线，**不产生事件**（否则 Agent 每次启动都会给每个容器刷一条假的 state 事件）；之后容器 `state` 变了记 `container.state`，docker 可用性翻转记 `docker.availability`。
- 采样线程绝不能拖垮 Agent：Docker 调用不持 `AgentState.lock`（只在追加事件时短暂持锁）；采样里任何异常都 catch 住（记成 docker 不可用事件或直接跳过），线程继续循环。
- 只有采样线程更新"上次见到的状态"并记容器/docker 事件；请求路径（snapshot/handshake/diagnostics）只读当前状态与事件缓冲，不记这类事件，避免重复计数与竞态。

### 3. `/v1/diagnostics`（加字段，现有 `checks` 不动）

- 新增 `uptimeSeconds`（`int(time.time() - started_at)`）、`eventCount`（当前事件数）、`events`（数组，**最新在前**，最多 100 条）。
- 其余端点（`/healthz`、`/v1/handshake`、`/v1/snapshot`）不动。

### 4. 版本

- `AGENT_VERSION` 从 `0.2.0` 升到 `0.3.0`（Agent 代码变了，镜像内容变了，tag 必须变）。其余版本逻辑不动。

### 5. 测试

- `agent/test_agent.py` 内新增测试类（或新建测试文件）：环形缓冲上限 100 条（超了丢最旧）、持久化往返（写盘再读回一致，损坏文件从空开始）、状态变迁检测（变了记事件、没变不记、首次采样不记）、Docker 可用性翻转记事件、配对失败记事件且事件里不含配对码、采样间隔环境变量解析（默认 30、小于 10 按 10）。
- 现有测试（`AgentStateTests`、`DockerHealthcheckTests`、`DockerSocketProxyTests`）须继续全过。

### 6. 文档

- `agent/README.md` 里端点说明处补 `/v1/diagnostics` 新字段与 `NASTART_SAMPLE_INTERVAL_SECONDS` 的说明。

## 不做

- App 显示事件历史（以后一件再接，本件只做 Agent 侧）。
- 资源趋势采样（load/memory/disk 的历史曲线，如以后需要另立一件）。
- 日志保留/查询接口；改 snapshot/handshake 的形状。
- 自动证书、正式云/官网。

## 文件

- 改：`agent/nastart_agent.py`（事件缓冲 + 采样线程 + diagnostics 字段 + `AGENT_VERSION` 一行）。
- 改：`agent/test_agent.py`（或新建测试文件）。
- 改：`agent/README.md`（端点说明）。

## 验收

- Codex 自己跑通新增与现有 Python 测试。
- Muse 复跑：构建并发布 `0.3.0` 镜像（走第 3 件流程），独立 Compose 起栈；`/v1/diagnostics` 返回 `events` 与 `uptimeSeconds`；停/起一个容器后 diagnostics 里出现对应的 `container.state` 事件；停掉代理（或断 Docker）后出现 `docker.availability` 事件；重启 Agent 容器后事件仍在（持久化）。
