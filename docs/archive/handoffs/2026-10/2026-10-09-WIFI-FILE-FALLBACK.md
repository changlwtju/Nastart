# Wi-Fi大文件原流的惰性备用请求

问题/关联：PX-03/PX-21。承接[上一轮接手修正](2026-10-09-HANDOFF-COMMIT-HOLD.md)；基线HEAD4de732dd+iOS diff f6ef10、普通fe7c/61c8。上一包受控家庭Wi-Fi下S03文件手机总6次/iPad5次缓冲，首钟后均5次，没有automatic_downshift_requested。该28窗仅属于上一包，不归本批最新回归。

根因证据：DevicesView仅在非wifi预先解析JellyfinMatchedFileStream；Wi-Fi原流MediaPlaybackRequest仅带Range/software资源回退，没有协商播放请求loader，Greenfield自动降档任务提前返回。严格转码匹配与独立original解析是不同查找，原original的ambiguousOrUnavailable不能证明转码匹配失效。

最小修改：原文件请求挂惰性备用请求，健康Wi-Fi原画启动不等待匹配或转码。只有共用储备/供流/再缓冲策略触发后，解析同文件严格身份，结合原流实测供流与新鲜探测，用现有码率规则创建候选。位置沿用实时秒钟，继续现有持钟/100ms资格/150ms帧/连续500ms储备，取消后晚到的候选释放代理和服务端编码资源。

本次保守资格：沿用至少16GiB视频文件范围；须确认第一音轨（ordinal0）以及字幕已知关闭、无内嵌字幕选择或外置字幕。严格匹配带回第一音轨的真实stream index，并显式请求该音轨/字幕关闭，避免服务端默认选择改变内容。其他音轨、内嵌/外置字幕、未知选择或无有效位置均继续原流并记原因；该缺口保留，不能声称完整轨道或全部大文件已覆盖。现有非Wi-Fi先选流与其他入口不改变默认规则。

L0：惰性Wi-Fi候选/实时位置与倍速、严格匹配不可用/未知音轨、未知或不支持的用户选择、准备后取消资源释放；全部核心及15预检/普通构建。此前真实解码持钟测试继续执行。L1：S03文件原失败双设备各180秒受控家庭Wi-Fi，媒体库两入口对照；另MI2相同文件规则和S01基础四单元。L2：S01/S03/S08双机双入口60秒；声音/画质/完整帧/十分钟/PiP/真实弱信号与家庭外Wi-Fi保留待验，不作跨包性能排名。未改Range/超时/解码参数，不触发L3发布或架构迁移。

11:17起始状态（历史）重新读取USB：iPhone13 iPhone14,5/iOS16.3.1；iPad iPad12,1/iOS18.3.1在线。原始设备名/UDID/偏好与凭据只留本机私有目录。本批起始时源码已改、设备仍为上一fe7c包；完成构建签名、逐机保留数据覆盖、偏好与正常启动核验后才能采本批基线。iPhone18未连接、不可声称更新。

当前：211核心测试和15预检通过，最新普通包已逐机保留数据覆盖及真实正常前台核验；本包20个播放窗口已采、文件现有轨道未通过L1，缓冲和起播失败保留。当前仅有家庭Wi-Fi；真实家庭外Wi-Fi按用户安排稍后补，模拟限速不替代弱信号或外部网络验证。保留其他未提交修改与全PX/UX/CB/竞品/Main状态。

## 普通候选包门槛（构建与验证）

