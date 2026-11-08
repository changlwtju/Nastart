# iPhone13真实候选控制与iPhone18最新包安装

日期：2026-10-23。接[上一批完整VOD准备](2026-10-23-CANDIDATE-VOD-PREPARATION.md)；[结构化安全结果](../../../testing/results/2026-10/2026-10-23-candidate-device-lab-and-iphone18.json)。问题关联PX-03/PX-01，28需求/76格完整验收状态不变。原始身份、包、偏好、地址和图片只在本机私有证据区；最新指针 `/tmp/nastart-candidate-device-lab-evidence`。本批没有卸载、清登录、网络/NAS/VPN/音量修改或周期调度，全部dirty保留。

## 已完成及仍开放

1. 新增显式Debug候选验证入口，调用现有生产 `replaceSource`→完整清单准备→AV解码/对齐/提交，解决旧initial playback-lab没有调用真实候选函数的观测缺口；没有改变自动触发、缓冲、Range、信任或正式启动行为。
2. iPhone13本地快/慢清单各1次实际候选提交；慢正文25秒完整收齐，清单准备25550ms、解码26197ms、对齐36473ms，仍在原40秒总预算内。原流在清单准备期间内部时钟3.010→27.002秒推进。
3. 准备中取消1次，manifestPreparation阶段10710ms失败且cancelled=true，无prepared/decode/commit；本次上游客户端停止、仅688128/1621922字节写出，没有把部分文本当完整缓存。
4. **用户新确认18家庭Wi-Fi后，22:12:52最新21:48普通Debug包保留数据安装成功，正常空环境首页/NAS在线已原生实图核，25完整非诊断偏好安装前后/启动后相同。** 此前不可用和未安装仅历史，不再作为当前阻塞。

真实NAS大文件KS/TrueHD/PGS→AV、自然自动降档、无感音画、完整字幕/PiP/帧时间、iPad受影响单端/双端及Release仍待验；上批真实S03/JF7300ms再缓冲没有修复。不以本地控制或安装完成关闭任何完整矩阵单元。

## 上批7.3秒再缓冲的离线核对

0新影片/设备播放。上批S03/JF派发后4.655→11.957秒内部再缓冲，出帧后2.561秒已切4秒储备目标。正文窗口约67.227/31.175/20.086/55.118/67.121Mbps；中间31/20窗口低于同窗运行需求55.529–75.234Mbps，原始运行估计在停滞时也可能保持旧值。主Range正文约40.391/63.792/57.260Mbps，续接仅11.700/13.107/0.665ms，主要task主动背压/暂停0。不能把多秒再缓冲归为Range固定多秒间隔或NAS/Wi-Fi单因，也不能据此直接降低4秒恢复门槛。首predictiveEligible在恢复后，attempt0并非新候选修复失败；缺自然候选触发证据。

## 本批实现与测试

仅Debug的 `PlaybackLabLaunchRequest.candidateConfiguration` 要求显式开关1、greenfield、原/候选HTTP(S)同scheme/host/port且无userinfo、候选m3u8、有限正时长。`makeCandidateRequest` 只注册冷代理根/资源释放tracker，不提前下载清单或媒体、不提供自动fallback loader。

`GreenfieldVideoPlayerView` 仅合格实验环境出现“验证候选”按钮，原播放器ready/无pending seek且不在换流时可点；本view单次按钮触发后消失，沿现有keepPlayingDuringPreparation的replaceSource，不伪造自动策略通过。普通空环境没有该按钮，Release不编译。内部debug_candidate_lab_requested仅标实验入口，不能当automatic_downshift_requested。

新增2方法验证缺失/无效配置、不同端口/主机/凭据/文件URL、已知时长、无自动loader、冷注册0请求与重复release撤销。连同既有18个候选完整清单/缓存/取消/截止/primer方法，**20不同方法正常结束、0失败、TEST SUCCEEDED**；15预检通过。主机报告源码本批未改，141测试是前批记录，未冒充本批重跑。

## 最新包与逐台身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加保留dirty；174完整输入，iOS diff SHA `fb558d4295322180db2f9de34679da0427b5c8d7f2d615b570c24b4f33a77ea7`。普通Debug/-Onone/Xcode27构建21:48:46+08，IPA SHA `3aa6244882e38faac2404cf1b0cf6f7912cddc0a302f4ee4ceb4b6a08a883052`；三二进制、29独立/深签名、profile、IPA CRC/二进制对应、linkage已核。完整哈希见安全结果，包不入库。20:53及更早均历史。

- 13现场名称/型号iPhone14,5/系统16.3.1/UDID/USB/未锁与Home Wi-Fi新核，22:08:06保留数据覆盖，25完整偏好相同；22:08正常空环境NAS在线首页实图已看。每个实验和22:19收尾再次核当前源包/安装回执，非以0.1.0/1判断身份。
- 18起初21:35全设备清单unavailable/USB无匹配只留历史；用户随后明确连家庭Wi-Fi并授权安装，本批新DNS-SD解析/既有配对核实际名称/UDID/iPhone19,7/iOS27.0/NETWORK。22:12:52.987+08 Complete、lookup存在，安装前后/正常启动后25完整非诊断偏好逐值全同；RSD实际目标/空env空args启动、22:13原生首页NAS在线/Wi-Fi已看。用户已有浮窗未操作，图片不进入共享结果。零媒体，不需要WDA、无配对/系统/网络改动；不称全部服务健康或18播放验收。
- Pad本批0 App/UI/安装/媒体，仍未装当前21:48包；切回必须重新核实际身份/源包及保留数据覆盖、WDA控制，不能继承13/18。

