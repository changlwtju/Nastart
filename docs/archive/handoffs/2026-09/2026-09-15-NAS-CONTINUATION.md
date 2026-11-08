# 2026-09-15 黑群晖接续开发指南

用户要求：将 Mac 本地 Nastart 项目当前成果推送 GitHub `changlwtju/Nastart` 的 `main`，供今天黑群晖接续。今天从最新 `origin/main` 开始；不要再寻找远端 `work/nas-20260914`。该远端分支不存在，9 月 14 日 NAS 六批源码已在 `4ccb161` 合入 main，Mac 在其上完成验证。本次交接只新增/更新文档，没有新增核心源码修改。

## 1. 安全同步与阅读顺序

先执行 `git status --short --branch`，保存 NAS 已有修改（本地工作分支明确提交，或包含未跟踪文件的命名 stash，并记录恢复方式）。工作区可安全切换后执行：

```sh
git fetch origin
git switch main
git pull --ff-only origin main
git log -3 --oneline
git switch -c work/nas-20260915
```

已有同名分支时先核对其提交与修改，再 `git switch work/nas-20260915`；不要强制覆盖或 reset。若 main 无法 fast-forward，先检查分叉并保留本地提交。

依次阅读：

1. [唯一任务总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)：全部 PX-01～PX-21、UX-01～UX-04 保留。
2. [Mac 实际验证记录](2026-09-14-MAC-VALIDATION.md)：本次最新构建/测试/真机事实。
3. [9 月 14 日 NAS 六批交接](2026-09-14-NAS-DAYTIME-CONTINUATION.md)：重点第 8～15 节及各批变更卡。
4. [分层开发流程](../../../development/playback-development-workflow.md)、[ADR 0002](../../../adr/0002-single-playback-optimization-mainline.md)、[播放调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)。
5. [同条件双入口比较](2026-09-14-NAS-PAIRED-COMPARISON.md)：正确性门槛完成后再使用。

## 2. 能继承的事实与不能继承的结论

| 范围 | 9 月 14 日 Mac 实际结果 | 仍未完成 |
| --- | --- | --- |
| 正常构建 | Xcode 26.6 / 17F113，Debug iOS 设备构建通过，签名/播放库链接通过 | NAS 后续新增 Swift 仍需重新 Mac 编译 |
| Swift XCTest | 94 项全部通过，0 失败/跳过；新增 16 项逐项通过 | 不能把 scope/queue 单测等同于 SDK/SwiftUI 真机集成验收 |
| 离线检查 | preflight、23 项诊断脚本 + 4 项 Agent Python 测试通过 | 每批修改需重跑相关检查 |
| ASan | 最新包已构建、签名、安装并显式重启；运行库链接已核实 | 完整退出压测、运行时 image 核对、原 SIGBUS 根因未完成 |
| S01 Jellyfin | 新架构从头出现电影片头，时钟推进到 00:15，再暂停于 00:26 | 暂停定位、退出续播、快速重开、切轨、设备文件与声音/字幕验收均未完成 |
| 性能 | 未开展本轮双入口速度比较 | 没有同条件正常包三组配对结论，不使用 ASan 数据比较 |

通话曾打断测试，恢复时 PID 从 55801 变为 55886；随后拉取的当日报告未见新的 Nastart 报告，进程变化原因未判定。短暂详情卡顿和 WDA 等待单列，不能直接认定为原 SIGBUS，也不能把无新报告写成崩溃已解决。手机交接时仍安装 ASan 包，尚未恢复正常包。

## 3. 今天优先做什么

当前优先级是正确性与退出崩溃，保持有限范围，不继续扩大核心并发改造、传输窗口、缓存或解码参数。

### A. 补充可在 NAS 审查的受控反例和诊断证据

以已有四批生命周期修改为基础：

- 验证设计须覆盖 start/progress/stop 单 tracker 无重叠、进度合并、失败/超时返回后最终 stop、重复 stop 和资源释放一次。
- 明确区分同 tracker 顺序、本地活动 ticket 资格、跨 tracker 服务端写入顺序；前两者已有单测，后者没有全局保证。
- 旧详情、stopped、resume 请求晚返回时，按认证 epoch、最新请求 ID 和活动 ticket 检查写回；不要用 sleep 或吞错规避。
- 详情停止快照与异步元数据合并、账号切换、预热候选不抢占等路径需要实际集成证据。现有 16 项 XCTest 通过的是规则，不代表全部 UI/SDK 路径通过。
- 有源码证据和确定性反例时才做最小修复；没有证据就整理 fixture/受控响应测试或观测方案，不扩展生产核心。

