# Nastart UI Style Guide

2026-11-03 [本批接受的布局](../archive/handoffs/2026-11/CODEX-2026-11-03-CLAUDE-UI-INTEGRATION.md)：iOS 17+ regular 宽度的设置/服务类子页使用约 720pt 可读宽，iPhone/iOS16 保持原分支；海报墙/网页/本地预览不套该限宽。Pad 三主题标准字号服务两列，辅助字号回单列；紧凑宽大字海报改横排行；海报仅裁封面，不裁标题。禁用操作用灰色并保留原因，清缓存沿系统 alert。TV 层级字号/焦点与状态标签按本批实现接受，完整遥控/读屏/性能未据此验收。旧 DEBUG 页脚观察按历史日期理解。

隔离预览的导航子页也要自行承接宿主主题，不能只给父页铺背景；Debug标记不能遮挡滚动末尾内容。两处预览黑底已修，Pad英文大字页脚遮挡仍待处理；正式宿主没有同一标记，不据此推断产品缺陷，见[本轮检查](../archive/handoffs/2026-11/2026-11-01-OFFLINE-SETTINGS-RECOVERY-AND-PRIVACY-PREVIEW-THEME.md)。

播放器设置的服务清单采用共用产品顺序、暖色图标及状态行。清单在线/安装、发现线索、保存授权与实际登录分别表述；无匹配用尚未确认，不推断未安装或未授权。未接原生媒体库的服务明确说明，服务摘要不代替精确身份校验，见[共用服务行](../archive/handoffs/2026-11/2026-11-01-SHARED-PLAYER-SERVICE-INVENTORY-ROWS.md)。

外观的紧凑指标、服务状态和卡片副标题使用同一NastartLaunchpadCardRows，名称/图标共用、Binding仍由各宿主提供。暖色图标之外使用主色文字；TV系统橙色焦点下图标与文字需要可辨对比，不能继续用相同暖色淹没图标，见[本批有限核对](../archive/handoffs/2026-11/2026-11-01-SHARED-APPEARANCE-CARD-OPTIONS.md)。

连接摘要的URL展示复用 `NetworkConnectionAddress.displayText(for:)`，移除用户、密码、查询和片段，保留协议/主机/端口/编码路径；显示值不得回填连接、存储或来源身份校验。TV原格式化保留薄包装，手机/Pad备用入口及三端服务详情共用，见[共用地址批](../archive/handoffs/2026-11/2026-11-01-SHARED-CONNECTION-ADDRESS-DISPLAY.md)。这不自动隐藏自定义名称或路径中的敏感内容，也不是全应用安全审计。

电视已保存账号应显示已保存登录配置/授权，不推断在线；连接卡片地址显示隐藏URL用户、密码、查询与片段，保留协议/主机/端口/路径。仅改展示，不能改实际会话路线，见[本批](../archive/handoffs/2026-11/2026-11-01-TV-CONNECTION-STATUS-AND-ADDRESS-PRESENTATION.md)。

凭据本机状态与服务器连接状态分开：只收到凭据/空结果时分别显示已保存/未读取到，不把读取失败当未保存。设置子页沿暖色图标和系统Toggle，辅助字号可纵排；无选择的禁用操作需说明原因，见[本批](../archive/handoffs/2026-10/2026-10-31-CREDENTIAL-STATUS-AND-EXPORT-SELECTION-ROWS.md)。

清理操作的名称、说明和确认须覆盖实际范围及会话影响；确认展示只接宿主动作，预览不执行真实清理。导出说明应区分结构化字段与自填文字，不作未经验证的完全匿名保证，见[本批](../archive/handoffs/2026-10/2026-10-31-PRIVACY-CLEANUP-SCOPE-AND-EXPORT-COPY.md)。

同步页按设置与事项、账号与授权、媒体资料与进度复用同一内容，实际可用状态由宿主决定；说明用户可理解的数据去向，不要求用户处理开发签名。TV固定三项普通字号等宽、大字纵排，见[本批](../archive/handoffs/2026-10/2026-10-31-SHARED-SYNC-SCOPE-AND-AVAILABILITY.md)。

搜索结果与加载/错误必须按当前关键词和请求代次归属，失败提供同词重试；不可拿上一关键词结果作当前缓存。暗色Hero中的共用提示局部指定暗色语义，避免受浅色页面主色文字影响，见[本批](../archive/handoffs/2026-10/2026-10-31-SEARCH-REQUEST-OWNERSHIP.md)。

有缓存的列表刷新/失败时保留内容，状态与内容共存；首次读取中不出现成功空态。当前关键词无匹配应显示搜索无结果，不能把底层缓存当空库，参见[共用Content容器](../archive/handoffs/2026-10/2026-10-31-CACHED-CONTENT-PRESENTATION.md)。跨关键词结果必须先确认归属，不盲目保留。

