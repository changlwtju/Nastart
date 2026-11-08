# 海报墙分类保留、搜索与空状态

更新：2026-10-30T17:43:52+08:00。接续[读取恢复批](2026-10-30-SHARED-HOME-WALL-READ-RECOVERY.md)。仍6.1；NAS恢复期仅本地代码/隔离场景，0真机发现/控制/安装、0NAS/旧凭据/源写/播放，不改NAS/VPN，无后台任务。

## 已确认的问题与接入

源码确认旧matching/categories两处各自优先已存category，不核新catalog中是否仍有此类；类别移除后会过滤成空列表、且没有选中的分类。另原files.isEmpty在附加视频隐藏前判空，只有匹配的花絮/预告时files非空、可见网格却全空。没有声称真机复现，按合成输入补反例。

新增纯Foundation的MediaWallSelection：同一快照确定固定顺序的可用分类、有效活动分类、去首尾空白的查询、整部匹配作品、真正可见作品及none/libraryEmpty/noResults/supplementsHidden。有效偏好保留，已失效偏好回退到首个实际分类；搜索仍限定当前分类，仍按作品题名/现有纠错展示名/文件名匹配，不自动跳到其他类，不拆季集/分段/光盘组，不改任何原文件或索引。

NetworkLibraryPosterWall正式使用此快照，分类高亮与网格不再各自算活动分类；ForEach接visibleItems，附加视频展开按钮继续用原matches/回调。onAppear和onChange通过retainCategory保存解析后的分类，避免默认分类在新分类出现时跳走，也避免失效旧分类后来出现又被自动选回；变更分类按原规则收起附加视频，不改关键词。初始默认/失效回退的真实生命周期仍待验。

三端共用NetworkLibraryWallEmptyState，明确区分本机索引暂无作品、当前分类没有搜索结果、附加视频收起。无匹配可清除搜索，沿TV紧凑/iOS普通按钮、暖色图标/主题文字/动态字号；电视正文23/说明20。新clearSearch函数实际供空态和原TV工具栏共用，后者继续清搜索框/焦点，分类保持，两个清除入口标识独立。原附加视频展开按钮保留，不另加一套展开逻辑。

LibraryViews中的模型/读取恢复/首页、MediaCatalog分类/聚合/缓存和MediaPresentation分组逐字保持；墙目录管理/导航/sheet/onSaved→dismiss、两种读取/扫描task及原焦点回调块、网格布局/海报样式核同。新分类回调可能影响实际焦点，需要补遥控，不把任务块核同当焦点已验；Jellyfin源码与播放链路未改。3既有源+1纯源+1测试，439输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持。

## 验证

9条新选择测试通过：有效分类与顺序、分类移除/再出现、默认分类保留后新增分类、空白查询、当前类无结果/清除不换类、文件名/纠错题名、分段电影及剧集不拆、隐藏附加视频可揭示/清除后仍收起、真正空库带旧关键词。11既有MediaCatalogTests含合成目录/临时本机库事务，4既有参数/隔离+3读取请求归属，共27通过；均不访问真实NAS/凭据。

首轮双模拟器+26测试过后，审查发现默认分类首次显示未保存，补onAppear共用保留回调及新增1测试；原证据保留before-retaining-default-category。最终双模拟器Debug/原生双签名Debug/双无签名Release串行过，439输入构建前后同，30/27 Mach-O核hash/签名及TV嵌入库过；正常Debug候选无参数/环境、未装真机，cp -cpR请求克隆并独立校验，root最新清单更新。

新增wall-category-fallback/search-empty/index-empty/extras-hidden四种Debug场景，纯合成CatalogItem/Group/Entry喂同一选择器，挂正式空态/共用海报卡片与网格；回退场景用原电视剧偏好+仅电影，附加视频场景只演示空态/合成展开按钮，回调为空。不构造真实model/store/vault/client/Task或请求目录/图片；不等实际分类栏/点击/控制器验证。

三端各4共12窗全部受磁盘预算阻塞：手机/Pad4.8GiB、TV3.8GiB起步，实测各3.48GiB，每端15秒有界等待后0实例/0图。未降低2GiB运行保留线、未做磁盘整理/删除旧包/清用户缓存；旧截图不补算当前新布局。最终27测试与编译不等新画面、onAppear/onChange、清除搜索/展开/遥控/读屏/滚动/图片或播放验收，114格无新P。

原包/日志/场景参数/截图阻塞记录仅留仓库外current-wall-selection-private；[安全结果](../../../testing/results/2026-10/2026-10-30-wall-category-empty-selection.json)。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T17:37:39.288573+08:00 | `7c0032fe637ab281f9cd0e0f92562d0cf8bf23893cc6e603820ea81dab4979f2` | `3dcaff9f93a1772e4f966f8a8b5b6197a2d0dc4c55621d3843aa1cc07ced51cd` | 30 |
| Apple TV | 2026-10-30T17:39:29.889038+08:00 | `cdd5c1fa622e1a7180b570768fa2770da11c086e455d6a7af8c874e5ba6dc188` | `efd6545807e902a577c80830c87aea5ff0ca053e74635b5c593c5a78c44ebce3` | 27 |

## 接续审查

已只读检查Jellyfin：移动私有JellyfinEmptyState独立VStack/本地化键，TVMediaGrid目前只有单行空提示，与网络墙呈现未共用。下一批可提炼通用空态展示，保留各入口原搜索/分页/认证/本地化/操作及播放，不把网络本机筛选器套到服务端查询上。先核错误/加载/待搜索/无结果和现有通用组件，再迁移，避免换入口就重造UI。空间达标补本批12窗、旧待验及真正清除/展开/分类/返回/焦点；真机/NAS仍等安全恢复新环境确认，Astra仅后续核心播放优化提示。
