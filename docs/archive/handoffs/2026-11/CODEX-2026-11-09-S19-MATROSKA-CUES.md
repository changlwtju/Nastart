# 2026-11-09 S19 同容器复测：Matroska Cues 与视频正文

接续 [合成 MP4 的起播分段](CODEX-2026-11-09-S19-PLAYER-RANGE.md)。这次只验证 Matroska 容器下怎样区分两类等待，未复现或归因真实 iPad 黑屏。

## 方法与结果

用工程已锁定的 FFmpegKit 6.1.4 本机构建命令行工具，将上轮 24 秒 H.264 合成画面无重编码封装为 15,056,257 字节 Matroska。按 [RFC 9559 的 Cues 定义](https://www.rfc-editor.org/rfc/rfc9559.html#section-22) 核对实际文件：SeekHead 指向 15,055,791 字节处的尾部 Cues（466 字节、24 个定位点），14 秒对应 Cluster 起点为 8,799,900 字节。基线源站实录确认播放器访问了这两个确切偏移。只对对应 GET Range 注入延迟或限速，未访问真实影片和 NAS。

独立 A16 模拟器中，使用同一生产播放器视图、规划器、有限 Range 原流代理与 KSPlayer。在隔离 UIKit 宿主全屏呈现，3.5 秒后请求系统关窗。五窗同一 14 秒起点，按 trace / plan / transferID 核对。每窗均走 `localRangeProxy / directPlay / ksPlayer`，关窗后释放该代理一次。内部时钟不等同实际显示首帧。

| 条件 | 代理与定位 | 截止证据 |
| --- | --- | --- |
| 正常供给 | Cues 响应头约 1 ms；初始定位约 16 ms，返回 0 | 有帧提交，661 ms 内部首帧 |
| Cues 响应延迟 5.5 秒 | 该 Cues 请求尚无响应头；初始定位 `pending` | 无视频首包、接受帧、提交或时钟推进 |
| 目标 Cluster 正文限速 64 kbps | 目标 206 头约 4 ms；定位约 24 ms，返回 0 | 有视频首包，无接受帧、提交或时钟推进 |
| Cues 响应延迟 640 ms | 该段 206 头约 650 ms；定位约 683 ms，返回 0 | 有帧提交，850 ms 内部首帧 |
| 目标 Cluster 正文限速 10.8 Mbps | 目标 206 头不足 1 ms；定位约 26 ms，返回 0 | 有帧提交，865 ms 内部首帧 |

这个 Matroska 的 Cues 等待发生在定位调用内，未推进退场为 `pending`；上轮 MP4 的尾部索引等待为 `notStarted`。第一视频包也不是目标帧到达的证明。需要用同一会话中实际 Range 请求和引擎退场联合判断。5.5 秒与 64 kbps 为主动截断诊断，未测产品默认超时。每个条件仅一窗；不比较生产速度，不推广至实际 128.8 GB HDR、AC3 和 PGS。

前两次以测试绑定请求关闭覆盖层未触发关闭，未作为有效对照，原始记录保留。最终改由隔离 UIKit 宿主真实关闭生产播放器视图；确认两次未推进退场均可由现有报告识别，未填为成功起点。模拟器及 loopback 源站已停止，测试实例已删，临时 XCTest 文件逐字节恢复。

## 真机门槛

本机签名 Debug `807b3c7e…` 签名、主程序/动态库哈希及 498 项当前 iOS 输入均复核匹配。用户告知 iPhone 暂代 iPad 接入。收尾前 A16 iPad 仍不在 USB，CoreDevice 为 unavailable，本轮未操作真机或重新安装。已准备只覆盖设备文件入口的有限脚本。接回后先核对设备、实际安装身份、当前进程与 Wi-Fi，在空环境看正常首页，再以 346.993 秒、AC3 2 / PGS 9 复测真片。若捕获慢窗，配对请求与 `engine_startup_incomplete`，决定先处理定位索引还是目标视频数据。

正式播放源码和参数未改，114 格状态不变。[结构化结果](../../../testing/results/2026-11/CODEX-S19-MATROSKA-CUES-20261109.json)。本机私有脚本和证据入口：`/tmp/nastart-s19-matroska-current`。
