# 首页与海报墙共用整理状态内容

更新：2026-10-30T15:51:34+08:00。接续[首页状态批](2026-10-30-LIBRARY-SCAN-STATUS-PRESENTATION.md)。NAS恢复期只本地代码/任务自建隔离模拟器，仍6.1；0真机发现/控制/安装、0NAS/旧凭据/播放/源写，无后台任务，不改NAS/VPN。

## 实际接入

NetworkLibraryActivityContent/NetworkLibraryNoticeContent不依赖List或model，同一内容包含标题、已发现视频文件数、原取消动作、说明、暖色符号与语义文字。首页NetworkLibraryStatusSections只做Section承载，海报墙NetworkLibraryWallStatus只做圆角主题卡片承载；LibraryPosterWall.header实际接后者，替换独立ProgressView与红字。TV正文统一23、标题23 semibold、说明沿20；iOS使用body/headline/动态字号，不再随两个父容器继承出不同字号。内容已是两个正式消费者共用，不是仅新增接口或计划。

海报墙只对当前库scanning或原有全局error显示状态，空闲时保持原头部布局；没有新增错误归属或隐藏其他库留下的原全局错误。状态标题放进共同内容，首页/墙同一信息层级；新内联取消ID为network.library.cancel.inline，首页和既有菜单继续用原network.library.cancel，避免墙内重复标识。

scanAction仍先核scanning==library.id，再核原canCancelScan；只有当前库扫描Task存在时显示“取消扫描”，其他编辑更新显示非交互“正在更新资料”。保留原刷新/改目录/禁用条件及cancel/scan回调，不改变model任务/事务，也没有宣称取消已完成。网格、海报/演员读取、搜索、导航/sheet与既有焦点回调逐字保持；仅状态新增可聚焦的内联取消，其遥控走向仍未验。

4既有源（LibraryViews/LibraryPosterWall/OfflineUIScenario/OfflineMediaScene），435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持。model/HomeController与其他控制器、源/存储/凭据/播放字节同；无路线变化，不改播放链路文档。

## 有限验证

Debug新增wall-scanning/updating/notice，直接挂正式WallStatus和共同内容；ScrollView用合成库名/海报区标记，不构造真正PosterWall、model/store/vault/client/Task，无图片/目录请求，取消为空回调。TV预览导航标题保持空、只用既有媒体标题组件，不重复居中大标题；这不是完整墙、真实网格或菜单弹出验证。

4既有OfflineUIScenarioTests过，覆盖新场景解析/显式错误参数隔离；无新镜像UI测试。双模拟器Debug及原生双签名Debug/双无签名Release过，全部串行降低内存峰值；435输入hash同、30/27 Mach-O核签/TV嵌入库过。普通Debug候选无测试参数/环境、未装真机，root清单更新。

计划三端各首页/墙3窗共18，实际TV6静态窗通过，三种主题的首页/墙两两对照：整理149文件/可取消、编辑更新0/无扫描取消、超时提示/无取消。关键文字、“离线界面测试”及“合成”标识、背景稳定和图hash成立；全部原图生成三张对照表实看，字体/语义色/卡片与可见控制一致。本批无失败重采，不将菜单条件源码核对当菜单实际操作，也不把内联焦点描边当遥控验证。

手机/Pad低于4.8GiB启动预算，有界等待后均未建实例，12窗仍待；本批6窗不叠加上批手机5/TV3成新结果。TV按3.8GiB起步/2GiB运行保留线，1自建实例finally清理、fresh列表无，合成偏好保持且无额外应用键。本批未做存储整理或其他缓存清理，不改系统交换区/用户应用；收尾约4.3GiB。实际Task/取消、返回/菜单/焦点/滚动/读屏、真实数据和播放继续未验，114格无新P。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T15:43:57.777196+08:00 | `f5d7e7313279236601775608e4f785c9f697f2fc1e39155fdd635719016d4b4c` | `bde984df2c1ab8123a5fc0cca9c754b1948d302e3359bdf67a105ec7b9516d56` | 30 |
| Apple TV | 2026-10-30T15:45:47.860121+08:00 | `d3993e89e640de25ba8a1e703ec4a876b07a719c56798d9c8f6f6c56a45af539` | `e04060f73154991190e193317d475d97cd229632056941351b338fb3f8a32233` | 27 |

原包/图/命令/偏好仅仓库外current-wall-status-unification-private；[安全结果](../../../testing/results/2026-10/2026-10-30-shared-home-wall-status.json)。[播放矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)已核、无新P，路线/引擎/缓存不变；真机与NAS等安全恢复和新环境确认后fresh设备/最新包。Astra只后续核心优化提示。

下一步先核空间；预算允许再补移动端12窗及旧已有连接Pad状态/真实返回。受阻继续审查其他网络媒体加载/空状态的可复用展示；不要为了补图降低保留线或反复创建受阻实例，不把合成回调算真实联调。
