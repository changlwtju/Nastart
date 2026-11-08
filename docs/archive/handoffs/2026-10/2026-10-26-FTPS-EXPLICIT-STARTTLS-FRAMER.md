# 显式FTPS：有界AUTH TLS升级与实际数据通道

2026-10-26自动接[MLSD条目](2026-10-26-FTP-MLSD-BOUNDED-ENTRY-PARSER.md)。[结构化结果](../../../testing/results/2026-10/2026-10-26-ftps-explicit-starttls-framer.json)，源码/配置/证书私钥/wire审计/产物仅在私有指针`/tmp/nastart-ftps-starttls-evidence`。**本批扩展原型的显式FTPS控制＋数据列表，不是生产App或完整FTP媒体库交付。**

## 接受实现

上批Network后端已核实际控制peer/数据数字连接/独立TLS和MLSD，但仅implicit/明确plain。新FTPStartTLS使用稳定公开NWProtocolFramer：start返回willMarkReady，先读取有界220欢迎（包括多行），只写无凭据AUTH TLS；234完成且无队列多余明文时，调用prependApplicationProtocol加入原TLS options，再passThroughInput/Output并markReady。TLS协议在framer之上实际握手后，整体NWConnection才ready；此时仍明确核trust成功后才允许PBSZ/PROT/USER/PASS流程。

依据Apple[Instance公开API](https://developer.apple.com/documentation/network/nwprotocolframer/instance)及本机SDK framer_options.h对动态TLS的说明；调用发生在framer callback且markReady之前。未用仅新系统提供的IgnoringReady重置接口、私有KVC/socket提取或关闭证书校验。options属性最低iOS/tvOS15.4，原型目标16，仍须真机核具体系统行为。

预升级回复1024字节/行、16KiB/128行/回复、两阶段总32KiB，每次最多4096字节；保留CRLF/UTF8/NUL及多行终止判断。拒绝220/234后已排队的额外明文，异常阶段markFailed并保留类型，不发送USER/PASS。不因AUTH/PROT拒绝、证书错或服务器522而退明文、换账户或自动重新授权。

原控制连接承载升级，保留actual peer；数据继续连该数字IP，按原始host和独立信任判断/控制叶DER验证。explicit、implicit和明确plain统一使用上批EOF/226/32KiB/MLSD整批解析门槛；MLSD.swift逐字节未改。整体timer/取消管理同一个Owned，framer等待/握手不会绕过预算。

## 实际证据

3个正向基线后，最终43场景按明确断言全部通过，其中8 ASan。显式IPv4/hostname/IPv6、DNS-only证书、逐字节欢迎/AUTH、多行欢迎、PASV第三方地址均实际成功；implicit/plain两条回归成功。显式控制/数据各TLSv1.3及各一次信任检查，actual peers相同，返回已解析Movie.mkv条目；服务端所有加密模式明文凭据命令0、AUTH/PASS各最多一次。

| 负例 | 结果 |
|---|---|
| 欢迎500/AUTH500/PROT534 | 对应unexpected；USER0，不降级 |
| 控制不信任/错名/过期 | tlsUnverified，USER0 |
| 数据错名/同CA另一张控制不同叶 | tlsUnverified，无列表结果 |
| 234夹带明文/超长欢迎 | invalidReply/limit，USER0 |
| 欢迎/AUTH/控制TLS/数据TLS/最终回复静默 | 按总预算deadline；已建立控制peer EOF均观察，数据未建立时不填数据EOF |
| 上述阶段取消 | CancellationError；本机取消后约0.176–0.659ms返回，非NAS排名/硬实时保证 |
| PASS530/完成426/坏目录条目 | 明确错误，无部分结果 |
| 服务器要求TLS session reuse | 两窗（普通/ASan）dataSessionReused=false、载荷发送0、522并无结果；不能当该服务器已兼容 |

初两个reuse负例的控制/数据服务端使用独立SSLContext，不能用于推断通用复用能力；补充共用服务器SSLContext的正常/强制复用普通及ASan共3窗，正常仍成功、强制复用两窗仍session_reused=false并522，无载荷。全部保留，不能把缓存fixture模型当真实NAS互通。

本批没有实现或建立可验证的跨通道session reuse支持，也未核真实NAS要求/证书轮换/接口切换或所有欢迎形式（严格220/234子集）。实际只见TLS1.3，最低1.2仅配置。ASan最终8窗＋补充1窗核StartTLS.o/Passive.o与运行时，无失效访问报告；detect_leaks=0，非TSan/泄漏或CFNetwork/Network内部竞态穷尽证明。证书alert等窗口不夸大为每个peer EOF都观察；关键静默/取消窗的已建连接已逐项核。

49个自有服务窗均thread join/监听器关闭，源仅内存合成MLSD，无RETR/远端写/真实NAS请求。没有借DSM/Keychain/竞品凭据，无NAS/VPN/系统信任/网络或媒体蜂窝改动。

## 构建、设备及下一步

iOS/tvOS普通Debug arm64动态原型编译/vtool通过，未签名/嵌入/设备执行。移动SHA `f567a4c92a94081b3ad0e33ef102ab2539216cf28f3b60a41553896607148c95`，TVSHA `f922454f38a49636e824746a4381bd618256499382dd335ad90e7dab27cd2200`。375生产App输入与11:09冻结包30/27 Mach-O零漂移，无新App构建/安装/真机功能；13/Pad/TV沿原安装记录。

17:42:39现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable且USB未见，未更新，原DSM域名＋端口实际路线旧项保持。原dirty保留，未建周期任务，无回合后后台执行。

下一FTPS会话复用兼容评估及MLST/NFO读前后版本、真实只读目录源/本机索引事务，再生产协议/凭据作用域/主工程证书策略/同主题UI与逐机核包。SMB严格选根仍FAIL，协商提案/转换及真实SMB3/许可继续独立保留；SFTP、新媒体客户端、在线provider仍未交付。30项14进行中/5待验收/11待开始、114播放格保持，AV/KS链未改。
