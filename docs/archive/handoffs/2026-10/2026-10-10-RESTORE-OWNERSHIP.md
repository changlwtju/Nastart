# NAS登录恢复任务归属

更新时间：2026-10-10T16:37:04.403393+08:00。本批完成 L0 与声明范围内 L1，未进行正式 L2/L3 或发布验收。脱敏数值见 [本批报告](../../../testing/results/2026-10/RESTORE-OWNERSHIP-20261010.json)。

## 问题与最终行为

旧恢复任务原先在初始登录后没有取消/任务归属检查，尾部只比较 SID，catch/defer 可清新任务状态；手动登录后台 snapshot 同样只比 SID。现在恢复/手动登录共享尾部流程，以连接操作 ID、主登录 UUID、当前数据来源身份判断归属，恢复另核刷新 ID。每次初始登录、fallback、FileStation、LAN、snapshot 挂起返回后核对；失效或取消任务不能发布旧结果、保存旧凭据或标记新登录失败。

最终归属检查、凭据保存与 snapshot/连接发布在同一 MainActor 执行段内完成。FileStation 会话先同步准备目录来源再发布连接，不等 inventory 完成。手动登录发起即使旧恢复失效，取消按钮只取消自己的操作；旧 UI cleanup 不清新登录状态。Mine 在等待退出登录前清本地数据，避免旧 logout 返回后再清新连接。恢复与手动登录失败清理在每个 logout 角色发送前读取当前会话，保护同端点图内当前 DSM 或 FileStation 正在使用的真实 SID，不因客户端 UUID 不同就注销它。

仅本批六个源码文件改变：AppStateStores、NASConnectionStore、DSMClient、LaunchpadConnectionViews、MineView、NonPlaybackPolicyTests。对前包 173 个输入逐项比较已存证；播放器、传输、书签、超时、重试与自动重新鉴权参数未改。工作区原有未提交修改保留，没有提交或推送。

## 受控证据

先以门控返回顺序固定 7 个反例，旧逻辑 19 项断言失败；第一候选 19 个新场景通过后追加“清缓存使待完成恢复失效”，又复现 4 项失败断言，补刷新 ID 检查后形成最终源码。红日志与中间源码均私有保存，未将中间包测试移为最终结论。

最终新增 20 个确定性场景覆盖：开始前取消、登录/snapshot 迟到取消、新手动登录优先、同 SID 不同 UUID、旧 catch/defer、新任务刷新标识、FS/LAN 迟到、保存失败、rememberPassword/OTP、实际 fixture HTTP 的主/FS logout 过滤与角色间重核、不同端点/跨角色、旧取消按钮、新退出意图、缓存失效。signOut 反例仅在模拟器无已保存凭据/无已接纳 NAS 会话条件下执行；未切换真机账户、清登录或向真实服务器制造故障。前台 refresh cleanup 的 token 由源码检查确认，未新增专用前台场景验收。

最终 XCTest **285 项、2 跳过、0 失败**（93 非播放与 192 播放）；15 预检、18 报告工具测试通过，正常设备 Debug 编译/链接通过。报告记录本轮执行结果，不沿用前包 265/284 项结论。

## 当前包身份与逐机核对

