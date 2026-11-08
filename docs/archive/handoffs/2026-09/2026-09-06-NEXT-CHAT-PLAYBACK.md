# 新对话接续：新架构播放优化与 HLS 内容保位

更新时间：2026-09-06；本文件用于用户主动新开对话后的无缝接续。先读本文件，再按需读历史交接，避免重复建设。

## 2026-09-07 最新接续

最新任务先读 [Jellyfin 搜索与海报修复](2026-09-08-JELLYFIN-POSTERS.md)，杜比方向见其中路线链接。此前任务见 [电视剧、字幕与服务识别](2026-09-07-TV-LAUNCHPAD.md)。此前修复见 [ISO、音频与界面进展](2026-09-07-ISO-AUDIO-UI.md)。LAN 连接与第一批播放修订已推送 main；音频缓冲/歌词与 ISO 续播、跳转的后续真机证据在该文档中。下文为此前历史，不要重复已完成的 HLS 内容映射测试。

## 用户已确定的方向（不得重新展开架构选型）

遵循 [ADR 0002](../../../adr/0002-single-playback-optimization-mainline.md)：

- 唯一持续优化主线是 Greenfield 新架构，KSPlayer 原始流优先；HLS/AVPlayer 为必要兼容分支。
- 常规入口只保留“新架构 / 旧架构”，旧架构仅供回退和关键里程碑对照。新架构完整验收后删除旧架构、仅旧架构使用的依赖和选择器。
- 不再将 Force original 当第三架构。三个入口（Jellyfin、设备文件、直接链接）已共用两项选择器，默认新架构，历史 Force 偏好不再读取。
- 保留/复用原有完整 UI、手势、设置、音字幕、清晰度、PiP 等功能，不要重做简化播放器界面。
- 先补齐新架构基本功能，再按既定真机矩阵逐项验收。不能凭截图、UI 时间、readyForDisplay 或时钟推进单独判定播放通过。
- NAS 外网目前有问题，**只使用局域网**。外网 Wi-Fi、蜂窝网络待恢复后补测，不将 LAN 结果推广至全部网络。
- DS One/Lenna 只用于回答具体问题，不继续广泛铺开竞品/新旧架构全套对比。

## 音字幕接续更新（优先于下面历史快照）

新架构外挂字幕选择跨画质切换丢失已复现并修复；KS→HLS→KS 中文字幕开启、国语音轨、关闭字幕共六处选择断言通过。当前已安装 `build-source-selection.log` 对应构建。详见 [源轨道状态与 PiP](2026-09-06-SOURCE-SELECTION-PIP.md)。HLS PiP 主屏小窗画面推进已有证据，完整返回与音频听测边界见该文件。不要重做已经通过的选择状态往返。

## 最新接续：音字幕/PiP（优先读取）

见 [源轨道状态与 PiP](2026-09-06-SOURCE-TRACKS-PIP.md)。已修复新架构字幕开启选择丢失，并实机验证 KS→HLS→KS 选择保留；另修复明确关闭被旧 sidecar 保留规则覆盖，最终包已安装但该子项待复测。国语源轨道请求与选择保留取得证据，HLS PiP 已进入主屏显示变化，完整返回全屏尚未验证。手机目前锁定、系统拒绝启动 App，已请求用户解锁；恢复后先确认状态，不复用旧坐标/session。

## 20:16 接续更新（历史阶段结果）

已完成清理构建安装并删除设备两份临时 URL 缓存。通过 LAN 实际转码日志及多起点分段内容匹配确认 fMP4 关键帧前滚与 VOD 清单时间不一致。新架构 Jellyfin H.264/AAC HLS 已改为协商 TS 分段，保留旧架构原配置；真机秒级内容偏移不再复现，并已补做 seek、第二次切换、连续播放验证。

详情、代码边界和最新私有证据见 [HLS 内容映射修复](2026-09-06-HLS-CONTENT-MAPPING.md)。完整 Q 仍不宣称通过：动画重复帧存在一至两帧匹配歧义，音频听测、音字幕、PiP 等剩余项目继续待验收。最新设备包是 `build-hls-content-fix.log` 对应构建，停在 S01 新架构 HLS 暂停，约 1104 秒，操作前重新读状态。

