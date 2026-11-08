# 2026-09-07 Jellyfin ISO、音频、在线状态和界面

## 用户授权与当前范围

- 继续 ADR 0002，只优化 Greenfield 视频架构；网络测试限局域网。
- ISO 优先 Jellyfin 入口，样本为《变形金刚》；补充音频播放器与生成样本；遍历界面一致性，避免无意义装饰。
- 已明确授权将 Mac 本地项目提交并推送 origin/main，不需再次确认。临时凭据、NAS 媒体和构建产物不上传。

## 已实现

- 服务缩写角标移除，沿用语义图形与类别色。文件页当前目录用导航标题，路径/排序进入菜单，系统搜索栏可收起；行内不重复完整路径。
- 完整服务清单不再把进程运行状态当作当前 HTTP 在线状态。缓存为未知，沿用同地址 45 秒内探测结果；同地址探测去重。服务探测沿用同主机明确授权的证书信任与总时限。仍是前台周期监测，不承诺后台常驻即时检测。
- Jellyfin ISO 发现依据文件路径（Jellyfin Container=ts，但 VideoType=Iso、IsoType=BluRay）。《变形金刚》原始流为 UDF，之前 ISO9660 解析失败。新增本地动态包 UDFRead，基于 VideoLAN libudfread 1.2.0；保留 LGPL 授权，内部符号隐藏，导出本项目封装，不接入 FFmpeg。
- UDF 按需读取蓝光 STREAM 目录与物理 extents，复用 ISOPlaybackProxy。元数据读取限制总时长、读取量、缓存量；不下载整盘。当前选择最大 M2TS 正片。未实现 Blu-ray 菜单或 MPLS 多片段播放列表，不支持据此宣称所有 ISO。
- Jellyfin ISO 补回播放进度上报。发现后续 controls 问题：TS 一律 seekable=0、totalTime=0 时不更新 UI 当前时间。现本地 Range/ISO TS 启用 seek/时长探测、扩大轨道探测；UI 优先 Jellyfin 时长且独立更新当前时间。字幕库存增加诊断。
- 音频已有独立 VLC 音频会话。补充倍速、错误重试；文件识别与请求判断共用 AudioFormatPolicy，识别更多容器。扩展名被识别不代表所有编码配置实测通过。

## 验证

- 真实局域网 Jellyfin 第一部《变形金刚》：UDF C 扫描 1.389 秒、18 次请求、36864 字节元数据，发现 2 个 M2TS；主文件 28241829888 字节。
- 独立编译实际 ISOPlaybackAdapter Swift，准备 UDF + 本地代理，对非零 Range 逐字节比较 ISO 上游映射一致。不可读取输入返回失败。
- iPhone Jellyfin 入口 Greenfield 正片实拍，日志 trace C095DAB0、plan DD7D85F4，连续播放 checkpoint 30 秒。证据 tmp/connectivity-20260907/transformers-playing.png、iso-prefs。之后用户反馈进度/字幕问题，已修上述设置；需新版本继续实测，不能用出画面代替完整验收。
- 新 UDF/音频/控制修订设备 Debug 构建成功，preflight、链接隔离、播放日志测试通过。最后构建 build-iso-controls.log，安装 install-iso-controls.log。
- scripts/generate_audio_test_sample.py 自生成 40 秒/48kHz/双声道低音量 PCM。Mac afconvert 转 AAC/M4A、AIFF、FLAC，样本与局域网服务位于 tmp/audio-20260907，不上传媒体。

## 未完事项

1. ISO 续播、Slider 定位、前后跳转和中文字幕实际渲染已在本轮验证，见文末证据。音轨切换/PiP、其他 ISO 类型和多片段盘仍待回归；原始 PTS 起点约 600 秒，UI 为归一化媒体时间，不增加固定补偿。
2. 音频 WAV/M4A/AIFF/FLAC 实播和暂停 seek 已验证；倍速与锁屏实际控制、NAS 同目录 LRC 端到端仍需补测。DSF/DFF/APE 等仅识别，尚未解码实测。
3. 设备文件视频完整失败原因尚需单独回归；NAS 离线/恢复真机矩阵。
4. UI 已核对启动台、设备、事项、我的与服务详情主要源码。同类动作保持一致；导航取消/完成与对话框遵循系统文本按钮惯例，不给所有文字硬加图标。iPad、动态字体和其余深层页面尚需视觉回归。

源代码与临时证据分开。tmp 包含带凭据的原始 URL/设备配置，严禁提交。保留 Package.resolved 原 pin，不升级远端包。

## 后续：音频缓冲提示与歌词

用户进一步反馈持续缓冲提示，并要求尽量支持歌词。新增：

