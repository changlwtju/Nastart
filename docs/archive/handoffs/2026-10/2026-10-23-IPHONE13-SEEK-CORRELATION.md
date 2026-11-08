# iPhone13切轨：已存队列、解码与供给离线关联

2026-10-23 17:28。承接[队列观测](2026-10-23-IPHONE13-SEEK-CAPACITY.md)与[音轨旧窗](2026-10-23-IPHONE13-AUDIO-SWITCH.md)。本批只分析保存的证据，**0设备命令/0播放/0下载/0构建/0安装**，不触发新网络或偏好操作；没有新增截图，最近实际播放图仍是16:39:01历史当窗图。173 App输入与iOS diff SHA重新逐项核同16:32包，保留所有其他dirty。原始日志/脚本/完整供给报告在本机私有指针`/tmp/nastart-iphone13-seek-correlation-evidence`。

## 两个包、四次请求独立关联

同一请求只按相同进程/planID/playbackTraceID与目标关联；使用seek开始到engine完成间最后一次decoder flush的local epoch，后续仅采集相同进程/epoch至下一次flush。旧恢复窗区间有2个flush，完整保留候选数量，采用最后一个；这是源码seek前/后队列清理的时序归组，**不是经过显式请求generation标签验证的decoder归属**。startupGeneration恒0不能当seek generation，epoch2/4也不能当用户第2/4次seek。初版离线脚本未识别旧engine_ready bufferFinished且多flush归组留空的部分结果保存，修正解析后才发布下表。

下表全部为同设备syslog记录之间的间隔，非CPU单次执行耗时；日志投递和线程调度有延迟。新包ready取seek_capacity_sample playable，旧包取engine_ready bufferFinished，保留各自事件语义。控制层恢复用seek_recovered；不与host派发、实际触屏或画面首帧混算。

| 包/请求 | request→engine完成 | 完成→首个视频send记录 | 首send→首个原始frame记录 | 首frame→ready | ready→控制层恢复 |
| --- | --- | --- | --- | --- | --- |
| 16:32 / 4→1 | 640.522ms | 178.347ms | 185.075ms | 401.195ms | 213.681ms |
| 16:32 / 1→4 | 109.701ms | 17.281ms | 267.546ms | 697.369ms | 200.453ms |
| 07:33历史 / 4→1 | 585.890ms | 3.835ms | 132.621ms | 622.547ms | 202.974ms |
| 07:33历史 / 1→4 | 761.934ms | 258.386ms | 549.422ms | 2149.289ms | 218.898ms |

FFmpeg packet trace写在`avcodec_send_packet`返回后，**不是包网络到达时间，也不是send开始时间**。首send至首frame包含后续包送入、重排、调度和解码，不能称单包解码耗时。原始frame trace在filter/conversion、seek过滤、入队与显示之前；不能拿回调数量冒充可用帧或真实画面。

## 视频储备与目标前压缩包

新包两窗ready前分别已有17/21条原始视频frame记录；中间waiting音频已足、视频仅0.292/0.125秒，ready时视频约1.043秒（16帧+9压缩包按FPS计算）。这证明本窗并非直到ready才首次解码出帧，仍不能由这些稀疏且非原子样本区分供给、解复用、decode、目标前过滤、格式转换和队列调度的时间占比。

| 包/请求 | 首视频包秒级PTS落后目标 | 12条有界packet样本中PTS早于目标 | ready前原始frame记录数 |
| --- | --- | --- | --- |
| 16:32 / 4→1 | 0.049s | 2/12 | 17 |
| 16:32 / 1→4 | 0.210s | 6/12 | 21 |
| 07:33历史 / 4→1 | 0.146s | 10/12 | 26 |
| 07:33历史 / 1→4 | 0.940s | 12/12 | 38 |

