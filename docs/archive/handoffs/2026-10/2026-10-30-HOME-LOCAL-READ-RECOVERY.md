# 存储与媒体首页的本机资料恢复入口

更新：2026-10-30T17:01:12+08:00。接续[本机库缺失状态](2026-10-30-LOCAL-LIBRARY-READ-STATES.md)。NAS恢复期仍只本地代码/自建隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/播放/源写；不改NAS/VPN，仍6.1，无后台任务。

## 正式实现

代码审查确认首页NetworkMediaLibraryView此前只有displayError提示，无法直接重读本机资料，且原操作error优先会遮住同时存在的本机读取错误。现原扫描/操作错误仍走NetworkLibraryStatusSections原字段，本机idle/loading/failed独立分区，ready收起。两个错误同时出现时各自可见，已有ForEach媒体库/服务/浏览文件/添加及导航与sheet不变；不隐藏已加载的库。

新增NetworkLibraryLocalReadContent复用NoticeContent的标题/提示/暖色图标，和NetworkReadPageActions的重试样式。首页只显示重试，原库缺失页和已有连接页仍传自己的返回回调，继续显示返回。按钮按原TV紧凑/移动普通及辅助大字纵排规则；加载只显示进度，不给重复重试；idle/失败可以重试。内容字体TV23/说明20、iOSbody/caption，沿主题表面，无独立底色。NoticeContent新增可选标识参数，默认原network.library.error不变；本机错误用network.library.home.read.error，避免同时出现时重复标识。

重试使用现有首页.task：id从原credits来源identity扩为LocalReadRequest(contextIdentity, retry UUID)，原context变化仍触发；按钮只在idle/failed设置新UUID，不创建额外Task，不清model错误/库/凭据，不调用scan/cancel/目录服务。任务入口先核Task取消，再按原流程传context并await model.refresh。离开页面的任务所有权继续交给SwiftUI，不取消其他页面任务或共享扫描。已有模型请求归属继续拒绝旧结果；实际点击/重复触发/退出取消尚未端到端验证。

所有NetworkLibrariesModel方法、networkMessage、LibraryLocalReadState及测试逐字保持；LibraryPosterWall全文件保持，未改墙/网格/海报/搜索/目录修改返回/源/事务/凭据/播放器。3既有Swift文件（LibraryViews/OfflineUIScenario/OfflineMediaScene），437输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保留。墙当前仍使用displayError并只有原提示，不冒充已拥有首页的本机恢复动作；这是接续共用候选。

## 验证边界

4既有参数解析/隔离测试和3既有读取请求归属测试共7过，无新增镜像UI测试。新增home-read-error/loading/idle/combined/ready五个Debug场景挂正式StatusSections、LocalReadContent与ActionLabel，合成149文件库始终在。空重试/取消回调，不构造model/store/vault/client/Task或真实库，不发目录/图片/网络请求。它们只覆盖展示，不是完整首页与真实数据保持的实测。

双模拟器Debug及原生双签名Debug/双无签名Release串行过，437输入构建前后同。最初双模拟器构建/7测试通过后审查发现两种错误同时出现会重用同一错误标识，补独立标识并重建；早期成功证据保留before-distinct-read-error-identifier，无截图归属混用。最终截图无失败重采。

三端各计划5新首页状态+旧库缺失/已有连接错误两窗，共21窗；实际TV7静态窗通过（清流/栈列/流光、亮暗），核关键字/不应出现的重试和内联返回、合成标识/背景两样本稳定/图hash；四张对照表已实看7窗。包括失败/idle/两错并存可重试、加载无重试、ready收起状态、合成库可见、原两种错误页保留返回。首页无内联返回不代表系统顶部返回/菜单焦点已验。手机/Pad各7共14窗低于4.8GiB预算，有界等待后均未建实例；不能以旧图替代本批可选返回参数后的布局验收。

TV按3.8GiB起步、2GiB运行保留线，1自建实例finally停止/关闭/删除，fresh列表无，合成偏好保持且无额外应用键。没有做缓存清理、删除旧包或调整系统交换区；本批新冻结候选使用cp -cpR请求克隆副本，所有路径独立并重新核二进制hash/签名，保留旧证据，不能把请求克隆当作测得的空间节省。

30/27 Mach-O核hash/签名、TV嵌入库检查通过；正常Debug候选无测试参数/环境、未装真机，root最新清单更新。移动大字、真正重试/导航/取消/重叠执行、遥控/读屏/滚动/真实资料和播放仍待；114格无新P，播放路线/引擎/缓存未改。原包/截图/命令/偏好只在仓库外current-home-local-read-retry-private，[安全结果](../../../testing/results/2026-10/2026-10-30-home-local-read-recovery.json)。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T16:56:24.367403+08:00 | `2895a04d9bb1579b70966559d16ac8381814d2911cf0f77c93344423067c5198` | `fe061d4bab6d9b1a86a7e25ed04da82f8ab7fb2de40cfda41aa739a7a2d135ab` | 30 |
| Apple TV | 2026-10-30T16:58:15.001191+08:00 | `9ffbe7f105494b86859b05a2c35735e8632c8a514afcd240989f67d71c3d8655` | `83a2a3f1b8ef2eabd278831b0e204df0506b4bb609922037e573ddc2c038415c` | 27 |

接续先核空间，达标再补移动14窗/旧待验项与真实操作，不重复建受阻实例。受阻可把保留的海报墙本机读取错误恢复动作接同一组件，已继续审查：墙现有.task(id:library.id)同时承担初始焦点和旧索引artworkScanVersion<4自动补扫；后续不能直接把重试UUID并入该task，否则本机重读可能触发scan。应保留该task原行为，给读取恢复单独的页面生命周期，且只调refresh。所有真机与NAS继续等安全恢复后的新环境确认，Astra仅后续核心播放优化提示。
