# 2026-10-26 已有NFO只读识别与电视本机存储修复

接续[前批WebDAV目录切片](2026-10-26-READONLY-WEBDAV-LIBRARY.md)。共享文件名/已有NFO识别已接三端实际扫描及展示，并修复电视无法保存索引的问题；不是在线provider刮削、海报墙或独立媒体库播放交付。详细安装包、UDID、偏好、原图、原始失败和脚本仅留本机私有区，指针 `/tmp/nastart-webdav-metadata-evidence`；可分享结果见[结构化结果](../../../testing/results/2026-10/2026-10-26-local-nfo-metadata-tv-storage.json)。

## 接受实现

共用代码仍在 `ios/Nastart/Packages/NetworkMedia`，两个应用工程同包编译。

| 源码 | 实际行为 |
| --- | --- |
| LocalMetadata.swift | 文件名提取片名、分隔年份、SxxExx/特殊季0/双集范围，数字片名保守保留；仅显示“文件名识别·待确认”，不伪造provider匹配 |
| LocalMetadata.swift | 同目录同stem NFO优先；同stem多份有歧义则不选；仅一个非剧集视频时才允许movie.nfo回退；不把tvshow.nfo套给单集 |
| LocalMetadata.swift | movie/episodedetails的标题、年份、简介/CDATA、季集和明确类型的imdb/tmdb/tvdb ID；拒绝实体/DOCTYPE、过深/截断/重复关键字段及冲突ID，不访问thumb/url/episodeguide外链 |
| WebDAV.swift / Models.swift | 新增限NFO的GET，文件URL没有目录尾斜杠，必须位于选定根、只读同origin、200、无跳转，流式512KiB；整轮NFO最多32MiB/4096份。原PROPFIND Depth1与4MiB上限保留；补深层重复编码拒绝和HTTPS挑战端口规范化 |
| LibraryIndex.swift | 目录完成校验后索引视频和已有资料；损坏/有歧义/已声明超大的NFO回退文件名并显式提示；已列出的NFO读取403/网络失败或取消则整轮不替换旧库。旧JSON没有metadata字段仍可读 |
| LibraryIndex.swift | 同进程统一actor；手机/Pad仍用Application Support原子快照；电视改用Caches可重建快照＋不超过64KiB的UserDefaults连接目录，仅含源UUID/名称/地址/所选根。密码仍只放独立Keychain，目录不含媒体索引/密码 |
| LibraryIndex.swift | 电视缓存消失时从连接目录恢复“待扫描”源，不能假称已完成扫描；移除后旧缓存不能复活源，损坏存储失败关闭。缓存清除恢复仅做隔离单测，不在真机制造清理/存储压力 |
| LibraryViews.swift / TVNASViews.swift | 显示来源/年份/季集/简介/原路径，新增显式“仅本机移除”；输入下一项/完成的焦点路径明确，网络库取消多余外层TV返回包装，键盘Menu不退出整个库；电视提示可重扫恢复缓存 |
| LocalStorageDiagnostics.swift | 普通Debug在本机缓存仅记操作/错误domain/code，不记路径、地址或凭据；首个电视实际错误定位为index-write/NSCocoaErrorDomain513 |

