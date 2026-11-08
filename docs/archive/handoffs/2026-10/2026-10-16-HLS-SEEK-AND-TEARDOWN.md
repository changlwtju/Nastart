# 2026-10-16 HLS深位置排查与退出崩溃修正

用户明确携iPhone18离家，本轮所有18发现/安装/测试动作暂缓，等用户晚上回家通知后重新核身份与当时最新包。没有无线重试，没有定时任务。

当前候选0df79c3a7ff5 / 普通Debug / Xcode27 / 11:42:47+08，HEAD 4de732加原有未提交工作。相对本用户轮a22仅4/173 App输入变化，169保持；三二进制SHA/IPA CRC/29库/deep/strict/profile核验。最新包/精确信息见[结构化记录](../../../testing/results/2026-10/HLS-SEEK-TEARDOWN-20261016.json)，私有指针 `/tmp/nastart-teardown-fix-evidence`，旧指针未重写。

本次工作分三段，不混结果：

1. a22旧失败窗口：只读取得5份服务器日志648068字节，1858号分片/7439.432秒有唯一启动命令，h264_vaapi+libfdk_aac+字幕overlay；严格5秒关联未匹配、探索10秒窗唯一候选（命令距动作5.166秒），没有会话所有权证明。FFmpeg首片后进度低于实时只作事实记录，不当客户端60秒等待/容器重启的唯一根因。[官方10.11.11同tag源码](https://github.com/jellyfin/jellyfin/blob/v10.11.11/Jellyfin.Api/Controllers/DynamicHlsController.cs#L1945)的GetSegmentResult会等待片及下一片就绪，仅作实现参考，不把它当现场时长证据。
2. dce诊断候选：新增AV seek派发/完成/1、3、10、30、60秒只读边界，区分已下载与声明可seek区间、引擎状态和错误；不改变播放、网络、重试或超时。Pad S19此次从头30秒仍00:00无首帧，原生滑条动作进入服务器换流分支，不是上一轮播放中原生seek的重现。7420.593秒候选seek完成/ready，但loadedRange0、无解码帧，约动作41.215秒decodedFrame预热失败；初始流67.741秒报CoreMediaErrorDomain -12889。t120、后续失败Alert和普通退出均保留。原生AV seek边界没有事件，不能声称真实AV回调已验。顺便看到了两个转圈/速度叠层，84a UI修正只保留一套，借助既有播放器loading状态决定归属；尚缺最终包相同状态下的实际图复核。
3. 84a修正后的S01 Pad已出现真实画面，退出后WDA400。按规范先拉报告：新增11:36:04 bug309 / SIGABRT / 线程0，KS UUID与安装二进制匹配；SwiftUI拆UIView→detachView→resetPlayer→selectedSubtitleInfo的Published setter同步通知，触发GraphHost asyncTransaction/Swift exclusivity abort。这是真崩溃，不能归为WDA失败；13同源S01正常退出无新增报告。原始图/报告、失败工具和安装身份保留，84a不是最终候选。

退出修正：dismantle回调不再同步reset；排到当前图销毁完成后的主队列，强持有coordinator/AVStream owner直至先解除字幕再释放decoder，保留PiP；挂载generation阻止旧清理销毁已重挂的layer，显式stop仍同步且废弃旧任务。已经为空的字幕不重复发布nil。补3项反例：拆视图期间0同步发布、重挂不被迟到清理、重复空reset0发布；原PiP/重置所有权测试保留。409 XCTest/2跳过/0失败、15预检及设备构建通过，编译失败的首次String.init歧义保留在诊断候选attempt1。

双机最终0df均现场USB身份重核后保留容器覆盖，25/18项安装偏好含书签逐值保持，正常空env/args启动实图已看；之后Pad S01/Jellyfin三次、13两次从头30秒播放及退出，五轮t30/closed图均实际审阅，无播放错误或退出故障，均初始KS直放/字幕关闭。相对修复前基线两台Nastart/WDA/Jetsam均0新增；整轮Pad仍有84a的1份真实崩溃，未删除、未写成整轮0崩溃。仅支持此入口/S01退出的定向验证，非空字幕、PiP、文件入口及压力仍需真机补齐，不能外推所有崩溃/播放已验收。

11:51收尾双机源码173输入/四输入变化、三SHA/签名/正常空环境首页及播放器关闭重核；13/Pad非书签24/17项保持，36/29原书签的轨道均0变化、0删/0增，各1项自然位置变化，无原始偏好回灌。Pad最终首页NAS正常，13仍显示未连接（Jellyfin在线及播放能力分列），不能称两机NAS会话稳定。WDA idle10/cool2、native active conditions0；本轮未修改亮度，继续保留用户低亮度意愿，未重读精确百分比。原CPU资源警告、Pad内存峰值、S19/原始用户字幕位置/旧字幕残留、切轨等待及完整SUB/AUD/显示帧、所有MI2/PX/UX/CB/Main/竞品/19×4缺口继续开放。下一步先完成原S01退出重复和非空字幕/PiP/两入口回归，再接HLS请求-分片就绪-AV画面链路，18待用户回家。
