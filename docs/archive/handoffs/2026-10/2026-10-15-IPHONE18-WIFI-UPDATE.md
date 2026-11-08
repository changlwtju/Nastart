# 2026-10-15 iPhone 18 最新包无线更新完成

按用户要求，本轮优先通过局域网 Wi‑Fi 更新 iPhone 18，并将可重复链路写入[无线更新操作手册](../../../development/IPHONE18-WIFI-UPDATE.md)。普通启动及实际首页已核验；没有新增 iPhone 18 播放、交互自动化或性能验收。iPhone13/iPad正在进行的换轨回归及所有旧未完成项保留，不因本次安装冲销。

## 当前包与现场身份

- 现场重新核对配对名称/UDID、型号 `iPhone19,7`、系统 `27.0`，网络连接，USB清单无目标。原始名称/标识/地址只留本机私有证据。
- 当前 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，dirty iOS源码SHA256 `c868c278fcefe2411cfc07eabb4adf33ce159f0a0f9fb446897aeb2ce25ac835`。普通 Debug `-Onone` 构建 `2026-10-15T18:56:47.888882+08:00`，包 `Nastart-Live-Track-Handoff-Final-Normal-Debug.app` / 同名IPA。
- 本任务不改 App 源码、不重构建。173输入、HEAD/dirty diff、三二进制、IPA SHA/CRC/内部二进制、29库独立签名、deep/strict、profile授权及期限在安装前、偏好保存后/上传前和收尾均核对。profile到期UTC `2026-10-17T22:23:40`。
- 主二进制 `963906f2460a7e8ca717dbb818d7ac6e6425a0466c28d96d8a5829cd21f8a75b`，Debug dylib `46cb682d7938d2f4d45b622dc49ca9ecc368f493717d7c23303a44196c4ba8f5`，KSPlayer `76d17821ceeba058544cad0031b0eb41f4fa6be90edb9ec36ebe2d1f24bb7b5e`；IPA SHA256 `197133cef44eec71d344cf716aee716f902edcad17a2bb51da80425e970ee537`。
- 同源396测试/2跳过/0失败和15预检属于18:56构建批，本次安装任务没有重跑App测试。无线工具最终11测试通过，结果明确分列。

## 实际成功链路与数据保持

1. 系统 DNS‑SD 重新解析已知目标服务及当前IPv4，既有配对、`autopair=False`、实时UDID/型号校验成功；随机广告端口与标准lockdown端口区别处理，无盲扫网段。本次确认标准端点可用，Xcode自动发现不作为安装前置条件。
2. 普通 HouseArrest 请求曾在 `VendContainer` 后 `ConnectionTerminatedError`；用户确认解锁并打开App后该路径仍失败。只读诊断使用已有配对 `EscrowBag` 后容器可读，同窗 installation_proxy lookup/AFC信息也可读。没有独立排除时间/设备状态因素，不把escrow认定为所有无线故障的唯一根因。
3. 最终工具保持真实lockdown provider类型，启动容器服务时复用现有escrow；成功保存完整偏好，再核包，经AFC暂存和 installation_proxy **`Install`** 保留数据覆盖。于 **2026-10-15 21:49:20.742898（北京时间）** 收到明确Complete，安装后lookup存在。
4. 安装前后25项非诊断偏好逐值相同，含完整书签对象，0键/值变化。既有配对 CoreDeviceProxy/userspace RSD现场核到目标，DVT请求 `environment={}`、`arguments=[]` 正常启动；实际截图已打开看过，是Nastart首页、NAS状态正常、播放器关闭。启动后25项偏好再次逐值相同。空env/args是启动请求证据，未额外读取实际进程环境。

没有卸载、清登录、删除书签、重配、修改Mac VPN/Tailscale/Shadowrocket、系统网络或remoted，没有系统升级、WDA重装或使用WDA。正常启动截图成功不表示Xcode自动隧道和WDA已恢复；WDA过期不阻止本次安装/原生启动截图链路。

## 工具、文档与保留失败

- 复用[实时发现工具](../../../../scripts/discover_paired_wireless_device.py)，新增[保留数据安装/可选正常启动工具](../../../../scripts/install_paired_wireless_app.py)，显式传入本机manifest/输入记录/已验证端点及独立输出目录；不改其他设备任务正在用的全局证据指针。
- 安装工具将上传、命令尝试/发送、Complete、lookup、偏好、启动/实际图审阅分开记录。备份失败/源码变化/错误设备均阻止上传；Complete已见后验证失败也保留成功事实，不用统一异常状态覆盖。
- 初版通用provider包装使HouseArrest误选RSD `.shim.remote` 服务名，实际返回 `InvalidService`，当次未上传/未发送Install。改为保留原client类型的HouseArrest子类后完成真实安装。该失败、两次早期断连、早期RSD失败均保留。两项构造测试最初无asyncio loop，修正测试夹具后11项通过；不是App故障。
- 实际设备成功运行后，仅增加异步异常原文写私有日志的处理，未改传输/授权/安装/启动逻辑；最终11项工具测试及冻结工具哈希另存。没有为文档变化重复安装或虚构第二次实机验收。
- [操作手册](../../../development/IPHONE18-WIFI-UPDATE.md)包含可执行命令、前提、签名/身份/数据门槛、escrow及普通/RSD服务名差异、WDA边界、各层失败和成功标准；README、播放运行手册与CLI观测手册均已增加入口。

安全结构化报告：[IPHONE18-WIFI-UPDATE-20261015.json](../../../testing/results/2026-10/IPHONE18-WIFI-UPDATE-20261015.json)。私有证据目录代号 `2026-10-15-iphone18-wifi-update-213932`；manifest完整路径、端点、偏好/凭据、诊断、PNG、各次失败与冻结工具都仅本机保存。原track-continuous窗口中旧18安装失败记录已归档，当前安装摘要另更新为本次c868成功，避免继续沿用旧f5/db873状态。

接续按[换轨保持播放交接](2026-10-15-LIVE-TRACK-HANDOFF.md)：USB13/iPad回归继续；18后续任何播放调试先重新核实时连接与当前包。蜂窝10GB仍非测试预算，本安装任务不进行蜂窝媒体测试。MI2、字幕/音轨、首帧/seek/HLS/NAS等待、全SUB/AUD/HDR/PiP/竞品完整帧/19×4及所有PX/UX/CB/Main未完成项保持开放。
