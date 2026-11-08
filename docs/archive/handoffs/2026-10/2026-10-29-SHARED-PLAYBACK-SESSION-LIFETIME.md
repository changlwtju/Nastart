# 三端多入口共用会话资源生命周期

更新：2026-10-29T07:42+08:00，6.1 Sol。[结构化结果](../../../testing/results/2026-10/2026-10-29-SHARED-PLAYBACK-SESSION-LIFETIME.json)。承接[统一接入](2026-10-28-UNIFIED-PLAYBACK-INTEGRATION.md)与[电视未连接页面](2026-10-29-TV-DISCONNECTED-PAGES-AND-WIRELESS-UPDATE.md)。

## 本轮优先级与边界

用户报告黑群晖 Container Manager 正在修复，暂停依赖 NAS 的真机调试，优先整合三端和 Jellyfin／设备文件／网络存储的播放链路。本批没有设备发现、安装、控制、NAS 登录/连通探针或蜂窝窗口；不沿用旧设备身份作新回归。之前 iPhone18 无线更新和电视 UI 验收仍只是前批包证据，不变成本批候选真机验收。

继续采用已选 Greenfield 核心、KS原流优先＋必要AV/HLS，未改缓存、探测、码率、超时、解码或 seek 性能参数；尚未切 Astra6。核心性能优化仍在接入/验证完成后提示用户实际切换。

## 实际接线与移除

新增同一个 `NetworkMedia.PlaybackSessionLifetime<Resource>`，用于初始重复准入、当前票据/迟到回调隔离、替换期间保留旧资源、同步所有权交接、退出失效与串行异步释放。拒绝的迟到结果在不继承调用者取消的 Task 中释放并等待完成；来源仍负责其内部“尚未返回结果”的部分分配。end供同一模型换下一项，close对已消失展示终止；重复结束不重复释放已交付资源。清理等待仅涵盖已交付资源，不能宣称非协作来源尚未返回时资源已全部释放。

| 实际来源 | 普通构建宿主 | 共用执行 |
|---|---|---|
| iPhone/iPad Jellyfin | GreenfieldPlaybackBridge → GreenfieldVideoPlayerView/Model | PlaybackSessionLifetime<PreparedSession> |
| iPhone/iPad 设备文件/直连视频 | 同一 Greenfield bridge/host | 同上 |
| iPhone/iPad WebDAV | NetworkPlaybackOwner交付能力 → 同一 Greenfield host | 同上；来源能力仍由原owner拥有 |
| TV Jellyfin | TVPlaybackSourceAdapter.jellyfin → TVUnifiedPlaybackView/Session | 同一个 PlaybackSessionLifetime<Resource> |
| TV 设备文件 | 同 adapter.file/同一 TV host | 同上 |
| TV 网络库 | 同 adapter.network/同一 TV host | 同上 |

移动模型初始异步 prepare 不再只靠取消 Task 决定是否挂载；停止后/新会话开始后的旧结果不能覆盖当前播放。PreparedSession 保存实际安装后的 finishingPlan，使同会话引擎 fallback 后结束对应当前路线。GreenfieldVideoPlayerView.replaceSource 原有整段换源执行移出 DEBUG，普通构建不再空执行；实验入口与细节诊断仍保留 DEBUG。没有重新编写或修改移动端已有预热/保帧算法。

TV 的初始加载、替换结果交付和退出也接同一个生命周期类，移除独立 generation/资源赋值与旧准备门禁。挂载前核票据，AV就绪与初始seek完成回调核当前票据；退出先同步停原生renderer，再按旧报告屏障→Stopped→共享coordinator结束→来源release的顺序清理。原生 AV/KS 控件继续只是电视适配。

移除全工程无引用的旧 `TVPlaybackSession`（Jellyfin会话）、`TVNASPlaybackSession`（文件会话）及仅被其引用的诊断类，保留 TVPlayerControlsModel/TVKSPlaybackControls 和上一批未连接页面。代码中不再保留这两条可误接的旧会话实现。

仍有明确边界：移动与TV原生renderer/控制层并非同一实现，移动预热替换与TV兼容/换轨执行也仍有各自适配。本批不能宣称完整生命周期/所有性能策略已百分之百同源；新增 FTP/SMB 必须交付来源能力并接当前宿主，不另建引擎链。

## 验证与失败保留

- 共用模块18项（含新增6项生命周期及既有7准备/5来源）：重复启动、最新候选覆盖、失败保旧资源、退出后迟到结果、独立取消清理、报告屏障顺序、重入与终止均过。
- TV完整单元54项通过；新增三种sourceKind交给同一会话/KS计划及退出只释放一次、非协作迟到源退出后不挂载。该夹具不挂载实际媒体surface、不访问NAS。首23项只是其子集，不重复相加。
- 移动定向最终15项通过，含三种sourceKind同模型停止/重开、fallback结束实际当前计划、已有换轨/暂停/续播规则，以及既有本地生成视频的renderer替换测试。小型本地夹具用于功能回归，不作播放链路优选或大文件提速证据。
- 移动首轮15项有1失败：新测试错误要求重建fallback计划复用原route UUID。实际规划重建路线身份；修正为核实际地址和结束计划与已安装计划一致，最终15项全部复验通过。原失败log/xcresult保留，不改性能参数掩盖失败。
- 旧类移除脚本首遇诊断枚举边界匹配断言，保留原稿和现场，按当前声明边界定点续做；没有恢复/覆盖其他脏树。最终编译及全TV测试覆盖实际删除后的源码。

双端普通签名Debug和无签名Release均编译通过。Release仅编译，未做签名安装或真机呈现验收。源码冻结426输入，与本轮清单逐项SHA一致；继承未提交修改保留，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`。

| 最新候选 | 构建时间 | main SHA-256 | debug dylib SHA-256 |
|---|---|---|---|
| 移动 Debug | 2026-10-29T07:34:43.671021+08:00 | `f3916629070956af05b60b48fc3c0129e5805c0d8e2a6937e6a58885ab230ee4` | `c5ea7b351288fbdb000cbd57b1b970629beb62baf345edb12e09422ecdb995ae` |
| TV Debug | 2026-10-29T07:34:16.195521+08:00 | `a244fd32f3dddf7b0291e7ed15e62ac51b3e067b5b3079baab30e5006ee08f5d` | `7be895637b205f898c90cb1d1993eb6d39096f5537eda433e44da53d4362f4b5` |

移动30/TV27个Mach-O逐项及deep/strict签名通过，TV embedded libraries核对通过。包、完整源码脏树/哈希、原始构建/测试日志都在仓库外私有证据，定位用 `current-shared-session-lifetime-private`；root package/source-input manifests已指这批**未安装**候选。默认启动参数[]/环境{}，本批没有实际启动设备。

## 当前接续

Container Manager修复期间保持真机/NAS支线暂停，不重试登录或探测服务，不复用旧OTP。旧TV内网DSM两步后通用失败根因仍未明；iPhone18原域名＋端口规则保持。下一对剩余原生控制与换源适配继续作来源无关收敛；候选上真机前重新核设备、源码与签名，并保留数据覆盖。NAS恢复后的首轮先验当前共同基础，再按既定大文件标准测试Wi-Fi/蜂窝的首帧、同点续播、正反seek、换轨字幕响应；先停媒体并恢复原Wi-Fi再作分析。

本批0真机播放、0蜂窝、0NAS媒体写，114格无新P，不关闭旧大文件约1MB/s缓冲、Pad控制/退出、ISO、物理换轨、Release或弱蜂窝缺口。完整需求仍仅在[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)维护。
