# 离线UI回归场景（媒体／设置／连接）

2026-11-03 [UI 批次新增入口登记](../archive/handoffs/2026-11/CODEX-2026-11-03-CLAUDE-UI-INTEGRATION.md)，以下均 DEBUG，Release 27 标记排除及 Debug 正对照已核：

- `--offline-ui local-library`：iOS 正式“存储与媒体”页面，标识 `private-host-1.example.invalid-library.banner`；**使用本安装正式媒体库与 Keychain**，仅自建模拟器手动添加指定 127.0.0.1:8089 合成只读夹具。不能用于带真实账户的真机或当成无副作用预览；92 空 MKV 不可播放。
- `--offline-ui launchpad-root` / `devices-root` / `tasks-root`：iOS 注入临时偏好域 `nastart.offline-ui.roots`、示例数据和无账号 stores，标识 `offline.roots.banner`；tvOS 断开账号的自有根外壳，标识 `offline.tv-roots.banner`，偏好域 `nastart.offline-ui.tv-roots`。默认构造分支仍是正式路径，仅 DEBUG 分流。
- tvOS `--offline-ui-tab launchpad|devices|tasks|mine` 覆盖离线根初始 tab；`--offline-ui-bold` 只在 DEBUG 离线分支设置系统粗体 trait（tvOS 无 iOS Larger Text）。不改正式初始 tab 或系统设置。
- 根离线入口**不是网络沙箱**：可到达的登录表单和部分深层页仍能直接联网/写入。禁止提交真实登录、点真实来源/服务请求；本轮只做空白宿主与模型回归，没有批准 NAS 普通根。

2026-11-02 [已保存／更改行与UI标识](../archive/handoffs/2026-11/CODEX-2026-11-02-SAVED-PASSWORD-INTEGRATION.md)：`connection-edit`默认预填且无`--offline-password-cell`时显示已保存／更改；点更改只在本地快照后清空、请求一次焦点，行内取消恢复。standard／large各一窗自动键盘／取消恢复通过，无延迟或补焦。显式cell（本轮F1）保留旧预填框，12→1已核，trace均关闭。

- 后缀：`.passwordSaved`（已保存状态）、`.changePassword`（更改）、`.cancelPasswordChange`（取消密码更改）。
- `offline.connection`前缀三项已实际观察；`network.connectionEdit`前缀三项为正式源码／编译登记，未用真实账号运行。
- 新建／无已存非空密码不启用该行（源码条件），本轮未操作这些窗口。取消结果只验合成UI恢复，真实Keychain／网络保存／TV遥控／iPad／完整读屏另验。
- 当前六配置／14项包测试与Release排除通过；旧批13项宿主有独立前源归属。新安装包身份及数据容器UUID检查失败见本批记录，不沿用旧F1包路径。


2026-11-02 [密码U/S同条件对照](../archive/handoffs/2026-11/CODEX-2026-11-02-PASSWORD-USF-CONTROL.md)：复用原F1安装包，UIKit／bare SwiftUI各2次，预填12点、standard、secure、content-type on、trace OFF；四次均12→1，启动参数与前后图／无trace已保存。对应batch7 U2／S2条件，未做U1／S1的content-type off。支持系统安全输入控件路径可复现，不证明内部先清空时序、所有iOS版本或显隐焦点修复；不增加播放验收。

2026-11-02 [第七／八批已接入](../archive/handoffs/2026-11/CODEX-2026-11-02-F1-BATCH7-8-INTEGRATION.md)：当前源码有以下变化；[主目录六配置／13项宿主及Release排除](../archive/handoffs/2026-11/CODEX-2026-11-02-BATCH78-SIX-BUILDS-HOSTED13.md)已补验通过，旧批9项证据仍保留原归属。单位测试和编译不替代下述真实界面验收。

- `settings` 外观目的地使用正式绑定及注入的临时合成偏好域：`offline.appearance.readback.choices`、`.toggles`、`.standard`。不写标准用户偏好；正式默认仍标准域与原通知。
- `privacy-cache`：`offline.privacy.cache-counters` 只记录合成确认／取消次数。真实清理实现按步骤继续并反馈部分失败；该计数不能验真实文件清理或取消零副作用。
- `privacy-export`／`diagnostics`：`offline.share.outcome`、`offline.share.counts` 控制DEBUG合成结果。正式分享改UIActivityViewController回调，完成／取消无提示，只有失败显示本地化键 `mine.share.failed`；此键不是accessibilityIdentifier。探针默认production不模拟／不记录；真实送达和完整iPad呈现未因此验收。
- 第七批新增`password-probe-swiftui`／`password-probe-uikit`和严格参数解析。密码JSONL沿原白名单新增 `cell`，native内新增 `role`（末段白名单）、`contentTypePassword`、`contentTypeUsername`；仍无文本／长度／偏移，0600且≤1024事件，默认关闭。手机F1标准／大字三次均12→1、四trace44事件；无trace补图两窗只为本轮用户逐格截图要求，不增唯一覆盖数。Pad未执行，显隐／真实凭据未验。

2026-11-02 [A16模拟器横屏补验](../archive/handoffs/2026-11/2026-11-02-IPAD-LANDSCAPE-AND-CLAUDE-BATCH3.md)：沿既有mine-info/diagnostics，3场景启动，无产品/参数修改。中文accessibility2独立说明/退出、诊断合成计数/空态禁用、AX滚动实际位移及横竖状态保持，英文standard横屏标签/摘要完整；不是OS全局字号/VoiceOver/实际剪贴板日志或真机Pad26.6验收。转场/白启动帧排除，DEBUG页脚同行边界仍开放；自建实例清、合成偏好同。

2026-11-02 [Mine/诊断实际组件宿主](../archive/handoffs/2026-11/2026-11-02-CLAUDE-BATCH1-INTEGRATION-AND-MINE-UI.md)：新增`--offline-ui mine-info` / `diagnostics`（DEBUG iOS）。复用正式退出/说明行、诊断操作/摘要，合成连接/计数、复制/清除仅内存回调、ShareLink仅固定合成字符串；不构造真实AppDataStore/诊断/账号/外观/权益或网络store，不写用户偏好。TV同参数为隔离范围提示，Release无该测试入口。中英标准/辅助字号模拟器四窗及13中文大字静态图仅覆盖本批组件；实际按钮/空态和原生AX滚动已核，普通scroll/拖动无位移保留，DEBUG页脚遮挡下方时间仍开放。不能当完整Mine/诊断页、真实日志、完整VoiceOver/帧时间或系统零网络证明。普通根仍会恢复NAS，本轮禁止启动。

