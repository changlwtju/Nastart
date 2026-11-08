# 2026-09-14 单位黑群晖接续工作指南

最新交回 Mac：用户已明确要求将今天 NAS 六批修改直接提交并推送到 GitHub `main`。回 Mac 先保留当地未提交工作，再 fetch 并同步最新 `origin/main`，不再以工作分支作为唯一接续入口。下文各批“未提交/未推送”描述为当时历史检查点，以上述最新交接为准。Swift 编译、16 项新增 XCTest、真机及 ASan 验证仍未执行；23 项 Python 测试通过不替代这些验收。

本指南承接 9 月 13 日 Mac 上的修改，供今天在单位黑群晖/Linux 环境继续开发。仓库为 `changlwtju/Nastart`，交接代码将推送至 `main`。今天没有 Xcode、模拟器及 iPhone/iPad 调试条件，工作集中在源码排查、离线诊断、测试用例和小范围实现；新增 Swift 修改必须记录为“待 Mac 编译/真机验证”。

## 1. 先同步并读取上下文

已有仓库：进入实际 Nastart 目录，先检查工作区。下面的切换与拉取命令仅在工作区干净时执行；有未提交修改时先保留到本地工作分支提交，避免覆盖单位已有工作。

```sh
git status --short --branch
git remote -v
git fetch origin
git switch main
git pull --ff-only origin main
git log -3 --oneline
git switch -c work/nas-20260914
```

没有本地仓库时，在选定的开发目录执行 `git clone https://github.com/changlwtju/Nastart.git`，然后 `cd Nastart`。私有仓库使用已有 GitHub 登录/SSH 凭据；Mac 的远端是 `ssh://redacted@example.invalid:443/changlwtju/Nastart.git`，单位环境按可用认证方式配置。不要把令牌写进仓库 URL。若工作分支已经存在，使用 `git switch work/nas-20260914`。

依次阅读：

1. [唯一任务总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)：保留 PX-01～PX-21、UX-01～UX-04 全部编号与状态。
2. [9 月 13 日双入口、字幕和退出问题证据](2026-09-13-ENTRY-PARITY-AND-WEB.md)：最新事实与失败记录。
3. [S19《指环王1》专项](../../../testing/samples/2026-09-12-S19-LORD-OF-THE-RINGS.md)：样本与原画策略差异。
4. [ADR 0002](../../../adr/0002-single-playback-optimization-mainline.md)：Greenfield 是唯一优化主线，旧架构仅回退。
5. [NAS 开发流程](../../../development/nas-dev.md)与[播放调试手册](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)。

## 2. 当前交接状态

| 范围 | 已实现/已有证据 | 还不能认定完成的部分 |
| --- | --- | --- |
| Jellyfin 首播 | 自动路由，条件满足优先原画；详情提前探测，减少播放时串行准备 | 双入口同片同轨同断点重复冷/热对照尚缺；网络零速空档未归因完毕 |
| 清晰度 | 按用户决定收起 Greenfield 手动清晰度入口，保留自动路由与兼容回退 | 不恢复手动入口、不承诺服务端临时转码丝滑切换；PX-04 保留 |
| 音轨 | 释放旧音频节点，配置变化后按用户播放意图恢复引擎；九次交替后时钟推进 | 实际听音、长时间及切轨+暂停+seek 连续组合仍待验收 |
| 字幕 | PGS 最新显示组替换旧组；按字幕独立画布缩放；外置字幕取消/缓存 | 手动字号、位置、延迟、导入仍待做；HDR PiP 字幕问题仍在 |
| 设备文件续播 | 本地保存断点及音字幕；真机恢复 6311.8 秒及国语 DTS；从头保留 PGS | 深位置慢样本 5863 ms 保留；文件版本变化、双设备和复杂组合待补 |
| Jellyfin 退出位置 | tracker 接收退出位置；详情增加停止快照与“从头播放” | 最新详情快照需重开验证；另发现退出后 JSON 解码崩溃 |
| 服务网页 | 独立全屏导航，底部网页工具栏布局调整；Homepage 打开/切模式/关闭已跑通 | 各服务、iPad、网页版本/历史完整回归未完成 |

