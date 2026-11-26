# Nastart 播放功能验收矩阵（历史76格＋新iPad38格）

2026-11-21 电视读库、服务详情返回及子页宽度已有源码候选和离线验证，三项修后真机验收均未完成；既有失败及播放验收状态保持。 [电视修正候选](../archive/handoffs/2026-11/CODEX-2026-11-21-TV-THREE-ISSUES-FIX.md)

2026-11-21 Jellyfin 恢复及续播的代码与离线回归已完成。iPad/iPhone 13 S19 同条件实播、seek 与退出书签，以及 iPhone 13/18 交替登录需 Muse 用签名包验收。各格待验状态保留。 [本批交接](../archive/handoffs/2026-11/CODEX-2026-11-21-JELLYFIN-PLAYBACK-AND-SESSION.md)

2026-11-20 新查明 iPhone 13/18 既有备份保存相同 Jellyfin 设备 ID（物理 UDID 不同）；13 当前仍相同。Jellyfin 按账号＋设备 ID 重登撤销旧会话，存在互踢缺陷。今天 13 保存公网会话读库 401，未提交密码；具体撤销操作待服务端日志。S19 设备文件续播有画面但缓冲，采样不完整，窗口已收尾。 原编号/整格状态保持；身份隔离修正及真机回归未完成。 [诊断与接续](../archive/handoffs/2026-11/CODEX-2026-11-20-JELLYFIN-DUPLICATE-DEVICE-ID.md)

2026-11-20 离线回读 11-12 旧包，S19 5G Jellyfin 从头窗首段四次请求未见响应头，设备文件 4G 黑屏窗已收到首个请求的分段并产生内部首帧。11-20 最新包真机播放仍待，风险覆盖保留两处独立待验。 [预检与复盘](../archive/handoffs/2026-11/CODEX-2026-11-20-IPHONE13-PLAYBACK-PREFLIGHT.md)

2026-11-14 iPhone 13 签名 Debug `caa776f8…` 的 4G 冷启动公网读库通过，原 Wi-Fi 已恢复。本窗只验证认证。 [公网冷启动](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-COLD-RESTORE.md)

2026-11-14 iPhone 13 签名 Debug `caa776f8…` 的 4G 公网认证首窗 401，次窗自动恢复读库，无播放样本。原 Wi-Fi 已恢复。 [4G 公网复核](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-PUBLIC-4G.md)

2026-11-14 iPhone 13 原 Wi-Fi 已覆盖签名 Debug `caa776f8…`，有效内网会话直接读库，公网备用 401。本次为安装和认证对照，无播放样本。 [覆盖对照](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-VERIFIED.md)

2026-11-14 iPhone 13 旧包原 Wi-Fi 的覆盖前基线读库返回 401，预填新用户名。本次未播放，签名候选尚未安装。 [覆盖前基线](../archive/handoffs/2026-11/CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-BASELINE.md)

2026-11-14 Jellyfin 公网旧会话处理已通过定向模拟器。尚无新签名包真机读库或播放样本。 [认证与恢复](../archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-PUBLIC-401-RECOVERY.md)

2026-11-14 只读关联 11-13 22:12 与 11-14 09:29 的 Jellyfin 401，两窗均有服务端令牌拒绝。没有新增真机播放样本。 [服务端日志关联](../archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-SERVER-401.md)

2026-11-14 iPhone 13 签名 Debug `c7cf7671…` 原 Wi-Fi，Jellyfin 隔夜内网会话读库通过，公网备用身份探测 401。仅认证证据，本窗无播放复测。 [隔夜读库](../archive/handoffs/2026-11/CODEX-2026-11-14-JELLYFIN-OVERNIGHT-SESSION.md)

2026-11-13 iPhone 13 同包原 Wi-Fi，Jellyfin 《变形金刚》ISO 从 19.187 秒续播，内部首帧 3.223 秒，有实图和音字幕轨 1 / 6。普通退出实见详情且 ISO 资源归零。现场听音与长期会话仍待。 [认证与退出](../archive/handoffs/2026-11/CODEX-2026-11-13-JELLYFIN-SESSION-ISO-EXIT.md)

2026-11-13 iPhone 13 同包原 Wi-Fi，Jellyfin 的《变形金刚》(2007) 与设备文件同名、同 UDF 主片和虚拟长度。Jellyfin 首播内部 2.120 秒、跳转恢复 2.180 秒、普通退出资源归零。续播 64.063 秒起，内部首帧 8.866 秒，10/30 秒图有中文字幕，测试截止原生收尾。22:12 普通冷启动又 401，听音和续播普通退出未验。 [双入口对照](../archive/handoffs/2026-11/CODEX-2026-11-13-TRANSFORMERS-ISO-JELLYFIN-COMPARISON.md)

2026-11-13 同包 iPhone 13 原 Wi-Fi，《碟中谍5》MKV 冷续播内部首帧 7.045 秒，30 秒实图见字幕；《变形金刚2》UDF ISO 内部首帧 1.632 秒，10/30 秒实图有画面，普通退出资源归零。Jellyfin 401 停在登录，实际听音与 Dolby 输出待核。 [补测记录](../archive/handoffs/2026-11/CODEX-2026-11-13-ISO-JELLYFIN-MKV-RESUME.md)

2026-11-13 iPhone 13 最新 Debug `c7cf7671…`、原 Wi-Fi、设备文件。《变形金刚》(2007) ISO UDF 主片首播及续播有实图，+15 内部恢复 8.976 秒，续播 7.320 秒且可见中文字幕。《碟中谍5》55,092,144,234 字节 MKV、DV P7 源，3/10/30 秒出画，+15 内部恢复 4.231 秒。实际 Dolby 输出、听音、ISO Range 响应和 Jellyfin 对照均未验，未关闭整格。 [新样本首轮](../archive/handoffs/2026-11/CODEX-2026-11-13-ISO-MISSION-IMPOSSIBLE-SAMPLES.md)

2026-11-13 同签名 Debug `c7cf7671…`，iPhone 13 原 Wi-Fi 受控 S19 W10 已重现选轨放弃自动降档，手动 KS 原片候选未对齐接管。后续独立 12 Mbps HLS 提交，日志保留 PGS 9，内部首帧 30.045 秒，字幕实图和完整退出未通过本轮验收。复算 5 条、0 不符。 [W10 字幕修正与真机](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-FIX.md)

2026-11-13 最新签名 Debug `c7cf7671…` 已装 iPhone 18，含 W10 字幕接入顺序修正。ISO 专项等待用户下载的《变形金刚》首部样本，当前包该机实播未验。 [安装与样本接续](../archive/handoffs/2026-11/CODEX-2026-11-13-IPHONE18-W10-SUBTITLE-INSTALL.md)

2026-11-13 W10 隔离模拟器的预热层首次接入试验复现轨 9 变为关闭。先完成 URL 初始化、用户明确关闭和同 URL PiP 回挂对照通过。真机字幕保持及听音结论沿用原窗口。 [字幕隔离验证](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-SIM.md)

2026-11-13 iPhone 13 同包 S19 原 Wi-Fi，两次独立降档均提交并保留 PGS 9。20→10 Mbps 窗有实际中文字幕，20→8 Mbps 窗出画且保存轨道，字幕画面未核。每窗复算 2 条、0 不符。WDA 两次未发选轨，旧 W10 体验失败和听音待验保持。 [W10 复核](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-FOLLOWUP.md)

2026-11-13 T5 签名 Debug `6beee7cb…` 的 W1–W10 换源协调行为已有真机证据。iPhone 13 内网受控 12 Mbps HLS 覆盖 W4/W5/W7 服务端跳转顺序及 W6 的旧集输入保护，iPad 补 W6 连点下一集和 W8 本地跳转重试。S19 内网受控 45 Mbps 限速窗 W10 选轨优先通过，46.410 秒内部首帧及后续独立降档丢字幕保留为体验失败。实际听音待核。 [T5 回归结论](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-READBACK.md)

2026-11-13 同包 iPhone 13 原 Wi-Fi 空环境 S19 原片续播，AC3 2 / PGS 9，内部首帧 4.343 秒，第 30 秒实图有简体中文字幕。普通退出前的自动降档候选保留字幕参数，未接管。 [正常续播回读](../archive/handoffs/2026-11/CODEX-2026-11-13-PLAYBACK-POLICY-T5-READBACK.md#原-wi-fi-正常续播回读)

2026-11-12 iPad 签名 Debug `6beee7cb…`，S19 内网正常原片 20→12 Mbps 自然降档实际提交。独立的 12 Mbps Debug HLS 窗验证 W8 选轨被本地跳转打断后从目标位置重试并提交，实图有画面。长距离跳转实际仍走引擎，服务端跳转重叠未验。iPhone 13 同包 Jellyfin 资源库 401，设备文件原片实图有片头和字幕。 [T5](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T5.md)

2026-11-12 iPhone 13 4G、签名 Debug `8025285b…`。《杀死比尔》38.1 Mbps、fits、音轨要求 12 Mbps HLS，23 秒实图出画，内部首帧 15.897 s。设备文件 S19 匹配 10 Mbps Jellyfin HLS，内部首帧 4.619 s，实际显示未验。 [V7/V10](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-V7-V10.md)

2026-11-12 iPhone 13、签名 Debug `8025285b…`、4G，S19 公网 Jellyfin 12 Mbps HLS 冷续播实图、原片试探后 10 Mbps HLS 实际接手、普通重开直接 HLS、前后 15 秒时钟恢复。持续播放与实际显示首帧时延仍待验。 [4G 续测](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-PLAY.md)

2026-11-12 iPhone 13、签名 Debug `8025285b…`、4G，公网 Jellyfin 资源库 401 且显示登录失效。停在播放前，无新增播放验收。 [4G 复核](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-4G-AUTH.md)

2026-11-12 A16 iPad、同签名 Debug `8025285b…`，S19 SMB 原画起播、22.285 秒续播、前后 15 秒及普通退出有真机证据，轨道 1 / 8。分别观测 2.004 和 3.596 秒的 Reader 相关卡顿，保留持续播放失败证据。 [本轮续测](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T3-RESUME.md)

2026-11-12 A16 iPad、同签名 Debug `8025285b…`，S19 SMB 内网原画起播，内部首帧 3.354 s，实图见片头。设备文件原画有 HTTP 交付和内部首帧，30 秒图黑屏。Reader 计时专项留证，续播、跳转及轨道配平未判通过。 [T3](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T3.md)

2026-11-12 NAS 恢复后，iPhone 13 同包 5G 公网 Jellyfin S19 从 688.501 秒续播，在准备阶段返回 HTTPS 401；未产生实际 HLS 档位或首帧。S04 搜索无匹配，未发播放。 [续测记录](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2-RESUME.md)

2026-11-12 iPhone 13 5G 上 S19 4 Mbps HLS 起播及 10 Mbps 续播均见实图。10 Mbps 从头窗约 30 秒仍无首帧，连续播放整格未通过。用户报告 NAS 疑似异常重启，后续真片暂停。 [T2](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2.md)

2026-11-12 同包 iPhone 13 上 5G 公网 Jellyfin 资源库 401，播放前阻塞，原 Wi-Fi 已恢复。Wi-Fi 内网重登成功不产生蜂窝播放覆盖。 [T2](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T2.md)

2026-11-12 iPad、签名 Debug `8025285b…`、家庭 Wi-Fi 内网 Jellyfin、S19 AC3 2 / PGS 9。起播、续播、从头为原片并普通退出，按实际触发核对 20→12 Mbps。续播约 10 s 和 30 s 均实见缓冲，仍无连续播放整格通过。 [T1 实证](../archive/handoffs/2026-11/CODEX-2026-11-12-PLAYBACK-POLICY-T1.md)

2026-11-10 iPad `01a6ec56…` 内网 S19，SMB 实图与中文字幕成立，出画后记录重复缓冲；一段停顿内仍观测约 28 MB 入站载荷。SMB 目标音轨重开、Jellyfin 重开及设备文件样本进入未完成。18 同包仅离线启动，无新增播放验收。 [诊断记录](../archive/handoffs/2026-11/CODEX-2026-11-10-S19-SAME-BUILD-TRIAD.md)

2026-11-10 `01a6ec56…` 的 13 重登 Jellyfin 后 S19 从头原画实图、普通退出与冷启动库恢复。iPad 同包 SMB Debug 346.993 秒以 AC3 2 / PGS 9 出画，有字幕和缓冲。匹配起点与轨道的上轮 iPad 两入口为另一包，114 格无新增完整验收。 [本轮记录](../archive/handoffs/2026-11/CODEX-2026-11-10-IPHONE13-REAUTH-AND-SMB-TRACK.md)

2026-11-10 iPad `f6b9223f…` Debug S19 346.993 秒定点，Jellyfin、设备文件同 AC3 / PGS 实图出画，SMB 保留轨道未配平和画面未核。13 `01a6ec56…` 的域名与内网 Jellyfin 授权均 401，未发出播放。114 格无新增验收。 [本轮回归](../archive/handoffs/2026-11/CODEX-2026-11-10-JELLYFIN-RECOVERY-HTTP-STATUS.md)

2026-11-09 当前签名 Debug `b9a6e09b…`：A16 iPad 的 Jellyfin 内网 S19 正常原流从头出画、有字幕、普通退出；iPhone 13 的设备文件同片原流从头出画、前后 15 秒有引擎恢复、普通退出，跳后实际画面仍未验。13 Jellyfin 库 401 继续保留，114 格状态不变。 [最新回归](../archive/handoffs/2026-11/CODEX-2026-11-09-JELLYFIN-SAME-ACCOUNT-LAN-RECOVERY.md)

2026-11-09 当前签名 Debug `a827696b…`：iPad S19 Jellyfin 两个限速夹具窗均实际从原流切到 HLS、有画面字幕并普通退出，开启组验证复用，未测得提速。13 S19 内网设备文件原画从头出画、前后 15 秒恢复及普通退出；保留缓冲实图和 Jellyfin 播放前 401 失败。无外网或听音证据，114 格状态保持。 [真机回归](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-CANDIDATE-SEGMENT-DEVICE.md)

2026-11-09 合成 iOS 27 模拟器同条件的 HLS 首段复用候选内部对齐成功，关闭探针的窗口保留未解码；七项定向通过。无真机安装、实际候选提交或大文件弱网验收，114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-CANDIDATE-SEGMENT-RETRY.md)

2026-11-09 原画缓冲恢复及 HLS 首段重试补本机合成证据；候选确有解码对照，但未提交切换，无新增真机证据，114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-RANGE-AND-HLS-TIMING.md)

2026-11-09 iPhone 13、A16 iPad 同签名 Debug `807b3c7e…`，内网 Wi-Fi、128.8 GB S19 设备文件原画。13 从头实图、二次缓冲约 8.04 秒后恢复并普通退出；iPad 旧书签 382.253 秒冷续播实图、可见中文字幕及普通退出，4.872 秒为内部首帧。114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-INDEPENDENT-CAPTURE.md)

2026-11-09 18、13 同包 `807b3c7e…`，Wi-Fi 设备文件 128.8 GB S19。从头实画仅 18 有独立图；18 前后 15 秒有内部恢复及普通退出，13 复测触控掉线前未发跳转。114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE18-13-S19-USB.md)

2026-11-09 Matroska 合成五窗验证 Cues 与目标 Cluster 两类等待，归模拟器诊断。iPad 真片新窗口未开，114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATROSKA-CUES.md)

2026-11-09 隔离模拟器以可解码合成 MP4 验证原流尾部索引等待及目标正文慢读，证据归合成诊断；正式大文件和显示首帧结论不变，114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-PLAYER-RANGE.md)

2026-11-09 iPhone 13、签名 Debug `807b3c7e…`、内网 Jellyfin：128.8 GB S19 在 1709.641 秒冷续播并实际出画、普通退出，26.313 秒短断点重开不可见。114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATCHED-SMB-AND-RANGE.md)

2026-11-09 A16 iPad `807b3c7e…` 的 S19 SMB 以相同实际起点和 AC3/PGS 对齐设备文件、Jellyfin 并实际出画。定点使用显式 Debug 参数。HTTP 慢读夹具为传输层独立证据。114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATCHED-SMB-AND-RANGE.md)

2026-11-09 A16 iPad 在 `807b3c7e…` 的显式 Debug 定点窗口，以同一 128.8 GB S19、346.993 秒验证三入口原流出画。设备文件首窗黑屏本次未复现，SMB 与另两路起始轨道不同，作为诊断证据。114 格状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-S19-FIXED-START.md)

2026-11-09 A16 iPad、`fe63a311…`、内网 Wi-Fi 的 128.8 GB S19 补 Jellyfin 原流续播、从头、跳转、DTS/AC3/PGS 选择及普通退出。续播 350.541 秒有画面和 PGS 字幕，未测听音或切换时延。114 格验收状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-S19-JELLYFIN-CONTROLS.md)

2026-11-09 A16 iPad、`fe63a311…`、128.8 GB S19，同机内网三入口原流均有实图。SMB 直连 Reader 补续播、从头、前后跳转、引擎选轨及普通退出。设备文件首窗从 346.993 秒书签重开后黑屏缓冲，353.666 秒的实际引擎起点复测可出画。记录为部分回归和失败证据，114 格验收状态保持。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-S19-THREE-ENTRY.md)

2026-11-09 13 在 `fe63a311…` 使用现有 13.0 GB MKV，验证 SMB 和 WebDAV 原流直连出画、前进 15 秒、普通退出。WebDAV 使用 Wi-Fi 域名，未测对端，暂不作内外网归类。保持 114 格验收状态。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-READER-SMB-WEBDAV.md)

2026-11-09 共享代理 Reader 以合成影片核解码、有限窗、撤销和正文完整性；14 项定向通过。NetworkMedia 包测试 30 通过、6 SMB 外部夹具跳过。A16 iPad 与 13 已保留数据覆盖 `fe63a311…`；iPad 的内网 SMB、FTP 用同一 13.0 GB MKV 核了直连起播、前进 15 秒和普通退出，13 用 128.8 GB S19 核 Jellyfin 原流短播。保持 114 格验收状态。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-NETWORK-READER-PROXY.md)

2026-11-09 最新签名 Debug `a444e8d9…` 的 iPad S19 设备文件同包对照，实测普通 Wi-Fi、原流、片头和相同音字幕，实验接手并送出 14,147 字节，首段未重复。13 Jellyfin 的同包对照实际交付 34,441 字节，无 ETag、首段未重复。四窗有实际画面及普通退出；Pad 906/649 ms、13 952/785 ms 都是内部首帧。20 项合成定向通过。此窗不测实际听音或显示首帧时间，114 格无新增通过。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-ORIGINAL-RESPONSE-HANDOFF.md)

2026-11-09 10:02 iPad 同一临时签名包原流对照，同片片头、同轨道和 Wi-Fi，两窗普通退出。启用组实际预读 0、未改变首个 Range，首帧为内部计时。恢复正常包并验证首页，114 格无新增通过。 [iPad 对照](../archive/handoffs/2026-11/CODEX-2026-11-09-IPAD-ASYNC-PREFIX-AB.md)

2026-11-09 09:55 两机同一正常签名 Debug 的 S19 原流短播覆盖 Jellyfin、设备文件和普通退出。四窗共 12 条真实 206，补上版本标识和路由证据。未做预读对照、听音或显示首帧，114 格无新增通过。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-ORIGINAL-VALIDATOR-AUDIT.md)

2026-11-09 09:37 新建空白模拟器最终 9 项通过。合成 H.264 的 KSPlayer 预读消费、跨窗字节一致、版本变更与撤销通过。无真机、NAS、真实屏幕首帧或速度证据，114 格无新增通过。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-ORIGINAL-PREFIX-PROOF.md)

2026-11-09 09:25 13 用同一签名 Debug 实验包、Wi-Fi 和 App 限速，S19 片头 AC3/关字幕，两轮原流至 HLS 均提交、截图可见标题、普通退出。目标分别 10/12 Mbps，切换后各一次缓冲。显示首帧、听音、长时及自然网络未验，0 新增整格通过。正常包 `542e9d2f…` 已恢复并启动加载资源库。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-HLS-COLD-LEAD-AB.md)

2026-11-09 08:49 iPhone13 `542e9d2f…` 同片片头/AC3/关字幕完成两轮 App 进程限速。两轮均从原流自动切到 12 Mbps HLS，清单 13.74/12.16 秒，首次提前 11 秒后解码至对齐仍等 5.04/7.38 秒。正常退出并收尾，未测实际显示首帧或听音。下一窗只改变首次提前量并配对观察；默认内网自然降档和预读仍待。 [回归记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-HLS-COLD-LEAD-REPEATS.md)

2026-11-09 08:36 13 签名包 `542e9d2f…` 的 S19 内网默认原流窗未自然降档。独立 Debug 12 Mbps HLS 窗完成 AC3 和字幕关闭替换，确认第二候选采用首窗渲染准备耗时加 150 ms，内部对齐 11.60 / 7.70 秒，两窗条件有差异。普通退出与自有设备窗口收尾已核。自然降档配对、显示/听音及预读待续。 [回归记录](../archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-HLS-REPLACEMENT-REGRESSION.md)

2026-11-09 `542e9d2f…` 普通 Debug 在 13/Pad 保留覆盖。S19 128.8 GB，Pad Jellyfin 冷启动、实际原流画面、续播/从头、前后 15 秒、引擎选轨和普通退出；13 设备文件原流续播和前后跳转，保留缓冲截图。13 Jellyfin 正确账号后仍 401。声音、显示首帧、HLS 候选切换与完整帧时间未验，114 格无新增整格通过。[当轮证据](../archive/handoffs/2026-11/CODEX-2026-11-09-IPHONE13-JELLYFIN-RESUME.md)

2026-11-09 [同环境三入口补测](../archive/handoffs/2026-11/CODEX-2026-11-09-SHARED-NETWORK-PLAYBACK.md)：892228ff正常Debug已保留安装13/Pad，五项隔离测试过。Pad S19 128.8GB的JF/设备文件/SMB均实画及普通退出/续播/从头/跳转/轨道选择；13文件补验、JF401。真实默认路径wifi/非昂贵/非受限，来源共用规划/KS/原流代理。不同落点与轨道/缓存窗不排名，仍有缓冲；非Release/完整听音/帧时间/HDR/长时或蜂窝验收，114格0新增整格P。

2026-11-08 [共享代理第一步](../archive/handoffs/2026-11/CODEX-2026-11-08-NETWORK-SOURCES-SHARED-PROXY-PHASE1.md)已接入。最终6项隔离测试通过，正常97b3保留安装13。LAN FTP 5.47GB MKV《赌侠》实际播放和前进15秒恢复，206、同trace桥接交付、预读0均有证据。普通退出未验证，原生收窗。A16 Pad未连接，最新包未装。第二步、预读及声字幕/帧时间/长时仍待，0新增整格P。

2026-11-08 [Jellyfin恢复及TV连接](../archive/handoffs/2026-11/CODEX-2026-11-08-JELLYFIN-LOGIN-AND-APPLE-TV-CONNECTION.md)。13同源bb4d保留安装，用户重登后资源库/搜索/详情恢复，《赌侠》原流短时实际画面由两种截图证实。续播、seek、声音、字幕、普通退出及全程帧时间待验，预读仍0。客厅TV认证配对成功，重启后开发连接仍不可用。30项/114格无新增验收。

