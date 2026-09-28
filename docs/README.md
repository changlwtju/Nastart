# Nastart Documentation Structure

播放开发方式：[共用逻辑优先、分层回归与完成条件](development/playback-development-workflow.md)。任务状态仍以唯一总账为准，19×4 功能矩阵保留完整验收范围。

当前常态工作方式：[白天远程 iPhone 13 / 后续 iPad，晚上本人及 iPhone 18 验收](development/remote-playback-routine.md)（2026-09-28）。

当前接续入口：[播放任务交接（跨会话/账号）](handoffs/CURRENT-PLAYBACK-HANDOFF.md)。本轮评估：[播放能力、开口项与矩阵准入审计](handoffs/2026-09-28-PLAYBACK-READINESS-AUDIT.md)。

历史任务接续：[2026-09-14 单位黑群晖接续指南（无 Xcode/真机）](handoffs/2026-09-14-NAS-DAYTIME-CONTINUATION.md)。

This directory is the source of truth for Nastart product, architecture,
security, research, and project planning documents.

播放架构的已接受执行决策： [ADR 0002](adr/0002-single-playback-optimization-mainline.md)。新架构为唯一优化主线，旧架构仅作临时回退。

## Core Documents

| Path | Purpose |
|---|---|
| `docs/strategy/NASTART_STRATEGIC_FOUNDATIONS.md` | Strategic baseline decisions before product blueprint |
| `docs/product/NASTART_PRODUCT_BLUEPRINT.md` | Highest-level product blueprint |
| `docs/product/PRD_MVP.md` | First shippable MVP scope and user journeys |
| `docs/product/SYNOLOGY_DSM_V1_COVERAGE.md` | Synology DSM v1 feature coverage and automation priorities |
| `docs/product/PRICING_STRATEGY.md` | Nastart Plus pricing principles and launch price candidates |
| `docs/research/NASTART_COMPETITIVE_LANDSCAPE.md` | Competitive landscape and differentiation |
| `docs/security/NASTART_SECURITY_ARCHITECTURE.md` | Security architecture and security principles |
| `docs/project/NASTART_MASTER_PLAN.md` | Cost, resources, modules, and execution roadmap |
| `docs/project/COST_BREAKDOWN.md` | Detailed first-stage cost categories and cost-control rules |
| `docs/architecture/IOS_ARCHITECTURE.md` | Initial iOS/iPadOS architecture |
| `docs/architecture/DATA_MODEL.md` | Initial domain data model |
| `docs/architecture/SYNC_STRATEGY.md` | iCloud/CloudKit sync strategy and future Nastart Cloud boundary |
| `docs/design/APP_ICON_DIRECTION.md` | First Nastart app icon concept, color, rendering, and rejection rules |
| `docs/design/INFORMATION_ARCHITECTURE.md` | First information architecture and navigation model |
| `docs/design/UI_STYLE_GUIDE.md` | App shell visual direction, typography, color, icon, card, and control rules |
| `docs/design/UI_WORKFLOW.md` | Required staged UI workflow from IA/style to wireframes, imagegen references, SwiftUI prototypes, and real-device testing |
| `docs/design/MEDIA_SERVICE_FLOWS.md` | Jellyfin, Emby, Navidrome, media resource, and external handoff UX flows |
| `docs/design/LAUNCHPAD_THEME_STRATEGY.md` | Quality-first launchpad theme strategy across Apple platforms |
| `docs/development/nas-dev.md` | NAS-side development workflow, preflight scope, and Mac/Xcode handoff boundary |
| `docs/development/service-icon-fixtures.json` | Common service recognition fixtures for launchpad icon, category, and visibility rules |
| `docs/handoffs/2026-08-02-NAS-MEDIA-JELLYFIN-THREAD.md` | NAS connectivity, media playback, Jellyfin redesign, diagnostics, and Mac handoff context |
| `docs/handoffs/PLAYBACK_OFFLINE_DIAGNOSTICS.md` | Offline playback trace report, policy simulator, and continuous telemetry workflow |
| `docs/handoffs/PLAYBACK_VALIDATION_TARGETS.md` | Real-device Jellyfin playback validation targets and decision rules |
| `docs/handoffs/MAC_PLAYBACK_DEBUG_TODO.md` | Mac/Xcode handoff for telemetry-first playback debugging |

## Future Directories

| Directory | Future Contents |
|---|---|
| `docs/architecture/` | iOS, Agent, Cloud, API, and data architecture |
| `docs/design/` | Design system, UX flows, themes, icons, and prototypes |
| `docs/development/` | NAS-side workflows, local fixtures, and static validation notes |
| `docs/adr/` | Architecture and product decision records |

## Naming Rules

- Use uppercase product-prefixed filenames for major documents.
- Use ADR files for irreversible or high-impact decisions.
- Keep generated documents in Markdown unless a richer format is required.
- Treat strategic and security documents as living documents.

后续媒体能力：[Dolby Vision / Dolby Atmos 播放路线](project/DOLBY_PLAYBACK_ROADMAP.md)。

播放优化任务总账：[播放体验分批计划与 PX-01～PX-21、UX-01～UX-04 状态](project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。每次恢复播放优化及每批结束时核对全表，避免跨会话遗漏需求。