2026-11-01 [正式导出宿主](../archive/handoffs/2026-11/2026-11-01-EXPORT-NATIVE-HOST.md)：新增 `--offline-ui privacy-export`，iOS复用正式Form/ShareLink，合成服务/提醒/偏好与注入样式，无真实store；从隐私预览导航也走同一内容，原假成功提示移除。TV保持只读隐私说明，Release不含该场景。4解析测试含新场景通过；模拟器000禁用→001→系统分享→取消回001一流程已看；13最新离线Form静态可见，真实分享/用户数据/普通宿主仍未验。

2026-11-01 [页脚与TV遥控](../archive/handoffs/2026-11/2026-11-01-PREVIEW-FOOTER-AND-TV-SERVICE-REGRESSION.md)：移动settings/sync/player标记随内容滚动，Pad当前图仍超时未验；TV player预览两卡和说明需focusable，大字Down实际240点位移。最终3主题/字号例、6实图仅覆盖合成行/返回焦点，非完整宿主/读屏/性能/真实登录；早期边界假设失败和大字零位移失败保留。

2026-11-01 [离线设置补验与背景](../archive/handoffs/2026-11/2026-11-01-OFFLINE-SETTINGS-RECOVERY-AND-PRIVACY-PREVIEW-THEME.md)：凭据/导出两个Debug子页须自行接宿主背景；正式页不改。手机标准中文及Pad大字补有限交互/同步旋转，全部为内存合成操作。Pad英文服务页脚被固定标记遮挡，旋转过渡图排除；TV工具两次超时无图。采图数不算测试通过数，详见本轮边界与清理。

2026-11-01 [播放器服务清单行](../archive/handoffs/2026-11/2026-11-01-SHARED-PLAYER-SERVICE-INVENTORY-ROWS.md)：既有player-settings及设置中的播放器目的地增加正式共用四行，固定合成保存授权/未确认/停止/已安装状态，无库存/账户/客户端/发现。场景参数未改，仍非完整正式播放器设置。预算约3.55GiB低于TV3.8/移动6门槛，创建设备前退出，0新模拟器/图，实际排版与读屏未验。

2026-11-01 [共用外观卡片选项](../archive/handoffs/2026-11/2026-11-01-SHARED-APPEARANCE-CARD-OPTIONS.md)：既有settings的外观目的地挂正式共用三Toggle，仅内存Binding，不构造AppearanceStore/TVAppState/客户端或保存偏好；参数未改。TV原生切换/往返/重入保留及恢复值的1唯一例通过，最终2图实看；首轮交互通过但焦点图标对比不足已排除，修正后再验。两自建实例全清，移动未达6GiB门槛未开；不是完整外观页、真实持久化、读屏或实体遥控验收。

2026-11-01 [account-connections原生遥控](../archive/handoffs/2026-11/2026-11-01-TV-CONNECTION-REMOTE-REGRESSION.md)：本批1唯一XCUIRemote例通过，Select切NAS/JF合成状态、Right/Left往返实际焦点及脱敏文字均有断言；2截图实看，只覆盖glassDeck/深色/标准字号。只改既有UI测试，不改产品/场景/参数；旧Return/Space无变化仍保留。1任务实例已清，非真实连接/实体遥控/VoiceOver/完整正式页/帧时间验收。

2026-11-01 [共用地址展示后续](../archive/handoffs/2026-11/2026-11-01-SHARED-CONNECTION-ADDRESS-DISPLAY.md)仅提取正式页面的纯显示方法，无场景/参数改动、0新模拟器/图。前批account-connections静态图属于旧输入，不用于当前包UI验收；两次切换无变化、客体AX未验结论保持。

2026-11-01 [电视账号连接预览](../archive/handoffs/2026-11/2026-11-01-TV-CONNECTION-STATUS-AND-ADDRESS-PRESENTATION.md)新增 `--offline-ui account-connections`：TV最早根分支挂正式TVConnectionPanel/纯展示快照，无TVAppState、账号、存储、钥匙串或客户端。合成URL中的虚构敏感部分只用于脱敏核对；两个按钮仅切内存，不执行登录/断开。移动同参数保持隔离并提示只适用于电视。TV深色glassDeck标准字号1静态窗已看；Return/Space无状态变化，切换及客体可访问性未验，1自建实例已清。它不是完整正式页、真实会话或实际遥控器验收。

2026-10-31 [凭据/导出子页](../archive/handoffs/2026-10/2026-10-31-CREDENTIAL-STATUS-AND-EXPORT-SELECTION-ROWS.md)：既有 `--offline-ui privacy` 在iOS新增两条子链接，复用正式保存状态行与三选项Toggle。凭据仅切合成Bool；模拟导出只改内存提示，不生成数据、不创建ShareLink或读取账号。仅共用行内容，非完整正式宿主；TV预览不增加这些能力，场景参数未变。0新模拟器/图，实际点击、零选择、大字与读屏待验。

2026-10-31 [隐私清理预览](../archive/handoffs/2026-10/2026-10-31-PRIVACY-CLEANUP-SCOPE-AND-EXPORT-COPY.md)新增 `--offline-ui privacy-cache`：iOS的隐私预览显示正式共用确认弹窗，确认仅改内存提示，取消沿系统动作，不调用缓存/网页/文件/钥匙串/网络逻辑。TV保持既有只读隐私预览，没有新增清理能力。4参数测试过，预算不足未启动模拟器、无本批新图，弹窗/取消/读屏尚未实验收。

2026-10-31 [同步范围预览](../archive/handoffs/2026-10/2026-10-31-SHARED-SYNC-SCOPE-AND-AVAILABILITY.md)新增 `--offline-ui sync-settings`，设置预览的 iCloud 目的地也接同内容。三项说明与正式移动/TV页共用；手机的不可用状态是合成固定值，TV内容与正式不可用页同源。无CloudSyncStore/AppState/账号/客户端/持久化任务，不触发真实云同步。手机标准、TV标准/大字共3静态窗已看；Pad因6GiB预算未启动。原五个目的地仅提示的历史描述自本批起不再适用于iCloud入口。

2026-10-29T15:06+08:00 [设置批](../archive/handoffs/2026-10/2026-10-29-SHARED-SETTINGS-CATALOG-AND-DETAIL-ROWS.md)新增`--offline-ui settings`与`--offline-ui player-settings`，`--offline-ui-text-size standard/large`控制预览字号；iOS还用进程参数AppleLanguages/AppleLocale做英文大字，不写用户语言偏好。实际复用正式6入口标签和默认两行，五个非播放器目的地仅范围提示，非完整设置。25窗最终验收按本批记录，不叠加上一30窗作本批55窗。

