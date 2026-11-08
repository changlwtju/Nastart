# 2026-10-10 即时冷启动续播与iPad接续

更新时间：2026-10-11T00:00:01.915726+08:00。本轮未改App源码，继续使用上轮源120c092e与普通9e8f21ec/2c3a2ca0/KSeda1包。完整哈希、路径、配置、时间、173输入及29库签名见[上轮冻结](2026-10-10-RESUME-STARTUP-SAVE.md)和[本轮机器摘要](../../../testing/results/2026-10/RESUME-IMMEDIATE-COLD-20261010.json)。同源306测试/2跳过/0失败、15预检仅引用此前完成记录，本轮不冒充重跑。

## 最新包与连接

13现场iPhone14,5/iOS16.3.1(20D67)/USB；本轮先保留诊断再保留数据覆盖相同最新包，25非诊断偏好完全一致，空环境实际正常首页已核。iPad12,1/iPadOS18.3.1(22D72)/USB首次新枚举出现，但未配对/信息读取失败。用户设备端确认后数据通道恢复，Mac已有配对刷新成功；保留数据覆盖最新包，16非诊断偏好完全一致，原生正常启动/实际首页及随后WDA空环境已核。每台UDID和原始偏好只在私有证据。

iPad旧本地WDA fixture profile已过期，执行前阻止；已安装Runner的实际profile经设备读取仍有效，故没有以过期旧fixture断言手机Runner无效或重装。使用现有同Bundle ID且有效的canonical签名fixture进行test-without-building，WDA16.1.5 ready、固定Bundle ID、no-launch session成功。没有显式重建/安装WDA；Xcode运行和所有原始日志留证。设备profile读取结束后SSL关闭警告也保留，不吞掉。

## 即时退出/冷启动证据

13正常S01文件续播30秒，实际电影画面已核，从121.908秒续播；普通关闭返回后立即提交XCTest terminate（下一条请求，无人为等待磁盘flush），App状态1确认进程已结束，然后空环境冷启动。持久书签为151.508秒，音轨1/字幕关闭不变，18条书签键均保留；最终可读取旧进程最新诊断时钟150.804秒，与保存点差0.704秒。再进入同文件、点击继续观看，首有效诊断时钟151.582秒、3秒实际画面02:33，匹配最新保存点；第二段30秒及普通退出也完成。

本次结果表明此前AFC偏好文件3～10秒延迟可见没有在这一正常终止窗口造成进度丢失。它不是crash/jetsam/SIGKILL/系统断电保证，也不能关闭全部保存收敛缺口。Apple说明UserDefaults进程内立即更新、磁盘异步写入，且无需使用synchronize；见[UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults?changes=_8%2C_8)和[synchronize](https://developer.apple.com/documentation/foundation/userdefaults/synchronize%28%29)。本轮没有添加主线程强制同步或仅因AFC旧文件就改变存储格式。

Pad同源S01文件普通续播30秒、实际t30电影及普通退出，60.784→88.272秒，音轨1/字幕4/启用保留；t3黑屏与00:00图完整保留。冷重启App后同键88.272秒恢复，3秒实际01:29电影可见，第二段30秒及普通退出完成。仅为普通KSPlayer文件入口定向L1，未验证声音生效/逐帧流畅或AV/蜂窝/Jellyfin同条件。稀疏截图、内部时钟不判性能PASS。

## iPhone18无线进展和阻塞

常规usbmux枚举仍无18；直接Bonjour候选却可读取iPhone19,7/iOS27.0新鲜身份，使用Mac既有legacy pair record验证成功，IPv4和IPv6均如此。之前CLI的--udid筛选在mobdev2候选地址列表未选中，因此“需要交互选择”不是设备配对无效。没有新配对、删除配对或修改Mac/手机网络配置。

直接连接的App容器服务VendContainer在实际收发时ConnectionTerminated，PMD与tidevice路径均失败；补现有escrow授权后仍同结果。CoreDeviceProxy StartService可以返回连接，但根本不能以此判隧道建立；无root的进程内userspace隧道在第一握手收包时断开，未连RSD。第一轮HouseArrest使用方式已按当前工具文档纠正、失败均保留，随后factory及独立tidevice仍复现服务断开。所有尝试都停止在诊断保存/容器通道之前，未向手机上传新包；最新9e8/2c3仍未安装。上一轮5ec2/ba52无线安装仅旧包记录。不能把identity/paired/StartService成功算安装、实际启动、调试或性能已完成；根因未确认。没有系统remoted/配对删除/USB前提操作。

## 收尾与接续

两台可用设备恢复最新正常App/空环境/播放器关闭、条件active0、idleWait10/动画2；最终实际首页图已核，NAS正常，其他服务卡片未知，不声称全部服务在线。00:03现场再次确认13/iPad USB身份/配对、WDA ready及设置/空环境前台，18直接网络身份与既有配对仍成功。最终UI和条件时间见机器摘要。下一步继续定位18服务数据链路/官方开发连接，通道恢复后先保留数据更新，核正常启动和UI；补实际后台/PiP/异常终止的保存边界、119、原弱蜂窝与旧ordinal0、完整帧和Lenna/DS One对照。全部PX/UX/CB/L2/L3/Main状态继续开放，无提交推送。

本批App profile北京时间2026-10-11 06:03:15、WDA 06:05:26到期；本轮执行时有效，后续开工先现场核签名与最新源码，过期则按runbook恢复，不以版本号相同当安装身份。原有全局临时证据指针仍可能指向旧批次，接续应使用本批私有根目录及归档helper。

原始账号/偏好/设备标识/网络地址/配对证书/截图仅本机私有 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-resume-startup-save-230033/continue-234239`；exact helper及SHA归档在helpers。用户未被要求取消既有配对。
