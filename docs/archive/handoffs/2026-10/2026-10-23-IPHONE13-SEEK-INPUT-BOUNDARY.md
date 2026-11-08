# iPhone13快进App输入边界诊断

更新：2026-10-23 08:04。用户明确后续以iPhone13为视频调试主设备，Pad仅必要对照；既定主线仍起播/零速→大文件深seek→真实音字幕与保存→PiP。28开放状态未改，不新建周期任务。

## 实现与包

仅在LaunchpadView.swift的PlaybackSeekBar新增Debug限定的Slider编辑开始/结束回调日志，包含trace、App本地position、时长、计算目标和uptime；结束日志在既有commit之前。不改任何seek/缓冲/时轴行为，不逐帧记录。该事件不是物理触摸释放或屏幕显示证据，Release编译时没有此日志。

HEAD 4de732dd645b36671becff992cdef1d0163fd1e4加保留dirty；iOS diff SHA 560ae5706398d6f8275bf971f9026ba8ae62515e0d49fceef7cd4bd9b2a9b974。普通Debug/-Onone，构建2026-10-23 07:33:24.191271+08；173输入、29独立/deep签名、profile、IPA CRC/三二进制和链接均核过。IPA SHA 7521f0129f4a34f2f47891f532ee75d495abc0a61bbf608294be37260fcba67b。15预检通过；没有重跑上一批12路线XCTest，不把历史测试计入本批。

13现场iPhone14,5/iOS16.3.1/USB，实际名称/UDID/配对与连接私有重核，07:36:58保留数据覆盖成功，25完整非诊断偏好逐值相同；07:37原生Home实际Wi-Fi已看。07:38媒体窗按173输入/29签名/profile/本设备回执再次闸门后正常空环境启动。Pad/18仍06:52旧诊断能力包，不能继承；18首页仍按用户稍后处理。

## iPhone13实际深seek窗口

正常空环境/参数，未改Wi-Fi、蜂窝、VPN；两个窗口串行，各一Play/一输入/零PiP。新条件仅App编辑边界证据，非重新校准已否定输入或严格两入口性能配对；请求50%不能代替真实App目标。

| 样本 | App结束ratio / target秒 | 下游seek_started目标 | 实际原生画面 |
| --- | --- | --- | --- |
| S19设备文件 | 0.5089766383171082 / 6972.149295070649 | 完全相同；回调后0.000524秒 | 起播3黑00:00/10蓝NewLine；seek+3旧NewLine+转圈/1:56:12、+10雪山、+30鸟飞且画面改变 |
| S03设备文件 | 0.5107719898223877 / 3843.4407243118285 | 完全相同；回调后0.000607秒 | 起播3黑00:01/10Paramount；seek+3飞机蓝天/1:04:04无转圈、+10驾驶舱、+30Tom户外不同画面 |

两窗精确时长13698.368/7524.768秒，相对名义中点偏差122.965295/81.056724秒。仅可缩小到偏差在App编辑结束前已出现，提交后没有再改目标；XCTest实际输入与SwiftUI/UIKit滑块处理尚未分开，不以调整播放器时轴迎合工具。不继续同方法精度校准或据两片不同恢复速度推因果。

S19内部seek_recovered=3107ms、S03=997ms，均只代表engineCompletionAndAdvancingClock。真实显示只接受稀疏图：S19在+3仍旧帧、+10已新帧，S03在+3已目标附近画面；没有精确首呈现帧/连续帧时间、实际听音、完整字幕验收。两窗普通完成均回同完整路径/源文件详情，最终Home Wi-Fi/无PiP实际已看；各自WDA App1/1、自有logger/guardian已停、auto/idle10/cool2回读，36原轨道/其他偏好保持、各仅一进度变化，新增App/WDA/Jetsam报告名均0。不声称13原生PID0。

[结构化结果](../../../testing/results/2026-10/2026-10-23-iphone13-seek-input-boundary.json)。分析包装首次误用requestStartUnix触发KeyError，保存后改用既有requestStart接口，仅离线重读，无重发真机输入。

## 当前接续与设备分工

07:46原续播/保存准备在DVT runningProcesses停进程处BrokenPipe，0 Play/轨道全同；改为既有WDA停止接口后07:48一Play，进入横屏时read_navigation_source的OrientationChanged中止计划图像采集，非App旋转错误。finally发原PGS恢复且应答，但外部同key仍5 ASS，原为7 PGS，保留不一致；当窗诊断仅存到Play标记+3.189秒，早于+7.420秒的恢复命令，没有恢复后的engine/checkpoint证据，不推定根因。原生黑00:00失败图/空环境NAS在线首页/Home Wi-Fi均实际已看，媒体/日志/守卫停、WDA1/1及auto10/2已核；这不算SUB/AUD/保存通过。07:51独立正常原PGS窗口前的容器已7 PGS/updatedAt814405774.096361，早于该窗播放；说明即时5 ASS快照不是最终保持状态，实际写回/观测延迟来源未知，不把不一致当已定位产品故障。随后普通播放3/10/30/45秒真实黑场→Paramount→Cruise/Wagner→人物画面已看，原生正常关闭回同JF详情/Home Wi-Fi已看，全部36原轨道与07:48前相同、其他偏好不变，零新增报告，WDA1/1/auto10/2、自有日志/守卫停。close与viewDisappear均ready=true/no pending seek、audio1/subtitle7、submitted/memory match，最终外部entry更新时间814405949.946129与后者相同，位置50.931秒；仅同进程保存观察，非冷续播/声音/完整字幕验收。07:56–07:59单个对白PGS→ASS→原PGS窗口已结束：PGS75秒、ASS切换后3/10/30秒、PGS恢复后3/10/30秒实际原生PNG均见不同中英双语cue；逐图未见方框/缺字/重复层/底部截断。PGS60秒未见cue也保留，不当全程缺字幕。ASS状态外部同key为5/108.297秒，恢复正常关闭后为原7/153.724秒；最终entry参考秒814406376.632526与viewDisappear完全同，close/disappear均ready/no pending seek、audio1/sub7、submitted/memory match。全部36原轨道/其他偏好保持，仅目标进度变化；正常回同JF详情/Home Wi-Fi实图已看，自有App WDA1/1、logger/guardian停、auto10/2及新增报告名0已核。只有本片本段有限字幕内容/切换和保存，不作全格式SUB、实际听音、时序精度、PiP或Release整项P；起播实际0/1秒，不以“继续观看”按钮或本地旧进度作为冷续播通过。本批6窗口/5 Play/2 seek/0 PiP，Pad0新操作/18零安装。Pad本批没有操作；18当前广告发现和已知实例实时解析均未验证身份，零安装命令，仍06:52包，不沿用旧IP；18正常首页仍用户暂缓，不重复探测/催促。

私有指针 /tmp/nastart-iphone13-seek-input-evidence，构建/原始图/源树/设备身份/偏好/凭据均在仓库外。保留全部失败与原dirty；不改NAS/VPN/网络或注入测试条件。

08:03最终只读核对：13实时身份/173输入/三二进制/29签名/profile/本设备安装回执仍匹配；完整非诊断偏好自对白窗结束后未变化，36原轨道与切ASS前全部一致。WDA App1/1、Home前台、auto10/2回读及原生Home Wi-Fi无PiP实际已看，自有播放/构建/日志host为0，不作13原生进程缺席声明。文档检查398篇/2164本地链接/缺失0，git diff --check通过；未创建周期调度或声称回合后后台运行。