9 月 13 日正常构建已有 78 项 Swift 播放/非播放测试、设备构建、签名与播放库链接检查通过。9 月 14 日推送前又运行 preflight、3 项诊断报告测试、4 项 Agent 测试，均通过。这些结论只覆盖交接时的代码，不能继承为今天新增修改的编译结论。

真机曾安装 ASan 诊断包；最后显式终止重启后，压测尚未完成。`B055B116` 可能属于覆盖安装前的旧进程，不能作为 ASan 未发现问题的证据。回 Mac 后先核对实际安装包、进程和构建，再继续。

## 3. 今天优先推进的任务

### A. 先分析退出崩溃与停止事件生命周期

已确认两个系统报告：`Nastart-2026-09-13-124118.ips` 和 `Nastart-2026-09-13-204441.ips`。异常均为 `EXC_BAD_ACCESS / SIGBUS`，访问地址 `0x0000003000000000`。

- 12:41 的关键调用链：`swift_unknownObjectRetain` → 字典 Objective-C 桥接 → `__JSONDecoder.container` → `MediaStream.init(from:)`。
- 20:44 的关键调用链：`objc_release` → `__NSDictionaryI`/`__NSArrayI dealloc` → `__JSONDecoder.__deallocating_deinit` → `JSONDecoder.decode` → `closure #1 in decode(_:using:)`。
- 服务网页 12:06 的报告是 SwiftUI/AttributeGraph watchdog，属于另一问题。

从 `JellyfinLibraryStore.reportPlayback` 的 stopped → `loadResumeItems` 开始，梳理停止上报、刷新列表、详情加载、播放器资源销毁的任务先后与所有权。SDK 的 Get 客户端在 detached task 中解码，栈顶位置只是排查线索；不要未经证据断定 JSONDecoder 共享、系统缺陷或 KS 内存越界就是根因。

今天可交付：标明源码位置的生命周期图/时序、可复现的确定性逻辑缺陷修复、针对最后一次事件/取消/重复 stop 的 Swift 回归用例，以及 Mac 上需要开启的诊断与复现步骤。不要仅加延迟或吞掉错误便将崩溃标记已修复。不要直接修改 DerivedData 中的依赖 checkout；如确认依赖缺陷，先整理可重复补丁及纳入仓库的方案。

### B. 对齐断点与轨道状态（PX-21/PX-20/PX-02）

核对正常退出、暂停后定位退出、定位未完成退出、从头播放、快速重开、切字幕关闭与外置字幕、文件版本变化等路径。特别检查停止快照是否会被稍后返回的旧详情请求覆盖、晚到的进度事件是否会盖掉停止位置、正在换流时本地切轨是否绕过最后选择规则。上述为待核查方向，不是已证缺陷。

设备文件当前只保存已就绪且没有 pending seek 的有效断点；不要把进度条上的未完成目标当作已经播放到的位置。保持账号/文件版本隔离、128 条上限、无效时钟保护和 Jellyfin HLS 时间偏移语义。

### C. 整理首帧离线分析（PX-01）

诊断中 `firstFrameSignal=playbackClock` 表示播放时钟推进，不能当成摄像测得的屏幕首帧。按 `playbackTraceID` 汇总准备、请求首字节、Range、解复用、seek、解码/提交事件；只对同片同音轨同字幕同位置、同网络及同构建的样本计算中位数和慢样本。

S19 文件大小 128795641934 字节，时长约 13698.368 秒，源码率约 81.9 Mbps。Jellyfin 默认 TrueHD 1 / PGS 8；文件早期样本默认无字幕。Jellyfin 从头一次 1605 ms，文件对应一次 1224 ms，时间间隔较长，不能据此宣布稳定差距或优化比例。更多样本见 9 月 13 日手记。

可推进 `scripts/playback_trace_report.py` 的解析与合成 fixture 回归。`playback_policy_simulator.py`、`playback_compare_runs.py` 和旧离线文档仍包含 Auto/Force、PGS 转码等历史假设，尚未对齐最新 Greenfield；先核对 Swift 策略再修工具，不反过来按旧模拟器改生产策略，也不把 Auto/Force 比较当作设备文件/Jellyfin 比较。

