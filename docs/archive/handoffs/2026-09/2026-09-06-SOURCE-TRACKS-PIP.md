# S01 新架构音字幕状态与 HLS PiP 接续

日期：2026-09-06；仅 iPhone 13 / LAN，遵循 ADR 0002。接续 HLS-CONTENT-MAPPING，不重复已完成的内容偏移取证。

## 已修复

1. 开启中文字幕后 KS→HLS→KS，字幕选择会丢失。共用 UI 的外部字幕选择只更新菜单/overlay；AV controls 的 sourceRuntimeTracks 是初始快照，无法代表用户最新选择。新增 `PlaybackUIEngineSession.usesSourceTrackSelectionForRuntimeState`，默认 false、Greenfield true。`SharedBuiltInPlayerView.runtimeStateForSourceChange()` 为新架构从当前源轨道菜单生成音字幕序号与明确关闭状态，画质、轨道、seek/回退等重建入口共用。旧架构仍返回原始 runtimeState。
2. 第一项修复后进一步发现“关闭字幕”会在画质切换后重新开启：旧的 `preservesServerSubtitleSelection` 用于规避 VLC 将 sidecar 报为 disabled，却覆盖了新架构明确的关闭意图。质量切换和兼容回退现对新架构尊重已知 Off，旧架构保留原规则。

涉及 `LaunchpadView.swift`、`GreenfieldKSPlayerRenderer.swift`、现有 `preflight.py` 调用检查。没有修改旧架构行为、HLS 时间轴、KS seek，也未加入 URL 导出探针。

## 真机证据与尚未完成项

- 修复前：从 HLS 菜单开启中文字幕后选 Auto，下一播放器字幕菜单变成关闭。`subtitle-selection-lost-before-fix.png`。
- 第一项修复构建：`test-source-selection.out` 和 `source-selection-{ks-on,hls-on,return-ks-on}.xml/png`，三次均选中中文字幕，暂停位置 18:28 保留。此处验证选择状态，不把菜单当作实际字幕正确显示。
- `test-track-off-pip.out` / `track-pip-hls-mandarin.xml/png`：选择国语后切 HLS，仍选国语。持久日志 trace `2AE15AA4` / plan `EF14F194`，`audioStreamIndex=2`、LAN TS proxy。没有设备听测，不将 AUD 判通过。
- 同脚本 `hls-subtitles-off` 实际仍选中文字幕，**这是第二项 bug 的失败证据，不是成功证据**。第二项修复已构建安装，但手机锁定前未能复测。
- HLS PiP：21:07:43 AVPlayer 记录 pictureInPictureRequested；`track-pip-pip-home1.png`、`track-pip-pip-home2.png`、`track-pip-controls.png` 显示主屏小窗里连续变化的影片画面。**尚未完成点击小窗返回全屏**。WDA 仍使用 Nastart 会话时 source 未列出系统小窗控件；尝试系统 session 后设备已锁定，不能将返回操作失败算作播放器错误。
- 源字幕时间表已从 LAN 读取到 `private-s01-subtitles.srt`，可选择明确 cue 核对实际 SUB。例如 00:21:08.092–00:21:10.686 “看起来就是间破房子嘛”；避免仅在没有台词的暂停点判字幕不显示。

## 最新构建、设备、下一步

最新安装包：`build-source-selection-off.log` / `install-source-selection-off.log`，构建成功；链接隔离检查通过；`preflight-source-selection-off.log` 通过；diff check 通过。随后仅补充代码注释，无行为变化。Package.resolved 按 HEAD 原字节恢复，结束前复核 IDE 是否再次删除。

设备 `/wda/locked` 返回 true，启动 Nastart 返回系统 Locked / RequestDenied；已向用户请求解锁。**下一步必须先确认已解锁并新建有效 WDA session**。不要复用当前 session ID 或假定仍停在影片。

待执行：
1. 最终构建复测：选中文字幕→明确关闭→画质切 HLS→菜单应保持 Off、请求 subtitleStreamIndex=none；再开启→切换→应保持 ID4。
2. 国语→粤语→原始流/HLS 的源轨道选择保留，按请求与实际引擎记录核实；设备听测独立。
3. 在已知 cue 时间点验证中文字幕实际显示及关闭无残留；字幕烧入与 overlay 不应重复。
4. HLS PiP 重新进入主屏、显示变化、使用系统小窗返回全屏、暂停恢复。此前只有进入/后台画面证据，完整 PP/MEM 仍未通过。
5. 完整 Q、音频/声画同步、退出续播、MEM 仍沿用未验收边界，不推进其它样本宣称通过。

持久日志：`tracks-pip-prefs/Library/Preferences/com.changliwen.nastart.plist` → `tracks-pip-export.log`。临时文件都在 `tmp/playback-20260905/`，不入 Git。整个工作区依旧未提交，不 reset/clean。
