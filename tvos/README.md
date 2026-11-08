# Nastart for Apple TV

原生 tvOS 工程：[NastartTV.xcodeproj](NastartTV/NastartTV.xcodeproj)，最低 tvOS16。目标为尽可能与 iPhone/iPad 功能一致；当前仍是逐步迁移阶段，完整对照及优先顺序见[功能对照](../docs/project/APPLE-TV-FUNCTION-PARITY.md)。未实现不能当作平台无法实现。

## 当前实现与边界

已接入 DSM/Jellyfin 双入口（默认DSM）、独立电视 Keychain 账号保存、DSM 两步验证码、固定填写地址的接口认证、设备CPU/内存概览与刷新、File Station 分页目录/已加载目录筛选/文件大小、共享KSPlayer/KSMEPlayer/FFmpeg文件播放与本机断点。加入沿用移动端 NAS 标识的正式 tvOS 图标和 Top Shelf 资源。DSM 接口路径及版本由 API Info 发现，密码/OTP置于POST body；SID仅在媒体文件URL中按File Station要求携带。普通API跨源重定向会拒绝，证书保持系统校验，不自动复制手机凭据、不自动改用发现的LAN地址。新增容器/套件/反代只读服务发现，公布端口关联与无DSM凭据的Jellyfin公共探测；始终保留独立Jellyfin入口。

保留 Jellyfin 地址及账号登录、媒体库/目录/剧集浏览、搜索与分页、详情、从头/断点播放、系统遥控器控制、进度/退出上报及本会话编码清理。支持的 MP4 原流按服务端能力播放，其他格式协商 HLS；当前兼容编码预算20Mbps/H264 1920×1080。文件播放已接共享KSPlayer，仍未接移动端Range代理，不代表完整格式/音字幕能力已迁移。Jellyfin新增Audio协商/播放端点、音乐目录与快速连接授权；DSM和JF账号分开保持，TV换取独立token，授权可取消/有时限。复杂字幕、听音/无损音频、HDR/杜比实际输出、多NAS及完整服务/任务管理继续验收和迁移。

2026-10-24：真实 Apple TV4K第三代/tvOS18.2开发连接已就绪，签名构建与保留数据覆盖安装成功；普通空环境实际截图已确认 DSM/Jellyfin 新入口。20项逻辑/协议测试、1项普通启动UI测试通过（最后音频展示修改另经真机构建）。正式桌面图标、DSM首页/CPU/内存、共享目录和运行中容器已有真实图；核心播放批中《碟中谍3》54GB MKV有10/30秒不同原生画面，第二窗两次遥控返回正常退出，首次自动化完成按钮失败+主动停止保留。听音/字幕/HDR与JF播放不能由这些短窗替代，详[本批](../docs/archive/handoffs/2026-10/2026-10-24-TV-CORE-PLAYBACK-AND-SERVICES.md)。

## 三端界面迁移（2026-10-24）

四Tab为启动台/设备/事项/我的；清流/栈列/流光及统一字体、石墨/琥珀样式已接入。Docker默认显示、分组/单卡显示管理、服务实际详情、六项设备资源、我的设置与本机事项已实现；JF入口保留在启动台/服务详情，不再单列Tab。JF采用AVPlayerViewController，增倍速/画面比例/跳转/播放信息等，默认倍速保存在本机，设置入口仅放在实际播放器。事项无自动监控/通知/跨端同步；其他Web服务写操作、完整服务管理/字幕/输出尚未完成。

最新普通27签名包保留登录安装，20逻辑+1UI通过；主题与实际子页、真实海报已有实机证据，更多菜单每个动作、音频/长播待验。详[本批记录](../docs/archive/handoffs/2026-10/2026-10-24-TV-UI-PARITY-AND-PLAYBACK.md)，不把短窗当全功能平移验收。

## 构建与测试

