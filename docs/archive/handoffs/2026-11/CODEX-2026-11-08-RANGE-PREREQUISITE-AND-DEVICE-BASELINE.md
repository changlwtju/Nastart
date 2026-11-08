# Range 前置修复与 13 / iPad 最新包基线

2026-11-08，Codex 接续用户“签名已更新，继续调试”。本批是共享代理第一步之前的边界修复与设备基线，不代表整批 Claude 改动已经完成接受审查。前序见 [总接续](2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md)、[接收核对](CODEX-2026-11-08-TRANSITION-INTAKE.md)、[代理方案审查](CODEX-2026-11-08-SHARED-PROXY-PLAN-REVIEW.md)。结构化结果见 [本批结果](../../../testing/results/2026-11/CODEX-RANGE-AND-DEVICE-BASELINE-20261108.json)。

## 实现与边界

保留 main HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 和所有继承 dirty，不提交、不改真实 index。Codex 本批产品/测试增量仅 `DevicesView.swift`、`PlaybackNextCoreTests.swift`；原字节、patch 和私有原始证据保存在仓库外。NetworkMedia / LibSMB2 整体未跟踪，仍须纳入后续审查和提交。

`MediaRangePolicy` 严格解析单区间、后缀、非法/溢出边界。后缀先发 `bytes=0-0` 取得长度，再换算真实尾部的有限窗口；不把尾部读成文件头。拒绝不合法客户端区间为本地 416，不请求上游；上游 416 保留可用长度。后续窗口限制响应范围/长度和编码；后缀保存长度及可用强 ETag/Last-Modified，通过 If-Range 避免静默拼接变更版本。窗口终点加法改为不溢出，已发头后的错误只关闭，不再发送第二份错误头。

源码映射：[DevicesView](../../../../ios/Nastart/Nastart/Features/Devices/DevicesView.swift) 的 MediaRangePolicy / MediaStreamProxyTransfer；测试映射：[PlaybackNextCoreTests](../../../../ios/Nastart/NastartTests/PlaybackNextCoreTests.swift)。接受路线已同步 [播放架构](../../../architecture/VIDEO_PLAYBACK_PIPELINE.md)。后缀长度探针会多一次有限请求；新增空资源416、忽略Range200、If-Range后的200版本变化、206长度变化四类异常，每类新路由3次，共12次交换通过：正确416/502、空错误体、正确If-Range与尾部区间。覆盖取消回调与本地错误发送的有限竞态样本，不外推所有服务端/调度行为。

第一步 `NetworkLibraryPlayerPresentation.registerOriginalStream`、桥接并发上限 2→至少 4、lease/迟到取消、稳定 trace/扩展名和测量边界尚未实施。第二步公共 ByteReader 路由和可消费预读也未交付。同一网络环境统一播放链路、协议只适配字节，FTP/SMB 限 LAN 的原则不变。

## 构建及验证

选定 iOS/tvOS 工程、源码、资源、包与测试输入 542 项，在本批测试/正常构建前后一致；清单 SHA-256 `a4a3bfeb02f0c6092aa3c9db67f44bb0c6516ea0011cf453a7d56dd4b5f1ada3`。这是明确选定的仓库输入清单，不声称包含外部 SDK 和全部传递构建输入。HEAD 不是完整源码身份。

原样枚举 Swift 探针 7 项过。新增后缀、非法区间、溢出、跨 32MiB 窗口和既有反向 seek、撤销隔离、半关闭/并发请求共 8 项宿主测试通过，08:40:53–08:42:31，空白自建 iOS27 模拟器，无用户账号/偏好，实例已删除。正常签名 Debug 与 iOS Release 编译均成功；Release 仅编译，没有安装。此前 Claude 六配置/350 包测试不冒充本批重跑。

资源事故：一次额外测试在 Release 构建结束确认前提前派发，存在同 DerivedData 重叠；立即只中断自有测试构建，exit75，删除自建实例，不接受测试结果。Release exit0 后串行补测5项，4过/1失败（该用例两条断言失败）。完整48MiB响应/两段范围均正确，供给稳定窗口只有1个。继承测试在64KiB/5ms下总时长约3.84秒，要求两个各2秒窗口；失败窗实际3.864秒，无法满足。该方法在本批前字节相同，未另跑修改前宿主A/B。仅将测试载荷延长至64MiB/约5.12秒，保留断言/采样规则/首段小于4秒约束，09:09:12–09:10:34串行5/5通过（该方法5.391秒）；不凭修改前后源推理冒称旧包实测。不得抹除失败。

