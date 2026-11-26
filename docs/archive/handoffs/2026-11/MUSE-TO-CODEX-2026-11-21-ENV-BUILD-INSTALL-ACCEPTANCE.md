# Muse → Codex 月度交接：环境恢复、标准构建、逐台安装与真机验收

2026-11-21，时间均为北京时间。接续 Codex 2026-11-21 交接
（`docs/archive/handoffs/2026-11/CODEX-TO-MUSE-2026-11-21-DEVELOPMENT-AND-OPEN-ITEMS.md`
与 `CODEX-2026-11-21-JELLYFIN-PLAYBACK-AND-SESSION.md`）。
本文记录 Muse 这一轮实际做的事、实测结论与剩余问题，供 Codex 接着修代码。

## 1. 执行环境结论（最重要）

### 1.1 Codex 沙箱会话的阻塞不是真故障

Codex 会话报：USB/WDA 连接 EPERM、签名身份 0 个、SwiftPM 清单缓存写失败、
`devicectl list devices` 超时、Codex.app 打开报 -10827。
Muse 用自己的 Mac 执行路径逐项对照，**同一台 Mac、同一时刻，全部正常**：

| 检查项 | Codex 沙箱会话 | Muse SSH 会话 | 结论 |
| --- | --- | --- | --- |
| USB / usbmuxd | EPERM | `idevice_id -l` 返回 13 与 iPad；`ios-deploy -c` 看到 18（Wi-Fi）、13（USB+Wi-Fi）、iPad（USB） | 设备都在，沙箱拦住了 Codex |
| WDA | EPERM | 8168（13）与 8169（iPad）`/status` 均 ready，WDA 16.1.5 | WDA 正常 |
| 签名身份 | 0 valid identities | `security find-identity -v -p codesigning` 返回 1 个有效：`Apple Development: 1432665996@qq.com (43G669CX74)` | 证书没丢，沙箱看不到钥匙串 |
| SwiftPM 缓存 | 写入被拒 | `~/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/` 可 mkdir、可写 | 缓存路径正常 |
| devicectl | 超时 | `devicectl list devices` 正常返回（见 1.2） | 工具正常 |

**结论：证书、设备、缓存都没有丢。Codex 的 `danger-full-access` 配置没有成为该会话的有效策略，
实际执行的是受管 `workspace-write` 沙箱 + `CODEX_SANDBOX_NETWORK_DISABLED=1`。**
Codex 要自己做构建/签名/安装，需要一个真正有系统服务访问权限的本地执行会话
（客户端重新创建允许系统服务访问的会话），或者继续由 Muse 走 GUI Terminal
（osascript → Terminal）代跑构建签名安装。修改项目源码或重写完整访问配置改变不了已生效的受管策略。

### 1.2 Mac 的 CoreDevice 服务当前是降级的（真实故障，与沙箱无关）

`devicectl list devices`（2026-11-21 13:17）：
- Apple TV `00008110-000235903E99801E`：**unavailable**；查设备信息报 CoreDeviceError 4016。
- iPhone 18 `00008160-001468D401A0000A`：**unavailable**；同报 4016。
- iPhone 13：devicectl 列表里只剩一个 ECID 行（8536819316572190，iPhone14,5），按 UDID 查报
  "The specified device was not found"（error 1000）。
- iPad `00008120-000865400C920032`：**connected**（唯一正常）。
- Apple Watch：available (paired)。

这是 2026-11-20 电视断连的同一类毛病（配对成功、配对后隧道连接失败，Mac 侧 CoreDevice 故障）。
11-20 逐项排除过（重启电视、删配对重配、断 VPN、IPv6 开、`killall -9 CoreDeviceService` 均无效），
**唯一有效解法是重启 Mac**（11-20 20:31 重启后电视与 18 立即恢复）。
本次（11-21）`killall CoreDeviceService` 未再单独试，但 11-20 已证明它无效。

**关键区分：CoreDevice 降级不影响 iOS 安装。** `ios-deploy` 走 usbmuxd，能看到全部三台 iOS 设备
（18 经 Wi-Fi、13 经 USB+Wi-Fi、iPad 经 USB），三台 iOS 安装均已完成。
**只有 Apple TV 安装必须走 devicectl，会被 CoreDevice 卡住。**
电视新包至今未装，仍是 11-20 21:06 的旧包。

