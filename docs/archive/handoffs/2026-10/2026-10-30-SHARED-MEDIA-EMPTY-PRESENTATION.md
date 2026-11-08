# Jellyfin与网络媒体库共用空状态呈现

更新：2026-10-30T18:07:38+08:00。接续[分类与空态](2026-10-30-WALL-CATEGORY-AND-EMPTY-SELECTION.md)。仍6.1；NAS恢复期仅本地代码/隔离场景，0真机发现/控制/安装、0NAS/旧凭据/源写/播放，不改NAS/VPN，无后台任务。

## 实际共用

MediaPosterCard.swift新增公开MediaLibraryEmptyState<Actions>：调用者传系统图标、Text标题/可选Text说明、主题accent与操作内容。直接接受Text以保留调用者LocalizedStringKey的主应用本地化语义，不把键转成普通String，也不依赖数据源。统一34图标/暖色、TV标题23/说明20/操作23、iOSheadline/subheadline/body及动态字号、12间距、水平24/竖32内边距，透明承载、主题文字、长文字换行和标题读屏语义。无说明/无操作不提供占位文案；不拥有任务、请求、存储或状态。

正式消费者已迁移：移动JellyfinEmptyState原包装保留参数和满容器frame，收藏/搜索/媒体集/剧集等既有调用经它走同一组件；JellyfinCollectionView加载失败也接同一组件，原action.retry→Task await load及bordered样式保持，无额外说明文案。NetworkLibraryWallEmptyState保留选择状态/标题说明映射、清除搜索回调/样式/标识，只把内容布局委托共用组件。TVMediaGrid待搜索/无结果/空库与TV首页账号无可见库也接同一实现，空库和未搜索不写成失败，文字仍对应原状态。

空态含义、外层满页或滚动区域、操作样式由宿主保留。移动本地化键、TV原空账号说明/搜索提示、网络分类状态与动作保持；TV库无内容新增明确说明。没有把网络本机筛选器套到JF服务器，也没有给既有无操作状态捏造重试按钮。不是所有错误/加载提示都已同源：TV已有海报时的行内error/重试继续保持，本批不动错误或分页行为。

源码核对：网络墙controller/选择/分类保留/两个task/导航/源及播放、LibraryViews模型/首页/恢复与MediaWallSelection逐字同；原海报卡片/焦点/类别/标题/工具栏/网格组件除插入新组件外逐字同。移动Launchpad全文件仅空态包装与媒体集失败呈现两块变化；TV全文件仅首页账号空态及grid空态两块变化，请求、分页、offset、reload、focus和退出代码字节同。6既有源、439输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持，无新源或测试文件。

## 有限验证

4既有OfflineUIScenarioTests通过，覆盖新增media-empty-library/search/error/long显式场景及隔离参数。未增加镜像UI测试，未重复运行数据筛选/目录事务测试；上批27仅此前分类逻辑证据，不作本批画面或交互验收。双模拟器Debug、原生双签名Debug/双无签名Release串行通过，439输入构建前后同，30/27 Mach-O核hash/签名与TV嵌入库通过。正常Debug候选无测试参数/环境、未装真机，cp -cpR请求克隆后仍独立校验，root清单更新。

新增4 Debug场景直接挂正式共用组件，纯合成题名/说明、空重试/清除回调，含无动作/有动作/无结果/长标题说明；另核旧wall-search-empty真实网络包装。无真实model/store/vault/client/Task、目录/图片或服务器请求；不冒充真实Jellyfin客户端/本地化资源验证。

最初三端各5共15静态窗均预算阻塞：各观察3.15GiB，15秒有界等待后0实例/图；此结果完整保留pre-space-recovery-capture。收尾空间恢复到TV3.8GiB启动线后，仅补做电视5窗（四共用场景与网络wall-search-empty），不再尝试手机/Pad，移动10窗仍待。5窗关键字/控制出现与不存在/合成标识/背景两样本稳定/图hash过，三张对照表实看，无可见裁切或标识重叠；1自建实例finally关闭/删除、fresh列表无，合成偏好保持且无额外应用键。原生构建先于这次补图源于前置空间阻塞，439输入补图前后同，未改代码，无需重复已过构建/参数测试。

运行2GiB保留线不降，未整理磁盘/旧包/缓存/交换区。电视静态组件不是实际JF本地化、状态分支、遥控方向、清除/重试/分页/返回、滚动或播放验收；手机/Pad大字和布局未验，旧图不补本批结果，114格无新P；播放路线/引擎/缓存未改。

原包/日志/参数/阻塞现场仅留仓库外current-shared-empty-presentation-private；[安全结果](../../../testing/results/2026-10/2026-10-30-shared-media-empty-presentation.json)。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T18:00:55.140935+08:00 | `c995ac8b24266cb7ac13b26e6bd16e8833f50e25dca51dbceb7d5d74db8cb2e4` | `2bfdbc6642677ff1e5888b087226bd65ab855332562d044797ffa5b1175da441` | 30 |
| Apple TV | 2026-10-30T18:02:46.286410+08:00 | `a1bcca4e098c9c80998646d76177ebb00e24bf99e19d87c72f4dbea6732e9813` | `2473683516cdbdf04d9c1e1612762c9560d89419d1e1fbe5431e7d93e12eb9a4` | 27 |

## 接续

只读核到TVMediaGrid同一error既承接首次加载又承接loadNextPage。分页失败保留items/nextOffset，而现有重试置reload，初页task会清items；本批完整保留，不能把共用呈现宣称保住重试后的缓存。下一统一失败提示时需区分首次失败和已有海报的分页失败，保留现有回调/取消/offset，若改重试行为需另做合成并发覆盖；不要全屏失败替换仍可浏览的海报。先查已有提示组件、再迁移真实消费者。空间达标补本批15窗/旧待验，真机/NAS仍等安全恢复新环境确认，Astra仅后续核心播放优化提示。
