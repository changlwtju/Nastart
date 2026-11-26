# Apple TV 两个管理页宽度修正

2026-11-21，北京时间。背景见 [Muse 交接](../../../handoffs/TV-SHEET-WIDTH-STILL-COMPRESSED-2026-11-21.md)。上一轮已在 Apple TV 三种主题量到容器详情信息卡 1620 pt。两张实拍指向「启动台 → 管理显示」和「存储与媒体 → 连接管理」的居中窄弹窗。后一处实际挂在 NetworkMedia 的 `NetworkMediaLibraryView`，从「我的 → 存储与媒体」进入也是同一入口。「我的 → 连接管理」直达的是另一张电视授权页，原本已走导航。

两处都切换到当前 tvOS 导航栈，使用系统 Back/Menu 返回：

- `tvos/NastartTV/Sources/TVNASViews.swift` 将管理显示推入启动台导航栈，按视口扣除安全留白来铺开分组卡片和两列服务。
- `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift` 将 tvOS 的存储连接管理推入存储与媒体导航栈，复用页面现有宽度、主题、连接数据和编辑动作。iOS 仍使用原来的弹窗及完成按钮。
- `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/SourceContext.swift` 让被推入的连接管理页保留原生返回处理，其他页面仍使用原有返回方式。

Xcode 27.2（27B52）在隔离副本以 Generic tvOS Device / arm64 Debug 完成 Build for Testing（18:38:31），App 和测试目标均构建成功。HEAD `8db1cc64` 加现有未提交修改，三处改动文件与构建副本逐字节一致。构建产物位于 `/Users/lagransun/Library/Developer/Xcode/DerivedData/NastartTV-hedldllpjgmcbmbdybhnuykyxxdb/Build/Products/Debug-appletvos/NastartTV.app`，Debug dylib SHA-256 `0ceef64b8e9aa35552b75d99fecb348adb4306fd4186514966309c60867fe8ad`。NetworkMedia 离线场景 10 项、已保存连接 8 项测试均通过（Mac，18/18）。本机无可运行的 tvOS 模拟器，本轮两页真实宽度及遥控返回尚未实测，也未安装真机。

## Muse 复测

从 `/Users/lagransun/workspace/Nastart` 当前源码构建，验签并保留数据覆盖 Apple TV。记录设备、包哈希、安装时间与正常启动。分别进入「启动台 → 管理显示」和「启动台 → 存储与媒体 → 连接管理」，确认已进入整页。用截图中可见的「收藏」或「媒体」分组卡片，以及「存储连接」分组卡片量横向 frame，宽度应 ≥1400 pt 且在 1920 pt 视口内。管理显示需核两个容器列和服务名，连接管理需核 Synology DSM 与 WebDAV 行完整显示。分别按一次 Back/Menu，确认回到启动台和存储与媒体。可以参考页面标识 `tv.services.visibility.page`、`network.connections.page` 判断落点。历史 `testSheetWidthManageDisplay` 的全层级最大宽度不能作为验收，从截图或实际卡片取得边界。回归 `testFixVerificationWidthCleanGrid`，上一轮基线为 1620 pt。按路径记录结果、可见卡片 frame、截图及失败现场。
