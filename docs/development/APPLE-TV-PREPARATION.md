# Apple TV 开发与真机安装准备

2026-11-08 升级后的现场为 AppleTV14,1 / tvOS 27.2（24K122），Xcode 27.0。两次无线配对认证成功后仍报 RemotePairing 1005，后来设备条目转为不可用。[升级后日志](../archive/handoffs/2026-11/CODEX-2026-11-08-APPLE-TV-27-2-DEVICE-HUB-LOGS.md)。下方 tvOS 18.2 为升级前和历史安装记录。

2026-11-08 Apple TV「客厅」两次配对后，CoreDevice 申请开发隧道立即收到4000/RemotePairing1005。Mac 仍识别已配对身份，旧式32498拒连与1005的因果未证。当前开发目标仍不可用，用户确认无第二台 Mac，独立对照暂缓。[隧道诊断](../archive/handoffs/2026-11/CODEX-2026-11-08-APPLE-TV-TUNNEL-1005-DIAGNOSIS.md)。

2026-11-08 [新现场](../archive/handoffs/2026-11/CODEX-2026-11-08-JELLYFIN-LOGIN-AND-APPLE-TV-CONNECTION.md)。客厅在 Device Hub 发现并由 Mac 日志确认配对认证成功，tvOS18.2 仍 Currently Unavailable。用户重启后 CoreDevice 精确详情及原生 RSD 仍不可用。用户接同一路由器网线后，配对端口在 IPv4/IPv6 仍可达，旧式设备发现广播端口 32498 拒连。开发目标仍不可用。签名是独立安装门槛。

统一安装/原生隧道/XCTest遥控分层、XCUIScreen取图及收尾见[真机远控手册](PHYSICAL-DEVICE-REMOTE-CONTROL.md)。当前恢复阻塞不变；本文历史成功不代表本轮已连接，NAS暂停期间不执行普通启动或媒体验证。

2026-11-01 当前恢复：用户已到电视“遥控器App与设备”页，两端Wi-Fi同路由器；本机Bonjour开发服务与客厅AirPlay解析到相同主机，路由为en0。Device Hub 27的附近设备列表已重新发现“客厅”，曾进入验证码步骤，但随后窗口已消失，**验证码提交/开发会话恢复仍未核实**。最新TV签名构建缺profile，旧profile已于10月31日05:46:14UTC过期；未安装旧包或启动普通App/NAS。下方10月24日成功为历史，不是今天最新回归。当前协作与设备调度按[双工具分工](CODEX-CLAUDE-COLLABORATION.md)。

## 历史实际使用的连接与安装链

回查确认，10 月 18 日在 Xcode 26.6 对「客厅」完成验证码配对后，同一台 AppleTV14,1/tvOS18.2 也出现过 RemotePairing 1005。当时刷新 Mac 用户级设备服务曾让电视重新出现在发现列表，随后的认证成功仍未带来可安装目标。10 月 19 日仍无开发连接。现有记录里，10 月 24 日 13:48 首次确认签名安装，14:15 再次覆盖并实看启动，10 月 29 日仍有同一电视的 LAN 安装记录。10 月 24 日记录从开发服务已可用开始，相关时段的 Mac 日志未找到可关联事件，原临时证据入口已不在，无法确认是什么让开发连接恢复。[10 月 18 日排查](../archive/handoffs/2026-10/2026-10-18-ORIGINAL-ROUTE-RACE-AND-TV.md) · [10 月 19 日复核](../archive/handoffs/2026-10/2026-10-19-APPLE-TV-PAIR-RECORD.md) · [10 月 24 日成功](../archive/handoffs/2026-10/2026-10-24-TV-PARITY-AND-DEVICE-REGRESSION.md) · [10 月 29 日复验](../archive/handoffs/2026-10/2026-10-29-TV-DISCONNECTED-PAGES-AND-WIRELESS-UPDATE.md)。

