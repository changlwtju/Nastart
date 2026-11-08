# FTPS/FTP控制通道、证书与取消隔离

2026-10-26在[SMB严格选根未过](2026-10-26-SMB-PATH-PINS-AND-CONTAINMENT-FAILURE.md)支线保留反例后，自动推进已授权FTP系列。 [结构化结果](../../../testing/results/2026-10/2026-10-26-ftps-ftp-control-tls-isolation.json)，源码/夹具/证书私钥/原始审计/产物仅在私有指针`/tmp/nastart-ftps-control-evidence`。**此批仅控制通道原型；FTP/FTPS媒体库、目录与播放未接App。**

## 实现与依据

使用系统Foundation URLSessionStreamTask/Security，无新增第三方库。显式模式先读220、AUTH TLS并要求234，再startSecureConnection；隐式模式连接起即TLS。独立ephemeral session不读Cookie、URLCredentialStorage或缓存；仅自有fixture用户名密码，无DSM/已有Keychain/竞品账户内容。只写协议会话命令，不操作任何远端文件。

TLS由task级challenge执行SecPolicyCreateSSL的预期主机名、证书链/有效期核对；自有CA仅作为该私有测试session的限定anchor，未安装/修改系统信任、未接受所有自签名证书。PBSZ 0先驱动升级握手，后续PROT P成功，且TLS验证已完成才允许USER/PASS；AUTH拒绝、证书无效、PROT拒绝均结束，不明文降级或换密码/匿名重试。当前参数仍为隔离配置，生产端点身份/已批准证书复用需接主工程现有策略，不提供任意预期主机名绕过入口。

依据[RFC4217](https://www.rfc-editor.org/rfc/rfc4217.html)区分控制TLS和PBSZ/PROT协商；本批接受PROT P只说明状态协商，**没有数据连接，不证明数据TLS/FTPS会话复用**。Apple[StreamTask入口](https://developer.apple.com/documentation/foundation/urlsession/streamtask%28withhostname%3Aport%3A%29)及本机SDK头注释核实startSecureConnection在已排队IO后升级、证书回调到task delegate；不因接口存在而推断NAS兼容。

控制回复按CRLF和三位状态/多行终止码解析，上限1024字节/行、16KiB及128行/回复、128KiB/会话、单次4096字节。AUTH回复后夹带额外明文拒绝，不能把它当握手后回复。用户名/密码控制字符、CRLF、NUL和长度先拒绝；输出只保留命令标签，不记录PASS内容。FEAT目前只核回复边界，未生成生产能力模型。

每次IO用剩余总预算，另有独立总计时器取消stream；用户取消也取消stream，finally取消自有timer/stream并invalidate session。信任拒绝单独记录，不能将Foundation -999当成用户取消。普通FTP只有隔离配置明确allowPlaintext=true才执行；FTPS失败不会进入plain模式。该测试开关不等于已交付用户授权界面。

## 实际验证

最终选择28场景均按明确断言通过，含5 ASan场景；因补收尾观察实际有6 ASan执行窗口。8初基线＋28主最终＋8独立关闭观察共44窗口均停止自有线程/监听器。早8个证书负例等基线保留；初最终静默窗在server sleep期间先结束夹具，未观察到peer close，不能当关闭证据。后8独立窗等server恢复读取后都见peer关闭，源码不变、不丢弃早期未观察记录。

| 场景 | 实际结果 |
|---|---|
| 显式/隐式与逐字节回复 | 实际TLSv1.3、各1次证书challenge、USER/PASS均在TLS后；登录/FEAT/QUIT成功 |
| 不受信任、名称不符、过期证书 | tlsUnverified，USER/PASS0，无第二连接/明文回退 |
| AUTH 500 / PROT 534 | 在USER前unexpected失败，凭据命令0 |
| PASS 530 | 仅1次PASS、1连接，无重试/清凭据 |
| AUTH后夹带明文 | invalidReply，未进入USER/PASS |
| 不答欢迎、TLS、未终止多行及仅LF | 180ms预算按deadline有限结束，最终独立观察均peer关闭；本机约194–200ms，非硬实时/NAS排名 |
| 欢迎/TLS/FEAT等待中取消 | 最终关闭观察取消后约0.391–0.786ms返回，peer随后确认；只代表本机窗口 |
| 超长行/多行超总量 | limit，结束等待/关闭连接 |
| 明文默认/命令注入 | tlsRequired或invalidInput，服务端接受连接0 |
| 明确plain兼容夹具 | 成功、2条明文凭据命令，标为已显式选plain，不能并入FTPS加密通过 |

实际仅见TLSv1.3，配置最低TLSv1.2但未强制1.2/旧版做负例；不声称完整TLS版本矩阵。ASan核Control.o与运行时，无失效访问报告，detect_leaks=0，非TSan/泄漏或CFNetwork内部竞态穷尽证明。系统DNS/daemon挂死、真实设备权限/切网、TLS session reuse与各NAS认证顺序未验。

## 产物、设备与接续

iOS/tvOS普通Debug arm64动态原型及vtool通过，未签名/嵌入/设备执行。移动SHA `8ae2fb4b52f0724bda7c0ba508f41c7c53813c0551bb0a491a5a846ca0a5575c`，TVSHA `6bdb1af9f7c75a83d2e2445354aaaedf9e5e56fd58eec2e100fedd98e12eb8c9`。生产App375本地输入及11:09冻结包30/27 Mach-O零漂移，无App构建/安装/真机功能；13/Pad/TV仍沿上批安装记录。16:34:57现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable且USB未见，未更新，DSM原域名＋端口实际路线旧项保持。

全部服务端仅loopback；证书/配置和原始端点不入仓库。无NAS文件/媒体请求、目录/数据连接、媒体/蜂窝或NAS/VPN/用户网络修改。44自有服务窗口均已清理，未创建周期任务。

下一FTPS/FTP先实现EPSV优先/控制连接实际对端绑定，PASV不采信第三方地址、数据TLS同原主机策略、MLSD/MLST有界解析、完成回复/截断/取消/文件版本与旧索引；会话复用要求及真实服务兼容另核。之后生产来源/凭据作用域/同主题UI、逐机最新包验证。FTP同样不能把文本路径/CWD当原子目录约束；SMB本地强制替换仍范围失败，不因本批改变。SFTP、Emby/Plex/音乐客户端、在线provider仍分别推进，30项14进行中/5待验收/11待开始、114播放格保持，AV/KS链未改。
