# 文件续播按钮刷新

## 实施前变更卡

- 对应UX-01/03、PX-21。上一轮iPad S19同键进度最终101.408秒，冷重开续播正确，但第二次退出预览页仍显示“预览”。尚未证明进度丢失。
- 源码证据：FilePreviewView的标题直接查询LocalPlaybackResumeStore.shared；store只有锁保护的持久存储，没有ObservableObject通知，页面没有订阅保存变化。
- 范围：保存成功且锁释放后通知主线程，文件预览页观察同一个resume store。保留原书签身份、完成归零、轨道继承、存储上限与播放/网络/鉴权参数。
- 受控规则：后台保存后观察者在主线程读取已持久的当前记录；另一文件/账号的保存不能借用书签；完成归零及时更新标题输入，非法值不覆盖有效书签/不发有效变更通知。
- L0：XCTest/预检/正常Debug编译与签名、源码清单；L1：13/iPad最新包逐机覆盖和正常启动，原iPad S19退出场景+S01另一片源、文件入口退出后立即及稳定标题、冷重开；S01双入口四单元补共享展示基线，正式L2/深seek/全帧/字幕声音等保留。
- 恢复/手动登录竞争审查已读：初次restore登录激活、SID-only快照尾部、凭据保存及catch/defer所有权仍待受控验证。本批不修改鉴权逻辑/不新增自动重新登录，另行闭环。
- 实施前状态（历史检查点）：尚未新包构建/安装/真机回归。初始将18无线配对列表误判为USB，后经USB-only与ConnectionType重核纠正；当时未安装或回归18。原始身份/偏好/凭据只留本机私有证据目录。

## 构建与当前检查点

- 2026-10-10T15:03:57.679205+08:00：265 XCTest/2跳过/0失败（新增3续播通知反例）、15预检/18安全报告测试完成，普通Debug -Onone构建成功。iOS diff 53b6c222dc55ad8fbcc2a74689cc60608ecc202fb2190aeab02221eb2313e6fe；构建 2026-10-10T15:01:41.885128+08:00；173输入、29库及deep/profile/链接核对通过。三二进制 SHA-256：{"Nastart": "5de9b770f629b1637699b46d1577f396e790afff5c05d4d8886b44ce66f97ba6", "Nastart.debug.dylib": "05cf9654a38eb6c589e6b95901c09a72eb00e8cd0d44c02e4148dc84df06aa51", "Frameworks/KSPlayer.framework/KSPlayer": "eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52"}。
- iPad最新包保留数据覆盖，16非诊断偏好安装与正常空环境启动后一致；实际NAS首页/播放器关闭已看，初始JF灰色unknown单列。原S19退出/冷重开定向验证进行中，13/18新包门槛尚未完成，不能提前称本批全机更新/修复通过。

## 真机中途检查点

- 2026-10-10T15:12:46.178107+08:00：iPad4窗完成，S19从头退出/冷重开再退出及S01文件均立即和稳定显示继续观看，已查看实际图片；S19冷重开保存59.269→首钟59.391（差0.122）→稳定退出持久96.287秒。S19从头t60黑场单列未定因、不当正文通过。
- iPad S19冷续播首推进6.923823秒、启动3003ms等待；39.935429秒再等待未有完整结束事件，41.654050秒备用接手、AV观察首推进41.936566秒。不能把原引擎等待跨切换计作完整关闭/性能PASS；仅修复按钮通知。
- 手机新包25偏好安装/普通空环境实际启动后一致，NAS首页/播放器闭合已看，初始JF灰未知保留；手机4窗进行中。18已接入但本批新包安装尚未执行。

## 本轮收尾（2026-10-10T15:29:46.969028+08:00）

文件预览页已订阅书签保存变化；保存完成且锁释放后在主线程通知。只改3个iOS文件，173个冻结输入对照及鉴权/网络/播放器参数未改证明保留。本轮实际执行265 XCTest（2跳过、0失败；3新增观察反例）、15预检及18安全工具测试。定向L0/L1完成；正式L2/L3、性能和Main继续开放。

