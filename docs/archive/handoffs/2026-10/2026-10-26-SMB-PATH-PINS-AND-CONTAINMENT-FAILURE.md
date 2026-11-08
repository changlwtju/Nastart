# SMB目录句柄保留与选根并发失败边界

2026-10-26接[可变区/所有权修复](2026-10-26-SMB-VARIABLE-SPAN-AND-PAYLOAD-OWNERSHIP.md)，[脱敏结果](../../../testing/results/2026-10/2026-10-26-smb-path-pins-containment-failure.json)。原型/失败/审计/包仅在私有指针`/tmp/nastart-smb-path-pins-evidence`。**候选未通过严格所选目录范围验收，不接App。**

## 实际反例

自有只读TEST共享内设置Library/Chosen为所选根、Outside/Chosen为外部兄弟树；没有用户NAS文件/凭据。服务端在首次打开Library后，将其改名并以指向Outside的链接替换Library。旧客户端检查父目录后关闭句柄，最终4次NFO READ均落Outside，成功提交outside-data；路径文本仍为Library/Chosen。只核文本前缀和末端OPEN_REPARSE_POINT不足。

候选一保留每级目录句柄到扫描结束，目录查询复用根句柄、移除重复打开；所有CREATE共享模式只保留READ/WRITE、不含DELETE。反向关闭目录句柄，失败/取消仍由context销毁断连接；最多16个祖先句柄。目录/普通文件类型与reparse属性同时检查。依据微软[CREATE共享模式与重解析标志](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/e8fb45c1-a03d-44ca-b7ae-47385cfd7997)，缺SHARE_DELETE用于阻止遵守共享规则的其他打开执行删除/改名；它不是NAS本地文件系统锁或相对目录句柄打开。

夹具按照请求ShareAccess模拟服从共享规则的改名：旧请求允许改名，新请求阻止，后者真实读取fresh-title且外部READ0。**此分支是共享规则模拟，未用第二个SMB客户端/真实Samba证明锁生效。** 不把配置位与模拟结果写成NAS兼容证据。

候选一服务端本地强制改名仍绕过共享约束，4次外部READ并提交。候选二追加所有祖先同FileId CLOSE POSTQUERY，比较creation/write/change及属性；目录属性由夹具实际打开句柄fstat取值，不按替换后的路径stat。此时强制改名被读后sourceChanged发现，旧索引磁盘/内存/重新加载/持久目录全部保持，但**4次外部READ已经发生，范围要求仍失败**。不继续靠重复检查/缩短预算声称消除TOCTOU。

## 验证与未接受范围

1旧基线＋13候选一＋13候选二共27自有服务窗口，全部finally终止/wait回收。最终13窗的预期观察均成立，其中12窗未读出所选根；强制本地改名1窗明确未通过所选根范围要求，不能写成13/13验收通过。正常/模拟服从共享规则/初始目录链接/末端NFO链接、目录/READ/CLOSE中取消及总截止覆盖；每窗peer关闭、客户端视频READ/写请求0。所有改名/链接只由夹具所有者做，未改用户NAS。

初始目录链接reparse拒绝、0 NFO READ。末端链接在读取前停止、0 NFO READ，但关闭时impacket返回其未规范处理的错误正文而得到unavailable，不能当reparse错误分类完整。取消保留原索引；正常请求所有目录CLOSE均在最后NFO READ之后，根目录只打开一次。最终4 ASan窗核运行时/RawReader对象插桩，无失效访问报告；非TSan/泄漏证明，detect_leaks=0。

NFO字节版本与目录读后检查均为乐观检测，低精度/保留时间戳仍可逃逸。SMB CREATE的路径相对于TreeConnect共享，不能因为保留父目录FileId就假设后续CREATE已经相对该句柄。服务端真实支持的句柄/对象身份访问、重解析行为和原子范围能力须进一步验证；不修改用户NAS共享或权限来绕过本约束，不把“旧索引未覆盖”偷换成“没有范围外读取”。

## 产物与接续

iOS/tvOS普通Debug arm64动态候选编译/vtool通过，未签名/嵌入/设备执行。移动SHA `f53371b7da829d4d93da4acafad97d1e0fa9e7f54fbda7181fd5d5d58b2e4462`，TVSHA `667669934183e12722010b23ee90425bc6f658c31ed3eec05703ab7c25f69a89`；编译不构成功能接受。C依赖与上一批零漂移，累计上游差异10文件；生产App375输入与11:09包30/27 Mach-O零漂移，本批无App构建/安装/设备功能回归。

14:29:04现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable且USB未见，未更新，原DSM域名＋端口实际会话旧项不变。13/Pad/TV沿上批安装记录。无用户偏好/凭据/NAS/VPN/网络配置修改或媒体/蜂窝流量，自有服务全停。

下一SMB保持严格范围未验收：需要真实服务器能力/行为和原子访问策略，及SMB3/加密/guest/重认证/其余解析、许可/签名嵌入；不继续同条件调参。同时推进独立FTPS/FTP传输与有界只读命令隔离，SFTP分开；未授权NAS安装服务或修改共享配置。30项14进行中/5待验收/11待开始、114播放格保持，AV/KS链未改，未创建周期任务。
