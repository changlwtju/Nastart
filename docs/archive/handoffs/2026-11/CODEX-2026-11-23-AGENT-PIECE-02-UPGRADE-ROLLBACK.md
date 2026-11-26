# Agent 第 2 件交回 Muse

2026-11-23 · 工作区 `/Users/lagransun/workspace/Nastart`。[Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-AGENT-PIECE-02-UPGRADE-ROLLBACK-2026-11-23.md)

## 升级与回退

- [upgrade_agent_via_ssh.sh](../../../../scripts/upgrade_agent_via_ssh.sh) 经 SSH 上传新版四个文件到私有临时目录，流式执行目标主机脚本。旧 Bearer token 从用户指定的私有文件经 SSH 标准输入传输，与 Docker 构建目录分离。
- [upgrade_agent_on_host.sh](../../../../scripts/upgrade_agent_on_host.sh) 核对运行容器、旧版本标签和镜像 ID、Compose 项目、现有命名卷及旧 token。构建在原容器运行时进行。候选版本必须使用独立标签，集成后通过同一 Compose 项目和已有 `nastart-agent-data` 卷启动。健康后从容器内请求 `/healthz` 与 `/v1/handshake`，核对 HTTP 200 和版本。
- 切换失败时从本机备份恢复四个部署文件，停止候选容器。回退通过 `NASTART_AGENT_VERSION=<旧版本> docker compose … up --no-build` 明确使用原镜像，并核对该标签对应原镜像 ID。回退通过后退出 1；回退也失败时退出 2，恢复资料在 `~/.nastart-agent/.upgrade-lock`。
- [verify_agent_upgrade.py](../../../../scripts/verify_agent_upgrade.py) 在 Mac 上建临时 Compose 项目、回环 SSH 服务和独立凭据。用同一 SSH 入口跑成功升级及故障回退。只做一次测试配对，三轮 handshake 都使用最初取得的 token。所有测试版本均从临时源码副本构建。

生产升级的用法见 [Agent README](../../../../agent/README.md)。适用于现有的版本化 Compose 部署，`--token-file` 接收最初配对返回的 Bearer token。

## 实测与证据

北京时间 16:46:58–16:48:18，Docker Engine 29.9.2（Linux arm64）和 Compose v5.6.1。在同一隔离项目上经回环 SSH 运行两次生产升级入口。

| 阶段 | 测试镜像标签 | Docker 健康状态 | 端点验收 |
| --- | --- | --- | --- |
| 基线 | `0.1.0-verify-e6925097` | `running healthy` | `/healthz` 与首次配对 token 的 `/v1/handshake` 均 200，版本为基线 |
| 成功升级 | `0.1.1-verify-e6925097` | `starting → healthy` | 两端点均 200，版本为 `0.1.1-verify-e6925097` |
| 故障候选 | `0.1.2-verify-e6925097` | `starting → unhealthy`，30 秒内未恢复 | 夹具把 `/healthz` 改为 503，健康门槛触发自动回退 |
| 回退完成 | `0.1.1-verify-e6925097` | `starting → healthy` | 两端点均 200，版本回到 `0.1.1-verify-e6925097`，升级命令退出 1 |

基线、成功升级后及回退后的 handshake 均使用初始配对取得的 token，返回同一个 `agentId`。验证脚本还核对了原卷名称、两次保留的旧镜像 ID 和回退后的四个部署文件。测试项目、命名卷、临时 SSH 服务和测试镜像均已清理。`test_agent.py` 5 项通过。

私有证据目录为 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-02.DG0Fdz`。`upgrade-final.log` 含两次实际 SSH 升级的构建、切换、回退与清理日志。`upgrade-observations.txt` 提取 inspect 状态与两端点的响应字段，含旧 token 校验证据。另有 `test-agent.log`、`docker-version.log`、`compose-version.log` 和首轮配置检查日志。

先用目标主机脚本验证本地事务。回环 SSH 首试时，隔离 Home 中缺少 Docker Desktop 客户端配置，启动前预检已退出。验证脚本随后显式传递本机 Docker 配置目录，并继续使用隔离的 SSH Home、端口、密钥和 known_hosts。

## 更新文件 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| `agent/README.md` | `15cc24b451b2b40c944cd0a2857ce6ba9f6eaec3d403d3fa523fb47b070b3ad9` |
| `scripts/upgrade_agent_via_ssh.sh` | `592dfd122ab3f53f49180f5d16746426929e0694bea646cb2830a400d88dc7fe` |
| `scripts/upgrade_agent_on_host.sh` | `3fc1847ee6e3d7c3832916742a43705c3f13ebe0db3f965a137b87d6a9e10b02` |
| `scripts/verify_agent_upgrade.py` | `97f2f5b96f2d8ede0a921840a6c07330687eaa3693c84c26c68de707d8744fdb` |

四项清单 `agent-piece-02-sources.sha256` 的 SHA-256 为 `ff4ddfff720d04a0ede13e69cf321299832ee8dfd67598937b3bd7702a4c1ee7`。

## Muse 复跑

在目标 Mac 启动 Docker Desktop 后，从工作区根目录执行。

```sh
cd /Users/lagransun/workspace/Nastart
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
shasum -a 256 -c "$HOME/Library/Application Support/Nastart/PrivateHandoff/agent-piece-02.DG0Fdz/agent-piece-02-sources.sha256"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s agent -p test_agent.py -v
PYTHONDONTWRITEBYTECODE=1 python3 -u scripts/verify_agent_upgrade.py
```

失败时请回传测试文件校验、Docker/Compose 版本、失败阶段、对应的 inspect 状态和脱敏 HTTP 响应。验证脚本使用临时测试 token，真实 Bearer token 留在本机私有文件。
