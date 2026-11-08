# 电视连接状态与地址展示

日期：2026-11-01。承接[凭据与导出子页](../2026-10/2026-10-31-CREDENTIAL-STATUS-AND-EXPORT-SELECTION-ROWS.md)，继续 NAS 恢复期的离线细节整理。本批没有发现、控制、安装真机，没有请求 NAS、读取真实凭据、播放或写入源目录；既定模型分工及 NAS/VPN/签名配置保持。

## 接受的实现

- Apple TV 连接管理的 NAS 卡片原本根据保存的账号是否非空显示“已登录”，现改为“已保存登录配置”；Jellyfin 沿“已保存授权”，没有配置时仍是“未连接”。保存状态不推断服务在线或认证仍有效。
- 两卡共用纯展示快照 `TVSavedConnectionSummary` 和既有 `TVConnectionPanel`。地址复用已有 `tvDisplayAddress`，去掉 URL 中的用户、密码、查询及片段，保留协议、主机、端口和路径。只改变显示字符串，原 URL、账号、实际会话和请求路线保持。
- 卡片原尺寸、主题表面、暖色图标、文字层级、地址两行中间截断和操作按钮保持。登录 sheet、退出、断开确认及回调字节核对未变；从 `TVNASConnectionBanner` 至文件末尾的网络/播放相关实现字节未变。地址格式化函数实现本身也未改。
- 外观页的 Docker 说明改为默认展示容器、启动台不展示套件，与当前实际过滤和默认可见规则一致；服务列表、分类和显隐偏好逻辑未改。
- Debug 新增 `--offline-ui account-connections`，TV 最早根分支直接挂上述正式卡片和快照；不创建 TVAppState、账户、存储、钥匙串或客户端。合成 `.invalid` 地址含虚构敏感部分，用于核对显示。两个预览操作只切内存状态，反馈明确未连接或移除服务器；它们不是正式登录/断开操作。移动端收到此参数时保持隔离，显示仅适用于电视，不进入正常流程。

## 来源与验证

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，446 输入，4 个既有文件改动，其余 442 个 hash 一致：TVNASViews、NastartTVApp、OfflineUIScenario、OfflineMediaScene。完整脏树、前后源码、命令/时间、包路径、二进制 hash、实例标识和原图只在本机私有证据区；指针 `current-tv-connection-presentation-private`。原有其他修改保留。

最终六配置编译成功：双端模拟器 Debug、移动签名 Debug、移动 Release、TV 无签名 Debug/Release。场景参数有新增，重跑已有 4 项 `OfflineUIScenarioTests` 全过，没有新增镜像测试。抽取实际纯快照与既有格式化函数，在 3 个合成 URL 上核对敏感部分移除、IPv6/Unicode 路径及协议/主机/端口/路径保留、原 URL 不变，以及两种已保存/空状态。首次检查脚本因顶层常量引用 private 类型而编译失败，原脚本/日志保留；只修脚本可见性后检查通过，生产源码未因此修改。此检查不是实际账户/网络或全应用安全审计。

预算检查约 5.23GiB，达到 TV 3.8GiB、低于移动 6GiB 门槛；只创建一个任务专属 tvOS 27 模拟器，不降低门槛、不清用户缓存或旧包。安装后核主二进制和 Debug dylib hash，未注入测试环境变量；显式离线参数仅归本场景。glassDeck/深色/标准字号静态窗口已实看：NAS 保存状态及脱敏地址、Jellyfin 空状态、双列等宽卡片和暖色图标可见。

Return 和 Space 两次按键后画面均未变化；打开模拟器遥控器菜单亦未形成可用的客体控件证据，停止继续盲试。两种切换交互未通过，不把按钮焦点边框或操作请求当作成功。macOS 可访问性树未暴露客体控件，未做 VoiceOver、真实遥控器、完整正式页面、其他主题/字号及帧时间验收。

外层清理已结束：任务进程终止，自建模拟器 shutdown/delete 均成功，fresh 列表确认不存在；合成偏好哨兵保持，无额外 App 偏好键，安装 hash 未变。原图和失败保留，无后台采集或模拟器任务。详细数字见[结构化结果](../../../testing/results/2026-11/2026-11-01-tv-connection-status-and-address-presentation.json)。

移动普通 Debug 候选冻结并逐一核验 30 个 Mach-O 签名，未安装真机。TV 正常签名沿旧 profile 阻塞，本批未重试；保留的 444 输入/27 Mach-O 旧签名包不匹配当前 446 输入，不能当最新包。无签名编译和隔离模拟器不等于正常签名或真机验收。

## 接续

继续无 NAS 的三端设置/连接反馈，优先补此前开放的交互，避免仅增加静态截图。预算满足后核[凭据/导出子页](../2026-10/2026-10-31-CREDENTIAL-STATUS-AND-EXPORT-SELECTION-ROWS.md)切换、[清理确认](../2026-10/2026-10-31-PRIVACY-CLEANUP-SCOPE-AND-EXPORT-COPY.md)取消、Pad 同步大字及移动目录完整反馈；本场景切换亦保持未验。不得重用旧安装身份充当最新包。

[密码显隐](../2026-10/2026-10-31-PASSWORD-INPUT-EVENT-DIAGNOSIS.md)、严格匿名导出、真实头像/海报闪动、JF TV Scope 及真实目录事务等既有开放项保留。播放路线、引擎、缓存和架构文档无改，矩阵 114 格无新 P，不关闭[唯一需求总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。NAS 安全恢复后才重新确认设备、最新包及新环境凭据，再做真实服务和大文件回归。
