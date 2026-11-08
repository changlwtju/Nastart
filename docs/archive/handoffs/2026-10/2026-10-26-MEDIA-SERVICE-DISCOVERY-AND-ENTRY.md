# 媒体服务识别、已有登录入口与三端回归

2026-10-26。承接[NAS会话首切片](2026-10-26-NAS-SESSION-SOURCE-HUB-NATIVE.md)与[统一来源方案](../../../architecture/UNIFIED_SOURCE_DISCOVERY_AND_ACCESS.md)，当前接续见[交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)，[脱敏结果](../../../testing/results/2026-10/2026-10-26-media-service-discovery-entry.json)。本批是服务发现与现有Jellyfin入口，不是FTP/SMB或新增服务完整客户端交付。需求编号只归[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)；30项14进行中/5待验收/11待开始、114播放格保持，未关闭验收。

## 接受实现

- NetworkMedia新增`MediaServiceDiscovery`、`PublicMediaServiceHTTP`、`MediaServiceViews`，共同产品线索/端点身份/可达/已存登录/原生入口语义、列表/详情和有界探测。产品支持线索包括Jellyfin、Emby、Plex、Navidrome、Subsonic兼容、Audio Station，不以名称、端口或容器running当产品API在线。
- Jellyfin/Emby公开JSON严格核ProductName/Version/Id；Plex identity XML核machineIdentifier/version且禁DTD/外部实体；Subsonic合法协议响应仅在type明确时标Navidrome，不编造稳定serverID；Audio Station保留套件线索，API/应用权限尚未验。
- 独立ephemeral会话无DSM SID/Cookie/其他服务令牌/共享认证缓存，不跟随跳转，仅公开GET，拒绝调用方认证头/敏感query。128KiB/响应、2秒请求/3秒传输、每候选最多2端点、并发3、16候选/页面12秒；离页/后台关闭自有任务，旧轮结果不能发布。
- 原URL拼写继续用于Keychain和进入端点；规范比较键不覆盖用户地址。仅完全相同非空端点集合且同产品线索才合并，保留多实例；产品身份冲突不进入错误客户端。证书仅复用主工程先前批准的精确origin/叶DER，不新建或轮换信任；本机TLS夹具覆盖正确与错误证书。
- 移动`LaunchpadMediaShortcuts`与`AppStateStores`核当前NAS代次和清单完整性；TV`TVNASOverview`核当前账户/清单，刷新重新查询DSM，失败保留缓存/部分状态。DSMClient/TVDSMClient的Jellyfin检查改用共享严格产品核验，不再凭HTTP200选址。
- 主页面加入“媒体服务”，详情分清已识别、已有登录待验证、需授权、无端点、冲突和原生客户端未接；沿用主工程主题，四Tab不变。当前仅现有Jellyfin目的页可进入，其余产品明确后续范围。现有NAS File Station目录入口不依赖可选服务确认完成。
- TV最终补独立“已保存的Jellyfin”来源：NAS清单缺端点时仍保留该连接，不推断其NAS归属；`TVJellyfinEntry`只在请求端点匹配时复用当前账户，避免进入另一服务器的库。

## 测试与实际边界

共享包67测试/0失败，较51基线新增13逻辑＋3真实HTTP/TLS；覆盖名称边界、严格端点/原拼写、产品冲突、子路径、多实例/旧结果、401/HTML伪200/跳转、无凭据、体积/取消及已有精确证书。服务返回格式夹具不是新增产品真实授权/播放认证；未向用户NAS安装服务或改协议/反向代理。Audio Station真实界面只是套件来源且status unknown的元数据线索，不能据此宣称已安装/运行/API可用。

