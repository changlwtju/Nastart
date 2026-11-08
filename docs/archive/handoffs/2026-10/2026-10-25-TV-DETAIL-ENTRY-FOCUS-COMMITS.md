# TV 详情首项入口与真实焦点提交

核对日期：2026-10-25。[本批安全结果](../../../testing/results/2026-10/2026-10-25-TV-DETAIL-ENTRY-FOCUS-COMMITS.json)。私有指针 `/tmp/nastart-detail-entry-evidence`，原始设备身份、包、截图、源快照和诊断均留仓库外。[所有分支总交接](2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)已补全，旧项目未提交修改保持。

## 用户要求与旧验收缺口

播放操作 Down 应直接进入第一演员；相似片曾浏览到后面，Up→Up 回播放区，再 Down→Down 必须进入第一演员及第一相似片。向上仍返回原演员/动作。上一轮三秒内最终 hasFocus 与“记住相似片”的预期不满足此要求，历史结果加了明确后续复核说明，未删除失败或重写旧通过。

本轮首先立即赋 FocusState 仍捕获两个真实原生焦点提交，局部帧依次为演员第二项 x220、第一项 x12；同步请求本身不能解决。测试仪表初期拿不到 SwiftUI 焦点项标识/坐标，保留为仪表失败，不能冒充产品失败或无闪跳通过。修正为 UIFocusSystem.didUpdateNotification、公开 parentFocusEnvironment/coordinateSpace 与 DEBUG 几何映射，记录**每次引擎实际提交**，未知项亦失败。

## 实际实现

TVViews.TVDetailView 给 hero、演员、相似片各区域设置 `.defaultFocus(..., priority: .userInitiated)`，系统在进入区域时直接评估语义入口，而不是先空间选到邻项再纠正。hero使用最后动作；演员从hero进入取首位，从相似片向上取原演员；相似片向下总取首片，移除 lastSimilarFocus 续入规则。onMoveCommand同步目标，保留既有请求匹配保护及最小揭示，未加延迟常量或强制居中。

参考 [Apple defaultFocus 文档](https://developer.apple.com/documentation/swiftui/view/defaultfocus(_:_:priority:)) 的 userInitiated 语义；只对详情横排上下文启用。首页大列表继续LazyHStack。详情演员最多20、相似片服务端Limit12，改HStack保持真实焦点项挂载；此前严格测试发现横向首次越过屏幕时懒占位项先提交，不能把它当作具体演员。此修改有提前创建这些小型横排/图片请求的成本，尚无完整内存/帧时间结论。

TVLaunchTests.testOrderedDetailFocusRoundTrip逐键比较具体最终ID及本键新增的**所有原生提交ID**，任何错误中间项都失败；补全返回顶部再Down→Down首相似片与屏幕外首尾。DEBUG fixture仍使用真实TVDetailView，仅内存元数据、无NAS/播放；焦点文本/几何采集不作为Release产品功能。普通启动不启用测试页面。

## 包、测试与真机

- 当前HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加原dirty。当前510输入、普通Debug、27Mach-O逐一严格签名/嵌入依赖/profile目标/有效期/AppID与Keychain组校验后，21:03:36保留数据覆盖 AppleTV14,1 / tvOS18.2；完整原生名称和UDID现场重新确认并留私有文件。主SHA `1e3555910a80dc8833ba46916027db59e1fc9ce8f15884d7153c16e391d91d1b`，其余二进制身份见安全结果。
- 最终模拟器40逻辑＋7无媒体UI全部通过，严格详情序列包含原生提交断言。候选与仪表失败均在私有目录保留。
- **真机内存夹具44逐键**：同签名包显式以 `--tv-exit-probe detail-focus` 启动、空环境，无网络/媒体；每键最终具体ID与新增原生提交均匹配，无错误中间项。演员/相似片首尾、上下记忆、从重播进入、重复首项均在链内。结束后终止夹具，以空参数/环境恢复普通启动。
- **普通真机真实影片47逐键**：《变形金刚3》20演员与App当窗前三相似片，逐项左右、首尾、Up/Down/再入首片/普通三层Menu返回成立。相似片顺序来自当窗App，不另请求Similar猜顺序；仅当前前三片，不冒称全库边界。普通页没有夹具仪表，因此其47步是最终落点及截图证据；瞬态提交由前述真机真实视图夹具44步覆盖，不能混淆两种证据。
- 首演员与重入首演员实图已看。自有Runner实际停止、三项本轮改动的WDA设置GET核回原值；普通首页返回，0播放/蜂窝命令，未动网络/VPN/NAS/插件/凭据。TV偏好与上一批结束快照0变化，该参考不是本批安装前即时快照。手机/Pad本批0操作，旧包的核对日期不刷新。

## 接续边界

此次两项具体报告在上述链内修复/验收。无演员/无相似片、动态错误/简介按钮、快速连续输入、辅助功能及全部页面未全验；原生焦点轨迹不等于视频/滚动完整帧时间，不声明全局导航或性能PASS。不改解码/选流/Range/缓冲/音字幕协商，28开放／114格不关闭。

下一阶段继续总交接中的TV原始音字幕目录及设备文件控制、高清海报补全；原弱蜂窝故障、评分来源、iCloud权限和18外出安装依赖继续保留。不要将此次无媒体导航验证继承为SUB/AUD、HDR、PiP或双入口实播验收。
