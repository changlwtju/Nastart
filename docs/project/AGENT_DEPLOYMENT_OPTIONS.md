# NAS Agent 部署方案

更新：2026-09-08。这里的 Agent 是 NAS 端增强服务，不是 AI 助手。

| 方式 | 当前基础 | 适用范围与后续工作 |
| --- | --- | --- |
| Docker / Compose（优先） | agent/ 下已有 Python 实现、Dockerfile、Compose | 支持容器的 NAS；完善镜像发布、升级回退、配对和健康检查。Docker socket 的 :ro 挂载并不限制 API 写操作，正式部署还需最小 API 权限代理或等价隔离 |
| 主机 Python 常驻进程 | 可直接运行；SSH 安装器在无 Compose 时以 nohup 回退 | 无容器环境/开发；正式使用需要主机适配的启动管理、升级和日志轮转，nohup 不等于可靠开机常驻 |
| 群晖 SPK 套件 | 尚未实现 | 群晖安装体验更完整；需包结构、权限、启停升级及机型/DSM 兼容验收，在 Agent API 稳定后建设 |

SSH 是安装和维护通道，不是第四种 Agent 运行架构。当前 App 安装器优先 Docker Compose，缺少该条件才回退 Python。DSM 直连仍是群晖登录、File Station 和会话媒体地址的主路径，Agent 补充发现、容器端口及状态；未部署 Agent 的设备仍能使用 DSM 模式。

近期顺序：完善 Docker 生命周期 → App 配对/身份与状态合并（避免重复卡片、离线明确标记）→ 受限 API 权限 → 增量监控/诊断 → SPK 及其他平台安装。保持 LAN only，不引入云中继依赖。当前实现存在不等于已在全部 NAS 环境完成部署验收。

参考：[Docker Compose 生产部署](https://docs.docker.com/compose/how-tos/production/)、[Synology SPK 结构](https://help.synology.com/developer-guide/synology_package/introduction.html)。
