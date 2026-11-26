# 2026-11-11 Claude：替换源协调状态机（纯逻辑，未接线）

接线和真机回归的排期见 [给接手模型的总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md) 的 T5；这 6 处问题在日志里的样子见它的第七节。

接续 [路线决策模型](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md) 第四节"替换源状态机"，对应 [任务简报](CLAUDE-2026-11-10-HARD-PROBLEMS-BRIEF.md) B 节。基线 `main/8db1cc64` 加已有未提交改动。本批只新增一个纯类型和它的单测，播放器视图没有改，App 行为没有变化。没有操作真机，没有访问 NAS，没有提交、暂存或推送。

## 结论

- 新增 `PlaybackSourceChangeCoordinator`（`Playback/Core/PlaybackPlanningPolicy.swift`）。它只决定重叠的换源请求谁先做、谁等、谁让位，不持有加载器、任务或播放器。
- 读 `replaceSource` 时确认了 6 处现有问题，状态机的规则都覆盖。这些问题是读代码得出的，没有在真机上复现。
- 新增单测 8 项全部通过。两组合计执行 699 项，698 通过，唯一失败是基线已知项。tvOS 共享文件类型检查通过。
- 接线会改变用户可见行为，需要真机回归，本批没有做。接线步骤和回归清单在第三节。

## 一、读代码确认的现有问题

`GreenfieldVideoPlayerView.replaceSource` 用"是否在换源、深度为 1 的待办、选轨去重"协调。待办是"最后一次请求生效"，不区分请求改的是什么，所以两个互不冲突的操作会互相顶掉。

| # | 场景 | 现在的结果 | 状态机的结果 |
| --- | --- | --- | --- |
| 1 | 切轨候选准备中，跳转走了服务端重新协商 | 选轨被丢。跳转的加载器用的是当前播放流的音轨和字幕 | 合并成一次替换：落在跳转目标，带新选的轨道 |
| 2 | 服务端跳转转圈时选了轨道 | 跳转被放弃，旧位置恢复播放，再从旧位置切轨 | 跳转继续完成，切轨排在它后面 |
| 3 | 下一集加载中又点了一次下一集 | 第一次加载完成后被丢弃，同一集再加载一遍 | 第二次点按什么都不做 |
| 4 | 两次暂停式替换相接（连续两次服务端跳转） | 中间先恢复旧流播放，同一轮里再暂停 | 一直保持暂停，到最后一次结束 |
| 5 | 切轨候选准备中用户暂停，随后服务端跳转 | 跳转完成后自动播放（沿用切轨开始时的"正在播放"） | 保持暂停 |
| 6 | 选了新轨道后马上选回当前轨道 | 再做一次完整替换，换到一条相同的流 | 取消准备中的候选，不再准备 |

第 1 条在上一份文档里已经记过。第 4 条的"先恢复再暂停"发生在同一轮主线程里，是否听得到需要真机确认。

## 二、状态机

### 模型

不逐对列规则。状态机维护"下一条流想要什么"（`Target`）：轨道、跳转位置、换到哪一集、是否是 App 自己的降档。每个新请求折叠进去，然后只做一个判断：替换准备中的尝试，还是排在它后面。

- 同一时刻只准备一个尝试（`Attempt`）。
- 暂停式：跳转和换集会暂停旧流直到新流就绪。选轨和自动降档让旧流继续播，就绪后无缝交接。
- 画质没有建模：Greenfield 播放器的画质入口现在传的是 `nil`。恢复入口时按选轨的方式加一个维度。

### 规则

| 准备中 | 新请求 | 结果 |
| --- | --- | --- |
| 无 | 任意 | 立即开始。选的就是当前轨道时不做任何事 |
| 选轨 | 另一组轨道 | 替换，取最新的选择 |
| 选轨 | 同一组轨道 | 合并，不打扰候选 |
| 选轨 | 当前播放的轨道 | 取消候选，后面不再跟任何尝试 |
| 选轨 | 服务端跳转 | 替换为一次带该轨道的跳转 |
| 跳转 | 同一目标 | 合并 |
| 跳转 | 另一目标 | 替换。排着的选轨一起带过去 |
| 跳转 | 选轨 | 排队。跳转提交或失败后再切轨 |
| 自动降档 | 用户的选轨、跳转或换集 | 替换，降档不带进用户的请求，由采样循环之后重新评估。选的就是当前轨道时不算请求，降档照常 |
| 任意 | 自动降档 | 忽略 |
| 换集 | 同一集 | 合并 |
| 换集 | 另一集 | 替换 |
| 换集 | 选轨或跳转 | 忽略：它们是对即将离开的那一集说的 |
| 选轨、跳转或降档 | 换集 | 替换。旧一集的轨道和位置不跟过去 |

