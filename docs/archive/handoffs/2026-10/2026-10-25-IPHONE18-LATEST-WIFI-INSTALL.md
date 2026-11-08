# iPhone18最新正常包无线覆盖安装

记录：2026-10-25T00:03:16.857897+08:00。用户重新授权将最新包安装至已连家庭Wi-Fi的iPhone18，恢复的是安装支线；此前域名自动选LAN问题继续保留待修。[安全结果](../../../testing/results/2026-10/2026-10-25-iphone18-latest-wifi-install.json)。没有新建调度、控制其他三台或修改App源码；全域共享改造仍接原主线。

## 现场与安装证据

系统DNS-SD当前广播逐一以既有配对认证，现场实际UDID匹配，iPhone19,7/iOS27.0/直接Wi-Fi TCP/62078，目标不在USB。CoreDevice同时paired但tunnel unavailable；这并未阻止历史直接Wi-Fi链路。本轮HouseArrest已有EscrowBag备份成功，AFC上传、installation_proxy Install明确Complete于**2026-10-24 23:57:29.852（中国时间）**，随后lookup和完整偏好读取成功，无卸载/清数据/重配对/改网络VPN/WDA。之前服务断开的旧失败保持；当前恢复可用不能归因于尚未证明的网络或工具修复。

## 最新包身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加原dirty，569输入逐项与23:41:52普通Debug构建核对，冻结/收尾漂移0。沿13当前完整兼容签名包，30个Mach-O均独立/深严格签名，profile包含18且至UTC 10月24日22:23:57（中国时间25日06:23:57）；AppID/Keychain groups与18先前包一致。二进制未修改，不重建相同源码；清洁IPA逐项CRC/成员/哈希核过，无AppleDouble。原始包/完整源清单与签名、设备身份只留私有证据。

- 主程序 SHA-256：`7871a1cb51b3587b0dd3a62316375c7d63578103a0dedfb9352de17f80a494c1`。
- Debug dylib SHA-256：`27868899d739e927352865ec59c50fbeacfa2683473d423dc499146197dcdb75`。
- IPA SHA-256：`67cae9ae417830d41a20b726049b5c329448847503225dc3cda962a8c4e8c562`。

`/tmp/nastart-iphone18-latest-wifi-evidence`为文本指针；其根的`current-package.json`给出本次实际包/IPA绝对路径，`discovery`、`install`、`normal`分开保存原始记录。首打包验证错误Python无依赖失败保留，改系统Python重核同包后才开始设备操作，不影响安装真实性。

## 正常启动、偏好及地址未修复边界

独立走已配对CoreDeviceProxy/userspace RSD/DVT，重新核实时UDID，environment={}、arguments=[]正常启动；原生截图已经实际查看：Nastart启动台NAS在线、CPU/内存/硬盘、12共享目录/112影片、DSM/Jellyfin服务可见，状态栏Wi-Fi图标存在。不是新播放/性能或同边界启动测试。截图前显示工具包装解析错误仅在Mac发生，随后实际显示原图并审阅。

安装前后及启动后**26项完整非诊断偏好逐值全同**，包括完整书签；登录数据未清除。本批未改任何连接字段或固定开关。但地址四层不能混为一谈：保存host仍原域名＋端口，remembered fixed_address=false；Keychain内部固定策略未直接读取；本轮认证后loadSnapshot(session)记录的session.baseURL为脱敏IPv4、协议/端口与保存项不同，**DSM自动选择内网IP的旧问题确实仍存在，未修复**。0媒体，视频实际路线未验证。不要以安装成功/偏好相同/首页在线称域名保持已完成。用户此前暂停此问题，未重写Keychain或重新登录绕过；原始地址不写入共享文档。

无线安装与正常启动已完成；所有自有协议上下文已退出，无新Runner/播放/采集，用户其他后台音频不干预。0蜂窝/0网络改动，无需恢复网络；本批不关闭28开放项/114矩阵格。接续三端共享字幕与TV普通退出，18域名修复仍作为明确未完成项。
