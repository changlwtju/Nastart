# Agent 第 8 件 SPK 与 Linux 安装交接（2026-11-24）

工作区为 `/Users/lagransun/workspace/Nastart`，基线为 `8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加工作区已有修改。本批交付 SPK 源文件、构建与模拟脚本、通用 Linux systemd 安装和说明。App、Agent 实现、镜像内容、配对与 token 逻辑沿用第 7 件。 [原任务](../../../handoffs/MUSE-TO-CODEX-AGENT-PIECE-08-SPK-INSTALL-2026-11-24.md)

## 包与行为

- 正式产物 `nastart-agent-0.4.0-0001.spk`，81,920 字节，SHA-256 `75645d6d96a7dc7bb53eceab98080edb804a95ba1530e04e4e40677f01021dae`。本机路径为 `~/Library/Application Support/Nastart/PrivateHandoff/agent-piece-08-2026-11-24.86vlQ1/nastart-agent-0.4.0-0001.spk`。本机按同一输入构建两次，产物逐字节一致。
- 使用 Agent 版本 `0.4.0` 和 DSM 要求的数字构建后缀 `-0001`。INFO 为 `arch="x86_64 armv8"`、`os_min_ver="7.0-40000"`，声明依赖 Container Manager。Container Manager 首个正式 Compose 版本要求 DSM 7.2。发布镜像 amd64 与 arm64 均已拉取核对，索引摘要为 `sha256:9fcf79c3ef02e1338039987a0412154a6901cc1249d6a3f9c20b52517a873d96`。 [Synology INFO 字段](https://help.synology.com/developer-guide/synology_package/INFO_necessary_fields.html) · [Container Manager 发布记录](https://www.synology.com/de-de/releaseNote/ContainerManager?model=DS718%2B&os=DSM&version=7_x_series)
- `conf/privilege` 用 `run-as: package` 与 `join-groupname: docker`，由 DSM 将套件用户加入已有 Docker 组。DSM 7 对未获群晖签名的 root 套件有限制，普通第三方安装警告无法授予 root。DS918+ 是否已有 `docker` 组以及该组能否访问 Docker socket 仍待核实。组不存在或 socket 仍为 root 专用时安装会在 DSM 或预检阶段受阻，本批不修改 NAS 的组、socket 或守护进程设置。 [DSM 限制](https://help.synology.com/developer-guide/getting_started/system_requirement.html) · [DSM 声明加入组的示例](https://help.synology.com/developer-guide/examples/compile_web_package.html)
- 安装拉取 `changlwtju/nastart-agent:0.4.0`，启动 Agent 和过滤代理，HTTPS 通过后返回。配对码保存在外部数据卷并镜像到套件 `var/pairing-code`（0600）。通过 **Container Manager → 容器 → nastart-agent-spk 项目的 agent 容器 → 详情 → 日志** 读取 `One-time pairing code:`，可直接在 App 用 `https://<NAS 局域网地址>:8787` 配对。已使用的码在升级、停止重启和保留卷重装之后仍保持失效。
- 升级、停机和卸载保留 `nastart-agent-spk-data`。停机移除两容器、网络和代理 socket 卷。卸载再移除套件配对码副本。管理员确认要永久清空后，可在已卸载时用 `sudo docker volume rm nastart-agent-spk-data` 删除持久数据。Linux 入口复制现有 `agent/compose.yaml` 并以 systemd 管理。 [安装与卸载说明](../../../../agent/README.md)

## 本机验证

- Mac Python 3.15.2 的原有 23 项 Agent 单测全部通过。构建脚本核对 INFO、载荷和校验值、两个 PNG 尺寸、两层 tar 内容与脚本权限，并运行 Bash 与 sh 语法检查。
- Docker Desktop Engine 29.9.2 上使用 Compose v5.6.1 和独立 Compose v2.5.1，验证依赖失败、安装、启动、停止、重启、升级、卸载和保留卷重装。HTTPS 健康、配对和原 token 握手均为 200，纯 HTTP 连接被拒，重复用码为 401。升版使用在引擎回环仓库临时发布的 0.4.1 夹具，Docker 重新拉取后实测新版本。两轮比较原 Agent ID、token/配对摘要、证书和密钥的文件哈希，原历史事件仍在。
- 早期试跑发现 Docker Desktop 的 Mac 回环映射无法供虚拟机内的 Docker 守护进程推送镜像，测试仓库已移到守护进程所在的回环。独立 Compose v2.5.1 停机后按服务筛选 `ps` 会报不存在，改为先列出项目容器再核其标签和健康状态。原始日志与最终复跑分开存于上述私有目录。测试期间 Docker Hub 曾间歇返回 503，安装拉取失败时允许再试一次。
- Linux 复用的 Compose 文件已从已发布镜像独立验证 HTTPS、配对、指纹和健康状态。Debian systemd 252 的 `systemd-analyze verify` 通过。另用替身记录 Docker 与 systemctl 的调用，验证安装器两次运行均拉正确标签、重启并启用服务，Compose 原样复制，目录 0700、配置 0600，配对配置逐字节一致。Linux 主机实际开机启动与 DS918+ Package Center 行为待现场验收。

源码及验证输入见 [SHA-256 清单](../../../testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-08.sha256)。

## Muse 接续指令

```text
请在 /Users/lagransun/workspace/Nastart 验收 Agent 第 8 件。源码是工作区的 spk/、scripts/build_spk.sh、scripts/test_spk_lifecycle.sh、scripts/install_agent_systemd.sh、systemd/nastart-agent.service 和 agent/README.md。先执行 shasum -a 256 -c docs/testing/results/2026-11/CODEX-2026-11-24-AGENT-PIECE-08.sha256，再运行 scripts/build_spk.sh /tmp/nastart-agent-0.4.0-0001.spk、scripts/test_spk_lifecycle.sh /tmp/nastart-agent-0.4.0-0001.spk 和 python3 -m unittest discover -s agent -v。Codex 已验证结构、23 项单测、Compose v5.6.1 与 v2.5.1 的完整生命周期，以及同卷保留 token、已使用配对状态、证书和事件。
由用户在 DS918+ 的 Package Center 里手动上传 .spk。先记录 DSM 和 Container Manager 版本。套件声明使用 DSM 管理的 docker 组，需要设备已有该组的 Docker socket 访问权限。若 Package Center 或依赖预检报权限错误，把实际提示回传，保留 NAS 权限与配置。用户确认装好后，从 Container Manager 的 agent 容器详情日志读取一次性码，用 https://<NAS 局域网地址>:8787 配对。按发现的设备与包身份核验项目真机要求，确认 HTTPS /healthz 200 和 0.4.0、握手证书指纹、App 启动台显示「Agent 已连接」。
如失败，请回传 .spk SHA-256、失败步骤、DSM 与 Container Manager 或本机 Docker 与 Compose 版本、Package Center 文案及对应脱敏日志、实际 HTTP 状态和 App 截图。配对码、token 和私钥留本机。
```