批次 1 仍优先。PiP、字幕设置、选集、章节、片头片尾、在线字幕和投屏继续保留在总账；今天可细化实现设计，不因无真机而删项或改成已验收。

## 4. 代码入口

以下路径相对仓库根目录：

| 路径 | 关注点 |
| --- | --- |
| `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift` | JellyfinLibraryStore、详情快照、准备路由、外置字幕缓存 |
| `ios/Nastart/Nastart/Features/Launchpad/LaunchpadPlaybackCore.swift` | 请求模型、MediaPlaybackTracker 停止/进度 |
| `ios/Nastart/Nastart/Playback/GreenfieldPlaybackBridge.swift` | 本地断点身份、存储、恢复与 HLS 语义 |
| `ios/Nastart/Nastart/Playback/GreenfieldVideoPlayerView.swift` | 退出保存、换源任务、最后选择、暂停状态 |
| `ios/Nastart/Nastart/Playback/Engines/GreenfieldKSPlayerRenderer.swift` | pending seek、内嵌字幕补读、全屏/PiP 覆盖层 |
| `ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift` | 原画预算/兼容策略 |
| `ios/Nastart/Nastart/Features/Devices/DevicesView.swift` | 文件继续观看/从头入口及文件身份 |
| `ios/Nastart/Nastart/Features/Launchpad/LaunchpadServiceDetailViews.swift` | 服务网页呈现、返回和工具栏 |
| `ios/Nastart/Packages/KSPlayer/Sources/KSPlayer/MEPlayer/` | AudioEnginePlayer、CircularBuffer、EmbedDataSouce、SubtitleDecode |
| `ios/Nastart/NastartTests/PlaybackNextCoreTests.swift` | 播放策略、状态、队列及断点回归 |
| `ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift` | 服务识别、排序与非播放规则 |

## 5. NAS 上实际运行的检查

需要 Git、Bash、Python 3.10 或更高版本。先运行 `python3 --version`；DSM 自带 Python 较旧时使用现有合适的开发环境/容器，不以安装 Linux Swift 替代 Apple SDK。下面命令均从仓库根目录运行，无须连接真实 NAS 服务或挂载 Docker socket。

```sh
bash scripts/preflight.sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 -m unittest discover -s agent -p 'test_*.py' -v
git diff --check
git diff --cached --check
```

preflight 校验静态结构、本地化、工程配置及部分规则；不执行 Swift 编译和 XCTest。若工具缺失，记录缺失条件与未执行项，不能记为通过。新增 Swift 测试今天可编写审查，但执行留到 Mac。

只有拿到脱敏且与解析器格式匹配的导出日志后，才执行（路径需替换为实际文件）：

```sh
python3 scripts/playback_trace_report.py --json tmp/playback-input.txt > tmp/playback-report.json
```

Mac 的 `tmp/playback-20260913/`、系统报告、截图、签名材料、应用包和 DerivedData 都不在 GitHub 中。单位克隆后看不到它们是正常情况，不能假定绝对 Mac 路径在 NAS 存在。本指南已保留关键栈和观测；需要更多原始数据时先列出最小所需片段，回 Mac 提取脱敏 fixture。不要上传 SID、Jellyfin token、完整认证 URL 或原始设备日志。

## 6. 下班前交回 Mac

在本指南后追加实际工作记录，并同步总账对应编号：改了什么、依据、执行了哪些检查、哪些未运行、Mac 需要怎样复现。提交前用 `git diff --stat` 和 `git diff --cached` 核对明确文件。今天的未编译 Swift 修改优先推送工作分支，待 Mac 验证后合并；本次 Mac 最新基线按用户要求直接推 main。

```sh
git status --short --branch
git diff --check
git diff --cached --check
# git add 后填写明确的源码、测试与文档路径，再提交
git commit -m "Continue playback lifecycle analysis on NAS"
git push -u origin work/nas-20260914
```

回 Mac 后：拉取该分支，运行正常 Debug 构建与播放/非播放 XCTest；先确认退出崩溃的诊断包确实运行并完成复现，再安装正常包。对 S19 重复两入口从头/深位置续播、切音轨/字幕、暂停/定位/退出组合，核对实际声音和屏幕；补齐服务网页返回、iPhone/iPad 与长时间回归。ASan 数据不用于速度比较，手机当前安装状态需重新确认。

