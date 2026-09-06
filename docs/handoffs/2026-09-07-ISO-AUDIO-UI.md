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

1. 重新验证 ISO 可拖动进度、前后跳转、音轨/字幕显示、续播及 PiP；当前原始 PTS 起点约 600 秒，UI 为归一化媒体时间，不增加固定补偿。
2. 音频四格式 iPhone 实播、倍速/seek/锁屏控制。DSF/DFF/APE 等仅识别，尚未解码实测。
3. 设备文件视频完整失败原因尚需单独回归；NAS 离线/恢复真机矩阵。
4. UI 已核对启动台、设备、事项、我的与服务详情主要源码。同类动作保持一致；导航取消/完成与对话框遵循系统文本按钮惯例，不给所有文字硬加图标。iPad、动态字体和其余深层页面尚需视觉回归。

源代码与临时证据分开。tmp 包含带凭据的原始 URL/设备配置，严禁提交。保留 Package.resolved 原 pin，不升级远端包。
