# 2026-11-13 《变形金刚》ISO 与《碟中谍》大文件样本

用户确认两组下载完成。从 iPhone 13 的 Nastart「设备 → 文件」只读核对 NAS 的 `video/downloads/movie`，在原 Wi-Fi 上串行验证。HEAD `8db1cc64`，开工 149 个未提交路径，500 个构建输入与 07:06:39 构建的签名 Debug 一致。现场核 iPhone14,5 / iOS 16.3.1、USB 与完整 UDID、已装回执，主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`，dylib `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`，签名描述文件到 11-15 08:30:17。未重装，原生空参数、空环境启动，复用已签 WDA。开始前系统主屏幕无浮窗，按安装路径核旧 Nastart 进程并备份诊断后结束。

## 样本

- 《变形金刚》下载目录含三部真实 `.iso`，列表显示《变形金刚》(2007) 26 GB、《卷土重来》(2009) 27 GB、《月黑之时》(2011) 29 GB。以第一部为 ISO-01，后两部本窗仅确认可见。容量为设备列表显示，播放器的虚拟主片字节数另记。
- 《碟中谍》合集列表确认至少三部 `.mkv`。《碟中谍》(1996) 约 51 GB、《神秘国度》(2015) 约 51 GB、《幽灵协议》(2011) 约 53 GB。本轮选《神秘国度》，文件名标注 2160p、10-bit HEVC、DoVi、TrueHD Atmos，实际源属性和设备输出按播放证据核对。既有 S03《碟中谍3》编号保留。

## ISO-01《变形金刚》(2007)

- `D91CB74F` 从头播放。ISO 准备 `indexFormat=udf titleCount=2 selectedPath=/BDMV/STREAM/00000.m2ts segmentCount=1 virtualBytes=28241829888 indexElapsedMs=1660 preparationElapsedMs=1672`，走 `directPlay / localRangeProxy / KSPlayer`。内部首帧 1,645 ms，点击确认约 17:12:33.478，首帧事件 17:12:36.909。3 秒图黑且时钟约 1 秒，10 秒和 30 秒实图分别见 Paramount 和 DreamWorks，不以内部首帧当屏幕首帧时间。
- `seek_started seekDeltaSeconds=15.064 seekTargetSeconds=63.478`，引擎完成后 `seek_recovered currentSeconds=63.614 seekRecoveryMs=8976`。途中截图有加载提示。点「完成」回详情，保留「继续观看」与「从头播放」。`iso_resource_released registeredCount=0`。
- 同进程继续观看 `4B4F4F62 plannedStartSeconds=65.6194`，内部首帧 7,320 ms、引擎初始定位 3,498 ms。恢复音轨 2、内嵌字幕轨 6，10 秒和 30 秒截图实见不同的中文字幕。普通退出回详情，`iso_resource_released registeredCount=0`。音频路由 `outputs=Speaker`，未独立现场听音或手动换轨。
- 专项证据涵盖 UDF 主片识别、实际画面、向前跳及同进程续播。未独立捕获 ISO 上游 Content-Range 响应，未测内存或长期连续性。容量策略复算为 `0 playback(s) with route evidence, 0 to check.`，此设备文件 ISO 路径未产生容量决策行，不计为复算通过。

## 《碟中谍5：神秘国度》

- `70EE1E2F` 走内网 `connectionAddressKind=privateIP / directPlay / localRangeProxy / KSPlayer`。内部首帧 1,274 ms，3、10、30 秒三张截图均有实际画面。原片代理多次收到 206，尾段记录从 55,092,135,511 至 55,092,144,233 字节完整交付 8,723 字节，对应文件长度 55,092,144,234 字节（约 51.31 GiB）。没有把稀疏截图当完整帧时间或持续流畅验收。
- `source_capabilities sourceDVProfile=7 sourceDVLevel=6 sourceDVCompatibilityID=6 videoBitDepth=10`，17 条字幕，自动应用轨 10，音轨 1。引擎记录 `audioPath=decodedPCM outputs=Speaker`，`dolbyVisionOutput=unverified dolbyAtmosOutput=unverified`，实际扬声器听测和设备的 Dolby Vision / Atmos 输出仍待，文件名不能证明输出。
- 前进 15 秒，`seek_engine_completed completed=true targetSeconds=62.284`，`seek_recovered currentSeconds=62.335 seekRecoveryMs=4231`。普通退出实见详情和「继续观看」，本轮未点该片续播、未切轨。路线脚本 `0 playback(s) with route evidence, 0 to check.`，设备文件原片路径本窗无容量决策行。

## 收尾

17:10:51–17:16:36，原 Wi-Fi 图标和主屏幕已核，App、Runner、采集及 8161 归零。逐步导出，私有证据入口 `/tmp/nastart-codex-new-samples-20261113-current`。只操作 iPhone 13，未切网、改远端、改代码或调参，无新构建和单测。后续补同一 ISO 的 Jellyfin 对照、真实听音、其余两部抽样，以及《神秘国度》续播与实际 Dolby 输出核验。
