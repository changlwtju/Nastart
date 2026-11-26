# Agent 第 1 件验收记录：Docker 健康检查与镜像命名（2026-11-23）

## 结论：通过

Muse 在 Mac 上复跑全部 4 步，全部通过。同一容器 healthy → unhealthy，两个端点均 200。

## 核对

- 6 文件 SHA-256 均 OK：`agent/compose.yaml` `ccf8021b…b068`、`agent/compose.sh` `f90d3e2a…4956`、`agent/test_agent.py` `b75cc402…d0a`、`agent/README.md` `afd300b5…ebd`、`scripts/install_agent_via_ssh.sh` `fc34035b…68d`、`scripts/verify_agent_docker.py` `a31eb071…429`。
- Python 3（版本以 Mac 系统 Python 为准）+ Docker 29.9.2 + Compose v5.6.1（CLI 在 `/Applications/Docker.app/Contents/Resources/bin`，须先 export PATH）。

## 复跑结果

- Python 单元测试：**5 项全过**（原 4 项 + 新增 `DockerHealthcheckTests.test_compose_probe_succeeds_while_agent_runs_and_fails_after_stop`）。
- `sh agent/compose.sh config --images`：`nastart-agent:0.1.0`（版本号由 `compose.sh` 从 `AGENT_VERSION` 派生，唯一来源是代码里的常量）。
- `python3 -u scripts/verify_agent_docker.py`：镜像构建成功；容器启动后 Health.Status=healthy、Running=True；`GET /healthz` 200 `{"ok": true, "version": "0.1.0"}`；`GET /v1/handshake` 200（agentVersion 0.1.0、apiVersion 1、permissionLevel read）；同一容器随后 Health.Status=unhealthy、Running=True；脚本输出 "Verified healthy -> unhealthy in the same running container"；容器/卷/网络已清理。
- `compose.yaml` 实测：`image: nastart-agent:${NASTART_AGENT_VERSION:?...}`；healthcheck 为 `python3 -c` 调容器内 `/healthz`（interval 5s、timeout 3s、retries 3、start_period 5s），未加新依赖。

## 更正

- 交接与拆分文档里原写“Mac 上无 Docker”是错的：Mac 上有 Docker.app，CLI 只是不在默认 PATH 里。已在两处更正为 Docker.app 路径与 export PATH 做法。

## 后续

- Agent 第 1 件已验收通过。下一步按拆分走第 2 件（镜像发布与升级/回退），等用户发话再定。
