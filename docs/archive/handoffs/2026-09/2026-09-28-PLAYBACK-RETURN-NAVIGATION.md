# 设备文件播放退出导航（2026-09-28）

用户报告 iPhone 18 Pro Max 从设备文件详情进入视频，退出后回到启动台，预期应保留文件详情。

## 原因与修复

`AppTabRootView` 原来用 `horizontalSizeClass` 选择 `TabView` 或 `NavigationSplitView`。大屏 iPhone 横屏播放会出现 regular 宽度，替换根导航层级；恢复 compact 时新建标签栏，默认选中启动台，设备文件导航随之丢失。

现按设备类型保持根层级稳定：iPhone 始终使用标签栏，iPad 使用能自行适配窄窗口的 `NavigationSplitView`。播放器关闭逻辑和媒体库路由保持原样。

## 本轮验证

- 用实际 `AppTabRootView.swift` 加轻量页面替身，在 iPhone 18 Pro / iOS 27 模拟器运行独立导航回归。先选设备标签并建立 folder → video-detail 路径，再注入 compact → regular → compact 环境变化。旧代码返回标签索引 0，标签栏身份丢失；新代码保留标签索引 1、标签栏身份、文件导航对象及原路径。此测试验证导航生命周期，不代表完整播放器真机验收。
- 回归夹具及前后 JSON 结果：`/tmp/nastart-navigation-regression/`。
- generic iOS Debug 构建、`bash scripts/preflight.sh`、播放库链接检查、深度签名验证均通过。
- 修复包已通过 USB 覆盖安装 iPhone 13，保留 App 数据。WDA 确认正常显示启动台；本轮未完成真机视频播放退出回归。
- iPhone 18 不在当前可连接设备中，尚未安装本次修复，也未完成其真机验收。接入后复测设备文件详情 → 播放 → 横屏 → 退出，确认仍在原详情页，并检查再次播放和返回原目录。

构建产物：`/tmp/nastart-iphone18-adaptive-derived/Build/Products/Debug-iphoneos/Nastart.app`；构建日志：`/tmp/nastart-navigation-return-build.log`；安装日志：`/tmp/nastart-navigation-return-iphone13-install.log`。
