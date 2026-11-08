# iPad进程状态核对与首页/我的一致性

2026-10-22 06:33–06:45，关联UX-05。接[上一批未知新PID](2026-10-22-IPAD-CONFIGURED-RESTORE.md)。无App/WDA源码修改、构建或安装；05:26普通Debug/-Onone、173输入/29库签名/profile、当前Pad名称/iPad12,1/iPadOS18.3.1/UDID/USB与本设备保留数据安装回执均重新核对。包/原始身份/偏好/图日志私存`/tmp/nastart-pad-process-audit-evidence`，package-private-root指既有最新包目录。

## 状态与失败，不能混为媒体任务

原未知进程仍同PID，原生startDate为UTC10-21 21:51:23.959804；原生Home无PiP/Wi-Fi实际已看。其来源没有被证明。磁盘诊断仍止于05:45，缺新记录不等于内存无请求，也不凭进程存在认定播放。

复用已签名/已安装固定Runner做有界观察。06:37初次连续两次XCTest state=2，本机Xcode SDK XCUIApplication.h定义为runningBackgroundSuspended；随后一次activate返回，但即时activeAppInfo仍SpringBoard，停止导航，不声称新PID或App失败。清理误用session路径/wda/homescreen返回404；后续只读时120秒自有Runner预算已到、MuxReplyError，失败保留，未重放激活/媒体。06:40单独改按明确state/观察目标判断，读3/3（runningBackground）即在动作前守卫停止，零激活/播放，不将其误标挂起或播放。官方[WDA会话命令](https://github.com/appium/WebDriverAgent/blob/master/WebDriverAgentLib/Commands/FBSessionCommands.m)供协议核对，本机实际响应优先；系统session的即时前台读取不足以证明App激活效果，不把后续成功倒推成唯一scope/转场根因。

两次有限尝试后停止扩展同条件控制。重新区分规则：同项目媒体互斥保护活动任务，不能把来源未知的每个闲置PID变成永久禁止正常App调试。原进程此前已实测连续挂起，本轮没有Play、没有其他活动同项目任务证据；保存完整偏好/诊断后，按用户已有正常调试授权做保留数据App基线重启。不是清登录/卸载、不是判断原进程属于用户或被WDA自动启动。

## 正常App会话与两页结果

06:43:28–06:43:41，独立明确App-bound正常会话，forceAppLaunch/shouldTerminateApp用于本次基线，environment={}、arguments=[]实际读回一致；记录本窗新PID用于精确停止。既有Runner与控制脚本按顺序同批运行，ready后立即测试、完成即SIGINT结束host，不让控制脚本空等耗尽Runner预算。

首页原生WDA PNG/AX实际NAS在线/状态正常，约5.307秒采样到（含WDA UI时间，单窗，非Strict CB15/竞品速度）。从当前唯一“我的”语义按钮进入，实际图/AX显示可用断开NAS、无正在恢复副提示。图片仍有WDA已知倒置现象，可辨内容与页面一致性已核，不以其作输入坐标/产品旋转/字幕呈现验收。各服务此时仍未知，不扩大为服务全健康。18完整非诊断偏好键和值逐值一致；0 Play/0 PiP，未点退出NAS、未改网络/SSID/蜂窝/VPN/凭据。

本窗App按记录新PID校验后停止，XCTest state=1。后续单owner原生RSD再核：原未知PID与新自有PID均不存在、全表Nastart=0、自有Runner=0，自有host/采集=0；18偏好再次完全相同、173输入/包/签名/profile再次通过。原生最终Home无PiP/Wi-Fi图标已实际看图核实；Pad不保留后台Runner/session，13持久Runner未动，18按用户暂缓不探测。

[安全结果](../../../testing/results/2026-10/2026-10-22-pad-process-and-mine.json)。只接受Pad正常首页/我的一致有限切片，清除“仅PID未知就禁止一切后续测试”的现场阻塞，不认定原进程启动根因、全App后台无流量或NAS性能达标。下一步回到已授权字幕/PiP剩余场景，媒体前仍现场核同项目任务/设备/包与原轨道，不重复旧PGS候选失败条件。28项保持开放。