媒体首页加载失败按实际可见内容选MediaLibraryLoadFailure：没有作品用EmptyState，有作品用Notice；局部分区提示留在其架子后。展示层只接宿主动作，不改变重试范围/缓存，不因错误隐藏已载内容，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-LOAD-PRESENTATION.md)。

导航标题每个平台只设一次；TV要隐藏系统标题时放互斥分支，避免空标题和iOS库名叠加。辅助字号允许内容自然滚动，核对操作可到达，不强压文本求首屏全见，见[本批](../archive/handoffs/2026-10/2026-10-30-WALL-NAVIGATION-TITLE.md)。

失败提示按内容上下文承载：无结果时用共用EmptyState；有海报时用共用leading Notice，保持可浏览内容，分页提示靠近列表尾部。回调如仍从头刷新，按钮应明确“重新加载”及影响，不暗示续接失败页，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-MEDIA-LOAD-FAILURE.md)。

媒体空态统一图标34/暖色、TV23标题与20说明、iOSheadline/subheadline动态字、12间距及24×32内边距。调用者用Text保留本地化、用Actions保留真实回调；空库/待搜索/无结果/失败含义不混用，宿主布局按满页或内容区适配，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-MEDIA-EMPTY-PRESENTATION.md)。

分类高亮与可见网格从同一选择快照生成；刷新保留有效分类，失效回退并更新偏好。空库、当前类无搜索结果、隐藏附加视频分别提示，清除关键词不改变分类/展开状态，见[本批](../archive/handoffs/2026-10/2026-10-30-WALL-CATEGORY-AND-EMPTY-SELECTION.md)。

首页与海报墙共用本机读取进度/错误/重试内容，承载分别为Section/主题卡片；操作错误与本机错误各自可见，成功收起、已有海报保持，扫描取消与本机重试不混用，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-WALL-READ-RECOVERY.md)。

本机资料读取错误与扫描/连接操作提示分开，首页提供原地重试，加载期间收起重复动作，成功收起状态、保留媒体库；重试按钮沿子页共享样式，返回按宿主需要可选，见[本批](../archive/handoffs/2026-10/2026-10-30-HOME-LOCAL-READ-RECOVERY.md)。

库入口缺失要区分正在读取/读取失败/未完成/已变更，保留可操作的返回；恢复按钮与连接准备页共用，大字纵排、普通横排，失败页避免重复标题，见[本批](../archive/handoffs/2026-10/2026-10-30-LOCAL-LIBRARY-READ-STATES.md)。

媒体库状态的内容独立于Section和卡片，首页/墙实际共享标题、计数、控制和提示；字号由内容明确，取消能力相同、内联与菜单标识不同，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-AND-WALL-STATUS.md)。

媒体库整理状态靠近内容前部，数量明确视频文件；只在扫描拥有可取消任务时提供扫描取消，其他编辑操作回原编辑页。错误以操作提示/暖色符号/可读正文呈现，保留具体原因，见[本批](../archive/handoffs/2026-10/2026-10-30-LIBRARY-SCAN-STATUS-PRESENTATION.md)。

连接详情中设置单独分组，已有媒体文件夹与添加同组；空态也保留添加入口。路径编辑说明只承诺已实现的操作，暖色图标/语义文字沿共用行，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-CONNECTION-DETAIL-GROUPS.md)。


已有连接准备页沿选择媒体文件夹标题与来源上下文；失败有重试/返回，两项固定动作普通字号紧凑并排、辅助字号上下排。多宿主返回统一“返回上一页”，不承诺特定页面；来源信息不画可点击箭头，见[本批](../archive/handoffs/2026-10/2026-10-30-EXISTING-CONNECTION-PREPARATION.md)。

添加媒体文件夹按已有连接/新增连接/其他协议分层；已有行说明选择文件夹，新WebDAV标HTTP/HTTPS，未开放协议用静态状态行、不画前进箭头。各端共用主次文字和暖色图标，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-SOURCE-ADD-CHOICES.md)。

连接管理只画有实际入口的分组；连接与媒体文件夹分层，同名目录显示来源与路径。入口说明必须对应真实目的地，旧来源不承诺可编辑连接；保留暖色图标，按钮行文字使用语义主色/次级说明。见[连接管理批](../archive/handoffs/2026-10/2026-10-30-SHARED-CONNECTION-INVENTORY.md)。

选目录应始终显示当前路径和读取范围；“无子目录”不能写成“没有视频”，不可选根目录时不能建议直接选择。读取失败与使用目录失败分开，处理中禁用父子页的退出和选择；选择任务先固定路径。沿共用状态/主题组件，见[文件夹选择批](../archive/handoffs/2026-10/2026-10-30-SHARED-FOLDER-PICKER-STATES.md)。

