# 三端代码一致性审查与收敛边界

2026-10-31 [共用WebDAV字段语义](../archive/handoffs/2026-10/2026-10-31-SHARED-WEBDAV-FIELD-ACCESSIBILITY.md)：WebDAV六字段语义在共用正式表单补齐，添加/编辑三端不另建副本；布局和回调保持。 445输入/1既有文件/其余444同，六配置编译过，移动30核签候选未装；TV正常签名仍阻塞、只无签名编译，0新模拟器/真机/NAS/播放，114格无新P。

2026-10-31 [原生事件与返回记忆](../archive/handoffs/2026-10/2026-10-31-NATIVE-FOCUS-EVENT-ORDER-AND-MEMORY.md)：共用网络FocusScope/Session修事件顺序；诊断仅离线显式开且Release无writer，JF专属View状态和播放链路不变。 445输入/5既有+1新，41单元/6唯一UI+fresh2重复例过，失败留存；6实例清，移动核签候选未装；TV无签名编译过、正常签名阻塞，0真机/NAS/播放，114格无新P。

2026-10-31 [弹层返回与焦点反例](../archive/handoffs/2026-10/2026-10-31-DETAIL-PRESENTATION-RETURN-AND-FOCUS-REGRESSION.md)：本批仅保留Debug测试；FocusMap/Session/Scope及正式三端代码未变，稳定ForEach实验无改善已回退。 444输入/3个Debug测试文件，正常构建核签过但非UI通过包，2实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [动态详情与长列表](../archive/handoffs/2026-10/2026-10-31-DYNAMIC-DETAIL-FOCUS-AND-LONG-ROWS.md)：网络正式与fixture共用FocusSession/Scope，Jellyfin共用纯Map但其View状态仍保留；移动端不接管遥控。 39单元/4最终唯一UI过，前4轮失败保留；444输入、双端各配置构建/核签候选过未装，5任务实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [网络详情文件焦点](../archive/handoffs/2026-10/2026-10-31-NETWORK-DETAIL-FILE-FOCUS.md)：Jellyfin与TV网络详情实际共用MediaDetailFocusMap；网络正式与离线场景再共用Scope/Target/人物行，移动nil上下文保触摸交互。 442输入/7既有+1新，29单元/6唯一UI及双端各配置构建/核签候选过未装；3实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [TV顶部操作焦点](../archive/handoffs/2026-10/2026-10-31-TV-DETAIL-ACTION-FOCUS.md)：共用MediaDetailFocusMap增加有效默认动作/移除恢复和动作左右序列，TV正式与隔离场景复用；网络fileSelection需先建区域，尚未接线。 7既有源/测试、441输入，24单元/4UI（5新单元/1新UI）及双端各配置构建/核签候选过未装；1实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [TV详情重试焦点](../archive/handoffs/2026-10/2026-10-31-TV-DETAIL-RETRY-FOCUS.md)：新MediaDetailFocusMap在共用包，TVDetailView与隔离fixture实际复用；TVDetailRetryButton同源样式，客户端/播放任务不改。 5既有+2新源/测试、441输入，19单元/3唯一UI用例、双端各配置构建/核签候选过未装；2实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [演职状态一致性](../archive/handoffs/2026-10/2026-10-31-CREDITS-STATE-PARITY.md)：原MediaCreditsAvailability/MediaDetailCreditsNotice公开给两App，算法/布局同，宿主传Text；Jellyfin元数据phase直接跟原detail请求，无独立people网络链。 8既有源/资源、439输入，12既有测试/双端各配置构建/核签候选过未装；13静态窗/3实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [搜索归属与详情提示](../archive/handoffs/2026-10/2026-10-31-SEARCH-REQUEST-OWNERSHIP.md)：MediaDetailReadState.swift现导出MediaReadState，旧详情别名同算法；移动搜索实际复用，未创建第二套服务或播放器。 6既有源/测试、439输入，9既有+3新回归/双端各配置构建/核签候选过未装；9静态窗/3实例清，0真机/NAS/播放，114格无新P。

2026-10-31 [缓存内容展示](../archive/handoffs/2026-10/2026-10-31-CACHED-CONTENT-PRESENTATION.md)：新增无数据/任务的MediaLibraryContent展示容器，复用既有LoadFailure/Notice/EmptyState，移动两消费者真实接线，保懒构建与原内容回调。 6既有源/资源、439输入，4参数测试/双模拟器及签名Debug/核签候选过未装；14静态窗/3实例清，Release未重跑，0真机/NAS/播放，114格无新P。

2026-10-30 [共用首页失败提示](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-LOAD-PRESENTATION.md)：新增LoadFailure只是Notice/EmptyState的展示选择，两App首页实际消费；数据/请求/缓存/恢复仍归宿主，无新播放链路。 7既有源/资源、439输入，4参数测试/双端模拟器与签名Debug/核签候选过未装；9静态窗/3实例清，Release未重跑，0真机/NAS/播放，114格无新P。

2026-10-30 [标题与滚动核对](../archive/handoffs/2026-10/2026-10-30-WALL-NAVIGATION-TITLE.md)：正式墙与离线包装标题配置都改互斥平台分支；只动修饰符，无请求/播放器/回调变化。 2既有源/439输入，双端模拟器及签名Debug/核签候选过未装；Release/参数测试未重跑，4自建实例清，0真机/NAS/播放。

2026-10-30 [共用加载失败提示](../archive/handoffs/2026-10/2026-10-30-SHARED-MEDIA-LOAD-FAILURE.md)：MediaLibraryNotice由网络Notice包装和TV retained-error真实消费；EmptyState承载TV首次失败/既有移动媒体集失败，source状态/请求不进展示组件。 5既有源/439输入，4参数测试/双端各配置构建/核签候选过未装；空间恢复后同包补验，本批15静态窗：12过/3未过（TV5/手机3/Pad4），4实例清；首次预算阻塞与失败均保留，0真机/NAS/播放，114格无新P。

2026-10-30 [共用媒体空态](../archive/handoffs/2026-10/2026-10-30-SHARED-MEDIA-EMPTY-PRESENTATION.md)：MediaLibraryEmptyState接受Text与泛型Actions，移动JF包装/Collection失败、TV两处、网络包装实际消费；标题/说明/字体/暖色图标/间距共用，不复制状态机。 6既有源/439输入，4既有参数测试/双端各配置构建/核签候选过未装；初15窗预算阻塞留档，空间恢复后TV5静态窗通过/1实例清、手机Pad10窗仍待，0真机/NAS/播放，114格无新P。

2026-10-30 [分类与空态](../archive/handoffs/2026-10/2026-10-30-WALL-CATEGORY-AND-EMPTY-SELECTION.md)：MediaWallSelection同时供正式墙与Debug合成投影；分类/网格同一快照，NetworkLibraryWallEmptyState三端共用，clearSearch供空态/TV工具栏复用；JF空态仍分开，下一收敛。 439输入、9新+18既有共27测试及双端各配置构建/核签候选过未装；三端12窗磁盘预算阻塞，0实例/图/真机/NAS/播放，114格无新P。

2026-10-30 [首页/墙读取恢复](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-WALL-READ-RECOVERY.md)：WallStatus实际复用LocalReadContent→NoticeContent/ReadPageActions；首页默认ID保留、墙独立prefix。墙读取任务与原旧索引扫描任务分开。 437输入、7既有测试/双端各配置构建/核签候选过未装；三端24静态窗均预算阻塞、0实例，尚无本批新图，实际交互未验，0真机/NAS/播放，114格无新P。

2026-10-30 [首页本机读取恢复](../archive/handoffs/2026-10/2026-10-30-HOME-LOCAL-READ-RECOVERY.md)：NetworkLibraryLocalReadContent接正式首页StatusSections；NetworkReadPageActions返回回调可选，两个旧消费者保原行为，NoticeContent默认标识保持、本机错误标识独立。 437输入、7既有测试/双端各配置构建/核签候选过未装；TV7静态窗、1实例清，移动14窗磁盘预算阻塞，0真机/NAS/播放，114格无新P。