"跳转 + 选轨"选排队而不是合并重来，是因为屏幕已经在等这次跳转，重来会延长转圈时间；排队则先恢复画面，轨道随后无缝切换。

### 其余规则

- 能否提交（`mayCommit`）：尝试没有被替换；画中画的代数没变，且画中画不在启动或活动中；对不暂停的尝试，跳转代数也没变。
- 本地跳转后重试：选轨候选因为本地跳转而作废时，结束后用同一选择从新位置再准备一次。画中画接管后不重试。自动降档不重试。
- 失败提示：只有用户的请求失败，并且它仍是当前请求时才提示。被替换的、被跳转作废的、App 自己的降档都不提示。
- 暂停的归属：第一个暂停式尝试开始时记下"之前是否在播"，一串暂停式尝试共用这个答案。新流据此决定开始时是否暂停；换集总是播放。只有在后面没有暂停式尝试时才恢复旧流。
- 关闭播放器（`cancelled`）：清空，不再跟任何尝试，不恢复。

### 接口

```swift
var changes = PlaybackSourceChangeCoordinator()
changes.submit(.tracks(...) / .seek(...) / .item(...) / .automatic, live:)   // -> Submission
changes.mayCommit(attemptID, live:)                                           // -> Bool
changes.finish(attemptID, .committed / .failed / .abandoned / .cancelled, live:)  // -> Completion
```

`Live` 是事件发生时从播放会话读的快照：跳转代数、画中画代数、画中画是否占着渲染器、是否想播放、当前播放流的轨道。当前轨道拿不准时传 `nil`，状态机就不会把任何选择当成"选回当前轨道"（字幕索引为空时服务端可能烧了默认字幕，这种情况视图不能担保）。

`Completion` 告诉视图三件事：下一个要准备的尝试、是否提示失败、是否恢复旧流播放。

### 保留的现有行为

- 重复点同一轨道不产生新请求。
- 连续选轨只准备最后一次选择。
- 切轨准备中本地跳转，从新位置重新准备。
- 画中画接管后放弃替换，之后同样的选择算新请求。
- 自动降档失败不弹提示。

### 没有放进状态机的

- 自动降档自己的额外条件（轨道没变、静态预测撤回）。它们读的是渲染器的实时状态，留在视图。
- 被替换的尝试仍要等它的加载返回才让位，和现在一样。要更快，加载器需要支持取消。

## 三、接线（下一批，需要真机）

### 步骤

1. 用 `PlaybackSourceChangeCoordinator` 取代 `changingSource`、`sourceChangeBlocksPlayback`、`pendingSourceChange`、`sourceChangeRequests`、`sourceChangeWasPlaying` 五个状态量。`sourceLoadTask` 和 `sourceChangeFailed` 保留。
2. 调用点改为提交 `Change`。`Target` 到现有加载器的对应：

| `Target` | 加载器 | 旧流 |
| --- | --- | --- |
| 只有轨道 | `sourceTrackRequestLoader(音轨, 字幕, 当前状态)` | 继续播 |
| 只有跳转 | `serverSeekRequestLoader(秒, 当前状态)` | 暂停 |
| 轨道加跳转 | `sourceTrackRequestLoader(音轨, 字幕, 位置换成跳转目标的状态)` | 暂停 |
| 换集 | `episodeNavigation` 的前一集或后一集加载器 | 暂停，新流总是播放 |
| 自动 | 降档加载器。预测码率和两个回调按尝试编号另存 | 继续播 |

3. 准备任务的主体不变。检查点里的 `pendingSourceChange == nil` 加 `canReplacePlaybackSession` 换成 `mayCommit`。
4. `defer` 里调 `finish`，按 `Completion` 恢复播放、提示失败、开始下一个尝试。下一个尝试的目标和刚结束的相同时，照旧记 `source_track_retry_after_seek`。
5. 接线完成后删除 `PlaybackSourceChangeRequestTracker` 和它的 3 项单测。

