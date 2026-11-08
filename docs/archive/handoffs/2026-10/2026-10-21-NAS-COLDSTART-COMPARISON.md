# NAS 冷启动观察与文件会话提前发布（2026-10-21）

接 [上批](2026-10-21-NAS-RECOVERY-CAPTION.md)。关联 UX-05、CB-15、文件会话准备；28项保持开放。iPhone18依用户要求离家暂停，未发请求、未设调度。

## 对照观察与边界

先现场核13 iPhone14,5/iOS16.3.1/USB、07:14正常Debug源码/173输入/签名/哈希与该机安装凭据；未重复构建或重装该基线。DS One现场2.4.5（4），现有NAS选择后正常重开实见NAS首页；没有改账号、服务器或文件。初次旧WDA会话查询HTTP400、选择后的瞬时账号管理遮罩和首个计时窗复合前台/参数断言失败均保留，未把命令成功作连接成功或反复点击。更换为每App独立WDA应用会话后两窗成功，失败未丢弃。

修正后的Nastart/DS One各一个进程冷启动观察，启动前原生核目标进程不存在、空环境/参数。NAS首页首次满足采样区间分别2.103–2.970秒、1.738–2.743秒；目标目录首次UI采到分别启动后9.995/5.067秒，包含不同导航层级、采样与截图开销。目录按钮派发→首次可见分别至多0.928/0.910秒，前一样本未采，不能当精准耗时。真实截图两边同目录5项内容一致；NAS首页/目录UI本身不证明新登录或服务端刷新。

这是默认体验探路而非性能验收：每App会话准备可能先启动一次，缓存保留且冷热未知；Nastart未优化Debug和Store配置不同，权限/协议与服务端缓存未完整对齐，未做5有效配对、不报胜负/p50或稳定速度。被动USB只存IP/端口/字节/进程元数据，未存载荷；批次两边都对同一个公网TCP5001目的地发出载荷，Nastart另有私网发现流量，不把发现当目录实际换路。macOS系统Python3.9的time.monotonic为每进程mach_absolute_time起点，未将两个进程时钟直接拼成每窗网络时序；上面UI区间只用同一进程。所有采集均结束。

旧磁盘偏好日志未及时包含本窗登录/目录结果，不能把旧11:30/12:10响应迁移到12:20样本。新包定向窗改采Nastart实时NSLog，原始记录只留私有目录。

## 接受实现与验证

此前日志中FileStation登录结束→发布文件会话有约2.15秒间隔；代码finishDSMConnection在attachFileStation后await可选discoverLAN，确认此处依赖可移除。最小修改：认证FileStation返回、operation/auth generation与取消检查后，立即publishFolderSession同步两个读取入口；再等原LAN发现、重新校验并合并地址，原快照/凭据保存/最终发布顺序保持。没有跳过鉴权、提前宣告快照刷新完成或持久化SID，也未将该间隔全部归因网络/DSM/API119。

新增挂起LAN发现反例：挂起时两读取入口已发布FileStation会话，快照/凭据尚未进行；发现完成后同源缓存身份稳定并完成快照。NonPlaybackPolicyTests共121项，120通过、1设备端点配置缺失跳过、0失败，Xcode正常退出；旧登录覆盖/取消等同批通过。15预检通过。字体/视频/PiP代码本批未改，旧像素测试证据仅属旧批。

普通Debug/-Onone/Xcode27，12:26:45.225262+08构建一次，173输入、29库/三二进制/深签名、有效三设备profile、IPA CRC/AppleDouble与链接均核验。iOS diff `65a946fadf61306b78d99aeb3198f202fd8fc34580ed3f2bb619f47d2493c329`，IPA SHA `7344e354d6cf56795048b28992878bef8c8d6a7d90c233c5b4e408873dcb6796`。最新私有指针为`/tmp/nastart-nas-coldstart-evidence`；prior-private-root接07:14包。包与原始身份/偏好/URL/截图/syslog均不入库。

13保留数据覆盖、25项完整非诊断偏好逐值一致，12:28:53–12:29:14定向空环境首页/NAS在线和目录5项真实图已看。实时同一个auth/FileStation pair在12:29:00.313已发布、12:29:02.199完成LAN后再次发布，相隔1886ms，证明FileStation来源已不再等这段可选发现；不是端到端提速1886ms或稳定连接性能验收。snapshot/browserRoot/browserFolder三条当前响应均HTTP200/envelopeSuccess/responseKind success，不关闭历史119。

13本窗零Play/PiP/文件修改，App与自有syslog已结束、原生核无App，WDA恢复auto/10/2，25项完整偏好一致、实际Home/Wi-Fi图标已看。无蜂窝、SSID/VPN/网络设置未动；没有本窗崩溃基线，故不报告零新增崩溃。

Pad现场iPad12,1/iPadOS18.3.1/USB，最初原生查有后台旧Nastart、无Runner；实际原生Home/Wi-Fi、无PiP画面已看后，12:32:49保留数据覆盖新包，18项完整偏好一致。复用已签名WDA，未构建/安装Runner。第一窗已见空环境NAS正常，但套用手机Button角色找不到侧栏设备，零点击并保留失败；依据实际iPad StaticText角色另窗核验，12:35:14–12:35:34正常首页与相同目录5项真实图已看，18偏好逐值一致。两窗自有App/syslog停、WDA恢复auto/10/2；本批自有Runner host精确SIGINT后，原生核App/Runner均不存在，13持久Runner未动。18仍05:31旧包并保持离家暂停。

下一步：NAS真正失败/慢样本来源与受控竞品配对仍需补，停止无变化重复采样；竖屏两次旋转未确认、真实字幕/完整PiP/长稳仍开放。

收尾复核：173输入、iOS diff、三二进制/IPA未变，自有批次Python host为0；文档366份/1904本地链接、0缺失，git diff --check通过。技术路线、开发状态、总账、功能/竞品矩阵和当前摘要已同步；无新播放验收P。
