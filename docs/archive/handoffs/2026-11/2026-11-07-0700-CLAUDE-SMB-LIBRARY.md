# Claude（本地会话）：SMB 媒体库接入

2026-11-07（Asia/Shanghai）。接 [FTP 交接](2026-11-06-2350-CLAUDE-FTP-LIBRARY.md)。

**授权**：用户选择 libsmb2，并同意放宽严格选根（拒绝链接、检测文件变化，不再防读取途中替换上级目录）。

**没有提交，没有改共享状态，没有登录 NAS。**

## 已完成

- **`Packages/LibSMB2`（新）**：libsmb2 3.0.1 的 `lib` 和 `include`，来自 10-26 原型（含当时的补丁）。独立动态框架 `LibSMB2.framework`，已确认嵌入 App 并由 `@rpath` 加载。
- **许可**：`COPYING`、`LICENCE-LGPL-2.1.txt`、`NASTART-MODIFICATIONS.md`、`THIRD_PARTY_NOTICES.md` 已加。修改清单来自当时的记录，**没有重新生成上游 diff**；App 内也没有许可展示。上架前要补。
- **`SMBConnection.swift`（新）**：串行队列上的阻塞连接。要求签名，服务器要求加密时自动加密。打开文件允许他人读写删除，不锁 NAS 文件。不支持访客（要求账号）。
- **`SMBLibrarySource.swift`（新）**：路径第一段是共享；根目录列共享（`IPC$`，过滤 `$` 结尾和隐藏共享）。海报和 NFO 复用 30 秒连接池，不必每张图登录一次。播放用独立连接，保持文件句柄，定位不重新登录；断线重连一次，并核对大小和修改时间。
- **防封锁**：登录被拒后 60 秒内同一账号密码不再连接；登录途中连接断开也按被拒处理。一次连接只登录一次，不换地址重试。这与之前 DSM 407 封锁有关。
- **界面**：添加页新增“添加 SMB”，删除原“其他协议/暂未开放”。表单隐藏协议切换，默认端口 445，提示只在局域网或 VPN 使用。英文文案已加。
- **测试**：`SMBLibrarySourceTests`（12 项）、`smb_media_fixture.py`。其中 6 项需要 impacket，未设置 `NASTART_SMB_FIXTURE_PYTHON` 时跳过。

## 验证结果

| 项目 | 结果 |
| --- | --- |
| `NetworkMedia` 测试 | 324 项通过（含 SMB 12 项，impacket 夹具） |
| `NonPlaybackPolicyTests` | 193 项，跳过 1，0 失败 |
| 六配置 | 全部 BUILD SUCCEEDED。TV 只构建 |
| iPhone 13 | App 能启动（框架加载正常）；添加页有 SMB 入口；表单已打开 |
| NAS（不登录） | 445 通；impacket 协商到它支持的上限 SMB 3.0；服务器不强制签名 |

## 未验证

- **真实 SMB 服务器：完全没有登录过。** 添加 → 选共享 → 扫描 → 播放都没在真机或真实 NAS 上跑。
- **SMB 3.1.1**：夹具最高 3.0，App 可能和群晖协商到 3.1.1，这条路径没测。这是最大风险。
- **加密共享、域账号、IPv6、断线重连**：没有用例。
- **链接检测**：解析层有测试；群晖 Samba 可能在服务端直接跟随链接，客户端看不出来，已接受。
- **共享列表的 DCE-RPC 解析**：10 月没审查过，只跑过夹具。
- **选根目录**：在共享列表一层点“选择”会把所有共享一起扫描，没有拦截。
- **Release/App Store**：只构建，没有归档或动态库替换验证。
- **性能**：没测大文件码率。读取是单请求 1 MiB，没有并行预读。

## 最终包

dylib 前 16 位 `5dc792d57ddcfc2c`：iPhone 13、A16 iPad、iPhone 18 已保留数据安装（iPhone 18 只安装未启动）。描述文件 2026-11-08 09:08（+08）到期。

## 请 Codex 处理（如果用户安排）

审查集成 `Packages/LibSMB2`、`SMBConnection`、`SMBLibrarySource`、`Models`、`WebDAVConnectionFields`、`LibraryViews`、`NetworkMediaPlaybackSource`、`THIRD_PARTY_NOTICES.md`；共享状态写明 SMB 已接入但未经真实服务器验证。`tvos` 工程会经 NetworkMedia 依赖新包。

## 2026-11-07 08:40：用户首次真机尝试

用户发来两张失败截图，都是地址或端口填错，还没有走到登录，FTP/SMB 登录仍未验证。

- **FTP**：填了 `192.0.2.2:5005`，提示超时。5005 是 WebDAV 的 HTTP 端口（Apache 对 FTP 命令回 400），不发 FTP 欢迎语，超时符合预期。21 开放。
- **SMB**：填了 `private-host-3.example.invalid`，提示无法连接。Mac 上这个名字解析不到；`private-host-2.example.invalid` 解析到 192.0.2.2，445 开放。
- **未改代码。** 发现一处文案问题：添加页超时也显示“原索引已保留”，新增连接时没有索引。

