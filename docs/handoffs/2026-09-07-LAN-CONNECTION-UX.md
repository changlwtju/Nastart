# 2026-09-07 内网连接与登录体验

## 最新范围

用户暂停 IPv6 外网验证，恢复以内网为主。优先优化登录等待与连接表单。用户提供了两张竞品截图，明确要求填写项直接、简洁展示，不接受将选项收进高级设置。ADR 0002 继续适用，播放只优化 Greenfield。

## 本轮修改

- DSMConnectionFlowView 采用直接展示的分组表单：局域网发现、协议、主机、路径、端口；账号、密码、验证码；证书与记住信息。协议改为单行菜单，地址自动识别内外网，无需额外选择连接位置。统一标签宽度和输入起点，补充必填/可选提示。保留完整地址自动拆分，不新增高级设置。
- 首次登录原先认证后仍等待 FileStation 登录、完整 NAS 快照和服务端点探测才退出。现在与缓存登录共用一个流程：认证成功即发布会话、进入主界面，完整数据在后台替换。旧会话完成时检查 SID，避免覆盖后续连接。
- App 启动恢复在会话建立后允许显示主界面，临时快照不再强制遮住整个 App。数据加载仍使用已有刷新状态。
- 切换会话时失效旧刷新任务，并清理其刷新状态，避免悬挂指示器。

## 同一工作区此前修改，仍需内网真机验收

- 缓存快照不再代表 NAS 在线；DSM 轻量探测失败直接标记不可达。前台约每 15 秒加请求耗时进行探测；服务健康探测覆盖发现的服务。不是后台常驻监测。
- 服务地址按当前 DSM 路由选择已知内外网端点，保留反代地址供切换，外网路由不探测私网候选。
- 设备文件 Greenfield 播放先验证候选 Range URL；ISO 请求进入 Greenfield。Jellyfin ISO 接入已有 ISOPlaybackAdapter。该适配器仅支持其已有 ISO9660 能力，不可声称支持全部 UDF/蓝光 ISO。

## 验证与待办

- 最新设备 Debug 构建成功：tmp/connectivity-20260907/build-login-final.log。
- preflight、git diff --check、播放 FFmpeg 链接隔离检查通过；本轮未重复完整播放矩阵。
- 安装成功：tmp/connectivity-20260907/install-login-final.log。真机已核对连接表单与主界面临时快照展示。UI 证据在 tmp/connectivity-20260907/login-form.png、login-after.png。WDA source 与截图中的协议/页面状态不一致，本次脚本输出的 3.52 秒计时无效，不可作为登录性能结论；仍需可靠测量内网首次登录及完整数据加载耗时。
- 继续测试首次无缓存登录、已有缓存恢复、离线状态与恢复、设备文件播放、用户实际 Jellyfin ISO。原有 HLS 内容映射与音字幕/PiP 成果见 09-06 后续交接，不从 NEXT-CHAT 的旧状态重做。

构建使用 /tmp/NastartConnectivity20260907Derived，依赖缓存使用 /tmp/NastartGreenfieldABiPhone13Derived/SourcePackages；不更新包版本。工作区包含大量此前未提交修改，勿重置。

## 后续优化：服务地址识别等待（本轮已安装与内网验证）

实际日志显示，认证与容器清单返回很快，但之前 mapServices 在 reverse_proxy.loaded 后长时间等待。原服务探测使用 URLSession.data(for:) 等整个响应，request timeout 是空闲超时，且会等待所有低优先级候选；共享 session resource timeout 为 65 秒。

- 服务探测增加独立总时限（沿用各请求 1.5/2.5/3 秒），外层取消会传递给 URLSession；取消后不再继续 GET。
- 普通服务/Jellyfin 候选均保留原先优先级；已得到最佳可选结果后取消更低优先级探测。
- 新增 endpoints.completed 阶段计时、snapshot.completed 总计时。
- 无网络模拟验证：抽取当前 Swift 方法执行 URLProtocol 成功/不结束响应/父任务取消；另验证高优先级慢成功胜过低优先级快成功、优先项失败回退、慢候选取消、全部失败。脚本与日志在 tmp/connectivity-20260907/probe-{deadline,priority}-test.*。这不是完整 XCTest 或真实网络矩阵。
- Debug 设备构建、preflight、播放链接隔离检查通过；安装完成，日志 build-probe.log / install-probe.log / linkage-probe.log。
- 新版 iPhone 内网自动恢复实测：主会话认证约 1548 ms，FileStation 会话约 1220 ms，完整快照 1812 ms，其中服务地址识别 58 ms；返回 14 个容器、47 个服务记录、12 个共享文件夹。总登录起点至快照发布约 4707 ms。只是一轮样本，不作为所有网络场景保证。
- 证据来自 probe-prefs 中诊断日志，快照起点 date=810420263.121678，结束 date=810420264.947202，refresh.applied=810420264.975881；本次日志为 connectionLocation=local。真机 UI 读取也确认 DS918+ 及 CPU/内存/硬盘数据与服务列表已展示。

仍待：首次无缓存全流程、离线/恢复、设备文件播放与实际 ISO 样本。此前 WDA 截图/source 不一致的登录计时仍作废，本轮性能数字取 App 内部日志，不依赖该计时。
