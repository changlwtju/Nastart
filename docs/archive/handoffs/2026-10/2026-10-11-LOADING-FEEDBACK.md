# 缓冲加载反馈修复与三机最新包更新

更新时间：2026-10-11T16:14:16.437256+08:00。接续[启动黑场取证](2026-10-11-STARTUP-BLACK-WIRELESS.md)，已读PROGRESS、CURRENT、runbook、分层流程及竞品矩阵。关联PX-01/PX-02，范围为共享播放器的加载反馈；没有改变选流、缓冲容量、seek、解码器或服务器报告策略。保留其他未提交修改，无提交/推送/卸载/清登录数据。用户要求保持网络配置、iPhone18界面延后继续有效。

## 变更卡与受控证据

基线HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，旧iOS差异 `a7f69445bb8c42a359e104b9006753ddc2b9f059d5e02a248abeeecaea6fd5c4`；Pad已有ready/buffering先到、bufferFinished后到而加载提示已消失的实际黑场证据。根因是controls以`!isReady`判断等待，chrome又以`hasStartedPlayback`屏蔽，transport buffering未发布，时钟停住时不能依赖下一tick刷新。

本轮仅三个源码文件变化：controls将buffering定义为“未就绪或transport仍缓冲”，transport只在值改变时发布，并提供独立`showsLoadingIndicator`；共享chrome使用该显示资格。其他session默认仍用原表达式，不改既有引擎行为。`hasStartedPlayback`及断点/0秒报告保护不变，已准备暂停不要求时钟推进，错误分支仍先于loading显示。

三个新增XCTest覆盖ready/旧0时钟/初始续播缓冲→缓冲结束、后续重缓冲→已准备暂停→disconnect/控件复用，以及transport独立变化发布与重复轮询去重。旧controls实际运行3测试均失败、6断言；修后本轮完整318测试/2跳过/0失败、15预检、真机普通Debug构建成功。上述为本轮执行，不引用旧315代替。

## 包身份与逐机门槛

新iOS差异 `27adfe361189fac22c586f25648742806f7b179afc5690b5074f9f63fbaf0c9d`；173输入、仅上述3输入变化，签名29库逐项+deep/链接核验通过，无晚于产物源码。普通Debug -Onone，启动空环境/空参数。构建2026-10-11T15:55:47.222799+08:00，冻结2026-10-11T15:56:51.815120+08:00，profile到UTC 2026-10-17T22:23:40。

- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-loading-feedback-155411/Nastart-Loading-Feedback-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-loading-feedback-155411/Nastart-Loading-Feedback-Normal-Debug.ipa`。
- 主SHA256 `2bbb9f4a92a8f9c8317972838960bda9f3094cbc67f2babb879151c1c10f3b42`；Debug `fae73a0fc504b7b056fc4377989f389362532c5b9f0866d7adbc6083825fab68`；KS `8e6bc9ccfd71d1aa406f1cf74f06201df62b90e577527315f72c040fe2465ebe`。
- 13 iPhone14,5/16.3.1 USB：现场名称/型号/系统/UDID/连接私有核对，2026-10-11T15:59:47.192641+08:00保留数据覆盖成功，25非诊断偏好一致，实际普通空环境首页确认后播放。
- Pad iPad12,1/18.3.1 USB：同样现场核对，2026-10-11T15:57:19.565017+08:00保留数据覆盖成功，16偏好一致，实际普通空环境首页确认后播放。
- 18 iPhone19,7/27.0：DNS-SD实时目标+既有配对TCP身份重核，USB缺席，2026-10-11T15:59:12.891892+08:00无线保留数据覆盖**本轮27ad新包成功**，lookup存在、25偏好一致。没有18 App启动/截图/播放，普通界面验证仍按用户延后；安装成功不等于启动/回归通过。未改Tailscale/Shadowrocket/配对/路由/防火墙。

每次入口/设备切换重新核173输入、源码差异、包哈希、安装回执与现场USB身份，完整身份只留私有目录。安装前保存旧诊断/偏好，播放后每条只更新同素材一书签、轨道保持；不把播放前后一致与安装前后一致混淆。

## S01四单元定向结果

顺序为Pad JF→Pad文件→13 JF→13文件，全程同项单路，普通Wi-Fi/无测试环境/无人为限速/无缓存清理。普通启动或有序终止/启动调用留证，不补称未记录的不同PID比较；缓存状态unknown。每条目标0～10及15/30秒截图、实际请求/返回区间、诊断、偏好和正常退出保存。真实画面已逐张查看。

| 设备 | 入口 | 内部buffering～bufferFinished/秒 | 已查看的早段画面 | 后续 |
| --- | --- | --- | --- | --- |
| ipad | Jellyfin | 1.836～3.791 | t3黑场+加载提示 → t4电影无提示 | t30电影/原退出已查看 |
| ipad | device file | 1.438～2.852 | t2黑场+加载提示 → t3电影无提示 | t30电影/原退出已查看 |
| iphone13 | Jellyfin | 1.173～1.637 | t1黑场+加载提示 → t2电影无提示 | t30电影/原退出已查看 |
| iphone13 | device file | 0.856～1.614 | t1黑场+加载提示 → t2电影无提示 | t30电影/原退出已查看 |

内部秒数从触摸API请求开始计，非实际可见首帧；`first_frame`仍仅代表推进时钟，decode调用不能证明最终展示。可见电影区间按截图及触摸请求边界保守计算，见JSON；不据跨轮起点/缓存不同数据声称首帧变快，也不判连续30秒、完整帧、流畅或竞品胜负。早段黑场保留，反馈修复不等于黑场等待已消除。两JF合计13提交均匹配HTTP成功回执，0报告失败，正started无提前0秒；HTTP成功不证明服务器耐久。

13文件在t30窗口后补暂停/恢复：第一次工具假定`pause.fill`，当前按钮名未匹配，未发送暂停，保留失败；随后新界面实际按钮为“暂停/播放”，修正私有helper并在同一播放会话完成。两张暂停图17:02和同画面保持、无加载提示，恢复17:05/画面变化、无提示，原UI退出回预览。该阶段晚于30秒窗口，额外播放时间不并入启动测量，不称原生触摸API全面失败。声音效果未验收。

## 收尾与下一步

双机实际最新普通首页/空环境、播放器关闭，NAS/DSM/JF/Homepage在线，Radarr/Sonarr及Pad Prowlarr警告保留；原生条件active0、WDA idle10/动画2恢复。Pad安装后首次前台信息400已保留，普通启动后首页正常，不记App崩溃。私有原图/UID/偏好/凭据/日志/helper及哈希仅`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-loading-feedback-155411`；background/loading指针为本轮，startup/ack/confirmed等旧指针不得盲用。

本批加载反馈L0及S01四单元定向完成，L2扩展、真实AV/HLS/暂停预热/后续重缓冲/失败和快速取消仍待补；L3/全矩阵未关闭。下一步先补目标有效帧、实际展示和缓冲容量，定位真正的首帧等待，再做同条件代表集与竞品性能；不通过降低参数掩盖等待。

18正常UI延后、Xcode自动开发通道/tunnel/DDI与直接无线成功的差异和间歇断开仍开放；旧+475.051服务器断点差异/最小阈值/耐久、S03/S08等代表族、S19/MTP/L2/L3、FileStation119/会话代际、13真实弱蜂窝旧ordinal0/协商、实际位移与完整显示计时、Lenna/DS One/Jellyfin/Popcorn、全部未验PX-01～21/UX-01～04/CB-01～26/Main保持原状态。无全局性能/竞品PASS。

结构化记录：[LOADING-FEEDBACK-20261011.json](../../../testing/results/2026-10/LOADING-FEEDBACK-20261011.json)。