1. 同局域网发现真实电视，经Xcode开发配对后，CoreDevice读到完整硬件身份和连接状态；不能把遥控设备记录或同名Bonjour当作认证成功。
2. `xcrun devicectl device info details`现场核型号/系统/UDID/连接；随后用本机`pymobiledevice3.remote.native_tunnel.establish_native_rsd(serial=...)`复用Apple系统原生隧道，RSD身份再次匹配目标。这是本机历史已用能力，不能假定任意Python安装都具备同一接口。
3. 通过已认证的HouseArrest保存App偏好；核当前源/包哈希、签名和目标profile后，`devicectl device install app`保留数据覆盖，再核偏好/安装回执。普通启动与实际截图是独立验收；NAS暂停期间普通启动仍不执行。
4. DVT用于进程/截图等独立诊断，XCTest/WDA用于已安装App的遥控/界面窗口；安装、隧道与WDA不是同一层，WDA失效不能直接判设备断线。现在不运行历史脚本里的普通启动或NAS操作。

历史证据：[10月24日正式TV签名/安装](../archive/handoffs/2026-10/2026-10-24-TV-PARITY-AND-DEVICE-REGRESSION.md)、[10月26日CoreDevice覆盖与实际页面](../archive/handoffs/2026-10/2026-10-26-READONLY-WEBDAV-LIBRARY.md)、[10月28日至29日统一接入与分层收尾](../archive/handoffs/2026-10/2026-10-28-UNIFIED-PLAYBACK-INTEGRATION.md)。原始身份、已用脚本、包与取证在仓库外私有证据，不能将其旧地址/PID/签名期复用为当前现场。

当前工具为`/Applications/Xcode.app` 27.0/27A266a及`~/Downloads/Xcode.app` 26.6/17F113。主构建/Device Hub沿27；[13的历史性能取证](../testing/CLI-DEVICE-OBSERVATION.md)及`prepare_wda_recovery.sh`仍用26.6兼容链，迁移实测完成前保留两套，不自动卸载或切全局开发目录。用户报告清理过缓存，但清理范围与开发连接变化的因果尚未确立；现已能重新发现电视，profile到期是另一个明确事实。

2026-10-24 当前状态：真实 AppleTV14,1/tvOS18.2 已 paired、developer服务可用，签名构建及安装成功；14:15 新增 DSM/Jellyfin 双入口包覆盖成功，14:16普通空环境实际截图已看。此前“开发连接未就绪”只作历史；不再重复配对/重启/要求系统更新。完整范围见[功能对照](../project/APPLE-TV-FUNCTION-PARITY.md)，本批见[电视迁移交接](../archive/handoffs/2026-10/2026-10-24-TV-PARITY-AND-DEVICE-REGRESSION.md)。

2026-10-19现场补充：[电视配对记录复核](../archive/handoffs/2026-10/2026-10-19-APPLE-TV-PAIR-RECORD.md)确认用户照片列有Mac、系统页无Developer；两版Xcode及26.6窗口仍无真实TV，定点只读服务返回AppleTV14,1/18.2。准确状态为“电视有配对记录，开发连接未就绪”，具体根因未知；不再笼统说未配对，不重复PIN/重启/升级。安装仍未发送。

2026-10-18 用户明确要求开始 TV App 开发安装，现已建立[独立原生 tvOS 工程](../../tvos/README.md)，不再仅停留在准备审计。Jellyfin 登录、媒体库/搜索/详情与原生播放流程已落地，模拟器 8 项规则测试及 1 项普通启动 UI 测试通过，真机平台无签名编译通过；实际电视签名、安装与播放尚未完成。详见[本批交接](../archive/handoffs/2026-10/2026-10-18-ORIGINAL-ROUTE-RACE-AND-TV.md)。