模拟器默认串行，OCR到页＋人工实图；先核磁盘余量，空间不足立即停并仅清任务自己的可重建副本，不碰用户数据。旧未安装候选路径可能已清理，安装前读当前存在的最终包清单，不能沿用历史路径。

更新：2026-10-29T13:29+08:00。[本批记录](../archive/handoffs/2026-10/2026-10-29-OFFLINE-MEDIA-UI-SCENES.md)／[独立优化清单](../project/NAS_INDEPENDENT_WORK_PLAN.md)。当前用于三端媒体组件和状态展示，不等于四Tab、完整设置或真实服务器页的全量回归。

## WebDAV连接表单隔离预览（2026-10-29）

`--offline-ui`另支持`connection`、`connection-http`、`connection-edit`、`connection-error`、`connection-busy`和`connection-actions`。前五项直接挂正式`NetworkWebDAVConnectionForm`，最后一项只挂实际共用的底部操作区，便于检查按钮；它不是完整表单或已经滚到表单底部的证据。`--offline-ui-text-size large`在iOS使用辅助功能字号，标签和输入改上下排列。

入口在隔离根的NavigationStack中，不构造真实添加/编辑宿主、NetworkLibrariesModel、存储、Keychain或网络客户端。域名使用`.invalid`，账号/密码和路径均合成。提交只执行纯本地`WebDAVConnectionFields.scope()`格式检查；仅保存/取消也只改内存消息，不写入账号或索引。忙碌页是固定状态，不启动任务。正式表单仍使用原有真实回调，不能把预览中的提交/取消当生产连接事务验收。

新采图除预期文字与“合成连接”外，检查背景采样点的深浅色和相邻两帧颜色稳定，保留每次重试。此规则只排除明显白屏或过渡截图，不能证明全屏颜色、帧时间、动画或交互正确。人工仍需抽看实图；旧批仅OCR通过的画面不追溯升级为稳定画面验收。原始异常及主动中断保留在私有证据区。

此批未执行键盘下一项、密码显隐切换/焦点保留、触控/遥控滚动与往返、读屏、真实提交或取消测试；预览的合成偏好哨兵保持不能代替用户设备偏好验收。FTP/SMB仍按原未开放状态，不把WebDAV预览作为它们已支持连接的证明。

## 共用帮助内容预览（2026-10-29）

`--offline-ui help`预览帮助专题，`--offline-ui help-detail`直接显示“浏览与播放”共用正文；设置预览中的帮助入口也接到专题预览，Plus/外观/iCloud/隐私仍是范围提示。不能将它们算成完整设置子页已迁移。

实际复用`NastartHelpTopic`内容清单和`NastartHelpSectionBody`正文；手机专题标签亦为正式`NastartHelpTopicLabel`。正式电视仍用原有两列TVFeatureTile，预览用无存储标签/焦点适配，所以不是整页电视网格或完整关于页验收。专题筛选规则一致：手机/Pad有连接、媒体、隐私三项，电视另有遥控器说明。

场景只挂静态内容，不构造正式Mine/TVAppState、诊断日志、账户或订阅对象，不运行反馈链接/导出操作。中文、英文和iOS辅助字号按同一离线参数选择；TV仍沿现有中文回退，不能宣称完整电视本地化。正式手机中的版本、诊断和反馈入口保留，但不在此预览中操作。连续背景检查沿上节规则，不能代替触控/遥控往返、长文完整滚动、读屏或性能验收。

## Plus概览隔离预览（2026-10-29）

`plus`预览普通状态（移动免费版、电视尚未开放），`plus-active`和`plus-expired`仅提供合成状态，`plus-features`只显示同一组件的功能区。设置预览中的Plus入口也接到此概览。仍不构造EntitlementStore、账户、收据、主题持久化或购买对象，不请求商品/恢复/订阅管理；合成“已开通”不是购买成功或真实权益验收。

`NastartPlusOverview`由正式手机/Pad和TV Plus页直接调用，概览内容和四卡布局共用；宿主只提供实际状态和主题表面。预览也必须挂整个View实例，再用`showsMembership: false`隐藏状态区；不可直接取未挂载实例的子View属性，否则环境字号会读到默认值。普通字号同排等高双列，辅助字号单列。`plus-features`只验功能区，不冒充整页已滚动到底。

电视不接入移动权益状态，正式固定“会员暂未开放”，并说明未提供iCloud同步；预览中的active/expired仅用于样式能力，不作为电视功能上线。移动中英文沿原本地化环境，TV仍用中文回退。正式权益权限判断、Debug既有active默认与发布版状态逻辑未改变。真实隐私设置/账号/缓存/证书动作未挂入此预览。

## 隐私摘要与确认提示预览（2026-10-29）

`privacy`只挂正式三端共用的`NastartPrivacyDataRows`，展示保存范围，不查询实际账号、缓存或连接状态；iOS另有明确标为预览的重置信任按钮。`privacy-reset`在iOS自动打开实际共用`NastartCertificateResetPrompt`，回调仅改内存消息；对话框额外带离线标识，正式提示不带该标识。未构造AppDataStore、TVAppState、CertificatePinStore、Keychain或缓存/网页数据存储对象，也不会执行清除。TV没有新增重置功能，直接同摘要且无该提示。

设置预览中的隐私入口接此摘要。正式手机仍有钥匙串、缓存/导出和快照内容，正式TV仍有连接状态与管理入口；这些不在本场景挂载，不能当完整隐私页或真实状态验收。确认框可用于只读采图；本批不按确认或取消，不能声明动作次数/取消清零/成功提示已做交互验收。

中文、英文及iOS辅助字号沿现有参数，TV沿中文回退。确认提示共用标题/正文/按钮，预览额外标识不等于正式页面文案；截图只证明提示实际出现。模拟器保持串行、保留重试、批后删自建实例，合成偏好哨兵不代替用户偏好验收。

## 大字号媒体详情与宽屏核对（2026-10-29）

`detail-long`使用既有长中英片名合成样本，仍挂真实MediaDetailHero/Heading等组件；`detail-missing`沿原缺图/缺简介夹具。iOS共用Hero由内容决定实际高度，辅助字号上下排海报和文字；海报墙标题辅助字号不限行，普通字号仍保留两行以对齐，TV标题同样预留两行。图片仍是合成渐变/缺图图标，不代表真实NFO、图片下载或演员头像补读验收。

宽屏验证仅在任务自己的Pad模拟器执行：先完成竖屏，核对设备身份后经Simulator界面旋转，随后以截图宽大于高及实际页面文字验证，不旋转图片冒充横屏。不改变App或播放器方向策略；手机普通页面沿原竖屏限制。转向受阻或超时必须记录并清理自建实例，不能给横屏PASS。

