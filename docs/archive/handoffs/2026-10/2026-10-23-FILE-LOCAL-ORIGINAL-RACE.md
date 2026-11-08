# 设备文件本地原流准备移除串行查找等待

2026-10-23，关联PX-01/PX-02/PX-03，接用户要求固定基础播放主线。保留全部既有dirty，不调整码率、缓冲、AV等待、认证或NAS/VPN配置。

## 变更卡与基线

旧正常包10-22 05:26，iPhone13新核名称/iPhone14,5/iOS16.3.1/UDID/USB、173输入/29签名/profile及本机回执，原生Home/Wi-Fi已看。S19设备文件从头两次Play请求/0 PiP均因脚本方向读取中断，无完整3/10/30秒实际画面，不计播放通过；第一次保留横屏播放器树，但不能当视频出画。每窗finally终止App/日志/时间守卫，最终state1/1、36原轨道及其他偏好一致、仅自然进度变化，报告名称清单增量0仅清单口径。后续用户明确指出WDA现场，另见[WDA恢复](2026-10-23-WDA-USER-RECOVERY.md)，不把旧接口响应扩大为稳定控制。

首窗真实准备事件：verifiedOriginalRoute耗5357ms/unavailable，随后localRange耗155ms/validated；原清单/相邻文件等准备很短。代码对应本地分支先await JellyfinOriginalFileRouteResolver.resolve，再验证DSM LAN Range，形成可避免串行依赖；日志只证明这段准备等待，不证明全首帧损耗或蜂窝唯一根因。

## 最小实现与反例

DevicesView的本地原流分支复用现有PlaybackOriginalRouteRace：同文件Jellyfin完整身份/认证/Range验证与DSM LAN Range同时开始，首个成功者取消另一项。外层PlaybackFileOriginalRouteSelection的蜂窝公网优先与失败回退不变；每个分支执行前/发布前仍核取消和preparation ownership。只有获胜Jellyfin源才记upstreamSource，不由败者迟到结果污染。未并发创建转码或代理；只有获胜原流选定后才注册代理。新增取消result仅诊断，不导出地址。

12项定向XCTest执行通过（新增2项）：慢可取消同文件查找不阻塞DSM、owner变化拒绝竞速胜者且不再开公网回退，加既有双向获胜/失败/取消及公网优先。15预检通过，正常Debug/-Onone真机构建成功。不是屏幕首帧/声音或性能验收。

## 当前构建与逐设备安装

新包构建于10-23 06:52:41.703248+08，173当前输入冻结、29库独立/deep签名、IPA CRC与内含三二进制、链接核验通过；使用既有三设备有效profile，未续签WDA。IPA SHA-256 `c4953504082b03e206bffbe5844b1c32c975b19db2e2e9bb5e868da37e97ac67`，iOS diff `aa4b5d2bb03805a35707525c06249e93a3b1fee66ed9a8df76c94f7983ea52d0`；完整三SHA见[结构化结果](../../../testing/results/2026-10/2026-10-23-file-local-original-race.json)。私有指针`/tmp/nastart-file-original-race-evidence`，前批包路径保留prior-private-root。

06:55:36 iPhone13、06:56:01 iPad、06:57:40 iPhone18均保留数据覆盖安装成功，逐台现场名称/型号/系统/UDID/连接及本机回执重新核对。13/Pad USB、18已配对Wi-Fi；分别25/18/25项完整非诊断偏好安装前后相同。13正常空环境启动和后续真实播放已核，Pad07:03正常首页/NAS在线原生图已看。18安装Complete/lookup成立，正常启动失败且07:00原生图为锁屏；用户选择“稍后处理，先继续其他调试”，因此正常首页待核、不再探测或催促。旧06:26的旧包正常首页不可继承。L1先S01设备文件/受影响大文件S19及同特征S03，结合Jellyfin未改动路线补基线；Pad及格式/网络代表回归按矩阵补。取消、错误身份、旧任务、画质和实际出画为非退化门槛。无同条件性能基线/完整帧时间不判提速或流畅P，失败保留，28项不关闭。


## 新包定向真机结果（Wi-Fi、普通空环境）

- iPhone13/S19/设备文件，06:57–06:58，1 Play/0 PiP：3秒原生图黑场，10秒New Line片头、30秒Wingnut不同实际画面，普通关闭回相同完整路径原详情已看。localRange72ms validated、同文件查询92ms cancelled；内部first_frame距实际发送1.305秒/时钟推进2.402秒，仅内部信号。36原书签键/原轨道及其他偏好保持，仅1自然进度变化；state1/1、采集/守卫停止、auto10/2、原生Home Wi-Fi无PiP已核。原观察脚本继承的“10-22包”文字标签错误已在独立复核撤销；源包/回执实际核的是本批06:52包。
- iPhone13/S03/设备文件，07:00首窗1 Play后原生截图SSLEOF失败，无完整画面，不判播放失败或通过。07:03–07:05保留该失败并增加截图故障回退后另窗1 Play/0 PiP，实际回退未启用，全部原生图成功：3秒黑场，10秒Paramount、30秒Cruise/Wagner不同片头；普通关闭同原详情及最终Home实图已看。localRange57ms validated、查询75ms cancelled；内部first_frame1.270秒/时钟推进2.311秒。36原轨道/其他偏好保持，仅1进度变化；自有播放/采集/守卫停止，state1/1、auto10/2已核。
- iPad/S01首窗07:06–07:07为导航SelectionError，0 Play：实际按钮label=设备而name=server.rack，错误唯一选择器被拒绝，未发送猜测点击。最终原生App/Runner均0、自有host停止、18非诊断偏好全同。第二窗07:10–07:11按实际唯一label/name进入video后，后续目录层级假设不成立而拒绝继续，仍0 Play；不追加第三轮同样媒体尝试。两窗最终自有host停止、原生App/Runner0、18偏好全同，第二窗最终Home Wi-Fi无PiP原图已看。Pad新包媒体回归仍未完成，须先从已保存真实列表建立可验证路径。

