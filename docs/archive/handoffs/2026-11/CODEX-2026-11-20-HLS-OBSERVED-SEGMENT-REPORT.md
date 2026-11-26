# 2026-11-20 HLS 续播首段离线诊断

接续 [iPhone 13 预检](CODEX-2026-11-20-IPHONE13-PLAYBACK-PREFLIGHT.md)。当前会话重试连接 Mac 的 `usbmuxd` 仍返回 `EPERM`，已核 8102、8161、8168 无 WDA 转发监听。今早 [安装记录](CODEX-2026-11-20-IPHONE13-USB-APP-WDA-INSTALL.md) 已证实现装 iOS 16.3.1 兼容 Runner 能通过 XCTest 返回 `ready=true`。本次未取得手机身份、已装 Nastart 路径及当前签名信任链的新证据，未发起重装、XCTest、远控或播放。

旧 `playback_phase_report.py` 的首段报告固定筛选 0 号段，会漏掉从非零段开始的续播。离线脚本新增 `firstObservedSegmentAttempts`，在每个 trace 内取观察窗内首个可见且已派发的播放分段。按同一本地 child 保留重试，缺少 child 时只关联同一 transfer。显式预取不参与选段，已观察到内部首帧时据此截住新发请求。首帧后返回的响应头和发送失败仍归属先前已发尝试。原 `startupSegmentAttempts` 和原 0 号段分析保留。分段序号缺失时保持未知，窗口内首次观察仅指现有采样。输出不含原始 URL、child 或 transfer ID。未修改 iOS 播放和网络实现。

| 11-12 历史 trace | 观察到的实际首段 | 请求次数 | 请求至响应头 | 交付字节 |
| --- | ---: | ---: | --- | ---: |
| `4D676234`，S19 Jellyfin 从头 | 0 | 4 | 四次均未观察到 | 未观察到 |
| `F4DF3ADE`，S19 Jellyfin 续播 | 166 | 1 | 3,007 ms | 5,116,420 |
| `69E7F11D`，《杀死比尔》从头 | 0 | 2 | 11,388 / 7,753 ms | 3,829 / 5,998,892 |
| `BF2DFD97`，S19 设备文件续播 | 3 | 1 | 2,731 ms | 1,272,384 |

重新读取私有偏好快照，在单个历史 trace 内按事件 ID 去重后用实际脚本分析。前两条 trace 共用的历史窗口有一份快照无法解析，缺口保留。原报告对第 166 和第 3 段均输出 0 条请求，新字段分别恢复 1 条。全套离线播放工具 160 项通过，其中新增反例覆盖预取先到、其他 child 并发、内部首帧后迟到终止、首帧后再次请求、缺失身份及非零段。各历史样本的画面与验收归属见 [上轮结构化结果](../../../testing/results/2026-11/CODEX-IPHONE13-PLAYBACK-PREFLIGHT-20261120.json)，本窗未新增真机验收。

USB 开发通道可用后，使用现装 Runner 启动 XCTest 并核对项目 bundle 和 `/status ready=true`。正式触控前查当前安装身份，先在原 Wi-Fi 补正常 Jellyfin 读库，再补 S19 蜂窝从头和续播。采集同窗首段请求、获头、正文、实际画面与正常退出，并按约定恢复原 Wi-Fi。
