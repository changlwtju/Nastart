# 2026-11-12 播放策略 T3 · SMB 续播与跳转

- A16 iPad（iPad15,7 / iPadOS 26.6）现场复核 USB、设备身份、现装路径、App 与 Runner 签名。沿用 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) 的普通签名 Debug，dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。HEAD `8db1cc64`，与冻结清单相比 499 个 iOS 源输入一致。
- 08:48–08:56 独占窗口。首次预检发现现有 Nastart，未操作。核实际 PID、bundle 与可执行路径，确认无现有 Runner、前台可用且播放器未打开后，保存诊断并按正常 App 路线进入。Wi-Fi 图标和播放器 Wi-Fi 状态可见，未切网。通过已保存的 SMB 连接添加单影片本机索引，读回恰好一份 S19、128,795,641,934 字节。基线 4 库、4 连接逐项相等。

| 场景 | 判定与证据 |
| --- | --- |
| SMB 从头，`8B4F0558` | `sourceScheme=smb route=sharedReader playMethod=directPlay plannedStartSeconds=0`，内部首帧 2,250 ms，首帧位置 0.098 秒，实图可见片头。普通「完成」返回详情，`local_resume_save_boundary` 记录 `close` 与 `viewDisappear`，出现「继续观看」。 |
| SMB 续播，`8DC91166` | 同一路线，普通重新打开时书签与 `plannedStartSeconds` 同为 22.285 秒，内部首帧位置 22.767 秒、3,852 ms，实图可见片头字幕。书签边界为同一 App 进程。 |
| 前进 15 秒 | 实际按下该按钮，`seek_started` 目标 54.940 秒，`seek_engine_completed completed=true`，`seek_recovered seekRecoveryMs=239 currentSeconds=55.141`，之后实图有电影标题。 |
| 后退 15 秒 | 实际按下该按钮，`seek_started` 目标 56.974 秒，`seek_engine_completed completed=true`，`seek_recovered seekRecoveryMs=1582 currentSeconds=57.073`，之后实图有电影标题。随后普通退出回详情。 |

两次跳转是连续播放中分开操作，事件中的 `seekDeltaSeconds` 分别为 +15.447 与 −14.274 秒。恢复时间按引擎定位完成并恢复时钟推进计。实际使用音轨 1、字幕 8，AC3 2 / PGS 9 的配平未执行。

两次运行 `scripts/playback_reader_timing_report.py`，输出如下。

| Trace | Reader 窗 / 播放采样 | 连接读取速率 | 报告卡顿 |
| --- | --- | --- | --- |
| `8B4F0558` | 18 / 24 | 53.26 Mbps | 2.004 秒，`readerBound/onTheConnection` |
| `8DC91166` | 46 / 53 | 56.32 Mbps | 1.583、1.069、3.596 秒，均 `readerBound/onTheConnection` |

续播的 16,567 字节尾块 `firstReadQueueWaitMs=104 firstReadMs=4 readerToDeliveryMs=107`。首块排队现象复现。该 trace 的最长卡顿窗口另有 `readerReadMs=3578 readerQueueWaitMs=0`，应与首块排队分开判断。上一批同机 HTTP 无背压参照中位数为 68.54 Mbps，本批未重跑 HTTP 或配平缓存。 [先前读数](CODEX-2026-11-12-PLAYBACK-POLICY-T3.md)

08:56:33 按已核实的名称撤除本轮临时索引，最终读回原 4 库、4 连接完全相等，保留来源未确认的原有空索引。08:56:41 App、Runner、8153 转发和采集结束。私有证据由 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `pad/t3-resume/`，含逐步诊断、控制确认、图像及两份 Reader 报告。无产品代码、播放参数、NAS 或远端文件修改。Reader 与路线复算现有脚本单测各 6 项通过。
