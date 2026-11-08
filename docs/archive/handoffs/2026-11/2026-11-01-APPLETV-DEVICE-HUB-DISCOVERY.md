# Apple TV Device Hub 回报与发现分层

2026-11-01 20:05（Asia/Shanghai），接[临时TV加入](2026-11-01-APPLETV-REJOIN-AND-IPHONE13-LARGE-TEXT.md)，[结果](../../../testing/results/2026-11/2026-11-01-APPLETV-DEVICE-HUB-DISCOVERY.json)。用户提供Device Hub截图：“客厅”tvOS18.2 Currently Unavailable；上方tvOS27设备明确标Simulator，不能替真机。

只读有界Bonjour浏览5秒×3服务。Mac可见一个名为客厅的AirPlay广播；_remotepairing与_apple-mobdev2亦有广播，但无同名记录，不能按名称排除其包含目标、不能将AirPlay当开发身份认证或断言两机Wi-Fi完整正常。端点/广播原文仅私有。对前批已核硬件UDID的fresh CoreDevice清单查询exit0，但目标已不在清单；旧CoreID详情exit1。与19:25已配对但unavailable的快照分开记录，不推断设备被谁删除/取消配对，也不能称本轮重新认证真机身份。

[Apple官方无线配对说明](https://help.apple.com/xcode/mac/current/en.lproj/devbc48d1bad.html)要求同网，并在电视打开Settings → Remotes and Devices → Remote App and Devices以发现Mac；新Device Hub官方文档亦列该电视入口。已就此具体遗漏步骤询问一次用户，等“已到配对页”后再fresh发现；这是前次主屏幕开机/Device Hub不可用截图之后的新步骤，不重复要求同一已完成动作。Mac端后续只对实际出现的目标核身份，不盲点模拟器、不自动取消旧配对，不重置网络/NAS/VPN/系统或修改账号/签名配置。

前批正常TV签名构建缺有效profile、旧profile过期的独立阻塞保留；发现或配对成功不等于最新包可安装。TV App/Runner/安装/媒体测试均未发起，NAS继续暂停，13最新包/两窗结果仍以前批为准，本轮未再操作手机。产品/测试源码未改，已有114格与未验需求不关闭；无需重跑前批构建/单元/性能。当前无自有App/采集或发现后台进程，私有指针`/tmp/nastart-tv-connection-followup-path`。