## 7. 可直接发给单位开发助手的接续提示

> 当前在单位黑群晖/Linux 上继续 Nastart，没有 Xcode、模拟器和真机调试能力。先读取 `docs/archive/handoffs/2026-09/2026-09-14-NAS-DAYTIME-CONTINUATION.md`、唯一任务总账及 9 月 13 日手记，基于 GitHub 最新 main 建工作分支。优先分析退出后的 JSON 解码崩溃与停止/详情/换轨的生命周期，其次核对双入口断点和修正离线诊断工具。Greenfield 是唯一优化主线，手动清晰度继续收起，所有 PX/UX 未完成项保留。可以实现有依据的小范围修复和回归用例；执行 NAS 可用检查，清楚记录不能运行的 Swift 编译、XCTest 和真机验收。不要凭栈顶函数认定崩溃根因，不要用时钟代替屏幕/听音，不要声称已经对齐 DS One。结束时更新本文和总账，给出回 Mac 的具体验证步骤。

## 8. NAS 实际接续：首批生命周期修正

- 用户补充：手动清晰度仅隐藏 App 入口，相关代码和接口全部保留，后期有必要再展示。已同步 PX-04 并在 Greenfield 源码注明；选项模型、`qualityRequestLoader`、换流准备与自动回退均保留。
- 从 `b4c789a` 建立本地 `work/nas-20260914`。本批修改位于本地工作区，尚未提交或推送；main 保留同步基线。
- 已修改 tracker 在首播前取消/释放后的终止状态，避免迟到 start/progress；分离详情页本次停止位置与异步元数据，避免迟到详情或加载失败覆盖断点；增加取消检查和无效时钟/整数转换边界保护。
- 新增 4 项 Swift XCTest，待 Mac 执行。原 JSON 解码崩溃未确认根因，不标已修复；未修改解码 SDK 或 KS 内存管理，未改变设备文件 pending seek 保存保护与 HLS 时间语义。
- 本批修改后实际检查：Python 3.12.13；`bash scripts/preflight.sh` 全部通过；诊断脚本 3 项 unittest、Agent 4 项 unittest 全部通过；`git diff --check` 与 `git diff --cached --check` 通过。环境没有 `swift`/`xcodebuild`，Swift 编译、4 项新增 XCTest 和真机验证未执行。
- 时序、具体代码位置、剩余竞态和回 Mac 复现步骤：[NAS 首批退出生命周期分析](2026-09-14-NAS-PLAYBACK-LIFECYCLE.md)。后续优先补上报顺序/账号隔离证据，再推进首帧离线工具；不跳过总账未完成项。

## 9. 开发方式调整：按逻辑与覆盖范围推进

用户要求综合原下一阶段目标与测试矩阵优化开发方式。现行执行方式见 [分层开发与回归流程](../../../development/playback-development-workflow.md)：共用逻辑优先，L0/L1/L2 用于日常修复与批次，L3 保留 19×4 完整验收。S19 继续作为压力样本，日常跨格式代表集复用 S01/S03/S08/S11/S18，具体范围按修改影响确定。原 25 个 PX/UX 状态及所有正式矩阵结果未改动。

下一步以停止事件顺序、旧会话/账号隔离和有效断点为有限交付范围，先写反例、证据和变更卡；原 JSON 解码崩溃仍待 Mac 捕获。Mac 完成构建/回归后建立正常包代表集基线，先固定性能口径及预算再优化。新增文档不是新增验收证据；本节优先于前文“持续优先 S19”的执行含义。

## 10. NAS 第二批：认证会话与继续观看响应隔离

已完成本地源码修改：旧 tracker 绑定准备时 client/认证会话，替换账号后拒绝旧上报任务；stopped 返回后复核会话；继续观看加载按最新请求校验并在同一次 MainActor 执行中发布；首页和详情补旧会话写回保护。详见 [第二批变更卡与 Mac 清单](2026-09-14-NAS-SESSION-ISOLATION.md)。