2026-11-08 最终包补核（[同批记录](../archive/handoffs/2026-11/CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)）：8+5+1方法分批通过，异常交换12次，继承夹具失败与修正均保留。测试文件补改后的正常重构建哈希不同，最终bb4d已在13/Pad再次fresh保留安装、默认正常首页实看并收窗，安装时全偏好同/最终仅诊断变；最新包0播放。627c FTP图和失败只是上一候选基线，不当bb4d最新回归；代理第一/二步与可消费预读仍待，30项/114格不关闭。

2026-11-08 [627c最新包基线](../archive/handoffs/2026-11/CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)：13/Pad均fresh身份保留数据安装，13 FTP《赌侠》5.47GB MKV/HEVC1080p/AC3有t3/t30不同实际片头图；仅稀疏图，不验声音/字幕/帧时间。内部first_frame2193ms不当显示首帧；seek/正常退出控制未验，native最终停止。JF401/文件目录空UI/Pad手动入口未完成分别保留，Pad0播放。预读0字节仍在，第一代理未接；0新增P、114格保持。

2026-11-08 [接续核对](../archive/handoffs/2026-11/CODEX-2026-11-08-TRANSITION-INTAKE.md)仅本机源/签名产物与22个SMB符号绑定复核，0新播放/真机/NAS窗口，114格无新P。Claude报告的13 FTP/SMB/WebDAV与JF/文件有限样本按原归属接收，首帧时钟/提交事件与实际显示、轨道事件与声音分别保留。样本下载/杜比与音频输出/iPad协议配置、长时/弱网继续选覆盖。

2026-11-08 [共享代理方案审查](../archive/handoffs/2026-11/CODEX-2026-11-08-SHARED-PROXY-PLAN-REVIEW.md)以网络环境统一链路为目标，FTP/SMB用LAN。只读代码和原样Range探针，无真机/NAS/播放/新帧时间样本；0新增P。11-07 Claude小样本播放数据为交付陈述，NAS同时下载/刮削及部分并发窗不作本批配对收益或完整帧时间验收。后续同源正常包按容量/容器/真实路由/网络风险选样，两机顺序并保留错误/超时。

2026-11-04 [目录导航UI回归](../archive/handoffs/2026-11/CODEX-2026-11-04-FOLDER-PICKER-INTEGRATION.md)：仅iOS目录页面导航及DEBUG内存夹具；13/Pad最新保留安装与签名Runner过，iPad有限交互通过、13子目录后超时未验收。0播放/本批NAS命令/新帧时间证据，未改播放解析/引擎/请求路线，114格无新P，历史失败/待验保留。

2026-11-03 [UI 集成核对](../archive/handoffs/2026-11/CODEX-2026-11-03-CLAUDE-UI-INTEGRATION.md)：TV 播放控制仅字体变化，未改解析/引擎/请求路线；六配置、包/宿主测试及签名包不构成播放验收，本轮 0 真机/播放/NAS，114 格无新 P，旧失败/待验保留。

2026-10-31 [共用WebDAV字段语义](../archive/handoffs/2026-10/2026-10-31-SHARED-WEBDAV-FIELD-ACCESSIBILITY.md)仅无障碍元数据及编译；0播放/新真机回归，114格无新P，旧失败/待验不变。

2026-10-31 [原生事件与返回记忆](../archive/handoffs/2026-10/2026-10-31-NATIVE-FOCUS-EVENT-ORDER-AND-MEMORY.md)41单元及关闭诊断6唯一UI+fresh2例仅覆盖合成焦点/滚动/弹层；未创建播放器或媒体请求，114格无新P，旧失败/真机待验保留。

2026-10-31 [弹层返回与焦点反例](../archive/handoffs/2026-10/2026-10-31-DETAIL-PRESENTATION-RETURN-AND-FOCUS-REGRESSION.md)两轮合成UI未全过，动态恢复/跨区记忆仍开放；合成全屏不创建播放器，不等于媒体退出/海报闪动验收，114格无新P。

2026-10-31 [动态详情与长列表](../archive/handoffs/2026-10/2026-10-31-DYNAMIC-DETAIL-FOCUS-AND-LONG-ROWS.md)仅焦点/目标滚动：39单元、4最终合成遥控用例不含实际编辑、媒体播放、图片读取或帧时间；前4轮失败保留，114格无新P。

2026-10-30 [限制说明批](../archive/handoffs/2026-10/2026-10-30-SHARED-PLAYBACK-LIMITATION-NOTICES.md)只解释已有能力，4参数测试/9静态窗不构成真实canPlay、ISO支持或播放验收；114格无新P。

2026-10-30 [共用文件字段批](../archive/handoffs/2026-10/2026-10-30-SHARED-FILE-INFORMATION.md)只展示/焦点逻辑，4参数测试、本机模型/方向函数及6静态窗不构成实际播放/遥控/展开验收；114格无新P。

2026-10-30 [多文件选择批](../archive/handoffs/2026-10/2026-10-30-SHARED-MULTI-FILE-SELECTION.md)仅展示与原动作搬位，22测试/6静态窗不等于真实选片/播放、ISO支持、方向或滚动验收；114格无新P，真机/NAS继续暂停。

2026-10-30 [电视季网格批](../archive/handoffs/2026-10/2026-10-30-TV-SEASON-POSTER-GRID.md)仅展示，24测试/5静态窗不构成播放、真实焦点/返回或流畅验收；114格无新P，真机/NAS仍暂停。

2026-10-30 [剧集/简介批](../archive/handoffs/2026-10/2026-10-30-SHARED-EPISODE-ROWS-AND-SYNOPSIS.md)仅布局/空文本/进度表面，22既有测试/10有效静态图不是实际媒体/播放、方向焦点或流畅验收；114格无新P，候选未装。

2026-10-30 [文件夹编辑批](../archive/handoffs/2026-10/2026-10-30-FOLDER-EDITOR-CONTEXT-AND-NOOP.md)仅无NAS编辑提示/等价路径保护，22临时测试/12静态图非真实目录/提交或播放验收；候选未装，114格无新P，旧失败保留。

2026-10-30 [演职状态批](../archive/handoffs/2026-10/2026-10-30-MEDIA-DETAIL-READ-STATES.md)仅网络库补读状态与展示，26测试/9静态图非实际图片或播放回归；候选未装，114格无新P，旧失败及横滑/TV焦点未验保留。

2026-10-29 [人物焦点批](../archive/handoffs/2026-10/2026-10-29-SHARED-PEOPLE-SCROLLER-AND-TV-FOCUS.md)仅展示/组件接线，3静态窗与6既有测试不代表横滑、真实图片或播放；横滑无位移/TV交互超时保留，114格无新P。

2026-10-29 [人物卡/本地返回](../archive/handoffs/2026-10/2026-10-29-SHARED-CAST-CARDS-AND-OFFLINE-RETURN.md)仅展示和夹具往返：6测试、10组件图及静态恢复不含真实图片/返回闪动或播放。双签名Debug/无签名Release编译过、候选未装；0NAS/真机/性能窗，114格无新P，旧故障/待验不变。

2026-10-29 [媒体头图/标题精修](../archive/handoffs/2026-10/2026-10-29-ADAPTIVE-MEDIA-HERO-AND-POSTER-TITLES.md)只有共用展示布局，6测试和12隔离组件窗（Pad真旋转横屏2）不含真实图片/播放。双签名Debug/无签名Release编译过，候选未装；0NAS/真机/性能窗，114格无新P，原故障/待验不变。

2026-10-29 [隐私摘要/提示精修](../archive/handoffs/2026-10/2026-10-29-SHARED-PRIVACY-SUMMARY-AND-RESET-PROMPT.md)仅范围显示和确认入口，4参数测试及12画面不含真实清除、连接或播放。双签名Debug/无签名Release编译过、候选未装；0NAS/真机/性能窗，114格无新P，旧失败/待验不变。

2026-10-29 [Plus概览精修](../archive/handoffs/2026-10/2026-10-29-SHARED-PLUS-OVERVIEW-AND-ACCESSIBLE-CARDS.md)仅显示层/Debug预览，4参数测试及12画面不含真实会员或播放。双签名Debug/无签名Release编译过、候选未装；0NAS/真机/性能窗，114格无新P，历史失败/待验不变。

2026-10-29 [共用帮助精修](../archive/handoffs/2026-10/2026-10-29-SHARED-HELP-TOPICS-AND-ARTICLE-POLISH.md)：仅帮助内容/正文和Debug预览，4场景测试及12离线画面不含实际播放/网络。双签名Debug/无签名Release编译过，候选未装；0NAS/真机/性能窗，114格无新P，历史失败/待验不变。

2026-10-29 [WebDAV表单精修](../archive/handoffs/2026-10/2026-10-29-WEBDAV-FORM-POLISH-AND-OFFLINE-PREVIEW.md)：只改共用连接表单/Debug预览，24模块过及24稳定背景隔离窗不含真实连接或播放。双签名Debug/无签名Release编译过，候选未安装；0NAS/真机/性能窗，114格无新增P，历史失败和待验不变。

2026-10-29 [设置入口与默认项共用](../archive/handoffs/2026-10/2026-10-29-SHARED-SETTINGS-CATALOG-AND-DETAIL-ROWS.md)：正式Mine/TV设置直接用同一6项清单及暖色标签；播放器默认两行共用，iOS保留本地化、大字上下排，TV仍原卡片/真实目的页。6既有源/433输入、4场景测试与双模拟器Debug/签名Debug/无签名Release过，25最终离线预览窗文字过/抽图实看，非完整设置与遥控验收。原并发白屏和明确磁盘满分别保留，清12个未安装中间包、5个任务实例，最终两候选已重新冻结未安装。0NAS/真机/播放/新114格P；下一设置子页与连接表单，仍6.1。

2026-10-29 [离线媒体场景](../archive/handoffs/2026-10/2026-10-29-OFFLINE-MEDIA-UI-SCENES.md)：三端共用Debug合成数据与真实媒体组件，@main先选隔离根再创建普通账号/同步；4模块过、双模拟器Debug/签名Debug/无签名Release编译过，433输入同，30最终模拟器窗页文字核对成立、抽图已看，失败原样保留。30/27签名候选未装真机，0NAS/真实播放/114格新P；只覆盖媒体组件/状态，四Tab/完整设置/大字/交互仍待。用户进一步限定未来数日打磨细节，全部真机/NAS等恢复后；按[场景规范](../testing/OFFLINE_MEDIA_UI_SCENARIOS.md)继续，仍6.1。

2026-10-29 [设置说明修正及NAS独立清单](../archive/handoffs/2026-10/2026-10-29-NAS-INDEPENDENT-AUDIT-AND-FIRST-FIXES.md)：只调整引擎说明与TV设置顺序，双普通Debug和1项既有可用性测试过，当前新包未安装/未做视觉或播放验收；430输入同，无NAS/蜂窝/真机窗口，114格不增加P。前批126通过/1PiP跳过和Release编译仅属09:20源，不自动升级为本批新源验收。

2026-10-29 [离线整合恢复／共用跳转执行](../archive/handoffs/2026-10/2026-10-29-SHARED-SEEK-COMMAND-EXECUTION.md)：用户将NAS处置留到回家，重新授权离线App统一；NAS访问/真机安装调试仍暂停。PlaybackSeekCommandExecutor实际接移动AV/KS与TV AV/KS，同一主线程准入/清待完成/读最新意图/时钟更新；受控旧TV暂停被autoPlay覆盖红测保留并转绿，原生遥控最新意图亦覆盖。430输入/双签名Debug及无签名Release编译过，32共用/61TV全过，移动33过1PiP模拟器跳过；30/27 Mach-O核签候选未安装。0NAS/设备/蜂窝/新性能窗，114格无新P；原生renderer/预热和服务端协商仍适配，未改库核心/性能参数，仍6.1，旧凭据/SID不自动复用。下方事件“开发暂停”为此前中断状态，仅离线开发现已恢复。

2026-10-29 [NAS勒索事件／开发暂停](../archive/handoffs/2026-10/2026-10-29-NAS-INCIDENT-AND-DEVELOPMENT-PAUSE.md)：用户报告NAS文件加密并提供勒索说明照片；实际变种、入口、范围未知。人在单位，可请家人断网，倾向直接关机后回家干净重建并可接受数据损失；关机/隔离尚未确认，助手0NAS操作。当前项目1438文件和本地Git6127blob对已知凭据三种表示均0命中，但私有明文JSON及此前HTTP/聊天风险确实存在，不能排除或归因；两份已核文件权限收紧0600、内容/证据保留。开发暂停：中断的共用seek执行器只32模块测试过，TV红测旧源复现失败留存，绿色接入/当前源码构建未做；最后已验包仍428旧候选，不能代当前源码。0新真机/蜂窝/性能P，旧凭据/SID不得自动复用，后续NAS操作须用户重新授权。

2026-10-29 08时[共用seek与换源边界](../archive/handoffs/2026-10/2026-10-29-SHARED-SEEK-AND-HANDOFF-BOUNDARIES.md)：Container Manager仍修复，本批继续离线；PlaybackSeekState实际接移动AV/KS和TVAV/KS，统一待完成目标/边界/迟到回调/失效，TV片尾对齐手机既有0.1秒余量；PlaybackHandoffBoundary共用seek/PiP规则，TV候选等待中新时间线会弃旧保原。428输入/双端签名Debug与无签名Release编译过，26共用/55TV全过，移动34项33过1因模拟器PiP跳过。签名包已冻结未安装，0真机/NAS/蜂窝/性能窗，不增114格P；原生命令执行、完整换源适配与最新播放意图竞态继续待核，未动库核心或性能参数，仍6.1。

2026-10-29 07时[共用会话资源批](../archive/handoffs/2026-10/2026-10-29-SHARED-PLAYBACK-SESSION-LIFETIME.md)：用户报告Container Manager修复，暂停NAS/真机，优先离线整合。新增同一个PlaybackSessionLifetime接移动Greenfield模型及TV共用宿主，统一初始/替换交付、退出失效与串行释放；移除两套无引用TV旧会话。移动原换源执行移出DEBUG，fallback结束使用实际安装计划。426输入/双签名Debug及无签名Release编译过，18共用/54TV/15移动定向分别过；首移动测试UUID断言失败原样保留后修正夹具复验。双包已冻结签名、未安装，仍保留前批设备包。0设备操作/0NAS探针或登录/0蜂窝/0性能窗口，不增114格P；原生renderer控制及部分换源适配仍需收敛，未宣称全部同源或大文件优化完成，继续6.1。

2026-10-29 [电视未连接页面与无线更新](../archive/handoffs/2026-10/2026-10-29-TV-DISCONNECTED-PAGES-AND-WIRELESS-UPDATE.md)：TV“我的／连接管理／设备”统一主题卡片和资源／维护分组，未登录DSM仍可进网络媒体库，复用既有展示与播放器。仅TVNASViews变化，424冻结一致、签名Debug及无签名Release编译过；06:53最新TV保留数据安装、15偏好同，四个实际页面及普通首页已核。18按新授权06:45无线覆盖最新移动包、27偏好同，仅安装不启动，实际DSM域名会话未复验。TV遥控现已恢复；内网DSM首需两步验证，用户验证码提交后通用连接失败，未登录、根因未明，无认证探针200仍不代表认证成功。工具/自有Runner收尾、普通首页已核。0播放/0蜂窝/0NAS媒体写、不增114格P；旧播放失败及完整renderer收敛继续开放，仍由6.1执行。

2026-10-29 [统一接入批](../archive/handoffs/2026-10/2026-10-28-UNIFIED-PLAYBACK-INTEGRATION.md)：TV三入口共用宿主并直接引用移动规划/协调/续播/KS原值配置；移动正式视频入口已去DEBUG分叉。双端签名Debug及无签名Release编译通过，31项NetworkMedia、52项TV、9项移动定向测试通过；初始夹具/驱动失败保留。424输入最新包已保留数据装13/Pad、普通首页与原偏好同。13约128.8GB WebDAV有真实画面、暂停/继续/返回，但约1MB/s及转圈仍在，不作性能通过。TV仍首版423包，遥控系统中断/未重登DSM，已一次请求重启；18离家零操作。Pad第二窗亦有实际画面，随后DTX断开，独立停流/普通首页已核，控制/退出未验；完整跨平台renderer生命周期及各机各入口/Release实测仍待，继续6.1接入验证，之后才Astra核心优化。

2026-10-28[来源接线与证据复核](../archive/handoffs/2026-10/2026-10-28-PLAYBACK-SOURCE-CONTEXT-PRECHECK.md)：6.1修正存储与媒体→JF只传当前地址的问题，改交同一服务完整候选；普通Debug/13定向测试过，13保留数据更新/普通启动，JF入口有界等待未就绪，0播放/0切网，切网原失败待验。旧两窗目标字幕实际在约12秒提交；菜单失败/提前恢复不等功能失效，原失败保留。两条测试残留字幕书签已定向恢复、覆盖及普通启动后再核；419输入本批单行来源接线变化，核心未改、无新114格P，继续6.1。


2026-10-28[有限优选结论](../archive/handoffs/2026-10/2026-10-28-PLAYBACK-ROUTE-SELECTION.md)：6.1 Sol基于13当前普通Debug的S19约128.8GB Wi-Fi/4G及38.6GB H264/M2TS有限证据，选定设备文件/Jellyfin现有Greenfield共用核心，KS原流优先＋必要AV/HLS兼容，供各来源/三端统一；不宣称入口全面最快。18个窗口含失败/截止，音轨物理响应、字幕异步切换、同点续播及三端/Release仍有缺项。第二次NAS重启等待997秒后单次HEAD有响应，13再次同包覆盖/普通启动，JF代表格式入口未就绪不作播放失败；21:00自有媒体停止、原Wi-Fi实连/图标、工具设置恢复/会话清理已核。419源码零漂移、统一尚未实现、114格不增P；用户随后明确当前保持6.1，先收窄证据/改动/验收，仅关键核心优化任务就绪时再提示切Astra6（详见同批交接末节）。


2026-10-28[真机优选首窗](../archive/handoffs/2026-10/2026-10-28-PLAYBACK-ROUTE-SELECTION.md)：用户限定大体积/代表格式、有限优选由6.1 Sol执行；13最新普通包fresh覆盖/偏好同，S19已实测KS原流→自动12Mbps AV/HLS，不能按纯原流排名。首seek工具404、0有效seek/主动停止均保留。18:50用户报NAS死机，已停自有App/恢复设置/删自有会话，未切蜂窝；等约十分钟重启后先核服务，不密集重连。未改播放实现、无优胜/新114格P。

2026-10-28[播放链路统一准备](../archive/handoffs/2026-10/2026-10-28-PLAYBACK-UNIFICATION-PREPARATION.md)：核六条实际路线及历史对照限制，419源码零漂移；现有26项准备/取消/WebDAV边界测试独立重建通过，首次skip-build缺二进制失败保留。未改播放实现、未新装包或开始真机/蜂窝窗口，无性能优胜或新114格P。准备材料完成；真机对照与链路优选仍由6.1 Sol执行，优选后的核心修改/优化才提示切Astra6。

2026-10-28[独立连接与原子编辑](../archive/handoffs/2026-10/2026-10-28-SAVED-CONNECTIONS-AND-ATOMIC-EDITING.md)：连接独立保存/旧库关联迁移、添加与编辑共用HTTP/HTTPS等表单、关联目录分区和全部关联库事务已接；旧库/原凭据保留。全215测试过/419输入双普通Debug，13/Pad/TV保留数据安装，三端编辑预填/取消与目录草稿取消过；13新包真实1文件A→B保存、墙更新及清临时库后完整迁移基线同。首诊断BrokenPipe/旧分隔符清理失败保留，独立清理及复验通过；连接改名原生输入超时未提交/原索引同，地址账号和多库提交仍待。原库149/3408/3408完整资料除新增connectionID外同，TV配置迁移变化单列/其他偏好同。用户已带走18，本轮零发现/安装/控制。0播放/NAS源写、30项14/5/11与114格不变。
2026-10-28[竞品连接参考与目录浏览](../archive/handoffs/2026-10/2026-10-28-STORAGE-REFERENCE-AND-FOLDER-BROWSER.md)：实际观察13 Infuse新增WebDAV表单/高级项、已有FTP目录及收藏重命名草稿取消；爆米花仅更新提示/TV仅清单，不夸大参考。三端共用添加来源选择、已有WebDAV登录复用、连接管理媒体文件夹入口及浏览选择路径草稿；独立连接/地址账号编辑仍未做。35定向0失败、418输入双普通Debug，13/Pad/TV保留数据更新及新流程草稿→取消/末首页实图过。TV前三驱动失败保留，fresh索引纠正旧movie预期后过；当前3408配置覆盖前已存在，不恢复旧149。13/Pad索引同旧批，TV同fresh3408基线，三机偏好同。18本批两次无线发现失败未安装，最后确认上一详情包。0播放/0目录提交/0NAS写，30项14/5/11及114格不变；FTP/SMB/全会话/Pad退出继续开放。

2026-10-28[详情信息区共用](../archive/handoffs/2026-10/2026-10-28-DETAIL-INFORMATION-LAYOUT.md)：MediaDetailInformation实际接移动/TV Jellyfin与网络库，统一演职→制作→推荐→来源/文件的顺序、制作文本和分区间距；TV演职标题共用Section，原遥控焦点保留。36资料回归过/418输入双普通Debug，四机保留数据更新，18仅无线安装。13/Pad/TV两入口同片实图已核，TV演员焦点往返成立；父级标记覆盖子级的中间失败已修正并保留，Pad另补视口实图，不以AX可见冒充屏幕可见。三机完整索引/原偏好同，0播放/0源文件写/无新114格P。用户再次要求完整参考Infuse/爆米花的连接与文件夹添加修改流程，下一优先落实该项，不能把此前有限首页观察算完成。

2026-10-28[共用准备执行与取消清理](../archive/handoffs/2026-10/2026-10-28-SHARED-PREPARATION-COORDINATOR.md)：PlaybackPreparationCoordinator实际接WebDAV双端/TV Jellyfin，统一初始执行、重复准入、当前性检查、迟到结果释放和当前错误；取消后的释放在独立未取消Task中执行且等待完成。65定向0失败、418输入双普通Debug，四机保留数据更新，18仅无线安装。13 WebDAV/TV两来源有限实播与正常返回已核，TV焦点Select暂停继续成立；Pad仅最新首页，旧416在播控制栏观察失败/主动停止保留，普通退出仍待。三机完整索引与原偏好同，无NAS写/114格新P；完整生命周期/FTP/SMB仍开放。

2026-10-28[共用播放准备](../archive/handoffs/2026-10/2026-10-28-SHARED-PLAYBACK-PREPARATION.md)：新增PlaybackPreparationGate并实际接WebDAV双端/TV Jellyfin，统一初始重复请求/取消迟到交付准入，源取消/释放仍由宿主负责。44＋14无重叠共58测试过，416输入双普通Debug/四机保留数据安装，18仅无线不启动；13 WebDAV与TV两来源同片名就绪后有限播放/正常退出已核。Pad3/10实帧成立但正常退出仍待，AX/驱动失败及主动停止均保留，最终首页/工具清理已核。三机149/3408/149索引完整JSON及原偏好同，无NAS写/114格新P；完整会话及FTP/SMB仍开放。

2026-10-28[真实目录切换](../archive/handoffs/2026-10/2026-10-28-NATIVE-FOLDER-SIBLING-VALIDATION.md)：414普通包13临时库实际从《哈尔的移动城堡》目录改到《碟中谍3》，新UUID/同名/1文件及海报更新实看，移除临时库后原149索引完整JSON同/26偏好同。TV两失败保留，实际单目录临时库成功但更多超时，已清理/原149索引同，真实保存仍待；v2目录仅编码字节差/JSON同，其余偏好同。0视频/0NAS写/114格不增P；后续共享准备候选源码正在构建，不拿414图作新版回归。

