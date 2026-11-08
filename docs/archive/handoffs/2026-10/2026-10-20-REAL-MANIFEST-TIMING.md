# 真实蜂窝清单时长与HTTP/2等待

日期：2026-10-20。承接[代理六窗](2026-10-20-PROXY-LAB-CONSUMER.md)，不重复其fixture。原始设备/偏好/凭据/包与日志留本机私有区，指针`/tmp/nastart-manifest-timing-evidence`。

## 执行前变更卡

- PX-01观测缺口：旧真实窗只有清单总时长/1880片及编码hls_time4，缺实际TARGET和首EXTINF，不能推断读者预算。
- 基线：HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加原修改，13:50普通Debug、iOS差异`73cfcd889b2222bc5a1f32ee22a049d1501184d48134fe0a7011404ef941b8d2`。仅13为目标；Pad旧包、18离家不操作。
- 最小修改：现有`PlaybackHLSRequestDiagnostics.playlistFields`增加两个有限正数结构字段，报告工具白名单接续；不输出URI/标题/查询、不改清单内容或代理/播放参数。缺失/无效/重复TARGET和无效首EXTINF保持unknown，不能借用后续合法片。
- L0：正常/缺失/无效/重复/主清单反例、隐私白名单，相关清单预热/取消测试及preflight。冻结后必要普通签名构建一次，13保存诊断/偏好并保留数据覆盖、空环境首页。
- L1：普通空环境S03真实蜂窝有界窗，逐窗绑定同trace/transfer/task、实际输出候选与唯一编码任务；两入口预算/字幕若不同只分列，不作提速对照。现场4G/5G/格数和用户报告弱蜂窝分别记，无RSRP/RSRQ/SINR则未知。
- 成功条件是补齐同窗真实字段和HTTP/2等头/正文边界，不是优化验收。每轮最外层先停自有媒体/采集、恢复原SSID并独立核Wi-Fi图标，再分析；所有失败、超时与落盘不完整保留，后读补齐不重播。
- 普通传输行为不变，未触发L3；不对首帧/字幕/听音/帧时间标新P，不扩展NAS/VPN/系统操作。

## 实现与安装

`DevicesView.swift`的`PlaybackHLSRequestDiagnostics.playlistFields`只增加`playlistTargetDurationSeconds`、`playlistFirstSegmentDurationSeconds`；TARGET须唯一正整数，首EXTINF须有限正数，首项无效不借后项。主清单/缺失/无效为unknown。`playback_phase_report.py`仅允许有限数值；URI、标题、查询和任意原文不进入新字段。没有修改清单、普通入口、等待、分片、重试或缓冲策略，普通primer仍停用。

7项定向Swift测试、32项报告测试、15项预检通过。首次模拟器编译的`String.init`泛型歧义已用显式闭包修正，失败日志/xcresult保留；接受测试后只做一次必要真机构建。14:20:56.401604普通Debug/-Onone/Xcode27，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加原修改，iOS差异`88efcc6f4c76662d29b16603b7665a0974cf1a952aa4796dbd181bfe306177f7`。173输入、29库逐个/整体签名、链接、清洁IPA CRC/三二进制一致性已核；profile UTC10月24日22:23:57到期。

| 产物 | SHA-256 |
| --- | --- |
| Nastart | `63a33bb119d148657f43a753af7c95ff5fa789e44e1057685767a962ed38f5a9` |
| Nastart.debug.dylib | `7d65d2b12b2577c310316c0bcdcb92953e7fb8008fcdce72db9259a3e09fd78c` |
| KSPlayer | `19bd2fa4ad43d4eca0efde6a02a973ee3eb12941c2873a5c76145352689446ad` |
| 清洁IPA | `66e8468e9012d6407c8345a083be7ef2a47a652a4d6144b9e1d4a7f670481fd6` |

13现场重核iPhone14,5/iOS16.3.1/名称/UDID/USB，保存故障/偏好后保留数据覆盖，25项非诊断偏好安装时一致，空环境实际首页已看。每窗前再次通过源码/包/安装身份闸门。Pad仍09:47旧包，18随用户离家，本批未操作或新包回归。

## 普通入口真实蜂窝两窗

14:23 JF、14:27文件，均空环境/空参数，从头，目标20秒。独立原生30秒守卫未触发，两窗均正常UI退出；最外层先终止自有App再恢复Wi-Fi。无并发媒体探针或人为限速，日志只读且每次≤1MiB，无新NAS媒体请求。导航前独立原生图均见4G/2格（4格制）；播放图仅见“蜂窝”HUD，不冒充同窗无线定量读数。分组“用户报告弱蜂窝”，RSRP/RSRQ/SINR未知。

