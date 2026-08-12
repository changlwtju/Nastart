# Nastart 18×4 播放功能验收矩阵

更新时间：2026-08-13（Asia/Shanghai）

本表把“18×4 播放单元”和“每个单元要测什么”分开固定。结果填写在 18×4 单元格中，不能只写“能播放”。状态顺序固定为：

`FF / ST / PA / SK / AT / SU / Q / PP / EX / MEM`

- `FF` 首帧；`ST` 连续播放；`PA` 暂停/继续；`SK` 快进/快退；`AT` 音轨；`SU` 字幕；`Q` Jellyfin 清晰度；`PP` 画中画；`EX` 退出/断点续播；`MEM` 内存/进程稳定性。
- 每项状态使用：`U` 未测、`P` 通过、`F` 失败、`N/A` 不适用、`NA` 不可达、`TOOL` 工具失效。
- 设备文件入口的 `Q` 固定为 `N/A`；Jellyfin 入口的 `Q` 必须测；没有字幕/第二音轨时仍要记录为 `N/A`，不能留空。
- 单元格示例：`P/P/U/U/U/U/N/A/U/U/P`。

## 入口缩写

| 缩写 | 含义 |
|---|---|
| `IP-D` | iPhone · 设备文件 |
| `IP-J` | iPhone · Jellyfin |
| `PD-D` | iPad · 设备文件 |
| `PD-J` | iPad · Jellyfin |

## 18×4 单元格总表

初始值全部为 `U`。任何一次参数或链路改动后，至少重测 S01 的四个单元以及受影响格式族；不允许沿用旧构建结果。

| 样本 | IP-D | IP-J | PD-D | PD-J |
|---|---|---|---|---|
| S01 哈尔的移动城堡 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S02 杀死比尔 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S03 碟中谍3 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S04 好东西 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S05 南方车站的聚会 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S06 爱情神话 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S07 白日焰火 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S08 黑豹：瓦坎达万岁 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S09 天空之城 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S10 奇异博士2 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S11 神奇动物在哪里 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S12 神奇动物2 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S13 非诚勿扰 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S14 无间道 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S15 奥本海默 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S16 A计划 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S17 A计划续集 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S18 方世玉续集 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |

## 功能判定细则

| 代码 | 通过条件 |
|---|---|
| `FF` | 进入播放器后有可辨认真实视频帧；只出现播放器、进度条、片源水印或转圈不算首帧 |
| `ST` | 至少 30 秒进度持续推进，期间无长时间黑/灰屏、无超时和无重复缓冲 |
| `PA` | 暂停按钮和视频画面双击均可暂停；再次操作后画面从相近时间点恢复 |
| `SK` | 前进/后退 15 秒后时间点正确，画面在合理时间内恢复 |
| `AT` | 每个可用音轨可切换，切换不退出、不回到 00:00 |
| `SU` | 每个可用字幕可切换，字幕显示正确，切换不破坏播放位置 |
| `Q` | Jellyfin 清晰度切换成功，时间点和播放状态保留 |
| `PP` | 进入/退出 PiP 成功，回到 App 后断点保留；不支持时记录明确原因 |
| `EX` | 退出播放器再进入时断点符合产品定义，不意外从头开始 |
| `MEM` | 采样期间 App 未被 Jetsam/崩溃；记录设备日志和关键内存现象 |

## 当前已知填写

S01 的历史结果和证据仍以结果表为准。目前不能把 S01 四个入口标记为完整通过：iPhone 旧构建曾发生 Jetsam；修正版 iPhone 曾在 3 秒和 10 秒看到真实画面；iPad 32 KiB 版本 00:00 超时，8 MiB 版本推进到约 00:34 但未稳定出帧；1 MiB 版本已出现进度推进和“暂停”控件，连续画面仍需完成串行与并发采样。

每次填写 `P` 或 `F` 必须在结果表追加：构建时间、设备、入口、链路、截图路径、日志路径和时间点。这样后续可以区分“同一视频不同链路失败”和“同一链路不同视频失败”。
