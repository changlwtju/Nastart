# Apple TV（客厅）— Mac 开发连接恢复链路

> 2026-11-20 晚实测验证通过的完整链路。目标：下次电视再出现"配对成功但不可用"时，按此文档从上到下恢复，不用重新排查。
> 另见：[Apple TV 开发与真机安装准备](../development/APPLE-TV-PREPARATION.md)（历史记录）、[当前播放交接](./CURRENT-PLAYBACK-HANDOFF.md)。

## 当前已验证状态（2026-11-20 21:06）

- 电视：AppleTV14,1「客厅」，tvOS **27.2**（24K122），IP **192.168.1.66**，与 Mac 同网段同子网。
- 稳定硬件 UDID：**`00008110-000235903E99801E`** —— devicectl 直连用这个。注意：每次在 Device Hub 里删记录重配，配对流程会生成一个新的**临时 UDID**（当晚依次出现过 A2E842C7…、C9BD116C…、1044A2D8…、E1F7E21B…），那个不用记，变了也正常。
- devicectl 状态：`Appletv 00008110-000235903E99801E available (paired) AppleTV14,1`。
- 已装应用：Nastart `com.changliwen.nastart.tv` **0.1.0 (1)**（2026-11-20 21:06 新构建覆盖安装，进程 PID 349 已启动验证）。
- tvOS 描述文件：`tvOS Team Provisioning Profile: com.changliwen.nastart.tv`，**2026-11-27 12:58:54 过期**。免费团队描述文件约 7 天一期，到期后重建即自动续（见"构建"一节）。iOS 描述文件同期到 2026-11-26/27，两边到期时间接近，续签时一起处理。

## 症状与定性

- 典型症状：Device Hub 里能发现电视、输验证码、配对流程日志显示 `Pairing attempt completed with error nil`（成功），但设备条目仍显示 **Currently Unavailable / Disconnected**；`xcrun devicectl list devices` 里根本没有电视。
- 定性：**配对/认证本身成功，失败在配对后的开发隧道连接**。这是已知的 Mac 侧 CoreDevice 故障（tvOS 26.6 同样中招，不是 tvOS 27.2 特有 bug），不要往"电视系统版本"方向排查。
- 地面真值以 `xcrun devicectl list devices` 为准，不要只看 Device Hub 界面。mDNS 扫描（`_apple-mobdev2._tcp`）可能完全看不到电视——Device Hub 的 beaconing 发现是另一条路径，mDNS 没有不代表电视不在。

## 恢复阶梯（按顺序，一次只改一个变量）

1. **确认电视本身活着**：`ping 192.168.1.66` 应零丢包；电视与 Mac 同一 Wi-Fi（5G/普通频段无所谓）。
2. **重启 Apple TV**（设置 → 系统 → 重新启动），再配一次。2026-11-20 实测：**没解决问题**，但成本低，先做。
3. **重启 CoreDeviceService**：`killall -9 CoreDeviceService`（会自动拉起），再看 devicectl。2026-11-20 实测：**没解决问题**。
4. **排除 VPN 与 IPv6**：断开 Shadowrocket（`scutil --nc stop "Shadowrocket"`）重配一次；Wi-Fi IPv6 开/关各试一次。2026-11-20 实测：**都没解决问题**。注意：**Wi-Fi IPv6 必须保持 Off**（Gemini Mac 客户端换 token 会撞坏的 IPv6 地址，2026-11-19 已定位；开回来会复发）。诊断完记得把 VPN 恢复 Connected。
5. **删电视上的 Mac 配对记录重配**：电视"设置 → 遥控器 App 与设备"里删掉已配对的 Mac，再配一次。2026-11-20 实测：**没解决问题**，且每次都会生成新临时 UDID。
6. **重启 Mac —— 唯一确认有效的解法**（文档案例 + 2026-11-20 晚实测）。重启后电视立即变为 `available (paired)`，真实隧道调用 `devicectl device info apps` 6 秒成功。
   - **重启前代价**：A1 抢实例监控、WDA、SSH 全断。重启后必须手动恢复：
     - A1 监控：`export PATH="/opt/homebrew/bin:$PATH"` 后 `nohup caffeinate -i /Users/lagransun/oci_ad1_monitor.sh >/dev/null 2>&1 &`（日志 `~/oci_ad1_monitor.log`；计数按轮次重置，属正常）。
     - WDA：`cd /Users/lagransun/workspace/Nastart && LOCAL_PORT=8168 zsh scripts/start_wda_iphone.sh`，再 `curl http://127.0.0.1:8168/status` 核 ready 与 bundle。
     - 验电视：`xcrun devicectl list devices | grep -i appletv` 应为 `available (paired)`。