## 2026-11-07 11:35：连接 SMB 闪退

崩溃报告（iPhone 13）：`SMBConnection.wait` 里 `smb2_get_fd` 空指针，符号落在 **MobileVLCKit**。VLCKit 自带并导出另一份 libsmb2，共 215 个符号重名；App dylib 调用的 22 个里有 19 个绑到了 VLCKit。macOS 测试没有 VLCKit，所以测不出来；之前“embedded 并按 @rpath 链接”的检查也没看每个符号的绑定。

修复：`include/smb2/nastart-symbols.h` 把 App 调用的函数加 `nastart_` 前缀。`nm -m Nastart.debug.dylib` 现在 22 个都来自 LibSMB2。SMB 测试 12 项通过。新包 `2a93258af245fbe9` 已装 iPhone 13，未装 iPhone 18。真实 NAS 上的 SMB 登录未验证。

## 2026-11-07 12:05：真实 NAS 全流程通过（iPhone 13）

用户输入密码后由我自动操作。SMB 登录和选文件夹成功（`/video/media`，共享 `video`），扫描 2410 个视频。SMB 读取原先在第一个大块就断开：之前打补丁的接收上限是 256 KiB，而 App 一次读 1 MiB（夹具最大读 64 KiB 测不到）。上限改为 1 MiB + 64 KiB。《赌侠》SMB 播放和手势定位通过（定位到 05:32，字幕正常，声音未实听）。协商方言未记录，3.1.1 是否用到未知。

FTP 同时发现漏扫：名字含 `[` 的目录，DSM 的 MLSD 带参数时当通配符，返回空列表且不报错（FTP 1682 / SMB 2410，差集全在方括号目录）。修复：路径含 `[]*?` 时先 CWD 再无参 MLSD。之后 FTP = SMB = 2410，差集 0。这也更正上面的推断：MLST 失败的原因更可能是方括号。

FTP 全库扫描 323 秒（每个 NFO 约 2 次 MLST + RETR）；SMB 扫描总耗时未精确测量。FTP 方括号路径里的视频没有实际播放。

**包：** dylib `842570779311f9de`，iPhone 13、iPhone 18 已保留数据安装；iPhone 18 未启动。测试窗口已关。描述文件 2026-11-08 09:08 到期。

验证：`NetworkMedia` 329 项 0 失败；六配置全部 BUILD SUCCEEDED（日志同 `nas-1106/six/`）。`NonPlaybackPolicyTests` 本轮未跑。TV 只构建。六配置构建覆盖了 mobile 产物，下次安装前先重建签名包。

## 2026-11-07 12:25：路径框与“原索引已保留”

- **路径：** 新增连接路径默认留空（显示占位提示）；`scope()` 去掉重复和多余的 `/`，`//video//media`、`video/media` 都得到 `/video/media`。SMB 提示改为“路径可留空”。
- **文案：** 所有报错去掉“原索引已保留”。只有刷新已有内容的媒体库失败时，才附加“上次的整理结果已保留。”英文同步。
- **验证：** `NetworkMedia` 330 项通过，iOS Debug 真机包构建并装 iPhone 13（dylib `b9e872a7f6eee32b`）。iPhone 13 上看过空路径表单和输入后的路径。六配置这批没重跑，iPhone 18 未装。

## 2026-11-07 12:40：海报、详情和 WebDAV 入口

证据来自 iPhone 13 的本机索引和一次临时扫描日志（日志已移除）：

- **WebDAV：** `我的 WebDAV`（`http://lagransun.cn:5005/video/media/`）只有连接、没有文件夹，首页只列媒体库所以看不到。现在首页列出“尚未选择媒体文件夹”的连接，点开进入选文件夹。未走完选文件夹流程，密码是否仍有效未知。
- **海报：** 系列根目录基本没有 poster/folder 图片和 tvshow.nfo；34 个剧集里只有《西游记》有剧集海报。现在没有剧集海报时用最早有图的一集，是剧照不是海报。《杀死比尔》只有 `movieset-poster.jpg`，已加入候选。0 字节图片不再被选中。
- **详情：** 20 部周星驰电影的 `.nfo` 是纯文本发布说明，不是 XML，所以无剧情和演员。现在标题取文件夹里的中文名，编码和分辨率取文件名，音轨取发布说明，不再记为无效。剧集页补充年份、类型、制片公司和“首集简介”。
- **重扫：** `artworkScanVersion` 升到 5，已有媒体库打开时自动重扫一次（FTP 约 5 分钟）。
- **结果（SMB）：** 72 个非剧集文件 71 个有图，缺《奇异博士2》；《一拳超人》《The Long Night》仍无图。《火影忍者》约 480 集无图，但已有其他集的图可做封面。

`NetworkMedia` 333 项通过，iOS Debug 真机包 `35de1a3f1f3d2e38` 装 iPhone 13，iPhone 18 未装，六配置这批未跑。FTP 媒体库未在新包上重扫。这 20 部的剧情和演员本地没有来源，要补只能联网刮削，尚未实施。
