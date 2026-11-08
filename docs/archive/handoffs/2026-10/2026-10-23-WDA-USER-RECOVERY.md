# 用户指出WDA未就绪后的双设备真实操作核验

2026-10-23 06:44起，用户在13手动开启WDA并报告Pad点Runner闪退。按新指令先修工具接入，不把HTTP ready、点击应答或旋转异常当播放验收。

Pad现场iPad12,1/iOS18.3.1/名称UDID/USB新核；保存6:44:04 Runner的EXC_CRASH/SIGABRT报告，最后异常栈进入+[XCTRunnerDaemonSession sharedSession]及UI测试初始化；只据此确定XCTest初始化中止，不能唯一归因签名或普通手动启动。原生RSD起始Runner0/Nastart1，Nastart归属未知未停止。既有已装Runner的本机包/deep签名、profile有效及目标核过，经native RSD/XCTest正确启动，限600秒，无重建或重装。

13新ready无session，旧助手拼None的TypeError保留；创建新系统session。两台一次设置激活的原始截图实见设置页；系统session的activeAppInfo仍报告SpringBoard与画面不符，误断言失败保留，不能独立凭这个字段判稳定前台。初次13截图处在打开设置动画中，后一次已完整设置页。没有改变任何用户设置/网络。

助手将Home写成session前缀路由得到明确404，修正为本机验证的全局POST /wda/homescreen后两台返回系统主屏；13原生/Pad WDA原始PNG均已看，Wi-Fi可见无PiP，原auto/idle10/cool2 GET已恢复。仅接受设置打开/返回Home的有限控制证明，不推断媒体、连续交互或旧失败原因。

所有失败日志与原始身份/报告/图在私有`/tmp/nastart-wda-user-recovery-evidence`。Pad这次600秒Runner于06:57达到时限退出，超时保留，不计App崩溃；07:03独立原生核Runner0/自有host已停。后续媒体窗各自新建有界Runner并分别finally清理，不继承这次ready。App源码随后正常构建并逐台安装[设备文件本地准备修复](2026-10-23-FILE-LOCAL-ORIGINAL-RACE.md)，此WDA核验未使用旧包冒充最新App回归。


脱敏控制/崩溃/收尾口径见[结构化结果](../../../testing/results/2026-10/2026-10-23-wda-user-recovery.json)。后续App回归与设备清理分别记录在[本地准备批次](2026-10-23-FILE-LOCAL-ORIGINAL-RACE.md)。
