# Jellyfin 播放恢复与账号会话交接

2026-11-21，时间均为北京时间。源码基于 `8db1cc64` 和当前工作树的未提交内容。项目已有并行修改，本批仅合入以下改动。

## 改动文件

| 文件 | 改动 |
| --- | --- |
| `ios/Nastart/Nastart/Core/Stores/KeychainStore.swift` | 设备 ID 统一从本机 Keychain 读取或生成，三个建客户端入口在同一进程共用该值。Keychain 不可读时记录状态。 |
| `ios/Nastart/Nastart/Features/Devices/DevicesView.swift` | 两个 Jellyfin 客户端接入同一设备 ID；401 附带 ID 前 8 位。 |
| `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift` | 登录及 401 恢复记录阶段和 ID 前缀；读库、搜索和详情接入同账号静默重登。详情与播放请求统一解析 Jellyfin ticks 和本机书签。继续观看、从头播放扩大命中范围，进度条处理点击、拖动与无障碍调整。 |
| `ios/Nastart/Nastart/Features/Launchpad/LaunchpadPlaybackCore.swift` | Jellyfin 每推进 4 秒报告进度，通用跟踪器保持原默认间隔。 |
| `ios/Nastart/Nastart/Playback/Core/LocalPlaybackResumeStore.swift` | 判断远端书签及本机检查点的优先级，限定播放断流重连预算。 |
| `ios/Nastart/Nastart/Playback/GreenfieldVideoPlayerView.swift` | 依据已确认时钟调用现有换源机制，播放暂停与生命周期边界主动上报当前位置。 |
| `ios/Nastart/Nastart/en.lproj/Localizable.strings`、`ios/Nastart/Nastart/zh-Hans.lproj/Localizable.strings` | 补齐 401 与静默续登的日志文案。 |
| `tvos/NastartTV/Sources/TVAccountVault.swift`、`NastartTVApp.swift` | 在当前设备 Keychain 按 Jellyfin 服务地址和用户隔离密码；同来源同用户的 401 可静默认证一次。 |
| `tvos/NastartTV/Sources/TVJellyfinClient.swift`、`TVNASViews.swift`、`TVViews.swift` | 首选 `/UserViews`，仅不支持该路由时使用旧端点。手动登录和 Quick Connect 取得新会话后先验证读库；过期时提供带原地址和用户名的重登入口。 |
| `ios/Nastart/NastartTests/PlaybackNextCoreTests.swift`、`tvos/NastartTV/Tests/TVClientTests.swift` | 覆盖续播选择、断流重连预算、暂停和待确认跳转、tvOS 请求和错误分支。 |

本地检查点沿既有路径约每 2 秒保存已确认位置。服务端 ticks 优先于百分比；本地检查点新于远端记录，或远端没有书签及看完标记时，显示与播放共用本地值。从头播放明确传入 0。等待续播定位、暂停、待确认 seek、片尾 5 秒及画中画不触发重连。已开始播放且确认位置 18 秒未推进时，允许从该点重新协商，同一轮最多两次，间隔至少 24 秒，持续推进 30 秒后恢复尝试额度。阈值及重连后的画面、字幕与声音连续性待真机验证。

## 编译与测试

| 项目 | 结果 |
| --- | --- |
| iOS Debug arm64 | 用 Xcode 26.6、iPhoneOS 26.5 SDK，重放 Xcode 的 Swift 编译与链接命令。当前全部 App 编译单元和 App 动态库链接通过。12:09:27，`Nastart.debug.dylib` SHA-256 `d389f7d733e9509a4aa257d9cd729769486691efb59fff416fd5bd61e1af26be`。 |
| tvOS Debug arm64 | 用 Xcode 27.2 AppleTVOS SDK 同法编译全部 App 编译单元并链接通过。12:06:23，`NastartTV.debug.dylib` SHA-256 `817426aa9091f701aed49461a8a5edee2b95617186a996c1e35d5db2a6582ed0`。 |
| 主机定向 XCTest | 编译项目实际续播存储、断流策略和 TV Jellyfin 客户端，运行仓库中的对应测试，8 通过、0 失败。TV HTTP 使用 URLProtocol 响应夹具。 |
| NetworkMedia XCTest | 共享 seek 执行、离线界面场景和 Jellyfin 数据源 23 通过、0 失败。额外的 3 项回环 HTTP 测试在夹具启动时超时，本会话独立验证绑定 `127.0.0.1` 返回 `EPERM`。 |

