# SMB认证错误、报文边界与取消内存验证

2026-10-26，承接[raw目录/NFO隔离](2026-10-26-SMB-RAW-DIRECTORY-NFO-ISOLATION.md)，不重复前两窗没有新证据的认证重试；先离线核对响应/解析，再换规范错误正文和诊断条件验证。[脱敏结果](../../../testing/results/2026-10/2026-10-26-smb-auth-error-receive-bounds.json)，原始源码/报文/测试日志/构建只留仓库外，指针`/tmp/nastart-smb-auth-frame-evidence`。**全部为仓库外原型；没有向Nastart接SMB、没有新App构建/安装/播放或NAS配置操作。**

## 原失败定位与实际修补

原impacket0.13.0服务夹具返回STATUS_LOGON_FAILURE时仍构造SESSION_SETUP正文。离线序列化17字节：其SecurityBufferOffset/Length落在ERROR布局ByteCount位置，解读为589896字节，但固定正文后实际只有9字节；旧C错误解析不核对实际帧，等待缺失内容直到4秒截止。服务端有失败状态不等于客户端已收到可正确解析的认证错误，不能将前两窗直接定性为NAS认证慢。

规范依据：[Microsoft SMB2 ERROR Response](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/d4da8b67-c180-47e3-ba7a-d24214ac4aaa)定义ByteCount为ErrorData长度；[发送错误响应](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/41295064-be3f-41dc-9aa5-f68545f945f0)要求失败正文使用该结构。本轮夹具将规范ERROR与原畸形正文分开测试，未给真实NAS加兼容分支或信任畸形状态。

第二个问题在Swift等待层：规范错误已通过C回调status=-61/NTSTATUS LOGON_FAILURE，但C关闭连接后的继续read触发EBADF，service返回-1，旧等待层把已完成的认证错误盖成unavailable。Darwin errno -61本身是连接拒绝，不能据此分类密码错误。当前在回调现场保存原NTSTATUS，只在已完成且status非0时保留该终态；成功回调之后的传输失败仍失败，不吞错。按连接阶段的明确NTSTATUS区分认证拒绝，文件权限拒绝仍为独立远端错误；不清除或循环尝试凭据。

局部C检查：帧前缀须64..262144字节，在可变负载分配前拒绝越限；NextCommand须对齐且位于当前帧剩余范围；ERROR ByteCount须不超过当前命令余量，在分配/等待前检查。继承前批缺失SIGNED拒绝；固定199个C文件仅`lib/socket.c`和`lib/smb2-cmd-error.c`有意变化，精确diff及所有输入摘要归私有证据。帧上限是此目录/NFO原型的局部政策，未当所有SMB3/大SPNEGO或视频读取的兼容上限。

## 最终普通原型测试

18个服务合同场景均保留源文件比较和连接关闭证据，写请求/视频READ/Outside目标READ为0；正例仍123项/2数据页＋结束查询、50001字节NFO/4 READ。不是递归全库扫描、应用索引事务或真实NAS速度验收。

| 场景 | 最终结果 |
|---|---|
| 规范LOGON_FAILURE | authenticationRejected，3.595ms，目录/READ 0；旧规范正文诊断窗先证callbackDone=true后被覆盖，失败保留 |
| 规范ACCOUNT_DISABLED | authenticationRejected，3.526ms，保留原NTSTATUS，不泛称密码错误 |
| 原畸形登录失败正文 | 3.529ms拒绝为unavailable/协议失败，未冒充认证拒绝，未等4秒 |
| 认证阶段静默 | deadline，311.237ms；不把超时变成密码错误 |
| 文件ACCESS_DENIED | 远端权限错误，未改为认证错误 |
| ERROR超长ByteCount | 在错误固定正文解析中拒绝，未等声明长度 |
| 复合包NextCommand越帧 | 读完头部即拒绝 |
| 普通、数量上限、畸形目录页、DFS | 正例/拒绝/不返部分汇总与前批边界保持 |
| 缺签、错签 | 均在目录/READ前拒绝，正常签名正例仍可用 |
| 目录/READ取消 | 本窗取消后2.216/21.589ms返回CancellationError，实际peer关闭 |
| 300ms截止 | 311.700ms deadline/peer关闭 |
| 带明确标记的文件/根重解析 | 文件跳过/根拒绝；此为合成属性，不代真实Windows/Samba边界 |

另5个真实TCP前缀场景：0、63、262145、0xffffffff均快速拒绝并peer关闭；恰在262144上限但不送正文时仍按300ms预算等待（实际307.939ms）并关闭。后者不等于已经证明完整最大帧所有字段可用。所有时间均本机loopback内部测量，不与NAS/竞品排名。

## AddressSanitizer与并发取消

独立macOS AddressSanitizer构建，已核动态运行时链接及C socket.o的ASan符号，非仅普通程序退出0。17个测试进程共28次连接操作：一窗12个context均进入READ等待后取消6个，得到6取消/6成功且12个连接关闭；另16个不同取消时点，13取消、3读取先完成，全部按自有context关闭。包括取消先到、读取先完成及接近边界时两种实际结果，未把发出cancel当取消已生效。

各窗源树SHA/大小/名称/mtime/目录不变，无媒体/写请求，ASan未报告失效访问或越界。它不是ThreadSanitizer、泄漏审计或穷尽竞态证明；不扩大为完整并发安全验收。诊断环境仅这些主机原型，未注入手机/TV正常App。

## 构建、设备与资源收尾

最终原型iOS/tvOS普通Debug arm64动态framework均编译、vtool平台核对通过；未签名、嵌入或真机执行。移动SHA `58a7ca36ca6901c56406201079444e3d1dc20562c8488cfcd858c5830068297c`；TVSHA `0a859db0e2d05907cda0036c1873f0b45fe5ef182c1b1011dc80ed4c4488e027`。

应用HEAD/dirty保持，375本地应用输入和移动/TV所有冻结二进制零漂移；上批11:09普通包及逐机11:10–11:11安装记录仍为最后已验证安装，本批没有重新冒称真机回归。只做一次主机设备清单核对：iPhone18仍unavailable，未安装；其保存域名＋端口和实际固定域名旧问题保持。

全部自有SMB夹具进程已停、TCP线程/连接关闭；不操作原设备Runner、偏好、Keychain、Wi-Fi/VPN或NAS。前批两窗4秒失败、规范错误修补前unavailable、所有旧正/负例均留原目录。原型C编译既有整数精度警告保留，不以成功构建抹去；本轮记录脚本一次SyntaxError在执行前失败，修正后才核平台/ASan证据，不是产品故障。

## 接续范围

同步getaddrinfo位于C连接启动、进入poll前；本轮都用literal loopback，未测DNS取消或将其当已解决。下一先把主机名解析从阻塞C入口隔离并保留原服务器/账户身份，再核DNS/IPv6/多地址取消和截止。还缺SMB3加密/重认证、全部C可变字段分配审查、真实服务器权限/重解析/DFS、并发目录改名的原子选根、NFO读后版本与旧索引事务、签名嵌入/许可分发及App界面/真机接入。帧及ERROR局部上限不是所有解析内存已证明有界。

30项14进行中/5待验收/11待开始和114播放格保持，不新增/关闭编号；需求只归[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。FTP/FTPS/SFTP和新增媒体服务原生授权/库/播放仍未交付，本轮未改AV/KS播放链。
