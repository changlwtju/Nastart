# Codex：11-02 下午至 11-03 UI 批次集成

2026-11-03（Asia/Shanghai）。按 [Claude 集成请求](2026-11-03-1600-CLAUDE-INTEGRATION-REQUEST.md)串行核对；Claude 已声明暂停源码写入。本轮没有更改产品源码。

## 基线和接入方式

- 主目录 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留全部历史 dirty 与暂存区。
- 接受基准为 saved-password 的 447 项 SHA-256 清单，规范化清单哈希 `617f1a573102eb8d6128f9ab8c0c1dca187c01f7cc035d9d83c99894c0b45d08`；当前 419 项相同、28 项变化、没有源文件新增或缺失。额外的 Xcode 用户 scheme 管理 plist 是生成配置，不属于产品输入。
- 28 份旧文件全部从此前同源独立目录找回，并逐字节哈希匹配；请求表中的前后摘要也全部匹配。Codex 在 13:14–16:18 之间只完成既定 saved-password 收尾、假库和 Claude 会话设置，没有改这 28 个产品文件。13:14 清单已含最终 saved-password 行；本批 LibraryViews 的 b0d 前值也吻合。
- Claude 已直接写在主目录，因此不重复 apply 或覆盖源码；本次接入是核来源、审增量、冻结、验证并登记接受。
- 当前 447 项规范化清单 SHA-256：`3a3f2c0a00f709163b0c41f2239d61a46e55446385b57adca070500eb2b04ae5`。完整输入与 28 文件增量见本机证据。

## 审查结论和接受范围

- **核心 store**：默认初始化仍使用 `.standard`，通知、同步、快照与连接逻辑保持正常路径；仅 DEBUG 能构造隔离实例。小存储通过注入 defaults 写临时域。新离线入口在正式 App 内容构造前分流。
- **TVAppState**：正式 init 仍依次读取 Jellyfin、NAS 钥匙串，再读/写安装 ID；改为显式初始化，没有改变此顺序。DEBUG 的 `init(offlineFixture:)` 账号 nil、固定设备 ID，不读钥匙串或写正式安装 ID。TV 根初始 tab 默认仍 launchpad；bold trait 注入只在 DEBUG 离线分支。
- **温度**：仅把 DSM 数值四舍五入后的显示后缀和示例的 `C` 改为 `°C`；字段选择、舍入、缺失返回 nil、请求均不变。已有缓存不迁移，下次获授权刷新才更新，NAS 暂停期间不为看单位发请求。
- **限宽**：`nastartReadableWidth` 仅 iOS 17+ regular 宽度设置 scrollContent 左右边距，目标约 720pt；iPhone/16 保持原分支。新增 25 个子页接入，海报墙、网页和本地预览保持原布局；iPad 标准字号三主题服务两列，无障碍字号回单列。
- **其余 UI**：接受海报卡裁切/详情兜底铺满、无计数进度文案、DEBUG 横幅背景、清缓存 alert、灰色禁用按钮、大字号紧凑宽度海报行、指挥中心设备指标及 TV T1–T5 的字号/焦点/标签改动；无播放解析、网络协议或数据迁移修改。TV 播放控制文件只改字体，不改变播放链路。
- **隔离边界**：`local-library` 使用本安装正式库/Keychain，只允许在自建模拟器连接指定合成 loopback；iOS/TV 根离线场景不是网络沙箱，登录表单与部分深层入口仍可能真实联网/写入。不能提交登录或点真实来源操作。
- 独立抽看三张交付图：iPad 服务详情限宽、TV T1–T5 对比、大字号手机海报列表。图像符合该批视觉变化；历史截图、Claude 真机报告与本轮实际运行的验证分列，不升级为本轮真机验收。

## 本轮验证

- iOS 与 tvOS 各 simulator Debug / device Debug / device Release，共六配置均 exit 0；每阶段结束核 447 输入未变。复用已释放的 SavedPassword 增量缓存，未并发重构建或删除他人缓存。
- NetworkMedia 完整包首次运行在既有 `TransportIntegrationTests.tearDown()` 的 `Process.waitUntilExit()` 卡住；保存自有测试进程 sample 后只停止本轮进程组，失败记录保留。一次限时、免重编译的原样测试重试通过 **305 项，0 失败**（9.384 秒）；没有修改测试或声称 teardown 问题已修。
- 新建空白、无账号/服务/Keychain 的专用 iPhone 17 Pro / iOS 26.5 模拟器运行五类宿主测试：**203 项＝202 通过、1 跳过、0 失败**。跳过是已有 `testDeviceEnvironmentPublicEndpoints`，原因原文 `Device endpoints must be explicitly configured`；没有配置或请求真机端点。覆盖 NonPlaybackPolicyTests、OfflineRootFixtureTests、AppearanceStoreInjectionTests、PrivacyCacheCleanerTests、NastartShareOutcomeTests。
- iOS / TV Release 的全部 Mach-O 中 **27 个 DEBUG 标记均为 0**，各平台 Debug 正对照成立；仅证明所查入口/标记排除，不代替完整生产安全审计。
- 宿主测试后自建实例 shutdown/delete 均 exit 0，fresh 核实例及数据目录已不存在；447 输入不变。原 Claude 模拟器保留。
- 正常 Debug 包独立签名构建 exit 0；30 个 Mach-O 逐个签名核验、整包 deep/strict 核验与 IPA 归档 CRC/二进制逐项 SHA-256 比对通过；没有安装或启动真机。

