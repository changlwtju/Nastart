# iPhone13起播后缓冲：供给、门槛与请求衔接

更新：2026-10-23 15:37。仅离线分析[中段冷续播批](2026-10-23-IPHONE13-COLD-RESUME.md)保存的09:57文件与10:16 JF窗口；无新设备命令、播放、构建或安装。普通07:33包的173输入重新计算哈希，差异0。保留全部其他dirty；原始包/日志/偏好/身份在私有目录，指针`/tmp/nastart-iphone13-reserve-analysis-evidence`，上轮观察和构建指针不变。

## 规则与来源

关联起播/原画供给与续播任务，编号只在[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。本次最小改动是主机离线报告，不改播放器缓冲、时轴或自动换流政策。新增[缓存关联报告](../../../../scripts/playback_reserve_report.py)，复用已有隐私白名单和事件ID去重；按同trace、transferID、upstreamTaskIndex关联，保留取消/失败、缺失、冲突和未结束任务，不把同一transfer的多段32MiB正文合并。正文窗口可能跨Range边界，不以当前taskIndex把整窗字节分给一项；不相加窗口/任务正文/解码器bytesRead。

[原阶段报告](../../../../scripts/playback_phase_report.py)补保留receivedBodyWindow及跨Range标记，并修正计时说明：action.json requestStart是主机记录的派发边界，不是已确认物理点击。两窗均逐值核对它来自nativeAction/sendingOnce，分别晚于选取目标前playDispatchAt 0.791089/1.552894秒。旧文件保留；文件稳态门槛旧记+3.759秒统一后为+2.968351秒，两个完成metrics时间见[结构化结果](../../../testing/results/2026-10/2026-10-23-iphone13-reserve-analysis.json)。不能混用边界推算提速。

## 文件窗口的分层证据

- 第一、二个约2秒正文窗口分别89.55、30.26Mbps；窗口内实际runtimeDemand分别75.23、75.09Mbps。后一窗口收到正文速度低于需求，前一播放决策采样缓存0.709秒，下一采样仅0.0207秒，随后引擎进入buffering。代理记录backpressure=0、suspendCount=0且排队仅数KiB。支持“此窗供给不足与缓存耗尽”这一层，不定位到NAS、无线链路或某具体线程。
- 同连续播放transfer的前两段各32MiB，body4506/3608ms，约59.57/74.40Mbps（用取整毫秒计算，非精确容量）；上游完成到下一Range发出9.027/9.251ms，下一headers还需请求时间，未见多秒空档。保留全部4个取消请求，不能将早期索引/读尾时的-999或连接关闭直接定为本次卡顿根因。
- [KSOptions.playable](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/AVPlayer/KSOptions.swift)检查就绪帧与loadedTime；[KSMEPlayer.sourceDidChange](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/MEPlayer/KSMEPlayer.swift)仅在已playable时帧/包耗尽转loading。仅升到4秒门槛不会直接暂停仍可播放的流；进入loading后恢复须满足该门槛。[MEPlayerItem](../../../../ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/MEPlayer/MEPlayerItem.swift)仍持续请求供给。[当前renderer](../../../../ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift)在时钟初步推进后从1/6升到4/16，既有实现未改。
- stall采样起点ahead0.25025秒，随后同位置3876.99秒下ahead1.0→1.729→2.521→3.396，恢复采样4.1248秒/current3877.161，报告5301ms。bufferedAhead是采样总量，不能推出耗尽瞬间每条音视频队列值；engine buffering/bufferFinished事件与telemetry计时不同，不能当精确屏幕卡顿时间。
- [自动策略](../../../../ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift)仍处起播保护：卡前缺合格稳定窗口、grace=false；首个稳定窗口约+8.942秒已在buffering，预测条件要求未缓冲且时钟推进，之后+11.856秒才出现grace=true。窗口内没有自动降档请求。该观察不证明应缩短保护或降低4秒恢复门槛，也不证明改参数可避免重卡。

JF上下文窗口前几窗正文约102.19/77.70/91.72Mbps；30秒只报起播stall1002ms。两入口音轨、字幕、位置、缓存及网络时窗不同，禁止作配对速度或“JF已修复文件”结论。现有数据缺逐包供给与回调/解码线程排队时间，尚不能排除客户端调度、截图负载等因素。

## 校验与接续

109项报告工具测试全部通过，其中6项新增覆盖：同transfer分task、重复/冲突指标、真实0与缺失、取消及不同transfer不误接、同窗同trace实际需求、开放stall和私有字段过滤。不是App XCTest重跑或真机功能验收；不产生新包，不改变28项状态/76格通过率。详细自动报告只在私有目录，可分享摘要在上述结构化结果。

本批无新媒体、自有采集或网络设置修改；中断恢复后主机未发现自有旧观察/构建/syslog/守卫进程，未借此声称设备原生PID为0或重新验过当前Home。13继续主设备，下一独立项为音轨切换输出与实际画面；先现场核目标/最新包。听音或实际声学输出未取证前不报AUD通过；PiP同条件旧失败、精确seek旧输入不重播。18仍06:52包，07:33更新缺实时连接身份，正常首页按用户暂缓，本离线批零探测/安装；Pad零操作。
