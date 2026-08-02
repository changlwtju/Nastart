# Nastart NAS、媒体播放与 Jellyfin 优化线程交接

日期：2026-08-02  
分支：`main`  
线程代码基线：`5e347b1 Improve NAS connectivity and media experience`

## 文档目的

本文用于在 Mac 上继续本轮 Nastart iOS/iPadOS 调试。它整理了黑群晖开发环境中的对话上下文、用户反馈、诊断结论、已经实施的代码修改，以及下一轮真机验证重点。

本文不保存 NAS 密码、DSM SID、Jellyfin Access Token、API Key、公网域名或完整内网地址。文中的地址统一使用示例或脱敏形式。

## 用户目标

1. iPhone 与 iPad 在局域网、外网连接同一台 NAS 时，功能和状态判断应保持一致。
2. 设备文件中的视频应快速开始播放、稳定拖动进度，并优先使用兼容播放器处理 MKV、TS、H.265、AC3 等格式。
3. Jellyfin 应能自动发现正确入口、可靠登录、显示刮削图片、搜索和收藏，并提供质感更好的首页和详情页。
4. 内置播放器与 Jellyfin 播放器应保持一致的控制和横竖屏体验。
5. 应识别已安装的外部播放器，并允许用户将媒体交给 Infuse、VidHub、VLC 或系统分享面板中的其他 App。
6. 资源统计、在线状态、帮助说明和安全提示必须准确，不能显示缓存造成的虚假内存值或过期在线状态。

## 问题演变

### 1. 初始代码审查

早期审查识别了以下风险：

- DSM 地址包含反向代理子路径时，API URL 直接覆盖 `path`，可能丢失 `/dsm` 一类前缀。
- File Station 外部播放 URL 包含 `_sid`，交给第三方 App 或分享面板时会扩大凭据暴露范围。
- Keychain 先删除旧记录再写入新记录，新增失败时可能丢失凭据。
- 自签证书信任曾经只按 Host 放行，没有处理证书变化。
- Linux/群晖环境没有完整 Xcode，无法完成 iOS 真机编译验证。

这些问题在随后提交中逐步处理，重点提交见“提交历史”。

### 2. iPhone 与 iPad Web 访问差异

- iPhone 曾无法通过内置浏览器或 Safari 打开 code-server 与 MetaCubeXD。
- iPadOS 18.3.1 使用相同 App 时可以正常访问。
- 因此暂时判断为 iPhone 网络、Safari/WebKit、DNS、代理或系统设置差异，不再为该现象保留测试容器。
- 三个临时 code-server 容器与对应测试镜像已经清理；原有正式 `code-server` 容器保留。

### 3. MobileVLCKit 接入和构建问题

为支持系统播放器不能解码的格式，项目通过 CocoaPods 接入 MobileVLCKit。期间处理过：

- Jellyfin 登录函数参数遮蔽属性，导致 `username is a let constant`。
- MobileVLCKit 的跳转 API 需要 `Int32`，不能直接传 Swift `Int`。
- Xcode User Script Sandboxing 阻止 CocoaPods `rsync` 写入 MobileVLCKit framework。
- 必须使用 CocoaPods 生成的 `Nastart.xcworkspace` 构建，不能继续打开 `.xcodeproj`。

### 4. 播放器体验问题

真机反馈包括：

- AVPlayer 无法播放部分 MKV/H.265/AC3 文件。
- MobileVLCKit 可以播放，但早期控制区过高、横屏信息栏未隐藏、字幕过大。
- 首次播放缓冲时间长，连续快进容易再次卡顿。
- 竖屏和横屏切换时视频区域尺寸跳变明显。
- 外网播放时下载速度低，原画 MKV/TS 不适合带宽不足的链路。

当前实现统一了播放入口，并根据媒体来源和网络位置选择 AVPlayer、MobileVLCKit 或 Jellyfin HLS 转码。

### 5. Jellyfin 体验问题

用户参考 Lenna 与 DS One，明确提出：

- 首页需要高质量刮削图轮播，不能使用随机视频截图。
- 需要电影、电视剧、继续观看、收藏和搜索。
- 详情页需要更完整的海报/背景、简介、剧集信息和播放操作。
- 需要在内置播放与外部播放器之间选择。
- 手机详情页曾出现内容超出屏幕、文字被裁切的问题。

当前首页轮播仅使用 Jellyfin 返回的 `Backdrop` 刮削图，并请求 1920 像素宽、高质量版本；没有 Backdrop 的条目不会进入轮播。

