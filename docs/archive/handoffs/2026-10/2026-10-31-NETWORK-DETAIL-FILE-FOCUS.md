# 网络媒体详情的多文件焦点共用

更新：2026-10-31T09:02:47+08:00。接[顶部操作批](2026-10-31-TV-DETAIL-ACTION-FOCUS.md)。NAS恢复期仍仅本地代码/专属隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/源写/播放，既定模型分工，无后台任务。

## 实际实现

MediaDetailFocusMap追加默认空的fileChoices，保既有Jellyfin调用兼容；顺序为顶部动作→纵向文件选择→横向人物→相关/重试→文件信息。文件上下按原顺序，不把文件行变成横向卡片；演员上移回有效的最后文件选择，失效记忆退到列表末位。无顶部动作时entry可落可选文件/人物/文件信息，不捏造播放按钮；contains和recoveryAfterContentChange只恢复确已消失的原焦点/待落焦所有者，其他有效或原生控件不被抢焦点。原24单元保持，新增5例含16种空区组合、文件上下/记忆、只读不造目标、动态内容移除与无动作fallback，共29过。

新增包内MediaDetailFocusScope/Context/Target/FocusedPeople，正式网络页与隔离场景实际共用FocusState、移动/记忆、滚动、水平人物入口与异步落焦。map变化令revision失效旧排队落焦；有上下文的演员行defaultFocus使用当前请求，避免系统沿旧人物记忆覆盖目标。它只处理UI，不创建model/client/store/vault/网络/媒体Task。Jellyfin继续用同一纯图，其现有专属UI状态和读取/播放不改。

NetworkLocalMediaDetail在TV使用该Scope，iOS context为nil；页面原顺序保留。可播放分段使用原canPlay筛选的ID，ISO/来源不提供播放的行仍保说明而不生成焦点目标；动作/人物/文件折叠头接相同上下文，人物ID含位置/姓名/角色/服务人物ID，资料替换不把旧人物目标盲套新条目。MediaDetailFileRow和MediaFocusablePerson新增可选外部焦点，默认行为/样式保持。折叠内修改资料按钮继续用原生空间导航，父级方向处理仅在实际绑定目标匹配时接管；不更改编辑动作。

原metadata/credits两个task、sheet/fullScreenCover、canPlay/播放限制/文件说明、播放选择和编辑回调、人物图片loader逐字或原表达式保留。没有新请求、播放路线、媒体能力、自动连播或远端写入；文件顺序/原文件结构不改。iPhone/iPad未增加遥控逻辑，触摸实际回归仍未验。

## 验证与失败留存

network-focus-files/read-only由已有early offline根选择，先于TVAppState，不调用普通根或旧client fixture。固定合成行只内存计数；合成简介选择后移除只模拟资料更新，不代表正式展开简介会删按钮。两新XCUIRemote用例使用真实共享Scope和文件/人物/折叠控件，验证分段往返和记住第二分段、Select只计数、只读不是Button、折叠后编辑可达且上移回折叠头、无可播放内容时初始焦点为文件信息、顶部操作移除后落回有效文件。未点正式编辑sheet或创建播放器。

首次6例为5过1失败：从编辑返回文件信息再上移，实际落第二人物而非请求的第一人物；测试树保存了该实际焦点。原失败包/442输入/日志/xcresult均私有保留，未将失败排除或修改断言。修正有上下文人物区域的defaultFocus后，第二轮该断言通过，继续执行到顶部操作移除又失败：实际文件二、请求文件一；诊断文字证实目标请求正确；结合源码判断，补救仍依赖已失效的旧context，缺少新revision的补交。第二轮仍5过1失败，包/源码hash/日志/xcresult也保留。新增仅针对实际移除所有者的new-revision异步补救后，第三专属实例相同6例全部通过（4旧+2新），不膨胀为18唯一用例。最终运行前后安装主/dylib hash同、重新取app/data容器核两合成哨兵保持/无额外应用键；三实例均finally关删且fresh无，沿3.8GiB启动及2GiB运行预算，不清用户缓存/旧包。

成功附件已实看，实看数量与观察见[安全结果](../../../testing/results/2026-10/2026-10-31-network-detail-file-focus.json)。这些证明合成页最终焦点与选择，不是完整model页面/真实图片/真实服务器资料替换、长行、触摸板、Menu返回、中间焦点或帧时间验收；第一次失败和所有旧待验保留。

双端模拟器Debug/29纯规则测试过后补TV异步revision与人物defaultFocus，由最终UI build-for-testing和后续正常候选重新编译；纯规则/参数不变，未重复单元测试。最终双端签名Debug/无签名Release串行过，30/27 Mach-O hash/完整签名及TV嵌入库过。候选空参数/环境、未装真机；UI与候选同442输入（7既有+1新、其余原434同），HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承改动保留。cp -cpR仅请求克隆，不声称实测节省。原始包/路径/偏好/日志/标识仅本机current-network-detail-focus-private；root清单更新。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T08:58:59.973718+08:00 | `415b809e68dbd4d1eafdc366e49e1af5804aed2d9d56afdc1f3e58c2cdbbf6d6` | `d81ae9e46b11c1aa555df590a6f549a44badf5524c6b4d487278623d48b857d5` | 30 |
| Apple TV | 2026-10-31T09:00:53.077385+08:00 | `a5200665aa8b14f960a196d20a34e24d8592fbb9e625e159c5b8fcb0b7feda05` | `d8537495c729ae95724662db09921611005d7bf68eab6a2b157fa1d57dfbf272` | 27 |

114播放格无新P，播放路线/引擎/缓存同前，无需将此UI批写作播放优化。

## 接续

下一核对共用Scope在文件可播放能力/人物名单替换时的实际UI恢复、长列表目标滚动和原生编辑边界，继续用无client合成状态；纯规则已覆盖但不能等同UI。完整网络详情、正式编辑与播放返回、图片闪动和真实服务均等待安全环境后逐机fresh包核对。