## 提交方式

采用本地审查分支 `codex/ui-integration-20261103`，不移动主目录 HEAD、不切换工作树、不改变真实 index、不推送。分三层保存：

1. 接受的历史源码检查点 `9e4feb769af5d95bc80254caa32b56ddcc56a32c`：从旧 HEAD 单独保存 307 个项目源码、工程和配套资源路径，28 文件恢复为已验证旧值；不混入历史文档迁移/删除和其它 dirty。447 项来源清单包含旧 Demo/Pods 等额外扫描输入，307 项并不表示全量依赖或离线可独立构建，干净环境仍需常规依赖准备。
2. Claude UI 增量 `c89c2a0584d9f804086d8dfeabc2b02f006b77e9`：父提交为上述检查点，diff **恰好本批 28 文件**，没有混入历史改动。
3. 本轮独有报告和结构化结果单独文档提交。共享摘要/登记在原工作区同步；由于这些文件继承了此前 dirty，不将其历史内容整体纳入本批提交。

源码归属为 Claude；Codex 做基线恢复、增量审查与集成验证。审查分支可直接逐层复核；主目录当前源码已是接受版本，不再重复应用补丁。

## 包和后续设备窗口

新正常 Debug `-Onone` 候选包已固定复制到本机私有证据 `normal-package/Payload/Nastart.app`，同目录上级有 `Nastart-Normal-Debug-20261103.ipa`；完整路径见登记。构建时间 `2026-11-03T16:22:25.282432+08:00`，现有签名 profile 到期 `2026-11-08T01:08:19Z`；未请求更新 provisioning。主程序 SHA-256 `0a63856a30314abb8f56bdf67804a45b79c2eab7f38891f201fff0799c28fc60`，debug dylib `8c8637f5379c9a9958d9dc83441dab88a41ecda0568f9688760d3bc6c9146135`，IPA `ab1f1a805ff73b180794d21e573bedb85e2a03b63b368962d4f125a054abb3d0`。其 447 源输入与当前冻结清单一致；本轮 0 真机安装，不能据此声称 13/Pad 已更新。

- **13 / A16 Pad 回归安排**：串行由 Codex 默认调度，先 fresh 核设备名称/型号/系统/UDID/连接与实际进程，保存偏好及必要诊断，再核新包签名/设备覆盖及安装身份；身份不明则保留数据覆盖，禁止卸载。只启动已审的安全离线场景，核清缓存 alert、禁用按钮、大字海报、根页面主题与 Pad 限宽/两列；取消与设置操作按实际 UI 能力另记，不能用截图代替触摸。
- 本次任务安排上述回归，未操作真机或 Runner；设备独占窗尚未 fresh 确认，不沿 Claude 旧安装记录声称已占用/已完成。Claude 报告 13 最新为设计第三批、Pad 为第四批，均早于 TV/宽屏/温度最终源；本轮新包未装，latest=false。
- NAS 暂停、18 hands off、TV 真机签名阻塞保留；不为当前包普通根启动、真实凭据、真实缓存/分享、真实 Jellyfin、VoiceOver 或帧时间添加通过。30 项需求状态、114 格播放矩阵不变。

## 证据和收尾

- 本机私有：`~/Downloads/Nastart-CodexEvidence-2026-11-03-ui-integration/`；指针 `/tmp/nastart-codex-ui-integration-path`。含基线恢复来源、完整前后清单、28 文件 patch、运行命令/日志、包和签名记录。
- 自建宿主模拟器与本轮进程清理结果见验证；未停止/删除 Claude-PW-tv、Claude-PW-iphone 等既有实例，未删他人缓存，未改 Claude 会话/设置/发送消息。
- SavedPassword 共享增量产物自 Claude 后续批次已被覆盖，旧包路径不能再用作其原始 UI/安装身份。新正常包另复制固定路径。
- 文档检查通过：655 documents / 3929 local links，Missing destinations: 0。