## 本地真机条件和结果

服务器仅Mac家庭LAN，0NAS媒体/蜂窝。两份旧保存H.264/AAC TS（121072/646156字节）以显式DISCONTINUITY反复组成120.12秒VOD；原清单1922bytes，候选同语义加注释填充1621922bytes。两清单各独立URL，慢候选正文25秒匀速写出；相同原/候选均AVPlayer，不是KS/HEVC/TrueHD/PGS换引擎。fixture重复短片不能作为长片时间轴、连续流畅或声音验收。

| 窗口 | 实际执行 | 结果 |
| --- | --- | --- |
| 首fast工具失败 | 22:09:33–46；1实验自动播放启动，0候选点击 | 助手查name=中文标签，实际name=playback.lab.prepareCandidate/label=验证候选；12原XML及enabled=true、first-clock和原媒体请求已证。仅改私有定位，不改App/重建；原失败和全部收尾保留 |
| fast-2 | 22:13:10候选派发；3/10/20及末图；22:13:38收尾 | 清单549ms、解码1482ms、对齐11463ms并实际提交；末界面Candidate Lab/00:25，内部候选13.752/live13.666。正文完整0.084秒，准备还含本地请求/代理/重写等；不把差值定为冗余等待 |
| slow | 22:14:32候选派发；3/10/20/30/40及末图；22:15:17收尾 | 服务器完整25.003秒，清单25550ms、解码26197ms、对齐36473ms/剩余3526ms并提交；原时钟清单期间3.010→27.002、21个内部样本，末Candidate Lab/00:42。不是只花647ms或36秒屏幕卡顿 |
| cancel | 22:16:08候选派发，3/8观察后正常“完成”入口取消；22:16:26收尾 | 清单阶段10710ms cancelled=true/剩余29289ms，无AV解码或提交；上游688128bytes/11.117秒clientWriteFailed在finally停服务器之前，未完整缓存。取消后原生黑场保留，不当普通返回原页面或呈现继续验收 |

每个正常控制窗一次手动实验触发，没有seek/音字幕/PiP操作；总4次实验自动播放启动、3候选点击，不能写成普通影片Play次数。3/10等是计划点，真实PNG采集起止见安全JSON；部分本身黑场/星空片头，后图有星云真实视频内容与Candidate Lab标题/时钟，只是稀疏呈现，不能从日志decode/clock推算每帧显示或无感交接。fast对齐约10秒主要等待前方目标与移动原时钟相遇，不能当整段卡顿或宣称删11秒lead已优化；本批未改该策略。

## 收尾和接续

每窗独立180秒停止守卫/最外层finally，App/WDA状态1/1、fixture服务/日志/守卫均停止，真实临时保活断言和AC供电多点已核。4窗全部25项完整非诊断偏好（含36原书签轨道及进度）不变，0新增Nastart/WDA/Jetsam清单。首工具失败亦计入。

22:17:19–27恢复空env/空args普通NAS在线首页，实际图片已看；22:19:41独立核新13身份/174输入/三哈希/29签名/profile/IPA/自有安装回执，25完整非诊断偏好两次独立读与安装前全同。仅停止本窗正常首页自有PID，WDA1/1/auto10/2、实际Home Wi-Fi/无PiP/host0已核，不声称原生PID0。18保持用户现有前台/浮窗，不追加操作或停止用户会话。当前无自有媒体/采集。

当前实现仅填补Debug候选验证入口，生产完整VOD准备仍前批接受的实现。本地候选有限验证完成后，本地总预算反例见下节已补；下一步：真正KS原流→AV候选/原失败操作与同格式另一片源；随后Pad S01单端/双端及共同链路回归。旧两次相同PGS条件不做无变化第三次重播，不因当前局部控制成功抹掉真实再缓冲和原失败。18安装已完成，不再列连接或首页待验。

## 22:31追加：同一40秒总预算真机反例

仍使用21:48包，0源码/重建/安装；只有私有fixture候选正文从25改32秒，原文/分片/原流和完整候选入口均不变。22:28:47派发候选，清单服务器完整32.010秒、manifestPreparation32433ms、candidateDecoded33083ms。候选目标45.915秒早于原流，应等原流追到对齐；总40008ms时alignment阶段失败、deadlineRemainingMs=0，候选45.913/原流42.489，未出现aligned或committed。既有automatic_downshift_abandoned是reportsFailure=false共用收尾事件，本窗是明确手动实验，不冒充自然自动降档。

40/45/末原生图已看；末Original Lab/00:49，没有切成Candidate Lab。片头黑场不能当后续视频连续呈现验收，但原标题/内部时钟和未提交证据分别成立。这是预定总预算反例，不是产品新增失败或提速；实际证明完整清单时间没有在解码后重置总40秒预算。

22:29:38外层finally停App/fixture/日志/180秒守卫，25完整非诊断偏好同、0新增崩溃清单。22:30:23–31再次恢复空环境NAS在线首页，22:30:59独立新核源包/174输入/三哈希/29签名/profile/IPA/安装回执、25完整偏好两次等于安装前、WDA1/1/auto10/2、实际Home Wi-Fi/无PiP/自有host0；旧22:19审计已私有保留，当前无自有媒体/采集。总计5实验自动播放启动/4候选点击（含首0点击工具失败），0NAS媒体/手动seek/音字幕/PiP。

安全结果totalBudgetCounterexample和finalAuditAfterBudget为最新。当前未完成项收窄为真正KS原流到AV/原失败操作/第二格式样本、真实再缓冲与Pad受影响回归；本地共享总预算不再列待验。18安装及正常首页已完成。
