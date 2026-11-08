# 共用连接地址展示

日期：2026-11-01。直接承接[电视连接状态与地址展示](2026-11-01-TV-CONNECTION-STATUS-AND-ADDRESS-PRESENTATION.md)的本地核对。本批没有真机、模拟器、NAS、真实凭据读取或播放；全部源文件读写限本地，原有其他未提交修改保持，既定模型分工不变。

## 问题与实现

手机/Pad 的 `MediaLibraryView.fallbackLibrary` 在“网页打开”入口直接显示完整 endpoint。手动服务 URL 策略虽拒绝用户/密码，但允许 query/fragment，因此不能假定摘要没有敏感参数。共用媒体服务详情也直接显示 endpoint，不过 `MediaServiceEndpoint` 经 `WebDAVScope` 已拒绝用户/密码/query/fragment；这是既有约束，不能把它记为已发生泄露。

将电视已有的显示脱敏逻辑提取为纯 `NetworkConnectionAddress.displayText(for:)`，置于 NetworkMedia 的 SourceContext 文件 UI 条件编译之外，便于两端和 Mac 测试共用。它只返回去掉 user/password/query/fragment 的可选显示字符串，保留协议、主机、端口和编码路径；调用方保留自己的无地址文案。电视原 `tvDisplayAddress` 成为薄包装，连接管理、网络信息和地址线索继续经它显示。手机/Pad 备用服务入口和三端共用服务详情改用同一方法，不新增另一套格式化。

显示值不可用于请求、持久化、身份判断或授权。真实 ServiceWebUIView 接收的仍是原 endpoint；已有 endpoint 校验、精确来源匹配、Keychain、请求、导航和播放均未改。共用服务详情只替换两处 Text 的字符串，手机文件只增加 import 和替换一处 detail 参数，电视只改格式化函数委托；既有 SourceContext 主体字节未变。

这不是全应用 URL/日志/导出的安全审计；服务名、文件路径和自定义路径中的敏感内容也不由此方法自动识别。共用连接清单中“当前 NAS 已登录”仍取决于宿主提供的 session context，后续需结合会话有效性单独审查，不在本批改连接状态机或凭据。

## 验证与边界

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，446 输入，5 个既有文件改动（SourceContext、MediaServiceViews、LaunchpadMediaLibraryViews、TVNASViews、MediaServiceDiscoveryTests），其余 441 个 hash 一致。完整脏树、源码前后、命令/时间、候选包与二进制哈希只保存在本机私有区，指针 `current-shared-connection-address-private`。

已有 MediaServiceDiscoveryTests 新增两项展示/授权边界测试，全组 15 项通过：合成含 user/password/query/fragment 的地址显示脱敏、原 URL 不变、原 endpoint 校验仍拒绝；IPv6、显式端口、Unicode/空格/百分号编码路径，以及路径中编码的斜杠、问号和井号保持。其余服务识别/来源/授权测试继续使用合成数据和自有内存 transport，无 NAS 或真实凭据。场景参数未改，没有重复上一批四参数测试或把旧结果记为新测试。

首轮 TV 模拟器编译通过、移动模拟器编译失败：旧 MediaActionRow 的 initializer 接收非可选 String，不能直接传入 String?。原源码、命令和失败日志留存，只在手机调用方补“—”显示回退后冻结最终输入，重跑 15 测试及全部构建；最终配置与签名结果见[结构化结果](../../../testing/results/2026-11/2026-11-01-shared-connection-address-display.json)。此失败是编译阶段，不是真机或运行崩溃。

本批只更改地址字符串来源，不启动新模拟器、不采新图、不将前批电视静态窗口升级成当前包 UI 回归。布局、点击、VoiceOver、长地址真实换行及完整正式宿主仍待验；前批 Return/Space 无变化的交互未验结论保留。没有新增性能、滚动或播放 PASS。

移动普通 Debug 候选逐一核验 30 个 Mach-O 签名后冻结，未安装任何真机；TV 正常签名沿旧 profile 阻塞，本批不重试，旧 444 输入/27 Mach-O 签名包不能作为当前 446 输入的最新包。六配置编译仅证明所列源码可编译，不等于正常 TV 签名、Release 体验或三端真机验收。

## 接续

继续不依赖 NAS 的设置/连接反馈与已开放的交互补验；预算达标后补[凭据/导出子页](../2026-10/2026-10-31-CREDENTIAL-STATUS-AND-EXPORT-SELECTION-ROWS.md)、清理取消、Pad 同步大字、移动目录反馈和电视合成状态切换。密码显隐、真实头像/海报返回闪动、严格匿名导出及 JF TV Scope 保持开放。播放架构、路线、引擎和缓存不变，114 格无新 P，不新增或关闭[需求编号](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。NAS/全部真机仍暂停，无后台任务。