截图/OCR与相邻背景采样只说明选定组件的可见布局。完整演员行、滚动返回、真实导航、焦点/VoiceOver、帧时间和播放不在本批静态验收内。TV的Hero与标准标题大小沿原值，不能把预览传入大字号参数当完整电视辅助字号实现。

## 演职人员与离线返回核对（2026-10-29）

`credits`和`credits-missing`直接挂真实MediaDetailPersonCard与MediaPersonPlaceholder，使用长中英姓名、长角色、空角色的合成样本。iOS辅助字号卡宽160/头像高200、姓名角色不限行，普通保持104×132；TV保留160圆头像，姓名/角色最多两行。空角色不添加虚构占位文字。合成人物素材不是服务器头像，不能作图片读取成功结论。

手机Jellyfin人物位通过personPortrait配置共用占位图，其他海报位默认图保持原样；网络库/TV人物位亦用同组件，加载URL、任务、缓存及授权不变。占位图没有“加载失败/永久缺失”的推断文案，不将正在加载等同服务器无图。

往返只在本任务自建手机模拟器的library场景进行：核对窗口与首张海报标识，进入详情后取实际内容/截图，再用已观察到的返回控件回墙。保存前/详情/后证据，必要比较排除状态栏的静态区域。只证明本地夹具导航及静态恢复，不包含真实来源宿主、图片任务、回播或返回动画的完整帧证据；不得据此声称修复海报闪动或流畅PASS。

## 人物横向浏览与电视焦点（2026-10-29）

人物区横向容器现在复用`MediaDetailPeopleScroller`，保留各宿主既有HStack/LazyHStack及人物ID；TV共用12点内边距与17+系统的越界裁剪配置，16保留系统裁剪。网络库人物卡通过`MediaFocusablePerson`成为只读焦点目标；TV Jellyfin沿原FocusState、ScrollViewReader与方向导航，仅复用`MediaPersonFocusFrame`的暖色底色/细边框，不增加无内容的演员详情跳转。手机/Pad保持触控浏览，人物姓名与角色合并为一个辅助阅读元素。

`credits`/`credits-missing`合成人物扩为12项，以便电视也出现首屏外项；人物数量不是实际媒体资料。隔离预览挂网络库相同焦点包装，不能代替真实Jellyfin详情宿主的方向导航验收。输入动作需用实际可见项位移与焦点变化核实；拖动/滚动请求成功却画面不动时，保留未验状态，不判浏览或流畅PASS。静态截图不包含动画/帧时间，VoiceOver亦需另验。

## 演职资料读取状态（2026-10-30）

新增`credits-loading`、`credits-empty`、`credits-error`，直接挂正式三端网络库所用`MediaDetailCreditsNotice`，分别显示读取中、成功读取但未提供人物、读取未完成。只有loading带装饰性进度图标，缺资料/错误不摆空头像框、不伪造人物，也不推断单张头像是否加载失败。三场景为固定状态，无计时任务、请求或自动状态跳转，不能据此声称实际请求/重试验收。

正式NetworkLocalMediaDetail对NFO补读和服务器人物补读分别使用MediaDetailReadState，身份和每次读取的Ticket隔离结果；Task取消及身份切换也在应用数据前检查。已有可见人物优先显示，不被补充加载状态遮挡。相同影片重试的旧Ticket也不能结束新请求。纯状态测试覆盖陈旧结果、取消、同身份重试和空/失败区分；页面仍需NAS恢复后核真实源的取消/往返/错误表现。

这批未改变WebDAV编辑/保存实现。既有LibraryFolderEditingTests和SavedConnectionTests使用临时目录、专属UserDefaults及内存只读源，验证取消/失败/过期事务保留旧索引；不是Keychain、真实表单或服务器兼容性验收。完整人物横滑/TV焦点移动仍沿上批未验，禁止以这三种静态提示闭合。

## 修改媒体文件夹的隔离预览（2026-10-30）

`folder-edit`为路径未变，`folder-edit-changed`为已选不同路径，`folder-edit-error`和`folder-edit-busy`分别固定错误/忙碌状态。直接挂正式`NetworkFolderEditorForm`，相同的当前库名/路径、新路径、浏览、主操作/取消与说明；只传合成字符串，不构造NetworkLibrary、NetworkLibrariesModel、Keychain、源客户端或索引。固定底部“合成文件夹”是预览额外标记，不能当正式界面的一部分。

路径相同（含等价斜杠）或空白时禁用保存；实际模型亦在凭据、扫描及新库身份分配前用replacementForFolderEdit阻止等价路径替换。非法非空路径仍可提交以返回原格式错误。字面百分号、空格和大小写不被随意规范成同一路径，目录本身不会改名或改结构。

预览浏览回调只选合成路径，保存只用DAVPath检查格式，取消只改内存说明；均不是正式目录选择、保存、取消事务验收。正式编辑页继续原原子替换/取消与同源约束，提交时冻结本次路径，失败后改路径会清旧提示。之前的WebDAV连接编辑/目录选择器未改；不能以文件夹表单预览称整个连接流程已验。

截图必须注明可见范围；大字号页可能只看到错误/当前文件夹/路径区，没看到主操作时不能声称已核按钮或滚到底。正常/忙碌/未修改状态的预期提示与“合成文件夹”分别核，静态截图不代表点击/焦点、键盘或原配置写入结果。

## 剧集行与简介阅读（2026-10-30）

`episodes`在iOS直接挂正式MediaEpisodeRow：普通/长中英标题、无编号/缺图、合成进度条等四项；移动Jellyfin与网络季列表共用此行。TV改挂与正式网络季页、TV Jellyfin相同的MediaPosterGridLayout/MediaPosterGrid/MediaPosterCard（16:9）和MediaPosterFocusStyle，7合成项覆盖长标题、缺图、无编号/奇数末行，使用默认4列且不读正式偏好。正式两电视入口读取同一密度偏好。所有图片仍为渐变/符号，无真实加载器、库model/store或播放；系统焦点与JF已有自定义方向逻辑不可凭截图称验收。

`overview`在真实MediaDetailSummary上传入固定长文和3行限制；iOS辅助字号取消行数上限，样本尾句用于核查实际可见的完整阅读。`overview-empty`输入纯空格/换行/Tab，下一段样本直接接续，不出现“暂无简介”或空简介标题。正式移动宿主仍各持标题/展开回调，但共用normalized判断，空白不建节、辅助字号不留无效展开操作。TV普通保留原折叠策略，Summary正文用宿主语义颜色，Hero暗环境仍白色、浅色页可读。

