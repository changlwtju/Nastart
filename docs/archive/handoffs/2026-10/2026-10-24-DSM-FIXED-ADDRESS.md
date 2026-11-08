# DSM固定地址及最新包更新

2026-10-24 10:05。用户要求iPhone18实际DSM始终保持原域名＋端口，不能在覆盖安装后自动变内网IP。接[地址核对与采集器修正](2026-10-24-HANDOFF-OUTPUT-AND-DSM-ROUTES.md)，[本批安全结果](../../../testing/results/2026-10/2026-10-24-dsm-fixed-address.json)，当前现场见[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。私有`/tmp/nastart-dsm-fixed-address-evidence`与全局最新完整包`/tmp/nastart-candidate-device-lab-evidence`现同根；prior/package-before-fix接09:23包及实测，不把它当09:48媒体回归。

## 原因与实现

当前自动恢复会在已配置域名/LAN端点中竞速无凭据元数据，再对选中地址发认证；保存的用户输入地址不改，但实际session可选LAN，DSM卡片又来自`session.baseURL`。本批13原生表单实际仍域名＋端口，但09:51两条DSM登录诊断target为脱敏RFC1918 IPv4/HTTP/显式端口，印证“保存域名、实际内网”可并存。输入、Keychain配置、实际会话和媒体请求须分别核对。既有session在前台刷新仍沿原地址，不能声称Wi-Fi→蜂窝自动迁移已完成；Jellyfin认证外网回退是独立路线。

新增连接表单“始终使用此地址”，中英说明明确DSM只连接上方地址，不可达时提示失败。`StoredNASCredential.usesOnlyConfiguredAddress`序列化保存，旧记录缺字段默认false，表单记忆同步保持；手动首次认证本就只用输入地址。恢复开启时根据`baseURLString`重新构建单一端点，忽略历史LAN/lastKnownRoute的地址替换；失败不发现LAN后再认证。`finishDSMConnection`保留该标记，即使发现可用LAN供可选媒体路线使用，再次恢复仍只认证配置地址。未按设备型号或域名硬编码，13/Pad旧自动策略保持。可选视频LAN选路、其他服务URL和用户手动覆盖独立，不把DSM固定地址说成全部视频禁用内网。

源码映射：`Core/Stores/AppStateStores.swift`存储/恢复/保存；`Features/Launchpad/LaunchpadConnectionViews.swift`开关/记忆/连接；中英Localizable；`NonPlaybackPolicyTests.swift`新增3例。未增加启动环境变量、清凭据、改NAS/VPN/网络、改主自动回退/Range/缓冲。

## 验证与正常包

19定向XCTest正式成功/exit0：3新增覆盖旧数据兼容与序列化、带历史LAN且lastKnownRoute=LAN的两次真实模拟HTTP恢复均只GET/POST域名、域名连接失败不发现/认证LAN；15旧连接隔离/认证失败/取消/代次/竞速用例及1实际解码输出接手/后续帧回归通过。模拟HTTP只用内建URLProtocol fixture，无真实账户/NAS请求；不替代18实际会话或蜂窝迁移验收。15预检和普通真机构建通过，测试/构建AC与自有保活起中末核对并停止。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty；174输入、普通Debug/-Onone/Xcode27，构建2026-10-24 09:48:23。iOS diff SHA `9b99045c40b459fa2788aa3a3fe08cc681812390a6d42dc59a327608bf06ba81`，IPA SHA `f972d6ad78aa0c1d687079e982506024f68448fc874d2f1d56dfd1f0b0c561bc`。二进制：Nastart `26fff4ab034e0833fcc56e52a130ec96ba8ccc3a33df7859bd4d2190bcc43524`；Debug dylib `ab88292957d556b1fbdfa8090e947c3fd87e7f83e77e600d7e5baeb2cf33120b`；KSPlayer `7091aad71bb399c23e285419afbe1cd055eb242cb5c6e4651a4fff7a4b181a4c`。29库逐个/deep签名、profile目标/期限、IPA CRC与二进制一致及链接已核；profile2026-10-24 22:23:57UTC到期，后续仍现场核有效期。

## 逐台结果与收尾

- 13现场型号iPhone14,5/iOS16.3.1/名称/UDID/USB私核，09:50:36保留数据覆盖，25非诊断偏好安装前后全同；09:51空环境/空参数NAS正常首页原生图，09:53实际连接表单域名/端口和新开关可见且Off，0编辑/切换/连接/播放；取消回正常NAS首页，偏好全同。该表单来自真实Keychain优先加载/既有记忆，未导出Keychain原始凭据；不因看见输入地址便声称actual session是域名。10:00:27源包/自身回执/USB、36书签键轨道/其他24项/完整偏好两读稳定、changedBookmarkFields空，App状态1/1与WDA设置auto10/2。末原生截图全黑保留；只发一次Home后原生实际为锁屏/Wi-Fi图标/无PiP、WDA仍locked=true，非App播放器黑屏；不冒称已解锁或末主屏，未反复唤醒/改自动锁定。已有非本批13WDA保留。
- Pad现场iPad12,1/iOS18.3.1/名称/UDID/USB私核，10:00:48保留数据覆盖，18非诊断偏好全同；复用已有有效签名Runner原生XCTest启动，未重建/重装WDA，实际空环境NAS首页原生RSD图已看，其他服务未知不说全健康。自有App/Runner结束；10:01:06源包/回执/USB、29键轨道/其他17项/完整偏好两读稳定、changedBookmarkFields空，native App0/Runner0、原生桌面Wi-Fi/无PiP。安装后/Runner前的原生图事后审阅为桌面，不改写成开始前已由模型审阅。
- 18新浏览2广播/规范同目标0，针对同一配对实例当前解析再次ValueError，0备份/上传/安装/启动。09:48最新包未装、固定地址未在18启用/实际验收；只确认历史00:00包安装。原一次解锁家庭Wi-Fi请求仍待反馈，不重复催促/扫旧IP/重配/改设置。无线可达后先备份，再保留数据安装本批或届时最新包，开启固定原域名并实核session/重启保持；不能用当前13表单代替18验收。

本批0媒体播放/0蜂窝任务；因此不能继承09:23/08:37旧格式或S19候选为09:48回归。所有自有安装、采集、Runner、保活均停止，本私有根活动进程0，不建周期任务。28开放及76格完整状态保持，前批原流多次转圈、候选PGS底行与系统横条重叠、普通自然自动/真实失败新协商、完整音画/PiP/弱蜂窝和竞品未关闭。

## 下一步

18服务恢复后完成最新包与固定域名实际启用，现场记录输入/Keychain配置与session及媒体路线，不能因安装成功便声称网络策略已验。独立主线继续候选PGS底行重叠/自动失败协商；13现锁屏不重复催促，可先分析本地原图/源码，不以旧包截图关闭新包结果。蜂窝恢复约束继续遵守。

## 接续：既有字幕图与承载方式离线核对

本批随后实际重看09:23旧包S19原流候选前及候选45秒两张原生图：原流英文在横条上方，候选英文底行被横条盖住；两张同一Debug根页面均有系统横条。源码`PlaybackLabPlayerView.player`经NavigationStack直接嵌入播放器，普通全屏经`GreenfieldPlaybackPresenter`使用`GreenfieldPlaybackHostingController.prefersHomeIndicatorAutoHidden=true`。因此已定位诊断与普通承载差异，尚未现场证明普通页面同cue通过，也不能把服务器PGS Encode画布位置问题全归因横条。私有安全记录`pgs-presentation-review-safe.json`保存两图SHA及源码SHA，原图未复制仓库。下一候选验证先统一普通全屏承载，再实核同源同轨cue及底部，不能通过修改文本字幕样式冒充烧录字幕修复。本接续0新设备/媒体/蜂窝/源码操作，09:48包身份保持。
