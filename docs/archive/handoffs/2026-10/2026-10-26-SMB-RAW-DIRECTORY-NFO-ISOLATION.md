# SMB raw目录、NFO与缺失签名响应隔离验证

2026-10-26，自动承接[服务入口批](2026-10-26-MEDIA-SERVICE-DISCOVERY-AND-ENTRY.md)及[早期协商取消原型](2026-10-26-LOCAL-CORRECTIONS-AND-SMB-PREFLIGHT.md)。[脱敏结果](../../../testing/results/2026-10/2026-10-26-smb-raw-directory-nfo-isolation.json)，原始代码/依赖/日志/fixture文件仅在仓库外，指针`/tmp/nastart-smb-readonly-isolation-evidence`。**没有向Nastart加SMB依赖、没有新App构建/安装或真机/真实NAS SMB请求**；11:09普通服务入口包仍当前，375本地应用输入零变化。

## 实际实验

复制前轮RawSMBProbe与固定C `aedafb2c8742c83188e27841e270fdaad6035d41`（原199文件逐项核同）到新的私有目录，扩Swift raw CREATE/QUERY_DIRECTORY/READ/CLOSE。每次操作独占context/专属poll队列，保留回调目标与读buffer直到context销毁；异步入口取消设标志，在队列检查单调deadline并关闭context。没有暴露远端写操作或序列化真实账户。

高层opendir会累积完整目录且未保留本实验需要的重解析标志，因此本轮直接请求16KiB目录页；最多16次/累计64KiB/256项，格式/数量/未完整EOF失败不返回部分汇总。CREATE仅FILE_OPEN、目录LIST＋READ_ATTRIBUTES或文件READ_DATA＋READ_ATTRIBUTES，显式OPEN_REPARSE_POINT；只读至多64KiB NFO，分16KiB READ，不读视频。逐组件拒绝父级/反斜杠/UNC/控制字符等路径；普通链接/根重解析与DFS负例单列。原型仅列所选根的一层，不是App全扫描适配器、NFO解析器或视频随机读取。

本机独立venv固定impacket0.13.0，SMB仅监听127.0.0.1随机端口、自有fixture账户和文件，share设只读并在服务端拒绝任何写CREATE/WRITE/SET_INFO。外层finally停止自有服务进程组；不启macOS系统共享，不改NAS/用户网络。实际协商dialect为0x0202/SMB2.0.2，即使配置请求2.1也不把它写成已验证2.1/3.x兼容。

## 签名负例与局部修补

固定C副本配置signing required后，去掉认证后响应的SIGNED标记并置空签名，原型仍成功读123项/50001 NFO字节；保留标记但签名置错则拒绝。源码只在SIGNED存在时验签，与本机负例一致。此结论仅归本次固定副本，不能扩大为全部SMB库/版本。

私有`lib/socket.c`增加客户端sign要求、非seal、认证后明文响应缺SIGNED即拒绝的局部检查；NEGO/SESSION_SETUP除外，保留原错签验证。199个C副本仅此1文件有意变化，精确diff/源码摘要已存私有证据。修补后的正常响应仍可读；缺签/错签均在TREE_CONNECT阶段失败、QUERY/READ为0、连接关闭。此前server command hook会被impacket自身改写请求签名标记，故最终另在processRequest调用前/输出后捕获原始字节，才核认证后请求SIGNED；不沿用改写后的标记作为线缆证据。

这只是隔离明文SMB2负例修补，未提交上游/未加入宿主；不能据此宣称SMB3加密、所有异步/重认证分支、真实服务器或分发已通过。

## 最终源码验证（局部签名修补后）

| 用例 | 结果与边界 |
|---|---|
| 普通根目录/NFO | 123项、2数据页＋1结束查询、50001字节NFO/4 READ；视频READ 0，写权限/写命令0；约34.369ms为本机夹具内部耗时，不与NAS或竞品排名 |
| 数量上限 | 限2项，首目录页后limit，NFO/视频READ 0，不返回部分汇总 |
| 畸形页 | 无效NextEntryOffset拒绝，READ 0 |
| DFS | 合成STATUS_PATH_NOT_COVERED即失败，QUERY/READ 0，不追到另一服务器 |
| 目录等待取消 | 服务端已收到QUERY后cancel，20.387ms后CancellationError；实际peer关闭 |
| NFO等待取消 | 服务端已收到READ后cancel，5.724ms后CancellationError；实际peer关闭 |
| 300ms截止 | QUERY等待，实际310.208ms deadline/peer关闭 |
| 文件重解析 | 合成明确REPARSE属性的escape.nfo跳过1项，未请求其内容，其他123项/NFO保持 |
| 根重解析 | 合成明确REPARSE属性的RootLink拒绝，QUERY/READ 0 |
| 正常/缺签/错签对照 | 正常可读；后两者均拒绝，三窗peer关闭，数据/结构保持 |

初版12场景还核父级路径/反斜杠路径在连接前invalidPath、wireCommands0。链接/DFS/畸形状态是本机夹具变体；尤其impacket未在本轮提供完整原生重解析语义，fixture显式设置相应属性，不当真实Windows/Samba越根兼容认证。

每窗比较自有树中文件内容SHA/大小、名称、目录、mtime和链接目标，最终各窗均不变；READ只NFO、未读Outside目标或视频。客户端请求经过服务端审计，最终原始字节记录认证后请求SIGNED，无写请求。没有NAS整库内容审计或实际影片/音字幕/首帧结论。

## 保留失败与未接受项

认证错误两窗：服务端明确STATUS_LOGON_FAILURE/0xc000006d，客户端未及时回传分类，约4秒deadline结束并关闭连接；只一组NTLM挑战/认证、不自动重试密码。两窗同条件无改善已停，不继续盲重试；后续先核C错误响应解析/回调归属。最终签名局部修补不覆盖认证阶段，未用未经重测的结论关闭此项。

初始Swift6的Any非Sendable和rawPDU指针桥接编译失败已保留并修；fixture首启5秒未就绪，finally已停进程，扩初始化窗口后才测试，不作为SMB客户端速度。所有正常/失败结果保留，不以首轮正例覆盖负例。

仍缺：DNS取消/截止、并发回调竞态/内存工具、C传输层整包分配上限、随机读/版本前后复核、真实权限/重解析/DFS兼容、并发改名下原子选根边界、SMB3加密/重认证与许可/动态分发验收。逐前缀检查不是原子NAS快照；不得把它当所有越根竞态已解决。NFO后读版本与旧索引事务尚未接App。

## 双平台隔离编译与接续

局部修补后iOS与tvOS arm64动态framework均编译成功，vtool平台分别IOS/TVOS；未签名/嵌入/真机执行。移动SHA `937e0ff4e717381b802ad67b5b47d762433eb366a52afaf9be0d5434592830c8`，TVSHA `0a277a68b290fb793fe12ff583ca1cc075f61a8578a4f61ceea142d50985c88f`。Swift/本机夹具执行不替代真机或Release/NAS回归。

最终所有自有fixture进程已停，原375应用输入及已安装11:09包保持，不触碰原设备Runner/偏好/凭据/网络。30项14进行中/5待验收/11待开始、114播放格未改；需求编号仅归[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。接续先解决认证失败分类、DNS/竞态/传输上限与SMB3/实际服务器边界，再决定接入；FTP/FTPS/SFTP和新增媒体服务原生客户端仍未交付。