普通/辅助字号及缺数据的截图只说明所选组件可见区域；未见到的长行、列表末项和展开/返回/焦点、实际服务器资料不能据此验收。季/剧列表与海报副标题明确“视频文件”数量，不将分段/多版本文件数量冒充唯一剧集数，分类/聚合/季集模型及文件不变。实际多版本识别/选择仍待后续，不算已完成。

## 入口与隔离

只在已核实的Debug包启用。普通启动不带参数；Release不编译场景及其数据，**不能给Release传这些参数并假定它已隔离**。iPhone/iPad的NastartApp、电视NastartTVApp先解析场景，再选择NastartOfflineUIRoot或原应用内容；原AppData/账号/同步/AppearanceStore和TVAppState只在原应用分支创建。

离线根只使用AppTheme静态token、NetworkMediaAppearance和纯内存场景。没有NetworkLibrariesModel、Keychain、NAS源、URLSession/网络客户端、图片下载器或持久化写入。没有播放动作；刷新与重试只改内存计数，所有资料与渐变/图标海报均合成。此边界针对本场景代码，不是全应用或操作系统零网络的抓包结论。

启动参数：

```text
--offline-ui library --offline-ui-theme glassDeck --offline-ui-appearance dark
```

| 参数 | 值 |
|---|---|
| --offline-ui | library、detail、detail-long、detail-missing、credits、credits-missing、credits-loading、credits-empty、credits-error、folder-edit、folder-edit-changed、folder-edit-error、folder-edit-busy、files-segments、files-disc、file-info、file-info-empty、playback-iso、playback-source、playback-unsupported、episodes、overview、overview-empty、missing、empty、disconnected、error、settings、player-settings、help、help-detail、plus、plus-active、plus-expired、plus-features、privacy、privacy-reset、privacy-cache、privacy-export、sync-settings、mine-info、diagnostics、account-connections；连接6场景见上节 |
| --offline-ui-theme | cleanGrid、commandCenter、glassDeck；默认cleanGrid |
| --offline-ui-appearance | light、dark；默认light |
| --offline-ui-text-size | standard、large；默认standard |

明确带模式参数但值错误、缺值、重复或等号形式时显示隔离的参数错误页，不回落到正常应用。只有theme参数不启用离线模式。勿在有用户配置的普通设备试错参数；优先任务专属、全新无账号模拟器。当前iPhone18使用中不操作，按用户最新要求全部真机调试延后。

## 复用范围

同一个OfflineMediaScene/OfflineMediaFixture被两App调用，实际复用MediaPosterGridLayout、MediaPosterGrid、MediaPosterCard、MediaPosterFocusStyle、MediaLibraryHeading/Menu、MediaDetailHero/Heading/Facts/ActionRow/Summary/Section/Information/PersonCard/Disclosure。七个固定作品涵盖奇数、长中英标题、缺年份与缺海报；详情提供有/无简介、制作信息和人物图的组合。选择海报可进入同组件详情，但本批没有执行触摸/遥控往返验收。

空库/断开/失败页目前是夹具内的状态样本，不声称已从每个生产入口抽成同一个空态组件。主题来自实际静态token，未创建持久化AppearanceStore；不等于原主题权限/偏好功能已验。大字、Pad横屏/分屏、实际头像滚动和子页返回仍待扩充。

## 可重复的核对顺序

1. 冻结源码/Debug包。创建本任务专属的手机、平板、电视模拟器，安装对应模拟器产物，保存包哈希和运行时身份；不使用旧NAS账号或迁移用户偏好。
2. 用已知值设置任务自己的偏好哨兵；它不是用户的偏好。按三种主题的library，再detail、detail-missing、missing、empty、error、disconnected、错误参数页执行。每台10窗。
3. 每个窗口必须确认实际页面文字与“合成资料”标识。启动成功、非空白像素或固定等候不足以证明到页；保存失败和重试，OCR仅辅助判到页，不能替代视觉质量/交互判断。
4. 观察长标题/年份对齐、海报尺寸、缺图和资料缺失的层级。完整帧时间/焦点/返回路径另测，不把截图当滚动流畅验收。
5. 结束每窗只停止自己的进程；结束整批回读哨兵，关闭并删除任务自己创建的模拟器，保留图片和原始失败在仓库外。不要改、关或删除其他模拟器。

## 当前覆盖及后续

本批iPhone18 Pro/iPad(A16)的iOS27模拟器、1080p AppleTV4K三代/tvOS27模拟器各10窗，30份最终截图均有预期标题与合成资料标识；仅部分图片人工实看。4项配置/边界测试、双端模拟器Debug、普通签名Debug及无签名Release编译过。3个模拟器的任务哨兵保持，不能代替用户设备偏好验收。没有真机安装或控制、NAS连接、影片播放、帧时间和性能PASS。

先补三端设置/连接表单的隔离场景，再统一字号、间距、按钮及状态组件；媒体页还需补横屏/大字、人物区滚动、真实导航返回及无图时的内容密度。当前夹具导航标题/背景是调试承载，不将其当生产页视觉成果。用户要求未来数日专注细节，全部真机/NAS联调待恢复后继续。


2026-10-30 [电视季网格有限结果](../archive/handoffs/2026-10/2026-10-30-TV-SEASON-POSTER-GRID.md)：TV三主题静态窗及手机/Pad辅助字号各1，共5窗，图hash及背景核过；24既有测试/编译核签通过。截图完整前缀含场景/主题/深浅/字号；3自建实例清，无真实设备/NAS，真实方向与滚动未验。


## 多文件选择区（2026-10-30）

`files-segments`与`files-disc`挂正式MediaDetailFileSelection/MediaDetailFileRow，分段2项含长文件名和未知容量，内部文件3项含无动作ISO行。可用按钮仅增内存计数，技术信息沿正式折叠；没有正式账户、model/store/client或播放器。此场景不意味着ISO/主片/自动续播支持。六静态窗和构建结果见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-MULTI-FILE-SELECTION.md)，实际点击/方向/滚动/读屏未验；按主题/深浅/字号区分采图前缀并逐图核hash。


## 共用文件字段（2026-10-30）

`file-info`挂正式MediaDetailMetadataRows/Row/FileProperties，Disclosure仅此合成预览initiallyExpanded=true，正式默认false保持。样本含长名/目录、合成NFO、24GB/48Mbps；`file-info-empty`用纯空白和负容量/零码率直接下一段，核无空字段/空折叠。无正式model/store/client/媒体读取。三端6静态窗、本机TV精确源码模型/方向函数有限检查及构建见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-FILE-INFORMATION.md)；不等同实际按钮展开/遥控、完整滚动或真实服务资料验收。