2026-10-28[端点凭据与人物图片](../archive/handoffs/2026-10/2026-10-28-ENDPOINT-SCOPED-CREDITS.md)：修复多地址已有登录凭据不同而误拒补图，精确编号/每端点自身凭据。13/Pad/TV同片真实人物照均已实看，缺图仍占位；Pad/TV保留原生等待后编辑预填→取消回墙通过，旧误导航/超时保留。Pad3,408/TV149索引完整JSON同、原偏好同。414输入/双普通Debug/39定向0失败，四机保留数据安装，18仅无线安装不控制。0播放/0 NAS写，不增114格P，UX-08/09仍进行中，完整播放会话/FTP/SMB继续开放。

2026-10-27[修改文件夹与共用操作](../archive/handoffs/2026-10/2026-10-27-LIBRARY-FOLDER-EDIT-AND-SHARED-ACTIONS.md)：414输入/双普通Debug/39定向0失败；WebDAV默认海报墙、移除独有列表、Jellyfin与网络库共用更多/刷新，新增完整路径先扫描后事务替换。13真实错误保149→原路径验证约160秒成功/绝对源文件集合相同；Pad/TV菜单与预填编辑实图成立，但取消未验、即时AX失败保留。四机最新包保留数据安装，18按用户使用中限制只安装不启动。TV头像样本9真实/1占位，13指定影片仍占位需定位，不能关闭头像项。无NAS写/新播放P，完整会话/FTP/SMB仍开放。

2026-10-27[图片返回与18无线更新](../archive/handoffs/2026-10/2026-10-27-ARTWORK-RETURN-STABILITY-AND-IPHONE18-UPDATE.md)：411输入普通Debug，TV有限3/10秒/暂停继续/同PID普通退出和回墙；秒级截图非逐帧闪烁验收。13UI被外部前台打断/0播放，18安装及普通启动图通过不当播放通过，Pad不可连接。27缓存/资料定向，114格不新增整格P，头像仍待。

2026-10-27[三端网络库精简与原盘资料补读](../archive/handoffs/2026-10/2026-10-27-COMPACT-LIBRARY-AND-CONSISTENT-CREDITS.md)：按用户新反馈，三端共用网络墙移除居中重复名、顶部统计和分类数量黄框，详情统一演职区/导演角色及制作文本，文件信息共用Disclosure默认折叠，移动Jellyfin同组件/去重复片名。修复BDMV详情遗漏影片目录NFO，复用扫描实际规则且读前后核版本/根范围/身份；19资料＋39分类图片只读定向回归过，双普通Debug/409输入。TV9c9012f…20:45:37、移动d5cfec4…13 USB20:45:55保留数据更新，TV普通片/原盘和13实图及文件信息展开已核；原盘缺本地封面仍未解决。Pad不可连接、18通话现场等待空闲回复，无最新包验收；播放会话迁移未实施，本轮0播放命令，不增114格P，30项14/5/11保持。

2026-10-27[共用媒体展示、离线资料与设备更新](../archive/handoffs/2026-10/2026-10-27-SHARED-MEDIA-PRESENTATION-AND-WIRELESS-UPDATE.md)：实际抽出共用海报卡/网格/标题工具栏、详情hero/资料/简介/操作/人物组件并接入原Jellyfin与网络入口；TV共用播放控制呈现/KS仅渲染，完整会话链尚未统一。NFO丰富资料15定向、图片11＋4分别过；双普通Debug/409输入，最终包身份及逐机安装/阻塞见归档。TV/13真实WebDAV电影详情实图与有限播放/正常退出成立；13同片Jellyfin对照发现子页主题丢失，最终20:12主题修正版已TV/13覆盖并实看；最终完整索引/15、26偏好同、409输入零漂移，普通首页实看/自有会话恢复删除/原Runner保留。Pad/18当前未装最终包。原索引及偏好保持，旧编译/入口/Pad菜单与自动隐藏失败保留，听音/精确源帧/全格式/Release未验。UX-08/09进行中，30项14/5/11、114格无新增整格P。

2026-10-27[音轨区分与iPad暂停跳转](../archive/handoffs/2026-10/2026-10-27-DISTINCT-AUDIO-TRACKS-AND-IPAD-PAUSED-SEEK.md)：TV与移动触控面板补音轨序号/源标题/当前选择，原ID及选择动作保持；TV/iPad真实WebDAV三轨切换恢复与普通退出实图成立。Pad另窗暂停18→33→18、保持暂停/实画变化、恢复播放及同PID退出有限成立，精确源帧/听音未验。399输入/双普通Debug；TV b2b3ea7…/27签名17:32:02覆盖，Pad最终cdd82a1…/30签名17:40:22覆盖，13未发现/18未动。原索引149/3408完整同、最近覆盖前偏好15/19同，会话恢复删除/TV自有Runner停/Pad原Runner保留；最终普通首页实看。30项14/5/11、114格不增P。

2026-10-27[TV音轨/字幕与源帧参照](../archive/handoffs/2026-10/2026-10-27-TV-WEBDAV-TRACK-MENUS-AND-FRAME-REFERENCE.md)：共享KS菜单补中文名称/当前值/稳定标识，字幕Off改关闭字幕。TV新普通Debug d7b97f0…/8cea50f…/399输入/27签名，16:52:12 fresh保留数据覆盖；真实保存WebDAV无搜索窗音轨5.1→立体声→恢复、字幕关→恢复、倍速菜单收起及两Menu同PID回详情有限成立，实图已看；听音/字幕完整性/精确seek未验。10MiB参照截止/165部分帧及低相关错配保留失败，未据此认定seek缺陷或通过。原149索引/15偏好同、会话设置恢复/Runner停；首收尾Home失败保留，后普通启动台实看。移动35f3bf8…仅构建/30签名未安装，Pad/13仍2deb、18离家未动。30项14/5/11、114格不增P。

2026-10-27[TV截图干扰与真实返回对照](../archive/handoffs/2026-10/2026-10-27-TV-WEBDAV-SCREENSHOT-INTERFERENCE.md)：同一普通Debug包/真实WebDAV文件/无搜索路径，XCUIScreen A正常一次Menu返回→DVT截图B三次不返回→XCUIScreen C含暂停继续后一次正常返回，均核同正PID/实际图。支持截图方式相关的调试干扰，具体系统消费Menu机制未证，不把所有旧失败洗成工具问题。正式播放路线未改，仅DEBUG准备页替换夹具；TV d8e9df5…/27库fresh覆盖，最终普通启动台实看、149索引/15偏好同、自有会话/Runner/夹具清理，Pad/13/18未动。114格不增P、30项14/5/11保持。 后续同包XCUIScreen seek窗已见00:10→00:34→00:24及对应不同画面，控制层打开/隐藏后两次Menu正常回详情。读时钟包含自然播放和动作/取图开销，未匹配源帧，不当精确±15秒或性能验收。

2026-10-27[TV嵌套与本地返回对照](../archive/handoffs/2026-10/2026-10-27-TV-NESTED-AND-LOCAL-EXIT-CONTROLS.md)：仅扩展显式DEBUG隔离场景，14种条件/16窗一次Menu同正PID返回，含嵌套/全屏/合成隐藏/本机H264及视图建层；不能复现真实WebDAV，正式退出未修。首驱动异步误判/多发键两失败保留，已改等待dismiss与正AUT PID门槛。最终TV普通Debug df96adf…/27库15:23:50 fresh保留数据覆盖，15:32普通启动台/原149索引/15偏好同，自有会话/Runner/本机夹具已清；Pad/13/18未动。114格不增P、30项14/5/11保持。

2026-10-27[TV WebDAV返回事件观察](../archive/handoffs/2026-10/2026-10-27-TV-WEBDAV-EXIT-EVENT-OBSERVATION.md)：实际事件日志中3次Menu未进入内外返回处理器；原生keyWindow/焦点存在，PlayPause后焦点到TVSlide。移动handler至最终方向处理后的候选无改善，临时观察及候选全部撤回，399源码与开工前同。最终普通Debug TVf14dbc7… fresh覆盖/普通首页，原149索引/15偏好同、自有Runner/会话/缓存清理；手机/Pad/18未动。TV退出未修，不增114格P；用户无TMDB产品建议为先稳定只读库/播放器，离线NFO/图兼容、在线补全商用许可单列。

2026-10-27[WebDAV承载与控制](../archive/handoffs/2026-10/2026-10-27-WEBDAV-PLAYBACK-HOST-AND-CONTROLS.md)：DVT两栈定位海报墙主线程重复分类，改actor按完整库快照后台投影/复用，移动接统一UIKit全屏承载及来源owner生命期。131模块测试/399输入/双普通Debug，移动2deb713…、TV984d999…。Pad真实NAS不同原生帧、显现控制/同PID普通返回，13缓冲后出图/同PID普通返回有限成立。TV3/10/30出帧但Menu/完成焦点失败，FocusState候选无改善已撤回；最终TV包按内层状态流程3次Menu仍未退出、原生主动停。18离家hands off；114格无新P、30项14/5/11。

2026-10-27[WebDAV独立播放首切片](../archive/handoffs/2026-10/2026-10-27-WEBDAV-DIRECT-PLAYBACK.md)：新route有129模块测试和399输入双普通Debug/三机最新包正常首页；Pad自有H264 MP4首3/10/30实帧、第二窗普通退出，真实NAS S01 MKV3.71/10.66/30.69秒不同实帧。实际NASWDA `/source` 超时后主动停止，普通退出/全控制/SA/帧时间/13和TV新route未验。只按新WebDAV来源记录有限L1，不沿用DSM/Jellyfin格、也不由Mac64KiB Range探针外推原生网络/首帧；旧114格无新P，历史失败保持。

2026-10-27[TV季集/空系列原生接续](../archive/handoffs/2026-10/2026-10-27-TV-SERIES-AND-EMPTY-CATALOG-NATIVE.md)补TV真实18文件两季的保存→剧→季→单集、本机编辑/恢复，Pad单集夹具移类后空季/空剧/恢复，无App源码或AV/KS/Range链修改、无视频GET。沿原普通Debug393输入/113既有测试，本批逐机fresh覆盖TV/Pad；原149/3,408库相同、临时库/服务已清。属于资料/导航有限验证，114播放格不增P；独立网络库播放/FTP/SMB及完整跨端边界仍未交付，历史控制超时保留。

2026-10-27[海报同端布局与季集](../archive/handoffs/2026-10/2026-10-27-POSTER-LAYOUT-PARITY-AND-SEASONS.md)：Jellyfin集/搜索与网络库共用实际窗口布局，手机3列、Pad竖4横5/上限960、TV沿既有密度5（支持3/4/5），标题/画布/间距对齐，TV按需搜索不自动弹键盘。113测试/393输入/双普通Debug，移动fa4c98…、TV831f47…，三机fresh覆盖/普通启动及配对截图；13真实18文件两季→单集详情已过，临时库已移除。TV季集保存/上层导航控制未验，保留失败不盲调。最终原索引Pad3,408、13/TV各149完整同；TV仅catalog Data字节差但JSON同，密度/其他偏好同。18离家hands off，无独立库播放/FTP/SMB交付或114格新P，30项14/5/11保持。

2026-10-27[分类与剧集层级](../archive/handoffs/2026-10/2026-10-27-MEDIA-CATEGORIES-AND-SERIES-HIERARCHY.md)：电影/电视剧/动漫/待分类、剧名→季→集、选根内tvshow.nfo/总海报与单集-thumb分离、本机类型/季集纠正展示已接；TV同页选目录显式焦点修复。最终111模块测试/391输入/双普通Debug，移动fa423b…、TVa62980…，Pad/13/TV fresh覆盖及空启动/19、26、14偏好同。Pad真实3,408文件/178作品/59剧目录/56总海报路径/2,308图片路径，三层和样本图片实看；13/TV实际认证/指定子目录149文件完成，最终保存库分别8/6张可见海报。2,308仅索引，不是全部图已看。TV/13剧集层级、本机纠错原生专项及全主题仍待；无NAS写/独立库播放/FTP或SMB交付，18离家hands off；30项14/5/11、114格不增P。

2026-10-27[海报升级与逻辑影片](../archive/handoffs/2026-10/2026-10-27-POSTER-UPGRADE-AND-LOGICAL-MOVIES.md)：Pad自有夹具复现旧库自动补图0/手动2，修根页push取消；新增原盘/保守CD分段及附加视频展示投影、选根内电影目录已有NFO/图片继承，物理文件保留。100测试/388输入/双普通Debug过，移动280b18…、TVb53fe5…；Pad/13/TV fresh覆盖及普通启动、19/26/14偏好同，18离家仍4e包hands off。留存149文件离线投影112主卡＋1附加、2原盘含22/16流，真实NAS封面未验收。Pad新包夹具实看4图/5主卡＋1附加、8文件列表全保留；旧schema自动升2/6物理图片引用，不再手动整理，源同/0媒体写/库移除/停服。三机无已保存WebDAV，真实NAS需连接信息，13/TV针对性回归继续；30项14/5/11与114格保持。

2026-10-27[离线图片首片与控制审计](../archive/handoffs/2026-10/2026-10-27-OFFLINE-ARTWORK-AND-CONTROL-AUDIT.md)：工具0视频命令，93模块测试和双构建不是独立库播放、海报真机或逐帧验收。用户18已更新后报告全占位/误分组，13旧a34包06:40:34真实scene-update watchdog保留，发生覆盖窗不定因果。18已带去上班，后续仅Pad/13/TV；114格不增P。

2026-10-27 [Pad横屏退出与FTPPath批](../archive/handoffs/2026-10/2026-10-27-IPAD-EXIT-ORIENTATION-FTP-PATH.md)：97da576e…普通包S01既有Jellyfin续播3/10秒不同实帧、完成回同详情，前后LANDSCAPE/两个1180×820窗口保持，独立70秒守卫未强停；仅自然进度变化保留。最终a34a6a…包方向源码同，381输入/新增FTPPath无传输或UI调用；Pad/13/TV最终普通首页已看，18最终无线已装但锁屏启动待验。不是全部方向/分屏/听音/完整字幕/帧时间或最新最终包完整播放复验，114格不新增P，旧失败均保留。

2026-10-27认证分类修复：WebDAV的Basic/Digest无凭据/重试被拒时，取消挑战前保留HTTP401，修正Foundation返回URL取消（实见-999）造成的误导。真实目录/NFO两新增测试先4断言失败，修复后75项0失败；双普通Debug并逐机覆盖，18实际无线安装/lookup/正常首页与27偏好保持成立。仅只读目录/NFO错误语义改变，凭据origin/证书/跳转和AV/KS播放链不变，S01有限播放证据仍标前包、不新增114格P。详[iPad接回批](../archive/handoffs/2026-10/2026-10-27-IPAD-RECONNECTED-WIRELESS-IPHONE18.md)。

2026-10-27 [iPad接回批](../archive/handoffs/2026-10/2026-10-27-IPAD-RECONNECTED-WIRELESS-IPHONE18.md)：当前3f9d61…普通包已fresh覆盖Pad15,7/26.6，19安装偏好同；新WebDAV合成来源选根/NFO/纠错/恢复/移除有限成立，0视频/写，首工具超时保留。S01/Jellyfin directPlay/localRangeProxy/KSPlayer续播3/10/30画面推进、第二窗普通退出已核；首窗控制效果未确认被70秒守卫停止，非产品崩溃/普通退出，仍不新增114格P或关闭全音字幕/帧时间。18当前无线身份及容器探测过，后续新包走无线，本批无新构建/重复安装。

2026-10-26当前[跨端卡片与WebDAV批](../archive/handoffs/2026-10/2026-10-26-CROSS-PLATFORM-CARD-RULES-WEBDAV.md)：三端设置分组/TV全部Docker默认显示与套件隐藏、手机语义底色及完整书架已接。HTTP域名ATS配置已修并核内置plist，改变全App HTTP允许性，但无视频/蜂窝/Release回归，不增114格P、不关闭旧失败。13新WebDAV表单连接后只读目录207仍未完成跳转，完整新增/NFO/纠错UI未过；18最新包USB安装正常启动，内部页面自动化受限，Pad已由用户断开。

2026-10-26服务接续：[识别/已有登录入口](../archive/handoffs/2026-10/2026-10-26-MEDIA-SERVICE-DISCOVERY-AND-ENTRY.md)67包测试及最终三机免重复密码进入已有Jellyfin库、NAS会话选目录成立；0媒体，不增加或关闭114播放格。新增服务仅身份/状态，不能外推其授权/库浏览/播放支持；历史失败保持。

2026-10-26新增File Station现有会话目录/NFO与已有WebDAV连接复用验证，详[本批](../archive/handoffs/2026-10/2026-10-26-NAS-SESSION-SOURCE-HUB-NATIVE.md)。未发媒体/改播放链，不增加或关闭114播放格；不能把目录/NFO认证成功当独立网络库播放、FTP/SMB或新增媒体服务验收。

2026-10-26用户新增FTP/FTPS与统一来源/服务识别，见[方案](../architecture/UNIFIED_SOURCE_DISCOVERY_AND_ACCESS.md)。本轮只有源码审查和无联网交互预览，无App源码/真机/媒体操作，不给FTP/Emby/Plex/音乐服务新增播放P；原114格、历史失败保持。

2026-10-26 [本机纠错/SMB预检](../archive/handoffs/2026-10/2026-10-26-LOCAL-CORRECTIONS-AND-SMB-PREFLIGHT.md)：42逻辑及三端最终包编辑/保存/恢复/移除，不涉及原位播放或音视频链。SMB仅仓库外动态构建/取消反例及raw协商取消原型，没有新增SMB播放能力；114格无新增P，原失败保持。

2026-10-26 [已有NFO只读识别与TV存储修复](../archive/handoffs/2026-10/2026-10-26-LOCAL-NFO-METADATA-AND-TV-STORAGE.md)：32测试、三机目录/4视频索引/2 NFO展示/本机移除，13/Pad取消有证据，TV取消仍未验。均为本机合成夹具的目录/资料读取，没有独立库播放实现或媒体/蜂窝窗，不新增格式/SUB/AUD/首帧P，29开放和114格保持；Pad安装阻塞已解除，18离线未装本批。

2026-10-26 [共享只读WebDAV切片](../archive/handoffs/2026-10/2026-10-26-READONLY-WEBDAV-LIBRARY.md)：15规则/真实HTTP测试及13本机目录→索引/重启/403旧库保留成立，TV表单有限验；Pad安装协调器阻塞、18离线。没有独立网络库播放实现或媒体/蜂窝测试，不新增播放P，29需求仍开放、原114格保持；不得把目录/构建/安装当格式与SUB/AUD/首帧通过。

2026-10-25 [只读库参照与设备更新](../archive/handoffs/2026-10/2026-10-25-READONLY-NETWORK-LIBRARY-AND-DEVICE-REFRESH.md)：18→13/Pad逐机最新普通包安装与首页/偏好核，TV最新普通首页恢复；此阶段0媒体/蜂窝，无新增播放P。网络媒体库一项新需求使开放总数29，WebDAV/SMB客户端未接，原114格不删改；既有TV原轨S01/ASS单cue切片不扩成PGS/听音/文件验收。

2026-10-25 [TV源目录/候选接手](../archive/handoffs/2026-10/2026-10-25-TV-SOURCE-TRACK-CATALOG-AND-HANDOFF.md)：47逻辑＋11UI，S01轨道/暂停/倍速/位置及画面切片，S03 Off→ASS5同cue可见中英字幕。仅TV JF局部；S03内部19.508秒等待保留，PGS只目录/未实际换，AUD=U，完整ST/帧时间/Release、文件/手机不继承P。脚本AX焦点误判/多seek与首次收尾误判均留档；28开放／114格保持。

2026-10-25补充：[TV方向键批](../archive/handoffs/2026-10/2026-10-25-TV-DETAIL-ENTRY-FOCUS-COMMITS.md)40逻辑＋7UI、真机内存元数据44步原生焦点提交/普通真实影片47步通过，均0媒体/蜂窝；不能据此填播放/SUB/AUD/帧时间格。旧最终落点测试不足已保留说明，114格及28开放保持。各分支边界见[总交接](../archive/handoffs/2026-10/2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)。

2026-10-25 20:32：TV按完整顺序改显式焦点及横排记忆，最终40逻辑＋7无媒体UI、真机44逐键闭环通过；旧跨区可达不足及两候选/错API顺序夹具失败保留。iPad横竖hero/图内圆点/完整参数已优化，首版横屏标题裁切经实图发现并修；最终普通移动包已13/Pad逐机保留数据安装与实图/返回核对，源510/570零漂移。TV自有Runner停；Pad仅自有HTTP会话已删除/原方向设置恢复，未知Runner保留，13未知Runner不改。0媒体/蜂窝，28/114保持。

实际接受映射：TVDetailView/TVMediaShelf/TVPersonCard明确焦点目标及确认后的横排记忆；移动LaunchpadView的JellyfinHeroCarousel/HeroSlide同画布与JellyfinMetadataFlow自然宽。固定AV/KS、Range/缓冲/音字幕协商未改；本批为详情导航/布局，不关闭原矩阵。

2026-10-25 19:45：TV首演员Up空间缺口已补焦点区域，普通新包9896b4c9/27签名19:30保留数据安装；40逻辑＋6无媒体UI、真机详情31方向与四根页/子页32检查完成。包括首/末演员Up及相似区上下，非所有动态界面/帧时间验收。两次自有Runner停/设置恢复，TV偏好与上一批末0变化，手机0操作。18条海报抽样确认源分辨率不一；白夜旧500×750但提供方可取中文1200×1800，实际图片下载解码通过，高清补全尚未接入产品。28开放／114格保持。

接受实现映射：TVViews.TVDetailView/TVMediaShelf及TVNASViews偏移操作组focusSection，原网格最小揭示不改；DEBUG内存夹具仅测试。高清图片仍原Jellyfin展示路线，候选可用不当产品已接入；解码/Range/缓冲/音字幕协商未改。

2026-10-25 19:20：三端详情精修已用普通新包逐机实看；共用海报/元数据格式、手机续播与重播同行、分类优先实际背景图。TV40逻辑＋5无媒体UI过；真实网格23次方向核对与最小滚动有证据，非帧时间验收。Pad黑屏经唤醒恢复、原因未知，最终详情和返回实看；自有Runner/设置已收尾。新报首个演员Up失效，当前继续全局方向键审查；新增高清海报/独立刮削调研。28开放／114格保持，未改播放传输，源音字幕切换及原弱蜂窝问题仍开放。

源码映射：AppTheme.MediaDetailDesign/NastartMediaFact共同格式与样式；LaunchpadView.Jellyfin详情/TVViews.TVDetailView只读展示，TVModels.TVDetailStream解码来源参数，TVJellyfinClient.libraryArtwork只读背景图。固定AV/KS解码、Range、缓冲及选流未改，40＋5不替代实播矩阵。

2026-10-25 15:39：[TV层级与遥控器批](../archive/handoffs/2026-10/2026-10-25-TV-CONTEXT-NAVIGATION-AND-REMOTE.md)最终38逻辑＋5无网络UI；TV最终普通包S01短窗实际画面/暂停/轻量焦点与同PID退出，仅局部UI/导航切片。蜘蛛侠3最终短窗仍准备、旧Menu失败均保留。移动最新普通包仅正常首页，未重做媒体格。28开放／114格不关闭；音听、完整SUB/AUD/HDR、帧时间/长稳/并发仍缺。

