# 2026-11-10 iPhone 13 Jellyfin 重登与 SMB 字幕取证

接续 [Jellyfin 两路 401](CODEX-2026-11-10-JELLYFIN-RECOVERY-HTTP-STATUS.md)。用户明确授权在 iPhone 13 上用此前提供的凭据重登。凭据只在控制输入时读入内存，未保存到本批文件，密码只输入 App 的安全文本框。原始设备身份、App 偏好和屏幕资料留本机，证据指针 `/tmp/nastart-jellyfin13-authorized-reauth-current`。

本批沿用 `main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 和 498 项冻结 iOS 输入的同源签名 Debug。03:41:18 CST 构建，`Nastart.debug.dylib` SHA-256 `01a6ec564dbc666db22a32687792b94e8d09b38875de760eb9bc1d3cdd991175`，主程序 `5e97386a67441070c5305c4abc65c96b2ee6bc8fa27e4837d983b13edfc8069a`，签名包在 `/tmp/nastart-jellyfin-standard-header-current` 指向目录的 `product/Nastart.app`，描述文件有效至 11 月 15 日 00:30:17 UTC。产品源码未改。

## iPhone 13

USB fresh 核名称、标识、`iPhone14,5` / iOS 16.3.1。现场安装查询匹配 03:41:47 的包路径及安装回执，本批复用现有安装与 Runner。首个预检发现 App 已在运行，未启动 Runner。确认精确 PID 和路径，保存偏好后只停止这个 Nastart，停止前后偏好全量一致。空参数、空环境、Wi-Fi 运行。

首个菜单坐标尝试在注销派发前停止。改用 XCTest 原生控件进入旧会话退出和登录表单，实际只提交一次登录。诊断记录一次 `login_succeeded`，三个资源库加载完成。对 128,795,641,934 字节 S19《指环王1：护戒使者》走 `localRangeProxy` 从头播放，内部首帧 980 ms，截图见片头画面推进，正常退出播放器。05:08:43 自有 App、Runner、转发全部关闭。

随后复核 USB 和安装回执，用新进程冷启动，正常空环境下直接恢复 Jellyfin 资源库。没有重新输入凭据，05:09:19 自有窗口全部关闭。本轮恢复了实际使用，旧会话为何失效尚未取到服务端记录。

## A16 iPad SMB 补证

USB fresh 核 `iPad15,7` / iPadOS 26.6 和设备身份。05:09:49 保留数据覆盖与 13 相同的 `01a6ec56…`，安装前后全量 App 偏好一致。复用已签 Runner，先以空参数、空环境打开首页并实图确认 Wi-Fi。

SMB 临时索引校验了同目录、同文件和精确 128,795,641,934 字节。先在播放器中选择 PGS 9，再选择 AC3 2，普通退出后读取到书签 354.168 秒与两条轨道。通过仅匹配该文件大小的 Debug 定点重开，trace 和 plan 确认引擎实际起点 346.993 秒、AC3 2 / PGS 9，`localRangeProxy`、KSPlayer、Direct Play、Reader 206。内部首帧 8.943 秒。间隔实图见影片画面变化和中文字幕，也在三张实图上保留了缓冲提示。普通返回详情。上轮 Jellyfin、设备文件相同起点与轨道使用的是 `f6b9223f…`，本轮 SMB 为 `01a6ec56…`，不同包、缓存未配平，数字不用于速度排名。

临时索引已从 App 删除，原 3 库、4 连接逐项一致。最后空环境重启实图复核首页与 Wi-Fi，05:14:42 自有 App、Runner 与转发全部关闭。本批不新增完整验收格。下一轮先在同一个包上收集匹配三入口的 Range 供给与缓冲条件，再比较速度。 [结构化结果](../../../testing/results/2026-11/CODEX-IPHONE13-REAUTH-AND-SMB-TRACK-20261110.json)