## 已有播放限制说明（2026-10-30）

`playback-iso`、`playback-source`、`playback-unsupported`挂正式MediaDetailPlaybackNotice及不可用MediaDetailFileRow，使用ISO/MKV/BIN合成名和说明；无播放动作/来源model，不证明真实来源能力或格式索引支持。旧files-disc的合成ISO行同步指定ISO原因。9静态窗、4参数测试及构建结果见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-PLAYBACK-LIMITATION-NOTICES.md)；没有真实canPlay/播放/滚动/遥控/读屏验收。初次编译后只精确修正BIN样本名，再重建UI产品；原构建保留，参数测试输入未变。初轮实图复核发现离线样例白标题在浅色背景不可读，已改为语义色样例标题并重建模拟器/原生产品、替换全部9窗；原图与记录保留但排除最终证据。


## 本机资料修改表单（2026-10-30）

`correction-movie`、`correction-episode`、`correction-error`、`correction-busy`挂正式NetworkMediaCorrectionForm，字段/季集条件/状态/按钮沿正式组件，原识别区仅合成文字。所有字段和回调仅在内存，保存/恢复只更新预览消息，不构造正式model/store/client，不验证真实事务；忙碌场景固定状态，不启动后台任务。手机/Pad大字错误首屏外的操作不算可见，键盘、类型切换、错误清除、取消/保存/恢复和遥控返回都未作交互验收。12最终静态窗及初OCR图标干扰排除/仅补缺记录见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-LOCAL-CORRECTION-FORM.md)。


## 文件夹选择展示（2026-10-30）

`folder-picker`、`folder-picker-empty`、`folder-picker-root`、`folder-picker-loading`、`folder-picker-error`、`folder-picker-selection-error`、`folder-picker-busy`直接挂正式NetworkFolderPickerPage；只有合成路径/目录与内存提示，固定加载/错误/忙碌状态不启动Task，不构造正式控制器/model/store/client或凭据。13静态窗及范围见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-FOLDER-PICKER-STATES.md)；不把样例的重试/选目录/保存按钮称真实事务或旧响应隔离已实测，也不以首屏代替完整滚动。根不可选/没有子文件夹与没有视频必须区分。


## 连接管理分组（2026-10-30）

`connections`、`connections-empty`、`connections-storage`挂正式NetworkConnectionsPage及StoredConnection/MediaFolder行，分别展示完整分组、无连接、仅存储；无媒体服务入口时隐藏服务组。同名合成文件夹的来源不同，字段不是正式模型映射结果。没有model/store/client/Keychain或实际导航/持久化。9最终窗与初轮排除、重新构建采图见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-CONNECTION-INVENTORY.md)，不能作为真实账号/来源映射、遥控/滚动/性能验收。


## 添加连接选择（2026-10-30）

`source-add`、`source-add-empty`、`source-add-connection`直接挂正式NetworkSourceAddPage/连接行/非按钮协议状态，分别是已有连接、没有连接、仅新增存储模式。只有合成文字及空回调，不构造model/store/client/Keychain或Task，不验证实际导航和保存。9最终窗、首Debug提示重叠失败保留排除见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-SOURCE-ADD-CHOICES.md)；首屏外内容/真实滚动焦点仍未验。


## 已有连接准备（2026-10-30）

`existing-preparing`、`existing-error`、`existing-unavailable`直接挂正式NetworkExistingConnectionStatusPage，固定合成来源/类型和原因、回调为空，无model/store/vault/client/Task。仅验证展示，不执行retry/cancel或真实准备。最终TV3窗为2自动+1人工解决OCR漏字，手机/Pad因磁盘预算未启动；初文案图与超时保留，见[本批](../archive/handoffs/2026-10/2026-10-30-EXISTING-CONNECTION-PREPARATION.md)。辅助字号纵排动作只编译，遥控/返回/读屏仍待。


## 连接详情分组（2026-10-30）

`connection-detail`、`connection-detail-empty`、`connection-detail-long`直接挂正式NetworkConnectionDetailsPage及MediaFolder行，纯合成名称/路径与空回调，无model/store/vault/client/Task。最终三端各3窗共9，手机/Pad长例辅助字号；初大字标识重叠已保留/加背景后重采，不称实际导航/编辑/新增/改路径或完整滚动验收，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-CONNECTION-DETAIL-GROUPS.md)。


## 首页整理状态（2026-10-30）

`library-scanning`、`library-updating`、`library-notice`直接挂正式NetworkLibraryStatusSections，固定149/0和合成错误、空取消回调，无model/store/vault/client/Task，不是完整首页。手机/TV各3新窗，另手机existing-preparing/error两窗补之前缺项，共8；Pad5窗因磁盘预算未启动，见[本批](../archive/handoffs/2026-10/2026-10-30-LIBRARY-SCAN-STATUS-PRESENTATION.md)。标识检查要求可见“离线界面测试”和“合成”及该场景关键内容，截图名带实例前缀防覆盖；不等于实际取消/返回或滚动/性能验收。


## 首页/海报墙状态共用（2026-10-30）

`wall-scanning`、`wall-updating`、`wall-notice`挂正式WallStatus卡片及与首页相同的ActivityContent/NoticeContent；固定合成标题/数量/原因/海报区文本、空取消回调，无model/store/vault/client/Task。TV6窗对比三种状态两种承载，手机/Pad共12窗受磁盘预算阻塞，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-AND-WALL-STATUS.md)。不是完整海报墙/菜单/实际取消及遥控验证；RootSection与墙内容共用，旧批手机图不能冒充本批新图。


## 本机库缺失状态（2026-10-30）

`read-loading`、`read-error`、`read-missing`、`read-idle`只挂正式NetworkLibraryAccessStatePage，固定合成phase/说明、空重试和返回，不创建真实model/store/vault/client/Task。加载说明是本机资料而非远端目录；missing表示本机读取完成后无此ID，并非NAS断线。TV新增4状态+既有连接准备/失败共6静态窗，手机/Pad12窗因磁盘预算未建实例；见[本批](../archive/handoffs/2026-10/2026-10-30-LOCAL-LIBRARY-READ-STATES.md)。3条纯状态请求归属测试+4既有参数测试，不等价于真实refresh/迁移/取消/返回验收。


## 首页本机读取恢复（2026-10-30）

`home-read-error/loading/idle/combined/ready`挂正式StatusSections/LocalReadContent与合成库ActionLabel；combined同显操作错误与本机错误，ready没有本机状态，其他首页状态不多放内联返回。5新场景+原`read-error`/`existing-error`共TV7静态窗，手机/Pad14窗因磁盘预算未建实例；[本批](../archive/handoffs/2026-10/2026-10-30-HOME-LOCAL-READ-RECOVERY.md)。固定phase/消息/149计数、空回调，无model/store/vault/client/Task/网络。7既有纯状态/参数测试与编译不等实际首页.task重试、取消、真实库保持或遥控验收。


