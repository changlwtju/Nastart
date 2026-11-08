# 客户端请求与编码输出的最小关联观测

2026-10-20，接续[零定位/主日志补证](2026-10-20-AV-ZERO-SEEK-AND-SERVER-LOG.md)。[结构化结果](../../../testing/results/2026-10/CLIENT-OUTPUT-CORRELATION-20261020.json)。关联PX-01/PX-03/PX-20，28项开放；本批增加诊断，不改变播放、分片、缓冲、预算、超时或定位策略，不称蜂窝性能修复。

## 先验证关联算法

旧9个协议任务以工具默认UA假设匹配0/9，保留失败，不追溯补填。新做一次独立Mac LAN协议窗口：现场服务器身份/版本10.11.11、S03来源/54,005,939,750bytes及PGS7核验；唯一诊断DeviceId、协商PlaySessionId，显式同一User-Agent贯穿请求，2Mbps/H264/AAC/854×480上限/PGS7/4秒片/min1/0秒。事前Sessions未报告播放或转码，但该接口不能证明所有入口无流，另核当前交接和本机进程无其他媒体任务。

仅取一个首片，744,480bytes，HTTP200/1.1；等响应头2.338987秒，正文约0.064942秒，完整2.403929秒。正文少于2MiB守卫、轮次60秒上限。精确DeviceId/PlaySessionId停止204，自有会话集合0，FFmpeg退出行已见，保活包装任务正常退出。未动手机、Wi-Fi、蜂窝、NAS/VPN或服务器设置；缓存状态未知，不作冷启动或手机提速比较。

用官方10.11.11路径/实际显式UA/设备/会话→UTF16LE MD5→.NET Guid字节序，预测输出标识与该FFmpeg日志唯一stem准确匹配。它证明该协议单窗可用，不证明旧0/9原因、手机实际头可取得或反代不改写，也不能提供首片可读时刻或宿主时钟同步。

## 最小代码变化及反例

`PlaybackDiagnostics.swift`新增`PlaybackJellyfinOutputDiagnostics`：按服务端规则选择EncoderPath（必须非空且有EncoderProtocol）或Path，结合URLSession transaction实际请求UA、唯一DeviceId/PlaySessionId生成仅用于比对的`jellyfinOutputKeyCandidate`。原始路径/UA/会话/凭据不写入此字段。初版对缺头/缺身份/重复参数/legacy Params/重定向标unknown（下文记录Params解析的后续修正）；非Jellyfin原流不增加候选。

`DevicesView.swift`设备文件匹配HLS、`LaunchpadView.swift`Jellyfin协商HLS都把来源路径放入各自proxy Route，再由Route生命周期传给Transfer；只在完成的metrics回调补诊断候选，不增加媒体请求，不改变请求头、会话、重试或取消。Route撤销仍释放自身元数据，原有任务隔离保持。公式明确标10.11.11候选，必须与真实日志核对，不能把它当已确认会话/首帧。

4项iOS定向测试通过：包含Unicode及非BMP字符的跨语言金向量、无原值泄露；不同UA变更结果；缺失/重复身份/Params；缺头/重定向unknown及EncoderPath条件。15项预检通过，Xcode27普通Debug编译成功；173输入冻结、29库逐一/深签名、链接与清洁IPA哈希核验，沿用既有三设备profile。包与私有标识仅本机证据区，详见结构化摘要。

`scripts/playback_server_log_report.py`增加可选私有输出key提取与metrics候选比对：唯一key可排除同时间/同序号的其他任务，冲突/不匹配不降级为时间巧合；同key多次编码保留歧义、其他起始序号保留已有任务证据。分享报告剔除私有key，仍不声称sessionIdentityVerified或首片可读。4项新增反例连同既有测试共28项通过。手机实际字段尚未验，不能回填旧日志缺失字段。

## iOS实测失败与等待分段

00:57诊断包已备份并保留数据覆盖13，25项非诊断偏好保持，空环境正常首页实际核实。S19/JF真实蜂窝45秒普通退出：24个完成metrics均cellular=yes，输出关联候选24/24 unknown，重定向计数0。不能把Mac单窗算法验证升级成手机可用，更不能回填旧任务绑定。

本窗media清单等头155ms、正文3508ms、总3663ms；首片等头2561ms、正文1385ms、总3947ms。内部播放时钟12.460秒才推进，maxStall1；t10实际黑屏转圈、网速未知，t45黑色影片画面中上下位置各有不同双语绿色cue，字幕正确性未验。清单正文与首片等头是独立耗时，不把全部余时归成解码或无线信号。与旧0.582/0.709秒清单窗口均保留，单窗不作性能配对。