### 6. 内外网连接问题

诊断日志曾显示：

- 局域网 Jellyfin 根地址返回明确的 HTTP 404，而外网反向代理地址可用。
- 这说明容器在线并不等于当前 URL 是 Jellyfin API 根地址。
- 局域网设备文件播放曾长时间停留在 MobileVLCKit `opening` 状态。
- 外网 Jellyfin 原画直放 MKV/TS 时启动慢、拖动恢复慢。
- 离开家庭网络后，启动页仍显示之前缓存的 NAS 和服务在线状态。

当前 Jellyfin 会验证 `/System/Info/Public`，并依次尝试已有路径、`/jellyfin` 和 `/emby`；普通 404 页面不会再被标记为可用 Jellyfin 服务。

## 当前实现

### DSM URL 与 HTTP/HTTPS

- `DSMURLBuilder` 拼接 API 时保留反向代理基础路径。
- 新增明确的 HTTP/HTTPS 分段选择器。
- 局域网允许 HTTP，缺省端口为 `5000`；HTTPS 缺省端口为 `5001`。
- 选择器会覆盖输入框中的旧协议，并同步切换默认端口。
- 外网连接仍强制 HTTPS；自签证书开关仅对 HTTPS 生效。

相关文件：

- `ios/Nastart/Nastart/Core/Stores/AppStateStores.swift`
- `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift`

### 设备文件播放

- File Station 为同一文件生成当前连接地址及可用的局域网 HTTP 备选地址。
- 播放前发送 `Range: bytes=0-1` 预检。
- 仅接受 HTTP 200/206 且不是 JSON/HTML 的响应。
- 使用重定向后的最终 URL，避免预检地址与播放器地址不一致。
- MobileVLCKit 使用硬件解码、HTTP 重连、连续连接和快速定位选项。
- 局域网缓存目标约 900 ms，外网约 1500 ms。
- 连续快进/快退操作在短时间内合并，减少重复重建网络读取。
- 字幕相对字号从早期较大的值调整为 18。

相关文件：

- `ios/Nastart/Nastart/Features/Devices/DevicesView.swift`
- `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift`

### Jellyfin 登录与播放

- 自动尝试根路径、现有反向代理子路径、`/jellyfin` 和 `/emby`。
- 登录成功后将实际有效的 Endpoint 与会话写入 Keychain。
- 局域网/private host 优先使用原画直放。
- 外网视频优先请求 Jellyfin HLS 转码，目标最高约 10 Mbps。
- 转码配置使用 H.264、AAC、3 秒分片，提升首播和 Seek 后恢复速度。
- 可获取的外置字幕 URL 会传给 MobileVLCKit 和支持字幕参数的外部播放器。

需要注意：设备文件页通过 DSM File Station 读取原始文件，DSM 本身不提供 Jellyfin 式实时转码。外网原始文件播放速度仍受 NAS 上行、反向代理、运营商链路和视频码率限制。

### Jellyfin 界面

- 首页顶部使用 Jellyfin `Backdrop` 刮削图轮播，最多 6 项，约每 6 秒自动切换。
- 请求 1920 像素宽、质量 96 的背景图。
- 首页包含媒体库、继续观看、收藏、电影与电视剧横向内容架。
- 保留搜索与收藏状态同步。
- 详情页采用全宽媒体头图和受约束的正文宽度，避免 iPhone 上横向溢出。
- 播放按钮与外部播放器菜单处于同一主要操作区。

### 外部播放器

App 使用 `UIApplication.canOpenURL` 和 `LSApplicationQueriesSchemes` 识别：

- Infuse
- VidHub
- VLC

Infuse handoff 会传递媒体 URL、文件名和可用的外置字幕 URL。对于没有公开稳定 URL Scheme 的播放器（例如当前未发现 Fileball 的可靠播放协议），使用“其他 App”打开系统分享面板，让已安装 App 自行声明接管能力。

包含 `_sid`、`api_key` 或 Token 的 URL 在交给 Safari、第三方播放器或分享面板前会提示用户确认。

### 资源统计

DSM 容器资源接口中的百分比是百分数点，不是 0 到 1 的比例。旧逻辑会把 `0.37` 显示为 `37%`。

当前逻辑统一除以 100，并在拥有整机总内存时，使用“整机内存 × 容器占用率”估算活跃内存。这样不会再把包含可回收文件缓存的原始 cgroup 计数直接显示成 Jellyfin `5.8 GB` 运行内存。

UI 中对应文案改为“估算内存占用”，避免把该值表述为精确 RSS。

