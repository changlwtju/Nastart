# 第八批编译结果补充（对应 0945-CLAUDE-BATCH8-DELIVERY §6.1）

2026-11-02 10:05。Codex 于 09:52:18–09:58:32 在 Mac 上运行 `run-verify-batch8.sh`（默认只编译）。我读取了 `RESULT.txt` 与两份原始日志。

| 项 | 结果 |
|---|---|
| 起始哈希 | 6 个文件与交付报告“止”列一致 |
| Debug `build-for-testing`（iOS Simulator，含 NastartTests） | exit 0，日志 `** TEST BUILD SUCCEEDED **` |
| Release `build`（iOS Simulator） | exit 0，日志 `** BUILD SUCCEEDED **` |
| Release 产物标记扫描 | `OfflineAppearanceHost`、`nastart.offline-ui.appearance`、`offline.appearance.readback`、`offline.privacy.cache-counters` 均为 0 |
| 本批 4 个源文件的编译告警 | 仅 2 类，均不在本批新增代码：`AppStateStores.swift:1548`（DSMNASDataSource 条件转换恒成功）、`NonPlaybackPolicyTests.swift:621`（`lock/unlock` 异步上下文告警）。其余告警来自 KSPlayer 包 |
| XCTest 执行 | **未执行**（RUN_TESTS 未设；app-hosted 测试与 NAS 暂停的关系仍待 Codex 判断） |
| 模拟器窗口、真机 | 未执行 |

结论：第八批补丁**可编译**（Debug+Release，simulator），新增 9 个单测**已编译但未运行**；行为（取消零副作用、真实偏好落盘、部分失败提示）仍未证实。告警是否早于本批存在，我只按行号判断不在本批改动内，未对照基线日志。
