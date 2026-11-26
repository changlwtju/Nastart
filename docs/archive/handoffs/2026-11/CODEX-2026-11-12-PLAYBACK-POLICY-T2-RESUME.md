# 2026-11-12 播放策略 T2 · NAS 恢复后续测

## 07:04–07:06，iPhone 13，5G

- 用户确认 NAS 已恢复。现场核对 iPhone 13（iPhone14,5 / iOS 16.3.1，USB）真实名称、完整 UDID、当前 App 安装身份与占用。HEAD `8db1cc64`，开工记录的 499 个 iOS 文件无漂移。沿用 [T0 签名 Debug](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)，dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。App 用空参数、空环境启动。复用已核签现装 Runner。
- 系统实图核 Wi-Fi 关闭、5G 图标。Jellyfin 公网现有会话能进入资源库，未提交登录信息。探测 `network=cellular measurementBasis=networkBody sampleBytes=1048576 bodyMs=205 measuredBitrate=40845710`。用户报告当前位置蜂窝偏弱，RSRP、RSRQ、SINR 未测。
- V7 用 S04《好东西》，搜索字段实填正确，但页面四次显示没有匹配内容。未点其他条目，未发出播放。复算输入没有路线记录，归未测。导航每步保留即时偏好诊断及 App 控制台。
- 07:06:00 原 Wi-Fi 勾选和状态栏图标核对通过；07:06:01 核本轮 App、Runner 和转发已结束，余留 App/Runner 数 0。证据目录为私有指针 `/tmp/nastart-codex-playback-device-20261112-current` 下 `phone/t2-resume/`。
- 无代码或参数修改，未跑 App 单测。接续以 [前一窗](CODEX-2026-11-12-PLAYBACK-POLICY-T2.md) 为基线，补 V7、V8、V10 和 HLS 控件时序。

## 07:08–07:10，iPhone 13，5G

- 同一 T0 签名 Debug，fresh USB 及现装 App、Runner、签名和独占核验通过，普通冷启动。Wi-Fi 关闭及 5G 有同窗实图。公网页的 `selectedAddressKind=publicDomain`，Jellyfin 资源库、S19 搜索与详情均实际打开。
- V8 的重启前取样用 S19《护戒使者》、AC3 2 / PGS 9，从 688.501 秒续播。Trace `F0D20BEC` 为 `network=cellular`、`sourceBitrate=75218094`、`capacitySource=preplayProbe`、`capacityBoundsBothSides=false`、`probeCapacity=47010528`、`probeAgeSeconds=58`、`restoredSamples=0`、`playbackCapacity=none`、`renditionLowerBound=none`。探测正文 1,048,576 字节、178 ms。现场判定 `lowerBoundTooFar`，`originalRangeSkipped reason=lowerBoundFarBelowSource`，请求上限 `renditionCeiling=12000000`。
- 续播请求发出后，同秒收到 `playback_failed httpStatus=401 transport=https`，详情另记 `stage=detailPreparation failureMessageKey=jellyfin.player.prepare_access_denied`。本窗未取得 `playback_prepared`、HLS 档位、首帧、交付下界或自动降档。3、10、30 秒图和诊断保留；无播放器完成控件，自动收尾精确结束本轮 App。
- 复算输出 `F0D20BEC … lowerBoundTooFar … unknown … - … ok`，`1 playback(s) with route evidence, 0 to check.`。仅判定可复算；路线和档位列分别为 `unknown` 与 `-`。V8 重启后对照未发出。
- 07:10:21 复核原 Wi-Fi 连接勾选及状态栏图标；07:10:22 本轮 App、Runner、转发、采集均结束，App/Runner 余留数 0。私有证据在同一指针的 `phone/t2-resume-2/`，含 `v8-seed-t30-console-route-report.txt` 和即时取证。

V7 缺满足 15–40 Mbps 的实际样本；V8、V10 和 HLS 切轨及 ±15 秒仍待补。V5 仍只有低于阈值一侧，V6 未触发。此前 V4 的 HLS 起播慢或未出画与本窗播放准备 401 分开记。T4 可用 `explore` 样本为 0，未改系数。无产品代码修改或新单测。T3 可独立进行，T5 仍等 T2 结论和第九节第 5 项决定。

## 07:14–07:22，设备文件入口补查

- iPhone 13 同包回执、USB 和现装 Runner 核验通过，原 Wi-Fi 基线已留。07:14 WDA 切 5G，逐步导出诊断，实际进入 S19 设备文件详情。07:15:09 核详情页有继续观看和从头播放。
- 同一采集看到未由本轮自动化派发的播放 trace `3DB4AE70`。07:18:15 `phase=verifiedStreamMatch result=unavailable`，随后 `addressKind=publicDomain networkClass=cellular playMethod=directPlay routeKind=localRangeProxy`。内部 `firstFrameSignal=playbackClock tapToFirstFrameMs=7604`，07:19:01 `playback_ended` 和上游取消有记录。该次未即时取得动作、可见帧或匹配成功时的探测和档位，作为补充诊断，V10 的已匹配 HLS 分支仍未验证。Jellyfin 路线复算器对此设备文件 trace 无主记录。
- 07:22 原生复核时手机已回到显示 Wi-Fi 图标的其他前台场景，自动窗口和本地 Runner 转发及采集已不在，设备 Runner 数 0。保留现有后台 Nastart，取消未派发的自动化播放，未接管用户前台。该窗原 Wi-Fi 连接勾选未复核。证据在 `phone/t2-v10/`。
- 08:04–08:05 补做只读前台检查，手机未锁但仍是另一前台会话。未打开系统设置，未干扰该会话。只结束自有 Runner 和转发，Nastart 既有后台进程保留。原网络勾选仍待当机空闲时核对。证据在 `phone/t2-v10-wifi-readback/`。
- 08:58 在 iPad 收尾后复核 iPhone 13 USB、现装签名包与前台。手机未锁，另一个 App 仍在前台。未打开设置、切网或派发播放。08:58:25 自有 Runner 与转发结束，保留既有后台 Nastart。原 Wi-Fi 连接勾选和公网播放准备仍待独占窗口。证据在 `phone/t2-wifi-followup/`。
