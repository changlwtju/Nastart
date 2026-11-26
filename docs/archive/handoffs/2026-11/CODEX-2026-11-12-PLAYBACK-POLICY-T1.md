# 2026-11-12 T1 iPad 内网路线回归

Codex 执行，时间为北京时间。依据 [总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md) 与 [V1/V2 判定](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md#三真机验证清单)。

## 包、设备和工具

- A16 iPad，iPad15,7 / iPadOS 26.6，03:42:52 fresh USB 核对。Nastart 安装路径匹配 T0 回执；源清单、HEAD 和包 dylib 已复核。普通 Debug dylib `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。空参数和空测试环境。
- 用户明确允许按需续签、部署现有兼容 Runner 副本。用本机同团队描述文件续签 iPad 副本，核覆盖当前 UDID、原 host/test bundle ID、arm64、签名 entitlement、deep/strict 与 12 个嵌套签名。Runner 主程序 SHA-256 `ddcd905aecb69bafa31a4db9a4c52073529d7ecc901134dba5d3f7547b7a7549`，profile 到 11-16 19:51:31。首次本机提取证书命令选项格式错误，修正后通过，首次命令无设备安装动作。
- 03:44:03 Runner 保留覆盖安装成功，fresh lookup 新 Runner 路径，Nastart 安装路径及全部偏好相等。XCTest/USB 转发到本机 8153，`ready=true` 并核前台 bundle/PID；实际导航、起播和普通退出均有图。iPhone 13 的 Runner 本窗未部署。
- iPad 实际网络 `wifi`，App 的 `probeFinished` 和三次 `playRequested` 都记录 `verifiedSameServerLAN`、`selectedAddressKind=privateIP`。资料库恢复地址与实际播放端点分开核对。三个初始流均用 AC3 2 / PGS 9，正常退出后详情仍显示原轨道。

## V1 与 V2

| 场景 / trace | 路线与首帧依据 | 判定和体验 |
| --- | --- | --- |
| V1 起播 `0D9521E7` | `jellyfinOriginalDirectPlay`、`maxBitrate=unlimitedOriginal`、`renditionCeiling=legacyBudget`，`noEvidence`，从 0；`tapToFirstFrameMs=1237`，`firstFrameSignal=playbackClock` | 原片起播规则通过。内部首帧慢于 0.6–0.9 s 历史窗，仍约 1 秒量级；可见片头字幕与后续片头画面。之后自然降至 HLS，已提交。 |
| V1 续播 `BF91A15B` | 同三项原片字段；`fits`；`effectivePositionTicks=4980000461`，首帧位置 498.125 s，`tapToFirstFrameMs=3363` | 原片续播规则与 2.5–3.6 s 历史量级通过；实图有电影画面和中文字幕。播放时钟在 504.290 s 至少连续 7.21 s 未推进，随后恢复；515.917 s 至少又停 3.07 s。约 10 秒和 30 秒截图均有缓冲图标。 |
| V1 从头 `0629D188` | 同三项原片字段；`fits`；`effectivePositionTicks=0`，`tapToFirstFrameMs=726` | 原片从头规则与首帧量级通过；实图确认片头画面、字幕，约 10 秒有缓冲。自然降档候选随后提交。 |
| V2 续播自然降档 `279D8F38` | `automatic_downshift_requested` 原因 `deliveryBelowSourceBitrate`，约在续播发起后 26.65 s；`fromBitrate=20000000`、`liveCapacity=30659149`、`routeCapacity=79681061`、`toBitrate=12000000` | 降档规则通过。0.5 × min(30,659,149, 79,681,061) = 15,329,574.5，严格低于 20 Mbps 的最高合适档为 12 Mbps。旧流普通退出后该候选记录 `cancelled=true, stage=decodedFrame, elapsedMs=11183`，本次续播候选未提交；起播和从头的自然 20→12 Mbps 候选另有 `replacement_committed`。 |

本轮 T1 的路线及降档判定通过。可见缓冲保留为体验问题，连续流畅未通过；内部首帧计时用于和此前同口径数据比较。未测实际音频输出或完整显示帧时间。

## 复算、采集和收尾

- 每步通过 fresh HouseArrest 保存诊断快照，并在播放开始、观测点和退出时保存。部分即时磁盘快照仍是先前落盘批次；联合多个已保留快照按事件 ID 去重，将本窗相关条目转为脚本兼容文本。原始快照和脚本兼容输入均保留。首次样本截图调度从命令开始计时，WDA 取树耗时造成标记偏移，实际近似为触摸请求返回后 2.0 / 4.0 / 22.3 s；续播和从头改用请求返回后计时。首次样本不用于严格 3/10/30 s 显示点验收。
- `python3 scripts/playback_route_decision_report.py t1-combined-report-input.txt` 退出码 0，输出 `6 playback(s) with route evidence, 0 to check.` 三次为 original，三次为自然降档的 server 候选。内网 `legacyBudget` 的具体路线与降档档位已按上表用原记录手工核对。
- 03:50:21 最后一次普通退出返回详情，03:50:43 XCTest、App 和 8153 自有转发均结束，原生复核 App/Runner 剩余 0。App 仅诊断和本次正常播放的续播偏好变化。网络未切换。
- 私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `pad/t1/`。无产品代码和参数修改；本窗未跑 App 单测，上一预检的脚本单测 6/6。
- 下一项为 T2 iPhone 13 蜂窝窗口。T3 未并入此次窗口，T4–T6 保持待办。总账和矩阵同步本轮有限实证，保留连续播放与候选提交的缺口。