- HEAD：`4de732dd645b36671becff992cdef1d0163fd1e4`；已有未提交修改保留，iOS diff SHA-256：`53b6c222dc55ad8fbcc2a74689cc60608ecc202fb2190aeab02221eb2313e6fe`。
- 包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-resume-preview-refresh-145700/Nastart-Resume-Preview-Refresh-Normal-Debug.app`；普通Debug `-Onone`，构建 `2026-10-10T15:01:41.885128+08:00`。三二进制完整SHA-256见上文和脱敏报告；收尾173输入、3哈希、29库、deep签名、有效profile及三目标资格再次核对。
- 每次设备切换/开窗均现场读名称、型号、系统、UDID及连接；原始UDID/登录偏好/凭据只留本机私有证据，未卸载/清数据。iPhone13（iPhone14,5/16.3.1/20D67，名称iPhone，USB）15:11:29保留数据覆盖及正常空环境启动，25偏好一致。iPad（iPad12,1/18.3.1/22D72，名称iPad，USB）15:02:18同样完成，16偏好一致。安装身份依据本轮验证包与安装成功回执，非0.1.0/1或能启动推断。
- 两机串行各4窗：S19文件从头60秒、App冷重开点继续观看45秒、S01文件/Jellyfin各60秒，共8完整窗/8原UI退出。6个文件出口立即与稳定实际图均显示继续观看及从头播放；6正文窗，另2个S19从头60秒暗场/淡出片头仅保留观察，不确定是片源或渲染原因，不算正文/流畅PASS。
- 同私有精确键冷重开：Pad保存59.269→首钟59.391（差0.122）→退出96.287429232；手机冷前58.28565841→首钟58.401（差0.115342）→退出92.080275267。手机前窗稳定出口快照45.503102409与冷前58.28565841有变化，保存收敛时间边界未核，不据此声称连续最终保存验收。此处只接受近开头冷进程续播，不代替深seek/长窗或冷服务端缓存。
- 本批新目录响应Pad20/手机21均success，无本批API119；不关闭旧119/服务端SID丢失原因。Pad S01文件一次诊断SocketError读取失败后原窗连接重试恢复，失败原记录保留；无可见播放器错误。
- 最终两机正常空环境/空参数实际前台，NAS/DSM/Jellyfin绿在线、播放器闭合，原生条件active0（15:19:50）、idle10/动画2已恢复；15:25只读最终实际图确认。Radarr/Sonarr及Pad Prowlarr为橙色警告，不声称全部服务绿。重启初始JF灰/unknown的早图保留。

### 等待证据（秒均相对各窗原动作，按引擎分段）

|设备/窗口|引擎|首观察推进秒|等待记录|
|---|---|---:|---|
|ipad/normalwifi-baseline-resume-s01-files|KSPlayer 35357E7F|3.201648|本窗未报告等待，不作流畅PASS|
|ipad/normalwifi-baseline-resume-s01-jellyfin|KSPlayer 409EC85B|2.910091|本窗未报告等待，不作流畅PASS|
|ipad/normalwifi-cold-reopen-resume-s19-files|KSPlayer 4ED3F3E6|6.923823|3.912194起/beforeObservedAdvancingClock/3003ms，结束6.923823; 39.935429起/afterObservedAdvancingClock/无完整结束/时长unknown，保留右截断|
|ipad/normalwifi-cold-reopen-resume-s19-files|AVPlayer 6B1D57F5|41.936566|本窗未报告等待，不作流畅PASS|
|ipad/normalwifi-from-head-resume-s19-files|KSPlayer D0AA93D4|3.844012|本窗未报告等待，不作流畅PASS|
|iphone13/normalwifi-baseline-resume-s01-files|KSPlayer 29FD6D3D|2.019159|本窗未报告等待，不作流畅PASS|
|iphone13/normalwifi-baseline-resume-s01-jellyfin|KSPlayer ABDE6BB9|2.320389|本窗未报告等待，不作流畅PASS|
|iphone13/normalwifi-cold-reopen-resume-s19-files|KSPlayer EB44FE84|7.118969|4.221064起/beforeObservedAdvancingClock/2900ms，结束7.118969; 17.717728起/afterObservedAdvancingClock/6300ms，结束24.014265|
|iphone13/normalwifi-cold-reopen-resume-s19-files|AVPlayer 26B1BDAC|37.381462|37.176523起/beforeObservedAdvancingClock/211ms，结束37.381462|
|iphone13/normalwifi-from-head-resume-s19-files|KSPlayer 5D0F3266|4.457262|本窗未报告等待，不作流畅PASS|
|iphone13/normalwifi-from-head-resume-s19-files|AVPlayer 7331C5F3|29.532668|29.032554起/beforeObservedAdvancingClock/无完整结束/时长unknown，保留右截断|

手机冷续播原KS启动2900ms、推进后6300ms等待，备用AV211ms；Pad启动3003ms、39.935429起原KS等待未完整关闭。手机从头AV等待亦无完整结束，不能把接手/后续钟推进强行当结束或时长。保留旧弱网等待、旧ordinal0与所有失败，禁止跨Debug/Release或不同缓存性能排名。

### iPhone18独立安装结论

现场名称iPhone、iPhone19,7/27.0/24A8428，连接为NETWORK无线配对、无USB；初始“USB”误判与失败门槛证据保留并纠正。原生CoreDevice安装4016（tunnel unavailable/MobileDevice-only）失败后，同173源码输入/签名/profile验证包以无改签Payload IPA通过既有AFC+installation_proxy保留数据覆盖，2026-10-10T15:26:00.457482+08:00返回InstallComplete并Lookup成功，IPA三二进制逐字节SHA与验证包一致；25非诊断偏好安装前后一致。**最新包安装成功；正常启动与实际画面验证未完成**：原生启动同连接受阻，既有配对DVT返回InvalidService、截图服务不可用；未卸载、未重装WDA、未改网络/系统设置，未开始18最新包播放/性能回归。需18以USB连接后重核同包、默认无注入启动及实际画面；13:11旧包启动证据不冒充本批新包结果。

### 接续事项

先补受控恢复/手动登录尾部所有权：相同SID不同登录UUID的迟到snapshot；取消后login/FS/snapshot不发布、不保存凭据、不写失败；旧cleanup不清新任务标记；手动登录/退出使恢复失效，旧任务logout不得注销复用同SID的新会话。反例成立后再最小鉴权修复并构建/逐机核包。另补手机S19保存收敛时间边界及等待原事件、18USB正常启动、真实弱无线/蜂窝/外部Wi-Fi、完整帧/自动位移、声音字幕/HDR/十分钟/PiP/MTP与Lenna同条件完整失败保留对照。全部PX/UX/CB/19×4/L2/L3/Main原缺口保持，按钮定向通过不改总状态。

完整脱敏报告：[RESUME-PREVIEW-REFRESH-20261010.json](../../../testing/results/2026-10/RESUME-PREVIEW-REFRESH-20261010.json)。私有原图/偏好/命令/失败/源码差异与帮助脚本归档在本轮DebugEvidence目录，勿提交原始凭据。
