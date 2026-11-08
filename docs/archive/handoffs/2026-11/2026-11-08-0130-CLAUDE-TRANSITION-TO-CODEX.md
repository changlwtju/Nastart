# Claude → Codex：11-06 至 11-08 工作接续

2026-11-08 01:30（Asia/Shanghai）。用户说明 Claude 额度将耗尽，后续工作由 Codex 接手。本文是总入口，细节见文中链接的各份 Claude 交接。

**所有改动都没有提交。** 共享状态（PROGRESS、当前交接、资源登记、`CLAUDE.md`）一直没改，仍停在 11-04 前后，需要 Codex 按本文更新。工作区有 309 个改动路径，其中大量是接受中的基线，不能清理或回退。`Packages/NetworkMedia` 和 `Packages/LibSMB2` 整体是未跟踪目录。

## 一、设备与包（接手时先核对）

| 设备 | 当前包（Debug dylib 前 16 位） | 状态 |
| --- | --- | --- |
| iPhone 13（iPhone14,5，iOS 16.3.1，`REDACTED-DEVICE-01`） | `4744df402a1897c3` | 保留数据安装；用户 11-06 授权 Claude 调试 |
| A16 iPad（iPad15,7，iPadOS 26.6，`REDACTED-DEVICE-06`） | `4744df402a1897c3` | 同上 |
| iPhone 18（`REDACTED-DEVICE-03`） | `4744df402a1897c3` | 只按用户要求 Wi-Fi 安装，未启动，未测试 |
| Apple TV | — | 未操作，只构建 |

- **签名（11-08 08:30 更新）**：Xcode 用 `-allowProvisioningUpdates -allowProvisioningDeviceRegistration` 生成新 App 描述文件，到 **2026-11-15 08:30（+08）**，含 13、iPad、18。只有构建时用 `-destination id=<UDID>` 且设备已连接，才会把它加进描述文件，generic 目标不会加。iPhone 18 用数据线一次才被识别。iPhone 13、iPhone 18 已装 `9a17067ae8bcc47f`；iPad 装的是同源码的 `56731c90bc8d0edc`（描述文件到 11-15 08:11）。旧描述文件移到 Claude scratchpad，没有删除。**Apple TV 没装**：CoreDevice 一直显示 unavailable（10-27 起），关掉 Shadowrocket 也无效，需要在 Xcode 重新配对。Runner 描述文件到 11-11。
- **测试窗口已全部关闭**：`phone/STOP`、`ipad/STOP` 已放置，自开的 syslog、debugserver 进程已结束。8101 的 iproxy（旧 iPad）不是 Claude 开的，没有动。
- **最新验证**（源码与包一致）：`NetworkMedia` 350 项全部通过；六配置全部 BUILD SUCCEEDED（日志 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/nas-1106/six/`）。`NonPlaybackPolicyTests` 最近一次是 11-07 早上（193 项，跳过 1），之后未重跑。
- **构建命令、安装方式、WDA 窗口脚本**：见 [FTP 交接](2026-11-06-2350-CLAUDE-FTP-LIBRARY.md) 和 [播放调试交接](2026-11-07-2340-CLAUDE-PLAYBACK-ACROSS-SOURCES.md) 的“工具”节。注意：`six15.sh` 无签名构建会覆盖 mobile 产物，安装前要再做一次签名构建。

## 二、已完成（按时间）

| 日期 | 内容 | 详细交接 |
| --- | --- | --- |
| 11-06 | NAS 恢复后真机调试：iOS 16 文件夹选择器卡死、iPad 播放变小窗、报错与转圈重叠 | [0845](2026-11-06-0845-CLAUDE-NAS-RECOVERED-DEVICE-DEBUG.md) |
| 11-06 | 真机 UI 修复（套件状态、标签回根、文件详情、音轨/字幕名称、iPad 全屏等）和大文件播放初步基线 | [1800](2026-11-06-1800-CLAUDE-DEVICE-UI-PASS-AND-PLAYBACK-BASELINE.md) |
| 11-06 | 全局走查清单（19 项） | [1900](2026-11-06-1900-CLAUDE-APP-AUDIT.md) |
| 11-06 | 走查第一批：DSM 登录被拒错误码（407 = IP 封锁）、媒体库 401 文案、系统目录隐藏等 | [2030](2026-11-06-2030-CLAUDE-AUDIT-FIRST-BATCH.md) |
| 11-06 | 跳过 SSL 开关回填、移除媒体库确认、约 350 条英文文案；栈列主题试验已撤销 | [2130](2026-11-06-2130-CLAUDE-SECURITY-ENGLISH-STACK-REVERT.md) |
| 11-06～07 | **FTP/FTPS 媒体库**：真实群晖上扫描、海报、NFO、播放通过 | [2350](2026-11-06-2350-CLAUDE-FTP-LIBRARY.md) |
| 11-07 | **SMB 媒体库**（libsmb2，含符号重命名避开 VLCKit 冲突、1 MiB 读取帧上限）：真实群晖通过 | [0700](2026-11-07-0700-CLAUDE-SMB-LIBRARY.md) |
| 11-07 | 海报和详情补全、路径 `//` 修复、“原索引已保留”误导文案、首页显示未选目录的 WebDAV | 同上 SMB 交接后半段 |
| 11-07 | **TMDB 补全**（默认关闭，只补缺失；接口优先 `api.tmdb.org`，因 `api.themoviedb.org` 在用户网络被拦） | [1840](2026-11-07-1840-CLAUDE-TMDB-METADATA.md) |
| 11-07～08 | **各入口播放调试**：修复网络媒体库掉帧（约 2 帧/秒 → 24 帧/秒）、WebDAV 提速、新增“继续观看/从头播放” | [2340](2026-11-07-2340-CLAUDE-PLAYBACK-ACROSS-SOURCES.md) |
| 11-08 | **网络存储接入共享播放链路方案**（只读调研，待 Codex 审） | [0100](2026-11-08-0100-CLAUDE-NETWORK-SOURCES-SHARED-PROXY-PLAN.md) |

