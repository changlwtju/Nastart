# iPhone18 Wi-Fi 最新包覆盖更新

2026-11-04后续：[解锁补核](CODEX-2026-11-04-IPHONE18-UNLOCKED-STARTUP.md)已执行。当前已非锁屏，两个原生启动/激活窗仍未取得Nastart前台图；安装成功不变，前台仍未验。App/隧道已清，停止重复尝试，下文保留11-03原始结果。

2026-11-03。用户明确要求无线更新 iPhone18，覆盖原“18 hands off”仅限本次安装/安全启动窗口；不扩大到普通根恢复、NAS、播放、WDA或其他设备。用户预计本周修复NAS是后续安排，尚非恢复确认。源自[二次UI最终包](CODEX-2026-11-03-CLAUDE-UI-INTEGRATION-2.md)，[结构化结果](../../../testing/results/2026-11/CODEX-IPHONE18-WIRELESS-UPDATE-20261103.json)。

## 包和现场

447扫描输入、主HEAD `4de732dd`、dirty iOS diff逐项与最终包冻结记录相同，因此复用正常Debug -Onone，无新源码或重复构建。清单SHA `4a0ce63e9e0a14da852f9151020069f047fcdd1e714b9476b4a98a2025367241`；有效源码接受提交f231962e/1fbad71e，原审查分支报告eb22898。构建 2026-11-03T23:31:16.686070+08:00 至 2026-11-03T23:32:10.407660+08:00。main `2090db4219666643c062b899ab376d7d1cc1edfd2dc164ca6909f6f3d1919c6b`，Debug dylib `8a1e979bb59c4a593068e8150a9b34bbd825a8a45ad7eec47cbbf33f2afe7605`，IPA `96f99d5021b113a1dee1977dc61e295299294fe6bd7b3ac90f19b7f187dbc23e`。

安装前/备份后重核所有输入与App/IPA哈希、30 Mach-O/deep/strict签名、29库、IPA成员/CRC及真实目标覆盖，profile到 `2026-11-08T01:08:19Z`，无签名账号或profile更新。包固定于二次UI私有normal-package；本次材料独立在 `/tmp/nastart-codex-iphone18-update-path`，原设备名称/UDID/端点、偏好、屏幕、原始报告不入库。

系统当前DNS-SD解析、已有配对、autopair=False、实时UDID认证为 iPhone19,7 / iOS27.0，名称和完整身份私存；当前USB清单不含目标。只连当前解析的无线端点，不用历史IP、不扫网段、不新配对/改网络/VPN。CoreDeviceProxy→userspace RSD→DVT同目标再次核实。安装前Nastart进程0，已保存必要诊断/全部偏好，无需结束未知进程或部署WDA。

## 完成与边界

沿原生安装工具的HouseArrest备份→AFC暂存→installation_proxy Install链路，2026-11-03T15:48:01.365713+00:00收到明确Complete，安装后fresh lookup存在；不靠相同0.1.0/1判最新。不卸载/清登录或回写旧配置。27项非诊断偏好及全部偏好值，从本轮开始、安装前后到安全启动后最终逐值相同。

首次安全离线启动请求和PID/路径成立，但实际原图为锁屏；已停止该App，前台启动未验。已只请求一次用户解锁，不绕过锁屏、不重复安装；后续同包解锁补核可独立完成。

两次启动如有补核均仅显式 `--offline-ui source-add` / glassDeck / dark / standard / zh-Hans，environment={}；经源码已审不构造真实目录客户端/连接模型，不普通恢复NAS。未注入测试环境变量，不把离线启动当普通账号根、真实媒体或完整UI回归。最终Nastart0，自有DVT/Lockdown/隧道/连接关闭，无自有播放/下载/采集/转发；未动Wi-Fi/蜂窝/VPN、配对或系统设置。

用户保存的域名＋端口相关偏好随全偏好保持；未主动读取/写入Keychain登录配置，未建立/核验DSM实际会话或视频路线。不能由偏好同/安装成功宣称已启用固定域名实际会话、蜂窝回退或NAS连通。NAS请求/播放/蜂窝任务0，其余真机未操作。30项/114格不关闭。

## 后续

NAS实际修复确认前继续暂停发现/登录/目录/图片/媒体/探针。恢复后先fresh核设备/当时最新包与有效签名、保存现场，再核18保存地址/Keychain配置/DSM实际会话/媒体请求路线，之后按既定矩阵进入真机功能/播放回归；不因预计修复时间自动发业务请求。13/Pad交互Runner过期、旧Pad不含A16及TV连接/签名旧阻塞独立保留。手机更新窗口收尾释放，无持续后台控制或周期任务。

本轮产品源码/真实index保持；共享摘要、当前交接、资源登记和开发状态已同步。核对总账/播放矩阵/技术路线无实现或验收状态变化，不制造新通过。文档检查通过：660 documents / 3943 local links，Missing destinations: 0。
