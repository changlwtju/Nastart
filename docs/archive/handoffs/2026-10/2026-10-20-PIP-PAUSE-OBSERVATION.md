# 系统PiP暂停的实际状态观测与核验

2026-10-20接[USB/session集成](2026-10-20-WDA-USB-SESSION-INTEGRATION.md)，关联PX-06，28项开放。

## 变更卡与边界

旧真实Pad/13偏好在原生暂停后仍保留暂停前playing telemetry；KS周期state也可能为`-`。源码表明系统delegate直接调用KSMEPlayer.play/pause，普通全屏toggle/clock采样不保证随后发生；不能拿缓存、零delta或HTTP200证明本次暂停。

最小实现仅加诊断：KSOptions提供可选系统PiP播放状态观察回调；KSMEPlayer在原有play/pause之后同步捕获requested/actual playing、真实位置及设备uptime。App转主actor后再检查active、完整owner UUID及弱owner，报告新observationID/full owner/实际快照时间，不改变controls或引擎行为。PiP生命周期runtime快照增加full owner和uptime，pip_started同时记录实际状态，为动作前基线提供锚点。HDR保护/传输/字幕路线保持。

[暂停核验器](../../../../scripts/pip_pause_evidence.py)只接受新同完整owner的单次实际暂停回报、未变的事件ID/基线及两次相隔至少2秒的原生Play唯一/Pause缺失；旧包、短ID、缓存、重复指令、seek/恢复/停止/换代、环形记录丢失等均拒绝。私有collector在AFC读取前后核同scene/控件并保存全部源/图/原始偏好；异步落盘仅有界重读，不能重发暂停。此项证明范围是底层指令回报与原生暂停控件保持，不证明连续停止时钟、电影恢复、音频或帧时间。

## 当前实现与验证

17项纯逻辑反例；新私有助手已接真实collector与guard，另4项私有集成和旧两设备真实偏好负例通过。原始证据指针`/tmp/nastart-pip-pause-observation-evidence`。旧偏好即使配上乐观合成UI也不能在点击前通过门槛，不将模拟UI当旧真机新结果。

四个新增Swift定向测试覆盖真实底层命令后快照、实际/请求状态分离、同前缀完整owner隔离、inactive/断开/弱owner/无效时间；连同既有10项，两次均执行14项、13项断言通过/1模拟器PiP不支持跳过/0断言失败，但Xcode均在测试收尾挂起，最终精确停止自有xcodebuild。**测试命令没有正常通过**，不重复第三次相同尝试。初轮后补齐生命周期完整owner锚点，初轮与最终源码/日志分开保存；无第二次真机包构建。

普通Debug/-Onone/Xcode27真机包一次构建成功，21:39:31.631055+08:00；iOS diff `3ee22cab315329e2d27e6851d223bc506d51c868b73dda27da6b2dc798485642`，173输入、29库逐一/整体签名、IPA CRC及链接核完。13于21:46现场核名称/型号/系统/UDID/USB后保留数据覆盖，已实际核空环境正常首页；24项非断点偏好与36原书签轨道保持、书签无增删/变化，零新增App/WDA/Jetsam。当时Pad仍16:16旧包，18尚未操作；22:42后追加授权更新见[后续安装及WDA复用](2026-10-20-WDA-REUSE-IPHONE18-UPDATE.md)。

安装前严格预期设置页的保护遇到实际桌面即停止，未发送安装；独立确认已解锁且桌面无PiP后才按实际场景执行首次覆盖安装。安装收尾创建设置session响应超时，没有重建同动作；先独立停止App并核原生无进程，再用独立截图看到设置主页面的原网络名称与Wi-Fi图标。一次Home清理后原桌面/Wi-Fi再次实见；稳定桌面上的WDA auto/idle10/cool2/activeAppInfo/未锁定只读检查随后恢复。系统会话超时保留，不当App崩溃或网络故障。首页source先采尚未出现NAS文字，稍后PNG可见绿色正常状态，两者时序分列，不凭单图宣称全环境健康。

## 当时的定向窗口门槛（实际结果见下节）

新包/实际观测补点/独立核验器及稳定桌面WDA与旧失败不同。共享任务列表仅当前线程active、未发现同项目媒体进程后，允许评估一次13 S01/JF原生暂停→恢复定向窗口；不是重跑旧媒体基线或补全矩阵。先现查身份/包/空环境、原网络；最多一次容器重显、一次Pause、一次Restore，各自需独立效果，未知即停。暂停前基线缺full owner或playing runtime时不发Pause。最外层先停自有App/守卫，再核原生网络/原桌面、偏好与崩溃；无蜂窝切换或系统/NAS/VPN修改。

## 22:01至22:25导航结果与停止扩展

三次均未发Play、Pause或Restore，媒体窗0。22:01使用全树验证搜索结果后的详情，8秒source超时后守卫阻断后续；22:09限定只导航，详情快速source与scene括号0.844028秒、独立原生图实见详情，完整source仍8.004284秒超时。新session实际重新取默认idle10/cool2，必须在创建后显式设临时0/0并收尾恢复，不能拿旧session设置推断当前。22:25查询唯一Jellyfin元素后首次click返回404 stale，未重选/重发；错误树仍启动台，原文私存，不当导航成功或媒体失败。

每次均原生停止自有App并确认无进程、恢复WDA10/2，24项非断点偏好、36原书签轨道及完整书签保持，App/WDA/Jetsam新增0；原网络及原生Wi-Fi图标实际看图核实。没有蜂窝切换。两次导航超时及动作stale全部保留，真实暂停/恢复仍待验，不追加相同窗口。

USB适配器仅新增固定快速source白名单（排除visible/accessible/traits；缺字段保持未知）与SpringBoard PiP容器/四控件的定向displayed/enabled/rect读取。原生定向观察不依赖全树，保留私有逐请求原文与PNG；仅query stale同scene有限重读、属性/动作未知不重发。13系统桌面图标的三个属性实际只读支持已核，不能转算PiP观察通过。51项WDA及17项暂停单测在Python3.9/3.14通过，另4私有集成；本轮无真实PiP新证据。

用户随后明确要求优先复用既有WDA安装/远控描述。删除尚未使用/测试的额外app-touch封装及其专属window/size路由，停止扩展。按已有start/capture与native RSD/XCTest路径核两端；不是再建一套控制协议。后续设备/18更新详见[同批记录](2026-10-20-WDA-REUSE-IPHONE18-UPDATE.md)。