最外层finally已终止自有App/媒体、还原原生原SSID；首次恢复截图仍4G，随后独立原生截图实际见Wi-Fi图标才记收尾完成。未动SIM/VPN。后续细分unknown为缺UA、缺query、legacy Params、身份缺失/重复或重定向；仅改诊断，不改HTTP头及播放行为。4项定向测试及普通真机构建再次通过。

## Params缺口修正及双入口真实关联

01:06原因细分包在13上S03/JF单窗17个metrics均为legacyParamsNotDecoded，UA可读，不能再归因于系统缺头。内部推进11.359秒；首片第一次等头5249ms，客户端读侧先结束、迟到200后发送失败并取消，再请求819ms等头+963ms正文；保留所有尝试。原偏好/轨道保持、普通退出且实际恢复原Wi-Fi。

仅诊断解析按官方10.11.11 StreamingHelpers.ParseParams补slot1 DeviceId/slot20 PlaySessionId优先级：非空白位置覆盖query但保留原字节，空白位置保留query；重复Params/身份仍拒绝。Unicode金向量、覆盖/空白/缺失/歧义/无原值泄露共5项iOS定向通过，15预检及普通真机构建通过。没有改请求头、URL或播放/缓冲策略。

06:48新包13上S03/JF及设备文件分别21/34个metrics全cellular=yes，每窗唯一输出候选均精确匹配服务端唯一一次0号编码命令。JF为PGS叠加10Mbps，文件为2Mbps/无叠加，不能严格比较入口速度；内部推进8.583/6.909秒，maxStall均1，首片等头2717/2199ms。匹配不提供跨主机同步时钟或首片实际可读时刻，分享报告将未校准的服务端相对秒置null。

三窗原申请20秒，但旧工具固定采样点含30秒，实际最后观测30.27/30.27/30.24秒；保留超时长事实，已修私有工具排除目标时长之后的采样点，不重跑掩盖。每窗最外层finally停App及媒体，原SSID已选但首次恢复图仍4G，随后独立原生截图见Wi-Fi图标才做分析。偏好及原轨道不变，相比19日最终库存新增App/WDA/Jetsam均0。当前吞吐观测是已完成且无背压片正文约4MB/s中位，不证明无线RSRP/RSRQ/SINR，也不能把秒级首片等头全部归成弱信号。

## 一字节首片准备可行性（尚未产品实现）

手机已停流/恢复Wi-Fi后，Mac LAN单个独立S03/2Mbps/PGS7协议任务确认首片Range bytes=0-0返回206、Content-Range正确且仅1字节，等头2.271秒；随后同任务完整GET等头0.057秒、744480bytes。精确DeviceId/PlaySession停止204，自有集合0，日志退出行已见。此为把编码准备与清单下载重叠的可行性，未证明真机收益，也未实现primer；续播目标片、会话取消/重复读、服务器不支持Range及不增加无用编码均需反例，不能直接提前取0号片。

完整清单仍由Jellyfin官方生成器产生，重封装存在关键帧分段，不盲造等长清单、缩短全局分片或删零定位。可核官方[生成器](https://github.com/jellyfin/jellyfin/blob/v10.11.11/src/Jellyfin.MediaEncoding.Hls/Playlist/DynamicHlsPlaylistGenerator.cs)及[Params规则](https://github.com/jellyfin/jellyfin/blob/v10.11.11/Jellyfin.Api/Helpers/StreamingHelpers.cs)。

## 当前构建、安装及收尾

最新06:48:25普通Debug/-Onone，iOS差异`35df7015b08ee4d929683983de8ac59d2d7111f94615bf85f38894fc25ae66ed`；173输入、29库逐一/深签名、链接及IPA核验。旧ditto归档含160项AppleDouble，18发送前按已有检查发现并清洁重包，二进制/签名未变；相关坏包保留，未发至18。13/Pad分别保留25/18项偏好覆盖，空环境正常首页/Wi-Fi实际已看，NAS卡未连接，不宣称NAS健康；Pad尚未新包播放。

[18有线安装](2026-10-20-IPHONE18-USB-INSTALL.md)已完成：无线实时配对身份有效，但打开App后备份及CoreDeviceProxy仍断开；用户改USB后现场有线身份及connected隧道、备份、原生安装、正常空环境启动/原生首页截图均通过，25项非诊断偏好连同书签逐值一致。随后用户已带18离家，不再操作18，13/Pad重新接回Mac后须现场重核。

Pad复用既有签名Runner恢复ready，未重建/安装；因用户插入18安装主动停止本批Runner，未发Pad播放。模拟器测试后已Shutdown，无自有协议/播放/保活残留；持久Phone WDA/转发保留。完整音字幕/深seek及28需求仍开放，TV原阻塞不变，DSM暂停/禁止更新维持。
