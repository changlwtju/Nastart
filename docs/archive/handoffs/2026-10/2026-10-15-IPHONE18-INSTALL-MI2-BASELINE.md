# 2026-10-15 iPhone 18 最新包安装与 MI2 花屏旧包对照

## 本轮结论

iPhone 18 Pro Max 已成功保留数据覆盖安装最新 f5 普通 Debug 包，并实际进入 Nastart 正常首页。MI2 暂停 seek 花屏在最新包及 ce53 历史包的相同实际目标 4741.904337234497 秒均已看到，说明此故障在跨小时时间标签修正前已存在；根因和最初引入版本仍未确定，播放整体继续未通过。

本轮只做安装、观察和旧包故障分析，没有修改 App 源码或播放参数，没有新构建/重跑 XCTest。385 测试/2 跳过/0 失败及 15 预检属于 10-14 同源已完成结果；当前 173 输入哈希、源码差异和产物新旧关系重新核对。

## 源码与最新包身份

- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS 未提交差异 SHA `f5d06b2c9a8906ba769b6ed207377f7feb6002aa5c005b1cd078ebe1b4b1a572`；保留其他未提交修改。
- 配置 `normal Debug -Onone; empty launch environment`，二进制构建 `2026-10-14T20:56:00.037456+08:00`。App 包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-14-native-slider-cue-201359/Nastart-Stable-Timeline-Clock-Normal-Debug.app`；IPA `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-14-native-slider-cue-201359/Nastart-Stable-Timeline-Clock-Normal-Debug.ipa`。
- 三二进制 SHA：Nastart `a9ab92a85a6d0232421b6fce6b940d1e5767de133d77360c754114e68e13c55a`；debug dylib `22fe9271410b518e0e60e32ae06c9f608b5a6b192eb65daeb265dac6e20baa61`；KSPlayer `0b41cde45c806504810100a3e86d64f9ad352b69a6337ce77b8767d89dae161e`。
- IPA SHA `27ff7f67ec6253de383508a4ad24bfcecc4181318649f4a9daa5f21fb82f43a5`，本轮重核完整哈希、CRC 与三二进制；29 动态库逐项签名、deep、描述文件覆盖目标及有效期已核。描述文件到期 UTC `2026-10-17T22:23:40`。

## iPhone 18 安装与启动

- 开工 USB 清单无 18，CoreDevice 显示 unavailable；未直接当作设备身份。以已有配对无线端点现场验证名称/UDID/型号/系统/paired：iPhone19,7、27.0、NETWORK，原始值仅私有证据。
- 安装前保存偏好与诊断，以 installation_proxy 的 Install 保留数据覆盖，2026-10-15T07:29:50.135154+08:00 观察成功完成，随后 App lookup 存在。没有卸载、清登录、改配对/网络配置或重装 WDA。
- 25 项非诊断偏好含书签在安装前后、普通启动后逐值保持。通过配对 CoreDeviceProxy/userspace RSD、DVT 请求空 env/args 普通启动；实际 PNG 已看，为 Nastart 启动台、NAS 正常、播放器关闭。不是只凭 PID/版本号判启动成功。未在 18 执行播放回归或读取实际进程环境，空 env/args 为启动请求证据。
- 后续收尾再次 TCP 连接 6 秒超时；新鲜 Bonjour 服务发现 3 个候选未核实目标。此时未发送 App 命令，不能宣称末尾再次核对偏好或 18 播放回归完成，也不撤销早先已保存的安装及实际正常启动证据。后续操作须重新核实时连接。

## iPhone 13 最新包复现

- 现场 iPhone14,5/16.3.1/USB、名称/UDID 核对，保存偏好和真崩溃清单；2026-10-15T07:30:06.507921+08:00 先覆盖最新包，25 项安装偏好保持，空 env/args 实际首页已看。复用 WDA 8102，无整形。
- 普通 UI 从头、早暂停保留原生 KS，小时→分钟→小时各一次，各步原图保留，无测试环境/偏好注入。名义 4750→3580→4750 秒；实际 4719.714853→3588.048522→4741.904337 秒，与上轮三个实际目标一致。坐标仍不是任意时间精确定位接口。
- 第三目标 t3/t20 实图均严重块状花屏，保持暂停；前两步选定目标图未见同种损坏。最新原失败未以正常输出 API/解码 error=0/无崩溃覆盖。恢复普通播放后 t3/t8/t13 选定实图正常，首个恢复时刻未测，不将它写成 3 秒修复耗时或性能通过。
- 新捕获 syslog：第三次 demux result=0，前后 flush epoch5/6；首视频包 PTS4741.32、key=true、372605 bytes，前12包 sendResult=0，受限96帧 decodeErrors=0、hwFrames=true、pixelFormat158。generation 为0，不提供逐seek所有权证据；没有 NAL 类型、独立源帧或硬件参考列表，不能据此归因 CRA/RASL/flush 或网络取消。

## ce53 历史包对照，非最新包回归

- 历史 ce538bed01f2 普通 Debug `2026-10-14T18:19:28.479335+08:00`；与最新173输入相比只时间标签 UI 和测试两个输入不同，其余171及全部KSPlayer输入相同。两包的编译二进制不当作同一哈希。
- 单独 historical-baseline-analysis 目录保留身份/偏好/诊断、三SHA、29库/deep/profile及安装证据，2026-10-15T07:35:33.261728+08:00 覆盖历史包，25项偏好保持，实际正常首页已看；每个故障窗显式历史门槛，未冒称最新回归。
- 旧布局相同名义拖动第一目标实际4666.460269，和最新4719.714853不同；第二目标3588.048522一致。第三次按已测坐标差补偿名义请求4803.254584587098，实际恰为4741.904337234497；t3/t15/t20均同种花屏。**第一目标没有配齐，不能称完整同条件序列或统计版本失败率**；但旧包在同一最终目标出现故障，足以说明此类故障早于时间标签修正。旧包未另得有效解码 trace。
- 历史失败及普通退出图单独保留。结束后 2026-10-15T07:40:19.080669+08:00 再保留数据覆盖最新f5，25项安装偏好保持，空env/args实际首页重核。首次最新安装原证据移入 initial-latest-cover-retained，避免恢复安装覆盖它。

## 收尾与适用边界

- 13 最终24项非书签偏好保持，34个原书签五轨道字段保持、0删除、1项自然位置变化；实际正常首页/播放器关闭/空env/args，WDA idle10/cool2，原生active0。真Nastart/WDA/Jetsam集合0新增。
- 仅本轮两个已捕获窗口：最新WiFi URL metrics24/蜂窝0，旧包WiFi21/蜂窝0；不推算运营商流量。10GB是月总额，不用于测试预算。
- iPad本轮只现场清单/偏好保存，没有切换至其UI、覆盖安装或播放回归，不把10-14结果冒充10-15新验证。竞品/滚动完整帧、音频/HDR/PiP/全SUB等未新验。
- 工具问题保留：旧包安装未完成时提前调用首页门槛被拒，未触发启动，成功后另执行；拼图首次错用主证据根在缺文件守卫停止；安全路径格式器首次拒绝已相对路径后修正；原始PNG未改。原日志流未包含重装后旧进程消息，因此不编造旧包codec证据。18收尾无线失败见上。
- 当前PX-02/PX-20问题继续开放。下一步优先独立源帧与NAL随机访问类型/解码参考及输出所有权对照，再决定通用修复；不按片名增加缓冲、超时、重试或解码参数。原PGS/精确目标/Pad暂停seek等待、自动预热alignment、10.544秒切流/HLS23.943秒和NAS同期日志、S03双入口seek/冷续播、S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3及其余PX/UX/CB/Main仍开放。

结构化结果：[报告](../../../testing/results/2026-10/IPHONE18-INSTALL-MI2-BASELINE-20261015.json)。私有证据：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-15-iphone18-mi2-followup-072916`。所有原始设备名称/UDID/端点、偏好/凭据、字幕原文和PNG仅本机私有目录。