上述内部stall计数均0和稀疏画面不能替代完整帧时间/听音/连续播放验收；未获得同条件缓存与网络配对，不能宣布“提速5秒”或全局起播修复。S01两设备/双入口、深seek、格式族/弱蜂窝、音字幕/保存及完整PiP继续开放，不升级完整矩阵格。


## S01双入口追加（07:13–07:18）

13每窗重新核现场/173输入/新包/本机回执，普通空环境，串行1 Play/0 PiP。文件3秒实际Walt Disney片头/00:01、10秒同片头显控消失、30秒蓝色雾景；一次普通关闭回原完整路径，最终Home Wi-Fi无PiP实图已看。LAN83ms validated，查询1ms unavailable，内部first_frame距实际发送1.006秒、推进时钟2.102秒。原36轨道/其他偏好保持、仅1进度变化。

JF首窗在选中详情后/source超时，0 Play，保留；第二窗把重复WDA PNG观测改为原生图/场景核对，3秒实际片头00:00、10秒下方制作字样变化、30秒蓝色雾景及字幕字样。一次完成后原生前后图为相同影片海报/标题/原文件信息，XML完整源文件名相同；原脚本要求visible=true，而导航源默认省略该字段，导致误断言false，失败保留并以独立实图复核，不重播。不是App退出故障。36轨道/其他偏好保持、1进度变化，WDA state1/1、采集/守卫已停、auto10/2已核。未听音/未测全帧或完整字幕，不关闭整格。

Pad第二窗“缺media”进一步离线定位为实际Button名称使用中文分隔符“、”，助手只接受英文“, ”，目录本身并未缺失；不归App目录层级错误。第三窗以该具体新条件匹配两种实际分隔符，并直接采集场景绑定WDA PNG，避免已失败的Pad旧原生截图服务；最终Home另用原生RSD核查。结果单列，不隐藏前两次0 Play失败。


## Pad文件实际回归与JF阻塞（07:20起）

具体分隔符修正后的Pad/S01/文件窗1 Play/0 PiP，场景绑定WDA PNG在3秒实见Walt Disney/00:01，10秒片头制作字样变化，30秒蓝色雾景和字幕字样；一次普通完成回相同完整路径原详情已看。LAN416ms validated，查询2ms unavailable；内部first_frame距实际发送2.143秒、推进时钟3.200秒，不等同显示/听音延迟。29原书签/轨道和其他偏好保持，1条自然进度变化；最终原生App/Runner0、自有host/日志/守卫停止、auto10/2及原生Home Wi-Fi无PiP已看。

外层旧wrapper的mediaCommands硬编码0被独立复核纠正为1，实际以observer单次sendingOnce及Play计数为准。外层完整非诊断偏好比较为1处变化，对应本轮自然进度，不能说18项完全相同；原轨道/其他偏好仍相同。原结果保留，在独立review中限定解释。

Pad/JF第一窗0 Play，搜索按钮实际name=magnifyingglass、label=搜索 Jellyfin，原私有助手另一处硬编码name导致SelectionError；第二窗统一为实际label/name后进入S01详情，但完整/source超时，仍0 Play，未冒充播放失败或P。不追加同条件媒体重试；新包Pad/JF起播基线仍是TOOL/未验。前窗已核自有App/Runner/host0与18偏好全同，末窗收尾独立记录。

精确深seek仍受旧输入精度反例约束，本批未重放两种已否定方法。当前代码PlaybackSeekBar只在Slider结束编辑时提交本地position，现有seek_started仅证明下游目标；没有同期手指松开/本地值和时长的独立证据，不能以AX整数百分比补齐。下一阶段优先补该边界的新证据或独立供给定位，不改时轴迎合工具。弱蜂窝、大文件深seek、真实音字幕/偏好冷恢复及完整PiP均未关闭。


末窗Pad/JF被新用户消息打断，原observer未完成finally；07:31确认所有本窗host已无，按保存exact App PID/初始Runner0清理自有进程，独立原生核App/Runner0、18完整偏好全同与Home Wi-Fi无PiP原图已看。0 Play，不声称原日志守卫正常结束；自有host实际缺席及补收尾另存。用户明确后续以13为主、Pad必要对照，本批停止Pad导航追加。
