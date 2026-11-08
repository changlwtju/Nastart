# 独立存储与媒体卡片、深色表面与暖色图标

2026-10-26 20:52 接用户三点现场反馈，续[首页简化与 TV 主题批](2026-10-26-UNIFIED-MEDIA-HOME-AND-TV-UI.md)。本批替代前批的“NAS 概览内嵌快捷入口”和最终安装包身份；不覆盖历史失败。原 dirty 保留，无提交/发布。结构化结果见[结果](../../../testing/results/2026-10/2026-10-26-independent-storage-card.json)。

## 实际改动

- 从 `DeviceSummaryPanel` 移除入口，在 cleanGrid、commandCenter、glassDeck 三个启动台中，紧接 NAS 概览单独展示“存储与媒体”卡片。iPhone 与 iPad 共用；仍只保留一个此功能入口。Apple TV 原先已为概览、指标的独立同级行，保持。
- 独立卡片改用宿主 `nastartCard`/`NastartSurfaceBackground`，替代不透明 `secondarySurface` 嵌套底色。流光深色保持渐变画布与轻透明表面；其他主题继续各自语义表面，并遵守减少透明度。图标使用与设备/服务相同的暖色徽标，不再黑色小卡片套在大卡片中。
- `NetworkActionLabel` 手机分支明确使用 host accent；共享 `NetworkIconLabelStyle` 给当前 NAS、协议提示及其他 Label 图标同样颜色。正文保留原明暗文字层级，不把所有文字改为黄色。
- 此次四文件：移动 `LaunchpadSharedViews.swift`、`LaunchpadLayoutViews.swift`，共享 `LibraryViews.swift`、`SourceContext.swift`。前批的 `MediaServiceViews.swift` 与 TV `TVNASViews.swift` 继续保留。没有改 AV/KS、协议、凭据或远端写入能力。