编译重用了现有 Apple 平台的依赖产物，重新编译了本批改动所在的 App 源码。标准 `xcodebuild` 整包流程因会话无法写入 Xcode 的 SwiftPM 清单缓存而中断；当前会话未找到可用代码签名身份。以上产物是编译和链接证据，完整签名包尚待生成。iPhone 18 本批未覆盖安装，iPhone 13、iPad、Apple TV 也未操作。各设备实际安装版本需由 Muse 开窗现场核对。

本机临时证据目录 `/tmp/nastart-20261121-codex.pzky5S` 包含双端编译和链接日志、`host-tests.log`、`network-mock-tests.log` 及回环夹具超时记录 `network-final-tests.log`。项目文档链接检查通过。

## Muse 真机验收

1. 生成并复核当前源码对应的签名包，保留数据覆盖目标设备。iPhone 18 之后与 iPhone 13 交替登录，双方各重新读取 Jellyfin 库，核对各机日志中登录、401、静默续登阶段的设备 ID 前缀。
2. iPad 和 iPhone 13 用原网络、S19 原音轨和 PGS 字幕，各测一次 10 秒内首帧和 60 秒连续播放，单次点击进度条后检查实际画面和播放恢复。记录 `jellyfin_stall_reconnect_requested` 及后续候选接管或失败；持续慢播仍按原待验窗口记录。
3. iPhone 13 人工点击“继续观看”和“从头播放”，核对两个 accessibility ID、详情书签与实际起播。正常退出和杀 App 各一次，重开详情，核对最后确认位置的误差是否 ≤5 秒。
4. Apple TV 用 App 内重登读库。遇到 401 时检查静默续登和再次读库；若仍失败，记录实际 HTTP 状态并验证重登入口。403 单独记录。

## 12:54 安装接续复核

收到用户“继续”后，重新查询当前会话的安装条件。签名身份查询仍为 `0 valid identities found`；USB 服务 `/var/run/usbmuxd` 和 WDA 本机端口连接均返回 `EPERM`；`devicectl list devices --timeout 12` 超时，未取得本轮设备身份。明确指定可写的模块、包缓存与派生目录并复用已有依赖缓存后，标准 Xcode 构建仍在 SwiftPM 清单诊断缓存写入时被拒。

复核实际编译输入与产物时间，iOS 57 个 App 编译输入、tvOS 28 个 App 编译输入均没有晚于本批二进制的源码。双端二进制哈希与上表一致。该核对不覆盖依赖的全量干净重建。

本轮更新终端数为 0。已更正资源登记中 iPhone 13、iPhone 18 和 iPad 的“当前源码已安装”字段，将较早安装记录保留为历史。真机设备和 Runner 均未接管。下一步需要在允许访问 Mac 签名服务、Xcode 缓存和设备开发服务的执行会话中完成标准构建、签名复核和保留数据覆盖，再交 Muse 验收。当前受管会话的 `sandbox_approval` 类别被自动拒绝，无法在本对话内提交此类权限请求。

## 执行环境原因复核

用户要求定位并解决访问失败后，读取当前本机配置，`sandbox_mode` 已为 `danger-full-access`，而当前对话实际由受管 `workspace-write` 策略运行，环境还设置了 `CODEX_SANDBOX_NETWORK_DISABLED=1`。`/var/run/usbmuxd` 实际存在且为 `srw-rw-rw-`，连接返回 `EPERM`。这些证据确认设备控制首先受当前执行沙箱限制。配置文件中的完整访问设置没有成为该对话的有效策略。

签名查询能定位到登录钥匙串路径，证书和身份查询仍无结果；当前结果不足以判断正常 Mac 用户会话中是否确实缺少证书或私钥。需在客户端重新创建允许系统服务访问的本地执行会话，先验证 USB、回环、Keychain 和 Xcode，再处理任何实际的证书或设备问题。当前没有可调用的客户端会话权限切换接口，修改项目源码或重复写入既有完整访问配置均无法改变已生效的受管策略。

用户要求直接操作客户端后，重新检索可用接口，当前未提供桌面点击或会话权限切换工具。尝试通过 AppleScript 只读查询前台应用，返回 `-10827`。USB 连接复核仍为 `EPERM`。当前未取得客户端 UI 控制能力，无法代替用户在客户端完成权限操作。
