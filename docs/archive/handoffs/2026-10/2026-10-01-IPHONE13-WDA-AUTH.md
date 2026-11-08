# 2026-10-01 iPhone 13 XCTest 授权阻塞定位

执行时间：15:21～15:28，Asia/Shanghai。读取 PROGRESS、当前交接和播放 runbook 后接续；用户明确暂缓 iPad，未处理其他设备。未修改 PROGRESS.md 或 App 源码，保留全部既有修改。

## 现场与包核对

- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，工作区仍有既有未提交修改。
- 现场 usbmux 只枚举 `REDACTED-DEVICE-01`；名称 iPhone，型号 iPhone14,5（iPhone 13），iOS 16.3.1；配对 validate 成功，收尾 USB/配对仍成功。
- 当前源码/配置最新文件仍为 AppTabRootView.swift，07:32:05；包产物 07:32:39，正常 Debug 配置沿用已记录构建，无新增 App 源码故而没有重建。
- 包路径：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`。本轮 codesign 深度严格验证通过；主 executable SHA-256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`，dylib SHA-256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。安装 IPA 中两文件哈希逐一相同。
- 原 Preferences 拉取失败（socket connection broken，工具虽打印 pulled 但目标实际不存在），不能记作诊断备份成功；原 15:12 私有证据保留，本轮保存了 syslog/截图/崩溃报告。没有卸载或清除登录数据。
- 本轮 tidevice 保留数据覆盖安装卡在 copying，未取得完成回执，采集现场后主动终止；ios-deploy 回退无输出、无有效安装证据，不能按 exit 0 判安装完成。故仅核对了本地包身份，本轮设备安装身份仍待完成。前轮 15:12 的安装成功属于历史证据。
- 收尾无测试变量/无参数启动返回 PID 67484，真实原生截图为 Nastart 启动台、NAS/Jellyfin 在线；设备进程枚举未读到该 PID，不能声称进程持续存在。本轮拉取报告中未见下午新增 Nastart 崩溃（最新文件 07:34:20），不据进程枚举缺项推断崩溃。

## WDA 定位

- 复用已安装固定 Bundle ID WDA，无重建/重装/换 ID。preflight 签名与 profile 到期核对通过。
- tidevice XCTest 拉起 Runner PID 67461，报告 Test runner ready detected / Start execute test plan；随后设备进程枚举明确读到 Runner。iproxy 已建立，但设备 8100 拒绝连接，console/process 文件为空。
- **15:24 原生截图明确显示“为 XCTest 输入 iPhone 密码 / Enable UI Automation”。本轮 UI 自动化正在等待设备本机授权。** 配对成功、普通解锁和 Runner 存活不能证明该授权完成；这解释了本轮测试计划启动后 HTTP 未监听的阻塞现象，未证明其他历史故障全部同因。
- 已请求用户在手机上输入密码完成授权，不要求用户在聊天发送密码；收尾尚无授权完成回复。启动脚本最终超时并退出，不能记 WDA ready。收尾停止本轮 syslog，失效转发随启动脚本退出清理；下次授权后需重新启动 XCTest。
- 标准 xcodebuild test-without-building 另有 `.xctestrun` 路径问题：TestHostPath 指向不存在的 `__TESTROOT__/Debug-iphoneos/...`，报告 Missing test product / Logic Testing Unavailable；还出现默认 DerivedData 写权限失败。这些是独立工具问题，不归因于 WDA 安装或播放器。未修改持久 WDA 产物。
- 两套 Xcode xctrace 都返回 No devices available for the recording；本轮没有帧采样证据。

## 结果与下一步

未开始滚动、S01 播放或 Lenna 对照，没有本轮回归 PASS/性能改善结论。runbook 已增加授权提示检查与历史 xctestrun 路径核对，git diff --check 通过。

1. 用户在 iPhone 本机完成 Enable UI Automation 授权后，重新启动固定 XCTest/iproxy，验证 status ready、Bundle ID 及 session/source/screenshot。
2. 先补必要诊断与最新包保留数据安装完整回执、正常启动/进程证据，之后才进入本轮回归。
3. 修复或绕过 Instruments 枚举阻塞后，按逐滑位移+完整帧时间门槛完成页面滚动及 Lenna 同条件对照；iPad 继续暂缓。

原始证据只留 `/tmp/nastart-20261001-wda-resume/`，包含系统日志、截图、包核对/安装尝试/启动日志与崩溃报告，不上传。不要从这些文件复制个人应用、凭据或设备偏好到项目。
