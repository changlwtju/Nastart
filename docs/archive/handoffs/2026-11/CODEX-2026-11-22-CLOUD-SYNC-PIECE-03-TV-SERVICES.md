# Cloud 同步第 3 件交回 Muse

2026-11-22 · `/Users/lagransun/workspace/Nastart` · `main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加现有未提交修改。[Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-03-TV-SERVICES-2026-11-22.md)

## 实现与公共源码

- `ios/Nastart/Nastart/Core/Stores/CloudSyncRecord.swift` 同时编入 iOS 和 tvOS，提供 `CloudSyncServices`、手动服务 Codable 模型、`NastartServices` / `services-workspace` 记录身份、v2 读写、数据库接口与 `updatedAt` 合并策略。iOS 的 `CloudSyncStore.swift` 使用这套记录代码，`ManualLaunchpadServiceStore.swift` 保留 iOS 专属的服务转换。
- `ios/Nastart/Nastart/Core/Models/LaunchpadServiceIdentity.swift` 同时编入两端，提供 `LaunchpadVisibilityKey`、DSM 字段优先级和服务名称解析。iOS 的 `NASModels.swift` 和 `DSMClient.swift` 使用共享函数；`TVDSMClient.swift` 单独计算键，电视页面继续显示原来的容器名、镜像与套件版本。
- `TVCloudSyncStore.swift` 管理本地 `tv.service.visibility.v1`、一次性旧键迁移、待上传开关和服务记录同步。`NastartTVApp.swift` 在首次进入及每次回到 `.active` 时发起拉取。`TVNASViews.swift` 的启动台与「管理显示」使用同一视图状态，开关操作立即本地保存并触发上传。`AppTheme.swift` 的电视 iCloud 页面说明服务显示同步的范围。
- 两个 `.xcodeproj` 显式加入共享源码和 `ServiceVisibilityIdentityTests.swift`，测试在各自的 App 宿主运行。

电视写入时读最新记录，按 `updatedAt` 比较是否应应用远端，并在本地胜出时只将待上传的开关合入云端可见性字典。读到的手动服务 JSON 对象和未知字段原样保留；写入冲突会重新读取并重新合并，读取失败时保留本地开关和待上传编辑。服务记录首次创建仍由 iOS 负责，以便先迁移 v1 服务数据。电视上显式保存「显示」和「隐藏」两种操作，因为两端的默认可见性不同。

旧键按已发现行的原 ID 映射。对应容器或套件清单成功读取后，已有新键优先，确实无匹配的旧键丢弃。发现失败的清单保留旧数据，等待成功后完成该部分迁移。正常电视构建使用本地存储，mock 通过同一个入口注入数据库。未来已配置 CloudKit 的构建可以启用 `NASTART_TV_ICLOUD` 接到默认私有数据库，本批不启用该配置。

## 键对齐

夹具的容器名和镜像取自 2026-10-13 保存的 iPhone 13 DSM 发现快照，旧 ID 为合成值。2026-11-21 Muse 在电视上确认列表包含同名容器。[电视清单验收](MUSE-TO-CODEX-2026-11-21-TV-MGMT-PAGES-ACCEPTANCE.md)

| 已发现容器 | 两端期望键 |
| --- | --- |
| `homepage` | `container\|homepage\|ghcr.io/gethomepage/homepage:latest` |
| `homepage-dockerproxy` | `container\|homepage-dockerproxy\|ghcr.io/tecnativa/docker-socket-proxy:latest` |
| `jellyfin` | `container\|jellyfin\|jellyfin/jellyfin:latest` |

容器键用 DSM 记录的镜像作为 detail，并按 iOS 现有服务规则取名称。例如 iOS 卡片名为 `Jellyfin`，电视行显示 `jellyfin`，归一化后相同。基础设施镜像的规则保留容器原名，避免把 `homepage-dockerproxy` 错判为 Homepage。iOS 反代卡片与普通容器使用同一键。套件键用 iOS 现有字段顺序取得名称作为 detail，夹具为 `package|download station`。DSM 键为 `dsm`。

当 Agent 丰富已有 DSM 卡片时，iOS 保留这张卡片的名称及已有 detail，因此继续使用 DSM 键。**只有 Agent 生成了卡片而 iOS 缺少对应 DSM 卡片时，实测规则产生不同键**，例如 `container|jellyfin|agent · 8096` 与 `container|jellyfin|jellyfin/jellyfin:latest`。电视没有 Agent 发现数据，无法确认同键，mock 也明确验证此差异。此场景保留原有 iOS 键和远端原条目，电视按 DSM 键处理，无推测匹配。缺少可用于 iOS 解析的识别字段时，电视不会产生可上传的键。

## 构建与测试

| 平台 | 工具链和环境 | 构建及测试结果（北京时间） |
| --- | --- | --- |
| iOS | Xcode 26.6（17F113），iPhone 17e，iOS 26.5 | 14:31:08–14:35:09，Debug App 和宿主测试编译链接，`TEST SUCCEEDED`。18 项通过，0 失败，0 跳过。 |
| tvOS | Xcode 27.2（27B52），Apple TV 4K（第 4 代），tvOS 27.2，arm64 | 14:32:44–14:34:23，Debug App 和宿主测试编译链接，`TEST SUCCEEDED`。23 项通过，0 失败，0 跳过。 |
| iPhoneOS Release | Xcode 26.6，arm64，无签名 | 14:35:37–14:38:21，`BUILD SUCCEEDED`。主程序 SHA-256 `26c3b647d0c45bdeb63d0f921221a96f002c0d944d7aae4d04a255e42e6b5cbf`。 |
| AppleTVOS Debug 传输分支编译 | Xcode 27.2，arm64，无签名，仅编译 | 14:37:56–14:38:33，`BUILD SUCCEEDED`。主程序 SHA-256 `ca9ee54726c58b23d49f142c33c03f0106a00390c182de6b363dd4c0750c3cb8`，`NastartTV.debug.dylib` SHA-256 `e66d372cc71282ad2374e63f545e6556a3961cce2038e31e3abd7480a133166f`。 |

新增的共享 `ServiceVisibilityIdentityTests` 在 iOS 运行 2 项，在 tvOS 运行 6 项。两端各自用生产发现解析路径核对上述三组键。iOS 宿主通过实际 `AppDataStore.setService` 与 `CloudSyncStore` 发布隐藏，并应用电视写入格式的显示开关。电视宿主运行真实 `TVCloudSyncStore` 和启动台筛选，mock 验证启动与前台读取、切换后写入、仅访问服务记录、保留手动服务和其他开关、迁移、读取失败、版本冲突与待上传数据重启恢复。其他通过项为 iOS 的 16 项既有同步和 Agent 回归，以及 tvOS 的 17 项既有 DSM 客户端回归。

电视模拟器首轮同时尝试 x86_64，依赖解析报 `Unable to resolve module dependency`（KSPlayer、NetworkMedia）。用本机模拟器的 arm64 重新构建并完成测试。iOS 沿用临时 scheme 绑定测试目标和第 1、2 件的 `EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift`，该播放测试文件曾有独立的 `target` 参数编译错误。

额外 AppleTVOS 编译用 `OTHER_SWIFT_FLAGS=$(inherited) -DNASTART_TV_ICLOUD` 检查未来可启用的传输分支，验证了二进制引用 `CKContainer`。首试覆盖整个编译条件导致 KSPlayer 的 `Bundle.module` 重复定义，改成追加编译选项后通过。该分支只做无签名编译。Muse 使用正常构建配置。

本机私有证据在 `~/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-03.XTOYqV`，包括日志、`CloudSyncPiece03iOS.xcresult`、`CloudSyncPiece03TVArm64.xcresult` 和 `simulator-binaries.sha256`。设备架构产物分别在 `iOSDerivedData/Build/Products/Release-iphoneos/Nastart.app` 和 `TVDerivedData/Build/Products/Debug-appletvos/NastartTV.app`，日志分别为 `ios-device-build.log` 与 `tv-device-r2-build.log`。两台独立模拟器已清理，真机更新及 UI 验收由 Muse 接续。

从工作区根目录复跑，先指定当次的模拟器 UUID。

```sh
nastart_piece03="$HOME/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-03.XTOYqV"
shasum -a 256 -c "$nastart_piece03/cloud-sync-piece-03-sources.sha256"
DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer xcodebuild test \
  -workspace "$nastart_piece03/Nastart-CloudSync.xcworkspace" -scheme Nastart-CloudSync \
  -configuration Debug -destination "platform=iOS Simulator,id=$ios_simulator_id" \
  -derivedDataPath "$nastart_piece03/MuseiOSDerivedData" -parallel-testing-enabled NO \
  -only-testing:NastartTests/ServiceVisibilityIdentityTests \
  -only-testing:NastartTests/CloudSyncRecordSplitTests \
  -only-testing:NastartTests/CloudSyncTaskTombstoneTests \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testCloudSyncMergePolicyProtectsNewerLocalChanges \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testAgentSnapshotMergerUsesSharedServiceRegistryForVisibility \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project tvos/NastartTV/NastartTV.xcodeproj -scheme NastartTV \
  -configuration Debug -destination "platform=tvOS Simulator,id=$tv_simulator_id" \
  -derivedDataPath "$nastart_piece03/MuseTVDerivedData" -parallel-testing-enabled NO \
  -only-testing:NastartTVTests/ServiceVisibilityIdentityTests \
  -only-testing:NastartTVTests/TVDSMClientTests \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
