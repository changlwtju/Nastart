# 候选验证统一全屏承载及字幕反例

2026-10-24 11:05。接[固定DSM地址](2026-10-24-DSM-FIXED-ADDRESS.md)，[安全结果](../../../testing/results/2026-10/2026-10-24-lab-fullscreen-parity.json)，当前现场见[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。私有入口`/tmp/nastart-lab-fullscreen-parity-evidence`与全局最新包`/tmp/nastart-candidate-device-lab-evidence`同根，prior/package-before-fix接09:48批。保留全部其他未提交修改，28开放/76格不变。

## 实现与定向验证

仅DEBUG的PlaybackLabPlayerView原在NavigationStack直接嵌入GreenfieldVideoPlayerView，现由PlaybackLabGreenfieldPresentation调用普通greenfieldPlaybackCover，使用同一个GreenfieldPlaybackPresenter/GreenfieldPlaybackHostingController，包含全屏、Home指示条偏好、关闭和PiP所有权。首次呈现标记阻止正常关闭后重新弹出。调试底页被全屏覆盖时不再提前release代理，实际播放器stop仍释放tracker；旧legacy调试入口的清理保持。普通产品承载、NAS地址策略、编码、Range、40秒预算和缓冲均未改。

新增真实UIKit回归：本地空文件请求、真实UIWindow/SwiftUI与普通全屏host，核modal全屏和隐藏横条偏好；覆盖底页期间资源未释放，绑定清空后实际dismiss及资源仅释放一次，再更新不重新呈现。它验的是呈现与资源生命周期，不能证明物理设备的系统横条已隐藏。20定向XCTest正式TEST SUCCEEDED/exit0：新呈现1、既有固定DSM3/其他连接15、实际解码接手1；15静态预检和普通真机构建通过。测试/构建按序执行，交流电与自有保活起中末核对，均已停止。

## 最新包身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty，174输入，普通Debug/-Onone/Xcode27，构建2026-10-24 10:57:06。iOS diff SHA `260b03606d7b8f298f42332ab23adb11160cd901ec9aba37c53f5c3a95cae463`，IPA SHA `05e0b1c72c8c5aac00b1ba3b7fd6f22ae8584c1f19e198159cb4ec88e069270e`。Nastart二进制 `7911c95c40dcfa227a1168254e553dadfa572e30d9aaccc89822da845eb89dc2`；Debug dylib `cfe4d1001d717a99ac31a301ba9c0f04533129789091b2aed1a94c70876d5e8d`；KSPlayer `029ab5b148dbb5db4fa14f79cc5ff902f2f37a8cd939501dcfb7932b7e9feded`。29库逐个/deep签名、profile期限/目标、IPA CRC/二进制一致/链接核过；profile至2026-10-24 22:23:57UTC，下一轮现场重核。

13实时iPhone14,5/iOS16.3.1/名称/UDID/USB私核；10:58:30保留数据覆盖，25非诊断偏好全同。前台短信未被终止，仅切到已授权Nastart；10:59普通空环境NAS正常首页实际看过才开始媒体。Pad在当前USB列表缺席，身份核对即停、0App操作，未装10:57包；最后确认09:48包。18新浏览2广播/规范同目标0、同配对实例实时解析失败，0备份/上传/安装/启动；最新包未装/固定域名未启用，保持既有一次人工动作请求，不重复催促、扫旧IP、重配或改设置。13结果不能替代18实际域名会话/蜂窝验证。

## 单次13真实NAS窗口

10:59:30–11:00:44，先核本项目其他活动媒体任务为0及主机无媒体读取进程，交流电/有界保活，家庭Wi-Fi不切换。fresh元数据确认S19 128,795,641,934bytes/13,698.368秒、audio1/PGS8 Encode/H264/AAC、12Mbps协商、Start4012.008；Mac仅元数据/协商、0媒体GET。原流static MKV/KS实际首钟4000.116秒，显式Debug单次手动候选，不是普通自动触发。

warmup→commit事件间27.527555秒，清单12206ms、解码19836ms、对齐27317ms；提交储备0.80066秒。7安装配置边界videoOutputCount均1/empty均no，AV采样stall计数0、后续不同电影/末1:07:19实际已看；不是完整物理帧时间或与旧窗供给不同的性能A/B。原流KS计数9（含起播），多张原生图转圈及3.2/4.9MB/s可见，不能因候选后来成功就判原流流畅；既有40.005秒/7300ms失败不关闭。

7张原生播放图均实际查看：全屏承载已统一，但Home横条仍在；候选30秒画面英文底行被白横条盖住，45秒控件隐藏后横条仍可见。**承载差异不是遮挡的充分解释，本次不能称字幕修复。** 候选30秒控件可见属于新AV分支的实际现场，保留原图，未通过裁图或更换文本样式隐藏失败。没有同cue完整字幕、听音、PiP往返、普通自然自动/真实失败新协商或Release验收。

## 收尾与接续

本窗App状态1/1、自有采集/日志/守卫/保活结束、精确自有device/session DELETE204；该响应不单证编码进程退出。25非诊断偏好全同，无新增Nastart/WDA/Jetsam报告。随后11:01恢复空环境正常NAS首页实图，停止仅自有Nastart，11:01:56重核174输入/包/自身回执/USB、36书签键轨道/其他24项及完整偏好两读稳定、changedBookmarkFields空、设置auto10/2、原生桌面Wi-Fi/无PiP。已有非本批13 WDA保留；本私有根活动主机进程0，0蜂窝、0网络/NAS/VPN/音量改动，无周期调度。

下一步针对物理横条仍显示与烧录PGS底行的真实可用区域制定本地反例，不能用host属性或测试通过代替截图；对完整画布/裁切/缩放与字幕保持分别验证，避免为隐藏遮挡破坏画面。原流等待/普通自动失败协商按总账继续，停止同条件无触发长播。18可达后先备份/届时最新包覆盖，再实际开启固定原域名并核重启会话；Pad恢复连接后先最新包核对再回归。

离线SDK接续：本机UIKit头文件明确childForHomeIndicatorAutoHidden可把偏好委托给子控制器；当前测试只断言所呈现host自己的prefersHomeIndicatorAutoHidden。下一本地反例应核实际有效child链及不轮询AX的原生静置图，尚未证明委托或自动化采集为根因。SwiftUI persistentSystemOverlays在本机SDK标注iOS16起可用，只确认可用性，未试改或宣称有效。私有记录home-indicator-next-counterexample-safe.json，无新设备/网络/源码操作。
