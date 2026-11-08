# 媒体首页收敛与 Apple TV 主题统一

**历史批说明：内嵌NAS入口/安装包已由[独立卡片批](2026-10-26-INDEPENDENT-STORAGE-CARD-AND-ACCENT.md)替代。后续完整WebDAV新增发现布局循环，两轮修复回退未解决；下文19:25设备结果不是最新包安装结论。**

2026-10-26。接用户连续补充：存储与媒体承担设备文件/影音库汇总，主线为连接 NAS 后浏览播放，以及选文件夹整理资料；协议和服务不应成为重复的日常入口。既有 dirty 全部保留，无提交或发布。需求只归 UX-08/UX-09 总账，30 项 14 进行中/5 待验收/11 待开始、114 播放格保持。

## 最终实际实现

- 移动启动台与 TV 的 NAS 摘要仅保留“存储与媒体”快捷入口，原并列设备文件/影音媒体库入口合并；原四主 Tab 保持。
- 该页仅展示“浏览文件”、已保存授权且有实际原生目的页的媒体库、已选文件夹的本机库、“添加媒体文件夹”。没有保存的媒体授权时不伪造媒体库。已有 Jellyfin 可一步进真实库，不再经过产品/实例/状态页。
- “连接管理”收纳存储连接与服务发现；其他协议收在“添加其他存储”。WebDAV 可连接，SMB 与 FTP/FTPS 明确未开放连接。六种产品（Jellyfin、Emby、Plex、Navidrome、Subsonic、Audio Station）均可在管理层查看；未发现不等于未安装，不把身份线索当可播放。
- Jellyfin 产品仅一行；独立已存连接和 NAS 提示地址继续按真实连接身份保留在产品详情内，不能仅因同名合并授权。不同 WebDAV 账户亦不按主机名误合并。
- 当前 NAS 使用已有 File Station 会话选目录，无需重复密码；根目录禁止直接整机扫描。只整理用户确认的共享/子目录。
- Shared NetworkContentPage/Section/GroupedRows/TVAction/InputStyle 使用宿主真实背景、表面与强调色；TV 改紧凑页头/统一纵向宽行/22 圆角/聚焦边框，command 主题保留左侧标记。连接表单、目录选择、库内容、纠错、媒体服务子页面共用层级。移动保持主题 List 与节表面。
- 已实现添加成功后退出添加页/管理并返回首页的回调；完整新增流程后续被布局循环阻断，尚未验收。纠错与索引仅本机保存，不写 NAS 原目录。

主要源码：`NetworkMedia/LibraryViews.swift`、`MediaServiceViews.swift`、`SourceContext.swift`，移动 `LaunchpadLayoutViews.swift`，TV `TVNASViews.swift`。本批不改 AV/KS 播放链。