现场 AppleTV14,1 / tvOS18.2；用户在Xcode26.6实际TV的Pair窗口输入验证码并Connect，17:55:30原生日志确认PairAction success/error nil。配对后两版列表尚无可安装物理目标，native RSD返回RemotePairingError1005（不支持隧道），旧开发广播/有效tvOS profile仍缺。电视安装尚未发送，用户确认本次配对后仍无Developer菜单，用户已普通重启，现原生authenticated/硬件UDID可读且IPv6已知端口可连，但Xcode仍无安装目标；不要重复配对、升级电视或把tvOS27模拟器当真机。

## 启动时机

现在可准备独立tvOS target/签名、遥控器焦点导航、媒体库大屏草图和模拟器最小流程；移动端后台/PiP、字幕默认选择、续播及多NAS账号隔离稳定后接入共用播放链路，避免跨平台重复修同一问题。无需等iPhone所有非播放功能完工，但真实音频/HDR/遥控器和长时播放必须在Apple TV独立验收。

2026-10-07 审计时原移动工程仅`iphoneos iphonesimulator`、设备family1/2；2026-10-18新增独立 `tvos/NastartTV` 工程，iPhone包仍不能装到Apple TV。KSPlayer本地Package声明tvOS13；这仅证明依赖声明，尚未验证最终FFmpeg制品与所有App代码可在tvOS链接。10月7日审计时Mac已有tvOS27.0及Apple TV4K第三代模拟器，当时未启动/配对；10月18日现已实际测试并查看模拟器、完成原生配对，开发安装通道仍待完成。UIKit设备页、方向/手势、音频/视图生命周期不能整份直接搬到tvOS。

## 开发包安装

1. Apple TV与Mac连接同一个可互通的局域网，电视开机。Apple TV打开“设置→遥控器与设备→远程App与设备”。不需要把Apple TV通过iPhone的数据线连接Mac。
2. 新Xcode使用Device Hub（管理设备）；旧版本使用“Window→Devices and Simulators”。选发现的Apple TV，发起配对，在Mac输入电视显示的验证码。
3. 创建并选择tvOS App target，配置当前开发团队的有效签名/描述文件、包含该电视的设备身份，选择已配对Apple TV作为运行目标。
4. 构建并Run，Xcode通过网络安装并启动tvOS开发包。后续迭代仍核对每台设备的构建及安装身份并保留登录数据。

Apple官方明确：tvOS没有iOS那种Developer Mode开关；通过Device Hub配对后出现Developer Settings。不要要求用户先去Apple TV寻找iPhone的“隐私与安全→开发者模式”。初次配对需现场读取电视验证码，必要时再请求用户提供，需要现场配对时再操作。

## 第一版范围与验收

- 先NAS/账号选择→Jellyfin/文件媒体库→详情→播放；遥控器聚焦、返回、暂停/seek/字幕菜单独立设计。
- 共用媒体请求、播放位置、账号隔离、认证与选流策略；tvOS播放器呈现和遥控器适配独立。Agent只改变资源发现/连接时尽量保持播放请求边界，若中转媒体则另外验证Range/HLS/取消/续播。
- 编译/模拟器通过之后配对真机，核对型号、tvOS、UDID/签名、包哈希/覆盖安装/正常启动。先S01/SDR基础，再S03大文件/ASS、S19深位置/PGS、HDR及实际输出音频；NAS负载先串行，再独立并发。
- 模拟器不能证明实际电视HDR/杜比输出、音频、网络吞吐、遥控器手感或真机流畅。移动端已通过项也不能直接填为Apple TV通过。

官方依据：[Apple TV无线配对](https://help.apple.com/xcode/mac/current/en.lproj/devbc48d1bad.html)、[在真实或模拟设备运行](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[Developer Mode与tvOS例外](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。

版本依据：[Apple官方支持表](https://developer.apple.com/xcode/system-requirements)中Xcode26.6支持tvOS15及以上设备、Xcode27支持tvOS17及以上设备，tvOS18.2均被覆盖。SDK版本不等于最低真机系统，当前TV工程最低16.0；不得凭隧道探测错误要求升级系统。