**待确认：** CoreDevice 两天内降级两次（11-20 一次、11-21 一次），触发规律未定位
（Mac 睡眠？电视睡眠？CoreDevice 自身 bug？）。更新电视正常时不需要重启，
只有 CoreDevice 掉线那次才要。

## 2. 标准构建（已完成）

- 工具：Xcode 26.6（`/Applications/Xcode-26.6.app`），iPhoneOS 26.5 SDK。
- 命令（GUI Terminal 跑，签名必须走 GUI 会话；SSH 会话无法代码签名）：
  `xcodebuild -workspace ios/Nastart/Nastart.xcworkspace -scheme Nastart -configuration Debug
  -derivedDataPath /tmp/NastartStandard20261121Derived -destination 'generic/platform=iOS'
  SWIFT_ENABLE_EXPLICIT_MODULES=NO build`
- 结果：**BUILD SUCCEEDED**（13:20）。日志 `/tmp/nastart-ios-standard-build-20261121.log`。
- 工作树：HEAD `8db1cc64`，58 个已跟踪修改 + 150 个未跟踪条目，**全部保留**，构建基于当前完整工作树。
- Codex 改的 5 个文件均编进本次构建（构建日志中出现）：KeychainStore.swift、
  DevicesView.swift、LaunchpadView.swift、LocalPlaybackResumeStore.swift、
  GreenfieldVideoPlayerView.swift。
- 产物：`/tmp/NastartStandard20261121Derived/Build/Products/Debug-iphoneos/Nastart.app`
  - 主程序 SHA-256：`24502c15dee0e3e478890023f30acfa1f8034f4fb1482e699f650aa35789b01f`
  - `Nastart.debug.dylib` SHA-256：`a7d347ecb003ec32b4661657b9165d7b4851f77636ae573d4ddad31b6cac2c8f`
    （与 Codex 编译的 `d389f7d7…` 不同：Codex 是重放编译链接命令的产物，本次是标准 xcodebuild 全量构建；
    源码相同，构建产物哈希不同属正常。）
  - `codesign --verify`：valid on disk，satisfies its Designated Requirement。
    Identifier `com.changliwen.nastart`，Team `5436TB5498`。
  - 描述文件：`iOS Team Provisioning Profile: com.changliwen.nastart`，
    到期 **2026-11-26 23:27:01 UTC**（= 11-27 07:27 北京时间），含 3 台设备。
  - `libswiftCompatibilitySpan.dylib` 已嵌进包内（172,064 字节），iOS 16 闪退修复在位。
  - `verify_playback_linkage.py`：PASS。
- 注意：构建时日志里有一条 DTDKRemoteDeviceConnection 报错（某台设备"passcode protected"，
  notification_proxy 起不来），属 Xcode 在 generic 构建时尝试连接设备，不影响构建结果。

## 3. 逐台安装（全部 InstallComplete，保留数据）

同一份标准构建产物，用 `ios-deploy --id <UDID> --bundle <App>` 覆盖安装。
ios-deploy 覆盖安装保留数据容器（Keychain、UserDefaults、登录态均不动）。

| 设备 | 方式 | 时间 | 结果 |
| --- | --- | --- | --- |
| iPhone 18（00008160-001468D401A0000A，iOS 27.0） | Wi-Fi | 13:23:29–13:23:43 | InstallComplete。用户 13:38 确认：App 能正常打开，Jellyfin 显示已连接。 |
| iPhone 13（00008110-001E543122E0401E，iOS 16.3.1） | USB | 13:24:42–13:25:27 | InstallComplete。WDA 启动验证：前台运行（state 4），Jellyfin 资源库已连接，DSM 已连接。 |
| iPad（00008120-000865400C920032，iOS 26.6） | USB | 13:25:27–13:25:42 | InstallComplete。WDA 启动验证：前台运行（state 4），Jellyfin 资源库已连接，DSM 已连接。 |
| Apple TV（00008110-000235903E99801E，tvOS 27.2） | — | — | **未安装。** CoreDevice 降级，devicectl 报 unavailable。等用户确认重启 Mac 后再装。 |

