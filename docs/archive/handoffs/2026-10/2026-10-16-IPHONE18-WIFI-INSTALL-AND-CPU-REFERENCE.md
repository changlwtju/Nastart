# 2026-10-16 iPhone18 最新包覆盖安装与 CPU 参考续查

## iPhone18 安装完成

用户在 CPU/内存排查过程中要求优先安装最新包，已沿 [Wi-Fi 安装手册](../../../development/IPHONE18-WIFI-UPDATE.md) 执行。现场 DNS-SD 重新解析并核到既有配对目标，型号 iPhone19,7、系统 27.0、网络连接、USB 清单无目标；名称、UDID、端点和全部原始偏好仅留本机私有证据。

当前 App 源码仍是 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` + iOS dirty diff SHA-256 `c868c278fcefe2411cfc07eabb4adf33ce159f0a0f9fb446897aeb2ce25ac835`。173 个构建输入未变，最新有效包仍为 **2026-10-15 18:56:47.888882 +08，Xcode27 普通 Debug -Onone**。本轮新增的是诊断分析，不包含 App 功能改动，无需重构建。396 项/2 跳过/0 失败及 15 预检只引用该同源构建批，没有重跑；无线工具及 App 源码本轮均未修改。

包 `Nastart-Live-Track-Handoff-Final-Normal-Debug.app/.ipa` 的实际路径保存在私有 manifest。安装前、偏好保存后/上传前及收尾重新核 HEAD、dirty diff、173 输入、IPA CRC/内容哈希/Bundle ID、29 个库独立签名、deep/strict 签名、profile 授权和期限，以及三二进制：

| 产物 | SHA-256 |
| --- | --- |
| Nastart | `963906f2460a7e8ca717dbb818d7ac6e6425a0466c28d96d8a5829cd21f8a75b` |
| debug dylib | `46cb682d7938d2f4d45b622dc49ca9ecc368f493717d7c23303a44196c4ba8f5` |
| KSPlayer | `76d17821ceeba058544cad0031b0eb41f4fa6be90edb9ec36ebe2d1f24bb7b5e` |
| IPA | `197133cef44eec71d344cf716aee716f902edcad17a2bb51da80425e970ee537` |

先通过既有 escrow 的 HouseArrest 保存完整偏好，再经 AFC + installation_proxy 保留容器覆盖。于 **2026-10-16 07:10:53.805191 +08** 收到明确 `Complete`，安装后 lookup 存在。安装前后全部 25 项非诊断偏好逐值相同，包含完整书签对象；启动后及后续只读复查也保持 25 项、0 键/值变化。没有卸载、清登录、回写旧书签、重配、系统/网络/VPN/WDA 改动。

## 启动证据的范围

- 既有配对 CoreDeviceProxy/userspace RSD/DVT 实时核目标，明确请求空 `environment={}`、`arguments=[]`。首次 6 秒截图已实际看过，前台为其他 App，不能拿它证明 Nastart 首页；该原始失败观察保留。
- 单独补做一次启动核验，**没有重复安装**。只将私有核验函数的截图等待从 6 秒缩短至 1 秒，原因是缩小前台变化窗口；项目工具和 App 均未修改。实际图已看，确为 Nastart 启动台，播放器关闭、界面已渲染。该早期截图 NAS 标为“未连接”，不能宣称 NAS 连接或播放通过；未额外读取实际进程环境。
- 后续一次纯截图/偏好读取没有再启动 App；前台已是其他 App，不当作 Nastart 的网络状态证据，也未操作该 App。安装后偏好仍完全保持。没有为追逐截图反复覆盖安装或改变手机网络。
- 安装及实际启动台核验完成。NAS 稳定连接、iPhone18 播放/交互/性能尚未验收；后续操作先重新核设备与包。

结构化安装记录：[IPHONE18-WIFI-INSTALL-20261016.json](../../../testing/results/2026-10/IPHONE18-WIFI-INSTALL-20261016.json)。本批独立私有根目录指针 `/tmp/nastart-iphone18-install-evidence`，没有重定向其他设备任务的 current/stage/background/memory/alignment 指针。

## CPU 与内存续查的增量

本轮开工已读进度及播放规范；用户安装请求前后，只读分析既有证据，没有新 iPhone13/iPad 安装或播放，也没有新增 profiler。原先 [分配诊断](2026-10-16-HANDOFF-ALIGNMENT-AND-ALLOCATIONS.md) 的 CPU 资源警告仍保留，内存对象归属未定。

1. 将资源报告中两条 App 帧的 image UUID 与当前冻结 debug dylib 精确匹配，再用该二进制符号化。只得到 `__debug_main_executable_dylib_entry_point` 与 `static NastartApp.$main()` 入口帧，没有取得可行动的分配或耗时函数。不能把 App 出现在栈里当作某个具体热点已定位。
2. 复算 10-15 **同源普通 Debug、未附加 Allocations** 的已有 Sysmontap 数据。CPU 使用本机 pymobiledevice3 CLI 所述的“单核百分比”口径，可超过 100；不是整机 CPU 百分比。仅汇总有限、非负的数值，缺失值保留，不补 0、不积分成 CPU 时间。

| 既有窗口 | 启动有效 CPU 样本 / 总样本 | 启动 CPU 中位（单核%） | 启动采样最大（单核%） | 同PID首页10～30秒 CPU中位（单核%） |
| --- | ---: | ---: | ---: | ---: |
| S19 r2 | 57 / 59 | 71.637 | 135.975 | 0.150 |
| S19 r3 | 61 / 61 | 64.800 | 153.024 | 0.122 |
| S19 r4 | 60 / 60 | 72.370 | 134.486 | 0.138 |
| S01 单轮 | 61 / 61 | 48.715 | 124.474 | 0.142 |

该结果表明普通包的既有启动窗口也有明显 CPU 活动，退出后同进程采样显著下降。三次 S19 与单次 S01 不是同片对照，不作排名；与 Allocations 进程的资源报告在时段、时长、缓存及采样方法上未配对，不能直接比较 63% 报告或判定诊断工具的额外开销比例。约 1Hz 数据和离散图也不能证明连续帧、卡顿或长期稳定性通过。

结构化参考：[CPU-REFERENCE-20261016.json](../../../testing/results/2026-10/CPU-REFERENCE-20261016.json)。独立私有指针 `/tmp/nastart-cpu-evidence`。本轮没有 App 修复、性能提速验收或 App 测试重跑；没有因为分析现有数据而重复播放大文件。

下一步取得可核对的分配类别/调用栈，并用可导出采样栈的 CPU 分析覆盖同源普通包启动和稳态；先确认热点再做共用规则修改。PX-20、CPU 资源风险、MI2、实际 AUD/完整 SUB/连续帧、严格配对、Lenna 竞品、19×4 及原 PX/UX/CB/Main 等未完成项全部保留。