- HEAD：`4de732dd645b36671becff992cdef1d0163fd1e4`；iOS 未提交 diff SHA-256：`c51133b78e77c80a02c9b7c23b4a7b1cdc7aaeb0327bab6b9c7d394c799b8a6f`。
- 构建：`normal Debug -Onone; empty launch environment`；时间：`2026-10-10T16:19:15.777382+08:00`。
- 包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-restore-ownership-final-161835/Nastart-Restore-Ownership-Normal-Debug.app`。
- Nastart SHA-256：`f26037831d6074b3779470c59191b4af0b9720eb522f1d730e2fba2a0e191f7e`。
- Nastart.debug.dylib SHA-256：`0649bd7b7a6f661d5bc4737485e70af8c1d0995df50d32ac862f64becd212950`。
- KS SHA-256：`eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`。
- 冻结及结束复核：173 输入一致、无较新输入，29 库逐个与 App deep 签名、三设备有效 profile、链接均核实。原始 UDID/偏好/日志仅在本机私有证据目录。

| 设备 | 现场名称/型号/系统 | 连接 | 安装核对时间（+08:00） | 结论 |
|---|---|---|---|---|
| iphone13 | iPhone / iPhone14,5 / 16.3.1 (20D67) | USB | 2026-10-10T16:21:20.442262+08:00 | 成功；安装及首次正常启动后 25 项非诊断偏好一致；实际空环境启动已核 |
| ipad | iPad / iPad12,1 / 18.3.1 (22D72) | USB | 2026-10-10T16:20:42.710207+08:00 | 成功；安装及首次正常启动后 16 项非诊断偏好一致；实际空环境启动已核 |
| iPhone 18 Pro Max | iPhone / iPhone19,7 / 27.0 (24A8428) | 无线配对，未连 USB | 2026-10-10T16:22:02.445359+08:00 | 最新包覆盖成功、25 项偏好一致；启动与实际前台画面未验证 |

每次切换与播放前重新查询 USB/设备信息、源输入、包哈希与本批覆盖安装凭据。保留数据覆盖，未卸载、未清登录、未重装 WDA。版本号 0.1.0/1 不用于证明安装身份。

18 原生安装/启动 CoreDevice 4016 保留；无线 AFC+installation_proxy InstallComplete 和安装后 Lookup 证明最终包安装完成，同包 IPA 内三二进制逐项一致、未重新签名。无线 DVT InvalidService 与原生截图不可用使普通启动和实际 UI 未核，需 USB 接入后重核包并启动；没有 18 播放验收。

## 最终包 L1

正常家庭 Wi-Fi、串行 NAS 访问、空环境/参数；原生起止条件 activeCount 均 0，没有注入网络条件。缓存、NAS 负载和温度未完整控制，不能用于性能排名。每机三次从根目录进入 video、退出/重进均对应 media 子目录，六组 XML 与十二张实际图片已核；手机立即重进图有导航过渡残留，因此不据此验动画或滚动流畅。24 个排除覆盖前旧事件后的新目录响应为 success，未出现本批 119，不关闭历史 119 服务端/SID 原因。

| 设备 | S01 入口 | trace | 首次观察到时钟推进（点击边界） | 采样 stallCount 最大值 | 画面/退出 |
|---|---|---|---|---|---|
| ipad | 文件 | `1CEA740B` | 3.166293s | 0 | 正文/原正常退出已看 |
| ipad | Jellyfin | `3415E214` | 2.739531s | 0 | 正文/原正常退出已看 |
| iphone13 | 文件 | `9BFF1164` | 2.233051s | 0 | 正文/原正常退出已看 |
| iphone13 | Jellyfin | `5D61795E` | 2.259443s | 0 | 正文/原正常退出已看 |

四个计划 60 秒窗均按原始退出边界解析，四正文、四正常 UI 退出；文件两出口与 Jellyfin 两详情均显示匹配片名和继续观看。稀疏截图及内部推进不是屏幕首帧或完整帧证据；手机截图容器内视频旋转，未核物理屏幕方向。iPad Jellyfin 一次 SocketError 诊断读取在同窗重试成功，失败原记录保留。启动阶段 clientFailed/clientBodySend POSIX 54/32 与取消 -999 事件原样保留，不能因最终电影可见抹除或擅判根因；无本批可见播放错误。

两机结束后重新核当前源码/包/设备、空环境普通启动实际参数，实际首页 NAS/DSM/Jellyfin 在线、播放器关闭；初始服务灰色图保留，随后只读图确认恢复。Radarr/Sonarr（及 iPad Prowlarr）橙色警告仍在，不称全服务正常。WDA ready，idleWait=10、animationCoolOff=2；原生所有网络条件 inactive。播放后书签等允许发生正常改变，不把最终偏好称为全数未变。

## 中间失败与未完成项

`8ee/a7ac/6841` 中间包只归其自身：首手机回系统桌面/WDA404 未知原因、随后导航栏缺失、恢复误入 fanart.jpg、目录返回超过七次界限均保存。曾因诊断目标目录不存在失败，随后 keep-only 导出，未找到本日 Nastart/Jetsam 报告；缺报告不证明无崩溃或原因已排除。工具改为实际元素身份点击后最终包导航通过，但桌面退出原因仍开放。中间文件播放 trace9236CE6F 在首推进后有报告1002ms等待（动作18.803925→19.812531s），独立于最终四窗，未删除/改记成功性能。

下一步先固定显式 signOut 的 logout 挂起期间新登录/复用 SID 的受控反例；本批保护的是失去归属的恢复/手动登录清理，不能声称所有已发送服务端 logout 都安全。随后定位当前会话 119、手机退出保存收敛、S19/原弱网/旧 ordinal0 等待。真实跨账号、前台刷新专用反例、完整帧/实际位移、声音字幕/HDR、深 seek/10分钟/PiP/MTP、物理弱网/蜂窝/外部 Wi-Fi 与 Lenna/DS One/其他竞品仍待补。全部 PX/UX/CB、19×4、正式 L2/L3/Main 保持原状态，不把本批局部规则修复当总体验通过。

私有证据根：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-restore-ownership-final-161835`；基线、红日志、中间失败、原始退出/读取、截图、冻结输入、签名、辅助程序及哈希归档均留本机。