| 观测 | JF | 文件 |
| --- | --- | --- |
| 预算/实际视频码率 | 10,000,000 / 9,360,000 | 12,000,000 / 11,360,000 |
| 音轨/字幕 | audio1、PGS7/Encode | audio1、Off |
| 真实媒体TARGET/首EXTINF | 5 / 4.004秒 | 5 / 4.004秒 |
| 完整VOD | 1880片、序列0、7524.768秒 | 相同 |
| 首片GET | 1 | 1 |
| 首片h2 request-end→首字节 | 2836ms | 2506ms |
| 首片正文 | 441ms / 1,941,476bytes | 522ms / 2,192,832bytes |
| 首片代理完整耗时 | 3288ms | 3034ms |
| 正文区间吞吐（非整窗速度） | 35.220Mbps | 33.607Mbps |
| 内部tap→0.5秒clock | 5140ms | 4855ms |
| 原生动作开始→内部clock日志 | 7.457秒 | 6.351秒 |
| 分片上游请求/完成 | 17 / 17 | 15 / 14，另1次退出后-999取消 |
| 分片metrics去重解码正文 | 73,213,968bytes | 73,077,280bytes |
| 完成响应delivered正文 | 73,213,968bytes | 68,461,328bytes |

全部已记录分片metrics为cellular=yes/h2；身份在私有区按同trace/transfer/task绑定，分享结果只用窗内序号。实际输出候选各唯一匹配一条编码命令：h264_vaapi/libfdk_aac，起点0，hls_time4；真实TARGET5与首EXTINF4.004直接来自当前窗完整媒体清单，不从编码配置推导。主清单两个新字段unknown是预期。预算/字幕不同，不能比较两入口提速，也不能将新时长回填旧窗。32个分片请求各ordinal仅一次，本窗没有重现旧首片重发，不关闭历史失败。

metrics字节仅覆盖已记录任务，包含文件取消任务的已收正文；不等于全设备IP、在途尾部或运营商计费。两窗未取pcap，不宣称严格字节上限。t10/t20均实际看到变化的影片画面；内部clock、稀疏截图、startup stallCount=1均不当完整首帧/流畅/听音/字幕验收。守卫未触发不等于已证明独立失效注入停止。

## 接续离线：供给与ready边界

同trace联合进入前、各采样点及退出后偏好，以事件ID去重，取回准备阶段/尾段，未重播。以原生播放动作requestStart为0，以下为日志墙钟相对时间；内部elapsed与实际屏幕呈现另列，不能相加推断单因果。

| 阶段（秒） | JF | 文件 |
| --- | --- | --- |
| 首片派发 | 2.757 | 1.808 |
| layer ready | 5.652 | 4.394 |
| 首片complete | 6.075 | 4.853 |
| 第二片派发→complete | 6.076→7.740 | 4.853→6.735 |
| item ready | 6.875 | 5.708 |
| playing | 6.898 | 5.725 |
| 内部0.5秒clock | 7.457 | 6.351 |

首片完成→ready约799.5/854.7ms，ready→playing约22.6/17.4ms；ready时第二片尚在传输，不能把尾段全算纯AV空等，也不支持再次延后/关闭自动等待。本窗首读方向结束约3279/3030ms，在响应body临近完成，之后完整成功；read EOF本身不能证明完整TCP关闭。本窗首片供给均短于4.004秒，只能与已完成本地时长反例并列，不证明通用读者截止公式或旧15秒等待根因。

下一步优先离线核对普通入口准备→intent→首片派发的实际共用调用链及可证明冗余；只有新反例才做最小共用修改。不要为观察长等头再次反复蜂窝重播，不重跑已完成直连/代理/片长fixture，不重开primer、删零seek或盲调缓冲。

## 再接续离线：准备调用链审计

没有新增构建、安装、播放、蜂窝或服务端媒体请求。联合各已存快照补查单一操作窗内的route-state事件；此类事件没有playbackTraceID，明确作为同窗上下文，不伪装成精确transfer/task绑定。

