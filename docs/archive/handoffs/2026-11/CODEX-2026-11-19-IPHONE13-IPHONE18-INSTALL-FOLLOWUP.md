# 2026-11-19 两台 iPhone 更新接续

接续 [三机续签安装](CODEX-2026-11-19-APP-WDA-SIGNING-AND-INSTALL.md)。用户已带 iPhone 18 Pro Max 回家并指定无线更新。用户在用 iPad，本轮只沿用其上午 Nastart 和 WDA 的覆盖安装回执。iPad 的 App 正常打开与 WDA 启动仍待用户使用窗口结束后核对。

22:24 开工。HEAD `8db1cc64`，163 个未提交路径。上午 Xcode 27.2 签名 Debug `e15ca935b8dc584eaeee1ce9b885a1029bb30af17a1de2000112aa8440ce3203` 的 647 个源码输入逐项一致。主程序 `796f65ba541ad13edd4397e27438d0fe9c1a8f3a5313aa9fa5df0ffc8f95decc`，IPA `cfc87ba8e474e92719f725c435290908d5a11138fd54f393c6a4ea96bb7ffefe`。上午生成的 Nastart 和 WDA 描述文件仍只覆盖 iPad，两台 iPhone 均未发送 Install。

- **iPhone 13**。fresh 核对现有 USB 身份、完整 UDID、iPhone14,5 / iOS 16.3.1。手机端已安装的 provisioning profile 列表未返回项目的 App 或 Runner 条目。Mac 仅定位到 Xcode 27.2，Apple 的旧版下载入口需要先登录。需取得同团队覆盖该手机的两个有效描述文件，或使用支持 iOS 16 真机的 Xcode 26.6 续签。 [Apple 真机支持范围](https://developer.apple.com/xcode/system-requirements/)
- **iPhone 18 Pro Max**。当窗 Bonjour 发现经实时配对认证，确认 iPhone19,7 / iOS 27.0，无 USB。无线 lockdown 与原生无线隧道均能查到现装 Nastart、WDA 并读出 Nastart 偏好，安装前数据备份可走无线。手机 profile 列表未返回项目条目。Xcode 自己的无线开发目标仍 unavailable，按完整标识发起针对本设备的 WDA 描述文件请求停在「找不到目标」。Device Hub 的附近配对页等待确认，需用户在手机开发者模式页面配合。 [Apple Device Hub 文档](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)

私有证据仍保存在 `/tmp/nastart-codex-renew-all-20261119-current` 指向目录，含本轮无线 App 备份验证、收据、两机签名检查。未修改源码、网络、DSM 地址或服务器配置。无播放样本、路线复算或单测。

22:38 后接续。fresh 核本机仅有 Xcode 27.2，iPhone 13 USB 仍可见，Xcode 设备列表无此机。iPhone 18 Pro Max 仍不在 USB，Xcode 仍显示在局域网搜索。两项项目描述文件均只覆盖 iPad。将 Device Hub 的附近设备发现切回 iPhone，仍显示等待配对。Safari 单独打开 Xcode 26.6 官方下载入口，实际停在 Apple Developer 登录页。两台手机仍无安装下发，iPad 继续交由用户使用。

23:21 后接续。Safari 的 Apple 登录页一度显示服务器中断。重新从 Xcode 26.6 官方下载入口进入，已到 Apple Developer Agreement，页面显示 Agree，等待用户本人审阅和处理。此次没有下载或安装 Xcode。Device Hub 仍在 iPhone 附近配对等待页，短时 Bonjour 观察未发现可配对广播，已有配对的其他服务记录仍可见。尚无两台目标手机的有效描述文件。私有安装脚本已对齐经过验证的无线备份通道，待获得同团队有效描述文件后再逐台核签和安装。

23:46 后用户确认 iPhone 18 Pro Max 已解锁、打开开发者模式页面。重新完成 Bonjour 身份验证并通过现有无线配对取得系统截图，实见开发者模式已开启、已有配对 Mac，以及下方可选同一 Mac 的蓝色 Pair with 项。Mac 的 Device Hub 重开 iPhone 附近配对后，仍显示等待手机发起。已告知用户精确入口，配对待确认。设备签名请求已准备，当前新包未发送。
