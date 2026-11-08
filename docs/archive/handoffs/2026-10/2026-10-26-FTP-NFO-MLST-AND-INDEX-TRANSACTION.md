# FTP/FTPS指定NFO、MLST版本与旧索引事务

2026-10-26接[显式FTPS升级](2026-10-26-FTPS-EXPLICIT-STARTTLS-FRAMER.md)。[结构化结果](../../../testing/results/2026-10/2026-10-26-ftp-nfo-mlst-index-transaction.json)，源码/夹具文件/证书私钥/原始结果/产物仅在私有指针`/tmp/nastart-ftp-nfo-version-evidence`。**本批仍是仓库外单个指定NFO读取与测试桥，不是生产FTP库已接入App。**

## 接受实现

同一次授权/控制连接内：OPTS MLST请求type/size/modify/unique → MLSD → 确认用户指定单个子项确为.nfo且有size/modify、至多64KiB → PWD → 读前MLST → RETR NFO/完整EOF与226 → 读后MLST → QUIT。只允许明确选中的单个文件，不猜测/自动读取视频，不写源文件；认证最多一次，不因元数据/权限失败换登录。

新增FTPMetadataPaths按[RFC959](https://www.rfc-editor.org/rfc/rfc959.html)解析PWD的257引号及双引号转义，按[RFC3659](https://www.rfc-editor.org/rfc/rfc3659.html)处理MLST多行事实。只接受单一事实行，返回路径必须逐字节等于原请求相对路径或由已核PWD构成的绝对路径，不使用basename/后缀匹配；保留空格/中文/字面百分号。缺size/modify、路径不同、未知类型/链接或多个事实行均不RETR或不发布结果。MLST的Unique在同一控制会话内比较，缺失/出现的变化也计不一致；不把Unique当影片ID。

读前比较目录与MLST的name/type/size/modify/unique；数据沿原actual peer/原host/独立TLS和控制叶策略，单次接收最多4KiB、NFO至多65536字节且必须等于已知长度，完整226后再读MLST比较。所有NFO字节留本轮私有暂存，版本/权限/网络/取消/截止失败不返回。通用transfer复用原列表数据路径，完成的数据连接从Owned移除；列表原UTF8/CRLF边界及32KiB限制保持。缺MLST/必要事实时明确失败，不以SIZE/MDTM或不明LIST猜完整。

这是**乐观版本检查**：同长度且mtime/Unique未变、低精度时间、服务端伪报或祖先路径替换仍可能漏检，不是内容快照或原子选根证明，不能据此关闭SMB范围FAIL。没有修改用户NAS来获取更强作用域。

## 索引证明的边界

复制生产NetworkMedia的21个源码/测试/清单输入，逐个摘要与工作区一致；只额外添加隔离目录初始化工厂。Fixture Bridge将完全核对的列表/指定NFO交给现有ReadOnlyLibraryScanner和NetworkLibraryStore，使用独立本机目录/独立UserDefaults suite，未改生产Store实现。

每窗先种previous-good旧库。版本/路径/类型/权限/数据TLS/短读/完成回复失败及取消、超时，均核磁盘JSON逐字节、内存完整快照、重新建Store加载、可选持久目录字节保持。成功才入fresh-title且origin=nfo；稳定读完但XML无效/空的NFO，沿已有规则成功回退Movie文件名、notice=invalidNFO，不将内容解析错误混作传输错误。传输/MLST错误不能转换成可忽略invalidMetadata。

Bridge只针对自有单目录/单NFO夹具，连接配置仍是https://fixture.invalid的WebDAV形状；这证明通用事务保护，不是生产FTP配置/凭据/路径模型。持久目录是在macOS私有suite核的同一逻辑，不是tvOS真机重启。下一接入必须区分FTP字面路径与DAV解码语义、协议/端点/账户身份，不能把含password的Codable测试参数或anchorDER本机路径直接持久化为App来源。

## 实际验证

最终49个NFO/索引窗口全过（6 ASan）＋原43列表/升级窗口全过（8 ASan）；两组分别统计。3正向基线、早版45窗均留档，共140自有服务窗口已停止/join/监听器关闭。首夹具elseabsolute语法错误在服务启动前发生，原脚本保留，不算网络失败。

| 场景 | 结果 |
|---|---|
| explicit/implicit FTPS、明确plain | 同控制连接1次授权、两条数据连接，50001字节NFO/两次MLST；加密模式控制/数据均TLS1.3、无明文凭据，视频RETR0 |
| 中文/空格/百分号、PWD含双引号、相对MLST路径 | 原名保持，正确匹配和识别fresh-title |
| 65536/65537字节 | 边界可成功；超上限在RETR前拒绝 |
| 误选视频/../路径/命令注入 | invalidInput，控制TCP接受0 |
| 缺size/modify、前MLST变化/坏日期/链接/550、错路径/多行/不支持MLST/PWD格式错 | 明确失败，无NFO RETR，旧库四项保持 |
| 后MLST大小/修改时间/Unique变化或丢失/链接/550 | NFO虽已读完仍不提交，旧库保持 |
| 自有文件同长改写/增长/截断/原位替换 | 已知版本变化或长度变化拒绝；只由夹具所有者改文件，客户端不写 |
| 单独短传输但226成功 | 4096字节后EOF仍不够已知长度，读后MLST前拒绝，旧库保持 |
| NFO数据错名/同CA另一叶证书、完成426 | 无结果/旧库保持，不降级或重登录 |
| NFO读取/读后MLST等待中取消/截止 | 有界结束且旧库保持；关键窗已建控制与数据EOF观察成立 |
| 空/无效XML | 版本稳定读取完成，按既有NFO规则文件名回退并标invalidNFO |

实际截断窗口中服务端文件句柄缓存仍发出了旧50001字节，最终是读后MLST大小变化拦截；不冒称它证明了短读分支。补单独短传输窗明确只发4096字节并在后MLST前失败。非改写源的内容SHA/大小/mtime/名称保持；改写窗单列fixtureOwnerMutations，所有窗客户端无远端写/视频RETR，不声称改写窗源未变。

ASan最终14窗口核Passive.o/MetadataPaths.o及运行时，无失效访问报告；detect_leaks=0，非TSan/泄漏或系统Network内部竞态穷尽证明。共享服务器TLS context的原强制reuse负例在43回归中仍522，复用兼容没有因此解决；不改服务端安全要求绕过。

## 构建、设备与接续

iOS/tvOS普通Debug arm64动态原型编译/vtool通过，未签名/嵌入/设备执行。移动SHA `c0e03ae0004ab4d6591a23c22e7a621e917b12a2e0890c199e5c4ee6f4f6b9a1`，TVSHA `ee3560ae5147c5c499dde2f3f4a3938764991d52e72194b122cbbc8de9837639`。375生产App本地输入及11:09冻结包30/27 Mach-O零漂移，无新App构建/安装/真机功能。

18:13:50现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable/USB未见，未更新；13/Pad/TV沿原安装记录，不作为新回归。原DSM域名＋端口实际路线旧项保持。无用户凭据/偏好、系统信任、NAS/VPN/网络或媒体/蜂窝改动；所有端点自有loopback，140服务窗清理，无周期任务/回合后后台执行。

下一转生产来源/协议与字面路径/凭据作用域模型、只读目录适配及有界递归扫描，同时保留FTPS复用兼容缺口；逐批接主题UI/本机索引并按每机最新普通包核对。NAS服务可用/账户授权不足须保留环境依赖，不修改NAS/VPN。SMB严格协商/转换/真实服务与原子范围FAIL继续独立保留，SFTP/新媒体客户端/在线provider仍未交付。30项14进行中/5待验收/11待开始、114播放格保持，AV/KS链未改。