## 首个基线包627c与逐机安装

正常 Debug `-Onone`，沿用有效签名，无测试启动参数/环境，无修改签名账号/设备或请求续签。构建完成 08:43:27，冻结检查 08:43:43+08。31 个 Mach-O 单独及 deep/strict 核签通过；22 个 SMB 导入均为 nastart 前缀且绑定 LibSMB2。App profile 至 **2026-11-15 08:30:17+08**，覆盖本轮目标。旧 4744 包及当天 09:08 到期说明仅为历史；Claude 08:30 续签候选 9a17 已被本批含 Range 修复的新包替代。注意：627c 后续被最终重构建 bb4d 替代，下述 FTP/界面基线归属627c。

- main SHA-256：`113e91b28971de5a54f16670516fa4a5f6d0e4fdc3b4248d84d79ab62e06142b`
- Debug dylib SHA-256：`627c173d7d0cc43d39e91cc7a8dc43480c8aac33251012bad6a9668af349c190`
- IPA SHA-256：`88765d6289216e84d346e1fa3ada0f4abef560c423f5776415b694abdb032b0c`

包路径为私有证据根目录下 `normal-package/Payload/Nastart.app` 和 `normal-package/Nastart-Normal-Debug-20261108.ipa`。私有根目录指针 `/tmp/nastart-codex-device-resume-path`；完整设备名、UDID、已装路径、偏好、连接地址与原始日志只在本机私有证据，不复制进共享结果。

| 设备 | 当窗身份 | 保留数据覆盖安装 | 启动与覆盖 |
| --- | --- | --- | --- |
| iPhone 13 | iPhone14,5 / iOS16.3.1 / USB，fresh 配对及实际身份核对 | 08:44:17 Complete + 新 lookup；29 项/全部偏好安装前后相同 | 默认空环境/参数正常启动、Wi-Fi 图；FTP 短时实际画面，详见下文 |
| A16 iPad | iPad15,7 /26.6 / wired；初缺席，用户接回后重新核对 | 08:44:46 成功 + 新 lookup；20 项/全部偏好安装前后相同 | 正常首页/存储与媒体实际图；FTP/SMB 各 2,292，未播放 |

安装不卸载、不清登录数据。iPad 安装前有已知 Nastart，先保存偏好/实际可执行路径，精确停止后安装，跨停止偏好同。当前 Runner 已有效签名至 11-11，本批复用安装，不重新部署。iPhone18 仅出现于设备枚举，没有控制/安装/启动；TV 未操作。

## iPhone 13 在627c上的实际基线与失败

Jellyfin 首次资源库读取返回 **401**，已停止重试，等待用户在 App 内重新登录，不索取聊天密码。设备文件入口可见 root/video/media/movie；两部影片目录界面为“暂无文件”，尚未拿到同窗服务端独立目录证据，不将其定为原文件丢失。

客户端本地索引保留：FTP 2,292、SMB 2,410、WebDAV 2,292。一次取 AX 早于加载，而稍后真实图显示媒体库，不是账号或索引被清空。只读客户端数据，无实际 Keychain 读取。

FTP《赌侠》5,467,405,922 字节、MKV/HEVC1080p/AC3，从头播放，名义 t3/t10/t30 截图留存，t3 与 t30 实看为不同片头画面。Wi-Fi 图标与 LAN 请求路线见私有证据；未做蜂窝任务/网络切换。内部 first_frame 2193ms、提交事件约 1028ms 属各自内部边界，不能当实际呈现首帧。稀疏截图不能判全程流畅/音轨有声/字幕正确。

预读仍 `preload_cancelled`、`reason=bytesNotMaterialized`、0 字节。共享代理传输 0 次符合该入口尚未接第一步，不是共享代理性能结果。当前默认 Observing IO 不物化字节为已定位设计，真实可消费预读仍是缺口。

