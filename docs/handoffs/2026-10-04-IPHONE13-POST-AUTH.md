# iPhone 13 XCTest 授权恢复后的真机接续

2026-10-04（Asia/Shanghai）。本轮继续用户要求的 Jellyfin 局域网《碟中谍》大文件优先回归及滚动/竞品待验；不升级 iOS，不恢复用户已放弃的切换控制路线。

## 设备和最新包门槛

10:58 现场核对 iPhone / iPhone14,5（iPhone 13）/ iOS 16.3.1 (20D67) / UDID `00008110-001E543122E0401E`，USB 配对有效。HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`；保留原未提交修改并将工作区差异存入本机私有证据。应用源码最后修改 10月2日07:33:02；正常 Debug `-Onone` 续签产物 10月4日06:04:29 更新于源码之后，本轮没有应用源码修改。

包为 `~/Library/Application Support/Nastart/DebugEvidence/2026-10-04-renew-060251/Nastart-renewed.app`，main SHA-256 `b2a72e80bcdcf421bd8d1e174621f5ac7a69ae42f85aca78b0b88d8d6b92b6fa`，dylib `6ab6193fa8c9a1f70ee820bb8e9524405a3dbb7f4052bc96db19f19492a2400c`；deep/strict 签名通过。先保存旧诊断，再保留数据覆盖安装，InstallComplete、无测试环境变量启动 PID94954 和真实启动台确认；WDA 激活后的 App PID94959。不得用相同版本号代替此次安装证据。

固定 WDA 复用已续签包，没有重装；Runner PID94956、8102→8100、HTTP ready=true，固定 Bundle ID、session/source/screenshot 和 W3C 点击/拖动均验证。此前本机 XCTest 授权阻塞已解除。系统仍显示“找不到外部切换”横幅，记录为干扰条件，未重新尝试切换控制/输入密码。此前两包有效期保持10月11日06:03:15/06:05:26。

## 《碟中谍3》最新包原画回归

真实私网 IP / HTTP/1.1 / Wi-Fi / localRangeProxy / KSPlayer / 原画，详情4K H.265 HDR、TrueHD5.1。

- 从头 trace `EABEB9A6`：内部播放时钟首帧0.094秒/1504ms，稀疏截图取得真实影片；前段播放后拖到6387.7219秒，实际短暂等待仍在。正常退出回详情，继续观看可见。
- 热续播 trace `92E04E9A`：首帧6413.937秒/2474ms（内部信号）；回退到6167.0674秒，恢复稳态目标4秒/上限16秒。此次位置靠近旧故障6152/6144段，但并非完全相同目标，不计算性能倍率。
- 起播/续播及回退前后仍有4次活动缓冲计数；buffer_updated 记录2051/5300/2372/5799ms等待，不报告零卡顿。原画自动降档尝试候选预热27041ms后因时间轴对齐失败而放弃（当前旧流已正常推进）保留原流，未将HLS后段混入本次原画基线。
- 回退后稳定观察区间：563条遥测覆盖600.385秒，位置6196.517→6796.921，stallCount恒为4、stallActive样本0，储备最低7.904秒；累计掉帧12→15。11张按分钟USB原图确认影片画面，不能据此判逐帧FPS/全程人耳音频PASS。
- 正常点完成回原详情，playback_ended=1。结论：最新包的回退锚点修复仍生效，该后段未再持续反复缓冲；起播与跳转等待、全片/格式族继续待验。

## 诊断边界与 CPU

两次 seek_recovered 在时钟恰等于目标且仍可能缓冲时记录928/980ms，属于引擎定位完成，不能当作可见连续恢复耗时。需另查实际时钟前进及缓冲结束；此诊断语义缺陷保留待修，未据此宣告秒切。

20秒 Time Profiler 成功录制并导出10,966行，样本权重总10.966秒、主线程3.211秒，SwiftUI/AttributeGraph 布局仍在栈中。此为正常Debug不同播放位置的单次采样，不是历史A/B、实际FPS或竞品排名；不能证明CLI导致问题或新优化降低CPU。

## 《碟中谍2》与滚动接续

MI2 是独立样本，不能写成矩阵 S02。54,918,998,512 bytes /4K HEVC/TrueHD，源PGS选择7（字幕实际生效与听音未验）。

原画 trace `6062DC4C`：从头首帧0.094秒/884ms（内部信号），开头视频局部约86～96Mbps；在11.060秒及后续一次缓冲，等待6543/6742ms，累计活动计数2、掉帧8。11个完整32MiB窗口中位52.28Mbps、最低38.89Mbps；慢窗口5.6～6.9秒，全部proxyBackpressure=0/无短EOF，不据此直接定位手机Wi-Fi、NAS或客户端哪端有错。

自动降档请求容量约40.12Mbps，候选预热20431ms，解码帧34.409秒，对齐到候选45.410/旧时钟45.491秒后接手，非重头播放。新 trace `8FB02EB3`，服务端协商12Mbps Transcode、本机localHLS/AVPlayer（遥测分类localRemux不代表原画）。220条有效遥测覆盖298.247秒，位置45.502→343.501，活动计数始终0；掉帧/储备字段AV分支未提供，不能填0。七张观察原图取得真实影片；正常退出，playback_ended=1及详情继续观看可见。原画失败与HLS恢复分开，不能声称系列原画全部解决。

Nastart电影网格：12/12实际位移，动作窗口148.248秒，4次hitch/150.242ms/最长83.433ms。显示表452行、0.715～8.685秒，后续拖动缺显示证据；最终INSUFFICIENT。Lenna1.0.17(610)既有Jellyfin库网格：12/12位移，窗口46.246秒，3次hitch/62.677ms/最长33.656ms；显示表999行、0.282～11.323秒，同样INSUFFICIENT。Debug与AppStore、排序/工作负载不同，不作相对排名；两款均受采样缺口影响，不归因于Nastart卡死。

原始日志、URL、设备偏好与截图仅存本机私有 `~/Library/Application Support/Nastart/DebugEvidence/2026-10-04-resume-105815`；项目仅保留脱敏结果。

## 扩展竞品与优化构建

用户新增DS One与Lenna全面量化，DS One含Jellyfin/DSM直接视频文件两入口；[执行卡](../testing/IPHONE13-COMPETITOR-EXPANDED-20261004.md)保留CB-01～20。现场DS One2.4.5(4)，DSM已登录、Jellyfin既有库入口可进。有效定量播放配对仍0。

标准Release因profile缺iCloud能力首次BUILD FAILED；同源码Release覆写CODE_SIGN_ENTITLEMENTS=Nastart/Nastart.Debug.entitlements，无iCloud能力，BUILD SUCCEEDED。私有Nastart-Release-noCloud.app mainSHA256 `9b454ee023a1fa33a22f164dc34fcc63d4813ca315ccac3e8374babd68aa6e6f`，11:45:54二进制、deep/strict签名通过、profile同10月11日06:03:15。再次USB核对、保存诊断、保留数据安装InstallComplete、无变量启动及真实启动台确认。

校准发现标准Release走旧VLC播放器，Greenfield入口依赖DEBUG编译分支。S01从头播放取得真实画面，稀疏USB截图给可见首帧约562.7～3018.5ms区间，不能当作Greenfield结果或竞品配对。正常退出旧播放器已验；该包未混入上方正常Debug MI3/MI2证据。

改为同源码Debug构建，明确覆写SWIFT_OPTIMIZATION_LEVEL=-O，实际命令保留DEBUG分支；未改App源码、未注入测试环境。私有Nastart-OptimizedDebug.app mainSHA256 `415f61260c10fb7e8049d8ee77c8a76086ac5027290b4d56a6cf1479ff231b93`，11:58:47二进制，无独立debug.dylib，deep/strict签名通过。再次USB身份核对、保存诊断、保留数据覆盖InstallComplete、无变量启动和真实启动台已验。这是最后验证安装身份；Greenfield实际播放基线未开始。DEBUG诊断开销保留，不宣称与AppStore生产配置完全公平。

## 12:14 USB采集失败与接续阻碍

原生USB屏幕设备枚举成功，但AVFoundation电影采集返回-11805 Cannot Record，未出现录制开始。随后WDA退出，USB截图/进程列表/崩溃拉取均无法连接。12:12与12:14交叉核对：idevice_id USB与网络列表为空、pair validate失败、ios-deploy限时枚举253；不能只归因于WDA、App崩溃、密码页或数据线。Mac IOConsoleLocked=No。

IORegistry仍有目标iPhone USB节点，!registered/!matched。按准确UDID唯一匹配，使用本机SDK公开IOUSBHostDevice.reset重新枚举USB（不是重启手机）API返回成功，新USB节点出现，但调试服务仍无设备。未重启Mac/iPhone/usbmuxd、未改密码或系统认证、未重装WDA。原因未确定，采集工具失败不能算播放器FAIL；原始日志仅本机私有。

受连接阻碍，结束恢复正常Debug **未完成**；当前最后安装是415f…优化Debug，不得声称b2a…已恢复。原正常签名包和安装证据都保留。恢复连接后优先现场核对设备、保存诊断、保留数据装回b2a…正常包并正常启动，再决定明确配置的下一轮；不得绕过最新包门槛。竞品有效播放配对仍0，扩展执行卡现覆盖CB-01～26，两入口、音轨真实生效、完整帧采样继续待验。

PX-01～21、UX-01～06 全部既有未验收状态保留；本轮不以单片观察关闭全局任务。iPad/iPhone18未接入、不借用其旧包结果。Lenna主对照及>=5有效配对、实际字幕/音频、完整滚动门槛继续待补。
