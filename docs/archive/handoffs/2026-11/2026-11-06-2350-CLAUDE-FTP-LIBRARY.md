# Claude（本地会话）：FTP/FTPS 媒体库接入与 iPhone 18 安装

2026-11-06 23:50（Asia/Shanghai）。接 [上一份交接](2026-11-06-2130-CLAUDE-SECURITY-ENGLISH-STACK-REVERT.md)。

**授权**：用户本轮明确要求把最新包装到 iPhone 18，并按“先 FTP 再 SMB”开工。iPhone 18 只做了安装，没有启动或测试。TV 没有操作。

**没有提交，没有改共享状态。**

## 已完成

- **通用来源层**：`WebDAVScope(address:)` 仍只接受 HTTP(S)，服务发现和 File Station 不受影响。新增 `init(storageAddress:)`，保存的媒体库地址可以是 `ftp://`（明文）、`ftpes://`（显式 FTPS）、`ftps://`（隐式 FTPS）。协议由地址决定，统一在 `networkStorageSource` 和 `networkMediaReader` 里选择，索引和 Keychain 格式不变。
- **FTP 客户端**：把登录和传输从 `FTPReadOnlyClient.run` 抽到 `FTPControlSession`。新增 `FTPLibrarySource`，一次扫描只登录一次，密码被拒不重试。媒体库扫描的目录上限放宽到 5 万条、8 MiB，符号链接等特殊条目跳过，不跟随。
- **播放**：`WebDAVPlaybackSession` 改为接收 `NetworkMediaByteReader`。`FTPMediaResource` 每次读取单独登录，先核对大小和修改时间（文件变了就报失效），再用 `REST`+`RETR` 读取，所以一次定位就要重新登录一次。类名暂未改。
- **界面**：添加页新增“添加 FTP / FTPS”，SMB 仍显示未开放。默认选 FTPS；选 FTP 时显示明文警告；连接详情显示协议类型。英文文案已加。
- **测试**：新增本地夹具 `ftp_media_fixture.py` 和 `FTPLibrarySourceTests`（7 项）。

## 验证结果

| 项目 | 结果 |
| --- | --- |
| `NetworkMedia` 测试 | 312 项全部通过（多次运行） |
| iPhone 13 表单 | 通过：三种协议切换、默认端口、明文警告 |
| iPhone 13 连 NAS 关闭的 21 端口 | 能提示失败；当时是通用文案，之后改成专门提示，新文案未上真机看 |