资料编辑保留可见字段标签；固定数量字段在宽屏并排，辅助字号上下排。错误放输入前并保留草稿，草稿变化清除旧错误；更新中显示独立进度并防重复提交/退出。原识别资料保留在下方，按钮明确本机作用范围。见[资料表单](../archive/handoffs/2026-10/2026-10-30-SHARED-LOCAL-CORRECTION-FORM.md)。

现有播放能力不足时提供就地、可读的原因；单文件在操作区后，多文件逐行说明，避免没有按钮也没有解释。说明不能伪装播放/重试按钮或承诺已实现格式支持，三端复用相同原因词汇和组件。见[说明批](../archive/handoffs/2026-10/2026-10-30-SHARED-PLAYBACK-LIMITATION-NOTICES.md)。

影片技术字段三端复用同一行/表面：标签与值分层，辅助字号上下排，长值完整换行，空白/未知数字不造占位。资料来源与目录保留真实来源语义，扩展名不假装已探测封装；没有有效字段时不画空文件折叠。见[字段批](../archive/handoffs/2026-10/2026-10-30-SHARED-FILE-INFORMATION.md)。

多文件影片的播放选择保持可见，分段与原盘内部文件说明分开；原始名称/已知格式容量/可用状态分层，三端共用文件行。技术资料留折叠，不把选择入口埋在技术信息中，不宣称主片/自动续播。见[多文件批](../archive/handoffs/2026-10/2026-10-30-SHARED-MULTI-FILE-SELECTION.md)。

同一终端按来源复用媒体组件：iOS季集用共用剧集行；TV季集沿Jellyfin横向16:9海报网格、相同密度与焦点边框，奇数末行不扩宽。简介按空白判断及宿主语义颜色，辅助字号完整阅读；文件数明确称视频文件，不冒充唯一集数。见[电视季网格批](../archive/handoffs/2026-10/2026-10-30-TV-SEASON-POSTER-GRID.md)与[剧集/简介批](../archive/handoffs/2026-10/2026-10-30-SHARED-EPISODE-ROWS-AND-SYNOPSIS.md)。

文件夹编辑按“当前文件夹／新路径／验证并保存”展示，库名与原路径保持可见语义；相同路径不触发重建。错误明确保留范围，修改草稿后清旧错误；三端共用表单和暖色操作，目录选择仍只读。实现与有限核对见[文件夹编辑批](../archive/handoffs/2026-10/2026-10-30-FOLDER-EDITOR-CONTEXT-AND-NOOP.md)。

演职资料未返回前应显示轻量读取提示；成功读取但未提供人物与读取失败须分开说明。已有资料继续展示，单张头像占位不冒充加载失败结论，也不补空人物卡。三端网络库的[读取状态实现](../archive/handoffs/2026-10/2026-10-30-MEDIA-DETAIL-READ-STATES.md)与实际来源验收边界分开记录。

人物横向区共用滚动容器和电视焦点表面。电视只读人物项也应能获得暖色细边框焦点，不为此新增空详情页或播放操作；保留来源宿主原导航ID和方向状态。手机/Pad不套电视焦点包装。当前[接线及未验交互](../archive/handoffs/2026-10/2026-10-29-SHARED-PEOPLE-SCROLLER-AND-TV-FOCUS.md)只含静态证据，实际横滑/遥控移动尚未通过。

人物资料使用共用人物卡与中性人物占位图，不以视频图标代替头像；辅助字号优先姓名、角色完整换行，空角色不补造。占位图不表示加载失败或永久缺失，不能据此声称实际头像读取已修复。当前尺寸、普通字号截断及离线核对边界见[人物卡批](../archive/handoffs/2026-10/2026-10-29-SHARED-CAST-CARDS-AND-OFFLINE-RETURN.md)。

影音头图区以内容决定实际高度，背景跟随铺满；辅助字号允许海报/文字上下排列和片名完整换行，不靠缩小字号压入固定框。普通海报标题预留相同行数保持对齐，辅助字号优先完整阅读；缺图不伪造资料。见[共用媒体自适应批](../archive/handoffs/2026-10/2026-10-29-ADAPTIVE-MEDIA-HERO-AND-POSTER-TITLES.md)，静态模拟器核对不等于真实图片/播放或完整交互验收。

隐私页按“数据保存范围／安全操作／数据管理”组织，静态范围说明三端共用，连接状态由各宿主提供。暖色图标、正文完整换行；证书信任重置先说明影响并确认，取消不执行原动作。具体[隐私批实现](../archive/handoffs/2026-10/2026-10-29-SHARED-PRIVACY-SUMMARY-AND-RESET-PROMPT.md)不代表真实删除或完整交互已验。

