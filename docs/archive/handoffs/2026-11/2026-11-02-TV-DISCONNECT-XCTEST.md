# TV确认框原生遥控测试：首轮定位失败、第二轮4/4通过

2026-11-02，接[实际组件抽取](2026-11-02-TV-NATIVE-DISCONNECT-CONFIRMATIONS.md)。私有首轮根 `/tmp/nastart-tv-disconnect-xctest-root-path`，最新轮 `/tmp/nastart-tv-disconnect-xctest-path`。不运行TVAppState/普通入口、NAS或真实账号退出。

既有TVLaunchTests新增4项：三类确认（设置NAS、连接NAS、影音授权）标准字号，加影音授权辅助字号。通过真实XCUIRemote选择打开，取消后旧反馈/次数不变；Menu关闭且App仍前台、返回发起按钮焦点；确认后仅一次合成动作/新反馈；再取消保当前反馈。只证明正式modifier的原生分派与本地注入动作，不证明真实清凭据/网络事务或完整读屏/帧时间。

首轮build-for-testing成功，4项均实际打开了native sheet，但4项都在取消焦点断言失败。失败AX层级证实：SwiftUI标识符在内层Button，焦点在包裹它的UIKit外层Button；两个动作在水平行，取消在左、确认在右。原测试误对内层断言hasFocus，误假设上下布局。完整xcresult/源/日志及4个原生弹窗PNG导出保留，不能称产品焦点失败或通过。

只修测试：从当前sheet内含标识子按钮的外层Button检查焦点，用真实左右方向；未改产品/宿主/注入回调。第二轮单独目录保留源清单，只有UITest一文件变、其余445输入同，build-for-testing通过。

第二轮07:23:10开始、07:25:29结束，原始xcodebuild exit0、XCTest四项0失败（测试121.108秒）；已逐项断言取消/Menu不调用动作、返回发起焦点、确认仅一次并清旧反馈、随后取消保新反馈。三类标准字号及影音授权large通过；这是实际modifier＋合成闭包，不运行三段真实账号/NAS回调。源码446输入及安装二进制哈希前后同，合成哨兵偏好保持/0额外键；finally shutdown/delete均0、freshAbsent=true。07:38本轮接续又核该命名模拟器为0、未见该批自有构建/运行进程。共享结果见[两轮结果](../../../testing/results/2026-11/TV-DISCONNECT-XCTEST-20261102.json)。

首轮finally已停App/删实例，哨兵同/0新增偏好。两轮结果分列，不覆盖初失败；第二轮不扩大为TV真机、真实凭据清理/网络事务、全应用焦点/完整读屏/帧时间验收。

第六批密码审查已读：它给出的UIKit/SwiftUI/contentType假说均非新运行证据。一次对照现象只能约束当窗条件，不能按方案中的“成立”直接推广成内部因果定论；仅计事件也不足以辨别SwiftUI中间空值。后续实验仍保留无原文/长度/精确偏移、相同正式表单与独立归因对照的边界，不能强行追加旧密码或关闭首次编辑/显隐反例。
