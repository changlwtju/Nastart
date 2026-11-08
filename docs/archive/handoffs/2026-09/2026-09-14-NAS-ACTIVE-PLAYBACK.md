# NAS 第四批：快速重开后的本地更新资格

关联 PX-21/PX-20，状态继续进行中。基线为 b4c789a 加 work/nas-20260914 前三批未提交修改；本批也仅在本地，未提交/推送。

## 变更卡

反例：A tracker 停止事件已入队或停止后刷新已发出 → B tracker 实际开始 → A 的本地快照任务/刷新响应才执行。两者属于同一认证会话，第二批账号 token 不能区分，第三批单 tracker 队列也不能保护跨 tracker 本地写回。

成功条件：仅当前实际开始的 tracker 可以发布停止快照及由它触发的继续观看刷新；预热未开始的候选不抢占更新资格；退出登录后的旧 tracker 即使迟到 started 也不能成为新账号当前播放。正常 stop 的服务端上报和资源清理继续保留，不通过吞掉旧 stop 来冒充服务端顺序已修复。

## 实现

- `PlaybackActivityScope` 是同一 library store 共享的带锁身份状态，包含认证 epoch、活动 ticket；创建 tracker 仅 prepare，started 回调才 activate。
- 本地快照执行前核对账号与活动 ticket。旧 stopped 请求仍发送，但返回后只有当前 ticket 可以启动列表刷新；refresh 开始及响应发布前再次核对 ticket，避免刷新期间出现新播放后仍使用旧结果。
- client 替换/清空时 invalidate，旧 epoch 的迟到 activate 无效。
- 资格检查在对应写回前执行；它不构成播放器线程、MainActor 和服务端之间的全局事务，极近时点的交错仍须并发/集成验证。

新增 4 项 XCTest：预热候选不抢占；快速重开拒绝旧快照；登出后旧 activate 无效；没有更新的 resume 请求时，旧 stop 刷新仍因播放身份变化而失效。测试覆盖身份规则，实际 UI/SDK 路径留给 Mac。

## 超时核对

`LaunchpadView.swift` 的 `makeClient` 使用 ephemeral URLSessionConfiguration，设置 request=20 秒、resource=60 秒、waitsForConnectivity=false，并将该 configuration 传入 JellyfinClient。此为源码配置证据，不等于实测每个 SDK 调用一定在该时限返回，也不能把 request 配置解释为固定总耗时。未新增 timeout、sleep 或重试参数；实际超时/错误推进通过受控响应在 Mac 核对。

## 验证与停止条件

本批 preflight、诊断脚本 3 项 unittest、Agent 4 项 unittest、git diff --check 全部通过。四批共新增 16 项 XCTest 均未在 NAS 编译或执行，不能计入原基线 78 项通过，也不改变 76 个矩阵单元。

Mac L0：正常构建、播放/非播放 XCTest（包含 16 项新增）、MainActor/Sendable 编译诊断及链接/签名核对。受控响应分别延后旧快照、stopped、resume 响应，在新 tracker 开始后释放；验证旧结果不回填，正常最新 stop 仍刷新；候选预热失败不破坏当前播放，退出/重新登录不接受旧 epoch。

L1：S01 四单元和 S03 两入口，快速退出重开、从头播放、暂停定位退出、换流准备取消。L2：S19 深位置和 S01 双设备相关退出/重开；实际声音、字幕、断点与账号隔离分别验。正常上报不能因本地资格保护丢失；必要检查完成后结束本修复，不增加片源参数。

## 剩余边界与下一步检查点

- 多 tracker 服务端上报仍可能交错；本批保护本地，不保证服务器最终位置。首页独立刷新并不携带播放 ticket；服务端旧状态仍可能被后续正常刷新读取。
- store 仅跟踪最近开始的一个 tracker。多播放器并行、PiP/换流的实际 start/stop 先后，以及旧 started 真正发生在新 started 之后的情况需 Mac 验证，不能当作全局播放协调器已完成。
- 原 JSON 解码 SIGBUS 仍需核对 ASan 包/进程并捕获，不认定已修复。
- 四批核心改动已形成一个待验证集合。下一步优先回 Mac 编译并执行受控时序集成测试，再决定跨 tracker 服务端协调方案；当前 NAS 不继续无证据扩大核心并发改造，可先完善离线日志配对和证据清单。
- 手动清晰度保持隐藏，代码与接口保留；未改传输/解码参数和设备文件 pending seek 保存条件。
