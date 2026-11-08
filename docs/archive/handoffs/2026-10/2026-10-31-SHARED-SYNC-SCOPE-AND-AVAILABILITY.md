# 共用同步范围与可用状态说明

日期：2026-10-31。NAS 恢复期只做本地与任务隔离模拟器；本批无真机发现、控制、安装、NAS 请求、播放或源目录写入，未改凭据、NAS/VPN 配置。沿既定模型分工，不调用 Astra、不建定时任务。

## 接受的实现

- AppTheme 的 `NastartSyncScope` / `NastartSyncScopeRow` 统一三项内容：设置与事项、账号与授权、媒体资料与进度。手机/Pad 的正式 SyncSettingsView 使用同一分组行；TV 正式页使用同源内容和 `NastartTVSyncOverview`。普通 TV 字号三张等宽卡片，辅助字号纵排；不改变宿主的主题表面。
- TV 保持尚未接通同步的真实状态，说明仅在本机保存；移除面向用户的个人签名、权限配置等开发术语。移动缺少 iCloud 能力时的中英文提示改为版本可用性及本机内容保留说明，不再要求用户重编译。
- 移动原同步开关、Plus 门槛、状态、最近成功时间、错误映射、立即同步及 `.task` 均保持；CloudSyncStore、快照、Keychain、索引、播放器和网络路线均未改。新文案说明的是既有边界，没有新增 TV 同步功能或把媒体索引纳入云同步。
- 新增 Debug `--offline-ui sync-settings`，设置预览中的 iCloud 入口也复用它。保持早期隔离分支；新预览没有 CloudSyncStore、AppState、账号、网络客户端、图片请求或持久化任务。移动预览的不可用状态固定合成，不能代替真实账号/签名状态测试。TV 预览复用正式内容，但不覆盖正式页标题、导航返回或完整宿主流程。

## 源码、构建与包

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交改动全部保留。446 输入中本批修改 7 个既有文件，其余 439 个 hash 一致：AppTheme、MineView、TVNASViews、两种语言资源、OfflineUIScenario、OfflineMediaScene。逐项 hash、前后快照、完整脏树、构建命令/起止时间和原始日志仅留本机私有证据。

移动 Debug 模拟器、普通签名 Debug、Release；TV Debug 模拟器、无签名 Debug、Release，六项 exit 0。中文/英文资源 lint 通过，同步键各 38 个、无重复且集合一致。既有 OfflineUIScenarioTests 四项通过，包括所有合法场景与无效参数的隔离守卫；没有增加镜像 UI 的单元测试。

移动普通 Debug 候选冻结并逐个核验 30 个 Mach-O 签名与哈希，未安装真机，无启动参数或环境注入。TV 正常签名仍是既有 profile 阻塞，本批没有重试或修改签名；保留的旧签名包来自 444 输入/27 Mach-O，与当前源不匹配，不能用其作为最新包测试证据。双端 Release 只编译，不声称真机或 Release 呈现通过。

## 实际展示核对

| 窗口 | 实际观察 | 边界 |
| --- | --- | --- |
| 手机／暗色／标准字号 | 状态说明与三类完整文本可见；暖色图标、主题卡片及分隔清楚 | 固定不可用状态预览；无真实云账号或导航测试 |
| TV／暗色／标准字号 | 状态卡、三张等宽等高说明卡可见，无截断 | 正式共用内容的静态预览；未测试遥控方向/读屏 |
| TV／暗色／辅助字号 | 同一包重新启动大字预览，三卡改纵排，全部文本可见 | 不代表全页动态字体、实际焦点或帧时间验收 |
| Pad／大字号 | 未启动 | 手机收尾后可用空间约 5.56GiB，低于既定 6GiB 启动门槛；不降预算、不创建实例、不盲重试 |

三张 CUA 实图均人工查看，原图与观察存私有证据；不能把未暴露 guest AX 的 TV 窗口树当作读屏证据。正式移动页与 TV 页均有源码接线，但没有以离线截图冒充真实宿主全流程通过。

两台任务实例的安装二进制 hash 与构建清单一致；结束后合成偏好哨兵保留、无意外 App 偏好键、安装 hash 不变；逐台关闭、删除，fresh 列表确认均不存在。无密码诊断 trace。其他已有模拟器 guest 未动，无自有后台任务遗留。移动启动 6GiB、TV 3.8GiB、运行 2GiB 保留线维持。

## 接续与未验

私有接续指针 `current-sync-presentation-private`；共享结果见[结构化记录](../../../testing/results/2026-10/2026-10-31-shared-sync-scope-and-availability.json)。下一步继续不依赖 NAS 的设置/隐私说明与状态细节；空间达到门槛后补 Pad 大字及移动完整反馈，不为补图降低预算。

真实 iCloud 授权/同步、正式页导航、VoiceOver 与遥控焦点未验，TV 同步仍未实现。上批[目录反馈](2026-10-31-FOLDER-EDITOR-FEEDBACK-AND-REMOTE.md)的移动后半段、[密码显隐](2026-10-31-PASSWORD-INPUT-EVENT-DIAGNOSIS.md)未修等开放项保留。JF TV 尚未全迁共用详情 Scope；真实头像/返回闪动、ISO、大文件/弱蜂窝、音轨字幕、SMB/FTP 仍待安全恢复后的新环境验收，不复用旧 NAS 凭据。本批不改播放架构，114 格播放矩阵无新 P，不关闭[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)中的整项需求。