2026-10-25 15:04：[源轨身份、播放意图与诊断校正](../archive/handoffs/2026-10/2026-10-25-SEEK-PHASE-AND-TRANSPORT-SCOPE.md)完成：旧late metrics 144项62归属误标已按发出记录校正；共享UI丢绝对源音轨/字幕ID及sidecar导致文件HLS准备拒绝已修，缓冲actual=false误当用户暂停已改读取AV/KS真实意图。9/10/12三组定向分别过（不相加成全量）；普通a4477a45最新保留数据装13/Pad、570输入/30签名/安装偏好0变化。13真实早期+15已HLS重建并startsPaused=false、实际继续电影/内部推进162秒/普通返回；三窗均停自有媒体和syslog、原网Selected＋Wi-Fi图核，其他偏好保持。完整声音/帧时间/格式族/并发、KS长等待与持续几KB仍开放，28/114不关闭。TV新增KS只读接口未重建，不以11:14旧包当当前源码回归。

2026-10-25 13:25：[蜂窝大文件与受限连接复用](../archive/handoffs/2026-10/2026-10-25-CELLULAR-FILE-SEEK-TRANSPORT.md)完成8定向测试，普通Debug主SHA f453254b已保留数据装13/Pad（12:51/13:02，570输入/30签名、安装偏好0变化）。13真实4G两轮文件各40次seek，pinnedRoute分别18/3条连接复用；末正/反内部恢复AV 9832/1451、KS 6009/9443ms，JF新包±15为1543/733ms，起点/轨道/路线不同不排名，持续几KB/s尚未稳定复现。受限pool只同route/origin、沿原CertificatePinStore策略，单任务取消/路线撤销隔离；KS一窗引擎确认4040ms、缓存就绪9186ms，网络/解码尚非单一根因。两机S01双入口实图/普通返回已核，Pad浮窗呈现仍缺；每窗自有媒体停/原网Selected＋Wi-Fi图核，Pad Runner已停、13未知Runner未改。非Release/全格式/并发/音听/帧时间验收，28开放/114格保持。

2026-10-25 11:33新用户报告与优先级：18蜂窝下设备文件入口的《指环王》等大文件seek后速度降至几K/几十K，JF入口无同样问题；用户明确授权用当前USB iPhone13真实蜂窝对照/优化。原三端一致性任务继续，18外出安装暂缓；本批尚未切蜂窝/无复现结论，先核13当前包/原Wi-Fi/实际端点，按双入口执行卡匹配文件/轨道/位置及原流/HLS，分离真实供给、旧请求取消、解码等待与显示速度。每窗finally停止自有流量并确认原网已连接及Wi-Fi图标，弱蜂窝指标未知保留未知，不改VPN/NAS/凭据。28项/114格不关闭。

2026-10-25 11:20：[播放控制与同款动作](../archive/handoffs/2026-10/2026-10-25-TV-TRANSPORT-PARITY-AND-MEDIA-ACTIONS.md)共用15秒/倍速/圆形控制及继续/从头同款按钮，TV JF固定AVPlayerLayer＋应用菜单；当前普通新包37逻辑＋4严格无媒体UI通过。实际S01 11次回退165秒准确，同cue菜单前/开/后字幕bbox一致/实图已看，菜单上移此场景修复；两级返回同PID稳定。本轮完整音轨/字幕/声音/帧时间和TV文件控制仍待验，保留旧失败；原10偏好不变/设置GET恢复/自有Runner已停。13与新Pad已装同一最新移动包，Pad重连及设备旧清理已核，18外出暂缓。28开放／114格不关闭。

2026-10-25 09:30：[共用设计／遥控器返回](../archive/handoffs/2026-10/2026-10-25-SHARED-DESIGN-AND-TAB-FOCUS.md)TV09:18普通Debug新包510输入/27签名；6步Tab聚焦即切、12页面与普通返回检查、35逻辑/3无媒体UI过；S01/JF原生3/10秒出画，2Menu曾瞬时回详情但后续再次看到播放器，ordinaryExitAccepted=false，已主动停媒体正常首页。没有音听／完整字幕／帧时间验收，114格不关闭。13共享包UI已核，18未装共享样式最新包／Pad缺席，不借TV图补其他设备。


2026-10-25 07:50：[TV 顶栏与首屏间距](../archive/handoffs/2026-10/2026-10-25-TV-ROOT-SCROLL-AND-PAGE-SPACING.md)普通新包已安装；固定顶栏／移除重复占位／共用紧凑页头，四页14滚动＋帮助/网络2返回、35逻辑/2UI通过，原10偏好全同/自有Runner已停。13四根页竖屏间距23–27点，Pad当前缺席待复核。[18有线新包](../archive/handoffs/2026-10/2026-10-25-IPHONE18-WIRED-REFRESH.md)07:33安装并正常NAS首页实看、26非诊断偏好不变，取代此前待识别签名阻塞；实际DSM仍自动LAN、域名旧问题继续暂缓。28开放／114格不关闭。

2026-10-25 07:15：[作者位图同源与新包回归](../archive/handoffs/2026-10/2026-10-25-AUTHORED-BITMAP-AND-DEVICE-REFRESH.md)已接移动/TV实际字幕层；13定向＋TV35逻辑/2UI通过，13/Pad/TV普通新包已装及正常首页实看。13两轮真实输入超时，迟到KS内部事件不当电影/字幕证据；Pad未播放且随后USB缺席，设备端Runner/设置收尾待重连核对。18当前签名不含设备/未装最新。28/114不关闭。

2026-10-25 05:23：[共用字幕视频区域](../archive/handoffs/2026-10/2026-10-25-SHARED-SUBTITLE-GEOMETRY.md)已实接移动原策略与TV文件KS，最终字幕观察隔离到子树，保留焦点返回。TV最新509输入/27签名包保留数据安装；S03一Menu、S01两Menu回原目录/同PID并停止，初版3Menu失败留档。最终移动8几何/像素＋TV2几何/2UI正式过、Release仅编译过；作者坐标/完整字幕/手机真机待验。18无线认证成功，新570输入包未装：新profile不含18，旧签名06:23:57到期，Xcode找不到目标，已一次询问有线解锁续签。仅自然续播/Runner清理，28/114保持。

2026-10-25 05:00：[TV返回事件定位与修复](../archive/handoffs/2026-10/2026-10-25-TV-EXIT-EVENT-PROBE.md)：观察版真片3次Menu未触发exit；无媒体夹具可退。将同一返回规则接到视频焦点层后，最新27签名普通Debug已04:47保留数据安装，S03/S01实际出画、各1次Menu回原目录、同进程及stop完成均核。候选32+5断言过但driver中断，独立2UI正式过；移动模拟器157执行/1跳过/0失败、Release仅编译过。仅自然续播变化/自有Runner全停，手机0设备操作，字幕与全播放契约尚未统一，28/114保持。

2026-10-25 03:22：[TV返回调查](../archive/handoffs/2026-10/2026-10-25-TV-PLAYER-EXIT-INVESTIGATION.md)两轮候选均32逻辑+1UI通过，但各一次Menu实片返回仍失败，均主动止媒体/停Runner；改动已逐字节回退，稳定源码508输入全同，重新构建27签名包/保留数据安装并正常首页实图核过。无媒体网络页相同Menu一次可正常回设备，缩小到全屏路径而非根因已定。9偏好仅自然续播变化，三次自有Runner全停，28/114不关闭；手机三台0操作。

2026-10-25 00:03：[18最新无线安装](../archive/handoffs/2026-10/2026-10-25-IPHONE18-LATEST-WIFI-INSTALL.md)按用户新授权完成：24日23:57:29 Complete/lookup、最新569输入/30签名普通Debug、独立正常空环境原生NAS首页/Wi-Fi已看；26非诊断偏好安装/启动后全同。无重配/WDA/网络改动，旧无线reset根因未定；实际DSM仍自动选内网IP，固定域名旧问题未修且继续暂缓。0媒体，28开放/114格不关闭。

2026-10-24 23:51：[三端代码审查/服务状态修正](../archive/handoffs/2026-10/2026-10-24-CODE-AUDIT-AND-SERVICE-HEALTH.md)完成应用源码库存和[26域控制流对照](../architecture/CROSS_PLATFORM_CODE_CONSISTENCY.md)：iPhone/iPad同实现，TV仅底层KS共用，完整播放链仍分叉。移动快照发布后立即探测/逐项更新，157执行/1跳过/0失败；13 23:44:00、Pad23:43:42最新普通30签名包保留数据覆盖，空环境首页实见状态，非配对启动性能。TV23:10大MKV有实际画面/双语，但三次Menu退出失败；已止媒体/停自有Runner、正常首页恢复，未修复退出/字幕。28开放及114格不关闭，18暂停。

2026-10-24 23:04：[TV文件与服务浏览](../archive/handoffs/2026-10/2026-10-24-TV-FILE-SERVICE-BROWSING.md)补四种服务端排序/升降序/代次隔离、真实文件信息和服务名称镜像筛选；32逻辑+1UI、当前27签名包保留数据更新及真机16个浏览/返回检查点，原偏好0变化/自有Runner停止。仅UI与只读元数据，0新媒体，28项/114格不关闭；大目录分页/写操作与完整播放仍待验，18仍暂停。

2026-10-24 22:20：[栈列信息页与返回回归](../archive/handoffs/2026-10/2026-10-24-STACK-INFORMATION-PAGES.md)将移动原生分区统一为侧线/紧凑行/等宽数字，TV设备/我的改栈列单行信息布局，资源表/服务目录按当前主题切换（修正目录强制栈列）。TV当前源码28逻辑+1UI通过；三台普通Debug保留数据更新，13/Pad设备子页和三类提醒表单、TV资源/网络/证书/服务/事项取消返回已核，后续覆盖/失败/恢复以本批JSON为准。未新增播放/性能验收，28项/114格不关闭，18暂停，真实iCloud仍缺。

2026-10-24 21:38：[三端主题与媒体入口](../archive/handoffs/2026-10/2026-10-24-GLOBAL-THEMES-AND-MEDIA-ENTRY.md)已统一内容画布/染色卡片，手机/Pad两个快捷入口合入NAS摘要；浅色流光调淡、深色增强，TV栈列改等宽排布并保留原流光配色。三端共享目录/当前账号电影统计已写，13/Pad实见12/112；TV统计与iCloud不可用状态入口真机核对。当前免费签名、无CloudKit权限，真实同步仍缺；28项/114格不关闭，18暂停，本批0媒体。最新包与失败/恢复边界见该批结果。

2026-10-24 18:56：TV [外观、连续海报与竞品批](../archive/handoffs/2026-10/2026-10-24-TV-APPEARANCE-POSTERS-AND-COMPETITORS.md)进行中：用户新增统一卡片/图标、网络返回、事项字号、媒体授权/倍速入口归位、继续观看/最近添加/演员相似与网易爆米花视觉参照。最新候选严格图片尺寸+自动分页回归中；22逻辑+1UI属于前一媒体包，未关闭28开放或手机114格，18仍用户暂停。

2026-10-24 18:02：[TV界面/功能对齐批](../archive/handoffs/2026-10/2026-10-24-TV-UI-PARITY-AND-PLAYBACK.md)统一四Tab、字体、三主题、Docker默认显示/分组、服务详情、设备资源子页、我的设置、本机事项与JF海报/原生播放控制；20逻辑+1UI通过，最新27签名包保留登录覆盖/普通原生启动。三主题、服务详情/目录和文件入口已真机核；JF实际出画/退出与音字幕等边界见该批，不宣称完整平移。18继续暂缓，手机源码未改，28项/114格不关闭。

2026-10-24 15:50 TV独立批：共享兼容文件播放器/音频路由已补，最新普通包保留DSM登录覆盖、首页/目录已核；用户报告《谍中谍》失败仍保留，真实两入口音视频回归进行中。见[本批](../archive/handoffs/2026-10/2026-10-24-TV-CORE-PLAYBACK-AND-SERVICES.md)，不新增或关闭手机114格，不把18逻辑+1UI或首页当播放PASS。

2026-10-24 14:28：[TV与双机批次](../archive/handoffs/2026-10/2026-10-24-TV-PARITY-AND-DEVICE-REGRESSION.md)补13与新Pad/S01/JF各一次普通30秒实际不同片头/正常回原详情，原轨道/其他偏好保持。新PadJF由未测转有限证据U；声音/完整字幕/帧时间等未验，不改整格P。TV新DSM包已覆盖/普通登录入口已看，真实媒体未验，不填入手机格。18用户暂缓、实际固定域名未修好。

2026-10-24 13:40：[新iPad11与13回归/18无线核对](../archive/handoffs/2026-10/2026-10-24-IPAD11-ONBOARDING.md)：新Pad12:23目标包/WDA安装成功，用户登录后普通NAS首页/S01文件30秒实际片头及普通回原详情已核；新书签0→1、其他偏好保持，App0/Runner0/Wi-Fi收尾。13于12:50同源码兼容包保留数据覆盖，真实S19原流4000.073→12Mbps/PGS8候选单次实际回调/22.846秒commit，静置横条隐藏但候选无可验cue，旧字幕遮挡/普通自动仍开放，12:59完整偏好/自有资源收尾。18历史无线成功链路已复核，当前广播实际配对身份已找到；解锁后仍VendContainer断开，0上传/安装/启动，域名配置未改。发现工具新增当前广播身份核对，16工具测试通过，App源码未改。28需求不变，旧76＋新Pad38格独立，不判整格P。

2026-10-24 12:00：[横条静置/AX/引擎对照](../archive/handoffs/2026-10/2026-10-24-HOME-INDICATOR-CONTROLS.md)：无App源码/新构建/测试重跑，174输入保持，13本轮11:44保留数据覆盖10:57包及正常首页/25偏好保持。三组本地原生对照（0AX、每2秒AX、真实KS→AV）静置均可隐藏横条，未证通用host/AX/AV根因；12图已看，不当PGS/完整音画验收。真实S19原流4000.094秒/两图横条隐藏；候选一次点击后效果未确认，应用回调/预热/提交0，未补点，不当已进入候选或40秒失败。按钮AX矩形与原生蓝色区域对齐（全帧尺度3已核），但实际命中未证。末11:57普通NAS首页/源包回执/完整偏好两读稳定/36轨道24项/Wi-Fi无PiP/自有资源停止核过。PadUSB缺席/未装最新；18发现解析失败/最新未装/固定域名未启用。0蜂窝，旧候选遮挡及28项/76格保持。

2026-10-24 11:05：[候选全屏承载及字幕反例](../archive/handoffs/2026-10/2026-10-24-LAB-FULLSCREEN-PARITY.md)：仅Debug复用普通全屏presenter、避免底页覆盖提前释放代理，实际UIKit呈现/关闭资源等20定向测试、15预检/真机构建通过。10:57包13于10:58保留数据覆盖/25偏好全同/普通空环境NAS首页实图；S19深位置单次手动候选27.528秒提交/储备0.801/AV采样stall0/末1:07:19已看，原流计数9/转圈仍有。7原生图横条仍可见，候选30秒英文被盖住，45秒控件隐藏仍有横条，未修字幕。末11:01普通NAS首页、源包/回执/偏好两读稳定/36轨道/24项/Wi-Fi无PiP及自有资源停止核过。Pad实时USB缺席/仍09:48包；18发现解析失败/最新未装/固定域名未启用。0蜂窝、0Mac媒体GET，不作普通自动/完整音画/帧时间/Release或旧失败关闭，28项/76格保持。

2026-10-24本批离线接续：重看09:23旧包S19两张原生图，候选英文底行确被系统横条盖住，原流同Debug根也有横条但cue更高；源码诊断根直接NavigationStack，普通全屏host已有自动隐藏策略。仅定位承载差异，未改App/新增媒体或证明普通同cue通过；下一候选证据先统一承载。详[本批接续](../archive/handoffs/2026-10/2026-10-24-DSM-FIXED-ADDRESS.md)，不关闭字幕或76格。

2026-10-24 10:05：[DSM固定地址](../archive/handoffs/2026-10/2026-10-24-DSM-FIXED-ADDRESS.md)：新增每连接“始终使用此地址”，Keychain/表单保存，恢复只认证配置地址、失败不认证发现LAN；旧记录默认false。19定向XCTest/15预检/普通真机构建通过，09:48包13于09:50、Pad于10:00保留数据覆盖且偏好全同/空环境NAS首页实图已核，末源包/回执/完整偏好稳定/自有资源停止。13表单域名但09:51登录目标内网，现有会话蜂窝迁移未验。18实时发现/解析仍失败，最新包未装/固定域名未启用；0媒体/0蜂窝，不继承09:23媒体为本包回归，28项/76格保持。

2026-10-24 09:40：[采集器接手修正与DSM地址核对](../archive/handoffs/2026-10/2026-10-24-HANDOFF-OUTPUT-AND-DSM-ROUTES.md)/[安全结果](results/2026-10/2026-10-24-handoff-output-and-dsm-routes.json)：仅DEBUG复用warmup已解码输出，避免诊断新增输出扰动；反例先失败、10定向正式成功/15预检/真机构建通过，09:23包09:31:32保留数据安装13。真实S19手动候选新窗30.172秒提交、七配置边界output1/empty=no、评估等待67ms，原流计数9/30秒转圈与底部字幕重叠保留；旧窗23.803秒/1063ms及供给不同，不作提速A/B或旧失败关闭。末09:37普通空环境NAS首页/完整偏好两读稳定/36键轨道/24项/Wi-Fi无PiP/自有资源停止核过。Pad本批0媒体/仍08:37包；18未连上/最新未装。用户要求18实际DSM始终域名＋端口；源码当前可恢复选LAN，历史偏好输入仍域名不证明Keychain/会话。下一步按连接保存固定地址策略，13原自动不变，18待实际启用验收；28项/76格保持。

2026-10-24 08:52：[08:37新包Debug深起播](../archive/handoffs/2026-10/2026-10-24-MANUAL-LAB-DEEP-RESUME.md)修正元数据，7定向XCTest/15预检；13/Pad当前包保留数据安装及普通首页已核。13/S03从4000.148秒单次手动12Mbps/PGS Encode候选22.826秒事件间提交、末1:07:38不同电影实图已看；接手后内部waiting990ms保留，不当自然自动/全帧/无感/字幕cue或旧失败修复。旧0秒、私有复核超时各0候选保留；Pad本批0媒体，06:20旧格式结果不继承新包。18最新08:37仍未装，76格及28需求状态不变。

08:20离线补充：既有13/Pad普通S03三窗预测合格51/55/30，数值预测容量均未越过本片41.788Mbps静态触发界线，储备/连续缓冲触发均0，缺数值保留unknown。无新设备/媒体/源码；不把attempt0窗记自动失败重试或候选验收，也不重复延长同条件播放，详同日Pad归档的接续核对；76格不变。

2026-10-24 08:14补[Pad当前普通包/Jellyfin格式族](../archive/handoffs/2026-10/2026-10-24-IPAD-FORMAT-REGRESSION.md)/[安全结果](results/2026-10/2026-10-24-ipad-format-regression.json)：S03/S08/S11/S18各60秒实际不同画面、仅S03/所见S08双语可见；S11原Off、S18片头署名不当独立字幕验收。S03首次完成stale保留，私有工具修正显控时序后15秒短窗及后三样本普通回原详情成立；S03起播计数1/735或1551ms保留，后三窗0不作流畅P。逐窗174输入/06:20包/本机06:26回执/空环境及USB新核，末29键轨道/17偏好/两读稳定/Wi-Fi无PiP/App0Runner0/自有host0已核，未改App/构建/安装。只补JF有限功能，不覆盖文件入口、真实自动候选、全音画、完整帧时间、HDR/DV、PiP或Release；76格与历史失败保持，18最新包仍未装。

2026-10-24 07:49：[13真实原流与PGS候选](results/2026-10/2026-10-24-real-nas-candidate-handoff.json)/[详细边界](../archive/handoffs/2026-10/2026-10-24-REAL-NAS-CANDIDATE-HANDOFF.md)：S03/S19各1显式Debug手动KS→AV提交，真实后续不同电影/字幕及末00:58已看；2Mbps从头/提前私有协商，非普通自动或旧深位置性能配对。S03黑图符合源转场；S19 stall1524ms含playing且时钟推进，不抹计数或当屏幕停滞。完整SUB/AUD/帧时间/普通自动仍待验，旧40.005秒/7300ms保留；Pad本批0、18最新未装，76格状态及完整通过率不变。

2026-10-24 07:28：[真实HLS与代表格式结果](results/2026-10/2026-10-24-real-hls-and-format-regression.json)/[详细证据](../archive/handoffs/2026-10/2026-10-24-REAL-HLS-AND-FORMAT-REGRESSION.md)：13普通JF S03/S08/S11/S18各60秒实际图/回原详情，S03前段转圈/末stall2，其余末stall0；非完整呈现/声音/SUB/整格P。S18另45秒成对采集和同源192MiB离线70秒参考支持两张黑图属于短转场，原图仍保留。S08旧名导航失败0 Play、S11 3秒原生读图失败后WDA补图分别留存。S03/S19真实NAS PGS显式Debug AV窗各master/media1上游+1缓存命中，只证目标分支接通，非普通自然候选/Release/性能对照。Pad本批0操作、18新包未装；76格状态及完整通过率保持，旧失败不删除。

2026-10-24 06:31：[单变体VOD主清单复用](../archive/handoffs/2026-10/2026-10-24-VOD-MASTER-REUSE.md)45 XCTest/15预检通过；只在同route/完整URL子VOD仍在时复用master原文，复杂/直播清单沿原路，不改分片/Range/40秒/NAS。06:20普通Debug已保留数据安装13/Pad并实图核空环境NAS首页。13实际本地AV播放证明master/media各1上游/1缓存命中、23完整分片及不同画面，非真实NAS/PGS提速。13/Pad S01双入口各30秒实际图/普通回原详情已核；Pad文件3秒黑场转圈、末stall1保留，其余三窗末stall0，非整格P/声音/完整帧时间。最终13/Pad源包/回执/完整偏好两读稳定、原36/29键轨道与其他24/17项/Home Wi-Fi无PiP及自有资源停止已核，只有自然进度变化；Pad原生App0/Runner0。18本轮服务解析/浏览无目标，未进入备份/安装/启动，仍仅确认00:00包，既有解锁请求待反馈。真实PGS40.005秒失败/旧7300ms及代表格式回归仍开放，28项/76格状态保持。

2026-10-24 05:29：[自动失败重试真机验证](../archive/handoffs/2026-10/2026-10-24-AUTOMATIC-RETRY-DEVICE-LAB.md)40 XCTest/15预检通过，05:05普通Debug于05:06:36保留数据安装13。本地显式Debug/H264/AAC故障窗由原自动规则20→8Mbps、首候选503失败后沿失败候选trace自动8→4Mbps并提交，实图已看；8/4仅协商上限、同一预编码素材，非真实编码质量/NAS/PGS性能。准备中取消窗无第二协商/提交且上游连接关闭。普通S01/JF空环境30秒不同片头/回原详情已核，末stall0，非完整帧时间/声音/整格P。05:19恢复普通NAS首页，05:20源包/回执/完整偏好两读稳定、36原键轨道/其他24项/Home Wi-Fi无PiP及自有资源停止已核，仅自然进度变化。18在容器备份连接中断，安装指令未发；已一次请求解锁保持Wi-Fi，仍仅确认00:00包；Pad本批0操作亦为00:00包。真实40.005秒PGS失败/旧7300ms未修，28项/76格完整通过率保持。 05:29继续离线核真实JF/文件后续loader：候选自身ceiling/trace、新请求源轨道及live起点在当前源码可追踪；未发现新增修正依据，未发新NAS/设备请求，不替代真实第二次协商/PGS性能验收。

