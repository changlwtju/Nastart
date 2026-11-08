# 2026-10-01 iPhone 13 显示采样门槛与工具续查

执行时间：16:01～16:10，Asia/Shanghai。先读 PROGRESS、当前交接、播放 runbook、竞品矩阵；只继续 iPhone 13，iPad 暂缓。按协作约定未写 PROGRESS.md，所有既有未提交修改保留。

## 设备与安装身份

- 开始/收尾 usbmux 均只见 iPhone 13，UDID `REDACTED-DEVICE-01`；名称 iPhone、型号 iPhone14,5、系统 16.3.1，现场配对 validate 成功。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`；既有源码修改保留，本轮未改 App 源码。源码/配置最新时间 AppTabRootView.swift 07:32:05，二进制 07:32:39，无需重复构建。
- 正常 Debug 包 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`，codesign deep/strict 验证通过；主 executable SHA-256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`，dylib SHA-256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。安装 IPA 两文件哈希均相同。
- 无法本轮可靠验证已安装二进制身份，尝试保留数据覆盖安装。tidevice 首次传输最终 DONE，但 installation service 没有完整回执，停止后保留 KeyboardInterrupt 原始栈；重试再次停在传输，停止。ios-deploy 尝试返回 0 但日志空，不能以此认定安装成功。没有卸载或清数据，历史私有诊断保留。本轮最新包安装门槛未完成，不宣称最新包回归。
- 无变量/参数启动曾返回 PID 67761，随后 WDA session/source/screenshot 显示真实启动台。收尾再次 DVT 启动报 NSError code 4 / 找不到 PID，立即下载崩溃报告；未见下午新增 Nastart 报告（最新仍 07:34:20），原因未定。WDA 常规激活后真实 source/screenshot 成功，设备进程确认 Nastart PID 67785。不能把失败启动归为确定的 App 崩溃，也不能以启动可用代替安装身份。

## 工具恢复与采样失败

- 固定 WDA 未重装，继续使用私有 tidevice wrapper 和可写缓存。启动命令 `TIDEVICE_BIN=/tmp/nastart-20261001-wda-resume/tidevice WDA_RUNTIME_DIR=/tmp/nastart-20261001-frames/wda scripts/start_wda_iphone.sh`。
- `/status ready=true`，固定身份 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`；Runner PID 67739，本机 8102→8100，session/source/screenshot 可用。收尾保留服务；下一轮重新核实。
- `/Applications/Xcode.app` 与 `~/Downloads/Xcode.app` 的 xctrace 均返回 No devices available；`~/Downloads/Xcode16.3` 不含有效 Developer 路径，不能作为可用旧 Xcode。两套工具导出历史 trace 都报 Missing features / Unexpected internal error。未升级系统、切全局 Xcode 或重装 WDA。
- 启动台仅作采集工具可用性尝试：xctrace 在录制开始前报 No devices found matching UDID，0 次手势，run/record/summary 已保存 INSUFFICIENT。此尝试不是完成安装门槛后的最新包基线，不能作为 App 回归结果。未播放任何视频、未操作 Lenna。

## 自动判定加固

`scripts/ui_scroll_probe.py` 之前只检查 trace 总时长及 hitch 表，空 hitch 表缺少完整显示采样证据。现增加 display-vsyncs-interval 导出，要求每次拖动中至少 30 个显示计时样本/秒，首尾及相邻间隙 ≤50 ms；缺失/稀疏/断档不能 PASS。针对 60Hz 设备保守执行，此计时属于合成显示，不代表 App 实际渲染 FPS；不满足时不能仅凭间隙区别真实卡滞与掉采样。

导出、录制及解析异常现在保存 INSUFFICIENT、原因和已有页面/构建/设备信息，并覆盖旧 summary PASS。竞品矩阵同步说明该完整性门槛，未改 hitch 工程阈值。新 schema 的正常真机导出尚未在本轮工具条件下验证，缺 schema 或列会保守失败，不宣称采样已经恢复。

验证：11 项工具测试通过，覆盖空/低频/中途断档/末次拖动缺失；真实缺 trace 导出故障验证退出非零、旧 PASS 被 INSUFFICIENT 覆盖且元数据保留；git diff --check 通过。无新的 App 性能改善、滚动 PASS 或竞品排名。

## 下一步

1. 先解决 installation/AFC 传输及完整回执，保留数据核对最新正常包后才开始回归。
2. 恢复 Instruments 枚举与正常显示 timing 导出，核对真实 schema 和时间单位，再做每页 ≥12 次有效滑动的正式验收。不得用秒级 FPS 均值替代完整帧时间。
3. 采集恢复后对齐 Lenna S01 服务/文件/路径/轨道/缓存，采用相同屏幕计时与至少 5 组交替配对；Debug 与 App Store 差异仍需说明。

原始诊断/安装日志/截图/进程/崩溃报告仅留权限 700 的 `/tmp/nastart-20261001-frames/`，不上传。未改系统网络、VPN 或 NAS；视频未启动，无测试注入环境。
