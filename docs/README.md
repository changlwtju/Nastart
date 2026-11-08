# 文档导航

当前进度看根目录 [PROGRESS](../PROGRESS.md)，继续任务看[当前交接](handoffs/CURRENT-PLAYBACK-HANDOFF.md)。这里按“需求 → 设计 → 实现 → 验证 → 历史”查找文档。

## 当前工作入口

| 文档 | 唯一职责 |
| --- | --- |
| [当前开发状态与计划](project/DEVELOPMENT_STATUS.md) | 项目模块进度、主要问题、阶段计划与验证边界 |
| [2026-11-02全面开发盘点](project/APP-DEVELOPMENT-OVERVIEW-2026-11-02.md) | 功能/架构/源码/风险/验证与发布的日期快照 |
| [Claude协作接续单](development/CLAUDE-PRIMARY-DEVELOPMENT-HANDOFF.md) | 按额度动态分工下的接续顺序、下一批范围与设备支持 |
| [Claude后续开发推进指令](development/CLAUDE-NEXT-DEVELOPMENT-PROMPT.md) | 可直接复制到Claude Code的本次有界任务 |
| [当前播放技术路线](architecture/VIDEO_PLAYBACK_PIPELINE.md) | 实际双入口/网络/取流/解码/换流/字幕链路与源码定位 |
| [当前交接](handoffs/CURRENT-PLAYBACK-HANDOFF.md) | 当前源码、构建、设备、故障和下一步 |
| [播放任务总账](project/PLAYBACK_EXPERIENCE_PRIORITIES.md) | PX/UX 编号、需求、状态和未完成条件 |
| [播放调试规范](handoffs/PLAYBACK-DEBUG-RUNBOOK.md) | 真机身份、安装、采集和证据要求 |
| [真机安装与远控手册](development/PHYSICAL-DEVICE-REMOTE-CONTROL.md) | 13/Pad USB、18/TV Wi-Fi、原生服务与WDA分层及恢复/收尾 |
| [开发与分层回归](development/playback-development-workflow.md) | 如何选择测试、验收及结束一批修改 |
| [19×4 功能矩阵](testing/PLAYBACK-FUNCTION-MATRIX.md) | 正式验收范围；单次成功不自动更新整表 |
| [竞品设备矩阵](testing/COMPETITOR-DEVICE-MATRIX.md) | Lenna 等竞品的同条件对照 |

## 按主题查找

| 目录 | 内容与主要入口 |
| --- | --- |
| `strategy/` | [战略基础](strategy/NASTART_STRATEGIC_FOUNDATIONS.md) |
| `product/` | [产品蓝图](product/NASTART_PRODUCT_BLUEPRINT.md)、[MVP 需求](product/PRD_MVP.md)、[群晖覆盖范围](product/SYNOLOGY_DSM_V1_COVERAGE.md)、路线与定价 |
| `project/` | [项目总计划](project/NASTART_MASTER_PLAN.md)、[任务总账](project/PLAYBACK_EXPERIENCE_PRIORITIES.md)、成本与部署安排 |
| `design/` | [设计导航](design/README.md)、信息架构、样式、流程、线框和图标资产；预览图统一归入此处 |
| `architecture/`、`adr/` | [当前播放技术路线](architecture/VIDEO_PLAYBACK_PIPELINE.md)、[架构导航](architecture/README.md)、初始iOS/数据/同步设计、[决策记录](adr/README.md) |
| `security/` | [安全架构](security/NASTART_SECURITY_ARCHITECTURE.md) |
| `development/` | [NAS 开发](development/nas-dev.md)、[远程调试](development/remote-playback-routine.md)、[iPhone 18 无线更新](development/IPHONE18-WIFI-UPDATE.md)、[离线诊断](development/PLAYBACK_OFFLINE_DIAGNOSTICS.md) |
| `testing/` | 测试规范、功能矩阵、[固定样本](testing/samples/README.md)、[按月结果](testing/results/README.md) |
| `research/` | [竞品研究](research/NASTART_COMPETITIVE_LANDSCAPE.md)、录屏分析与 [DS One 对照规格](research/DSONE-VIDEO-PLAYBACK-SPEC.md) |
| `handoffs/` | 只保留当前接续入口及必须保持固定路径的调试规范 |
| `archive/` | [历史索引](archive/README.md)：按月交接、整理前状态快照与维护记录 |

## 如何维护

当前状态只写一处，其他文档链接引用，不再复制整批日志。每批详细记录放 `archive/handoffs/YYYY-MM/`，结构化结果放 `testing/results/YYYY-MM/`；历史记录保留当时构建和失败，不覆盖为当前结果。

代码链路与新验证结果同批同步技术路线、开发状态及矩阵受影响内容；PROGRESS只作摘要，当前交接只作现场，编号验收状态只在总账维护。同步规则已写入根目录AGENTS与开发流程，不依赖额外提醒或定时任务。

文件移动后同步更新相对链接和工具中的固定路径，并运行 `python3 scripts/check_documentation.py`。真实设备偏好、凭据、安装包、原始日志和大体积产物保存在仓库外本机私有目录；文档只记录必要的可分享结论。
