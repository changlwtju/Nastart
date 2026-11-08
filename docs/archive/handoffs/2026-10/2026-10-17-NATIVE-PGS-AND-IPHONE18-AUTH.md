# 2026-10-17 原生 PGS 底边和大快进回归；iPhone 18 等待本机授权

接续用户“继续”。本轮无 App 源码修改、重构建或测试重跑，保留全部既有 dirty 修改。最新仍为 cc64de38bfaa、10-16 19:50:56 普通 Debug/Xcode 27 包，173 输入、三二进制、29 库、IPA CRC/内部 SHA、签名/profile/目标授权及收尾核验通过。[结构化结果](../../../testing/results/2026-10/NATIVE-PGS-AND-IPHONE18-AUTH-20261017.json)保存完整哈希与分项边界；历史全套失败未撤销。

## iPhone 18：安装完成，当前 UI 与播放没有通过

现场 DNS-SD、既有配对 TCP、名称/UDID 核到 iPhone19,7 / iOS27.0 / Wi-Fi，USB 无目标。先保存包含诊断和书签的完整偏好，再保留数据覆盖；北京时间 **03:41:36.031347** Install Complete、lookup 成功，安装前后及普通启动后 **25 项非诊断偏好完全相同**。无卸载、清登录、重配或网络修改。

RSD/DVT 请求空 env/args 启动，但实际 PNG 为 SpringBoard，不能用上批正常首页或返回 PID 代替本轮首页。立即执行 `idevicecrashreport -n -e -k`，标准网络通道退出 1；随后通过配对 userspace RSD 实际读取报告清单并拉取 Nastart 匹配报告。该时点清单 Nastart 0、WDA 8、Jetsam 8，Nastart 进程 1、Runner 0；不将意外后台称为 App 崩溃或 WDA 工具故障。

installation_proxy lookup 确认固定 Runner 已安装、ProfileValidated=true；misagent 只读核到匹配的有效 profile，目标已授权，到期 `2026-10-17T22:28:19 UTC`。复用已安装 Runner，经现有配对 CoreDeviceProxy/userspace RSD 的 testmanagerd/DVT 建立 XCTest，未重建或安装 WDA。实际原生截图显示 **“为 XCTest 输入 iPhone 密码 / Enable UI Automation”**；已通过问题面板请用户在手机本机输入，禁止把密码发入聊天。用户尚未回复，WDA 未取得 ready，未建立 App 交互会话、未播放。

批末主动 SIGINT 停止本批自建 XCTest Python，日志 KeyboardInterrupt/exit 是主动收尾，不是自动断连。后续 40 秒有界 RSD 收尾读取超时，尚未取得进程清单，故不能声称 Runner 最终已退出、最终 UI/偏好/conditions 已复核。安装/启动后 25 项保持证据仍成立，最后额外复核未完成须分列。下轮收到本机授权完成后先重新核身份/包和 Runner 状态，不因这次授权提示重装 WDA。

## iPhone 13：原生 PGS 带字幕暂停与大快进

现场核名/UDID、iPhone14,5 / iOS16.3.1 / USB；保存偏好/诊断和本轮报告基线，覆盖最新包，安装前后 25 项保持，空 env/args 实际首页已看后才播放。低亮度未改。iPad 本轮未发现、安装或播放，仍为上批主动停 Runner 状态。

Jellyfin S19 原默认简英 PGS 轨道 index8，从头普通播放；初始 t3 黑屏、t10 蓝色片头及缓冲、t30 New Line 标识均保留。早期未取得可用暂停 cue，不能算字幕验收。一次 element click 返回成功但未暂停，实际控件仍为“暂停”；改用本轮新鲜唯一控件边界的 W3C 触摸并验证状态，未改 App。

随后在 **01:23** 实际暂停并稳定保留“七枚给了矮人诸侯 / Seven to the Dwarf-lords.” 原生位图：显示控制栏、隐藏、重显、竖屏、回横屏均采 PNG/XML/偏好并实际查看。横屏 844×390，cue 底边 y357，距屏幕底 **33pt**；竖屏 390×844，cue 底边 y798，距底 **46pt**。本组位于屏幕底部，无旧中部位置或裁切；这是当前 13/原生 PGS 的定向证据，不能替代 18 或烧录 HLS 的位置验收。

从稳定暂停 cue 进行大快进：滑块期望 7500 秒，实际引擎目标 **7332.848 秒**（触摸映射偏差保留，未将期望当实际）。KSPlayer dispatch→completion **4.584 秒**，目标预览 API **5.726 秒**、PTS7332.825；均不是实际呈现时间。首图采集窗相对触摸开始约 **0.852～1.351 秒**，仍旧视频帧但旧字幕已无；t3 仍旧画面/缓冲，t10/t30 已是目标电影画面，所有原图已看。支持这一原生窗口旧 cue 清除，仍存在明显跳转等待，不判提速/完整 SUB 通过。

目标位置继续自然播放，t3/10/30 和暂停图已看，不同电影帧及后续“不 / No!” 保留；稀疏图与内部时钟不能作为连续流畅或 AUD 证明。后续诊断明确自动转 AV/HLS（currentSeconds7364.793），因此其后的字幕切换记录不能混进原生 PGS 测试。

## 换轨与工具失败的边界

在实际字幕菜单从默认简英 PGS 改为简体 PGS，再恢复原选择。0/1/3/10 秒图仍保留旧视频帧/原烧录字幕及缓冲，选择菜单最终核回默认轨道。一次 `warmup_failed` elapsed11234ms 的 stage 是 **candidateInvalidated**，由恢复原选择取消旧候选触发，不能称独立超时或根因。原生 cue 助手在已转 HLS 后无法找到独立节点的 AssertionError 保留为工具资格失败，不计 SUB 失败；这段不是切换成功或低延迟证据。

退出后新鲜树里的底层导航按钮触摸误开详情字幕菜单，错误“首页”截图保留。改为普通空 env/args terminate→launch，实际正常首页逐图重核后才收尾，未把误触成功回执当导航成功。最终首页播放器关闭，NAS 卡仍显示未连接、Jellyfin 健康绿点；不称 NAS 会话恢复。

最终 24 项非书签偏好保持，36 项原书签 0 删除/0 新增/0 轨道字段变化，仅 1 项自然位置变化；较本轮开始 Nastart/WDA/Jetsam 均 0 新增，native active conditions0，WDA idle10/动画2，普通实际首页已看。临时 Mac 防睡眠断言已释放，永久电源/手机亮度/网络配置未改。

下轮先完成 18 本机 XCTest 授权与普通最新包首页；13 继续分开原生与 HLS 的完整字幕/换轨、大跳转等待和候选预热归因。HLS、蜂窝准备失败、音频、CPU/内存、PiP/双入口、菜单偏移、MI2/PX/UX/CB/Main/竞品及完整矩阵未完成项均保持。原全套测试失败继续以旧交接为准。

私有指针 `/tmp/nastart-18-regression-evidence`；原始设备名/标识/地址/凭据/偏好/PNG/报告与可复用 RSD/XCTest 工具保存在对应仓库外目录及 `reproduction-tools-private`，未进仓库。
