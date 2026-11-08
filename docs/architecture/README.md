# 架构文档

[高清海报补全与刮削方案](HIGH_RESOLUTION_MEDIA_ARTWORK.md)：实际源图/交付尺寸、只读候选实证与未接入边界。

当前播放实现以[视频播放技术路线](VIDEO_PLAYBACK_PIPELINE.md)为准，随代码和接受的优化同步更新；架构决策见[ADR](../adr/README.md)。计划中的接口或早期设计不等同于已经实现/验收。

| 文档 | 范围 |
| --- | --- |
| [当前视频播放技术路线](VIDEO_PLAYBACK_PIPELINE.md) | 双入口、网络与选流、取流代理、解码、字幕、seek、换流、诊断及源码定位 |
| [iOS 初始架构](IOS_ARCHITECTURE.md) | 2026-07 初始设计；其早期播放设想由当前路线与ADR更新 |
| [Agent 实现说明](../../agent/README.md) | 可选NAS端只读组件与接口入口 |
| [数据模型](DATA_MODEL.md)、[数据提供方](DATA_PROVIDER_STRATEGY.md) | 领域模型及数据来源策略 |
| [多来源评分调研](MULTISOURCE_RATINGS.md) | IMDb/TMDB等聚合候选、豆瓣独立来源与未交付边界 |
| [同步](SYNC_STRATEGY.md) | iCloud/CloudKit等同步设计与边界 |
| [认证与权限策略](AUTH_ENTITLEMENT_STRATEGY.md) | 认证与能力边界 |

当前完成度和后续计划看[开发状态](../project/DEVELOPMENT_STATUS.md)，具体实现/验证范围不由初始设计中的将来时推断。

- [WebDAV / SMB只读媒体库与客户端刮削](READ_ONLY_NETWORK_MEDIA_LIBRARY.md)：竞品实看、源文件不改的协议边界、共享模块与分阶段验收；尚未接产品。
