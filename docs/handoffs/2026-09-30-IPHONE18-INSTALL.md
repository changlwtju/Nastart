# 2026-09-30 iPhone 18 最新包安装

- 17:58（北京时间）现场确认 USB 设备 `00008160-001468D401A0000A` 为 iPhone 18 Pro Max，CoreDevice 状态 `connected`。安装前设备已有 Nastart 0.1.0(1)，未见运行中的 Nastart 进程。
- 最新应用源码均不晚于本次签名产物；安装包为本机 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-iphone13-stall/Nastart-lan-probe-policy.app`，`Nastart.debug.dylib` SHA-256 `cbfff361a80cc472afe19ec20c37843fdecfdd195c7dbfc3c95970827fc44ef8`。`codesign --verify --deep --strict` 通过，描述文件包含该 iPhone 18 UDID。之后只有测试与文档改动，没有应用源码变更。
- 通过 CoreDevice 保留数据覆盖安装，返回 `App installed`、Bundle ID `com.changliwen.nastart`，设备路径含 `Nastart-lan-probe-policy.app`。无 `DEVICECTL_CHILD_*` 注入正常启动，PID 2178；约 8 秒后进程仍在，设备仍显示 Nastart 0.1.0(1)。这完成安装与启动检查，不代表 iPhone 18 播放、NAS 登录或 UI 功能回归。
- 安装与启动日志仅存本机私有目录 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-iphone18-install/`。该 Debug 包的开发描述文件到期时间为 2026-10-03 16:26 UTC；之后若需继续安装或启动真机 Debug 包，应先更新签名。