2026-10-24 00:30：[失败候选重试修正](../archive/handoffs/2026-10/2026-10-24-FAILED-CANDIDATE-RETRY.md)37 XCTest/15预检通过，00:00普通Debug三台保留数据安装均确认。13/S03及S19/JF各150秒实片/PGS/普通返回已看，内部再缓冲3222/6290ms保持，两窗各149决策attempt0，不能当自动重试或旧7300ms修复。Pad/S01文件/JF各60秒实图/普通回原详情已核，前置0 Play工具失败保留，非整格P。18于00:08:57 Complete/lookup，其他24偏好/书签键轨道保持，1条目进度字段变化来源未知；新包正常首页因用户另一前台应用未核。最终13/Pad完整偏好两读稳定/原轨道/Home Wi-Fi无PiP与自有资源停止已核。28项及76格完整通过率保持，下一步先补可重复触发的自动失败后重试接线，停止同条件原流重播。

2026-10-23 23:40：[两次13传输控制](../archive/handoffs/2026-10/2026-10-23-NATURAL-CANDIDATE-TRANSFER-AUDIT.md)仅合成H264/AAC/显式Debug：后续充足时切换、原储备有限且持续限速时超限保留原流；条件多项不同，不能作配对性能、真实PGS、声音或76格验收。0普通影片新Play/0NAS媒体，Pad与18无新操作；前批S01双入口有限基线保持，最新Pad双入口/双端仍待补。当前包/源码不变，23:38最终收尾核过，历史失败和完整通过率不变。

2026-10-23 23:10补[当前21:48包有限回归](../archive/handoffs/2026-10/2026-10-23-KS-AV-S01-AND-PAD-UPDATE.md)：13/S01/JF与文件各60秒，播放前详情片名核实、实际电影图和普通回同详情，KS/localRangeProxy，退出采样stall0；JF从头/文件续播，未做同点对照、听音/完整帧时间/seek/换轨/PiP，不标整格通过。首助手误检索S03失败保留，不计S01；该窗真实自动候选40.005秒alignment超时保留原流，7300ms旧失败仍未修。合成KS→AV5.151秒提交只属局部机制证据。Pad当前包已保留数据安装/18偏好保持/普通首页与有界WDA核过，本轮0媒体，最新S01双端仍待补；18前批安装首页已完成。76格完整通过率保持，历史失败不删除。

2026-10-23 22:31追加同包本地总预算反例：候选清单32.433秒准备、33.083秒解码，40.008秒alignment阶段deadlineRemaining=0，未对齐/未提交且保留原流；末图Original Lab/00:49，稀疏黑场图不当连续呈现或声音验收。22:29:38全部实验资源停止，22:30:23–31恢复空环境正常NAS首页，22:30:59源包/25完整偏好两读全同/WDA1/1/auto10/2/Home Wi-Fi/host0独立核完。仅本地显式Debug控制，不改App/包或真实7300ms再缓冲结论；18安装与首页已完成。

2026-10-23 22:20：[候选真机控制与18最新包安装](../archive/handoffs/2026-10/2026-10-23-CANDIDATE-DEVICE-LAB-AND-IPHONE18.md)完成本批有限证据。新增显式Debug同源/已知时长/手动单次候选按钮，沿原replaceSource/完整VOD/解码/对齐/提交，普通环境隐藏、Release不编译，不改自动触发/缓冲/Range/信任。20不同XCTest正常通过、15预检；13本地快/慢候选提交，慢manifest25550ms/总36473ms、原流内部时钟持续推进；取消10710ms清单阶段失败/未提交、上游部分正文停止，黑场/稀疏图限制保留，非自然自动/真实KS到AV/音画性能验收。21:48普通Debug包（174输入/29签名，IPA SHA 3aa6244882e38faac2404cf1b0cf6f7912cddc0a302f4ee4ceb4b6a08a883052）13于22:08保留数据安装；用户新确认家庭Wi-Fi后18于22:12:52 Complete/lookup，25完整偏好安装前后/启动后全同、实际空环境NAS在线首页/Wi-Fi已核。18旧连接/未安装/首页暂缓仅历史，不再列当前阻塞。13于22:17恢复普通首页、22:19源包/25完整偏好含36书签两读全同/WDA1/1/auto10/2/Home Wi-Fi无PiP/host0新核。真实S03起播后7300ms再缓冲仍失败，Pad当前包及S01双端、真实候选/完整声音字幕/PiP/Release待验；28状态/76格通过率保持。

2026-10-23 21:29追加同20:53新包[13/S03/JF一次正常90秒窗](../archive/handoffs/2026-10/2026-10-23-CANDIDATE-VOD-PREPARATION.md)：21:26:45进片，原生3/10秒转圈、30/60/90不同电影画面及两段双语对白已看，末1:06:32、普通回原PGS详情。内部802ms起播/7300ms起播后再缓冲保留；90决策/80预测合格均attempt0、无候选准备/接手，不判修复/全程流畅或候选验收，不与旧文件6.4秒配对比较。21:28:26已停自有App/日志/守卫，21:29源包/36轨道/其他偏好/WDA/Home Wi-Fi/host0新核、仅晚自然进度对应disappear并再读稳定。停止同条件重播；新候选真机受控条件、Pad受影响回归及18最新包安装仍开放，28/76状态保持。

2026-10-23 21:20：[候选完整VOD准备与13新包基线](../archive/handoffs/2026-10/2026-10-23-CANDIDATE-VOD-PREPARATION.md)已落地：注册根/已知有限时长候选在既有40秒总预算内先完整清单缓存再创建AV，取消只停本次上游任务、保留同route独立读取者及原播放器；直播/不可缓存沿普通AV。18不同XCTest正常结束、15预检/141主机报告测试通过，初版取消失败/测试后诊断中断保留。20:53普通Debug（174输入/29签名，IPA SHA `29155b89e97fe74c1c9f73bbd269bc7ee93710c22ec6a4e96453a14c300d3f4d`）20:57保留数据安装13，正常NAS首页及S01双入口21:04–21:07实际画面推进/普通返回已独立看；两窗起点/字幕不同，不比速度，采样stall0不当完整流畅或新候选切换通过。21:15收尾新身份/源包/36轨道/WDA1/1/auto10/2/Home Wi-Fi无PiP/自有host0已核；晚自然进度对应disappear再读稳定，工具失败不抹除。真实慢VOD候选解码/对齐/接手、旧6400ms再缓冲和Release仍未验/未修；Pad/18最新未装，28状态/76格通过率保持。下述18:00与“未改App”均各旧批次历史。

2026-10-23 20:13：[13自动降档条件离线核对](../archive/handoffs/2026-10/2026-10-23-IPHONE13-ADAPTATION-GATE-AUDIT.md)完成；本轮0设备/媒体/App构建安装。未改App的实际Swift策略按事件时间近似重放62决策、0不符，另3控制通过；原采样monotonic now缺失，reserve沿用记录eligibility，不冒充精确原始重演。本窗0降档请求/attempt0：10秒保护内不累计，保护后缓冲采样约3.15秒未达8秒；缓冲前仅1条预测合格，平均/运行需求和供给未同时满足确认条件。补主机报告predictiveDeliveryCapacity与预算容量区分，128测试通过；174 App输入/18:00包不变，无性能修复或新现场验收。已续核候选成本/调用点，首合格时储备约0.062秒、旧失败不当成功时延；下一步本地实际候选入口验证慢正文/完整VOD缓存准备与取消边界，尚未改钩子，不盲降门槛；18最新未装、28状态/76格通过率保持。

2026-10-23 19:35：[等待分段与现场可见播放](../archive/handoffs/2026-10/2026-10-23-IPHONE13-WAIT-ANALYSIS-AND-LIVE.md)完成。仅修离线报告，127测试通过；174 App输入/18:00普通包未变、无新构建安装。暂停预览1268/676ms与含主动暂停的13455ms时钟恢复已分开；源码容量检查配置0.05秒、诊断采样0.5秒，不能混称固定等待。用户质疑时19:22实图确为NAS首页，已解释此前离线；19:24–25现播13/S03文件1 Play/0选轨/seek/PiP，3/10/30及末图19:25:10实际1:12:15已看、普通回原路径。10秒仍转圈，同窗内部再缓冲6400ms保留，不能报流畅或修复。19:29最新包/36轨道/其他偏好/WDA1/1/auto10/2/Home Wi-Fi无PiP/自有host0已核；首偏好即时与晚读不等失败保留，1自然进度晚更新对应disappear、独立再读稳定。18最新仍未装、Pad本续接0，28状态/76格通过率保持。

2026-10-23 19:08：[13过滤/真实队列批](../archive/handoffs/2026-10/2026-10-23-IPHONE13-SEEK-FRAMES.md)及[同包暂停切轨](../archive/handoffs/2026-10/2026-10-23-IPHONE13-PAUSED-AUDIO.md)已收尾。9定向XCTest/15预检/117主机报告测试通过；18:00普通Debug包174输入/29签名，18:03保留数据覆盖13。首窗过滤12/19帧、实际队列各16/声明PTS并集0.656秒，只补诊断，不作过滤CPU或提速结论。暂停窗4→1→4期间7次界面时钟均1:10:46、约36秒，明确继续后3/10/30实图及18:42:15实际1:11:20已看，普通返回同完整路径成立；内部13455ms包含主动暂停保持，不是13秒切轨卡顿。首暂停窗保活归属检查误拦为0 Play，失败保留。首播放窗实时capacity副本0/持久9；暂停窗8个实时事件身份可核但字段均为子集、完整逐字段匹配0，不报完整采集。18:48最终输入/签名/回执、36原轨道/其他偏好/结束后完整偏好、WDA1/1/auto10/2/Home Wi-Fi无PiP/自有host0已核。全批3观察用例/2 Play/4选轨/1暂停/1继续/0手动seek与PiP；无活跃自有媒体采集。18最新18:00包未装、待可靠连接；Pad仅USB基础身份，0App/UI/安装/媒体。28项状态及76格完整通过率不变。

2026-10-23 17:28：[13切轨离线关联](../archive/handoffs/2026-10/2026-10-23-IPHONE13-SEEK-CORRELATION.md)完成，无设备/播放/下载/构建/安装或新图，173输入/iOS diff仍同16:32包。新包首send记录→首原始frame185/268ms、ready前17/21原始frame；旧3956ms窗首frame→ready仍2149ms，首key包早目标0.940s、12/12有界packet样本早目标。追赶/有效视频储备形成列待证假设，不报单包解码耗时、丢弃数、网络根因或修复提速。新task首正文583/92ms，旧539/557ms各自保留；完整task均值不作seek瞬时供给。下一步只补seek过滤接受/丢弃与PTS覆盖缺失观测，先归属测试再新包13回归；28状态及76格完整通过率保持，18最新包未装/首页暂缓、Pad历史包均未改变。

2026-10-23 16:51：[13队列观测批](../archive/handoffs/2026-10/2026-10-23-IPHONE13-SEEK-CAPACITY.md)仅Debug有界容量记录；首16:20版提前绑定未配置plan而零诊断保留，修正固定计划派生planID并补初始化顺序回归，4定向XCTest/15预检/112报告测试通过。16:32普通包16:34保留数据安装13、25完整偏好同，实际S03文件4→1→4及切后/恢复3/10/30图、普通退出已核。6条样本显示两次waiting音频储备已足、视频不足，视频约1.043秒后就绪；只定位本窗门槛，不归因传输/解码或报3956ms修复/声音/P。两窗2 Play/0手动seek/0 PiP/4选轨，16:45最终36原轨道/其他偏好、晚到自然进度与disappear对应及后读稳定、WDA1/1/auto10/2/Home Wi-Fi/自有host0已核。Pad0，18仍06:52；2026-10-23 17:01阶段收尾只读发现3服务/0匹配目标，已知实例当前解析失败，0安装/启动，未改配对或网络；正常首页继续暂缓。28状态保持。

2026-10-23 15:55：[13设备文件音轨切换](../archive/handoffs/2026-10/2026-10-23-IPHONE13-AUDIO-SWITCH.md)：沿07:33包，实时USB/173输入/签名/本机回执逐窗及最终重核。S03原粤语4→英语1→4，切后/恢复后3/10/30实际电影图与普通回原详情已核；恢复3秒仍转圈，内部恢复1571/3956ms、telemetry换轨stall1100/3100ms，非听音/精确屏幕或速度P。首窗codec名称谓词错误在选轨前停止，连续原XML已证面板打开，失败保留；只修私有语言行定位后完成。两窗2 Play/0手动seek/0 PiP/2音轨选取，36原轨道及其他偏好保持，自有播放/采集守卫停、WDA1/1/auto10/2/Home Wi-Fi已核。Speaker/5%音量只是路由，实际AUD仍缺，28状态保持；Pad/18零操作，无新包。 同批离线已拆恢复4：底层seek约0.564秒，完成到缓冲就绪约2.958秒；恢复期间门槛为1秒，恢复后才升4秒，故不能归为等满4秒。首包/首帧队列来源仍缺，110主机报告测试通过，零新设备/源码/包。

2026-10-23 15:37：[起播后缓冲离线分层](../archive/handoffs/2026-10/2026-10-23-IPHONE13-RESERVE-ANALYSIS.md)：13旧窗正文约30.26Mbps低于同窗75.09Mbps需求，代理无主动背压；Range续接发出间隔9.027/9.251ms，无多秒空档。恢复4秒门槛与起播保护已分开，不归因NAS/Wi-Fi、不盲调缓冲。修正主机派发/选取前计时混用，109报告工具测试通过；173 App输入未变，无新设备/播放/构建/安装或功能P。接13音轨实际输出，28状态保持。

2026-10-23 10:20：[13两入口中段冷续播](../archive/handoffs/2026-10/2026-10-23-IPHONE13-COLD-RESUME.md)沿用07:33普通包，173输入/签名/本机回执与实时USB身份重新核实，无源码/构建/安装变更。文件S03保存3875.241秒→实际1:04:35→1:04:58；JF普通中段停止3876.73秒获HTTP确认→冷详情/请求/初始时钟同值→实际1:04:36→1:05:06。文件起播后5301ms再缓冲保留，JF30秒仅起播1002ms、不作配对速度/整项P。首JF冷窗容器诊断未落盘导致0 Play门槛失败保留，实时同PID日志已有正确位置；只加私有读取备选完成第二窗，未改产品。4窗3 Play/1 seek/0 PiP，36原轨道/其他偏好、普通回原详情、WDA1/1/auto10/2及自有采集/守卫停/Home Wi-Fi已核。Pad/18零操作、28状态不变。

2026-10-23 08:04：[iPhone13主线有限回归](../archive/handoffs/2026-10/2026-10-23-IPHONE13-SEEK-INPUT-BOUNDARY.md)新增Debug滑块编辑边界，07:33普通包仅13于07:36保留25完整偏好覆盖，173输入/29签名/15预检核过；旧12路线XCTest未重跑。S19/S03文件各一次深seek实际恢复/画面变化/普通回详情已看，App结束值与下游目标一致，请求比例偏差已在提交前存在，非精确配对。S03/JF对白PGS→ASS→原PGS的实际中英cue及两次切后3/10/30图已核，原轨道7→5→7、close/disappear内存match/最终外部同entry，36原轨道/其他偏好保持。此前DVT零播放失败、横屏跨读中止及即时ASS快照保留；后续启动前已原PGS，不定持续保存故障。6窗5 Play/2 seek/0 PiP，自有播放/采集/守卫停、Home Wi-Fi已看；不是实际听音/冷续播/全字幕/逐帧/完整PiP/Release验收。Pad仍06:52；18本包实时发现/解析未验证、零安装，仍06:52且首页用户暂缓。28编号状态不变。

2026-10-23 07:26：[本地原流并行准备修复](../archive/handoffs/2026-10/2026-10-23-FILE-LOCAL-ORIGINAL-RACE.md)12定向/15预检通过，06:52普通Debug包已保留数据安装13/Pad/18，173输入/29签名/逐台回执已核。13/S19、S03设备文件及S01文件/JF均有3/10/30原生图（两大文件3秒黑场），不同后续画面和正常回原详情已独立复核；JF可见属性缺失导致的误断言及首窗/source超时保留。Pad/S01文件3/10/30实际WDA PNG及正常关闭同原详情已看，前两0 Play导航失败经实际label/中文分隔符定位后补齐；Pad/JF两窗0 Play搜索选择/详情source超时保留，当前新包该单元仍TOOL。13/Pad原轨道及其他偏好保持，成功窗仅自然进度变化；不作严格配对提速/全帧/全SUB-AUD或整格P。18新包06:57已装，锁屏且用户选择稍后核首页，不再催促。最新私有包`/tmp/nastart-file-original-race-evidence`；28项状态保持，按深seek输入新证据/供给→音字幕保存→PiP接续。

2026-10-23 06:32：[13设备文件普通关闭](../archive/handoffs/2026-10/2026-10-23-IPHONE13-FILE-NORMAL-CLOSE.md)新核身份/源包后1 Play/0 PiP，实际出画及一次完成回原详情，前后可见完整路径相同。原助手复合名称断言false保留，独立图/XML核实返回；36原轨道/其他偏好保持、1进度变化，App state1/1/自有采集守卫已停、Home Wi-Fi已看。标题返回后单行截断待复核。无App改动，未关闭整项；按总账主线接起播/零速/深seek。

2026-10-23 06:26：[18最新包重新安装](../archive/handoffs/2026-10/2026-10-23-IPHONE18-REQUESTED-REFRESH.md)新现场及源包签名核对后06:26:05 Complete/lookup；25完整偏好安装前后/启动后全同，原生首页/NAS在线/Wi-Fi已看。零播放，无App源码/构建变更，不新增完整功能验收。13用户已确认收起控制中心，恢复接续。

2026-10-23 05:55：[Pad S01暂停/定位](../archive/handoffs/2026-10/2026-10-23-PAD-S01-PAUSE-AND-EXIT.md)当前05:26普通包已实见3/10/30画面及暂停38→53→38秒；3次Play请求/0 PiP（含一次进片后观测失败），正常退出仍未验：完成应答200后方向读取/timeout阻塞，助手固定竖屏假设无依据，不当App退出失败或修复。停止同条件媒体；离线已核进入前/暂停均横屏，末尾完整source读取8.003秒超时，逐次方向响应/原详情后帧仍缺。后续按实际稳定方向观测，同方向不强走旋转接口。主机守卫/显式方向只读接口70测试通过，无App源码/构建/安装变化；最终173输入/签名再核、App/Runner/host均0，29原轨道及其他偏好保持、仅1进度变化，Home Wi-Fi已看，末窗设置恢复GET未完成且Runner已停。 28项保持开放，13仍控制中心待用户给条件；18未追加回归。

2026-10-23 05:30：[瞬态观测时效](../archive/handoffs/2026-10/2026-10-23-TRANSIENT-CONTROL-AGE.md)主机guard/USB已接可选0<预算≤2秒门槛，64工具测试通过。Pad首窗1秒到期0点击保留，后窗2秒内“我的/启动台”两次实图效果通过，派发年龄1.218/0.979秒；2次过期探针均0点击。建会话期间App换PID，撤销原进程保持解释，最终按新PID/出生窗清理，原生App/Runner/host均0、18完整偏好保持、Home Wi-Fi已看。0媒体/无App改动，不新增播放验收；13仍控制中心，已一次请用户收起。 28项状态保持。

2026-10-22 22:17：[13双入口暂停/15秒定位](../archive/handoffs/2026-10/2026-10-22-PAUSED-SKIP-TWO-ENTRIES.md)沿05:26普通空环境包，JF实见44→59→44秒、恢复推进及正常回详情；设备文件实见20→35→20秒、恢复23秒，最后完成按钮stale未确认正常退出，finally已停流/采集。两窗2 Play/0 PiP，早期DTX/助手state2门槛和文件导航守卫超时均零播放失败保留；最终36原轨道/其他偏好全同，仅2条进度变化，WDA state1/1及原生Home无PiP/Wi-Fi/auto10/2已核，原生进程清单不可用。不是严格速度配对或完整SUB/AUD/深seek验收，28项开放。 [18晚间安装及普通首页](../archive/handoffs/2026-10/2026-10-22-IPHONE18-EVENING-INSTALL.md)已核，18无新增媒体结果；本批不整格升级76基础单元。

2026-10-22 08:40：[Pad实际菜单与FS故障](../archive/handoffs/2026-10/2026-10-22-IPAD-TOOLBAR-OBSERVATION.md)沿05:26普通空环境包，两次只读属性/单次实际外层目标点击后菜单出现与原项关闭/返回成立，未更改排序值。新FS pair的snapshot/browser119与后窗成功分列，零Play/PiP/预览下载，不增加FF/ST/SUB/AUD/PP/完整排序或性能P；18偏好保持与收尾原生Home Wi-Fi已核，18按用户暂缓。

2026-10-22 08:28：[13样本探查](../archive/handoffs/2026-10/2026-10-22-NATURAL-SORT-SAMPLE-DISCOVERY.md)只见补零集号、缺已知/缺失混合；[Pad两窗](../archive/handoffs/2026-10/2026-10-22-IPAD-FILE-SORT-CURRENT.md)只新增正常导航/根12行观察与TOOL失败，零排序/媒体。当前05:26普通包/空环境，源包/本机回执重核，13/Pad完整偏好不变、采集停及Home Wi-Fi已看；不增加FF/ST/SUB/AUD/PP或基础单元P，L0四项为既有报告只读复核。18继续用户暂缓。

2026-10-22 07:52：[13子目录排序](../archive/handoffs/2026-10/2026-10-22-SUBFOLDER-SORT-CURRENT.md)实际三日期升/降序、六文件25KB–120GB大小与jpg/mkv/nfo类型双向顺序、四文件夹加一文件的优先规则及正常返回NAS首页均实图/AX核实。首窗重复关菜单stale失败保留，后窗删私有助手冗余操作后只接剩余场景；非App修复。两窗0媒体/预览下载，最终25偏好含36书签全同，自有App/日志停、Home Wi-Fi已核；源包05:26不变，18按用户暂缓、28项开放。

2026-10-22 07:35：[13根目录排序](../archive/handoffs/2026-10/2026-10-22-FILE-SORT-CURRENT.md)同05:26普通包12行AX同集合/升降序反转、原生图实际顺序已见；仅共享文件夹根目录，不当日期/大小/类型/完整UX-02通过。即时AFC旧值引发断言失败保留，最终25偏好含36书签完全恢复、App/日志停/原生Home Wi-Fi已核。主机只补invalid element state安全分类、18项工具测试通过，零App源码/构建/安装/媒体；18首页按用户新回复暂缓，不探测/催促，28项开放。

2026-10-22 07:20：[18当前包安装](../archive/handoffs/2026-10/2026-10-22-IPHONE18-CURRENT-UPDATE.md)按用户新授权已解除暂缓；现场iPhone19,7/iOS27.0/原配对与实时UDID核完，复用05:26普通包，07:12 Complete/lookup、25完整偏好相同。正常RSD启动两次失败/原生锁屏图保留，首页待用户打开，不重复安装。并行[13服务网页](../archive/handoffs/2026-10/2026-10-22-SERVICE-WEB-CURRENT.md)实见简洁网页隐藏App导航、回详情恢复；回Home选择器及菜单可见性守卫失败保留，两窗0媒体/25偏好全同，App/采集已停、Wi-Fi已看。无App源码/构建/测试重跑，28项开放。

