# 冷续播外置字幕与画中画缺口交接

更新时间：2026-10-12T17:49:29.746915+08:00。操作范围仅当前 USB iPhone13、iPad；iPhone18 用户带走，本轮完全未操作。Tailscale、Shadowrocket、路由、配对和系统条件保持原状，未注入测试环境、限速或大文件人工转码条件，未提交或推送。

## 最新安装包身份

本轮无 iOS 源码修改；HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留全部原未提交修改，iOS diff SHA-256 `5907048189b28f527c02383402938fb06907a12bfd2f57bca80407eed0cab7af`。构建配置 `normal Debug -Onone; empty launch environment`，构建时间 `2026-10-12T16:29:52.953492+08:00`。App/IPA 路径：

- `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-source-selection-162926/Nastart-Committed-Source-Selection-Normal-Debug.app`
- `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-source-selection-162926/Nastart-Committed-Source-Selection-Normal-Debug.ipa`

| 二进制 | SHA-256 |
|---|---|
| Nastart | `63821b634e4eb50c497a3f0cefb7084e0c435885644f9ba38d24c2f1da9b0799` |
| Nastart.debug.dylib | `2f5eee64dc077d28b476262fde6ead5a8c94bdd2d48d7632454fc259749f3a3b` |
| Frameworks/KSPlayer.framework/KSPlayer | `df76e71df756331a8e80a0e0550683b73a24af6282db214a7401fd975af643c4` |

开工、窗口、切换和收尾均核对现场 USB 名称/型号/系统/UDID；原始身份只留本机。iPhone13 为 iPhone14,5/iOS16.3.1，iPad 为 iPad12,1/iOS18.3.1。173 输入哈希/mtime、三二进制、deep strict、29 库签名、IPA/链接通过；源码不晚于产物。326 测试/2 跳过/0 失败、15 预检为此前同源码结果，本轮未重跑。

无法独立确认旧安装身份，先保留诊断/偏好后逐台保留数据覆盖：iPhone13 `2026-10-12T17:12:45.048807+08:00`，iPad `2026-10-12T17:12:52.776796+08:00`；25/16非诊断偏好逐项一致，实际普通空env/args首页已看。

## 本轮结果及失败归属

1. **iPhone13 自然路线观察**：ASS5普通播放约90秒内无字幕/定位/暂停操作，0 fresh AV 遥测、0 replacement commit、0 warmup failure，实际KS/localRangeProxy。3/10/30/60图白双语，90图无cue；普通退出4724.87/音轨1/字幕5开启。不能算13 AV完成，也没有失败回滚负例。
2. **iPad原生切换**：本轮也KS；ASS→原生Off，约51.404秒未见AV提交，Off实际勾选、重新ASS5。手动PGS工具在检查实际AV基线时抛出守卫错误，**未向App提交PGS候选**，没有实际准备失败弹窗。保留失败日志，不当App失败或回滚通过。然后45秒普通退出4831.382/1/5开启，3/10/45电影无采样cue，不作字幕内容通过。
3. **iPad冷续播内容**：普通终止后冷启动，搜索实际条目，未重选字幕就续播；45秒3/10/45实际图，10和45白双语自然cue，菜单勾选ASS5，fresh1288cue、KS/localRangeProxy。外置字幕冷启动基础内容补证完成；不等于全ASS样式/长cue/音画/HDR性能验收。
4. **PiP字幕缺口**：实际播放器画中画按钮后桌面3/10/30图均有电影浮窗。fresh42条pip_subtitle_frame里17条非空文本，external=true但composited=false。观察期间后续采样保留，不把稀疏图片算完整连续帧。S03详情标HDR，源码GreenfieldPiPSubtitleCompositor明确跳过PQ/HLG；这只是候选解释，现有事件没有当帧transfer或分配失败原因，尚不能排除pool等失败。**PiP字幕FAIL/未验收，不改HDR守卫以制造通过。**
5. **PiP恢复工具缺口**：第一次激活App保持同PID，实际详情页仍有浮窗，激活不等于恢复全屏。临时SpringBoard会话创建后树无PiP，控件查找StopIteration；随后普通激活同PID但浮窗消失，原因未定。没有恢复按钮成功证据，也没有该窗口完成按钮普通退出证据。保留截图/XML/guard记录，不计恢复全屏PASS。另经正常详情PGS7/30秒/普通退出恢复，归独立恢复窗口。
6. **保留的早期等待**：两机PGS恢复3秒图spinner（Pad黑场），10/30实际电影但无自然PGS cue，仅选择/保存恢复核验。搜索工具首试“碟中谍 3”无匹配，实际改“碟中谍3”成功；记录TOOL_QUERY_MISMATCH，不丢失败也不算App搜索崩溃。

## 收尾

| 项目 | iPhone13 | iPad |
|---|---|---|
| 非书签偏好 | 24项一致 | 15项一致 |
| 变更书签 | 1（S03JF） | 1（S03JF） |
| S03JF退出位置/音轨/字幕 | 4749.478 / 1 / 7 开启 | 5114.004734646 / 1 / 7 开启 |
| S03文件，未播放未修改 | 646.729 / 4 / 5 开启 | 912.997 / 4 / off |
| 新崩溃报告 | 0 | 0 |
| 最新普通包/空环境/无挡首页/播放器关闭 | 已核实际图 | 已核实际图 |
| WDA idle/animation | 10/2秒 | 10/2秒 |

NAS/Jellyfin在线；Radarr/Sonarr及Pad其他服务警告留证，不声称所有服务健康。原始偏好、凭据、地址、诊断、源diff/状态、设备身份、媒体和截图仅在私有证据 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-av-rollback-continuation-171152`。公共脱敏摘要：[JSON](../../../testing/results/2026-10/USB-COLD-EXTERNAL-PIP-GAP-20261012.json)。

## 接下来

- 先区分PiP拒绝合成的原因：无cue/PQ或HLG保护/overlay/pool/分配。保留HDR保护，新增原因诊断时按新源构建、签名核验和逐机保留数据覆盖；用SDR字幕样本对照当帧，并补系统真实恢复全屏控件及普通退出。不要复用不存在的系统控件或通过重启代替恢复验收。
- 13真正AV、手动候选准备失败后的菜单/覆盖/旧流/保存负例仍未触发；此前同源PadAV结果仍有效历史证据，本轮KS观察不继承为AV回归。
- 代表S03/S11/S18/S19、字幕样式/长cue/动画/烧录/音画与HDR、13蜂窝、MTP/L2/L3、475/119/HLS/callback/供流、Lenna与DS One同条件完整帧，以及18自动无线通道/PX01–21/UX01–06/CB/Main等全部历史未完成范围继续保留。本轮没有完整帧、音频连续性、真HDR/DV、性能或竞品PASS。
