# NAS Agent 部署方案

更新日期为 2026-11-24。Agent 是 NAS 端增强服务。

| 方式 | 当前基础 | 适用范围与后续工作 |
| --- | --- | --- |
| Docker / Compose（优先） | 0.4.0 默认 HTTPS，Agent 通过过滤代理读取 Docker 容器清单。真实 socket 只挂在代理容器。 | 支持容器的 NAS；通用 Linux 主机可用 systemd 接入同一 Compose 栈。 |
| 主机 Python 常驻进程 | 可直接运行；SSH 安装器在无 Compose 时以 nohup 回退 | 无容器环境/开发；正式使用需要主机适配的启动管理、升级和日志轮转，nohup 不等于可靠开机常驻 |
| 群晖 SPK 套件 | 由 Package Center 安装，Container Manager 的 Docker Project Worker 管理 Compose。Agent 状态写入 DSM 永久套件目录。 | DS918+ 已安装并启动 0.4.0-0008，HTTPS 健康检查通过，iPhone 13 配对待验。 |

SSH 是安装和维护通道，不是第四种 Agent 运行架构。当前 App 安装器优先 Docker Compose，缺少该条件才回退 Python。DSM 直连仍是群晖登录、File Station 和会话媒体地址的主路径，Agent 补充发现、容器端口及状态；未部署 Agent 的设备仍能使用 DSM 模式。

SPK、Linux 安装、版本要求和配对码读取路径见 [Agent 安装说明](../../agent/README.md)。Agent 继续使用局域网直连。

参考：[Docker Compose 生产部署](https://docs.docker.com/compose/how-tos/production/)、[Synology SPK 结构](https://help.synology.com/developer-guide/synology_package/introduction.html)。
