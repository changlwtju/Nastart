# 2026-10-11 iPhone18无线WDA恢复与正常界面验证

本阶段完成：2026-10-11T19:16:12.865586+08:00。接续[无线/HLS交接](2026-10-11-WIRELESS-HLS-FOLLOWUP.md)。用户要求继续，并报告手机WDA签名过期、询问其与Xcode自动隧道/界面验证的关系。本轮按此接续恢复WDA并完成最新Nastart首页验证，未开启播放/性能验收。原始设备名称/UDID/IP、签名配置、旧诊断、偏好和图片仅在私有目录 `2026-10-11-wda-wireless-recovery-190724`；[脱敏记录](../../../testing/results/2026-10/IPHONE18-WDA-RECOVERY-20261011.json)。

## 分开的能力与证据

- Xcode/CoreDevice自动无线隧道不依赖WDA。已有配对、开发服务/系统支持和网络通道需独立判断；本轮WDA实际ready后原生隧道仍unavailable，所以不能把它归结为WDA签名问题。
- 手动打开和查看Nastart不需要WDA；本项目当前自动点击、读取界面树及截图方案使用有效签名的WDA/XCTest会话。WDA图标直接打开不是建立自动化测试会话的门槛证明。
- 普通安装、直接DVT启动和系统开发服务可单独验证。此前直接无线RSD/DVT已成功；本轮DVT启动Nastart返回PID，但后续系统截图45秒超时，失败留存，不能用它计正常UI通过。本轮实际UI通过来自后续WDA终止state1/空环境重新启动和已查看的图片。

参考：[Apple真机运行说明](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)、[Appium WDA签名和安装说明](https://github.com/appium/appium-xcuitest-driver/blob/master/docs/getting-started/provisioning-profile/generic-device-config.md)。

## 最新Nastart门槛及现场设备

App源未改，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，当前iOS差异 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`；保留其他未提交修改。普通Debug -Onone、17:36构建/17:38冻结，同一173输入/三二进制/deep strict签名/29库签名/有效profile目标包含关系重新核对。322测试/2跳过/0失败、15预检为此前最终同源结果，本轮未重跑或构建。

包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.app`；IPA `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.ipa`。

- 主程序SHA-256 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`。
- debug dylib `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`。
- KSPlayer `9764ba65bd197b17931a6fff5220d2883cab665daf93bcaaaa99a972de5f2c6b`。

本轮重新DNS-SD发现、配对实时核对名称/完整UDID/iPhone19,7/iOS27.0；目标USB缺席。仅用现场发现地址和已有配对，不取消/重配对。最新Nastart在 `2026-10-11T19:08:09.488962+08:00` 保留数据覆盖成功，保存旧诊断及偏好，不卸载、不清登录。安装后以及最终实际启动后25项非诊断偏好完全一致。

13/iPad本轮未开展新调试/安装，不沿用上轮身份或安装回执作为本轮回归。下一轮若使用这两台须先执行新鲜设备和最新包门槛。

## WDA签名与无线测试会话

用户反馈已装WDA过期；独立安装lookup只读 `ProfileValidated=true`，设备copy_all没有返回精确匹配的旧profile，**未提取到旧embedded profile过期日期**。保留用户反馈与实际查询的边界，不把lookup当成旧签名有效的充分证明。

本机已有当日续签的固定Runner包，本轮复制到新的私有证据目录，核对目标设备包含关系、app identifier、13个签名对象及deep strict签名。WDA源未重新编译，未替换其它设备正在用的Runner。包在 `2026-10-11T19:09:29.118530+08:00` 通过已有配对Wi-Fi/AFC/installation_proxy保留数据覆盖成功，安装lookup存在；没有改变Nastart数据。

- 固定Runner：`com.changliwen.nastart.WebDriverAgentRunner.xctrunner`。
- Runner SHA-256 `4bca27886642bb8793c06401f14ffa24f2113d6019ef78957eb9723221a47850`。
- 有效profile到期UTC `2026-10-17T22:28:19`，北京时间**2026-10-18 06:28:19**。仅代表当前有效期，不承诺自动长期续签。

通过进程内用户空间CoreDeviceProxy/RSD和testmanagerd建立真实XCTest会话：ctrl/main初始化、启动Runner、测试授权、反向XCTestDriverInterface、test plan执行均在私有日志中有记录；随后目标当前Wi-Fi端点 `/status` ready=true且固定Runner Bundle匹配，后续session/activeAppInfo/空环境启动/source/screenshot均实际成功。不是只安装/直接打开WDA便声称可用。Runner专用环境USE_PORT/WDA_PRODUCT仅用于测试服务，没有向Nastart注入条件。

WDA运行由本轮工具会话44543/私有owner记录管理，保留当前测试服务用于后续界面工作；未开启后台自动播放或定时任务。其他设备WDA/转发未停止。退出当前服务/重启Mac/设备后需重新核对并从Mac启动XCTest，不能只点击WDA图标当成ready。

## 实际正常首页验证

19:12 WDA执行普通终止，state1确认，空env/args启动。实际activeAppInfo为Nastart且processArguments明确env={}/args=[]。截图已人工查看：Nastart首页、NAS在线/状态正常、CPU34%/RAM22%/磁盘63%；其它可见服务卡片未知，不能宣称全部正常。播放器关闭。最终25项非诊断偏好无变化，登录未清除；观察waitForIdleTimeout10/动画2已恢复。

同一轮19:12:36独立devicectl仍paired、developerMode enabled、tunnelState unavailable、ddiServicesAvailable false；Xcode本机26.6/17F112。**不把WDA恢复当成Xcode自动隧道已恢复，也不凭版本差异推定兼容性根因**。未用root、DDI挂载、remoted重启、VPN/Tailscale/Shadowrocket更改或设备系统设置变更。

## 接续未完成项

1. 保留现已可用的18直接无线/XCTest链路开展最新包的界面及播放回归；开始/切换/源码修改后继续逐台新鲜门槛。首页验证不是播放、声音、完整帧或滚动性能PASS。
2. Xcode原生自动隧道/间歇断开及直接DVT系统截图超时独立排查，不再把WDA续签作为前置根因修复。优先只读具体服务/系统日志与当前端点，不改现有网络配置。
3. HLS候选完整deadline/分片生命周期、demux/read/异步callback/容量等待仍接续上轮；上一轮退出后500不能直接当退出前根因。旧475.051耐久/119/账号代际/真实蜂窝/代表族/Lenna及其他竞品、全部未验PX/UX/CB/L2/L3/Main继续保留，无性能或竞品PASS。

后续状态补记：上一轮正式XCTest随后以ConnectionTerminatedError结束；本轮起始HTTP拒绝连接已保存，并在已有有效签名WDA上重建无线会话。原成功首页证据保留，后续无线播放与原生状态见[本轮接续](2026-10-11-IPHONE18-WIRELESS-PLAYBACK.md)。
