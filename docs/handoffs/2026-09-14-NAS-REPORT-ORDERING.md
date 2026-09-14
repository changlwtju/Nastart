# NAS 第三批：单 tracker 有界上报顺序

关联 PX-21/PX-20，继续进行中。基线为 `b4c789a` 加当前 `work/nas-20260914` 的前两批未提交修改；本批也未提交/推送。遵循 [分层开发流程](../development/playback-development-workflow.md)，不修改片源参数或清晰度能力。

## 变更卡与确定性反例

原 tracker 在解锁后直接回调：start 已登记但尚未执行回调时，另一线程可能先交付 stop；重入回调也会使 stop 在 start 回调返回之前执行。即使回调顺序正确，原 `makePlaybackTracker` 对每个事件分别新建 Task，progress 和 stopped 网络请求仍可同时在途。

本批成功条件：同 tracker 回调按锁内登记顺序交付；网络发送最多一个在途；未发送进度合并为最新位置及暂停状态；stop 丢弃未发送进度并保留最终位置/失败标记，重复 stop 与 stop 后事件无效；报告函数处理错误返回后队列继续。缓冲容量不随连续进度增长。退出本地快照不等待网络。

## 实现

- `MediaPlaybackEventBuffer` 在每层最多保留两个待交付事件：start + 最新 progress，或 start + stop。正在处理的事件不在缓冲内。首次 stop 终止接收，start 重复和未开始的 progress 被忽略。
- `MediaPlaybackTracker` 在原状态锁内登记事件，单个同步 drain 在锁外交付；重入/并发生产者只登记，不递归交付。回调完成后 drain 再取下一事件，锁不跨回调持有。
- `MediaPlaybackReportQueue` 用锁保护缓冲和 drain 标志；只有队列从空闲变为有任务时创建一个 worker Task。worker 在 MainActor 上逐个 await 现有 `reportPlayback`，网络 await 不持有锁。`@unchecked Sendable` 的可变字段全部由锁保护；报告闭包为不可变 MainActor/Sendable 闭包。
- stop 的本地详情快照在 admission 时单独调度一次 MainActor 更新并核对认证会话；网络 stop 不再重新发布快照。用户退出后的本地反馈不受前一个请求耗时影响。
- 第二批认证会话身份检查保留。失效账号的排队报告在真正处理时被拒绝；旧在途请求仍使用旧 client，其完成不能刷新新会话。

## 4 项新增 XCTest 与实际边界

1. 1000 次 progress/重复 start 仍只保留有限事件，最新暂停状态被保留；stop 的 0 秒和失败标记覆盖未发送进度，重复 stop 不变更结果。
2. 首播前 stop 不产生虚假报告，迟到 start 无效。
3. start 回调中重入 progress/stop：必须先返回 start 回调，再交付 stop，无递归乱序或死锁。
4. 用 continuation 挂起 start，期间入队 1000 次 progress 和重复 stop：不提前发送后续报告；模拟报告函数处理传输失败并返回后，继续一次最终 stop。该测试验证失败处理返回后的推进，真实 SDK 错误路径仍需 Mac 集成验证。

三批共新增 12 项 XCTest，当前 NAS 未编译/执行。测试不是跨格式/声音/字幕验收证据。

## Mac L0/L1/L2 清单与停止条件

- L0：Swift 编译、播放/非播放 XCTest，特别检查 MainActor/Sendable 编译诊断，执行 12 项新增测试。
- 受控网络：挂起 start 或 progress 响应，连续暂停/进度/退出；确认同 tracker 请求无重叠，stop 等待在途结束后发送且携带最终位置。让前一请求返回错误或超时，再确认最终 stop 仍会尝试；重复 stop 不重复发送。收集请求开始/结束、session/trace 与资源释放顺序，日志脱敏。
- 取消/身份：在请求在途及排队时退出账号，再登录同/不同账号，确认旧排队事件被拒绝，新 tracker 不借用旧 client；本地停止快照不等待 HTTP，账号切换后清除。
- L1：S01 四单元、S03 两入口，正常播放→暂停→完成 seek→退出→重开，另测尚未完成 seek 退出。Jellyfin 确认服务端断点，设备文件确认本地断点与轨道不回归。
- L2：按会话改动映射补 S19 深位置与 S01 双设备退出/重开专项；没有设备则保留待验。必要回归无新增失败且上述规则成立后结束该修复，不追加片源参数。本批不进行 L3、不改 76 单元状态。

后续 [第四批活动播放身份](2026-09-14-NAS-ACTIVE-PLAYBACK.md) 已补本地快照/停止刷新资格并核对源码 timeout 配置；实际 SDK 超时与跨 tracker 服务端顺序仍未验证。

## 未覆盖的风险

- 队列粒度是一个 tracker；快速换流/重开创建的新 tracker 有自己的队列，跨 tracker 及跨设备的服务端写入顺序仍未统一。本批不宣称同账号所有播放事件全局串行。
- 同 tracker stop 会等待已经发出的请求返回/报错；没有额外添加固定延迟、自动重试或应用层超时。若 SDK 请求不能正常超时，worker 可能一直等待，但缓冲仍有界；须核实实际请求 timeout 后再决定超时/取消方案。
- 失败请求在服务器是否已提交可能未知，不能把客户端串行直接等同于服务端事务；不做无依据重试。
- 编码器停止、代理注销、渲染资源销毁仍不等待 stopped 网络请求；不把资源清理变成网络依赖。
- 同账号不同 tracker 的本地停止快照仍可能交错，需后续播放会话身份设计。队列无性能加速结论，也不证明原 JSON 解码 SIGBUS 已修复；继续保留 Mac ASan 捕获要求。

## NAS 实际验证

修改后 preflight 全部通过，诊断脚本 3 项 unittest、Agent 4 项 unittest 全部通过，`git diff --check` 通过。环境没有 Swift/Xcode，新增 4 项 XCTest 尚未执行；前两批 8 项同样仍待 Mac，不继承基线 78 项通过作为本次结论。
