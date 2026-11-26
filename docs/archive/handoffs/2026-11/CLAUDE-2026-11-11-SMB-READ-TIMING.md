# 2026-11-11 Claude：SMB 读取分段计时（排队等待 / 连接上读取）

真机取数的排期见 [给接手模型的总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md) 的 T3。

接续 [路线决策模型](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md) 第五节"下一步先测什么"的第 1 项，也是 [任务简报](CLAUDE-2026-11-10-HARD-PROBLEMS-BRIEF.md) C 节留下的缺口。基线 `main/8db1cc64` 加已有未提交改动。本批只加诊断：读取大小、顺序、并发和取消宽限都没有改。没有操作真机，没有访问 NAS，没有提交、暂存或推送。

## 结论

- SMB 的每次读取现在分开记两段时间：在同一连接上排在另一次读取后面等了多久，以及读取本身在连接上花了多久。两段都汇入现有的 1 秒代理计时窗口。
- 离线报告能直接给出"一次只读一块时连接上的速率"，以及每个请求首块延迟里排队占多少。这两个数决定 SMB 该往哪个方向优化。
- 单测：NetworkMedia 包 354 项，348 通过，6 项跳过，0 失败。App 两组 691 项，690 通过，唯一失败是基线已知项。
- 真实 SMB 服务器上的读数还没有，需要下一个 iPad 窗口。

## 为什么要分这两段

[S19 实测](CLAUDE-2026-11-10-S19-PROXY-READER-TIMING.md) 已经确认 SMB 的慢在 Reader 供给侧：稳态每秒约 1000 ms 在等 Reader，每个新 Range 的首块延迟 90–300 ms。但"等 Reader"里有两种不同的原因，对策相反：

| 原因 | 表现 | 对策方向 |
| --- | --- | --- |
| 排队：读取排在同一连接上另一次未完成的读取后面 | 排队时间长，读取本身短 | 结构读取和跳转探测走第二条连接，或让新请求更快抢占 |
| 连接上慢：请求往返、服务端读盘、传输、签名校验 | 排队时间近零，每次读取都长 | 更大的单次 READ，或同一连接上保持 2 个在途读取。若已接近链路速率，则无可优化 |

## 改动

| 文件 | 内容 |
| --- | --- |
| `Packages/NetworkMedia/Sources/NetworkMedia/WebDAVMediaResource.swift` | 新增 `NetworkMediaReadTimingRecorder`：线程安全的累加器，记读取次数、排队时间、读取时间和各自的最大值，`take()` 取出并清零。`NetworkMediaByteReader` 增加带 `timing:` 的 `stream`，默认实现不上报，所以 FTP、WebDAV 和测试替身不用改 |
| `Packages/NetworkMedia/Sources/NetworkMedia/SMBConnection.swift` | `SMBWorker.run(timing:_:)`，以及 `SMBWorker.timed(on:timing:_:completion:)`：在串行队列上分开计"入队到开始"和"开始到完成"。原来的 `run(_:)` 保留 |
| `Packages/NetworkMedia/Sources/NetworkMedia/SMBLibrarySource.swift` | `SMBMediaResource.stream(offset:count:timing:deliver:)`：每次读取上报一次。读取循环本身没有变 |
| `Nastart/Features/Devices/DevicesView.swift` | `NetworkMediaProxyTransfer` 每个传输建一个计时器交给 Reader，每块到达时取出产生这一块的读取的计时，汇入 `NetworkMediaProxyTransferTimeline` |
| `NastartTests/PlaybackNextCoreTests.swift` | 新增 2 项：时间线字段；真实代理加一个上报计时的 Reader，端到端核对 |
| `Packages/NetworkMedia/Tests/NetworkMediaTests/NetworkMediaReadTimingTests.swift`（新增） | 3 项：累加器；串行队列上排队与执行的区分；失败的读取也计时，不上报的 Reader 不留痕迹 |
| `scripts/playback_reader_timing_report.py` 及其测试 | 新增 `readerSplit`、`firstReads`，以及 `readerBound` 卡顿的 `readerDetail` |

## 诊断字段

只有 Reader 上报时才出现，目前只有 SMB。

- `proxy_transfer_progress stage=readerTimingWindow`：`readerReads`、`readerQueueWaitMs`、`readerReadMs`、`maxReaderQueueWaitMs`、`maxReaderReadMs`。
- `proxy_transfer_finished stage=readerTransferFinished`：同样的字段，前缀 `total`（`totalReaderReads`、`totalReaderQueueWaitMs`、`totalReaderReadMs`、`totalMaxReaderQueueWaitMs`、`totalMaxReaderReadMs`）。
- `proxy_transfer_started stage=readerFirstChunkDelivered`：`firstReadQueueWaitMs`、`firstReadMs`。