帮助专题的数据与正文应共用；只有遥控器/平台真实能力不同才增加专属说明。正文使用可读的primary颜色、完整换行和系统字号，标题与正文保持稳定层级。面向用户解释操作及资料来源边界，不把代码组件/内部实现写成使用步骤。[本批帮助实现与核对](../archive/handoffs/2026-10/2026-10-29-SHARED-HELP-TOPICS-AND-ARTICLE-POLISH.md)尚不包含完整导航或真实账户操作验收。

连接表单沿用同一主题背景、暖色操作图标和既有主按钮组件；添加与编辑共用字段与操作层级，主操作在前、辅助保存在后。普通字号保持标签/输入对齐，辅助功能字号改上下排，错误在顶部完整展示。密码显示按钮提供明确的显隐名称，并在开始提交及离页时恢复隐藏；不能借UI精修改变端口、路径或凭据保存语义。当前WebDAV实现与隔离验收范围见[本批记录](../archive/handoffs/2026-10/2026-10-29-WEBDAV-FORM-POLISH-AND-OFFLINE-PREVIEW.md)，其他协议/全部设置子页尚未据此验收。

## 卡片尺寸与密度：主页面和子页面共同规则

2026-10-26用户确认：按内容性质与数量是否固定决定布局，主题不改变这一规则。

- CPU/内存/硬盘等固定三项指标等分三列；固定功能组使用稳定等宽、等高网格，不能因某项名称短就单独拉大。
- 用户最后修订（2026-10-26）：TV Docker 服务卡片使用固定双列，启动台与设备服务子页复用；奇数最后一张靠左，保持相同宽高，不扩成整行、不补空卡。管理显示沿用双列与暖色焦点。其余数量不固定的事项、目录等管理条目按阅读目的采用统一紧凑行高；不要机械以数量是否固定决定所有场景。
- 双列服务卡片各自保留轻微主题底色和细边框，焦点用暖色加粗边框；分组标题可折叠/展开，折叠不写服务隐藏偏好。具体服务图标由共享54条映射决定，手机/Pad/TV不可各自用分类图标替代全部服务图标。
- 固定入口可按可读性分为资源/维护/设置，主页面与跳转页复用组件。长文本信息表、表单和媒体海报按各自阅读/浏览目的布局，不机械套用服务卡片规则。
- 横向媒体书架按实际内容区计算完整卡片数。手机竖屏默认完整两张；大窗口展示完整多张，不用固定宽度制造半张首屏。
- 所有原生信息/功能卡片使用宿主语义表面；流光主题不可夹杂不透明系统黑/白小卡片。图片画布、播放器画面、内嵌网页与主题缩略预览保留各自语义背景。
- TV焦点在服务行内显示，不通过大幅放大或额外外层卡片改变内容对齐；主次操作保持视觉层级，危险连接操作先确认。
- 数量固定并不表示所有平台强行同列数；手机/分屏优先保证可读与触控，电视以固定列数铺满可用内容区。

本次实际实现与回归边界归[跨端卡片与WebDAV批](../archive/handoffs/2026-10/2026-10-26-CROSS-PLATFORM-CARD-RULES-WEBDAV.md)。

2026-10-26最新补充：存储与媒体应作为NAS概览之外的独立卡片，三种移动布局沿用nastartCard宿主表面；流光深色使用渐变画布/透明表面，不再嵌套不透明黑色小卡片。业务矢量图标明确使用host accent，正文保持语义文字颜色。13流光深色和TV三窗有限实图已看，18安装与Pad连接仍阻塞。 见[最新批](../archive/handoffs/2026-10/2026-10-26-INDEPENDENT-STORAGE-CARD-AND-ACCENT.md)。

2026-10-26媒体首页进一步精简：浏览文件、已连接媒体库、添加文件夹，连接管理为次级入口；TV统一纵向宽行、紧凑页头、宿主22圆角/表面/强调色，表单/选目录/纠错沿用同一组件。最终普通包TV clean/light、command/dark、glass/system与遥控返回有限通过；手机最终包验证、iPad安装后连接阻塞和未验组合见[本批](../archive/handoffs/2026-10/2026-10-26-UNIFIED-MEDIA-HOME-AND-TV-UI.md)。

2026-10-26服务区延用NetworkMediaAppearance的实际主题/宽行/列表节样式，主名称、次名称、连接状态按共同层级展示，TV保留遥控器焦点和整行点击。真实普通包三端回归范围与失败见[服务批](../archive/handoffs/2026-10/2026-10-26-MEDIA-SERVICE-DISCOVERY-AND-ENTRY.md)；当前主题实图不代表全部深浅色/大字组合通过。