下面保留 **本轮开始前的历史快照**；其中“临时探针尚未清理安装”“TS 尚未修改 App”“下一步取日志”等状态已被以上更新取代。

## 历史阻塞问题

**KS→HLS 画质切换后，UI 时间和 AVPlayer 输出帧 PTS 均接近目标，但视频内容落后源视频数秒。Q（精确内容保位）仍未通过。**

不要重新实现已经存在的 AVPlayer 共用 UI，也不要重复排查已经修好的 KS FFmpeg ABI 或 KS 精确 seek。

### 已经取得的独立证据

1. 原始源 S01《哈尔的移动城堡》：H.264 1280×688 / AC3，时长 7165.010 秒、起始时间 0，Mac FFmpeg 探测名义帧率 **29.97 fps**。此前部分文档写 23.976，是旧假设，应使用 29.97 与实际帧时间基。
2. KS 暂停 seek 原先可提交目标之后最多 **5.752 秒**的关键帧。原因是 avformat_seek_file 的范围允许选到后方关键帧；解码丢弃前帧无法纠正这种超前。
3. 已修复初始/交互 accurate timestamp seek：max_ts=目标、min_ts=Int64.min，并去掉交互目标的整数秒截断；字节 seek 分支保持。最终 11 个初始/前进/后退预览 PTS 最大目标偏差 **30.665 ms**，仍小于 29.97 fps 的 33.367 ms。
4. HLS `6F6709B2` / plan `0BF0AB97`：目标/AV raw clock=1057.026667，AVPlayerItemVideoOutput PTS=1057.022597；反向 seek raw clock=1046.665，输出 PTS=1046.645585。
5. Mac 使用同一 LAN 原始流独立提取 **1057.026667 秒**参考帧，与 iPhone KS 画面一致（老妇人与稻草人，俯视山坡）。HLS 同时钟截图是稻草人近景，对应源视频约 **1053–1054 秒**。源参考网格覆盖 1047–1071 秒。说明不能通过“AV PTS 也正确”关闭问题。
6. 当前 NAS Jellyfin 版本通过已授权的 LAN System/Info 读取得到 **10.11.11**。下载了相同版本官方源码供只读核对：`tmp/playback-20260905/encoding-helper.cs`、`hls-controller.cs`。
7. 实际 HLS media playlist：VOD、version 7、targetDuration 4、mediaSequence 0，大量 EXTINF=3.003000。片段 index 351 的清单累计起点 **1054.053 秒**，fMP4 实际视频首 PTS **1052.415889 秒**，尾 PTS 1055.385517，90 帧。首帧内容为稻草人全景，接近源 1052 秒。清单与分段时间不完全相符，需要继续核实相邻段及 AV 映射。
8. 独立尝试同一服务器流将 SegmentContainer 改为 ts、使用新 PlaySessionId：index 351 清单起点仍 1054.053，TS 探测 start=1064.010333、首视频 PTS=1064.084222，内容为源约 1054 秒的稻草人近景。**这只是诊断实验，不代表 TS 已解决问题，也没有修改 App 为 TS。** 不可只拿 TS 绝对 PTS 减清单时间直接得出源偏移（TS 自身可能有复用时间偏移）。
9. 匹配版本 Jellyfin `EncodingHelper.GetFastSeekCommandLineParameter`（本地约 2949–2995 行）在部分 fMP4 HLS 启动使用 `-noaccurate_seek`，TS 排除该条件；DynamicHlsController（约 1668 行）使用 `-copyts -avoid_negative_ts disabled` 等。此为下一步研究线索，尚不能仅凭源码确认为本次全部根因。

下一步应围绕 **服务器分段生成、清单累计时间与实际源内容映射** 取证，必要时检查本次转码命令/相邻片段。不要加入 S01 专用固定秒数补偿，不要把未验证 TS 参数推广到主线。

## 已有实现，保留并在其上继续

