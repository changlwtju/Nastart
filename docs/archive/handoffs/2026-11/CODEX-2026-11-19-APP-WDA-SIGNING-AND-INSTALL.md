# 2026-11-19 Nastart 与 WDA 续签安装

用户要求更新 iPad、iPhone 13 和 iPhone 18 Pro Max 的 Nastart 和 WDA，18 走无线。HEAD `8db1cc64`，开工 162 个未提交路径。647 个冻结输入与 11-14 构建清单逐项一致，且当前无清单外新增的 iOS 或 Agent 工作区文件。源码及未提交改动原样保留。

## 安装结果

| 设备 | 连接与身份 | Nastart | WDA |
| --- | --- | --- | --- |
| iPad (A16) | USB，iPad15,7 / iPadOS 26.6，原生设备服务核对实时标识 | 07:35:49 保留数据覆盖安装完成，fresh lookup 核对新路径和签名，安装前后偏好逐值相等，非诊断项 22 个 | 07:35:53 保留覆盖兼容 Runner，核对新的安装路径和签名。XCTest 启动遇开发者信任拦截，未取得 ready |
| iPhone 13 | USB，iPhone14,5 / iOS 16.3.1，Developer Mode 已开启，原有兼容 DDI 挂载成功 | 当前 Xcode 27.2 找不到 iOS 16 设备作为签名目标。此机没有有效的新描述文件，未发安装 | 未发安装。原生核到既有 Runner，非本批启动，进程保留 |
| iPhone 18 Pro Max | 早窗以实时 Bonjour 和现有无线配对验证 iPhone19,7 / iOS 27.0，未连接 USB | Xcode 原生无线开发隧道 unavailable，签名目标不可用，无线容器预检超时。用户确认手机已带离家中，停止探测，未发安装 | 未取得覆盖此机的新描述文件，未发安装 |

iPad 本地 `codesign`、原有开发证书、App ID 和 entitlement 一致。系统原生启动返回 Security，后续截图实见「不受信任的开发者」。WDA 同样不能启动，无法代用户完成信任。需要在 iPad 系统设置完成开发者信任后分别复验正常首页和 WDA `ready`。自有 iPad 测试转发已退出，无 Nastart 或 Runner 验证进程残留。

## 包与签名

- Xcode 27.2，签名 iOS Debug，07:29:10–07:30:40。Nastart 主程序 SHA-256 `796f65ba541ad13edd4397e27438d0fe9c1a8f3a5313aa9fa5df0ffc8f95decc`，Debug dylib `e15ca935b8dc584eaeee1ce9b885a1029bb30af17a1de2000112aa8440ce3203`，IPA `cfc87ba8e474e92719f725c435290908d5a11138fd54f393c6a4ea96bb7ffefe`。已核 IPA CRC、应用及 30 个嵌入库签名。当前 App 描述文件仅覆盖 iPad，到北京时间 11-26 07:29:24。
- 用既有团队为 WDA 取得新描述文件，复制并重签 iPad 原兼容 Runner。独立核对 13 个签名对象和整体签名。Runner SHA-256 `3dcfcf9669a30c4ae38e459bc2d7d2fe62a2de711124c7dff4c64eb3bd3f2f7c`，描述文件仅覆盖 iPad，到北京时间 11-26 07:31:23。
- 当前 Mac 只定位到 Xcode 27.2，旧 26.6 路径已无安装。Apple 文档列出 27.2 真机支持 iOS 17 起，26.6 支持 iOS 15 起。iPhone 13 可续用当前产物并用该设备有效描述文件同团队重签，也可由兼容 Xcode 续签。18 回原局域网后重新核无线开发服务及描述文件，再走保留数据安装。 [Apple Xcode 支持范围](https://developer.apple.com/xcode/system-requirements/)

本批未改系统网络、家庭 Wi-Fi、NAS、Jellyfin 或任何手机 DSM 连接地址。只在 App 覆盖安装所需范围内保存私有偏好，不读取 Keychain。无新增播放、选路复算样本或单测。原始材料及包路径位于本机私有入口 `/tmp/nastart-codex-renew-all-20261119-current`。Apple TV 未操作。
