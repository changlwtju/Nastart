# 双 USB 暂停换字幕候选对齐接续

更新时间：2026-10-12T08:23:04.833385+08:00。本轮用户将 iPhone18 带去上班，只使用 Mac 连接的 iPhone13 和 iPad。iPhone18 未发现、连接、更新或回归；上一轮 a4be 包的首页证据不能归给当前 575947 包。其最新包安装、播放和原生 Xcode 自动隧道仍待后续设备可用时验证。未改 Mac 的 Tailscale、Shadowrocket、配对、系统和设备网络配置。

## 当前源码与安装门槛

- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；保留原有全部未提交修改，iOS dirty diff SHA-256 `575947129f9a0004a61c2136be071dc786f32fd73de2027d2ad9d58146eadec8`。本轮最初 a4be 基线安装/诊断另存 `baseline-package-gate`，不能当作修复包测试。
- 正常 Debug / -Onone，构建时间 `2026-10-12T07:55:40.688892+08:00`；每次普通启动实测 env={}、args=[]，没有性能或测试条件注入。App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-075116/Nastart-AV-Paused-Alignment-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-075116/Nastart-AV-Paused-Alignment-Normal-Debug.ipa`。
- 主程序 SHA-256 `4bb4262b77b1f0b252feae2770cada545a041c738dfa4ebbcb62583e26f57a35`；Debug dylib `fd438ccfce6256597719458af7ae02c223508fffd1ca1a8a9d6e6abb9d265d3b`；KSPlayer `a981b6ce9643d58ef5cbdd81b3f1aa2c1878e6c4e590ee41f1afd510bc3da83c`。
- 173 源输入逐个 SHA/mtime、IPA 三二进制同一性、29 个 dylib/framework 独立签名、App deep/strict、链接已核；最终重核源输入/三 SHA/deep 签名及 diff check。签名截止 UTC `2026-10-17T22:23:40`。
- 现场重新确认名称、型号、系统、UDID、USB、有效固定 WDA/解锁；原始身份仅在私有证据。13 为 iPhone14,5/iOS16.3.1，Pad 为 iPad12,1/iOS18.3.1。07:57:38（13）/07:57:34（Pad）保留数据覆盖当前包，25/16 非诊断偏好安装前后完全一致，实际最新正常首页已查看；未卸载或清登录，也未重装 WDA。
- 本轮实际构建成功；322 测试、2 跳过、0 失败；15 项 preflight。实际 H264 fixture `testOriginalReplacementDecodesPausedPreviewBeforeHandoff` 包含新增暂停候选延后 invalidation 断言，2.725 秒通过。

## 修复与实际定向结果

`GreenfieldVideoPlayerView.swift` 的 AV 候选对齐此前把“不在播放”当成结束准备：已解码静帧且时钟很近，但 itemStatus=0、没有连续缓冲范围时，仍剩约 35 秒截止时间就提前放弃。现在暂停候选保持 pause 并继续 20ms 轮询，仍受原有 40s/20s deadline、generation invalidation、取消和错误约束；readyToPlay、至少半秒连续储备、帧与时钟门槛保留，没有加大超时、放宽 seek 容差或特判片名。

共享播放器增加 `sourceTrackChangeInProgress`，准备结束后将菜单的临时音字幕选择和外部字幕 URL 恢复到实际提交 request；两处调用传入 changingSource。成功切换分支已真机观察，**新包真实准备失败后的菜单回滚负例仍待独立真机验收**，不能用成功分支或此前工具取消代替。

| 设备 / 路径 | 当前包实际观察 | 结论边界 |
| --- | --- | --- |
| iPad S03 设备文件 / AV | 暂停 578.665 秒开启 PGS7：decodedFrame 5502ms 时状态仍未 ready，6544ms aligned 后才提交；实际双语原图已看，保持暂停 | 原失败场景的正常准备成功；非全 SUB/音画验收 |
| iPad S03 设备文件 / AV | 再次确认 systemAVPlayer/localHLS/localRemux 后暂停约 648.653；PGS7 5341→6985ms、关闭 4931→6302ms；两次都有 7.9209 秒连续储备，startsPaused=true | 新鲜 commit 晚于各自操作；实际 cue 显示→消失、稳定关闭原图已看 |
| iPad 普通退出 | UI 恢复原 4/off 后退出保存 648.652342842，最终普通重启回读 648.6516686666666（延后写入差 -0.000674175 秒）；音轨4、nil字幕/off一致 | 此轮无需容器改偏好；保留两次原始值，不宣称精确数值完全相等 |
| iPhone13 S03 设备文件 / KS | 使用实际菜单几何与前台/边界守卫选 PGS7，t30 私有偏好明确7；3/10/30 原图已看，t10实际中英同句可辨；UI恢复 ASS5并普通退出 | 最终465.332秒、音轨4/字幕5开启保存；非 AV 路线或完整字幕格式验收 |

候选日志内部 decoded/aligned 耗时不是用户可见响应耗时，Pad 工具等待 24.357 秒包含 WDA采样/等待/退出，不做性能排名。上轮 PGS OCR 宽差 0.185% 属 a4be 包，本轮不重新宣称该量化结果。

## 保留失败与误选

- Pad 最初关闭字幕后脚本过早退出，候选 decodedFrame1776ms/cancelled=true，旧7正常保留；该次工具取消不计新包正常关闭通过或 App 故障。
- Pad 冷重试实际 KS/directPlay/localRangeProxy，脚本却等待 AV commit，随后复用旧 AFC Device 连接出 SocketError/DeveloperImageNotFound；保留 TOOL 证据，改为每次新建诊断读连接。该原生关闭普通退出保存612.101秒/4/off；最终有效 AV 关闭另行重做。
- 13 首次同名字幕选择误中 ASS5，原命名含PGS的图片不能当PGS证据；所有当时回读均5，该轮标 INVALID_ACTION，正常退出432.382。纠正后实际轨7及真实字幕句、恢复轨5证据独立保存，不丢弃失败样本。
- 最终审计最初要求 Pad 退出与延后持久化位置完全相等，因0.674ms差异拒绝；随后保留原值并明确按 <1ms 比较位置，轨道字段仍逐项精确一致。这是审计精度修正，没有改 App 或设备偏好。

## S01 基础四入口与收尾

两机设备文件、Jellyfin 各普通短播30秒，串行无其他设备同期播放；逐次核对最新源/包/安装收据、现场设备、无变量前台，保存请求/返回时间及0～10/15/30秒原图/XML/诊断。实际3/10/30秒已全部查看：可辨片头及后续天空，未见播放失败提示，普通退出均完成。Pad JF 首次按钮为“在 Nastart 中播放”，13 JF为“从头播放”，各自真实入口保留；不同起点/轨道/缓存不作 A/B性能比较。

最终两机普通重启、实际稳定首页/DS918+ NAS正常/播放器关闭已查看，WDA idle10/animation2已恢复；DSM/Jellyfin在线、部分其他服务警告保留，未将首页所有服务判通过。24（13）/15（Pad）非书签/非诊断偏好完全一致；各三条书签自然更新，原始前后只在私有证据，不写回恢复。S03原轨道按普通UI恢复成功。规范化崩溃文件 basename 比较：两机新报告均0；累计13为Nastart13/WDA0/Jetsam26，Pad为1/1/3。清单未删除。13本轮仍Wi-Fi，不属于蜂窝回归。

这批只完成 L0 和上述 L1 定向/基础观察。稀疏 PNG、内部时钟和无错误不能证明连续流畅、完整首帧/动画/音频/HDR；MTP 并发、L2代表集/L3全矩阵均未验收。无竞品正式配对新增，Lenna仍为13/Pad主对照，其他指定竞品按[设备矩阵](../../../testing/COMPETITOR-DEVICE-MATRIX.md)接续。

## 下一步与全部总账

优先新包真实准备失败的菜单/实际轨道/退出保存负例，再外部字幕、另一字幕格式/代表族及S19压力；补iPhone13真实AV分支与S03 Jellyfin。然后按相同文件、网络、方向和计时边界补Lenna/DS One及完整帧时间，原失败/超时都保留。PX-01～21、UX-01～06及CB、L2/L3/Main现有未验收状态不变；本批关联PX-03/PX-20/PX-21，没有关闭任何全局任务。既有475/119、供流/read/callback/HLS、蜂窝、音画/PiP/Dolby和代表格式缺口继续保留。

脱敏量化：[本轮 JSON](../../../testing/results/2026-10/USB-AV-PAUSED-ALIGNMENT-20261012.json)。完整原始证据及冻结助手：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-075116`。设备名称/UDID、地址/媒体身份、凭据/偏好、截图/XML/原始日志只保留本机私有目录；此处不复制到仓库。