六配置全部 BUILD SUCCEEDED（日志在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/nas-1106/six/`）；`NonPlaybackPolicyTests` 193 项，跳过 1 项，0 失败。TV 只构建。

## 未验证

- **真实 FTP 服务器：完全没测。** 2026-11-06 探测 NAS（`private-host-2.example.invalid`）：21、990 拒绝连接，445、5005、5006 开放。没有登录，也没有改 NAS 设置。
- **最大风险**：客户端要求服务器在 FEAT 里声明 `UTF8`、`MLST`、`TVFS`，否则直接报不支持。群晖的 FTP 服务是否满足不知道，开启后才能确认。
- **自签名证书**：FTPS 严格校验证书和主机名。用局域网 IP 或自签名证书连接会被拒绝，这可能是家用 NAS 的常见情况。
- **真机全流程**：添加 → 选文件夹 → 扫描 → 播放都没有在设备或模拟器上跑过。局域网测试服务器被权限拦截（Expose Local Services），没有绕过；模拟器访问权限请求用户未响应。
- **FTP 下的海报**：每张图单独登录，首次加载可能偏慢，没有测量。
- **FTPS**：新增的 `FTPLibrarySource` 和 `FTPMediaResource` 只用明文夹具测过。TLS 路径只有原有 `FTPClientIntegrationTests` 覆盖。

## 其他发现

- `TransportIntegrationTests.testArtworkRealRedirectPermissionByteBoundsAndCancellation` 偶发卡死（8 次全量运行中有 2 次卡住，其中 1 次定位到这项，另 1 次没有定位）。它测的是 WebDAV 海报，FTP 改动没有碰这条路径，但没有用旧基线确认是否本来就有。Mac 上有 10 月 27 日和周二残留的 `xctest` 进程，可能是同类问题，没有处理。
- iPhone 13 测试窗口的后台进程在收尾前退出（退出码 144，原因没查），此时走查已完成。之后已清理 8102 的 iproxy 并放了 STOP 文件。

## SMB：尚未开始

10 月原型基于 libsmb2（LGPL 2.1），打了约 10 个文件的补丁，放在私有证据目录，没有入库。尚未决定用它还是用 Swift 重写只读客户端。用户“开工到 SMB 时再确认”的两件事：实现方式和许可；放宽严格选根。

## 请 Codex 处理（如果用户安排）

审查集成 `FTPControlSession`、`FTPLibrarySource`、`WebDAVPlaybackSession`、`Models`、`LibraryIndex`、`LibraryViews`；共享状态里加入 FTP 已接入但未经真实服务器验证。

## 最终包

dylib SHA-256 前 16 位 `6607747943f4c2d3`（含 FTP）：iPhone 13、A16 iPad 已保留数据安装。

iPhone 18：2026-11-07 早上通过 Wi-Fi 更新到同一个 `6607747943f4c2d3`（含 FTP，日志 InstallComplete），只安装，没有启动。描述文件 2026-11-08 09:08（+08）到期。

## 2026-11-07 早上复查

用户发来 DSM 截图：FTP（无加密）已勾选，FTPS 未勾选；SMB 已启用。不登录探测 `192.0.2.2`：21、990 仍拒绝连接（间隔约 20 秒测了两次），445 开放。截图看不出是否点过“应用”。真实服务器仍未测。

## 2026-11-07：FTP 真实能力

NAS 点“应用”后，21 端口开放。不登录发 FEAT：有 `UTF8`、`MLST`、`TVFS`、`MLSD`、`REST STREAM`、`AUTH TLS`，满足客户端要求。登录和全流程仍未跑（要用户输入密码）。SMB 见 [SMB 交接](2026-11-07-0700-CLAUDE-SMB-LIBRARY.md)。

## 2026-11-07 09:55：真实 NAS 的 501

用户填对 21 端口后报“拒绝本次操作（响应 501）”。不登录向 NAS 发 `OPTS MLST` 得到 `501 OPTS command is not defined for MLST.`，FEAT 中 `type/size/modify/unique` 都已带 `*`。

- **推断：** 客户端先过 PASS 230、TYPE 200 才发 OPTS，所以用户账号登录大概率已成功。App 没有记录 501 来自哪条命令，这点未直接确认。
- **修复：** 四个事实都已激活时跳过 OPTS（`FTPFeatureReply.requiredFactsAreActive`）；否则仍发送并要求 200。夹具增加群晖模式，新增 2 项测试。FTP 相关 44 项通过，全量和六配置未跑。
- **包：** dylib `84b0816ab97a7c30`，iPhone 13 已保留数据安装（InstallComplete），未启动；iPhone 18 未装。
- **未验证：** 真实 NAS 上的目录列表、MLST 回显路径、EPSV、扫描、播放。解析器较严，事实值含空格、非 UTF-8 文件名、MLST 回显路径与请求不一致都可能报错。

iPhone 18：用户要求后，通过 Wi-Fi 安装同一个 `84b0816ab97a7c30`（InstallComplete），只安装，没有启动。

## 2026-11-07 09:58：真实 NAS 首次通过登录

用户截图显示 FTP 媒体库已创建，路径 `/video/media`，0 部作品、0 个文件，没有报错。说明登录和读取 `/video/media` 目录没有报错（包 `84b0816ab97a7c30`，iPhone 18）。

0 个文件的原因未确认。代码上只有三种情况不报错却得到 0：目录里没有视频（或为空）、条目是符号链接（按设计跳过）、用户点了“仅保存连接”没有扫描（这条要看入口，未确认）。新增子文件夹地址的夹具测试，FTPLibrarySourceTests 9 项通过，夹具层面排除了子文件夹路径拼接问题。尚未改产品代码。

## 2026-11-07 10:15：0 个文件的原因

用户子文件夹里有视频，手动刷新后报“FTP 目录内容无法识别”（`FTPListingError`）。不登录向 NAS 发 `OPTS UTF8 ON` 得到 `200 OK, UTF-8 enabled`，说明 DSM 不默认用 UTF-8。

- **推断（未直接确认）：** 中文文件名以旧编码返回，整个列表解码失败。根目录只有英文名，所以选文件夹能通过。
- **修复：** 登录后发 `OPTS UTF8 ON`（被拒也继续）；事实和文件名按 `; ` 分隔，事实值可含空格；媒体库扫描时单行无法解析只跳过该行，播放和元数据仍严格。
- **未验证：** 真实 NAS 扫描。NFO 读取走 MLST，回显路径的严格比较可能是下一个问题。

## 2026-11-07 10:35：真实 NAS 全流程通过（iPhone 13）

用户在 iPhone 13 输入一次密码后由我自动操作（密码不经过我）。`/video/media` 扫描成功，海报和 NFO 正常，《赌侠》（5.4 GB，HEVC）播放，画面在变，手势定位后新的 `REST` 读取正常。声音未实听。

第三个问题：DSM 的 MLSD 能列出某文件，MLST 却在 250 回复里夹一行 550“No such file”（首例路径同时含中文和方括号，没有分别隔离；本轮全量 209 次 No such file）。修复：MLST 无效或 550 时从父目录 MLSD 取同样的事实。RETR 对中文路径正常。

临时 DEBUG 日志已移除。本次中途的扫描约 3351 次 MLST、1673 次 RETR、480 次 MLSD，耗时约 2 分钟。每次读取重新登录，未做大文件性能基线。全量测试未跑完（Transport 卡住），六配置未跑。
