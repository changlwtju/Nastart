# 2026-10-12 设备文件 TS 时间轴与正在录制文件打开修复

- 更新时间：2026-10-12T23:29:18.640414+08:00。USB13/Pad优先，配对无线18更新；每设备/窗口名称、型号、系统、UDID及连接重核，原始身份/凭据/偏好/图只在本机私有。HEAD4de732dd、dirty源4e362e83；普通Debug主c64595d9/Debuge023a1ce/KSe68d7420，173输入/29逐库与深验/profile/IPA/链接及最终三SHA核验；实际337测试、2跳过、0失败和15预检。其他dirty/网络/系统/配对保留。
- 完整电影TS旧包24:09:59错误时钟：保留合法>24h/负FFmpeg原点，初始seek使用时间单位且不带字节标志，媒体丢帧使用相对原点；6项回归。首修1a62冷续播0帧/EOF/无法播放真实失败保留，二修1e81及最终4e36 Pad S05冷续播实际电影与正常时钟、普通退出769.469611已核。
- 用户最新目录持续变化，先发现MP4，再找到正在增长R01 TS；最终Pad列表80216064→实际162267136、13列表165412864→实际371458048 bytes，206/video-mpeg。TS/m2ts/mts只允许追加长度；其他文件仍严格等长、缓存隔离、截短/HTML/JSON/401/416拒绝。本轮未改缓冲/decoder/probe-size。两机串行90秒请求窗实际画面变化，Pad拖动约58秒后恢复有画面；非精确seek/完整帧/音频/直播尾部通过。
- 新发现R01冷续播失败：13正常退出保存130.6754，冷启动刷新448790528→461635584 bytes后入口变预览，initialPosition=0，普通退出42.7394。书签身份含长度和mtime，增长会换key；不得声称录制文件续播已修。下一步安全识别同一追加录制与替换文件、补冷续播，然后增长尾部等待/时长刷新/录制结束恢复。
- 最终USB23:00:38/48及无线18 23:11:16保留容器覆盖同包成功，安装时25/16/25偏好逐值不变；USB普通空env/args实际首页已看，18未本轮启动/实际UI仍待验。无线Bonjour探测超时/既有端点重新核对成功均保留，不声称Xcode自动隧道修复。
- 最终13原24/Pad原15非书签偏好不变，各5/2书签自然更新、S03文件/JF原轨及位置未动、无新崩溃，正常首页/播放器关闭/idle10动画2已核。Pad查最新目录的UI排序实会持久化，已正常UI恢复名称升序；额外2个默认排序key保留并明确记录，不能声称偏好总字典完全一致。未手写设备偏好/清登录/卸载。HDR PiP、历史重复原句、全SUB/AUD/HDR/性能/蜂窝/Lenna及全部PX/UX/CB/Main/MTP/L2/L3、475/119/HLS等未验总账保留。


## 包和安装身份

