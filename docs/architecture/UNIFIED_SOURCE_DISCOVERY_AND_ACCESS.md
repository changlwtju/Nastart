# 统一存储与媒体服务：发现、授权恢复和界面方案

2026-10-26用户最新规则：Plus并入三端“设置”组；TV固定六项等大三列两行。TV启动台默认显示全部Docker（可手动隐藏），不展示套件，分类与设备→容器目录及手机共享规则一致；套件入口留设备资源组。TV Docker 服务及管理显示最终改为双列等大卡，奇数末张靠左；分组标题整行，暖色焦点不使用覆盖名称的系统白条。存储入口仍保持“浏览文件/已有库/添加目录”，连接表单分HTTP/HTTPS、地址、端口和路径，发现线索不等于已有授权。具体实施与未接能力见[当前批](../archive/handoffs/2026-10/2026-10-26-CROSS-PLATFORM-CARD-RULES-WEBDAV.md)。

2026-10-26实际入口按用户简化要求修订：日常只“浏览文件→现有预览播放”和“已选媒体文件夹→整理本机资料”；首页直接列已连接媒体库及添加文件夹，协议/服务发现移入连接管理。已有Jellyfin一步进真实库；协议差异只属连接细节。当前NAS复用已有File Station会话，新增服务不得借DSM凭据。下文较早NAS/服务分类方案由此收敛；能力边界与最终逐机结果见[UI批](../archive/handoffs/2026-10/2026-10-26-UNIFIED-MEDIA-HOME-AND-TV-UI.md)。

2026-10-26最新私有[FTP NFO/MLST事务](../archive/handoffs/2026-10/2026-10-26-FTP-NFO-MLST-AND-INDEX-TRANSACTION.md)已同授权会话核目录/读前MLST/指定≤64KiB NFO/读后MLST、精确路径/长度/EOF/226；49 NFO/旧库四核对＋43列表回归含14 ASan/双平台编译，140服务窗清理。未改生产Store经私有桥验证，仍非生产FTP配置/字面路径/账户来源或递归库/App；Codable密码与anchorDER仅测试，不得直接持久化。下一生产来源/凭据/路径模型与扫描，FTPS复用/真实兼容及SMB严格范围FAIL单列；属性提示非原子内容快照，早批“无MLST/NFO”按当时归档阅读。

2026-10-26最新私有[显式FTPS升级](../archive/handoffs/2026-10/2026-10-26-FTPS-EXPLICIT-STARTTLS-FRAMER.md)以公开Network framer在220/AUTH TLS/234完成后动态加TLS并markReady，信任通过才发凭据；显式控制/数据TLS、实际peer/原host及MLSD已走通。43最终场景含8 ASan、共用server SSLContext补3窗/双平台编译成立，49服务窗清理；强制session reuse仍522，未建立复用/真实NAS兼容，MLST/NFO/目录源/索引/App仍未接。早批“仅隐式/explicit不支持”按当时归档阅读，SMB严格范围FAIL保持。

2026-10-26最新私有[FTP MLSD条目](../archive/handoffs/2026-10/2026-10-26-FTP-MLSD-BOUNDED-ENTRY-PARSER.md)已在完整EOF/226后解析file/dir/可选版本，原样保留中文/空格/字面百分号，cdir/pdir不遍历，未知类型/链接/重复/晚坏行拒绝整批；50契约＋9网络窗含8 ASan操作/双平台编译，误接受非ASCII key的反例已修/保留。只独立原型，尚无显式数据升级/session reuse、MLST/NFO/目录源/索引/App；SMB最新[原生替换反例](../archive/handoffs/2026-10/2026-10-26-SMB-ROOT-LIFETIME-BOUNDARY.md)仍能越根且提交，严格范围FAIL，不能以版本/保留句柄承诺总保旧库。下方早批按当时归档阅读。

2026-10-26最新仓库外[FTP/隐式FTPS数据通道](../archive/handoffs/2026-10/2026-10-26-FTPS-PASSIVE-PEER-AND-DATA-TLS.md)已用Network实际控制peer固定数据IP、原host核数据TLS及控制叶一致，EPSV优先/PASV忽略声明主机；42最终场景含6 ASan和双平台原型编译，EOF/226/32KiB及取消/截止成立。原StreamTask控制源码未改，新后端仅隐式FTPS/明确plain；显式数据升级/session reuse/MLSD条目/MLST/NFO/库/App仍未接，SMB严格范围失败保持。早批“无数据通道”按当时归档阅读，不当最新能力。