新包首视频包均key=true；旧恢复窗首包亦key=true、位置3961.458s，目标3962.398s。旧恢复窗“首原始frame之后仍等2.149秒”和目标前压缩包较多支持把**关键帧后追赶/有效视频储备形成**列为下一条待证假设；不能归为已经证实的丢弃数量或根因，更不能从不同内容点、缓存和供给的两包结果宣布3956ms被修复。旧英语首包key=false，不能把所有首包泛称关键帧。

四个最终epoch各记录12条packet/96条frame，均达到既定上限，是截尾样本，不覆盖全部解码流量。已记录sendResult全0、frame decodeErrors全0且hwFrames全true，只说明这些样本；不是整个解码过程零错误或性能PASS。原始frame PTS缺显式stream/filter timebase与duration/accepted记录，本批保留原单位，不按毫秒猜换算，也不由packet PTS直接计算frame的seek丢弃计数。

## 供给独立计时和取消保留

每次request→recovered期间只发现1个新mediaRange task1，以trace+transferID+upstreamTaskIndex独立关联，后续metrics唯一；旧传输取消及-999、曾有背压的数据保留在完整私有reserve报告，未混入新任务，也未归为故障。

| 包/请求 | 新任务issue→首正文回调 | TCP（完整task metrics） | request-end→首字节 | 首32MiB正文时长 |
| --- | --- | --- | --- | --- |
| 16:32 / 4→1 | 583ms | 243ms | 324ms | 3502ms |
| 16:32 / 1→4 | 92ms | 16ms | 61ms | 3174ms |
| 07:33历史 / 4→1 | 539ms | 310ms | 211ms | 3387ms |
| 07:33历史 / 1→4 | 557ms | 286ms | 260ms | 3583ms |

新任务均HTTP206、HTTP/1.1、cellular=no，完整task所报主动背压/暂停均0。四窗控制层恢复都早于首个32MiB task完成；新两窗早2482.661/1967.699ms，旧两窗早2376.520/355.083ms（同事件date域），因此不是客户端等首32MiB全部完成才恢复。首32MiB时长跨越恢复后，不用完整task平均速率代表seek期间每一瞬间，也不与decoder bytes相加；2秒正文窗保留可能跨Range边界标记。已有正文和帧在ready前出现，可以排除整段持续完全无供给/无解码输出，**不能排除局部供给、解复用或解码瓶颈，不能定位NAS/Wi-Fi根因**。

## 审核与继续条件

[安全结构化结果](../../../testing/results/2026-10/2026-10-23-iphone13-seek-correlation.json)保留四组同窗事件、间隔、任务metrics与截尾/身份/计时边界。独立审核核四个epoch及任务身份、六条capacity字段与既有独立安全导出逐值一致、旧窗多flush/目标前计数及敏感字段无导出；173输入/iOS diff均同最新普通包。本批无App或主机报告工具源码变化，未重复运行XCTest/112报告测试。文档检查403份/2205本地链接、0缺失，git diff --check通过；28需求状态/76矩阵格完整通过率保持。

**下一步所缺的是当前seek窗在filter/conversion前后、目标过滤接受/丢弃及实际队列PTS覆盖的有界证据。** 先设计最小新增观测和归属测试，再按新包/每台安装门槛进入13有限回归；仅重复现有packet/frame/容量字段不能解决该缺口。不得直接删video flush或降低缓冲阈值迎合这两个短窗。精确seek旧两种输入及PGS候选同条件失败仍停止。实际声音、完整PiP/PGS、起播后再缓冲、弱蜂窝与竞品滚动未因本报告完成。

本批没有设备操作，不重报当下Home/Wi-Fi或新安装证据。13最后有效安装仍16:34覆盖16:32包，最后实际Home Wi-Fi核验16:45；18当前16:32包未装，17:01只读发现失败原样保留，无新连接条件不重复探测，正常首页用户暂缓。Pad仍06:52历史包。此前播放/采集已停，本批未创建自有媒体/守卫/采集或周期任务。
