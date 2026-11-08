# Nastart

Nastart 是面向 iPhone、iPad 的 NAS 与 HomeLab 管理应用，当前重点为群晖 DSM、服务启动台、文件管理与视频播放。产品采用本地优先设计，Agent 是可选的 NAS 端组件。

## 从这里开始

| 要做什么 | 入口 |
| --- | --- |
| 看当前进度 | [PROGRESS.md](PROGRESS.md) |
| 看详细开发进度、问题与后续计划 | [开发状态](docs/project/DEVELOPMENT_STATUS.md) |
| 全面了解功能、架构、源码与协作开发 | [2026-11-02全面盘点](docs/project/APP-DEVELOPMENT-OVERVIEW-2026-11-02.md)、[Claude协作接续单](docs/development/CLAUDE-PRIMARY-DEVELOPMENT-HANDOFF.md)、[可转发推进指令](docs/development/CLAUDE-NEXT-DEVELOPMENT-PROMPT.md) |
| 了解播放技术路线与当前真机矩阵 | [技术路线](docs/architecture/VIDEO_PLAYBACK_PIPELINE.md)、[测试矩阵](docs/testing/PLAYBACK-FUNCTION-MATRIX.md) |
| 继续开发或调试 | [当前播放交接](docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md) |
| 找需求、设计、规范或历史记录 | [文档导航](docs/README.md) |
| 核对真机安装与工作约定 | [AGENTS.md](AGENTS.md) |
| 复用USB/Wi-Fi安装、原生调试及WDA遥控 | [真机安装与远控手册](docs/development/PHYSICAL-DEVICE-REMOTE-CONTROL.md) |

## 项目目录

| 目录 | 内容 |
| --- | --- |
| [ios/](ios/README.md) | iOS/iPadOS 应用、Xcode 工程、测试与本地播放依赖 |
| [tvos/](tvos/README.md) | Apple TV 原生首版、独立工程与测试 |
| [agent/](agent/README.md) | 可选 NAS Agent、Docker 配置与测试 |
| [scripts/](scripts/README.md) | 构建、设备操作、诊断与文档检查工具 |
| [docs/](docs/README.md) | 按主题组织的需求、设计、开发规范、测试及历史交接 |
| [cloud/](cloud/README.md)、[website/](website/README.md) | 后续能力的边界与说明 |
| `tmp` | 指向仓库外私有调试产物的兼容链接；不参与版本管理 |

## 开发约定

视频播放按 [ADR 0002](docs/adr/0002-single-playback-optimization-mainline.md) 集中优化 Greenfield 主线，按[分层回归流程](docs/development/playback-development-workflow.md) 验证。每台真机调试前必须核对最新包身份，无法确认时保留数据覆盖安装，不能仅凭版本号判断。

本地静态检查：`bash scripts/preflight.sh`；文档路径检查：`python3 scripts/check_documentation.py`。实际编译、签名及真机验收在 Mac/Xcode 上执行。
