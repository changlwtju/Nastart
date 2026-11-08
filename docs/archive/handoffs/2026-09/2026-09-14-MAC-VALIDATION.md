# 2026-09-14 Mac 接续验证

关联 PX-21/PX-20/PX-02/PX-01，均继续进行中。当前为验证检查点，未完成真机正确性验收，没有性能比较结论。

## 基线与本地修改

- GitHub 没有 `work/nas-20260914`：`git fetch origin work/nas-20260914` 返回 remote ref 不存在，随后核对远端 heads。
- NAS 六批已提交至 `origin/main` 的 `4ccb161`（Guard playback lifecycle and add matched-entry diagnostics）。最新接续指南首段明确这一交接变更；从该提交建立本地 `work/nas-20260914`。
- Mac 原有 Package.resolved 删除和 KSPlayer 未跟踪辅助文件已完整保存在 stash `a463b9b3a88891f3656413b05157d9c120a68779`，名称 `codex-preserve-mac-before-nas-20260914`。未 pop/drop；9 月 15 日已恢复 stash 中的 KSPlayer 未跟踪辅助文件到 Mac，原备份与其他历史 stash 均保留。这些上游 Demo/Documents/配置不属于本轮 Nastart 实现，未新增进仓库。
- 工作区仍出现原 Package.resolved 删除，构建期间未人为更新依赖版本。本次尚未修改生产 Swift、KSPlayer 或 DerivedData 依赖源码，没有继续扩大核心修改。

## 已完成 L0

使用已有 `/Users/lagransun/Downloads/Xcode.app`，Xcode 26.6 / 17F113。系统默认 developer directory 仍为 CommandLineTools，构建通过仓库脚本选择完整 Xcode，未修改系统默认设置。

| 检查 | 本轮实际结果 |
| --- | --- |
| 正常 Debug iOS 设备构建 | BUILD SUCCEEDED |
| 播放与非播放 XCTest | 94 项通过，0 失败，0 跳过；iPhone 17 Pro / iOS 26.5 模拟器 |
| NAS 新增 16 项 XCTest | 已逐项匹配通过记录，包含取消/重复 stop、无效时钟、重入、有界队列失败推进、账号/响应/活动播放身份 |
| preflight | 通过 |
| 诊断脚本 Python unittest | 23 项通过 |
| Agent Python unittest | 4 项通过 |
| 正常包播放库链接与独立签名 | 通过，包括 app、Framework 和 dylib |
| ASan 设备构建、独立签名及播放库链接 | 通过 |

编译无新增 MainActor/Sendable 错误；日志保留已有未使用 plan、旧 AVFoundation 同步 API 弃用及 AppIntents 元数据提示，不把构建通过写成无警告。

证据均在本地 `tmp/playback-20260914-mac/`：`normal-tests.log`、`normal-tests.xcresult`、`test-summary.json`、`new-tests-evidence.json`、`normal-device.log`、`asan-device.log`、`preflight.log`、`python-scripts.log`、`python-agent.log`、`build-manifest.json`。清单包含精确 commit、测试统计及两个 app 的 debug dylib UUID/SHA-256。

## 真机检查点

- iPhone 13 / iOS 16.3.1，USB 枚举、配对有效；复用既有 WDA，未重装 WDA、未更改设备系统。
- 最新 ASan 包覆盖安装成功，保留应用数据。`Nastart.debug.dylib` UUID 为 `D561604D-B419-3758-B539-5684F5F557F3`，链接 `libclang_rt.asan_ios_dynamic.dylib`。
- 安装后通过 tidevice 显式重新启动，启动输出及 WDA UI tree 对应 PID `55801`。已进入启动台、Jellyfin 资源库、S01 哈尔搜索与详情；完整退出压测尚未执行。安装与启动证据为 `install-asan.log`、`asan-launch.log`、`asan-launched.xml`，本次采集 `asan-relay.log`。
- 约 20:12 iPhone 被用户视频通话占用，曾暂停真机点击。用户确认设备可用后已继续；恢复时进程为 PID `55886`，重新进入 S01 详情。拉取当日系统报告没有新的 Nastart 报告；进程变化原因未确认，不据此宣称无崩溃。
- S01 Jellyfin 新架构从头播放已出现实际电影片头，日志标识 `engine=KSPlayer`、`playMethod=directPlay`、`routeKind=localRangeProxy`，trace `4EC4C7F6`、plan `1CCAF55C`；控件时钟到 `00:15`，随后暂停在 `00:26`，按钮变为“播放”。证据 `s01-playing.png`、`s01-controls.xml`、`s01-paused.xml`、`asan-relay-resumed.log`。没有执行暂停后的 seek、退出、快速重开、切轨与设备文件对照；未完成 30 秒连续播放/听音验收。
- 进入详情时曾有自动化响应等待与 HangTracer 短卡顿记录，之后可继续播放；该观察保留为待归因，不据此修改参数。9 月 15 日用户要求转 NAS 并推送交接，停止继续真机操作。
- 正常包已构建并签名，尚未覆盖回正常包。ASan 包、模拟器和旧包数据都不纳入速度对照。

## 退出崩溃排查事实

重新读取 9 月 13 日两份原始报告；两者仍为 `EXC_BAD_ACCESS / SIGBUS`，地址 `0x0000003000000000`。12:41 栈包含 `swift_unknownObjectRetain` → Objective-C 字典桥接 → `__JSONDecoder.container` → `MediaStream.init(from:)`；20:44 为 `objc_release` → 容器析构 → `__JSONDecoder` 析构 → `JSONDecoder.decode` → Get 解码任务。已提取无认证参数的线程、image UUID/offset 和符号到本地 `prior-crash-symbols.json`，未提交原始日志。

本机实际依赖源码核实：JellyfinClient.swift 初始化时配置 JSONDecoder；Get 的 APIClient.swift 在 send 取用该 decoder，DataLoader.swift:357 的 decode 在 detached task 执行解码。因此存在多个请求解码重叠的调用路径，但这不是解码器不安全或 SIGBUS 根因的证据；同 tracker 有界上报也不串行化其他详情/resume 解码。没有据此修改 SDK、替换解码器、加入延迟或宣布崩溃修复。

本次启动后暂未采集到 ASan 错误，但原触发操作未完成，不能记为 ASan 阴性压力证据；设备实际加载 image 的运行时核对及异常捕获仍需继续。

## 继续顺序与未完成项

1. 设备可用后保持本次诊断上下文：S01/S03 两入口开始、退出续播、快速重开、从头、暂停后完成 seek/未完成 seek 退出，再做 S19 深位置、音轨/字幕切换组合。记录实际屏幕、声音、字幕和已确认位置，不能用菜单或时钟替代听音/显示验收。
2. 继续原退出崩溃复现；如发生异常，立即保留 ASan/系统报告、异常线程和相邻 trace/session、资源释放与上报顺序。受控旧详情/stopped/resume 响应集成验证、真实 SDK 失败/超时和跨 tracker 服务端顺序尚待验；现有 scope/queue XCTest 不是这些集成验收。
3. 正确性稳定后覆盖回本次正常包，核对新进程。按 `2026-09-14-NAS-PAIRED-COMPARISON.md` 采集至少三组独立同片版本/轨道/字幕/请求起点/设备/网络/构建/冷热配对；先检查 strict trace 和 unassignedEvents，再运行比较工具。播放时钟指标与屏幕首帧分列，保留失败和慢样本。
4. iPad/双设备、实际第二账号与其他格式族仍按分层流程保留待验；不改变既有 76 个正式矩阵单元，不删除任何 PX/UX 事项。