2026-10-30 [本机读取状态](../archive/handoffs/2026-10/2026-10-30-LOCAL-LIBRARY-READ-STATES.md)：LibraryLocalReadState负责读取请求归属；NetworkLibraryAccessStatePage负责库缺失展示，NetworkReadPageActions由新状态页/原连接页实际复用，displayError在首页/墙汇总操作与读取错误。 7测试/双端各配置构建及核签候选过、未装；TV6静态窗，2实例清，移动12窗磁盘预算未达，0真机/NAS/播放，114格无新P。

2026-10-30 [首页/墙共用状态](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-AND-WALL-STATUS.md)：ActivityContent/NoticeContent实际接首页Section和海报墙主题卡片；TV字号不再依赖父容器。墙菜单先核当前库再核canCancel能力，内联取消ID独立，模型/网格/搜索/导航/焦点回调/播放保持。4既有源、4参数测试/串行双端各配置构建过，核签候选未装；仅TV6静态窗，1实例清，移动12窗因磁盘预算未验，实际菜单/取消/返回仍待。0真机/NAS/播放，114格无新P。

2026-10-30 [首页整理状态](../archive/handoffs/2026-10/2026-10-30-LIBRARY-SCAN-STATUS-PRESENTATION.md)：正式三端首页共用进度/更新/操作提示，置于内容前部，文件数含义明确；只读canCancelScan控制真实扫描入口，所有model方法/导航/源/存储/播放保持，savedMedia同body一次。3既有源、4参数测试/双端各配置构建过，核签候选未装；手机5+TV3静态窗过、2实例清，Pad磁盘预算阻塞，实际取消/返回未验。海报墙仍旧状态实现、下一需接共享内容；0真机/NAS/播放，114格无新P。

2026-10-30 [连接详情分组](../archive/handoffs/2026-10/2026-10-30-SHARED-CONNECTION-DETAIL-GROUPS.md)：正式三端共用设置与媒体文件夹分区，添加与关联目录同组、空态保留添加，路径修改说明准确；关联列表同body一次过滤。原sheet/回调/凭据/目录/播放保持。3既有源、4参数测试及双端各配置构建过，核签候选未装；最终三端9静态窗核过（8自动+1人工OCR复核）、6自建实例清；初Debug大字标识重叠失败保留排除，改背景重采；离线包无损整理释放1.44GiB后补完移动端。真实交互/映射未验，0真机/NAS/播放，114格无新P。


2026-10-30 [已有连接状态](../archive/handoffs/2026-10/2026-10-30-EXISTING-CONNECTION-PREPARATION.md)：正式三端接共用准备/错误/重试/返回页；返回文案覆盖多宿主，本地同步准备按取消/attempt检查后提交路径与source，原凭据/目录回调/播放保持。3既有源、4参数测试及双端各配置构建过，候选核签未装；仅TV最终3窗（2自动+1人工解决OCR漏字），初3排除/超时保留，2自建实例清。手机/Pad受磁盘预算阻塞，真实交互未验；0真机/NAS/播放，114格无新P。

2026-10-30 [添加媒体文件夹](../archive/handoffs/2026-10/2026-10-30-SHARED-SOURCE-ADD-CHOICES.md)：正式三端共用已有/新增连接和协议状态；已有WebDAV复用连接管理行，新增明确HTTP/HTTPS。SMB/FTP静态“暂未开放”且TV无前进箭头；来源同body取一次，连接专用模式不取。原选择/凭据/事务/播放保持。3既有源、4参数测试、9最终静态窗与双端各配置构建过，核签候选未装；首Debug提示重叠失败排除，5自建实例清，0真机/NAS/播放，114格无新P。实际交互未验。

2026-10-30 [连接管理分组](../archive/handoffs/2026-10/2026-10-30-SHARED-CONNECTION-INVENTORY.md)：正式三端共用有条件的存储/文件夹/服务分组，空服务不占位，旧来源说明对应真实目的地；全局/连接详情共用来源+路径行和语义文字色，NAS名需匹配账号/地址。来源列表同body只取一次，原事务/播放保持。3既有源、4参数测试、9最终静态窗与双端各配置构建过；初版排除，9自建实例清，核签候选未装，0真机/NAS/播放，114格无新P。真实映射/交互未验。

2026-10-30 [文件夹选择状态](../archive/handoffs/2026-10/2026-10-30-SHARED-FOLDER-PICKER-STATES.md)：正式三端共用路径/子目录/读错/选错/加载及忙碌展示，空根不可选文案修正；冻结选择路径，同步阻父页取消/名称修改和TV返回，过期读取成功/失败受Request与取消检查。3既有源、14既有测试、13静态窗及双端各配置构建过，30/27核签候选未装；实际目录/交互未验，0真机/NAS/播放，114格无新P。下一连接管理分组/缺服务空态。

2026-10-30 [本机资料表单](../archive/handoffs/2026-10/2026-10-30-SHARED-LOCAL-CORRECTION-FORM.md)：正式三端与离线场景共用字段/本机操作/保留原资料，宽屏固定字段并排、大字上下排；错误独立、改草稿清旧错误，更新中禁用重复动作/返回。原校验/存储事务与播放保持。3既有源、4参数+10既有纠错测试、12静态窗及双端各配置构建过；候选未装，0真机/NAS/播放，114格无新P，真实交互/持久化未验。下一步文件夹选择页。

2026-10-30 [已有播放限制说明](../archive/handoffs/2026-10/2026-10-30-SHARED-PLAYBACK-LIMITATION-NOTICES.md)：网络详情单文件和多文件行共用ISO/来源/格式说明，先看原canPlay，仅加UI原因；原按钮/选择/路线及JF/设备文件保持。4既有源、4参数测试、9静态窗及双端各配置构建过，候选未装；0真机/NAS/播放，114格无新P。真实来源能力与播放仍待，下一步本机资料修改表单。

2026-10-30 [共用文件字段](../archive/handoffs/2026-10/2026-10-30-SHARED-FILE-INFORMATION.md)：移动JF/网络与TV JF接共用字段/格式化；大字上下排、空值不占位，网络扩展名/目录/来源分层，TV只读可选字段和新折叠焦点逻辑接入。7既有源、4离线参数测试、只读模型3例/方向函数9分支、6静态窗与双端各配置构建过；候选未装，0真机/NAS/播放，114格无新P。真实遥控/展开/字段读取及单文件不可播放说明仍待。

2026-10-30 [多文件选择区](../archive/handoffs/2026-10/2026-10-30-SHARED-MULTI-FILE-SELECTION.md)：网络详情三端共用可见分段/原盘选择区和文件行，原文件名/已知格式容量/不可播放说明分层，技术资料继续折叠；原选择动作/能力/归并/播放保持。4既有源、22既有测试、6静态窗及双端各配置构建过，核签候选未装；0真机/NAS/播放，114格无新P，真实点击/长列表及主片/续播仍未验。

2026-10-30 [电视季网格](../archive/handoffs/2026-10/2026-10-30-TV-SEASON-POSTER-GRID.md)：网络季页改用TV Jellyfin的共用网格/16:9卡片/焦点边框及同一密度设置，移动仍共用剧集行；2既有源、24既有测试、5静态窗和双端各配置构建通过，候选未装。0真机/NAS/播放，方向/真实图片与多文件选择仍未验，114格无新P。

2026-10-30 [剧集行/简介共用](../archive/handoffs/2026-10/2026-10-30-SHARED-EPISODE-ROWS-AND-SYNOPSIS.md)：移动JF与三端网络季页接MediaEpisodeRow；空白简介收起、iOS大字完整显示/不留无效展开，TV正文跟宿主颜色。文件数量明确“视频文件”，不算唯一集数或多版本归并。7既有源/435输入同、22既有测试及双模拟器Debug/签名Debug/无签名Release过；10有效静态窗，首手机同名图覆盖排除并仅补1窗，4自建实例清。30/27核签候选未装，0NAS/真机/播放，114格无新P。TV JF剧集仍网格/真实图片与交互未验。

