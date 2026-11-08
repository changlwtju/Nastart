# 2026-10-26 只读 WebDAV 扫描与本地媒体库

用户“继续”接续上一批只读网络媒体库设计。已把共享模块接入手机、平板和电视工程；完整实测闭环目前只有 iPhone13。原始地址、UDID、偏好、安装包、截图、失败报告及调试脚本留仓库外，私有指针 `/tmp/nastart-webdav-index-evidence`。可分享结果见[结构化结果](../../../testing/results/2026-10/2026-10-26-readonly-webdav-library.json)。

## 实际接受实现

共用代码位于 `ios/Nastart/Packages/NetworkMedia`，两个工程链接同一个本地静态包：

| 源码 | 已接行为 |
| --- | --- |
| Models.swift / WebDAV.swift | 规范相对路径及所选目录边界；仅 PROPFIND、Depth:1、具名属性；DAV命名空间/逐条属性状态校验；只接受207完整目录；不跟随跳转；Basic/Digest挑战限同origin，不绕过TLS验证 |
| WebDAV.swift | 每次独立临时会话，响应流4MiB上限、25秒资源预算、单请求取消；拒绝DOCTYPE/ENTITY、重复/越界href、缺少自身目录或资源类型的列表 |
| LibraryIndex.swift | 有界逐层全扫描，最多10万条目、1万目录和相对64层；只索引已知视频扩展名；相同文件名按不同相对路径保留；原子JSON快照只放客户端Application Support |
| LibraryIndex.swift | 完整成功才替换索引；失败/取消不提交半轮；代次拒绝迟到提交；损坏本地库失败关闭、不用空库覆盖；移除只删本机记录 |
| CredentialVault.swift | 独立Keychain条目绑定source UUID与确切规范地址，WhenUnlockedThisDeviceOnly，不同步；索引不存密码，不复用DSM SID或竞品凭据 |
| LibraryViews.swift | 网络库列表→独立连接表单→目录浏览/显式选根→扫描计数/取消/重扫→文件名列表；暂显示“资料待匹配”，没有伪造海报、刮削或播放按钮 |
| LaunchpadLayoutViews.swift / TVNASViews.swift | 新增网络媒体库入口，现有设备文件/Jellyfin入口保留；公开AnyView工厂将共享界面的属性包装存储留在模块内部 |

当前是完整快照扫描，尚非增量索引。服务器通过同一路径暴露的别名/链接真实落点仍由服务器决定；客户端只能约束可观察href和请求路径，不能证明服务器内部文件系统快照或链接语义。SMB、NFO/图片读取、provider刮削、纠错、网络库播放和跨端同步均未交付。播放传输及现有AV/KS链路未改，不据此更新播放路线为已接入。

## 构建身份和设备

源码HEAD `4de732d`，保留原有及本批dirty/untracked。普通Debug，空启动参数/环境。02:25:10完成，冻结本地源码/工程/资源362项，构建前后和收尾0漂移；口径不同于历史570项，不冒充完整依赖闭包。签名逐Mach-O校验，包路径与全部二进制SHA仅在私有清单，主SHA列于结构化结果。