## 构建身份与逐机状态

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` + dirty，375 本地应用输入（非完整依赖闭包）。源改后重新构建双平台普通 Debug/arm64，空参数/环境；移动 30、TV 27 Mach-O 签名/profile 与 TV 嵌入核验。输入与全部二进制零漂移。

移动冻结 `2026-10-26T20:41:05.870878+08:00`，主 SHA `ccf70658c603b02124367a5d562b62c1128854b2ff2b4403dfd1cd1a7dd50bad`，Debug dylib `ded16c806ed8b98f72b38e07350d65be9a3be56891109c57c1897d454fe5ea69`；TV 冻结 `2026-10-26T20:40:53.064100+08:00`，主 SHA `12ce5006cd20a2df970d7daf54263f0aa9ec60ae528806fa106a0f53452bca80`，Debug dylib `38452e3c5e1aa29b454276b9666e3a9de026a6d5e4bdfcc7d397b4806df80bfb`。App 路径仍私有根下 `Nastart-SourceHub-Debug.app`、`NastartTV-SourceHub-Debug.app`；IPA 与完整 manifest 同处，原始设备/地址/偏好仅留本机。

| 设备 | 本轮现场与最新包结论 | 实际验证 |
| --- | --- | --- |
| iPhone 13 | iPhone14,5/16.3.1，USB lockdown 身份现场确认；20:42:47 保留数据覆盖 Complete | 正常首页，流光深色的独立卡片、媒体首页、连接管理实图及暖色图标已看；经 UI 恢复原 system，临时 WDA 设置恢复；26 非诊断偏好全同 |
| 客厅 TV | AppleTV14,1/tvOS18.2 LAN，20:42:34 Complete | 普通原生首页；精简流程/真实方向 Select/Menu、文件/已有库/管理/协议/NAS 根禁选与子目录选择；clean/light、command/dark、glass/system 三窗图与上下焦点；主题/13 偏好和 3 WDA 设置恢复，自己的 Runner 已停止 |
| iPad | iPad15,7/26.6 为上次已确认身份；20:50 最新 CoreDevice 检查 unavailable、RSD 无可用连接，安装前即阻塞 | 此包未确认安装、未回归；19:25 的旧包 Complete 不能当此次结果。重连后先现场核包 |
| iPhone 18 | iPhone19,7/27.0 家庭 Wi-Fi，现场 Bonjour 匹配原配对身份，USB 当时缺席；20:43–47 最新包安装等待超时，无 Complete/lookup | 尚未确认新包安装，更未验证 iPhone18 深色页面；用户已解锁仍出现安装服务超时，已一次请求 USB 保持解锁，等待回复。未重配/卸载/清凭据/改 NAS/VPN |

iPhone18 此前 20:34–38 回退包也在 dispatchingInstall 超时，和更早包“安装已完成但启动被锁屏拒绝”分开保留。不能因系统能启动旧 App、同版本号或 iPhone13 已更新而声称18更新。DSM 保存域名/端口与实际会话/视频路线分别记录；本批没有后两者的新验证，也没有修复旧自动选 LAN 路线。

## 验证与清理

最新模块 67 测试通过，双构建通过。最新13深色 UI 看到了独立同级卡片、渐变/半透明面与暖色文件/媒体库/添加/管理图标，未见黑色嵌套卡片；TV 三窗有限验证通过。不等于18/iPad、全主题/大字、减少透明度真机或滚动性能验收。

最新13本机库/TV本机库均为0；四个本机 WebDAV 夹具均 stopped/portClosed/sourceBytesUnchanged=true，总共5 PROPFIND、0 NFO GET、0 视频 GET、0远端写入。无实际媒体播放、无蜂窝切换，114播放格不增P。TV自有Runner停止、3设置GET恢复；13临时2设置GET恢复，原有Runner保持。原始报告/偏好/HTTP会话均私有。20:55已删除13自有HTTP会话，未停止原有Runner；20:56再次查USB，18仍未出现。477文档/2811本地链接缺失0，diff空白检查通过。

## WebDAV 连接卡住：两轮失败、停止调参

前批完整新增目录 UI 尚未通过：iPhone13/iOS16.3.1 点击“连接并选择文件夹”后，HTTP PROPFIND 已返回，界面仍读取目录。三份同窗 xctest spindump 显示 Nastart 主线程 SwiftUI/UIKit/AttributeGraph 布局循环，约5/5秒100%CPU、内存增长约126MB。没有对应新的 Nastart SIG 报告，不能直接称协议失败或 App 崩溃。两次有上限的 LLDB 等待由调试器主动杀进程，其退出也不算产品崩溃。

1. 独立导航 bool 与清焦点候选，移动主 SHA `8b3675a4c00b950945829529c125b631630347fbb60b56411b17747dbf9fd545`：连接仍超时，已回退。
2. 稳定加载行/避免禁用聚焦按钮候选，移动主 SHA `c6108312bd477384ae72e274b83681eb322787114fed17f71cb1663bcc75a56a`：20:31 再次实际点连接后超时，已回退。此前20:26脚本初次失败未到新连接，不混作一次结果。

遵守两轮无改善停止盲调，没有第三轮修改连接逻辑。本批新增外观改动与该未解决路径分开；“新增后自动退回首页”的回调虽已实现，但新增→NFO资料→本机纠错→恢复→移除的完整 UI 尚未走通，不作为交付验收。接续应先用已保存栈做隔离复现，定位布局/导航的真正循环边界，再提出有新证据的修复；不要继续替换几个状态变量碰运气。

自动化的原始失败也保留：可访问性 id 同时落在容器与真实 Button 时，改按 Button 匹配；第三方键盘的 dismiss 没隐藏且滑动误输入字符，已修正夹具输入；实际可见按钮却报告 AX visible=false 时依据实图/已测坐标作原生点击；回退包13完整 smoke 有界130秒超时，无输出，不算通过。最新只记录上述独立深色检查通过。

## 接续

先完成18 USB最新包与实际深色核对；Pad恢复后同样先核包。WebDAV新增布局故障、完整本机资料流程仍开放。FTP生产来源/字面路径/账户作用域/递归未接，SMB严格选根FAIL未接；在线provider/海报/独立库播放/增量/同步与新增Emby/Plex/音乐原生客户端仍未完成。30项14进行中/5待验收/11待开始保持，不因外观批关闭这些任务。没有周期任务，不声称回合结束后后台运行。

## 21:03 USB接续：iPhone18已装，替代上文安装阻塞

用户完成USB连接与解锁后，重新现场读取iPhone19,7/27.0/USB/原配对身份，核对当前375输入、HEAD/dirty、全部30 Mach-O/IPA/签名/profile。21:03:22保留数据覆盖最新移动ccf70658…包，InstallComplete/安装后lookup成立。普通空环境启动，3/10秒原生进程与截图成立；实看流光深色首页的独立卡片/宿主表面与暖色入口图标、Wi-Fi图标。安装前后及正常启动后27非诊断偏好全同。没有修改保存地址/凭据，实际DSM固定域名/视频路线旧项仍未重测。

内部媒体页自动化尚未成立：使用设备已有Runner启动时报告initializationForUITestingDidFailWithError，未建立HTTP服务；该Runner已停止，无新Runner安装。一次原生AX inspector替代读取没有得到目标焦点，0按压/0设置写入，自有监控finally关闭。二者是工具未完成，不能写成产品页面失败或iPhone18内部深色验收。已恢复原生正常首页。后续用户新增Apple TV启动台同类尺寸与紧凑布局，另归下一批。
