# FTP/隐式FTPS被动对端绑定与实际数据TLS

2026-10-26接[控制TLS/取消](2026-10-26-FTPS-FTP-CONTROL-TLS-AND-CANCELLATION.md)。[结构化结果](../../../testing/results/2026-10/2026-10-26-ftps-passive-peer-and-data-tls.json)，源码/证书私钥/原始配置/审计/失败及产物仅在私有指针`/tmp/nastart-ftps-data-peer-evidence`。**仍未接App；新后端只支持隐式FTPS或明确allowPlaintext的FTP，显式AUTH TLS数据升级不在本批接受范围。**

## 实现及接受范围

先尝试URLSessionStreamTask.captureStreams，实际已交出Input/OutputStream；打开前/后6窗socketNativeHandle属性均nil，无法可靠核对实际对端。停止此路径、留源和全部结果，原Control.swift恢复与上批逐字节一致；不把配置hostname当已观察实际IP。

新独立FTPPassive用系统Network.framework建立控制/数据通道。控制ready及认证后取currentPath.remoteEndpoint，必须是已解析IPv4/IPv6；数据连接只使用该数字IP，禁止再次按原hostname解析。TLS名称仍用原始host；localhost证书只有DNS SAN、无IP SAN的独立夹具成功，证明数据没有误用数字IP做名称验证。每个TLS通道独立验证证书链/有效期/原主机名，数据另要求与已核控制叶证书DER完全一致；即使另一张证书同CA、同主机名也拒绝。验证结果未明确存在时，不读取数据。

EPSV优先，保留数字对端、只取有界响应端口。仅明确allowPASV且IPv4、EPSV返回500/502/522时允许一次PASV；严格解析六段但不使用返回的主机地址。声明203.0.113.7的夹具仍连控制实际127.0.0.1。畸形成功回复/421/TLS失败不转PASV，不降级明文/匿名或换密码重试；PASS最多一次。原型保守拒绝小于1024或等于控制端口的被动端口，特殊老设备兼容尚待评估。根据[RFC2428](https://www.rfc-editor.org/rfc/rfc2428.html)处理同控制对端的扩展被动连接；[RFC4217](https://www.rfc-editor.org/rfc/rfc4217.html)区分控制协商与数据TLS，两个通道实际握手证据分别记录。

控制回复继承1024字节/行、16KiB及128行/回复、128KiB总量；150/226合并接收时保留缓冲，等数据EOF后才消费226。数据每读最多4096字节、总32KiB，UTF8/CRLF/NUL边界及最终226全部满足才返回52字节合成MLSD载荷摘要；4xx、缺完成回复、超量和断行都不返回部分结果。尚未解析MLSD事实/条目，不能据此称目录媒体库已支持。

独立全任务timer和用户取消会取消全部自有NWConnection；waiting与failed均终止本轮，不restart。初版将waiting当可继续，证书拒绝虽挡住后续操作却等待总预算；首41窗中的8信任负例及明文数据/端口拒绝10窗保留，修复后明确证书错误或连接错误快速返回。后41窗及追加明确数据叶验证后的42最终窗分别留档，不混淆源码版本。

## 实际验证

最终42场景经独立断言全过，包含6 ASan窗；早4正向＋两组41窗＋6 capture均保留，本批共134服务窗口全停止/线程join/监听器关闭。ASan实际共18窗，最终6窗核Passive.o/运行时无失效访问报告；detect_leaks=0，非TSan或泄漏验收。

| 场景 | 结果 |
|---|---|
| 隐式FTPS、localhost、IPv6、DNS-only证书 | 控制/数据实际TLSv1.3、两次独立信任检查、数据数字peer等于控制peer，完整52字节摘要成立 |
| 明确允许plain | 成功，2条明文凭据命令单列，不计为加密通过 |
| plain未明确允许、explicit、根注入 | TCP接受0，先拒绝；不拿旧explicit控制结果当新数据能力 |
| PASV第三方地址 | 忽略声明主机、连实际控制peer；禁止回退/非法字段或端口时数据接受0 |
| 数据证书不信任/过期/错名/同CA另叶 | tlsUnverified，数据应用载荷发送0，无明文回退 |
| 控制证书拒绝 | USER/PASS0，快速tlsUnverified |
| PROT后发送明文数据 | TLS协议拒绝，不当列表返回 |
| 426、无226、完成回复静默 | unexpected/closed/deadline，无部分结果 |
| 数据超量、缺CRLF、被动端口拒绝 | limit/invalidReply/connection refused，无结果 |
| 数据TLS/读取/完成回复中取消与静默截止 | 有界结束，相关取消/截止窗控制和数据peer EOF均观察到 |
| 合并150/226、逐字节数据 | 完整等待EOF/226后成功 |
| 登录530 | 仅一次PASS，无后续目录命令 |

证书失败时服务端收到TLS拒绝alert，部分窗口未独立观察peer EOF，结果如实保留，不能称所有窗peer EOF均成立。取消/截止的关键静默窗均等待服务恢复观察后确认两通道EOF。实际TLS只见1.3，最低1.2仅配置。session reuse未实现，要求控制/数据TLS恢复绑定的NAS仍未兼容；接口切换/真实设备/真实NAS/IDNA等尚未验。

## 构建、设备与接续

iOS/tvOS普通Debug arm64动态原型/vtool通过，未签名/嵌入/设备执行；移动SHA `ba0fdc92af7b64ebc5eb0e30e275a79b0da01d7671825d568519a88007bc6732`，TVSHA `d6141c19f886899376dc64ed7e8587750b457ce8a8634ed7fc45e2088489f14d`。375生产App本地输入及11:09冻结包30/27 Mach-O零漂移，无App构建/安装/真机功能回归；13/Pad/TV仍沿上批安装记录。

17:18:12现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable、USB未见，未更新，原DSM域名＋端口实际路线旧项保持。没有读用户凭据/Keychain、改系统信任、NAS/VPN/网络或播放/蜂窝；端点均自有loopback，MLSD载荷为内存合成，0 RETR/远端写/真实NAS请求。

下一显式FTPS的安全升级/实际对端保持及session reuse，再MLSD/MLST条目语义、NFO版本和旧索引事务、生产来源/凭据/主题UI/逐机核包；普通FTP必须保留明确选择。SMB原子选根仍FAIL及严格协商/转换等未完成项继续独立保留，不能以此批关闭。30项14进行中/5待验收/11待开始、114播放格不变，AV/KS链未改，无周期任务或回合后后台执行。
