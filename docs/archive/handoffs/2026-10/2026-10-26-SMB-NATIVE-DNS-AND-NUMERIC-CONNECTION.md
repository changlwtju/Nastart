# SMB原生DNS生命周期与数字地址连接隔离

2026-10-26，承接[认证错误/接收边界](2026-10-26-SMB-AUTH-ERROR-AND-RECEIVE-BOUNDS.md)，原[目录/NFO与签名负例](2026-10-26-SMB-RAW-DIRECTORY-NFO-ISOLATION.md)继续保留。[脱敏结果](../../../testing/results/2026-10/2026-10-26-smb-native-dns-numeric-connection.json)，源码/完整日志/地址/记录发布配置/构建仅在仓库外，指针`/tmp/nastart-smb-native-dns-evidence`。**仍未接入Nastart：本批没有新App构建/安装、真机功能回归、真实NAS文件/媒体协议请求或媒体/蜂窝测试。**

## 接受的隔离实现

固定C在连接启动中同步getaddrinfo，尚未进入轮询就可能等待系统名称解析。新`NativeDNS`使用系统`DNSServiceGetAddrInfo`，每次查询由独立串行派发队列管理，取消/截止/失败/快照完成调用`DNSServiceRefDeallocate`，之后才恢复Swift continuation，记录创建/释放及完成次数。[Apple查询API](https://developer.apple.com/documentation/dnssd/DNSServiceGetAddrInfo%28_%3A_%3A_%3A_%3A_%3A_%3A_%3A%29)说明查询的持续生命周期，[释放API](https://developer.apple.com/documentation/dnssd/dnsservicerefdeallocate%28_%3A%29?language=objc)说明终止查询及注册的作用；回调采用派发队列策略。

原型在总体预算内查询，连接使用剩余预算。指定IPv4/IPv6的连接只查询相应地址族；通用解析以30ms收敛窗口提供快照及`familiesComplete`，空结果等待所需族的确认或截止。最多8个地址/32次回调，合法数字地址直接处理；拒绝URL、通配符、控制字符/NUL、未指定/多播地址以及缺scope的链路本地IPv6。域名原型目前仅接受有界ASCII标签；UI/IDNA仍待接。

C新增数字地址专用连接入口，以AI_NUMERICHOST/AI_NUMERICSERV解析地址/端口；失败不回落到原主机名解析。原服务器名独立保存到UNC，数字地址只用于TCP。当前按指定族选择一个候选，**自动多地址连接回退/Happy Eyeballs尚未实现**。旧C入口的同步解析仍存在；只有本次新入口避开名称查询，不能外推所有SDK调用已可取消。

保留原缺签拒绝、帧/复合边界/ERROR长度与非零回调终态优先。固定199个C文件相较原基线仅4文件有意变化：`include/smb2/libsmb2.h`、`lib/libsmb2.c`、`lib/socket.c`、`lib/smb2-cmd-error.c`；逐文件差分/摘要在私有证据，不是未修改上游版本或已采用的新宿主依赖。

## 最终源码验证

最终35个主要窗口：17个系统解析/连接窗口、12个解析入口边界窗口、4个LocalOnly记录集窗口、2个LocalOnly域名真实SMB读取窗口。另有4个发布引用释放后的有界观察窗口，不与主要通过数量混合。

| 组 | 实际结果与范围 |
|---|---|
| 系统主机名 | localhost双族快照；指定族实际IPv4/IPv6读取成功，每次查询1创建/1释放 |
| 数字地址 | IPv4与展开写法的IPv6实际读取，DNS引用0；UNC保留输入原写法 |
| 地址/身份分离 | `source-preserved.invalid`作原名、数字loopback作传输，真实读取/原名UNC成立；数字入口收到localhost即失败、SMB协商0，不以原名重新查DNS |
| DNS取消/截止与连接组合 | 解析引用活跃时取消/5ms预算结束均释放，SMB协商0；最终ASan组合另用未收到答案的`.invalid`查询，callbacks0、取消或deadline、TCP关闭记录/SMB协商均0 |
| 真实等待中的解析 | 生成的`.invalid`查询callbacks0时取消/截止，引用1/1；未将截止冒充NXDOMAIN |
| 认证 | 新连接入口仍以原NTSTATUS返回authenticationRejected，无自动密码重试 |
| 地址/输入边界 | URL/通配符/NUL/未指定/多播/无scope链路本地地址拒绝；带scope仅核规范化，未当链路本地NAS连通性 |
| LocalOnly记录集 | 2/8地址返回成功，9地址tooManyRecords；正常及ASan均释放查询，不返回部分成功 |
| LocalOnly域名实际SMB | 自有A/AAAA记录分别在IPv4/IPv6完成50001字节NFO读取，UNC与原名一致、peer关闭、源文件不变 |

LocalOnly通过`DNSServiceCreateConnection/RegisterRecord`发布自有随机主机记录，查询也限定LocalOnly；[Apple范围说明](https://developer.apple.com/documentation/dnssd/kdnsserviceinterfaceindexlocalonly)定义其本机可见范围。没有改系统DNS配置/hosts、NAS或VPN；普通系统解析沿原DNS配置，上游DNS路线未另审计。6个发布引用共32条记录均执行释放并退出发布进程。释放后的LocalOnly观察窗均未返回地址但到deadline，**不是权威不存在证明**；发布引用已释放与观察结果分别记录。

最终36个查询引用全部36次释放，完成状态至多一次。查询创建的本机daemon API调用本身仍同步；本轮观测正常初始化，但未模拟daemon挂死，不能承诺其内部初始化也有严格可中止截止。通用快照不保证穷尽所有地址；接口变化/更多负缓存和真实NAS mDNS/WAN变体仍待验。

## 内存与只读证据

ASan最终9个主要窗口/20个任务操作，已核运行时链接及C socket.o/Swift NativeDNS.o的插桩符号。其中12个并发查询，6个在引用仍活跃时取消、6个完成SMB读取，实际SMB协商/连接关闭各6；两族、无答案取消、9地址超限与LocalOnly域名读取均覆盖。未见ASan失效访问/越界报告；不是TSan、泄漏或穷尽竞态证明，系统dnssd内部不因本机插桩而变成已审计代码。

SMB仅自有127.0.0.1/::1服务，逐窗核内容SHA/大小/名称/mtime/目录不变，视频READ及写请求0。未向真实NAS借用DSM凭据；没有远端文件改名、移动、删除或资料写入。所有自有SMB服务、DNS发布进程和查询引用已收尾，系统共享mDNSResponder保留。

## 构建、失败与设备

iOS/tvOS普通Debug arm64动态原型最终编译与vtool平台核对通过，未签名/嵌入/真机执行。移动SHA `0a460e7e3acfbd6c8e71ba2b05508269f4ab34816222173dd15eb4c4947b6212`，TVSHA `91c24d6c954fddb4ccb4182bbe8dcdfb3977814787c1bb61072d43e7ff4c6c98`；macOS普通与ASan结果分开，不当Release或设备结果。

初版public默认诊断对象构造器可见性编译错误已修；显式链接dns_sd库在Apple SDK找不到，改用系统dnssd模块链接后过。首次UNC审计误用夹具Buffer对齐引发服务hook异常、客户端unavailable，保存原窗后按报文PathOffset/Length读取审计才通过，不归客户端或真实服务器故障。早期来源修订的窗口均留私有目录，最终统计来自最后源码。NUL入口边界在转C字符串前检查，避免名称截断；未改任何用户保存地址。

375本地应用输入及移动/TV冻结二进制0漂移，应用HEAD/原dirty保留；仍沿上批11:09包及11:10–11:11安装记录，不继承为本批新真机验收。iPhone18本批最终主机清单仍unavailable，未安装，原DSM域名＋端口及实际固定域名路线旧项保持；本次SMB UNC保留不能当DSM路线已修。

## 接续

下一先补数字候选的连接回退及取消边界，保持一次服务授权语义；再核NFO读后版本/旧索引事务、并发改名/链接原子边界、其余C分配、SMB3加密/重认证和真实Windows/Samba/NAS兼容。签名嵌入/许可分发、App适配/界面/真机尚未实施。FTP/FTPS及独立SFTP、Emby/Plex/音乐服务原生授权/库/播放与在线资料/海报仍未交付。

30项14进行中/5待验收/11待开始、114播放格保持，不新建或关闭编号；唯一编号归[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。本批不修改AV/KS链，不以DNS或目录读取填播放P。