2026-10-22 06:57：[当前包ASS小窗](../archive/handoffs/2026-10/2026-10-22-CURRENT-ASS-PIP.md)复用05:26普通包，13/S03/JF三张原生PiP3/10/30秒实际中英可见；一次显控后无暂停按钮，零Pause/Resume/Restore，不继承旧包往返。主窗恢复被系统目标前台守卫拒绝的失败保留，另一次正常PGS播放已恢复36原轨道/其他偏好，仅一进度变化；两窗共2 Play/1 PiP，自有App/采集/守卫均停，最终源包/auto10/2/Home无PiP及Wi-Fi已核。无新源码/构建/安装/测试，18暂缓、28项开放。

2026-10-22 06:45：[Pad进程与我的](../archive/handoffs/2026-10/2026-10-22-PAD-PROCESS-AND-MINE.md)先实测原PID state2/2挂起，激活即时前台/清理路径及后续state3守卫失败全部保留；未以PID存在冒充媒体。保存诊断后按已有授权做一次正常App基线重启，空环境读回、NAS首页/我的无恢复提示均实图/AX成立，18偏好保持、0媒体。原未知与新自有PID及Runner/host最终原生均无；无新源码/构建/安装，28项开放，不认定进程来源或NAS速度。

2026-10-22 05:56：同[Pad批次](../archive/handoffs/2026-10/2026-10-22-IPAD-CONFIGURED-RESTORE.md)继续复用既有已签名Runner，120秒有界native RSD/XCTest、ready/系统session/source/PNG与auto10/2回读通过，零构建/安装/媒体。WDA PNG倒置，原生最终Home正常/Wi-Fi已看，不当坐标/字幕验收。自有host/Runner已停；旧清理助手误要求非本窗新Nastart也不存在的失败保留并修正所有权前提，未知新PID未停止，下轮媒体先核归属。18偏好/173输入/包/签名再核，28项开放。

2026-10-22 05:45：[Pad同包正常首页](../archive/handoffs/2026-10/2026-10-22-IPAD-CONFIGURED-RESTORE.md)现场身份/173输入/签名重核，原生安装分配RSD失败保留，既有USB配对Install明确Complete/lookup、18完整偏好保持。复用05:26包，无新构建/WDA重装；单owner原生RSD/DVT一次正常空参数启动，15秒NAS在线、30秒DSM/Homepage/JF在线，其他服务警告不当全健康。已应答停止本窗PID/原生缺席、采集结束/Home Wi-Fi已看；0媒体，WDA仍未ready/未交互，18用户暂缓、28项开放。

2026-10-22 05:35：[真实保存窗口](../archive/handoffs/2026-10/2026-10-22-TRACK-SAVE-MEMORY-WINDOW.md)复用05:26普通包，13/S03/JF一窗1 Play/0 PiP，外部同key从ASS5到PGS7，正常close/disappear均ready/无pending seek、提交且同锁内存match，最终外部entry时间与disappear完全一致。旧保存故障未复现或归因，不当修复；片头无cue、不计完整SUB/AUD/流畅度。36原轨道/其他偏好保持，仅一进度更新；App/自有采集/守卫已停、Home Wi-Fi已看，18暂缓、28项开放。

2026-10-22 05:29：[配置地址恢复](../archive/handoffs/2026-10/2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md)自动恢复先并行检查已配置地址的无凭据API.Info，复用先完成的合法结果、取消其余GET，再串行POST；手动/单地址与不确定认证不重发保持。151项L0=150通过/1既有跳过/0失败、15预检；05:26正常包13保留数据安装并实见空环境NAS在线首页/我的无恢复提示，25偏好完全相同。一次约4.725秒在线采样非速度验收，Mac地址身份未绑定的TLS失败不定旧根因；0 Play/0 PiP，18暂缓、28项开放。

2026-10-22 02:46：[保存观测](../archive/handoffs/2026-10/2026-10-22-RESUME-SAVE-OBSERVATION.md)已接真实checkpoint/可选同锁内存回读/Debug强制边界安全字段；143项L0为142通过/1既有跳过/0失败，另11项既有resume/recording通过、15预检。02:35普通包仅13于02:38保留数据安装、25完整偏好一致；空环境启动DSM恢复timeout、最后AX缓存/DSM未连接，NAS在线首页与媒体保存窗未验，0 Play/0 PiP。记住地址的Mac无凭据探测TLS也未完成但未绑定实际keychain端点，不定根因/不改NAS。App/采集已停、偏好/Wi-Fi/包/当前session已核，Pad/18仍15:39历史、18暂缓，28项开放。

2026-10-22 01:31：[S01系统X关闭](../archive/handoffs/2026-10/2026-10-22-PIP-SYSTEM-CLOSE-S01.md)13/S01/JF当前19:52正常包，新增PP/EX“系统X关闭”有限切片：1 Play/1 PiP/1 Close，无暂停/继续/换轨；实际Home无窗、会话/媒体停止并返回原详情。PiP3片头/10秒黑场均保留，未作完整FF/ST/SUB/AUD/PP/逐帧P；76基础单元不整格升级、其他设备/入口待验。

2026-10-22离线补证：[轨道保存边界](../archive/handoffs/2026-10/2026-10-22-TRACK-SAVE-OFFLINE-BOUNDARY.md)确认旧失败窗seek完成后2.783秒才派发关闭，不能单独归为pending seek未完成；缺同进程保存门槛/内存entry快照，外部plist不等同内存提交。零新实现/设备/媒体/测试，不加等待或同步写盘、不改验收状态。

2026-10-22：[本地清单边界](../archive/handoffs/2026-10/2026-10-22-LOCAL-MEDIA-PLAYLIST-BOUNDARY.md)使用19:52普通包显式Debug lab，三条件零NAS媒体：慢media正文直连/代理失败、同字节即时直连取两TS并t3实际出画。仅供给/消费者反例，非候选warmup/普通入口、SUB/AUD/PP/性能或完整帧验收；76基础单元历史不改、新P为零。两次零请求控制失败和全部收尾保留，Pad/18未操作。

2026-10-21 20:08：[候选错误链诊断](../archive/handoffs/2026-10/2026-10-21-CANDIDATE-REQUEST-DIAGNOSTICS.md)19:52正常Debug仅13完成保留数据安装/正常首页；136项L0/1跳过/0失败、15预检不作矩阵P。13/S03/JF/PGS两窗各1 Play/0 PiP，KS原流降档AV候选均未解码/提交，媒体清单未收齐且客户端header=false/body=0，保留失败；最新NSError为-1008→CoreMedia/-12884、URI缺失。普通退出与清理已核，完整FF/ST/SA/PP及Pad/18未验，旧15:39 ASS往返不继承，28项保持开放。

2026-10-21 19:49：[候选请求诊断](../archive/handoffs/2026-10/2026-10-21-CANDIDATE-REQUEST-DIAGNOSTICS.md)已接route内精确关联、AV失败快照和清单收/发分计；132项L0/1跳过/0失败、15预检，19:36正常包仅13保留数据覆盖/空环境首页NAS正常，25项偏好一致。一窗1 Play/0 PiP已正常退出：媒体清单仅上游437124/1529038bytes，client header=false/body=0，item失败后才撤route；errorLog为空/access URI缺失，未定位具体AV失败资源，不作播放修复或P。36原轨道/其他偏好及Home/Wi-Fi清理已核。Pad/18仍15:39历史包，18按用户安排暂缓，28项开放。

2026-10-21 19:09：[PiP往返与PGS候选失败](../archive/handoffs/2026-10/2026-10-21-PIP-FAST-INPUT-ROUNDTRIP.md)沿用15:39普通包，零源码/构建/安装。13/S03/JF的ASS系统暂停/继续/恢复全屏各一次实际效果与画面成立，只计有限功能切片；旧stale不归单纯延迟，系统X关闭/完整SUB/AUD等待验。PGS下一窗显控无按钮、零系统指令；进入PiP前AV/localHLS候选item失败/-1008、等待帧阶段27.376秒后结束且未提交，主KS原流后续仍缓冲；不归字幕或PiP，不重播同条件。 离线候选trace又绑定master清单完整873bytes/7.229秒，media清单仅上游收170692/1527158bytes、未重写/完整发送、未见分片请求，item失败后才撤route/-999；clientReadEnded仅对端写方向EOF，不证明接收停止。三窗2 Play/2 PiP，36原轨道/其他偏好、清理/Wi-Fi及19:05包/WDA回读已核。18已最新安装但用户选择稍后首页核验，不再切前台或催促，28项开放。

2026-10-21 18:39：[18晚间更新](../archive/handoffs/2026-10/2026-10-21-IPHONE18-EVENING-UPDATE.md)按用户已回家条件，现场无线身份/173输入/签名核完后，18:34 Complete/lookup及25项完整偏好逐值一致。已为15:39最新普通包，无新构建；空环境启动后实际其他用户App前台，首页/播放不计通过。新保存内部主登录约1.77秒/FileStation约1.18秒成功，非首页或性能验收；用户选择稍后验证、先其他工作，不再切前台或催促，28项开放。

2026-10-21 18:24后续：同批复用既有App session指定系统目标，已读真实PiP浮窗并按现场矩形显控；暂停尝试1返回stale、未确认效果，无继续/恢复，不算往返通过。八窗合计6 Play/3 PiP，最终显式PGS/36轨道/其他偏好、无App/Home无PiP/Wi-Fi/WDA设置回读已核；全部自有流量/守卫结束。先处理瞬态按钮输入，不再同路径重复媒体；详见[本批归档](../archive/handoffs/2026-10/2026-10-21-ASS-PIP-NATIVE.md)。

2026-10-21 18:10：[普通包ASS PiP实拍](../archive/handoffs/2026-10/2026-10-21-ASS-PIP-NATIVE.md)13/S03/JF空环境沿用15:39包，3/10/30秒实际系统小窗中英文字可读。系统session创建超时，零暂停/恢复，不当完整PiP通过；未显式选轨的恢复失败及两次零媒体导航菜单失败保留。等首页恢复/目标稳定后显式PGS7，真实起播与36书签原轨道已核，其他偏好一致；App/采集/守卫已停、Wi-Fi及WDA设置回读已核。零源码/构建/安装，Pad/18未操作，28项保持开放。

2026-10-21 16:49：[竖屏与ASS真片补证](../archive/handoffs/2026-10/2026-10-21-PORTRAIT-VISIBLE-PANEL.md)沿用15:39普通包，零源码/构建/安装；13设置目标稳定且完整可见后实际竖屏、35/45秒中英文字已看，早前过期/裁切目标失败保留。ASS切回PGS派发后书签仍旧ASS，已用正常PGS播放恢复36书签原轨道，保存不一致根因待查。五Play/零PiP（含失败与恢复），App/采集/守卫已停、偏好/原生Wi-Fi与各窗崩溃清单已核；不作完整SUB、PiP、字号配对或18原图通过，28项开放。

2026-10-21 15:49：[认证异常响应修复](../archive/handoffs/2026-10/2026-10-21-AUTH-AMBIGUOUS-RESPONSE.md)125项L0/1跳过/0失败、15预检，15:39普通包13/Pad空环境首页/目录与25/18完整偏好已核；缺SID/HTTP502反例只属本地URLProtocol，不新增播放矩阵P、NAS性能P或18旧timeout根因结论。18离家暂停；竖屏/实际文字/完整PiP缺口保持，历史失败保留。

2026-10-21 12:36：[NAS冷启动观察与提前发布](../archive/handoffs/2026-10/2026-10-21-NAS-COLDSTART-COMPARISON.md)已移除FileStation会话发布对可选LAN发现的依赖，保留operation/auth generation与取消校验、原快照/凭据顺序。121项L0/1跳过/0失败、15预检；12:26正常Debug已保留数据更新13/Pad，空环境首页/目录真实图及25/18完整偏好一致。13当前实时三类目录响应成功，同pair先发布、1886ms后LAN后发布，非整体提速验收。07:14包与DS One各一窗默认体验探路不足5配对，配置/缓存条件不齐，不报性能胜负；查询/角色/计时前置失败保留，无新播放P。18离家暂停仍05:31，慢POST来源/竖屏/完整PiP待验，28项开放。

2026-10-21 07:14批次：[NAS恢复与字号修复](../archive/handoffs/2026-10/2026-10-21-NAS-RECOVERY-CAPTION.md)已生成07:14普通Debug，173输入/签名/IPA核完，124项L0/1跳过/0失败、15预检。13/Pad保留数据更新并实见空环境首页/NAS在线，25/18完整偏好一致；13先恢复提示、5.53秒采样在线，不计NAS速度或DS One对照P。真片竖屏两次旋转效果未确认、已停两轮并保留失败/清理，字号仅计真实SwiftUI像素证据。18按用户明确要求离家暂不操作/更新，仍05:31包，等回家重新核包。POST超时来源、真实字幕/完整PiP/性能仍待验，28项开放。


2026-10-21 06:54：[18正常首页补核](../archive/handoffs/2026-10/2026-10-21-IPHONE18-NORMAL-HOME.md)已沿用最新05:31包，现场配对身份/源码/签名/哈希及空环境真实首页、25项完整偏好一致；未构建/重装。NAS未连接仅为实际首页状态，不归因旧HTTP502/API119/VPN。既有WDA实际安装有效标记但原生XCTest启动被系统拒绝，零UI会话/媒体；最终设备已解锁且其他用户App前台，保留现场。18竖屏/外置文字/PiP未新增P，28项开放不变，不重复催解锁或无依据重试。

2026-10-21最新：[普通Debug兼容HDR字幕](../archive/handoffs/2026-10/2026-10-21-PIP-PQ-NORMAL-DEBUG.md)为05:31包/空环境，不再借用显式候选证据。三台数据保留安装，13/Pad正常首页；Pad S03/JF KS原流系统PiP3/10实际中英PGS可见，白点/四surface/别名自检通过。13普通输出true但两稀疏截图无cue不记SUB呈现P；13竖屏搜索失败与无唯一现有tile两次零Play/PiP保留。后续13资源库HTTP502/首页NAS未连接已留存，不归119或VPN。早前显式候选两台实见与暂停恢复两次零指令失败单列，不回填普通/闭环结果。Release/不满足准入仍保护，HDR10兼容基础层不作DV动态输出；外置文字、听音、全帧/长稳/完整PP与18原片未验，28项仍开放。18已安装、其他用户App前台保留，未强切。全部Wi-Fi、收尾停App/自有Pad Runner及原SSID图标、偏好/零新增崩溃已核。

2026-10-20 23:06：[18竖屏字幕反馈](../archive/handoffs/2026-10/2026-10-20-IPHONE18-CAPTION-VIDEO-RECT.md)为21:39包真实失败，外置文字落整屏底；PiP 4K PQ有cue被hdrPQPreserved跳过也仍失败。新23:03包共用视频矩形定位已接，4项几何/实际像素L0正常通过并安装18/核普通首页与数据；新包电影竖屏、双入口/两设备SUB及PiP/HDR/帧时间均未新增P。历史失败不删除。

2026-10-20 22:47：[系统暂停观测](../archive/handoffs/2026-10/2026-10-20-PIP-PAUSE-OBSERVATION.md)只有诊断源码/离线反例、三次导航级尝试，零Play/Pause/Restore，不增加PP/PA/EX/SUB/AUD/帧时间P。13/18最新21:39包正常首页已核，Pad旧App。两端已有WDA系统session/source/PNG成功，Pad随后DTX断连不算稳定；[18安装及25项完整偏好一致](../archive/handoffs/2026-10/2026-10-20-WDA-REUSE-IPHONE18-UPDATE.md)不当播放验收。

2026-10-20接续：[USB/session36项及私有8项集成](../archive/handoffs/2026-10/2026-10-20-WDA-USB-SESSION-INTEGRATION.md)已接新助手；13现有原生设置页只读实测成功，原Wi-Fi重新核实。未发点击/播放/设置变更，不新增任何电影PP/PA/EX/SUB/AUD/帧时间P；旧两次工具失败与Pad延迟画面缺口保留，暂停仍需新同trace事件与独立实际观测。

2026-10-20离线证据：[WDA边界17项及Mac元数据36帧](../archive/handoffs/2026-10/2026-10-20-WDA-QUERY-ACTION-BOUNDARY.md)只验证工具查询/动作规则与生成Main10硬件编码/解码载体。没有新设备单元或PP/SUB/AUD/帧时间P；旧13恢复目标缺失、Pad查询stale与延迟画面缺口保留。HLG Auto/None、PQ静态字段分列，不当真实DV影片/iOS/字幕修改后元数据或资源上限验收。

本批只追加两个指定PP恢复/EX普通退出操作的证据，基础单元与PP整项仍进行中，不将稀疏电影图、无cue或内部零stall升级为ST/SUB/AUD/完整帧验收。13文件和Pad JF均同包KS/1280×688/420v/ITU_R_709_2，无字幕合成；手动Home分列，不算自动Home。未重跑13 JF/Pad文件或HDR/S19，旧失败不由此次成功覆盖。

2026-10-20最新：[PiP帧归属修复](../archive/handoffs/2026-10/2026-10-20-PIP-FRAME-OWNERSHIP.md)已接实际工厂，active/完整plan UUID/弱owner先于cue/cache，KS/AV开始设身份、断开失效。10定向9通过/1模拟器PiP不可用跳过，15预检；16:16普通Debug一次构建，13/Pad均保留数据覆盖并核空环境首页。S01三媒体窗/13文件API119阻塞，基础四单元未全过；Pad/JF及13原流S19系统按钮回App，13延迟字幕变化可见，退出/控件工具失败均保留，不算完整PiP验收。13 PQ位图仍被保护跳过；共享IOSurface别名/移附件已否定token全局预算，未接产品。媒体及自有Pad Runner/守卫已停，原Wi-Fi/偏好/零新增崩溃核实；28项开放。会话离线复核已完成：同一新附加/已发布pair的snapshot2/browser6均119，否定仅browser旧会话；后续新pair成功、失效来源未知，不盲重登/重播或构建。

2026-10-20接续：[HDR字形/PGS16组](../archive/handoffs/2026-10/2026-10-20-HDR-PIP-GLYPH-AND-LIFETIME.md)仅Mac CoreText及生成PGS经FFmpeg解码，非电影PGS/iOS路线；活跃像素正确不抵消CLI t1起始缺帧。跨格式CMSampleBuffer持有反例与参考白编码校准不计手机SUB/PiP/HDR/帧时间P。未改App/包/设备，继续保留真实HDR原帧保护失败及完整验收缺口。

2026-10-20后续：[HDR PiP离线八组](../archive/handoffs/2026-10/2026-10-20-HDR-PIP-POOL-AUDIT.md)仅Mac合成中性源/alpha条带，覆盖PQ/HLG、全/视频范围、1080p/4K及池耗尽/恢复；没有真实字幕画布、设备/媒体播放或App修改，不新增SUB/PiP/HDR/帧时间P。仍按实际路线、转移、动态元数据、参考白及资源分别验。

2026-10-20 14:33：[普通入口真实蜂窝时长观测](../archive/handoffs/2026-10/2026-10-20-REAL-MANIFEST-TIMING.md)：13当前14:20普通Debug/空环境S03双入口各20秒，t10/t20实际出画/变化且普通退出；TARGET5/首EXTINF4.004、首片单GET/h2等头2836/2506ms。用户报告弱蜂窝，导航前原生4G/2格（非同窗无线定量）；RSRP/RSRQ/SINR未知。JF10Mbps/PGS7、文件12Mbps/Off不作严格配对，startup stall1及退出-999保留，无完整SUB/AUD/逐帧/Release或整项新P。两窗停流/原SSID和Wi-Fi图标、偏好/零新增崩溃已核；Pad旧包/18离家不操作。

2026-10-20本批：[认证代理六窗](../archive/handoffs/2026-10/2026-10-20-PROXY-LAB-CONSUMER.md)是13:50普通Debug的显式lab注入，实际AV→生产HLS代理→本地保存TS；6窗t10实际出画、master冷/预热双GET与读者失败完整保留，时长反例不算优化。无NAS媒体/蜂窝、无普通入口/完整听音字幕/逐帧/Release新P。旧真实窗TARGET/首片EXTINF未知，不用均值回填；下一真实同输出窗补观测。13新包/空环境/原Wi-Fi/偏好/零新增崩溃已核，Pad仍09:47包，本批未做其当前源码新包回归。

2026-10-20 13:12：[iOS本地消费者对照](../archive/handoffs/2026-10/2026-10-20-IOS-LOCAL-HLS-CONSUMER.md)复用四窗、补一窗。实际systemAVPlayer但为Debug lab直连本地HLS，无认证代理/普通入口/NAS媒体/蜂窝；master三窗双GET、媒体清单延迟窗单GET，元数据纠正未消除。五次普通串流零请求工具失败及另一次点击保留。旧候选蜂窝供给/ready离线拆分不是09:47包新验收，本批不新增FF/SK/SUB/AUD/帧时间P；13原Wi-Fi/空环境/偏好与零新增崩溃已核。

2026-10-20 停用结论：[单字节候选真机结果](../archive/handoffs/2026-10/2026-10-20-STARTUP-SEGMENT-PRIMER.md)13 S03蜂窝JF/文件内部9.657/6.224秒、stall1，确有206/1byte和同输出各单一编码任务，但未证明可靠收益；JF首片约4秒后客户端重发，随后旧发送EPIPE，非重复转码。两入口已恢复原清单预热调用，09:47普通停用包已覆盖13/Pad并核首页/Wi-Fi，7定向/30工具/15预检；此前09:06四窗仅候选历史。下一步手机受控请求边界，不能断言通用4秒超时；18离家不操作。

2026-10-20 当前候选：[共用单字节首片准备](../archive/handoffs/2026-10/2026-10-20-STARTUP-SEGMENT-PRIMER.md)已实现，仅蜂窝从头/完整同源VOD/真实首片0，route单次且独立5秒取消、异常Range/重定向/续播隔离；7项iOS/30项报告工具/15预检通过，09:06普通包已构建签名。13已覆盖并看空环境首页、S01 JF普通退出，其他回归接续；性能收益尚未验收。18离家仍06:48包，不挪用旧安装结论。

2026-10-20 蜂窝接续：[首片重叠收益边界](../archive/handoffs/2026-10/2026-10-20-STARTUP-OVERLAP-BOUNDARIES.md)离线复核当前绑定窗口：首片派发前JF/文件3.902/3.086秒，等头回调2.699/2.141秒；完整清单后才primer的排程重叠上限仅1.172/0.471秒，非实际提速。清单前缀方案还缺可信VOD/URI到达/取消及续播反例，不直接固化；首片后还在取后续片，不归为纯AV等待。未新增产品实现或真机P。

2026-10-20 新增执行证据：[重新连接与PiP专项](../archive/handoffs/2026-10/2026-10-20-RECONNECTED-PIP-ROUTES.md)。S01四单元只记基础出画/普通退出，Pad文件stall1保留。PiP交叉维度必须按实际KS原流/AV HLS、SDR/PQ/HLG/DV、文本/PGS/外置/服务端烧录及后台/恢复/关闭分列：13 S19/JF PQ位图cue被跳过为当前失败；Pad烧录可见不等于原流通过。设备文件本批PiP未测，不能回填。完整往返、SUB/AUD/帧时间仍无新增P；32×32 Mac HDR原型不计真机单元。

