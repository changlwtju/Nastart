# Agent 第 6 件事件历史交接（2026-11-24）

Agent 版本从 0.2.0 升到 0.3.0。事件环形缓冲保留最新 100 条，通过原子写入保存到数据目录的 `events.json`。文件不存在或损坏时从空历史启动。已认证的 `/v1/diagnostics` 新增 `uptimeSeconds`、`eventCount` 和最新在前的 `events`。

采样线程启动时建立基线，随后按整数秒间隔检测同一容器 ID 的状态变化和 Docker 可用性翻转。Docker 不可用时保留最近一次成功采样的容器基线。配对码校验失败记录来源地址和 Unix 时间。已触发限流的请求在校验前返回。

## 改动文件

- [nastart_agent.py](../../../../agent/nastart_agent.py) 实现事件历史、采样、诊断字段和版本更新。
- [test_agent.py](../../../../agent/test_agent.py) 增加 7 项事件历史测试，并消除既有代理测试发送请求头后被提前断开的竞态。
- [agent/README.md](../../../../agent/README.md) 补齐诊断和采样间隔说明。
- [PROGRESS.md](../../../../PROGRESS.md)、[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md) 和 [开发状态](../../../project/DEVELOPMENT_STATUS.md) 更新接续摘要。

从仓库根目录运行 `shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-06.sha256`。 [SHA-256 清单](../../../testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-06.sha256)

## 本机验证

Python 3.15.2 编译检查通过。`python3 -m unittest discover -s agent -v` 的 7 项新增测试和 11 项现有测试全部通过。首跑代理拒绝测试在拆开发送请求头和请求体时出现 `BrokenPipeError`。夹具改为一次发送后，全量测试连续 20 轮通过。

Mac Docker Desktop Engine 29.9.2 和 Compose 5.6.1 使用新构建的本地 arm64 0.3.0 镜像起独立项目。验证配置在 Agent 容器内设置 10 秒采样间隔，使用回环临时端口和项目专属数据卷。

| 操作 | 结果 |
| --- | --- |
| 起栈、配对、读取诊断 | HTTP 200，`events=[]`、`eventCount=0`、`uptimeSeconds=5`，两项原有检查均在。 |
| 提交错误配对码 | HTTP 401，`pairing.failed` 仅含类型、时间戳和来源字段。 |
| 停止再启动同一测试容器 | 先后记录 `running → exited` 和 `exited → running`。 |
| 停止再恢复 Docker 代理 | 先记录 `available=false`，详情为 `ConnectionRefusedError`，后记录 `available=true`，详情为 `null`。 |
| 重启 Agent 容器 | 原 token 仍可读取诊断，5 条历史逐条一致，最新在前，与卷内 `/data/events.json` 的逆序一致，运行时长重新计数。 |

首轮验证脚本在重启后沿用原临时端口，诊断请求超时。复跑在重启后重新读取 Compose 端口映射。私有证据位于 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-06-2026-11-24.OUKd0V/`，包含两轮 Compose 日志、验证脚本和 Python 测试日志。临时项目、容器、网络、卷和本地测试镜像已清理。Docker Hub 发布及发布包复验由 Muse 接续。

## 可直接转发给 Muse

```text
请在 /Users/lagransun/workspace/Nastart 接续 Agent 第 6 件。先从工作区根目录运行 shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-06.sha256。产品源码为 agent/nastart_agent.py、agent/test_agent.py、agent/README.md。Codex 已通过编译、18 项 Python 测试和本机 Compose 事件采集与重启持久化验证。
请复跑 python3 -m unittest discover -s agent -v，并按第 3 件流程运行 NASTART_DOCKERHUB_NAMESPACE=changlwtju scripts/publish_agent_image.sh，构建、发布 0.3.0 和 latest。独立 Compose 项目用发布的 0.3.0 镜像、测试容器和数据卷起栈。可在 Agent 容器环境内设 NASTART_SAMPLE_INTERVAL_SECONDS=10。
配对后核对 /v1/diagnostics 的 checks、events、eventCount、uptimeSeconds。等首次采样建立基线，逐次停、启同一测试容器并核对两条 container.state，逐次停、启代理并核对 docker.availability 的 false 和 true。待采样捕获前一事件再进行下一操作。重启 Agent 后若使用动态端口，重新查询映射。用同一 token 核对历史逐条一致、最新在前、运行时长重新计数。
如失败，请回传 SHA-256 校验结果、镜像标签和摘要、Docker/Compose 版本、测试输出、操作时间线、容器与端口状态、脱敏诊断响应及相关日志。配对码和 token 留在本机。
```
