# 本地媒体清单供给与消费者边界

2026-10-21晚间慢供给，2026-10-22 01:18–01:20快速内容对照与最终核对。关联PX-03，沿用[19:52正常Debug诊断包](2026-10-21-CANDIDATE-REQUEST-DIAGNOSTICS.md)，零App源码改动/构建/安装，未追加第三轮同条件NAS真片。设备13每窗现场核iPhone14,5/iOS16.3.1/USB、173源码输入/dirty diff、三二进制/IPA、29库逐签/深签及profile、本机保留数据安装回执。18按用户“稍后，先继续其他工作”暂缓，Pad未操作，均仍15:39历史包；不能沿用为最新19:52回归。[结构化结果](../../../testing/results/2026-10/2026-10-22-local-media-playlist-boundary.json)；身份、端点、完整偏好、原图、脚本和日志仅在`/tmp/nastart-local-media-playlist-evidence`所指私有目录，prior指回最新包私有目录。

## 可控条件与范围

目标是区分媒体清单响应头/正文与客户端消费，不重做10-20的4.5秒首TS/codec/片长实验。复用保存的H.264/AAC、852×480、23.976fps两TS（121072/646156bytes），各2.002秒。master164bytes立即交付；VOD media1620153bytes、TARGET5、sequence0、ENDLIST与两段EXTINF不变，实际段条目前加90000行短注释制造长正文。慢供给每个读者独立25秒匀速、32768bytes块，HTTP/1.1头与Content-Length立即写出。快对照完全相同master/media/TS字节，只立即发送正文。

使用现有显式Debug playback-lab：greenfield、m3u8、jellyfin、PROXY=0/1、PREWARM=0，逐窗核实际env。**此入口是initial systemAVPlayer，未调用候选GreenfieldAVPlayerWarmup.prepare**，不是普通入口、精确候选复现或功能修复。人工注释长清单也不等于真实1880段VOD。每个条件仅一窗，快对照与慢窗跨日，不能当性能配对/统一超时公式/全格式验收；没有NAS媒体与蜂窝流量。

## 保留零请求的控制失败

1. 初始native stop/WDA launch后bundle/env组合断言失败，未保留实际字段，具体不匹配未知；零fixture请求，不算播放失败。
2. 正常首页恢复创建了新session，而后续复用旧ID，收到404 invalid session；零fixture请求，不重发动作。

两窗均finally停App/fixture/采集/守卫，偏好/崩溃清单不变并恢复正常首页。随后每条件创建新session并保存返回ID、有限前台只读等待与env核对。没有重建/安装/重启持久13 WDA，控制失败不归为App媒体根因。新session会替换旧会话的上游机制见[WDA session实现](https://raw.githubusercontent.com/appium/WebDriverAgent/v16.8.0/WebDriverAgentLib/Routing/FBSession.m)；现场结论以实际404及新session请求为准，不以外部版本代替已装Runner身份。

## 结果

| 条件 | 服务端/代理边界 | App与实际图 |
| --- | --- | --- |
| 25秒直连，40秒观察 | master完成；media响应头立即，正文持续到达，写1277952/1620153bytes后BrokenPipe，request→end20.227秒；零TS请求 | itemInstalled→failed内部elapsed20184ms，NSURLErrorDomain/-1008；t40原生“无法播放媒体/无可用资源”，无有效视频帧 |
| 25秒生产代理，40秒观察 | master164→233bytes完整发出；media上游1620153bytes/25.002秒完成；客户端读方向结束20014ms；item失败后才完成重写1620297bytes，header completion=true，但body completion=0、clientFailed/posix54，零TS请求 | failed内部elapsed20242ms，NSURLErrorDomain/-1008；t40同样失败。上游成功不能算播放器收到/播放成功；读EOF单独不证明接收关闭 |
| 相同内容立即直连，15秒观察 | media完整1620153bytes，request→end0.645秒；两个TS均单GET完整发送 | ready内部1608ms，playing1706ms，clock0.501信号2259ms（不是屏幕首帧）；t1仍黑，t3实际暗色星空画面、00:02/00:04，后续自然到约3.969秒。startup stall1/15ms保留，不以此作性能或听音/完整帧验收 |

这提供了“同内容可以解码，缓慢完成可触发失败”的有限反例，否定把本fixture失败单独归为代理不发响应头或内容必定无效；不能证明所有AV都有固定20秒超时，不能将NAS候选失败强行绑定该media URI，也不能解释CoreMedia/-12884全部含义。19:52包新增的收/发计量在本次明确区分了上游完成、header完成、body失败；未改供给、缓存、等待或重试策略。

## 收尾与下一步

每窗外层finally与60秒独立守卫均保留。三内容窗全部非诊断偏好逐值相同（含36书签原轨道及进度，零增删），App/WDA/Jetsam清单零新增；App/fixture server/自有syslog/守卫已停。01:19恢复空env/空参数，25完整偏好一致，原生首页NAS在线/最终Home无PiP与Wi-Fi已看；01:20再核173输入/包/29库、当前有效session设置auto/idle10/cool2、全部fixture端口关闭与自有媒体/构建进程零残留。网络/SSID/蜂窝/VPN/NAS均未改，持久13 WDA保留。正常首页是功能恢复证据，不当新冷启动提速成绩。

本批到此停止追加同类慢清单/同条件NAS播放，不调大等待或重复预热。若实施清单流式交付，必须先证明逐行URI认证/相对地址/UTF-8块边界、EXT-X-START插入、未知/无效/非VOD、长度/Range、缓存仅完整提交、取消后不重开及原格式族回归；这只是接线门槛，当前产品仍完整缓冲后重写发送。转向已有轨道保存问题的离线内存提交/磁盘可见性审查，系统X关闭、原片字幕/PiP、音画/长稳、18最新包仍待条件；28项开放不变。
