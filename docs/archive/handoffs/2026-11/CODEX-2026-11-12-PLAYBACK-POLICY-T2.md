# 2026-11-12 T2 iPhone 13 蜂窝窗口与 Jellyfin 登录阻塞

Codex 执行，时间为北京时间。用户在 [T2 预检](CODEX-2026-11-12-PLAYBACK-POLICY-T2-PREFLIGHT.md) 后明确授权 Codex 用 WDA 切到蜂窝并恢复原 Wi-Fi，两次动作均无需用户操作。

## 设备、安装身份与网络

- iPhone 13，iPhone14,5 / iOS 16.3.1 / USB。fresh 核名称、系统、完整 UDID、USB 配对和 Nastart 实际安装路径。签名 Debug 对应 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)，dylib `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。现有有效 Runner 复用，未再部署。
- 首窗前设置为原 Wi-Fi，原生已连接行勾选和状态栏 Wi-Fi 图标双核。三个实际切网短窗均原生显示 Wi-Fi 关闭和 4G，属于用户报告弱蜂窝条件。状态栏可见信号只作定性现场记录；RSRP/RSRQ/SINR 未测。因未发出播放，媒体吞吐、首字节和卡顿均无样本。
- 现场私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `phone/t2-cellular/`、`phone/t2-cellular-run2/`、`phone/t2-cellular-run3/`、`phone/t2-cellular-run4/`。保存原始截图、已脱敏诊断、各次状态和失败日志。原 Wi-Fi 标识仅在私有证据中保留。

## 经过与判定

| 时段 | 现象 | 收尾 |
| --- | --- | --- |
| 04:10:45 起 | Wi-Fi 关闭、4G 实图。私有工具 `queue.py` 与 Python 标准库同名，导航取证导入失败。没有启动播放。 | 最外层清理先终止本轮采集，恢复 Wi-Fi 后，AX 在状态过渡时断言失败。更正文件名，原生核本轮 App 停止，04:11 原生图补核原 Wi-Fi 行勾选与状态栏图标。04:12:05 App/Runner/8161 均已释放。 |
| 04:12:28–04:13:11 | 4G 正常，导航尝试未找到 Jellyfin 的“媒体资源库”控件。无播放。 | 04:12:57 App 已停，04:13:10 原 Wi-Fi 及图标通过清理脚本复核，随后确认进程和转发归零。 |
| 04:14:58–04:15:48 | 4G 正常。启动台卡片的 W3C 触摸实际弹出“从启动页隐藏”菜单，保留实图；未选择菜单项，也未进入资源库。 | 清理先停采集，DVT 握手断开，最终原生进程检查为零。04:15:45 原 Wi-Fi 行勾选和状态栏图标双核。 |
| 04:16:11–04:17:35，原 Wi-Fi | 通过 XCTest 原生元素点击，实图进入 Jellyfin 服务页并打开媒体资源库。App 显示“登录已失效，请重新输入密码”。诊断 `library_failed httpStatus=401`、`session_rejected stage=library`、`storedLibraryRecovery result=httpRejected httpStatus=401`；资源库先使用 `publicDomain`，同时取得 `verifiedSameServerLAN/privateIP` 播放端点核对。此次 401 的实测网络为 Wi-Fi。 | App 保留在登录页供用户手动输入，自有 WDA 会话、Runner、转发与采集已结束。Wi-Fi 未改。 |

V3–V8、V10 均无实际起播。每次导航失败留存设备诊断与工具记录；路线脚本没有本轮 `routeCapacityEvidence` 可复算，零记录不算通过。T4 无试探样本，不调参。产品代码和参数未改；T5 未接线，T6 未做。

## 接续

- 用户随后明确授权，尝试使用其历史聊天中曾为 iPhone 13 Jellyfin 提供的同一组登录信息。04:20 本机按用户消息来源定位到唯一匹配项，仅保留私有来源指针。登录输入限制为当前账号相符时在 App 的安全输入框提交一次。
- 04:20:39 已保存诊断并精确结束先前自有 Nastart。复用现装 Runner 的两次启动均遇开发服务连接断开；一次在 XCTest 进程控制通道，另一次在 USB DVT 进程预检。既有配对有效，Developer Mode 已启用，开发镜像已挂载，旧截图服务实见设备未锁和 Wi-Fi 图标。现有配对 Wi-Fi 的 DVT 同样断开；旧 USB 服务名不提供服务。只读复制的 DTServiceHub 报告仅有 11-08 历史文件，未发现本窗新报告。自有转发和采集已结束。未输入或提交登录信息，未修改系统或重装 Runner。
- 续接先恢复 WDA 开发通道，在当前 Wi-Fi 下用已授权信息单次登录并核资源库。随后由 Codex 负责 WDA 切网和最终恢复；蜂窝端登录可用性仍须实证。
- T3 的 SMB 读取与 HTTP 同窗取数待做。源码核对显示已保存 SMB 媒体库仍从 `network.library.source` 打开，iPad 该行需实际手动进入；保留本批对合成点击的限制。

## 重启后的 5G 复核

- 04:43:14 在原 Wi-Fi 经恢复的 WDA 提交一次用户授权的登录，`login_succeeded`，内网地址 `serverIDRecorded httpStatus=200`，资源库加载完成，3 库。该登录成功归属内网端点。设备和 App 签名仍为本窗 T0 身份。详见 [WDA 恢复](CODEX-2026-11-12-IPHONE13-WDA-RECOVERY.md)。
- 04:44:43–04:45:31，WDA 复核原 Wi-Fi 勾选后切网。实图 Wi-Fi 关闭、状态栏 5G，仍属用户报告弱蜂窝所在位置。无线定量指标未测。空参数、空环境冷启动后通过原生元素点击进入 Jellyfin 资源库。
- 04:45:07 App 记录 `network=cellular`、`expensive=true`、`selectedAddressKind=publicDomain`。公网候选 `hasStoredSession=true`、`sameSelectedUser=yes`；资源库 `library_failed httpStatus=401`、`session_rejected stage=library`，并见登录失效页。内网新登录与公网旧会话为两个端点；未确认公网服务为何拒绝该会话。
- V3 被公网资源库鉴权挡在播放前。V4–V8、V10 未发起，本窗无路线判定、媒体吞吐或首帧。复算报告本窗无路线记录。T4 无样本，不调参。无新产品代码与测试修改。
- 04:45:16 已核 App 停止，收尾停止采集，04:45:31 原 Wi-Fi 勾选和状态栏图标核对通过。最终 App/Runner/8161 均结束。已请用户决定是否授权在公网登录页单次提交刚在 Wi-Fi 验证的登录信息，同时请用户手动进入 iPad 现有 SMB 库的目标详情，供独立 T3 窗口。证据在私有批次 `phone/wda-post-restart/`。

## 06:23 公网登录与首次 V3 派发

- iPhone 13 fresh USB、App T0 安装回执和现装 Runner 核对。原 Wi-Fi 勾选和状态栏图标确认后经 WDA 切至 5G。公网旧会话仍 401，在用户要求继续后单次在 App 登录，06:25:13 成功，资源库实际加载。06:25:15 探测 `networkBody`、1,048,576 字节、211 ms、39,652,695 bps。
- S19 详情当时没有续播点，本次为从 0 冷起播。当前 trace `A97C0182`，`sourceBitrate=75218094`、`capacitySource=preplayProbe`、`capacityBoundsBothSides=false`、`probeAgeSeconds=61`、`renditionLowerBound=none`、`restoredSamples=0`。`originalVerdict=lowerBoundTooFar`，`originalRangeSkipped reason=lowerBoundFarBelowSource`，`renditionCeiling=12000000`，实际协商 `serverNegotiatedHLS maxBitrate=12000000`，与复算式一致。
- 私有自动化把诊断环里 11-10 的旧 trace `B6C3FA9E` 也交给新脚本，旧格式缺 `originalVerdict`，造成自动停窗。保留原始回执，当前 trace 的实时输出在决策时是 1 条、0 不符，随后实时日志确认 12 Mbps，未到首帧。无产品代码或常数修改。下一窗私有复算输入按实际起点过滤，保留完整原始导出。
- 06:26:20 App 已停，06:26:32 原 Wi-Fi 勾选和状态栏图标双核，06:26:33 App、Runner、转发和采集结束。私有证据在 `phone/t2-public/`。

## 06:27 复测与 NAS 暂停

- 同包空环境冷启动，5G 上公网已登录的会话直接加载资源库。V3 从 0 起播 `AFC24ACF`，`preplayProbe=8316553`、`capacityBoundsBothSides=false`、`restoredSamples=0`，`lowerBoundTooFar`，HLS 4 Mbps，内部首帧字段 4,825 ms。后续有电影画面及字幕实图；本窗开头没有已有断点，V3 的冷续播口径留待。
- 同进程 V4 续播 `F4DF3ADE`，`probeAgeSeconds=142`、`renditionLowerBound=21359325`、`lowerBoundTooFar`，HLS 10 Mbps，从 668.503 秒续播，内部首帧字段 9,838 ms，可见缓冲。随后从头 `4D676234`，`probeAgeSeconds=201`、`renditionLowerBound=20969036`、`lowerBoundTooFar`，HLS 10 Mbps，约 30 秒实图仍为 00:00 缓冲，未取得首帧。V4 选路规则通过，体验失败。实时复算共 3 条、0 不符。V5 仅覆盖低于阈值，V6 未触发。
- 从头的 30 秒即时偏好读到不完整 plist，保留原图、实时诊断和异常，随后原生止 App 与采集。自动 Wi-Fi 核验超时，06:32:16 另用原生图确认原网络勾选与状态栏 Wi-Fi 图标，06:32:31 App、Runner、转发归零。私有证据在 `phone/t2-route/`。
- 06:33 用户报告 NAS 疑似异常关机重启并要求暂停，停止全部 NAS 和播放访问。30 秒超时的服务端原因未证。V7、V8、V10、HLS 音轨/±15 s 及 T3–T6 待恢复后安排。本轮无试探系数样本，未调参。用户另授权 iPhone 18 最新包保留数据覆盖安装。
