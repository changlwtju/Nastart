# 2026-10-01 17:06 采样环境接续核查

本轮读取 PROGRESS、当前交接、runbook、竞品矩阵及根 AGENTS；按协作约定不修改 PROGRESS.md。保留所有既有修改。继续 iPhone 13，iPad 暂缓。

## 本轮现场证据

- usbmux 仅枚举 iPhone 13：名称 `iPhone`，型号 `iPhone14,5`，系统 `16.3.1`，UDID `REDACTED-DEVICE-01`；现场配对 validate 成功。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，App 已跟踪差异 SHA-256 `e37971081d969e8001a0711fb3e5a2b53f5fdfb9b5c38c747a2561c0cafb6b1d`，与上轮相同。未修改 App 源码。
- 正常 Debug 包仍为 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`。现场 deep/strict 验签成功；主 executable SHA-256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`，dylib `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。构建产物时间 07:32:39，最新扫描到的 App 源码/配置时间 07:32:05。
- **上述仅重新核对本机包。设备安装完成回执属于 16:56～16:57 的上一轮，本轮未重新核对设备安装身份、覆盖安装或启动 App。** 本轮没有进入真机基线或回归；采样可用后仍须完成当轮安装门槛。
- `python3 scripts/ui_scroll_probe.py --preflight-only --device REDACTED-DEVICE-01 --output /tmp/nastart-sampler-resume-20261001` 返回退出码 1、`INSUFFICIENT`、0 手势。三项 xctrace 枚举均退出 0，但实际分别为无录制设备、无 instruments、缺 Animation Hitches。原始日志和 JSON 在该本机目录。
- 当前选择 `/Applications/Xcode.app/Contents/Developer`，实际 xctrace 为其中 `usr/bin/xctrace`。没有修改全局 Xcode 选择。

## 尚未完成的环境对照

上一轮原始日志仍可读取：`xctrace-system.log` 明确为 `Cannot run while sandboxed`，`host-record.log` 有 `Failed to query kext info (MAC policy error 0x1)`，`historical-export.log` 为 `Missing features`。这些说明当前执行环境存在访问限制，但**不能单凭这些证明 Instruments 三项枚举异常均由沙箱造成**。

本会话不允许提权，未尝试绕过限制或通过其他进程间接执行。已请求用户在同一 Mac 的普通 Terminal 运行只读命令 `xcrun xctrace list instruments` 并提供输出；尚待回复。

- 若普通 Terminal 列出 instruments，下一步在正常授权的执行环境完成同一预检（devices/instruments/templates），再做真实录制及 schema 导出；列出 instruments 本身不等于恢复采样。
- 若普通 Terminal 同样为空，继续定位宿主 Xcode/Instruments 初始化问题，不重装 WDA、不修改播放器参数。
- 采样恢复后，先核对当轮设备安装身份，再完成各页至少 12 次实际位移、完整显示采样的滚动回归；Lenna 同条件配对及 5 组样本仍未完成。现有正常 Debug 不能直接与 App Store 包给出公平速度排名。

本轮未操作 WDA/UI/Lenna、未启动视频、未修改设备及网络配置，无新增滚动/播放 PASS 或竞品排名。