- `GreenfieldVideoPlayerView.swift`：KS 与 AV 各有独立 GreenfieldPlaybackControls；均复用 SharedBuiltInPlayerView。AVPlayerLayer/PiP、初始精准 seek、paused preroll、音字幕选择、seek generation、跨引擎时间初始化已实现。
- Jellyfin VOD HLS 当前按完整媒体时间轴 seek，不把请求 StartTimeTicks 再加到 AV raw clock。跨引擎暂停意图和开始/停止 tracker 已接入。
- 控件 beginSession 清理旧 pause/resume/seek 计时，disconnect 使旧 seek 回调失效；已实机断言暂停计时属于当前计划。
- KSPlayer 被编为独立动态 framework，隔离 FFmpegKit 与 MobileVLCKit 的 FFmpeg ABI；构建安装后必须跑链接校验。
- KS MetalPlayView 的 `videoFrameSubmitted` 回调记录首个提交帧和 forced preview 的 PTS，明确 `rendererSubmissionNotPresentation`。不逐帧写日志。
- **本轮新增、已构建真机验证的 DEBUG AV 观测**：AVPlayerItemVideoOutput 保留系统显示；初始 seek / paused preroll / 交互 seek 后最多 20×100ms 取样，绑定 item+seekGeneration；停止取消任务。记录 `video_output_sample` 或 unavailable，不将输出采样当 compositor 呈现。
- 首帧旧字段 firstFrameMs 曾错误写媒体位置，已改为 firstFramePositionSeconds / firstFrameSignal=playbackClock，报告兼容旧字段，未知 renderer latency=null；3 个 Python 回归已通过。
- 连续 30 秒按实际连续推进时长累计，暂停/seek/等待重置，短重复 clock 不误清零；主动暂停不算卡顿。

## 当前代码、构建与临时探针边界

工作区有大量本系列任务未提交改动，**没有 commit**。不要 git reset/clean，不要删除无关 KSPlayer Demo/Documents/dotfiles、xcuserdata 等。

- 最新已安装构建：`build-hls-reference-probe.log` / `install-hls-reference-probe.log`，含临时环境变量控制的 HLS URL 私有导出探针。
- **临时 URL 导出代码已经从工作区移除**（rg `NASTART_EXPORT_REFERENCE_RESOURCE` 应无代码结果）；但最后移除后尚未重新构建安装，所以设备包与当前源码仅在该临时探针上有差异。下一轮先完成该清理构建/安装。
- 先前另有原始流 URL 导出探针，已移除。Mac 私有证据目录保留导出的带凭据 URL，供源帧复现；不能打印 URL/token、不能入 Git、不能写入报告。设备 caches 中也可能保留两份导出文件，后续清理这两个精确文件即可，不要卸载/清空 App。
- 常规 final 构建（不含临时导出）应保留 DEBUG AV 帧观测代码。
- Package.resolved 常被 Xcode/IDE 删除。结束前用 `git show HEAD:...` 的原字节恢复，不能重解依赖；不要因此重置整个工作区。

## 设备与操作

- 仓库：`/Users/lagransun/workspace/Nastart`；macOS zsh。
- iPhone13 UDID `REDACTED-DEVICE-01`，iOS16.3.1；当前测试只有 iPhone，不能冒充 iPad覆盖。
- NAS `http://192.0.2.2:8096`，仅 LAN；手机 IP 会变，不硬编码。
- WDA `http://127.0.0.1:8102`；先检查 /status。失效时 `./scripts/start_wda_iphone.sh`；/status ready 不保证旧 session 有效，404 时新建 session 即可，不先重建 WDA。
- 当前 session ID 存在 `tmp/playback-20260905/session.json`，读取使用，不硬编码。
- WDA helper `tmp/playback-20260905/wda.py`，调用前缀：`exec(open(...).read().split('if sys.argv[1]')[0])`。
- 设备最后由 `capture-hls-reference.py` 留在 **新架构 HLS 暂停**状态；时间不固定，先读 source。用户可能操作/锁屏，重新确认，不能照搬上一轮状态。
- App bundle `com.changliwen.nastart`。
- `open-s01.py` 重启正常 App，进入 Jellyfin、搜索哈尔、打开详情（此时按钮可能“继续观看”）；portrait 播放约 x155,y642。
- landscape WDA 844×390；完成85,32；双击420,170；后退109,345；前进244,345；quality620,345，菜单当前1080p20Mbps约530,263，Auto约530,110。**优先读 source 确认，不盲信坐标。**
- `/wda/tap`、`/wda/doubleTap`、`/wda/dragfromtoforduration`。截图 raw1170×2532常带旋转，view_image可看；截图不能独立验收。
- 脚本 `test-av-output-pts.py` KS→HLS→KS，HLS恢复只有4秒（历史变量 after32 只是名字）。`test-accurate-demux.py` 才包含32秒持续测试。
- 不要再常规运行 `open-reference-probe.py`（它加临时导出环境变量）；正常使用 open-s01.py。

