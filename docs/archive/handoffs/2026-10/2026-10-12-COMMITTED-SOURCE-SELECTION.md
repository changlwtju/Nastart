# 自动候选结束后的字幕选择一致性修复

更新时间：2026-10-12T17:03:26.581406+08:00。继续 Mac USB iPhone13/iPad；iPhone18用户带走，本轮未发现、连接、安装或测试。开工已读PROGRESS、CURRENT和播放runbook；其他未提交修改和Tailscale/Shadowrocket、网络/系统/配对保留。

## 问题与修复

基线普通包8322在iPhone13 S03 Jellyfin开启外置ASS5后，自动降档因deliveryBelowSourceBitrate开始AV准备，时间早于手动关闭字幕11.377秒。成功的原生Off使自动候选alignment/candidateInvalidated、cancelled=false、未提交。准备结束观察器却按旧request重设菜单ASS5和外置覆盖，实际再次显示白双语；正常退出保存4412.541秒/音轨1/字幕nil/off=true。这是已提交原生选择与旧请求不同步，不能记作手动切轨准备失败回滚。

本轮三文件修改：LaunchpadPlaybackCore加入已提交runtime源字幕身份解析；SharedBuiltInPlayerView在sourceTrackChangeInProgress结束后，对支持源选择且字幕身份已知的renderer同步菜单、音轨和overlay，原生Off保持nil，未提交候选保留实际旧轨；PlaybackNextCoreTests新增原生Off/旧外置保留和实际源索引/未知sidecar两项回归。外部URL只唯一映射已有非负源ID，未知不猜。未改候选deadline、对齐、ready、缓冲、路由或KSPlayer源码。实际326测试/2跳过/0失败，15预检，正常Debug构建成功。

## 最新包与设备门槛

- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS dirty diff SHA-256 `5907048189b28f527c02383402938fb06907a12bfd2f57bca80407eed0cab7af`；普通Debug/-Onone，构建 `2026-10-12T16:29:52.953492+08:00`，启动env={}/args=[]。
- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-source-selection-162926/Nastart-Committed-Source-Selection-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-source-selection-162926/Nastart-Committed-Source-Selection-Normal-Debug.ipa`。
- 主SHA `63821b634e4eb50c497a3f0cefb7084e0c435885644f9ba38d24c2f1da9b0799`；Debug `2f5eee64dc077d28b476262fde6ead5a8c94bdd2d48d7632454fc259749f3a3b`；KS `df76e71df756331a8e80a0e0550683b73a24af6282db214a7401fd975af643c4`。
- 173输入SHA/mtime、三二进制SHA、29库独立签名、deep/strict、IPA三SHA与链接核验，最终源码/产物/签名复核通过；profile UTC `2026-10-17T22:23:40`，无源晚于产物。KS二进制是本次重建结果，不代表本轮改了KS源码。
- 开工、切换及各回归现场读取名称/型号/系统/UDID/USB，私有身份核对一致。先保存诊断，逐机保留数据覆盖签名最新包，成功回执、普通启动和实际首页原图已核。未卸载/清登录/手工写偏好。

| 设备 | 型号/系统/连接 | 最新安装成功 | 安装前后非诊断偏好 |
| --- | --- | --- | --- |
| iphone13 | iPhone14,5 / 16.3.1 / USB | 2026-10-12T16:32:20.232898+08:00 | 25 项一致 |
| ipad | iPad12,1 / 18.3.1 / USB | 2026-10-12T16:32:27.495776+08:00 | 16 项一致 |

## 最新包实际结果

| 路径 | 实际结果 | 验证边界 |
| --- | --- | --- |
| 13 JF ASS→Off/自动AV候选失效 | 再现自动候选失效，菜单勾选Off，实际无覆盖字幕，正常退出4496.868/1/nil/off | 未提交AV，不是手动准备失败负例 |
| 13 Off冷续播 | 普通冷启不重新选轨，30秒正常退出4520.13/1/nil/off；3/10等待、30实际电影 | 等待保留，不算连续流畅 |
| 13重新ASS5 | 30秒/实际白双语，退出4549.494/1/5开启 | 基础内容与身份 |
| Pad ASS→Off | 新鲜systemAVPlayer/localHLS replacement_committed，观察到提交用时约20.040秒、startsPaused=true；实际暂停无字幕及菜单Off | 非首帧/性能通过 |
| Pad AV重新外置ASS5 | AV内部原生外置切换，无需第二次replacement；菜单ASS已核，3/10实际白双语、45电影、fresh1288cue与41份AVPlayer遥测，正常退出4577.965195893/1/5开启 | 已验证基本AV外置内容/身份；非全SUB/音画 |
| Pad从AV退出后冷续播 | 普通冷启，不重新选轨，fresh实际KSPlayer/localRangeProxy，退出4607.833/1/5开启；3/10/30电影无字幕cue | 名称av-cold指前一退出路线，不是AV冷路线；只验身份，冷续播内容待补 |
| 两机JF恢复原PGS7 | 正常详情选择/30秒/正常退出；Pad30灰中文金英文实际cue | 13补采10秒spinner保留；两机原1/7开启恢复 |
| 两机S03设备文件 | 各30秒/正常退出，13原4/ASS5开启、Pad原4/off保持；10/30电影，13白双语实际可见 | 13第3秒准备页、Pad第3秒旋转/黑/spinner保留 |

最新源完成7个普通原生短时窗口，外加13原生Off一致性窗口和Pad AV外置45秒窗口。每个窗口均记录源/包/安装身份与空env，实际3/10/30（AV为3/10/45）原图已看；没有跨设备同时供流。PGS内容完整性、自然长句和音频/HDR/完整帧时间未验收。

- iphone13：S03文件 `{'positionSeconds': 646.729, 'audioTrackID': 4, 'subtitleTrackID': 5, 'subtitlesDisabled': False}`；S03 Jellyfin `{'positionSeconds': 4903.582, 'audioTrackID': 1, 'subtitleTrackID': 7, 'subtitlesDisabled': False}`。24项非书签偏好一致，2条书签自然更新，新增崩溃报告0。
- ipad：S03文件 `{'positionSeconds': 912.997, 'audioTrackID': 4, 'subtitleTrackID': None, 'subtitlesDisabled': True}`；S03 Jellyfin `{'positionSeconds': 4638.057, 'audioTrackID': 1, 'subtitleTrackID': 7, 'subtitlesDisabled': False}`。15项非书签偏好一致，2条书签自然更新，新增崩溃报告0。

最终普通首页/NAS正常/播放器关闭实际原图已看，WDA idle10/animation2恢复。13最终首次截图出现系统Apple ID登录密码弹窗，按系统实际UI取消后补采无挡首页；不输入密码，账号和截图只留私有证据。服务警告仍存在，不称全部服务在线。

## 保留的失败和下一步

基线8322 Pad真实AV关闭提交19.1447秒及后续外置已核，但不替代新包结果；初版工具误等外置切换第二次AV提交，50秒断言失败保留并纠正。13基线菜单HTTP404、原先错误的ASS回滚断言均保留，自动失效重新分类为候选被原生选择替代，不能算手动准备失败回滚。

新包13首轮PGS恢复在t15后WDA RemoteDisconnected/ConnectionRefused，窗口保留为tool-incomplete。现场USB仍在，崩溃清单无新增；WDA恢复ready，新session/前台/解锁/原图复核后普通退出保存4879.701/1/7开启，再单独重采30秒。连接失效期间播放自然继续，不能把整段当作30秒采样或应用崩溃；后续依赖动作因门槛失败未发生。没有重装Runner或改网络。最终系统弹窗标记首断言因不换行空格失败亦留证，按实际源确认后取消。

下一步先补手动准备失败回滚负例、13真实AV、Pad冷续播自然字幕cue/PiP，再S19 PGS/S11 TrueHD/S18 FLAC代表族；随后按同条件完整显示帧时间与Lenna（13/Pad）/DS One对照。完整SUB/控制动画/样式/长句/burn-in、音频/HDR、蜂窝/MTP、475/119供流/read/callback/HLS、18无线原生自动隧道与全部PX01～21/UX01～06/CB/L2/L3/Main缺口继续保留，不升为PASS。

脱敏记录：[JSON](../../../testing/results/2026-10/USB-COMMITTED-SOURCE-SELECTION-20261012.json)。最新原图/XML/偏好/凭据/设备身份/媒体URL/日志/失败/包/冻结脚本仅在私有目录 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-source-selection-162926`，基线目录 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-160702`。继续前仍须执行最新包门槛。
