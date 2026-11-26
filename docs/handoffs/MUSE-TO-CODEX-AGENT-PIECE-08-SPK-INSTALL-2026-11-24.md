# Agent 第 8 件交接：SPK 及其他平台安装——群晖套件与通用 Linux 安装（2026-11-24）

## 目标

Agent 现在只能走 SSH 脚本或 App 内 SSH 安装器部署。给它一个群晖原生安装方式（SPK，Package Center 一键装）加一个通用 Linux 安装方式，让用户不用 SSH 也能装。Agent API 已稳定（0.4.0，默认 HTTPS），前置已满足。

## 现状（已摸清，Codex 不用再探）

- 部署方式见 `docs/project/AGENT_DEPLOYMENT_OPTIONS.md`：SPK 一行写着"尚未实现"，要"包结构、权限、启停升级及机型/DSM 兼容验收"。
- 仓库里没有任何 SPK 文件，从零建。
- 当前安装路径：`scripts/install_agent_via_ssh.sh`（SSH 到目标主机，拉镜像、起 Compose）、`scripts/upgrade_agent_via_ssh.sh`、`scripts/upgrade_agent_on_host.sh`；App 内 `SSHAgentInstaller` 优先 Docker Compose、缺 Compose 才回退 Python。SPK 不替换这些，只多一条原生安装路。
- 目标 NAS：DS918+（apollolake，x86_64），DSM 7.x，已装 Container Manager（Docker 在跑，启动台能看到容器）。Mac 能 ping 通 NAS（192.168.1.64），但**没有 NAS 的 SSH 权限**（Mac 密钥未授权），DSM 版本号不经认证拿不到——所以 SPK 的真机安装测试由用户在 DSM Package Center 里手动上传 .spk 完成，Muse 验收时只做本地构建与模拟生命周期验证，装机后由用户确认、Muse 再验 Agent 与 App 配对（见"验收"）。
- Agent 镜像已发布到 Docker Hub（`changlwtju/nastart-agent:0.4.0`，双架构 amd64/arm64），SPK 不打包镜像，安装时从 Docker Hub 拉取（参考做法：容器类 SPK 约 80 KB，镜像安装时拉）。
- 部署参考：Synology 官方 SPK 结构（https://help.synology.com/developer-guide/synology_package/introduction.html）。

## 本件做

### 1. 群晖 SPK（主件，目录 `spk/`）

包结构（按 Synology 官方 SPK 布局）：

```
spk/
├── INFO                    # package=nastart-agent, version 跟 AGENT_VERSION 走（0.4.0）, arch=x86_64 armv8, os_min_ver=7.0-40000, maintainer, description, displayname
├── package.tgz             # 载荷：compose.yaml + compose.sh（或等价启动包装）+ 默认配置，解到 /var/packages/nastart-agent/target/
├── scripts/                # preinst, postinst, preuninst, postuninst, preupgrade, postupgrade, start-stop-status
├── conf/
│   ├── privilege           # 权限声明（见下）
│   └── resource            # 端口 8787 等资源声明
├── PACKAGE_ICON.PNG        # 64x64（DSM 7 要求）
├── PACKAGE_ICON_256.PNG    # 256x256
└── LICENSE                 # 可选，< 1 MB
```

