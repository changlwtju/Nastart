# 2026-11-12 播放策略真机接手 T0

依据 [设计到真机总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md)。Codex 执行，时间为北京时间。

## 源码与安装包

- 开工 HEAD `8db1cc6491c6e8bce2bc8b41f57e6112142132ba`，`git status --short` 122 个路径，与总交接一致。保留开工状态、已跟踪差异和索引差异。499 个仓库内 iOS 输入（含未提交和未跟踪文件）的清单 SHA-256 为 `d08775b76e66360d1b7398a4bb0bfaa8a3ea964fd6234a2a8da3978642b94b36`，构建后逐项复核一致。
- 03:28:30–03:29:39，Xcode 27.2（27B52），`Nastart.xcworkspace` / `Nastart` / iOS 真机 Debug。使用独立 DerivedData 与锁定依赖的私有 SourcePackages 副本，按此前设备构建关闭 Swift 显式模块，使用本机既有签名。构建成功。
- 包为私有批次目录下 `DerivedData/Build/Products/Debug-iphoneos/Nastart.app`，bundle `com.changliwen.nastart`、arm64、0.1.0/1。主程序 SHA-256 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`，Debug dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`。
- `codesign --verify --deep --strict` 和 31 个嵌入 Mach-O 的逐个核签通过；签名与描述文件的 application-identifier、Debug entitlement 对齐，描述文件覆盖两台当前 USB UDID，有效至 11-15 08:30:17。私有证据入口为 `/tmp/nastart-codex-playback-device-20261112-current`，含包清单、源清单、构建日志及下述原始回执、偏好和前台图。

## 逐台结果

| 设备及窗口 | 覆盖安装 | 正常启动与收尾 |
| --- | --- | --- |
| iPhone 13，iPhone14,5 / iOS 16.3.1，USB，约 03:30–03:31:35 | 本轮核真实名称、UDID、配对及旧 bundle 路径；安装前保存偏好与内含的诊断。03:30:53 USB installation_proxy 返回完成，fresh lookup 验证 bundle；30 项偏好全部相等。 | 03:31:24 原生图实见 Nastart 启动台和 Wi-Fi 图标。空参数、空测试环境；PID 对应新安装路径。03:31:35 结束自有 App 并核无 App / Runner，启动后仅诊断偏好变化。 |
| A16 iPad，iPad15,7 / iPadOS 26.6，USB，约 03:32–03:32:40 | USB 与 CoreDevice wired/paired 双核名称、UDID 和系统。保存旧诊断和偏好后，对应路径和 PID 二次匹配，精确结束空闲旧进程，偏好复核一致。03:32:09 `devicectl device install app` 成功，fresh lookup 验证 bundle；21 项偏好全部相等。 | 03:32:26 原生图实见 Nastart 启动台和 Wi-Fi 图标，现场同时有 VPN 图标。空参数、空测试环境；PID 对应新安装路径。03:32:40 结束自有 App 并核无 App / Runner，启动后仅诊断偏好变化。 |

两台串行登记和执行，未启动 WDA 或转发，未切换网络。iPhone 18 与 Apple TV 未操作。

## 判定及续接

- T0 通过。依据是两台各自的安装完成回执、fresh 安装查询、偏好比对、正常首页实图和最终进程清单。
- T0 没有发出播放，路线复算和 Reader 报告不适用于此窗。未运行新的 App 单测，未改产品代码、参数、测试或签名配置。T1 的 V1/V2 仍须在内网实际播放并即时导出，T2–T6 无本窗结果。
- 同步当前包、安装状态、当前开发接手与窗口释放。需求总账与矩阵已核对，T0 无播放证据可登记。