2026-10-26：NetworkMediaAppearance由主工程注入实际主题背景、行表面、强调色与command样式，避免包内复制主工程颜色；TV为plain整行按钮/明确图文间距。实图有限覆盖手机glass/Pad clean/TV glass，深色/大字/全部主题仍待验，见[本批](../archive/handoffs/2026-10/2026-10-26-NAS-SESSION-SOURCE-HUB-NATIVE.md)。

2026-10-26来源页补充：[统一来源方案](../architecture/UNIFIED_SOURCE_DISCOVERY_AND_ACCESS.md)要求复用实际AppTheme/AppearanceStore的表面、字体、22圆角、间距及平台焦点；不得把独立List/Form继承强调色当完成统一。交互预览为演示数据，不是已安装界面；Native主题接线/三端实图后单独验收。

Version: 0.3
Status: Draft
Last updated: 2026-07-30

### 后续视觉细化方向（2026-10-26用户补充）

设置与列表可参考Shadowrocket的清晰层级、统一间距、分隔和轻量状态标识，只观察既有App，不触动代理/VPN/账号。影音展示需要统一海报比例与留白、标题/元数据层级、演员与简介的排版节奏，形成能识别为Nastart的视觉语言；三端沿用同一内容顺序与组件语义，触控/遥控及屏幕宽度再适配。该方向持续细化；已接入的共用头图、人物卡与排版以文首批次记录为准，尚不代表整体视觉或真实头像验收，不覆盖真实播放、来源连接、客户端只读刮削和海报来源的优先级。

## 1. Purpose

This document defines the first visual direction for Nastart's app shell,
typography, colors, icons, cards, and interaction patterns.

The goal is to make Nastart feel Apple-native, calm, precise, and premium
without becoming visually heavy or hard to implement.

Launchpad themes may change the dashboard expression, but the app shell should
remain stable and recognizable.

The Launchpad is Nastart's primary visual showcase. It can carry more crafted
layout, material, and card personality than fixed utility pages, but it must
still share the same typography, icon language, color semantics, spacing rhythm,
and interaction patterns as the rest of the app.

## 2. Product Feeling

Nastart should feel like:

- a native Apple utility
- a refined NAS home base
- a personal infrastructure launchpad
- technical enough to be trusted
- simple enough to be used every day

Nastart should not feel like:

- a web admin panel squeezed into a phone
- a terminal-first server tool
- a media app clone
- a colorful dashboard skin collection
- a stitched bundle of unrelated utilities

Core visual principle:

```text
Simple, useful, designed; never plain, noisy, or over-explained.
```

Chinese product motto:

```text
简约而不简单
```

Meaning:

- top-level pages should feel clean, calm, and immediately understandable
- deeper pages can hold richer configuration and technical detail
- the app should feel capable without looking complicated
- richness should be discovered progressively, not dumped on first sight

Nastart should pass this product-level UI test:

```text
One glance attracts.
Two glances explain.
Three glances invite action.
```

The UI should communicate through hierarchy, spacing, symbols, status color,
cards, and interaction states before relying on explanatory text.

This principle also applies to implementation and app footprint. Nastart should
cover useful NAS workflows without becoming bloated in installed size or runtime
complexity. Prefer compact native SwiftUI views, SF Symbols, vector assets, and
shared components before adding raster-heavy visuals, large dependencies, or
duplicated custom UI.

Every feature should pass this product-and-engineering test:

```text
Does it add clear user value without making the app feel heavier, harder to use,
or unnecessarily larger to install?
```

If the answer is unclear, simplify the UI first, defer nonessential assets, and
place advanced capability one level deeper.

Top-level pages should follow this rule:

```text
Show the purpose, show the state, show the next action.
Hide everything else one level deeper.
```

For Launchpad specifically, "simple" must not become "ordinary". A plain grid of
service icons is too weak for Nastart's core selling point. The Launchpad should
feel designed through:

- an intentional top status area, not a generic header
- service grouping that feels curated rather than dumped
- cards with clear hierarchy between identity, state, and next action
- richer media cards that still belong to the same card family
- progressive detail for Agent/Plus without fragmenting the layout
- empty space used for calmness, not because the page lacks content strategy

The design target is:

```text
Launchpad should look simple at first glance, useful at second glance, and
crafted at third glance.
```

## 3. App Shell Style

The app shell covers:

- onboarding
- tabs and sidebar
- device center
- reminder center
- settings
- forms
- warning sheets
- purchase screens
- support and privacy pages

The shell should be consistent across themes:

- native navigation bars
- system tab/sidebar patterns
- white or system background as the default surface
- limited accent colors
- simple list and card layouts
- SF Symbols as the primary icon language
- no decorative background illustrations in core utility pages

Launchpad themes can vary card style and information density, but they should
not change core typography, settings layout, purchase UI, or security flows.

The fixed pages should be deliberately quieter than the Launchpad:

- Onboarding, Devices, Tasks, Mine, Settings, and purchase pages should
  look Apple-native and restrained.
- Launchpad should be the most expressive surface, but it should not introduce
  a separate visual system.
- Shared tokens should make the Launchpad feel like a premium expression of
  the same app, not a separate skin.

The recommended baseline should be close to WeChat-style restraint:

- white background first
- black or near-black text first
- black monochrome vector icons for most navigation and utility actions
- color only for selected state, warning, success, danger, Plus, or primary
  action
- no ornamental gradients, noisy backgrounds, or over-designed widgets in the
  app shell

## 4. Typography

Use Apple's system typefaces through SwiftUI dynamic type styles.

Recommended mapping:

| Use | SwiftUI Style | Weight | Notes |
|---|---|---|---|
| Large page title | `.largeTitle` or `.title` | Semibold/Bold | Use sparingly; not every screen needs a large title |
| Navigation title | `.headline` or native nav title | Semibold | Let system navigation do most work |
| Section title | `.headline` | Semibold | Short, direct labels |
| Card title | `.headline` or `.subheadline` | Semibold | Avoid truncating service names too early |
| Body text | `.body` or `.callout` | Regular | Keep paragraphs short |
| Metadata | `.caption` or `.footnote` | Regular/Medium | Use enough contrast |
| Status label | `.caption` | Medium | Pair with status dot/icon |
| Button text | `.body` or `.callout` | Semibold | Clear action verbs |

Rules:

- Prefer system Dynamic Type instead of fixed point sizes.
- Avoid long explanatory paragraphs in primary flows.
- Use sentence-style labels, not marketing slogans.
- Use metadata only where it helps scanning.
- Do not rely on light gray text for important content.
- Prefer short labels and structured choices over full-sentence explanations.
- Use one-line helper text only when a technical concept would otherwise be
  unclear.

### 4.1 Copy Density

Every primary screen should pass this scan test:

- The user can identify the screen purpose in one glance.
- The primary action is visible without reading a paragraph.
- No card requires more than one short line of explanation.
- Technical terms are shown as labels, chips, or status values where possible.

Avoid:

- multi-line teaching text on dashboards
- long feature descriptions inside cards
- repeated "why this matters" copy
- putting setup instructions on everyday-use screens

## 5. Color System

Nastart should use a calm neutral base with a warm accent.

### 5.1 Core Roles

| Role | Direction | Use |
|---|---|---|
| Background | White / system background | Main app pages |
| Grouped background | Very light system grouped background | Long lists, grouped settings, secondary surfaces |
| Surface | White or system secondary background | Cards, panels, form groups |
| Primary text | Near black in light mode, near white in dark mode | Main content |
| Secondary text | Medium gray with sufficient contrast | Metadata only |
| Separator | System separator | Dividers and grouped lists |
| Accent | Warm amber/gold-orange | Primary actions, selected state, Plus |
| Success | System green | Online and healthy |
| Warning | System orange/amber | Certificate/domain/backup warnings |
| Error | System red | Offline, expired, dangerous |
| Info | System blue | Links, neutral guidance, learn more |

### 5.2 Accent Guidance

The accent should feel warm and premium, closer to App Store service buttons
than dark bronze.

Recommended starting accents:

- Light mode accent: `#F4A340`
- Pressed accent: `#E98D26`
- Soft accent background: `#FFF3E2`
- Dark mode accent: `#FFB35A`

Rules:

- Accent is for primary action and selected state, not general decoration.
- Status colors should remain semantic and separate from brand accent.
- Avoid using the warm accent for every icon.
- Default icons should be black/near-black, especially in tabs, lists, toolbars,
  and settings.
- Do not make the whole app brown, orange, or sepia.
- If a card uses a theme-specific tint, keep text and controls legible first.

## 6. Icon System

Primary icon source:

- SF Symbols.

Use custom icons only when:

- SF Symbols cannot represent the service clearly.
- The icon is a generated service/app icon.
- A known service brand icon is legally safe and locally bundled.

Icon rules:

- App shell icons should use consistent stroke weight and optical size.
- Use monochrome icons for tabs, lists, settings, and toolbar actions.
- Use filled or multicolor icons only for service logos/cards where they add
  recognition.
- Do not mix several icon packs in one screen.
- Do not use complex vector illustrations for basic navigation.
- Use color on icons only when it communicates state or selected action.

Recommended tab symbols:

| Tab | SF Symbol Direction |
|---|---|
| Launchpad | `square.grid.2x2` / `rectangle.grid.2x2` |
| Devices | `externaldrive` / `server.rack` where available |
| Tasks | `bell.badge` / `calendar.badge.clock` |
| Mine | `person.crop.circle` plus settings rows, or `gearshape` if account is not central |

## 7. Card System

Nastart should use cards for meaningful repeated objects:

