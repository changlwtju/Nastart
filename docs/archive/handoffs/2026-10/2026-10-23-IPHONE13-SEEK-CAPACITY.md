# iPhone13切轨恢复的有界队列观测

2026-10-23本批承接[音轨恢复等待](2026-10-23-IPHONE13-AUDIO-SWITCH.md)。只补Debug观测，不改缓冲/seek/选轨行为；旧包视频日志已见新包/解码回调早于bufferFinished，仍缺音/视频各自的队列状态。原始身份、包、偏好及日志只在本机私有指针`/tmp/nastart-iphone13-seek-capacity-evidence`，当前包在其`owner-fix`子目录。

## 实现与验证范围

GreenfieldKSOptions.playable原样返回super结果。Debug限定PlaybackSeekCapacityObservation在既有seekPlayback前开始请求观测窗，仅KS isSeek后采样，最多每0.5秒一条、20条等待加1条终态，10秒截止；旧playable队列不提前结束新窗。记录每种媒体packet/frame/FPS及计数推算时长、全局LoadingState、preferredForwardBufferDuration和uptime，回主线程核固定plan UUID/当前seek generation/ready。各队列字段顺序读取，**不是同锁原子快照**；计数/FPS是队列时长，不是PTS覆盖、网络字节、实际声响或显示。请求观测窗不冒充底层decoder generation。

第一版在makeOptions错误捕获尚未configure的controls.planID；16:20普通包、3定向XCTest/15预检通过，16:23安装13、25完整偏好保持。16:25–16:27 S03文件4→1→4实际电影画面及普通回同详情、原轨道/Home Wi-Fi已核，播放/日志/守卫结束；容器与实时日志均0条队列记录。原因是新增诊断owner绑定错误，不能归为播放器或持久化故障；本窗不能用于队列归因。失败包与完整证据保留。

修正为seekCapacityObserver(for: plan.id)，以不可变计划UUID绑定将来的owner，再核实时归属。第四项XCTest覆盖“配置前创建→正确owner配置后接受；未配置/不同generation/未ready/退休plan均拒绝”，另3项覆盖节流/总量/终态、旧队列不提前结束、无seek到期/非法时间。4定向XCTest与15预检通过；112主机报告测试通过，白名单保留数值/布尔与缺失，不导出URL/凭据。旧12路线测试不当本批重跑。

## 当前包与安装

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty；当前iOS diff SHA `5360a5df7c24ea5ae3d4e74e75d45492e2ce8401dd98526b2a9efb900b605615`。16:32:03普通Debug/-Onone/Xcode27，173输入、29独立及deep签名、有效profile/三二进制/IPA CRC及链接核过；IPA SHA `506da76d122f6e79eff46afabf373655b5c5865682d2eaab33c1e4ac0952abab`。16:34:28已保留数据覆盖13，25完整非诊断偏好逐值相同；新诊断实际窗口正在核验。07:33与16:20均为历史包，不继承整项验收。

Pad/18零命令，仍06:52包；18最新包更新缺实时连接身份，正常首页继续用户明确暂缓，不重复探测/催促。无蜂窝、网络/NAS/VPN或音量更改。新源码/真机有限观测不改变28需求状态或76格完整通过率，实际听音/逐帧/完整PiP/Release仍未验。

## 第二窗实际产出与有限结论

16:37–16:39，空环境/参数正常启动后S03设备文件1 Play、音轨4→1→4各选一次，0手动seek/0 PiP。实际切后/恢复后3/10/30图均已看，电影场景不同，第一切后时钟1:08:09、恢复后1:08:43，末图16:39:01实际1:09:14。普通完成返回同完整路径详情，最终Home Wi-Fi/无PiP已看。六条新日志按请求seekGeneration 2/3分组，每组2 waiting/1 playable，没有过期/重复或旧owner数据回灌证据。固定计划UUID经既有8位planID核对，并非完整decoder身份校验。

| 请求窗 | 请求后采样 | audio队列时长 | video队列时长 | KS可播放 |
| --- | --- | --- | --- | --- |
| 4→1 | 644.5ms | 0 | 0 | false |
| 4→1 | 1169.2ms | 0.911667s | 0.291958s，7帧/0包 | false |
| 4→1 | 1420.0ms | 1.620000s | 1.042708s，16帧/9包 | true |
| 1→4 | 100.8ms | 0 | 0 | false |
| 1→4 | 601.5ms | 0.520833s | 0.125125s，3帧/0包 | false |
| 1→4 | 1100.9ms | 1.083333s | 1.042708s，16帧/9包 | true |

恢复阶段preferred为1秒，既有KS seek音频门槛为其一半（另有至少2帧等条件）、视频为1秒。两次中间waiting采样音频已满足该储备、视频仍不足；video达到约1.043秒时就绪。**只定位本窗的就绪门槛由视频储备限制**，不能由videoPackets=0单次采样排除网络、解复用、关键帧追赶或解码/调度，也不能推断音频实际可听。新内部时钟恢复1638/1307ms、telemetry起播/两次切轨stall1401/1020/1011ms，口径不同不混合；不同内容点/缓存/供给窗，不与旧3956ms作修复提速结论。没有改缓冲阈值。

两包两窗合计2 Play/0手动seek/0 PiP/4选轨；两次覆盖均保留25完整偏好，两个窗口原36轨道及其他偏好不变，自有syslog/独立守卫均结束。新Nastart/WDA/Jetsam报告名增量各0，只是清单口径。第一版诊断零产出与修正过程完整保留，不将第一次计作队列P。

16:45最终只读再次核实时13身份/173输入/签名/profile/三二进制/本机回执；WDA1/1、auto10/2与新原生Home Wi-Fi/无PiP实际已看、自有播放/构建/logger主机0，不报iOS原生PID0。即时结束进度4149.460/updated814437537.366694，后读4156.798/814437544.692188，仅该同key自然进度变化；后一时间逐值对应viewDisappear，submitted/memory match/ready/无pending、audio4/Off。保留首次严格比较失败，未回写；再次独立读取全部非诊断值稳定，36原轨道与本批开始一致。

[安全结构化结果](../../../testing/results/2026-10/2026-10-23-iphone13-seek-capacity.json)记录三二进制SHA、六条原字段与两版失败/安装/最终核对。下一步先用已保存video packet秒级PTS、原始frame PTS和供给日志区分视频队列为何不足；frame原始PTS缺显式timebase，不按猜测毫秒转化。已有诊断已工作，不再为相同字段重建/重播。实际听音、完整PiP及此前PGS候选新条件仍缺。


## 同阶段收尾：18当前无线发现

2026-10-23 17:01：13媒体/采集全部收尾后，只读核一次当前无线广播。6秒浏览见3个当前Add服务，但无与已配对18实例匹配的目标；对既有目标标识执行当前DNS-SD解析也未得到endpoint，未进入TCP实时UDID/型号/系统核验。没有沿用历史IP或扫描网段，未改配对/网络，0安装命令/0App启动，发现进程已结束。此前媒体阶段的Pad/18零命令仍归各自窗口，本收尾仅18新只读发现；Pad仍0。不能把“已知服务未解析”扩大为所有链路不可用，也不能报最新包已安装。18仍06:52历史安装，16:32最新包待实时身份/容器可读后保留数据覆盖；正常首页继续用户明确暂缓，无重复催促。
