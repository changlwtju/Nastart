# Agent 第 3 件交接：镜像发布到 Docker Hub（2026-11-23）

## 目标

镜像能发布到 Docker Hub（公开仓库），NAS 上能直接拉取，不用在目标主机上构建。

## 现状（已摸清，Codex 不用再探）

- 镜像目前是本地构建、无命名空间：`compose.yaml` 里 `image: nastart-agent:${NASTART_AGENT_VERSION}`，`compose.sh` 从 `AGENT_VERSION`（现为 `0.1.0`）派生版本；`pull_policy: never`。
- **无发布脚本**：没有 `docker push`、没有 registry 配置。
- **Mac 上未登录 Docker Hub**：`~/.docker/config.json` 的 `auths` 为空。发布前用户须在 Mac 上 `docker login` 一次（凭证进 Docker Desktop 的 credential store，Codex 不碰密码）。
- **命名空间**：Docker Hub 镜像名须为 `<namespace>/nastart-agent:<version>`。命名空间 = `changlwtju`（用户的 Docker Hub 用户名，2026-11-23 截图确认，与 GitHub 用户名相同）。

## 前置（已确认，2026-11-23）

- Docker Hub 用户名（命名空间）=`changlwtju`（用户截图确认）。
- 用户已在 Mac 上登录 Docker Hub（Docker Desktop 账号菜单显示 `changlwtju`；仓库默认公开）。

## 本件做

### 1. 发布脚本

新增 `scripts/publish_agent_image.sh`（或同等脚本）：构建镜像，打标签 `<namespace>/nastart-agent:<version>` 与 `<namespace>/nastart-agent:latest`（版本仍由 `compose.sh` 的机制从 `AGENT_VERSION` 派生，唯一来源是代码常量），推送到 Docker Hub。命名空间由环境变量传入（如 `NASTART_DOCKERHUB_NAMESPACE`），必填、无默认值、不硬编码。

### 2. 镜像命名

`compose.yaml` 的 image 改为 `<namespace>/nastart-agent:<version>`（namespace 同样由环境变量传入）；`compose.sh` 仍从 `AGENT_VERSION` 派生版本。本地构建与发布共用同一命名规则。

### 3. 部署侧改用拉取

`scripts/install_agent_via_ssh.sh` 与 `scripts/upgrade_agent_via_ssh.sh` 支持从 Docker Hub 拉取已发布镜像（不再在目标主机上构建）。做法由 Codex 定（如加 `--pull` 模式或默认拉取），并在交回里说明默认行为与 `pull_policy` 的改动。拉取后仍须走第 1–2 件的健康检查与升级/回退逻辑（新容器 healthy 才算成功）。

### 4. 验证

Codex 在 Mac 上实测发布一次（推到 Docker Hub 公开仓库），再在干净环境（删掉本地镜像）从 Docker Hub 拉取并启动，验 `/healthz` 与 `/v1/handshake` 均 200、版本正确、配对流程正常。

## 不做

- SPK、受限 API 权限、App 配对合并、自动证书、正式云/官网。
- 改 `AGENT_VERSION` 的值。
- 私有仓库（默认公开；用户若要私有另说）。

## 文件

- `scripts/publish_agent_image.sh`（新增）。
- `agent/compose.yaml`、`agent/compose.sh`（镜像命名）。
- `scripts/install_agent_via_ssh.sh`、`scripts/upgrade_agent_via_ssh.sh`、`scripts/upgrade_agent_on_host.sh`（拉取模式，按实际结构定）。
- `agent/README.md`（发布与拉取用法）。

## 验收

- Codex 交回 Docker Hub 仓库地址、推送成功的证据（`docker push` 输出）、干净拉取并启动的证据（`/healthz` 与 `/v1/handshake` 均 200、版本正确）。
- Muse 在 Mac 上复跑：拉取已发布镜像并启动验证（发布本身由 Codex 已做，Muse 不重复推）。