- service cards
- device cards
- reminder cards
- certificate/domain cards
- media resource cards

Do not wrap page sections in decorative cards unless they represent grouped
interactive content.

Cards should use design language instead of text-heavy explanation:

- icon or service logo for identity
- title for object name
- small status dot or badge for state
- one metadata line for context
- one primary tap behavior
- secondary actions behind menu or long press

### 7.1 Service Card Anatomy

Required elements:

- service icon
- service name
- short category or service type
- status indicator
- primary action through tap

Optional elements:

- endpoint label: Local, Remote, VPN
- latency or last checked time
- certificate warning
- container state
- secondary action menu

Avoid:

- long descriptions
- more than two visible metrics on compact cards
- multiple competing action buttons
- dense technical names unless the user expanded details
- decorative badges that do not change user behavior
- explaining what a common icon already communicates

### 7.4 Progressive Detail

Nastart should use three layers of information:

| Layer | Where | Content |
|---|---|---|
| Glance | Launchpad card, device card, reminder card | Name, icon, state, one hint |
| Decision | Detail page | Endpoint, warning reason, related device/container, action choices |
| Explanation | Sheet, help page, diagnostics | Technical cause, next steps, logs, advanced settings |

The first layer must stay quiet. The third layer can be technical, but only when
the user has intentionally opened it.

## 8. Launchpad Versus Fixed Pages

Nastart needs a clear visual hierarchy between its showcase surface and its
everyday utility pages.

### 8.1 Fixed Pages

Fixed pages should feel clear, native, and dependable:

- mostly white or system grouped backgrounds
- simple navigation titles
- grouped lists and plain cards
- black SF Symbols-style icons
- short labels and status values
- minimal decoration
- no custom theme backgrounds

These pages earn trust through restraint and consistency.

### 8.2 Launchpad

Launchpad should feel more crafted:

- stronger card composition
- richer service identity
- more considered section rhythm
- optional material/depth per theme
- clear online, warning, and unavailable states
- polished empty and first-success states
- visually satisfying layouts at 6, 12, and 24 services

The Launchpad may be beautiful, but it must remain operational. If a visual
choice makes service status, endpoint choice, warning state, or tap behavior
less clear, it should be removed.

### 8.3 Shared Design Tokens

Use shared tokens to prevent visual fragmentation:

- text styles
- foreground and secondary text colors
- accent and semantic status colors
- icon stroke weight
- radius scale
- spacing scale
- separator color
- card padding
- sheet and menu behavior

Launchpad themes should be variations on these tokens, not separate one-off
styles.

### 7.2 Device Card Anatomy

Required elements:

- device name
- provider type, such as Synology DSM
- connection status
- short resource summary

Optional elements:

- DSM version
- local/remote endpoint hint
- Agent connected state
- warning count

### 7.3 Reminder Card Anatomy

Required elements:

- reminder name
- type
- due date
- urgency state

Optional elements:

- related service/device/domain
- renew URL
- notification schedule

## 8. Layout Principles

### 8.1 iPhone

- Use tab navigation.
- Use one primary task per screen.
- Keep forms grouped and short.
- Put destructive or advanced operations behind detail screens.
- Use context menus and bottom sheets for secondary card actions.
- Keep Launchpad cards thumb-friendly.

### 8.2 iPad

- Use sidebar or split view.
- Avoid simply stretching iPhone screens.
- Show Launchpad grid and device/status panels side by side where useful.
- Use inspector/detail panes for service and device details.

### 8.3 Future macOS

- Keep components resizable.
- Support pointer hover, keyboard shortcuts, and denser layouts later.
- Do not hard-code iPhone-only assumptions into core Launchpad components.

### 8.4 Future Apple TV

- Treat Apple TV as a future status-wall and media-handoff surface.
- Cards must support focus state and large viewing distance.
- Avoid tiny metadata on tvOS layouts.

## 9. Buttons And Controls

Primary button:

- warm accent background
- white or high-contrast text
- semibold label
- used once per screen when possible

Secondary button:

- system filled or grouped background
- primary text color
- used for cancel, edit, preview, or alternate path

Destructive button:

- red text or red background only when the action is clearly destructive

Selection chips:

- use for categories, filters, endpoints, reminder types, and themes
- selected state can use soft accent background and accent text

Menus:

- use for card secondary actions
- avoid showing every external app on the primary screen

Sheets:

- use for endpoint warnings, certificate trust, open-in choice, and Agent setup
  guidance

## 9.1 Functional Discoverability

Users should understand what Nastart can do without a long introduction.

Use these patterns:

- Tab names for major jobs.
- Section headers for object groups.
- Cards for services, devices, and reminders.
- Status dots and chips for state.
- Context menus for secondary actions.
- Empty states with one action.
- Settings rows for preferences.

