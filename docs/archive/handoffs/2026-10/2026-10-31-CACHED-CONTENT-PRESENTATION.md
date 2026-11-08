# 媒体集与剧集的缓存内容展示

更新：2026-10-31T05:32:26+08:00。接[首页提示批](2026-10-30-SHARED-HOME-LOAD-PRESENTATION.md)。仍按用户既定模型分工，仅本地代码/任务隔离模拟器；0真机发现/控制/安装、0NAS/旧凭据/源写/播放，无后台任务。

## 交付范围

新增MediaLibraryContent<Content,Recovery>共用SwiftUI展示容器，只接isLoading/hasContent/可选Text错误与标题、主题/标识、内容和原恢复操作。LazyVStack保懒构建：加载时显示进度，失败时委托既有LoadFailure/Notice/EmptyState；有底层内容始终挂内容，没有内容仅在非加载且无错误时挂空内容。没有自己的数据、持久化、任务或网络。既有共用组件保持。

移动JellyfinCollectionView与SeriesView实际消费。媒体集不再用加载/失败整页分支替换旧海报；保原查询过滤/海报网格/导航/标识，状态提示有16边距，初次无内容保容器最小高度。hasContent依据未过滤items；已有缓存但当前关键词无匹配时，显示行内失败加搜索无结果，不误报空库。剧集列表在加载/失败时继续挂原按季ForEach和行，hero/简介/季集分组保持；首次失败提供错误说明与原重试。成功但无集数改用剧集专属空态文案，避免说账号无媒体库，中英文各4个新key。

6既有源码/资源、439输入中其余433同。load()/loadEpisodes()及后续查询/季分组方法逐字同，原Task await load/loadEpisodes与bordered保持；store/auth/所有请求/播放器同。只改展示，不改变取消/迟到响应处理，不扩展持久化缓存；尚不能称图片闪动或真实恢复已修复。TV业务页未改，TV仅编译共用容器与有限样例，不声称电视分页/刷新也已统一为保留内容。

## 验证与边界

六新Debug场景content-loading/loading-retained/error/error-retained/error-search/empty直接挂正式容器，分别固定输入；内容是两张合成卡或合成空态，操作为空，无model/store/vault/client/Task/真实图/网络。手机/Pad各6、TV只首次/带内容失败2，共14静态窗；自动核预期/禁用文本、主题/连续两样本背景/hash，全部对照表实看（含初始进度），有缓存的加载/失败卡片与恢复按钮可见，空态只在成功无内容时出现。静态固定状态不是请求/状态转换、真实集合/季列表布局、图片身份/闪动、点击/滚动/焦点/帧时间或读屏验收。

4既有参数/隔离测试覆盖新增枚举过，双模拟器Debug及正常签名Debug串行过，两语言strings格式与新key唯一性过，无镜像UI测试或新增测试文件。Release未重跑，不借用旧结果称本批Release验收。439输入构建前后同、正常候选30/27 Mach-O hash/完整签名和TV嵌入库过，cp -cpR请求克隆并独立核验，无测试参数/环境，未装真机，root清单更新。3自建实例finally清理且fresh列表无，合成偏好保持/无额外应用键，沿4.8/3.8启动与2GiB运行预算，未清用户缓存/旧包。

临时证据定位文件缺失已从本机原证据区恢复；首次基线命令在写入前失败，新容器补丁已加入后，通过仅移除本批完整新增块重建其原文，其余五基线直接读取；六基线SHA均与上一冻结清单一致才继续。没有丢弃用户改动。[安全结果](../../../testing/results/2026-10/2026-10-31-cached-content-presentation.json)，原始包路径/图/命令/偏好仅仓库外current-cached-content-presentation-private。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T05:24:52.816517+08:00 | `b6ecdb7b70bfee0bf52393f6ebbc2c9a2f0c31c06d0bbff05da4cb9e85f61a4c` | `ba55c647a81cdb850eb5dd7aa246adfaf8ae0ca7ef439f6c4b0897715153fe60` | 30 |
| Apple TV | 2026-10-31T05:25:06.594856+08:00 | `24a4a3de480e4571221c6546c9a500024b152eae7edbba219015ddf81f2f127c` | `5fc9e306eb94f838ceafe3ed6ec0a1112d936e85679b9790a770f1ab9ffacf64` | 27 |

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持。旧手机大字滚动无位移、其他积压与真实恢复仍开放；播放路线/引擎/缓存没改，114格无新P。

## 下一步

核对其他搜索/详情状态的语义再复用。移动全库搜索遇错会清results，不能直接保留上一关键词结果来套本容器；先确保结果归属/取消/重试语义，不能为展示复用改请求策略。TV grid原reload会清items，从头刷新不等失败offset续接；改业务恢复需先合成并发覆盖。真实网络/播放待安全恢复新环境，Astra仅核心优化前提示。
