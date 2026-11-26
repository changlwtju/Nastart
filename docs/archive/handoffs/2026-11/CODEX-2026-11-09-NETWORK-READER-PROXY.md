# 2026-11-09 网络存储 Reader 接入共享代理

接续[共享代理第一步](CODEX-2026-11-08-NETWORK-SOURCES-SHARED-PROXY-PHASE1.md)和[原流首段接手](CODEX-2026-11-09-ORIGINAL-RESPONSE-HANDOFF.md)。本批基线为 main/8db1cc64 加已有未提交修改；Codex 独占列明文件。没有改变 NAS 文件、连接配置或协议凭据。

- iOS 的 `NetworkLibraryPlaybackView` 由已索引版本构造 `NetworkMediaByteReader`，通过 `NetworkMediaPlaybackSource.Transport` 把能力交给 App。来源地址、稳定书签键、文件名和总长度仍来自原元数据。协议 Reader 仍负责鉴权、版本核对及具体读法。iOS 正常路由不会启动包内监听器，只有 App 代理注册失败且准备任务未取消时，才按需启动旧桥接；两者使用同一种呈现 lease 释放。tvOS 仍用包内桥接。
- `AuthenticatedMediaStreamProxy` 在同一 loopback 监听器上按注册能力分发 HTTP 上游或 Reader。Reader 的能力严格绑定播放路径，不接受查询参数或换目标；HEAD 只回答长度。有限、开放和后缀 Range 共用解析，支持 416，总长度已知无需上游后缀探针。未广告本地验证标识，`If-Range` 无法匹配时返回完整表示。
- 一个客户端响应可覆盖多个最多 32 MiB 的 Reader 调用。每个调用保持协议的版本检查和内部块尺寸；客户端每块发送完成后才接收下一块。四路上限保留，第五路收到空体 503。客户端断线、路由撤销、监听失效或 30 秒无进展都取消对应读取。半关闭写端不影响继续收正文。首块失败发 502；头部已发后若正文不足则关闭连接，保留原 Content-Length 供播放器识别短读。
- `sharedReader` 表示 App 选择直接 Reader；`readerFirstChunkDelivered` 与 `readerTransferFinished` 记录客户端交付。交付计入播放字节，排除出源端自适应吞吐估计。原 HTTP 路线和默认关闭的原流首段接手实验不变。

Xcode 27.2 / 空白 iOS 27.0 iPhone Air 模拟器。首轮 13 项通过；加有限窗和跨界校验后，最终同源 14 项通过。合成 H.264 实际解码并对齐。另覆盖 32 MiB 连续性、HEAD、后缀/开放/越界/条件范围、路径绑定、四路满额后重新接入、客户端 RST、半关闭、单路撤销不影响另一能力、首块失败、超长和短读，以及既有桥接、HTTP 和首段接手回归。测试用临时模拟器已删除。

NetworkMedia 的定向包测试为 30 通过、6 跳过、0 失败。6 项为未提供 SMB 测试服务的集成夹具；没有使用用户的 NAS 凭据补齐夹具。Reader 描述符和旧桥接的稳定书签键、版本检查、FTP 与 WebDAV 定向用例均通过。

签名 Debug `fe63a3119a8949f49357e41d453bd0f9ed82b9746dbc9dbe482245f0051e58f4`（代码 dylib），主程序 `82ffa5d56cfed3fec1fe7a9d1767473bcb9485d5fc745afce4106722ebccf944`，14:06:44 构建并冻结。包与构建清单仅存私有证据目录，入口 `/tmp/nastart-network-reader-proxy-current`。A16 iPad（iPad15,7，iPadOS 26.6，USB）14:07:11 保留数据覆盖，签名及偏好全等，空环境正常启动。每次重新打开窗口均核设备与包身份，使用已验证的现有 Runner。

iPad 14:13 的实际读取使用已有 SMB 索引中的 13,047,776,001 字节单个 MKV，普通 Wi‑Fi、内网地址、KSPlayer 原流。同一会话记录 `sharedReader`、`readerFirstChunkDelivered` 和 206；三个有限尾部范围各完整交付（85、2,122、174,254 字节），开放范围因播放器换请求而取消，其中一路取消前交付 45 MiB。已目视检查起播和前进 15 秒后的两张不同影片画面。应用记录内部首帧 2,012 ms、跳转恢复 2,757 ms（目标 27.365 秒）；两者均为内部事件计时，没有测到屏幕首帧时刻。普通退出回到详情，14:14:13 核自有 App、Runner、转发均已停。库和连接索引全等，最后偏好只有本地进度和诊断变化。

此前四次导航核对未请求播放：先后修正夹具参数、搜索入口、蓝光分组动作及无续播记录时的播放按钮。保留现场日志，不能算作播放失败或另四次运行。

iPhone 13（iPhone14,5，iOS 16.3.1，USB）14:15:17 保留数据覆盖同包，安装偏好全等。空环境启动、已有 Jellyfin 登录、资源库搜索均正常。普通 Wi‑Fi 从头播放 128.8 GB《护戒使者》：私网 HTTP、206、`localRangeProxy`、KSPlayer，未触发默认关闭的首段接手。内部首帧 887 ms，截图有实际片头画面且当时正在缓冲，日志记录一次稳态缓冲。普通退出后 App、Runner 和本地转发均已停止；偏好只有诊断和本地进度变化。该窗核原 HTTP 路线兼容性；13 的 Reader 路线另补。

iPad 14:17 再从已有 FTP 索引选择同路径、同名、同大小的 MKV，普通 Wi‑Fi、私网地址、同包、同引擎。`sharedReader` 实际交付 206，三个有限尾部范围均与 SMB 等长；一个开放请求在客户端断开前实际交付 44,065,464 字节，超过一个 32 MiB Reader 窗。起播和前进 15 秒后均有真实不同画面，内部首帧 1,719 ms、跳转恢复 1,449 ms（目标 27.962 秒），普通退出。14:18:21 核已停自有 App、Runner 和转发，库和连接索引仍全等，最后偏好差异仅诊断和本地进度。SMB 与 FTP 各一窗、固定先后顺序且跳转落点略有差别，不比较速度。

[结构化结果](../../../testing/results/2026-11/CODEX-NETWORK-READER-PROXY-20261109.json) 区分模拟器、包级和真机证据。本窗不判断提速、显示首帧、长时、音轨字幕或 HDR 输出，不关闭矩阵格。下一步补 WebDAV 及 iPhone 13 的 Reader；再用《护戒使者》按实际网络和相同落点复验续播、从头、跳转和切轨。SMB/FTP 仅内网；首段接手仍默认关闭。未操作 iPhone 18 或 Apple TV。