2026-10-20最新：[输出关联诊断](../archive/handoffs/2026-10/2026-10-20-CLIENT-OUTPUT-CORRELATION.md)已修Params观测缺口，13 S03真实蜂窝双入口分别21/34请求精确对应唯一编码任务；首片等头2717/2199ms，内部推进8.583/6.909秒，预算/字幕不同不作提速比。5项iOS定向/28项报告工具/15预检及06:48普通Debug签名核验通过，13/Pad已覆盖，18也已[USB安装及正常首页验证](../archive/handoffs/2026-10/2026-10-20-IPHONE18-USB-INSTALL.md)。用户带18离家，后续仅13/Pad；所有蜂窝已停流并实际恢复原Wi-Fi。1字节首片准备仅协议可行性，未产品实现/性能验收，28项仍开放。

2026-10-20当前：[同片S19内网补窗](../archive/handoffs/2026-10/2026-10-20-S19-LAN-COMPARISON.md)双入口45秒原流KSPlayer，内部3.836/2.143秒、maxStall0，原Wi-Fi/轨道偏好/零新增崩溃已核；与蜂窝HLS不同输出分列，字幕内容仍待验。[分片时长对照](../archive/handoffs/2026-10/2026-10-20-SEGMENT-DURATION-COUNTEREXAMPLE.md)10次尝试/9个完成媒体窗/1个清单守卫失败已收尾：S03取齐4.004秒媒体，2秒片约1.96～1.98秒、4秒片约2.42～2.57秒，但S19的2秒完整清单声明5.67MB，触发工具3MiB上限且未取媒体，不盲改segment4/min1。旧蜂窝大清单单次0.582/0.709秒，不能解释全部起播等待；App已允许清单压缩协商；[初始零定位反例/主日志补证](../archive/handoffs/2026-10/2026-10-20-AV-ZERO-SEEK-AND-SERVER-LOG.md)未支持删除零定位或“重请求即重启编码”，客户端直接任务绑定仍缺，未做新产品修复/真机验收。19日22:20包不变，13/Pad已覆盖，18数据服务重置未发包；28项开放。早期日期保留历史状态。

TV边界补充（2026-10-19）：[照片/现场复核](../archive/handoffs/2026-10/2026-10-19-APPLE-TV-PAIR-RECORD.md)仅证明电视配对记录与只读服务可达；开发目标/签名安装/真机播放仍未就绪，不计手机或TV播放通过。

2026-10-19 19:15接续：[18更新与有界回归](../archive/handoffs/2026-10/2026-10-19-INSTALL-AND-BOUNDED-PLAYBACK.md)：周期调度已删除，18最新同签名程序安装及数据/正常首页已核。13固定2Mbps PGS诊断6.391秒、首片等头2321ms，Off工具失败未配对；原Wi-Fi/空环境/轨道恢复，零新增崩溃。Pad正常JF内部起播3.705秒/文件5.526秒；文件静态预测触发后容量恢复仍提交，maxStall=1；既有Debug reserveOnly隔离窗已完成，结果与限制见交接。候选容量恢复撤回规则尚未实现；产品及17:16包不变，28项开放，不把诊断开关视为交付。

2026-10-19 18:21离线归属复核：[S03日志审计](../archive/handoffs/2026-10/2026-10-19-S03-CELLULAR-SESSION.md)确认4份服务端声明同一片源54,005,939,750bytes/相同ETag，但缺PlaySessionId/请求身份，不能回填客户端任务归属或冷启动耗时。下一步条件明确为既有Debug仅JF固定2Mbps、从头PGS/Off诊断（未执行、非产品优化），须先排除活动媒体任务；无新请求/构建/设备动作，28项开放。

2026-10-19 18:13实测：[S03蜂窝会话窗口](../archive/handoffs/2026-10/2026-10-19-S03-CELLULAR-SESSION.md)13双入口各从头45秒，内部起播JF7.821/文件6.741秒；首片均单GET等头2362/2628ms，旧15秒故障未本窗复现但未修复。JF4Mbps/PGS7、文件10Mbps/Off不作严格配对；33次只读会话补JF DeviceId/S03关联，文件未上报Playing不作无流判断。两轮已停流并核原网络/Wi-Fi；事后另项目活动任务报告Mac首片探针，不能排除重叠，不作干净性能环境。四份服务端日志未绑定归属，产品/17:16包未变，28项开放。

2026-10-19 17:49离线核对：[输入快照审计](../archive/handoffs/2026-10/2026-10-19-SEEK-INPUT-SNAPSHOT-AUDIT.md)确认两窗精确时长同为7165.01秒，差异在seek_started已提交且UI文字吻合，整数50%掩盖不同落点；尚未定位WDA/控件松手偏差。产品及17:16包未改、无新设备/媒体请求。严格seek配对继续受阻，从头PGS/Off首片调查独立推进，28项开放。

2026-10-19 18:24最新：[PGS/Off首片协议对照](../archive/handoffs/2026-10/2026-10-19-PGS-FIRST-SEGMENT-PROTOCOL.md)14窗已按独立会话收尾；Mac私网三次/条件约2.2秒，公网curl单窗/条件约2.44秒、连接后约2.21秒。公网Python慢值被IPv6顺序建连干扰（一次7.43秒ENETUNREACH后IPv4成功），不能重标旧iPhone复用h2的15秒等头。首片均相同H264852×480，非真机/字幕/听音验收；产品和17:16包不变，28项开放。

## 当前执行版：2026-10-22

18时协议补证：只读真实源的PGS7/Off首片控制不依赖seek手势，HTTP/1.1 open→头包含建连，不与URLSession requestMs混算；Mac IPv6失败回退已单独举证。14协议首片没有新增真机FF/SK/SUB/AUD/帧时间P，ASS5/6及用户报告弱蜂窝仍待实际覆盖。

本节更新**怎样选样本、比较网络、测量等待及结束一批回归**，不重置后文历史状态、不新增产品需求编号。正式范围仍为 19 部电影 × iPhone/iPad × 设备文件/Jellyfin 的 76 个基础单元；iPhone 13 与 iPhone 18 的结果必须另列，网络/构建/缓存/实际路线也另列，不能把“76”当全部设备及网络组合数。