NFO命名/字段以[Kodi电影说明](https://kodi.wiki/view/NFO_files/Movies)及[单集说明](https://kodi.wiki/view/NFO_files/Episodes)为参照，仅实现上表子集，不承诺完整Kodi兼容或多根/新版多集NFO布局。电视持久存储设计依据[Apple电视应用指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/)及本次实际513拒绝证据；不将旧指南的容量数值当所有新系统已测上限。当前自行限制配置64KiB，媒体资料不塞入偏好。

## 真实问题与修复

电视能够连接、读取目录并选到Movies，但保存时显示本机存储失败。先加无敏感信息的本机诊断，经同操作复现，确认凭据保存没有失败，错误发生于索引写入（Cocoa513）；不是网络错误。将电视索引移到允许写入的Caches并增加独立小型连接目录后，真实保留数据新包成功保存4视频/2项NFO，取回本机快照核对；重启保留和UI移除均成立。不能沿用前批“TV只表单”的状态，也不能把此修复扩大为电视取消/Release验收。

32项测试/0失败：原目录/存储10，文件名及NFO10，缓存可重建连接目录3，真正loopback HTTP9。包含中文/数字片名、双集和特辑、NFO优先及歧义、恶意/损坏XML、类型冲突/ID校验、旧格式兼容、仅NFO GET/认证/拒绝跳转/分别有界响应/取消、403不覆盖旧库、缓存丢失/移除防复活和超大配置先失败。第一版NFO大header夹具只声明600KiB却没发body，返回-1005而不是预期大小错误；已修夹具完整发声明body，未放宽客户端，失败保留。

## 当前源码、构建与逐机结果

HEAD `4de732d`及既有/本批dirty/untracked全部保留。普通Debug、默认空参数/环境，03:53:01完成，366项本地源码/工程/资源摘要构建前后及收尾0漂移；口径不同于历史570项，非完整外部依赖闭包。完整签名/二进制SHA及不可变包路径留私有清单。

- 移动主SHA `255dd0691df000e2c4346f931b11b57eb05671afea44316e3ed3f1209ab603c1`，30签名Mach-O。
- TV主SHA `b7c524489dbf857be321cdd53df24bfe789cd11ed26017e3a5669face31db1fc`，27签名Mach-O。

| 设备 | 本轮最终包安装 | 实际有限验收 |
| --- | --- | --- |
| iPhone13 / iPhone14,5 / iOS16.3.1，有线 | 03:53:46，ios-deploy InstallComplete；安装前备份及后续偏好核对 | 普通首页；匿名自有夹具连接/选Movies/4视频、2 NFO和坏NFO回退；NFO简介/特辑双集显示；显式取消及NFO403时旧库逐字节不变；重启保留、恢复重扫、本机移除及取回空索引 |
| 新iPad / iPad15,7 / iPadOS26.6，有线 | 03:53:35，CoreDevice成功；上批安装协调器已现场解除，原因未知 | 普通首页、连接/选Movies/4视频和2 NFO、本机快照核；显式取消后旧库逐字节不变；本机移除及取回空索引。没有将旧协调器原因写为已修复 |
| 客厅TV / AppleTV14,1 / tvOS18.2，LAN | 03:53:36，CoreDevice成功，含实际513修复 | 普通首页、真实遥控输入/键盘Menu保留表单、匿名夹具连接/选Movies、4视频/2 NFO及简介/季集/坏NFO回退；本机快照、重启和移除成功；**取消真机仍未通过** |
| iPhone18 / iPhone19,7 / iOS27.0 | 本批没有可连接目标，0安装 | 不继承25日旧包为本批新源码回归；原DSM保存域名未改，固定域名实际路线旧问题继续暂缓 |

三端都只连接本机自有匿名夹具，本批没有真实NAS WebDAV认证/大库或SMB兼容结论。认证由真实HTTP单测覆盖，不等于电视真实NAS账户已验。最后三端测试源均通过UI移除、本机索引为空，TV连接目录key也移除；安装/最终非诊断偏好均不变，原登录/网络/VPN/方向保留。

## 不能丢弃的自动化失败

- 电视系统会议室显示成为前台（activeAppInfo证实`com.apple.TVConferenceRoomDisplay`），相应“无目录”截图不算客户端失败或成功。重新激活Nastart即可继续，未改系统空闲/会议室设置。
- TV List的Cell与内层Button焦点不同，部分click仅移动焦点后报400；后续按实际节点/焦点判断。真实目录/建库结果和索引已核，不用单次点击成功代替。
- TV取消第一轮：控件消失后脚本盲补Select，误触本机测试库移除，数据空；保留失败并重建自有库，未动NAS。第二轮：取消目标已不存在，扫描先结束；4条files相同但完成时间已变，不能当取消保留旧库通过。停止此自动化重复，不再补按或继续调等待；仅手机/Pad有本轮取消实证。
- 手机重启后立即点击曾落到只读DSM详情，未改端点/配置；该窗不通过。返回新鲜首页再核可见入口后，旧库4视频/2资料存在、恢复重扫与移除成立。不以此断言已证明App或工具的根因。
- Pad首次连接后目录尚未取得，过早断言失败；复核当前表单/启用连接控件后实际目录、索引及取消通过。没有改VPN或账号绕过。

## 只读与收尾

自有夹具9文件和3目录，前后路径、内容SHA、大小、mtime及目录结构完全相同；53请求=29 PROPFIND＋24 GET，所有GET都只读NFO，未请求Outside子目录/媒体或海报，不访问NFO外链。临时服务已SIGINT停（预期exit130，finally终态清单落盘），0媒体播放/蜂窝；没有向真实NAS写测试文件。

自有TV Runner各轮均停，修改设置恢复且GET核；手机/Pad只删除自有HTTP会话，未知原Runner及其全局设置不动。删除会话后又以原生截图/显式空条件前台启动核三端NAS首页；TV/Pad3及10秒原生图均看过，手机原生截图见Wi-Fi，Pad原Wi-Fi/VPN状态保持。没有系统更新、卸载、重置或凭据清除。

## 下一步

收尾已继续核[接入决策](../../../architecture/READ_ONLY_NETWORK_MEDIA_LIBRARY.md)：TMDB需本项目授权/来源，AMSMB2有动态产品但SDK对象编码含密码，尚未采用。已把本地纠错独立覆盖放在前，不依赖在线token；SMB先隔离审实际依赖、只读/越根/取消和动态嵌入签名。后续仅文档修改，没有改变03:53源码/包或重启测试服务，不把调查写为功能交付。

电视取消需要独立可靠的原生焦点/事件测试，先修测试边界，不重放本批两轮失败。继续共享在线provider契约/可合法使用的凭据及本地匹配纠错，再接海报和SMB只读适配；当前文件名结果仍待确认，NFO来源仍明确，不把ID当在线匹配完成。增量扫描、tvshow.nfo季集层级、独立网络库播放、跨端同步和Release均未交付。[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)29项开放，114播放格保持；原轨/PGS/听音/文件KS/高清评分/弱蜂窝等按[总分支交接](2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)接续。本批不创建周期任务，不宣称回合结束后后台工作。
