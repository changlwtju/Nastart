# Agent 第 5 件 Docker socket 过滤代理交接（2026-11-24）

0.2.0 的 Compose 部署由 Agent 和过滤代理两个容器使用同一镜像。真实 Docker socket 只挂载在代理容器。Agent 以 `nastart` 运行，通过只读共享卷访问过滤后的 Unix socket。代理以 root 运行，显式设置 socket 权限为 0666，两容器均使用只读根文件系统、`no-new-privileges` 和 `cap_drop: ALL`。

白名单只放行 `GET /v1.41/containers/json?all=1`。查询串解析后必须恰好是一对 `all=1`。代理转发通过检查的方法和请求目标，上游请求头由客户端库生成。代理保留 Docker 返回的状态码和 body。禁止的请求返回 403，后端无法连接返回 502，拒绝日志只记录方法和路径。

## 改动文件

- [docker_socket_proxy.py](../../../../agent/docker_socket_proxy.py) · 标准库 Unix socket 代理与可导入的 `is_allowed`。
- [compose.yaml](../../../../agent/compose.yaml) · 双服务、独立挂载和命名卷。
- [Dockerfile](../../../../agent/Dockerfile) · 镜像内包括模式为 0555 的代理脚本。
- [nastart_agent.py](../../../../agent/nastart_agent.py) · `AGENT_VERSION` 改为 `0.2.0`。
- [test_agent.py](../../../../agent/test_agent.py) · 新增假 Docker 后端和 6 项代理测试。

工作区为 `/Users/lagransun/workspace/Nastart`。SHA-256 清单列出上述文件和本批更新的文档，从工作区根目录运行 `shasum -a 256 -c` 校验。 [SHA-256 清单](../../../testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-05.sha256)

## 本机验证

Mac Docker Desktop Engine 29.9.2，Compose 5.6.1，Python 3.15.2。Python 编译检查通过。运行 `python3 -m unittest discover -s agent -v`，6 项新增加 5 项现有用例全部通过。假 Docker 后端收到允许的请求，能返回原始 200/503 状态和 body，所有拒绝的请求均未到达后端。也覆盖上游断开时 502、旧 socket 文件清理及权限。

复跑已有的 `scripts/verify_agent_docker.py` 通过，验证同一运行容器从 healthy 转为 unhealthy，健康接口、配对与握手均为 200。

Buildx 本地构建了 amd64/arm64 双架构镜像，两个架构分别能导入代理与 Agent，版本均为 `0.2.0`，代理脚本为 0555。amd64 使用 Mac 上的模拟执行。本机 Compose 起栈用的是单独构建的 arm64 镜像，独立项目、回环临时端口、临时卷。

| 检查 | 实测结果 |
| --- | --- |
| Agent 容器 | 用户 `nastart`，实际 UID 100，状态 healthy。挂载只有数据卷和只读过滤 socket 共享卷。 |
| 代理容器 | 用户 root，正常运行。真实 `/var/run/docker.sock` 仅在此容器以只读绑定挂载。 |
| Agent HTTP | `/healthz`、配对、已认证的 `/v1/handshake` 和 `/v1/snapshot` 均 200，报告版本 `0.2.0`。 |
| 容器列表 | `/v1/snapshot` 返回 Agent 与代理两个测试容器，`dockerAvailable=true`，`dockerError=null`。 |
| 过滤后的 socket | 白名单 GET 200。`GET /version`、`GET /v1.41/version`、POST stop、DELETE、缺少 `all=1` 和多余参数均 403。写类探针使用虚构容器 ID。 |
| 代理重启 | 停代理时快照继续返回 200，并报告 Docker 不可用。重启代理后清单恢复，Agent 容器 ID 保持。 |

原始日志位于 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-05-2026-11-24/`，包含 `unittest.log`、`compose-verification.log`、`buildx.log`、`healthcheck-regression.log` 和 `ssh-build-context.log`。本轮 Compose 容器、网络、测试卷和测试镜像已清理。

发布由 Muse 接续。本批产品改动限于交接列出的 5 个文件。旧 SSH `--build` 的上传列表缺少 `docker_socket_proxy.py`，复现了构建阶段 COPY 失败。0.2.0 的本地构建使用完整工作区，SSH 配合发布后的镜像使用默认拉取。此次本机结果覆盖 Compose，SSH 升级与回退未复测。

## 可直接转发给 Muse

```text
请在 Mac 工作区 /Users/lagransun/workspace/Nastart 验收 Agent 第 5 件。先运行 shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-05.sha256。Codex 已通过 11 项 Python 测试、amd64/arm64 本地构建和 Mac Compose 起栈测试。
请用完整工作区运行 NASTART_DOCKERHUB_NAMESPACE=changlwtju scripts/publish_agent_image.sh，发布 0.2.0 和 latest。随后在独立 Compose 项目拉取 0.2.0 并起栈。确认代理在运行，Agent healthy，配对后的 /v1/snapshot HTTP 200 且容器清单存在。docker inspect 核对 Agent 只有只读共享卷上的过滤 socket，真实 /var/run/docker.sock 只挂在代理容器。
从 Agent 容器内向环境变量 NASTART_DOCKER_SOCKET 指向的 socket 发 GET /v1.41/version 和使用虚构容器 ID 的 POST stop，核对均返回 403；同窗核对白名单 GET /v1.41/containers/json?all=1 返回 200。旧 SSH --build 上传不含代理源码，本批发布和验收采用完整工作区与已发布镜像。
如失败，请回传 SHA 校验、Docker/Compose 版本、镜像摘要、容器状态、脱敏挂载列表、快照结果和 socket HTTP 状态。配对码与 bearer token 留在本机。
```
