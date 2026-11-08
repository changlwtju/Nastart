# 普通Debug的兼容HDR基础层PiP字幕

2026-10-21，接[显式候选与实际校准](2026-10-21-PIP-PQ-CANDIDATE.md)。对应PX-07，PX-06/20仍保留未验收；[结构化结果](../../../testing/results/2026-10/2026-10-21-pip-pq-normal-debug.json)。原始包/设备身份/偏好/截图只留`/tmp/nastart-pip-pq-normal-evidence`指向本机私有目录，旧失败与包通过prior-private-root保留。

## 接受范围与配置

在两台真实iOS的显式候选PGS呈现、白点/roundtrip与固定池/别名自检后，将相同受限路线接入当前普通Debug默认。Debug无环境变量即允许准入，显式NASTART_PIP_PQ_CANDIDATE=0可保留旧保护对照，1仍可用于诊断；Release保持关闭。未取消输入/元数据/格式/运行时校验：仅3840×2160 x420、PQ/2020、FFmpeg-before-filter已检查侧数据、有效静态mastering；Dolby仅已知HDR10兼容7.6/8.1基础层，其他条件仍原帧返回。

输出保持10-bit PQ与正确静态24bytes，不复制旧RPU或原CLL/FALL，明确是HDR10兼容基础层字幕，未宣称杜比动态保真。正常全屏路径/音频/字幕时钟保持。普通Debug的接受范围只限此功能子集，不以此关闭全格式矩阵、完整PiP往返、音画/帧时间/长稳或Release验收；固定池和稀疏App内存不当全App硬上限。

14项定向在新源码下正常Xcode通过；05:31:36.792475普通Debug/-Onone新包，iOS diff `4b21ef47f66e81c6ff1468497a56eb5325515bff0b207fcd44a4a1d089e6144c`。173输入/29库逐一与深签名、profile/三SHA/IPA CRC/AppleDouble/链接核完。三台均保留数据覆盖此包：13/Pad空环境实际首页/NAS正常，18经既有配对Wi-Fi userspace RSD Complete/lookup、25项完整偏好一致。先前04:55显式候选18安装已完成，随后因源码默认配置改变才覆盖此包，不是未知安装的重复派发。

## 普通空环境实测

13 05:35:29–05:37:58，S03/JF原流一次Play/一次PiP及手动Home，实际进程参数env={}、args=[]。两条image1/composited=true/hdrPQOutputCreated，白99.9128→203.703nit、roundtrip0、四surface/别名拒绝第五分配通过；渲染采样39.287/19.041ms。PiP3/10原生图恰无字幕，不把两张稀疏图当实际字幕P，也不把内部合成标志当呈现验收；显式候选原图不迁移为新包结果。

Pad 05:40:46–05:43:18，同包空环境S03/JF KS原流一次Play/一次PiP及手动Home。PiP3和PiP10原生图均实际中英PGS可读，普通默认路径呈现已证；白点与资源自检仍成功。保持音画、全帧与杜比输出未验收，不以两图关闭PP/SUB整项。两设备原生原SSID/Wi-Fi图标、恢复正常首页后停App均核；13原生无App，Pad WDA state1后结束本批XCTest并独立原生核无App/Runner。24/17非断点偏好与36/29原轨道保持，各一自然进度、无书签增删和新增App/WDA/Jetsam。没有蜂窝、网络/VPN变更、新Runner构建/安装或公共WDA封装。

## 竖屏补证与18现场

13 05:46:39–05:47:53拟补竖屏/连续cue截图，JF搜索实际提示暂时无法搜索，零Play/PiP后收尾；05:50:23–05:51:05改读当前资源库现有tile以避开失败搜索，但没有唯一当前S03入口，仍零Play/PiP、未重发搜索或猜坐标。两个结果/原图保留，停止继续无变化采集；竖屏新包真机仍未验，之前四项实际SwiftUI像素/几何L0与修复实现保留。暂时搜索失败未定性为API119或VPN原因，未盲重登/改网络；设备设置后续可见VPN未连接，与早期已连接截图分列，工具未调用VPN变更。

18此普通新包已保留数据安装，安装后原生截图可见其他用户App前台且已解锁；保留用户现场，没有强切App或重试此前锁屏失败的启动。正常首页/用户原片的竖屏和外置文字仍待可用空档复核，不继续声称设备仍锁屏，不反复催解锁或重装。当前已交付普通Debug的受限兼容HDR字幕能力，未宣称18原问题全部验收。

补充离线核实：第二次零媒体窗新增diagnostics.jellyfin.library_failed，Get.APIError/errorCode0/httpStatus502；最新正常启动图实际NAS显示未连接，不能将安装时/此前首页NAS正常沿用成当前连通。原Wi-Fi已连接原SSID且图标清晰；HTTP502的具体网关/服务来源未知，不归119或VPN，也未改变网络/凭据或继续发媒体。当前竖屏补测有真实服务响应阻塞，等待可区分条件后接续。
