# 设备文件HLS分辨率约束与新包回归

更新：2026-10-18 10:14。范围PX-01/PX-02/PX-03；28项需求状态均保持。用户授权继续App调试及18更新，DSM重启诊断暂缓；未升级DSM/引导/驱动/套件，未改NAS配置、VPN或进行限速/并发大片压测。参见[上一批基线](2026-10-18-RESUMED-PLAYBACK-AND-IPHONE18.md)及[结构化结果](../../../testing/results/2026-10/FILE-HLS-DIMENSIONS-20261018.json)。

## 变更卡与反例

旧69b1普通Debug设备文件HLS仅限制20Mbps，没有Jellyfin入口已有的编码尺寸约束；旧Pad S19曾输出2560×1440，而既有20Mbps画质阶梯定义为1920×1080。该请求不一致有源码及实际输出支持，不据此归因全部慢播放或NAS重启。

`DevicesView.swift`提取实际使用的PlaybackInfo请求构造，按既有GreenfieldQualityPolicy加入H264必需的width/height上限。仅作用于设备文件协商HLS；原画、码率阶梯、音字幕选择、绝对起播时间、分片长度及超时策略保留。新增诊断只记录请求/返回尺寸、码率和本地追踪标识，不记录流地址或token。`PlaybackNextCoreTests.swift`新增3项，检查序列化后实际JSON的多档尺寸、音字幕/绝对时间及禁止误变原画/stream-copy。

先提取构造器但不加尺寸，3项中1项因缺CodecProfiles失败，负例exit65已保留。修复后26项定向0失败，15项preflight、普通Debug真机构建、FFmpeg链接隔离和29库签名通过。未运行全套；历史5项失败不消失。完整S03/S08格式族、三次同条件、10分钟稳定、真实SUB/AUD/HDR/PiP和竞品帧时间未完成，不能宣称L2或最终性能验收。

## 源码与包身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，含原有未提交修改，未重置其他工作；当前ios diff SHA-256 `d664b96e9f59c6369709b0432db5b5f06800759d41d17d40dbbf482ec527b332`。Xcode 27.0/27A266a，normal Debug -Onone; empty launch environment；编译 2026-10-18T09:55:01.834634+08:00，复用既有三设备有效profile重新签名 2026-10-18T09:58:19.868092+08:00，不能把重签时间冒充编译时间。173输入哈希冻结且mtime早于构建产物；profile至UTC 2026-10-24T22:23:57（北京时间10月25日06:23:57）。新包仅留本机私有证据区。

| 二进制 | SHA-256 |
| --- | --- |
| `Nastart` | `4d133035089027548c013fc9b9a79202dc0ed366ee9b430f2425b1213712374e` |
| `Nastart.debug.dylib` | `570b2be7c6e38e4a9cba353fd4c41f41ab29f99447a13a9646ca4152d63524dd` |
| `Frameworks/KSPlayer.framework/KSPlayer` | `997d6ff1e3ed18f6cebe57404b5e8b208b75f0412618b56741bd9b2ac8601c39` |

最终干净IPA SHA-256 `5e48e661327ddbdef3ce647cfebaf7897b41de20dacc3c81d34936f1fa8d7742`，CRC与三二进制一致。第一次普通Mac归档混入AppleDouble `Payload/._Nastart.app`，18以CFBundle错误拒装；失败包/回执保留。仅清理压缩元数据、同签名二进制重打包后安装成功，不归为无线断连，不卸载或清空数据。流程已补入[无线更新手册](../../../development/IPHONE18-WIFI-UPDATE.md)。构建默认profile一度只含Pad，冻结前已换回既有三设备profile并逐库重签验证；没有修改源码/凭据或系统。

## 逐台核包安装

每台均现场重读名称/型号/系统/UDID及连接，不沿用旧列表；USB安装前AFC报告清单与偏好快照留存，18通过当前DNS-SD/配对TCP直接核身份及容器。13/Pad覆盖后实际普通首页已看，空环境启动；18为安装确认，实际Nastart前台仍未验。

| 设备 | 型号/系统 | 安装时间 | 回执 | 实际Nastart前台 |
| --- | --- | --- | --- | --- |
| iphone13 | iPhone14,5 / 16.3.1 | 2026-10-18T09:58:47.049578+08:00 | success | True |
| ipad | iPad12,1 / 18.3.1 | 2026-10-18T09:58:41.269178+08:00 | success | True |
| iphone18 | iPhone19,7 / 27.0 | 2026-10-18T01:59:41.030722+00:00 | Complete/lookup | False |

13/Pad覆盖前后25/18项非诊断偏好逐值一致。18安装前后及启动后25项偏好全部一致（含65书签）。18普通启动请求及截图均完成，但实际截图是另一款App，因此前台核验为false，不称正常首页或18播放回归，也未继续抢占其前台。

## 新包有界窗口