口径：

- 排队时间：读取进入 `SMBWorker` 的串行队列，到轮到它开始。一次播放只有一条连接，播放器的所有 Range 请求共用这个队列。
- 读取时间：轮到它之后在连接上的全部时间，从发出请求到收完回包。读取需要先连接登录或打开文件句柄时，这些也算在内，所以每条连接的第一次读取会明显更长，看 `max` 值。
- `readerWaitMs` 减去这两段，剩下的是代理、Reader 和工作队列之间的调度开销。
- 被取消或失败的读取也计一次。传输结束时还没交付的那次读取，记在最后一个窗口里。
- 不记录地址、账号、路径或内容。

## 下一个 iPad SMB 窗口怎么用

不需要切换网络，内网 Wi-Fi 即可。

1. 同一个签名包，S19，SMB 入口：起播、续播、前后各跳 15 秒，每一步之后导出诊断。
2. 同一窗口里用设备文件（HTTP）入口播同一部 30 秒，作为这条 Wi-Fi 链路的参照速率。
3. 对每个 trace 运行：

```sh
python3 scripts/playback_reader_timing_report.py <playbackTraceID> 导出.json
```

读数怎么解释：

| 读数 | 含义 | 下一步 |
| --- | --- | --- |
| `readerSplit.wireBitrate` 接近 HTTP 参照速率 | 链路本身就这么快，SMB 没有多余开销 | Reader 无可优化。S19 在这条链路上余量本来就小 |
| `wireBitrate` 明显低于 HTTP 参照，`meanReadMs` 远大于 1 MiB ÷ 链路速率 | 每次请求的固定开销占主导 | 顺序读取时把单次 READ 提到协商上限，或同一连接上保持 2 个在途读取 |
| `firstReads` 里 `queueWaitMs` 占 `readerToDeliveryMs` 的大半 | 新请求排在上一个请求没收完的读取后面 | 结构读取走第二条连接，或缩短已取消读取的宽限 |
| `firstReads` 里 `readMs` 大，16 KB 的尾部读取也超过 100 ms | 延迟在连接上：服务端寻道或每请求延迟 | 查服务端；客户端可以考虑会话内保留头尾字节 |
| `readerSplit.otherMs` 占 `readerWaitMs` 的一成以上 | 调度开销不小 | 查代理与 Reader 之间的任务切换 |
| 卡顿的 `readerDetail=notReported` | 这个入口的 Reader 不上报（FTP、WebDAV） | 需要时按同样的方式给它加计时 |

## 验证

- NetworkMedia 包（本机 `swift test`）：354 项，348 通过，6 项跳过，0 失败。跳过的 6 项是需要 `NASTART_SMB_FIXTURE_PYTHON` 的 SMB 夹具测试，此前也跳过。
- 包测试有两次运行中途卡住，各卡在一项回环集成测试（一次 FTP，一次 WebDAV）的 `tearDown`：测试结束夹具进程后 `Process.waitUntilExit` 不返回。卡住的是测试夹具的收尾，被测代码与本批无关；结束进程后重跑，完整通过。记在这里，以后遇到同样的卡住可以直接重跑。
- App（临时模拟器 `Claude-ReadTiming-20261111`，iPhone 17 Pro / iOS 27.0，已删除）：`PlaybackNextCoreTests` 与 `NonPlaybackPolicyTests` 共 691 项，690 通过，失败的是基线已知项 `testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse`。已有的 6 项 Reader 代理测试都通过。
- 脚本：`test_playback_reader_timing_report` 6 项通过。
- tvOS：NetworkMedia 包被 tvOS 目标使用。包在 tvOS 模拟器上构建通过。
- 没有验证：真实 SMB 连接上的计时读数。`SMBWorker.timed` 用休眠的假任务测过排队与执行的区分；真实连接上的行为要等设备窗口，或在装有 impacket 的环境里跑 SMB 夹具测试。

## 没有改的

- 读取大小（1 MiB）、停等式读取、一次播放一条连接、已取消读取的 1.5 秒宽限。
- FTP 和 WebDAV 的 Reader 不上报计时。
- 预读策略。它要等上面这些读数，而且需要物化字节，受现有约束。

需要 Codex 同步：`docs/development/PLAYBACK_OFFLINE_DIAGNOSTICS.md` 的字段说明和脚本用法。
