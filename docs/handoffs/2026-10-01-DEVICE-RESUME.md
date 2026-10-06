# 2026-10-01 下午双机接续：最新包与滚动证据门槛

执行时间：2026-10-01 14:48～14:59，Asia/Shanghai。已先读 PROGRESS、CURRENT-PLAYBACK-HANDOFF、播放 runbook 和竞品矩阵；不修改 PROGRESS.md，由 Bot 汇总。

## 项目与包身份

- 遍历项目目录并审阅当前修改、App 导航根、启动台布局、滚动脚本及交接：App 目录 79 个文件、scripts 33 个、docs 184 个；iOS 源码/配置（包含本地依赖）389 个。未覆盖阅读全部第三方实现，不宣称全项目代码审计。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`。既有 18 个 tracked 文件修改及所有 untracked 内容保留；初始状态与 diff 在本机私有证据目录。
- iOS 源码/配置树 SHA-256 `8e2a45bb173efc0a2c1bd81d129c2210649b6dbec18ed48068f2fa77333831be`（路径排序，依次拼接路径、NUL、文件内容 SHA-256）。最新源码修改为 `AppTabRootView.swift`，07:32:05；正常 Debug 产物 07:32:39 晚于源码。原构建日志确认 `BUILD SUCCEEDED`、`SWIFT_OPTIMIZATION_LEVEL=-Onone`，不是临时 `-O` 实验包。本轮仅改 Python 工具/交接，不改 App 源码，无需因此重建 App。
- 包：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`。
- `Nastart.debug.dylib` SHA-256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`；主 executable SHA-256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`。
- `codesign --verify --deep --strict`、播放器隔离 linkage 验证及项目 preflight 通过。安装用临时 IPA 仅封装原签名内容，未改签名或二进制。

## 逐台现场核对

### iPhone 13：已覆盖安装最新正常包，UI 回归未完成

- 设备名 `iPhone`，型号 `iPhone14,5` / iPhone 13，iOS 16.3.1，UDID `00008110-001E543122E0401E`。`ideviceinfo`、配对 validate 成功，tidevice 确认 conn_type=usb。
- 原安装二进制身份不能可靠确认：先保存原 App Preferences 诊断到本机私有目录，未输出凭据或媒体路径。随后保留数据覆盖安装上述验签包，没有卸载 App 或清登录数据。
- 14:52 安装服务返回 `InstallComplete (100%)` / `Complete`；14:53 显式无测试变量/无参数启动 PID 67246，后续设备进程列表确认 Nastart 存在。收尾停止本轮挂起的 WDA runner，再次无变量启动 Nastart PID 67290，14:58 设备进程列表确认存在；证据见 `iphone-final-launch.log` / `final-processes.json`。本轮 8102 USB 转发保持供接续使用，不等于 WDA ready。
- tidevice 默认 SSL 缓存目录超出当前写入范围：临时包装器将其缓存写至权限 0700 的 `/tmp/.../tidevice-cache`，未修改 HOME、系统配置或安装的 tidevice。
- WDA XCTest runner 启动 PID 67249、收到 runner ready/test plan 消息，但本机 8102 `/status` 持续 connection reset，**不能将 runner ready 当作 WDA HTTP ready**。本轮没有实际 UI/播放/滚动通过结果。
- 本机读取到已安装 Lenna 1.0.17、DS One 2.4.5、Jellyfin 1.7.0；未操作竞品账号、库配置或购买订阅，未做公平配对。

### iPad：当前连接不可见，安装身份未完成核对

- 现场 usbmux `idevice_id` 与 tidevice 枚举均仅一台 iPhone 13；`xctrace list devices` 返回 No devices available，CoreDevice 初始化超时。系统 USB profiler 空列表不能单独判离线，但交叉枚举仍未发现 iPad。
- 无法现场确认 iPad 名称/型号/系统/UDID/连接，历史 `iPad12,1 / 18.3.1 / 00008030-001168403C43C02E` 仅作接续参考，不冒充本轮事实。
- 未安装、未启动、未开始本轮基线；8103 无服务。已请用户检查数据线/信任连接并解锁两机，回复就绪后继续，不把未回复当作已处理。

## 滚动自动化优化与历史证据边界

- 找到此前未汇总的 `07:34:41` iPad 启动台原始记录：`a79ae773-Debug-Onone`，12 次请求、26.975 秒，合并 hitch 49.986 ms / 1.853 ms/s，最长 33.32 ms，16 项文本发生首次位移，原工具判 PASS。
- **这是历史记录，不是本轮真机测试。** 原脚本只验证第一滑位移，缺少后续逐滑有效性；不能按本轮加强后的规则认定 12 次都有效。没有海报页/电影网格/详情/设备文件页或全页面通过结论，也没有竞品排名。
- 修正 `ui_scroll_probe.py` 原 `>=10` 请求门槛为 `>=12` 实际位移检查：每滑保存 XML、至少两个唯一文本位移 ≥40pt、操作前核对前台；动作起止须正序、无重叠、完整位于 ≥10 秒运动窗口和 trace 范围。缺位移/越界/缺动作/切换 App 返回 INSUFFICIENT。
- 未完成 motion 的 manifest 可直接输出 INSUFFICIENT，避免先导出不存在的 trace。新增不足 12 次、缺失/反向/重叠/越界动作、边界无位移、前台切换反例；工具测试实际 9 项通过。
- 新工具尚未真机执行；完整帧时间数据有效性仍须配合 Instruments 实际导出验证，不把 XML schema 存在当作帧采样完整。当前尝试导出历史 vsync 表返回 `Missing features / Unexpected internal error`，属于工具失效，不能推断无卡顿。

## 下一批

1. 用户确认 iPad 接入/信任且两机解锁后重新现场枚举。iPad 先保存诊断、保留数据安装验签正常包并记录启动，再开始基线。
2. 恢复 WDA HTTP ready 与 Instruments 可记录/导出后，以新版工具先完成 Nastart iPad 海报页、电影网格、详情、启动台及设备文件页；每页 ≥12 次有效位移，完整帧采样。短页/边界回弹不得算通过。
3. 只有有效证据再次复现 App 瓶颈才继续改 App 源码；改后构建验签并逐台更新，避免叠加未经验证的布局猜测。
4. 按竞品矩阵补 Lenna 同机滚动及 iPhone S01 同路首帧/热续播配对；缺端点/缓存/帧证据记 BLOCKED/INSUFFICIENT，不给排名。

私有原始证据：`/tmp/nastart-20261001-resume/`（安装/启动、原 Preferences、状态、工具日志），USB 枚举 `/tmp/nastart-20261001-resume-usb.json`。不上传这些文件。历史原始记录 `/tmp/nastart-oct01-final-launchpad/` 保持不变。
