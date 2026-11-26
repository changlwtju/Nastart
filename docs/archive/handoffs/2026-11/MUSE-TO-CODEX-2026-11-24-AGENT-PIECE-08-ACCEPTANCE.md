# Agent 第 8 件 DS918+ 验收记录

2026-11-24（UTC+8）。DS918+（apollolake / x86_64）的已登录 DSM 页面显示版本 7.4.1-90080 Update 1。Container Manager 已安装，当前版本号待核。第 8 件仍待端到端验收。

## 套件中心格式预检

通过 Safari 的现有 DSM 会话打开套件中心 → 手动安装。以下「通过」指上传后进入第三方责任确认。对照包在该步骤取消。

| 样本 | SHA-256 | 结果 |
| --- | --- | --- |
| Muse 最小包 | `12ed943f8bf23351069257d1059c5983c68c1ca495d61caf44a7d3d050558d25` | Muse 已安装成功，作为字节对照 |
| Muse INFO 基线 | `78b812e890ff5f468b8ba07b17e76df248e4261adf4be5437f0ea1982575e50d` | Codex 复现「套件文件格式不正确。请联系套件开发人员。」 |
| 01 只改最小包的包名 | `0586c701939154764ae7badd140622173c42ed7b669b9fd7283ef08fb7805792` | 通过 |
| 02 在 01 上只把 `join-groupname: docker` 加入 `conf/privilege` | `3ad5b58f42c80cd07fa0fa20e1e89ddf86592cd17a62897ecb9927beefe1e9cb` | 同一格式错误 |
| 03 在 01 上换用 INFO 基线的 `package.tgz` 和对应 checksum | `b7da0bf672a5d75e9251134580342a2098a80bb65c63283dcdc9ed631b6aa15b` | 通过 |
| 04 在最小包上换用完整版四个 INFO 字段，保留原载荷与 checksum | `482fb3267ee23d662828227a0a890745615a086850b89afaf8a39f39b6713777` | 通过 |
| 源码重建完整包 `nastart-agent-0.4.0-0001.spk` | `ddcb12345ae578ade474edbbf076ad038c7e61d6958f8e942f70260dfd8badd5` | 通过格式预检，用户继续至安装事务，部署失败 |

最小包与 Muse INFO 基线的原始 tar 在相同位置有 396 个不同字节。两包的成员名、顺序、模式和 UID/GID 一致，时间戳不同。提取后内容差异仅见 INFO 的包名和 checksum、`package.tgz`、`conf/privilege`。两个内层归档的 `README.txt` 逐字节一致，时间戳和压缩字节不同。

01 与 02 的唯一成员变更是 `conf/privilege`，证实当前 DS918+ 上拒绝由 `join-groupname: docker` 声明触发。DSM 内部为何拒绝该组声明仍无细分日志。04 正向验证了四个原产品 INFO 字段同时存在，四个旧单字段包保留相同权限声明，SHA 已复核，未再次提交 DSM。它们原始值及失败历史见 [Muse 交接](../../../handoffs/MUSE-TO-CODEX-AGENT-PIECE-08-SPK-DEBUG-2026-11-24.md)。

## 源码与本机复跑