## 首页/墙读取恢复共用（2026-10-30）

新增`wall-read-error/loading/idle/combined/ready/scanning`仍用既有OfflineWallStatusScene，正式WallStatus与首页同一个LocalReadContent。scanning同时有149文件/取消扫描与本机失败/重试；ready不挂状态，合成海报区持续可见。另核home-read-error、旧wall-scanning，共三端计划24窗；三端24静态窗均预算阻塞、0实例，尚无本批新图，[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-WALL-READ-RECOVERY.md)。固定phase/字符串/空回调，无真实model/store/vault/client/Task/图片/目录。参数和纯请求状态7测试，不等墙新增UUID任务/取消/返回或实际扫描验收。


## 分类/空搜索（2026-10-30）

`wall-category-fallback/search-empty/index-empty/extras-hidden`用合成CatalogItem/Group/Entry喂正式MediaWallSelection，正式空态或共用海报网格；回退用已消失的电视剧偏好，分类文字是解析结果而非真实分类栏。清除/展开为空回调，无model/store/vault/client/Task/目录/图片请求。三端12窗均预算不足、0实例/0图；9新选择+18既有测试共27过，见[本批](../archive/handoffs/2026-10/2026-10-30-WALL-CATEGORY-AND-EMPTY-SELECTION.md)，不等实际onAppear/onChange、焦点、点击或新画面验收。


## 共用媒体空态（2026-10-30）

`media-empty-library/search/error/long`直接挂正式MediaLibraryEmptyState，合成Text与空动作；另核wall-search-empty包装。初15窗预算阻塞留档，空间恢复后只补TV5静态窗、1实例清，手机Pad10窗仍待，[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-MEDIA-EMPTY-PRESENTATION.md)。无model/store/vault/client/Task/网络；4既有参数测试不等真实JF本地化/分支、按钮、焦点或像素验证，旧图不补算。


## 首次/保留内容失败提示（2026-10-30）

`media-failure-initial/retained/long`挂正式EmptyState/Notice；retained/long只有两个合成缩略卡/固定文本/空动作，样式沿NetworkTVCompactStyle，非真实TVTileStyle和TVMediaGrid。另核library-notice/wall-notice实际包装，TV5静态窗、1实例清，手机Pad10窗预算阻塞，[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-MEDIA-LOAD-FAILURE.md)。无model/store/vault/client/Task/网络；4参数测试/静态图不等真实分页、保留、点击、滚动/焦点或播放。

补验更新：空间恢复后同包补验，本批15静态窗：12过/3未过（TV5/手机3/Pad4），4实例清；首次预算阻塞与失败均保留。手机长大字按钮落首屏下方未核滚动，失败墙预览缺标题；正文可见不代替整窗通过，初期受阻/超时仍留档。源码/候选同，真实分页/操作未验。


## 标题互斥与长提示滚动（2026-10-30）

wall-notice的iOS库名与TV空导航标题用互斥分支，避免空串标题遮掉库名，正式墙同步修复。三端各1窗过；media-failure-long辅助字号经cua_repl有限输入仍无合格位移，按钮可达性未通过；工具返回不代替实际位移，不按“首屏外”等同布局坏，也不以静态图判流畅/真实重试。旧失败留档，见[本批](../archive/handoffs/2026-10/2026-10-30-WALL-NAVIGATION-TITLE.md)。


## 首页失败提示（2026-10-30）

home-load-empty/retained挂正式MediaLibraryLoadFailure，home-load-shelf挂Notice；两个固定合成卡/空重试，无model/store/client/Task/真实图，TV用预览按钮样式而非App TVTileStyle。三端各3共9静态窗、4既有参数测试过，见[本批](../archive/handoffs/2026-10/2026-10-30-SHARED-HOME-LOAD-PRESENTATION.md)。只能核组件可见区域，真实首页缓存/刷新/部分失败、按钮/滚动/焦点不能凭此验收。


## 缓存内容展示（2026-10-31）

content-loading/loading-retained/error/error-retained/error-search/empty挂正式MediaLibraryContent；固定两合成卡/空态、空操作，无model/store/client/Task。手机/Pad各6、TV两错误态，共14静态窗，4既有参数测试过，见[本批](../archive/handoffs/2026-10/2026-10-31-CACHED-CONTENT-PRESENTATION.md)。可核首加载不露成功空态、缓存内容不被加载/错误替换、过滤无结果区别；不等真实状态转换/集合季列表/图片身份/回调/焦点或帧时间验收。


## 搜索重试与暗Hero提示（2026-10-31）

search-retry挂带空恢复动作的正式EmptyState，detail-notice在合成Hero内挂Notice并指定dark；三端各3共9静态窗过，见[本批](../archive/handoffs/2026-10/2026-10-31-SEARCH-REQUEST-OWNERSHIP.md)。无真实搜索状态/store/model/client/Task，实际同词重试/竞态由后续真机验证；纯代次回归3不替代网络，TV预览按钮不代替生产TVTileStyle焦点。


## 演职状态三端一致性（2026-10-31）

沿原credits-loading/empty/error/missing四场景各端4窗，新related-notice仅TV1，共13窗；公开后仍同组件/字体/标识，人物名存在而照片缺失不展示“无人员”。相关提示仅固定两卡/空恢复动作，见[本批](../archive/handoffs/2026-10/2026-10-31-CREDITS-STATE-PARITY.md)。无真实详情方法/model/store/client/Task，不能验人物请求/动态状态/头像或TVTileStyle方向，12既有逻辑/参数回归不替代这些。


## 电视详情方向键隔离（2026-10-31）

detail-focus-retry/empty/only由TV App最外层early分支挂TVDetailFocusOfflineScene，先于普通TVAppState；iOS仅隔离提示。真实样式/共享方向图/焦点绑定/文件Disclosure配固定卡与内存重试，无client/store/vault/网络Task；不能用旧tv-exit-probe客户端fixture替代。3唯一XCUIRemote方向/Select用例过，19单元过，1附件实看，见[本批](../archive/handoffs/2026-10/2026-10-31-TV-DETAIL-RETRY-FOCUS.md)。初收尾旧容器路径错误保留，第二专属实例重新取路径核身份/哨兵通过，两实例清；不判全详情/触摸板/中间焦点或流畅。


## 顶部动作移除隔离（2026-10-31）

