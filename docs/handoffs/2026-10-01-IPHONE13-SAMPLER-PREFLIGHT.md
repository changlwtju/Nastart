# 2026-10-01 iPhone 13 安装回执恢复与采样预检

执行时间：16:45～17:02，Asia/Shanghai。先读 PROGRESS、当前交接、播放 runbook、竞品矩阵和 AGENTS。继续 iPhone 13；iPad 暂缓。按协作约定未写 PROGRESS.md，保留既有未提交修改。

## 本轮安装门槛已完成

- 开始与安装后 usbmux 均只见 `00008110-001E543122E0401E`；名称 iPhone，型号 iPhone14,5，系统 16.3.1，配对 validate 成功。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，App 源码/配置最新时间 07:32:05，正常 Debug 二进制 07:32:39；本轮只改采样脚本，没有新增 App 源码。既有 App 差异 SHA-256 `e37971081d969e8001a0711fb3e5a2b53f5fdfb9b5c38c747a2561c0cafb6b1d`，差异与状态快照仅留私有目录。
- 包：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`。deep/strict 验签通过；主 executable SHA-256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`，dylib SHA-256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`，IPA 两文件一致。
- tidevice 的 IPA 上传已完成，但等待 installation_proxy 首条回执；faulthandler 留有接收栈。原生 libimobiledevice 接口分别取得 `MissingPackagePath`、`Coordinator already exists` 和普通 IPA 来源不允许免费开发 profile 的 `ApplicationVerificationFailed`。这些是各次尝试的原始结果，不能笼统归为 USB/WDA/播放器故障。
- 成功方式：AFC 上传已验签的完整 `.app`（100 文件），回读设备暂存目录的两个二进制计算 SHA-256，逐一与本机包相同；libimobiledevice `instproxy_install` 使用 `PackageType=Developer` 安装该目录。16:56～16:57 完整回执为 `InstallComplete (100%)`、`Complete`、`FINAL complete=1 request_rc=0`，命令退出 0。未卸载或清除数据，历史私有诊断保留。
- 成功脚本/回执在私有目录：`upload-developer.py`、`install-native.c`、`install-native`、`upload-developer.log`、`install-developer.log`。原生回调以返回 plist 的 `Error` 字段判断失败；中间进度不能作为完成回执。安装失败的早期辅助程序也保留以解释证据，后续复用以最终源码及成功日志为准。
- 无变量 tidevice 启动 PID 68138，真实启动台截图确认 DSM/Jellyfin 在线。其后收尾明确无变量重启并建立 WDA 普通会话，PID 68158；真实启动台和 `ps --all --json` 交叉核对。正常冷启动早期有“未连接”状态，不能当作持续 NAS 离线结论。
- **进程检查需用 `ps --all --json`**：本轮默认 `ps --json` 因 `isApplication` 过滤未列出 Nastart，而 `--all` 可见 PID 68158。不能只据默认列表缺项判定进程退出。下载报告未见下午新增 Nastart 崩溃（最新仍 07:34:20）。

## WDA 与 Instruments 分开处理

- 固定 WDA 未重装，恢复命令：`TIDEVICE_BIN=/tmp/nastart-20261001-wda-resume/tidevice WDA_RUNTIME_DIR=/tmp/nastart-20261001-next/wda scripts/start_wda_iphone.sh`。Runner PID 68043；8102→8100 ready=true，固定 host 身份正确，session/source/screenshot 可用。收尾保留服务，下一轮现场重验。
- 当前 xctrace 同时报告：无设备、无 instruments、缺 Animation Hitches 模板。模板文件实际存在，Devices 插件可以 dlopen，故不能仅凭列表把问题归为手机未连接或 Xcode 文件缺失。
- 使用显式模板在 Mac 本机录制也触发内部断言及内核查询 MAC policy 错误；显式加载 Hitches package 抛出目标 URL 为 nil 的异常；历史 trace 导出报 `Missing features`。本执行环境还明确禁止 `log show`（Cannot run while sandboxed）。这些证据表明当前宿主采样链路不可用；尚未证明全部异常的共同根因，也未取得正常帧时间导出。
- 没有升级/重启系统、改变全局 Xcode、系统网络、VPN 或 NAS；没有启动视频或 Lenna。本轮没有滚动 PASS、播放新回归或竞品排名。

## 采样工具更新与验证

`scripts/ui_scroll_probe.py` 增加 `--preflight-only`，在修改 WDA 设置和界面动作前枚举 devices/instruments/templates，保存原始输出和 `sampler-preflight.json`。即使命令退出 0，缺目标设备、空 instruments、缺模板也停止；超时保留已取得输出。提前保存 run.json，故 UI/采样准备失败仍保留设备、页面、构建和 0 动作信息。

13 项工具测试通过，新增覆盖“退出 0 但无采样能力”和枚举超时证据保留。现场独立预检保存 `INSUFFICIENT`，0 次手势，无 App 性能结论。`git diff --check` 通过。

下一轮先运行：

```sh
python3 scripts/ui_scroll_probe.py --preflight-only \
  --device 00008110-001E543122E0401E --output /tmp/nastart-sampler-next-check
```

先恢复宿主 Instruments 的 instruments/模板/设备枚举及真实 schema 导出，再完成各页至少 12 次有效滑动。若本机常规 Terminal 能枚举而当前执行环境不能，按宿主执行权限问题继续处理；本轮未完成这一环境对照。不要继续盲目重装 WDA，也不要用默认 ps 的过滤结果推断崩溃。采样恢复后对齐 Lenna 文件、路径、轨道、缓存与共同计时，补至少 5 组配对。

原始截图、安装日志、完整设备信息、崩溃报告和诊断仅留权限 700 的 `/tmp/nastart-20261001-next/`，不上传；未写 PROGRESS.md。
