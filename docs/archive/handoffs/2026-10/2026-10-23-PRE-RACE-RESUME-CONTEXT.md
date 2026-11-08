# 当前播放与NAS任务接续

2026-10-23当前：[本地原流并行准备修复](../../../archive/handoffs/2026-10/2026-10-23-FILE-LOCAL-ORIGINAL-RACE.md)12定向/15预检/06:52普通构建及173输入29签名核过，最新包`/tmp/nastart-file-original-race-evidence`，安装/真机回归进行中。旧05:26与未完成30秒的两窗方向读取失败保留，不判首帧P。13/Pad WDA已实际打开设置/返回Home；系统前台字段错判及session前缀Home404已保存，Pad经Mac XCTest启动，无WDA重装。28项仍开放。

更新：2026-10-23 06:32。先读[调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)、[分层流程](../../../development/playback-development-workflow.md)。28项编号/状态仅在[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。自动接续仅覆盖已有授权，无周期调度/回合后后台执行承诺。

## 当前包与逐设备现场

[构建批次](../../../archive/handoffs/2026-10/2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md)：10-22 05:26:28.931374+08普通Debug/-Onone/Xcode27，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty；iOS diff `e65a8da17ea0db5e1a22d374c2bb79c5d5d8dd4eb4acb4a5fedd8f3057cbaa16`，IPA `45d213bafb07a70a3543980ff961388a817172e7e9176185f67c76fb2b1eaf9b`。既有151项NonPlaybackPolicyTests：150通过/1配置跳过/0失败、15预检。本批未改App源码或构建，未重跑产品XCTest，主机WDA70测试通过；18前批同包保留数据安装已完成；173输入/三二进制/29库逐签深签/profile目标及期限/IPA CRC已再核，profile至UTC10-24 22:23:57。

包/三SHA/完整输入与早间安装回执在`/tmp/nastart-connection-timeout-audit-evidence`，18晚间新回执在本机独立晚间指针；此包目录prior再接02:35/19:52/15:39历史包。无产品输入变化不重建；每次换设备/回归仍重新现场核身份和本机回执，版本号不作包身份。

- **13**：用户确认控制中心已收起，06:26新现场名称/iPhone14,5/iOS16.3.1/UDID/USB/源包/本设备回执重核，实际Home Wi-Fi已看。06:30[设备文件普通关闭](../../../archive/handoffs/2026-10/2026-10-23-IPHONE13-FILE-NORMAL-CLOSE.md)1 Play/0 PiP实际出画，单次完成后回原详情，前后可见完整路径一致、实际图已看；原助手用列表复合名称比详情末尾断言false保留，独立复核通过，不重播。36原轨道/其他偏好全同、仅1进度变化，WDA state1/1、auto10/2、日志/守卫停止及原生Home Wi-Fi已核；不报native PID0。新指针`/tmp/nastart-iphone13-resume-evidence`。返回后标题变单行截断待复核，原因未知。以下22:17仅为前批结果：[晚间双入口暂停/按钮定位](../../../archive/handoffs/2026-10/2026-10-22-PAUSED-SKIP-TWO-ENTRIES.md)已接当前05:26包，每窗重新核iPhone14,5/iOS16.3.1/名称UDID/USB及173输入/29签名/本设备回执。JF44→59→44秒、恢复并正常回详情；文件20→35→20秒、恢复23秒，完成按钮stale未确认正常返回，finally已停止自有App/日志/守卫。22:17 WDA state1/1、auto10/2 GET、原生Home无PiP/Wi-Fi已看；原生DTX进程清单不可用，不报native PID0。36书签原轨道及其他完整偏好全同，仅2条自然进度变化。最新session在`/tmp/nastart-paused-skip-file-active-evidence`；前两准备失败/一导航超时均零Play，旧失败保留，不再重复同条件DTX/退出点击/重装WDA。[早间自然序样本缺口](../../../archive/handoffs/2026-10/2026-10-22-NATURAL-SORT-SAMPLE-DISCOVERY.md)继续开放。
- **Pad**：[S01暂停/退出新窗](../../../archive/handoffs/2026-10/2026-10-23-PAD-S01-PAUSE-AND-EXIT.md)每窗及05:51最终均新核iPad12,1/iOS18.3.1/USB/173输入/29签名/当前05:26包回执。实见3/10/30秒画面及暂停38→53→38，3次Play请求/0 PiP；完成应答200后方向读/timeout未取到正常原详情图，EX仍未验，停止同条件媒体。助手固定退出竖屏未基于实际横屏进入页，不据此归App错误。最终App/Runner/自有host均0、29原轨道及其他完整偏好保持，仅1自然进度变化，原生Home无PiP/Wi-Fi已看。末窗设置恢复/GET超时，Runner已停，下一session必须显式设置并GET，不沿用末session。私有指针`/tmp/nastart-pad-s01-final-evidence`；[前阶段工具接入](../../../archive/handoffs/2026-10/2026-10-23-TRANSIENT-CONTROL-AGE.md)与旧[菜单/API119](../../../archive/handoffs/2026-10/2026-10-22-IPAD-TOOLBAR-OBSERVATION.md)边界保留。
- **18**：今日[06:26按用户要求重新安装](../../../archive/handoffs/2026-10/2026-10-23-IPHONE18-REQUESTED-REFRESH.md)，新现场身份/173输入/29签名/当前包已核；06:26:05 Complete/lookup，25完整偏好安装前后及正常启动后全同，原生正常首页/NAS在线/Wi-Fi已看，0 Play。新回执`/tmp/nastart-iphone18-requested-refresh-evidence`。以下为旧批历史：[晚间21:59重新安装及首页已核](../../../archive/handoffs/2026-10/2026-10-22-IPHONE18-EVENING-INSTALL.md)，现场新Bonjour/实际UDID/原pair核同iPhone19,7/iOS27.0/Wi-Fi，173输入/源包/29库签名/profile再核。21:59:14 Complete/lookup，安装前后及启动后25完整偏好全同，正常空环境/空参数RSD启动成功，原生正常首页/NAS在线/Wi-Fi实际已看，无播放器/PiP。用户本次新指令解除早间首页暂缓；旧07:12安装后的两次DTX失败/锁屏证据保留，未定唯一根因。私有指针`/tmp/nastart-iphone18-evening-evidence`，包仍05:26，0 Play/PiP；未重试/重装WDA，原片竖屏/字幕/完整PiP尚未验。

## 当前批次结论与下一步

按用户要求收拢主线：18安装已完成，13当前包设备文件普通退出有限缺口已补，停止重复控制中心/菜单/小片关闭。下一主线为两入口起播慢/零速及大文件深seek，继而真实音字幕/保存，再PiP；其他App与扩展保留总账，不临时插队。28项是12进行中/5待验收/11待开始，不是28个已确诊故障。

[Pad S01暂停/定位](../../../archive/handoffs/2026-10/2026-10-23-PAD-S01-PAUSE-AND-EXIT.md)当前05:26普通包已实见3/10/30画面及暂停38→53→38秒；3次Play请求/0 PiP（含一次进片后观测失败），正常退出仍未验：完成应答200后方向读取/timeout阻塞，助手固定竖屏假设无依据，不当App退出失败或修复。停止同条件媒体，转离线真实方向/完整后帧条件。主机守卫/显式方向只读接口70测试通过，无App源码/构建/安装变化；最终173输入/签名再核、App/Runner/host均0，29原轨道及其他偏好保持、仅1进度变化，Home Wi-Fi已看，末窗设置恢复GET未完成且Runner已停。 离线已核进入前/暂停/Home均1080×810、关闭前LANDSCAPE，末尾是source及settings各8.003秒超时，台账无逐次响应值。后续采集须保存真实scene/完整请求响应及原详情独立后帧，同方向不走旋转接口，不再固定竖屏或追加本假设真片；13用户已确认收起控制中心，本轮恢复接续。

[13双入口暂停/15秒定位](../../../archive/handoffs/2026-10/2026-10-22-PAUSED-SKIP-TWO-ENTRIES.md)沿05:26普通空环境包，JF实见44→59→44秒、恢复推进及正常回详情；设备文件实见20→35→20秒、恢复23秒，最后完成按钮stale未确认正常退出，finally已停流/采集。两窗2 Play/0 PiP，早期DTX/助手state2门槛和文件导航守卫超时均零播放失败保留；最终36原轨道/其他偏好全同，仅2条进度变化，WDA state1/1及原生Home无PiP/Wi-Fi/auto10/2已核，原生进程清单不可用。不是严格速度配对或完整SUB/AUD/深seek验收，28项开放。 原始图、身份、偏好/日志只留私有指针；正常包与播放路线无实现变化。离线已核完成派发距恢复4.844秒、当前控件4.5秒自动隐藏，与查询/点击间消失一致但无任务起始事件，未定唯一根因；后续约束瞬态观测时效，不重播同条件影片；深seek输入精度、其余字幕与设备覆盖继续保留。

[子目录排序归档](../../../archive/handoffs/2026-10/2026-10-22-SUBFOLDER-SORT-CURRENT.md)：三个真实修改日期双向正确；S19目录六文件25KB–120GB大小与jpg/mkv/nfo类型双向正确；混合目录四文件夹日期内部升序、日期本应插入的文件仍最后，目录不显示伪造递归大小；正常逐级返回及四项导航实际核。只读目录元数据，0文件预览/下载/Play/PiP。首窗为核勾选重开菜单后重复点已选项关菜单时stale，未重发、finally恢复；第二窗删私有助手冗余关菜单步骤后只接剩余场景，实际图/AX验证，不当App修复或旧stale唯一根因。两窗报告名称增量0仅清单口径。

[数字/缺失样本探查](../../../archive/handoffs/2026-10/2026-10-22-NATURAL-SORT-SAMPLE-DISCOVERY.md)仅见补零集号、未找到已知/缺失元数据混合，不能判上述真机场景P；只读当前包既有xcresult四项排序/元数据L0均Passed，新增测试运行零。[Pad两窗](../../../archive/handoffs/2026-10/2026-10-22-IPAD-FILE-SORT-CURRENT.md)仅文件列表/navigation切片与TOOL失败，不新增排序验收。停止继续搜补零目录、重复已验窗或第三个同条件Pad窗口；后续[只读属性与一次菜单实证](../../../archive/handoffs/2026-10/2026-10-22-IPAD-TOOLBAR-OBSERVATION.md)已确定可见/可命中的外层目标并正常打开/原项关闭，未改排序值或新增完整排序P。两窗离线比对已核日志目标相同、各自新FS pair、窗内无logout；缺线上SID/服务端会话证据，来源仍未知。下一步转有独立条件的文件/字幕/seek缺口，不重复菜单或同条件登录、不盲重登。该排序批次未改App或主机工具，也未重跑测试；共享主机安全分类18项是更早批次结果。当前批WDA工具变更及70项测试见上文。

[网页窗](../../../archive/handoffs/2026-10/2026-10-22-SERVICE-WEB-CURRENT.md)仅实见简洁页隐藏App导航、关网页回详情恢复；旧返回标签假设/菜单遮挡可见性守卫失败保留，不重做第三轮同条件或把未过滤底层AX名称当可见TabBar。

## 保持的播放/NAS实现与未验收边界

- NAS：[POST前配置地址准备](../../../archive/handoffs/2026-10/2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md)仅在多条已保存/校验/去重URL并行无凭据API.Info（8秒绝对上限），复用首个同源合法Auth结果/取消其余，再串行凭据POST；不新增host、不改URL到IP或证书策略。手动/单地址、[认证异常不隐式重发](../../../archive/handoffs/2026-10/2026-10-21-AUTH-AMBIGUOUS-RESPONSE.md)、POST绝对18秒和[FileStation提前发布](../../../archive/handoffs/2026-10/2026-10-21-NAS-COLDSTART-COMPARISON.md)保持。13/Pad有限两页一致不证明端到端提速、DS One胜负或18旧timeout/API119根因。Mac内网API.Info约0.151秒/记住公网TLS失败未绑定旧实际keychain端点，不据此改NAS/VPN。
- 保存：[真实同key窗口](../../../archive/handoffs/2026-10/2026-10-22-TRACK-SAVE-MEMORY-WINDOW.md)ASS5→PGS7，close/disappear提交/同锁内存match与最终外部entry时间一致；旧失败未复现/归因，不当修复或冷启动耐久，不加synchronize/等待。AFC即时偏好快照可落后当前UI，不据旧快照重放动作；测试后以完整最终偏好核原状态，不回写旧plist。
- 字幕/PiP：[当前包13外置ASS](../../../archive/handoffs/2026-10/2026-10-22-CURRENT-ASS-PIP.md)3/10/30秒原生中英实见；系统显控一次后无按钮，零暂停/继续/恢复，原因未知；显控函数与旧成功窗一致/各取新矩形，缺触摸后连续原生帧，不加等待重播。[旧真实竖屏](../../../archive/handoffs/2026-10/2026-10-21-PORTRAIT-VISIBLE-PANEL.md)、[旧ASS有限往返](../../../archive/handoffs/2026-10/2026-10-21-PIP-FAST-INPUT-ROUNDTRIP.md)、[S01系统X有限关闭](../../../archive/handoffs/2026-10/2026-10-22-PIP-SYSTEM-CLOSE-S01.md)不能继承为新包完整SUB/AUD/PiP/18原图通过。S01小窗10秒黑场未归因。视频矩形底锚点/视频高6%限12–20pt、普通Debug固定4K PQ兼容基础层、Release/不支持条件原帧保护保持，非DV动态输出或全App硬预算。
- 供给：[两PGS候选失败](../../../archive/handoffs/2026-10/2026-10-21-CANDIDATE-REQUEST-DIAGNOSTICS.md)仅-1008→CoreMedia/-12884，无失败URI；media未收齐、client header=false/body0，不能把master绑定当失败子清单。停止第三轮同条件NAS真片。[本地清单反例](../../../archive/handoffs/2026-10/2026-10-22-LOCAL-MEDIA-PLAYLIST-BOUNDARY.md)仅initial AV lab：慢直连/代理均失败，代理收齐后body发送失败，同字节快速直连出画；非候选精确warmup根因或流式交付已实现。

弱蜂窝单列用户报告弱信号，RSRP/RSRQ/SINR未知；蜂窝任何退出最外层先停自有播放/下载/采集、恢复原SSID并核原生实际连接和Wi-Fi图标后再分析。竞品滚动必须同条件实际位移/完整帧时间，AX或稀疏图不作流畅P。保留全部dirty及私有凭据，不卸载/清登录/改NAS/VPN/系统；TV安装与DSM更新旧约束保持。