入口仍为 `LaunchpadPlaybackCore.swift` 的 tracker/buffer/report queue/scopes，`LaunchpadView.swift` 的 makePlaybackTracker/reportPlayback/refreshResumeItems/详情快照，以及 Greenfield 播放页退出与 renderer pending seek。

### B. 崩溃的事实边界

原 9 月 13 日两份报告均为 `EXC_BAD_ACCESS / SIGBUS`，地址 `0x0000003000000000`：一次在字典桥接/MediaStream 解码，一次在 JSONDecoder/容器析构。Mac 核实 Get 解码经 detached task 执行，并使用配置 decoder；这是并发调用路径证据，不能推出 JSONDecoder 不安全、SDK 缺陷或 KS 越界就是根因。

不要改 DerivedData checkout，不要无证据替换解码器。若需要新诊断点，先说明要区分的假设和最小日志字段，避免 SID、token、认证 URL；真实 ASan 与 `.ips` 捕获留待 Mac。不要把可疑栈顶函数当根因，也不要以一次没崩溃关闭问题。

### C. 性能只做采集准备

正确性尚未稳定，不开始调速。可以整理同条件 manifest、检查真实日志字段与未归属事件，完善有明确反例的离线工具测试。不得复制 trace 凑三组，不用旧 Auto/Force 工具冒充双入口比较，不把播放时钟当屏幕首帧。

保持 Greenfield 唯一优化主线；手动清晰度只隐藏入口，相关接口/代码保留。设备文件只保存 ready 且无 pending seek 的有效断点，保持账号/文件版本隔离、128 条上限和 HLS 绝对时间语义。

## 4. NAS 每批检查与交付

```sh
python3 --version
bash scripts/preflight.sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 -m unittest discover -s agent -p 'test_*.py' -v
git diff --check
git diff --cached --check
```

NAS 没有 Apple SDK，不以 Linux Swift 替代 iOS 编译/真机测试；新增 Swift 明确标记待 Mac 验证。不要继承 94 项通过作为后续修改的测试结果。每批记录问题、反例、最小修改、检查与缺口，同步唯一总账；不删项或将未验收项改为通过。

提交前核对明确文件和 staged diff。今天的新修改默认放 `work/nas-20260915`，交回时说明准确提交与目标分支；本次用户授权推 main 是当前 Mac 交接，不据此省略未来新核心改动的 Mac 验证。

## 5. 回 Mac 的具体入口

1. 保留本地修改后取回 NAS 提交，重跑相关构建/XCTest、签名与链接检查。
2. 核实手机实际安装包、运行进程和 ASan image，从 S01 暂停定位→退出→快速重开开始；设备文件/Jellyfin 均做，再测 S03 与 S19 深位置及切轨组合。应用可能已被后台回收，不假定仍停在 00:26。
3. 完成旧响应受控集成及退出崩溃捕获；实际声音、字幕、30 秒与代表样本稳定性独立验收。iPad/双设备、第二账号不足时如实保留缺条件。
4. 正确性稳定后覆盖正常包并显式重启；依据配对文档至少三组独立重复，同片版本、轨道、字幕、起点、设备、网络、准确构建和冷热一致。保留失败、慢样本和未归属事件。

Mac 原始证据位于 `tmp/playback-20260914-mac/`，旧报告在 `tmp/playback-20260913/`；不在 GitHub。正常/ASan app、签名材料、原始日志和私有数据保持本地。原 Mac 修改的命名 stash 保留且 KSPlayer 辅助文件已恢复，未覆盖或丢弃用户原修改。

## 可直接交给 NAS 助手的提示

> 从 GitHub 最新 main 同步 Nastart，先保留 NAS 当地修改，阅读 docs/archive/handoffs/2026-09/2026-09-15-NAS-CONTINUATION.md 与唯一任务总账。9 月 14 日 NAS 六批源码已在 4ccb161，Mac 正常设备构建及 94 项 Swift 测试（含新增 16 项）全部通过；但退出/快速重开/切轨/暂停定位与 ASan 退出压测仍未完成，只观察到 S01 Jellyfin 从头画面和 00:26 暂停。今天在黑群晖优先补生命周期受控反例、SDK/旧响应集成设计和退出崩溃证据，不扩大核心改动、不凭 JSONDecoder 栈断言根因，正确性稳定前不做速度优化。保留全部 PX/UX 和清晰度代码接口。执行 NAS 可用检查，新增 Swift 明确待 Mac；逐批更新此接续文件和总账，交回时列准确提交、实际检查及未完成项。
