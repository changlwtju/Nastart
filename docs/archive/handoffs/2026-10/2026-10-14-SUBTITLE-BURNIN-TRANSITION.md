# 2026-10-14 烧入字幕切换到文字字幕

## 变更卡

- 关联 PX-20、PX-02、PX-21；沿用 Greenfield 主线，当前批只处理字幕交付方式切换。
- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`。接续时发现本机 12:32 批未写回的记录及普通 Debug 包：源码差异 `7029e4561adbca4ea1be1210060503b539a682ccb011bf8a629be643b76644b7`，13:11 构建。它包含“重复点选已提交的烧入字幕不重新准备播放流”的既有修改；保留该修改及所有其他工作区内容。
- 本轮现场 USB 确认 iPhone 13 / iPhone14,5 /16.3.1、iPad 9 /iPad12,1 /18.3.1。设备名称、UDID、原始偏好与凭据只保存在本机私有证据目录。先保存诊断、核对 173 构建输入/签名/三二进制哈希，再保留数据覆盖基线包并验证空 env/args 正常首页。
- 原故障：iPad Jellyfin 播放已烧入 PGS 的 MI2，选择 ASS 后同时出现原流内的中英 PGS 和共享文字层。本轮 `current-before-fix.png` 实际再次看到双层字幕；前一批的固定暂停图也保留。菜单选择成功不等于字幕交付正确。
- 根因：文字字幕分支直接设置 overlay 并继续原视频。已经编码在视频里的 PGS 无法通过关闭 AV legible/native subtitle 消除。原协商日志明确 `SubtitleMethod=Encode`、PGS index7。
- 修改：仅在已提交请求具有文字 sidecar 或明确关闭字幕、且没有准备中的替换时，使用原快速文字切换。其他情况交给已有 sourceTrackChange：原画 KS 可原地禁用内嵌字幕并启用 sidecar；烧入视频先准备不含旧字幕的新源，提交后才显示文字。沿用既有暂停/位置/失败保留/队列与字幕恢复机制，不改媒体参数、Range、网络、书签身份或服务器配置。
- L0：预检、现有完整 XCTest、普通 Debug 真机构建与签名/IPA 核对。L1：原故障、字幕关闭/恢复、显隐/旋转与暂停 seek。基础回归：两机 S01 双入口、S03；更广格式/声音/HDR/PiP/性能不因本批而验收。
- 成功条件：目标字幕真实可读、旧层消失，暂停/位置正确，关闭/恢复可用，正常退出；保留所有失败与未完成项。

## 取证边界

本轮全部 WiFi，不将用户月 10GB 额度用作测试预算。基线 seek 采集曾在 AFC 关闭诊断读取时 SocketError；实际 App 仍在前台播放，崩溃清单无新增。该次采集及后续原生控件未找到的工具失败保留，不作为播放通过或 App 崩溃。

## 本轮包与已完成的定向验证

- dirty 源码 SHA256 `f03a7f2f3fddd6a5c3eba1d2ecfc2e10e762c626835539ea80864b1a7ad558e6`；普通 Debug -Onone，构建 `2026-10-14T17:32:33.245938+08:00`。173 个 iOS 构建输入中只有 LaunchpadView.swift 本轮变化，其余 172 逐哈希保持。另更新 preflight 的旧“文字字幕一律复用视频”检查为有条件复用，原预检失败保留。
- 本轮实际 380 测试、2 跳过、0 失败；15 项预检、真机构建、29 库独立签名、deep/profile/linkage、IPA CRC 与三二进制一致性通过。完整包路径在本机 current-package.json；文件名 `Nastart-Subtitle-Burnin-Transition-Normal-Debug.app`，IPA `Nastart-Subtitle-Burnin-Transition-Normal-Debug.ipa`。
- 主二进制 `ce2fadeb661ea765fec6202e6c87aa72afddc42ee8aa9d01559c85431eca9b71`；Debug dylib `1f415e842f2c17b1720f28196806c4ea6036b98eb4528b555ab9d2b85d2413ad`；KSPlayer `ca6175564417d88c8fb61a18bcc78c711a16d18e23799cf3bd71fe55a740774d`。IPA `7480ff215cc39e8fa31e2388744e00d16386d444b87a318e476f427c104827df`；profile 到期 UTC `2026-10-17T22:23:40`。
- iPhone13 `17:33:20+08:00`、iPad `17:32:56+08:00` 保留数据覆盖成功，分别 25/18 项安装偏好逐值保持；空 env/args 的实际正常首页已看。每个播放/切轨窗口另做现场身份、源码/签名包与安装门槛核对。
- iPad MI2：开始为 PGS7 烧入 HLS，选择 ASS5 后请求服务端字幕 -1，10.544 秒内部提交；保持暂停，提交前后位置 4700.563/4700.562 秒。实际 1:18:38 为单层双语文字，控制栏显隐、竖屏及恢复横屏均已看；没有原 PGS 层。不是切轨显示耗时或完整字幕验收。
- iPad 同暂停 cue 关闭字幕图无文字但仍有 spinner；原等待工具 AFC SocketError 保留，后续保存日志恢复到本次 Off 内部提交 6.932 秒。再启用 ASS 的图及 10 秒重复选择无换流已看。暂停 +15 秒到 1:18:53，t3 仍旧电影帧、t10 更新，新文字 cue 两图均在；显示恢复延迟仍待排查。原 PGS 已重新提交（9.666 秒）并实际正常退出。
- iPhone13 MI2：本轮自动兼容候选先预热失败并放弃，未冲销；切 ASS 时仍为原画 KS，原地禁用内嵌字幕并启用文字。实际 1:18:56 单层文字、显隐与旋转已看；重复已选 ASS 的 10 秒窗口无换流。暂停 +15 秒到 1:19:11，t3/t10 为目标附近同一画面和单层新 cue。原 PGS 原生选择恢复并普通退出；恢复后该暂停点无字幕的截图不计 PGS cue 阳性。误用等待 replacement 的工具 45 秒断言保留，已按无需换流的 native 路径分类。

## 基础回归与最终收尾

以下均为本轮 f03 包新取证；MI2 含刻意暂停和切轨，不用长会话信号推断性能。S01 制作字样不作为可移动字幕 cue 证据。每个基础窗口实际 t3/t10/t30 和普通退出图已看，S03 t3 黑场但时钟推进，后续为真实片头/制作画面。

| 设备 | 样本/入口 | 非蜂窝/蜂窝 metrics | 结论范围 |
|---|---|---:|---|
| iphone13 | MI2 / Jellyfin | 30 / 0 | 字幕切换定向 |
| iphone13 | S01 / device file | 2 / 0 | 稀疏片头与普通退出 |
| iphone13 | S01 / Jellyfin | 2 / 0 | 稀疏片头与普通退出 |
| iphone13 | S03 / Jellyfin | 5 / 0 | 稀疏片头与普通退出 |
| ipad | MI2 / Jellyfin | 64 / 0 | 字幕切换定向 |
| ipad | S01 / device file | 2 / 0 | 稀疏片头与普通退出 |
| ipad | S01 / Jellyfin | 2 / 0 | 稀疏片头与普通退出 |
| ipad | S03 / Jellyfin | 4 / 0 | 稀疏片头与普通退出 |

- iphone13：最终 2026-10-14T17:53:54.764488+08:00，原 24 项非书签偏好逐值保持；检查原 34 个书签，删除 0、轨道字段变化 0，自然书签变化 4。实际正常首页/播放器关闭/空 env/args 已看，WDA idle10/动画2，原生条件 active0；Nastart/WDA/Jetsam 报告集合新增均0。
- ipad：最终 2026-10-14T17:53:55.594851+08:00，原 17 项非书签偏好逐值保持；检查原 27 个书签，删除 0、轨道字段变化 0，自然书签变化 4。实际正常首页/播放器关闭/空 env/args 已看，WDA idle10/动画2，原生条件 active0；Nastart/WDA/Jetsam 报告集合新增均0。

原始偏好/媒体路径/截图/诊断与完整包路径仅保存在本机私有目录，代号 `2026-10-14-mi2-file-ass-recovery-172405`。安全报告：[SUBTITLE-BURNIN-TRANSITION-20261014.json](../../../testing/results/2026-10/SUBTITLE-BURNIN-TRANSITION-20261014.json)。本批没有更改 Mac 网络/VPN、NAS 配置或 WDA 安装。


## 尚未验收

- 本批只关闭上述烧入流叠加文字的定向缺陷；换流约 10.5 秒、iPad 暂停 seek 显示延迟、iPhone 自动候选预热失败及暂停 PGS cue 可用性继续开放。
- S03 双入口 seek/冷续播、旧 HLS 首分片 23.943 秒、S19/完整 L2/L3/19×4/MTP、旧119/PadTS02/13Network、增长 TS、全字幕/音频/HDR/PiP、弱 RF/外部 WiFi、PX/UX/CB/Main 仍沿用原任务总账，不因局部结果标通过。
- 本轮未执行 Lenna/DS One 等竞品新包配对或完整显示帧采样，不判滚动/播放性能 PASS。iPhone18 不在本次两台 USB 设备范围，未安装本包，其最新包和无线回归仍单列待办。
