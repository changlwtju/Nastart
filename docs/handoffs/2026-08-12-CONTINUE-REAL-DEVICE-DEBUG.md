# Nastart 真机视频调试续接记录

更新时间：2026-08-13 05:40（Asia/Shanghai）

## 用户目标

固定同一 18 部电影，完成 iPhone/iPad × 设备文件/Jellyfin 的 18×4=72 个基础播放单元，并重复检查指定网络链路。重点验收：首帧速度、连续播放是否卡顿/黑屏、快进快退、暂停续播、字幕/音轨、Jellyfin 清晰度、画中画及退出后的断点续播。ISO 为独立专项；目前没有可重复访问的 ISO 样本，必须记为“样本缺失，未验证”。

## 已完成的本地恢复

- iPhone：UDID `00008110-001E543122E0401E`，iOS 16.3.1；WDA 端口 `8102`。
- iPad：UDID `00008030-001168403C43C02E`，iPadOS 18.3.1；WDA 端口 `8101`。
- 两台设备 WDA 16.1.5 均可通过 `/status` 返回 ready；不要更新任一设备系统。
- WDA 应用历史包已经安装；后续失效优先重启 DVT/iproxy，不要每天重新安装 WDA。

## 已冻结样本和结果文件

- 样本清单：[2026-08-12-PLAYBACK-MATRIX-18-SAMPLES.md](./2026-08-12-PLAYBACK-MATRIX-18-SAMPLES.md)
- 结果表：[2026-08-12-PLAYBACK-MATRIX-RESULTS.md](./2026-08-12-PLAYBACK-MATRIX-RESULTS.md)
- 18 部样本：S01 哈尔的移动城堡；S02 杀死比尔；S03 碟中谍3；S04 好东西；S05 南方车站的聚会；S06 爱情神话；S07 白日焰火；S08 黑豹：瓦坎达万岁；S09 天空之城；S10 奇异博士2；S11 神奇动物在哪里；S12 神奇动物2；S13 非诚勿扰；S14 无间道；S15 奥本海默；S16 A计划；S17 A计划续集；S18 方世玉续集。

## 已得到的关键真机证据

- iPhone → 设备文件 → `/video/media/movie` → S01：约 1.7 秒出现播放器，首帧初始状态有“暂停”控件，说明不是启动即暂停；出现字幕/音轨/快进/快退控件。
- 同一入口连续采样：约 1 秒间隔 6 组截图中，进度首组为 `00:02`，后续画面基本黑屏，只剩片源水印；侧边下载速率约 `72.1 MB/s` 到 `95.7 MB/s`，不是简单的网络吞吐归零。该单元连续播放流畅度未通过。
- iPhone → Jellyfin → S01：约 1.8 秒进入播放器，`00:01` 到约 2.2 秒的 `00:04`，显示“暂停”控件，初步播放成功；字幕控件点击后 WDA/DVT 连接重置，字幕切换及其余项目未判定。
- 截图证据目录：`/tmp/nastart-evidence/`，包括 `iphone-S01-device-file-playing.png`、`iphone-S01-jellyfin-playing.png` 和 `iphone-S01-stutter/`。
- 过程中出现 Nastart 进程退出/WDA 报告 App 不运行；已用 WDA App launch/DVT 恢复，未重新安装 WDA。

## 当前最重要的下一步

不要直接批量跑剩余 17 部。先定位 S01 `video/media` 黑屏/停滞和 App 退出问题：

1. 检查当前源码中的 `FilePreviewView.prepareMediaPlayback`、`AuthenticatedMediaStreamProxy`、`VLCMediaPlayerSession`，确认本次实际走的是 direct HTTP 还是 local Range proxy，并记录启动/缓冲/重连日志。
2. 重新单测 S01：稳定采集 10 秒进度变化和画面截图；使用元素级控件操作，避免不必要的坐标点击导致 App/WDA 崩溃。
3. 对比 iPad 同一 S01 设备文件入口，确认问题是 iPhone 特有、iPad 特有，还是共用播放器/Range 响应问题。
4. 定位并修复后重新构建 main 分支当前源码，安装两台真机，再从 S01 开始继续矩阵。

## 源码状态

当前有用户改动，必须保留：`NASModels.swift`、`AppStateStores.swift`、`DevicesView.swift`、`LaunchpadView.swift`、中英文本地化，以及本目录的样本/结果记录。

## 继续工作约定

结论必须基于真机证据；未完成、不可达、样本缺失和 WDA 失效分开记录，不得记为通过。用户不希望每天反复安装 WDA，也明确禁止更新 iPhone/iPad 系统。

## 2026-08-13 续接结果

- 已在 iPhone 真机重新复现 S01：预览后约 8 秒出现真实视频画面，说明本地代理至少能够送出首帧；继续观察时 Nastart 被系统终止。
- `idevicesyslog` 明确记录：`Nastart` 进程达到 `2148374KB`，随后被 Jetsam 以 `per-process-limit` 杀掉；这不是“网络没数据”或单纯 WDA 断连。
- 根因定位到工作区未提交的播放改动：本地 Range 代理在首个 `bytes=0-` 请求上去掉 Range，向 VLC 暴露整部 2.7 GB 文件的渐进式 `200` 响应，导致进程内存失控。
- 已做最小源码修正：域名/公网路由继续直连；本地代理即使启用也始终从有限 Range 窗口开始，不再返回整文件渐进式响应。保留现有用户改动，未更新设备系统，未重新安装 WDA。
- 已确认本机 Xcode 位于 `/Users/lagransun/Downloads/Xcode.app`（Xcode 26.6，build 17F113）；修正版已完成签名构建，并安装到 iPhone 与 iPad。未更新设备系统，未重复安装 WDA。
- 32 KiB 构建在 iPad 上约 00:00 超时；8 MiB 构建可推进到约 00:34，但未稳定出帧；1 MiB 构建完成了两台设备同步回归。
- 同步回归证据：两台设备在时间差不超过 2 秒时启动 S01，iPhone 在 t=3/10/30 秒均有真实画面，iPad 在 t=3/10/30 秒均为黑屏；iPad 日志显示连续收到匹配的 `206`、每段约 `1048903` bytes，随后本地回环连接被重置。该结果排除了“iPad 卡住必然连带 iPhone”的共享链路结论，当前优先定位 iPad 专有的 VLC/解码或 Range 消费问题。
- 本轮仍不能把 S01 标为完整通过，也不要批量跑剩余样本；后续必须继续记录首帧、连续播放、seek、暂停/继续、字幕/音轨、退出和内存稳定性。

## 2026-08-13 播放规范与手势

- 已新增 [PLAYBACK-DEBUG-RUNBOOK.md](./PLAYBACK-DEBUG-RUNBOOK.md)，固定设备文件/Jellyfin 播放链路、历史故障、并发回归顺序和日志要求。
- 已新增 [PLAYBACK-FUNCTION-MATRIX.md](./PLAYBACK-FUNCTION-MATRIX.md)，把 18×4 单元拆成首帧、连续播放、暂停/继续、seek、音轨、字幕、清晰度、PiP、退出断点和内存稳定性逐项验收。
- 内置 VLC 播放器手势约定：双击视频画面暂停/继续；单击只显示/隐藏控制栏；横向拖动快进/快退；纵向拖动调节亮度。代码已通过 `swiftc -parse` 和 `git diff --check`，尚未随本轮手势改动重新安装真机。
