# 2026-11-20 iPhone 13 App 更新接续

用户确认 iPhone 18 Pro Max 安装包已成功更新，本轮优先 iPhone 13 的 Nastart。前批见 [18 无线安装和 WDA](CODEX-2026-11-20-IPHONE18-WIRELESS-APP-WDA-INSTALL.md)。本轮未接触 iPhone 18 Pro Max 或 iPad。

- 05:47 开始，HEAD `8db1cc64`，165 个未提交路径。11-19 07:30:40 的 Xcode 27.2 Debug 冻结输入 647 项、HEAD 和 iOS diff 均一致。原包主程序 `796f65ba541ad13edd4397e27438d0fe9c1a8f3a5313aa9fa5df0ffc8f95decc`，Debug dylib `e15ca935b8dc584eaeee1ce9b885a1029bb30af17a1de2000112aa8440ce3203`。当前构建源码可复用，待手机签名后重新计算正式下发包哈希。
- iPhone 13 经现有 USB 配对核实完整 UDID、iPhone14,5 / iOS 16.3.1，旧 Nastart 和 Runner 均可查询。手机签名列表零条项目匹配；Mac 两个同团队项目描述文件均不覆盖 iPhone 13。Xcode 27.2 活动设备列表无此目标。本机未找到 Xcode 26.6 应用或下载归档，也无 Time Machine 快照或备份目标。
- Apple 旧版下载前一窗仍停在账户协议。此次 Safari 检测到用户正在使用，已交用户自行打开官方下载入口、审阅页面需要的账户协议。已准备按 App 描述文件单独打包的私有脚本，续签和覆盖可分别验收，不依赖 Runner 更新。 [Apple 官方下载入口](https://developer.apple.com/download/all/?q=Xcode%2026.6)

本轮为只读预检，零安装下发。设备无占用，未作播放回归或源文件改动。USB 预检与签名检查证据在 `/tmp/nastart-codex-renew-all-20261119-current` 指向目录内。