2026-10-26新增仓库外[FTPS/FTP控制隔离](../archive/handoffs/2026-10/2026-10-26-FTPS-FTP-CONTROL-TLS-AND-CANCELLATION.md)：系统StreamTask显式/隐式TLSv1.3、严格主机/证书/凭据门槛、无降级、有界回复和取消/截止，28场景与双平台动态编译。普通FTP只显式配置，不自动回退；没有EPSV/PASV数据连接/目录/NFO/库/数据TLS或App交付。下一实际对端绑定和数据TLS/MLSD/版本事务；SMB严格选根范围失败不因本批改变，用户NAS/系统信任不改。

2026-10-26当前SMB**严格选根未通过**：[目录保留/范围失败](../archive/handoffs/2026-10/2026-10-26-SMB-PATH-PINS-AND-CONTAINMENT-FAILURE.md)证明祖先路径替换可使文本仍在根内而实际NFO READ在根外。保留祖先句柄/移除SHARE_DELETE/目录CLOSE读后校验只能在夹具模拟服从共享规则时阻止改名，强制本地改名仍4次外部READ；旧库虽保住，不当范围通过。13最终窗12范围成立/1失败，候选不接App，需要真实服务器和原子访问策略；不改NAS共享/权限绕过。独立推进FTPS/FTP传输隔离，下面早批编译/局部通过不扩大SMB交付。

2026-10-26最新私有[SMB可变区/所有权修复](../archive/handoffs/2026-10/2026-10-26-SMB-VARIABLE-SPAN-AND-PAYLOAD-OWNERSHIP.md)实证旧READ/CREATE短帧大声明等待及目录越界double-free；补命令内固定/可变区分配、READ请求容量和错误路径所有者，24窗含8 ASan/双平台编译通过。原型累计10个上游差异文件，仍未接App/签名嵌入；非全部解析/SMB3/并发路径证明，下一原子选根与其余真实兼容。FTP系列/新增客户端状态不变。

2026-10-26最新接受范围仅仓库外：[NFO版本/旧索引事务](../archive/handoffs/2026-10/2026-10-26-SMB-NFO-VERSION-AND-INDEX-TRANSACTION.md)在目录→CREATE→同FileId CLOSE POSTQUERY比较原FILETIME/大小/属性，未知/变化/缺有效标志不发布暂存；未改Store副本经私有桥核失败保留旧库，第二NFO失败不提交部分结果。29最终场景含2工具预期复核、ASan实际6窗/双平台动态编译，夹具与断言失败均留档。不是原子内容快照/并发路径证明，也未接生产SMB适配/签名嵌入/UI；下一并发选根、其余C分配和真实SMB3/许可，FTP系列及新增媒体客户端交付范围不变。下方同日早批“下一步”按当时归档阅读。

2026-10-26协议接续：[认证前地址回退隔离](../archive/handoffs/2026-10/2026-10-26-SMB-PREAUTH-ADDRESS-FALLBACK.md)已在DNS快照内有界尝试候选，并以首次SESSION_SETUP入队作为停止回退的界限；后续授权拒绝/权限/超时不重复尝试凭据。仍无App协议/界面交付变化，NFO版本、完整边界/真实SMB3与签名嵌入/许可后再接工程。

2026-10-26协议后续：[SMB原生DNS/数字连接隔离](../archive/handoffs/2026-10/2026-10-26-SMB-NATIVE-DNS-AND-NUMERIC-CONNECTION.md)已核查询取消/截止和两族实际只读、原名UNC保持及地址上限；仍无App协议/界面交付变化。下一连接回退/NFO版本，再核完整边界、真实SMB3/分发许可；FTP系列与新增媒体服务原生客户端仍待接，不改变NAS/用户网络配置。

2026-10-26接续：[SMB认证/接收隔离](../archive/handoffs/2026-10/2026-10-26-SMB-AUTH-ERROR-AND-RECEIVE-BOUNDS.md)修正旧4秒的畸形ERROR等待与终态覆盖，限定接收/并发取消证据已取，尚无App协议/界面交付变化。同步DNS、其余解析分配/并发选根/SMB3及真实服务器待核，FTP/FTPS/SFTP仍未接。

