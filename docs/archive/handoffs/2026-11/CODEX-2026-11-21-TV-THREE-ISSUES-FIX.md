# Apple TV 三项问题修正候选与验证边界

2026-11-21 16:36 北京时间。依据用户指定的 `docs/handoffs/TV-THREE-ISSUES-PROBE-2026-11-21.md`，基于当前 HEAD 与所有既有 dirty 源码继续修改，未回退其他人的内容。**本批为已编译链接的候选，三个问题均未通过修后真机验收，不作为完成交付。**

## 本批修改的六个文件

| 文件（均位于 tvos/NastartTV） | 本批变化 |
| --- | --- |
| Sources/TVJellyfinClient.swift | Authorization 的 MediaBrowser 字段补 Token；记录端点类别、实际 HTTP 状态与短 SHA-256 token 指纹；增加失败后 Users/Me 的只读策略标志诊断。 |
| Sources/NastartTVApp.swift | 记录续登请求、跳过原因、认证成功、Keychain 会话写回及触发页面重新加载；不删除被拒密码；已更新账号的旧请求可识别新会话。 |
| Sources/TVViews.swift | 首页 Resume/最近添加的 401 也可进入有界续登；读库恢复失败后追加只读账号策略诊断；tvPageInsets 在 tvOS 17+ 按 ScrollView 可用宽度约束整页，16 保留兼容撑宽。 |
| Sources/TVNASViews.swift | 服务详情目的地从 LazyVGrid 单元移至外部 navigationDestination；详情交给 NavigationStack 原生 Menu 返回；信息卡可获焦并添加真实宽度测量标识。 |
| Tests/TVClientTests.swift | 更新标准认证头契约；补禁用旧认证、旧 token 401 → 登录 → 新 token 三路首页请求、未认证请求不携 token 的测试。 |
| UITests/TVLaunchTests.swift | 保留三探针输出，移除这三项主动 XCTFail，改为验收断言；Jellyfin 优先经过存储与媒体并退出重进，Docker 连续三个容器，详情测量内容卡宽度 ≥1400。 |

TVAccountVault.swift、TVUnifiedPlayback.swift 等本来已有的改动保留，本批没有修改。

## 认证定位与实际证据边界

源码可以确认旧电视客户端 Authorization 只有设备信息，token 仅在 X-Emby-Token。Jellyfin 官方实现先读取标准头 Token，旧头只在 EnableLegacyAuthorization 开启时读取：[官方 AuthorizationContext.cs](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Server.Implementations/Security/AuthorizationContext.cs)。因此该请求契约存在真实兼容性缺口；**当前电视服务版本、旧认证配置、实时 HTTP 与账号策略尚未现场取得，不能把该缺口直接认定为本次电视全部 401 的已证根因**。继续观看可见也不能证明同窗另外两路请求使用相同有效会话。

日志 subsystem=com.changliwen.nastart.tv，category=JellyfinSession。核对顺序：`http route=UserViews status=401` → `renew_requested` → `renew_login_started` → AuthenticateByName 状态 → `renew_login_succeeded` → `session_saved` → `renew_persisted_reload` → 三路新指纹请求。跳过原因区分 identity / in_progress / no_saved_password / renewed_token_rejected_no_login_loop。旧账号没有保存密码时仍需在 App 内重新授权，不复制手机凭据。刷新仍拒绝时记录 Users/Me 的 HTTP 与 disabled/allDevices/allFolders/playback 四个布尔值；allDevices/allFolders=false 本身不证明无权限，需结合允许范围与服务端授权日志只读核对，不能自动修改服务配置。

不记录原始 token、域名、用户 ID、密码、响应体或文件夹/设备授权列表。没有伪造本轮实际 HTTP 状态或 Keychain 写回成功。

## 已执行验证

- Xcode **27.2 / 27B52** 已现场核对。
- 28 个当前 App 源码输入使用 Xcode 27.2 的 tvOS 27.2 SDK / arm64 / Debug / tvOS 16 deployment 编译成功，使用已有依赖产物链接成功。完整输入哈希、命令及日志保存在本机证据目录；这不是完整签名安装包构建成功。
- 最新 `TVLaunchTests.swift` 用 tvOS SDK 与 XCTest Swift overlay 完整类型检查通过。这不是 UI 测试运行通过。
- 仓库真实 `TVJellyfinLibraryRoutingTests` 的 5 项测试，在 Mac XCTest 独立运行器执行，**5 通过 / 0 失败**。使用真实 TVModels / TVJellyfinClient 和 URLProtocol 响应夹具，不访问 NAS；MediaDetailDesign 枚举由现有共享源码原文抽取。覆盖客户端 HTTP 契约，不验证 SwiftUI 页面、TVAppState 的真实 Keychain 事务或电视账号。
- `git diff --check` 通过。文档检查见本轮最终记录。

## 标准构建与真机阻塞（本轮实测）

