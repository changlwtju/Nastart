# 主题装饰示意图字号与 Claude 排队状态（进行中）

2026-11-02，Codex 接续。[上一实际组件窗口](2026-11-02-CLAUDE-BATCH3-INTEGRATION.md)在 phone/Pad 辅助字号下确认：真实卡片说明与状态已分行，但固定高度的装饰 Artwork 内假标题和服务行随辅助字号放大而被裁切。不是 NAS 状态，也不是实际服务控件。私有证据指针 `/tmp/nastart-theme-artwork-path`，旧包与旧失败保留在前批私有目录。

## 修改与核对

只改 `MineView.swift` 的 `LaunchpadThemePreviewArtwork`，在装饰子树固定 `.dynamicTypeSize(.large)`；卡片标题、说明、状态及正式预览外部文字继续使用系统字号。该图已被隐藏于 AX，仍保留完整示意结构，未改变主题应用、权益、账号或用户偏好。相对前批冻结清单 1 改 / 445 同，原 HEAD/index 同，Claude 独占的四个文件未变。

串行移动 Sim Debug、unsigned Debug、Release 均过。同一冻结模拟器 dylib f487a8f1 用自建 iPhone13/iOS27 中文辅助字号和 A16 iPad/iOS27 英文辅助字号各一窗口实查：三张示意图标题/指标/服务行不再被大字裁切，外部真实说明和状态仍辅助字号完整显示。phone 的 Glow 与 Pad 的 Stack 放大图完整，合成预览及返回保原选择；AX 合并标签仍无假 DSM/百分比等示意状态。两实例 finally 停 App/shutdown/delete、fresh 不存在、哨兵原值同、0 新偏好、无 trace。截图/AX 在 CUA 工具轨迹，没有独立 PNG。

结果见[结构化记录](../../../testing/results/2026-11/THEME-ARTWORK-SIZING-20261102.json)。这是两指定窗口的实际组件观察，非全主题/字号/方向笛卡尔积，非正式账号或主题应用、完整 VoiceOver、手势/帧时间或真机验收；普通 wheel/drag 旧 0 位移失败保留。

正常 Debug -Onone 已于06:41构建通过，子进程显式 Xcode27/27A266a，无全局切换或 provisioning 更新。冻结 APP/IPA，深度及逐个核签30个 Mach-O/29库、IPA归档和446当前输入通过；主二进制 SHA-256 `56d9431957728339a65f2b34191567f724e723aeabc84d5d18137a9699bc19e8`，debug dylib `26b87a16d0e1648977024acff0f87df1272ecb500313af50cb782fa1658d6b54`。签名到2026-11-08T01:08:19Z有效；仅历史13目标核profile覆盖，不代替下一设备fresh身份。包在本批私有证据根`Nastart-Latest-Normal-Debug.app`及同名IPA/current-package.json，当前iOS diff `4f97dc8ebfaccb6d24ef886cfac625c3d8deb6efdcebd8a037d98ebe85f67fd0`。未安装真机、未启动普通根，下一逐台fresh身份/进程/签名覆盖再有界隔离启动。

## Claude 第五批的实际状态更正

此前“提交成功”仅证明消息已进入队列。此次 native AX 现场显示：第五批消息有“排队消息”操作，“立即发送”禁用；前一批正在等“Claude 想要完全控制您的计算机”的“允许一次／拒绝”弹窗。独立第五批目录仍 clean、没有交付，不能记为实施中或交付已收到。

用户只授权 Codex 发任务消息、不作其他 Claude 操作；Codex 没有点击权限按钮、改模式/设置、取消旧任务或重复发消息。已一次告知用户自行处理弹窗，Codex 继续独立离线任务。第五批四文件写入许可保持，未擅自回收或接管。消息正文在现有对话中仍排队，不需要重复提交。

NAS 测试继续暂停，iPhone18 hands off；本批尚未操作任何真机。完整读屏/触摸/帧时间、真实账号/主题应用和原密码问题仍开放，114 格没有新 P；目标继续 active。

本批收尾：604文档/3753本地链接0缺失、diff空白检查过；446输入/原index同、Claude四文件未变，0构建worker/自建模拟器遗留。下一直接逐台fresh真机核身份/进程/新包保留覆盖；Goal active，本阶段未完成审计，不因Claude等待停止独立工作。