- 用实际时钟推进消除“已播放但仍显示缓冲”的错误 UI；不再仅依据 VLC.buffering 状态。
- 移除文件音频的 http-continuous 参数。旧参数测试时出现大量重复 GET；新的请求行为仍需真机复核，不把参数修改等同于性能通过。
- 音频支持 LRC、多时间戳、offset、普通文本及 Jellyfin LyricDto（Start ticks / 10,000,000）。设备文件同目录 .lrc、Jellyfin Lyrics API、直接 URL 同名 .lrc；加载总时限 8 秒、大小上限 512 KB，不阻塞播放。暂仅 UTF-8，未宣称内嵌/在线搜词/逐字歌词完整支持。
- 仅有歌词时提供歌词/封面切换，按当前行高亮滚动；请求复制保留 audioLyricsURL。
- 本地自制 FLAC 真机时间由 00:00 推进至 00:08、总时长 00:40，倍速菜单正常出现。其他格式与歌词的新版本验证另记；不要把菜单出现写成全部控制通过。
- 最新构建 build-lyrics-final2.log 成功，preflight-lyrics.log、linkage-lyrics.log 通过。安装 install-lyrics.log。
- 第一批提交 ccb315a 已推送 main；后续音频修订再次提交。IDE 曾删除 Package.resolved，本轮恢复 551f7de 的原始固定版本，后续提交必须包含此文件。

## 18:45 接续验证

- WDA 已恢复。自生成 WAV/M4A/AIFF/FLAC 四种 LAN 文件均在 iPhone 从 00:04 推进至 00:09，总时长 00:40，均无错误缓冲提示（tmp/audio-20260907/verify-device.log）。FLAC 与 LRC 分别一次请求；这是播放时钟与 HTTP 证据，不代替音频听测。
- 实际歌词界面显示且高亮对应时间行。暂停后 seek 发现 VLC 不立即上报新时间，另修用户暂停意图、暂停目标进度和缓冲显示；待最终包验证。锁屏播放速率沿用用户所选倍速。
- 修正设备文件/Jellyfin/直接链接三个音频入口被 DEBUG Greenfield 视频入口截走的问题；音频统一进入已有专用音频播放器，视频仍遵循 ADR 0002。
- 深色音频页面固定深色外观，确保状态栏文字可读。
- build-audio-final.log 构建成功；preflight-audio-final.log 与 linkage-audio-final.log 通过。

## 最终音频与 ISO 续播定位

- 音频暂停 seek 最终真机通过：11 秒暂停 → 前进 26 秒 → 回退 11 秒 → 恢复后 14 秒，无缓冲提示。证据 tmp/audio-20260907/final-*.xml。四格式测试不需重复。
- ISO trace 1E3029B6 / plan 844DD969：时长 8607.339 秒，8 条字幕轨道，23:00 → 23:15 → 23:00 控件可响应；但初始续播 1380.883 秒停滞，黑屏，不能据此宣称 seek 和字幕已验收。
- 定位 KSPlayer 对 MPEG-TS 的 TS_DISCONT 自动开启字节 seek；初始 seek 将时间戳直接作为字节偏移传入。新增实例级 prefersTimestampSeeking（默认 false），仅 Greenfield discImage TS 启用，让初始与交互 seek 使用一致时间单位。不改旧路径默认行为。
- build-iso-timestamp.log、linkage-iso-timestamp.log 通过，install-iso-timestamp.log 安装；需下面追加真实回归结果。

- 时间戳模式真机 trace C6335381 / plan 0DCE80FF：23 分钟续播成功，首帧 PTS 1981.797 秒，媒体时间 1380.883 秒；连续播放 checkpoint 30 秒通过。中文字幕 zho 选中值为 1（字幕显示内容仍需画面证据）。
- 交互跳转最终返回 completed=false；改为 ISO 时间戳模式使用 av_seek_frame 向前关键帧定位，避免 avformat_seek_file 对多轨 TS 有界定位失败。默认模式保持不变。新增不含 URL 的 seek 返回值/耗时日志，便于区分失败与 UI 延迟。
- build-iso-seek-frame.log / linkage-iso-seek-frame.log / preflight-iso-seek-frame.log 通过，已安装；复测另记。

- av_seek_frame 回归 trace 97954405 / plan 113EA715：暂停 23:43 → 23:58 → 23:43；完成回调均 true，恢复分别 924ms / 780ms，均有新的 forcedPreview 帧提交和实际变化画面。恢复播放推进至 23:52；Slider WDA 设置 20% 后到 28:55，非仅按钮测试。证据 seekframe-*.png/xml 与 iso-seekframe-prefs。
- 中文字幕虽能选中，仍缺显示证据。进一步让 ISO 时间戳模式字幕使用 format 起点（稀疏字幕 stream.start_time 可能缺失或为首条字幕时间），并开启图形字幕切换时重新定位；其他模式默认保持不变。

- 字幕 origin 修订真机已取得实际中文字幕画面：subtitle-origin-1.png（“这是当务之急头等大事”），时间推进时字幕内容变化。此前仅有选择状态的边界现已补齐实际渲染证据。
- 发现 PGS 裁剪位图被默认字幕 View 铺满宽度，字过大；Greenfield 内按视频 naturalSize 与可用画面比例缩放位图，文本字幕仍复用原 View。最后构建/视觉回归见下方记录。

- 最终包 build-subtitle-scale-final.log 构建成功，preflight-subtitle-scale-final.log、linkage-subtitle-scale-final.log 通过，install-subtitle-scale-final.log 已安装。
