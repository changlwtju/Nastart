# Agent 第 3 件验收记录：镜像发布到 Docker Hub（2026-11-23）

## 结论：通过

Muse 在 Mac 上复跑 `scripts/verify_agent_docker.py --pull`（命名空间 `changlwtju`），干净拉取已发布镜像并验证通过。拉取摘要与用户给定的完全一致。

## 核对

- 19 文件 SHA-256 均 OK（清单 `docs/testing/results/2026-11/CODEX-2026-11-23-AGENT-PIECE-03.sha256`）。
- Docker 29.9.2 + Compose v5.6.1（Docker Desktop 已启动）。
- 发布命令已跳过（按用户要求，用已发布镜像）。

## 复跑结果

- **清理**：复跑前本机留有 `changlwtju/nastart-agent:0.1.0` 与 `nastart-agent:0.1.0`，确认无容器使用后已移除（对应标签与镜像 ID），确保本次为真干净拉取。
- **拉取摘要**：`changlwtju/nastart-agent@sha256:18dfe1cb216fff62b8ea25f988a77a8dafe7bd3ff75558d0b7401256c0311373`，与用户给定的摘要完全一致。
- **容器**：启动后 Health.Status=healthy、Running=True。
- **端点**：`GET /healthz` 200（version 0.1.0）；`POST /v1/pair` 200（bearer 已签发）；`GET /v1/handshake` 200（agentVersion 0.1.0、apiVersion 1、permissionLevel read）。两个版本字段均为 0.1.0。
- **健康翻转**：同一容器 healthy → unhealthy 已验证。
- **清理**：容器、卷、网络已删；VERIFY_EXIT=0。
- 配对码与 token 留在本机，未外传。

## 过程问题（已解决）

- SSH 会话里直接跑 `--pull` 失败：Docker 凭证助手读 macOS 钥匙串被拒（`keychain cannot be accessed because the current session does not allow user interaction`）。改走 GUI Terminal（osascript）跑同一命令，钥匙串在 GUI 会话里是解锁的，拉取成功。这是 SSH 会话访问钥匙串的固有限制，不是镜像或脚本问题。

## 后续

- Agent 第 3 件已验收通过。下一步按拆分走第 4 件（App 配对/身份与状态合并），等用户发话再定。
