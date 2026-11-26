# 2026-11-09 iPhone 18 USB 保留更新

用户要求最新包，已把18用数据线连接MacBook。本次fresh确认iPhone19,7 / iOS27.0，USB及原生CoreDevice wired/paired/tunnel connected，完整名称、标识、路径只存本机私有证据 `/tmp/nastart-iphone18-usb-current` 所指目录。过去无线连接断开不是这次USB结果。

本窗冻结最新普通签名Debug `cef058281897916e64ead99c6a12c4a893538f6d7225e6d396317e2a9a53740b`，主程序`36e896383cb89ba1b4f2903e1defbde1c3f504957a5bb5b4f21d510f70441400`，07:09:41+08构建，main/8db1cc64加网络输入与HLS候选分段计时dirty。7项定向通过，播放候选真机验收仍未完成。验签/实际二进制及当前源码哈希、profile覆盖和到期均核。

原有USB配对通过HouseArrest备份App偏好，核对目标PID/实际已装路径后仅退出Nastart，退出前后偏好等值。07:22:33由devicectl保留数据安装成功，服务回执含正确bundle；fresh lookup确认开发包，安装前后全偏好等值。保留用户原DSM域名＋端口的保存配置，不以此推断实际会话地址。无卸载、清账号、Keychain读取、网络或NAS配置修改；未启动App/恢复DSM或Jellyfin会话、未启动Runner。最后核Nastart进程0，设备独占释放。本窗是USB更新回执，不作正常首页或播放回归结论。
