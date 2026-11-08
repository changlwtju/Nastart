# Claude 11-03 晚间 UI 二次集成与最新包静态回归

2026-11-03。响应[第二次集成请求](2026-11-03-1945-CLAUDE-INTEGRATION-REQUEST-2.md)，基线 `codex/ui-integration-20261103` / `3a4e68b`。第一次四文件接受提交 `f231962e`，真机审查后窄屏导航收紧的单文件增量 `1fbad71e`；未推送。主目录 HEAD `4de732dd`、真实 index 及其它 dirty 保留。447项扫描清单冻结稳定，相对接受清单443同/4变；审查树跟踪的ios/tvos源码和资源与工作区同，只有README文档差异。清单含179项继承Demo/Pods扫描材料，不在审查树中，未声称干净检出即可独立构建。结果见[结构化记录](../../../testing/results/2026-11/CODEX-CLAUDE-UI-INTEGRATION-2-20261103.json)，原始材料仅本机 `/tmp/nastart-codex-ui-integration2-path`。

## 增量与来源

| 文件 | 基线 SHA 前16 | Claude 交付 | 最终接受 |
| --- | --- | --- | --- |
| `Localizable.strings` | `2007a5fb9a27283c` | `508d8b05041afd04` | `508d8b05041afd04` |
| `LibraryViews.swift` | `630447404a474191` | `fb7b4a00b947751e` | `1fbd58484a41abed` |
| `MediaDetailPresentation.swift` | `467eb63d8bca1468` | `ce15f138a5b3223a` | `ce15f138a5b3223a` |
| `SourceContext.swift` | `1fdefee5d6c3f9b6` | `b05159530b4655f7` | `b05159530b4655f7` |

交付时全部 ios/tvos 已跟踪文件仅这四项及 `ios/README.md` 不同，四项均与 Claude 请求的哈希一致。README 当前 SHA `b44ee7c8945599e850728fb7093e6b53b14a6a5678557a379b56e3f3f464be66`，与独立的 11-01 OfflineUI 快照及多个 11-02 快照逐字节相同，已证明早于本批。内容是 10-19 当前播放路线提示与三个迁移后的诊断文档路径；[10-17 整理记录](../2026-10/2026-10-17-BANDWIDTH-BODY-AND-ORGANIZATION.md)也记载过 README 链接调整。无法仅凭这些未提交历史可靠确认最初作者，不归到 Claude 本批。保持这项继承 dirty，不把跨文档迁移混入四文件 UI 提交。

## 审查决定

- `NetworkContentPage`：实际 19 个调用点，含 3 个仅 DEBUG 的状态/连接操作场景；其余 16 个生产调用可派生多种目的页，并非已逐页验收的“20 页”。分布为存储首页、媒体服务/连接管理、文件夹编辑/选择、库状态、资料编辑、添加来源、WebDAV 表单、连接详情/准备状态，以及季/剧集和媒体服务详情。调用清单/位置保存在结构化记录。
- iOS17+ regular 采用 `max(0,(窗口宽−720)/2)` 的横向 scroll-content margins 和 inline 小标题。背景/滚动区域保持整窗，List 原生行内距仍存在，因此称约 720pt；窄于 720 的 regular 窗不产生负边距，仍用小标题。compact 与 iOS16 不进入新分支；tvOS 分支不变。接受此范围，不推断分屏/所有页面/辅助字号均已验完。
- `MediaDetailHero` 的 820pt 内层、18pt padding、全宽外层居中，与正式详情正文 `min(820,W−36)` 后加 18pt padding 的顺序一致；背景仍全宽。iPhone 窄屏保持自适应。离线 detail 的正文是测试外壳自己的布局；A16竖屏内层也未超过820pt，不拿它替代正式详情正文对齐/限宽上限/横屏验收。
- 文件夹路径通过同一页面内 `history/current` 切换，不是每层一个 NavigationStack entry；自定义返回先退历史，再退父目录/root callback，系统 pop 则退出上一导航层，不能承诺逐级返回。仅 `backTitle != nil` 时隐藏系统返回，接受同时不能系统侧滑 pop 的明确取舍；父页取消入口、保存期间返回/取消禁用仍保留。没有全局修改 UINavigationController 手势。Claude 的模拟器按钮结果与本轮真机静态结果分开；真机没有注入点击/侧滑，UX-08/09 不关闭。
- **Codex 一处布局收紧**：候选1的 iPhone13 标准字号 folder-picker 返回文字占用较多导航空间；原始分辨率复核标题完整、无重叠，**不认定已证实的截断缺陷**；compact 改为自定义 chevron，保留完整 accessibilityLabel 和原 action/identifier/disabled。regular iPad 继续文字按钮，tvOS 保持原码。最终包手机实图标题完整、返回箭头单一；不以图像宣称按钮动作/完整 VoiceOver 已通过。

