# 共用媒体加载失败与保留内容提示

更新：2026-10-30T18:45:46+08:00。接续[共用空态](2026-10-30-SHARED-MEDIA-EMPTY-PRESENTATION.md)。仍6.1；NAS恢复期仅本地代码/隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/源写/播放，不改NAS/VPN，无后台任务。

## 实际实现

MediaPosterCard.swift新增公开MediaLibraryNotice<Actions>，接Text标题/消息/可选说明、主题accent、消息标识与真实操作内容。行内leading布局、12间距，暖色符号、TV23标题/正文与20说明、iOSheadline/body/caption，透明承载、标题语义及消息combine，字体与源无关；无数据/请求/任务/恢复状态。原MediaLibraryEmptyState、海报/网格/焦点等共用组件逐字保持。

NetworkLibraryNoticeContent三端包装实际委托此组件，保原标题/消息/identifier（包括默认network.library.error与本机读取独立标识）；原Section/墙主题卡片、外层读取说明/重试/取消及模型不变。不是只新增公开接口或独立Debug页面。

TVMediaGrid首次失败（error且items空）用已有MediaLibraryEmptyState，搜索失败/媒体库读取失败标题区分；带items的失败则在现有网格及loadingMore之后，用同一MediaLibraryNotice，提示“后续内容暂未加载”。保留全部海报/导航/原焦点回调，状态位置不全屏覆盖网格。新重试按钮沿TVTileStyle、暖色图标/主色文字/紧凑内边距，标识分别tv.media.retry与tv.media.reload.afterFailure。

两种按钮仍只执行原reload=UUID()，没有改变网络、分页或缓存恢复策略。带内容按钮改名“重新加载”，说明“已显示的海报仍可浏览。重新加载会从头刷新列表。”，准确反映原行为；并非已实现从失败offset续接。点击后原初页task依然清items/nextOffset，行为没有偷偷变更。首次及分页错误原message原样传Text，不改现有错误分类/清理。

源码核对：NetworkLibraryNoticeContent以外LibraryViews全文件同（模型/首页/读取任务/迁移/存储/凭据等），LibraryPosterWall及MediaWallSelection全文件同；TV全文件只初始错误/保留内容提示两块变化，所有请求、offset/generation、去重、reload任务、焦点/退出代码同；移动JF源码未改，其初始媒体集失败已沿上批EmptyState。5既有源、439输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持，无新源/测试。TV首页其他错误、移动服务错误等不是本批全部迁移的承诺。

## 有限验证

4既有参数/隔离测试通过，含新media-failure-initial/retained/long。未加镜像UI测试或重复跑无变化的目录/数据测试；它们不验证真实分页和重试。双模拟器Debug/原生双签名Debug/双无签名Release串行过，439输入前后同、30/27 Mach-O核hash/签名及TV嵌入库过，正常候选无测试参数/环境、未装真机，cp -cpR请求克隆仍独立核验，root清单更新。播放路线/引擎/缓存未改，114格无新P。

新3 Debug场景挂正式EmptyState/Notice；保留内容场景只是两张固定合成缩略卡在提示上方，不是TVMediaGrid真实客户端或分页网格，动作为空、沿NetworkTVCompactStyle，不能冒充实际TVTileStyle按钮验证。另核library-notice/wall-notice真实网络包装，共三端计划15窗。

实际TV5静态窗通过：三个新场景及网络首页/墙提示，三主题/亮暗，文字/正确控件/合成标识/背景两样本稳定/图hash核过，三张对照表实看；合成卡/保留说明/重新加载按钮可见，未见裁切或重叠，无失败重采。手机/Pad各5共10窗低于4.8GiB起步线，分别15秒等待后未建实例；TV按3.8GiB起步/2GiB运行线，1实例finally清、fresh列表无，合成偏好保持且无额外应用键。没有磁盘整理/删旧包/清用户缓存或改交换区。

真实首次/分页故障、海报保持、按钮点击/重试/offset、TVTileStyle焦点/位置/返回、移动大字/布局、本地化/真实图片/播放均未验；旧图和4参数测试不补这些结论。原包/图/命令/偏好仅仓库外current-shared-load-failure-private，[安全结果](../../../testing/results/2026-10/2026-10-30-shared-media-load-failure.json)。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T18:38:30.190028+08:00 | `270d75820ef26c8533eb4e612667b1eee163a9a824bd3072b9d4850e401cb92c` | `6764b2afe1838d17dd36d8667182dc03c26cfc934827ab90f097e22a80661456` | 30 |
| Apple TV | 2026-10-30T18:40:23.282840+08:00 | `78240bdcf37ffea72df72962fd79e52c2494785f0261b11c663855da0ea71abe` | `85085c4f05a60ad15840083d4c9c7980c91980a9708f685603d0b01255775913` | 27 |

## 空间恢复后的补验（2026-10-30T18:57:08+08:00）

空间恢复后同包补验，本批15静态窗：12过/3未过（TV5/手机3/Pad4），4实例清；首次预算阻塞与失败均保留。手机先2过，长提示大字在首屏放不下重新加载而50秒检查超时，finally清理；不重复这条失败窗，后续独立实例只补其余2窗。Pad5窗有4过，wall-notice缺预期“合成媒体库”标题而不通过；人工核对提示正文/主题承载存在，没有把正文可见改判为整窗合格。失败不丢弃、不改验收条件，本批未修改源码或重复构建/核签包。手机大字的说明/按钮在滚动区下方，滚动后可用性尚未核；缺标题与真实宿主关系待查，不能据合成画面断言正式导航有缺陷。

手机/Pad五张对照表与TV原三张已实看（含失败窗），合成偏好保持、图hash核验，4个自建实例finally删除/fresh列表无。初期TV5及移动10预算受阻记录仍在initialCapture；本次是空间自然恢复后新增证据，非抹除原阻塞。普通移动提示及Pad长字有静态证据，原先移动10“全部待补”状态已被本节取代，但实际点击/滚动/焦点/分页/本地化/数据/播放依旧未验。

## 接续

继续收敛其余带缓存的加载失败/读取提示，并保持“首次失败不写成空库、分页失败不遮已载内容”。如要让分页重试从失败页续接，先用合成分页覆盖offset/generation/重复项/取消/迟到回包，再改正式数据回调，不把本批UI改名算续接已交付。优先查手机大字滚动及墙提示缺标题，并补旧待验和实际遥控，真机/NAS仍等安全恢复新环境确认；Astra仅后续核心播放优化提示。
