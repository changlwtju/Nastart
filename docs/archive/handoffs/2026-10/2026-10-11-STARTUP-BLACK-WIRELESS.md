# iPad启动黑场时间线与iPhone18无线更新

更新时间：2026-10-11T15:47:58.337100+08:00。接续[0秒报告修复](2026-10-11-CONFIRMED-SERVER-START.md)，先读取PROGRESS/CURRENT/runbook/分层流程/竞品矩阵。本轮未改App源码或播放参数；保留全部已有dirty修改，无提交/推送/卸载/清登录数据，用户现有网络与18界面延后要求有效。

## 包身份与逐机门槛

仍为HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS差异 `a7f69445bb8c42a359e104b9006753ddc2b9f059d5e02a248abeeecaea6fd5c4`。173源码输入逐项匹配、无更新，普通Debug -Onone、空环境/空参数。构建2026-10-11T14:47:41.254392+08:00；冻结2026-10-11T14:50:56.328536+08:00，profile到UTC 2026-10-17T22:23:40（北京时间10月18日06:23:40）。开工/播放/切换入口/收尾重核源码、哈希、签名、现场设备身份；本轮引用此前同源315测试/2跳过/0失败及15预检，未重跑，不当本轮新执行。

- 已验证包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-confirmed-server-start-144428/Nastart-Confirmed-Server-Start-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-confirmed-server-start-144428/Nastart-Confirmed-Server-Start-Normal-Debug.ipa`。
- 主SHA256：`4b4f086cd8b934e4086a295f864b7848f30c0f6094b672e38a63dd986862087e`；Debug SHA256：`6a1abcf3afd93584f48721be1624fb91677424f7ed9a0ef951cb86c98743d86a`；KS SHA256：`8e6bc9ccfd71d1aa406f1cf74f06201df62b90e577527315f72c040fe2465ebe`。
- iPad12,1/18.3.1 USB当前名称/UDID/连接私有重读，2026-10-11T15:33:54.294932+08:00保留数据覆盖最新同包成功，16偏好一致，普通空环境实际首页已查看后开始本轮播放。
- iPhone18 iPhone19,7/27.0当前既有配对Wi-Fi实时身份成功、USB缺席。2026-10-11T15:35:43.992023+08:00直接无线保留数据覆盖**本轮最新a7包成功**，安装后lookup存在、25偏好一致。没有18 App启动/截图/播放，实际正常界面仍由用户延后；不能把安装成功说成UI/播放回归完成。
- iPhone13 iPhone14,5/16.3.1 USB本轮只读实时身份/配对/既有WDA ready，没有13安装/启动/UI/播放，不沿用上一轮为本轮测试结果；下轮调试前重新过门槛。

## 无线服务的实测进展

系统DNS-SD只解析既有目标并核对TCP配对身份。安装代理Lookup和App容器VendContainer各以普通连接、携带既有EscrowBag做两只读探测，四次都收到成功响应；EscrowBag只用于已有配对的标准服务请求，未重配、未修改设备安全设置。普通方式已经成功，因此不声称Escrow修好了上一轮断开。

随后正常保留数据覆盖安装成功。上轮容器/独立Lookup断开与本轮恢复都保留；端点对照见JSON，不认定手机锁屏、VPN、配对或根因已修。Tailscale/Shadowrocket/防火墙/路由/配对记录均未改。

15:36原生devicectl详情exit0但可能缓存，仍paired/enabled、tunnel unavailable、DDI=false。15:45使用当前实时Wi-Fi身份、userspace CoreDeviceProxy TCP协议与RSD核对同UDID，**RSD连接、DVT服务公布及实际DVT会话建立均成功**，随后正常关闭自己的会话；无root、无修改remoted、无DDI挂载或App命令。此真实成功与原生详情分开记录：不称所有无线开发服务都不可用，也不称Xcode自动发现/LLDB/WDA/完整帧性能已通过。自动通道差异和间歇断开的原因仍待定位。

## iPad S01两入口启动时间线

先设备文件普通终止/启动后的首页→新预览→继续观看，后普通终止/启动后的首页→Jellyfin新详情→继续观看；各实际采集到30秒并普通UI退出。终止/普通启动调用按顺序完成，本轮未另存前后PID对照，不补称不同PID已证。无另一台同时播放同项，普通Wi-Fi、无测试变量/人为限速，未清媒体/服务器缓存，缓存状态unknown。每条保存目标0～10秒及15/30秒原图/XML、每次截图请求/返回、诊断/偏好文件、原退出及失败证据；早段有采集延迟，按实际时间报告，不把target编号当精确采样时间。

| 当前入口 | 就绪/秒 | bufferFinished/秒 | 首个合格时钟诊断/秒 | 最后已查看黑场 | 首张已查看真实电影 |
| --- | ---: | ---: | ---: | --- | --- |
| 设备文件 | 1.759 | 2.344 | 2.519 | target1，实际截图请求约2.024秒 | target2，请求约2.443秒 |
| Jellyfin | 1.741 | 3.735 | 3.965 | target3，请求约3.106秒 | target4，请求约4.009秒 |

以上阶段秒数以触摸API请求开始为基准；真实触摸释放只知在请求/返回区间，不能报毫秒精度可见首帧。保守可见电影延迟区间按触摸和截图完整请求边界计算，文件约1.291～3.056秒、JF约2.067～4.497秒；并非精确解码/显示首帧，不能用于竞品排名。两次t30电影和原退出实际已查看；文件早段黑场、JF t3黑场保留，连续30秒/性能/完整帧均未验收。各只改变同素材一条书签、轨道偏好保持。JF六提交均匹配HTTP成功回执，正started未观察到提前0秒，不证明服务器耐久。

同源上一轮Pad文件冷续播就绪/开始buffering约1.221秒，bufferFinished 5.793秒，合格时钟6.030秒；t3黑場在缓冲期间。此前JF两轮合格时钟约4.233/3.554秒，亦须与原图采集边界对齐。本轮文件起点和缓存与此前不同，不据2.519对6.030声称启动变快或历史故障修复；具体六条时序及局限见JSON。

## 已定位的加载反馈缺口与下一步

`GreenfieldPlaybackControls.isBuffering = !isReady`、`hasStartedPlayback = isReady`，共享控件只在`isBuffering && !hasStartedPlayback`时显示加载提示。KS引擎在源已打开时就ready，初始定位/缓冲尚未完成；本轮JF 1.741～3.735秒仍buffering但提示已无资格显示。这解释该阶段反馈缺失，**不解释全部启动耗时**，本轮未改上述规则。

先建立“ready先到、初始seek、缓冲、从头、暂停预热、切计划/引擎、失败/快速取消”的受控状态反例，再修正加载反馈。要优化等待时长，先补已过目标丢弃边界的有效解码帧及实际展示时间/缓冲容量，不能仅靠降低缓冲或seek参数。`MEPlayerItemTrack.doDecode`里的decodeVideoTime是在解码调用返回后设置，回调可能异步且帧可被seek丢弃；`first_frame`事件由推进时钟触发，两者都不是实际首个可见帧证明。此前“首帧位置”的数值只解释为时钟合格位置，不能转成真实显示帧时延。

## 收尾与完整待办

iPad最新正常空环境首页实际重核、播放器关闭、native条件active0、WDA idle10/动画2恢复；NAS/DSM/JF/Homepage在线，Radarr/Sonarr/Prowlarr警告保留。13仅只读，18UI延后。原图/身份/偏好/凭据/详细日志及helper哈希只留`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-black-window-153329`；background与startup私有指针指向本轮，其他旧ack/confirmed指针不作为本轮输出路径，不盲用全局临时指针。

加载反馈与真实启动等待继续开放，18普通界面和Xcode自动无线/LLDB/WDA/性能待验；S03另一源、AV/HLS、S19深位置/MTP/L2/L3、历史+475.051差异/服务器续播阈值、FileStation119/会话代际、iPhone13真实弱蜂窝旧ordinal0/探测/协商、实际位移与完整显示帧、Lenna/DS One/Jellyfin/Popcorn和全CB/PX/UX/Main均未关闭，无性能/竞品PASS。

结构化记录：[STARTUP-BLACK-WIRELESS-20261011.json](../../../testing/results/2026-10/STARTUP-BLACK-WIRELESS-20261011.json)。
