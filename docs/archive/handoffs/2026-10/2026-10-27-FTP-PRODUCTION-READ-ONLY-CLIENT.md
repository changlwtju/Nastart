# FTP共享只读客户端首批（2026-10-27）

前序是[私有NFO/MLST事务](2026-10-26-FTP-NFO-MLST-AND-INDEX-TRANSACTION.md)。本批把协议实现接入正式NetworkMedia包，移除原型的WebDAV形状端点、Codable测试密码和证书文件路径；**尚无App的FTP来源保存、账户管理、选目录适配、递归建库或播放入口**。不能据本批宣称用户已经可以添加FTP。

## 实际实现

正式源码位于`ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/`：`FTPReadOnlyClient.swift`、`FTPWire.swift`、`FTPStartTLS.swift`、`FTPMLSD.swift`、`FTPMetadataReply.swift`。`FTPServer`保存协议/端口/原主机，解码重验；`FTPCredential`不实现Codable，保留凭据字面空格并拒绝控制字符。现仅ASCII DNS或规范IP，非ASCII域名/IDNA尚未支持。

公开客户端只用系统证书信任，模块内部测试入口接受DER字节，不保存测试证书路径或关闭验证。显式FTPS、隐式FTPS和明确选择的plain FTP分别配置；TLS失败不自动降级。控制TLS验证后，先核FEAT中的UTF8/MLST/TVFS再发送USER，随后PBSZ/PROT、TYPE I和OPTS MLST。端口默认显式21/隐式990；真实NAS兼容尚未实测。

选根使用正式FTPPath字面UTF-8字节身份，百分号不作URL解码。每个客户端有独立授权标识，跨客户端条目在联网前拒绝。目录≤32KiB/256普通条目，cdir/pdir跳过，未知链接/重复/晚坏行整批拒绝；重复比较用原字节，Unicode规范等价但字节不同的两个名字保持区分。

实际控制peer固定数据IP，EPSV优先，只有明确不支持才受限PASV回退，忽略PASV声明主机。数据TLS仍验证原主机及控制叶证书一致。同会话列表/精确绝对MLST→仅允许NFO（≤64KiB）或已有图片（≤2MiB）→精确长度/EOF/226→读后MLST；大小、修改时间、Unique及缺失状态一致才返回。视频RETR及远端写命令不提供。总截止1～60000ms/默认10000ms，取消/截止关闭本次连接，发布前再核取消。

这些是**字面范围和乐观版本检查**，不是服务器物理目录原子约束或内容快照。FTPS强制跨通道session reuse的前批522仍开放，没有修改NAS配置绕过。SMB严格范围和协商失败不因FTP本批改变。

## 验证、失败与边界

新增7契约＋22真实loopback FTP/TLS集成测试，夹具是包测试资源`Fixtures/ftp_readonly_fixture.py`。覆盖显式/隐式有效TLS、坏证书/主机和同CA不同数据叶拒绝、能力缺失时零USER、无TLS降级、中文/空格/字面百分号和字节不同Unicode、授权隔离、NFO/图片、错路径/版本/短读/超限/负完成、取消/截止及对端EOF。每窗核自有夹具线程停止和命令范围；不访问用户NAS。

- 最终29定向普通Debug通过；29 ASan通过，`detect_leaks=0`。
- 模块按142项（跳过既有TransportIntegrationTests，含29 FTP）＋18既有传输项分批通过，覆盖160个不同用例；不能写成一次完整整套通过。
- 首27项中超限用例误套通用512KiB NFO上限，2断言失败保留，改为协议64KiB后复验。
- 首160项中一个TLS拒绝夹具因状态文件非原子读写产生2个unexpected，改临时文件原子替换；旧失败保留。
- 后一次整套180秒超时，最后缓冲输出在既有传输组，精确挂起点未知；只停止本次确切构建目录的自有xctest，不停止两个较早的非自有进程。随后使用保活和各60秒守卫分批验证，超时不洗成通过。

共享源码已随本日普通iOS/tvOS Debug编译，不等于FTP真机连库。[结构化结果](../../../testing/results/2026-10/2026-10-27-ftp-production-read-only-client.json)。私有证据在`/tmp/nastart-tv-storage-ui-evidence`所指根下`current-ftp-production-client-batch-private`，测试原始日志/证书/夹具状态不入仓库。

下一接协议来源持久化、Keychain原端点账户、目录/扫描适配和同端共用展示；先解决作用域/真实服务器条件，不把客户端原语直接作为完整来源交付。NAS源零写、无TMM/TMDB或NAS/VPN/系统/凭据改动。
