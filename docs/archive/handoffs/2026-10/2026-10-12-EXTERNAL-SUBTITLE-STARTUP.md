# 外置字幕冷启动显示与续播身份修复

更新时间：2026-10-12T11:52:43.972971+08:00。按用户要求继续 Mac 上连接的 iPhone13/iPad；iPhone18 已带去上班，本轮未发现、连接、安装或测试。开工读取 PROGRESS、CURRENT、播放调试规范及竞品矩阵，保留其他未提交修改。

## 现场问题与改动

旧正常包 9fe5 在 iPhone13 S03 Jellyfin 详情选择 ASS5，规范化后提供外部 SRT，却同时携带“关闭嵌入 ASS 渲染”的旧标记。Greenfield 将其解释成全部字幕关闭：当轮新鲜 overlay_loaded 为 0，正常退出后保存位置4119.071秒、字幕ID为空且关闭。播放能出画面不能证明外置字幕正常。原图、请求、偏好、退出及旧包身份均保留。

最终修改五个文件：MediaPlaybackRequest 增加 Greenfield 专用关闭语义（只有旧关闭标记且无外置URL才关闭）；桥接初始化和 subtitlePlan 两处均使用它；共享覆盖字幕的初始化/切换回滚恢复按新语义，旧兼容播放器分支仍使用原语义；KS PiP 外置模型在连接时同步初始URL。保存时仅将唯一、非负的源字幕目录URL映射回源轨道ID，独立/未知或同URL多轨不猜ID，避免 ASS5 在冷续播时丢失或退回默认PGS。没有改动 KSPlayer 源码、候选对齐/deadline/缓冲门槛、网络、系统或配对。

新增两项回归：规范化外置文本的实际桥接模式/源轨5/保存重读及显式关闭；未知、负ID与歧义源身份不推断。第一轮324项测试有1失败，揭示漏改的第二处 subtitlePlan 关闭守卫；该构建未安装，失败日志单独保留。补齐后重新完整构建，实际324测试、2跳过、0失败，15预检通过。

## 最新包与逐台门槛

- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS dirty diff SHA-256 `832259d17114836b84f145463af869c000e8913b8f7c79467ab3d64cb5bd6c3b`；正常 Debug/-Onone，构建 `2026-10-12T11:22:29.283846+08:00`；普通启动 env={}/args=[]。
- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-105527/Nastart-External-Subtitle-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-105527/Nastart-External-Subtitle-Normal-Debug.ipa`。
- 主 SHA `7b48bcc467cb70c5000f903c0603600492f19552c60e9d4dd60e850330ffc994`；Debug `f8f2b30e029120d49a7c634b2723454d98af5da7dc7edbc3fdb9f3909ab8eb57`；KS `a8b150bb68836745c5f5749d138cdc7b173eedb7cfc138ade464cb2cac9cdf28`。
- 173输入逐SHA与mtime、三个二进制与IPA、29库独立签名、deep/strict及链接核验；最终输入/源码/三SHA/deep签名/diff check重核。profile UTC `2026-10-17T22:23:40`。源码没有晚于产物的输入。
- 现场及各窗口独立读取设备名称、型号、系统、UDID/USB；对应私有身份核对一致。最新安装身份不能由版本号证明，所以先保存诊断，再保留容器覆盖安装。无卸载、清登录或写入原始偏好。覆盖安装25/16项非诊断偏好一致，空环境普通启动的真实首页已看。

| 目标 | 现场型号/系统/连接 | 最新包安装成功时间 | 安装前后非诊断偏好 |
| --- | --- | --- | --- |
| iphone13 | iPhone14,5 / 16.3.1 / USB | 2026-10-12T11:25:26.224279+08:00 | 25 项一致 |
| ipad | iPad12,1 / 18.3.1 / USB | 2026-10-12T11:25:36.206258+08:00 | 16 项一致 |

开工13有前次登录留下的系统密码弹窗，原始阻挡图保留；切换WDA到系统实际弹窗后按取消解除，未输入凭据、验证码不入项目。Pad WDA连接重置，复用已签名Runner的正式test-without-building恢复，未重装Runner；既有网络配置保持。

## 最新源码真机结果

| 路径 | iPhone13 | iPad | 边界 |
| --- | --- | --- | --- |
| S03 Jellyfin 详情选ASS5 | 30秒普通播放/正常退出，保存1/5开启，位置4142.759 | 首两次点击未进入播放器；方向刷新与普通重启后重新选ASS，45秒播放、实际白双语、正常退出保存1/5开启，位置4235.210 | 两次工具失败留证，不算播放通过；方向状态不同步是推断，不声称已定位WDA根因 |
| S03 Jellyfin 冷续播ASS5 | 普通终止/空环境重启，详情ASS；新鲜请求5，两份覆盖模型各加载1288 cue；3/10/30/45图实际核对，30/45白双语；退出4182.832仍1/5开启 | 空环境冷启动、不重新选轨；请求5/1288 cue、10/45白双语；退出4276.951仍1/5开启 | 旧嵌入关闭标记仍true但外置正常，不能要求它变false；仅基础内容和身份验证 |
| S03 Jellyfin 恢复原PGS7 | 普通详情选择简英PGS、30秒/正常退出，1/7开启 | 同样30秒/正常退出，1/7开启 | 原图3/10/30已核，有灰中文/金英文cue；不是所有PGS验收 |
| S03 设备文件续播 | 30秒/正常退出，原4/ASS5保持；t3仍准备页，t10/t30实际电影 | 30秒/正常退出，原4/off保持；t3黑屏spinner及旋转过渡，t10/t30电影 | 早期延迟原图保留，非首帧或流畅通过 |
| S01 设备文件/Jellyfin | 各30秒，3/10/30原图、普通退出已核 | 各30秒，3/10/30原图、普通退出已核 | Jellyfin现场按钮为“在 Nastart 中播放”；13旧按钮守卫停止未提交动作，修正后重采，失败不丢弃 |

最新源共12个已进入播放器并正常退出的串行窗口，均实际 KSPlayer/localRangeProxy；没有把本轮旧包AV候选或前轮9fe5 AV菜单结果算作8322的AV验证。普通启动、源/包/安装回执及现场身份逐入口核对，媒体只单路顺序进行。13两次ASS窗口t10及Pad冷续播t3有spinner，字幕模型加载/保存或后续出画面不能证明连续流畅。

- iphone13：文件 S03 `{'positionSeconds': 621.342, 'audioTrackID': 4, 'subtitleTrackID': 5, 'subtitlesDisabled': False}`；Jellyfin S03 `{'positionSeconds': 4232.274, 'audioTrackID': 1, 'subtitleTrackID': 7, 'subtitlesDisabled': False}`。24 项非书签偏好一致，4 条播放书签更新，新增崩溃报告 0。
- ipad：文件 S03 `{'positionSeconds': 886.587, 'audioTrackID': 4, 'subtitleTrackID': None, 'subtitlesDisabled': True}`；Jellyfin S03 `{'positionSeconds': 4307.197, 'audioTrackID': 1, 'subtitleTrackID': 7, 'subtitlesDisabled': False}`。15 项非书签偏好一致，4 条播放书签更新，新增崩溃报告 0。

原S03文件/Jellyfin轨道通过普通UI恢复，位置保留实际播放更新；没有手工回写偏好。最终两机空环境普通重启、稳定首页/NAS正常/播放器关闭原图实看，WDA idle10/animation2恢复。其他服务警告仍存在，不称全部服务在线。

## 失败与未完成项

旧包Pad sidecar后切off触发AV候选，工具在准备期提前退出，仅是取消未提交；另一轮实际KS原生PGS切换却等待AV replacement_committed导致工具超时。原日志/原图/归类保留；随后KS自然窗口与普通退出恢复PGS。Phone基线文件入口误在Pad候选未结束时启动，重叠流单独排除，不用于单路性能或AV通过。以上都不能替代真实准备失败回滚负例。

本轮修复并验证外置SRT基础冷启动/保存/冷续播；实际AV外置字幕、PiP画面、显式off/失败回滚全过程、完整字幕样式/长句/控制显隐动画与burn-in隔离仍待验。继续USB代表族S19 PGS/S11 TrueHD/S18 FLAC及13 AV，再按竞品矩阵采完整显示帧时间和同条件Lenna（13/Pad主对照）/DS One；本轮未做正式竞品配对、蜂窝、音频/HDR/MTP或性能验收。原475/119、供流/read/callback/HLS、18无线原生隧道、全部PX-01～21/UX-01～06/CB/L2/L3/Main缺口保留。

脱敏证据：[本轮JSON](../../../testing/results/2026-10/USB-EXTERNAL-SUBTITLE-20261012.json)。全部设备私有身份/凭据/偏好/媒体地址/截图/XML/日志、包、命令、失败和冻结助手仅在本机私有目录 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-105527`。继续前先执行最新安装包门槛。