- HEAD：`4de732dd645b36671becff992cdef1d0163fd1e4`；所有原有未提交修改保留。源码diff SHA-256：`4e362e83bf54a133c5e974d637e3b257334a750cc07ea1a0024dc8e638d95a13`。
- 配置：普通Debug -Onone，空env/args，无注入条件；构建时间 `2026-10-12T22:58:16.565725+08:00`。
- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-device-file-ts-investigation-221450/Nastart-TS-Recording-Growth-Final-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-device-file-ts-investigation-221450/Nastart-TS-Recording-Growth-Final-Normal-Debug.ipa`。原始证据目录权限私有，设备名/UDID、端点、完整文件名、凭据、原图不复制到项目。
- `Nastart` SHA-256：`c64595d9911ce8c910a9e1507fc2f86f755161e03e5079a8bfc44129aafdf566`。
- `Nastart.debug.dylib` SHA-256：`e023a1cef56f33f878cf1fd7373b1ba8c8fc4cae812ba5dc685d9a4161b18d5a`。
- `Frameworks/KSPlayer.framework/KSPlayer` SHA-256：`e68d742056f06b8806d18ce13f3027b47a2d9bc380671b7371a985b6d139f785`。

| 设备 | 本轮现场型号/系统/连接 | 安装 | 当前正常界面 | 本轮播放 |
| --- | --- | --- | --- | --- |
| iPhone 13 | iPhone14,5 /16.3.1 /USB | 最新包保留数据覆盖，25项不变 | 空环境实际首页已看 | R01增长TS打开；冷续播失败 |
| iPad | iPad12,1 /18.3.1 /USB | 最新包保留数据覆盖，16项不变 | 空环境实际首页已看 | R01增长TS打开/拖动后继续；S05冷续播 |
| iPhone 18 | iPhone19,7 /27.0 /配对无线 | 最新包覆盖，25项不变 | 本轮未启动/待验 | 未测试 |

## 证据边界与下一轮

- TS支持原本已有；故障包含增长文件被旧长度检查拒绝，以及TS源时间原点和初始seek单位错误。文件列表与播放间文件增长是真实证据，旧版本同一增长时刻未回装复现；“旧严格等长会拒绝”由旧代码+实际长度推导。
- 用户“按时间最新文件夹”不是稳定身份：23:03最新文件夹是已完成MP4；23:07更新列表出现R01正在写TS；23:11又出现另一较新MP4文件夹。未读取录制服务配置，不能认定MP4是完成后自动转码。记录R01确切文件与每次修改时间只在私有证据。
- `recording-active-pad-file` 90秒请求窗clock0.294→119.643；拖动界面00:58/06:18已看，随后恢复自然画面，普通退出保存141.893611。滑杆量化、字节估计、采集与退出耗时使真实播放时间超过请求90秒，不能将其标成准确90秒或60秒精确seek。
- `recording-active-phone-file` clock0.115→130.121，退出130.6754；`recording-active-phone-cold-file` clock0.137→42.718、initialPosition0.0/initialSeek notRequested，退出42.7394。后者是续播失败，虽无媒体错误仍不PASS。`LocalPlaybackResumeStore.key` 的长度/mtime身份需安全增长策略，不能简单忽略全部文件替换身份，也不能手写书签制造通过。
- 原点固定S05旧24:09:59错误，首修真实冷seek零帧失败、最终包正常冷电影回归；13 FileStation API119、原生工具/错误Python运行时、无线端口超时、Pad首次审计2个排序key不一致均保留。119后来正常刷新/冷启动/覆盖后恢复，未做因果隔离，不说账户/网络根因已解。
- 最终首次审计严格字典断言失败：Pad正常UI排序新增2 key；正常UI恢复name/true后重新审计，原15项逐值一致、2默认key新增。无偏好文件写入。报告明确`nonBookmarkPreferencesExactlyUnchanged=false`，故障未删除。
- 下一轮先最新包身份门槛，USB13/Pad串行R01安全增长续播/换文件负例，再增长尾部等待、时长刷新、停止录制/追加恢复。当前播放器仍按打开时已知长度/时长，不能宣称持续追新尾部或完整直播播放。
- 不用稀疏截图/内部clock验收帧流畅、声音、字幕、HDR、蜂窝、竞品；下一轮仍执行Lenna主对照与完整帧矩阵。18下一步实际最新UI/播放和Xcode自动通道；现有网络/VPN不变。
- 其他旧未完成项继续依照上一交接：HDR PQ PiP外置字幕仍F、历史重复“Remember / I can figure…”原句未重放、失败准备回滚/13真实AV、S01四入口/代表S08/S11/S18/S19、19×4、HLS deadline/分片/read callback、所有旧PX/UX/CB/Main/475/119/MTP/L2/L3均保留。该L1专项不替代全矩阵。

安全结果见[本轮JSON](../../../testing/results/2026-10/DEVICE-FILE-TS-RECORDING-20261012.json)，先前字幕/画中画交接见[上轮](2026-10-12-PIP-RESTORE-SUBTITLE-STATE.md)。
