# 2026-10-01 iPhone 13 工具恢复与 S01 短回归

执行时间：15:43～15:56，Asia/Shanghai。已先读 PROGRESS、当前交接、播放 runbook、竞品矩阵及任务总账；按用户最新范围只处理 iPhone 13，iPad 继续暂缓。未写 PROGRESS.md，保留全部既有未提交修改。

## 设备及最新包门槛

- 本轮开始及收尾 usbmux 均只枚举 `REDACTED-DEVICE-01`，现场名称 iPhone、型号 iPhone14,5（iPhone 13）、系统 16.3.1；配对 validate 成功。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，工作区保留既有源码、脚本、文档及 KSPlayer 修改。App 源码/项目配置最新文件仍为 AppTabRootView.swift，07:32:05；正常 Debug 二进制 07:32:39。未新增 App 源码，不重复构建。
- 最新正常包路径：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`。本轮 `codesign --verify --deep --strict` 通过。主 executable SHA-256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`；dylib SHA-256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。安装 IPA 中两文件哈希逐一相同。
- 安装前保留历史私有诊断，并尝试拉取 Preferences；此次 HouseArrest/AFC socket broken，目标不存在，不能记作备份成功。未卸载或清除数据。本轮保留数据覆盖安装取得 `InstallComplete (100%) / Complete` 完整回执，随后无测试环境变量/参数启动 PID 67618；WDA source、真实启动台截图及设备进程枚举均确认该进程。
- 正常启动后 DSM 恢复、Jellyfin 在线；收尾再次明确无变量正常启动 PID 67681，启动台截图及设备进程枚举确认持续存在。收尾 NAS 可见 CPU 30%、RAM 22%、磁盘 93%，不是本轮新增故障。下载报告中未见下午新 Nastart 崩溃，最新文件仍为 07:34:20。

## WDA 已恢复及启动脚本修正

