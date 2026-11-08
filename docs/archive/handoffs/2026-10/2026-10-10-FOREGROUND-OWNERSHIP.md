# 前台刷新取消与任务归属

本轮完成PX-20/PX-21的前台刷新入口取消定向修复。开始前已取消的前台任务仍会占用90秒冷却、发起可达性I/O；合法下一次刷新被跳过。直接refreshDSM还会替换folderSourceID。8个受控场景先固定原行为，2场景/5断言失败；最小在refreshForForeground与refreshDSM入口拒绝Task.isCancelled后全通过。

另6场景覆盖旧可达性响应与新前台标记、同SID新登录代际的迟到snapshot、取消后的失败/快照、合法刷新/冷却、恢复登录分支旧cleanup。模拟I/O、可控返回门及测试时钟，不靠睡眠凑顺序，不访问真实服务/切真机账号/清登录。现有token及迟到返回规则通过专用证据，本轮不增加自动重登、重试或网络参数。完整XCTest 298项/2跳过/0失败；15预检/18工具测试及普通Debug构建通过。

中间包2d10/bc17/85e1的测试接口重复创建客户端，代码复核发现后修正为默认可达性与快照复用原dataSource/client。中间8场景/298测试、三机安装、Pad两前台/三目录/两播放窗完整留在原私有目录，不能充当最终源验收。最终源码重新完整测试、构建、逐机现场核包覆盖安装和L1回归；90秒冷却及五分钟新鲜度保持。只AppStateStores与NonPlaybackPolicyTests较上一签收08e7构建改变，其他未提交修改保留。

冻结HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS diff SHA-256 `5ec2da7280c45943a286ad76e1c0b47fb34badcd55fe18a4cdccebd034f84290`，构建 `2026-10-10T18:21:10.548811+08:00`，配置 `normal Debug -Onone; empty launch environment`，包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-foreground-ownership-final-181404/Nastart-Foreground-Ownership-Normal-Debug.app`。173输入、29库独立和deep签名、有效profile（三目标）、链接均核对。profile到期UTC `2026-10-10T22:03:15`。

- Nastart SHA-256 `ba52bac0047a93a11312a59deae37bfeb74f5b310a8e10f735ee3884afba096d`。
- Nastart.debug.dylib SHA-256 `5e0cdd388f3cb7e2625d5b4d6c6796e2acd93a3d0476816e19dc7d0efd384f71`。
- Frameworks/KSPlayer.framework/KSPlayer SHA-256 `eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`。

| 设备 | 现场身份 / 连接 | 最新包安装与执行时间 | 当前结论 |
|---|---|---|---|
| iPhone 13 | iPhone / iPhone14,5 / 16.3.1 (20D67) / USB现场重核 | 2026-10-10T18:21:48.706118+08:00 保留数据覆盖，25非诊断偏好安装及初始正常启动后一致；本轮三哈希签名包 | 空环境/参数实际启动；两次正常前台返回、三目录重进、S01双入口两60秒窗；最终核对 2026-10-10T20:32:44.330567+08:00 |
| iPad | iPad / iPad12,1 / 18.3.1 (22D72) / USB现场重核 | 2026-10-10T18:21:30.693963+08:00 保留数据覆盖，16非诊断偏好安装及初始正常启动后一致；本轮三哈希签名包 | 空环境/参数实际启动；两次正常前台返回、三目录重进、S01双入口两60秒窗；最终核对 2026-10-10T20:32:45.049423+08:00 |
| iPhone18 | iPhone / iPhone19,7 / 27.0 (24A8428) / 无线，未在USB列表 | 2026-10-10T18:22:09.496500+08:00 相同签名包AFC + installation_proxy InstallComplete/Lookup成功，25非诊断偏好一致 | 原生正常启动4016、DVT InvalidService、截图不可用；启动及实际UI未验证，播放NOT_RUN |

每次切换/用例先核源码173输入、包三哈希、现场设备身份、安装凭据；缓存/负载/温度未完全控制，家庭Wi-Fi串行，无网络条件注入或测试启动环境。Pad自动后台两秒返回、手机按Home并按运行状态等待后台后两秒激活，为UI定向证据，不能证明真实取消竞态或119恢复（归属由受控fixture单列）。手机自动deactivate HTTP500和三次即时状态断言失败作为工具记录保留，待状态读到后台后继续，不能冒充App崩溃或丢失。双机返回图的动画边框、手机返回时DSM/JF灰态、手机目录边缘过渡都保留，不据此验收滚动或动画。

最终源四S01文件/Jellyfin 60秒完整观察窗、四实际电影正文、四原正常UI退出；实际对应标题和继续观看核对。报告按原退出边界分析，历史事件ID排除，本批目录响应24 success（手机13、Pad11），API失败0，读取失败0，可见播放器错误0。

| 设备 / 入口 | trace | 首次观察到时钟推进，动作后秒 | 最大采样stall |
|---|---|---:|---:|
| ipad / files | B79C29D2 | 2.660329 | 0 |
| ipad / jellyfin | B6ECAEB3 | 2.761126 | 0 |
| iphone13 / files | 9AA6CDC3 | 2.677391 | 0 |
| iphone13 / jellyfin | 060D1F7B | 2.315789 | 0 |

时钟不是屏幕首帧；取消-999/POSIX/方向信号按原时序保留，不因后续成功丢弃。正文截图与零计数不证明逐帧/音频/字幕/HDR/性能。原失败弱网/ordinal0等窗口不得以这些正常窗替代。没有Lenna/DS One公平配对，本批不作流畅度或竞品排名验收。

最终双机当前源/包/USB重核，实际正常首页NAS/DSM/Jellyfin在线、播放器关闭、环境{}参数[]，原生网络条件active0，WDA ready、idle10/动画2恢复、无重装。冷启Pad初始DSM/JF灰态、手机初始NAS未连接（后续再核在线）及Radarr/Sonarr、Pad Prowlarr橙警告保留，不声称所有服务绿。最终偏好私有保存；书签正常变动不冒充安装偏好不变。

下一步：补手机退出保存收敛精确边界、当前会话119原因和原弱网/旧ordinal0等待，另核连接监控/服务健康探测任务归属。已发出logout的服务端顺序、历史前台丢失及1002ms等待未关闭。18待USB后重新现场核最新包、正常启动/实际UI。S03/S08/S11/S18格式族、S19深seek/十分钟/PiP/MTP、外部Wi-Fi/弱蜂窝、完整帧/实际位移、声音字幕/HDR、Lenna/DS One、全部PX/UX/CB/19×4/正式L2/L3/Main保持开放；本轮只有L0/L1定向，不推算总矩阵通过率。未提交或推送。

最终脱敏报告：[FOREGROUND-OWNERSHIP-20261010.json](../../../testing/results/2026-10/FOREGROUND-OWNERSHIP-20261010.json)；本机私有证据 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-foreground-ownership-final-181404`，原始UDID/偏好/凭据及工具绑定仅留本机，helpers有摘要，重跑先重新门槛。收尾 `2026-10-10T20:33:24.364644+08:00`。