1. `devicectl list devices --timeout 12` 超时，未取得本轮设备名称、型号、系统与当前连接状态。本批未占用电视 Runner，未安装或启动 App，未改账号、NAS、VPN 或设备设置。
2. 标准 xcodebuild build-for-testing 首次在 SwiftPM 模块/清单缓存写入 EPERM；指定可写缓存后失败于嵌套 sandbox-exec / sandbox_apply Operation not permitted。
3. 原生 Xcode 打开电视工程并执行 Build，报告 KSPlayer / NetworkMedia / LibSMB2 已由另一项目或工作区打开，继而 Missing package product。关闭只读 AGENTS 文件窗口、重新解析现有依赖并重试，仍 Build Failed（16:30）。未更改包版本、签名、工程依赖或重置缓存。退出此 UI 尝试后保留电视工程窗口。
4. 手工编译只关闭编译器自己的嵌套宏子进程沙箱，外层执行限制仍在；不等于系统服务、签名或设备访问权限恢复。

## 三项验收状态

| 问题 | 本轮结果 | 仍需完成 |
| --- | --- | --- |
| Jellyfin 401/登录已失效 | 认证请求契约修正，5 个 HTTP 夹具测试通过；现场原因未证实 | 标准有效签名包；实际 HTTP/续登与写回；电影/电视剧/继续观看三行与退出重进，无错误；必要时只读核账号与设备授权 |
| 容器 Menu 返回 | 已移出懒加载单元目的地、取消详情自定义返回并补焦点；编译通过 | 由容器列表进入三个详情，各 Menu 回列表再 Menu 回启动台；启动台直达详情按 Menu 应回启动台，不能多 pop 一层 |
| 子页宽度 | 共用可用视口宽度约束，编译通过；测量断言已准备 | 连接管理、存储子页、服务详情及设备各子页 ≥1400；清流/栈列/流光分别核；连接管理需实际遥控到“我的”入口 |

标准构建修复后，先 fresh 核设备及签名与本批源码清单，保存必要诊断，保留数据覆盖并核实际启动，然后复跑：

```sh
xcodebuild test -project tvos/NastartTV/NastartTV.xcodeproj -scheme NastartTV \
  -configuration Debug -destination 'platform=tvOS,id=<本轮确认的UDID>' \
  -only-testing:NastartTVTests/TVJellyfinLibraryRoutingTests \
  -only-testing:NastartTVUITests/TVLaunchTests/testJellyfinEntryProbe \
  -only-testing:NastartTVUITests/TVLaunchTests/testDockerBackButtonProbe \
  -only-testing:NastartTVUITests/TVLaunchTests/testSubpageWidthProbe
```

连接管理导航局限继续保留，不能以此省略人工遥控验收；当前探针只覆盖部分子页与当前主题，不自动代表所有主题/设备页面。旧失败证据仍在原探针交接中，未覆盖或改成 PASS。

本机证据：`/tmp/nastart-tv-three-fixes-20261121`。候选 dylib SHA-256：`b40b542e7d00e9d6a98da3dc1774894b89f6d26c48edd138fbbf252c58d2b445`。该文件没有完整 App 签名，不可直接当安装包使用。

## 16:56 标准构建接续

原生 Xcode 27.2 用当前含未提交修改的独立工程副本完成 Build（16:54）和 Build for Testing（16:56），两次均显示 Build Succeeded。与原候选清单核对 27 个仓库 App 输入均匹配，另一个输入为生成的资源符号。复制目录 `/tmp/NastartTVVerify1652`。

最终产品 `/Users/lagransun/Library/Developer/Xcode/DerivedData/NastartTV-hedldllpjgmcbmbdybhnuykyxxdb/Build/Products/Debug-appletvos/NastartTV.app`，测试描述 `/Users/lagransun/Library/Developer/Xcode/DerivedData/NastartTV-hedldllpjgmcbmbdybhnuykyxxdb/Build/Products/NastartTV_appletvos27.2-arm64.xctestrun`。主程序 SHA-256 `6e6497831d7c063cf001ad34c04728e442e851e25bcbbc56762e98f0eb463d6e`，Debug dylib `5919500c2a6b9318d1f6a47d32a2b65f936aea8706c9c3b972b927f0a69e57a7`。Xcode 列出同一台 Appletv 27.2 的真实 UDID，profile 覆盖该机，UTC 2026-11-27 12:58:54 到期。OpenSSL 验证 profile 消息签名，未验证其信任链。当前命令会话 deep/strict 复核返回 CSSMERR_TP_NOT_TRUSTED，设备查询超时，未执行安装或探针。真实 HTTP、返回和宽度仍未验收。

## 代码交接

2026-11-21 用户明确分工：Codex 基于 Muse 的反馈做源码修正和优化，完成代码审查、编译与相关离线测试，必要时使用模拟器。用户通过 Muse 负责安装更新和真机调试验收。电视三项修正已交代码，Xcode 27.2 标准构建和测试目标构建通过，Mac HTTP 测试 5 项通过。电视效果待 Muse 实测。 共享同一项目工作区时直接使用当前六个源码及测试文件。独立副本使用本批前基线对应的六文件补丁。补丁已验证在本批前基线应用后逐字节匹配标准构建的输入。