```

## 源码 SHA-256

清单 `cloud-sync-piece-03-sources.sha256` 自身 SHA-256 为 `09f4ad2e3ca0fcb0b4d1900eeeb1e4745ca0683f3ec9b83e73998252abd9b7b0`。范围为本批源码、测试和工程文件共 14 项。

| 文件 | SHA-256 |
| --- | --- |
| [LaunchpadServiceIdentity.swift](../../../../ios/Nastart/Nastart/Core/Models/LaunchpadServiceIdentity.swift) | `f197995669cdf1fb59f7f3c04398214bea4ca51ddaef2fbd61f6638fb548b7f2` |
| [NASModels.swift](../../../../ios/Nastart/Nastart/Core/Models/NASModels.swift) | `7967c511af66e58f00c2de7d917f9148895712a4912ed4738f62516f7bfd54d0` |
| [CloudSyncRecord.swift](../../../../ios/Nastart/Nastart/Core/Stores/CloudSyncRecord.swift) | `d7d4c9ad6817963fda2cc3fcf728e9355dda05de8e2ad5c7990fdc4b883b1850` |
| [CloudSyncStore.swift](../../../../ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift) | `69e95fbeb5a35ff5e529a3ad80a58637a350cd5e8371344ee1279688f4c41ae9` |
| [DSMClient.swift](../../../../ios/Nastart/Nastart/Core/Stores/DSMClient.swift) | `667a4e244f69e0c7dff61a9c58f71838c7856660af3462b8e15c2141a1559545` |
| [ManualLaunchpadServiceStore.swift](../../../../ios/Nastart/Nastart/Core/Stores/ManualLaunchpadServiceStore.swift) | `e6b9dc5cb0e2d12eb3844a04989ea5a383f2e18156e49cac0fc474b8505337a0` |
| [AppTheme.swift](../../../../ios/Nastart/Nastart/Core/Design/AppTheme.swift) | `639c524aae924e98d46270bab648b78e986ba494e0e2a91f3593d8f37c768b7d` |
| [TVCloudSyncStore.swift](../../../../tvos/NastartTV/Sources/TVCloudSyncStore.swift) | `e21d31faffa57662290f8dfe04486c2758c870c206bf9f7c7bf75552ad74ad38` |
| [TVDSMClient.swift](../../../../tvos/NastartTV/Sources/TVDSMClient.swift) | `bbb53412743aa9ed9bce12740991222cb61ebea5d3f6967aa50b09815a880772` |
| [NastartTVApp.swift](../../../../tvos/NastartTV/Sources/NastartTVApp.swift) | `874bc7aacad31f969c88678e7817d77c59a80265c0ed13c4367c180873efe565` |
| [TVNASViews.swift](../../../../tvos/NastartTV/Sources/TVNASViews.swift) | `ef267bcfa26f279658db11b30580332d2936740302480fd04d20646293e3e957` |
| [ServiceVisibilityIdentityTests.swift](../../../../ios/Nastart/NastartTests/ServiceVisibilityIdentityTests.swift) | `053b6fa91d774bed064748e0ef26c8b676766900d6c05f34938f6c2d73c40c3b` |
| [iOS project.pbxproj](../../../../ios/Nastart/Nastart.xcodeproj/project.pbxproj) | `c0cf8327131b6175cfa8a8f2a6ea9364893e14193c33dc479f3e96cca33e7c63` |
| [tvOS project.pbxproj](../../../../tvos/NastartTV/NastartTV.xcodeproj/project.pbxproj) | `fba800e9e8b3b0a759b79b821e102f49db10f9b7fcb8081a70ba36c796f63ba3` |

## Muse 接续

1. 在上述工作区核对文件 SHA-256，使用本页命令分别复跑 iOS 和 tvOS mock。检查双向显隐、手动服务字段保留、旧键迁移及服务记录读写隔离。
2. 用 Xcode 27.2 构建普通签名 tvOS Debug 包。用户指定设备后按真机规程核对本轮设备与包身份，保留数据覆盖安装。检查正常启动、已有 DSM 登录及服务清单、管理显示开关、冷启动后本地显隐，以及 iCloud 页的服务范围文案。按需用 Xcode 26.6 构建指定 iOS 设备的普通签名 Debug 包，核对已有服务与可见性。跨设备云行为以 mock 验收。
3. 失败时在 [Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-03-TV-SERVICES-2026-11-22.md) 写回源码与包 SHA-256、设备和系统、安装及启动证据、复现步骤和对应截图、日志或 `.xcresult`。键不一致时只记录脱敏的发现来源、名称、镜像或 Agent detail 及两端键。
