# Agent 第 7 件自动证书交接（2026-11-24）

Agent 0.4.0 默认提供 HTTPS。首次启动由 OpenSSL 生成有效期 3,650 天的 RSA-2048 自签证书，CN 为 Agent 主机名，SAN 包含主机名、localhost 和 127.0.0.1。数据卷保存 `tls-cert.pem`（0644）与 `tls-key.pem`（0600）。生成与验证在卷内私有临时目录完成，再原子替换两个文件。以后每次启动检查剩余有效期，30 天内或证书已过期时自动换新。

同时传递 `--tls-cert` 和 `--tls-key` 或使用对应环境变量时，Agent 使用指定证书，显式证书由部署方续期。OpenSSL 不可用或自动证书初始化失败时，Agent 记录警告并提供 HTTP。HTTPS 握手保留 TLS 1.2 下限。已认证的 `/v1/handshake` 返回证书 SHA-256 指纹、Unix 秒到期时间和 CN，HTTP 模式返回 `certificate=null`。`/v1/diagnostics` 新增证书检查，状态为 `ok`、`expiring`、`expired` 或 `unavailable`。

## 改动文件

- [nastart_agent.py](../../../../agent/nastart_agent.py)、[Dockerfile](../../../../agent/Dockerfile)、[test_agent.py](../../../../agent/test_agent.py)、[agent/README.md](../../../../agent/README.md) 实现自动证书、TLS 诊断、构建依赖、验证和迁移说明。
- [compose.yaml](../../../../agent/compose.yaml)、[verify_agent_docker.py](../../../../scripts/verify_agent_docker.py)、[agent_smoke_test.py](../../../../scripts/agent_smoke_test.py) 适配 HTTPS 的健康检查和独立验证。
- [upgrade_agent_on_host.sh](../../../../scripts/upgrade_agent_on_host.sh)、[install_agent_via_ssh.sh](../../../../scripts/install_agent_via_ssh.sh) 适配已有部署的协议检查和默认配对地址。升级探针先在容器内对回环地址检查健康，再用探测到的协议验证原 token。
- [PROGRESS.md](../../../../PROGRESS.md)、[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md) 和 [开发状态](../../../project/DEVELOPMENT_STATUS.md) 更新接续摘要。

从仓库根目录运行 `shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-07.sha256`。 [SHA-256 清单](../../../testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-07.sha256)

## 本机验证

Mac Python 3.15.2 编译与脚本语法检查通过。18 项原有测试和 5 项新增测试在 Mac 与 0.4.0 Alpine 镜像内均通过。新增用例覆盖真实 RSA 证书、CN/SAN、独立 DER 哈希和到期解析、重启复用、一天证书续期、显式证书及到期状态、生成失败和 PATH 移除 OpenSSL 后以 HTTP 继续提供健康检查、配对及诊断。

使用 Docker Desktop Engine 29.9.2、Compose 5.6.1 和本地 arm64 0.4.0 镜像运行 `python3 scripts/verify_agent_docker.py`。项目只发布回环临时端口，数据存放在测试卷。

| 检查 | 结果 |
| --- | --- |
| 监听协议 | HTTPS `/healthz` 返回 200 和版本 `0.4.0`，同一端口拒绝明文 HTTP。 |
| 配对与握手 | 均为 200。指纹及到期时间与独立 OpenSSL 命令一致，CN 为容器主机名。 |
| 证书诊断与卷 | `certificate` 为 `ok`，剩余 3,650 天，密钥 0600、证书 0644。 |
| 健康检查回归 | 同一容器的 Agent 进程暂停后由 healthy 转为 unhealthy。 |
| 旧版回滚 | 故意令 TLS 候选返回 503，主机事务回滚至已发布的 0.3.0，HTTP 握手用原 token 返回 200，数据卷保持。 |
| 正常升级 | 同一数据卷从 0.3.0 HTTP 切换至 0.4.0 HTTPS，原 token 的握手返回 200。 |

本地升级回归从完整的 staging 目录直接执行主机端事务。SSH `--build` 上传限制见第 5 件交接。两轮 Compose 验证及升级测试使用独立项目，测试容器、卷和候选镜像均已清理。原始输出与本机测试脚本位于 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-07-2026-11-24.u7AdR9/`。 [第 5 件交接](CODEX-2026-11-24-AGENT-PIECE-05-DOCKER-SOCKET-PROXY.md)

## Muse 接续指令

```text
请在 /Users/lagransun/workspace/Nastart 验收 Agent 第 7 件。先运行 shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-07.sha256。Codex 已完成编译，Mac 与 Alpine 各 23 项单测全过，独立 Compose 已验证默认 HTTPS、证书诊断和文件权限，主机端 0.3.0 至 0.4.0 升级及故障回滚已用同一数据卷和原 token 验证。
复跑 python3 -m unittest discover -s agent -v。按第 3 件流程运行 NASTART_DOCKERHUB_NAMESPACE=changlwtju scripts/publish_agent_image.sh，构建并发布 0.4.0 和 latest。设置同一命名空间运行 python3 scripts/verify_agent_docker.py --pull，从发布镜像新建独立 Compose 栈。确认 HTTPS /healthz 200 和 0.4.0、明文请求失败、握手指纹与 openssl x509 一致、有效期约 10 年、certificate 检查为 ok，以及两份 PEM 权限为 0644 和 0600。
按项目真机手册先核对 iPhone 13 身份及已安装 Nastart 的包身份。用 HTTPS 地址重新配对，启用「跳过 SSL 验证」。原配对码已用过时，给 Agent 设置新的一次性配对码并保留数据卷。确认启动台显示「Agent 已连接」。
如失败，请回传 SHA 校验、镜像摘要、Docker/Compose 版本、脱敏的握手与诊断输出、证书指纹和权限、以及 iPhone 13 的包身份和相关截图或日志。配对码、token 和私钥留在本机。
```