Avoid these patterns:

- large onboarding slides for features users have not tried
- dashboard banners explaining every module
- repeated callouts competing with the service cards
- icon-only controls without native labels, tooltips, or accessible names

## 10. Motion And Feedback

Motion should be restrained:

- subtle card press scale or highlight
- smooth sheet presentation
- refresh progress where status checks run
- small status transition animations

Avoid:

- decorative looping animations
- busy dashboard effects
- motion that makes service state harder to read

## 11. Empty, Loading, And Error States

Text should be short and action-oriented.

Examples:

- No services yet. Connect Synology DSM to generate your launchpad.
- Certificate expires soon.
- Local address is unreachable. Try remote address?
- Agent is offline.

Rules:

- Avoid long teaching paragraphs.
- Provide one primary next action.
- Offer "Learn more" only when the issue is genuinely technical.

## 12. Plus And Paywall Style

当前购买未开放时，Plus页使用共用的权益概览和功能预览，不把示例价格包装成可选择的购买方案。普通字号功能卡片同排等高，辅助字号切单列，不缩小或截断正文；状态和主题由宿主传入。电视尚无会员账号与iCloud接入时如实标示，不能因共用UI而宣称可用。见[本批实现与边界](../archive/handoffs/2026-10/2026-10-29-SHARED-PLUS-OVERVIEW-AND-ACCESSIBLE-CARDS.md)。

Plus should feel like a natural unlock, not a hard wall.

Recommended:

- show value in context
- keep Free useful
- label Plus-only features quietly
- annual plan as recommended
- lifetime as a NAS-user-friendly option if pricing allows

Plus visual style:

- warm accent
- simple comparison rows
- no aggressive countdowns
- no overloaded pricing page

## 13. Design Token Candidates

These are starting points, not final values:

| Token | Value Direction |
|---|---|
| Card corner radius | 16-22 on iOS, slightly less on dense layouts |
| Card padding | 12-18 |
| Section spacing | 20-28 |
| Compact grid gap | 10-14 |
| Wide grid gap | 14-20 |
| Icon size compact | 24-32 |
| Service icon size | 36-48 |
| Status dot | 7-9 |

The token system should be implemented once and reused across themes.

## 14. Quality Checklist

Before a UI direction becomes implementation-ready:

- Screens work in light and dark mode.
- Primary text has strong contrast.
- Icons look like one family.
- Every screen has one obvious primary action.
- Long service names and IP addresses do not break layout.
- The Launchpad looks good with demo, real, sparse, and dense data.
- iPad layouts are intentionally designed.
- The design still feels usable without decorative backgrounds.

## 15. Screenshot Reference Notes

These notes come from user-provided screenshots of DS One and MyServers. They
are design observations, not instructions to copy either product.

### 15.1 DS One Lessons

Useful patterns:

- The home page uses a light background, rounded cards, clear NAS status cards,
  and a simple icon grid. This makes technical NAS data feel approachable.
- The bottom tab bar uses large, readable icons with direct labels.
- The media page shows that immersive image-led surfaces can work well for
  media, but this should stay limited to media contexts.
- The settings page uses grouped rows, monochrome outline icons, and short row
  labels. This is a strong reference for Nastart's Mine/Settings pages.
- The card spacing is generous enough that the app feels calm rather than like
  a dense admin panel.

Risks to avoid:

- Do not let Nastart's Launchpad become a media-app home page.
- Do not use many colored square icons unless the icon style is tightly
  controlled.
- Do not add top-level Video, Audio, and Album tabs in Nastart v1; those belong
  inside media service cards and handoff flows.

### 15.2 MyServers Lessons

Useful patterns:

- The tab split between dashboard, board, servers, terminal, and settings shows
  a clear operations-oriented mental model.
- The board page proves that status widgets can be powerful when the user wants
  monitoring density.
- The settings page uses large title, grouped sections, toggles, and clear
  system-style rows.

Risks to avoid:

- Nastart should not expose terminal as a first-level tab in v1.
- Monitoring cards should not overwhelm the Launchpad.
- The app should avoid showing too many gauges, counters, and technical labels
  on the first screen.
- Plus/paywall cards should be cleaner and more restrained, with less visual
  weight unless the user has intentionally opened Plus.

### 15.3 Nastart Adaptation

Recommended adaptation:

- Use DS One's softness and approachable card spacing as the baseline.
- Use MyServers' dashboard discipline only for the `Command Center` Launchpad
  theme and Device Detail pages.
- Keep Nastart's main app shell closer to white-background, black-text,
  monochrome-icon utility design.
- Let color appear mainly through status, selected tab, primary actions, service
  logos, and theme-specific Launchpad cards.
- Keep media imagery inside media surfaces; do not make the whole app poster-led
  or image-heavy.