2026-10-30 [文件夹编辑与等价路径](../archive/handoffs/2026-10/2026-10-30-FOLDER-EDITOR-CONTEXT-AND-NOOP.md)：三端实际共用当前库/原路径/新路径/错误/忙碌/操作表单；等价路径在凭据/扫描前返回，未改路径不重建。5既有源/435输入同，22测试及12静态窗过；双模拟器Debug/签名Debug/无签名Release与30/27核签候选过未装。大字OCR图标干扰失败保留，只补未过窗，4自建实例全清。0NAS/真机/播放，114格无新P，真实目录和完整交互仍待。

2026-10-30 [演职资料状态与请求隔离](../archive/handoffs/2026-10/2026-10-30-MEDIA-DETAIL-READ-STATES.md)：三端网络库分读取中/成功空/失败，已有姓名继续显示；NFO与人物补读用身份+每次Ticket隔离陈旧成功/失败/取消。4既有+2新增文件/435输入同，26测试及9静态组件窗过，双模拟器Debug/签名Debug/无签名Release编译过；30/27核签候选未装。编辑事务仅核既有临时存储测试，0NAS/真机/播放，114格无新P；真实图片/横滑/焦点仍待。

2026-10-29 [人物横向共用与TV焦点](../archive/handoffs/2026-10/2026-10-29-SHARED-PEOPLE-SCROLLER-AND-TV-FOCUS.md)：正式三端多来源共用横向容器，TV网络人物补只读焦点/共用暖色边框；TV Jellyfin原方向状态保持。5源/433输入、6测试及双端Debug/Release编译过；仅3静态基线成立，手机横滑无确认位移、TV交互超时清理，均未判交互PASS。3自建实例全清，候选核签未装；0NAS/真机/播放，114格无新P。

2026-10-29 [人物卡与离线返回](../archive/handoffs/2026-10/2026-10-29-SHARED-CAST-CARDS-AND-OFFLINE-RETURN.md)：人物卡大字160宽/完整姓名角色，TV最多2行、空角色不伪造；三端Jellyfin/网络人物位共用占位图，图片任务/URL及播放源码保持。6既有源/433输入同、6既有测试/双模拟器Debug/签名Debug/无签名Release过；10组件窗（4手机/3Pad/3TV）文字/背景及抽图核过。独立同包手机进详情返回静态区域相同，非真实来源/动画闪动验收；初导航超时/截图148保留，短流程复查完整，4自建实例全清。30/27核签候选未装，0NAS/真机/播放，114格无新P；下一横滑/TV焦点/缺资料。

2026-10-29 [媒体头图与标题自适应](../archive/handoffs/2026-10/2026-10-29-ADAPTIVE-MEDIA-HERO-AND-POSTER-TITLES.md)：共用iOS Hero随内容增高、辅助字号上下排，Heading大字完整换行；海报大字不限行，TV标准标题预留两行对齐。4既有源/433输入同、6既有测试、双模拟器Debug r2/签名Debug/无签名Release过；12组件窗（4手机/5Pad含真实旋转横屏2/3TV）文字/连续背景及关键图核过，非真实图片/头像/完整交互验收。初版接口编译失败保留并修正，3自建实例全清；30/27核签候选未装。0NAS/真机/播放，114格无新P；下一人物区/缺资料与返回。

2026-10-29 [隐私摘要与确认提示](../archive/handoffs/2026-10/2026-10-29-SHARED-PRIVACY-SUMMARY-AND-RESET-PROMPT.md)：三端正式隐私页共用四项数据保存范围和暖色/大字正文；TV连接配置/管理保留，iCloud未接入如实说明。移动重置信任先alert确认，原clearAll/缓存/钥匙串删除实现不改。7既有文件/433输入同，4参数测试/资源检查与移动模拟器r2/TV模拟器r3/签名Debug/无签名Release过；12最终隔离窗（5手机含英文/4Pad/3TV）文字/背景及关键实图已核，确认框显式取消/重置可见，但未点按钮或执行清除。首版无取消浮层及TV构建目录锁失败保留，提示已修正/编译顺序重跑过，4自建实例全清；30/27核签候选未装。0NAS/真机/播放，114格无新P；下一媒体缺资料/横屏大字。

2026-10-29 [Plus共用概览](../archive/handoffs/2026-10/2026-10-29-SHARED-PLUS-OVERVIEW-AND-ACCESSIBLE-CARDS.md)：正式手机/Pad/TV共用状态、开放说明与四功能卡片，移除尚不能购买的月年价格选择及死分支，原权益判断/Debug active不改；TV明确会员与iCloud未接入。标准字号同排等高双列、辅助字号单列，宿主延续主题。7既有文件/433输入同，4参数测试/资源检查及双模拟器Debug r2/签名Debug/无签名Release过；12最终隔离窗（5手机含英文/4Pad/3TV）文字/背景与抽图已核，非真实会员或完整导航验收。首轮大字仍双列失败保留并修正，6自建实例全清；30/27签名候选未装。0NAS/真机/播放，114格无新P，真实隐私页不变，下一继续。

2026-10-29 [共用帮助与正文精修](../archive/handoffs/2026-10/2026-10-29-SHARED-HELP-TOPICS-AND-ARTICLE-POLISH.md)：正式手机/Pad新增使用指南，三端共用连接/媒体/隐私专题及正文，TV另有遥控器专题并保留两列卡片/返回；移动中英文补齐，正文改primary/支持大字。7既有源/433输入同、4场景测试/资源检查与双模拟器Debug/签名Debug/无签名Release过；12最终隔离窗（5手机含英文/4Pad/3TV）文字及背景稳定过、关键图已看，非完整帮助/交互验收。首版截图及中断清理保留，全部自建实例已清；30/27核签候选未装。0NAS/真机/播放，114格无新P；Plus/真实隐私操作未迁移，下一继续。

2026-10-29 [WebDAV表单精修](../archive/handoffs/2026-10/2026-10-29-WEBDAV-FORM-POLISH-AND-OFFLINE-PREVIEW.md)：正式添加/编辑复用同一表单和主次操作，新增密码显隐、辅助字号上下排、顶部错误/忙碌提示，iOS主题导航/按钮内边距对齐；原HTTP/HTTPS/端口/路径解析和连接事务不变。4既有源/433输入，24既有模块测试与双模拟器Debug/签名Debug/无签名Release过，24最终隔离窗经文字及相邻背景采样核对、关键实图已看；非完整交互/真机验收。白屏/冲淡颜色及主动中断原样保留，全部自建实例清理；30/27核签候选未装。0NAS/真机/播放，114格无新P；下一设置子页与媒体细节，仍6.1。

2026-10-29 [设置入口与默认项共用](../archive/handoffs/2026-10/2026-10-29-SHARED-SETTINGS-CATALOG-AND-DETAIL-ROWS.md)：正式Mine/TV设置直接用同一6项清单及暖色标签；播放器默认两行共用，iOS保留本地化、大字上下排，TV仍原卡片/真实目的页。6既有源/433输入、4场景测试与双模拟器Debug/签名Debug/无签名Release过，25最终离线预览窗文字过/抽图实看，非完整设置与遥控验收。原并发白屏和明确磁盘满分别保留，清12个未安装中间包、5个任务实例，最终两候选已重新冻结未安装。0NAS/真机/播放/新114格P；下一设置子页与连接表单，仍6.1。

2026-10-29 [离线媒体场景](../archive/handoffs/2026-10/2026-10-29-OFFLINE-MEDIA-UI-SCENES.md)：三端共用Debug合成数据与真实媒体组件，@main先选隔离根再创建普通账号/同步；4模块过、双模拟器Debug/签名Debug/无签名Release编译过，433输入同，30最终模拟器窗页文字核对成立、抽图已看，失败原样保留。30/27签名候选未装真机，0NAS/真实播放/114格新P；只覆盖媒体组件/状态，四Tab/完整设置/大字/交互仍待。用户进一步限定未来数日打磨细节，全部真机/NAS等恢复后；按[场景规范](../testing/OFFLINE_MEDIA_UI_SCENARIOS.md)继续，仍6.1。

