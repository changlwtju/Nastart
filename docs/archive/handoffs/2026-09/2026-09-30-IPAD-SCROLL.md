# 2026-09-30 iPad 启动台与海报滚动

## 必须延续的调试门槛

用户明确要求：每次在 iPhone 13 / iPhone 18 / iPad 开始调试，先逐台核对是否最新包。已写入根目录 `AGENTS.md`，README 与播放调试规范均引用。版本号不作为唯一身份；无法核实时先保存诊断，再保留数据安装有哈希/签名证据的当前包。

## 当前设备与安装

- USB 清单：iPhone 13 `REDACTED-DEVICE-01`、iPad 9 `REDACTED-DEVICE-02` / 18.3.1。CoreDevice 仍列 iPhone 18 connected，不能据此说它 USB 接入；本轮未操作 iPhone 18。
- 调试前保存 iPad 偏好诊断，先将两台已知旧包更新为上一轮 ISO 最新包 `343f0b3a…`，确认正常启动后开始界面操作。
- 本轮源码基于 HEAD `9a9941c` 加既有未提交修改。第一轮滚动修正完成后重新构建、严格验签，21:55–21:56 将最新 `dd26df8f…` 包再次保留数据安装两机并正常启动；iPad PID 8450，iPhone ios-deploy launch success、PID 60564。
- 最新包 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll/Nastart-scroll.app`。
- `Nastart.debug.dylib` SHA-256：`dd26df8f2f23a29b74dac4d58a11885cc69c01c7556bcee6c62a84ad967602f7`。配置 Debug（-Onone），没有人为网络限速或视频转码。不能把 Debug 测试当作 Release 性能结论。

## 用户现象与代码改动

用户明确最卡页面为“启动台／媒体海报列表”。

1. 默认 ProductLaunchpad 与服务组行原先使用 VStack，一次创建全部内容；改为 LazyVStack 按需创建，保留服务 ID、分组折叠和现有外观。
2. 海报缓存原来用 JPEG 等压缩数据 `data.count` 作为成本，却持有 UIImage 解码像素，低估内存。改为实际 `bytesPerRow * height`（无 CGImage 时用像素面积估计），保留 64 MiB 软预算。
3. 下载后在专用串行队列 `preparingForDisplay()`，将解码准备移出显示路径，保留图像方向，并检查取消；未降低海报请求分辨率。

这是代码审查确认的成本问题，不能直接认定解释全部卡滞。尚未获得同条件、同配置、同缓存状态的前后帧时间对照。

## 验证及证据

- iphoneos Debug 构建成功，codesign 严格验证、preflight 和 diff 检查通过。
- iPad 旧 WDA fixture 本轮通过 XCTest 正常启动，8103 ready=true（16.12.10）；此前的 WDA 不可用状态已过时。
- 原最新包已实机执行启动台 12 次往返滑动；随后打开 Jellyfin 媒体资源库，截图确认海报/继续观看内容正常加载。没有启动影片。
- xctrace 按 PID/name 附加报找不到 Nastart，但全进程采样成功。初始 15.41 秒 Animation Hitches 录制仅有一个 16.72 ms hitch，尚未完成进程归属分析；**不能以这个系统级单次结果证明或排除用户的长期卡滞**。
- `/tmp/nastart-ipad-media-before.trace` 实际覆盖服务详情到媒体入口准备，不是有效的海报滑动基线，禁止用于宣称海报优化百分比。
- 私有证据目录同包目录，原始偏好包含账户信息，不入库；构建日志 `/tmp/nastart-ipad-scroll-build.log`、WDA `/tmp/nastart-ipad-scroll-wda.log`。滚动修复未提交。

## 待验

量化验证仍需同一设备的冷/热海报长列表滚动、主线程采样及同源码 Release 对照；需确认实际可感知改善，不能仅凭能滑动或单张截图关闭 UX 性能项。iPhone 18 下一次调试须先补装当前最新包；其旧 ISO 包仍是上一轮记录。

## 新包实机补证

`dd26df8f…` 包 iPad 默认启动台 6 次往返滑动请求成功；再次通过 Jellyfin 服务进入媒体资源库，新包截图确认顶部轮播、媒体分类、继续观看海报正常显示。尚无主观流畅验收。21:56 的全进程 Animation Hitches 录制 `/tmp/nastart-ipad-launchpad-after.trace` 覆盖约 20 秒；与首轮录制时段/操作并不完全匹配，不计算改善百分比。

后录制导出共 12 个系统级 hitch（含 16.66–33.32 ms 等样本）；首次导出早于保存完成而失败，保存结束后成功。该结果没有进程归属及同条件控制，不能将 1→12 宣称改善或回退。媒体页 WDA 首次滑动等待空闲超时；日志有 event loop idle notification not received，截图仍正常，不能仅据此判定 App 卡死。已将本轮 WDA 的 idle/animation 等待设为 0 继续核实，不改变 App/系统动画设置。

最终媒体页补测：关闭 WDA 空闲等待后，同一新包 6 次往返滑动请求全部成功；这是交互可执行证据，不是帧率或真人流畅验收。结束本轮 XCTest/8103 转发，保留 WDA 安装与正常 Nastart 进程，未改系统网络。
