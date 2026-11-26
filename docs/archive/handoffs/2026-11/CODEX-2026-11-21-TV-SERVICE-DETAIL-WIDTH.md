# Apple TV 服务详情宽度修正

2026-11-21 17:22（北京时间）。本轮范围为服务详情页及宽度探针。上轮 Jellyfin 真机读库通过。Docker 的 homepage 返回已验证，其他容器和列表路径仍由 Muse 按计划核对。[Muse 上轮真机记录](MUSE-TO-CODEX-2026-11-21-TV-FIX-ACCEPTANCE.md)

上轮 /tmp/nastart-tv-acceptance-20261121.log 第 1270 行起的 XCTest 树显示，旧的 tv.service.info 标识落到了四个 StaticText 上。/tmp/nastart-tv-width-20261121.log 用 firstMatch 得到的 126 pt 对应该树中的「当前服务」文本，整张卡片当时的实际宽度仍需重新测量。该轮宽度验收未通过。

- TVNASViews.swift 的 TVServiceDetailView 在 ScrollView 外读取视口宽度，扣除左右各 70 pt 后为详情内容、管理入口与信息卡设定明确宽度。信息卡在此宽度上绘制背景，并把可访问内容组合成带 tv.service.info 标识的节点。真实卡片边界受页面可用宽度约束。
- TVLaunchTests.swift 的两个宽度探针在详情 ScrollView 内查找信息卡，要求恰好一个匹配，卡片宽度至少 1400 pt 且在视口横向边界内。日志记录卡片与视口的实际 frame。

Xcode 27.2（27B52）原生 Build for Testing 于 17:22 成功，App 和 UI 测试源码均编译。隔离工程 /tmp/NastartTVVerify1652 的两份改动源码与工作区逐字节一致。Debug dylib SHA-256 为 3e1a1ca7fadd48b2d145724fbc9625c31a3c90c1ee97e14942f83e502fef3b1d。本机 Xcode 未列出实际 tvOS 模拟器，宽度探针仅构建，实测待 Muse。此轮无真机安装。

Muse 从当前工作区构建并保留数据覆盖 Apple TV，然后运行 NastartTVUITests/TVLaunchTests/testFixVerificationWidthOnly。通过首页重点复测 homepage，按清流、栈列、流光三种主题记录卡片及视口 frame、截图和实际结果。若节点命中多个或宽度仍不达标，回传该页 XCTest 匹配树和截图。连接管理等其他页面如需复核，请独立记录现象。
