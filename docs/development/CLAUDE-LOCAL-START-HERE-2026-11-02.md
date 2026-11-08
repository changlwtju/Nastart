# 本地 Claude Code：从这里开始（2026-11-02 13:45，云端会话交接）

给在用户 Mac 上直接运行的 Claude Code 会话。云端会话只能写文件、点界面，没有 Xcode；你有真正的 macOS 命令行，可以自己构建、测试、装模拟器。先读 CLAUDE.md / AGENTS.md，再读本文，以用户最新指示为准。用户用中文，每段任务结束要给小结：做了什么 / 做到哪 / 下一步 / 需要你；不要每步都等用户，做完一项自动进入下一项。

## 已完成并并入主目录（Codex 已构建验证，六配置通过）
- 第七批：密码输入 DEBUG 归因夹具（`--offline-password-*`、`password-probe-uikit|swiftui`，匿名 trace）。
- 第八批：外观偏好可注入读回（`AppearanceStore(defaults:noteChange:)`、离线 `settings→外观`）、清缓存逐步清理与部分失败反馈（`PrivacyCacheCleaner`）、原生分享结果（`NastartShareButton`，成功不弹，仅失败提示）。
- 密码行“已保存 · 更改”（LibraryViews.swift）：编辑已保存连接且原密码非空时显示“已保存”+“更改”，点更改清空并聚焦空密码框，旁有“取消”恢复；新建连接不变；离线场景带 `--offline-password-cell` 时仍是旧原生框。
- 结论：密码“首次输入替换预填值”(A) 在纯 UIKit、裸 SwiftUI 和正式表单上都复现（iPhone 17 Pro / iOS 27.0 模拟器，12→1），是 iOS 安全输入框系统行为，不是我们的 bug。“显示密码后失焦”(B) 仍是独立未关闭问题。
- 报告都在 `docs/archive/handoffs/2026-11/`，Claude 的以日期开头，Codex 的以 `CODEX-` 开头。

## 正在进行 / 下一步（按顺序）
1. Codex 正在做“本机假媒体库”：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-fakelib/`，只读 WebDAV 绑 127.0.0.1:8089，全是虚构电影/剧集/动漫（含缺海报、缺简介、超长中文名）。若 Codex 不再使用，你自己按此规格做。
2. 加一个仅 DEBUG 的离线场景 `local-library`：直接承载公开函数 `networkMediaLibraryView(nas: nil, ...)`（真实“存储与媒体”页，不带 NAS 上下文，不走普通根，所以不会触发局域网发现），再手动添加 `http://127.0.0.1:8089`，用来调海报墙、影视详情页、返回保位。注意 `OfflineMediaScene` 里 switch 无 default，新增 `Scenario` 要补所有 switch（OfflineUIScenario.swift、OfflineMediaScene.swift、LibraryViews.swift:603/667/1103、AppTheme.swift:1195 附近的 `existingScene`），并同步 OfflineUIScenarioTests；原“离线场景不构造 NetworkLibrariesModel”的注释要改成按场景说明。
3. 做一份逐页 UI 清单：四个主入口（启动台、设备、事项、我的）× 每个二级页 × 标准/大字号 × 横竖屏/iPad，模拟器截图，列问题再按严重程度排批次。
4. 之后：返回保位（海报墙退出详情）、SMB/FTP 本机夹具边界、播放确定性反例。路线图见云端文档“Nastart 优化路线图”（用户有链接）。

## 硬边界（沿用，用户未解除）
- NAS 停用：不发现、不连接、不认证、不探测；不启动会恢复 NAS 的普通根（用离线场景 `--offline-ui <scene>`）。
- iPhone 18 不动；Apple TV 签名被阻塞；iPhone 13/iPad 上的安装包早于源码；不要启动真机或 Runner（需要时单独问用户）。
- 不清理/回滚主目录里大量未提交修改，它们是被接受的基线；不要用旧 HEAD 4de732dd 当基线；写补丁前先 `git apply --check`。
- 共享状态（PROGRESS、CURRENT-PLAYBACK-HANDOFF、资源登记 AGENT-RESOURCE-STATE.json、需求状态）原由 Codex 单点维护。用户若不再用 Codex，由你接管，但先问用户并写明。
- 不卸载、不清账号、不碰 VPN/系统/签名/发布；不记录密码明文、长度、精确选区或真实凭据；未运行的项目必须写“未执行”；不再猜“延迟聚焦”这类参数。
- 只删自己能重建的构建产物；磁盘剩余约 6GiB（构建门槛 6GiB），大缓存在 `~/Library/Developer/Xcode/DerivedData`、`~/Library/Caches/Nastart`、`iOS DeviceSupport`。

## 构建与测试要点
- iOS 16+，SwiftUI，tvOS 目标，本地包 NetworkMedia；bundle id `com.changliwen.nastart`；Swift 5.0 模式；pbxproj 手写，避免新增文件。
- 用 `scripts/xcodebuild_nastart.sh`；六配置 = iOS/tvOS × (Simulator Debug、device Debug、device Release)，无签名、串行。独立 DerivedData，不用别批的。
- 单测：`OfflineUIScenarioTests`、`WebDAVConnectionFieldsTests`；宿主测试（app-hosted）需核无凭据/服务/缓存。
- 模拟器：只用自己创建的（名字以 Claude- 开头），用完删自己的；已有 `Claude-PW-iphone`（iPhone 17 Pro / iOS 27.0）可复用。
- 离线 UI：`--offline-ui <scene> --offline-ui-text-size standard|large`，主要场景见 OfflineUIScenario.swift。

## 本地会话能做、云端会话做不到的
自己跑构建/测试/装包、读完整日志、操作 git。仍需谨慎：真机控制与签名没有验证过，默认留给 Codex 或问用户。
