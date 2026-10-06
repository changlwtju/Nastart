# iPhone13 供流复现与候选接手诊断

2026-10-06 04:49，接续[上一轮](2026-10-06-IPHONE13-SUPPLY-NATIVE-CONTROLS.md)。本轮给大文件间歇卡顿补了两段自然十分钟证据，并增加诊断字段；**再次复现5200ms缓冲，卡顿未解决，正式竞品配对0。**[脱敏量化](../testing/IPHONE13-WARMUP-DIAGNOSTICS-20261006.json)保存每段包身份、时序、窗口与缺口。原始截图、端点、偏好、包路径和安装日志仅在本机私有证据目录，证据键`2026-10-06-hls-subtitle-supply-042031`。

## 设备与最新包门槛

04:20现场重核iPhone / iPhone14,5 / iOS16.3.1(20D67) / `00008110-001E543122E0401E` / USB。先核验01:58普通d62b/53a2包，保存诊断后保留数据覆盖安装，再执行第一段基线。源码修改后重新正常Debug -Onone构建、深严格验签、核profile设备和期限，并再次保留数据安装；两次均InstallComplete、25项非诊断偏好一致、env={}/args=[]、实际普通启动台已看。不卸载或清登录。

最新HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`；未提交iOS diff SHA `92f7265bd3574b0079e45aaf58b80474403a56d394919d02da6da21fd060fad4`。构建时间`2026-10-06T04:36:03.053072+08:00`；main `baa94b1c2fe8dafc6482e37f53d2545961ec062238660a7e755822a78be095df`；dylib `bddf70e426e3e88a72e6496b361db32457671c7c794c380b1008ee324e63be44`；KSPlayer `c2f1a42bcad0e5c30d0bcebd24576f92d8475c201589ed1f9655cc637d6e7910`。包路径和原始profile在本机manifest，签名期限北京时间2026-10-11 06:03:15。其他未提交修改全部保留。

## 诊断修改及验证边界

`GreenfieldAVPlayerWarmup`在准备、解码、对齐和失败时记录总耗时、候选剩余期限、目标/当前/候选时钟、rate、加载范围前向储备、item/player/timeControl状态、bufferEmpty/keepUp、seek结果、取消和错误domain/code。用于区分准备超时、解码失败、追赶未完成；没有改等待上限、seek/rate、实际帧门槛或接手策略。

`AuthenticatedMediaProxyTransfer`增加随机transferID，和upstreamTaskIndex共同关联窗口metrics/完成。同一播放下实际有3个独立transfer，任务编号各自从1开始，不能仅按编号串联；新日志唯一关联已在真机验证。未改变Range窗口/限流/重试/缓冲策略。源码检查确认暂停累计量在每个上游任务开始重置，吞吐储备样本已经排除>=100ms本地backpressure，未将该假说误报为已修复缺陷。

正常设备构建及15项preflight通过。105核心测试为历史记录，本轮没有重跑；仅诊断增量，未添加镜像测试。自然播放没有触发候选时，新增warmup分支的实际执行仍为INSUFFICIENT，不能把编译通过冒充HLS回归。

## 两段自然原画证据

同实际私网HTTP8096 MI2、54,918,998,512bytes、既有音轨1/字幕7；普通Debug、不注入环境、不清缓存、不限速、不强制转码。第二段从真实“从头播放”按钮开始。请求起止与各屏幕采集实际时刻均在JSON。

| 段 | 当段包 | 有效遥测覆盖 | 新增缓冲 / 丢帧计数 | 完整32MiB窗口 |
|---|---|---|---|---|
| long1 | d62b/53a2，修改前 | 599.183秒 / 562样本 | 0 / 0 | 141 |
| diag1 | baa9/bddf，最新诊断包 | 614.842秒 / 575样本 | 1 / 4 | 144 |

第一段10秒后最小储备5.610秒，首四完整窗口3224/2173/2059/2027ms；第二段首四4627/5265/3593/3650ms且backpressure均0。第二段请求+8.328秒储备1.919秒，+10.525秒0.584秒，+11.529秒0、stallCount=1；时钟在9.631秒附近冻结，+16.727秒记录buffer_updated=5200ms，随后恢复并出现丢帧4。该失败保留，不用前段稳定或后段恢复覆盖。

第二段供流窗口关联是transferID+index的唯一metrics/完成对。第一段旧日志没有transferID，限定<100ms相邻、同trace/index/kind/role且唯一才配对，不全局按index合并；非数值“-”保持unknown、不转0。第一段最长响应10303ms伴随最高backpressure7809ms，<100ms backpressure窗口最长3935ms；第二段相应10962 / 8702 / 5265ms。消费端主动等待不等于NAS响应慢，仍无法将供流波动归因NAS/Wi-Fi/CLI/解码某单项，顺序/缓存/负载也未受控。

真实双语字幕、电影画面和Home条隐藏已核；第一段t3/t10采集调度晚，不能作首帧结果。第二段t3实际00:01自然黑场，t10已是Paramount山峰，t30悉尼；相同请求边界的可辨片头粗区间3.254～11.531秒。t180完整双语安全/safely cue、t300飞机另一帧已核。自然黑场和稀疏截图不提供精确解码首帧或完整显示流畅度，也不与竞品单样本排名。两段未自然触发HLS，**最新包旧HLS失败的同字幕cue仍未验**。第二段场景日志scenePhase=background但eligible=true；既有门槛按实际播放活动执行，不将SwiftUI场景标签当本轮阻塞根因。

## 接续与收尾

本轮没有新竞品样本，上一轮Lenna及DS One Jellyfin/DSM探索值仍单独保留，正式同条件配对0；不同路线、源码构建、方向、未知缓存与文件等价不能排名。下一步优先隔离初段储备耗尽和供流波动，等待自然候选后用新增分阶段诊断解释失败，补HLS同失败字幕cue；再补DS One不切轨暂停字幕对照、统一路线/文件/轨道/方向/构建资格的>=5组配对。PX01～21、UX01～06、CB01～26既有缺口、真实声音、完整帧/滚动、代表格式及iPad/iPhone18继续保留。

收尾2026-10-06T04:49:23.332744+08:00：最新普通Nastart PID19718，env={}/args=[]，视频已实际退出、普通页面Home条恢复，手机locked=false、WDA ready，既有宿主70500、idleWait10/defaultActiveApplication=Nastart，Mac有界caffeinate52029仍在。源码/包哈希仍一致；全程未重装Runner、新建session、输入密码或变更系统安全设置，不保证一天免授权。
