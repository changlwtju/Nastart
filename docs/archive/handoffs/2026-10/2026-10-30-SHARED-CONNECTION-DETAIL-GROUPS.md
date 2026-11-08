# 连接详情：设置与媒体文件夹分组

更新：2026-10-30T12:50:27+08:00。接续[已有连接状态批](2026-10-30-EXISTING-CONNECTION-PREPARATION.md)。NAS恢复期仅代码/任务自建隔离模拟器，仍6.1，0真机发现/控制/安装、0NAS/旧凭据/播放/源写；无后台任务，不改NAS/VPN。

## 实现

NetworkConnectionDetails改接正式三端共用NetworkConnectionDetailsPage。连接设置独立一组，“编辑连接”保留原名称/identifier，并标WebDAV与可编辑字段；关联文件夹与“添加媒体文件夹”放同一组，已有目录仍共用NetworkMediaFolderLabel的名称/来源/路径。空列表有建立媒体库说明及可用添加入口；有目录时说明可修改路径且不移动/修改远端文件，不承诺尚未提供的改名。普通动作显式语义主次文字与暖色图标，TV沿NetworkGroupedRows和既有焦点样式。

同次body只过滤一次关联folders，ForEach和空态共用该快照；不声称性能已测。编辑/新增/文件夹sheet、onSaved/updated/dismiss回调逐字核同，其他库控制器、上批准备/取消守卫和FolderPicker字节同；凭据/源/存储/媒体模型/播放输入保持。3既有源（LibraryViews/OfflineUIScenario/OfflineMediaScene）/435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保留。无播放路线变化，不改路线文档。

Debug connection-detail/empty/long直接挂正式Page和文件夹行，仅合成名称/路径与空回调，无model/store/vault/client/Task或实际导航。完整样本有两个同名目录但路径不同；长样本覆盖中英混合目录及100%字符。隔离展示不证明正式模型关联或真实账号可达。

## 有限验证

4既有OfflineUIScenarioTests正常重建通过，接受新场景并核参数隔离；无新镜像UI测试，不重复未改的事务套件。双模拟器Debug、双普通签名Debug、双无签名Release构建过；435输入hash同，30/27 Mach-O核签/TV嵌入库过。普通Debug候选无测试参数/环境，root清单更新，未装真机。

最终三端各3静态窗，共9窗：完整列表glassDeck深色、空列表cleanGrid浅色、长名称/路径commandCenter深色，手机/Pad长样本用辅助字号。8窗自动文字/背景稳定通过；Pad长例OCR误认合成标识末字，原图明确为“详情”，其余文字/背景成立，保留有界超时并人工确认此1窗，不称9窗全自动PASS。全部图hash和原图复核，分组、同名不同路径、空态/添加和可见长字段/语义色成立。手机大字底部说明未完整在首屏显示，不称完整阅读/滚动已验；静态焦点描边不算遥控交互。

手机/Pad初受4.8GiB预算阻塞。对24个任务冻结的离线候选包做写时复制整理，42个框架文件复用重复数据块，每包签名差异保留原字节；原路径/全部二进制hash/整包签名前后核同，各文件仍独立，实际回收约1.44GiB（3.68→5.12GiB）。没有删除安装包/日志/截图或用户数据。系统Python属性API预检曾在0文件改动时退出，记录保留；不同长度框架额外预检无适合项、0改动，停止未扩展。模拟器删除后空间回收有延迟，预算不足时有界等候实际回收，不降低4.8/3.8GiB起步和2GiB运行保留线。

首TV3及手机前2窗保留但排除最终；首手机大字窗发现透明Debug标识与说明重叠，标识OCR超时。只给OfflineConnectionDetailsScene底部标识加全宽背景，正式Page不变；重建双模拟器并全9重采，参数输入未变不重复4测试。Pad已过2窗后曾触及2GiB运行预留线，finally退出清理，记录保留；不降低预算，等回收后新建实例只补长路径，原2窗未重跑。初候选包路径保留，最终候选另名冻结。初2＋最终4（含Pad补余窗）共6实例finally清理、fresh列表无，所有合成偏好保持且无额外应用键；测试scratch本批正常重建，未skip-build。收尾约4.8GiB。实际编辑/新增/路径修改、返回/滚动/焦点/读屏、真实目录/持久化/图片/播放仍未验，114格无新P。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T12:47:06.722431+08:00 | `87f11336efe53cbbffcc9a0a46269627ac564a933551b8dbce4c1a5b73b1b2b1` | `9c20129dc2723606c73075be362c8ac8404e371e569ef13146b74d95af783a6b` | 30 |
| Apple TV | 2026-10-30T12:46:39.133845+08:00 | `586f265f9667cfdc5701b036080c7dfd179c3ea0ed142429193d3ec36534e87f` | `15c6164f74a25acef3751c6027d525bf9d4dc3f58fc6796c2f186ce3025ab374` | 27 |

原包/图/命令/偏好仅仓库外current-connection-detail-polish-private；[安全结果](../../../testing/results/2026-10/2026-10-30-connection-detail-groups.json)。[播放矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)核过、路线/引擎/缓存未动；真实联调等NAS安全恢复并确认新环境后fresh设备/包，Astra仅后续核心优化。

下一步先核空间，补已有连接准备页的手机/Pad大字实图和离线导航/返回；预算未满足不反复创建。可继续审查媒体库扫描/取消/失败的状态层级与已有展示组件，保留源事务，不构造真实NAS或model作预览。