- **安装（postinst）**：检查 Container Manager / docker 可用（缺了就明确报错退出，不装一半）；拉取 `changlwtju/nastart-agent:<AGENT_VERSION>` 镜像；建数据卷；`docker compose up -d` 起 Agent + 代理；生成一次性配对码并写到套件数据目录与容器日志里（用户不经 SSH 也能拿到码——写清读取位置）。
- **启停（start-stop-status）**：start/stop/status 走 `docker compose up -d` / `down` / `ps`，返回码符合 DSM 约定（running 时 status 返回 0）。
- **升级（preupgrade/postupgrade）**：停旧版、拉新镜像、起新版；数据卷不动（token、配对状态、证书、事件历史都保留）。
- **卸载（preuninst/postuninst）**：停并删容器；**数据卷默认保留**（重装不丢配对与证书），文档里写清手动删卷的方法。
- **权限（conf/privilege）**：DSM 7 强制降权，套件默认不以 root 跑。脚本要调 Docker（需 docker socket 权限）。Codex 定具体做法（二选一，写清理由）：套件用户加 docker 组，或 privilege 里声明 root（Package Center 会弹警告、用户须确认）。不偷偷绕过 DSM 的权限模型。
- **兼容**：INFO 里 `arch` 至少含 `x86_64`（DS918+ apollolake）；`armv8` 也加上（镜像是双架构，ARM 机型以后能用）。`os_min_ver` 至少 `7.0-40000`；若 Container Manager 要求更高（容器类应用需 DSM 7.2.1-69057+），按实际要求写。
- **构建脚本**：`scripts/build_spk.sh`，从仓库 + 当前 `AGENT_VERSION` 组装出 `.spk`，并做结构校验（INFO 必填字段、图标尺寸、脚本可执行、package.tgz 布局）。
- **文档**：`agent/README.md` 里补 SPK 一节（怎么装、配对码在哪读、怎么升/卸、兼容矩阵）。

### 2. 通用 Linux 安装（次件，小）

- 一个 systemd unit（`systemd/nastart-agent.service`）+ 一个小安装脚本，复用现有 `agent/compose.yaml`（Docker Compose 栈），覆盖非群晖的 Docker 主机。`restart: unless-stopped` 已在 compose 里，systemd 只负责 Docker 起来后把栈带起来。不做 QNAP/TrueNAS 等其他 NAS 包格式。

### 3. 测试

- `scripts/test_spk_lifecycle.sh`（或等价脚本）：在 Mac 的 Docker 引擎上模拟 DSM 套件布局（临时目录当 `/var/packages/nastart-agent/`），依次跑 postinst → start-stop-status start/status → stop/start → 升级路径（postupgrade，用新 tag）→ preuninst/postuninst；每步核对 Agent 以 HTTPS 起来（`/healthz` 200、版本对）、配对与握手 200、数据卷保留、卸载后容器与网络清理干净。
- 结构校验进构建脚本：INFO 字段、图标尺寸、脚本 `bash -n` 过、package.tgz 能解开。
- 现有 23 项 Python 测试全过（本件不改 Agent 代码，只加 SPK 与安装文件；若动了 compose.yaml 或脚本，相关测试要过）。

## 真机安装（用户步骤，验收时不由 Muse 代做）

- 用户在 DS918+ 的 DSM Package Center 里手动安装 → 上传本件产出的 `.spk` → 装完后按文档读配对码，用 App 以 https 重新配对。Muse 在用户确认装好后验 Agent（HTTPS 200、版本、证书）与 App（启动台"Agent 已连接"）。
- 原因：Muse 没有 NAS 的 SSH 权限，也没有 DSM 管理员口令，不能代装。

## 不做

- App 代码改动（App 已支持 https 配对，SPK 只是部署件）。
- QNAP QPKG、TrueNAS 等其他 NAS 包格式。
- 公共套件源 / 自动更新通道（那是第 9 件云/官网的地盘）。
- 改 Agent 代码、改配对/token 逻辑、改镜像内容（SPK 复用已发布的 0.4.0 镜像）。

## 文件

- 新建：`spk/`（INFO、package.tgz 内容、scripts/、conf/、图标、LICENSE）。
- 新建：`scripts/build_spk.sh`、`scripts/test_spk_lifecycle.sh`。
- 新建：`systemd/nastart-agent.service` 与通用 Linux 安装脚本（小）。
- 改：`agent/README.md`（SPK 与通用 Linux 安装说明）。

## 验收

- Codex 自己跑通构建脚本、结构校验与模拟生命周期测试；现有 23 项 Python 测试全过。
- Muse 复跑：从仓库重建 `.spk`，结构校验过，模拟生命周期全流程过（装/起/停/升/卸，HTTPS 与配对正常，数据卷保留，卸载干净）。
- 用户在 DS918+ 上手动装完 .spk 后，Muse 验 Agent HTTPS 与 App https 配对（启动台"Agent 已连接"）。
