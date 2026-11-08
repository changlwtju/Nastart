# SMB NFO版本核对与旧索引事务隔离

2026-10-26，接[认证前候选回退](2026-10-26-SMB-PREAUTH-ADDRESS-FALLBACK.md)。[结构化结果](../../../testing/results/2026-10/2026-10-26-smb-nfo-version-index-transaction.json)，原型、冻结源码、协议审计、失败、产物和原始设备信息仅在仓库外，指针`/tmp/nastart-smb-nfo-version-evidence`。本批无App源码/依赖修改、App构建/安装或真机功能回归。

## 接受实现

原先目录记录到CREATE只比较NFO长度，READ后直接CLOSE；同长度改写可能混入。新原型从FILE_DIRECTORY_INFORMATION保留原始64位creation/last-write/change FILETIME、大小与属性，打开时逐项核对。last-write/change为0视为版本信息不足；不把未提供版本当稳定版本。

全部NFO字节先留本次私有暂存，仍每次READ至多16KiB、单NFO至多64KiB。读取完成，在**同一FileId**的CLOSE请求设置POSTQUERY_ATTRIB，复制固定长度CLOSE响应；成功且响应明确有POSTQUERY_ATTRIB标志后，再与CREATE的creation/last-write/change、EOF和属性逐项比较。未返回属性标志为metadataUnavailable，变化为sourceChanged；任一失败/取消/截止不返回整批暂存结果。不额外引入QUERY_INFO或修改C解码器；继承上一批4个C文件私有修补，本批C源码零变化。

访问时间可能因读取变化，故不比较last-access；allocation size不是内容版本，亦不比较。原FILETIME直接比较，不在客户端截断或转换浮点。依据微软[接收CLOSE请求](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/f2b4183a-29c2-4fc0-a5de-fe290408f68c)及[CLOSE响应](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/c0c15c57-3f3e-452b-b51c-9cc650a13f7b)，只有明确返回标志才使用属性。

这是**乐观版本检查**，不是文件锁、原子文件系统快照或内容证明。低精度/保留时间戳的同长度修改、服务端伪报、句柄所指对象与当前路径被替换等不能由这组属性完全识别；选根并发改名/重解析问题仍开放。不得将此批描述为已彻底排除读中变化。

## 旧索引事务

仓库外复制现有NetworkMedia的21个生产/测试/清单输入，逐个摘要与工作区一致；唯一新增为测试工厂，令现有内部目录初始化器指向本批私有目录和独立UserDefaults suite。未改NetworkLibraryStore/scanner/NFOReader实现。

私有FixtureBridge将已完整核对的raw结果转成夹具已知的平级目录及NFO数据，再交给现有store.scan。它不是可接任意NAS的生产SMB适配器，不支持真实递归目录，也不改变生产来源URL模型。种入previous-good旧库后，对每个失败检查磁盘JSON逐字节、内存完整快照、重新实例化加载、可选TV持久连接目录值。失败全部保持；成功才替换为fresh-title。

后续修正夹具排序不确定性：以第一实际读取的NFO为基准，改写第二个不同NFO。普通、带持久目录、ASan三窗均先成功完成第一份，再在第二份读后失败；实际各8次READ、2次POSTQUERY CLOSE，旧库四种核对均成立，不能用早期恰好先读b.nfo的窗口替代这条证据。持久目录是在macOS独立suite验证的同一存储逻辑，不是tvOS真机证据。

## 验证与保留失败

最终主/补充共34执行窗口，原驱动30断言通过、4断言失败均保留；另有前期12个基线/夹具定位窗口（8拒绝、4成立）。按明确替代关系选29最终场景：27原断言通过，截断和未知版本两窗按原协议/旧库证据独立复核为预期安全失败，审计不覆盖原始断言结果。不得写成“全部自动测试零失败”。