## 构建、包与两机回归

初次候选完整构建/核签并保留安装到两机；审查手机导航布局后，候选1的材料全部保存在私有 `candidate1/`，明确 superseded，不用于最终源回归。最终源重跑六配置全部 exit0；两端 Release 各 27 调试标记零、Debug 正对照通过；中文 strings lint、提交 diff check 通过。Claude 报告的 305 项包单测是其交付证据，本轮 iOS 展示修正没有重新跑包/宿主测试，不沿用旧宿主 202+1 作为新 UI 通过证据。

正常 Debug -Onone 使用既有自动签名、未申请 profile 更新、无测试环境变量；显式安全离线参数单列。构建日志窗口 `2026-11-03T23:31:16.686070+08:00` 至 `2026-11-03T23:32:10.407660+08:00`，封包核验 `2026-11-03T23:32:15.563445+08:00`。main `2090db4219666643c062b899ab376d7d1cc1edfd2dc164ca6909f6f3d1919c6b`；Debug dylib `8a1e979bb59c4a593068e8150a9b34bbd825a8a45ad7eec47cbbf33f2afe7605`；IPA `96f99d5021b113a1dee1977dc61e295299294fe6bd7b3ac90f19b7f187dbc23e`。30 Mach-O 签名、deep/strict、profile 有效期/目标覆盖、IPA 成员/CRC/二进制一致性逐机安装前均核过；profile 到 `2026-11-08T01:08:19Z`。App/IPA 固定在本批私有 normal-package，不能使用旧共享 DD 路径判断身份。

| 设备 | 最终包保留安装 | 偏好 | 实图窗口 | 边界 |
| --- | --- | --- | --- | --- |
| iPhone13 / iOS16.3.1 / USB | 2026-11-03T23:32:41.775686+08:00；InstallComplete + fresh lookup | 26项非诊断与全部值同 | 首页、添加来源、文件夹标准/忙碌大字、detail，共5窗 | 返回箭头/标题完整，忙碌外观；未点击/侧滑/VoiceOver |
| A16 iPad / iPadOS26.6 / wired | 2026-11-03T23:33:14.962592+08:00；CoreDevice success + fresh lookup | 19项非诊断与全部值同 | 首页、连接管理、添加来源大字、表单、文件夹标准/忙碌大字、detail，共7窗 | 居中列/小标题与文字返回可见；未旋转/点击/正式详情正文 |

每台安装与启动前均 fresh 核设备名称/型号/系统/完整 UDID/连接（原值私存），核包后保存必要诊断/全偏好。候选1与最终覆盖窗均fresh核实际进程；发现Nastart时精确核安装bundle的实际可执行路径、保存偏好、立即复核PID/路径后才原生停止，安装派发前均确认无Nastart进程。没有卸载/清登录。每个离线窗口均环境为空、明确场景/主题/字号/语言，有 PID、实图并已实际查看，finally 仅停本方 App；最终两机 Nastart 0，全部偏好同。两机未启动普通账号根，未改网络/系统/凭据；NAS0、蜂窝0、18/TV操作0。

## 未完成与收尾

iPhone13 开始未连 USB，用户接回后重新枚举并确认再继续。现有 13 Runner profile 已于 10-25 过期；现有旧 iPad Runner profile 10-03 过期且不含 fresh A16，已重新本机核签名材料，不部署/重签或借旧 Runner 声称输入就绪。按钮逐级返回/取消、真实导航侧滑、横竖/分屏、完整读屏与帧时间仍待有效且覆盖目标的交互窗口；真实媒体服务与目录流程仍受 NAS 暂停约束。此前 Claude 合成 loopback 截图不是这些真机项的替代。

资源窗口已按实际清理释放；本批不创建/删除模拟器，不清他人缓存、不操作 Claude 对话/权限、不新建周期任务。核对 DEVELOPMENT_STATUS、当前交接、PROGRESS、唯一需求总账及播放矩阵：这批不改播放解析/引擎/请求路线，VIDEO_PLAYBACK_PIPELINE 无实现变化无需制造更新；30项开放、114格无新P，旧失败保留。最终登记门禁曾错误假设447项都在审查树，写共享文档前即拒绝；核实为268项跟踪扫描输入及179项未变的继承Demo材料，改以审查树实际ios/tvos逐项比对（仅README不同）与447冻结清单双重核对。此工具断言失败保留，不当产品失败。文档检查通过：659 documents / 3935 local links，Missing destinations: 0。
