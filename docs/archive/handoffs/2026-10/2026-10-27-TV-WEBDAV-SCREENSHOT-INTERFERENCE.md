# TV WebDAV截图干扰与真实返回对照（2026-10-27）

**同一个安装包上，截图方式与普通返回结果存在可重复关联。** XCUIScreen A一次Menu正常返回，DVT截图B三次Menu仍在视频，XCUIScreen C在暂停/继续后又一次正常返回。正式播放路线没有修补；新增内容仅为DEBUG异步准备对照。前批失败观察保留，但“已确认产品无法返回”的归因需要修正。详[结构化结果](../../../testing/results/2026-10/2026-10-27-tv-webdav-screenshot-interference.json)。

## 为什么改变排查方向

本批先用前包不经搜索、直接海报墙进入同一已索引2,949,955,051字节MKV，DVT3/10秒已出不同画面，但三次Menu各等5秒仍未返回，最后主动停止。排除“必须用搜索才能触发”的假设，不能据此断言搜索永无影响。

随后新增显式DEBUG局部夹具：准备按钮先取得实际焦点，4秒后替换为AnyView本地KS播放器，分别直接全屏/嵌套详情sheet+NavigationStack。对照直接播放一次Menu，两个异步场景两次Menu均同正PID返回；第一次将隐藏控制的controller焦点移回play，第二次surface dismiss。准备按钮focused=true、替换后按钮消失均核原生源，代表本机视频帧已看。它们不是NAS播放，也未复现真实路径三键均无返回。

查到[10-25已有记录](2026-10-25-TV-TRANSPORT-PARITY-AND-MEDIA-ACTIONS.md)曾提示DVT截图后遥控干扰。本批之前真实窗都在按键附近使用DVT截图，局部夹具使用XCUIScreen；这是一个尚未控制的测试条件。本批补上同包交替对照，没有继续改按钮样式、FocusState、处理器顺序或window手势。

## 同包三窗结果

| 顺序 | 取图方式 | 有限结果 |
|---|---|---|
| A | WDA/XCUIScreen，3/10秒及返回后 | 一次Menu回同详情，正常退出，同正PID |
| B | DVT，3/10秒及每次Menu后 | 三次Menu均仍播放器，同正PID，由finally主动停 |
| C | WDA/XCUIScreen，3/10秒及暂停/继续后 | 暂停时00:09保持约3.92秒；继续后已见后续画面，一次Menu回详情且再等4秒仍详情，同正PID |

A/B/C都用d8e9df5…普通Debug、空参数/环境，复用原保存登录/同一文件、无搜索路径和同样5秒返回等待；没有改NAS/VPN/账号或客户端正式播放代码。每窗重新普通启动并重新进入同一详情，前窗媒体已停才开始下窗。A/C实际图包含不同播放内容和完整返回详情，不能仅以底层详情AX节点可见判关闭。B及最早前包失败均明确intentional kill，不是崩溃。

此结果支持**截图方式相关的调试干扰**，足以停止把这些带DVT取图条件的失败直接当正式播放器缺陷持续调参。是否为系统截图提示消费Menu、具体消费方及所有历史/用户场景是否相同，尚无直接证据。没有永久关闭“退出”验收项，也没有声称全格式、Release或全遥控器状态已修。

C暂停两张图控制为播放图标且00:09不变，继续后实图推进；继续时控制自动隐藏，XML无时间文字不是时钟归零。属于有限暂停/继续证据，不等于听音、稳定长播、帧时间、精确首帧、seek或字幕完整性验收。原114格不增P。

## 接续的有限seek窗

完成A/B/C后沿同包399源码/27签名/安装回执，并现场fresh核TV身份/连接后继续，不重复构建。自有270秒有界Runner与新会话仅在此窗使用XCUIScreen。实际控制为Up打开进度、Menu隐藏控制后Right请求+15秒，再Up观察；同样隐藏后Left请求-15秒。进度00:10→00:34→00:24，实际画面已看从片头到后续内容再返回前段，最后两次Menu（先收控制、再回详情）同PID正常返回，4秒仍详情。

三个读数间含自然播放和命令/取图等待，不能直接把00:34减00:10当成快进距离，也不能当精确15秒/目标源帧已核。JSON明确 `exactSourceFrameMatched=false`；只有有限的跳转响应、内容变化和普通返回证据，不增114格P。字幕/音轨未在此窗切换。

## 最新包与源码

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加继承dirty。399输入只改变 `tvos/NastartTV/Sources/NastartTVApp.swift` 的 `#if DEBUG` / `--tv-exit-probe` 模式，新增 `player-ks-local-lazy-async-edge` 及其 `-nested` 对照；普通启动与Release不会进入。正式 `NetworkLibraryPlaybackView`、`TVNetworkLibraryPlayer`、KS事件/解码和WebDAV Range/认证桥均未改。

最终普通Debug构建 `2026-10-27T15:43:39.020440+08:00`，主SHA `d8e9df5408b5181434c654a879dc6d9ec4b29a0582431e64841a685a1e695f84`，调试库SHA `ff89966404bf50565cc4cb6204d416929acd38f468b73b2f70e605d69e7fc3c1`。27 Mach-O独立及外壳签名、嵌入依赖/profile/源码核后15:44:03 fresh AppleTV14,1/tvOS18.2 LAN保留数据覆盖Complete，空参数/环境普通启动已核。源码399最终仍与包冻结清单同。初始df96adf…包也在15:37逐机核后保留数据覆盖；不将初始失败归到d8包。原131模块测试为前批基线，本批无模块逻辑变化、不冒称重跑/Release实机验收。

Pad/13/18本批均未访问；移动仍前批2deb713…有限证据，18离家hands off仍07:00旧4e包，DSM原域名端口约束保持。

## 失败与清理

首个目标海报已在AX树但屏外，click返回HTTP400；随后不重置位置就向下找，走到管理行而停止，两次驱动失败完整保留。最终重置普通首页再进入媒体墙，以可见焦点与几何逐键Down/Right、Select进入目标，详情核精确预期文件名。各实播窗重新走这一方式，不能把offscreen click失败当产品无法打开。

较早自有Runner到900秒上限自动结束，当时没有媒体窗在运行；16:11创建新自有Runner/会话后才继续本地和真实对照。最终16:18设置readback恢复/HTTP DELETE200、Runner已停。仅删除SHA读回一致的自有客户端MP4并核不存在；未改NAS原文件/NFO/图片、未执行TMM/TMDB、没有蜂窝或NAS/VPN/系统/凭据改变。

两次清理后的首个普通启动只见系统Home，尽管PID存在，按失败保留；没有据此写正常首页通过。后一次即使已确认Runner停止仍首启只在Home，故不能把原因定为Runner清理竞态；后续重做空参数/环境普通启动，3/10秒取图，最终启动台实际可见；确切最终开始时间与进程在JSON。原149文件完整索引JSON同、15非诊断偏好同，App在/Runner不在，没有本轮后台播放/采集。原始包/图/索引/设备标识/凭据只在本机私有证据根 `current-tv-library-entry-batch-private`。

## 接续

将截图隔离约束补入[播放调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)和[观测手册](../../../testing/CLI-DEVICE-OBSERVATION.md)。下一按XCUIScreen或明确无取图干扰的窗口验证精确seek/目标帧、音轨/字幕与面板返回，再扩Pad/13及代表格式；需要DVT画面时另开受控采集窗，不能每次按键前重复截图后把无事件当App故障。FTP生产适配/FTPS reuse与SMB严格协商/选根仍沿当前交接继续，UX-08/09与30项14/5/11保持。
