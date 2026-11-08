# WebDAV播放承载、海报投影与真机控制

2026-10-27接续[首切片](2026-10-27-WEBDAV-DIRECT-PLAYBACK.md)。用户授权留家Pad/13/客厅TV空闲独占，18离家hands off；本批未访问18、未改NAS/VPN/凭据，未用蜂窝。原有dirty保留，HEAD4de732dd645b36671becff992cdef1d0163fd1e4。原始地址/文件名/账号/索引/截图/栈/安装包仅本机私有区，指针`/tmp/nastart-tv-storage-ui-evidence`下`current-webdav-controls-batch-private`。

## 问题、接受改动与边界

旧包真实NAS可以出画面，但播放中WDA source常25秒超时。保留四种旧包工具窗：原生观察后tap约8.56秒、关闭quiescence仍8.43秒、单W3C动作约3.96秒、一次串行动作约12.39秒均未核实普通退出；失效观察不补发盲点，失败均主动停自有App。请求发送成功不是控制有效，不能统称产品崩溃或把WDA等待当已确定根因。

移动WebDAV原先直接嵌入GreenfieldVideoPlayerView，现由`LaunchpadLayoutViews.swift → NetworkLibraryPlayerPresentation → greenfieldPlaybackCover`走与设备文件/Jellyfin一致的保留UIKit全屏承载器；一次呈现，关闭请求清空后关闭来源准备页。`NetworkLibraryPlaybackView → NetworkPlaybackOwner`持有读取桥，明确关闭或最终owner释放时撤销，去掉被全屏覆盖即onDisappear断流的行为。PiP/方向沿既有承载器，但本批没有PiP验收。首承载候选c621c1…仍在source25秒超时，未把这个改动单独当根因修复。

随后取得目标App两次独立DVT栈：播放前查询窗31线程、source进行中27线程；主队列均在`NetworkLibraryPosterWall.body → MediaCatalog.items`，分别落于`MediaPresentation.groups/isSupplement`及`SeriesLayout.folder/DAVPath.isWithin`。以实际安装dylib UUID匹配再atos符号化，其他进程栈丢弃，采集已停止。证实底页重绘重复在主线程分组；不由两次栈推断所有卡顿、网络或首帧原因。

`MediaCatalogCache` actor按完整NetworkLibrary快照（含索引版本提示、本机纠错、所选根）后台计算并复用，移除库释放缓存；`NetworkLibrariesModel.refresh`以generation防止旧刷新覆盖，结果与库一起交主线程。海报墙、剧/季页只取投影，详情复用已算movie group；分类、季集和原索引语义保持。新增两项测试覆盖本机纠错→文件版本变化→失效、移除/重加空库与独立选根，防止显示旧资料。没有远端写入。

TV另复现返回仍在播放、显式完成按钮无法聚焦（WDA400），各窗由原生finally主动停App。来源页NetworkPageStyle的plain样式传播到全屏；`TVNetworkLibraryPlayer`新增显式bordered按钮、FocusState及初始焦点，保留既有KS解码/stop路径。该候选仍Menu失败、doneFocused仍false，故已撤回，未接受为修复。后显式Done复核在播放前连接被拒，fresh RSD证实自有Runner PID不在，未发媒体，不计为产品Done再次失败。最终恢复接受源码后只做fresh安装/普通基线。

## 构建、测试与每台设备门禁

399冻结输入，最终逐SHA检查；普通Debug移动主SHA `2deb7138f1c247dc083113aeb3ed4d02f8a97a42c38c4c0aa71dc21b1c1879b6`、dylib `1efc6c80d69fd1e5982051fb589394fcfdb99345b7ce7d7e60ae0c2c4192fc21`（2026-10-27T14:23:19.801421+08:00），TV主SHA `984d999dd0643db7ede480da7a9d51b000c29a062c5658a0ad77bac249a814bf`、dylib `463d7551a2dd51e4b6a0bc72ead8cfe11e04672f5f3aab030cef7c909dfece0c`（2026-10-27T14:23:17.991023+08:00）。30/27 Mach-O、profile及IPA核验。TV撤回失败焦点实验后重建双端，虽399源码输入与接受缓存候选完整相同，移动主/调试库及部分嵌入库签名哈希发生变化；没有沿用旧包身份，三机再次fresh覆盖/普通启动，再补移动实播；不借同版本号证明身份。

Pad15,7/26.6 USB：13:48 fresh身份/签名/源码后保留数据覆盖Complete，普通空参数/环境首页；19非诊断安装偏好相同。13/iPhone14,5/16.3.1 USB：13:49同包fresh覆盖Complete/26偏好同/正常首页。TV/AppleTV14,1/18.2 LAN：13:49的ce1c39…属于焦点修复前包；焦点候选e8f749…覆盖/普通首页后Menu仍失败；最终接受包984d999…再次fresh覆盖和普通首页，具体时间见本批结果JSON。18仍07:00旧4e包，私有区同名候选清单不是设备更新。

完整NetworkMedia套件最终直接xctest运行131项0失败，5.318秒；此前测试夹具对let etag赋值的编译失败已修，两个SwiftPM全套150秒守卫超时均留档，不能称两次原命令通过。直接运行同一新编译bundle，未忽略测试。既有UIKit全屏生命周期模拟器测试两次600/420秒在构建/准备阶段超时、未执行测试，均保留；模拟器原Shutdown、最终仍Shutdown。不能用模块测试或普通Debug当Release/完整播放验收。

