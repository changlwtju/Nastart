# PGS字幕缩放修复与iPad AV轨道失败

更新时间：2026-10-12T07:47:41.349285+08:00。继续以USB iPhone13/iPad优先、无线iPhone18其次。已读PROGRESS、CURRENT、播放规范及竞品矩阵；不改现有VPN/配对/系统服务，未卸载App、清登录数据或提交其他未提交修改。脱敏结果：[JSON](../../../testing/results/2026-10/PGS-SCALE-AND-AV-TRACK-FAILURE-20261012.json)。

## 包与设备门槛

开工源615edbaa旧正常包基线在私有`2026-10-12-subtitle-continuation-070929`，13/Pad现场USB名称/型号/系统/UDID核实，07:09保留数据覆盖25/16偏好一致，空env/args实际无遮挡首页已看。基线两台本轮解码日志确认S03轨5/6=`ass`、7/8/9=`hdmv_pgs_subtitle`；初始库存enabled不等于最终选择。轨7不是靠同名标签或截图风格推断。基线13同句英文行显示/隐藏OCR归一化宽度0.24855/0.38081，约53.2%变化；原图已核、错误/超时全部保留，不作为新包通过证据。

只新增修改`GreenfieldKSPlayerRenderer.swift`中的字幕overlay：GeometryReader先获得完整播放区域，底部控制避让在其内部布局；位图尺寸不再因控制栏预留高度而缩放。文本底距与此前隐藏300ms保留避让继续有效。没有改AV候选准备、传输、seek或播放轨道策略。

