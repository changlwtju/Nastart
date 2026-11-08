# 2026-10-01 CLI 画面观测与采样复用

## 执行范围

用户要求检索成功案例、恢复视频画面观测，并把逐帧性能采样独立处理。已读 PROGRESS、CURRENT、RUNBOOK 及新 AGENTS。保留所有既有工作区修改；本轮不改 App 源码，不清登录数据，不升级系统。

## 设备/安装

18:03 现场 iPhone / iPhone14,5 / iOS16.3.1 / `REDACTED-DEVICE-01`，USB、配对正常。源码 HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`；最新 App 源码07:32:05，正常 Debug二进制07:32:39，未新增App源码。包路径 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`，deep/strict验签通过；dylib SHA256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`；主程序 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`。

保留历史故障证据，18:04 ios-deploy覆盖安装取得最终InstallComplete/Installed package，无变量启动PID68587，新增采集脚本成功取得启动台PNG/XML。没有把普通版本号当安装身份。

用户后续继续时已19:52，USB空列表且原会话不可用；明确询问接回，没有沿用18:04在线结论。用户确认后19:53重新核实同设备/配对，19:54重新覆盖安装有完整成功回执，再无变量启动和截图。iPad/iPhone18本轮未调试。

## WDA 与可复用脚本

固定历史WDA未重装；18:04 Runner68575 ready；19:53接回时转发短暂连到默认身份com.facebook的残留Runner，按固定host停止后重新建立XCTest，Runner69302及身份校验ready。

新增：
- `scripts/wda_capture.py`：前台校验、PNG/XML、采集请求起止时间、session复用；真实启动台已验证。
- `scripts/match_video_reference.py`：离线raw灰度帧+showinfo与截图匹配，不读取认证URL。
- `scripts/tidevice_private.py`：持久私有可写缓存，替代/tmp wrapper；系统Python tidevice0.12.11，version与普通App launch实测。
- 完整环境、命令、成功案例与边界见 [CLI手册](../../../testing/CLI-DEVICE-OBSERVATION.md)。

## 历史视频证据与源帧复验

核实 `/tmp/nastart-20261001-resume2` 内真实S01截图、XML、syslog和短播记录；`s01-first`是加载详情，不误当视频首帧。9月6日 `tmp/playback-20260905` 的原脚本及截图、raw帧、showinfo仍存在，但旧/tmp FFmpeg已消失；新建持久隔离环境imageio-ffmpeg0.6.0。

离线重算 `content-fix-av-second.png` 结果完全复现历史前4名：1069.633/MAE2.73125，1069.600/2.7421875，1069.666/3.03046875，1069.566/3.121875。源raw1798帧，历史showinfo1800条，在明确尾部-to差异下允许2条末尾PTS并记录。重复动画帧仍有歧义，不能称严格唯一帧匹配或流畅通过。未联网重跑历史凭据脚本。

## 采样独立结果

本会话Instruments工具/模板正常；历史iPad `scroll.trace` TOC和display-vsyncs-interval导出成功（1945行），与下午CLI三项皆空/历史导出失败不同。当前Xcode仍未枚举iPhone13；19:55直接指定UDID录制8秒失败：No devices found matching。USB/WDA正常，所以剩余问题聚焦iOS16 Instruments设备发现，不能称所有采样或画面观测不可用。

旧1945行并不证明每个动作连续覆盖；早晨旧门槛PASS不提升为新门槛PASS。DVT约1Hz及CoreProfile原始事件也不视为完整显示帧。现有采样脚本13项测试通过；新增脚本语法及diff检查通过。

私有证据统一在 `~/Library/Application Support/Nastart/DebugEvidence/2026-10-01-cli-recovery/`；原始截图/账户路径/日志不提交。后续优先完成当前S01真实画面短序列及退出；逐帧采样继续独立处理，不作为截图路线前置。


## 20:03 最终进展（覆盖上文中途待办）

- S01实际播放观测已恢复：`video/00..03.png+xml`，四张请求偏移0/3.0039/10.0003/30.0050秒，均为Nastart前台；图像实际从吉卜力片头推进到雾中城堡。采集从命令开始计时，不冒充播放点击计时；已退出回同一详情，`after-exit`保留截图。Nastart正常进程69309。日志trace2217D65A，71条telemetry、68条playbackTick，stallSampleCount0，末段累计droppedVideoFrames1；不是零丢帧验收。
- **iPhone Instruments已恢复录制/导出**：显式 `DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer`（Xcode26.6/17F113），能枚举iPhone13；8秒Animation Hitches all-processes录制自然结束并退出0。TOC/display/hitch/commit导出成功，实际8.418323秒、374条display、16条hitch、0条commit。默认Xcode找不到该设备的失败证据同时保留；没有改全局Xcode选择。
- display时间0.358349125～8.412495833秒，最大相邻间隔66.651709ms；视频中采样能力验证不等于完整帧覆盖，也不是滚动回归。采样脚本display表实际列名timestamp，已纠正此前误用start的读取，13项测试通过。
- 下一步直接用该Xcode环境的滚动预检/正式采集，分析逐动作覆盖、显示事件语义与丢失；继续对照Lenna。画面路线已经独立完成本轮恢复，无需再等待采样问题。

- 收尾：采样预检在Downloads Xcode环境返回ready=true、problems=[]。视频已退出，syslog及本轮WDA启动进程已停止，App未注入测试环境；下轮重新启动WDA及核对设备。
