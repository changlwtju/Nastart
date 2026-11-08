# 三端全应用主题、媒体入口与统计

核对：2026-10-24 21:38。用户要求三端全页面尽量一致；流光不能只限启动台，浅色要减淡，深色参考用户认可的TV；栈列首页要均衡，设备文件和影音媒体库在手机/Pad合入设备摘要并缩小。iPhone18域名问题仍按用户暂停，无操作。

## 接受实现

- 移动端 `NastartThemeBackground/NastartPageTheme/NastartSurfaceBackground` 统一页面画布、导航底与卡片/原生List分区。约50个页面标题节点与99个Section接入；数量是代码覆盖，不当全部页面视觉验收。保留高级主题原权限门控、清流默认语义、减少透明度的可读实色分支。系统键盘/播放器画面不强制着色。
- 流光浅色改为更淡的紫/桃/青；卡片低不透明度染色避免纯白块。深色加深蓝紫/酒红/青色底与通透卡片；移动端不使用会洗成白底的regularMaterial。TV保留用户认可的原流光颜色/材质，本轮不继续调TV配色。
- TV栈列上半部从左侧竖排指标改为整行NAS摘要、三个等宽指标、两个等宽媒体入口；已实际看过均衡布局。其他页先统一画布/边缘/分组；未来可在资源/服务/事项采用紧凑行和状态列，不把海报/播放器强制改表格，完整栈列子页布局仍待设计。
- 手机/Pad在DeviceSummaryPanel内放两个小快捷卡，无单独“影音与文件”标题。设备文件复用现有FileBrowserView根；唯一真实JF服务直接走MediaLibraryRouter；多个/未配置时用真实媒体目录和手动连接。过滤开发控制台，未改用户服务隐藏偏好，未造新播放器。
- 三端统计同口径：当前DSM账号可访问的共享目录数，及当前JF账号Movie总数；不是全盘文件数，不把剧集/单集混入电影。移动端复用根目录读取；TV根共享目录total优先。JF单次Limit=0/Recursive/Movie/TotalRecordCount，只读元数据、不取海报或媒体正文；4秒请求/6秒资源时限、取消后不发布、账号变更丢弃、拒绝重定向，未知显示待统计，不递归扫描或伪填0。多个JF服务的移动汇总尚未实现。
- TV我的新增iCloud同步状态页与明确返回，连接管理保留独立入口。用户确认仅个人免费签名，现场所有profile/安装包无CloudKit权限，移动普通Debug为NASTART_NO_ICLOUD。TV尚未接同构Snapshot/冲突合并；只显示当前不可用及本机数据归属，无假开关/云写入。苹果能力取决于平台/会员，见[官方说明](https://developer.apple.com/help/account/capabilities/capabilities-overview)。真实同步仍未交付，不能只靠换付费签名便声称功能完成。

## 最新包与真机门禁

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加原有dirty保留。手机569输入（包含无关TV清单）、TV508输入分别冻结；移动有效输入漂移0，TV有效输入漂移0。普通Debug、无环境/参数注入；不是Release。二进制、profile、AppID/Keychain和依赖均核，保留数据覆盖。13独立重签30 Mach-O、Pad30、TV27；13旧profile有效期到10月25日06:23中国时间，下轮须现场重核，不沿用。

| 设备 | 主程序SHA-256 | Debug dylib SHA-256 |
|---|---|---|
| iPhone13 | 3c949475adcfc874000ce84d55a853a1d36330ed26e1b3f6c613b7399012ea85 | 1070b68a3c88c088bbbc7f4bfa08259a899d5fd48f23618909991d746661a33c |
| iPad | 10537e2290d83f794e2f42baedf77843d0ed1290dcfeb0212f72016c879883db | 97a22386635549f9c2dcd21341a4bc2a54b8af308707f137fb0c9226f48b1b61 |
| AppleTV | 2c7ae6d5e6375c3a88f6f6cb7b4977ed2c55c8abc7473d174e4c24a9205ea5de | 8a9907f05bf3e74e5eeb094e27cde9e19a643d93bb01f8fcf51dfe620f2cb47c |

- iPhone13现场USB确实可用：iPhone14,5/iOS16.3.1。CoreDevice不可用列表不等于USB断开；tidevice安装传输停滞保留后，沿历史ios-deploy --no-wifi覆盖成功（21:05:46）。空环境正常；已看浅/深首页、深色设备/事项/我的、文件和直接JF；12目录/112电影实际可见。原glassDeck/system已恢复实读、WDA10/2已恢复；预存Runner不属于本批，未停止。
- 新Pad现场USB iPad15,7/A16/iPadOS26.6，21:13:47覆盖同源码普通包成功，正常NAS首页实际看到12目录/112电影。当前主题检查：light glass；dark glass across four tabs。旧包证据不升级为本包；初始工具选择器失败与主题画廊流程误判分别保留，不当App失败或成功。
- TV现场客厅AppleTV14,1/tvOS18.2，paired localNetwork。最新`tv-icloud-inventory-final`冻结/安装，以结构化结果的时间为准；前一`tv-icloud-status`实际核iCloud页/Menu回我的/12目录112电影，最后仅改“密码”为准确“登录会话”后重建再次覆盖。最终包回归/正常启动已完成，21:32:53–21:33:05停Runner后普通3/10秒原生首页实际已看；不得外推播放或全子页。
- 前一TV状态/事项包28逻辑+1UI成功，13条导航检查收尾与Runner停止20:08:41已核；本批全局主题TV四根、资源/文件/JF/帮助及返回有独立采样，最后增统计/iCloud只读说明后经真机构建和定向UI。旧测试不能冒充最后源码重跑29项。

## 失败、清理与未验

手机早期坐标谓词500、元素点击超时、隐藏底层code-server的错误断言保留；最终改为从新AX树取可见目标坐标，文件/JF真实路由通过。不把工具超时写作App旋转错误或崩溃。Pad原生Tab name为图标，label才是中文；主题为画廊→预览→应用，不是简单picker。保留失败JSON/截图。早期Pad原生黑图不算首页，后续WDA正常首页单列证据。最终停Runner后DVT直接启动又得到黑图；21:35:09系统前台激活重启（空参数/空环境）后3/10秒实际普通NAS首页已看，修正的是启动取证方式，未改App源码或声称历史黑图成功。

恢复原偏好：13 glassDeck/system；Pad cleanGrid/system；TV glassDeck/system、海报密度5。每个实际恢复/自有Runner停止结果以JSON实读为准，未知不声称成功。所有自有Runner有900秒上限及finally，10/2恢复后停止；不停止预存13Runner。本批0播放、0下载、0蜂窝，没有改NAS/VPN/凭据，不做性能或竞品结论。

28开放编号、旧76＋新Pad38播放格保持，无新增整格PASS。所有子页视觉/返回、复杂音字幕/HDR/长播、iCloud同构模型、Agent/完整任务/文件/播放策略依然待验；TV仍独立View与业务实现，不能宣称改一端三端自动生效。详细私有源清单/包/设备/凭据/原生图仅留本机证据入口，不入库。结果见[结构化记录](../../../testing/results/2026-10/2026-10-24-global-themes-and-media-entry.json)，后续按[全域差异](../../../project/APPLE-TV-FUNCTION-PARITY.md)继续。
