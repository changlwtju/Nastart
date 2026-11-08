# FTP MLSD有界条目解析与整批拒绝

2026-10-26自动接[实际peer/数据TLS](2026-10-26-FTPS-PASSIVE-PEER-AND-DATA-TLS.md)。[结构化结果](../../../testing/results/2026-10/2026-10-26-ftp-mlsd-bounded-entry-parser.json)，源码/输入/证书私钥/原始返回与产物仅在私有指针`/tmp/nastart-ftp-mlsd-evidence`。仍未修改生产App或接FTP媒体库。

## 实现

私有FTPPassive新增MLSDListing/FTPDirectoryEntry，完整EOF与226之后才解析/返回条目。按照[RFC3659](https://www.rfc-editor.org/rfc/rfc3659.html)区分facts与pathname、字段名大小写及cdir/pdir；不去掉文件名首尾空格，不做URL百分号解码。中文/空格/字面%与%2e%2e保持原名；协议后续必须直接使用FTP路径语义，不能套DAVPath反复解码规则。

file/dir映射为文件/目录；cdir/pdir即便声明绝对父路径也只忽略、不遍历。未知类型、符号链接扩展、没有type/事实的记录拒绝整批，不猜文件类型或退回歧义LIST；服务器合法不提供type与非法语法分开为unsupportedEntry。共享命名空间/管理员并发替换不能由这组文本校验保证，不能当原子选根通过。

facts先验证原始ASCII名称、再做大小写折叠；同名facts重复或同目录名字重复/Unicode规范等价冲突均拒绝，大小写不同名称保留。Size为可选非负Int64，拒绝溢出；Modify为可选UTC日历时间，检查真实年月日时分秒及小数部分、保留原串；Unique仅原样保留可选不透明值，不当影片ID或单独内容版本证明。缺Size/Modify不伪造0或当前时间，后续NFO读取必须另建立可确认版本条件。

预算32KiB载荷、1024字节/行、256条目、16个特殊目录、32个facts/条、255字节文件名，key/value分别64/512字节；小数秒至多9位。这些是本客户端原型的保守子集，不把RFC允许的更长字段或无facts形式说成服务器违规。空目录可明确返回空；任意晚出现的坏行抛错，不能返回此前好条目的部分替换。

## 证据与保留反例

初期49契约＋9网络窗口通过后，额外构造`Key`发现先lowercased可把非ASCII字段误接受；原返回/原parser保留，补原始ASCII判断。最终50解析契约（含6 ASan）及9实际网络窗口（含2 ASan）全部按明确断言通过，不将此批替代上批42个传输场景。传输/被动端口代码与上批逐段一致，仅载荷完成后接解析与结果类型。

覆盖中文、首尾空格/空白文件名、字面百分号及encoded-looking名称、大小写不同名、UTC闰日/小数、缺版本字段、Int64上限/溢出、256/257条、总量/行/名字上限、非法UTF8/NUL/CRLF截断、斜杠/反斜杠/点路径、规范等价重复/重复facts、未知类型/链接、特殊目录跳过预算。已有好记录后再出现不安全名字时返回错误、无entries。实际隐式FTPS和明确plain可解析列表；链接/重复/缺type/晚坏行整批拒绝，所有9最终网络窗均见控制及数据peer EOF。

ASan最终8操作核MLSD.o插桩和运行时，无失效访问报告，detect_leaks=0；非TSan/泄漏证明。初9＋最终9共18服务窗口均join/关闭监听器，独立合成MLSD只发会话/列表命令，0 RETR/写请求。没有新NFO读取、递归库、Store事务或播放测试，不继承SMB旧索引证据到尚未接的FTP适配。

## 构建、设备与接续

iOS/tvOS普通Debug arm64动态原型编译及vtool通过，未签名/嵌入/设备执行。移动SHA `dd167b072602aeb8cb6712e6897b56b91d6d80f053c857d89f51077eb03530d8`，TVSHA `a2cf425f35cdb0a52b03cdb1a0a5ab6d910796f26fe2e50ec79ef579b756e16e`。375生产App输入及11:09冻结包30/27 Mach-O零漂移，无新App构建/安装/真机功能回归。

17:31:00现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable、USB未见，未更新；13/Pad/TV沿原安装记录，不把旧包记录当本轮回归。原DSM域名＋端口实际路线旧项保持；无NAS/VPN、系统信任、偏好/凭据、媒体/蜂窝改动。

下一显式FTPS安全升级/实际peer及session reuse、MLST/NFO读前后版本、真实目录源/本机索引事务，再生产来源/凭据作用域/主题UI与逐机核包。解析失败应保留为目录扫描错误，不映射成可忽略的invalidMetadata而覆盖旧库。SMB严格协商/转换/真实兼容与原子范围FAIL独立保留；SFTP/新增媒体客户端/在线provider仍未接。30项14进行中/5待验收/11待开始与114播放格保持，AV/KS链未改，无周期任务和回合后后台执行。