2026-10-29 [NAS独立优化审查](../archive/handoffs/2026-10/2026-10-29-NAS-INDEPENDENT-AUDIT-AND-FIRST-FIXES.md)：用户授权NAS修复期间集中三端UI/竞品及本地可验证工作，形成[执行清单](../project/NAS_INDEPENDENT_WORK_PLAN.md)，不另建编号。确认并修正手机旧MobileVLCKit说明，双端读共用视频引擎摘要；TV设置顺序对齐移动。五份既有输入变化、430冻结同，1既有引擎测试/双普通Debug/30与27签名过，候选未装；0NAS/设备控制/蜂窝/新114格P，未改实际播放路线。完整三端视觉/本地协议等仍待，不把计划当交付；本批未重建Release。下一优先无NAS真实组件场景、主题/设置及媒体页核对，NAS网络性能继续暂停。

2026-10-28[独立连接与原子编辑](../archive/handoffs/2026-10/2026-10-28-SAVED-CONNECTIONS-AND-ATOMIC-EDITING.md)：连接独立保存/旧库关联迁移、添加与编辑共用HTTP/HTTPS等表单、关联目录分区和全部关联库事务已接；旧库/原凭据保留。全215测试过/419输入双普通Debug，13/Pad/TV保留数据安装，三端编辑预填/取消与目录草稿取消过；13新包真实1文件A→B保存、墙更新及清临时库后完整迁移基线同。首诊断BrokenPipe/旧分隔符清理失败保留，独立清理及复验通过；连接改名原生输入超时未提交/原索引同，地址账号和多库提交仍待。原库149/3408/3408完整资料除新增connectionID外同，TV配置迁移变化单列/其他偏好同。用户已带走18，本轮零发现/安装/控制。0播放/NAS源写、30项14/5/11与114格不变。
2026-10-28[竞品连接参考与目录浏览](../archive/handoffs/2026-10/2026-10-28-STORAGE-REFERENCE-AND-FOLDER-BROWSER.md)：实际观察13 Infuse新增WebDAV表单/高级项、已有FTP目录及收藏重命名草稿取消；爆米花仅更新提示/TV仅清单，不夸大参考。三端共用添加来源选择、已有WebDAV登录复用、连接管理媒体文件夹入口及浏览选择路径草稿；独立连接/地址账号编辑仍未做。35定向0失败、418输入双普通Debug，13/Pad/TV保留数据更新及新流程草稿→取消/末首页实图过。TV前三驱动失败保留，fresh索引纠正旧movie预期后过；当前3408配置覆盖前已存在，不恢复旧149。13/Pad索引同旧批，TV同fresh3408基线，三机偏好同。18本批两次无线发现失败未安装，最后确认上一详情包。0播放/0目录提交/0NAS写，30项14/5/11及114格不变；FTP/SMB/全会话/Pad退出继续开放。

2026-10-28[详情信息区共用](../archive/handoffs/2026-10/2026-10-28-DETAIL-INFORMATION-LAYOUT.md)：MediaDetailInformation实际接移动/TV Jellyfin与网络库，统一演职→制作→推荐→来源/文件的顺序、制作文本和分区间距；TV演职标题共用Section，原遥控焦点保留。36资料回归过/418输入双普通Debug，四机保留数据更新，18仅无线安装。13/Pad/TV两入口同片实图已核，TV演员焦点往返成立；父级标记覆盖子级的中间失败已修正并保留，Pad另补视口实图，不以AX可见冒充屏幕可见。三机完整索引/原偏好同，0播放/0源文件写/无新114格P。用户再次要求完整参考Infuse/爆米花的连接与文件夹添加修改流程，下一优先落实该项，不能把此前有限首页观察算完成。

2026-10-28[共用准备执行与取消清理](../archive/handoffs/2026-10/2026-10-28-SHARED-PREPARATION-COORDINATOR.md)：PlaybackPreparationCoordinator实际接WebDAV双端/TV Jellyfin，统一初始执行、重复准入、当前性检查、迟到结果释放和当前错误；取消后的释放在独立未取消Task中执行且等待完成。65定向0失败、418输入双普通Debug，四机保留数据更新，18仅无线安装。13 WebDAV/TV两来源有限实播与正常返回已核，TV焦点Select暂停继续成立；Pad仅最新首页，旧416在播控制栏观察失败/主动停止保留，普通退出仍待。三机完整索引与原偏好同，无NAS写/114格新P；完整生命周期/FTP/SMB仍开放。

2026-10-28[共用播放准备](../archive/handoffs/2026-10/2026-10-28-SHARED-PLAYBACK-PREPARATION.md)：新增PlaybackPreparationGate并实际接WebDAV双端/TV Jellyfin，统一初始重复请求/取消迟到交付准入，源取消/释放仍由宿主负责。44＋14无重叠共58测试过，416输入双普通Debug/四机保留数据安装，18仅无线不启动；13 WebDAV与TV两来源同片名就绪后有限播放/正常退出已核。Pad3/10实帧成立但正常退出仍待，AX/驱动失败及主动停止均保留，最终首页/工具清理已核。三机149/3408/149索引完整JSON及原偏好同，无NAS写/114格新P；完整会话及FTP/SMB仍开放。

2026-10-28[端点凭据与人物图片](../archive/handoffs/2026-10/2026-10-28-ENDPOINT-SCOPED-CREDITS.md)：修复多地址已有登录凭据不同而误拒补图，精确编号/每端点自身凭据。13/Pad/TV同片真实人物照均已实看，缺图仍占位；Pad/TV保留原生等待后编辑预填→取消回墙通过，旧误导航/超时保留。Pad3,408/TV149索引完整JSON同、原偏好同。414输入/双普通Debug/39定向0失败，四机保留数据安装，18仅无线安装不控制。0播放/0 NAS写，不增114格P，UX-08/09仍进行中，完整播放会话/FTP/SMB继续开放。

2026-10-27[修改文件夹与共用操作](../archive/handoffs/2026-10/2026-10-27-LIBRARY-FOLDER-EDIT-AND-SHARED-ACTIONS.md)：414输入/双普通Debug/39定向0失败；WebDAV默认海报墙、移除独有列表、Jellyfin与网络库共用更多/刷新，新增完整路径先扫描后事务替换。13真实错误保149→原路径验证约160秒成功/绝对源文件集合相同；Pad/TV菜单与预填编辑实图成立，但取消未验、即时AX失败保留。四机最新包保留数据安装，18按用户使用中限制只安装不启动。TV头像样本9真实/1占位，13指定影片仍占位需定位，不能关闭头像项。无NAS写/新播放P，完整会话/FTP/SMB仍开放。

2026-10-27[三端网络库精简与原盘资料补读](../archive/handoffs/2026-10/2026-10-27-COMPACT-LIBRARY-AND-CONSISTENT-CREDITS.md)：按用户新反馈，三端共用网络墙移除居中重复名、顶部统计和分类数量黄框，详情统一演职区/导演角色及制作文本，文件信息共用Disclosure默认折叠，移动Jellyfin同组件/去重复片名。修复BDMV详情遗漏影片目录NFO，复用扫描实际规则且读前后核版本/根范围/身份；19资料＋39分类图片只读定向回归过，双普通Debug/409输入。TV9c9012f…20:45:37、移动d5cfec4…13 USB20:45:55保留数据更新，TV普通片/原盘和13实图及文件信息展开已核；原盘缺本地封面仍未解决。Pad不可连接、18通话现场等待空闲回复，无最新包验收；播放会话迁移未实施，本轮0播放命令，不增114格P，30项14/5/11保持。

2026-10-27用户再次明确：三端共同信息结构/业务/视觉优先，仅触摸、遥控器焦点、观看距离及平台真实能力适配；同端Jellyfin/WebDAV/后续FTP/SMB不能另建平行实现。[媒体共用批](../archive/handoffs/2026-10/2026-10-27-SHARED-MEDIA-PRESENTATION-AND-WIRELESS-UPDATE.md)已将实际海报卡/网格/标题工具栏、hero/资料流/简介/操作/人物组件抽入NetworkMedia并由两App原Jellyfin及网络入口调用；TVPlaybackPresentation共用chrome，KS为render-only。仍有来源宿主/会话与剧季展示差异，不能称全三端一致。13同片对照发现背景未继承，已在导航边界显式传递宿主主题，最终普通包实图确认修复；不用截图看起来相近代替复用。