横屏后 W3C 两次触摸未显示控制条；+15 与完成按钮不存在时只查找失败，未误点。seek/普通退出未验收，输入通道与页面机制尚未区分，不继续盲调。约37秒触发 STOP，原 native cleanup BrokenPipe 失败；改用独立 fresh USB/DVT，保存偏好、双核已装实际路径/PID，08:55:59 精确停止 Nastart，确认 App/Runner 0、自有转发/采集退出。实际总播放窗约90秒，不写成严格30秒自动截止。偏好最终仅诊断与本地续播两键变化，其余相同；不能把安装时全偏好同外推整个播放窗。

## iPad 在627c上的受限窗口与收尾

08:56 首次 Runner 预检发现已有 Nastart 后失败；私有 helper 的 finally 仍精确停止了该已知 App，但未在这次停止前补存当前画面/偏好（此前安装备份存在）。此为工具清理缺陷，保留失败，不写“完整前置通过”。已修 helper：预检未取得本批窗口时不清既有 App；独立 fresh native 清理及自有转发退出置于 finally。

08:57:56 第二窗有效 Runner + 正常启动，首页与“存储与媒体”实图。FTP/SMB 各2,292；WebDAV 为未选择目录及等待首次整理，与旧交接不同，不能沿用“全无媒体库”。没有验证这两协议实际凭据或播放。严格不合成点击 `network.library.source`（历史会误开移除菜单）；请求用户手动进入 FTP/影片详情，未获操作结果，09:06:37 结束窗口，不把等待当完成。App/Runner 0、自有8104转发退出；20项/全部偏好同，自有 syslog 停止。

未新增 NAS 配置、VPN、源文件写入或凭据修改；没有蜂窝流量任务。未知旧8101转发保持。13/Pad均无遗留本批 App/Runner 或采集。30项需求/114格不因这次有限基线新增P，原失败保留。

## 最终包bb4d与再次安装门槛

设备基线后只修改测试文件：修复继承夹具时长、新增12次异常交换；产品源码与基线相同。最终542项清单SHA-256 `4d99ee1bce4cc990497f825e7c866c4834ec9e31634f9e3e8aa08616da196918`，与基线仅PlaybackNextCoreTests不同。为遵守源码晚于产物先构建，再执行正常签名Debug构建，exit0；实际五个Mach-O哈希发生变化，不能以产品源码相同跳过逐机更新。未推断变化原因。

09:15:50冻结最终包（31核签/22SMB独立绑定、同11-15有效profile、无测试插件），私有 `normal-package-final/Payload/Nastart.app`、`normal-package-final/Nastart-Normal-Debug-20261108.ipa`：

- main：`384be2453843e34fa463b6f75f6aa8232c669f87abbf5b6dfdbf6cc40a65fdff`
- dylib：`bb4defd4dcd424acfe0b7e3c540da8f0869d0d8b52cabec510a2e01e242c7c39`
- IPA：`6b00f27a5f0c2cec3e39d5f5ed433b7e77536552f44995c07f5241f474e452b0`

13于09:16:53、Pad于09:17:26再次fresh身份/当前源与签名验证后保留安装成功及lookup；安装前均出现已知Nastart进程，保存偏好/核实际路径后精确停止，跨停止与安装全部偏好相同（29/20项）。未卸载或清登录。默认空参数/环境正常首页两机均实看，Wi-Fi图标可见；13于09:18:31、Pad于09:19:38精确收窗，App/Runner0、自有8102/8104转发停止。两机最终仅诊断偏好变化，所有非诊断偏好相同；没有最终窗syslog采集或新播放。**627c的FTP播放不算bb4d最新包播放回归；bb4d仅核普通启动，不关闭播放验收。** 本地一次误用无设备依赖的系统解释器在导入阶段退出，未访问设备；随后复用已有pymobiledevice3环境，无安装/升级依赖。

## 接续

1. 继续维护 Range 异常上游/取消反例覆盖，完成第一步路由 lease、取消/trace/扩展名/测量边界与桥接四连接预算，构建后重新过每台安装门槛。
2. 13 控制条输入失败与普通退出、Jellyfin重新登录；iPad 手动入口后 FTP/SMB/WebDAV 实播分别待补。不得假定已修复或沿用本包结果证明下一包。
3. 按总交接继续整批源码审查；第二步中性 ByteReader 路由及真实预读由 Codex 接续。声音、字幕、长时/PiP、实际帧时间与可靠首帧仍未验收。
