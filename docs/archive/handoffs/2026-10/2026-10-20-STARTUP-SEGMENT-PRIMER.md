# 完整 VOD 后的单字节首片准备候选

日期：2026-10-20。用户再次明确阶段后直接接续；本批已从反例验证推进到共用实现、普通签名包与真机回归，不新建调度。前置证据见[重叠边界](2026-10-20-STARTUP-OVERLAP-BOUNDARIES.md)。

## 变更卡与实际实现

问题：媒体清单已完整预热后，首片仍等播放器呈现/安装才开始生成。旧同窗可覆盖的排程空间JF约1.172秒、文件0.471秒，是上限而非收益承诺。

最小候选：在既有蜂窝从头播放、完整VOD预热返回前启动可取消的1字节首片请求，调用方不用等待该片响应；解析真实重写后的首URI，不合成播放清单或猜片名。设备文件和Jellyfin使用同一实现。只允许同route本地child TS且解析到真实上游首片ordinal0，同scheme/host/port、Jellyfin源路径存在；只有完整ENDLIST、无加密/key/map/byterange/显式起点/非零mediaSequence/变体等才进入。Jellyfin非零startTicks不启用；设备文件原调用只在startSeconds=nil预热。此前原流、Wi-Fi、live、恢复/深seek不新增primer。

归属与收尾：每route仅一个primer对象，5秒独立截止；注销、非零定位或预热取消时取消本route primer及其上游任务，不触碰其他route/普通播放器请求。显式permit防止取消发生在排队/派发之间后又启动；处理本地请求时再核primer仍活跃及未设新起点。

内部loopback采用NWConnection只发送一次，避免URLSession对无HTTP响应的本地GET自动重发；上游继续复用原代理的认证、连接、任务诊断及取消路径。内部marker不转发给上游。响应必须206、Content-Length1、Content-Range bytes0-0/正数；否则取消正文，禁止重定向。可选准备既不计实时播放下载速度，也不进入完成/窗口容量估计。若网络栈在MIME判定前未交付response回调，仍由独立截止取消，不等该回调释放资源；不是宣称任何线上字节硬上限。

源码映射：`PlaybackPlanningPolicy.swift/PlaybackHLSStartupPrimerPolicy`选URI/校验回应；`DevicesView.swift/AuthenticatedMediaStreamProxy.prewarmVODPlaylist`负责两入口共用接入、route/permit、NWConnection一次请求；`AuthenticatedMediaProxyTransfer`在接受正文前校验、限制重定向、隔离估计及取消。`LaunchpadView.swift`只把已知从头条件传入，不额外探测NAS或改画质/字幕/AV等待策略。

报告工具识别startupPrimer=true并将它留在excludedSegmentRequests/optionalStartupPrimer，播放器首片边界仍取实际消费者请求。避免把1字节准备当重复播放器请求/已出画。30项报告工具测试通过。

## 确定性反例与失败保留

最终7项iOS定向/0失败，15预检通过：完整/嵌套VOD与live/master/跨route/端口/查询/格式/key/map/byterange/start/非零序列；返回头被控制住时预热仍返回；重复调用单次；A注销不取消B，B单字节完成；本地marker未上游泄漏；Range忽略和redirect不交付正文；非零片序/显式续播跳过；准备取消不再发片；无MIME且不完整回应独立5秒截止、定位取消已派发任务，不重试或写容量样本。沿用既有默认只预热清单的两个反例，未改变其默认语义。

前三个诊断运行保留同一测试的失败：最初自定义回应声明10MB但只发送头/不足MIME判定的字节，CFNetwork在响应回调前等待；第一种内部URLSession还可能重试loopback。不能把这些失败丢掉或都归为播放器问题。改为一次NWConnection且增加独立取消传播；有明确video/mp2t的200/Range忽略在头路径拒绝，无MIME原反例改为单独截止验收。最终源码冻结后重跑7项通过，时长约5.32秒；未把早期源码交叉修改过程当最终构建证据。

## 普通包与真机边界

