# 2026-10-01 iPad 卡滞与竞品矩阵接续

## 用户要求

继续未完成的 iPad 滑动优化，自动判断卡滞是否解决并排查其他页面。今日 USB 为 iPad 9 /18.3.1 与 iPhone 13 /16.3.1。新增 Lenna 主对照（两机均有）、DS One/Jellyfin/网易爆米花扩展矩阵。详见 `docs/testing/COMPETITOR-DEVICE-MATRIX.md` 的 CB-01～20 与 JSON 模板；已纳入 AGENTS.md 和正式功能矩阵。

## 到目前为止的有效证据

- 昨晚 `dd26df8f…` 包 12 次海报页滑动，57.545 秒原始采样记录 521 个前台合成 hitch、最长 233.253 ms；97 个 Nastart 相关卡顿提交片段，最长 60.251 ms。原脚本将多层/重叠时段相加得到 779.864 ms/s，此数不是去重后的时间占比，不直接用于改善百分比。明确复现严重卡滞，但脚本当时尚无自动位移证据检查。
- `dd26df8f…` 媒体页 30 秒主线程约 30027 个 1ms 运行采样；静止 12 秒约 12043。栈主要为 SwiftUI AttributeGraph、布局、导航栏偏好更新，已被媒体页盖住的启动台仍反复计算。
- 仅将同源码改为 Debug `-O`、关闭 opaque type erasure 的 `3e09c3a8…` 包，静止 10 秒仍约 10042 个主线程运行采样，未解决循环；不能把构建优化当作修复。
- 尝试媒体页呈现时撤掉背景启动台 toolbar 的 `cd3c554e…` 包，静止仍约 9656 个主线程采样；已撤回该改动。
- 返回服务详情，8 秒仍约 8044 主线程样本。问题至少涉及媒体页及其背景导航/详情链路，不能归因于图片下载，也不能宣称所有页面均已测。
- 曾编译/安装 `708b7d9e…` 固定 hero 画布实验；尚未形成有效验证，该猜测已从源码撤回。目前正在隔离 iPad NavigationSplitView 与 TabView 导航根，临时环境开关 `NASTART_UI_TAB_ROOT=1` 仅用于因果对照，收尾需移除实验路径或固化经验证实现。

## 自动判定脚本

`scripts/ui_scroll_probe.py` 使用 WDA 12 次相同手势 + Instruments Animation Hitches，保存前/中页面 XML、截图、动作时间、完整 trace 和 JSON。校验前台 App、至少两项稳定文本发生 ≥40pt 位移、>=10 秒完整动作覆盖；合并重叠 hitch 区间。工程门槛 <=5ms/s、单次 <100ms，否则 FAIL；缺证据 INSUFFICIENT。脚本已支持 bundle/process 区分竞品。4 项工具单测通过（区间去重、空数据、忽略工具栏/重复标签、XML 引用解析）。

原始证据仅本机 `/tmp/nastart-scroll2-*`、`/tmp/nastart-oct01-*` 与 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/`，不入库。源码/项目记录与所有既有修改未提交。当前尚无新版本滚动通过结论、无竞品定量优劣结论。

## 导航根隔离与正式候选

- `14d6fa84…` 临时 TabView 导航对照，约 8 秒主线程样本降至 546（包含启动后短暂活动，不能与稳定期直接算精确 CPU 百分比）。原 NavigationSplitView 叠加各页 NavigationStack 的路径静止仍持续运行；这是针对 App 当前导航组合的实机证据，不泛称所有 NavigationSplitView 都有故障。
- 后续海报对照的 trace 传输损坏，工具明确拒绝判定，未将其视为 PASS。脚本已改为让固定 60 秒录制自然结束，避免 SIGINT 截断；所有临时 toolbar/hero/环境分支均已移除。
- 正式候选：iPadOS 18+ 使用 `TabView.sidebarAdaptable`，保留顶栏/侧栏切换和各标签独立导航栈；旧 iPadOS 保留原兼容分支，iPhone 导航不变。Apple API 依据：https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable 。
- 正常 Debug `-Onone` 包已构建、严格验签、preflight 通过，保留数据安装 iPad 和 iPhone 13，正常启动。iPad PID 8618；该包不需要实验环境变量。
- 当前包 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`，dylib SHA-256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。尚在逐页自动回归，不能提前判流畅通过。
- iPad Lenna 已进入服务器列表，存在“我的 Jellyfin”配置；尚未核对与 Nastart 是否同端点/媒体源，不因已配置就认为满足配对条件。