| 层 | 当前实际调用 | 仍需收敛 |
| --- | --- | --- |
| 海报与详情 | NetworkMedia.MediaPosterCard/Grid、MediaLibraryHeading/Toolbar、MediaDetailHero/Facts/Section/ActionRow/PersonCard；LaunchpadView和TVViews真实使用 | 剧/季布局、来源缺资料能力、完整深浅色/大字及设备对照 |
| 移动入口/宿主 | WebDAV NetworkLibraryPlayerPresentation→MediaPlaybackRequest→greenfieldPlaybackCover；Jellyfin详情普通兼容BuiltInMediaPlayerView及DEBUG greenfield分支 | Release实际路线/公共准备与生命周期不能因DEBUG共宿主就写全部完成 |
| TV呈现/引擎 | Jellyfin TVNativePlayer与WebDAV TVNetworkLibraryPlayer→TVPlaybackPresentation；AV与KS为不同实际能力适配 | TV文件入口其余宿主及字幕几何完整一致性 |
| TV来源与会话 | Jellyfin TVPlaybackSession→client.prepare/report/stopEncoding；WebDAV NetworkPlaybackOwner→WebDAVPlaybackSession→临时loopback→KS | 准备/取消代次、退出清理、续播/轨道意图需要共同权威实现；来源认证、服务器协商/报告保留适配器 |
| FTP/SMB | 正式FTP只读原语已有、App仍未接；SMB原型严格范围失败未接受 | 类型化来源/账户/选根与共同播放适配，不能声称已共用未交付功能 |

2026-10-26后续SMB raw分页/NFO与缺签拒绝实验[双平台隔离编译](../archive/handoffs/2026-10/2026-10-26-SMB-RAW-DIRECTORY-NFO-ISOLATION.md)成立，全部在仓库外；无新宿主依赖、App代码/包身份或三端SMB交付收敛，不能把原型framework当已集成模块。

2026-10-26服务接续：NetworkMedia现共用产品线索/端点身份/有界公开HTTP＋TLS/结果代次/服务列表与详情；移动DSMClient和TVDSMClient的Jellyfin核验均用严格产品解析。平台保留DSM清单、已有Keychain/TV账户读取和现有Jellyfin库目的页；TV独立已存来源不冒充当前NAS服务。共享识别不等于共享或新交付Emby/Plex/音乐授权/播放链。见[本批](../archive/handoffs/2026-10/2026-10-26-MEDIA-SERVICE-DISCOVERY-AND-ENTRY.md)。

2026-10-26：NAS文件夹来源的扫描/分页/NFO/存储/纠错及界面仍共用NetworkMedia；移动LaunchpadMediaShortcuts和TVNASOverview仅提供各自当前会话校验与实际主题。File Station适配已共享，不使用两端原文件浏览器的不同分页结果拼库。见[本批](../archive/handoffs/2026-10/2026-10-26-NAS-SESSION-SOURCE-HUB-NATIVE.md)。

2026-10-26来源扩展审查：[统一来源方案](UNIFIED_SOURCE_DISCOVERY_AND_ACCESS.md)指出移动已有部分名称归类、TV目前主要验证Jellyfin，NetworkMedia工厂缺NAS上下文/主主题接线；拟共享发现证据/身份、授权/能力和主题组件，平台保留必要交互差异。本轮未修改源码，不将方案或预览计作代码收敛完成。

2026-10-26再续：[本机纠错/宽行修复](../archive/handoffs/2026-10/2026-10-26-LOCAL-CORRECTIONS-AND-SMB-PREFLIGHT.md)共用LocalMediaCorrection、版本复核、旧表单保护及SwiftUI编辑/恢复；TV持久v2目录保存有界覆盖，手机/Pad随Application Support快照，原始NFO不改。42逻辑与最终三机建库/电影编辑/恢复/移除通过，旧胶囊/Pad空白点击失败已修并留档。SMB仅仓库外双平台动态构建、SDK取消反例及raw协商取消/截止原型，没有加入工程；不改变现有播放链差异。

2026-10-26后续：[NFO与TV本机存储](../archive/handoffs/2026-10/2026-10-26-LOCAL-NFO-METADATA-AND-TV-STORAGE.md)共用NetworkMedia的文件名/季集/NFO规则、GET边界、单actor与来源展示；平台差异仅电视Caches可重建索引＋小型UserDefaults源目录，手机/PadApplication Support，凭据同Keychain约束。32测试/双工程构建及三机实际目录/NFO切片成立，TV取消待验；不是全部播放链统一或在线provider交付。

2026-10-26：[只读WebDAV切片](../archive/handoffs/2026-10/2026-10-26-READONLY-WEBDAV-LIBRARY.md)新增同一本地NetworkMedia包，移动/TV工程都实际链接目录/扫描/索引/Keychain/SwiftUI入口；以公开AnyView工厂保持界面存储在模块内。平台入口分别在LaunchpadMediaShortcuts/TVNASOverview；15测试/两端构建，13完整夹具证据，TV表单有限/Pad安装阻塞。共享的是当前网络库切片，SMB/匹配和播放仍未接，不能据此把现有AV/KS全播放链标为统一。

2026-10-25新增[只读网络媒体库设计](READ_ONLY_NETWORK_MEDIA_LIBRARY.md)：新WebDAV/SMB、扫描/匹配/索引应共同模块，平台只适配连接/目录选择和呈现。当前只有来源枚举/SMB发现，完整协议客户端与独立刮削未接；不因设计而改变现有三端交付结论。

2026-10-25补充：[TV原始音字幕目录](../archive/handoffs/2026-10/2026-10-25-TV-SOURCE-TRACK-CATALOG-AND-HANDOFF.md)已采用源绝对索引与用户意图快照；TV仍独立TVSourceSelection/会话，不冒称已直接共用移动Intent。AV与KS文件的事件归属已核，文件renderer-only共享字幕入口尚缺；47逻辑＋11UI与局部实播不代表完整三端一致。

2026-10-25补充：[TV焦点修复](../archive/handoffs/2026-10/2026-10-25-TV-DETAIL-ENTRY-FOCUS-COMMITS.md)是遥控器专属区域入口策略，不向触屏端照搬；首项向下/原动作向上与共同信息层次保持。未统一TV原轨目录/文件KS与移动完整播放链。[总交接](../archive/handoffs/2026-10/2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)列明所有分支剩余差异，不能称三端代码已完全共用。

2026-10-25 20:32：TV按完整顺序改显式焦点及横排记忆，最终40逻辑＋7无媒体UI、真机44逐键闭环通过；旧跨区可达不足及两候选/错API顺序夹具失败保留。iPad横竖hero/图内圆点/完整参数已优化，首版横屏标题裁切经实图发现并修；最终普通移动包已13/Pad逐机保留数据安装与实图/返回核对，源510/570零漂移。TV自有Runner停；Pad仅自有HTTP会话已删除/原方向设置恢复，未知Runner保留，13未知Runner不改。0媒体/蜂窝，28/114保持。

实际接受映射：TVDetailView/TVMediaShelf/TVPersonCard明确焦点目标及确认后的横排记忆；移动LaunchpadView的JellyfinHeroCarousel/HeroSlide同画布与JellyfinMetadataFlow自然宽。固定AV/KS、Range/缓冲/音字幕协商未改；本批为详情导航/布局，不关闭原矩阵。

2026-10-25 19:45：TV首演员Up空间缺口已补焦点区域，普通新包9896b4c9/27签名19:30保留数据安装；40逻辑＋6无媒体UI、真机详情31方向与四根页/子页32检查完成。包括首/末演员Up及相似区上下，非所有动态界面/帧时间验收。两次自有Runner停/设置恢复，TV偏好与上一批末0变化，手机0操作。18条海报抽样确认源分辨率不一；白夜旧500×750但提供方可取中文1200×1800，实际图片下载解码通过，高清补全尚未接入产品。28开放／114格保持。

