# iPhone 18最新普通包正常启动补核

2026-10-21 06:49–06:54（Asia/Shanghai），用户已回复“已解锁”后接续。原始设备名/UDID、端点、安装metadata、偏好、日志和PNG仅存`/tmp/nastart-iphone18-normal-home-evidence`所指私有目录；[结构化结果](../../../testing/results/2026-10/2026-10-21-iphone18-normal-home.json)只含安全摘要。

## 最新包与实际首页

沿用[05:31普通Debug包](2026-10-21-PIP-PQ-NORMAL-DEBUG.md)，未修改源码、重新构建或重复安装。现场USB无目标；系统DNS-SD服务解析本次失败，保留原失败。只对既有配对端点进行一次实时lockdown身份核对，确认原目标名称/UDID、iPhone19,7、iOS27.0及配对状态；原生userspace RSD再次核同一UDID，未自动配对、扫描子网或改网络。

启动前重新核173源码输入、HEAD/完整iOS dirty diff、29库/深签名、profile有效期及目标授权、三二进制、IPA SHA/CRC/AppleDouble。diff仍`4b21ef47f66e81c6ff1468497a56eb5325515bff0b207fcd44a4a1d089e6144c`，IPA仍`67184ddc7138c71ed00099e9b7cfd835556e465c45214645b8cc2c54a20d6dbc`；既有本设备InstallComplete/lookup与相同包哈希收据已核，没有安装请求。

06:49:46–06:50:01本批原生空环境/空参数启动一次，返回PID，6秒后的原始PNG实际为Nastart首页、播放器关闭、原生Wi-Fi图标可见。25项完整非诊断偏好启动前后逐值一致，最终读取仍一致，未回写旧偏好/凭据或书签。首页NAS状态实际“未连接”；其他服务缓存在线标记不等于本批库请求健康，也不能据此归因为05:50的HTTP502、API119或VPN。没有新媒体/库请求证据可用于该归因。

## WDA复用边界与失败

为补18竖屏/PiP，先尝试已有本机Pad fixture的签名/目标授权预检；该fixture不授权18，断言停止，零Runner启动，保留前置选择错误。随后只读本设备实际安装metadata，预期WebDriverAgentRunner Bundle存在、ProfileValidated=true。以此实际安装对象经既有原生RSD/XCTest复用一次，系统在launch_suspended_process返回DTXNsError（deviceprocesscontrolservice code2/启动请求失败），未取得PID/WDA ready/UI session。不能把ProfileValidated或“已装WDA”当作当前可控。

不重建/覆盖WDA、不猜点、不重复派发失败启动、不扩大公共控制封装。06:54独立只读PNG实见设备已解锁且其他用户App前台、无PiP，保留用户现场；无根据声称仍锁屏或将系统拒绝唯一归因为锁屏/签名。全部本批有界命令正常退出，自有媒体请求为零，没有蜂窝/SSID/VPN变更。

## 接续

18最新包安装及空环境首页现已核实；用户原片竖屏、外置文字、PiP/暂停恢复/音频/长稳未新增通过。13先前HTTP502与两次零媒体失败保留，Pad普通包实际PiP字幕证据不迁移为18通过。28项仍开放。后续在18可控且用户空档的条件下补原片；源码未变不重复构建或L0。技术路线实现未变，本批只更新安装/核验与工具阻塞证据。
