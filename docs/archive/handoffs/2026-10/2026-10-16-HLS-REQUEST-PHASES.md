# 2026-10-16 HLS请求阶段诊断与验证阻碍

本批接续65bb，用户尚未通知携iPhone18回家；未执行18发现/安装/播放或自动化，最后已核仍07:10 c868。iPhone13低亮度意愿保留，本轮未调整或重读精确百分比。其他未提交工作均保留。

当前普通Debug -Onone / Xcode27.0 27A266a / d0ae9dcdb0b9 / 17:23:50+08。HEAD仍4de732加原有dirty。仅PlaybackPlanningPolicy、DevicesView和PlaybackNextCoreTests三输入变化，170/173保持；没有改变播放器、传输、并发上限、重试、超时、码率或解码策略。三二进制SHA、29库逐项/deep/strict/profile/IPA核验及15预检成功；完整哈希/结果见[结构化记录](../../../testing/results/2026-10/HLS-REQUEST-PHASES-20261016.json)，私有指针`/tmp/nastart-hls-phases-evidence`。本批是待继续验证的诊断候选，不能称全套测试通过或播放问题修复。

新增边界为任务创建→首次fetch、最后fetch→request、request发送、requestEnd→首字节、响应体、responseEnd→metrics回调及redirect数。另按upstream task ID保存单调时钟的首个headers回调，排除旧重试回调及重复覆盖。缺失、倒序、非有限/溢出边界写unknown，实际零写0。三反例覆盖redirect边界不串、缺失/倒序及数值异常、重试身份与首次头时间。采用[Apple temporal metrics定义](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics)及[fetchStartDate](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics/fetchstartdate)，这些间隔不能单独叫“队列耗时”或“服务器耗时”，没有据此猜测调参。

验证失败完整保留：

- 第一次415项：409通过/2跳过/4失败；四项为AudioConfigurationChange、AudioFormatStress、OriginalReplacementPausedPreview、OriginalReplacementFailureAndCancellation中的真实模拟器SIGABRT。xcresult与报告主栈为_ReportRPCTimeout→AURemoteIO::Cleanup→AVAudioEngine outputNode→AudioEnginePlayer.init，不能写成断言全过或真机崩溃。
- 不改环境复跑一次：415项408通过/2跳过/5失败，同四项RPC abort，另VODPrewarmUsesItsFullDeadlineWhileProxyBuffersAMovingResponse本地loopback -1001超时。新三项均通过，设备构建成功；没有跳过失败再拼全绿，也没有第三次盲重试/重启音频服务。当前源码全套验证未过，归因尚须对照。

双机现场USB名称/型号/系统/UDID及连接重核，13为iPhone14,5/iOS16.3.1、Pad为iPad12,1/iPadOS18.3.1。诊断/原偏好先保存，再保留容器覆盖最新d0ae，25/18安装偏好含书签逐值保持，不卸载或回灌。13 WDA空env/args正常启动实际首页已看；Pad安装成功后WDA8100拒绝，立即拉crash reports并核清单与进程：Nastart/WDA/Jetsam0新增、Runner进程不存在。Pad经原生RSD/DVT请求空env/args启动，实际Nastart首页已看，只支持正常安装启动，不算播放回归。

Pad工具恢复：旧canonical xctestrun确实存在但TestHostPath指向10月3日过期产物，未启动此产物。早期路径解析/签名校验失败保留在工具记录；找到10月11日续签的固定host/test fixture，逐项签名及目标profile核验通过，再复用历史Downloads/Xcode的test-without-building，无新Runner构建/显式安装。短暂ready=true后远程连接invalidated、exit65，随后再次拉报告仍无新增；没有把ready瞬间当可用回归，也未进一步重装/反复拉起。当前WDA恢复待处理，原生空env最新包首页保留。

网络只读：17:15 Mac已配配置System/Info/Public 12秒超时；17:17同一既有私有literal入口HTTP200约0.016秒，另一既有域名入口200约7.754秒，server ID与上轮一致。没有把Mac探测替代手机路径证明，也没有更改端点、DNS、VPN、配对或NAS配置。初次Phone导航的Jellyfin在线标签在两次观测间变化、下一次工具缺少Phone native_touch方法，均在播放前失败，旧失败截图保留；改用本轮唯一Jellyfin元素及有界W3C触摸后进入详情。

13受控静态HLS沿用同普通二进制，只注入NASTART_TEST_STATIC_HLS=1，Apple bipbop HEVC VOD既有fixture/本地代理、无NAS转码、无整形。正常出图后实际深跳357.340秒，本次native AV dispatch至completion约1.539秒。对应206 Range：taskCreated→firstFetch0ms、lastFetch→request0ms、发送0ms、requestEnd→首字节327ms、headers回调329ms、完整响应体1567ms、metrics延迟0ms、h2复用/背压0。仅35条取得新阶段的传输观测；不能外推“队列总是0”或把header等待当纯服务端。与旧65bb的43秒非同档/同条件配对，期间有自动换源；没有改播放策略，不能称提速修复。深跳前还存在一次约+15秒seek（completion约0.041秒），保留独立事件，不混进深跳计时。t30实际38.280秒、seek t45实际47.803秒，迟到采样不伪写精确边界；t30初始测试图、seek t3转圈及t47.8目标约6:22测试图均已看，不能当完整显示timing或连续流畅。

静态场景已普通退出并恢复空env/args。随后Phone Jellyfin《哈尔》普通包30秒采集及退出成功，实际t30是压制组蓝背景片头、closed是正确电影详情；未获得合格自然电影帧，不标完整FF/稳定播放/SUB/AUD通过。与旧S01云海图不混批。

17:42收尾：13实际空env/args首页/播放器关闭已看，原24非书签项及36原书签轨道保持，0删/0增、1自然位置变化；Pad原18项非诊断偏好含全部书签保持，原生正常首页/播放器关闭已看。两机首页NAS仍显示未连接，不能称会话稳定（服务健康点显示在线分列）。两机Nastart/WDA/Jetsam0新增、native conditions0。13 WDA idle10/cool2；Pad WDA不可用，不能声称最终settings已复核。原CPU/内存、字幕底边/旧cue/烧录旧帧、长HLS等待、切轨、PiP/文件入口、完整SUB/AUD/显示帧及全部MI2/PX/UX/CB/Main/竞品/19×4缺口保留。

下一步先解决五项全套验证失败并恢复Pad XCTest链路，继续用本批只读边界记录原来的慢请求窗口；同一Jellyfin会话目标分片入口/就绪/AV回调归属未证前不改网络参数。iPhone18仍待用户回家通知后重核当时最新包。
