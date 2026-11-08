# 2026-10-16 亮度、字幕位图分配与 CPU 调用栈

当前稳定产物为 **5df8e033fabddd22d5c0769376a7456512210d9c7421e87471cb93222eb81dc1**，HEAD仍4de732d，其他未提交修改全部保留。用户随后反馈字幕位置偏高及大幅seek仍显示旧字幕，**这两项未修复、正在作为下一批优先重放**；本批选定截图不是用户位置验收通过。

私有证据指针 `/tmp/nastart-brightness-cpu-evidence` 保存调整亮度及c868 CPU参考；`/tmp/nastart-bitmap-evidence` 保存5df包、173输入、双机安装、CPU/内存及偏好原始证据。未改旧current/stage/background/memory/alignment证据指针。结构化结论见[本批记录](../../../testing/results/2026-10/BRIGHTNESS-BITMAP-CPU-20261016.json)。

## 亮度

用户明确要求调低iPhone13亮度。重新现场核到iPhone14,5/16.3.1/USB、实际名称/UDID留私有；既有WDA ready且Runner正确。最初自动前台定位落在旧应用，返回成功的手势未改变实际画面；改为明确系统前台后读到控制中心0%，展开原生亮度条并拖动至约25%。这不能证明此前主观高亮由系统100%引起。播放器代码仅发现用户手势写UIScreen亮度、未发现启动强制拉满；保留1000诊断中无brightness事件，历史原因仍未知。

25%已在c868和5df两次60秒S19播放退出后重新读取并实际查看；按用户意愿保留此较低档，后续测试不要恢复为假定的旧高亮。未改变自动亮度/原彩/夜览、网络、配对、系统或WDA安装。

## 定位与修正

先取得iPhone13普通c868 Debug调用栈：旧Xcode录制Time Profiler、Xcode27成功导出完整time-profile。100.348秒/39695行，6行无栈保留。App与KSPlayer UUID逐项对应冻结二进制。播放15～60秒字幕PNG转换含781个1ms Running采样，调用链为CGImage.data→SubtitleDecode.text→decodeFrame；统计采样权重0.781秒不当精确耗时或整机CPU占比。

修正仅涉及三个输入：KSPlayer Utility.swift、SubtitleDecode.swift、PlaybackNextCoreTests.swift。多矩形字幕合成的旧行长为256×宽度（RGBA仅需4×宽度再对齐），现由Core Graphics自动对齐；直接保留已拥有像素/alpha的CGImage，删除每条字幕的PNG编码再解码。保留canvas、origin、缩放及时间选择，未调整媒体缓冲/网络/解码参数。

新增回归检查320×60画布、行长上限、透明间隙，以及直接图像与原PNG路径的逐像素/方向/尺寸一致。**397 XCTest、2跳过、0失败；15预检通过**，属于本批新构建。Xcode27.0/27A266a、iphoneos27.0，普通Debug -Onone，构建时间2026-10-16 07:38:13.176251+08，173输入无晚于产物，29库及deep/strict签名、IPA CRC与哈希核对。完整包路径及输入在私有manifest；三SHA/IPA SHA见结构化记录，profile至2026-10-17 22:23:40 UTC。

## 真机证据边界

13/Pad现场重新核名称、型号、系统、UDID、USB，先备份偏好再覆盖5df：分别25/18项非诊断偏好含完整书签逐值保持，普通空env/args首页实际已看。13新版Time Profiler100.433秒/37786行，11行缺栈保留；15～60秒PNG路径0采样，SubtitleDecode.text仍有0.083秒采样权重。旧新总采样25.916/24.391秒，单窗、无冷缓存/温度控制，不称整体提速比例；录制开销与普通CPU基线分开。两窗退出后均在Jellyfin详情页，**不是首页释放对照**。

Pad普通包S19从头60秒，原生正常退出并同PID返回启动台30秒。61个播放内存采样：physical footprint峰952.081MiB、t30.370；resident峰230.500MiB，两指标分列。回首页10～30秒20样本physical footprint中位121.737MiB，CPU单核百分比中位0.147。实际自动降档t6.900请求、t30.774提交，stall计数1；高内存/降档等待并未解决。旧三轮927～949MiB只是历史参考，无严格版本配对；没有无泄漏、全片SUB/AUD/FPS或稳定性验收。

13/Pad选定t3/10/30/60图片已看。Pad晚段为AV/HLS烧入字幕，不能把全部截图称原生PGS通过。07:42～07:46收尾记录：正常空环境首页、播放器关闭、原非书签偏好24/17项保持；原书签轨道0变化/0删/0增，每机1项自然位置变化，Nastart/WDA/Jetsam0新增，active conditions0，WDA idle10/cool2。用户新问题重放会产生独立后续窗口，不沿用此时刻状态作后续结论。

## 失败与未完成

Xcode27录制未发现13；首旧版录制包装器就绪文本不匹配、播放前停止；旧导出器完整XML后SIGSEGV，另用Xcode27退出0重新导出为权威输入。分析器早期未处理新导出布局/缺栈/未知binary，均修正后完整重算。过早生成Pad t60联系图失败保留，补齐后已实际查看。不计App崩溃。

iPhone18本批DNS-SD重新解析后广告端口和同地址62078均超时，身份未核、**未发送Install，未更新5df**。最近已验证仍为本日07:10的c868无线成功批，不能把之前安装成功称为当前最新包。没有重新配对或改网络。

下一批优先字幕屏幕底部锚点及大跳转清除旧图，用户截图为未通过证据。原CPU资源警告、内存归属、换轨等待、首显/AUD/完整SUB、全部MI2/PX/UX/CB/Main/竞品/19×4等缺口保留；日志持久化和音频渲染在采样中仍有工作量，未经因果对照不随意禁用。