## 命令

构建：

```sh
./scripts/xcodebuild_nastart.sh -scheme Nastart -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/NastartGreenfieldABiPhone13Derived -skipPackageUpdates -disableAutomaticPackageResolution build
python3 scripts/preflight.py
python3 scripts/test_playback_trace_report.py
python3 scripts/verify_playback_linkage.py /tmp/NastartGreenfieldABiPhone13Derived/Build/Products/Debug-iphoneos/Nastart.app
```

安装使用 ios-deploy --id UDID --bundle APP。日志重定向到 tmp/playback-20260905 下。没有完成全量 XCTest，不宣称通过。

持久诊断：ios-deploy --id UDID --bundle_id com.changliwen.nastart --download=/Library/Preferences/com.changliwen.nastart.plist --to PRIVATE_DIR；然后 `export-prefs.py PLIST OUTPUT.log`，再 `python3 scripts/playback_trace_report.py OUTPUT.log --json`。结果根键是 `playbackTraces`。plist 内 date 是 Apple 2001 epoch，可用于毫秒级事件间隔断言。下载前留出日志落盘时间。

## 私有证据索引（tmp/playback-20260905，不入 Git）

- `accurate-demux-final-export.log/report.json`：KS 精确 seek 最终证据；KS AE8DA96A、0C6F59DF；HLS F9DD21A6 有33样本/1waiting/accessLogStalls0/无失败/continuous checkpoint。
- `av-output-final-export.log`、`av-output-pts-*.png/xml`：本轮 AV 输出采样和跨引擎图像；HLS 6F6709B2。
- `source-reference-1057.png`、`source-reference-grid.png`：独立源帧；网格1047–1071。
- `reference-hls-segment.mp4`、`reference-hls-segment-first.png`：fMP4 index351，已合并 init+segment，可离线解码。
- `reference-ts-segment.ts`、`reference-ts-first.png`：TS诊断，不作为最终修复。
- `private-hls-master.m3u8`、`private-hls-media.m3u8`、`private-hls-media-url.json`：包含凭据的清单/URL，禁止直接输出。
- `reference-resource/Library/Caches/playback-reference.json`、`hls-reference-resource/Library/Caches/hls-reference.json`：带凭据资源，禁止直接输出。
- `probe-hls-segment.py`、`probe-ts-segment.py`：安全读取私有 URL、打印时间元数据；网络工具只能请求 LAN NAS；FFmpeg 错误输出可能带 URL，应重定向私有文件。
- `encoding-helper.cs` / `hls-controller.cs`：从官方 jellyfin/jellyfin v10.11.11 原始源码下载；来源 https://github.com/jellyfin/jellyfin/tree/v10.11.11 。外部源码线索不可替代真机结果。

## 后续验收边界

目前仍只推进 S01 局域网专项。Q 精确内容保位、AV PiP 完整往返、音频听测、完整音字幕/外部打开/退出续播/MEM 等尚未全通过。矩阵见 PLAYBACK-FUNCTION-MATRIX.md 与 PLAYBACK_VALIDATION_TARGETS.md；不因本轮日志更齐全就整体改 P，不跳过 S01 的阻塞项直接宣称 S02–S18 通过。历史完整背景见 2026-09-05-SHARED-PLAYBACK-CONTROLS.md。
