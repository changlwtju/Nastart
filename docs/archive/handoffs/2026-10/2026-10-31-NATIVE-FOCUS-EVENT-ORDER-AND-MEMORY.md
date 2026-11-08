# 原生焦点事件顺序与返回记忆

更新：2026-10-31T14:11:47+08:00。接[弹层反例批](2026-10-31-DETAIL-PRESENTATION-RETURN-AND-FOCUS-REGRESSION.md)。此前两轮无改善后停止猜测调参，本批先采事件证据，再针对实际先后顺序修正；不抹掉上批及本批失败。NAS恢复期仅本地代码/任务模拟器，0真机发现/控制/安装、0NAS/旧凭据/源写/播放；既定模型分工，无后台任务。

## 不改变决策的诊断

新增MediaDetailFocusDiagnostics，仅DEBUG且tvOS编译、两early离线fixture显式opt-in；记录序号/uptime、原生绑定与session实际焦点/请求/owner、map版本、控制器与body呈现窗口、方向事件/恢复check/commit/skip。最多2048行，600权限临时JSONL；目标先映射为本进程数字，不输出姓名、路径或来源ID，无账号/网络/存储对象。写入非Observable，不增Published状态、焦点赋值、重试、Timer或Task；最终正式Scope默认不开启。日志仍可能影响调度，因此另做关闭日志的回归，不能说采样绝对零开销或时序完全不受影响。

初诊断窗口临时显式开启bool以复现；最终改为fixture且带--offline-focus-trace才开启，正常入口和Release无日志sink。一个测试wrapper仅追加该离线参数并调用原动态用例，不改变断言/等待、不算新验收覆盖。Scope观察绑定通过autoclosure避免未开启时读取引入新依赖；正常observer=nil。没有新隐式启动环境或用户偏好。

## 抓到的两处失配

未修改决策的动态窗口失败，50事件/1控制器：seq29–30原生已由简介移到文件一，但request/owner仍为简介；seq32源简介的down事件此时才到，binding已经文件一，旧相等guard丢弃。第二次down同理seq35–39实际文件二、请求仍简介；文件二失效时seq43按错误owner回简介。说明该窗口不是控制器重建丢状态，而是源事件到达时原生焦点已移动。对照sheet窗口104事件/1控制器通过，多数事件在原生移动前进入语义处理；原生编辑up则可晚到。两窗口仅说明已观察顺序，不推断所有设备/系统时序。

第一修正只移除MediaDetailFocusTarget中“实际绑定仍等于源控件”这一guard；按接到事件的控件ID处理已有语义移动，其他请求/revision/native编辑保护不变，不加新焦点赋值。关闭诊断的6例为5过1失败，分段失效/重排已越过，删除人物A时仍失败：期望C，实际请求/焦点B。保留原包/输入/日志/xcresult，未调大等待。

于是仅采同断言wrapper，149事件/1控制器再失败：seq115–116原生先到A，requested仍B；seq118–121源B的left回调正确请求A，但实际焦点早已A，因此不会再触发第二次recordFocus(A)。只在recordFocus与requested相等时更新记忆的旧策略导致lastPerson仍B。seq131删A后选中了仍存在的旧记忆B，而非第一现存C。原生提前落点与语义请求“已确认相同”这一边界此前单元未覆盖。

第二修正在MediaDetailFocusSession.request中，目标合法且focused已等于target时调用现有remember；不把所有原生瞬时落点都记住，只记已被语义请求确认的目标。不更改移除fallback策略。新增2个单元显式模拟recordFocus先于源move、且之后没有第二次onChange：人物移除回C、文件头上移回已确认第二分段。39旧+2新=41定向单元通过。

## 关闭诊断的回归

最后同一445输入、无trace参数、空自定义环境下，6个既有唯一XCUIRemote用例全过：动态能力/人物重排移除、sheet两种关闭后编辑及分段返回、全屏两种关闭、12文件/18人物滚动、原多文件/原生编辑、只读无播放按钮。另一fresh任务实例再跑动态+sheet两例均通过，因上批已有间歇反例而安排确认；这2例不膨胀唯一数，不扩展为8唯一样本。不再重复已过窗口。两次最终正常运行均没有生成诊断文件，安装前后主/dylib hash同、偏好哨兵保持且无额外应用键。

3个诊断窗口（动态失败、sheet通过、第一修正动态失败）+第一普通修正6例5/1+最终6例通过+fresh确认2例通过，共6任务实例，全部finally关删且fresh无；其他模拟器不动。沿TV3.8GiB启动/2GiB运行预算，不清用户缓存/旧包。诊断baseline、第一修正失败及第二诊断包/hash均保留。附件实际查看数量与位移文本在[安全结果](../../../testing/results/2026-10/2026-10-31-native-focus-event-order-and-memory.json)，只判目标可达，不判中间焦点或流畅性能。

## 源码、构建与范围

5既有源/测试修改+1新诊断文件，总445输入，其余原439同；UITest原断言/等待边界不变。正式NetworkLocalMediaDetail读取任务、校正sheet/播放cover、头像loader及播放路由/引擎/缓存/能力/回调、iPhone/iPad布局未变。Jellyfin用同一纯Map，其TV专属View焦点还未迁到Scope；不能说所有入口焦点实现完全相同。本批是共用网络详情组件事件处理，不是播放链路优化，VIDEO_PLAYBACK_PIPELINE不改为UI结论，114格无新P。

最终TV UI build、移动模拟器Debug、移动签名Debug与无签名Release过；TV正常Debug因找不到开发描述文件失败（exit65），只读核本机2份profile无该TV bundle匹配，未下载/生成/改签名配置。随后TV明确CODE_SIGNING_ALLOWED=NO的Debug及无签名Release编译过，不能作为可安装包。最新移动普通候选30 Mach-O核签过、空参数/环境、未装；TV仅保留上批444输入旧签名包，root清单明确与本批445输入不匹配及签名阻塞，不声称本批TV候选核签或嵌入检查已完成。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`、继承改动保留，root源码/包清单和current-focus-event-trace-private更新。Release不包含诊断writer，不把无签名Release构建写成可安装包。最终两正常模拟器窗口与最新移动候选均为445输入；电视旧真机包仍444输入，历史失败源码另外保留。

| 包（TV为旧包） | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T14:04:11.194524+08:00 | `963c9647ac0cef41af31e27a8989403a25edff2e4136bc9ab51ca017da618b87` | `5655da06a12042c76603ff2b9881ce9007e56b834d4c36ea6c73ea19792c1ddb` | 30 |
| Apple TV旧包：444输入，本批未更新 | 2026-10-31T12:36:33.579791+08:00 | `baf21f8bd1dc412cdd55140b840474d15afe60d4f01b1349e23c864d8a223cfc` | `41c0e4cc8218d0eed04ed7e401e0a91290d78d6acc4c0a163016e305e3c1e0c5` | 27 |

此处只接受已覆盖离线方向/更新/返回边界；正式model页、真实异步资料、图片/演员头像和海报闪动、真实编辑器/播放器进出、手机Pad触控与位置、触摸板/中间焦点帧时间仍未验。真实同名同角色人物身份限制仍在，不能由数字trace证明解决。上批失败只补后续处理链接，不删原结果。

## 接续

这组离线故障已有事件依据及关闭诊断后的复核，不再重复调参或扩展无关播放逻辑。可转独立三端连接/目录表单的可读性、错误与无障碍细节；真实图片、播放返回及弱蜂窝等安全NAS环境恢复后fresh设备核包再验。