- JF从动作0.713秒请求context（路径代次4），1.526秒观察代次5；1.874秒媒体准备结束即触发同服同账号复核，2.321秒attempt1成功，2.322秒完成（自报439ms）。`mediaRenegotiated=false`，同输出只一条编码命令；不是第二次媒体协商/清单重做。旧媒体准备保留，没有理由删除认证复核。不能把该439ms算作async-let取消空等，参考子任务是否早已完成未单独计时。
- 对应源码：`LaunchpadView.swift`的`playbackRequest`→并行`preparedLibraryReference`/`makePlaybackRequest`→`negotiatedVideoPlayback`完整VOD预热→变更后`revalidatePreparedLibrary`→发布请求；实际窗只触发一次认证attempt，没有第二次重试。此前“首片派发前所有额外时间都在供给”的归因不成立，也不支持全部算冗余。
- 文件路径：`DevicesView.swift`的匹配HLS `stream`→同源URL/轨道核对→完整VOD预热（952ms）→`PreparedStream`/tracker→请求；JF预热1021ms。两入口大媒体清单均一次上游读取、一次后续本地命中；小master各两次上游读取。不能把本地重写两次当大清单下载两次。
- `PlaybackPreparation.holdPreparedResultForDebugIfRequested`空环境默认0立即返回，两窗没有hold事件；方向重试由`PlayerOrientationController.updateScenes`另起Task，调用方不await，不能把0/150/350/700ms直接累加进首帧关键路径。
- 共用`GreenfieldVideoPlayerModel.start`激活音频后由`prepareSession`/`PlaybackSessionCoordinator.prepare`解析、打开，再安装AV item。此窗intent→ioOpened约1ms，ioOpened→首片派发约253～273ms；前者不是HLS全部打开耗时，后者还含item/清单与消费者调度，没有更细同窗边界不擅分摊。音频准备日志的通用控制器标签不能覆盖实际AV telemetry/route。

本轮观测已排除“必有第二次大清单”和“固定Debug延时”这两个解释，未形成可证明删除的串行段。下一项优先利用既有长等头失败与当前成功窗，核首个响应正文回调/读者结束/取消的可比条件及证据缺口；只在新反例支持时变更共用逻辑，不为凑配对重复蜂窝长窗。28项状态不变。

## 旧长等头失败的可比条件复核

继续只读已保存的三批归档/JSON，没有新媒体请求或设备操作：

| 已有JF窗口 | 首片GET/第一等头 | 与当前窗不可直接比较的条件 |
| --- | --- | --- |
| 10月19日13:42包 | 3 / 15392ms | 2Mbps/PGS7；首TARGET/EXTINF及唯一编码输出归属缺失；旧信号不能追溯重标当前弱蜂窝 |
| 10月20日01:06诊断 | 2 / 5249ms | Params当时未解码，输出候选unknown；实际首清单时长未采集，不能猜同输出 |
| 09:06 primer候选 | 2 / 4468ms | primer启用且实际输出/预算不同；有唯一任务但真实首清单时长未知 |
| 本批14:23普通 | 1 / 2836ms | 10Mbps/PGS7、primer停用；TARGET5/EXTINF4.004直接观测；仍单窗、缓存未知 |

因此现在能解释请求/EOF/失败的先后，仍不能把“第二GET”当15秒等头的原因，或把单GET窗口当修复成功。跨窗输出/预算/缓存/信号及服务器首片可读时刻仍缺严格可比证据；只读主日志唯一任务匹配没有提供生成首字节的同步时钟。没有据此发新构建、调等待/片长、关闭字幕或重新开启primer。下一轮只在出现新的可定位反例时追加相应最小诊断，既有本地fixture和无变化蜂窝窗停止重复；独立PiP/HDR、完整音画/深seek需求仍按总账接续。

## 收尾与保留失败

两窗原生恢复首张截图仍显示4G，即使原SSID已勾选也未算完成；App已停止后再独立USB复核，JF约14:24、文件14:31实际看到原SSID勾选和状态栏Wi-Fi图标，失败图保留。文件后续源树用value=1推断选中返回0匹配，此断言形式不能替代实际图；以保存的原网络、先前原生选择核对和实际勾选/Wi-Fi图共同确认，没有改蜂窝或VPN。

最新普通包空环境首页14:33实际可见，NAS卡显示未连接，不能当整个NAS环境健康。24项非断点偏好完全保持，36个原书签无删除/轨道变化、无新书签；两条自然进度变化保留，未回写伪造。App/WDA/Jetsam新增均0；WDA idle10/cool-off2/auto恢复，既有13持久Runner保留。两窗自有保活/守卫/媒体进程均已结束，同窗电源日志无Sleep/Wake。

服务端各绑定输出出现q停止命令，紧随同日志线程FFmpeg code0退出及删除残片。最终只读本机DeviceId会话NowPlaying已空，但TranscodingInfo仍有旧值；旧值不当活跃编码证明，服务器绝对时钟对齐/进程PID级退出另未验证。未向其他设备发停止，也未改服务器配置。

[结构化结果](../../../testing/results/2026-10/REAL-MANIFEST-TIMING-20261020.json)保留全阶段及所有请求/取消。28项仍开放，本批完成观测缺口及独立供给分析，不宣称蜂窝性能修复或Release交付。
