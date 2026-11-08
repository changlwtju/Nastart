# SMB命令分配边界与错误路径所有权

2026-10-26继续[NFO版本/索引事务](2026-10-26-SMB-NFO-VERSION-AND-INDEX-TRANSACTION.md)，[结构化结果](../../../testing/results/2026-10/2026-10-26-smb-variable-span-memory-ownership.json)。私有原型、冻结输入、逐文件补丁、服务端wire审计、ASan报告及产物指针`/tmp/nastart-smb-variable-span-evidence`。本批无生产App改动/构建/安装。

## 原因和修复

此前256KiB传输帧上限只限制帧前缀，不能限制内部字段。三窗基线复现：READ/CREATE在短帧内声称1MiB可变区，旧解析分别约1820.416/1809.443ms直到总截止；QUERY_DIRECTORY越界路径先free(rep)但未清pdu->payload，context销毁再free，ASan明确double-free且进程中止、无JSON。基线报告完整保留，不能把工具JSON解析失败当无内存问题。

仓库外新增内部command剩余范围计算：按payload_offset、当前接收位置、next_command或实际帧尾核算；添加FIXED接收向量前检查固定长度，命令解析返回后/分配VARIABLE前检查其长度。拒绝把下一个复合命令的字节当本命令数据。

CREATE在uint64范围检查context offset/length后才做旧int偏移算术，拦截大偏移回绕。READ要求精确StructureSize及固定体长度、数据范围位于本命令、长度不超过请求传入接收向量容量；上层16KiB检查仍在。QUERY_DIRECTORY改用不溢出的当前命令范围，两个早退free均先置空payload所有者。NEGOTIATE/SESSION_SETUP security span不再把整帧截成uint16，也不跨复合命令。原签名、ERROR、DNS数字连接、单次授权回退和NFO检查保持。

相较NFO批有7个依赖文件变化：include/libsmb2-private.h、socket.c、smb2-cmd-create/read/query-directory/negotiate/session-setup.c；与固定上游相比累计10个有意变化文件（前批libsmb2.h/libsmb2.c/error.c仍在）。依赖尚在私有原型，未分发/嵌入App；补丁需后续正规集成、许可与真实兼容复核。

## 验证范围

最终24窗全通过，其中8 ASan；包含正常/持久目录、第二NFO失败、关闭中取消，及READ超实际帧/超请求/短StructureSize、目录越界/偏移进头部、CREATE超帧/偏移回绕、协商/会话安全块超界、TREE_CONNECT/CLOSE固定体被截短、READ跨next_command。所有异常按unavailable早退并保持旧索引四种核对，不把协议错报成密码错。异常窗本机约1.747–32.253ms，均小于测试500ms阈值；只是本机反例消除，非NAS性能排名。

8 ASan窗核socket/query-directory/read对象插桩及运行时，未报告失效访问；detect_leaks=0，未做TSan或穷尽内存审计。所有24最终窗peer关闭，源文件保持（第二NFO窗仅自有夹具预定改写），客户端视频READ/写请求0。3基线＋24最终服务窗口均finally终止/wait回收，独立catalog suite移除。

这仍不是“全部解析分配已安全”：SMB3加密/压缩转换、3.1.1协商上下文、NTLM/SPNEGO解析及其他未用命令/内部对象预算、真实Windows/Samba/NAS、并发路径替换与重解析需继续核对。合成明文SMB2.0.2包不当实际SMB3兼容证明；协议级错误通用unavailable的用户可读分类仍待生产适配。

## 构建、设备与接续

iOS/tvOS普通Debug arm64动态原型及vtool通过，未签名/嵌入/设备执行。移动SHA `d124309b844bb6a0a2d5a46c81946e46b4c457974cc5b561d7c8bbf74a1581d3`，TVSHA `f5f6457b6069cca1d62f15cbdb08a72fd9b2c47cd6f1b8ce40c041f774610a24`。375本地App输入及11:09冻结包30/27 Mach-O零漂移；沿上批13/Pad/TV安装记录，本轮无设备功能回归。14:00:37现场18/iPhone19,7/iOS27.0仍CoreDevice unavailable且USB未见，未更新，DSM原域名路线旧项不变。

未取用户凭据/改设备偏好、NAS/VPN/网络或启媒体/蜂窝。30项14进行中/5待验收/11待开始、114播放格保持，不改AV/KS链、不新建周期任务。下一并发路径替换/原子选根，再其余解析、真实SMB3/加密/guest/重认证、许可/签名嵌入与生产SMB适配；FTP系列和新增媒体客户端仍未接。