## 三、待 Codex 处理

### A. 先做（时间敏感或阻塞后续）
1. **Apple TV 仍无法安装**（iPhone 13、iPad、iPhone 18 已于 11-08 重新签名）。11-08 排查结果：电视在局域网广播正常（`_remotepairing._tcp`，49152 端口通），配对每次都成功，但建立开发隧道时立即报 `RemotePairingError 1005: This device does not support tunnel connections`，CoreDevice 只把它记成 `RemotePairingWirelesslyPairableDevice`。已排除：Shadowrocket/TUN、中文设备名（曾导致 hostname 生成失败，已改名 `Appletv`，错误依旧）、Xcode 版本（27.0 → 27.2 后依旧）。电视已升级 tvOS 27.2。“设置 → 隐私与安全性”里没有开发者模式开关。11-08 16:00 已重启 Mac 和电视并重新配对：电视首次以真机出现在 `devicectl list`（UDID `REDACTED-DEVICE-07`，CoreDevice ID `REDACTED-DEVICE-08`，配对状态 paired，Device State unavailable）。`remotepairingd` 能通过蓝牙和 Bonjour 识别它，但之后没有发起隧道连接；`devicectl device info apps` 现报 `CoreDeviceError 4016`（无法满足使用断言，可用状态为空）。电视“设置 → 隐私与安全性”里仍然没有开发者模式开关，判断是 tvOS 27.2 或 CoreDevice 的问题。暂停，等系统更新后再试，或者向 Apple 反馈。16:10 在 Mac 上删掉配对记录（`devicectl manage unpair`）后重新配对，两次都失败：Device Hub 报 `DeviceKitError 5000 / NSError -1`。`remotepairingd` 显示，连电视手动配对广播（`F8751598…`，`private-host-4.example.invalid:55747`）时，TCP 一直停在 preparing，10 秒后被取消；直接测 55747 端口被拒绝，常规端口 49152 能连上。重启后 Shadowrocket 又自动连上了（utun4 是默认路由），还没测过关掉它之后配对。**现在 Mac 上没有这台电视的配对记录**，用户决定先放一放。
2. **方案已审**：Codex 的[审查报告](CODEX-2026-11-08-SHARED-PROXY-PLAN-REVIEW.md)有条件接受第一步。第一步要先等 Codex 修好共享代理的 Range 语义（后缀范围 `bytes=-500` 被改成读文件头、非法范围被静默修正），并补齐路由撤销、诊断关联和有界并发 4。启动预读 0 字节已确认是“只观察”适配器的设计行为，真实字节预读属于实现缺口，由 Codex 负责。**Claude 额度将尽，第一步建议也由 Codex 接手**（范围：`LaunchpadLayoutViews.swift`、`WebDAVPlaybackSession.swift`、`WebDAVMediaHTTPTests.swift`，以及 13、iPad 顺序对照）。
3. **审查集成**：本文所列各份交接的文件（各交接末尾有“请 Codex 处理”清单），并更新共享状态，包括：NAS 已恢复、FTP/SMB 已接入并经真实 NAS 验证、TMDB 已接入但真实接口待验、13/iPad 由 Claude 调试的阶段结束。