源码HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`＋保留的dirty；375本地源码/工程/资源输入，不是完整外部依赖闭包。双普通Debug/arm64，空启动参数和环境，30/27 Mach-O签名及TV嵌入库检查通过，最终源码/二进制零漂移。

| 产物 | 构建时间（+08） | 主二进制SHA-256 |
|---|---|---|
| 移动普通Debug | 2026-10-26T11:09:52.887294+08:00 | `286f158605c81d4c3cbea8e36f2d8fab9f836fdf0dc6cafd1834993c39411bc1` |
| TV普通Debug | 2026-10-26T11:09:49.673355+08:00 | `354991033311ddcc30184b783488746fee6fe02e398a0b772935a6f04486c5da` |

完整包路径、Debug dylib/嵌入摘要、UDID、设备枚举、profile、安装回执、偏好、原始XML/截图/日志在仓库外私有目录，指针`/tmp/nastart-media-service-discovery-evidence`；包名沿用SourceHub-Debug，以摘要区分版本。此前10:22候选及08:35上批不得当最终包。

| 目标 | 本轮身份与连接 | 最终保留数据安装完成 | 最终包回归 |
|---|---|---|---|
| iPhone13 | iPhone14,5 / iOS16.3.1 / USB；CoreDevice unavailable不覆盖现场lockdown USB成功证据 | 2026-10-26T11:11:00.393744+08:00 | 服务身份/已有登录、无密码进入真实Jellyfin库、刷新服务清单、NAS会话选目录、普通首页成立 |
| iPad | iPad15,7 / iPadOS26.6 / USB | 2026-10-26T11:10:50.224360+08:00 | 服务身份/已有登录、无密码进入真实Jellyfin库、NAS会话选目录、普通首页成立 |
| 客厅Apple TV | AppleTV14,1 / tvOS18.2 / LAN，非同型号tvOS27模拟器 | 2026-10-26T11:10:52.277059+08:00 | 独立已存服务身份、原生Select实际进入库/海报、无密码、NAS会话选目录、普通首页成立 |
| iPhone18 | iPhone19,7 / iOS27 / 不可连接 | 未安装 | 原域名＋端口/实际会话固定域名旧项保持，不能继承旧包或别机结果 |

13/Pad服务行各2、TV最终3是当窗渲染行数，不是NAS总服务数或新增产品兼容性统计。三端现有库实图均已看，无播放/密码输入命令；NAS目录仅列共享目录，未重跑扫描/NFO/在线刮削，不继承上批完整扫描结论。当前主题实图不代替全主题/深浅色/大字验收。

## 失败与纠正

首轮64测试有1个URL.path尾斜杠断言失败，改查原absoluteString并明确保留URL拼写；随后67通过。首TV构建textSelection不可用，限iOS后两端通过。清单重载前候选未安装；10:22候选已安装并保留真实结果，但TV无独立已存来源，身份等待25秒失败，不能丢弃。补独立来源后重建两端、重新核签名和逐机覆盖，才做最终回归。最终TV element/click等待35秒超时，截图/XML证实仅移动到正确焦点；保存失败后使用已核焦点包装行的原生Select进入详情，再Down核目标/Select进入真实库。不把点击请求返回或焦点移动当进入成功。首次脱离子进程构建启动日志为空，修独立进程组后正常两端构建；不作为产品故障。

## 收尾与下一步

最终三端原非诊断偏好与本批最初备份全同，独立网络库索引仍0（本批未建库/改已有账户）。正常空环境回NAS首页并实图核，TV另在自有Runner停后原生启动3/10秒进程与截图核。13/Pad Wi-Fi图标可见，未切网络/蜂窝或改VPN；0媒体任务，不声称完成蜂窝恢复测试。

手机/Pad仅删除自有HTTP会话，原Runner和设置保留；TV原无Runner，已停本批自有Runner且3项设置恢复/GET核。物理回归未启动夹具服务；单测HTTP/TLS自有服务随用例停止。未对NAS文件调用写入/改名/移动/删除，也未做NAS整库哈希审计。

接续先扩仓库外SMB raw只读目录/NFO、认证/DNS、越根/DFS及取消竞态验证，通过后再接工程；然后显式FTPS/FTP兼容、独立SFTP。新增媒体服务在隔离环境逐个实接授权/库浏览，用户NAS不安装软件。在线provider项目授权、海报/增量/独立库播放/同步以及原播放主线仍开放；本批没有改AV/KS或播放路线，播放矩阵114格不变。
