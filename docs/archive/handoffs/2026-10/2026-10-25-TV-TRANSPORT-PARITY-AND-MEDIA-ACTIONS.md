# TV播放控制与三端媒体动作一致性

2026-10-25 11:20。用户确认字幕仅在系统菜单打开时上移，要求三端控制/设置/高亮尽量一致，继续与从头播放同款；18外出暂缓安装，当前13/新Pad有线、TV无线。28项/114格保持开放。

## 接受实现及边界

- 三端实际编译移动AppTheme.swift中的PlaybackControlDesign：15秒步长、0.5/0.75/1/1.25/1.5/2倍速及图标；NastartPlaybackButtonStyle共用圆形/白边控制，TV仅适配焦点强调色；NastartMediaActionButtonStyle供继续与从头播放同款按钮，移动54点/TV56点。TV详情两按钮同形同尺寸已实看。
- TV Jellyfin保留TVPlaybackSession/AVPlayer选流、续播及服务端上报；TVNativePlayer改固定TVAVVideoSurface/AVPlayerLayer＋应用控制栏，上方关闭/标题/静音/更多，下方进度/后退/播放/前进/音轨/字幕/设置，按移动信息层级。onExit先关面板，再finish→owning playback=nil/stop；不再调用系统播放器菜单。
- TVPlayerControlsModel持有AV观察、有限seek、倍速/静音和当前AVMediaSelectionGroup；暂停改倍速不自动播放，detach后不能操作旧player。连续seek按pendingSeek累加、seekGeneration隔离旧完成回调；结束后重新读实际时钟。只修控制，不改解码/Range/缓冲/40秒、原20Mbps H2641080配置或NAS。
- 仍缺移动完整source-track目录/重协商，当前单Unknown音轨/字幕不能当全目录；TV文件入口仍既有KSVideoPlayerView。完整Intent/Plan/Route与会话未共享；不称三端全功能已一致。

## 真机与测试证据

TV最新普通Debug 11:14:49保留数据覆盖，510输入/27 Mach-O逐个及deep签名、目标profile、原AppID/Keychain组核过，主SHA `650e4ee223f5a10f5b4bf1cfdab505a962b923909d5f32bf7f0499ddde265c30`。本轮37逻辑/4严格无媒体UI通过；非Release/完整媒体验收。

11:17:22–11:18:56 S01/Jellyfin正常空环境/空参数，一次实际播放：3/10秒原生出画；暂停后连续11次回退15秒，13:47→11:02，与165秒目标一致；不是只看预设目标，settled UI及后续实际画面均留存。随后恢复短播至11:05可见对白，暂停同cue，在菜单打开前/打开时/关闭后三张原生像素图，字幕OCR归一化bbox均x=.398256,y=.072222,w=.203488,h=.056977（Vision左下原点），前/开图实看同一句对白位置/尺寸完全一致。该场景菜单上移未复现，可接受此cue局部修复；完整字幕样式/格式/换轨仍未验。音轨/字幕面板可打开和返回，真实切轨/声音未听，不据勾选判完整通过。

本轮普通返回：Menu关设置/音轨/字幕面板；再Menu回详情，停3秒仍详情，再Menu回搜索且同PID，实际末图已核。前一11:00纯SwiftUI窗亦有限稳定返回；保留此前旧实现/工具干扰失败，不外推所有样本/子页已修。3/10秒用DVT截图后等8秒再交互，后续WDA像素图避免系统“已截屏”提示干扰；干扰原因仍是推断，未证明全部旧失败均由工具造成。

## 失败、回退与收尾

第一/二版焦点onExit窗在截图后Menu不返回，已留存并停止自有媒体。局部UIKit responder实验首Menu直接关整个player，原夹具只查面板消失不足，已更正accepted=false并完整移除host。现严格UI要求首Menu面板消失且播放器仍在，第二Menu才关闭。DEBUG最多64行事件/焦点/面板/单调时钟trace无账号端点标题，不当Release能力。

11:00旧版本28次回退只退18次（18:04→13:34）保留失败；本轮pending目标修正后11次165秒成立，不据此宣称所有速率/格式和网络下连续seek完成。

11:19:27原WDA 50/10/2设置fresh session恢复并GET核对；11:19:31自有Runner实际核停；11:19:28正常空环境重开，3/10首页实图留存；11:19:42原10偏好全同、510源输入0漂移。无蜂窝/网络/VPN/NAS设置修改，无后台工作承诺。

## 移动设备与接续

13于10:16:49、新Pad于10:46:25保留数据安装同一普通移动包，570广义输入/30签名，主SHA `d1e2aed691409851d541e98acb5b745c2079a109d09b8341e5b655f201fe07d8`；后来只有TV源码漂移，不参与移动编译。13正常首页/我的已看；新Pad iPad15,7/A16/26.6 USB现场核，正常NAS/四根页已看，非诊断偏好保留；10:43确认旧设备Runner不在，前批设备清理阻塞解除，新Runner10:59:07已停且原设置GET核过。旧内存设置无法倒读，不追认旧轮GET。

13既有未知Runner不启停/不改设置；11:22–11:23 S01/JF 3/10/30实际不同画面、详情同款按钮/控制布局已实看，普通回详情/正常首页恢复，其他偏好只自然播放/诊断变化。11:27–11:28新Pad同S01/JF不同电影片段/普通回详情已核，原生采样呈桌面浮窗式视频、实际控制栏未出现，不把隐藏AX当全屏UI通过；这是新增待查呈现边界。随后原WDA设置GET恢复、自有Runner实际停、正常App重开。18随用户外出、最新共享包未装；DSM实际自动LAN旧问题按用户要求暂缓。免费签名无CloudKit，真实同步未接通。

私有根由`/tmp/nastart-tv-unified-transport-evidence`指向；当前TV由`/tmp/nastart-tv-unified-current-evidence`指向pending-seek，早期scoped-responder/swiftui-controls均历史。移动当前包focused-exit/mobile，Pad现场ipad-reconnected，原始UDID/端点/凭据/偏好/包/日志/图仅仓库外私有区。[安全结果](../../../testing/results/2026-10/2026-10-25-tv-transport-parity-and-media-actions.json)。
