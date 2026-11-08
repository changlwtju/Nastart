# 2026-09-20 Mac 接续：退出生命周期与 Jellyfin 原始流

基线 `fd95f1d`（main）。本批为本地未提交修改；不要把旧 main 当作已包含修复。原有 Package.resolved 删除与 KSPlayer Demo/Documents 等辅助文件保留，未混入本批改动。原备份 stash `a463b9b3a88891f3656413b05157d9c120a68779` 保留。

## 已定位并修复的退出崩溃

9 月 15 日五份真机 ASan 报告具有同一调用链：`__asan_report_store4 → FFmpegAssetTrack.isEnabled.setter → Coordinator.resetPlayer → dismantleUIView`。嵌入字幕对象借用 AVStream，旧 reset 先释放 playerLayer，再禁用所选字幕，可能写入已经释放的流。

最小修复位于 KSVideoPlayer.swift：先将 `selectedSubtitleInfo` 设为 nil，由 didSet 禁用旧轨，再释放 playerLayer；重复 reset 不再访问旧字幕。新增确定性测试验证禁用时 owner 仍在、选择清空、第二次 reset 不再禁用。修复前该测试出现 3 个断言失败，修复后通过。此证据不等于证明 9 月 13 日 JSONDecoder SIGBUS 也属于同一根因。

9 月 19 日修复版 ASan 真机 S03（碟中谍3 TrueHD/内封字幕）记录 8 个 playback_ended，覆盖带字幕退出、快速重开、暂停后前进 15 秒并退出续播、切换国语和连续三轮退出。日志中进程为 45553，未捕获 ASan 报错；保存了画面及 XML。观察到 48:58 断点重开。不把时钟、轨道标签或单张画面当作实际声音和长时字幕同步验收。9 月 20 日首次拉取的系统报告没有新增 Nastart 报告。

## Jellyfin 默认原始流

只改变 Greenfield 默认路由策略，不重写播放器核心：

- 默认无 forcedServerBitrate 时，原始流不再受蜂窝/未知网络预算或大文件门槛限制；启动不等待测速。
- 继续认证并探测原始 Range URL，进入现有 KSPlayer 原始流路径；探测失败仍可回退。
- 音频解码能力、必须服务端渲染的字幕限制仍有效；缺少可用原始地址时保留服务端协商。
- 显式码率请求、qualityRequestLoader、sourceTrackRequestLoader 和 adaptiveFallbackRequest 保留，清晰度 UI 仍隐藏；显式切回原画失败保持原播放，不悄悄改成转码。
- 旧播放路径仍保留自适应预算。新诊断 `defaultMode=originalFirst`，原流探测不再谎报与测速重叠。

这解决了原先 12 Mbps 蜂窝预算/大文件策略主动将可解码原画送入 HLS 的差异；鉴权、服务器 Range 响应、元数据与进度上报仍不同，不能承诺两个入口耗时完全一致。

## 本次验证与签名

- 最终正常设备构建成功；模拟器 XCTest **96/96** 通过（包括此前 16 项 NAS 测试和本轮回归测试）。
- preflight、23 项 scripts Python 测试、4 项 agent Python 测试、diff whitespace 检查通过。
- 正常包 codesign 及 FFmpeg 隔离链接检查通过，已覆盖安装并显式启动到 iPhone 13，PID 50029；没有卸载或清除用户数据。
- Nastart 和 WDA 已于 9 月 19 日重新签名，有效期至 **2026-09-26 21:26:18 北京时间**；WDA 持久恢复 fixture 也已更新。
- 9 月 20 日 06:03 WDA 已恢复。超时位于 `_requestChannelWithCode:identifier:`，即设备端 testmanagerd 通道握手；覆盖安装和重启 runner 无效。仅结束已确认的 testmanagerd PID 49912 后，系统新建 PID 50122，WDA 在约 5 秒内 ready。未重启 iPhone，未清除 Nastart 数据。服务会话卡住的具体内部原因尚未证明，不归因于签名。
- 恢复验证：创建新会话、激活 Nastart、读取 28 KB 页面树、点击“设备”并断言选中、点击“启动台”并断言选中均通过。当前 WDA PID 50124，激活后的 Nastart PID 50132。新策略的真机双入口播放回归及性能比较仍未完成。

## WDA 同类超时的恢复步骤

仅在签名有效、设备已解锁、普通设备服务可用，但 XCTest 握手重复超时时使用。先结束本次挂起的 WDA 启动命令，确保没有其他正在执行的 XCTest；重启 testmanagerd 会中断设备上的测试会话。

1. 执行 `tidevice -u <实际 UDID> ps -A --json`，确认 **当前**名称严格为 `testmanagerd` 的 PID；不要重用本文历史 PID。
2. 执行 `tidevice -u <实际 UDID> kill <刚确认的 testmanagerd PID>`，只重启该测试服务，不结束其他系统进程。
3. 执行 `zsh scripts/start_wda_iphone.sh`，保留该进程运行。以 `http://127.0.0.1:8102/status` 的 ready 为第一道门槛。
4. 再创建 WDA 会话，激活 Nastart，读取 source 并实际点击页面入口；端口 ready 不能单独算作 UI 自动化恢复。

本次无需重新构建/签名 WDA，也无需重启整台手机。不将系统服务重启加入每次启动的自动动作。

## 下一步

1. WDA 已恢复，在当前正常包验证设备文件与 Jellyfin 同一 S03 的退出、快速重开、暂停定位、音字幕切换；检查 Jellyfin 日志为 originalFirst、KSPlayer、directPlay，不把安装成功算成播放成功。
2. 补 S01/S19 和 30 秒观察，继续拉取系统报告；保留未验证的旧 SIGBUS、双设备、第二账号等边界。
3. 正确性稳定后再按 2026-09-14-NAS-PAIRED-COMPARISON.md 收集至少三组独立配对。正常包、同片版本/音轨/字幕/起点/网络/冷热必须相同；ASan 数据不参与速度比较。当前没有新的性能比率结论。
4. 所有 PX/UX 状态保持，不能因本轮测试通过而整体验收。后续提交仅选择本批源码、测试、检查规则与文档，审阅 staged diff，不包含原始日志、签名或本地既有改动。

## 本地证据

`tmp/playback-20260915/`：崩溃报告、reset-before.log、reset-after-tests.log、原 ASan 包。

`tmp/playback-20260919/`：续签记录、ASan 真机 live.log、stress-0/1/2 XML、字幕/音轨/暂停定位截图与 XML。

`tmp/playback-20260920/`：tests-final.log、test-summary.json、build-final.log、build-manifest.json、preflight.log、python-tests.log、agent-tests.log、linkage.log、install.log、launch.log、WDA 恢复日志和正常 app。这些含私有设备/服务信息或签名材料的证据留在本地，不推 GitHub。

`tmp/wda-recovery-20260920/`：恢复前后进程、测试服务重启及 WDA 启动日志、会话、页面树与 verification.json；留在本地。
