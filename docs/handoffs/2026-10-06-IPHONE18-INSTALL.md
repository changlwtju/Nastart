# 2026-10-06 iPhone 18 最新包与 WDA 安装

2026-10-06 15:31 最新接续：按用户打断要求，现场重核刚接入iPhone18 Pro Max/iOS27.0，将同源码e855/38ce最新普通包验签后保留数据覆盖；正常系统启动成功、约69.8秒后同进程仍在，安装及启动后25项偏好一致，WDA未重装。 iPhone18已从旧d84f更新到当前e855；本轮只安装及进程启动核验，原生截图TOOL、实际前台UI/播放性能未验。iPhone13既有宿主ready时恢复一次no-launch session，13/iPad正常启动台重核；无新源码或播放采样。 返回iPhone13/iPad原画供流和HLS首段等待/取消关联、健康预测边界与控制/字幕，再推进Lenna/DS One Jellyfin和DSM全面量化；保留所有PX/UX/CB未验收项。 见[安装续记](2026-10-06-IPHONE18-LATEST-APP.md)及[供流排查](2026-10-06-IPHONE13-IPAD-UPSTREAM-LOADING.md)。


用户要求先安装iPhone18，再继续iPhone13优化；随后确认两者可正常启动，并将断开iPhone18、改接iPad。

现场确认 iPhone 18 Pro Max / iPhone19,7 / iOS27.0(24A8428)，USB及CoreDevice connected、配对成功、开发者模式enabled、无需密码且启动后已解锁。完整设备标识/安装路径及原始偏好仅在本机私有证据。

Nastart使用09:38:36最新正常Debug -Onone包（HEAD9a9941cd；source diff dc7d0883；main d84fda19 / dylib a389980c / KSPlayer c2f1a42b）。安装前复核源码与冻结二进制、deep/strict签名及描述文件包含目标设备。CoreDevice保留数据覆盖安装成功，25非诊断偏好全部保持；未卸载或清登录。签名至北京时间10月11日06:03:15。完整身份见[量化记录](../testing/IPHONE18-INSTALL-20261006.json)。

首次CoreDevice正常启动返回Security拒绝（签名、权限或开发者信任的通用错误），原始错误保留，不据此认定具体根因或App崩溃。用户随后明确确认Nastart与WDA均可正常启动。自动化启动请求后实际前台是com.openai.chat，因此该截图只私存并排除，不能当Nastart最新包UI/播放回归证据；正常启动最终依据标为用户确认。

WDA从现有固定Bundle的已验证签名fixture复制到该设备独立私有目录，不修改iPhone13产物。Runner bundle com.changliwen.nastart.WebDriverAgentRunner.xctrunner，runner SHA256 8f1ec108…（完整值见JSON），描述文件包含目标、签名至北京时间10月11日06:05:26；CoreDevice覆盖安装成功。Xcode27 test-without-building使用该设备独立xctestrun映射启动，单独8104转发；/status ready及固定Bundle/iOS27.0已核，session/source/screenshot可用。报告SDK26.4，不能说是新版本WDA源码重建。

用户断开iPhone18后，本轮该设备XCTest已结束，自己的8104转发已停止；不影响已安装数据，不宣称离线WDA仍ready或完成播放验收。iPhone13原WDA宿主保留，但旧session缺失、普通锁屏和前台状态须独立恢复，不以status ready代替可操作性。iPad在这次USB清单中尚未接入，接入后先核对实际型号/系统/连接及最新包，再开始其回归。

后续优先iPhone13同私网MI2自然首卡与候选/HLS字幕失败cue，iPad接入后完成最新包门槛并补受影响播放/滚动/竞品项。正式竞品配对仍0，所有PX/UX/CB缺口保留。上一轮[局域网修复与回归](2026-10-06-IPHONE13-LATE-LAN-CONTEXT.md)仍有效，不把安装成功冒充iPhone18播放或跨设备性能通过。
