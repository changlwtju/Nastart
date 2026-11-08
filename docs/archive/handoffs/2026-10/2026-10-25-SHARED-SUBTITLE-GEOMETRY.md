# 共用字幕视频区域与返回回归

核对：2026-10-25 05:23。原始包/设备/偏好/账号/日志/原生图仅`/tmp/nastart-subtitle-geometry-evidence`文本指针所指本机私有目录。[脱敏结果](../../../testing/results/2026-10/2026-10-25-shared-subtitle-geometry.json)；接[焦点返回修复](2026-10-25-TV-EXIT-EVENT-PROBE.md)。

## 实际接受的范围

新增KS包`Subtitle/SubtitleViewportGeometry.swift`，从移动原策略原样抽出videoRect、bottomInset与手机原字号默认值。移动`LaunchpadPlaybackCore.swift`将原PlaybackSubtitleViewportPolicy改为typealias，Greenfield/外置字幕既有调用真正链接同一实现，旧默认几何/12～20pt与安全区规则保持。TV文件所用KSVideoPlayerView通过独立VideoSubtitleViewport调用同一videoRect，读取引擎naturalSize和fit/fill模式，将原VideoSubtitleView放在视频可见矩形；未知尺寸暂不画字幕，时间模型更新时在字幕子树重读尺寸。

TV仍使用自身字幕字体、padding和作者TextPosition；**不能说TV安全边距/字号也已完全统一**。这是共用视频区域的第一步，尚未移动/恢复ASS作者样式或位图origin；烧录和系统AV字幕路线未改，片源编码内黑边也未自动检测。TVJF仍系统AV/服务端烧录，不假冒已接这个KS布局。没有改选流、轨道保存、解码/Range、缓冲、40秒、NAS/VPN或连接地址。

## 失败、修正和测试

第一版在KSVideoPlayerView根存subtitleVideoSize State，并在state回调更新；普通S03虽出画且后来中英字幕可见，3次Menu仍无exit事件，必须主动终止媒体。失败保留，不能以4项模拟器测试/Release编译过掩盖。该版未接受。

最终版移除父State/回调赋值，将coordinator/timeModel观察放入独立字幕视图，保留已验证视频焦点surface onExitCommand。真机最终S03一Menu、S01两Menu均回原目录/同App进程，trace各只有一次surface exit→disappear→stop.finished。S01第一次采集仍为黑色画面且“完成”存在，第二次才见目录；保留动作/采集差异，不声称各一次或证明每次按键均送到App，也不单凭两窗确证系统底层根因。

- 最终源码移动模拟器8项几何/真实渲染像素回归正式exit0，覆盖竖屏/宽银幕、fit/fill、未知尺寸、安全区、双语文本/位图画布与底边。主移动播放器规则抽取前后保持。
- 最终TV 2几何＋2未prepare播放器返回UI正式exit0；普通Debug及Release无签名compile-only均成功。Release未运行真机。
- TV测试首版CGFloat.infinity歧义编译失败、随后测试target未链接KS动态库的链接失败均保留；只补显式CGFloat及KS测试依赖后通过，产品App依赖未另加副本。

## 当前真机包与收尾

现场重核客厅AppleTV14,1/tvOS18.2/paired/localNetwork与UDID；509输入冻结和收尾全同、27个Mach-O逐个/deep签名、设备授权/有效期、AppID/Keychain及嵌入依赖核过。最终包保留数据覆盖于2026-10-25T05:14:49.447104+08:00，包取私有指针下`isolated/app-path`；主SHA `a020220db6a11e2ddedf70b167ed68c020cb39e842f53b95a5dbd9f4a341fc9f`，dylib `e501c60c2f9aa8b053d2fd7e43ceff45d60b5b8aab99369b39e9f7fb81a2d8a3`。前一`surface-exit/app-path`只属上一批。

最终两窗实际出画/退出/正常空环境首页已逐张看，S03一条完整中英可见但不是全SUB验收；S01开场实图不是听音或全帧证据。整个本批10完整偏好前后仅2条自然续播变化，主题/账号等其余保持，三个自有Runner核停/设置恢复。无蜂窝/网络/NAS修改、无自有媒体采集继续运行。28开放及114格保持。

## iPhone18新一轮包状态

本批现有Bonjour广告中重新认证iPhone19,7/iOS27.0、paired直接Wi-Fi TCP；不是无线不可达，也未重配或修改网络。按当前570输入普通Debug构建完成，30签名/全部二进制已冻结，**尚未安装**。新构建自动采用的有效profile不含18，旧18的同名/同Team/AppID profile至中国时间2026-10-25 06:23:57；不拿Pad授权或同版本号冒充18可装。

以18为destination并允许正常更新签名的Xcode构建exit70：找不到该destination，未进入成功续签。已一次询问用户数据线连接并解锁以重新识别，回复仍待；没有反复催促或把超时当授权。当前候选路径`iphone18/pending-app-path`，原始manifest/构建与发现失败均私有保留。24日23:57无线安装成功仍属历史事实；当前新570源码包不能称18已更新。13/Pad本批0设备操作、当前源码最新真机回归仍待。18实际地址自动LAN旧问题按用户暂停保留，未改保存地址/Keychain/会话。

后续：收到18连接后新核设备/签名/源码，续签覆盖并核数据/实际首页；继续字幕作者画布/位置映射及移动真机新包验证，再推进轨道/续播/取消与退出共享契约。不能把本步写成三端完整播放统一交付。