## 真实WebDAV影片：结果按端分开

Pad原3,408库内精确S01 MKV，原已保存登录/范围/版本绑定。缓存候选第一窗source约2.97秒返回，但脚本错把控件name当label，未退出；第二窗查询过早未观察单击生效，均留图/主动停止。改按实际label和单击手势完成后的原生图观察，最后窗3.154/10.156秒同PID不同实帧，12.72秒控制栏可见，普通完成后16.23/19.88秒回原详情，同PID4539、未主动终止。播放中source3.034秒返回、关闭后1.367秒；仅代表这几个窗口，非帧时间/流畅度或性能评级。

13相同索引S01：独立DVT连接先InvalidService，未开始媒体；改用现有WDA截图与实际activeAppInfo。3.21秒仍缓冲、10.18秒已有画面，控制显现后完成返回原详情，前后真实正PID4761相同、未强停。iOS16原搜索框需向上展开；旧0匹配是工具导航问题，未冒充产品搜索故障。没有独立帧时间、上游网络字段、听音或全音字幕证据。

TV：首窗3.31/10.30/30.30秒不同原生实帧、同PID，Menu后仍是影片且done仍在，失败后主动停；后显式Done点击400亦主动停。工具另有系统TVConferenceRoomDisplay前台、未打开真实键盘导致value无效、脚本语法/进程名Nastart与NastartTV误配；均在播放前纠正/留档，不当播放通过或App崩溃。焦点修复后的结果待本批更新。

## 收尾、限制和下一阶段

已读原索引Pad3,408、13/TV149，完整JSON均同前基线；未添加临时库、未触发TMM或写NAS。移动原WDA10/2/50设置恢复、自有HTTP会话DELETE200、原Runner保留。TV首自有会话/Runner已清，第二焦点回归Runner退出与设置恢复结果见本批JSON；失败媒体由原生finally主动停止。最终Pad/13非诊断偏好19/26均同，TV检查及回归结果另见[结构化结果](../../../testing/results/2026-10/2026-10-27-webdav-playback-host-and-controls.json)。

仍待：pause/seek完成与恢复、完整音轨/字幕/听音、方向/PiP/稳定续播、代表大文件/格式及Release/帧时间。新WebDAV来源只记有限原生层，不沿DSM/Jellyfin格；114矩阵不新增P，30需求14进行中/5待验收/11待开始。FTP生产适配/FTPS reuse、SMB严格选根/协商仍开放，原归档失败保留，不以本批播放器变化交付FTP/SMB。

最终重包：此前13:48/13:49的85cf8fe…结果仅属前包。最新移动2deb7138f1c247dc083113aeb3ed4d02f8a97a42c38c4c0aa71dc21b1c1879b6、TV984d999dd0643db7ede480da7a9d51b000c29a062c5658a0ad77bac249a814bf，源码399输入同，仍重新保留数据覆盖；最新安装/普通启动/补回归的实际时间见结果JSON。第二TV自有Runner在追加Done复核前已不在，最终原生进程清单也确认无Runner；该Runner设置无法通过已失效HTTP会话复核恢复，不声称DELETE成功，已退出Runner的内存设置不当用户偏好改动。第一TV会话设置恢复/DELETE200和自有Runner退出证据保留。

最终重包原生回归已补齐：Pad14:26:28、13 14:26:39、TV14:26:30 fresh覆盖/普通空环境启动；最终移动2deb713…实际NAS窗Pad3.161/10.157秒不同原生帧、12.743显现控制，16.242/19.884回详情同正PID4562，播放source2.647秒/关闭后0.987秒。13 3.232秒缓冲/10.201秒出图，13.903秒关闭后详情同正PID；两窗未主动终止，实际帧已查看。最终3408/149/149完整索引同、19/26/15非诊断偏好同；Pad/13设置恢复/DELETE200、原Runner留，TV最终App在/owned Runner与Mac监督进程均不在，未再启动媒体。第二TV设置HTTP恢复与DELETE不可复核，明确保留。

最终TV状态流程反例：本地KSVideoPlayerView.handleTVExit源码显示先隐藏mask、再恢复.play焦点、最后dismiss；为避免只按一次返回误判，最后同一984d999…普通包再次fresh覆盖/正常首页，原库精确选片。独立原生3.293/10.264/30.497秒不同实帧；每次查询done仍在才继续Menu，共3次，32.345/34.729/36.719秒仍在视频，42.290秒仍非详情；已查看实图，原生finally明确主动停PID3743，无普通退出。这个有界状态流程测试也没有支持“第一次只被控制层消耗即可解释全部问题”的假设，退出事件接收/焦点归属仍待诊断，不再盲调样式。仅私有工具错误曾因复制不存在install-private.json阻止Runner启动、ready超时，在媒体前纠正并留档。

最后第三自有TV会话设置恢复经readback核同、DELETE200，stop标记请求监督进程退出，最终Runner/普通App状态、索引/偏好以结果JSON为准；第二Runner早退导致其HTTP恢复/DELETE不可复核的历史限制保留。
