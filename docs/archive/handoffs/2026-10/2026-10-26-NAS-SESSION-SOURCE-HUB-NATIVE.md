# 当前NAS会话、已有连接复用与来源界面接入

2026-10-26。接续[统一来源方案](../../../architecture/UNIFIED_SOURCE_DISCOVERY_AND_ACCESS.md)。本批将方案首切片接入App，不宣称FTP/SMB或新增媒体服务适配完成。源码HEAD `4de732d`，原dirty保留。

## 实现映射

- `NetworkMedia/FileStation.swift`：共享只读File Station源，从当前会话取得SID；动态发现List/Download API路径，版本2核对，SID仅POST正文；有界响应/超时、拒绝重定向、独占HTTP任务实际取消。当前会话授权的自签名策略仅用于同端点，不另开NAS协议或改变地址。
- `list_share`选共享目录、`getinfo`核逻辑/物理路径、分页列表必须完整；拒绝重复/越层/越根/数量变化/异常offset/未提供总数的普通目录，旧版共享目录无total只接受不足一页。要求real_path与当前父目录、子名对应，NFO另核选根与文件物理后缀。该检查是请求当时的服务器映射，不是NAS原子快照或TOCTOU完全防护。
- 扫描只下载已列出的NFO，不读取视频/封面；复用原有文件名/NFO识别、本机覆盖与原子旧索引保持。File Station响应HTTP200内API错误不能被当成无效NFO吞掉。
- `NetworkNASContext`由移动/TV主工程传当前实际会话地址、账号、源工厂，读取前后校验当前登录身份/代次；退出/切换/后台取消，旧会话不能借新账号读取。File Station来源持久化账号和端点绑定，不保存新SID/密码；旧WebDAV索引及TV v2目录兼容。地址保持与现有DSM会话一致，本批不修旧iPhone18域名路线。
- `LibraryViews`保留AnyView模块边界，入口改“存储与媒体”，增加当前NAS选目录、已有WebDAV凭据再选目录；每个新库仍独立Keychain记录，移除原库不影响新库凭据。共享目录总根不允许一键导入全NAS。现有连接目前仍由库记录提供，尚无独立连接去重/管理模型。
- `NetworkMediaAppearance`接收主工程的实际背景、表面、强调色与command样式；移动用NastartThemeBackground/NastartSurfaceBackground，TV用TVPageBackground/TVTheme及glass材质。最终TV整行plain按钮、明确图文间距与完整点击范围，避免默认胶囊裁切/重叠。首次浅色手机glass、Pad clean、TV glass有限实图检查，不等于所有主题/深色/大字/宽度验收。

## 构建与安装

首轮TV因`scrollContentBackground`不支持失败，限定iOS后双普通Debug构建通过。初版08:24包三机均保留数据安装、普通首页/真实会话列共享目录通过；13完成实际NAS单个影片叶目录1视频/1 NFO并仅本机移除。TV实图见按钮图文重叠，修正后重新构建、冻结/逐项签名/逐台保留数据安装，不能把初版证据当最终包重测。

最终371项本地源码/工程/资源摘要（非完整外部依赖闭包），移动08:35:47主SHA `08765530c7d154e7370b4024ad32ba704663609b5045d0a4306f2a2e2f1dc23a`、30 Mach-O；TV08:35:35主SHA `4c27016f56c32c98bf772c5107070c03e2ef5901d62e692be86ef5b2bff92a5c`、27 Mach-O。另存实际Debug dylib及全部嵌入二进制摘要，TV非系统依赖核验通过；默认空参数/环境。安装路径/时间、设备UDID与完整签名/源码/偏好证据仅本机私有指针`/tmp/nastart-source-hub-native-evidence`。

设备现场：iPhone13/iPhone14,5/iOS16.3.1 USB，iPad/iPad15,7/iPadOS26.6 USB，客厅AppleTV14,1/tvOS18.2 LAN；没有混用同型号tvOS27模拟器。最终三机安装成功，安装前后非诊断偏好均相同。iPhone18当前不可连接，未安装本批，保存域名/凭据不改，不继承旧包验收。

## 测试与失败边界

51项包测试/0失败（原42＋7 File Station场景＋2真实loopback HTTP），覆盖501条全分页、会话POST编码、只读方法、物理路径越界/重复页、异常API路径不带SID、迟到响应会话撤销、NFO API错误/越根、TV目录缓存丢失恢复及旧WebDAV结构。真实传输另验POST会话不进URL、307拒绝、流式体积限制与取消；不是NAS兼容或原生界面测试。最终布局变更仅SwiftUI，逻辑结果来自本批前一构建阶段。

最终三机普通启动、新入口及已有WebDAV连接复用均有实机证据：自有Basic认证夹具首次输入一次账号后选Movies（4视频/2有效NFO），再用保存连接选Nested（1视频），无需密码表单，最后仅本机移除两个自有库。13/Pad另验先移除原库后余库仍可认证重扫，原库内容在建立第二库前后逐字段不变；TV此附加变体未验。共有资料库/Keychain仍按每库隔离，并非共享凭据引用迁移已完成。

保留脚本失败：Pad初次拖动坐标落在模态框外，没把video滚进视野；后续基于实际CollectionView范围处理，不能以滑动请求成功当已位移。Pad WebDAV首次登录触发系统“保存密码？”遮住控件，原脚本误认底层按钮存在即可操作，等待首库超时；选择“以后”不保存自有合成密码，恢复已观察的界面后完整流程通过。一次旧read-index工具仍断言4视频固定夹具，读到空库即失败；改为只读导出、调用处断言，不改App。TV900秒自有采集正常到期、设置GET恢复/Runner停后，一次额外WDA收尾请求连接拒绝，改用原生普通启动/截图，不重启采集或当产品失败。

最终包NAS复核、收尾与公开结果见[结构化记录](../../../testing/results/2026-10/2026-10-26-nas-session-source-hub-native.json)，以实际字段为准。没有媒体播放、蜂窝任务或NAS/VPN配置变化，不作独立网络库播放、FTP、SMB、Emby/Plex/音乐服务、海报/在线刮削/增量/同步验收。原114播放格不变；UX-09进行中，当前30项14进行中/5待验收/11待开始。

下一步先补共享服务候选/身份/可达/授权/客户端能力，接现有媒体入口；继续隔离SMB适配、FTPS/FTP及服务逐项接入。已有NAS选择流程还需大目录、权限失效/切换的完整真机变体，全部主题/大字与TV扫描取消独立验证。用户NAS未装新增媒体服务，不要求安装、不启协议。

最终包复核与收尾：13/Pad/TV安装分别08:36:45/08:36:35/08:36:36完成；最终包三机现有NAS会话列共享目录，无密码输入，目录行数仅表示可访问树中已渲染行，不冒充完整总数。13再次完成真实叶目录1视频/1 NFO/仅本机移除，Pad/TV未做此最终完整变体。三机空索引已取回、所有非诊断偏好与安装前一致，正常NAS首页实图已看；手机/Pad Wi-Fi图标存在，网络/VPN未改。自有Basic服务SIGINT正常停，9文件/3目录内容/mtime/结构0变化、70请求仅PROPFIND和NFO GET；实际NAS未做整库哈希。TV Runner已停/设置GET恢复；13/Pad只删自有HTTP会话、原Runner保留。最终371输入及两包全部Mach-O零漂移。没有周期任务或回合结束后后台工作承诺。

文档检查461份/2684本地链接，缺失0；git diff --check通过。总账30项状态14/5/11核对成立，本轮自有测试进程剩余0。最终设备目录iPhone18仍unavailable，未装本批。