```sh
xcodebuild test -project tvos/NastartTV/NastartTV.xcodeproj \
  -scheme NastartTV -configuration Debug \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),arch=arm64' \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/Nastart-TV" \
  -clonedSourcePackagesDirPath "$HOME/Library/Caches/Nastart/SourcePackages-20261017" \
  -onlyUsePackageVersionsFromResolvedFile \
  -parallel-testing-enabled NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
```

产物与xcresult放仓库外；真机按[安装准备](../docs/development/APPLE-TV-PREPARATION.md)核对真实型号/系统/身份/当前源包和有效tvOS签名。iPhone安装包与iOS描述文件不适用于TV。

签名校验不能发现漏打动态库。安装前另运行 `python3 scripts/check_tvos_embedded_libraries.py /absolute/path/NastartTV.app`，并正常启动查看真实首页；本批第一包因遗漏KSPlayer嵌入而DYLD启动失败，已修正工程Embed Frameworks并以失败/修正包做门禁回归。

## 外观及媒体布局接续（2026-10-24）

外观支持系统/浅色/深色、海报3/4/5列默认4列；CPU/内存/入口共用38图标、76底座、160等高卡片。网络页支持Menu与页内返回；我的统一连接管理集中NAS和影音授权，顶层不展示断开按钮或倍速设置。Jellyfin首页增加当前用户继续观看及最近添加；详情增加背景、评分类型时长、圆形演员/人物资料及相似影片，缺数据时隐藏。固定2:3海报裁切、紧凑标题年份、接近末尾自动加载后续60项，取消手动“加载更多”。参考网易爆米花的层级与留白，保留Nastart四Tab和主题。

最新包22逻辑+1UI通过、已保留登录覆盖并正常空环境启动；真实布局/分页结果与竞品失败边界见[本批记录](../docs/archive/handoffs/2026-10/2026-10-24-TV-APPEARANCE-POSTERS-AND-COMPETITORS.md)。不继承旧包播放结论。

最新主题/导航包24逻辑+1UI通过。三主题实际布局已扩展到首页上半部：清流双列、栈列整行摘要与等宽三指标/双入口、流光渐层材质。剧集正式海报优先，图片1000/92；帮助分层卡片和全子页返回接续核对。服务仅有可用动作才可进入：JF原生媒体库、反代地址手机二维码，无动作静态状态卡片；二维码不携带DSM登录凭据。


2026-10-24全应用核查以[三端功能对照](../docs/project/APPLE-TV-FUNCTION-PARITY.md)为基准：手机/Pad共用四根View，TV仍独立业务实现，不能宣称改一端自动同步三端。新增共享TV资源快照用于启动台/资源概览、硬盘/uptime/容量/诊断、维护证书只读/重新发现、隐私、事项四类型/对象/日期/预览和详情，28逻辑+1UI通过；真机预填修正最终验收见本批交接。iCloud/Agent/提醒同步/完整文件与播放策略仍未迁移。

2026-10-24 21:34：[全应用主题与媒体入口](../docs/archive/handoffs/2026-10/2026-10-24-GLOBAL-THEMES-AND-MEDIA-ENTRY.md)已接统一内容画布与卡片，三端入口显示共享目录/当前账号电影统计，Limit=0只读元数据不触发媒体。TV保留用户认可的流光颜色。我的新增iCloud不可用状态页并验证Menu返回；当前免费签名无CloudKit权限、TV同步模型仍缺，未加启用开关或云写入。最新普通Debug真机构建/签名/覆盖及实际检查见结构化结果，不把前包29项或播放窗当最新源码全功能验收。

2026-10-24 22:18：[栈列信息页与返回](../docs/archive/handoffs/2026-10/2026-10-24-STACK-INFORMATION-PAGES.md)新增主题信息行环境，设备/我的在栈列改单列128pt最小行，标题/说明分列，保留38/76图标尺寸；资源表压缩行距并对齐数字。服务目录不再固定栈列，按当前主题采用单/双列；海报/播放器不套信息行。当前源码28逻辑+1启动UI通过，真机设备子页/事项取消/帮助返回等覆盖见该批，不当全功能或播放验收。