接受实现映射：TVViews.TVDetailView/TVMediaShelf及TVNASViews偏移操作组focusSection，原网格最小揭示不改；DEBUG内存夹具仅测试。高清图片仍原Jellyfin展示路线，候选可用不当产品已接入；解码/Range/缓冲/音字幕协商未改。

2026-10-25 19:20：三端详情精修已用普通新包逐机实看；共用海报/元数据格式、手机续播与重播同行、分类优先实际背景图。TV40逻辑＋5无媒体UI过；真实网格23次方向核对与最小滚动有证据，非帧时间验收。Pad黑屏经唤醒恢复、原因未知，最终详情和返回实看；自有Runner/设置已收尾。新报首个演员Up失效，当前继续全局方向键审查；新增高清海报/独立刮削调研。28开放／114格保持，未改播放传输，源音字幕切换及原弱蜂窝问题仍开放。

源码映射：AppTheme.MediaDetailDesign/NastartMediaFact共同格式与样式；LaunchpadView.Jellyfin详情/TVViews.TVDetailView只读展示，TVModels.TVDetailStream解码来源参数，TVJellyfinClient.libraryArtwork只读背景图。固定AV/KS解码、Range、缓冲及选流未改，40＋5不替代实播矩阵。

2026-10-25 15:39：[TV层级与遥控器批](../archive/handoffs/2026-10/2026-10-25-TV-CONTEXT-NAVIGATION-AND-REMOTE.md)将“统一”明确为共同语义/设计＋平台交互适配。新增TVRootNavigationShell由TVHomeView拥有全部四根栈，TVSettingsView不再重复持栈；真实root生命周期控制全局导航可见性，保持挂载避免重新夺焦。共享PlaybackControlDesign新增restartSymbol，移动与TV详情实接。TVNativePlayer仅遥控器chrome/进度绘制调整，TV文件KS、完整Intent/Plan/Route仍独立，不能写成全播放链统一。

2026-10-25 15:04：[源轨身份、播放意图与诊断校正](../archive/handoffs/2026-10/2026-10-25-SEEK-PHASE-AND-TRANSPORT-SCOPE.md)完成：旧late metrics 144项62归属误标已按发出记录校正；共享UI丢绝对源音轨/字幕ID及sidecar导致文件HLS准备拒绝已修，缓冲actual=false误当用户暂停已改读取AV/KS真实意图。9/10/12三组定向分别过（不相加成全量）；普通a4477a45最新保留数据装13/Pad、570输入/30签名/安装偏好0变化。13真实早期+15已HLS重建并startsPaused=false、实际继续电影/内部推进162秒/普通返回；三窗均停自有媒体和syslog、原网Selected＋Wi-Fi图核，其他偏好保持。完整声音/帧时间/格式族/并发、KS长等待与持续几KB仍开放，28/114不关闭。TV新增KS只读接口未重建，不以11:14旧包当当前源码回归。

2026-10-25 13:25：[蜂窝大文件传输候选](../archive/handoffs/2026-10/2026-10-25-CELLULAR-FILE-SEEK-TRANSPORT.md)仅修改iPhone/iPad同一DevicesView代理实现，同route/origin连接复用、原认证/单任务隔离保留；8定向＋两机S01双入口/13蜂窝实际复用局部核。TV不编译此代理，当前11:14包未因本批失效，但完整播放链路仍分叉；不能把移动候选外推为三端同链路或全部功能通过。Pad桌面浮窗/全屏控制仍开放，18外出暂停。

2026-10-25 11:20：[播放控制与同款动作](../archive/handoffs/2026-10/2026-10-25-TV-TRANSPORT-PARITY-AND-MEDIA-ACTIONS.md)共用15秒/倍速/圆形控制及继续/从头同款按钮，TV JF固定AVPlayerLayer＋应用菜单；当前普通新包37逻辑＋4严格无媒体UI通过。实际S01 11次回退165秒准确，同cue菜单前/开/后字幕bbox一致/实图已看，菜单上移此场景修复；两级返回同PID稳定。本轮完整音轨/字幕/声音/帧时间和TV文件控制仍待验，保留旧失败；原10偏好不变/设置GET恢复/自有Runner已停。13与新Pad已装同一最新移动包，Pad重连及设备旧清理已核，18外出暂缓。28开放／114格不关闭。

2026-10-25 09:30：[共享设计实际接线](../archive/handoffs/2026-10/2026-10-25-SHARED-DESIGN-AND-TAB-FOCUS.md)TV工程PBXSources增加移动Core/Design/AppTheme.swift，主/次按钮、强调色、流光色组与卡片圆角同文件编译；iOS尺寸保留，TV仅必要语义颜色/焦点/尺寸条件。TVRootTabBar焦点改selection并给当前项userInitiated默认焦点；TVBackNavigation仅留遥控器dismiss边界、删除重复栏，纯返回按钮移除/只读内容可聚焦。完整页面/业务模型仍未全部共享，TV完整播放Intent/Plan/Route与Jellyfin会话仍独立；关闭候选真实稳定返回未通过，不能用共用样式替代播放契约共享。

2026-10-25 07:50：[TV 顶栏与首屏间距](../archive/handoffs/2026-10/2026-10-25-TV-ROOT-SCROLL-AND-PAGE-SPACING.md)普通新包已安装；固定顶栏／移除重复占位／共用紧凑页头，四页14滚动＋帮助/网络2返回、35逻辑/2UI通过，原10偏好全同/自有Runner已停。13四根页竖屏间距23–27点，Pad当前缺席待复核。[18有线新包](../archive/handoffs/2026-10/2026-10-25-IPHONE18-WIRED-REFRESH.md)07:33安装并正常NAS首页实看、26非诊断偏好不变，取代此前待识别签名阻塞；实际DSM仍自动LAN、域名旧问题继续暂缓。28开放／114格不关闭。

2026-10-25 05:23补：[字幕矩形第一步共享](../archive/handoffs/2026-10/2026-10-25-SHARED-SUBTITLE-GEOMETRY.md)已由移动策略别名与TV文件KS子树实际调用同一KS模块；作者坐标/样式与TV边距字号、JF系统/烧录仍未统一。TV新包S03/S01各1/2次Menu回原目录，手机真机新包待验；18新构建等待设备重新识别续签，非无线认证失败。

2026-10-25 05:00补：[TV焦点返回](../archive/handoffs/2026-10/2026-10-25-TV-EXIT-EVENT-PROBE.md)在共用KS的tvOS视频surface复用原退出规则，S03/S01普通短窗实证。新增DEBUG-only有界交互观察/无媒体夹具，不改变移动退出/字幕实现。下列24日源码库存是审查时基线，最新代码行数因本批变化，不能沿用为当前精确计数；完整播放契约和字幕几何共享仍缺。

2026-10-25补：[TV返回调查](../archive/handoffs/2026-10/2026-10-25-TV-PLAYER-EXIT-INVESTIGATION.md)两版候选未通过并已回退，当前无接受代码变化；普通网络页Menu可返回，完整播放器仍失败，嵌套dismiss根因尚未证。三端全链路/字幕统一尚未交付。

核对：2026-10-24。用户要求允许必要平台差异，但业务规则和播放链路尽量共用；维护目标不是继续复制三份逻辑。此文记录代码归属、当前接线与分批迁移契约，不另设需求编号；功能缺口仍以[全域对照](../project/APPLE-TV-FUNCTION-PARITY.md)和[唯一总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)为准。[机器可读清单](../testing/results/2026-10/2026-10-24-cross-platform-code-audit.json)列出所有本轮应用Swift源文件和关键符号位置。

## 结论与检查范围

- iPhone/iPad是同一`Nastart` target、同一App/Features/Core/Playback，设备族1,2；iPad导航/宽度适配有分支，不是另一套播放业务。两台真机和不同系统仍须各自验证。
- TV是独立target，8个应用Swift文件3038行；移动54个文件48588行。数量仅为库存，不是覆盖率、代码质量或功能完成度。
- 两项目确实引用同一本地KSPlayer包（58个Swift文件18782行）及其FFmpeg依赖；但TV没有链接移动`Playback/Core`、桥接、Greenfield渲染和请求/代理生命周期。**同一个解码库不等于共用播放链路。** TV文件走KS；TV Jellyfin走原生AVPlayer，会话/选流/上报又分别实现。
- 本轮对应用源码全量列清单，对应用入口、连接恢复、状态刷新、服务、文件、媒体库、播放直到退出的关键控制流逐段对照。不是逐行形式化等价证明；复杂错误分支、所有接口及真机全矩阵仍开放。静态清单也不证明Release或实际输出验收。

