# 从头PGS/Off首片协议对照与Mac建连干扰

2026-10-19 17:57～18:17。关联PX-01/PX-20，接续[输入快照审计](2026-10-19-SEEK-INPUT-SNAPSHOT-AUDIT.md)后独立调查0秒首片，不依赖精确seek手势。新[结构化结果](../../../testing/results/2026-10/PGS-FIRST-SEGMENT-PROTOCOL-20261019.json)仅为Mac到真实Jellyfin的协议诊断，不是真机、蜂窝或播放器呈现验收，28项均开放。

## 条件与边界

App产品/测试源码和17:16普通Debug包均未变，HEAD 4de732dd加原修改、ios差异139d9310…与173输入再次一致；没有构建、安装或设备请求。13/Pad/18本批未动，不新称安装或Wi-Fi核验；17:28原网络证据只属于前批。未改NAS、反代、VPN、IPv6或系统设置。

Jellyfin现场版本10.11.11。S03由唯一Item/MediaSource元数据核实，服务端报告54,005,939,750 bytes、7524.768秒，源HEVC3840×2160，固定源音轨Index1/TrueHD6声道；字幕7确为PGS，5/6是ASS，本批不覆盖ASS。

请求固定从头0秒、总上限2Mbps、H.2641.616Mbps/AAC384kbps、尺寸上限854×480、HLS4秒/MinSegments1，仅切PGS7 Encode/Off。每条独立PlaySessionId均从PlaybackInfo返回，并核master/媒体清单/首片URL继承该ID及独立诊断DeviceId。每窗仅GET首片0.ts一次；首片上限2MiB，清单3MiB，25秒请求上限、60秒round alarm（清理在alarm取消后，不能当整个含清理墙钟均≤60秒）。每条媒体完成/失败均finally关闭读取并按精确自有DeviceId+PlaySessionId停止编码；公共路由清理另备同服务器已核实LAN回退，本批未用回退。

内网与公网urllib各按PGS/Off/Off/PGS/PGS/Off顺序执行，每条件三次；随后公网curl各一窗只用于新增分段计时，不补进三次统计。冷缓存/源文件页缓存未知，未清缓存；没有并发自有媒体。服务端额外1920×1080同源日志存在，不能宣称全服务器无其他负载。

## 观测结果

以下前三列为调用open/启动传输→收到响应头，**包含DNS/TCP/TLS建连**，不是旧URLSession request-end→response-start的requestMs；不能直接相减或当纯NAS处理时间。

| 路线与工具 | PGS秒，中位数[范围] | Off秒，中位数[范围] | 完成/失败 |
| --- | --- | --- | --- |
| Mac内网HTTP/1.1、urllib | 2.285 [2.210,2.360] | 2.168 [2.167,2.270] | 各3/0 |
| Mac已核配置公网HTTPS/1.1、urllib | 8.076 [7.992,12.361] | 8.009 [7.966,10.082] | 各3/0；被本机建连干扰，不作供给排名 |
| 同公网curl8.7.1/HTTP1.1，新增诊断 | 2.443931，单窗 | 2.441168，单窗 | 各1/0；非可靠分位数 |

公网不是从脱敏日志猜测：从本机原NAS配置与旧诊断端口取得候选，先匿名/System/Info/Public、正常TLS校验并确认ServerId与LAN相同，之后才使用既有令牌。公网配置未改。Mac实际接口/出口未测，此处内网/公网仅按目标地址分组，不证明物理Wi-Fi或无VPN链路。

curl两首片的pretransfer→first-byte均约2.210秒，连接/TLS就绪约0.23秒；这一边界仍包含发出小GET和网络往返，不冒充服务器首片生成时间。14窗均200、744,480 bytes，合计首片正文10,422,720 bytes（非IP/计费总量），SHA-256完全相同；CoreMedia对保存TS内H.264 SPS/PPS解析确认852×480，未解码帧、听音或验字幕内容。服务端候选日志对应PGS7 overlay/Off，不能从片头首4秒二进制相同推出全片字幕无差异。

## 额外延迟定位于本机工具

只用匿名小型元数据做urllib/curl/urllib/curl交错，避免新增媒体：urllib到头4.391/6.733秒，其中DNS约0.004/0.001秒，DNS+TCP约4.314/6.699秒；curl相应到头0.281/0.320秒。

再对一次urllib请求包装socket.connect、参数不变：IPv6（Darwin AF_INET6=30）7.429545秒后ENETUNREACH/errno51，随后IPv4（AF_INET=2）0.000672秒连接成功；总到头7.465889秒，ServerId一致。额外时间已在这次Mac顺序地址建连内出现，不是DNS解析或这次PGS视频处理。没有关闭IPv6或改VPN。

**不能用该Mac工具问题重标旧iPhone15.392秒等头。** 旧窗h2且连接复用、requestMs排除建连；本批Mac/H1、客户端、网络接口/缓存/负载都不同。当前条件下PGS/Off均未在可靠curl分段边界复现旧等待，也不能排除真实冷启动、弱蜂窝或其他负载下的PGS交互，未形成App性能修复。

## 服务端绑定、失败和收尾

14个协商PlaySessionId唯一，协商响应→实际请求URL绑定明确；14次精确作用域DELETE均204，客户端媒体读均关闭，三个批次remainingOwnedSessions均0。后续只读Sessions中没有这些诊断DeviceId的NowPlaying/TranscodingInfo；**这本身不证明编码进程退出**。主日志/FFmpeg捕获的15个真实候选中14个与输出尺寸/PGS条件兼容，另一个同源1080p不兼容候选保留并排除归属；缺少PlaySessionId→输出job的直接服务端映射及首片创建时刻，不以近时日志证明精确会话或全局隔离。没有停止其他设备/用户会话。

保留：旧上下文别名不存在（HTTP前失败）；首次把脱敏主机当地址，IDNA编码前失败（未发网络或令牌）；后用原配置及匿名身份核对纠正。一次离线glob还误含两个curl响应头文件，已改为精确FFmpeg文件名匹配，15候选/14兼容的最终计数不混入这些工具文件。原始失败均留私有。

无新手机蜂窝任务，未动任何原生Wi-Fi/蜂窝/VPN，不能把前批17:28状态写为本批重新核验。自有媒体/采集结束，持久WDA保留；无App/其他仓库未提交修改被回退。私有入口/tmp/nastart-pgs-first-segment-evidence，含配置/令牌、URL/身份、首片、日志、原始curl指标及一次性探针；共享结果不含这些私有值。保活随命令生命周期，开始断言未另存，仅保存中途/最终及同窗电源核对，不作完整性能环境验收。

下一步回到正常包的iPhone用户报告弱蜂窝，从头0秒同入口PGS/Off，先逐台核包/设备/当前用户现场；用URLSession已复用连接的请求/首片正文及同窗服务端证据，保留输出/缓存未知，finally先停流量恢复并核实原Wi-Fi。精确seek候选仍否定，不重复像素/归一化调参；协议对照不升级为矩阵P。

最终检查：331文档/1656本地链接、缺失0，git diff --check通过；未重复XCTest/既有92报告测试。17:55～18:22同窗Sleep/Wake/DarkWake0，自有构建/采集进程0。