detail-focus-actions继续在TV App early分支，iOS只隔离提示。固定内存详情retry与合成简介更新，真实MediaDetailActionRow/共享retry样式/焦点图/FocusState；无client/store/vault/网络或媒体Task。简介Select后移除只模拟资料变化，不代表正式简介展开行为。新增1XCUIRemote用例和原3回归过，24单元过；两个附件实看，1实例清，见[本批](../archive/handoffs/2026-10/2026-10-31-TV-DETAIL-ACTION-FOCUS.md)。不判正式client页面、真实资料/长行/触摸板/中间焦点/帧时间或播放。


## 网络多文件焦点隔离（2026-10-31）

network-focus-files/read-only用已有early根，正式共享MediaDetailFocusScope及文件/人物/折叠控件，只有固定资料和内存计数，无model/client/store/媒体或网络Task。移动同参数为隔离提示；合成简介移除模拟资料更新。5新单元+24旧=29过，2新遥控+4旧=6最终过；前两轮各5过1失败保留，人物defaultFocus/新revision补救修正后同断言补核，三实例清。见[本批](../archive/handoffs/2026-10/2026-10-31-NETWORK-DETAIL-FILE-FOCUS.md)；不判正式model页、真实替换、长列表/触摸板/帧时间、编辑或播放返回。


## 动态详情与长行隔离（2026-10-31）

network-focus-dynamic/long用early根和正式Scope/FocusSession/文件/人物/折叠组件；无client/model/store/网络/媒体Task。动态Select/PlayPause仅改内存能力与名单，假imageID不请求图片；长行12文件/18人物逐次真实方向/焦点/命中/视口断言，并记录实际纵向527点位移。39单元（29旧+10新）、4最终唯一UI（2旧+2新）过，前4轮失败/包保留，5任务实例清。详见[本批](../archive/handoffs/2026-10/2026-10-31-DYNAMIC-DETAIL-FOCUS-AND-LONG-ROWS.md)。不等于真实异步服务/头像、触摸板/帧时间、编辑sheet/播放器返回验收。


## 详情弹层返回反例（2026-10-31）

network-focus-presentation仅TV early根合成sheet/fullScreenCover/内存次数，复用Scope和文件/折叠组件，不创建编辑器、播放器或client；iOS为隔离提示。2新遥控用例核关闭按钮/Menu后的焦点与次数及跨区记忆；两轮4例分别3过1失败、2过2失败，动态恢复及sheet后续文件记忆未稳定，实验回退后停调。此前4例成功窗口不能当稳定结论，详见[本批](../archive/handoffs/2026-10/2026-10-31-DETAIL-PRESENTATION-RETURN-AND-FOCUS-REGRESSION.md)；真实媒体返回、图片闪动、移动位置及性能仍未验。


## 原生焦点事件诊断（2026-10-31）

只有network-focus-dynamic/presentation且显式--offline-focus-trace启用Debug TV匿名有界JSONL，不写可观察状态/焦点/账号，Release不编译writer。testOfflineDynamicFocusDiagnosticWindow调用原断言且不增唯一覆盖。先采3诊断窗口（50/104/149事件）并保留2失败，普通第一修正6例5过1失败保留；确认源事件晚到与已确认目标记忆遗漏后，最终无trace参数6唯一UI过、fresh2例重复过且无诊断文件。41单元含2时序反例，6任务实例清，见[本批](../archive/handoffs/2026-10/2026-10-31-NATIVE-FOCUS-EVENT-ORDER-AND-MEMORY.md)；真实服务器/图片/编辑播放器/移动位置及帧时间仍未验。


## 共用WebDAV字段语义（2026-10-31）

6输入框显式accessibilityLabel，地址/端口/路径3提示，添加/编辑与三端复用；本批只源码/六配置编译、0模拟器，不把旧静态窗或焦点测试当本批读屏/键盘验收。下一复用connection及connection-edit/error隔离根检查实际操作，见[本批](../archive/handoffs/2026-10/2026-10-31-SHARED-WEBDAV-FIELD-ACCESSIBILITY.md)。


## 连接表单交互反例（2026-10-31）

原生AX字段语义/Pad大字号非法端口更正/合成取消及TV操作区静态图补观察（动作未验）；完整Next链/读屏朗读/真实事务仍未验。密码显隐丢键盘，两种试改都未通过值与连续输入完整回归，均撤回，445原输入全同；5实例清。保留[本批失败及边界](../archive/handoffs/2026-10/2026-10-31-CONNECTION-FORM-INTERACTION-AND-PASSWORD-REGRESSION.md)，下一诊断不添加焦点重试，不把夹具格式通过当网络连接成功。

## 密码事件隔离（2026-10-31）

显式--offline-password-trace只在early合成连接表单且Debug iOS启用，不读密码内容/长度/选区，不改变焦点决策，默认关闭、Release无writer。15/27事件区分原控件替换与旧桥接状态不一致；原生回调定向候选在无诊断手机窗保持输入，但Pad大字号替换初值失败，整项撤回。最终fresh正常手机确认旧键盘丢失仍在且无trace文件，不能称修复过。5实例清，见[诊断及失败](../archive/handoffs/2026-10/2026-10-31-PASSWORD-INPUT-EVENT-DIAGNOSIS.md)；无新增自动化覆盖，真实事务/读屏/TV输入仍待。

## 文件夹编辑实际操作（2026-10-31）

同最终446输入fresh手机folder-edit原生AX操作，原/等价尾斜杠路径禁用保存；合成浏览启用，非法父跳转路径提交提示，改路径清错，取消后重提本地反馈可见，原目录文本保持。键盘打开时AX Scroll Down使保存可达；不判流畅/读屏或真实目录浏览/事务。夹具旧提示可与新错同存、回调不dismiss/不收键盘，作为夹具边界待补；1实例清、hash/哨兵保持，无trace。见[结构结果](results/2026-10/2026-10-31-folder-editor-interaction.json)。

## 目录反馈与遥控（2026-10-31）

folder-edit夹具note改为空初始/改草稿与验证开始清旧note/取消清旧错，正式共用note仅加标识，无事务变化。TV两新增XCUIRemote例检查真实方向焦点与Select、保存禁用/合成浏览/反馈/取消/返回，2过且2附件实看；无client/model/store/vault/网络Task，无trace，不能当真实目录或TV文本输入。手机与Pad大字首屏/浏览/本地校验观察到，均在键盘输入阶段触2GiB运行线主动退出，完整错误/重提未验；两次中断停止移动重试，下一至少6GiB可用空间，3实例清，见[本批](../archive/handoffs/2026-10/2026-10-31-FOLDER-EDITOR-FEEDBACK-AND-REMOTE.md)。
