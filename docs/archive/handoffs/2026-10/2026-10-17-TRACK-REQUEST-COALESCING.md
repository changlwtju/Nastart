# 2026-10-17 换轨重复请求合并修正与双机短回归

最新普通 Debug 已从 cc64 更新为 **8e71c89113fb**，iPhone 13/iPad 均保留数据覆盖并核到实际首页；iPhone 18 本轮 Bonjour 目标未解析，**新包未装 18**。本轮修正一个重复请求触发点，不宣称 HLS 切轨或大跳转等待已解决。

## 修改与验证

代码检查确认：服务端换轨准备期间，再次点同一未提交的轨道会进入 `pendingSourceChange`，令当前候选的 `candidateStillCurrent` 返回 false，随后重复准备相同选择。

- `PlaybackSourceChangeRequestTracker` 只合并连续相同的待处理轨道请求，不写入新的排队闭包；诊断事件 `source_track_request_coalesced`。
- 请求身份包含音轨、字幕、seek generation、PiP generation。真正改选、原轨返回、Off、seek/PiP 后的新意图、准备结束后的重试均保留；非轨道操作不合并。
- 接入现有 Greenfield Debug 换源队列，在旧任务释放后清 tracker，再应用最后排队的选择。未修改码率、超时、重试、媒体传输、字幕渲染或解码策略；未扩展到 Release 路线。
- **8 项定向测试全部通过**，含 3 项新序列反例及原 PiP/seek/轨道偏好/Off 保护；15 项 preflight、普通真机 Debug 构建通过。没有重跑全套，历史全套 5 项失败仍保留。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，既有 dirty 修改保留。相对 cc64 仅 3/173 输入变化（tracker、Greenfield View、测试），170 保持。Xcode `27.0/27A266a`，构建 `2026-10-17T06:29:01.969488+08:00`；包 `Nastart-Track-Request-Coalescing-Normal-Debug.app`/同名 IPA。源码完整 diff SHA、三二进制/IPA SHA 见[结构化记录](../../../testing/results/2026-10/TRACK-REQUEST-COALESCING-20261017.json)。29 库、deep/strict、profile 目标授权/期限、IPA CRC/内部二进制与输入在冻结和收尾重核；完整包路径及证据只留本机 manifest。

首次测试退出 74：旧 `/tmp` 依赖目录存在但 Package.swift/Git 元数据缺失，尚未编译到 App。保存失败后按原 `Package.resolved` 锁定版本重建，未升级依赖或改锁文件；持久 DerivedData/SourcePackages 的成功命令已写入[运行手册](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)。清理原因未知，不归因磁盘、网络或 App。

## 真机证据与边界

逐机现场名称/UDID/USB 核对，13 为 iPhone14,5 / 16.3.1，Pad 为 iPad12,1 / 18.3.1。先保存诊断、偏好及报告基线，保留容器覆盖后 25/18 项非诊断偏好逐值保持，普通空 env/args 实际首页已看后才播放。13 低亮度未改。

**13 S19/Jellyfin 续播**：t10 有实际电影帧但缓冲，t30/t60 为不同电影帧，t60 可辨简英字幕位于底部，图片已看。t60 KSPlayer/current7465.244/stallCount3；后续约 90 秒仍 KSPlayer/current7479.730/stallCount4、bufferAhead0，不能称连续流畅或等待已修复。HLS 重复选择脚本因引擎前置条件不符退出 AssertionError，未发送轨道选择，原轨未变；此项为 **INSUFFICIENT，未覆盖换源去重的真机路径**。不得将没有进入分支写成去重通过。没有通过测试变量强制换源来混入普通结果。

搜索导航一度停在结果页，实际图/查询与唯一结果核对后改用原生 element click 才进入正确详情；原失败图保留，不是 App 播放失败。播放普通退出回同一详情及最终首页实际已看。

**Pad S01/Jellyfin**：复用已续签固定 fixture，经 Xcode27 XCTest 恢复 WDA，无新建或显式重装 Runner。第一次指定不存在的“从头播放”按钮被守卫拒绝，未发送播放；新窗口使用实际“在 Nastart 中播放”。约60秒样本的自然电影画面、普通退出回《哈尔》详情均已看；t60 KSPlayer/current48.912/stallCount0。早期 t0～5 的采集延迟完整保留，未作为精确首帧或完整显示帧证据；字幕 Off，AUD/连续流畅/完整矩阵未验收。

最终 13/Pad 的 24/17 项非书签偏好及 36/29 原书签轨道保持，0 删/0 增，各 1 项自然位置变化；较本轮开始 Nastart/WDA/Jetsam 均 0 新增，native conditions0、WDA idle10/动画2。双机实际普通首页/播放器关闭已看；13 NAS 正常，Pad NAS 卡仍未连接（Jellyfin 健康在线分列）。

批末按精确父子 PID 主动停止本批 Pad XCTest，exit75 标明 intentional；首次收尾脚本 NameError 在信号前中止，修正后才发送，未误杀其他进程。停 Runner 后原生空 env/args 启动及实际 Pad 首页再次看过，18 项非诊断偏好与审计整份保持，NAS 卡仍未连接。最终参数是请求证据，实际回读属于停止前 WDA 窗口。临时 Mac 防睡眠断言已释放，未改永久电源/网络/配对/亮度。

**18**：系统 DNS-SD 未解析既知目标服务；没有沿用历史地址、重配、发送 Install、启动或播放。本批身份/授权状态未核实，最后确证包仍 03:41 安装的 cc64，先前 XCTest 本机密码提示的完成情况仍未知。恢复可达后先核身份并更新 8e71，再进入播放回归。

下一步优先覆盖真实 HLS 准备期间重复点击同一选择，以及改选/失败重试，核新事件、候选是否保留和实际 cue。大跳转、切轨时延、18 原始字幕/蜂窝故障、CPU/内存、PiP/双入口、菜单偏移、音频环境故障及全部 MI2/PX/UX/CB/Main/竞品/19×4 未完成项继续保留。

本机私有指针 `/tmp/nastart-playback-next-evidence`；旧指针未覆盖。原始偏好/凭据/设备标识/端点/PNG/日志/失败与复用脚本仅保存在该仓库外证据目录。
