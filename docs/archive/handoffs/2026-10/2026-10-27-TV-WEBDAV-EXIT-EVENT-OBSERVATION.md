# TV WebDAV返回事件观察、回退与无TMDB产品边界

2026-10-27接续[承载与控制](2026-10-27-WEBDAV-PLAYBACK-HOST-AND-CONTROLS.md)。本批只操作客厅TV，手机/Pad/18均未访问。沿HEAD4de732dd645b36671becff992cdef1d0163fd1e4及原dirty，最终399源码输入逐SHA与开工前完整相同，**没有接受新的播放行为修复**。原始设备/签名/包/图/帧/地址和交互日志仅私有证据指针`/tmp/nastart-tv-storage-ui-evidence`下`current-tv-network-exit-batch-private`，安全结果见[JSON](../../../testing/results/2026-10/2026-10-27-tv-webdav-exit-event-observation.json)。

## 事件与真实焦点证据

沿既有TVPlaybackInteractionTrace新增临时DEBUG-only网络入口host/焦点/exit/PlayPause记录，最多64条，仅事件、状态、单调时钟，无账号、地址、片名。观察包dd58af…普通Debug fresh核签保留数据覆盖及普通首页后，原149库精确索引/原登录S01 WebDAV短窗独立DVT3/10出画。3次Menu均请求返回，但trace只host.appear与focus.play，无surface/container exit、host.exit、close或disappear；故不能说关闭回调已执行却失效。PlayPause也没有进入SwiftUI的观察事件，但随后focus变controller，未由这点单独判断媒体系统具体消费方。失败原生finally主动停，非App崩溃或普通返回。

第二观察包94d82e…增加仅DEBUG、最多30秒原生UIFocusSystem只读采样。实际渲染MetalPlayView处活动keyWindow=true，控制隐藏时系统focusedItem为UIKitFocusableViewResponderItem（不是UIView，父UIView链为空不等于没有焦点），控制显示后系统焦点为TVSlide，链到UIHostingView/TransitionView/Window。三次Menu仍无exit处理器事件。证据说明不能仅将问题归于“没有焦点”；没有给opaque focus item做未经观测的组件归属断言。

对照旧[10-25事件定位](2026-10-25-TV-EXIT-EVENT-PROBE.md)与[两轮失败回退](2026-10-25-TV-PLAYER-EXIT-INVESTIGATION.md)：旧DSM两真实文件窗口的surface handler通过只属当时入口/包，不扩为新WebDAV嵌套展示；不重复接受旧callback、直接绑定或window全局手势方案。

## 有信息依据的候选与回退

一个新候选把已有surface.onExitCommand从键盘/方向处理之前移至最终onMoveCommand之后，退出分支/解码/Range/认证保持。4c4841…普通Debug fresh覆盖/普通首页和同源短窗后仍无exit事件、无普通返回；3/10及返回后原生图已逐张看过，播放器仍在，finally主动停。故候选被拒绝，不继续同组顺序/按钮参数猜测。

临时观察/采样代码及候选全部撤回，源码399输入与开工前全同，保留所有原dirty。普通Debug回退构建通过，最终主SHA `f14dbc7e1301ed754fa8b7cc0960b3a4f14c69d67acfcb61165f5c14f81a0bc3`，调试库 `a1b564ae713d640c5b7d23fcc6c430bbeeb247f1e2a431ef78283c11d6dbb866`，构建2026-10-27T14:59:09.083137+08:00，27 Mach-O逐项/deep签名与描述文件目标设备/有效期/嵌入依赖核通过。客厅AppleTV14,1/18.2 LAN每轮fresh身份核后保留数据覆盖，最终2026-10-27T14:59:55.983582+08:00 Complete与空参数/环境原生3/10秒正常首页。最终没有重测实播，候选失败不混归回退包；原131模块测试仅既有源码基线、本批未重复，不声称新增测试或Release验证。

自有TV会话各轮设置readback恢复/DELETE200，owned Runner监督进程结束/原生最终清单无Runner；普通App在。自有交互文件只在设备私有Caches，已保存本机证据并删除精确单文件。原149完整索引JSON前后同，15非诊断偏好同。没有NAS写入、TMM刮削、蜂窝/NAS/VPN/系统/凭据修改，无自有后台媒体或采集。移动及18继续沿上一批包/证据，不称本批新回归。

## 无TMDB商业授权时的产品建议（不是新授权或已交付能力）

用户询问这是否让WebDAV等媒体库失去意义。本轮建议保留连接、文件解析/分类、剧名→季→集、直接播放和三端体验作为核心；用户已有NFO/封面可只读导入，缺资料时文件名识别与待匹配展示仍可用，但不能承诺无资料也完整自动海报/演员/简介。已有tinyMediaManager产物可兼容导入；不为此自动运行Docker、写回NAS或替用户申请/购买服务。

[TMDB官方FAQ](https://developer.themoviedb.org/docs/faq)说明商业用途需联系商业授权；[API条款](https://www.themoviedb.org/api-terms-of-use?language=en-CA)要求单独书面商业协议。Docker转接不能自动成为许可豁免；本地文件格式兼容也不等于对第三方内容获得再分发权。[Jellyfin本地NFO](https://jellyfin.org/docs/general/server/metadata/nfo/)和[tinyMediaManager格式](https://www.tinymediamanager.org/docs/tvshows/nfo-formats)说明本地资料交换是现实路线。其他在线来源须逐项核商用条款，当前未选/购买/接入新商用来源，也没有调用TMDB。建议是先完成稳定只读库/播放，再评估在线补全的许可和成本，未把用户的产品问题当取消现有开发。

## 下一步

TV问题已收窄到本窗处理器之前，不能声明系统底层原因已知。下轮先做有明确差异的无媒体嵌套呈现/已有设备文件入口对照，核真实focus environment与事件接收范围；不要只重复3次Menu/改样式、onExit顺序或全局手势。随后回到跨端pause/seek/音字幕/PiP、FTP生产适配/FTPS reuse与SMB严格范围。30项14/5/11、114格无新P，所有历史失败保持。
