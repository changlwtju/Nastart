# AV 字幕菜单与已提交播放方案一致性

更新时间：2026-10-12T09:33:29.794015+08:00。本轮继续 USB iPhone13/iPad。用户已将 iPhone18 带去上班，未发现/连接/更新/回归该机；当前 9fe5 包在18未安装，既有18历史证据不得复用为最新结果。

## 问题与最终改动

关联 PX-20/PX-21（字幕切换、菜单与断点保存），兼顾 PX-03 AV 自动候选。开工已读 PROGRESS、当前交接、调试规范、分层流程与竞品矩阵，其他未提交修改完整保留。

575947 正常包在 iPad 设备文件 S03 实际 AV/localHLS/localRemux 暂停约695.282秒：关闭→PGS7 成功提交并显示灰中文/金英文，同画面重开菜单却勾“关闭字幕”；随后 ASS5 已实际显示白双语，重开菜单才勾PGS7。新鲜 replacement_committed 与准备日志确认真实选轨，菜单落后一次；原截图/XML/诊断保留。前一助手关闭菜单只按 name 匹配“取消”，实际 label为取消，采集因别名守卫失败，未算App失败；之后正确触摸重新取菜单，正常UI恢复4/off并保存695.2816686666666。

第一版尝试在共享界面 `.onChange(request.id)` 再同步。本轮1ed0包构建/322测试/15预检均通过、两机已安装，但 iPad 再次选PGS7后 requestSubtitleID=7/mode=embedded，菜单仍off，真机断言拒绝。该包该cue没有可见PGS文字，不冒充内容通过。失败包身份、原图、日志及普通off恢复首读723.192169355另存，延后结果保留；实际值以私有原始回读为准。该观察器已撤回，**不能称第一版修复成功**。

`.id(plan.id)` 修正菜单后，ece5包真机进一步发现：暂停关闭字幕的候选781.530004秒略早于请求781.53125291秒，冷续播保存门槛未确认目标时钟，普通退出首读及后续回读仍是旧ASS5开启，不能算成功。PGS/ASS/off菜单均正确，ASS自然t10确有白双语；该版本失败原图、诊断、包、偏好和测试全保留。

最终在 `GreenfieldVideoPlayerView.swift` 的 AV SharedBuiltInPlayerView 增加 `.id(plan.id)` 与说明，和既有 KS 分支相同：新提交方案重建其控制界面/选轨/字幕模型状态，旧方案的准备结束后菜单从新方案初始化，已观察到的旧选项滞后不再出现。准备失败没有新方案，保留此前 `.onChange(sourceTrackChangeInProgress)` 的回滚逻辑；**实际准备失败负例本轮未触发，仍未独立验收**。没有放宽字幕、解码、对齐、deadline或缓冲门槛；无片名特判。第一版 SharedBuiltInPlayerView 改动已精确撤回，最终新增还包括 connectAVControls：仅已通过候选decoded/alignment/reserve门槛且ready的附着prewarmed item，用其有限非负实际clock初始化保存门槛；非prewarmed/cold路线仍按请求起点，零时钟/未完成seek保护原样，不放宽候选提交。暂停量化点无需继续播放即可保存，真机退出4秒与15秒分别保留。

## 最新包与每台门槛

- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS dirty diff SHA-256 `9fe56dbe9b04ea7aef6fed7c563febf006fab70e1621b0a20224ed7a749d188f`；正常 Debug/-Onone，构建 `2026-10-12T09:18:40.642495+08:00`，普通启动 env={}/args=[]。
- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-085149/Nastart-AV-Menu-Clock-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-085149/Nastart-AV-Menu-Clock-Normal-Debug.ipa`。主 SHA `9f952eeb1f181b832e63fd0ff75faf6e9ee429ca6769cf744d1746851338d8da`、Debug `1a354fb84af5790511638f1a135956d2af9a6a9babe24638cf30edc60ffe4d1e`、KS `a981b6ce9643d58ef5cbdd81b3f1aa2c1878e6c4e590ee41f1afd510bc3da83c`。
- 173输入逐SHA/mtime、三二进制/IPA、29库独立签名、deep/strict和链接核验；最终源码/输入/二进制签名及 diff check 重核。profile UTC `2026-10-17T22:23:40`。最终实际322测试/2跳过/0失败和15preflight；1ed0及ece5也各执行一次，版本独立留证，不把三个版本测试结果混写。
- 开工现场USB13=iPhone14,5/iOS16.3.1、Pad=iPad12,1/iOS18.3.1，名称/UDID匹配现场目标、解锁与正式有效WDA ready；每次安装/媒体入口均补读现场身份，私有身份不复制进仓库。
- 最终最新包13/Pad于09:20–09:21保留数据覆盖，25/16非诊断偏好安装前后完全一致，实际普通首页已看。原575947、被否定1ed0、菜单正确但保存失败ece5与最终9fe5安装门槛分别保存；没有卸载、写偏好、清凭据、重装WDA、更改系统/配对或Tailscale/Shadowrocket/设备网络。18无本轮安装。

## 真机结果与边界

| 设备/路径 | 最新 9fe5 实际结果 | 未覆盖 |
| --- | --- | --- |
| iPad S03 设备文件 / AV | 普通冷续播后确认AV路线；此前ece5退出未保存off，因此本次冷续播实际ASS5→暂停选PGS7→ASS5→关闭，各自等待新鲜commit，重新打开菜单逐次实际勾选7/5/off，XML value和原图均核；PGS/ASS暂停13:45均无可见cue，不算内容通过；ASS自然t10确有白双语，3/10/30实际原图已看，普通退出恢复原4/off | 非Jellyfin/外置/所有PGS cue或失败准备验收 |
| iPhone13 S03 设备文件 / KS | 真实菜单几何选PGS7，当前菜单勾PGS而非ASS；自然3/10/30和私有已保存7已核，普通UI恢复原ASS5并退出；4秒首读仍PGS7、约38.1秒后再次只读ASS5已核，首读断言失败保留，不冒充即时持久化通过 | 非AV/蜂窝/完整格式或音画 |
| 两机 S01 设备文件/Jellyfin | 最新源/包/收据、现场身份、普通env/args逐次核对；四入口串行普通30秒、真实3/10/30原图及正常退出/持久化证据保留 | 非同条件首帧排名、全SUB/AUD/连续流畅或MTP |

Pad 最新最终S03字段 `{'positionSeconds': 858.7066706666667, 'audioTrackID': 4, 'subtitleTrackID': None, 'subtitlesDisabled': True}`；13 `{'positionSeconds': 533.844, 'audioTrackID': 4, 'subtitleTrackID': 5, 'subtitlesDisabled': False}`。实际commit候选字段与请求/返回窗口保存在脱敏JSON；内部 decoded/aligned/遥测不是实际显示响应。稀疏截图也不能用于帧时间/FPS/流畅PASS。没有新增竞品正式配对，Lenna仍为Pad/13主对照。

最终普通重启、实际稳定首页/DS918+ NAS正常/播放器关闭已看，WDA idle10/animation2恢复。24（13）/15（Pad）非书签偏好与开工基线一致；书签自然更新数量和末次延后保存差异见JSON，原值只在私有目录，不写回恢复。前后崩溃清单basename规范化比较，两机新增均0；累计旧报告不删除。首页其他服务警告/未知不算全面在线验收。本轮13仍Wi-Fi。

## 下一步

已确认并修正 AV 成功换流菜单滞后；保留真实失败准备回滚负例、外置文本与burn-in隔离、S03 Jellyfin/13 AV、S19 PGS/S11 TrueHD/S18 FLAC和其他代表族。MTP、完整字幕/动画/音频/HDR、显示帧时间及Lenna/DS One同条件比较未完成。原475/119、供流/read/callback/HLS、蜂窝/18无线原生隧道、全部PX-01～21/UX-01～06/CB/L2/L3/Main未验收状态均保留，不把本批局部正确性当整体播放或发布通过。

脱敏证据：[本轮JSON](../../../testing/results/2026-10/USB-AV-TRACK-MENU-20261012.json)；完整冻结助手/包/设备身份/偏好/凭据/媒体地址/截图/XML/日志仅在本机私有目录 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-continuation-085149`。继续前先执行最新安装包门槛。
