# iPhone 18 Pro Max 最新正常包安装

日期：2026-11-01，收尾 2026-11-01T17:56:20.019029+08:00。用户明确要求安装最新包，本批只恢复目标手机发现、备份、覆盖安装和正常启动核对；其他设备、NAS/播放测试仍暂停。[结构化结果](../../../testing/results/2026-11/2026-11-01-IPHONE18-LATEST-INSTALL.json)。没有源码修改，原未提交修改保持。

## 现场与包身份

实时USB为0；系统Bonjour当前广播→既有配对认证取得名称iPhone、型号iPhone19,7、iOS27.0(24A8428)，完整UDID与目标相符，仅本机私存。Xcode缓存tunnel unavailable不当作直接无线服务失败。没有重新配对、改网络/VPN或安装WDA。

旧安装包不匹配当前源码，因此本次实际重建正常Debug -Onone，构建2026-11-01T17:51:54.445848+08:00至2026-11-01T17:52:39.664875+08:00，exit0。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，dirty iOS diff SHA-256 `045cca60476091d088d7d9d01eddf782c9eeaa1d4902fdc0524947e33279b0b5`；446输入构建前后及安装后hash全同。使用本机现有有效profile，无provisioning更新请求/签名配置改动；有效至2026-11-08T01:08:19+00:00且包含目标。30个Mach-O逐一与deep/strict签名、29库、IPA CRC/成员/二进制一致已核。不重复先前纯函数测试，也不冒充本次完整功能回归。

私有包路径：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-11-01-iphone18-install-175114/Nastart-Latest-Normal-Debug.app`；IPA同目录。原始偏好、设备/地址和屏幕仅私有目录，不进仓库。

| 身份 | SHA-256 |
| --- | --- |
| Nastart | `7304e1f1d859c25ca7a26458aa999a76e2c677dd24f5c153853b13ffe21db8e8` |
| Nastart.debug.dylib | `379eb7d23e58263a8f851b805d13dae26105ae8f0b040a588cafd0a794d5cb61` |
| KSPlayer | `e407877addc2d4658a3cde83261f3adb191083dab78d6909a81629a8670b890e` |
| IPA | `df6eb743259a094b12b82f20d460a6b4e135b4a76bbfe1166daba9aac51787fa` |

## 安装和正常启动

安装前通过HouseArrest备份偏好，发送一次保留容器Install，2026-11-01T09:53:30.575157+00:00收到Complete，随后lookup成立；不是仅靠0.1.0/1判最新。安装前后27项非诊断偏好全同；正常启动后仍27项全同，含既有书签对象；不卸载、不清数据/凭据，不宣称整个容器逐字节备份。

首次安装后DVT启动返回DTXNsError，原失败保留，不能抹去安装完成事实。单独空环境/空参数启动成功、PID存在，但实际屏幕仍是其他用户App，故不判前台通过、不处理该App内容。随后按本机既有DVT能力显式ActivateSuspended激活同一PID，空环境/参数保持，已实际看到Nastart启动台首页；未重装、未注入测试变量。进程实际继承环境未独立读取，不把请求参数当完整进程环境证据。自有连接/隧道已退出，无自有采集、播放/下载或新后台任务。

首页显示NAS正在恢复连接/未连接和Wi-Fi图标；旧缓存CPU/内存/硬盘数字不证明实时会话在线。用户保存配置27项未变、没有修改DSM地址或Keychain配置；Keychain登录地址和实际DSM会话端点未单独读取/核验，视频请求未发起，不宣称已启用固定域名会话或蜂窝回退。仅正常启动可能触发App自有恢复连接，本批无额外NAS探测/控制，不声称网络请求总数为0。

## 交接

本批目标安装及正常首页核对完成。iPhone13/iPad/TV未安装本包，旧失败和阻塞保留。已核对唯一需求总账、播放架构和114格矩阵：没有播放实现或验收变化，不新增P或重复改其状态。此前[完整导出函数](2026-11-01-DATA-EXPORT-PAYLOAD-AND-PREFERENCES.md)的真实绑定/分享/读屏及文本隐私边界仍开放；NAS恢复前保持其他真机/NAS/播放暂停。本次不扩大到NAS恢复、系统更新、账号/profile配置或源文件写操作。
