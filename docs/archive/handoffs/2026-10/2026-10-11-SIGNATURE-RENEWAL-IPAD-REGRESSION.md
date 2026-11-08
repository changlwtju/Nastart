# 签名续签、iPad 暂停/PiP 冷续播与18无线接续

更新时间：2026-10-11T07:01:51.277945+08:00。本轮仅续签与调试取证改进，未修改 App 源码、未提交推送。当前有效包替代此前已在10月11日06:03:15到期的包；iPhone18尚未安装本轮续签包，不能沿用凌晨三机更新结果。

## 源码与最新有效安装包

- HEAD：`4de732dd645b36671becff992cdef1d0163fd1e4`；保留全部未提交改动，iOS差异 SHA-256：`a56c92d3fd10dae04b2a5c50e8e4f09c4fdc7587441b8dbae01726b968b3743c`。173源输入逐项不变，未发现晚于产物的源文件。
- 配置：normal Debug / -Onone，默认空环境、空参数启动。原编译时间 `2026-10-11T00:59:15.598915+08:00`；本轮增量构建与续签冻结 `2026-10-11T06:24:46.296910+08:00`，构建退出0、签名执行，没有重新执行Swift编译。
- 包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-signature-renewal-062208/Nastart-Renewed-Normal-Debug.app`。App profile有效至北京时间2026-10-18 06:23:40；深严格签名、29动态库独立验签及链接核验通过。
- 主程序 `309d3e6978376473eb5fe4ce8f8252b1f738536628bf6253bba165773b473915`；Debug dylib `acb8c81956fa6a5a54845708691e88fad1411e56a71fe76eea78b7c9395a3d13`；KSPlayer `8e6bc9ccfd71d1aa406f1cf74f06201df62b90e577527315f72c040fe2465ebe`。
- 引用同一冻结源码此前306测试/2跳过/0失败与15预检，本轮签名续签未重跑这些测试。不得写成本轮新增测试执行。

## 逐机安装核对

| 设备 | 当轮连接/系统 | 续签包与正常启动 | 数据保留 |
|---|---|---|---|
| iPhone13 | USB / iPhone14,5 /16.3.1，现场身份原始私有保存 | 2026-10-11T06:25:25.198975+08:00保留数据覆盖成功；空环境/实际NAS正常首页已查看 |25键/25值一致，无卸载 |
| iPad | USB / iPad12,1 /18.3.1，现场身份原始私有保存 | 2026-10-11T06:26:12.597104+08:00保留数据覆盖成功；空环境/实际首页及文件入口已核 |16键/16值一致，无卸载 |
| iPhone18 | 本轮未接通目标无线设备；原生缓存paired/developer enabled、tunnel unavailable/DDI=false | **本轮续签包未安装、未验当前最新包启动** |未卸载、未改配对/网络 |

用户已完成亮屏解锁/同Wi-Fi操作。最新Bonjour发现2条mobdev2、1条remotepairing；目标历史Wi-Fi/UDID身份未匹配，直接地址有界探测也未确认目标。旧地址userspace探测超时，不声称停止了目标App。本轮已请用户提供手机Wi-Fi详情页当前IP，待答复后核对真实UDID再使用已有配对连接，不能将USB作为前提。完整无线WDA/LLDB/性能仍待验。

## WDA续签及重复操作路径

复用历史固定fixture、host `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`、test `com.changliwen.nastart.WebDriverAgentRunner`，未更换身份。新profile北京时间2026-10-18 06:28:19到期，覆盖目标设备，13嵌套签名目标逐项/深严格验签及prepare_wda_recovery验证通过。仅终止逐项核实的旧XCTest所有者，保留数据覆盖安装，13正式tidevice XCTest、Pad正式Xcode test-without-building均恢复ready及新session；13原转发已退出，确认端口空闲后才补建，未盲杀其他转发。正常App首页、source/screenshot均已核。

持久fixture `/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1` 已同步为新有效签名，之前副本私有保留。新.fixture/.xctestrun、XCTest/转发日志、命令及PID/设备身份在私有证据。本次属于实际签名到期恢复，不以每天重复安装作为调试方法。

## iPad功能结果与证据边界

普通Wi-Fi、S01设备文件KSPlayer，逐窗0/3/10/30秒实际画面已查看，单路播放。暂停→系统返回桌面→后台state3→有序XCTest终止state1→新PID正常冷启动：保存623.451秒等于最后时钟，音轨字幕偏好和书签键保持；下一冷续播首帧623.579秒，差0.128秒，实际电影画面已核。

自动PiP→真实SpringBoard窗口→有序XCTest终止→正常冷启动：最终稳定保存654.576秒与该PiP原plan最后时钟一致，原plan的scene/native/PiP will-start/did-start回调均已落盘；下一次冷续播首帧654.715秒，差0.139秒，实际电影与普通退出已核。这里用于核定的稳定偏好是在再次正常冷启动后、任何新播放动作前只读采集，未强制保存/注入/回写。早先即时文件仅638.224秒且缺失边界日志，造成-11.616秒初判；初判及错误预期的首帧断言均独立保留，不能写成未发生，也不能继续将其当已证实App丢进度。

另一次PiP专门检查冷启动后只读文件收敛：保存716.229秒、原plan最后716.880秒，误差0.651秒；首次冷启动只读采集即包含边界回调，没有新增前置等待保存或新播放。该点未再重放，不将上一个654.576点的冷首帧归到此点。两次读取表现不同，磁盘文件收敛的稳定时延/异常终止耐久性仍开放，不声称已修复或保证瞬时落盘。

所有结果限本次有序XCTest终止边界；未做Jetsam/崩溃/重启、完整PiP字幕/声音/帧性能验收，也不关闭PX/UX全部任务。

## 观察工具修正与失败保留

iPad真实按钮为`pause.fill`/`play.fill`，不能只查中文名；旧点按显示控制无实效，改用实际App边界内的W3C触摸并核对图标/实际画面。横屏文件页没有竖屏底部标签栏，旧70点避让会排除实际可见video项，已改按当前方向边界查找。Home单键注入无实效的失败保留；使用设备级`/wda/homescreen`，将默认活动App切到SpringBoard并读取新source后再核state，PiP state4必须伴随真实系统窗口。

初次暂停窗口t3黑场、t30电影、控件定位中断，以及两次Home状态检查中断、两次横屏导航失败、即时磁盘读差异均私有保留。Home过渡截图可能仍为播放器，不能称其为完成的桌面；后续SpringBoard source/state与PiP实际窗口分别核对。精确辅助脚本与SHA清单在`helpers-private/`，不是App源修改。重复操作要先按AGENTS逐机核最新包，再依序打开文件详情、播放30秒、验证暂停或系统PiP、确认有序终止及新冷PID，并在新播放前取稳定偏好，按原trace/plan关联日志。

## 收尾与未完成项

13/iPad最新有效包正常首页实看NAS/DSM/Jellyfin在线，其他橙色警告保留；播放器关闭、环境/参数空、性能条件active0、等待恢复idle10/动画2。13继续USB以便真实蜂窝专项；Pad本轮USB，不称已验无线。

18恢复连接后先保留数据安装本轮有效包并验启动，再恢复无线开发专项。FileStation119根因、磁盘收敛与异常终止、原真实弱蜂窝/旧ordinal0、S19及格式族、完整显示帧与实际滚动位移、Lenna/DS One及CB01-26、全部未验PX01-21/UX01-04/L2/L3/Main保留。当前iPad文件访问已恢复，只表示本轮入口可用，不将此前119/2FA根因标为修复。竞品有效配对本轮0，没有滚动/播放性能PASS。

脱敏机器摘要：`docs/testing/results/2026-10/SIGNATURE-RENEWAL-IPAD-20261011.json`。原始设备身份、IP/配对记录、偏好/凭据/路径与截图仅本机私有目录 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-signature-renewal-062208`。