2026-10-26协议后续：[SMB raw目录/NFO与签名隔离批](../archive/handoffs/2026-10/2026-10-26-SMB-RAW-DIRECTORY-NFO-ISOLATION.md)已扩到按页读取/实际取消/缺签负例局部修补，但仍仓库外，认证错误/DNS/竞态/内存上限/SMB3和真实兼容未验，不改变下述App协议交付范围。FTP/FTPS/SFTP仍计划，用户NAS不装软件/启协议。

2026-10-26接受实现更新：共享`MediaServiceDiscovery`/`PublicMediaServiceHTTP`/`MediaServiceViews`已接双工程“媒体服务”区；NAS清单完整性、产品线索、公开身份、可达性、已存登录及原生入口能力分别处理。Jellyfin/Emby检查ProductName＋Version＋Id，Plex解析identity XML，Subsonic协议响应仅在type证据成立时标Navidrome；Audio Station保留套件线索/权限待核，不臆造API。现有Jellyfin可进入原生库，其余产品只交付识别/状态，授权、库浏览、播放尚未实现。TV另保留独立“已保存的Jellyfin”来源，缺NAS端点不得隐藏它或推断NAS归属。详[本批边界与证据](../archive/handoffs/2026-10/2026-10-26-MEDIA-SERVICE-DISCOVERY-AND-ENTRY.md)。

公开请求使用独立无Cookie/凭据/缓存会话，不跟随跳转，仅GET公开身份；128KiB/响应、2秒请求/3秒传输、每候选至多2端点、并发3、页面12秒及16候选上限，离页/后台取消并隔离旧代结果。只复用主工程已批准的精确origin/叶证书，不创建或轮换信任；原URL拼写用于Keychain和实际入口，规范键仅用于等价比较。仅合并同产品且完全相同的非空端点集合，不以名称/IP合并多实例。手动刷新重新取DSM清单，失败保留缓存状态；不完整/未广播/无端点均不推导未安装。FTP/SMB/独立SFTP和新增服务原生客户端仍在后续范围。

以下“方案/尚未接入”章节为本日较早设计基线，当前交付以本段和当前交接为准。

2026-10-26原生接续：首切片已实现NAS上下文/File Station会话选根与共享只读扫描、已有WebDAV连接再选目录及主工程主题传入，详[实现与边界](../archive/handoffs/2026-10/2026-10-26-NAS-SESSION-SOURCE-HUB-NATIVE.md)。以下是原方案与当时审查，FTP/SMB/新增服务及完整发现/授权模型仍待实施，不能读成全部交付。

