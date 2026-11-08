# 详情弹层返回与焦点回归：未解决，停止调参

后续处理（2026-10-31）：[原生事件与记忆](2026-10-31-NATIVE-FOCUS-EVENT-ORDER-AND-MEMORY.md)先采实际事件，针对源事件晚于原生移动及已确认目标未记忆两处修正；41单元、关闭诊断6唯一UI+fresh2重复例过，仅接受覆盖的离线边界，本文失败记录保持。

更新：2026-10-31T12:37:51+08:00。接[动态详情批](2026-10-31-DYNAMIC-DETAIL-FOCUS-AND-LONG-ROWS.md)。该批4例成功窗口保留，但本批复现反例，不能继续称动态恢复已稳定解决。NAS恢复期只本地代码/任务专属模拟器，0真机发现/控制/安装、NAS/旧凭据/源写/播放；无后台任务，既定模型分工。

## 本批保留的实际工作

新增Debug early场景network-focus-presentation与2条XCUIRemote测试，使用正式MediaDetailFocusScope/文件选择/折叠控件；NavigationStack内只持内存Bool/合成文件标识/返回次数。sheet与fullScreenCover分别打开纯文字和关闭按钮的合成目的地；关闭按钮和onExitCommand只调用dismiss。不构造正式编辑器、播放器、model/client/store/vault或网络/媒体Task，不提交资料，不读取媒体。iOS同参数显示隔离提示，因此不能声称手机/Pad触控、滚动位置或弹层已验。

新测试分别走第二分段→文件信息→原生编辑→sheet按钮关闭和Menu关闭→编辑→文件头→原分段，以及第二分段→合成fullScreenCover→按钮关闭和Menu关闭→第二分段→顶部；都核实际hasFocus、关闭后的不存在及onDismiss次数。不是实际播放器关闭/Menu/首帧或资料保存测试。

最后源码只改3个Debug夹具/UI测试文件，444输入中其他441个均保持，包括正式页面、FocusMap/Session/Scope、metadata/credits任务、sheet/cover、头像loader、播放路径/缓存/能力/回调。此前39项单元实现与测试hash同，本批未重跑；不将旧单元通过冒充本批UI通过。

## 两轮失败及回退

第一轮4例3过1失败（最终接受源码）：新sheet完整用例和fullScreen完整用例、旧只读例通过；旧动态例phase1人物重排失败，期望人物B，实际第一分段，诊断请求与owner也回第一分段。此时production焦点源码与上一成功批逐字相同，证明已有间歇/生命周期问题，并非只有新测试代码才失败。

源码发现人物焦点标识稳定但ForEach仍按位置复用，尝试正式人物行及动态fixture改同一稳定标识，断言与等待边界不变。第二轮4例2过2失败：动态例更早在第二分段失效时失败，期望第一分段、实际简介，诊断ownerFile=false；新sheet例两次返回编辑、次数=2均已通过，继续上移到文件头再回分段时落第一分段而非记忆的第二分段。fullScreen及只读完整例仍通过。不能把sheet关闭边界本身误写为失败点，也不能把整个扩展路径写PASS。

按项目两轮无改善停止调参，撤回稳定ForEach尝试，正式源码完全恢复。最终444输入与第一轮逐项相同；没有第三轮相同猜测或调大超时。两轮包/源码hash/实验源码快照/日志/xcresult/失败AX附件均私有保留，3张成功附件实看；失败依据实际树/断言，未声称看过失败视频。安全数据见[结果](../../../testing/results/2026-10/2026-10-31-detail-presentation-return-and-focus-regression.json)。

现有证据说明实际聚焦、请求与所有者在SwiftUI交互阶段可能失配；仅纯会话模型测试不足。究竟是原生方向处理未同步语义记忆、视图生命周期重建或异步事件顺序，需要有事件边界的诊断，尚无确定根因。不要继续给defaultFocus、延迟或重复restore打补丁，也不能仅因下一次偶然通过关闭问题。

## 构建/清理与接受边界

最终接受源码的TV UI编译来自第一轮；实验撤回后按hash核等价。移动模拟器Debug和正常双端签名Debug/无签名Release串行编译过，正常候选30/27 Mach-O签名/hash与TV嵌入库过，但UI仍有已知失败，包清单明确仅为编译/签名候选，未装真机。根清单/current-presentation-focus-private记录包与444输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承改动保留。两实例finally关删、fresh无，安装前后hash/两偏好哨兵保持、无额外应用键；其他模拟器不动。沿原启动/运行磁盘预算，不清用户缓存或旧包。

| 候选（非UI通过） | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T12:34:42.660269+08:00 | `6acac5c2ce40b26a376996cb3678137f247fdaab4b882bc41929a2acf16cb930` | `d0e2da148d44f1c0c9a9825972600852f33235a81abf717b8651e4f03c0e158d` | 30 |
| Apple TV | 2026-10-31T12:36:33.579791+08:00 | `baf21f8bd1dc412cdd55140b840474d15afe60d4f01b1349e23c864d8a223cfc` | `41c0e4cc8218d0eed04ed7e401e0a91290d78d6acc4c0a163016e305e3c1e0c5` | 27 |

不关闭真实编辑/播放器返回、海报闪动/演员头像、手机/Pad触控及位置、触摸板或性能验收。0播放，114格无新P；播放路线/引擎/缓存未动，VIDEO_PLAYBACK_PIPELINE不改为UI实验。

## 接续

这条焦点支线暂停调参。先整理事件诊断方案：需同时记录方向来源、实际FocusState、请求/owner、View/控制器生命周期与map版本，采样不改变焦点，区分用户移动与系统临时回退；明确可复现边界后再做一项针对性修正。可先推进与此独立的三端表单可读性/无障碍细节，NAS/真机继续等安全恢复。
