# Agent 第 2 件验收记录：升级/回退（本地构建版）（2026-11-23）

## 结论：通过

Muse 在 Mac 上复跑 `scripts/verify_agent_upgrade.py`，两笔交易全部通过：升级成功、故障候选 unhealthy、自动回退 healthy、原卷与原 token 保留。

## 核对

- 4 文件 SHA-256 均 OK：`agent/README.md` `15cc24b4…3ad9`、`scripts/upgrade_agent_via_ssh.sh` `592dfd12…c7fe`、`scripts/upgrade_agent_on_host.sh` `3fc1847e…0b02`、`scripts/verify_agent_upgrade.py` `97f2f5b9…4fdb`。
- Docker 29.9.2 + Compose v5.6.1（Docker Desktop 已启动，CLI 在 `/Applications/Docker.app/Contents/Resources/bin`）。

## 复跑结果

- **升级（0.1.0 → 0.1.1）**：基线容器 healthy，`/healthz` 与 `/v1/handshake` 均 200；升级前已配对一次；新镜像构建成功，容器重建后 starting → healthy；`/healthz` 200（version 0.1.1）、`/v1/handshake` 200（同一 agentId，version 0.1.1）；脚本输出 "Upgraded to nastart-agent:0.1.1-verify-… with the existing token verified."
- **故障候选与回退（0.1.1 → 0.1.2 故障版 → 回 0.1.1）**：故障候选镜像构建成功，容器重建后 starting → unhealthy；30 秒内未 healthy，脚本输出 "upgrade did not become healthy within 30s." 与 "Rolling back to nastart-agent:0.1.1-verify-…"；回退后容器 starting → healthy，`/healthz` 200（version 0.1.1）、`/v1/handshake` 200（同一 agentId）；脚本输出 "Upgrade failed. Rolled back to nastart-agent:0.1.1-verify-… with the existing token verified." 与 "Verified rollback exit=1. Same volume=…_nastart-agent-data; same initial token accepted."（回退时 exit=1 是预期行为：升级脚本以非 0 退出并说明已回退。）
- **清理**：容器、网络、卷已删；三张测试镜像已 untag 并删除。
- 验证走回环 SSH（与 Codex 的实测方式一致），两笔交易均在隔离的项目/卷里跑，不动现有部署。

## 后续

- Agent 第 2 件已验收通过。下一步按拆分走第 3 件（镜像发布到 registry），需用户先选 registry，等用户发话再定。