- 工作区 HEAD `8db1cc6491c6e8bce2bc8b41f57e6112142132ba`，保留已有未提交源码。修改 `spk/conf/privilege`，使用 DSM 的默认套件账号声明。修改 `scripts/build_spk.sh`，校验该权限声明。修改 `spk/scripts/common`，以实际运行脚本的套件账号为准报告 Docker 访问失败。 [Synology 权限配置](https://help.synology.com/developer-guide/privilege/privilege_config.html)
- 完整包在 22:44:07 构建，81,920 字节，保留真实 hooks、`conf/resource`、端口 8787、完整 `package.tgz`、LICENSE、图标与生产 INFO。两次独立构建 `cmp` 一致。构建包存于 Mac 用户私有下载子目录 `~/Downloads/nastart-spk-debug-20261124/`。
- Mac Docker 29.9.2 / Compose v5.6.1。Agent Python 单测 23/23 通过。用同一完整包运行 `scripts/test_spk_lifecycle.sh` 返回 0，覆盖 Docker 不可用预检、安装启动、停启、临时镜像升级、卸载、重装、临时资源清理及身份、配对状态和证书保留。

本批三个构建输入的 SHA-256。

```text
5d13c58603841012618f6058f13d4022784bfa716f733c55f2e4703d0710d72a  scripts/build_spk.sh
14a38d068c87a5d4dc900237a3d21a6b7ce40bda0bce5ca2714a8c1817d9fecb  spk/conf/privilege
f5ca7dc35d46350be0b05eda62d3deb2cbf804babf2e6ee5676bf4c02be4f3cc  spk/scripts/common
```

## 2026-11-25 安装事务与诊断版

- 用户截图和 Safari 同窗核对显示套件 `0.4.0-0001`、安装位置 `/volume5`，并报「无法正确安装此套件」。后续一行是旧版 `postinst` 对 `stack deploy` 非零退出的合并错误。该行出现在 Docker 和 Compose 预检成功之后。镜像拉取、数据卷、配对状态、Compose 启动及 HTTPS 就绪仍需细分证据。
- Mac 对 NAS 8787 的 HTTPS 检查连接失败，HTTP 码 000。Container Manager 图形日志未找到能归因的 Agent 事件。NAS 的只读 SSH 预检返回 `Permission denied (publickey,password)`，无法取得 DSM 套件原日志。需保留并核对 `/var/log/packages/nastart-agent.log` 与 `/var/log/synopkg.log` 的同窗条目。 [DSM 套件日志位置](https://help.synology.com/developer-guide/breaking_changes.html)
- 源码在 `spk/package/compose.sh` 细分拉取、创建持久卷、准备配对状态、启动和就绪失败。安装、升级及手动启动 hooks 保留该诊断供 Package Center 显示。仅写脚本定义的阶段和原因，原始命令输出留在子进程捕获范围内。 [DSM 套件结果消息](https://help.synology.com/developer-guide/synology_package/show_massage.html)
- 用 `SPK_BUILD_NUMBER=0002 scripts/build_spk.sh` 构建诊断版 `nastart-agent-0.4.0-0002.spk`，SHA-256 `092ff26660b8d454abba430794d4f0c828de569ab7bcac84b071fca63cd71106`。镜像仍为 0.4.0。离线注入 5 类故障，验证 DSM 提示、退出状态以及模拟私密值不出现在输出，全部通过。独立复建逐字节一致。23 项 Agent 单测和同包 Mac 完整生命周期通过，临时容器、镜像和数据卷已清理。诊断版待 DS918+ 现场复跑。

## 2026-11-25 部署失败后的修复路径

- 用户在 DSM 提交 `0.4.0-0002`。套件中心进入更新，现有 `0.4.0-0001` 的容器栈停止步骤返回失败。DSM 弹窗显示 `Could not stop the old stack. The Agent data volume was retained.`，对应新版 `preupgrade` 调用旧版 Compose 启动器。DSM 日志中心记录 04:25:12 和 04:25:23 修复失败。Container Manager 的容器、网络和映像页面未显示 Nastart 条目。
- `0.4.0-0003` 的 `preupgrade` 通过 Docker 查询旧项目的容器、网络、Compose 卷。全部查询成功且为空时直接继续，外部 Agent 数据卷不纳入查询。旧项目为空且旧启动器返回错误的回归测试、完整生命周期、逐字节复建均通过。SPK SHA-256 `82b6354725cf050747081eb5829ac291a6ea60b3a85afb7671c0daadb5981ccb`。 [DSM 升级 hook 顺序](https://help.synology.com/developer-guide/synology_package/scripts.html)
- 用户授权后，Codex 在 DS918+ 安装 `0003`，DSM 04:29:07 记录修复失败。弹窗显示 `Could not list the old Agent containers.`，对应 `docker ps -aq --filter` 返回非零。查询失败时保留现场，跳过旧栈停止的条件没有满足。日志中心仅显示修复失败，无法区分权限、Docker 连通性或客户端错误。
- `0.4.0-0004` 保留空项目恢复逻辑，细分上述 Docker 查询错误。注入权限、连通性、命令参数和 API 版本错误均通过，23 项 Agent 单测及 Mac 完整生命周期通过。SPK SHA-256 `a57d21b1ec473ccf81aa76ba39b454ca41737d80d8e2c1a6c3d1b58fcc261469`。
- 04:33（UTC+8），用户授权后，Codex 在 DS918+ 套件中心执行 `0004` 更新。DSM 弹窗显示「无法修复 Nastart Agent」，并报告 `Could not list the old Agent containers. Docker access was denied.`。这是 `preupgrade` 内 `docker ps -aq --filter` 返回的权限类错误，现有证据不足以区分 socket 的文件权限与 Docker 守护进程的授权。按用户要求停止实机尝试，留存弹窗，并保留 NAS 用户、组、socket 和 DSM 设置。04:33:13 的 NAS HTTPS 检查仍为 HTTP 000。

## 实机验收状态

- DS918+ 已安装并启动 `0.4.0-0008`。iPhone 13 最新 App 包身份、同端点配对、TLS 与 App 握手指纹比对、启动台「Agent 已连接」待验。Mac 上既有 Agent 与 iPhone 13 配对状态保留。
- 04:48 左右刷新并查看套件中心已安装清单，23 个套件操作项中唯一 Nastart 条目是产品套件，`nastart-minimal` 已不在清单。未观察到独立的卸载执行回执。
- 调试期间未人工修改 NAS 用户、组、Docker socket 权限或 DSM 设置。

## 2026-11-25 Docker Project Worker 安装

- DSM 套件中心确认 Container Manager 已安装版本 `24.0.2-1706`。产品改用 DSM Docker Project Worker 管理 Compose。套件脚本准备项目配置，Agent 使用 DSM 套件身份运行。只有过滤代理容器持有宿主 socket 并获取对应容器内附加组。 [Synology Docker Project Worker](https://help.synology.com/developer-guide/resource_acquisition/docker-project.html)
- `0005`、`0006` 在格式校验被拒。基于 `0004` 的 INFO-only 与 resource-only 对照分别通过。补齐标准生命周期脚本后的 `0007` 通过格式，但 DSM 安装前无法准备尚未就绪的持久目录。Worker 先于 postinst 读取 Compose，`0008` 在 preinst 写入项目配置，由 Agent 启动时在 DSM 已挂载的永久数据目录中创建专用子目录。 [DSM 资源时序](https://help.synology.com/developer-guide/resource_acquisition/timing.html) · [DSM 套件目录](https://help.synology.com/developer-guide/integrate_dsm/fhs.html)
- 经用户授予 DSM 操作权限，Codex 在套件中心手动提交 `nastart-agent-0.4.0-0008.spk` 到 `/volume5`，保留「安装完成后立即启动」。包 SHA-256 `4f461b92d65d708ad9d4b8b51f1765b0e9a5fbe10b7c266f60b058ff1a5fe236`。04:47 台账显示套件已安装、已启动，日志中心均有成功事件。Container Manager 显示 `nastart-agent-spk-agent-1` 和 `nastart-agent-spk-proxy-1` 运行，均使用已发布镜像 0.4.0。
- Mac 对 NAS 的 HTTPS `/healthz` 返回 200 和 0.4.0。直连 TLS 证书 SHA-256 指纹为 `e6fca921dcdafcbd814a210dd43b129f6595abc7c533390b7af783379e02630d`。证书有效至 2036-11-21 UTC。已确认容器日志生成一次性配对码。
- 同包在 Mac 模拟 Worker 生命周期中通过安装、停启、升级、卸载后重装，持久身份、证书、配对状态和过滤代理保持。23 项 Agent 单测通过，两次独立构建字节一致。DS918+ 已验证本次安装和启动，真机升级及卸载后保留数据未实测。先前失败部署的旧 Docker 命名卷未迁移，当前 NAS 实例使用新的 DSM 永久套件数据目录。

## 2026-11-25 iPhone 13 配对验收（Muse 复核）

- 配对：iPhone 13（Nastart 0.1.0，第 4 件构建）经「设备 → 配置 Nastart Agent」重新配对到 `https://192.168.1.64:8787`。「跳过 SSL 验证」已开。一次性配对码由用户从 Container Manager 容器日志取后直接在手机上输入（码未记录、未打印）。App 显示「Agent 已配对并验证」。
- 已连接主机：`63b7d538e462`，与 NAS Agent 证书 CN 一致（Mac Agent 为 `cf8424d04af1`，已替换）。
- 证书指纹：SHA-256 `e6fca921dcdafcbd814a210dd43b129f6595abc7c533390b7af783379e02630d`，Muse 经 openssl 直连 192.168.1.64:8787 复核一致，有效期至 2036-11-21 UTC；与 Codex 验收记录一致。App 配对时完成 TOFU pin，「已配对并验证」即握手通过。
- 启动台：显示「Agent 已连接」，DS918+ 在线、NAS 状态正常；实时指标 CPU 8%、内存 21%、硬盘 3%。硬盘不再是 0%（Mac Agent 读容器文件系统得 0%），证实启动台现取 NAS Agent 的真实 NAS 数据。
- NAS Agent 健康：`https://192.168.1.64:8787/healthz` 返回 200、版本 0.4.0（Muse 复核两次）。
- 过程说明：Codex 额度用完（明早恢复），配对码未走文件传递；Muse 经 WDA 把表单地址改好、确认跳过 SSL 开着，用户在手机上输码点「重新配对」，Muse 经 WDA 验结果。Mac 上第 7 件持久 Agent（192.168.1.82:8787）仍在运行，未动；iPhone 13 现连 NAS Agent。
- 截图存证：`shot13_08_after_pair.png`（已配对并验证）、`shot13_08_launchpad3.png`（启动台 Agent 已连接）；配对前基线 `shot13_08_baseline.png`（Mac Agent，硬盘 0%）。

第 8 件验收通过。