- 未重装/重建 WDA，固定 host/test Bundle ID、历史签名/profile preflight 通过。此前设备授权阻塞本轮未再出现；15:44 XCTest Runner 启动并实际监听 8100，8102 转发取得 ready，session/source/screenshot/元素点击均可用。
- 默认 tidevice 因写 `~/.tidevice/ssl` 被当前文件权限阻止；复用上一轮私有 wrapper `/tmp/nastart-20261001-wda-resume/tidevice`，将缓存留在可写且私有的 `/tmp/nastart-20261001-resume/tidevice-cache`，没有修改 HOME 或系统工具。
- 首次 status 报 `com.facebook.WebDriverAgentRunner`；已对照历史 `FBSessionCommands.m:172` 与当前持久二进制字符串，确认这是未注入变量时的源码默认值。设备 appinfo 显示固定 host ID、`ProfileValidated=true`，本机签名包 host/test ID 相符；未把这个默认值当作另一个 Runner 安装失败。
- 修正 `scripts/start_wda_iphone.sh`：启动 XCTest 显式注入 `WDA_PRODUCT_BUNDLE_IDENTIFIER`，复用服务及启动完成均核对返回身份；身份不符直接报错，避免启动第二条未知链路。`prepare_wda_recovery.sh` 输出同样的恢复命令。
- 停止本轮旧 Runner 链路后实测重启：15:54 Runner PID 67680，status `ready=true` 且身份为 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`；重建 Nastart session/source/screenshot 成功，再次执行启动脚本直接复用 ready 服务。两脚本 zsh 语法检查、`git diff --check` 通过。
- 本轮启动命令：`TIDEVICE_BIN=/tmp/nastart-20261001-wda-resume/tidevice WDA_RUNTIME_DIR=/tmp/nastart-20261001-resume2/wda-final scripts/start_wda_iphone.sh`。收尾该 XCTest/转发仍在，下一轮必须重新核对状态；若临时 wrapper 已丢失，需恢复其可写缓存适配，不直接写用户受限目录。

## S01 Jellyfin 短回归

正常 Debug、无测试变量、单路 S01《哈尔的移动城堡》、新架构原画 KSPlayer。设备 Wi-Fi，上游本轮为公网域名 HTTP/2，不能解释为 LAN 回归或蜂窝结果。

| 路径 | 本轮证据 | 边界 |
|---|---|---|
| 从头播放 → 退出 | trace `3E6C5DF1`，内部首帧时钟信号 0.094 秒，tapToFirstFrameMs=1003；48 条 playbackTick，1.182→51.572 秒，读字节推进，stallCount=0、丢帧/丢包样本均 0；真实影片画面截图与退出回同一详情、继续观看按钮齐全，ended 事件 1 | 首帧内部信号不是屏幕精确首帧计时；第一张名为 s01-first 的截图实际仍是准备中详情，不当首帧证据。实际视频证据在后续截图。未做听音、十分钟或完整字幕验收 |
| 热续播 → 退出 | trace `D5EBFE4C`，内部首帧位置 51.870 秒，tapToFirstFrameMs=1699；38 条 playbackTick，51.785→91.870 秒；截图有真实画面/时钟，退出回同一详情，ended 事件 1 | 启动阶段 stallActive=yes、stallCount=1；末段 stallActive=no，累计 droppedVideoFrames=1，不能报整轮零卡顿/零丢帧。缺完整缓冲时长及听音证据 |

截图名 t15/t30 是采集标签，不作为精确 t=15/30 秒定时证明；计时以原始日志和文件时间为准。两轮仅补充 PX-01/PX-21 的短路径证据，不将总账整项改为通过，也未验证 PX-03 原始冻结根因或真实失败恢复。

## 滚动与 Lenna 对照

- `xcrun xctrace list devices` 仍为 No devices available；滚动脚本实际尝试报 No devices found matching 当前 UDID，在采样开始前终止，0 次手势。保存 record.log/run.json/summary.json，自动结果 `INSUFFICIENT`，不丢弃失败。此次采样尝试在 Jellyfin 搜索页，不是海报长列表验收；旧 manifest page 标签 jellyfin 不代表全库页面已测。
- Lenna 本轮现场安装版本 1.0.17；从既有“我的 Jellyfin”配置进入资源库，搜索并进入同名 S01 详情，未修改服务配置/购买订阅/升级/清缓存/退出账号，未启动竞品视频。
- Nastart 详情标 688p H.264/AC3 5.1，Lenna 详情标 720p SDR；标注差异尚不能证明不同文件，也不能推定同片源/同路径/同轨道。账号端点、文件身份、实际直放/转码、缓存条件与共同屏幕计时尚未核对，无有效性能配对、无排名。

## 收尾与下一步

两轮 Nastart 视频均已退出；已回无变量正常包启动台。Lenna 无视频请求，未改变系统网络/路由/VPN。App 源码无本轮改动，只有 WDA 脚本与交接新增变化；iPad/iPhone 18 无本轮安装或回归结论。全部 PX/UX 未验收项继续按唯一总账保留。

1. 现场核对服务/设备及最新包后，优先恢复 Instruments 设备枚举，补启动台、海报首页/电影网格等逐滑实际位移与完整帧时间；失败继续保存，不能替换为 WDA 手势成功判 PASS。
2. 对齐 Lenna 的服务器/文件/播放模式、轨道及屏幕计时，先 S01 单路小样本，再按矩阵至少 5 组交替配对；Debug 与 App Store 优化级别差异仍须说明。
3. 本轮热续播的初始缓冲及 1 帧丢帧需在重复基线中观察，再补设备文件入口/冷续播及代表片长播；不能由一次短测直接改播放参数。

原始日志、UI 树、截图、设备偏好尝试、安装回执、崩溃报告只留 `/tmp/nastart-20261001-resume2/`（目录权限 700）与此前私有目录，不上传。当前 WDA 会话/PID/端口均仅是收尾现场，下轮重新确认。
