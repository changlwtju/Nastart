# iPad WDA 经 tidevice 无法启动：26.6 开发者镜像缺失

2026-11-20 21:57，用户把 A16 iPad（00008120-000865400C920032，iPad15,7，iOS 26.6）连回 MacBook 后，尝试用现有脚本起 iPad WDA（端口 8169，与 iPhone 13 的 8168 错开）。

## 经过
- `scripts/start_wda_iphone.sh` 接受 DEVICE_UDID/LOCAL_PORT/DEVICE_PORT 环境变量，iPad 可直接复用；但它要求 Runner 与 xctestrun 在 WDA_ARTIFACT_ROOT 下。
- iPad-18 目录新建后缺 Runner：用软链指到 iPhone-16.3.1 的重签 Runner（11-19 续签，覆盖三台设备）解决；xctestrun 缺失用 XCTESTRUN 环境变量指到 iPhone 根目录的 `WebDriverAgentRunner_iphoneos26.5-arm64.xctestrun` 解决；DDI_ARCHIVE 同样指过去。
- 之后卡在 `tidevice developer` 挂载开发者镜像：`ServiceError: DeveloperImage not found`。tidevice 的 `_request_developer_image_dir` 只认两处：`/Applications/Xcode.app/.../DeviceSupport/<版本>/DeveloperDiskImage.dmg`（Xcode 27.2 已无此目录）与自带下载缓存（`~/.tidevice/device-support/` 只有 16.3），26.6 两处都没有，联网下载也未命中。
- Xcode 按需下载的 `~/Library/Developer/Xcode/iOS DeviceSupport/iPad15,7 26.6 (23G71)/` 只有 Info.plist 与 Symbols，没有 .dmg（iOS 17+ 不再用旧式 dmg 挂载）。

## 结论
- tidevice 路线起 iPad WDA 目前走不通，缺 26.6 开发者镜像是硬缺口，不是配置问题。
- iPad 已知的可行路线是 Xcode 原生 XCTest（11-19 安装与 11-20 16:58 实际触控验证都是这条路），下次需要驱动 iPad 界面时走 `xcodebuild test` 而不是 tidevice。
- iPhone 13 的 WDA（8168）不受影响，仍在服务；iPad 上 Nastart 0.1.0 已装，WDA Runner 也在，但未起服务。
- iPad 的 Jellyfin/DSM 登录状态尚未核实（无界面通道）；iPad 装的是 11-19 旧包，未含 Jellyfin DeviceId 修复，登录前不要用它做双机互踢验证。

## 解决（2026-11-20 22:06）：走 Xcode test-without-building
- tidevice 路线是死路：`get_developer_image_path` 对 17.x 直接报 "iOS 17.x is not supported yet"，26.x 也无对应 .dmg 可下载；iOS 17+ 已不用旧式 DeveloperDiskImage.dmg 挂载。
- 可行路线是 Xcode 原生 XCTest：用 iPad-18.3.1 根目录的 `WebDriverAgentRunner.xctestrun`（`__TESTROOT__` 相对路径）跑 `xcodebuild test-without-building -destination 'platform=iOS,id=00008120-000865400C920032'`。
- 坑：iPad-18.3.1/Debug-iphoneos 里的 Runner 是旧版，描述文件 2026-10-03 已过期；已备份为 `.expired-20261003`，换上 iPhone 根目录 11-19 重签的 Runner（描述文件到 2026-11-26，覆盖三台设备，含 iPad UDID）。
- 验证：Runner 在 iPad 上跑起（ServerURL http://192.168.1.26:8100），iproxy 8169→8100 转发后 /status 正常（WDA 16.1.5）。iPad 截图确认 Nastart 首页：Jellyfin 已连接、媒体库可见（电视剧 8、电影 36、继续观看两部）。
- 结论：iPad 远程调试走 Xcode 路线（xctestrun + iproxy 8169），不要再走 tidevice；iPad WDA 服务需保持 xcodebuild 进程在前台，重启 Mac 后要重起。脚本：/tmp/start_wda_ipad_xcode.sh，日志 /tmp/wda-ipad-xcode-20261120.log。