2026-10-26。状态：**方案、源码核对与交互预览，尚未接入App**。本轮用户新增FTP兼容、NAS识别后减少手动登录、网络存储界面统一，以及Emby/Plex/Navidrome/Subsonic/Audio Station等服务识别。用户明确其NAS未安装这些新增媒体服务；不要求用户安装，不改NAS/VPN/端口配置来验收。需求编号只归[唯一总账](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)；既有只读实现与包见[当前交接](../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。

## 产品范围与当前差距

从“添加一个WebDAV地址”扩为“从已登录NAS与已有来源开始使用”。文件夹来源与服务端媒体库共享入口、设备归属、授权状态与主题，但数据分别管理：前者客户端索引/刮削，后者优先读取服务已有库、海报和稳定条目ID。Navidrome/Subsonic/Audio Station按音乐资料组织，不套电影/季集表，也不假定音乐API目录就是NAS真实路径。

现状核对（只读源码，非新真机验收）：

| 位置 | 已有实现 | 缺口/不能宣称的能力 |
|---|---|---|
| `NetworkMedia.LibraryViews`、`NetworkCredentialVault` | 独立WebDAV表单、按库UUID绑定凭据、已有库重扫可读取已存凭据 | 公开AnyView工厂无NAS上下文参数；新增来源直接要求地址，不会按当前NAS显示可用连接，也缺跨文件夹复用已有连接的入口 |
| `LaunchpadView.JellyfinLibraryStore.restoreIfNeeded`、`KeychainStore` | 按已配置端点加载先前Jellyfin令牌、恢复用户、校验身份；首次signIn另行进行 | 自动恢复来自**服务已有授权**，不是发现NAS后用DSM SID登录Jellyfin |
| `DSMClient.mapServices`、`ServiceIconRegistry` | 容器/套件/反向代理元数据、部分产品名称/图标/分类；含Emby/Plex/Navidrome/Audio Station名称规则 | 名称归类不是完整API验证/授权/原生播放；部分Web端点候选目前只看公开路径HTTP成功，不能作为跨产品身份结论 |
| `TVDSMClient.discoverServices` | 查询容器、套件、反向代理；对Jellyfin做公开身份校验 | 其余产品未同等接原生客户端；与移动探测/状态语义仍有差异 |
| `LANDiscoveryService` | HTTP/HTTPS/SMB Bonjour线索，面向DSM的探测 | SMB广播不等于已有SMB目录；没有通用FTP/音乐服务器的完整发现链 |
| `AppTheme`与`nastartListSection` | 同一强调色、表面/主题、圆角22、行节奏；TV已有共享底层设计 | NetworkMedia的独立List/Form未系统接收主工程的主题与NAS上下文；不能靠继承tint称完全统一 |

本轮不改上述代码、不重新构建/安装，也不把原型当新App界面。已安装07:15最终包身份不因文档/预览变化而改变；既有42项逻辑结果不记为本轮新测试。

## 首选流程：从已登录NAS开始

1. 打开“存储与媒体”，先显示已连接NAS、已保存来源与可用的文件访问能力；不先弹地址/密码表单，也不新增第五主Tab。
2. 对群晖优先提供**使用现有File Station会话选文件夹**。现有会话和权限有效就无需第二次登录，也无需先开启WebDAV/FTP/SMB。当前File Station文件浏览已存在，但接入独立网络库扫描是后续实现，不把NAS地址伪装为WebDAV端点。
3. SMB/WebDAV/FTP系列用于已有共享、其他设备或指定协议。已存的同一连接可再选文件夹，不再重建账户；首次可明确选择“使用此NAS账户”或其他账户。只在该协议/端点身份已确认且用户选用后，读取本机凭据尝试一次；成功后按协议/服务器/账户范围保存连接。
4. 媒体服务先恢复有效服务授权，恢复成功直接进库。首次或失效才展示该服务所需的登录/设备授权，不能把暂时断网当密码错误、清除整个NAS登录或所有资料。
5. 自动连接不等于自动导入整个NAS。用户仍选择库根及是否包含子文件夹；仅完整、有界扫描成功后提交客户端索引，沿用本机纠错/缓存/失败旧库保持规则。

文件访问API及会话/权限依据[群晖File Station开发资料](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Package/FileStation/All/enu/Synology_File_Station_API_Guide.pdf)，实际可用API、版本和权限以当前会话核对为准。DSM SID不冒充WebDAV Basic/Digest或SMB/FTP密码。**不用重复填表可以做到，无授权的通用免登录不成立。** 原保存域名＋端口、实际会话地址与请求路线分别维护，继续遵守iPhone18固定域名约束；发现内网IP不能静默覆盖已保存域名。

## 存储协议安排

| 类型 | 安排 | 关键接受条件 |
|---|---|---|
| File Station | 先接NAS会话上下文，减少当前用户重复登录 | 当前DSM身份/权限确认、只读列表/NFO、取消、选根、账户切换隔离；不额外申请管理员权限 |
| WebDAV/HTTPS | 先补已发现/已存连接与当前NAS的入口，保持现有扫描 | 保留原地址与证书策略，不跨origin转发凭据，已有索引/本机纠错迁移不丢 |
| SMB2/3 | 继续现有隔离原型，随后接只读目录 | 实际取消/截止、权限/FILE_OPEN、DFS/重解析越根、随机读及签名/加密配置，不能以发现广播代替接入 |
| FTPS | FTP家族优先的加密连接；先显式TLS，再按兼容性评估隐式TLS | 控制与数据通道都受保护，验证证书及绑定服务器，不因失败自动降级成明文 |
| FTP | 旧设备兼容项，可明确选用；不默认开启NAS FTP | 明文含义明确、被动数据通道、中文路径、列表格式、取消、文件版本/长度、恢复读取；不宣称列目录即可流畅seek |
| SFTP | 独立SSH文件协议，按需求扩展；不与FTPS混名 | 服务器主机密钥验证、独立权限与读取偏移、连接取消；不为支持它而开启NAS SSH服务 |

[RFC4217](https://www.rfc-editor.org/info/rfc4217/)区分FTP控制和数据通道的TLS；[RFC3659](https://www.rfc-editor.org/info/rfc3659/)定义机器可读列表及恢复读取等扩展；[RFC2428](https://www.rfc-editor.org/info/rfc2428/)涉及EPSV/NAT与IPv6；[OpenSSH资料](https://man.openbsd.org/sftp.1)说明SFTP使用SSH传输。这些是适配依据，不代表已有客户端已交付。

FTP首版：能力协商优先MLSD/MLST、UTF-8、SIZE/MDTM及REST/RETR，旧LIST只能在可可靠解析时回退；保留文件名空格/大小写，不套WebDAV百分号路径规则。拒绝CR/LF命令注入、越根/不明链接、截断/歧义列表；无法确认完整时保留旧索引。EPSV优先复用控制连接对端；PASV不得任意连接响应中提供的第三方主机。取消须关闭自有数据/控制等待，认证失败不循环换密码或匿名尝试。FTP目录/NFO阶段不读取整段媒体；将来REST支持、大小/版本检查与深seek单独验。

只读命令层不给业务暴露上传、追加、删除、改名、建目录、权限或时间修改，禁止STOR/APPE/DELE/RNFR/RNTO/MKD/RMD及相关SITE/MFMT写入。AUTH/USER/PASS/CWD、TLS协商、列表/读取及ABOR等会话操作不等于更改源文件；不能简单按HTTP POST或SMB CREATE名称判写入。客户端缓存、海报、纠错始终只落本机；NAS/VPN/协议开关不由发现流程修改。

## 媒体服务安排与授权

| 服务 | 如何识别候选与确认 | 登录与后续体验 |
|---|---|---|
| Jellyfin | 当前NAS服务元数据/发布端点及公开产品身份；现有实现继续核正 | 恢复已存服务令牌；首次账户登录或后续评估Quick Connect，不能用DSM SID代替 |
| Emby | 同台NAS套件/容器/发布端点，按Emby响应验证；不能仅凭8096端口或共用路径当Jellyfin | Emby用户授权与会话保存；不要默认要求管理员全局API Key |
| Plex | NAS元数据、本地GDM线索；授权后可用其账户提供的服务器列表，仍核服务器身份/归属 | 使用官方设备/PIN授权与服务器选择；NAS登录不能直接授权Plex账户 |
| Navidrome | NAS元数据＋Subsonic/OpenSubsonic协议响应；有产品证据才标Navidrome | 专门音乐账户/已保存授权，按服务能力协商支持的鉴权方式 |
| Subsonic兼容 | 协议能力家族；未知实现显示“Subsonic兼容”，不强行标Navidrome | 与Navidrome共用协议适配基础，保留实现差异，不能重复展示同一实例 |
| Audio Station | 群晖已安装套件、API目录、运行及应用访问权限 | 优先现有群晖身份，在服务允许的会话范围内复用；接口/权限不符时只显示对应原因，不臆造已支持的私有API或通用SSO |

依据：[Emby发现](https://dev.emby.media/doc/restapi/Locating-the-Server.html)与[鉴权分类](https://dev.emby.media/doc/restapi/index.html)、[Plex官方授权](https://developer.plex.tv/pms/)及[GDM设置说明](https://support.plex.tv/articles/200430283-network/)、[Navidrome兼容说明](https://www.navidrome.org/docs/developers/subsonic-api/)与[OpenSubsonic鉴权](https://opensubsonic.netlify.app/docs/api-reference/)、[Jellyfin Quick Connect](https://jellyfin.org/docs/general/server/quick-connect/)。Audio Station具体API版本/会话复用尚无本轮已安装环境证据，不能写成已验证。

## 发现与授权各自建模

“已安装/运行中”“端点可达”“服务身份已确认”“账户已授权”“客户端支持哪些能力”分别记录，合成一个清晰的主要状态和一个下一步操作。容器running不是API在线，HTTP200可能只是登录页面；超时、权限不足或未广播一律不推导“未安装”。默认不显示一排根本没发现的Emby/Plex等占位卡。

优先读取现有DSM有权访问的套件、容器发布端口、反向代理资料；Bonjour/GDM等只生成候选，公开无凭据探测再核产品身份与稳定服务器ID。使用实际端口/子路径，不用默认端口猜唯一服务。多实例保留，服务合并须有服务器ID/明确映射，不能只按名字、IP或电影片名去重。公开探测独立ephemeral会话，不带DSM SID、Cookie或其他服务令牌，不跟随跨端点授权跳转。

本地来源身份应包含NAS归属、协议/产品、稳定服务器/实例、端点含basePath、账户引用、用户选根与能力；地址/凭据分离。现有`WebDAVScope`与`DAVPath`保持协议边界，后续新增带类型的来源/路径与适配器，兼容已有库UUID、原路径、纠错、Keychain与TV v2持久目录。不得改protocol标签后仍向FTP/DSM地址发送PROPFIND。

恢复登录的顺序：已绑定会话/凭据→受限身份/权限检查→有效则进入→确需授权时才展示服务专属流程。新的“同NAS账户”授权范围限定到目标服务/协议；一次认证拒绝立即停止，防止跨服务试密码/锁号。切换NAS或账户、服务端点改动、退出/后台均按代次隔离；旧响应不能发布到新账户，暂时离线保留索引和用户纠错。相同IP/相同主机名本身不足以发送NAS密码。

发现仅在当前NAS/页面有界执行，已有来源和缓存先显示，慢服务逐项更新，不让启动/播放等待全部协议扫描。无必要时不广播、不轮询全网段、不在蜂窝持续探测；局域网权限拒绝也保留手动添加。公共日志仅记录类型/结果/数量，不记录地址、SID、密码、token或认证参数。

## 原生界面与实施顺序

入口拟用“存储与媒体”，保留原四主Tab；从NAS摘要/已有来源到此页。主页面按NAS归属展示“NAS文件夹”“媒体服务”，已有授权可直接进库，首次才“连接”，新增按钮收起手动协议/地址表单。数据为空、权限受限、离线各有对应状态，不将未安装服务伪装成错误。高级端口、子路径、编码、证书与路由放连接详情。

复用主工程AppTheme/AppearanceStore的同一主题、表面、22圆角、字体、间距和SF Symbols；NetworkMedia以主工程传入的上下文/主题配置或共享组件接入，不复制一套看似相近的颜色。保留AnyView工厂及模块内状态包装边界。iPhone单列、iPad按实际宽度排布、TV用可见原生焦点与完整宽行；大字/浅深色/三个既有主题/返回层级均独立回归。

顺序：**先NAS上下文＋File Station会话选根和已有连接复用、统一界面→共享有界发现/能力与授权状态→SMB只读适配→FTPS/FTP兼容→Emby/Plex及音乐服务逐个原生接入，SFTP独立排期**。已有Jellyfin路线与原播放重点继续维护。发现/网页入口、原生库浏览、播放/字幕/进度/离线分别标验收，不以一个“支持服务”开关盖住差异。

本轮交互预览仅示意这些路径，包含已有授权、更多服务、未发现服务、无权限及离线状态，无真实网络/登录/扫描能力，不能安装到手机或替代App改版。

## 用户没安装服务时如何验证

以自有loopback协议夹具/录制格式的脱敏合成响应验证正常、401/403、超时、产品身份冲突、同端口不同子路径、多实例、重定向、登录HTML伪200、错误/部分列表、旧响应和取消。FTP/FTPS另覆盖TLS控制/数据双通道、被动端点约束、中文/空格/编码、REST、链接和真实关闭连接；全部比较源文件内容/mtime/名称/结构无变化。Plex PIN流、Subsonic能力扩展、AS无接口/无权限均单列。

客户端逻辑/夹具测试≠真实服务兼容认证。再在独立本机测试环境运行可用开源服务版本，实际授权/库浏览/播放分别验，不在用户NAS装软件、启用协议或改反向代理。Plex/AS真实授权或平台依赖不足时保留待验，原有服务不受影响。最后每台真机按AGENTS先核源码/签名/包身份，再做普通启动与界面/功能回归；用户NAS提供必要的空环境/权限负例，本批未发真机/真实NAS探测。