当前HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，包含原有未提交修改，iOS diff SHA `a4be368ba042c0f52bb58be240a6e90c5bfc49032653f64ee22440ddedbbb935`，正常Debug/-Onone，构建时间`2026-10-12T07:18:09.565389+08:00`。包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-071725/Nastart-PGS-Stable-Scale-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-071725/Nastart-PGS-Stable-Scale-Normal-Debug.ipa`。

- 主二进制SHA-256：`036fea1f544b85cfb2b9aa6185e5ddddcacd102b6f997d5cdb3afbcfed36e937`。
- Debug dylib SHA-256：`2b45b6688bc50b1da2417f39e277c4a602b0045ff8cf6433381d77cce23afa70`。
- KSPlayer SHA-256：`a981b6ce9643d58ef5cbdd81b3f1aa2c1878e6c4e590ee41f1afd510bc3da83c`（与基线同一库）。
- 173输入SHA/mtime、IPA三二进制一致、29库独立签名、App deep/strict及链接均核验；profile到`2026-10-17T22:23:40` UTC且覆盖三机。
- 本轮实际构建成功，322测试/2跳过/0失败、15预检通过，非引用旧结果；没有增添镜像实现的测试。

|设备|本轮系统/型号|当前包覆盖完成|正常空环境实际首页|最新媒体验收|
|---|---|---|---|---|
|iPhone13 USB|iPhone14,5 / 16.3.1|2026-10-12T07:20:29.712645+08:00，25偏好保留|已核，末次稳定NAS完整状态|同句PGS稳态缩放通过；完整SUB/动画/声音/流畅未验|
|iPad USB|iPad12,1 / 18.3.1|2026-10-12T07:20:23.395167+08:00，16偏好保留|已核，末次恢复正常首页|发生实际准备失败，最新PGS布局未通过|
|iPhone18 配对无线|iPhone19,7 / 27.0|2026-10-12T07:20:30.768287+08:00，25偏好保留|用户解锁后07:21已核|本轮未播放；末次WDA查询超时，最终前台未知|

原始设备身份、偏好、凭据、URL、截图/XML、源diff、安装回执和日志只留本机私有证据`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-071725`。18原生设备枚举仍paired/tunnel unavailable；直接无线WDA复用已有正式Runner可打开新包，不重装WDA。末次超时不能覆盖此前真实新包首页，也不能宣称当前仍在线。

## iPhone13的新包回归

S03普通续播、3/10截图、暂停，普通后退15秒逐次核clock定位同句，真实选择轨7。暂停/隐藏/重现/锁定/解锁、ASS切换再返回PGS的原图已看；稳定保存位置全部364.244。PGS暂停返回有`subtitle_paused_display_reused`、requestedTrackID7/currentSeconds364.244，与实际PGS画面同时核验，不把解码库存日志单独当呈现证据。

OCR同句英文行新包显示/隐藏/重现/返回宽度约0.42006/0.42083/0.42006/0.42006，变化约0.185%；结合原图确认稳态不再显著缩放、控制栏未遮挡该cue。OCR高度随识别框变化，不用于逐像素字号证明；也不是完整动画/帧时间或性能证据。新包13syslog未抓到codec库存，保留该缺口；codec来自本轮基线同片实测、同KS二进制及新包Pad库存，选择/实际位图由新包本机证据确认。

恢复PGS播放3/10/30实际自然cue原图全部已看，再通过UI恢复原ASS5，普通退出398.185。24非书签偏好一致、仅S03自然更新，最终4/5开启；崩溃前后清单无新增。最终普通空env/args稳定NAS首页、播放器关闭、WDA idle10/动画2。首冷首页曾处于NAS状态加载中，后续完整同目标状态原图已看，不只据“NAS正常”占位字样验收。Wi-Fi回归，未冒充蜂窝测试。

## iPad失败与清理，不能记为通过

新包轨7第一次目标定位遇按钮自动隐藏/404；后续菜单元数据更新为完整ASS/PGSSUB标签，旧同名假设失败；所有工具失败、超时、脚本版本和实际画面留存。部分后退请求未达预期clock，后来实际截图证实播放器弹出“无法准备播放”，因此不能把所有停止归为自动化错误。此前曾在未看失败图时按坐标/时钟问题重试，这个分类已修正。

诊断07:27:50与07:29:42两次`replacement_warmup_failed`：AVPlayer/alignment、`notAlignedBeforeDeadlineOrPlaybackStopped`，errorDomain/errorCode均无具体值；播放器`GreenfieldVideoPlayerView.sourceChangeFailed`使用相同无详细正文的弹窗。候选未对齐的底层原因仍待定位，不能仅凭混杂syslog中的-1001/-1004或计数判定网络根因。普通确认弹窗后恢复退出，后续独立冷续播实际route=`systemAVPlayer/localHLS/localRemux`；暂停424.126的显隐画面为无字幕cue，不作为PGS布局通过。后退15实际到06:49已核；播放中请求关闭字幕再次弹准备失败。

**字幕关闭UI未可靠提交/保存。** 字幕图标一度变为未填充，但正常退出542.298781仍保存轨7开启；不能凭图标宣称偏好恢复。为不留下本轮测试改动，App终止至state1后，通过容器只将S03的`audioTrackID/subtitleTrackID/subtitlesDisabled`回滚到安装前字段（4/off，字幕ID原来不存在），保留542.298781位置与其他书签字段、全部其他偏好/诊断/账号；写前原始备份、精确写后回读和再次普通空环境启动后读取均核验。此为**失败测试清理，不是注入后通过的媒体结果，也不是关闭字幕功能通过**。15非书签偏好一致，仅S03自然位置变化；崩溃前后清单无新增；最后稳定普通首页/播放器关闭/idle10动画2。iPad最新包已安装，不再沿用旧IX48阻塞；低存储历史风险仍不能宣称彻底解决。

## 下一步及保留总账

优先复现iPad AV/localHLS选择/关闭PGS的候选alignment失败，核对暂停和播放两种liveClock、候选loaded ranges/seekResult/deadline、提交失败后UI/轨道快照/书签是否保留旧状态；先取同一播放trace完整链，避免1000条诊断循环覆盖失败边界。修复后新构建、三机门槛与双USB回归，补真正KS路径Pad的同cuePGS/ASS/外部字幕及动画。其次18重新发现并验证实际播放与原生自动通道；当前包首页已补齐，不能继续写为locked未启动。

完整SUB/AUD/HDR、实际显示帧时间/滚动流畅、Lenna/DS One同条件公平对照仍未验收。旧AV ordinal兼容、HLS完整deadline/分片/read/callback/容量、475保存与服务器耐久、119、13真实弱蜂窝、代表族/PiP及全部CB/PX/UX/L2/L3/Main未验项保留，详见既有总账，未将本轮稳态布局扩大成全通过。
