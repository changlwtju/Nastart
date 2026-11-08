# 退出登录期间的新会话保护

本轮完成显式 signOut 的定向修复与 L0/L1 回归。旧包清本地状态后顺序注销 DSM 与 FileStation；第一步 HTTP 响应挂起时，新登录可能复用旧 FS SID，旧任务随后会错误发送 FileStation 注销。现在每个待发送角色都读取当前连接，避免清理其在相同服务端点复用的 SID。默认退出行为、清本地凭据的时机与其他未提交修改保留。

新增五个真实 URLSession/URLProtocol 受控 HTTP 场景：复用为新 FS、新主会话、旧 DSM 注销失败后仍复用、未复用旧 FS 应继续清理、不同服务端点同 SID 应继续清理。以保留原行为的可注入 I/O 接口先跑，五项中三项失败；最小改用已有受保护 logout 后五项通过。挂起响应由测试手动释放，不以休眠凑竞态；新连接、登录代际及任务归属均检查。只使用模拟地址及测试模拟器空凭据，未在真机退出账号或切换账户。

最终本轮完整 XCTest 290 项、2 跳过、0 失败；15 预检和18脱敏分析工具测试通过，普通 Debug -Onone 设备构建成功。较前一冻结构建173输入中仅 NASConnectionStore.swift 和 NonPlaybackPolicyTests.swift 改变，播放器、传输、续播、重试及超时参数未改。工具模块导入路径与一次证据文件名引用错误已修正，原失败记录保存在私有目录，不能计作 App/播放失败。

冻结 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS diff SHA-256 `08e70b66f7a2c7ae007b606cd62ae0ee0028f98bdda8fd4c42bbf8dc7365c7c8`；构建 `2026-10-10T17:07:23.847455+08:00` / `normal Debug -Onone; empty launch environment`；包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-signout-ownership-170316/Nastart-SignOut-Ownership-Normal-Debug.app`。173输入、29个库各自签名与 deep 验签、三目标 profile 和链接均核对；profile 到期 UTC `2026-10-10T22:03:15`。三二进制 SHA-256：

- Nastart：`4272d44baa06a3cfdf11313891faa8051f64b20e9dc68672cb447bf256d76840`。
- Nastart.debug.dylib：`ed72484327f5d0b46e9c4dced3b9923ddff97918a3c13adb93a32fdd8fc5569f`。
- Frameworks/KSPlayer.framework/KSPlayer：`eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`。

现场身份、覆盖安装、启动结论（UDID与原偏好/凭据只留本机私有证据）：

| 设备 | 现场名称 / 型号 / 系统 | 连接 | 最新包核对与执行时间 | 启动与本轮回归 |
|---|---|---|---|---|
| iPhone 13 | iPhone / iPhone14,5 / 16.3.1 (20D67) | USB、当轮重核 | 2026-10-10T17:10:06.353451+08:00 保留数据覆盖4272/ed72/eda1成功；25项非诊断偏好安装及初始启动后一致 | 空环境/参数实际启动；三目录重进与四60秒播放窗；最终核对 2026-10-10T17:30:57.826086+08:00 |
| iPad | iPad / iPad12,1 / 18.3.1 (22D72) | USB、当轮重核 | 2026-10-10T17:09:06.786569+08:00 保留数据覆盖4272/ed72/eda1成功；16项非诊断偏好安装及初始启动后一致 | 空环境/参数实际启动；三目录重进与四60秒播放窗；最终核对 2026-10-10T17:30:58.536673+08:00 |
| iPhone 18 | iPhone / iPhone19,7 / 27.0 (24A8428) | 当轮无线配对，未出现在USB列表 | 2026-10-10T17:10:06.258327+08:00 同包AFC + installation_proxy InstallComplete与Lookup；25项非诊断偏好一致 | 原生安装/启动4016，DVT InvalidService、截图不可用；正常启动/实际UI未验证，播放NOT_RUN |

每次切换设备和每个播放用例先重核源码输入、包哈希、当轮设备信息及安装凭据，再正常空环境冷启；两设备串行，无人为网络条件注入。目录退出重进捕获到过渡左侧窄条（手机三次、iPad第三次），只确认返回根目录/重进media及未显示目录错误，不验动画流畅或请求中途取消。

双机 S01《哈尔的移动城堡》及 S03《碟中谍3》，各文件/Jellyfin入口：8个完整60秒观察窗、8张实际正文、八次原普通UI退出，对应标题及继续观看均实际核对。报告以原退出边界分析，历史事件ID排除；本批新目录响应共38成功（手机19、iPad19），API失败0，读取失败0，可见播放器错误0。前包窗口未沿用。

| 设备 | 素材 / 入口 | trace | 首次观察到时钟推进，动作后秒 | 采样最大stall |
|---|---|---|---:|---:|
| ipad | S01 / files | 3DEB5DE3 | 2.548858 | 0 |
| ipad | S01 / jellyfin | 6709F6B8 | 2.62162 | 0 |
| ipad | S03 / files | 7654B225 | 4.305651 | 0 |
| ipad | S03 / jellyfin | 32EF6F39 | 3.379991 | 0 |
| iphone13 | S01 / files | DD1D3F93 | 2.26835 | 0 |
| iphone13 | S01 / jellyfin | 41833974 | 2.21393 | 0 |
| iphone13 | S03 / files | 48A2FACF | 3.764404 | 0 |
| iphone13 | S03 / jellyfin | 72FADA4C | 2.535446 | 0 |

这些时钟数值不是实际屏幕首帧。启动阶段 POSIX clientBodySend/clientFailed、上游取消-999及方向更新失败按原时间完整保留，不能凭后续成功删除。稀疏正文截图与零采样计数不能证明完整帧、滚动、声音、字幕、HDR/DV正确或性能提升；S03截图中可见字幕不等于完整字幕验收。Wi-Fi/NAS缓存、负载、设备温度未经完整配对核实，不与Lenna/DS One排名。

最终两机现场源码/哈希/USB身份再次核对；实际正常首页 NAS、DSM、Jellyfin 在线，播放器关闭，环境{}、参数[]；原生网络条件active0，WDA ready、idleWait10、动画2，无WDA重装。冷启初始DSM/JF灰态及其他服务橙警告保留，不声称所有服务通过。最终偏好另存本机，播放书签正常变动不冒充安装偏好不变。

边界与下一步：本修复保护尚未发送的注销角色；已经发出的注销请求与之后SID复用的服务端执行顺序仍未证明安全。测试中的模拟119不是真机119根因再现；本批无119不关闭历史故障。接着核对前台刷新与登录代际的任务归属，再定位119及手机书签保存收敛、原弱网/旧ordinal0等待；历史中间包前台丢失及1002ms等待保留。iPhone18待USB接入后重新确认最新源/包、正常启动与实际画面。S19大文件深seek/十分钟/PiP/MTP、其余格式/外网弱蜂窝、完整帧及Lenna/DS One竞品和全PX/UX/CB/L2/L3/19×4/Main仍开放。没有提交或推送。

脱敏汇总：[SIGNOUT-OWNERSHIP-20261010.json](../../../testing/results/2026-10/SIGNOUT-OWNERSHIP-20261010.json)。本机证据 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-signout-ownership-170316`；原始设备偏好、诊断及工具绑定仅在该私有目录，helpers带摘要可追溯，重跑前重新执行门槛。收尾时间 `2026-10-10T17:31:46.140538+08:00`。