- 移动包主SHA `1a5389164aa6588b07bb024de316dd2d8ee22db7f3b4d05080d6d2a2f8175175`，30个签名Mach-O。
- TV包主SHA `b3850247ff0c3852411b81af9bf496a519bc3ce6c7abab183a64b7f7a066666f`，27个签名Mach-O。
- iPhone13，iPhone14,5/iOS16.3.1：现场usbmux/配对/硬件身份核对，安装前偏好备份；首次installation_proxy超时、最初有公开具体View启动失败，均留档。修复后第一次ios-deploy发现超时，重新现场有线发现后，02:29:28同包InstallComplete。普通空条件首页实图、完整连接/目录/索引/重启/错误恢复/本地移除均核。收尾偏好除诊断外0变化，原Wi-Fi图标可见，只删自有HTTP会话，未知原Runner/全局设置不动。
- TV，AppleTV14,1/tvOS18.2、LAN：02:26:08 CoreDevice保留数据覆盖，偏好0变化。新入口及连接表单实图/名称和地址输入成立；直接element value无效、键盘下一项超时、遥控时序/AX焦点不一致造成填表未完成，最后已回首页且未建索引；不能称选目录/入库通过。自有Runner有界运行并停止，修改的3项设置已恢复且GET核实。DVT仅看到进程时截图曾仍是SpringBoard，已纠正：最后显式前台空条件启动，3/10秒NAS首页实图及进程均成立。
- 新iPad，iPad15,7/iPadOS26.6、有线：备份偏好后installation_proxy在发出安装后120秒超时，无Complete。替代安装及一次协调器复查均报IXErrorDomain48“已有安装协调器属于另一个进程”；当前普通启动亦被阻塞。偏好仍0变化，但不能确认最新已安装或完成回归。已经一次请求重新插拔并解锁，未获回复；不卸载、不重置、不杀设备系统安装进程，设备原Wi-Fi/VPN/方向保持。
- iPhone18，iPhone19,7/iOS27.0：本批无可连接目标，未安装本批包。25日22:13包属旧源码，不继承为本批最新；保存域名未改，实际DSM域名路线旧问题继续暂缓。

## 自动化和只读证据

`swift test`最终15项/0失败：10项路径/XML/扫描/存储及5项真正loopback HTTP。覆盖中文、同名不同目录、无密码索引、越界/双重编码、缺失属性/可选404、实体和截断、原子旧库保留、取消、迟到、移除后迟到、损坏库不覆盖、HTTP Basic、403、真实HTTP跳转不跟随及跨origin的href拒绝、带长度和无长度超大响应、实际请求取消。

iPhone13普通包通过UI填写自有临时测试源，选Movies，实际收录3个视频（含两条不同路径same.mp4）；本机索引取回确认根和3条，重启后仍在。只给子目录返回403，错误在界面可见，前后索引逐字节相同；恢复读取后重扫成功，凭据经Keychain重读。最后通过系统长按菜单移除本机测试源，取回JSON确认空库，原偏好保持。旧WDA不支持element touchAndHold的失败保留，改用已观察坐标的全局长按后完成，未改App绕过。

自有Mac临时目录6文件，前后文件路径/内容SHA/大小/mtime及目录结构完全相同；16次服务端请求全部PROPFIND/Depth1，未请求未选Other目录。没有向真实NAS写入或创建测试文件，没有复制竞品凭据，没有媒体/蜂窝流量。临时服务已用SIGINT停止（预期exit130，finally快照已落盘），不是测试失败。

首次测试发现XML可选字段对同一Optional读写的Swift独占访问崩溃，已改为仅存在时赋值；HTTP302终态覆盖redirect错误已修，跳转从未真正跟随。首次TV包在共享具体View销毁时空地址崩溃，报告含CODESIGNING Invalid Page；改为模块内私有View＋公开AnyView工厂后，在13/TV当前观察范围不再复现。此为有效规避和有限真机证据，不宣称已证明编译器根因或完成Release验收。

## 下一步

优先解除iPad安装阻塞并核最新包，补TV完整连接→选根→入库→取消/重扫/本地移除的真实遥控闭环；复用本机只读夹具，不再次复制竞品账号。自动化失败先根据实际焦点/键盘状态修正，不盲发同样按键。随后实现共享文件名/季集识别及已有NFO只读解析，再接可合法使用的provider与本地纠错；SMB适配器另做只读权限/许可审计。当前[只读设计](../../../architecture/READ_ONLY_NETWORK_MEDIA_LIBRARY.md)为后续边界，[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)保留29项开放，原114播放格不变。

上一TV原轨、PGS/听音、内部19.508秒慢等待、文件KS单控制层、高清/评分、原弱蜂窝大文件seek、iCloud等仍按[前批](2026-10-25-READONLY-NETWORK-LIBRARY-AND-DEVICE-REFRESH.md)与[总分支交接](2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)接续。本批没有新建周期任务，不声称回合结束后后台执行。