| 核对 | 实际结果 |
|---|---|
| 稳定内容、可选持久目录 | 成功提交fresh-title；视频READ/写请求均0 |
| 仅last-access改变 | 成功，不误判内容版本变化 |
| 打开时creation/write/change/大小/属性与目录不一致 | sourceChanged，0 NFO READ |
| 关闭时上述五种属性分别变化 | sourceChanged，旧库不变 |
| 实际同长度改写/增长 | 自有服务端在第一READ后修改文件并推进mtime；读后拒绝，不发布暂存内容 |
| 实际截断 | 第二READ返回成功但数据为空，malformedPage；不等到提交、不覆盖旧库 |
| 第二NFO失败 | 第一NFO已完成也不提交部分替换，普通/持久目录/ASan成立 |
| 缺POSTQUERY标志/未知版本 | metadataUnavailable；不把全0或未标有效的属性当版本 |
| 关闭权限错误 | remote失败，旧库保持 |
| 关闭等待中取消/总截止 | CancellationError/deadline，peer关闭且旧库保持；普通取消后约16.178ms，本机测量非NAS排名 |
| 原始impacket CREATE | 未填ChangeTime，读前拒绝；不当真实服务器兼容失败 |

初期夹具问题：impacket0.13.0向CREATE的非wire字段LastChangeTime赋值，实际ChangeTime保持0；原CLOSE还没有设置属性有效标志、且关闭后按路径stat。夹具已用打开句柄fstat取关闭前属性，并正确填标志和ChangeTime。首次修正用stat浮点子秒而原目录/CREATE沿stat元组整秒，严格比较仍正确拒绝；查明代码差异后统一夹具自身表示，客户端不做精度降级。两轮拒绝全部保留，未盲调预算/容错。

主窗openSize夹具误用了CLOSE字段EndofFile给CREATE（正确EndOfFile），导致断连接，修正后独立窗在READ前拒绝。驱动另两次截断原预期EOF错误，但实际服务器返回空数据成功；未知版本应为metadataUnavailable，原辅助断言写成sourceChanged。两类按原数据复核，保留失败、不反复重跑同条件。

ASan实际6窗口（含较早第二文件窗口），核RawReader/socket对象插桩与运行时；无失效访问报告，detect_leaks=0，非泄漏/TSan/穷尽竞态证明。只有自有夹具做预定改写；所有非改写窗的内容SHA/大小/名称/mtime/结构保持，改写窗明确归夹具所有者。所有客户端视频READ/写请求0。

## 产物、设备与收尾

iOS/tvOS普通Debug arm64动态原型编译及vtool平台核对通过；未签名/嵌入/在设备执行。移动SHA `a7f33961b19037b520399d4201836c5eae44544e93c66df83cdede9a765029df`，TVSHA `81aa96f236c81c2c6febf2a3ec035b3812a3645d229ec077981c62d8af84d1b9`。生产App375本地输入与11:09冻结包所有30/27 Mach-O零漂移（不是完整依赖闭包）；13/Pad/TV沿原11:10–11:11覆盖安装记录，本批无新核包回归。

13:48:42现场CoreDevice与USB枚举：iPhone18/iPhone19,7/iOS27.0仍unavailable，USB未见目标UDID，未更新；实际DSM原域名＋端口路线旧项仍未解决，不继承其他设备结果。此批未碰设备偏好/凭据、媒体/蜂窝、NAS/VPN/网络配置；无恢复网络动作需求。

46个自有服务窗口均在finally终止且wait回收；独立UserDefaults suite随probe退出移除，原始索引仅留私有证据，无后台服务或周期任务。30项14进行中/5待验收/11待开始、114播放格保持；本批未改AV/KS链。

下一先核并发路径替换/选根原子边界与其余C解析分配，然后SMB3加密、guest/重认证及真实Windows/Samba/NAS；补取消、分发许可、签名嵌入和生产适配后再接App及逐机核包。DNS daemon初始化内部/接口权限和后续答案仍有边界；FTP/FTPS/SFTP、新增媒体服务原生授权/库/播放和在线provider不因本批改变交付状态。
