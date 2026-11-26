# 2026-11-10 Jellyfin 会话拒绝与 iPad 三入口

接续 [同账号内网会话恢复](CODEX-2026-11-09-JELLYFIN-SAME-ACCOUNT-LAN-RECOVERY.md)。在 `JellyfinLibraryStore` 的已保存会话接管分支增加 Debug 诊断，区分内网候选缺失、候选不符合条件、请求返回状态、身份结果和上下文变化。诊断仅输出阶段、枚举原因和 HTTP 状态，避开地址、账号、令牌及响应正文。认证规则和播放器路径沿用上一批。

`main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加已有未提交改动，498 项构建输入冻结并复核。Xcode 27.2 签名 Debug 在 03:25:30 CST 构建，`Nastart.debug.dylib` SHA-256 `f6b9223f5ddcc068b7bbc471e67c34de730cfaa752c50d25289a2181dc2ec27a`，主程序 `8e5ef33775ac5d588956d53c0eb9c7ab4815f18184b707cd3a5134a207b95834`。包在私有证据目录 `product/Nastart.app`，本机指针 `/tmp/nastart-jellyfin-recovery-stage-current`。签名与两台 USB 设备覆盖均核，描述文件有效至 11 月 15 日 00:30:17 UTC。

## iPhone 13

`iPhone14,5` / iOS 16.3.1 / USB。03:26:26 保留数据覆盖，安装前后 App 偏好全量一致。空参数、空环境正常启动首页，实际截图有 Wi-Fi。沿已有登录进入 Jellyfin：同账号的私网会话存在，公开标识探测先确认两条地址属于同一服务器。随后域名资源库请求返回 HTTPS 401，触发内网会话的 `Users/Me`，内网也实际返回 HTTP 401，记为 `storedLibraryRecovery/httpRejected`。资源库未加载，没有发出播放请求。03:27:25 App、Runner 与转发核实收尾。

此前放宽同账号会话的保存时间条件使内网候选能进入认证，但现有两份会话均未获服务器接受。现场没有证据区分令牌撤销、过期或服务端访问策略，未重登或更改凭据。后续若复现拒绝原因，需要按同一时刻匹配服务端认证记录，或在明确验证新会话后与旧会话对比。

代码核对发现域名资源库通过 SDK 发送 `Authorization: MediaBrowser`，单独的身份探测则发送旧 `X-Emby-Token`。Jellyfin 10.11.11 和 12.0 都有旧头开关，12.0 的迁移会关闭旧授权。因此首轮内网的 HTTP 401 还无法区分请求头与保存会话。标准头补测使用同一个已保存会话。 [服务器认证实现](https://github.com/jellyfin/jellyfin/blob/v10.11.11/Jellyfin.Server.Implementations/Security/AuthorizationContext.cs#L74-L99) [12.0 迁移](https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Server/Migrations/Routines/20260531160000_DisableLegacyAuthorization.cs)

## A16 iPad 同片同起点

`iPad15,7` / iPadOS 26.6 / USB。03:29:02 保留数据覆盖 `f6b9223f…`，安装前后 App 偏好全等，原 Runner 复用。两轮测试前先以空环境启动，并以实际首页和 Wi-Fi 图标核对。专项仅给当前 128,795,641,934 字节样本指定 346.993 秒，实际引擎起点以 trace 和 plan 对应诊断为准。首轮设备文件定位失败，因为脚本遗漏侧栏 Cell。首轮 SMB 定位失败，因为旧工具限定了弹窗位置。两次都未派发播放或建立临时索引。补跑识别侧栏 Cell，并用当前弹窗的可访问标题和实测几何定位。

Jellyfin 和设备文件都从 346.993 秒以 AC3 2 / PGS 9、KSPlayer、`localRangeProxy` 和 206 原画出画，截图见中文字幕，随后正常返回详情。内部首帧分别为 6.954 秒和 5.242 秒。两窗为单次 Debug 定点，未配平上游缓存或测屏幕首帧，数字用于定位。

SMB 补跑读取到同一文件，实际引擎起点 346.993 秒，Reader 返回 206，内部首帧 5.849 秒。开播默认音轨 1、字幕 8，音轨已选到 2，触控脚本未在新弹出的菜单中找到字幕 9。截图采于首帧前，只见缓冲。该窗保留为未完成同轨对照。临时索引从 App 移除，读回确认原 3 库和 4 连接逐项一致。最后以空参数、空环境启动复核首页和 Wi-Fi，03:40:11 App、Runner、转发均收尾。最终偏好仅变化诊断和本地书签。

## iPhone 13 标准认证头补测

身份探测改用 `Authorization: MediaBrowser`，先编码端点自己的已保存令牌。沿用原端点校验、禁止重定向、相同身份及网络代次要求。签名 Debug 03:41:18 构建，`Nastart.debug.dylib` SHA-256 `01a6ec564dbc666db22a32687792b94e8d09b38875de760eb9bc1d3cdd991175`，主程序 `5e97386a67441070c5305c4abc65c96b2ee6bc8fa27e4837d983b13edfc8069a`。私有证据 `/tmp/nastart-jellyfin-standard-header-current` 指向同级 `product/Nastart.app`，同一 498 项输入重新冻结和复核。03:41:47 在 13 保留数据安装，空环境正常首页和 Wi-Fi 已核，安装前后偏好全等。iPad 本轮出画证据归早先的 `f6b9223f…`。

域名资源库再次返回 401。公开同服务器核验这次略晚到，随后仍成功发出标准头的内网身份请求并收到 HTTP 401。确认旧认证头不是本轮 401 的唯一原因，服务器的具体拒绝理由仍待取证。未修改账户凭据或发起播放。03:42:48 已核 App、Runner、转发全停，设备和网络窗口释放。验收格保持原状态。 [结构化结果](../../../testing/results/2026-11/CODEX-JELLYFIN-RECOVERY-HTTP-STATUS-20261110.json)