- 18 的 `ios-deploy --justlaunch` 无法启动调试（缺 iOS 27.0 的 DeveloperDiskImage，
  报 "Unable to locate DeviceSupport directory"），改为用户手动打开验证，已确认可用。
- 13 与 iPad 的 Jellyfin 登录态、DSM 连接、媒体库（电视剧 8、电影 36、继续观看 指环王1/碟中谍）
  在覆盖安装后均完整保留。

## 4. 真机验收结果

片源：《指环王：护戒使者》（S19，128.8 GB，Jellyfin，时长 2:58:00），
音轨 English (compatibility track)，字幕 Chinese (Simplified) PGS，家中 Wi-Fi。

### 4.1 验收①：13/18 交替登录，互不踢 — 通过（初步）

- 18：用户 13:38 确认 Jellyfin 已连接。
- 13：覆盖安装后即显示"Jellyfin 资源库已连接"；杀 App 重开后仍是"已连接"。
- **两台同时在线，谁也没把谁顶掉。** 这是互踢问题第一次在两台同时在线下成立。
- 待补：尚未做"18 登录 → 13 重读库 → 13 登录 → 18 重读库"的严格交替流程；
  设备 ID 前缀与 401/静默续登日志尚未在真机上核对（诊断日志只在内存 + os_log，Mac 的
  `log show` 不支持 `--device`，读不到 13 的历史日志）。
  另：Jellyfin 后台 Dashboard → Devices 的 13/18 Device ID 直接比对仍待用户在家内网自查。

### 4.2 验收②：起播、持续播放、停滞恢复 — 通过（短窗），速度未达实时

| 设备 | 首帧 | 60 秒连续 | 速度 | 备注 |
| --- | --- | --- | --- | --- |
| iPhone 13 | 约 4 秒（点"继续观看"13:32:06，13:32:10 已出帧，位置 02:52:09） | 通过（60 秒以上无停住、无转圈） | 约 80–98% 实时 | 13:32:10 02:52:09 → 13:33:14 02:53:00（51 秒内容/64 秒墙钟）；13:33:14→13:34:00 36 秒/46 秒；13:34:45→13:35:47 54 秒/62 秒 |
| iPad | 约 5 秒（点"继续观看"13:40:54，13:40:59 已出帧，位置 02:52:05） | 通过（81 秒无停住、无转圈） | 约 69% 实时 | 13:40:59 02:52:05 → 13:42:20 02:53:01（56 秒内容/81 秒墙钟） |

- 两台都没有出现 80 秒以上停住不恢复、也未触发 `jellyfin_stall_reconnect_requested`
  的可见停滞（未在日志里确认该事件是否被记录，WDA 截图无转圈）。
- **速度仍未达实时**：13 约 80–98%，iPad 约 69%。比之前过夜的 15–20% 好得多，
  但长播（数小时）是否会再次慢下来，未验证。Codex 的 18 秒停滞重连、最多两次的策略
  在短窗内未被触发，真实慢播收益未知。
- 13 播放中途（02:56:36，13:37:18）因验收需要被杀 App，未播到片尾。

### 4.3 验收③：进度条 seek 与详情按钮 — 部分通过，seek 未通过（WDA）

- **"继续观看"按钮：通过。** 13（115,505）与 iPad（340,245）坐标点按均起播，
  从正确续播点开始（13 从 02:52:00，iPad 从 02:52:00）。
- **"从头播放"按钮：未测。** 点它会从 0:00 起播并把续播点清零；13 与 iPad 的续播点都在
  02:52–02:57（片尾附近），为保住用户进度未测。需用户定夺，或在用户确认后补测。