## 最新普通包与逐机安装

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` + dirty；375 本地应用输入逐字节冻结（非完整第三方依赖闭包），Debug/arm64，空参数与环境。双平台构建成功，逐个核验移动 30/TV 27 Mach-O 签名、profile 及 TV 嵌入路线；没有把相同版本号当安装证据。

| 设备 | 现场型号/系统/连接 | 最新包安装证据（北京时间） | 本批回归归属 |
| --- | --- | --- | --- |
| iPhone 13 | iPhone14,5 /16.3.1 USB；CoreDevice unavailable，lockdown 可用 | 19:25:14 InstallComplete，保留数据 | 精简首页、文件入口、一步进入真实 Jellyfin、管理内六服务/协议状态、WebDAV 表单及 NAS 无密码选目录 |
| iPad | iPad15,7 /26.6，安装时 USB connected | 19:25:02 Complete，保留数据 | 安装前后 19 个非诊断偏好一致；随后 19:43 调试时 CoreDevice unavailable/native RSD no device，最新包界面回归未完成。旧候选结果不作此包结果 |
| 客厅 Apple TV | AppleTV14,1 /tvOS18.2 LAN，非 tvOS27 模拟器 | 19:25:03 Complete，保留数据 | 遥控器真实方向/Select/Menu、文件入口/已有媒体库/管理/协议/表单/选根与子目录返回；三主题有限实图 |
| iPhone 18 | iPhone19,7 /27.0，已配对家庭 Wi-Fi | 19:25:28 Complete + 安装后 lookup，保留数据 | 原生正常首页实图/Wi-Fi 图标，安装及启动后 27 非诊断偏好全同；未执行本批完整子页回归 |

移动冻结时间 19:20:13、主 SHA-256 `eddbd1d552c826b16d23e13f2a2c63b918087eadb88b7484c751376464c949d8`，Debug dylib `0970b13d01ab5a4219067198e68e652dbedd1c228d9a299a5ee6a8bbbeb9a83c`。
TV 冻结时间 19:20:07、主 SHA-256 `57f2288540d1362ef441515ebfc12a5f3d5c415784cada148941d58a3862cca1`，Debug dylib `b2e4aa2c2e9302fef11e5e54831d1800ea59c007738bf045c3060c6ef30e4569`。
移动包 `Nastart-SourceHub-Debug.app`，TV 包 `NastartTV-SourceHub-Debug.app`，均在私有证据根目录；IPA `Nastart-Latest-Normal-Debug.ipa` SHA `c808f3afca82e7299fcabbe1ab52ca816d966e1a543e3cac28bab29bc20ca0f6`。

iPhone18 用现场 Bonjour/既有配对无线识别，无重配、无 WDA 安装要求、未改 NAS/VPN/保存地址。CoreDevice unavailable 与已配对无线可达分别记录。早期候选无线安装一次超时、重试 Complete 以及各候选包另存，不能替代上述最终包。DSM 保存域名/端口保持并不证明实际会话固定域名；本批未重测实际端点与视频路线，该旧项继续开放。

## 验证、保留失败与边界

19:42 最终包对应共享模块 67 项测试通过（0 失败）。先前一次自有 xctest 卡住以及等待锁的测试进程已停止，独立 90 秒上限重跑通过，未把挂起当成功。UI 不增加镜像实现的测试。

TV 遥控器精简流程通过，包括 NAS 根选择禁用、进入子目录后可选、一次 Menu 回根、再 Menu 回首页；clean/light、command/dark、glass/system 三窗实际图及上下焦点通过，已通过 UI 恢复原 glass/system，原 13 非诊断偏好一致。不是全部深浅色/大字组合或滚动流畅度验收。

iPhone13 首次测试误将 SwiftUI 容器与真实按钮的同一 identifier 当两个按钮而中断；现场均可见，但容器 accessible=false，实际 Button 仅一个。测试改按真实可访问 Button 后全程通过，未因此改产品代码。候选移动列表延迟生成/转场时序误断言、TV 屏保前台导致旧候选脚本失败均保留。最终包结果单列，不以候选早期通过替代。

本机只读目录的完整新增在连接阶段布局循环，新增/资料/纠错UI未通过；两轮修复均回退与夹具清理详独立卡片批。

私有指针 `/tmp/nastart-tv-storage-ui-evidence`，包含最新 source-inputs、源码差异、两个 package manifest、全部签名/哈希、逐机 fresh identity/安装/偏好/真实图和自动化过程。原始 UDID、端点、偏好/凭据不入仓库。自有 TV Runner 已停止且三设置 GET 确认恢复；移动仅清理自有 HTTP 会话，不停未知所有者 Runner。

## 仍未完成

协议统一是交互目标，不能写成全部传输已交付：FTP/FTPS 仍私有传输/NFO 原型，生产来源/字面路径/账户凭据/递归适配未接；SMB 严格选根反例仍 FAIL，不能放进 App。独立库仍文件名/已有 NFO 与本机纠错，在线 provider/新海报/独立库文件直接播放尚未接；“浏览文件”复用现有宿主文件预览播放目的页，本批未实际播放视频。Emby/Plex/音乐服务只有识别/状态，新增原生授权/库/播放未交付。iPad 重连后先重新现场核包再回归；TV 扫描取消/大字/大库与旧播放任务继续开放。
