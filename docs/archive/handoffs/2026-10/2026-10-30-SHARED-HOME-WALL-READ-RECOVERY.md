# 首页与海报墙共用本机资料恢复

更新：2026-10-30T17:20:47+08:00。接续[首页恢复批](2026-10-30-HOME-LOCAL-READ-RECOVERY.md)。仍6.1；NAS恢复期只本地代码/任务隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/播放/源写，不改NAS/VPN，无后台任务。

## 实际接入与任务边界

海报墙原displayError只呈现一个合并提示。现header与移动端是否显示状态，均按当前库扫描、原操作error、本机读取phase判断。操作error与读取错误分别承载；ready本机状态收起，idle/失败可重读，loading只进度，既有网格/海报/搜索/选片/目录编辑/菜单与已有库不因提示替换而清空。

NetworkLibraryWallStatus在主题卡片中实际接首页的同一NetworkLibraryLocalReadContent，继续用NoticeContent/ReadPageActions。共享内容新增identifierPrefix，首页默认network.library.home.read保持，墙为network.library.wall.read；读取进度/错误/重试标识不与原操作error、inline取消或其他宿主重复。TV正文23/说明20，iOSbody/caption与大字纵排、暖色符号/语义文字沿原实现，没有另造墙专属恢复UI。

墙新localReadRetry UUID仅在idle/failed置值，单独.task(id:localReadRetry)先核存在与取消，再仅await model.refresh。defer只清仍属于本次的UUID，不覆盖更新请求；onDisappear清待处理UUID，由此任务id和页面生命周期取消本页读取，避免未开始的请求或完成后的UUID在返回时自动重放。实际SwiftUI取消/返回仍未验，不将代码守卫当真机结果。

原.task(id:library.id)包含初始焦点和artworkScanVersion<4旧索引补扫，整块逐字保留；新重读不修改其key、不调用scan/cancel，不创建脱离页面的任务。NetworkLibrariesModel/refresh/迁移/存储/凭据、读取请求状态与测试、首页controller、墙搜索/网格/导航/sheet/onSaved→dismiss和菜单全部相应源码核同；仅状态接线与本页读取任务新增。没有改播放路线/引擎/缓存或NAS原文件。

4既有源（LibraryViews/LibraryPosterWall/OfflineUIScenario/OfflineMediaScene），437输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持；无新源/新测试。displayError兼容getter暂留，但首页和墙已分开消费操作/读取状态，不再依赖它合并遮盖。

## 有限验证

4既有参数/隔离测试+3既有读取请求归属测试共7通过；新6种wall-read-*都由参数allCases覆盖。它们不验证新的SwiftUI UUID清理或原真实迁移任务。双模拟器Debug、原生双签名Debug/双无签名Release串行过，437输入构建前后同；30/27 Mach-O核hash/签名、TV嵌入库检查过。普通Debug候选无参数/环境、未装真机，root最新清单更新，新副本cp -cpR请求克隆后仍独立校验。

Debug扩充已有OfflineWallStatusScene，6新状态error/loading/idle/combined/ready/scanning直接挂正式WallStatus及共享内容；scanning合成149文件、可取消扫描+本机读取失败同时呈现；再核旧wall-scanning与home-read-error。固定phase/文本/合成海报区，空回调，不构造model/store/vault/client/Task，原3种墙场景保留。

三端均低于启动预算，等待后0实例；没有新截图。纯组件此前首页/墙静态图只是历史基线，不能作本批新呈现验收；源码/编译/参数测试不代替画面或交互。

本批：三端24静态窗均预算阻塞、0实例，尚无本批新图。移动4.8GiB/TV3.8GiB起步及2GiB运行保留线不降；实例有则finally关闭/删除并fresh核无，合成偏好保持，无实例则不写成UI通过。初次因空间无法先出图，后续编译与模拟器仍串行，不把编译时空间变化当布局证据。

只对旧任务包做元数据预检：最多3个大framework即使理想共享也最多0.131GiB，当时可用3.494GiB，仍低于TV3.8GiB启动线。因此0旧包修改/0共享操作，未执行清理，不再尝试；数值为本轮观测，不是空间节省。

真实重试/退出/返回、旧请求取消、扫描与读取并行、真实库和图片、焦点/读屏/滚动/播放均未验；114格无新P，旧失败保持。原图/包/命令/偏好只留仓库外current-wall-local-read-retry-private；[安全结果](../../../testing/results/2026-10/2026-10-30-shared-home-wall-read-recovery.json)。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T17:13:55.680883+08:00 | `a16cffe4faeb9c33a4b8e0c776b1d124eae6e23f3be82de3e5c8c15c231352d2` | `62e9b0e0278a67b7a9d52cba01d78e24dc34e8afbd908f5c6cfe70726ada4b3c` | 30 |
| Apple TV | 2026-10-30T17:15:45.030422+08:00 | `9e6f95cd0279f659672c940847e189ab849b885ff5f4fb097c1192cab4100070` | `b39fb02fca37d56c25442b34fd4e00087a90ae9992ed34c5d6eb138fe095e1a8` | 27 |

接续先核空间，达标补本批移动/旧待验项与实际返回，不重复建受阻实例。独立工作可审查重读后的分类保留与空搜索提示：matching/categories目前直接优先旧category，需核类别已不存在时是否误显空库，不臆断真机复现；保留搜索/焦点/网格，不重复造展示代码。真机/NAS仍等安全恢复新环境确认，Astra仅后续核心播放优化提示。