## 构建与安装（已验证，2026-11-20）

- 工程：独立 tvOS 工程 `tvos/NastartTV/NastartTV.xcodeproj`，scheme `NastartTV`，bundle `com.changliwen.nastart.tv`，团队 `5436TB5498`（自动签名）。
- Xcode：`/Applications/Xcode.app` = **27.2**（电视/tvOS 固定用这个；`/Applications/Xcode-26.6.app` 只负责 iPhone 13 的 iOS 16）。
- **签名必须在 Mac 图形界面的 Terminal 里跑**：SSH 会话无法代码签名（钥匙串报 "User interaction is not allowed"）。经 `osascript` 让 Terminal 在已登录的 GUI 会话里执行，输出 tee 到日志。
- 构建命令（GUI Terminal 内）：
  ```
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project tvos/NastartTV/NastartTV.xcodeproj -scheme NastartTV \
    -destination 'platform=tvOS,id=00008110-000235903E99801E' \
    -derivedDataPath /tmp/NastartTVDerived -allowProvisioningUpdates build
  ```
  产物：`/tmp/NastartTVDerived/Build/Products/Debug-appletvos/NastartTV.app`。
- 已知构建失败（都已踩过）：
  1. `No profiles for 'com.changliwen.nastart.tv' were found` —— TV 描述文件 10-31 过期后未续，11-19 的续签只覆盖了 iOS。解法：加 `-allowProvisioningUpdates`，Xcode 自动生成（会把电视 UDID 登记进描述文件）。
  2. `TVUnifiedPlayback.swift:47:41: error: value of optional type 'URL?' must be unwrapped` —— `.network` 适配器把可选的 `playbackURL` 直接传给必填的 `Resource.url`。已修（2026-11-20）：`guard let url = source.playbackURL else { throw TVClientError.noPlayableSource }`。注意 `playbackURL` 只有 bridge 传输才有值，reader 传输是 nil，电视端只能走 URL 播放，nil 时报"无可播放源"而不应崩溃。
- 安装（保留数据覆盖）：
  ```
  xcrun devicectl device install app --device 00008110-000235903E99801E /tmp/NastartTVDerived/Build/Products/Debug-appletvos/NastartTV.app
  ```
- 验证：
  ```
  xcrun devicectl device info apps --device 00008110-000235903E99801E   # 应列出 Nastart 0.1.0 (1)
  xcrun devicectl device process launch --device 00008110-000235903E99801E com.changliwen.nastart.tv
  xcrun devicectl device info processes --device 00008110-000235903E99801E  # 应有 NastartTV 进程
  ```
- 截图：`idevicescreenshot` 看不到无线配对的电视（只认 USB/ usbmuxd 设备），不要用它判失败；以 `process launch` 成功 + 进程在跑为准，或直接看电视屏幕。

## 诊断命令速查

```
# 电视在不在 devicectl（地面真值）
xcrun devicectl list devices | grep -i appletv
# 最近一次配对尝试的日志（error nil + Disconnected = 配对成功、隧道失败）
log show --last 15m --predicate 'process == "DeviceHub"' --style compact | grep -E 'PairActionDeclaration|Pairing attempt completed'
# 电视网络可达
ping -c 2 192.168.1.66
# 描述文件到期时间（装包前核对）
security cms -D -i /tmp/NastartTVDerived/Build/Products/Debug-appletvos/NastartTV.app/embedded.mobileprovision -o /tmp/tv-prov.plist
python3 -c "import plistlib; d=plistlib.load(open('/tmp/tv-prov.plist','rb')); print(d.get('Name'), d.get('ExpirationDate'), '00008110-000235903E99801E' in d.get('ProvisionedDevices',[]))"
```

## 不要做的事

- 不要因为电视配对失败就升级 tvOS / 重置电视 / 解除配对后反复重配（重配只会换临时 UDID，不解决问题）。
- 不要把 tvOS 27 模拟器当真机验证；模拟器不能证明真机 HDR/音频/网络吞吐。
- 不要动 Tailscale（用户不在家时靠它远程控制 Mac）。
- tvOS 没有 iOS 那种"开发者模式"开关；配对后出现 Developer Settings 即正常，不要让用户去电视上找开发者菜单。
