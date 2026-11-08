# 当前接续：共享代理第一步与 Apple TV 连接

2026-11-08 晚间接续：[《指环王：护戒使者》样本现场](../archive/handoffs/2026-11/CODEX-2026-11-08-LORD-OF-THE-RINGS-PLAYBACK.md)。产品快照 `main/d3dbc9c4` 已推送；签名 Debug `3ac44312…` 已在 13 保留数据覆盖并启动，iPad A16 已重新识别、本轮未安装。13 Wi-Fi 设备文件原流实画成立，50% 定位首次恢复后再次缓冲，十分钟原流观察记录 9 次缓冲。Jellyfin 库返回 401；源 Dolby Vision Profile 7，实际显示输出、声音、iPad 和 NAS 负载对照待验。此前 97b3/BB4D 与断连描述为历史结果。

2026-11-08 用户将《指环王》样本调试交给 Codex。完整 NAS 路径保存在本机私有交接原件，公开的[新样本一节](../archive/handoffs/2026-11/2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md#新样本11-08-1720用户经-radarr-下载)记录了样本边界和待测项。先核 NAS 可用性、样本元数据和目标设备最新包，再串行测起播、跳转、长时、HDR、TrueHD 与 NAS 负载。Safari 的黑屏和约 60% CPU 为用户提供的前序观察，Codex 尚未独立复现。

2026-11-08 Apple TV 已升级至 tvOS 27.2（24K122）。16:18 截图的两次 DeviceKit 5000/-1 均发生在验证码认证前，广播的手动配对 TCP 55747 在 IPv4/IPv6 拒连，16:21 复核仍拒连且同主机 AirPlay 7000 可连。下次重新进入电视配对页后先核对新广播和端口。此前 13:08/13:09 两次配对成功后报开发隧道 1005，13:11 条目转为不可用。独立 Mac 对照暂缓。[升级后日志](../archive/handoffs/2026-11/CODEX-2026-11-08-APPLE-TV-27-2-DEVICE-HUB-LOGS.md)。

回查历史，同一电视 10 月 18 日配对后也报过 1005，10 月 24 日已有可用开发会话并成功安装。此前刷新 Mac 用户级设备服务只恢复过发现，未恢复当时安装能力。成功连接首次出现的触发动作未留证。[历史核对](../development/APPLE-TV-PREPARATION.md)。

2026-11-08 当前包为正常签名 `97b35832…`，源为 main4de732dd+dirty，542项清单 `fae72d6dccea751980dd8708a688a8309edd760e550b60b0680ae19d96660318`。13已fresh保留覆盖并真机FTP短播+短跳转，App/Runner/转发/采集收尾。iPad截至10:12:39不在USB，用户暂不方便接回，仍保留此前bb4d安装证据。源码映射、两阶段测试失败及修正、完整包SHA与私有路径见 [最新阶段](../archive/handoffs/2026-11/CODEX-2026-11-08-NETWORK-SOURCES-SHARED-PROXY-PHASE1.md)。下文bb4d与Range为前批现场，非当前13包。

当前接续为同包iPad安装及真机回归，补13正常退出及协议对照，再接公共ByteReader、可消费预读。TV配对认证已成功，重启后仍缺开发服务。接同一路由器网线后复查仍无开发目标。现有配对保留，下次复现时可同步采集隧道日志及该电视的定向网络流量。iPhone18仍仅按明确请求安装。

2026-11-08 [Jellyfin恢复及TV连接](../archive/handoffs/2026-11/CODEX-2026-11-08-JELLYFIN-LOGIN-AND-APPLE-TV-CONNECTION.md)。13同源bb4d保留安装，用户重登后资源库/搜索/详情恢复，《赌侠》原流短时实际画面由两种截图证实。续播、seek、声音、字幕、普通退出及全程帧时间待验，预读仍0。客厅TV认证配对成功，重启后开发连接仍不可用。30项/114格无新增验收。

最新批次：[Range前置与两机结果](../archive/handoffs/2026-11/CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)。此前[Claude总接续](../archive/handoffs/2026-11/2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md)、[接收核对](../archive/handoffs/2026-11/CODEX-2026-11-08-TRANSITION-INTAKE.md)、[代理方案审查](../archive/handoffs/2026-11/CODEX-2026-11-08-SHARED-PROXY-PLAN-REVIEW.md)保留归属，后续均由Codex接手；具体余额未知。资源见[登记](../development/AGENT-RESOURCE-STATE.json)。

## 当前源、包与设备

main HEAD4de732dd、继承dirty保持；整批Claude代码接受审查尚待，NetworkMedia/LibSMB2整体未跟踪不可遗漏。本批Codex修改DevicesView的Range边界及PlaybackNextCoreTests，不提交/不改真实index。选定542仓库输入冻结（非外部SDK全量传递清单），正常Debug构建/31核签及22SMB导入绑定过，iOS Release仅编译过。

最终正常包 main `384be2453843e34fa463b6f75f6aa8232c669f87abbf5b6dfdbf6cc40a65fdff`、dylib `bb4defd4dcd424acfe0b7e3c540da8f0869d0d8b52cabec510a2e01e242c7c39`，profile到11-15 08:30:17+08；冻结包和原始证据通过私有指针 `/tmp/nastart-codex-device-resume-path`。旧4744/到期09:08状态已过时，不能继续当当前候选。

13 iPhone14,5/16.3.1/USB与Pad iPad15,7/26.6/wired，均fresh核名/UDID/连接、核签/当前源码后保留数据覆盖同包。首个627c安装13于08:44:17、Pad08:44:46，成功+lookup，安装前后29/20项及全部偏好同；默认无测试环境启动。复用既有有效Runner，无重新部署。

627c基线（不是最终包播放回归）：13正常首页/Wi-Fi和FTP《赌侠》短时实际片头图；Jellyfin401已停止重试，等待用户App内重登。控制条合成触摸两次无变化、seek/普通关闭未验，未判页面缺陷。旧cleanup BrokenPipe，独立fresh原生通道08:55:59精确停，App/Runner0；最终只诊断/续播偏好变化。Pad：正常首页/存储页，FTP/SMB各2292，与旧交接不同；WebDAV未选/待首次整理。未合成点媒体库行，手动入详情未获结果，09:06:37收窗，0播放/App/Runner0/全偏好同。Pad首轮预检finally误停已知App但缺当次画面/偏好备份的工具缺陷已修并留证。

两机自有syslog和8102/8104转发已结束，未知8101不接管。iPhone18仅枚举无操作，用户/Claude08:30报告9a17仅为其归属；未装本批bb4d，仍仅按明确请求安装，不启动/测试。TV无运行窗口。

最终测试文件变化后正常重构建，五个Mach-O哈希改变，已冻结bb4d（私有normal-package-final）。最终542输入清单SHA `4d99ee1bce4cc990497f825e7c866c4834ec9e31634f9e3e8aa08616da196918`，与627c仅测试文件不同；产品源码相同不替代安装核对。13于09:16:53、Pad09:17:26再次fresh保留安装成功及lookup，全部偏好安装时同。最终正常首页两机实看/Wi-Fi，13收窗09:18:31、Pad09:19:38，App/Runner0、自有转发停，最终仅诊断偏好变化。**bb4d没有播放回归；627c FTP画面不能当最新包结果。** 原13控制/JF401与Pad手动入口待验分别保留。

## 验证与下一步

1. Range边界/跨窗等8项、补充5项及1项12次异常交换分批通过；继承夹具3.84秒不足两个2秒采样窗，仅延长测试载荷后5/5通过。一次构建重叠已中断自有补测/实例删除，不接受该结果；失败保留。空416/忽略Range/If-Range后200/206总长度变动均正确拒绝。
2. 前批记录的第一代理接入当时未实现：NetworkLibraryPlayerPresentation注册原流、路由lease/迟到取消、稳定trace/扩展名、桥接上限至少4和诊断测量边界，一起接入后同源正常包重新逐机核验。
3. 前批13控制条输入机制/Jellyfin用户重登、Pad手动入口后FTP/SMB/WebDAV实播待补。不重复猜密码，不以自动化派发等同实际交互。iPad不要合成点network.library.source，包括通过label绕过也不允许。
4. 第二步公共ByteReader路由与可消费共享预读由Codex继续；默认Observing IO不物化导致0字节已定位，Range元数据不是缓存字节。补可靠首帧呈现及网络/读取/解码分段。按实际网络环境统一链路、FTP/SMB限LAN。

NAS业务可只读访问，原文件/目录/配置/VPN不得修改；密码/TMDB令牌由用户App内输入、不读实际Keychain/密码眼睛。TMDB真实API/UI、NAS安全收尾/样本缺口、声音/字幕实际呈现/帧时间/PiP/长时仍待。需求编号仅在唯一总账，30项/114格保持。