实际检查：preflight、诊断脚本 3 项 unittest、Agent 4 项 unittest、`git diff --check` 全部通过。本批新增 4 项 XCTest，两批累计新增 8 项，均未在 NAS 编译/执行。当前仍为 `work/nas-20260914` 本地未提交修改，无 GitHub 推送；质量入口隐藏且代码保留。下一步针对同一播放会话 start/progress/stop 的有界串行队列与失败/取消规则取证和设计，原 SIGBUS 仍需回 Mac 捕获。

## 11. NAS 第三批：单 tracker 有界上报队列

已修改 tracker 的锁内事件登记/锁外交付，并接入单 worker 网络队列；未发送 progress 只保留最新值，stop 替换未发送进度，重复 stop 无效；本地停止快照单独更新，不等待网络。详情见 [第三批变更卡](2026-09-14-NAS-REPORT-ORDERING.md)。本批新增 4 项 XCTest，累计新增 12 项未执行。

修改后 preflight、诊断脚本 3 项 unittest、Agent 4 项 unittest、`git diff --check` 通过。Swift 编译/新增 XCTest/真机仍未执行；本地分支未提交、未推送。跨 tracker 会话顺序和真实 SDK timeout 是下一步证据缺口；原 JSON 解码崩溃未认定修复，清晰度接口继续保留。

## 12. NAS 第四批与 Mac 检查点

已增加活动播放 ticket：仅实际 started 才获得本地更新资格，旧停止快照与刷新不能在新 tracker 开始后继续回填，预热候选不抢占，账号切换使旧 ticket 失效。详见 [第四批变更卡](2026-09-14-NAS-ACTIVE-PLAYBACK.md)。本批新增 4 项，累计 16 项 Swift XCTest 均未编译/执行。

本批 preflight、诊断 3 项及 Agent 4 项 unittest、git diff --check 通过。源码已有 request/resource 20/60 秒配置，实际 SDK 超时行为待 Mac 核对。修改仍未提交/推送；所有 PX/UX 状态和矩阵保留。下一步先执行 Mac 构建、16 项新增测试及受控乱序响应验证，再决定跨 tracker 服务端协调；NAS 侧可继续日志/离线诊断，不继续扩大未经编译的核心改动。

## 13. NAS 第五批：离线报告归属修正

仅修改报告工具/测试及文档，按 trace/plan 归组，禁止借用其他会话的准备或测速数据；无法归属事件输出行号，旧日志标注兼容模式。新增 9 项 Python 测试，全部 12 项、preflight、git diff --check 通过，详见 [第五批变更卡](2026-09-14-NAS-TRACE-ASSOCIATION.md)。Swift 未继续修改，原 16 项仍待 Mac 验证；本地未提交/推送。拿到真实脱敏日志后先核对未归属事件与同条件字段，再进行性能比较。

## 14. NAS 第六批：双入口配对校验与比较

新增 playback_compare_entries.py 和 [三组模板/操作说明](2026-09-14-NAS-PAIRED-COMPARISON.md)，仅在同条件、正常构建、至少三组独立完整配对时输出播放时钟中位数、范围和配对差值；失败或不匹配时保留原因且不汇总。新增 11 项 Python 测试，全部 23 项、preflight、git diff --check 通过。未修改 Swift，原 16 项仍需 Mac；本地未提交/推送。需要真实脱敏报告及经核实的条件清单才能形成实际比较结果。

## 15. Mac 接续检查点

已从实际推送的 `origin/main` / `4ccb161` 建立本地 `work/nas-20260914`，Mac 原有修改保存在命名 stash。正常 Debug 设备构建、94 项 Swift 测试（包括 NAS 新增 16 项，0 失败/跳过）、preflight、23 项诊断及 4 项 Agent Python 测试均通过。最新 ASan 包构建、签名、链接、覆盖安装及显式重启已完成；通话结束后已恢复测试，S01 Jellyfin 从头播放出现电影画面、时钟推进并暂停于 00:26；退出/重开/切轨/暂停定位压测仍待完成。当前未覆盖回正常包，未进行性能对照，原 SIGBUS 未定位或验收。详见 [Mac 验证记录](2026-09-14-MAC-VALIDATION.md)。

9 月 15 日最新接续入口：[NAS 今日开发指南](2026-09-15-NAS-CONTINUATION.md)。以该文件及 Mac 最终验证记录为准，前文各批未编译/未执行的描述保留为历史检查点。
