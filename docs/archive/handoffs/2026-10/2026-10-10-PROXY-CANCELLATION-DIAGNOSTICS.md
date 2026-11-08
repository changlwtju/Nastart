# 首分片取消与迟到回调诊断

2026-10-10T06:58:26.000+08:00 本批诊断/定向回归收尾。关联 PX-01/PX-03/PX-20/PX-21；取消诊断遗漏已修正，弱网卡顿仍FAIL，不关闭性能或全局验收。

前包慢手机窗同首分片出现三个重叠请求，两个client失败无真实完成/metrics。代码finish清空self.task且完成回调要求未finished，证据丢失有直接源码支持。Xcode SDK确认task delegate强引用至完成，故不保留任务或延长代理资源生命周期。

本批新增加锁数值任务身份/单调时钟诊断；当前任务的迟到metrics和完成仍记录，旧重试任务拒绝，关闭后的metrics不计容量；清空前冻结压力诊断。正常完成不当取消，重复结束不覆盖原取消时间。底层NWError补posix/dns/tls类型与数值，不导出私密文本。传输/超时/重试/连接数/解码/选流门槛不变。

L0：233测试/2跳过/0失败、15预检、16安全分析测试已完成。首次复合字典编译过长已拆分，原失败日志保留。4确定性诊断反例和2工具反例覆盖迟到/旧重试/正常完成/重复取消及失败/未知/隐私，不替代真机取消证据。

新普通 Debug -Onone 构建 2026-10-10T06:20:56.353656+08:00；HEAD 4de732dd645b36671becff992cdef1d0163fd1e4；工作区ios差异SHA-256 3e4b4851e620ad1f066c2d501901acd06c20028f423b43e2c67a448a02ff5127。包路径 /Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-proxy-cancellation-061739/Nastart-Proxy-Cancellation-Normal-Debug.app。
二进制 SHA-256：{"Nastart": "0446076c4705be581f4d6abdde62ab23a07a642dc8baa46a39de7a74ec6948f5", "Nastart.debug.dylib": "99b8b6a1b4c554150746fa8b7d4722dc37aa2fd6b735f400122047ab80f1dbd6", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}。
29库/deep验签、137输入不晚于构建与链接已核；签名有效至2026-10-10T22:03:15 UTC。

两机现场USB/配对：iPhone13/iPhone14,5/iOS16.3.1/20D67，iPad9/iPad12,1/iOS18.3.1/22D72，UDID仅本机私有证据。均保存旧故障后保留数据覆盖；25/16非诊断偏好安装后及空环境正常启动后完全一致，实际启动台/NAS正常已核。安装时间与全部包哈希逐机在私有install-summary-safe.json。iPhone18本批未连接/未更新，不能当最新包验收。

L1已执行：每机3×90秒MI2文件，原生家庭Wi-Fi受控40/33Mbps/双向1ms/0丢包，无App测试环境，串行执行，原失败保留。L2本批已执行S01双机双入口各90秒，另有两个iPad文件30秒控件窗；未改共享传输行为，全格式族/正式完整矩阵仍开放。最终空环境/原生条件inactive/WDA idle10已核。

私有证据 /Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-proxy-cancellation-061739。原包/旧失败与新包严格分列。本批不以内部缓冲计数、稀疏截图或完成动作证明流畅、声音、完整字幕及竞品PASS。

阶段观测（手机三弱窗，仅本普通包）：request→commit 为17.150720、7.227625、7.661392秒，三原KS各采样最大1次等待，候选AV为0/1/1（须按首实际推进前后分列）。首慢窗第一首段issued12.335695、headers21.917904/9.582209秒，系统requestMs9582、h2/连接复用、taskInterval9587ms，发送给client时POSIX32；cancel标记21.940709，metrics21.941096/完成21.941601，cancel→完成2ms/-999。第二同首段issued16.358749、headers22.147181/5.788432秒、完整22.484995，两请求重叠，不能相加。其他两首段头等待2.298083/2.297016秒。说明慢区间在可观测请求→响应等待内，尚未证明网络、转码、服务端或回调细分根因；取消动作本身快不能证明客户端放弃时立即检测到了关闭。