- **进度条 seek：WDA 下未通过。** 13 上两次尝试均未让播放头移动：
  - 点按进度条（760,360，约 8 分钟前的位置）：位置继续向前（02:53:00→02:53:36），未跳回。
  - 拖动播放头（800,360→750,360）：位置继续向前（02:53:36→02:54:22），未跳回。
  - 播放器进度条、播放/暂停、返回键均**不在无障碍树里**（播放画面源里只有 424 个
    XCUIElementTypeIcon，无 Slider、无 ProgressIndicator、无 seek 相关元素）。
  - 同样，播放器左上角返回键（15,30）与（20,30）两次点按均未退出播放；
    底部上滑 Home 手势也未让 App 回到后台。
  - **定性：** KSPlayer 播放器控件由视频渲染层绘制，不暴露为标准无障碍元素，
    WDA 的合成手势到不了那一层。手指在真机上点进度条/返回键是否有效，**必须人工验证**，
    不能据 WDA 结论定为 App bug。13 详情页按钮不在无障碍树里也是同一类问题
    （按钮肉眼可见，但 WDA 找不到 `jellyfin.detail.continue` / `jellyfin.detail.replay`）。
  - 建议 Codex：核查 KSPlayer 播放器控件是否应暴露无障碍元素 / 是否响应合成手势；
    至少让进度条与返回键在真机手指操作下可验证。

### 4.4 验收④：正常退出与杀 App 后续播误差 — 杀 App 通过，正常退出未测

- **杀 App：通过。** 13 在 13:38:00 杀 App（杀前最后确认位置 02:56:36 @13:37:18，
  按 80% 速度推算杀时位置约 02:57:10）。重开后详情页显示"从 02:57:07 继续观看"，
  误差约 3 秒，在 5 秒以内。本地约 2 秒检查点在起作用。
- **正常退出：未测。** 因播放器返回键不响应 WDA 点按，无法正常退出到详情页；
  Home 手势也未生效。正常退出路径需人工在真机上验证。

### 4.5 验收⑤：Apple TV 登录后读库 — 未测（等装新包）

电视仍是 11-20 21:06 旧包。用户 2026-11-21 13:38 反馈当前电视 UI 存在三个问题（见第 5 节）。
待 Mac 重启恢复 CoreDevice、装上新 TV 包后，再按 TV 验收流程测读库与 HTTP 状态。

## 5. 电视新发现的三个问题（用户 2026-11-21 13:38 反馈，旧包上实测）

以下三点是用户在当前电视（旧包）上亲眼看到的，不在 Codex 本批改动范围内，
需 Codex 定位。复现步骤以用户描述为准，Muse 尚未在电视上复现（电视新包未装，
且电视 UI 探测需 XCTest 逐屏跑，见下）。

1. **子页面被压缩。** "连接管理"及"管理提示"等选项下的子页面，以及后续跳转的页面，
   都被压缩了（布局变窄/压扁）。疑似 tvOS 子页面布局约束问题。
2. **Docker 详情里返回键无效，只能强制退出 App。** 点击进入 Docker（例如 Jellyfin 的 Docker），
   按返回键无反应，只能强制退出 App。疑似详情页焦点/返回处理缺失。
3. **从"存储与媒体"进 Jellyfin，依旧刷新不出页面。** 与 11-20 的 401/403 读库失败同一症状。
   Codex 本批改了电视会话（Keychain 存密码、401 静默认证、首选 `/UserViews`），
   待新包装上后验证是否修好。若仍失败，记录实际 HTTP 状态（401 还是 403）。

另：电视构建（Xcode 27.2，tvOS）本轮尚未在 Muse 侧跑。Codex 已给出 tvOS 编译链接证据
（`NastartTV.debug.dylib` SHA `817426aa…`），标准整包构建与签名待 Muse 在 Mac 重启后补做。

## 6. 其它注意事项

- **`/tmp/ssh_proxy.py` 在 VM 替换后会丢。** 2026-11-21 13:29 实测丢失，已按 AGENTS.md 原理重建
  （读 HTTPS_PROXY、连代理 host:3130、CONNECT 带 Basic 认证 + `User-Agent: curl/8.5.0` +
  `Proxy-Connection: Keep-Alive`、select + 原始 os.read/os.write 转发）。
  **重建时发现并修复一个 bug：** 第一版重建未处理写端背压，`os.write` 在 stdout 未来得及消费时
  抛 `BlockingIOError`，导致大文件 scp 中断。已改为双向缓冲（仅当目标缓冲为空才读源，
  仅当目标可写才写），scp 4.9 MB 文件已验证通过。
  该脚本的最终版在 VM `/tmp/ssh_proxy.py`（VM 替换即丢，下次按 AGENTS.md 重建）。