普通Debug/-Onone/Xcode27，09:06:22构建，iOS差异`0d54a71cf005386dad2485805d78af9ca36bd2a2c08a7c6981083513b3f806bf`；173输入、29库逐个/整体签名、链接及清洁IPA CRC/三二进制核验。全部私有路径/哈希、设备身份、原始偏好和日志见本机指针`/tmp/nastart-startup-primer-evidence`，公共[结构化结果](../../../testing/results/2026-10/STARTUP-SEGMENT-PRIMER-20261020.json)只放安全字段。

13已现场核USB身份、备份诊断/偏好后保留数据覆盖，25项非诊断偏好完全一致；实际空环境首页/Wi-Fi已看，初始NAS卡未连接不当健康通过。首次S01工具因新证据区缺参考身份文件在开播前停止，补齐私有参考后重新现场核实才发播放；JF30秒基础出画/普通退出已完成。其余新包回归正在接续，结果更新同一批次，不把安装或内部时钟当性能/音字幕验收。18仍随用户离家，不操作；其06:48旧包成功记录不代表安装此新候选。

## 接下来的验收

先完成新包S01双机双入口，再13真实蜂窝S03两入口，核primer实际触发/1byte/同输出任务、真实播放器首片/首帧与全部失败、收尾先停自有流量恢复原Wi-Fi/图标；若无收益或退化按两轮规则停实验。S19、深seek/完整音字幕、HDR PiP及总账28项继续开放。该候选尚未实测证明提速，不标已解决蜂窝等待。

## 真机结果、停用及恢复（09:47包）

09:06候选在13/Pad S01四单元各30秒均普通退出/抽帧出画，本轮采样stall均0，只是基础回归。13与Pad覆盖分别保持25/18非诊断偏好。蜂窝最初设置页面工具失败发生在关闭Wi-Fi/播放之前，初次日志被同名finally日志覆盖的工具缺口已保留并修为逐调用文件；独立原生勾选原SSID和Wi-Fi图标证实无蜂窝播放。之后S03两入口真实4G各20秒完成普通退出，所有23/18完成metrics为cellular=yes；两轮finally先停App，首次恢复图仍4G，后续独立源树/原生图实际见原Wi-Fi才记恢复。

| 候选窗口 | 内部clock推进 | 最大采样stall | primer | 真正播放器首片 |
| --- | --- | --- | --- | --- |
| JF | 9.656759秒 | 1 | 206/1byte，requestMs5000 | 首次等头4468ms仅28430bytes后客户端发送EPIPE32，另一完整请求128ms头+599ms正文/1355480bytes |
| 文件 | 6.224480秒 | 1 | 206/1byte，requestMs2509 | 单GET等头2128ms+508ms正文/1941476bytes |

primer与普通消费者输出候选一致；两次有界只读主日志各71963bytes，各仅匹配1条编码命令，JF有PGS overlay、文件无overlay。服务端时钟未对齐，不填跨宿主生成耗时。JF未达预期，文件实际码率/字幕与旧基线不同，不能称可靠提速。两入口普通调用已停用primer，保留经过反例测试的显式可选基础设施，不继续改截止/缓冲参数碰运气。

另取同客户端因果顺序：JF primer3.063秒派发，真正首片3.586秒派发；旧客户端读方向EOF7.582秒，新首片请求7.619秒已经发出，旧请求8.084秒才在clientBodySend报告EPIPE并取消上游。不能把读取EOF等同完整关闭，也不把客户端随后重请求叫二次转码。约4秒后重发只是本窗边界；此前Mac相同4.5秒延迟fixture没有重请求，故不能断言AV跨平台有统一4秒超时，更不能重做删零seek实验。

停用后同源7项定向/0失败再次通过并重建09:47:40普通Debug，iOS差异`39b0bdc21ea6e43e8c357d1c26ae78f8f87f63b69c301ae20d8b5ba717a45591`，173输入/29签名库/链接/IPA核验，13/Pad均再次保留数据覆盖并核普通空环境首页与实际Wi-Fi。Pad原生首页实见NAS正常，其余卡未知；13首页NAS卡未连接而个别服务在线，不扩大为全环境正常。18离家未安装本批两包。

下一阶段按真实手机的请求重发边界取证，先复用Mac反例，再设计受控本地故障样本；不把单字节候选继续固化为性能修复。最新关闭实验后的包尚未完成完整音字幕/大文件/深seek验收，不能沿用09:06或06:48包成绩。