下一层假设：当前代理在读完HTTP头后不继续接收客户端；是否直到响应写入才发现已关闭客户端仍待观测。必须先补读侧结束/错误时间、真实请求发出与服务端首段就绪边界，不能见FIN便取消正常GET。[Apple receive completion](https://developer.apple.com/documentation/network/nw_connection_receive_completion_t) 说明TCP完成标记表示读方向结束；[send](https://developer.apple.com/documentation/network/nwconnection/send(content:contentcontext:iscomplete:completion:)-5ecuz) 区分写方向关闭。因此后续需要合法半关闭仍可收响应、RST真正断开、重叠请求/Range/HLS的fixture与设备证据，再决定行为修复。这里是源码/协议推断，尚无本机客户端提前FIN/RST实测，不把它当已证根因。

口径限制：新manifest完成标记沿用代理的binary received计数，该计数不累加playlistBody，故其taskReceivedBytes/cumulativeReceivedBytes=0不得解释为清单没下载；清单正文采用playlistRewritten.inputBytes或最终deliveredBytes与实际metrics。失败/取消缺responseEndDate的字段保留unknown，不补0。毫秒值截断，0ms表示低于1ms的观测，不是零耗时。

弱窗请求至提交：手机三次17.150720/7.227625/7.661392秒，中位7.661392、范围7.227625～17.150720；iPad三次8.686569/9.300118/7.761715秒，中位8.686569、范围7.761715～9.300118。仅同包探索性重复，不作稳定P95或因果速度比较。六窗原KS均首实际推进后等待，最大计数每窗1；两设备候选AV均0/1/1，有等待的四窗在其首实际推进前。五个原KS等待区间未观察到结束，右删失保留，不能以接手动作填恢复时点。

弱六窗共13个取消transfer（手机7/iPad6），全部有迟到metrics/完成；手机取消完成0～2ms、iPad1～2ms（截断口径）。只有首手机一个首段取消，其余主要原流Range探测/替换。此观测范围不代表所有进程任务或所有用户退出。

S01 iPad文件90秒基线首推进前1次短等待，已结束报告382ms；媒体库采样计数0。两实际90秒图均动画列车/人物开场，正文、声音/字幕/完整帧/质量不验收。控件首次延迟坐标点击后未观测到暂停；第二次可见元素方法在实际点击前按钮可见性超时/RuntimeError，均保留为未确认/TOOL，不能当App暂停已通过或已失败。第三个独立30秒窗采用fresh visible坐标直接点击：33.151678请求暂停→33.585136返回，图标play.fill，00:32在35.187920/39.405233两次图上保持；39.851486请求恢复→40.291473返回，图标pause.fill，44.077708显示00:35、49.189492显示00:40。动作/可见性/时钟/实际截图一致，本包此限定序列成立；旧包t60play.fill差异未复现，不宣称修复。额外两控件窗片头天空/字幕不作正文结果，均普通退出。

逐机最后安装核对（同一普通0446/99b8/KSeda1包，完整SHA与路径见上文）：

| 设备 | 最新保留数据覆盖及正常启动核对时间（+08:00） | 核对结论 |
| --- | --- | --- |
| iPhone13/iPhone14,5/16.3.1/20D67 | 2026-10-10T06:49:01.134255 | 新鲜USB身份/配对、29库/deep/137输入、包哈希、覆盖成功、25非诊断偏好及实际空环境首页均已核；此前6:22门槛证据在gates-initial中保留 |
| iPad9/iPad12,1/18.3.1/22D72 | 2026-10-10T06:30:32.255252 | 切设备前重新现场核对并覆盖，新鲜USB身份/配对、29库/deep/137输入、包哈希、16非诊断偏好及实际空环境首页均已核；此前6:23门槛在gates-initial中保留 |

收尾：本普通包12个完整观察窗/12原时点普通退出，10个90秒基线（6 MI2真人电影、4 S01动画人物开场）与2个30秒控件片头窗分列。手机两常规S01采样计数0，iPad媒体库0/文件起播前1次382ms；未出现可见播放错误，不能据此判流畅、正文连续播放、声音/字幕或质量PASS。诊断读取0失败；控件两次未确认/TOOL单独保留，没有从尝试总数中丢弃。

全部窗口共20个取消transfer（两设备各10），均收到迟到metrics与完成；取消至完成整体0～6ms，弱六窗子集13个0～2ms。普通退出后的证据独立记录exit-action及closedPreferencesResponseEnd，不延长90/30秒基线。范围内没有回调缺失，不证明所有进程任务都已覆盖。自适应估计仍只接受未结束的当前任务指标，迟到记录不会恢复客户端或触发重试/改选流。

新包构建后的有来源目录响应共68条（手机28/iPad40），全部success，旧2次API119未复现/仍未关闭；会话代际、服务端失效原因尚未证明。快照落盘尾部缺口继续由snapshotFreshness公开，不用退出后保存时间填补基线。逐窗、条件、安装及控件证据见[脱敏机器摘要](../../../testing/results/2026-10/PROXY-CANCELLATION-DIAGNOSTICS-20261010.json)。20个最终工具版本与原控件尝试源在私有used-tools目录及SHA清单保留；少量工具观测增补的时序也已说明，App源码/包在12窗期间始终不变。

最终06:54～06:55两机新鲜USB身份、当前源码/二进制、实际正常首页/NAS正常、真实processArguments空env/args、播放器退出、WDA ready/idleWait10/animation2及所有原生条件active0均已核。未改变Wi-Fi/VPN/路由、未卸载/清除登录；原偏好、凭据、设备UDID与原始记录仅在本机私有目录。其他未提交修改保留，无提交/推送/Main验收。

下一步先补客户端读侧结束/错误、重复请求出现、真正上游请求发出与服务端首段就绪的独立边界；合法半关闭、RST及重叠请求fixture先行，再决定最小取消/传输行为修复。继续拆身份查询/容量探测/协商子阶段与目录119会话刷新/代际。真实弱无线/蜂窝/外部Wi-Fi、S03/S08/S11/S18格式族、S19、声音/完整字幕/画质/完整帧、十分钟/PiP、Lenna及其他竞品、L2/19×4/全部PX/UX/CB/Main仍开放；iPhone18本批未连接/更新，仍前包。