"轨道加跳转"走选轨加载器时，请求原因会记成 `sourceTrackSwitch`，运行时偏好用的是 `applyingSourceTrackRuntimePreferences`。接线时要核对它和跳转用的 `applyingRuntimePreferences` 的差别是否影响倍速和字幕显示。设备文件入口（`DevicesView` 的 `trackLoader`、`seekLoader`）同样处理。

### 真机回归清单

网络：任一条会走服务端 HLS 的线路即可（蜂窝，或内网下需要转码的片源）。不需要切换网络。每个场景后导出诊断。

| # | 操作 | 判定 | 看哪些字段 |
| --- | --- | --- | --- |
| W1 | 选另一条音轨 | 期间继续播放，随后切到新音轨 | `playback_preparing` 的 `requestReason=sourceTrackSwitch`、`audioStreamIndex`；`replacement_committed` 一次 |
| W2 | 连点两条不同音轨 | 最后听到的是第二条 | `replacement_committed` 只有一次；最后一条 `playback_prepared` 的 `audioStreamIndex` 是第二条 |
| W3 | 选新音轨后马上选回原音轨 | 画面和声音不中断，不发生替换 | 没有 `replacement_committed` |
| W4 | 选新音轨后马上拖到未缓冲的位置 | 一次转圈后落在目标位置，并且是新音轨 | `playback_prepared` 的 `startTimeTicks` 是目标、`audioStreamIndex` 是新轨；`replacement_committed` 一次 |
| W5 | 拖到未缓冲位置，转圈时选音轨 | 先在目标位置恢复画面，随后无缝切到新音轨 | `replacement_committed` 两次，第一次的位置是跳转目标 |
| W6 | 下一集加载时再点一次下一集 | 只加载一次 | 下一集的 `playback_preparing` 只有一次 |
| W7 | 暂停后重复 W4 | 提交后保持暂停 | `replacement_committed` 的 `startsPaused=true` |
| W8 | 选音轨后在已缓冲范围内跳转 | 从新位置重新准备并切换成功 | `source_track_retry_after_seek`，随后 `replacement_committed` |
| W9 | 选音轨后马上进画中画 | 画中画继续播放原流，不被替换 | 没有 `replacement_committed` |
| W10 | 自动降档准备中选音轨 | 选轨完成，降档放弃 | `automatic_downshift_abandoned`，随后 `replacement_committed` |

W4、W5、W6、W7 是行为会变的四项，W3 是新增的取消。其余是保持不变的回归项。

## 四、改动与验证

| 文件 | 内容 |
| --- | --- |
| `ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift` | 新增 `PlaybackSourceChangeCoordinator`。只依赖 Foundation，tvOS 目标共用这个文件 |
| `ios/Nastart/NastartTests/PlaybackNextCoreTests.swift` | 新增 8 项单测，覆盖规则表的每一行、提交条件、重试、失败提示和暂停归属 |

- App（临时模拟器 `Claude-SourceChange-20261111`，iPhone 17 Pro / iOS 27.0，已删除）：`PlaybackNextCoreTests` 与 `NonPlaybackPolicyTests` 执行 699 项，698 通过，另有 2 项跳过（此前也跳过）。唯一失败是基线已知项 `testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse`。上一批是 690 通过，本批多出的 8 项就是新增的单测。
- tvOS：17 个共享播放核心文件对 tvOS 16.0 模拟器做类型检查，DEBUG 和 release 都没有错误。没有构建完整的 tvOS 目标。
- `scripts/preflight.py` 输出与本会话开始时的基线逐行一致（它的失败项都在基线里）。`scripts/check_documentation.py`：723 篇文档，缺失 0。
- 没有验证：接线后的任何行为。状态机没有被 App 代码调用。

## 五、需要用户决定

1. 换集加载中对旧一集的选轨和跳转：状态机选择忽略。现在的行为是"最后一次操作生效"，换集会被放弃。
2. 是否安排接线批次。它需要一个真机窗口跑完 W1–W10。

共享文档没有改动，也不需要 Codex 同步字段说明：本批没有新增诊断字段。
