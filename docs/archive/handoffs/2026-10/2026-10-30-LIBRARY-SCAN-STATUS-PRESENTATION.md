# 存储与媒体首页：整理进度与操作提示

更新：2026-10-30T15:17:44+08:00。接续[连接详情批](2026-10-30-SHARED-CONNECTION-DETAIL-GROUPS.md)。NAS恢复期只代码/任务自建隔离模拟器，仍6.1；0真机发现/控制/安装、0NAS/旧凭据/播放/源写，无后台任务，不改NAS/VPN。

## 实现

正式NetworkMediaLibraryView接三端共用NetworkLibraryStatusSections，状态移到首页内容前部，仍按scanID保持身份。当前扫描显示“正在整理”、已发现的视频文件数及原取消扫描动作；连接/路径编辑占用scanning但不拥有scanTask时，显示“正在更新资料”和编辑页取消说明，不再在首页提供无效的扫描取消入口。只加canCancelScan只读getter（scanTask != nil），全部model方法逐字保持，未加取消状态或改变Task/事务；按钮仍调用原model.cancel，没有声称取消已完成或响应速度提升。

错误保留原model.error文本，使用“操作提示”分组、暖色符号和语义主色，不把刷新/删除/扫描等所有错误统一误称扫描失败，也不在未知来源时添加泛化重试。原有扫描完整结束/取消失败保旧说明保持，不扩展成新的持久化保证。进度/媒体库行的数量明确为视频文件，不冒充去重后的作品数，不估算百分比或剩余时间。

savedMedia同次body只取一次，条件/ForEach共用，原saved-login筛选与nativeDestination映射逐字同，不新增服务登录，不声称性能已测。原导航/sheet/后台取消/credits上下文生命周期及其他控制器、源/存储/凭据/播放输入保持。3既有源（LibraryViews/OfflineUIScenario/OfflineMediaScene）、435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；继承未提交修改保留，无播放路线变化。

Debug library-scanning/updating/notice只挂正式状态Sections，分别使用149/0及合成超时文本，取消回调为空；无model/store/vault/client/Task。只预览状态区，不是含真实文件/媒体库行的完整首页。新增预览底部合成标识有独立背景，沿上批已确认方式避免文字叠印。

## 有限验证

4既有OfflineUIScenarioTests过（新增三场景及显式错误参数隔离）；没有新镜像UI测试，不重复未改的存储事务套件。双模拟器Debug、双普通签名Debug、双无签名Release构建过，435输入hash同、30/27 Mach-O核签与TV嵌入库过；内存/磁盘偏紧，原生两平台串行构建。普通Debug候选无测试参数/环境，root清单更新，未装真机。

计划手机/Pad各5＋TV3共13窗，实际手机5＋TV3＝8静态窗通过：手机和电视各覆盖整理、编辑更新及错误3窗，另手机补已有连接preparing标准字号/error辅助字号，复用上批正式StatusPage；后者大字动作纵排、原图可见，但不执行真实重试/返回。TV三主题深浅，手机新错误/已有连接错误含辅助字号。文字/合成标识、更新与错误无“取消扫描”、背景稳定、最终图hash及全部8图人工核过；只验可见组件，不证明真实Task所有权判定、实时计数/取消完成、保旧事务、长列表首屏位置、导航返回/焦点/滚动/读屏或性能。

Pad低于4.8GiB启动预算，有界等90秒后仍不足，未建实例、5窗全部保留待验；TV3.8GiB起步/运行时2GiB线不降。两个自建实例均finally清理、fresh列表和对应目录已无，合成偏好保持且无额外应用键。只读系统观察交换区总4GiB、已用约2753MiB；不推断具体进程原因，不改系统交换区或其他用户应用。对上轮最新两个冻结包的4个重复框架做无损写时复制，前后24个所选离线包全部hash/整包签名仍同，回收约0.13GiB；不删包、原日志/截图或用户数据。额外只读大小核查无后续改动。收尾约4.5GiB，不为补图擅自清用户数据。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T15:07:55.968207+08:00 | `4edd0d66474797915c60f0aa3236501b3fb68e40839b3047f405bd077bfb010f` | `4c341ffb6df3a19c572ec02041e53f323ca137f2e9bd43a1bd6d3e7d8a046450` | 30 |
| Apple TV | 2026-10-30T15:09:46.285443+08:00 | `c66985ec8ffe9415910e6742de97e9e5a4a5a57e1319a8e3667743c16e10d848` | `476849408ab70bfddc22dbc5be17bcad90295f8e874905a463fee10ccc2e67f5` | 27 |

原包/图/命令/偏好仅仓库外current-library-status-polish-private；[安全结果](../../../testing/results/2026-10/2026-10-30-library-scan-status.json)。[播放矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)已核，114格无新P，播放路线/引擎/缓存不改。真实NAS目录/取消与大文件/弱蜂窝/头像/返回闪动继续等安全恢复、新环境确认后fresh设备/包；Astra仅后续核心优化提示。

## 接续发现

只读审查发现LibraryPosterWall.header仍用自己的ProgressView/红字（约236/237行），scanAction在scanning==library.id时仍无条件给取消（约266行）。本批未改该文件，不能称海报墙已接新状态；下一应拆出适合Section/List与VStack共同使用的状态内容并真实接两个宿主，菜单也核同一取消能力，保留既有刷新/改目录/焦点回调。现有TVLaunchTests是tv-exit-probe/player/navigation，不证明当前离线状态页回调或真实目录返回。

先核磁盘，空间达标再补Pad五窗（已有连接NAS不可用变体和实际返回也未验）；受阻不反复创建，继续独立代码整合，预览不构造真实model/store/client。
