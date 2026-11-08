# 电视网络季页面复用Jellyfin海报网格

更新：2026-10-30T07:03:35+08:00。NAS恢复期，仍6.1，仅本地/自建隔离模拟器；0真机发现、安装或控制，0NAS/旧凭据/播放/源写，无后台任务。

NetworkSeasonPage的TV分支由纵向行改为MediaPosterGridLayout.television + MediaPosterGrid + MediaPosterCard（16:9）+ MediaPosterFocusStyle，与TV Jellyfin剧集卡使用同组件。标题34、卡题23/副题20、列间38/行间30、卡片宽减20给焦点留边及纵向70边距沿既有网格；读取相同tv.library.posterDensity，默认4、合法3–5/窄窗或辅助字号按共用算法减列。奇数末行按原网格靠左，不拉宽/造空卡。季标题只保留一处左对齐标题，无额外数量大框。移动继续MediaEpisodeRow，提取标题/集号帮助函数供两个分支使用，未知集号不虚构。

2既有源：SeriesViews与OfflineMediaScene。系列概览、季数据/排序/文件计数、详情destination、网络图片读取和所有播放/分类/聚合源均保持；TV Jellyfin源码未改，其既有自定义方向处理也未迁移或冒称通用。网络网格沿系统焦点，不在本轮宣称方向/返回/滚动已验。没有实现多版本归并、原盘主片选择或自动连续播放。多文件信息检查确认仍保留物理文件和现有折叠入口，下步只改善表述/选择布局，不能凭标题强并不同作品。

Debug episodes在TV用同一网格/卡片，7合成项覆盖长标题、缺图、无编号及奇数末行；iOS仍原4合成行，只有内存状态，不构造库model/client/store或读正式密度偏好。5有效静态窗：TV流光深、清流浅、栈列深；手机/Pad流光深辅助字号各1。预期文字/合成标识、连续背景采样和最终图hash通过，关键实图已看。采图完整前缀含场景/主题/深浅/字号，未覆写。3自建实例shutdown/delete后fresh列表无，合成偏好哨兵保持、无额外应用键。图片均为合成素材；截图不是真实资料/焦点/流畅/播放验收。

24既有测试（网格2/分类11/投影7/离线参数4）、双模拟器Debug、双签名Debug、双无签名Release过；未增加镜像UI测试。435冻结输入构建后hash相同；30/27 Mach-O核签与TV嵌入库过。普通候选未装真机、无测试参数/环境，root两包/输入清单已更新。原图/命令/包/身份仅在仓库外current-season-grid-polish-private。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T07:00:18.363458+08:00 | `9d65e79ab5a0ed506afadb508e98b3bf6659a9192a4341f40b12de985537708e` | `b7be4ccc35d10a2cf40147742843f380b57a689307aca3041c567008ce8c53ef` | 30 |
| Apple TV | 2026-10-30T06:58:27.366024+08:00 | `b0480681c16f3b8d0f92c9d325067c09a9cc500488cd4c718e5cb7cf68e01217` | `cd454cb5cc2a5fde5c8f429c80487f6eebec6251741a82bc6ec5b9a40b1ba3c3` | 27 |

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保留。[安全结果](../../../testing/results/2026-10/2026-10-30-season-grid-polish.json)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。114格无新P，播放路线文档未改；真实图片/头像/目录事务/返回闪动、原大文件/弱蜂窝/ISO等仍待NAS恢复。收尾空间约7.4GiB，下批先核空间，模拟器串行、同目录构建串行；不使用已清历史包路径。