均串行媒体、无测试环境、无人工限速；稀疏截图和内部时钟不替代完整帧时间。首帧列为触摸到内部first_frame，不是精确首个屏幕可见帧；缓存未知、每组仅一次，不作旧新包提速统计。

| 设备 | 单元 | 内部首帧秒 | 采样stall最大值 | URL metrics蜂窝yes/no | 普通退出 |
| --- | --- | --- | --- | --- | --- |
| iphone13 | cellular-file-s19-r1 | 16.758/45.939 | 2 | 40/0 | True |
| iphone13 | cellular-jf-s19-r1 | 1.842/55.661 | 1 | 21/0 | True |
| iphone13 | wifi-file-s01 | 0.755 | 0 | 0/2 | True |
| iphone13 | wifi-jf-s01 | 1.111 | 0 | 0/2 | True |
| ipad | wifi-file-s01 | 2.217 | 0 | 0/2 | True |
| ipad | wifi-file-s19-r1 | 4.333 | 2 | 0/33 | True |
| ipad | wifi-jf-s01 | 1.871 | 0 | 0/2 | True |

四个S01组合实际出画面并普通退出，30秒范围内采样stallCount0；Pad文件t30见底部中文制作字幕，不能代替完整SUB验收或当前S19旧cue问题复验。蜂窝字段来自每任务URL metrics，计量仅保存完成任务正文、已按transferID/upstreamTaskIndex去重，不是接口总流量或计费量。

Pad文件S19内部首帧4.333秒，8.7秒触发自动降档；实际20Mbps协商返回MaxWidth1920/MaxHeight1080。同片同窗服务端输出1920×1080，末累计687帧/27.36秒、0.773x，仍不足实时；缺精确客户端PlaySession匹配，不能归因全部候选等待。候选40.026秒仍未对齐（距触摸50.25秒，候选约21.37、旧流约41.32秒），失败保留，未宣称自动接手通过。随后大seek走KSPlayer原画，内部恢复3615ms，t3旧标题+缓冲、t10/30目标雪山人物画面已看；这不是上一批HLS深seek失败的成功复验。

蜂窝两入口的实际画面、失败/准备阶段及seek证据见JSON各单元；没有把原画成功混写成HLS成功。此次尺寸规则修复已到真实协商与输出，整体加载/转码等待尚未解决。原流8秒探测及44秒详情准备超时未在此批改参数。

蜂窝文件S19实际12Mbps请求返回1920×1080、后续1.5Mbps返回854×480；45.089秒兼容流接手，AVPlayer大seek至6808秒内部恢复20645ms，t10黑屏0KB/s、t30雪山人物实际画面。40项完成URL metrics均cellular=yes，本窗正文183,886,724 bytes，不是总计费流量。首帧16.758秒且深seek约20.6秒，慢等待未解决；不与前批不同设备/缓存的结果计算提速。

蜂窝Jellyfin S19本次1.842秒首帧、55.661秒兼容流另一次first_frame；t10实际片头+缓冲5.2MB/s、t30标题、t60黑帧不单独判停滞或淡出，采样stallCount1、21项完成URL metrics均cellular=yes。本窗60秒普通退出，seek未做；一次成功不能排除前批44.727秒准备超时。导航时服务徽标变化导致一次旧名称定位404，实际App仍在Nastart；重新读取当前控件后正常进入，失败证据保留。

## 数据、报告与收尾

最终13/Pad24/17项非书签偏好一致，36/29原书签零增删、音字幕轨道五字段零变更，4/3条自然更新；App/WDA/Jetsam报告零新增，标准保留拉取均exit0。空环境首页实际已看，WDA10/2、原生条件0；自有Python媒体/Runner worker剩余0，原13常驻服务保留。Pad Runner退出130及保活退出143均为采集后主动停止，不当App崩溃。09:51:57～10:13:04电源日志未见Sleep/Wake转换，开始/中途/末次断言均保存。原始偏好不回写覆盖自然进度。13原Wi-Fi状态恢复，Mac/手机VPN未改；Pad为Wi-Fi型。只结束本批自有Runner与保活，13原常驻服务保留；末次10:13:13只读会话按精确自有DeviceId匹配，13/Pad均无NowPlaying；13仍有TranscodingInfo、Pad无。10:12与10:13两读均如此，元数据残留不等于编码进程仍在，也不能证明全部退出；未广泛终止其他用户会话。

私有指针 `/tmp/nastart-oct18-hls-dimensions-evidence`，工具 `/tmp/nastart-oct18-hls-dimensions-tools`；原始包、日志、身份、偏好、截图和旧失败仅在仓库外，勿公开。后续先把候选首分片/供给与对齐等待固定成可控反例，补精确会话关联，再最小修改；18实际前台、新包HLS深seek、蜂窝两入口重复及完整格式族仍待补。不以DSM重启诊断作为继续App工作的前提。
