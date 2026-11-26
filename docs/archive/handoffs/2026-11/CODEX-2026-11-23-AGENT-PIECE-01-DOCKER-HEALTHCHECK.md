# Agent 第 1 件交回 Muse

2026-11-23 · 工作区 `/Users/lagransun/workspace/Nastart`。[Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-AGENT-PIECE-01-DOCKER-HEALTHCHECK-2026-11-23.md)

## 实现

- `agent/compose.yaml` 使用镜像自带的 Python 标准库，通过容器内回环地址请求 `/healthz`。HTTP 200 退出 0，每 5 秒检查，HTTP 超时 2 秒，Docker 超时 3 秒，启动宽限 5 秒，连续失败 3 次记为不健康。
- `agent/nastart_agent.py` 的 `AGENT_VERSION` 是版本号唯一来源，当前值为 `0.1.0`。`agent/compose.sh` 每次读取该值，传给 Compose 生成 `nastart-agent:0.1.0`。`scripts/install_agent_via_ssh.sh` 的既有 Compose 分支使用同一入口。
- `agent/test_agent.py` 执行 Compose 中的实际 Python 命令，在独立端口直接启动和停止 Agent，分别断言退出 0 和非 0。
- `scripts/verify_agent_docker.py` 使用解析后的 Compose 配置构建镜像，在独立项目下通过随机回环端口运行。验证用容器使用临时数据卷与独立网络，隔离宿主 Docker socket。配对后持临时 Bearer token 请求 handshake。向验证容器发送 `SIGSTOP` 后检查相同容器、相同 PID 和启动时间；退出时恢复进程并清理容器、卷和网络。

## 结果

Python 3.15.2 共 **5 项通过**。Docker Desktop 4.98.0、Docker Engine 29.9.2（Linux arm64）、Compose v5.6.1 使用当前仓库 Dockerfile 构建并运行 `nastart-agent:0.1.0`。Docker Hub 令牌请求首次遇到 TLS 超时，随后从 AWS Public ECR 的 Docker Library 镜像取得 `python:3.13-alpine`，加载到本机同名镜像缓存后完成构建。基础镜像摘要为 `sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e`。

| 核对项 | 实测 |
| --- | --- |
| 正常请求后的同一容器 `5479583fd20b` | `Health.Status=healthy`，`Running=True` |
| `GET /healthz` | HTTP 200，`{"ok":true,"version":"0.1.0"}` |
| 配对后 `GET /v1/handshake` | HTTP 200，`agentVersion=0.1.0`，`apiVersion=1`，`permissionLevel=read` |
| 暂停服务后的同一容器 `5479583fd20b` | `Health.Status=unhealthy`，`Running=True`，PID 与启动时间相同 |

Compose 版本来源另用临时源码副本核对。把副本的 `AGENT_VERSION` 改成 `7.8.9-test`，同时给入口传入陈旧的环境值，解析结果为 `nastart-agent:7.8.9-test`。

私有证据目录为 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-01.w7NYvi`。其中 `test-agent.log` 为单元测试结果，`docker-verification.log` 为完整构建与验证记录，`docker-observations.txt` 保留两次 inspect 状态和两条完整 HTTP 响应，`version-source.log` 为版本来源核对。版本和下载记录见 `docker-version.log`、`compose-version.log`、`docker-hub-first-attempt.log` 和 `python-base-ecr.log`。

## 更新文件 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| [compose.yaml](../../../../agent/compose.yaml) | `ccf8021b3e3c2ab3db2fb603efc6735244688732374e3f00b8c1681dcfcab068` |
| [compose.sh](../../../../agent/compose.sh) | `f90d3e2ac3fe4f105b1623ee301108949e8a3ff51110e4ac4e3d496e21c64956` |
| [test_agent.py](../../../../agent/test_agent.py) | `b75cc40233c41477de15cb85fcaad536af81e761d08f5364f29fc08fd8a97d0a` |
| [Agent README](../../../../agent/README.md) | `afd300b58ad9a718c77b0f82075564087ec29f874c119901ab588866a0b6cebd` |
| [install_agent_via_ssh.sh](../../../../scripts/install_agent_via_ssh.sh) | `fc34035b2bad3c603b152df8c62cc73c6c0924e49989c58e82cd037ccdb68d8e` |
| [verify_agent_docker.py](../../../../scripts/verify_agent_docker.py) | `a31eb071175ce286b4ee70a65812e50e264041cd5108724ce6163c50f5f1e429` |

六项清单 `agent-piece-01-sources.sha256` 的 SHA-256 为 `a3deb41454f2af2f0f71b8bbc5294fe2910ba18a2cce9f017d98de02335eaa03`。

## Muse 复跑

从工作区根目录执行。配置校验需要 Docker Compose CLI，容器验证还需要本地 Docker 引擎。在这台 Mac 上，可将 `/Applications/Docker.app/Contents/Resources/bin` 加入本次终端的 `PATH`。

```sh
shasum -a 256 -c "$HOME/Library/Application Support/Nastart/PrivateHandoff/agent-piece-01.w7NYvi/agent-piece-01-sources.sha256"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s agent -p test_agent.py -v
NASTART_PAIRING_CODE=123456 sh agent/compose.sh config --images
PYTHONDONTWRITEBYTECODE=1 python3 -u scripts/verify_agent_docker.py
```

Python 测试同时完成直接启动 Agent、命中 `/healthz` 与停止后探针失败的验收。失败时请回传清单校验、Python 与 Docker/Compose 版本、失败步骤和日志。若已启动容器，请附该验证容器的 `docker inspect` 健康状态以及脱敏 HTTP 响应。
