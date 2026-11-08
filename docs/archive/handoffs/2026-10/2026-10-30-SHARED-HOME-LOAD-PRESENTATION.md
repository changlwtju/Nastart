# 三端Jellyfin首页加载失败提示共用

更新：2026-10-30T22:47:07+08:00。接[标题与滚动批](2026-10-30-WALL-NAVIGATION-TITLE.md)。仅本地代码/任务隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/源写/播放；无后台任务，沿用户既定模型分工。

## 实际实现

MediaPosterCard新增公开MediaLibraryLoadFailure<Actions>，由宿主传hasContent、Text标题/原错误消息、accent/messageIdentifier和恢复动作；有可见内容委托MediaLibraryNotice，无内容委托MediaLibraryEmptyState。没有自己的数据、任务或恢复状态；原卡片/空态/Notice/网格/焦点组件保持。

移动JellyfinHomeView实际替换旧VStack错误区，hasVisibleContent按真正显示的featuredItems/媒体库/继续观看/收藏/电影/剧集判定，最近添加只通过可见hero计入，避免只存在于store却没有显示的资料误作可见内容。仅选提示承载，不更改内容筛选、排序、缓存或请求。新中英文标题key jellyfin.library.load_incomplete各一条，原errorMessage、action.retry及Task await store.refresh/bordered原样保留。

TVLibraryView主错误区实际接同一LoadFailure，hasContent包含libraries/resuming/recent，故主库读取失败但某个已有架子可见时仍用行内提示。“继续观看”“最近添加”的两项部分失败由caption小按钮改接MediaLibraryNotice，提示留在各自架子后，原错误条件及数组保持。三个位置共用homeRetryAction，暖色arrow/主色文字/紧凑padding及既有TVTileStyle，仍只reload=UUID，不另启某架子请求或改变刷新范围；三条原.task的loading/error/cancel赋值与client调用逐字同。TV grid/其他页面同，移动store/auth/所有读取与播放同。

7既有源码/资源，439输入中其余432逐hash同，无新测试/源；App变动限定移动Home/TVLibraryView，非所有错误状态/所有入口均已同源。不把新展示类当独立业务模型或新的播放入口。

## 有限验证

新增home-load-empty/retained/shelf三个Debug参数，前两挂正式LoadFailure，第三挂正式Notice；带内容样例只两张固定合成缩略卡，不是真实Jellyfin库、首页store或架子。操作为空，TV沿NetworkTVCompactStyle而非实际TVTileStyle；无model/store/vault/client/Task/真实图/网络，不能验实际缓存/请求/重试/焦点。

三端各3共9静态窗，分别glassDeck/dark、commandCenter/dark、cleanGrid/light，标题/消息/重试/合成标识、背景连续两样本稳定与图hash核过，6张对照表实看。初始样例没有合成海报，保留内容与分区提示样例海报在上方可见；只是所选展示组件的静态证据。3自建实例finally关闭删除且fresh列表无，合成偏好保持，无额外应用键。按原4.8/3.8GiB启动、2GiB运行预算，没有删用户缓存/旧包或改交换区。

4既有参数/隔离测试（覆盖新增场景枚举）过、两模拟器Debug及两正常签名Debug串行过，中英文strings格式及新key唯一性过。未重跑Release，不把上批Release/其他数据逻辑测试算本批执行。439输入构建后同、正常候选30/27 Mach-O核hash/完整签名及TV嵌入库过，cp -cpR请求克隆并独立核验，无测试参数/环境、未装真机，root清单更新。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留继承未提交修改。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T22:40:57.061125+08:00 | `c4f111e9178ef7d4a27786aeafcbda5837265977510cfdec92cef467efc63ccc` | `daf217f241560e9ef1901f2888908bf46995222aa8a7ebe5806d9c4c2d0c13b6` | 30 |
| Apple TV | 2026-10-30T22:41:11.181914+08:00 | `04f9050c25bc32343a7bff3af2df972273f48e79ef212c9aa4a9b8458ab4087c` | `8df9ccef8989e720ed7f1e03c259a036d3a69baf4c6338760d3da575fd2a2141` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-shared-home-load-presentation.json)，原始包路径/日志/图/偏好只在仓库外current-home-load-presentation-private。真实首页保留数据、各来源恢复、按钮/遥控/本地化全语言/辅助字号/读屏/滚动性能仍未验；上批手机大字输入无合格位移的失败仍保留。播放路线/引擎/缓存未改，114格无新P。

## 接续

继续把媒体集/剧集详情等首次/部分失败提示接相同组件，先确认错误条件及重试范围，不改服务器搜索/分页。真实恢复行为如需变更，先合成offset/generation/迟到/取消/去重覆盖；TV现有grid reload仍从头刷新。其他旧待验及真实NAS/播放等安全恢复后重新确认环境，Astra仅核心播放优化前提示。
