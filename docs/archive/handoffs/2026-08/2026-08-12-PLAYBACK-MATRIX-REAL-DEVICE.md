# 2026-08-12 真机播放验证记录

## 验证边界

- 安装包：workspace 签名包，commit `a5ff98d`。
- 包体：`/tmp/nastart-same-workspace-signed2.sy3shQ/Build/Products/Debug-iphoneos/Nastart.app`。
- 包内主二进制 SHA-256：`c9c163e7af5c05c1766d53c2e29e4c3a6dffd591bc583ccfa4f26c9f1690e56f`。
- iPad：`REDACTED-DEVICE-02`，iPadOS 18.3.1。
- iPhone：`REDACTED-DEVICE-01`，iOS 16.3.1，iPhone 13。
- 两台设备均安装了同一包体；未以 Mac 文件扫描或目录浏览替代真机播放。

## 已实际完成的单元

| 设备 | 入口 | 实际样本 | 结果 | 证据 |
|---|---|---|---|---|
| iPad | DSM `/video/media` | `A Touch of Sin (2013)` / `Tian.zhu.ding.2013.PROPER.BluRay.1080p.DTS.x264-iNK.mkv` | 通过 | 真机画面实际出帧，应用进程存活 |
| iPad | DSM `/video/media` | `Castle in the Sky (1986)` / `Castle in the Sky (1986) Bluray-1080p.mkv` | 通过 | 真机画面实际出帧，应用进程存活 |
| iPad | DSM `/video/media` | `Fantastic Beasts The Crimes of Grindelwald (2018)` / `...Bluray-1080p.mkv` | 超时黑屏 | 真机显示“无法播放媒体 / 播放器等待媒体数据超时”，应用进程存活 |
| iPad | DSM `/video/media` | `Black Coal, Thin Ice (2014)` / `Bai.ri.yan.huo.2014.BluRay.1080p.DTS.x264-MTeam.mkv` | 超时黑屏 | 真机显示同一超时错误，应用进程存活 |
| iPhone | Jellyfin 媒体库 | `A计划` | 通过 | 真机约 12 秒后实际出帧，应用仍在播放，无错误界面 |
| iPhone | DSM `/video/media` | `[哈尔的移动城堡].Howl s.Moving.Castle.HDTV.720p.x264.AC3-CMCT.mkv` | 通过 | 真机实际出帧（WALT DISNEY STUDIOS PRESENTS / 字幕），应用进程存活 |

## 崩溃归因

- iPad 早先设备文件播放《哈尔的移动城堡》的崩溃已由设备 `.ips` 确认是应用真实崩溃：`EXC_BAD_ACCESS`，调用栈落在 MobileVLCKit 的 `VLCMediaPlayer(options:)` 初始化路径。该路径已移除并重新签名安装；之后同一入口已实测出帧，未再复现同类崩溃。
- iPhone 旧报告中确实存在历史 Nastart 崩溃记录，但没有媒体标题字段，不能把其中某一份报告直接归因到《A计划》。最新同签名包通过 WDA 真机重播《A计划》实际出帧；播放后重新拉取的报告没有新增崩溃。因此当前可确认的是：本次《A计划》复测不是操控退出，也没有发生新的应用崩溃；旧事件仍保留为“历史崩溃，具体触发样本未能从报告确定”。

## 矩阵状态

目标是每台设备分别完成：Jellyfin 18 个随机真实视频 + DSM `/video/media` 18 个随机真实视频，共 72 个真机入口单元。当前只登记上表已实际打开、播放并观察的单元；失败和未测项均不记为通过，完整矩阵仍未完成。