### B. 用户原则（11-08，已写入 Claude 记忆，请纳入共享文档）
播放链路按**网络环境**区分，不按入口区分。同一网络环境下，Jellyfin、设备文件、SMB、FTP、WebDAV 共用一条链路，只有“取字节”那层不同；FTP、SMB 只用于内网。目前网络存储没有注册到共享代理（日志里 0 次代理传输），这是要补的缺口。

### C. 播放问题清单（用户提出加 Claude 补充）
| 问题 | 编号 | 现状 |
| --- | --- | --- |
| 大文件起播、续播首帧慢 | PX-01 | 29 GB m2ts 首帧 2.1～6 秒；起播后再缓冲 6.4～7.3 秒仍开放；**启动预读空转** |
| 快进快退、远距离跳转慢 | PX-02 | 内网多 1～3 秒、原盘 3～4 秒；蜂窝深跳转 8.4～8.6 秒；13 上一次解码器 7.6 秒无输出，未复现 |
| 音轨、字幕切换慢 | PX-20 | 日志约 0.7～1.7 秒生效；声音未实听，字幕上屏未逐帧确认 |
| 杜比视界、全景声 | PX-18/19 | 只能识别片源。KS 路径把音频解码成 PCM，做不到全景声；DV 显示未验证，P7 增强层未处理；缺样本和输出设备 |
| 网络存储未接共享链路 | 新 | 见方案 |
| 自动兼容和降档 | PX-03 | 只在构造条件下验证过 |
| 断点和轨道偏好跨入口一致 | PX-21 | 未完整验证 |
| 字幕（PGS 旧字幕遮挡、缩放、位置、延迟、导入） | PX-08～11 | 大部分未开始 |
| 画中画 | PX-05～07 | 零星验证 |
| 长时播放、内存、资源释放 | TC-11 | 未跑 |
| `first_frame` 日志常丢 | 新 | 系统日志丢行，测速脚本已改认 `video_frame_submitted`，App 内应改更可靠的采集 |
| 详情页被播放器盖住仍持续重算 | 新 | 已把每次重算变便宜，根因没查 |

### D. 网络媒体库其他未完成
- **iPad 上 SMB、FTP、WebDAV 未测**：iPad 没配 SMB、FTP；iPad 的 WebDAV 密码可能仍失效（之前 401），需要用户本人更新，不要用旧密码反复尝试，以免再次触发 DSM 封锁（407）。
- **SMB 索引过期**：还是旧的 2410 个，FTP、WebDAV 是 2292 个，差的是用户移走的 118 个损坏文件。刷新即可，点开已移走文件时的提示没测。
- **FTP 每次读取重新登录**：跳转慢一点，接入共享代理后会放大，应改为复用控制连接。
- **TMDB**：真实接口未验证（要用户在手机上粘贴令牌，不要索取令牌）；TMDB Logo 未加；Plus 收费前需要 TMDB 商业授权。
- **SMB 3.1.1、加密共享、IPv6、断线重连**：没有用例。LibSMB2 的上游 diff 没有重新生成，App 内也没有许可展示，上架前要补。
- **走查清单剩余项**：10～19（见 [1900](2026-11-06-1900-CLAUDE-APP-AUDIT.md)），以及 DSM 会话失效（`SYNO.FileStation.List` 返回 119 时文件页失败，重启才恢复，未修）。
- **未实测的界面**：移除媒体库确认框、离线状态、被拒提示、iPad 修改文件夹、英文界面（iPad）、TV 文案。

### E. 样本缺口（等用户）
大文件下载进行中。《碟中谍3》《好东西》《哈尔的移动城堡》目录为空；`music` 共享为空。需要 DV P5/P8/P7、DD+ JOC、TrueHD Atmos、DTS 样本，以及空间音频耳机或外接设备，由用户实际看和听。

## 四、NAS 现状（用户在 Claude 协助下操作，和 App 无关但影响测试）