### 行内帮助

“断开 NAS”等危险或需要解释的操作，叹号按钮点击后直接在当前行下方展开说明；iPad 指针悬浮时也会原地显示。不会再跳转到空白页面或展开全屏 Sheet。

## 提交历史

本轮关键提交按时间排列：

| Commit | 内容 |
|---|---|
| `9bcfaf0` | 改进兼容播放器控制 |
| `b63ce99` | 改进 Jellyfin 浏览和原画播放 |
| `557de0c` | 优化 Jellyfin 资源库与统一播放器 |
| `59565cb` | 修正 iPad 连接布局和播放器路由 |
| `5fd5374` | 修正 LAN 可达性与安全媒体播放 |
| `1252b74` | 修正媒体播放回归与海报轮播 |
| `d0acc2a` | 加固 LAN/WAN 路由与上下文帮助 |
| `5e347b1` | 改进 NAS 连接、媒体体验和 Jellyfin UI |

## 已完成检查

在群晖开发环境执行：

```bash
git diff --check
bash scripts/preflight.sh
```

结果全部通过：

- Git whitespace
- Swift delimiter balance
- iOS 16 静态 API 守卫
- 英文/简体中文本地化一致性
- 本地化引用
- AppIcon
- Xcode project settings

群晖环境没有完整 Xcode 和 iOS SDK，因此以上不等同于 Swift 编译、链接或真机运行验证。

## Mac 接续步骤

```bash
cd /Users/lagransun/workspace/Nastart
git pull origin main
cd ios/Nastart
pod install --repo-update
open Nastart.xcworkspace
```

必须打开 `Nastart.xcworkspace`。`Nastart.xcworkspace` 和 `Pods/` 是 `pod install` 在 Mac 本地生成的内容，不提交进 Git。

如果 Xcode 报 CocoaPods framework 的 `rsync Operation not permitted`：

1. 选择 Nastart Target。
2. 打开 Build Settings。
3. 将 `User Script Sandboxing` 设置为 `No`。
4. 执行 Product > Clean Build Folder。
5. 删除对应 DerivedData 后重新构建。

## 真机回归矩阵

每一种连接都分别测试 iPhone 与 iPad：

| 场景 | 连接 | 重点 |
|---|---|---|
| LAN HTTP | `http://192.168.x.x:5000` | DSM 登录、文件列表、设备文件播放 |
| LAN HTTPS | `https://192.168.x.x:5001` | 自签证书、证书固定、文件播放 |
| WAN HTTPS | 脱敏公网域名 | DSM、Jellyfin、首播、拖动恢复 |

每个场景至少覆盖：

1. App 冷启动后在线状态是否重新验证，而不是继续显示旧缓存。
2. Jellyfin 登录后是否选择了正确 Endpoint。
3. Jellyfin 首页轮播是否全部为刮削 Backdrop，而不是视频帧。
4. MP4、MKV、H.265/HEVC、AC3/DTS 各选择一个样本。
5. 首帧时间、连续三次前进 15 秒、拖动到影片中段后的恢复时间。
6. 内封字幕和外置字幕是否出现、字号是否合适。
7. 竖屏、横屏、全屏来回切换是否有明显尺寸跳变。
8. Infuse、VidHub、VLC 和系统分享面板是否只显示可用入口并能实际播放。

## 下一轮诊断建议

若仍然卡顿，请导出诊断日志并同时记录：

- 使用 LAN HTTP、LAN HTTPS 还是 WAN HTTPS。
- 文件容器、视频编码、音频编码、分辨率、文件码率和大小。
- 从点击播放到首帧出现的秒数。
- Seek 前后时间点，以及恢复播放所需秒数。
- 同一 URL 在 Infuse/VLC 中是否流畅。
- NAS 上行速度与 Jellyfin 是否触发转码。

这些信息可以区分 URL/认证错误、证书问题、播放器解码问题、NAS 读取速度、Jellyfin 转码性能和公网带宽瓶颈。

## 当前未闭环事项

- 尚未在完整 Xcode 环境编译提交 `5e347b1`。
- 尚未取得本轮修改后的 iPhone/iPad 新诊断日志。
- Device Files 外网播放没有服务端转码能力，极高码率源文件仍可能受带宽限制。
- Jellyfin 字幕轨道选择还需要针对内封 ASS/SSA、PGS 和外置 SRT 做真机验证。
- Fileball 没有接入私有或未经文档确认的 URL Scheme，目前通过系统分享面板提供。