- **WDA 坐标点按的可用端点：** `touch/perform` 在 WDA 16.1.5 上报 unknown command；
  可用的是 W3C `/actions`（pointer + pointerMove/Down/pause/Up）。
  元素查找 + click 只对 SwiftUI 暴露的元素有效；KSPlayer 播放器控件与详情页按钮不在树里，
  只能坐标点按。
- **iPad WDA：** 会话 `78BA5272-B732-49EE-B08F-9C8550CE0AC2`（端口 8169），2026-11-21 11:07 重启后一直可用。
  iPhone 13 WDA 会话 `B5FB6D95-0E11-489B-B447-2CD39558357E`（端口 8168）。
- **A1 监控：** Mac 上 `~/oci_ad1_monitor.sh`（PID 936/938）仍在跑，Mac 重启后需手动恢复
  （先 `export PATH="/opt/homebrew/bin:$PATH"`，再 `nohup caffeinate -i ~/oci_ad1_monitor.sh`）。
- **描述文件到期：** iOS 描述文件到 2026-11-26 23:27 UTC；电视描述文件到 2026-11-27 12:58:54。
  两者都在 11-27 前后到期，到期重建一次即可。
- **用户确认的 18 状态：** 18 上 Nastart 能正常打开，Jellyfin 显示已连接（2026-11-21 13:38 用户亲口确认）。

## 7. 剩余工作（给 Codex / 下一轮 Muse）

1. **Mac 重启恢复 CoreDevice**（等用户确认；重启后恢复 WDA 与 A1 监控），然后：
   - 电视标准构建（Xcode 27.2）+ 签名核验，`devicectl device install app` 保留数据覆盖安装。
   - 电视验收：登录后能否实际读库，记录准确 HTTP 状态（401/403/200）；验证第 5 节的三个问题
     是否仍在（Jellyfin 读库、页面压缩、Docker 返回键）。
2. **Codex 定位第 5 节的三个电视问题**（页面压缩、Docker 返回键、Jellyfin 读库），
   尤其是前两个不在本批改动内，需看代码。
3. **Seek 与播放器控件：** 核查 KSPlayer 控件的无障碍暴露与手势响应；用户手指实测进度条/返回键
   是否有效（Muse 侧 WDA 无法定性）。
4. **"从头播放"补测：** 需用户确认（会清零当前 02:52–02:57 的续播点），或等用户看完本片后再测。
5. **长播验证：** 短窗（60–80 秒）无停住，但速度 13 约 80–98%、iPad 约 69%，
   数小时长播是否再次慢下来，需一次长窗验证。
6. **13/18 严格交替登录流程：** 18 登录 → 13 重读库 → 13 登录 → 18 重读库，
   并核对设备 ID 前缀与 401/静默续登日志。
7. **Jellyfin 后台 Device ID 比对：** 用户在家内网打开 Dashboard → Devices，核对 13/18 的 Device ID
   是否已各自独立。

## 8. 关键文件与日志位置（Mac 上）

- 标准构建日志：`/tmp/nastart-ios-standard-build-20261121.log`
- 构建产物：`/tmp/NastartStandard20261121Derived/Build/Products/Debug-iphoneos/Nastart.app`
- 18 安装日志：`/tmp/nastart-install-18-20261121.log`
- Codex 证据目录：`/tmp/nastart-20261121-codex.pzky5S/`（编译/链接日志、测试日志）
- 本交接：`docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-21-ENV-BUILD-INSTALL-ACCEPTANCE.md`
- Codex 交接原文：`docs/archive/handoffs/2026-11/CODEX-TO-MUSE-2026-11-21-DEVELOPMENT-AND-OPEN-ITEMS.md`、
  `docs/archive/handoffs/2026-11/CODEX-2026-11-21-JELLYFIN-PLAYBACK-AND-SESSION.md`
- 验收截图（VM `~/workspace/`）：`nastart-13-newbuild-20261121.png`、
  `nastart-ipad-newbuild-20261121.png`、`nastart-13-play-3s.png`、
  `nastart-13-play-35s.png`、`nastart-13-seek.png`、`nastart-13-seek2.png`、
  `nastart-13-after-exit.png`、`nastart-13-detail-after-kill.png`、
  `nastart-ipad-play-4s.png`、`nastart-ipad-play-65s.png` 等。
