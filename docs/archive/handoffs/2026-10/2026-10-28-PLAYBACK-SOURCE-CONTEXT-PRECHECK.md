# 播放来源接线与旧换轨证据复核

日期：2026-10-28。6.1 Sol继续；基础选择不变，未进入Astra6核心优化。关联PX-01/PX-03/PX-20/PX-21与UX-09；状态和114格不新增P。保留原脏树，无NAS配置/源文件写，无18发现/安装/控制。本批仅13；Pad/TV未安装/回归。旧18窗与新包分开。

## 有限变更卡

问题：Wi-Fi中打开“存储与媒体→Jellyfin”后切到4G，旧窗仍选择内网且不出帧；普通重新进入后用公网出图。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`＋继承dirty，419输入中本批仅`LaunchpadLayoutViews.swift`变化。

旧日志已在准备前报告cellular，不能简单归因NWPath初始回调太晚。warm窗口恢复候选为3个privateIP（root/jellyfin/emby），cold为3个publicDomain；两组自身根路径有保存登录，不能跨域复制token，也不能用后来的公网登录推断旧store当时已有它。warm没有任何公网候选可供既有安全回退选择。

源码确认：`LaunchpadMediaShortcuts.networkServicesContext`先按现有配置建立同一服务的完整`MediaServiceCandidate.endpoints`，native destination却只传`fallbackEndpoints: [endpoint]`；`MediaLibraryView`另一路使用完整配置。`JellyfinLibraryStore.endpointCandidates`为初始化快照，之后只扩展同origin路径，不会凭空增加域名。这个裁剪缺陷与旧证据一致；尚不能证明它是该设备唯一原因，原服务是否当时已有另一origin需在新包实际候选取证。

最小修正：[LaunchpadLayoutViews.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadLayoutViews.swift)传`candidate.endpoints.map(\.url)`。只含当前已验证service ID的候选，保留当前已登录endpoint优先；仍由既有store逐端点加载各自凭据/同服务器同账号验证。未改KS/AV、网络预算、传输窗口、身份或取消策略，不发明地址，不改DSM保存域名。此为6.1可完成的来源接线修正，不需要Astra6。

L0：普通iOS Debug编译成功；13项`MediaServiceDiscoveryTests`、0失败，仅本机fixture，验证精确端点登录、冲突隔离、旧轮结果及无凭据公共探测等既有边界，不冒充原生回归。初次工具查找不存在的Xcode目录下xcrun失败，改用系统xcrun后执行通过；无产品失败。TV源码不受本次单行接线改变，未重复构建TV。

包：21:32:12.428000+08:00普通Debug，args[] env{}，419输入冻结；main `48b3b8fc56abddf7553d9abbb4d10a4b6f1ffb28c5f4263f48a7333d735baa19`、debug `980e0f358bcdda7a5146e580e70b84323aa1af969eb4c1047f61369309a69df3`，30 Mach-O逐签/deepstrict过。包/路径/全哈希在仓库外`current-source-route-context-private`；root移动manifest/source输入已指新包，旧连接批/旧18窗冻结件仍保留，不混用。

13现场fresh确认iPhone14,5/iOS16.3.1/USB与精确UDID、签名profile后保留数据覆盖，安装成功/原非诊断偏好同。普通启动台实图成立；首次图仍在恢复NAS，不能当DSM/JF已就绪。21:44有界进入存储与媒体仍缺Jellyfin入口，未发出播放请求、未切蜂窝。L1原失败（保持同库页面Wi-Fi→4G后播放大文件）**未验**；不得声称蜂窝地址问题已修好或速度提升。安装时间和最新清理结果见安全JSON。

## 换轨旧结果的归属纠正

外部helper在目标选择后取+1/+5秒图、读偏好并恢复原项，未等待新会话commit；音轨菜单选中不等于实际音轨已切换。`replaceSource`在pending新请求出现时可将准备中的候选作废，旧窗不能把这些candidateInvalidated都视为引擎自发失败。

| 旧窗 | 实际目标字幕新会话 | 请求至commit | 可以说明 |
| --- | --- | --- | --- |
| JF 4G cold/full | Off；后有audio_session_ready请求subtitle none | 12.559秒 | 目标替换确实提交，非“完全无法关闭字幕” |
| 文件4G续播 | 源字幕8；后有audio_session_ready请求subtitle 8 | 11.819秒 | 目标替换确实提交，非“完全无法开启字幕” |

上述是用户请求→内部替换提交，不是实际字幕/声音呈现延迟。两次AssertionError实际为菜单selected option count=0，可能处于替换重建窗口；缺失败瞬间完整菜单/同代次实帧，不能断言唯一UI原因。原始失败保留，不改PASS。目标音轨2未有完整提交/听音证据，不用菜单读回给它通过。

更正收尾：旧helper声称restored仅为菜单读回；离线after-close/后续偏好证明两条源书签字幕状态仍留在测试目标。已fresh确认13、停止自有App，完整备份后只恢复这两个确切书签的audioTrackID/subtitleTrackID/subtitlesDisabled，保留当前进度、updatedAt及其他所有字段/偏好；并非回滚整份历史偏好。写前对当前值守卫，未知用户变化则拒写；读回完整比较通过。新包覆盖后原偏好同，普通启动后的fresh偏好再核两项保持原值。首次DVT握手ConnectionTerminated未写数据，改用已授权WDA确认App停止后才执行；原失败保留。未清凭据/登录、未远端写。

后续最小取证：单次选择后不插入恢复/第二次选择；分别记录用户请求、候选/代次、commit、目标session轨道以及实际声音/字幕。菜单因替换消失时记录转场，不立即断言功能失败。确认/有界超时后，恢复原选择须同样等实际会话及持久偏好匹配，不能只看勾选。先单轨复现，再做快速连续选择的独立取消用例；不将二者混作普通切换耗时。

## WebDAV当前可交付的最小优化输入

已证明：`NetworkLibraryPlaybackView.destination`只交loopback URL、title、byte count和close；宿主构造默认directURL请求。`networkOriginURL`取externalHandoffResource或url，因此在这里仍是loopback。稳定身份/源轨道/断点/完整释放并未交付；这解释来源信息缺口，**不等于已证明它造成全部缓冲**。

重要约束：不能把真实WebDAV origin塞进`externalHandoffResource`充当元数据；`GreenfieldPlaybackBridge.greenfieldPrimaryResource()`会在directURL/非HLS/loopback时优先选择该资源，可能直接绕过认证代理。下一步需要独立的来源origin/身份描述，而renderer URL仍指向可撤销loopback，不能用一个URL兼任两种职责。

已证明取流实现为每次至多1MiB、独立ephemeral URLSession、完成后invalidate、串行read完再send；旧真机有1MB/s缓冲实图。未采每窗认证/连接/首字节/正文/转发耗时，不能宣称建连是唯一根因或先调大窗口。下一6.1工作为本机可控Range fixture固定测量和来源交付契约；核心改造才按明确反例提示Astra6。

最小合同验收：renderer URL保持loopback；network classification用独立原origin；同文件重新开桥稳定身份/断点不变、不同文件版本和账号scope隔离；旧generation取消不交付/不泄漏资源。既有严格Range/版本/重定向/账号与只读约束保持。该合同是计划，尚未实现，不算Release交付。

## 接续与边界

普通播放核心保持Greenfield/KS优先及必要AV/HLS。本轮是来源接线和观测归属修正，不改核心状态机或引擎切换。维持6.1，待JF入口实际就绪后补一窗原切网反例，避免反复恢复/探测；在此之前可继续离线fixture和接口准备，不需用户切Astra6。NAS/VPN/权限/凭据不动。停止自有媒体、原Wi-Fi实连/图标与工具会话收尾核完后才结束；不声称后台继续。

[结构化结果](../../../testing/results/2026-10/2026-10-28-PLAYBACK-SOURCE-CONTEXT-PRECHECK.json)；[上一有限优选](2026-10-28-PLAYBACK-ROUTE-SELECTION.md)。原始设备身份、偏好、精确地址、错误、截图及驱动仅私有证据区。
