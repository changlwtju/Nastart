# 电视详情顶部操作的可达与移除恢复

更新：2026-10-31T08:21:16+08:00。接[相关重试焦点批](2026-10-31-TV-DETAIL-RETRY-FOCUS.md)。仍仅本地代码/任务专属隔离模拟器；0真机发现/控制/安装、0NAS/旧凭据/源写/播放，既定模型分工，无后台任务。

## 实际实现与边界

TVDetailView顶部详情错误在reload开始时清空，重试按钮随即消失；此前lastActionFocus仍可能记住该ID，defaultFocus直接引用过期记忆。简介折叠按钮也会因资料/宽度变化而移除。此前actions只处理下移，左右交给系统空间导航，详情retry单独一行可能被略过。

MediaDetailFocusMap新增preferredAction：只接受当前动作中的记忆，否则用首动作；新增recoveryAfterActionChange：只有实际焦点（优先）或无实际焦点时的待落焦请求属于旧动作且已移除，才返回仍有效的动作。不因过期requested抢走人物、相关、文件或其他有效动作的焦点。原有相关retry的移除规则不改。动作左右现按当前actions顺序（播放/从头播放/简介/详情重试）移动并钳制边缘，使独立一行的详情retry仍有明确入口；上下区域语义同前。

TVDetailView实际使用合法defaultFocus和动作列表onChange，始终规范化lastAction；需要补救才改focused/requested。点击顶部详情重试先把记忆/请求/焦点落到播放，再执行原reload UUID一次；异步滚动落焦提交前再核目标仍在actions中。资料/相关读取task、播放器cover、其他TV页面与移动生产视图保持逐字同；播放路线/引擎/缓存无变更。

## 验证

5新纯规则用例覆盖动作水平次序/边缘、重试与简介移除、有效记忆、其他区域与过期待落焦、无归属更新和空动作。合计24单元（19旧+5新）通过。双端模拟器Debug过；随后仅TV异步落焦有效性保护微调，由UI build-for-testing重新编译最终TV源码，参数/纯规则未再变更，未重复单元测试。

既有无client早期隔离TVDetailFocusOfflineScene新增detail-focus-actions：真实MediaDetailActionRow、retry样式、FocusState与同一规则，固定人物/相关卡及内存操作。合成简介按钮选择后模拟资料更新而移除该按钮，用于测试onChange恢复；不代表真实简介展开会删除按钮。新XCUIRemote用例依次播放→简介→演员→简介→详情重试，Select后retry不存在/播放有焦点/receipt=1；再选择合成简介更新使其消失，验证播放有焦点，演员上下往返仍回播放。加上原三相关retry回归，共4唯一UI用例一次运行全过。

新场景在App early offline分支先于TVAppState/普通根；iOS同参数仅隔离提示，不回正常根。未使用旧构造client的tv-exit-probe。fixture无client/store/vault/UserDefaults/网络/媒体Task；不把它当作完整正式详情页或真实资料请求验收。

本次UI运行前后主/dylib hash一致，测试后重新取app/data容器核身份和两合成哨兵，偏好保持且无额外应用键。1自建实例finally关删，fresh清单无；沿3.8GiB启动及2GiB运行预算，未清用户缓存/旧包。两个成功附件已实看：新增场景最终播放焦点/简介与retry消失，receipt在图外仅由UI断言证明；原场景第二相关作品边框/receipt1可见。没有中间焦点事件、实际长横排、触摸板/Menu/返回/帧时间和实体遥控验收。

441输入，7既有源/测试修改，其余434输入同；UI包与正常候选源清单一致。双端签名Debug/无签名Release串行通过；30/27 Mach-O hash/签名与TV嵌入库核验过，cp -cpR请求克隆但不声称测得空间节省。候选正常参数/环境为空，未装真机，root清单更新。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留继承未提交改动。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T08:18:11.721215+08:00 | `7a6cc0435362bfae23b2827becde20439455960e726184e81fddcb68f1d6a284` | `c93df34969007727f493d7d0adf7b0727f98bb8180c31809e9fe2670c0aae120` | 30 |
| Apple TV | 2026-10-31T08:20:03.438814+08:00 | `c1bd8190ae539fab4d84e105b6c85ea291756afcfe8b07f9af37e2be5a7d2e41` | `d84febf1a2e43ab4eacefa41848533c14941cdfddf92754a8f45a8b9a40db792` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-31-tv-detail-action-focus.json)。原始包/源码diff/清单/日志/xcresult/截图/偏好/设备标识仅本机私有current-tv-detail-action-focus-private。114播放格无新P，真机/NAS/资料头像及旧失败均保留。

## 网络详情复用评估与接续

已读NetworkLocalMediaDetail：单文件/多文件与播放能力有条件动作；fileSelection在credits前，人物行只读聚焦，文件Disclosure现无显式FocusState，模型/回调仍承担真实选择。不能把当前Hero→人物→相关→文件图直接硬套多文件场景，避免跳过主片/分段按钮。下一优先补共享焦点图的有序文件选择区域及稀疏组合覆盖，再按现有可播放条件接TV网络详情；原文件选择/媒体能力/播放回调不改。真实metadata更新与返回/触摸板仍待安全环境，不能关闭完整三端体验验收。