- **曾遭勒索软件**：备份盘 `NAS_encrypted` 中有 `.L0CK3D` 文件和 `read-me3.txt`；5 个存储空间的共享文件夹里没找到 `L0CK3D` 文件。**NAS 安全检查（陌生账号、计划任务、端口转发、QuickConnect）尚未完成**，`read-me3.txt` 内容未看。用户还没确认 `mihomo` 订阅和 `ddns-go` 云厂商密钥是否为事件前的旧配置（若是应重置）。`docker` 共享有 `everyone` 只读权限，建议收紧。
- **存储布局**：`video` 在存储空间 3（`/private-nas-path`），`docker` 在存储空间 5，`rescue` 在存储空间 4。媒体库 `/video/media`（movie、anime、TV）。
- **已移走**：118 个损坏视频移到 `/private-nas-path`；还有 73 个可疑视频留在媒体库，用户尚未决定。
- **Jellyfin**（官方镜像 12.4.0，`/private-nas-path`）：VAAPI 硬件转码已验证（`h264_vaapi`）；`user 1026:100`、`group_add 937`、只映射 `renderD128`；媒体只读挂载 `/private-nas-path`。因 `api.themoviedb.org` 被拦，加了 `extra_hosts: api.themoviedb.org:3.167.192.73`，这是 CDN IP，可能会变。
- **qBittorrent**（`libtorrentv1`，`/private-nas-path`）：BT 端口改为 52881（6881 被北洋园拉黑）；默认保存 `/data/downloads`，分类 TV、movie、anime、music；Host header 验证已关，以支持 `lagransun.cn:8081` 反向代理。上传限速 500 KiB/s；BT 端口未转发；PT 站做种者主要是 IPv6，容器 bridge 网络可能没有 IPv6，这是下载慢的推测原因，未验证。
- **mihomo**：临时加的 TMDB 规则已从备份还原，配置未改。

## 五、已知约束（继续适用）

- 真实密码只由用户输入，不读 Keychain，不显示密码眼睛，不用猜测密码登录 NAS（DSM 自动封锁）。TMDB 令牌同理。
- iPad 上不要合成点按媒体库行（`network.library.source`），会弹出含“移除此媒体库”的长按菜单。
- iPhone 18：只在用户要求时安装，不启动不测试。TV 未授权运行。
- 不清理、不回退未提交的基线；不改系统、安全、签名、VPN、NAS 设置。
- 构建前确认磁盘可用空间 ≥ 6 GiB（当前约 11 GiB）。
- iPhone 13 的 Instruments（xctrace）看不到 iOS 16 设备；主线程采样可用 `pymobiledevice3 developer debugserver start-server --local-port 9333` 加 `xcrun lldb`（`process attach --pid`）。`pymobiledevice3 syslog` 只能一个读者，孤儿进程会让新日志收不到内容。

## 六、建议的下一步（按优先级）

1. 重新签名并安装，核对三台设备的包身份。
2. 审查并集成 Claude 这几天的改动，更新共享状态。
3. 排查启动预读空转；审查网络存储接入共享代理方案，按分工实施第一步，并用 `mx.py` 同口径对比。
4. 大文件起播、跳转：先改可靠的首帧计时，再拆分网络、读盘、解码三段耗时。
5. 切轨在 iPhone 18 上实听对照。
6. 杜比视界和全景声：等样本和输出设备到位再做，先补 E-AC-3 JOC 的系统解码分支调研。

## 新样本（11-08 17:20，用户经 Radarr 下载）

- **文件**：完整 NAS 路径保留在本机私有交接原件。下载目录和媒体库各有一个硬链接，指向同一份数据（链接数 2）。
- **可补的样本空缺**：4K 原盘 Remux 大文件、杜比视界（UHD 原盘一般是 Profile 7，带 HDR10 底层，可能有 FEL）、TrueHD 7.1。DTS、杜比视界 Profile 5/8、音乐文件仍然没有样本。
- **已观察到**：Mac Safari 用 Jellyfin 网页播放时转码，NAS CPU 约 60%，画面黑屏。原因未确认，可能是软件色调映射、TrueHD 转码或烧录字幕。原生客户端直接播放应该基本不占 NAS CPU。
- **建议测试**：Jellyfin 直连、SMB、FTP 和设备文件入口，比较首帧、跳转、长时播放、音轨与字幕切换、内存，以及 HDR/杜比视界的显示效果。iPhone 13 是 A15，iPad 是 A16，两台都能硬解 HEVC 10bit。TrueHD 在 App 内怎么处理（软解、转换还是不支持）要实测确认。这个文件体积很大，要注意缓冲窗口和内存。