当前技术实现看[播放技术路线](../architecture/VIDEO_PLAYBACK_PIPELINE.md)，问题和依赖计划看[开发状态](../project/DEVELOPMENT_STATUS.md)，任务状态仅看[总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。下方有日期的旧接续、网络限制和传输描述保留当时证据；当前执行采用本节、最新规范和当前源码，不按旧记录恢复已撤回策略。

本批风险补充：S03按实际PGS7/Encode（JF）与Off（文件）记录，不能按历史ASS标签算ASS覆盖；两入口完整VOD时长相同，但原生滑块请求0.5的实际seek目标3739.868/3676.824秒不同，受控配对前先修输入/核目标。TC-02保留同一child首片所有重请求、迟到200及取消回调，不只选第三条成功响应。此前S19预算/字幕仍分列。

对照配置补充：已核实存在的Debug `NASTART_TEST_STARTUP_HLS_BPS=2000000`可用于后续同JF入口PGS/Off初始HLS诊断，未在本批运行，设备文件不受其控制。显式记为注入条件，核实际协商、输出、轨道和缓存，结束还原空环境/偏好/Wi-Fi；不与普通默认窗口或Release混合计分。同MediaSourceId/ETag只证明服务端声明来源，不等于同客户端任务。

会话判定补充：TC-02两入口按实际协商分列；/Sessions同DeviceId/NowPlaying仅在该入口确实上报Playing时提供证据，文件兼容tracker无Playing上报，空值不判无流。服务端TranscodingInfo尺寸不升级为解码/输出验收。Wi-Fi收尾遇源树/截图延迟需保留失败并用独立原生截图核原网络及图标，恢复前停止自有App。

输入判定补充：TC-05按实际提交目标及UI文字核，不以整数50%判同点；固定从头0秒的TC-02不依赖TC-05校准，PGS/Off首帧调查可先独立推进。快照与源树顺序采集，不当同步触摸证据。

17:29校准补充：S01原生归一化0.5及暂停后实际拇指拖动均未达到跨入口1秒目标容差，不能按相同请求比例配对；前者文件还在首帧前加载，后者已暂停并看可辨画面。两种候选已停止，失败不删除；没有新基础单元P或首帧/seek性能结论。最新包/设备按当前交接重核，Pad/18未装17:16包。

清单计量补充（12:51）：逐窗区分大媒体清单首次上游读取、本地VOD命中及小master再次读取，不能把本地重写当重复NAS下载；delegate解码后字节、线上计数和实际计费另列，未知不填0。8项现有本地fixture通过，仅验证缓存/Params/seek/live/持续响应边界，不新增真机P。见[离线审计](../archive/handoffs/2026-10/2026-10-19-MANIFEST-PATH-AUDIT.md)。

13:19历史反例（当时Pad仍旧包）：认证复核期间再次变蜂窝路径，需保留首次拒绝、稳定等待和重新协商/重复清单的全部时间，不能以第二次成功覆盖失败。新字节字段区分含协议接收计数、解码后正文、Content-Length和编码枚举；历史无字段不追填，非计费数据。当时13两窗与S01两窗均非整项P；最新13/Pad包身份按当前交接另核，不继承历史包通过。

### A. 按容量与格式选代表样本

容量分层用于选样，不是给各容量硬编码参数。以下 GB 为十进制近似值，正式比较仍冻结精确字节、时长、文件版本、轨道及源/实际流的分辨率和码率。不能只按体积判断带宽需求：5.2 GB 的 4K 和 12 GB 的 1080p 仍有不同解码/字幕风险。

| 容量/格式层 | 固定代表与已知特征 | 着重项目 | 扩展或缺口 |
| --- | --- | --- | --- |
| ≤5 GB 基线 | S01，约 2.7 GB，MKV/H.264/720p | 两入口起播、暂停、±15秒、退出/续播、基本音字幕 | S13约4.8 GB用于另一1080p交叉样本；次GB短片覆盖尚缺，不伪造现有样本 |
| >5～20 GB 压缩视频 | S08约5.2 GB MP4/4K/HEVC 10-bit/HDR/双音轨；S04约17 GB HEVC | 容器差异、硬解/色彩、尺寸、切轨、内存；MP4首部/尾部索引按实际核验 | S07约11 GB H.264与S10约7.2 GB 1080p HEVC 10-bit补不同编码/位深 |
| >5～20 GB 兼容音频 | S11约16 GB HEVC 10-bit/TrueHD/多音轨 | 实际有声、切轨后恢复、原流/转码选择、暂停中切轨、连续性 | S02 LPCM、S18 FLAC为音频格式族补充，容量未核不得强行分档 |
| >20～<100 GB REMUX | S03《碟中谍3》，历史约50～54 GB，MKV/4K/HEVC/TrueHD/ASS | 大文件认证/索引、真实蜂窝首帧和零速、深seek、音轨/文本字幕、十分钟供给 | 不同历史容量可能是单位/版本差异；每批重核同文件，不混合比较 |
| ≥100 GB 长时间轴 | S19《指环王1》，128,795,641,934 bytes 已有响应证据，PGS/多音轨 | 首片等待、>4 GiB偏移、50%/接近尾部seek、旧cue清除、PGS、稳定供给/内存 | 实际DV/Atmos输出独立验证，文件名不算；不由S03或小片代替 |
| 容量非主要风险的格式 | S05交错H.264、S02 LPCM、S18 H.264/FLAC | 受影响的解码/音频格式族及另一目录/文件入口 | 新识别字段回写固定样本定义，不按片名推测 |
| 独立专项 | ISO、增长TS、TV01～03剧集、外置字幕、多终端 | 索引/增长、季集身份、字幕访问、会话隔离与续播 | 不计入76单元通过率；缺样本/不可达写明，不能用REMUX代ISO |

样本真实身份仍维护在[固定清单](samples/README.md)。扩展样本先核对可达性和规格，不因本节增加容量分档就自动增加已执行覆盖。

2026-11-08 [S19 恢复后抽测](../archive/handoffs/2026-11/CODEX-2026-11-08-LORD-OF-THE-RINGS-PLAYBACK.md)：设备文件的 `Content-Range` 总量 128,795,641,934 bytes，13 Wi-Fi 原流出画，识别 Dolby Vision Profile 7 源；15 秒定位、50% 实画成立，50% 首次恢复后再次缓冲。十分钟窗口记录 9 次缓冲，未通过稳定性；设备输出和同条件 NAS 负载仍开放。Jellyfin 401 单列，iPad 未回归，不增加整格通过数。

2026-11-08 [S19 iPad 续测](../archive/handoffs/2026-11/CODEX-2026-11-08-S19-IPAD-LAN-COMPARISON.md)。同包 Wi-Fi 设备文件开头 200 秒，iPad 记录 0 次缓冲，13 历史窗 1 次。Pad 中段实际画面、SMB 和 FTP 同片短播及三入口正常退出成立。FTP 一次缓冲，SMB 该窗未记录缓冲。十分钟 iPad 稳定性、设备输出和同条件 NAS 负载仍开放，未新增整格通过。

2026-11-08 [S19 中段对照](../archive/handoffs/2026-11/CODEX-2026-11-08-S19-DEEP-SEEK-AB.md)。13 两个同落点窗均出现二次缓冲，2.5 秒门槛候选首次恢复更晚，已撤回。Pad 正式包另一中段点短窗连续推进。稳定性整格保持开放。

### B. 设备、网络与入口维度

| 条件 | iPhone 13 | iPhone 18 | iPad | 记录要求 |
| --- | --- | --- | --- | --- |
| 内网 Wi-Fi / 实际私网上游 | 双入口基线与回归 | 最新包安装核对后补同场景复核 | 双入口及设备差异基线 | 不能只凭Wi-Fi图标；记录实际端点归属/引擎/协议 |
| 真实蜂窝 / 公网上游 | 当前主调试设备，新SIM已解除旧流量限制 | 条件允许且不影响用户使用时做最终设备复核 | 仅现场确认有蜂窝能力才执行 | 关手机Wi-Fi并核URL metrics cellular；记录LTE/5G/VPN已知状态，不擅改VPN |
| 外部 Wi-Fi / 公网上游 | 条件可用时做解耦对照 | 条件允许再补 | 条件可用时执行 | 区分公网延迟与蜂窝路径；家中公网域名不直接归入外部Wi-Fi |
| 网络切换/中断/恢复 | 定向专项 | 待设备条件明确后复核 | 按真实硬件/链路记录 | 记录变化时刻、恢复与用户意图；热点不标iPad直接蜂窝，人工限速不替代真实网络 |

每次开始、切换设备、源码改变后均执行[最新包门槛](../../AGENTS.md)，保存身份/签名/安装/普通启动证据。只更新一台不能代替其他设备；18安装成功但未正常启动/播放，仍不是本轮通过。默认普通构建、空测试环境；性能构建及注入条件独立列组。

2026-10-19用户确认当前iPhone13蜂窝信号偏弱：本地点后续窗口单列“用户报告弱蜂窝”，记录实际无线制式、可见信号状态和同窗吞吐/首字节，未测RSRP/RSRQ/SINR保持unknown。弱/普通/强信号及外部Wi-Fi分组，不将本地点结果推广为一般蜂窝体验；旧窗没有同窗信号证据的保留未知。弱信号可能影响性能，不能据此排除客户端重复准备、输出预算/字幕分叉或时间轴问题，仍须检验弱网下恢复和画质底线。

随后用户要求独立验证，本轮手机端有限下载得到公网NAS 3×8MiB整体约38～44Mbps、独立源3×2MiB约20～32Mbps，短窗均完成；不支持将当前所有结果径直标成“实测弱蜂窝”。当前分类为“实际4G、用户报告偏弱、无线强度未证实”，无线指标未知仍保留，需将信号/吞吐/高码率供给不足分开。大文件仍测，不以测速替代播放，也不据短窗保证持续原画。

[本批S19三窗](../archive/handoffs/2026-10/2026-10-19-CELLULAR-LINK-ASSESSMENT.md)：蜂窝文件/JF内部深seek7.931/6.163秒、首正文2.941/3.261秒，实际20/10Mbps及字幕Off/8-Encode；Wi-Fi文件30秒未恢复、目标6734.415秒与蜂窝6783.602秒不同。保留失败、旧cue与条件差异，不合并严格配对或升级19×4单元。三窗已退出并核实原Wi-Fi连接。

[共用测速协议开销候选回归](../archive/handoffs/2026-10/2026-10-19-PROBE-PROTOCOL-FRAMING.md)：37定向规则/新包13核安装，S01双入口各30秒maxStall0但完整音画未验；S19两入口已取得networkBody。文件初始HLS12后仍降2Mbps，深seek5.012秒/目标6808.195秒；JF45秒未进页，准备两次被路径校验取消、seek未测。前述旧三窗不作新源码回归，不作不同目标/预算提速聚合，Pad/18待后续。TC-01/02增加准备结果发布及取消原因核对；正常/失败finally均恢复原Wi-Fi，最终图标实际已看。

### C. 当前问题驱动的测试项目

下列 TC 标识仅便于引用测试步骤，关联既有 FF/ST/PA/SK/AT/SU/SA/EX/MEM 等，不是新增需求状态表。

| 项目 | 操作与样本 | 必须观察的边界/失败 |
| --- | --- | --- |
| TC-01 点击反馈与准备 | S01、S03、S19两入口，从头与续播分别测 | 点击→页面呈现；目录/认证/匹配/协商等待；取消可用；错误有阶段；不能只记录播放器已启动 |
| TC-02 首帧与零速 | 同上，内网/蜂窝分别，明确实际KS原流或AV/HLS | 请求发出→响应头→首正文→解码/输出→可辨画面；未知速度与可靠0速分开，零速时长与当时阶段、是否缓冲关联 |
| TC-03 连续供给 | 首帧后至少30秒；稳定后对代表大文件路线补十分钟 | 连续画面/音频、缓冲次数/总时长/最长、连续储备与字节；刻意seek造成的stall不计作自然播放卡顿率 |
| TC-04 小步定位 | 同一明确起点±15秒，缓存内与未缓存分列 | 提交→目标点引擎完成→新画面/声音恢复，绝对时间正确；误触/多次提交单列 |
| TC-05 深定位与回退 | S03/S19：从头起播后跳50%、回10%；按时长再选接近90%非片尾点 | 同文件同目标秒数跨入口/网络对照；目标偏移/首片序号、后续分片、解码与连续推进；不能只用滑块比例证明落点相同 |
| TC-06 暂停/连续快速定位 | 暂停中深seek；有界连续拖动/前后跳，再等待最后请求 | 暂停意图不丢、仅最后请求提交；旧任务不覆盖新帧/断点；恢复后仍有声/字幕正确 |
| TC-07 字幕位置与旧cue | S19 PGS、S03 ASS；控件显隐、深seek、横竖屏和适应/填充 | 底部相对整屏/视频区与黑边关系；旧cue何时清除、新位置cue何时出现；无残留/重复/裁切，不把字幕空白直接当通过 |
| TC-08 音字幕切换 | S03/S11/S18及S19，覆盖可用格式；播放/暂停→切换→seek | 点选→菜单选择→本地生效或候选准备/对齐/接手→实际声音/字幕；同轨重复选择不换源，Off后旧字幕不返回 |
| TC-09 自动兼容/降档 | 仅自然出现供给不足/不支持时观察，原失败场景优先 | 原流→HLS的触发依据、实际码率/尺寸/轨道、旧流保持、候选失败/取消、接手后至少30秒持续推进；playing一瞬后停住记失败 |
| TC-10 退出与身份隔离 | S01基础，S03/S19深位置；准备中取消、退出后重入/从头 | 正确详情、已确认断点、轨道/Off保存；停止/释放本会话，旧账号/旧源响应不串入；服务端Sessions不能独证编码进程已退 |
| TC-11 资源/生命周期 | 相关格式、反复进入退出、旋转/PiP/后台往返 | 内存峰值/趋势、退出释放、App/WDA/Jetsam、候选释放；记录工具主动终止，不能当崩溃或普通退出 |
| TC-12 真正画质/声音输出 | S08/S11/S19及实际输出设备 | 源格式、实际流/输出分别核验；低码率不卡顿不构成画质通过，PCM不冒充Atmos，元数据识别不等于HDR/DV点亮 |

TC-07/08仍需要实际内容与听音证据；自动化控件点击、菜单勾选、内部时钟或稀疏截图不能补齐缺失项。手动清晰度Q UI仍按总账暂缓，自动回退另记；PiP、剧集、ISO及竞品保留后文及各专项完整要求。

### D. 执行批次与停止条件

1. **先离线定位。** 读当前失败阶段，建立可证伪假设；规则错误先L0，不反复播放电影试超时/缓冲参数。延后AV自动等待已被真机否定，禁止直接当默认优化重新启用。
2. **先守基础，再对照大文件。** 每批相关链路修改至少S01四单元；按[影响映射](../development/playback-development-workflow.md)覆盖S03/S08/S11/S18。涉及蜂窝/大偏移/字幕时，S03和S19双入口为重点；不强迫每个小改动重做全部未来功能。
3. **网络对照分两层。** 第一层保留正常自动路线，回答真实用户体验；第二层仅在同片、同音字幕、同实际路线/码率及环境允许时做有记录的诊断对照，回答传输/解码原因。LAN KS与蜂窝HLS不合并算纯网络提速率，不为凑对照强制不可持续原流。
4. **固定变量并交错。** 同设备、同构建、同文件版本、同目标秒数及轨道；冷进程、热重开、媒体缓存和服务端缓存分别记录。未知填unknown，不清用户缓存。不同网络/入口采用交替或ABBA等顺序；至少三次探索性重复，报告中位数、范围与失败数，少量样本不报可靠P95。
5. **有界、串行。** 测前写下每阶段观察上限、总窗口、成功及非退化预算、普通退出和超时清理动作；不擅设“全片N秒”验收承诺。30秒从真实首帧后观察，十分钟另列。无首帧/卡住的超时不删掉或记0；独立守卫主动终止与App故障分开。
6. **失败即归档并判断下一层。** 原失败阻止该修复验收，同一假设两轮受控无改善则停止调参；新增持续暂停、错断点、串源、旧字幕或崩溃应先处理/撤回。正常时钟不能掩盖音画失败。
7. **收尾与升级。** 每轮蜂窝任务正常完成、失败、超时或打断后，先停止本轮播放/下载并自动恢复原Wi-Fi，核实原生已连接状态及Wi-Fi图标，然后才离线分析或结束；自动化最外层`finally`执行，开关开启不算连接完成。恢复用户偏好、清理自有测试条件/任务，保留持久用户服务；回到最新普通包。L1/L2结果按实际覆盖记，Release迁移/删除旧架构/里程碑才进入L3完整范围；当前不并发大片压测，MTP继续保留待条件允许。

竞品仍需[竞品矩阵](COMPETITOR-DEVICE-MATRIX.md)规定的至少五组有效配对与相同证据边界，本节三次探索重复不降低竞品门槛。滚动成功请求不证明实际位移或帧时间流畅。

### E. 每窗最小结果字段

| 类别 | 必填内容 |
| --- | --- |
| 来源 | 日期/运行编号、源码与差异标识、Debug/Release及优化、二进制哈希；安装/普通启动核对关联 |
| 条件 | 设备型号/系统；样本ID/精确容量/时长/文件版本；入口、音字幕/Off、起点/目标秒；实际上游公网/私网、Wi-Fi/蜂窝/未知、VPN已知状态、缓存/顺序 |
| 路线 | 起始与最终引擎/原流或HLS、实际码率/尺寸/音字幕处理；换流触发、候选失败及提交 |
| 时间 | 点击/页面/准备；首请求/头/正文；decode/accepted/submitted；屏幕首帧；seek提交/完成/新画面/声音/旧cue清除/新cue；每段均注明计时起点 |
| 供给 | 正文字节、分片/Range及任务精确关联、首字节/正文耗时、连续储备、零速区间、卡顿次数/时长、协议及cellular指标；未知不补猜 |
| 结论 | 单项P/F/U/N/A/NA/TOOL；超时值及守卫终止原因另记；实际听音/字幕/显示证据；普通退出/资源/偏好恢复，失败和未执行项 |

单窗内部推进、路线观察和视觉抽查可以分别记录，不升级成整单元P。必须记录实际源轨道ID、字幕Off/外置/烧录及最终协商参数，不能仅写“偏好保持”。2026-10-19离线核实同S19蜂窝文件20Mbps/字幕Off、JF4Mbps/字幕8-Encode，原四窗保留为正常自动路线观察，不能做同档同字幕聚合。共享结果脱敏后放 `results/YYYY-MM/`，私有身份/原始日志/包/截图留仓库外，月度交接链接该结果。

本次仅优化矩阵与执行规则，**未新增真机测试结果，后文76单元及所有需求状态不变**。2026-10-19已有四窗仅提供阶段观察，详见[当批证据](../archive/handoffs/2026-10/2026-10-19-PREPARED-HANDOFF-WAITING.md)。

## 既有定义与历史记录

2026-10-07 08:14 接续：新普通主题包iPhone13三主题即时应用/重启保存已核；S19设备文件144遥测/177.631秒原流停于1.844秒，noStoredJellyfinSession待查，当前完整长度及大偏移尾索引已核。其他App前台/无线变化使后续退出/对照不可验，条件全关；S19 Jellyfin与MI2/S03双入口、全部PX/UX/CB/竞品开放。iPad新包空间错误受阻、18待重连。见[本轮记录](../archive/handoffs/2026-10/2026-10-07-LAUNCHPAD-THEME-AND-WEAK-LARGE-FILES.md)。

2026-10-07 07:36 用户强调：优先补实际弱蜂窝下《碟中谍》（MI2/S03）及《指环王》（S19，100GB以上）大文件；设备文件与Jellyfin入口同步优化、分别取证回归。最新S03仅Jellyfin部分证据，MI2弱蜂窝、S19最新弱蜂窝及设备文件对应单元仍待补，不能由小片或单入口推断通过。执行[弱蜂窝大文件双入口卡](WEAK-CELLULAR-LARGE-FILE-DUAL-ENTRY.md)，既有矩阵状态保留。

2026-09-14 执行更新：本表保持 19×4 的正式验收范围和所有历史状态；日常修改使用 [L0～L3 分层流程](../development/playback-development-workflow.md)。L1/L2 结果不推算为完整矩阵通过率。手动清晰度 Q 暂缓、代码与接口保留；其未测状态保留，内部自动路由/兼容换流另行验证，不因入口隐藏改记通过。

更新时间：2026-09-12（Asia/Shanghai）

2026-09-12 用户新增 100 GB 以上《指环王 1》为 **S19**，基础矩阵扩展为 19×4=76 个播放单元。原有 S01～S18 的历史状态不变，本轮按用户要求优先执行 S19 大文件专项。文件规格、独立功能状态与证据统一记录于 [S19 专项](samples/2026-09-12-S19-LORD-OF-THE-RINGS.md)，不能仅凭容量或能打开就标记通过。

本表把“19×4 播放单元”和“每个单元要测什么”分开固定。结果填写在单元格及关联专项记录中，不能只写“能播放”。状态顺序固定为：

核心状态序列：`LIB / FF / ST / PA / SK / AT / SU / Q / PP / EX / MEM`

在核心序列之外，所有播放单元再追加补充项：`SA = SUB / AUD`（字幕显示 / 音频输出）。

- `FF` 首帧；`ST` 连续播放；`PA` 暂停/继续；`SK` 快进/快退；`AT` 音轨；`SU` 字幕；`Q` Jellyfin 清晰度；`PP` 画中画；`EX` 退出/断点续播；`MEM` 内存/进程稳定性。
- `SA` 不替换 `AT` 或 `SU`：`SUB` 验证字幕是否实际显示且内容正确，`AUD` 验证设备音频输出是否可听、连续且无异常；两项分别记录，避免“字幕正常但无声”或“有声但字幕乱码/重复”被合并掩盖。
- 每项状态使用：`U` 未测、`P` 通过、`F` 失败、`N/A` 不适用、`NA` 不可达、`TOOL` 工具失效。
- `LIB` 是入口资源加载：Jellyfin 记录媒体库首屏/海报/详情；设备文件记录目录加载和点击后的明确等待反馈。设备文件入口的 `Q` 固定为 `N/A`；Jellyfin 入口的 `Q` 保留验收要求，目前按 PX-04 暂缓 UI 测试，恢复入口后再验；没有字幕/第二音轨时仍要记录为 `N/A`，不能留空。
- `PP` 的自动化验收必须记录完整链路：DS One/Nastart 播放器入口点击 → 系统 PiP 浮窗出现 → SpringBoard 会话发现 PiP 控件 → 点击 `恢复全屏幕` → 回到播放器且断点保留。不能只记录 Home 后浮窗出现，也不能在错误的 App session 中猜测退出按钮。
- 传输策略是跨样本的验收前置条件，不允许在单元格中填入“某样本专用窗口”。设备文件和 Jellyfin 原流须记录当前实际客户端有限响应或兼容连续响应、上游有限206、精确偏移、总长度与短EOF/重试；HLS按清单/分片分列。历史continuous chunked不是当前所有分支的固定形态，窗口边界不能被误记为ST结束或EX触发。
- 单元格示例：核心项 `P/P/P/U/U/U/U/N/A/U/U/P`；补充项另记 `SA=P/P`。

## 2026-10-01：竞品真机对照必测补充

新增 [竞品对照矩阵](COMPETITOR-DEVICE-MATRIX.md)，Lenna 为 iPad/iPhone 13 主对照，DS One、Jellyfin 客户端、网易爆米花为扩展。CB-01～CB-20 覆盖从头/续播首帧、定位、字幕/音轨实际生效、滚动、网络恢复、资源与可靠性；按设备/素材/路线/缓存配对，不能用内部时钟与竞品屏幕首帧混比。保留失败/超时，数据不足明确标识，完成 5 组有效配对前不输出速度排名。

## 2026-09-07：新架构电视剧必测补充

遵循 ADR 0002，当前仅 LAN，沿用已通过的电影/HLS 证据，不因本次补充重复整个历史矩阵。电影通过不能代替电视剧通过。

| 样本 | 入口 | 必测流程 | 结果 |
|---|---|---|---|
| TV01 天才女友 · S1E1 | iPhone Jellyfin 媒体资源库 → 剧集 → 季 → 单集 | 竖屏详情 → 自动横屏播放；首帧/连续 30 秒；双击暂停/继续且不改变缩放；字幕位置/切换；seek；退出恢复竖屏；再次进入续播 | 本轮复测中，见 2026-09-07-TV-LAUNCHPAD.md |
| TV02 同剧另一集 | 同入口 | 返回季列表、选择另一集，标题/进度/字幕不继承上一集错误状态；再次退出竖屏 | U |
| TV03 同剧跨季单集 | 同入口 | 季切换、首帧、字幕、方向与退出恢复 | U |
| TV01–03 | iPad Jellyfin、设备文件 | 相同流程；按可用设备与文件记录，缺条件不记通过 | U |

## 入口缩写

| 缩写 | 含义 |
|---|---|
| `IP-D` | iPhone · 设备文件 |
| `IP-J` | iPhone · Jellyfin |
| `PD-D` | iPad · 设备文件 |
| `PD-J` | iPad · Jellyfin |

## 19×4 单元格总表

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
| S19 指环王 1（用户新增，100 GB 以上） | U，逐项见 S19 专项 | U，逐项见 S19 专项 | U，逐项见 S19 专项 | U，逐项见 S19 专项 |

## 新 iPad11 独立 19×2 单元格（2026-10-24加入）

新现场型号 iPad15,7（iPad/A16）、iPadOS26.6；`P11-D`=本机设备文件入口、`P11-J`=本机Jellyfin入口。上表`PD-D/PD-J`保留旧iPad9/iPad12,1历史，不能复用旧设备安装、首帧、轨道、性能或竞品结果。新38格均未完整验收；用户NAS登录/普通首页及S01文件、JF各30秒实际片头/正常返回已有有限证据；本地合成测试出画不计入真实样本格。旧76格与新38格合计114格，分组报告，不改变28个开放需求编号或历史失败。

| 样本 | P11-D | P11-J |
|---|---|---|
| S01 哈尔的移动城堡 | U（普通30秒片头/回同详情已核；声音/完整字幕/帧时间等未验） | U（普通30秒片头/回原详情已核；声音/完整字幕/帧时间等未验） |
| S02 杀死比尔 | U（待测） | U（待测） |
| S03 碟中谍3 | U（待测） | U（待测） |
| S04 好东西 | U（待测） | U（待测） |
| S05 南方车站的聚会 | U（待测） | U（待测） |
| S06 爱情神话 | U（待测） | U（待测） |
| S07 白日焰火 | U（待测） | U（待测） |
| S08 黑豹：瓦坎达万岁 | U（待测） | U（待测） |
| S09 天空之城 | U（待测） | U（待测） |
| S10 奇异博士2 | U（待测） | U（待测） |
| S11 神奇动物在哪里 | U（待测） | U（待测） |
| S12 神奇动物2 | U（待测） | U（待测） |
| S13 非诚勿扰 | U（待测） | U（待测） |
| S14 无间道 | U（待测） | U（待测） |
| S15 奥本海默 | U（待测） | U（待测） |
| S16 A计划 | U（待测） | U（待测） |
| S17 A计划续集 | U（待测） | U（待测） |
| S18 方世玉续集 | U（待测） | U（待测） |
| S19 指环王 1（100 GB 以上） | U（待测） | U（待测） |

## 功能判定细则

| 代码 | 通过条件 |
|---|---|
| `FF` | 进入播放器后有可辨认真实视频帧；只出现播放器、进度条、片源水印或转圈不算首帧 |
| `ST` | 至少 30 秒进度持续推进，期间无长时间黑/灰屏、无超时和无重复缓冲 |
| `LIB` | Jellyfin 首屏资源、海报和元数据在可接受时间内出现；设备文件目录和点击后的状态明确，不出现无反馈的归零等待 |
| `PA` | 暂停按钮和视频画面双击均可暂停；再次操作后画面从相近时间点恢复 |
| `SK` | ±15秒及S03/S19深定位分别验证；缓存内/外分组、绝对目标正确，记录提交→新画面与内部恢复、旧字幕清除/新cue、实际声音，暂停意图及持续推进保留；性能预算按当前执行版预先固定 |
| `AT` | 每个可用音轨可切换，切换不退出、不回到 00:00 |
| `SU` | 每个可用字幕可切换，字幕显示正确，切换不破坏播放位置 |
| `SA` | 以 `SUB/AUD` 分开判定：`SUB` 在实际画面中显示正确、无乱码/方框/重复/残留；`AUD` 在设备扬声器（必要时再测耳机/路由）中有可辨识声音、无持续静音/断续/失真，音轨切换后仍正常。没有可用字幕时 `SUB=N/A`；没有音频轨道时 `AUD=N/A`；不能只凭播放器控件存在判定通过 |
| `Q` | Jellyfin 清晰度切换成功，时间点和播放状态保留 |
| `PP` | 进入/退出 PiP 成功，回到 App 后断点保留；不支持时记录明确原因 |
| `EX` | 退出播放器再进入时断点符合产品定义，不意外从头开始 |
| `MEM` | 采样期间 App 未被 Jetsam/崩溃；记录设备日志和关键内存现象 |

## 当前已知填写

### 2026-08-31 Nastart S03 播放引擎优化验证

- 在源码修改前已执行远端/工作区核对，本地 `main` 与 `origin/main` 没有提交差异，
  但工作区存在既有未提交文档、WDA 脚本和播放相关改动；本轮未回退这些改动。
- 先将当时工作区构建出的 Nastart Debug 包安装到 iPhone 13，再应用本轮播放协商改动，
  重新构建 `/tmp/NastartEngineOptIPhoneDerived/Build/Products/Debug-iphoneos/Nastart.app`
  并安装到同一设备；`ios-deploy` 返回 `InstallComplete`，WDA 16.8.0 在 `127.0.0.1:8102`
  返回 `ready=true`，Nastart session 可读取首页 XML。
- S03《碟中谍3》详情页在 Nastart 中显示 `4K · H.265 · HDR`，默认音轨为
  `TRUEHD - 5.1 - 默认`，字幕为 `ASS`，源文件名含
  `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`，大小
  `54.01 GB`。本轮新增策略让私网/码率安全原始文件在默认音轨触发 HLS 但存在可直放音轨时，
  初始播放先选择可直放音轨，避免不必要的 Jellyfin HLS 首段等待。
- 验证结果：点击“在 Nastart 中播放”后进入内置播放器并取得真实画面；两个延后截图
  `/tmp/nastart-engine-opt-s03-now.png` 与 `/tmp/nastart-engine-opt-s03-later.png`
  内容不同且后者字幕文本变化，证明画面持续推进。syslog 出现 `MobileVLCKit` player instance
  创建；AVPlayer 初始化日志仍存在，但这是系统 player session 目前无条件构造的副作用。
- 继续优化：compatibility 初始路由已延迟 `AVURLAsset`/`AVPlayerItem` 创建，系统播放器资源
  只在实际选择 AVPlayer/PiP/HLS fallback 时准备。新包重采 S03 时，`t=2.3s` 进入播放器
  loading，`t=6.2s` 出现可辨认真实帧，`t=8.3s/12.3s` 画面继续推进；起播阶段 syslog
  仍记录 `MobileVLCKit` player instance，未见 `AVURLAsset`/`AVPlayerItem` 媒体加载关键字。
- 自动化注意：详情页播放按钮曾因中心点与底部 tab bar 重叠导致一次误点，本轮已将播放主操作
  移到音轨/字幕选择之前，减少小屏和 WDA 坐标点击污染。
- 控制层修复：MobileVLCKit 内置播放器自动隐藏控制条后，单击视频画面可重新显示控制项。iPhone 13
  WDA session `66B27E04-DEC4-459D-A8C9-30F57280F274` 用 Jellyfin 样本《哈尔的移动城堡》
  验证：隐藏态只保留 `显示或隐藏播放控制` 命中层，单击后 `完成`、`暂停`、`前进 15 秒`、
  `后退 15 秒`、`音轨`、`字幕`、`更多播放控制` 等按钮重新可见。截图：
  `/tmp/nastart-controls-hidden.png`、`/tmp/nastart-controls-after-tap.png`。
- 未完成项：首次精确分秒采样脚本失败，因此本轮不能填写准确 FF 秒数；未完成
  `PA/SK/AT/SU/AUD/Q/PP/EX/MEM` 全矩阵；HTTP Range/Content-Range 仍需服务端或代理日志补齐。

### 2026-08-29 DS One S03 大文件动态续采

- DS One 2.4.5 Build 4 在 iPhone 13 上继续采集 S03《碟中谍3》
  `50.3 GB` Jellyfin 样本，证据见
  [2026-08-29-DSONE-S03-DYNAMIC-CONTINUATION.md](../archive/handoffs/2026-08/2026-08-29-DSONE-S03-DYNAMIC-CONTINUATION.md)。
- 本轮已确认：首个真实视频帧约在点击播放后 3 秒出现；`HEVC / 2160P /
  23FPS / 57.42mbps` 画面连续推进至少 30 秒；暂停 5 秒定帧且吞吐降到
  `0 B/s`；恢复后从相近位置继续；进度条前跳/回跳后不回到 `00:00`；音轨菜单列出
  AC-3/TrueHD 四轨且选择 TrueHD 后位置保持；字幕菜单列出 PGS/ASS 且切到 ASS 后播放不中断；
  后续自然画面已看到 ASS 双语字幕实际渲染；PiP 进入后出现 iOS 系统 PiP 浮窗，并在恢复后
  回到 S03 全屏播放器且位置、字幕保持。
- 本轮不能升级为完整 `P` 的项：精确 +/-15 秒 seek、按固定采样点完成的字幕完整性、实际音频听测、
  Jellyfin 清晰度切换、HTTP Range/Content-Range、服务端 Range 日志和 PiP 退出闭环。
  PiP 入口与恢复均有截图证据，但 SpringBoard `恢复全屏幕` XPath 退出步骤仍被 WDA 设备锁定状态阻塞；
  该项应继续记为 `TOOL/U`，待下一次稳定解锁状态下重跑。

### 2026-08-29 Range 响应校验实现状态

- Nastart 本地认证 Range proxy 已将上游 `206` / `Content-Range` / 请求起始偏移 /
  文件总长度校验收敛到 `MediaRangePolicy.validatedPartialResponse`，并在交付 body 前拒绝
  `200`、缺失或 wildcard 总长度、起始偏移不匹配、反向区间和超出文件长度的区间。
- 本次只更新跨样本传输前置策略和单元测试覆盖；未执行 DS One 2.4.5 真机动态采集，也未执行
  Nastart 四入口播放矩阵回归，因此 18×4 单元格状态不变。
- 验证状态：`preflight`、`git diff --check`、generic iphoneos app build 通过；simulator 单测仍被
  `NastartTests` target 无法解析 `MobileVLCKit` 模块阻塞，需单独修测试工程依赖后重跑。

### 2026-08-15 通用传输策略验收状态

- 已通过 15/15 iOS 单元测试、preflight、Swift parse、签名 iphoneos 构建和 playback-lab 的连续 `206` Range 样本（`0-32767`、`32768-65535`）及 malformed Range `416` 边界检查。
- 当前代理策略固定为“客户端连续 chunked + 上游有限 206 窗口”，续段按每个上游任务的实际交付量计算；这是跨样本的传输实现约束，不是 S01 专用参数。
- 最终包已安装到 iPhone `REDACTED-DEVICE-01` 和 iPad `REDACTED-DEVICE-02`。iPad WDA 已通过标准 `xcodebuild test` → `iproxy 8101:8100 -u UDID` → `/status ready=true` 恢复，并重新采集 S01 设备文件入口 t=0/3/10/30 真实画面；不能把工具恢复或部分截图推断为 S01 新包完整通过。
- iPhone 的标准 Xcode 26.6 XCTest 通道仍会报告 `DVTBuildVersion` 空值/`Logic Testing Unavailable`，但历史 DVT 链路已恢复：正确 Bundle ID 的 WDA 16.1.5 在 `127.0.0.1:8102/status` 返回 `ready=true`，并已建立 session、读取启动台和“设备→文件”页面。iPhone 播放四单元尚未因此自动通过；仍不得用 iPad、simulator 或 playback-lab 替代 iPhone 的首帧、ST、SA、控制项或 MEM。

S01 的历史结果和证据仍以结果表为准。目前不能把 S01 四个入口标记为完整通过：iPhone 旧构建曾发生 Jetsam；修正版 iPhone 曾在 3 秒和 10 秒看到真实画面；旧的 32 KiB/8 MiB/32 MiB 窗口实验曾分别在不同时间点停滞。当前构建改为“有限上游窗口 + 客户端连续 chunked 响应”，iPad Jellyfin 已取得 t=0/3/10/30 真实帧并推进到约 1:18，仍需完成四入口全功能、并发以及 S03/S08/S11/S18 格式族回归后才能固化。

电视剧专项使用相同的核心项和 `SA=SUB/AUD` 补充项，另加 `NEXT`（接近结尾自动跳转下一集）和 `EP-RESUME`（跨集/返回上一集的断点与集号正确）。ISO 专项至少记录 `ISO9660/Range/FF/ST/SK/AT/SU/SA/EX/MEM`；ISO 样本缺失时写“样本缺失”，不得用普通视频替代。

## SA 补充项的固定采集

- `SUB`：在 `t=3/10/30s` 至少各观察一次字幕，并额外等待一个自然字幕帧；记录字幕轨道是否存在、实际显示文本、字形/编码、是否重复或残留、是否被底部裁切，以及切换后是否保持播放位置。`SUB=P` 的必要条件是画面上每个可见字都完整可辨、无方框/缺字/乱码/重复层/残留；任一采样帧出现问题即为 `SUB=F`，不能用另一个正常句子抵销。截图只能证明“画面上的字幕结果”，不能仅凭“字幕”按钮存在判定通过。
- `AUD`：在首帧出现后确认设备实际音频输出，至少覆盖 `t=3/10/30s` 的可听性和连续性；记录输出路由（设备扬声器/耳机/系统路由）、是否静音、是否断续/失真，并在存在多音轨时记录切换前后结果。音频输出不能由视频截图推断，必须有听测或等价的音频路由/系统日志证据。
- `SA` 的结果格式为 `SUB/AUD`，可写 `P/P`、`F/P`、`P/F`、`N/A/P`、`P/N/A`、`TOOL/TOOL`；任一子项未测，整体 `SA` 不得记为通过。

字幕问题的判定顺序固定为：先判断是外挂 UIKit overlay、内封 VLC/SPU、还是两条路径重复；再检查编码与 CJK 字体；最后检查布局/安全区域。不得只给某个样本添加字体、编码或位置参数。历史失败截图必须作为回归基准，且必须在修复后的同一入口、同一设备和至少一个不同字幕帧上复核。

每次填写 `P` 或 `F` 必须在结果表追加：构建时间、设备、入口、链路、截图路径、日志路径和时间点。这样后续可以区分“同一视频不同链路失败”和“同一链路不同视频失败”。

## 2026-09-07 NAS 清单驱动的代表性电视剧样本

只读扫描 3,247 个 Episode，按文件大小排序，再按码率、分辨率、编码、动态范围、音轨和字幕去重选样。体积为十进制 GB；以下属性来自 Jellyfin 元数据，实际输出效果仍需验证。

| 编号 | 样本 | 体积 / 码率 | 格式特征 | 选择理由 | 状态 |
|---|---|---|---|---|---|
| TV04 | 白夜追凶 S1E29 | 9.35 GB / 24.8 Mbps | mp4 / hevc / SDR / 3840px | 9 GB 级持续 Range 读取与 4K HEVC 高码率 | U，已选样未实播 |
| TV05 | 繁花 S1E23 | 7.96 GB / 22.7 Mbps | mp4 / hevc / DOVI / 3840px | Dolby Vision Profile 5、四音轨切换；DD+ 双声道，不是 Atmos | U，已选样未实播 |
| TV06 | 黑袍纠察队 S5E4 | 7.13 GB / 15.0 Mbps | mkv / hevc / HDR10Plus / 3840px | HDR10+ 的兼容输出与 4K MKV | U，已选样未实播 |
| TV07 | 绝命毒师 S1E1 | 4.18 GB / 10.2 Mbps | mkv / hevc / SDR / 3840px | PGS/SRT/ASS 多字幕与多格式切换 | U，已选样未实播 |
| TV08 | 辅佐官：改变世界的人们 S1E6 | 3.03 GB / 6.1 Mbps | mkv / h264 / SDR / 1920px | H.264 对照组，避免所有测试只覆盖 HEVC | U，已选样未实播 |

每个样本复用核心 LIB/FF/ST/PA/SK/AT/SU/Q/PP/EX/MEM，并增加方向进退、双击行为、字幕尺寸/位置/透明背景。大文件增加至少跨多个传输窗口的连续播放；不得把下载/探测成功记作实播通过。
当前手机 iPhone 13 / iOS 16.3.1，iPad 与外网仍未验证；不下载新的影视内容，不修改 NAS 文件。
