# 密码选区匿名诊断与连续协作启动

2026-11-02，Asia/Shanghai。[结果](../../../testing/results/2026-11/2026-11-02-PASSWORD-SELECTION-DIAGNOSTICS.json)。接[原密码反例](../2026-10/2026-10-31-PASSWORD-INPUT-EVENT-DIAGNOSIS.md)；Claude第三批MineView独占期间，Codex只改NetworkMedia的PasswordInputDiagnostics.swift，不改密码控件/焦点/提交/存储逻辑，不作第三轮猜测修复。

## 新增诊断与边界

仍仅DEBUG+iOS，早期合成连接页显式--offline-ui和--offline-password-trace同时启用。增加selectionKnown/selectionEmpty/markedTextPresent布尔量、native.change事件和sourceToken匿名编号；不知道选区时known=false，不能将empty=false解读为已选文字。token弱映射、1024事件上限和0600私有JSONL保持，不读text/长度/选区偏移/位置/通知内容，不改delegate、不加焦点赋值/重试或定时器。只接当前探针窗口的密码控件，已知控件脱离时仍可关联结束事件；不会因两个window都nil误接未知控件。

446接受输入仅该既有诊断文件改/445同，Mine起始SHA不变。移动/TV模拟器Debug、移动/TV device Debug无签名及双方Release六配置全部exit0；Release移动主二进制中诊断文件名/Probe marker均无。未新跑无关导出或全量预检，旧5类失败保持。

## 实际合成窗口与新增线索

一个本方A16/iOS27模拟器，当前新包main a14854ba92b04aa772c266475ad036ae35538e8aa9bca2687e6afb2a79765fa5、dylib960ad1300387215e4139f86a4dbf5f2ebd170c42d04a1a2225e04bc72b20f7c8。仅connection-edit/中文/辅助字号2，先带trace后同包去掉trace，不启动普通根、真实存储或NAS。工具轨迹实际AX/截图，不虚构另存PNG。

带诊断窗口共31事件，5个native.change、9个sourceToken事件、3个匿名控件；JSON顶层/控件字段白名单核对、类型正确、文件0600，合成密码/账号/地址/路径字面标记不在记录里。初始原合成密码在首次点屏幕键盘字符时变为单字符，**这发生在任何显隐切换之前**。当时采样token1一直firstResponder/secure，selectionKnown/selectionEmpty为true，clearsOnInsertion/clearsOnBeginEditing均false，连续两次native.change。不能用“本次已观测全选”解释，也没有will-insert内部事件/精确选区位置证据，不能将所采空选区推广到所有中间时刻或定为UIKit内部根因。

随后显隐产生token2非secure、未firstResponder，Swift focus到none、keyboard.willHide及token1 native.end；旧焦点丢失反例仍在。手动重新聚焦明文控件后一次字符追加成功，记录markedTextPresent=true，实际拼音候选可见；这属于组合输入状态，不等于已提交文本。再切密文会结束/提交该组合，native.change与sourceToken可关联，不把它当纯ASCII插入。未读/保存原始输入内容。

去掉诊断参数、删的仅本自建容器已私存的诊断文件后同夹具正常再启动：首次输入覆盖合成初值及显隐丢键盘仍复现，证明本轮不是修复通过；结束后无新诊断文件。两合成偏好哨兵保持、0额外键，finally停App/shutdown/delete均成功，fresh自建实例不在。没有真机、旧凭据、NAS/媒体/剪贴板/源目录操作或后台采集。

本批尚未冻结新正常签名包/安装真机，13/Pad旧a03b/6a58不称当前诊断源码的最新回归。Claude第三批已在接续中交付，将与其接入完成后统一冻结最终包，避免立即过时的重复包；当前仅证明此诊断快照六配置/合成证据，不能用于随后Mine改源的UI验收。私有指针`/tmp/nastart-password-selection-path`。

## 用户新授权和下一阶段

用户明确要求完成任务自动按“接下来干什么”推进，已启动线程Goal（非定时任务/heartbeat）；按官方长期任务能力跨回合接续，保留本项目权限/暂停边界。用户同时授权仅在Mac现有Nastart的Claude对话发送任务/必要继续指令，不对Claude做其他操作。Codex只定位现有对话、填第三批任务、发送并核消息实际已提交/“Claude正在回复”，没有改模式/设置/建会话或操作其它任务。指令不含原始证据、设备偏好、凭据或聊天历史，仅分配文件/目录和边界。

本轮原先说“只能在当前回合接续”过于绝对，官方文档核实Goal后已向用户更正并实际启用，不靠文档授权假装自动后台。消息已发送与对方已交付分别记录；当前第三批0535报告已存在，接下来核补丁、释放后审查接入并准备安全主题卡片宿主。只发一条自足任务、不重复催“继续”。自动接续由Goal状态管理，不新建周期轮询。

旧密码问题仍开放；下一需要针对首次插入/初始化差异作受控原生输入研究，当前数据不支持再猜焦点延迟。先接入已交付第三批，真实Pad/完整读屏和114格播放不升级、不关闭需求编号，NAS恢复仍须用户确认。