## 当前映射与偏差

| 范围 | iPhone/iPad现行位置 | TV对应位置 | 差异及处理方向 |
|---|---|---|---|
| 应用与四Tab | [AppTabRootView.swift:4](../../ios/Nastart/Nastart/App/AppTabRootView.swift#L4) | [TVNASViews.swift:7](../../tvos/NastartTV/Sources/TVNASViews.swift#L7) | 同一信息结构；导航与焦点保留平台适配 |
| 登录/会话恢复 | [AppStateStores.swift:1833](../../ios/Nastart/Nastart/Core/Stores/AppStateStores.swift#L1833) | [NastartTVApp.swift:22](../../tvos/NastartTV/Sources/NastartTVApp.swift#L22) | 移动重新认证/主与FileStation双会话；TV保存SID、失效提示，无同等恢复状态机 |
| DSM协议/接口发现 | [DSMClient.swift:839](../../ios/Nastart/Nastart/Core/Stores/DSMClient.swift#L839) | [TVDSMClient.swift:81](../../tvos/NastartTV/Sources/TVDSMClient.swift#L81) | 请求/错误/路径校验/DTO重复；认证信息不能在迁移中跨域或重发 |
| 资源与缓存新鲜度 | [AppStateStores.swift:864](../../ios/Nastart/Nastart/Core/Stores/AppStateStores.swift#L864) | [TVNASViews.swift:472](../../tvos/NastartTV/Sources/TVNASViews.swift#L472) | 移动持久快照+未知/缓存/实时；TV并行状态/发现、无同等持久快照 |
| 服务状态含义 | [ServiceHealthProbe.swift:15](../../ios/Nastart/Nastart/Core/Stores/ServiceHealthProbe.swift#L15) | [TVNASViews.swift:940](../../tvos/NastartTV/Sources/TVNASViews.swift#L940) | 移动HEAD可达检查；TV容器running；语义不等同，不能按首屏绿点比网络性能 |
| 文件目录/排序 | [DevicesView.swift:647](../../ios/Nastart/Nastart/Features/Devices/DevicesView.swift#L647) | [TVNASViews.swift:622](../../tvos/NastartTV/Sources/TVNASViews.swift#L622) | 四排序方向含义相近、DTO与分页/偏好不同；共享请求/排序契约，视图分离 |
| 播放入口/计划 | [PlaybackIntent.swift:163](../../ios/Nastart/Nastart/Playback/Core/PlaybackIntent.swift#L163) | [TVViews.swift:639](../../tvos/NastartTV/Sources/TVViews.swift#L639) | TV只有item/resume，未接移动Intent/Plan/Route；高优先级统一契约 |
| 选流与能力 | [PlaybackPlanningPolicy.swift:1221](../../ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift#L1221) | [TVJellyfinClient.swift:174](../../tvos/NastartTV/Sources/TVJellyfinClient.swift#L174) | TV原生容器优先/20Mbps H2641080p方案；移动按原流/网络/轨道/兼容条件规划 |
| 文件播放与传输 | [DevicesView.swift:647](../../ios/Nastart/Nastart/Features/Devices/DevicesView.swift#L647) | [TVNASViews.swift:801](../../tvos/NastartTV/Sources/TVNASViews.swift#L801) | 移动代理/Range与原流路线；TVdownload URL直交KS，KS共用不代表请求与生命周期共用 |
| 播放生命周期 | [PlaybackSessionCoordinator.swift:9](../../ios/Nastart/Nastart/Playback/Core/PlaybackSessionCoordinator.swift#L9) | [TVPlaybackSession.swift:6](../../tvos/NastartTV/Sources/TVPlaybackSession.swift#L6) | TV AVPlayer与文件KS另有两套prepare/stop；取消/错误/资源所有权须统一状态契约 |
| 字幕位置与缩放 | [LaunchpadPlaybackCore.swift:236](../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadPlaybackCore.swift#L236) | [KSVideoPlayerView.swift:594](../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/SwiftUI/KSVideoPlayerView.swift#L594) | 移动按fit/fill视频可见矩形+安全边距；TV文件按整播放器默认布局；TVJF系统/烧录又一条 |
| 内置文字/位图字幕 | [GreenfieldKSPlayerRenderer.swift:607](../../ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift#L607) | [TVJellyfinClient.swift:146](../../tvos/NastartTV/Sources/TVJellyfinClient.swift#L146) | 移动本地文本/PGS等、外置文字及偏好；TVJF只声明VTT HLS及多格式Encode，不能等同本地渲染 |
| 音轨与字幕偏好 | [LaunchpadView.swift:11457](../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift#L11457) | [TVViews.swift:680](../../tvos/NastartTV/Sources/TVViews.swift#L680) | 移动保存选择和off/sidecar/切源规则；TV系统轨道菜单，未接完整偏好与切源策略 |
| 续播和进度上报 | [LaunchpadView.swift:7244](../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift#L7244) | [TVPlaybackSession.swift:65](../../tvos/NastartTV/Sources/TVPlaybackSession.swift#L65) | 移动身份隔离/来源偏好；TV文件本机哈希键自动续播、JF本地seek和10秒上报独立 |
| 退出/清理 | [GreenfieldKSPlayerRenderer.swift:780](../../ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift#L780) | [TVNASViews.swift:858](../../tvos/NastartTV/Sources/TVNASViews.swift#L858) | TV文件宿主与KS嵌套ExitCommand有竞争，23:10窗三次Menu未退出；未修复，不当PASS |
| PiP与HDR | [GreenfieldKSPlayerRenderer.swift:122](../../ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift#L122) | [TVViews.swift:680](../../tvos/NastartTV/Sources/TVViews.swift#L680) | 移动有受条件约束的PiP/HDR字幕链，TV未接同等策略；显示/输出能力应注入而非复制常量 |
| 主题和显示参数 | [AppTheme.swift:3](../../ios/Nastart/Nastart/Core/Design/AppTheme.swift#L3) | [TVViews.swift:4](../../tvos/NastartTV/Sources/TVViews.swift#L4) | 命名/规则分开；应共用语义token与主题值，焦点材质/尺寸平台适配 |
| 事项/存储/云 | [CloudSyncStore.swift:73](../../ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift#L73) | [TVNASViews.swift:297](../../tvos/NastartTV/Sources/TVNASViews.swift#L297) | TV独立本机模型且真实CloudKit未接；免费签名无权限，不为一致性伪造同步 |
| 媒体库/海报/搜索 | [LaunchpadMediaLibraryViews.swift:4](../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadMediaLibraryViews.swift#L4) | [TVViews.swift:302](../../tvos/NastartTV/Sources/TVViews.swift#L302) | 移动库路由/多服务与TV独立Items/详情DTO；统一元数据/页状态/海报语义，遥控焦点单列适配 |
| 凭据与持久化隔离 | [KeychainStore.swift:41](../../ios/Nastart/Nastart/Core/Stores/KeychainStore.swift#L41) | [TVAccountVault.swift:5](../../tvos/NastartTV/Sources/TVAccountVault.swift#L5) | TV独立SID/token单账号；共享schema/迁移规则不等于跨端复制密码或共用Keychain命名空间 |
| 服务显示/顺序 | [ManualLaunchpadServiceStore.swift:3](../../ios/Nastart/Nastart/Core/Stores/ManualLaunchpadServiceStore.swift#L3) | [TVNASViews.swift:954](../../tvos/NastartTV/Sources/TVNASViews.swift#L954) | TV独立UserDefaults可见表，无完整移动收藏/排序/手动添加；需稳定共享服务身份 |
| 任务模型/规则/通知 | [LocalTaskStore.swift:51](../../ios/Nastart/Nastart/Core/Stores/LocalTaskStore.swift#L51) | [TVNASViews.swift:297](../../tvos/NastartTV/Sources/TVNASViews.swift#L297) | 移动提醒持久化/调度与TV本机待办独立，表单相似不等于规则/状态一致 |
| 错误和恢复语义 | [DSMClient.swift:13](../../ios/Nastart/Nastart/Core/Stores/DSMClient.swift#L13) | [TVDSMClient.swift:59](../../tvos/NastartTV/Sources/TVDSMClient.swift#L59) | 认证失效/权限/取消/错误文案重复；不能把不同错误都降为无法播放 |
| 诊断与可观测性 | [DiagnosticLogStore.swift:103](../../ios/Nastart/Nastart/Core/Stores/DiagnosticLogStore.swift#L103) | [TVPlaybackSession.swift:20](../../tvos/NastartTV/Sources/TVPlaybackSession.swift#L20) | 移动结构化日志与代次/阶段记录，TV仅简化播放信息/错误，无同等诊断导出 |
| 文件模型/身份/媒体识别 | [NASModels.swift:755](../../ios/Nastart/Nastart/Core/Models/NASModels.swift#L755) | [TVDSMClient.swift:14](../../tvos/NastartTV/Sources/TVDSMClient.swift#L14) | TV按扩展名枚举、mobile更多文件/光盘路径；共同格式与身份契约优先，能力输入与真实回归分别验证 |
| 协议与回归用例 | [NonPlaybackPolicyTests.swift:5](../../ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift#L5) | [TVClientTests.swift:4](../../tvos/NastartTV/Tests/TVClientTests.swift#L4) | 两App当前测试独立；抽共享规则后同fixture同边界，仍保留各平台真实渲染/返回测试 |

## 字幕的统一契约

默认普通对白跟随**实际显示的视频矩形**，水平居中、底部留安全边距，双语作为一个完整字幕块向上展开，不能把最后一行挤出画面。fit/fill、旋转、竖屏黑边、电视安全区变化都重新计算可见区域。屏幕底/黑边是可选呈现偏好，不应三端暗中各用一种坐标。片源本身带黑边时，编码帧不等于可见内容；未做有效画面检测不能声称自动识别黑边内容。

带作者定位的ASS/PGS/IMSC按其画布和坐标做映射，不应强制把招牌/旁白/双人对白全部挤成底部字幕；系统AV字幕及服务端烧录由适配器明确声明能力，烧录不能靠客户端移动。参考[W3C IMSC坐标/Active Area](https://www.w3.org/TR/ttml-imsc1.1/)、[Apple AVPlayerViewController](https://developer.apple.com/documentation/AVKit/AVPlayerViewController)的视频区域。12pt/现行字号是移动实现，不可直接把同一绝对字号硬贴电视；共享几何/边距规则，尺寸由显示环境输入。

移动Greenfield当前也将字幕parts放进底部VStack，文本转string，位图使用canvas缩放尺寸但未按origin布局；作者定位/样式可能丢失。两台共用并不证明实现已正确，不应把这部分原样复制成三端统一方案。

本轮发现TV文件默认`KSVideoPlayerView`整屏GeometryReader/HStack/padding字幕，移动另有视频矩形布局；TVJF是系统或烧录。当前未修改字幕输出，用户报告三端共性问题保留，下一批优先抽共享几何并接实际两个App入口，不新建未使用的空模块冒充完成。

## 首屏快慢的统一契约

移动已经持久化DSM快照，冷启动立即读，服务先标unknown避免把旧在线当实时；随后重新认证、发布主会话、附加FileStation、等待LAN发现、完整快照（含证书/套件/网络/容器补全）再替换。快照中的`async let`已经并行，不应把问题简单描述成所有接口串行。登录尾仍等待可选发现，慢的补充接口仍可延后整份快照呈现。

TV Keychain复用SID和API目录，状态与服务发现分别`.task`读取，跳过移动的重认证；但容器`running`不等同移动HEAD服务地址可达。TV也不是缓存秒出：本批Overview没有同等持久快照。用户看到“快”有效，但不能据此推出相同状态语义和同条件实测更快；DSone用户观察同样保留，未做新同窗竞品计时。

移动健康检查6并发、单请求3.5秒，旧实现等所有结果再一起发布。**本批已将每个完成端点即时回调并更新其同URL服务，保留最终汇总、取消/刷新代次守卫，并在恢复/刷新快照发布后立即触发检查，避免依赖下一次15秒监测；157逻辑测试执行、1跳过、0失败。** 三个确定性门控测试覆盖即时触发、“慢服务挂起时快服务已发布”和“取消后晚结果不发布”。尚不等于真机启动秒数改善，也没有跳过认证、假在线或修改NAS地址。

需要继续统一：设备可达、容器运行、服务可达三种状态独立；缓存显示上次更新时间；认证/基础资源/容器清单/健康探测/扩展信息分阶段发表。不能为了首屏全绿保存密码到TV、无条件重登、取消证书校验、修改用户域名或把超时延长。

## 收敛顺序与代码归属

1. **先收敛可独立验证的规则**：字幕视频矩形、safe-area/字号输入、时间/ticks/续播身份、轨道off/default、错误与网络状态语义。每项真正从移动原位置抽出，两个App链接并调用同一个实现；原入口以迁移兼容层过渡，不保留两份新旧权威逻辑。
2. **再统一播放契约与生命周期**：共享Intent/Plan/Route、会话身份/取消代次、字幕/音轨选择与报告、退出清理；引擎适配器分别调用KS/AV，capability明确可用编码/音频/渲染/PiP，不把20Mbps/1080p限制当永久tvOS能力。两入口先接同一协调器，再迁移代理/Range与恢复规则。保留真实退出失败，不为套用架构删除原有效链路。
3. **连接与数据层**：共享DSM请求/错误映射/DTO、刷新阶段和状态，Keychain访问及证书提示等留平台适配；保存地址/登录地址/请求地址分别建模。服务发现/分类/可见规则、文件排序/分页/筛选契约只维护一处。
4. **内容模型与界面**：共享四Tab/分组/主题token、设备/服务/事项/我的信息模型与持久化schema，视图按手机/平板/电视布局与焦点适配。云能力和平台限制显式声明；当前TV云模型及免费签名权限没有完成。

不把整个四万行移动应用直接编入TV：UIKit/WebKit/iOS通知/横竖屏/系统PiP与tvOS接口需要适配，手机文件中混放的纯业务规则需先解耦；这不是拒绝统一的理由。初期以内部共享模块承载纯规则和模型，业务依赖App UI属于反向依赖，不准引入。

## 每批验收与当前现场

- 共同fixture在两个target跑相同契约测试；用必要的平台能力输入验证差异，不用各写一份期望来遮住分叉。记录模块实际调用方，禁止仅建空接口就写已统一。
- 各自构建有效签名普通包，核源码/产物哈希和设备，保留数据覆盖再真机回归；13/Pad同cue、TV相应入口独立跑，Debug/Release各自标明。字幕验证包括文字/位图/外置、单双语、fit/fill/字幕开关、控件显隐与实际可见边界；听音/HDR/帧时间不得用内部时间或稀疏图替代。
- TV 23:10最新浏览包播放54.01GB MKV：3/10/30/60秒有原生不同电影画面；三次Menu后仍是播放器且时间继续，不是普通退出成功。已主动结束App媒体并停自有Runner，23:18空环境重新打开原生NAS首页已看；所有权不明的13Runner未动。此失败和字幕位置用户反馈是优先接续，不重复播放掩盖。
- 最新移动普通Debug已Pad23:43:42、13 23:44:00保留数据安装，原生NAS/服务状态已查看；原偏好仅自然诊断变化。详细签名/哈希、工具失败和TV清理见[本批归档](../archive/handoffs/2026-10/2026-10-24-CODE-AUDIT-AND-SERVICE-HEALTH.md)。这不是同边界冷启动性能比较。
- 本轮代码审查和移动健康检查修改不代表TV字幕/全链路已统一。28开放需求与114播放格无新整格PASS；iPhone18域名/无线支线继续按用户暂停。