211测试/2跳过/0失败，新增4项候选规则及原真实解码测试均通过；15预检通过。当前HEAD4de732dd645b36671becff992cdef1d0163fd1e4、iOS diff `4bdd232dc5a5684d07cd96a92723bf11a909e78f77f1d1eb9a1f69ad62f08b46`，普通Debug -Onone（实际编译参数已核），构建 `2026-10-09T11:21:41.625056+08:00`；包路径 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-wifi-file-fallback-111729/Nastart-WiFi-File-Fallback-Normal-Debug.app`，29库/deep签名、137输入mtime及链接通过。SHA-256 `{"Nastart": "97a1cc932b4205f1bcd3a12cdd99909295d05543f272dfd6b45c98e61930d742", "Nastart.debug.dylib": "77b0dcd3e6000c42de803d6cd28e544ba12bff8bb3472842fde9dfd82ec3bc2b", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}`。

两机均已现场重核后保留数据覆盖，手机25/iPad16项非诊断偏好安装后及正常空环境启动后一致；11:24/11:25正常启动和实际启动台/NAS在线/Wi-Fi/无播放器已核。本包回归从此后开始，此前28窗不移用。

## 首个定向反例（新包，不能记修复通过）

手机S03文件180秒受控40Mbps家庭Wi-Fi，严格源匹配verifiedTranscodeSource/parentTailSizeAndFilename且lookupComplete=yes；76.556/113.148秒两次originalFallbackUnavailable，reason=runtimeTracks。该新包分支已被调用，当前选轨不满足保守资格，没有originalFallbackPrepared或replacement_committed。KS首次计时后计数增长，单renderer最大4次缓冲；180秒实际枪口/人质电影画面、普通退出已核。不能与旧包6次直接作改善归因，供流/缓存/起点/轨道未严格对照，音频/完整帧未知。

随后S03媒体库首次尝试t3截图RemoteDisconnected、旧session404，恢复后activeAppInfo500 nil dictionary；已保存1403项报告目录，未找到本时段Nastart报告。原生恢复画面仍有电影与双语字幕，原采样窗口不完整，后图不归原窗；普通退出恢复TOOL，后续正常重开终止旧播放器。恢复会话及defaultActiveApplication后独立retry继续，原TOOL不得抹除。

12:02检查点：已完成6个180秒定向窗口（手机S03/MI2双入口、iPad S03双入口），iPad MI2继续。手机S03文件4/iPad5、手机MI2文件9次缓冲；手机S03媒体库接手后1次、iPad两次接手后分别1次；手机MI2媒体库原2次（首钟前1）/候选1次。没有把跨renderer计数相减。文件现有轨道均未资格，originalFallbackPrepared/新文件接手未证实，L1失败保留；普通Wi-Fi12格60秒待完成。单张可辨电影/一处双语cue不替代完整字幕/声音/画质/显示性能验收。

## 本批收尾与后续边界

2026-10-09 12:34：独立最新源20窗（12普通Wi-Fi60秒+8受控家庭Wi-Fi180秒），均实际核过可辨电影和原时点普通退出。另1个手机S03媒体库原窗口早期截图/session TOOL、晚恢复退出TOOL/正常重开终止，另1个手机S01文件目录App读取失败（invalidResponse）均独立保留；重测不覆盖原失败。MI2初次导航KeyError与iPad MI2仅查closed日志的错误“pre-player FAIL”属于工具缺口，前者按实际Mission Impossible II目录补映射、后者用所有采样快照并集合并出原trace，已保存纠正说明及工具源副本。原始诊断/偏好/UDID/凭据/图片/工具源只在本机私有目录。

本包S03文件手机4/iPad5、MI2文件手机9/iPad7次缓冲（各自同renderer首钟后增量相同）；四窗共8次originalFallbackUnavailable/runtimeTracks，0个originalFallbackPrepared、0次文件候选提交。其他音轨/内嵌或外置字幕/未知选择的保守拒绝确实生效，但现有轨道尚未支持；**Wi-Fi大文件备用流修复未验收，L1 FAIL**。不改变用户现有选轨来凑通过，不以媒体库成功替代文件入口；这些分支在严格match解析之前退出，原路由ambiguousOrUnavailable不能归为协商匹配失败。

媒体库既有共用链路有6次受控Wi-Fi接手、普通iPad S03另2次，总8次；这些是对照入口的明确提交记录，不属于本次新文件请求的成功证据。接手后缓冲仍增加，按各renderer独立列计数，AV丢帧unknown，KS真实丢帧保留。12个普通60秒窗中iPad S03媒体库两次接手后的renderer各增长1次缓冲，其余普通窗未记录增长；S08双设备双入口4窗仍超过内部起播钟目标，弱S03手机文件/iPad双入口3窗也超目标，共7窗。内部时钟与实际电影首帧不同，零缓冲计数不等于逐帧流畅。无跨包改善百分比或竞品排名。

两机12:28重新读取USB/源码/包哈希，正常空环境/空参数启动；12:30实际启动台NAS在线/Wi-Fi可见/无播放器已核，idleWait10/coolOff2/WDA ready恢复。12:28:54原生条件读取全部inactive（两机activeCount0），未改无线/VPN/NAS/账号设置；普通包保持97a1/77b0/KSeda1、diff4bdd，不使用性能包。iPhone18未USB连接、未更新本包。

L0为211测试（2跳过/0失败）与15预检；L1当前选轨备用路径及连续播放失败；L2代表播放窗口完成但完整功能未验收。下一步先固定runtimeTracks的具体数字/布尔资格反例，严格映射当前音轨到已验证同文件，并补内嵌/外置字幕有效状态和候选/后续降档/菜单/书签的一致继承；无法验证时保留原流，不能静默改语言或字幕。随后同源新普通包逐机覆盖/核验、重复四个原文件弱Wi-Fi失败及媒体库对照，再核健康原画/暂停/seek/取消。分开定位DSM目录invalidResponse与HLS起播/接手后供流。

MI2/S03/S19真实弱蜂窝与规则VPN、S19本包压力、真实弱信号/争用、用户稍后提供的真实家庭外Wi-Fi、同起点十分钟/声音/画质/全字幕/轨道/后台PiP/完整显示帧、双机并发及Lenna/DS One正式配对仍待续。PX-01～21、UX-01～06、CB-01～26/19×4/Main状态保持开放。完整安全摘要见[本批20窗](../../../testing/results/2026-10/WIFI-FILE-FALLBACK-20261009.json)；此前fe7c的28窗和1d08的16窗独立保留，不归本包最新回归。

| 设备 | 网络/样本/入口 | 秒 | 点击至内部首钟秒 | 各renderer最大缓冲 | KS最大丢帧/AV未知 | 接手次数 | 保留标志 |
|---|---|---|---|---|---|---|---|
| iphone13 | 受控/mi2/file | 180 | 3.479 | 9 | 30 | 0 | 缓冲增长、现有轨道未资格 |
| iphone13 | 受控/mi2/jellyfin | 180 | 1.983 | 2/1 | 0/U | 1 | 缓冲增长 |
| iphone13 | 受控/s03/file | 180 | 7.421 | 4 | 14 | 0 | 起播钟超目标、缓冲增长、现有轨道未资格 |
| iphone13 | 受控/s03/jellyfin | 180 | 1.599 | 0/1 | 0/U | 1 | 缓冲增长 |
| iphone13 | 普通/s01/file | 60 | 1.120 | 0 | 0 | 0 | 短窗证据，不作完整PASS |
| iphone13 | 普通/s01/jellyfin | 60 | 1.273 | 0 | 0 | 0 | 短窗证据，不作完整PASS |
| iphone13 | 普通/s03/file | 60 | 3.290 | 0 | 0 | 0 | 短窗证据，不作完整PASS |
| iphone13 | 普通/s03/jellyfin | 60 | 1.666 | 0 | 1 | 0 | 短窗证据，不作完整PASS |
| iphone13 | 普通/s08/file | 60 | 3.730 | 0 | 0 | 0 | 起播钟超目标 |
| iphone13 | 普通/s08/jellyfin | 60 | 3.916 | 0 | 0 | 0 | 起播钟超目标 |
| ipad | 受控/mi2/file | 180 | 3.680 | 7 | 13 | 0 | 缓冲增长、现有轨道未资格 |
| ipad | 受控/mi2/jellyfin | 180 | 2.424 | 1/1/1 | 5/U/U | 2 | 缓冲增长 |
| ipad | 受控/s03/file | 180 | 3.820 | 5 | 8 | 0 | 起播钟超目标、缓冲增长、现有轨道未资格 |
| ipad | 受控/s03/jellyfin | 180 | 3.689 | 0/1/1 | 26/U/U | 2 | 起播钟超目标、缓冲增长 |
| ipad | 普通/s01/file | 60 | 1.405 | 0 | 1 | 0 | 短窗证据，不作完整PASS |
| ipad | 普通/s01/jellyfin | 60 | 1.700 | 0 | 6 | 0 | 短窗证据，不作完整PASS |
| ipad | 普通/s03/file | 60 | 3.509 | 0 | 4 | 0 | 短窗证据，不作完整PASS |
| ipad | 普通/s03/jellyfin | 60 | 2.438 | 0/1/1 | 7/U/U | 2 | 缓冲增长 |
| ipad | 普通/s08/file | 60 | 5.243 | 0 | 2 | 0 | 起播钟超目标 |
| ipad | 普通/s08/jellyfin | 60 | 5.698 | 0 | 1 | 0 | 起播钟超目标 |
