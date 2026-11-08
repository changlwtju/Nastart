# PiP 当前矩形输入、ASS 往返与 PGS 候选失败

记录：2026-10-21 19:09。关联 PX-03/PX-06/PX-07；状态只在[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)维护。[结构化结果](../../../testing/results/2026-10/2026-10-21-pip-fast-input-roundtrip.json)。

## 基线与执行边界

沿用15:39普通Debug/-Onone/Xcode27，无App/框架源码修改、构建、安装或测试环境注入。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`及其他dirty保留，iOS diff `6fd78d20f8d406a7794686d7e92c5316274b707ac12cac8a4a7dd52563d8d6e7`，IPA SHA-256 `e0c196cf2195de31426041d4acfe7175298c06f1c1e618d6fbd903747ae2c877`。173输入、三二进制、签名/profile及13原安装回执逐窗核对；19:05再次核验未变，不重跑未变L0。

iPhone13现场iPhone14,5/iOS16.3.1/USB，家庭Wi-Fi，S03/Jellyfin串行。仅修改仓库外观察程序；现有持久WDA复用，无新系统session或Runner安装。每窗正常空环境启动、首页恢复提示结束/目标矩形稳定后导航。独立190秒守卫、命令生命周期防休眠和最外层清理保持。私有指针`/tmp/nastart-pip-fast-input-evidence`保存设备身份、完整偏好、截图、系统树、日志和原始计时；最新包指针仍`/tmp/nastart-auth-response-evidence`。Pad未操作；18已最新安装，但用户选择稍后首页核验，本批不切18前台或重复询问。

## 输入方法及失败保留

沿用App WDA会话，将观察目标设为SpringBoard。以当前全量树找到实际PiP容器，在本窗矩形中心显控；再读实际语义按钮、唯一性/显示/启用/当前矩形/系统前台/容器内边界。观察返回后1秒内按新矩形发送一次W3C触摸，中间不插截图，不用缓存元素ID点击。超过期限或目标不唯一即不触摸；无效果/未知动作不重发。恢复全屏后先把自动化目标设回auto，再核实际App前台及画面。

18:45首窗因PGS菜单选择器同时匹配详情触发器和真实选项而停止，0 Play/0 PiP、无轨道/进度变化。下一独立窗仅缩小真实菜单选项匹配，不盲重发原动作。

历史18:20的stale失败保留。旧首份显控树到点击约2.72秒，但最后一次刷新树到点击约0.686秒；新窗0.705–0.752秒并不更短。此次同时改用当前矩形W3C且去掉中间截图，成功只支持组合方法，不能认定“缩短2.72秒”是唯一修复，也不能断言元素点击普遍失效。

## ASS 有限功能往返成立

18:47:33–18:50:20：1 Play/1 PiP，显式原PGS7后播放、切ASS5，系统小窗3/10/30秒观察后，原生暂停/继续/恢复全屏各1次。三次观察返回至输入分别0.752226/0.705030/0.746418秒。

同完整渲染owner/trace实际`pip_system_playback_changed`回调先requested/actual均false，7.800108秒后均true，两个回调位置均75.251秒。原生暂停早/晚图为相同电影内容及播放三角，继续后电影前进并出现“One.”；恢复实际App全屏、01:26位置及中英ASS已看，3/8秒后电影继续。初次恢复PNG是竖向画布承载旋转内容，后续实际横屏，不单据转场图认定旋转故障。最后显式恢复原PGS并正常完成、详情停留后收尾。

暂停两张PiP区域逐字节比较为false，不能称像素完全冻结或完整帧时间通过；暂停图无有效cue，不能补暂停字幕保持验收。内部controlsPlaying回调采样为true只按原始值保存，不直接归为产品故障。此窗支持13/S03/JF正常Debug的ASS PiP→暂停→继续→恢复全屏→普通退出功能切片；不是系统X关闭、全格式/设备、完整SUB/AUD、Release、杜比动态输出或长稳通过。

## PGS 系统关闭窗未完成，候选失败发生在 PiP 前

18:55:30–18:57:21：1 Play/1 PiP，显式PGS7，未切ASS。系统容器可读，显控1次后树未暴露暂停/继续/恢复/关闭，停止于`Pause control not exposed`；0 Pause/Resume/Restore/Close，没有系统播放回调。原生图仅片头，不能以没有字幕cue判PGS失败。

离线按原始trace/plan/route核对，主播放从始至终同一个KSPlayer directPlay/localRangeProxy，实际源字幕7、embedded、10-bit。内部`playbackClock`首帧信号8427ms，不当实际屏幕首帧。候选有另一trace/plan/route，为systemAVPlayer/localRemux/localHLS；主流事件报告仍带原KS owner，不能把事件头engine当候选引擎。

| 本地日志时间 | 已核实事件 |
| --- | --- |
| 18:56:06.334 | 自动降档attempt1，reason=deliveryBelowSourceBitrate；bodyWindow容量1620339、储备0.291958秒，非无线信号定量测量 |
| 18:56:09.615 | 候选预热开始，目标1.737秒；此时主流也为1.737秒 |
| 18:56:36.992 | 候选warmup_failed，stage=decodedFrame，elapsed27376ms，仍余12623ms；itemStatus2、NSURLErrorDomain/-1008，候选1.736667秒、rate0、范围0/储备0、cancelled=false；没有候选已解码/提交事件 |
| 18:56:36.993 | automatic_downshift_abandoned；主流9.694秒，未由候选接手 |
| 18:56:39.993 | 才进入PiP，主流9.694秒；候选失败已先发生 |
| 18:57:00.331及之后 | 同一原流又推进14.707秒，随后停在16.200秒至最后采样，储备仍低 |

9.694与16.200是同一主流的不同时段，不能混成候选时间、跳回或仅一个停顿。源码`GreenfieldAVPlayerWarmup.prepare`的`reportProgress("decodedFrame")`表示正在等实际output帧，循环会因item.failed退出；`stage=decodedFrame`不是解码成功。此窗由item失败提前结束，不能认作40秒deadline超时或PiP进入使候选失效。错误码本身未识别具体失败资源/AV响应，尚无证据将失败单归NAS、Wi-Fi、字幕或本地代理，不加缓冲/等待参数或重复同条件媒体。

进一步按候选trace绑定代理传输：masterPlaylist在7.229秒内完整200/873bytes；mediaPlaylist于18:56:16.944派发，约3.090秒收到200及首正文，到item失败时仅累计170692/1527158bytes，最后正文回调距派发19.489秒，没有该候选媒体分片请求或mediaPlaylist重写/完整发送事件。18:56:36.959对端写方向结束（clientReadComplete=true/errorKind=none），不能单独证明对端停止接收。36.992 item失败，36.994才routeRevoked、随后上游-999取消；取消是收尾，不能倒置为最初失败原因。约20秒只属这一窗，不宣称统一AV超时。

源码`DevicesView.swift`的playlist分支在上游完成后才调用`sendPlaylist()`重写并发送响应头/正文；终止日志的`deliveredBytes`对playlist实际取`playlistBody.count`，本窗170692是代理上游已收字节，不能声称已发给AV。共享/独立代理URLSession均request30秒/resource24小时，本窗没有代理30秒超时证据。已把问题缩小到候选媒体清单尚未完整可交付时的AV失败边界；具体AV失败请求仍缺errorLog条目绑定，不能直接改成前缀清单、流式重写或延长超时。

## 收尾与接续

本批三窗合计2 Play/2 PiP；所有失败、时间和原始图保留。各窗36书签全部原轨道、零增删，媒体窗仅本片自然进度变化，其他非诊断偏好相同。App/自有采集/守卫结束、原生无App/Home无PiP与Wi-Fi图标已核，WDA auto/idle10/cool2在19:05 GET复核，无新增App/WDA/Jetsam清单项；网络/SSID/蜂窝/VPN未改，持久WDA保留。

已明确下一批最小观测边界：在候选item失败时，同一MainActor/候选代次中立即快照AV errorLog/accessLog与当前状态，分别记错误域/码、事件日期、访问次数/字节和时钟；URI仅在本机映射到当前route/transfer及master/media/segment角色后输出安全关联，无法唯一绑定则unknown，不外发URL或原始errorComment。代理需分别记录upstreamBodyReceived、clientHeaderSent、clientBodySendCompleted，不能复用playlist的deliveredBytes名义；输出只作观测，不增加请求/重试、不改变deadline/清单交付/撤销顺序。旧候选晚回调不得记入新候选，缺errorLog事件和已撤route也须保留为明确缺证。该方案尚未接App，不当新增日志已交付。

后续实施前用现有7.229秒master成功/媒体清单未收齐/失败后route撤销序列制作离线夹具，核空日志、多个事件、不同代次、URI无法绑定与凭据不导出的反例；通过相关编译与L0后才新建包并执行一次有区分力的串行回归。既有失败不需要为设计而重播。系统X关闭、PGS/其他路线往返及18原图场景保留待验。28项保持开放。
