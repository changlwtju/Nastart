# USB优先字幕控制栏布局交接

更新时间：2026-10-11T21:04:05.022954+08:00。接续[上一轮](2026-10-11-IPHONE18-ENABLED-TRACKS.md)，机器摘要为[USB-SUBTITLE-CONTROLS-20261011.json](../../../testing/results/2026-10/USB-SUBTITLE-CONTROLS-20261011.json)。先13、Pad，后18；旧证据不当成新包回归。

## 当前源码和包

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS未提交差异SHA-256 `2946c84b6a1831e41220671b9807bf56dba8d28643a238fa3aee78d8805e525c`；本轮只新增SharedBuiltInPlayerView实际控制栏高度/安全区避让与GreenfieldKSPlayerRenderer字幕底部环境值，两文件原有修改保留。控制隐藏/锁定时恢复原有字幕底距，外部CJK文字也使用控制栏避让；外部字幕及AV系统字幕未真机验收。播放策略、轨道身份和seek实现未改。

普通Debug/-Onone，构建时间 `2026-10-11T20:43:17.198378+08:00`，无测试环境变量/参数。包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-usb-subtitle-203049/Nastart-Subtitle-Controls-Normal-Debug.app`，IPA同目录；173输入内容及mtime、29动态库逐一签名/App deep strict、链接核验通过，profile UTC `2026-10-17T22:23:40`。本轮实际执行322测试、2跳过、0失败和15预检。三个二进制SHA-256：

- Nastart `7ec01c72e7b92036543b275f4e0166c0bbcb96a54d62a753aad63f987bffb465`
- Nastart.debug.dylib `17f17700a89e13c6515f71c99f7c12aa6c357633baacd84d4164aeeececc7705`
- KSPlayer `042a3ecaaf2d9d6b30bf6d176b4f6a8e8d0319ece60f2eea55bca061b6aedc04`

现场名称、UDID、地址、配对记录、原始偏好/诊断/截图及helper仅在本机本轮私有证据目录。不得写入公开文档或复用旧端点。

## 逐台最新包门槛和结果

|设备|现场型号/系统/连接|本轮当前包|实际结果|
|---|---|---|---|
|iPhone13|iPhone14,5 / 16.3.1 / USB|保留数据覆盖成功，25项偏好一致，实际空环境首页已看|S03同cue稳态布局及45秒自然播放观察；最终正常首页、播放器关闭、idle10/动画2|
|iPad|iPad12,1 / 18.3.1 / USB|阻塞：CoreDevice3002/IX48，无法确认安装身份|禁止当前包播放回归；有效固定WDA正式XCTest已ready，仅工具恢复|
|iPhone18|iPhone19,7 / 27.0 / 实时DNS-SD既有配对无线|新包安装成功，25项偏好一致|普通启动被Locked拒绝，待解锁；新包实际首页/播放未验|

iPad先前上传未完成以及USB InstallationProxy90秒超时都保留，无InstallComplete；停止自己失败的传输后原生有界重试仍IX48。Mac未发现剩余本轮安装命令；不能据此消除手机系统协调任务。已请求设备图标状态，未卸载/清除登录。复用本机续签固定fixture（有效至UTC10/17 22:28:19）正式test-without-building恢复WDA，不改配对/开发服务/网络。不要把WDA可用或旧App能打开作为新包门槛通过。

## iPhone13定向对照

旧c692包在S03暂停同一中英句时英文与底部按钮重叠、隐藏后可读。新2946包通过普通播放/后退控件取得同句，暂停保存285.545秒，t0/3/10精确位置一致且字幕位于控制栏上方；普通恢复3/10/30/45原图逐张已看，正常退出保存332.734，音轨4/字幕5开启保持。再次稳定暂停/隐藏/重现补查最终正常退出364.873；24非书签偏好未改，只有S03书签自然更新，未注入偏好。

**只确认该横屏S03文本双语字幕稳态遮挡改善。** 首次重新显示约0.3秒截图仍有过渡重叠，保留为未完成项；补查等待2秒后字幕回到控制栏上方，但不能用稳态图替代动画全程验收。无完整声音、帧时间、HDR/流畅、全SUB或CB排名PASS。截图在iOS16呈竖向像素、实际App横屏bounds；不能据截图旋转误判App方向。

失败不丢弃：旧helper沿用18符号找不到13本地化按钮；隐藏后的XML不含字幕导致同cue匹配失败；一次HTTP RemoteDisconnected后session404，重建新session后保持原暂停画面；启动早于控件就绪以及快速15秒后退未取得指定cue的尝试也保留，均不冒充合格样本或seek验收。新旧cue比较无需电影帧完全相同。主回归与最终崩溃文件名清单均无新增（已有Nastart13/WDA0/Jetsam26），不声称历史报告不存在。最终普通空env/args首页NAS正常已实看，其他卡片未知；13现场有Wi-Fi图标，本轮不是蜂窝测试。

## 继续队列

1. 优先解决Pad协调安装阻塞；据设备图标状态继续非破坏性安装诊断，成功后保留数据覆盖当前包并核实际普通首页。13补控制显隐动画、竖屏/旋转/锁定、长cue/bitmap/外部字幕，不绕过最新包门槛。
2. 18解锁后核当前包空环境实际首页，再按同源串行播放补布局与冷续播。WDA已装有效fixture与Xcode自动隧道是两条链：本轮无线安装成功、普通启动Locked，不代表原生tunnel/DDI4016已修；保持Tailscale/Shadowrocket等现有网络。
3. 保留旧AV ordinal身份兼容、HLS完整候选deadline/分片/read/callback/容量、475差异与服务器耐久、119、真实弱蜂窝、S03/S08/S11/S18/S19及PiP等代表族。Lenna仍Pad/13主竞品，全CB/PX/UX/L2/L3/Main未验账目未关闭；缺完整显示采样和内容位移不得判滚动PASS。

未提交/推送；原始敏感证据只留本机。
