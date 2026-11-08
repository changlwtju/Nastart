# 真实NAS HLS与代表格式回归

2026-10-24 06:59开工，接[主清单复用](2026-10-24-VOD-MASTER-REUSE.md)。关联PX-03，28开放与76格完整通过率保持；编号仅[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。

## 基线与范围

本批不改App/KSPlayer/仓库主机工具，不新构建；沿06:20:01普通Debug/-Onone/Xcode27，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty、174输入，iOS diff SHA `a6dffa97d9301537a7a104d2700d72854e33040e94d2daed9ee4c1f267b0c024`，IPA SHA `76ebb89a8b390d650f9b5eb7cf9556f8c945b56ebccf22037cad1426b50bc4b7`。每个13窗口现场核名称/UDID/iPhone14,5/iOS16.3.1/USB、当前输入/签名/profile及自身安装回执，不能用版本号或其他设备结论替代。07:02空环境NAS在线首页实图已看，25完整非诊断偏好保持。

真实HLS窗口显式使用既有Debug proxy/prewarm/AV入口，由私有协议助手新协商同一NAS资源；不是普通入口、自然自动降档、候选对齐提交或Release验收。采用旧已核固定2Mbps H264/AAC/854×480/4秒片/MinSegments1与PGS Encode条件，不改NAS设置。匿名ServerId先核同服，再实时Item/MediaSource/字节/轨道核身份；独立诊断DeviceId和本次PlaybackInfo返回PlaySessionId精确绑定。Mac仅小型元数据/协商，无媒体GET；媒体由iPhone实际代理取流。最外层finally先停App、自有会话DELETE、日志/守卫；独立超时守卫亦只停自有App/协商会话。原始凭据/URL/偏好/截图仅仓库外，私有指针`/tmp/nastart-real-hls-regression-evidence`，package-private-root指06:20冻结根。

## S03真实HLS有限证据

07:04:43–07:05:37，1显式lab启动/0普通影片Play/0候选按钮/seek/PiP，无客户端限速；实际S03为54,005,939,750 bytes/7524.768秒，源音轨1、字幕7 PGSSUB，协商Encode/H264/AAC≤2Mbps，从头0秒。身份/源轨道与协商绑定均新核，PlaybackInfo200/约63ms。

- 客户端完整窗口326持久事件，实际master/media各1次上游任务；各1次vodPlaylistCacheHit（781/1,350,438 bytes），媒体走AVPlayer。主清单总47ms、子清单219ms，后者正文178ms；HTTP/1.1、cellular=no，子清单连接复用。44次实际分片上游请求，不把清单复用当少一次编码。
- 内部first_frame为12191ms/position0.517，是引擎信号；helper开始到该事件16.112秒，不是物理点击或屏幕首帧。原生3/10/30秒不同电影/片头及末00:34实图已看。29遥测末stall1/accessLogStalls0，稀疏图不能报全程流畅或声音。
- 首片0.ts同trace/child两个读取：第一发出后约4.005秒观察读方向结束、约4.032秒后第二发出；第一等头10363ms，第二等头6338ms，响应头几乎同时。第一只交付5570 bytes后clientBodySend失败/主动取消，第二744480 bytes完成、正文约143ms。EOF不是完整连接断开证明，重叠等待不能相加，不能从这两读推断两次转码/纯CPU/NAS唯一根因。
- 30秒图PGS中英文可见，但英文与Home指示条重叠；只保留该Debug根页面现场，不判完整SUB。源码已核普通GreenfieldPlaybackHostingController覆写prefersHomeIndicatorAutoHidden，而NastartApp的显式lab用根NavigationStack直接放GreenfieldVideoPlayerView；因此不能把此图外推为普通全屏回归，亦不因截图盲改普通布局。
- 结束后App两次WDA状态1/1，自有日志/守卫停，25完整非诊断偏好不变、新Nastart/WDA/Jetsam报告名0；按本次独立DeviceId+PlaySessionId DELETE204/remainingOwnedSessions0。HTTP204只证明停止请求成功，未单凭Sessions推断FFmpeg进程退出。AC及实际自有caffeinate PID开始/中段/结束已核。

此窗在真实NAS资源和PGS编码条件下证明缓存接线生效；与旧12Mbps/深位置/原流并行准备条件不同，不做时延改善对照，旧40.005秒候选失败和7300ms不关闭。

## 普通格式回归

所有普通窗口恢复空环境/空参数，不注入lab或限速，逐窗新核设备及包。S08首轮用样本表“黑豹：瓦坎达万岁”查不到结果，0 Play、退出及日志/守卫已停，失败保留。实时同服目录核当前唯一名“黑豹2”/2022，源5,530,303,399 bytes、MP4/HEVC3840×2160/双AAC；按实际目录修正私有定位再跑，不改App。S11实时17297326567 bytes/MKV/HEVC3840×2160/TrueHD+AC3，S18实时14825705867 bytes/MKV/H2641920×1036/FLAC+AC3。

| 样本/普通JF窗口 | 实际图复核 | 当前持久诊断 |
|---|---|---|
| S03 07:08:37–07:10:15 | 3秒电影+转圈，10秒打斗/PGS仍转圈，30/60秒不同电影和双语对白；普通回原详情 | KSPlayer，内部first_frame 2076ms；60遥测，末4429.340秒/stall2，续播起点约4374秒 |
| S08修正定位 07:13:26–07:15:04 | 3秒黑场转圈，10秒暗片头，30/60秒不同电影；普通回“黑豹2”详情 | KSPlayer，内部first_frame 3593ms；60遥测，末60.553秒/stall0 |
| S11 07:15:04–07:16:43 | 3秒黑场00:00；10秒WB、30秒片名、60秒报纸及PGS中文特效，末图01:00；普通回原详情 | KSPlayer，内部first_frame 1092ms；62遥测，最后有位置者62.878秒/stall0 |
| S18 07:16:44–07:18:21 | 3秒黑场转圈，10秒片头，30/60秒黑场；显控末图00:58红字演职员，普通回原详情 | KSPlayer，内部first_frame 2259ms；62遥测，最后有位置者61.513秒/stall0；黑场原因须独立核实 |

四窗各1 Play/60秒，不同起点不作配对提速；普通返回效果与原详情均已看。S11标称3秒原生截图读取失败，保留失败后用WDA截图，不冒充原生成功；10/30/60及返回均原生。四窗原36书签键、轨道及其他24偏好保持，仅各1自然进度变化，新Nastart/WDA/Jetsam报告名0，自有App/日志/守卫停。自动候选尝试/提交均0，不能据此关闭自动候选问题；源HDR/TrueHD/FLAC标签不等于实际输出/听音验收，稀疏图及内部stall0不判全程呈现或整格P。

S18另于07:20:44–07:22:06做45秒成对采集，同一正常包/空环境/普通JF，仅改私有采样点为15/25/35/45秒，直到末图前不碰控制；各点先原生后WDA（非同一瞬间），八张图均有不同片头/红字演职员，控制隐藏仍出画，普通回原详情已看。此证据排除“隐藏控制栏必然持续黑屏”的笼统结论，不抹去先前两张黑场、不凭两读排除间歇问题；同源有限前缀离线转场核对独立记录，不盲改App。

全部手机媒体停止后，另核同服/同Item/同MediaSource/14825705867 bytes，以原始Static MKV有限206读取前缀，不协商转码。首次48MiB只覆盖19.89秒，FFmpeg退出0仍不能证明请求70秒已覆盖；保留提前EOF和没有产出目标PNG的失败，再以第二次明确有限Range续至总192MiB。两个206响应/长度/实际正文均核，离线仅解码至70.02秒，无网络解码或无限整文件200。源blackdetect在25.150–25.859及55.430–55.889秒有0.709/0.459秒短黑场；原30/60秒图最近两条遥测分别25.182/26.291及55.176/56.285秒。源25.5/55.5秒实际参考图黑场、26.3/56.3秒红字演职员均已看，后者与手机末图相符。结合成对截图，先前两张黑图与片源转场一致，不建立“持续App黑屏”故障；采样并非显示帧精确对齐，不扩为全部间歇问题已排除或完整呈现PASS。

初私有元数据助手字符串未引用/生成器漏import的HTTP前失败均保留，修正后只读元数据成功，不计App/播放器失败或XCTest。

## S19真实HLS有限证据

07:18:41–07:19:26，在四窗普通媒体停止后串行执行。实际128,795,641,934 bytes/13698.368秒，音轨1/PGS8 Encode、同一2Mbps H264/AAC显式Debug协议入口；0普通Play/候选/seek/PiP/客户端限速/同窗Mac媒体GET。fresh PlaybackInfo200/160ms；此协商在App外，不当普通页面协商耗时。

master/media各1次上游、各1次缓存命中（781/2,460,059 bytes），33分片上游请求；master总48ms/media411ms（正文221ms），HTTP/1.1/cellular=no。内部first_frame4922ms/position0.500、helper+7.915秒，非屏幕首帧；原生3/10秒不同New Line片头、30秒双语/精灵文PGS与末00:34实图已看，底部英文受lab Home指示条影响沿上述Debug范围保留。29遥测末28.002秒/stall1/accessLogStalls0，不能外推声音、全帧、深位置/自然候选/Release或与S03作性能A/B。

App状态1/1、完整非诊断偏好全同、无新增上述报告，自有日志/守卫停止；按本次独立DeviceId+PlaySessionId DELETE204/remainingOwnedSessions0，不能单凭HTTP证明编码进程退出。旧40.005秒候选失败/7300ms保持开放。

## iPhone18与收尾边界

本轮重新解析旧已配对实例失败；系统当前广播存在其他实例，但规范化同一目标匹配0。未沿旧IP扫描、改配对/网络/VPN，未进入备份/上传/安装/启动，不能声称当前实时设备值或归因锁屏。仅确认历史00:00包已安装，06:20仍未装。前批一次解锁保持家庭Wi-Fi请求待反馈，不重复催促。Pad本批未操作，仍06:20包与前批有限结果，不继承本批13证据。

07:23:18–26恢复最新普通包空环境/空参数NAS在线首页，原生实图已看；只终止本批该前台PID。07:24:41最终重新核174输入/冻结包/当前安装回执与实际USB身份，完整非诊断偏好两读稳定，36原书签键及轨道/其他24偏好保持，只自然positionSeconds/updatedAt变化；WDA App状态1/1、auto/10/2已恢复，原生Home Wi-Fi无PiP实图已看。保留非本批拥有的已有WDA服务；两次NAS会话停止204与自有App/日志/守卫/保活清理分别记录。

[可分享结构化结果](../../../testing/results/2026-10/2026-10-24-real-hls-and-format-regression.json)。本批共5普通Play（四代表窗加S18配对窗）和2显式真实HLS lab，0候选按钮/seek/PiP/手动选轨/蜂窝；原始诊断与192MiB前缀仅本机私有。无源码/构建/安装/新增测试，45 XCTest/15预检沿前批，不冒充本批重跑。真实HLS仍需普通入口/自然候选、原流并行/深位置同条件验证与全格式/双设备覆盖；不新增需求编号、不改完整通过率、不新建调度，不声称回合后后台执行。

07:30:36主机最终核本批证据根活动助手0、自有operation caffeinate存活0；各case finally资源停止与两次精确会话DELETE结果已分项留存。文档检查415份/2287本地链接/缺失0，`git diff --check`通过。完整矩阵及28需求状态保持。
