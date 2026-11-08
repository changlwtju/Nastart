# 2026-10-14 蜂窝认证准备重叠：三机最新包与定向回归

本批实现并验证上一批的认证准备优化，尚未完成大文件首帧/seek性能验收。历史[HLS服务器诊断](2026-10-14-HLS-SERVER-STARTUP.md)和旧播放流释放修复/失败继续保留。安全汇总见[测试记录](../../../testing/results/2026-10/OVERLAPPING-ORIGIN-PROOF-20261014.json)。

## 源码、构建、测试

- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；dirty iOS diff SHA-256 `5b8afe21d0ce1af67bfcd90380d3d5a51323a58b01952e310d06b817d0b1b346`。普通Debug -Onone，构建 `2026-10-14T06:06:17.061227+08:00`，默认空env/args。本批仅LaunchpadPlaybackCore.swift、LaunchpadView.swift、PlaybackNextCoreTests.swift三个既有输入新增修改，其他170输入保持；不把全工作树历史dirty都算本批。
- 本轮实际377测试/2跳过/0失败、15预检通过、正常构建成功。新增6个受控异步用例证明两请求并发启动、先完成公网不能抢过内网、正内网立即取消公网、内网302/401/403/500不允许切换、旧网络/登录/凭据拒绝、等待内网及等待公网时父取消均传给独立请求。原账号/服务器/网络/取消测试保持通过；本批无旧代码受控负例，不声称已执行。
- 冻结 `Nastart-Overlapping-Origin-Proof-Normal-Debug.app` /同源IPA；绝对路径与173输入manifest仅在本机私有current-package.json。29动态库逐项签名、deep/profile/IPA及链接验证成功，描述文件到期UTC `2026-10-17T22:23:40`。
- 主二进制 `202e26a3d9b6b6bb81a779eebccfd09475cf3bc0d68e3c15e296c731bf2600dd`；Debug dylib `b35fa59db32d3115def38b490999aa7b541eef9ac8db294a5a614e0f2a27a183`；KSPlayer `691afae0a0b9f8870c472449a808530a7a940331cd55d09a95d9fc7f1d37a1d4`。最终173输入/三SHA/deep及git diff --check重核。

## 行为边界

仅当蜂窝选择私有入口、当前自己的主凭据有效、300秒内同登录身份参考新鲜、网络代次已知时，让第一个已保存公网入口自己的身份探测与私有身份探测重叠。各请求独立URLSession，仍先等私有结果；内网可达优先，只有明确transport失败才允许消费公网证据。公网还必须同服务器/账号，发布前后重核当前网络、登录和两端凭据，旧路径响应丢弃；原最多两次candidate尝试不扩大。取消/退出传递到两个请求并在作用域结束清理。

没有改变私有3秒请求/5秒资源预算、媒体Range/缓冲/解码/字幕/轨道/canonical书签、全局client、NAS或Mac网络。App冷启动蜂窝没有新鲜身份参考仍保守拒绝，本批未放宽账号边界。

## 三机最新安装身份

- 每窗前现场核对名称/型号/系统/UDID/连接、最新源与包；原始身份/凭据/偏好只留私有目录。
- USB iPhone13 iPhone14,5/iOS16.3.1：06:08:27保留数据覆盖；25项偏好逐值保持。USB iPad iPad12,1/iOS18.3.1：06:08:18覆盖；18项偏好保持。两机普通空环境实际首页已看。
- **iPhone18 iPhone19,7/iOS27.0/NETWORK：06:09:43无线保留数据覆盖成功**，InstallComplete+lookup；25/25偏好逐值保持，后续启动后再次保持。现有配对直连与userspace RSD/DVT普通冷启动（kill_existing、空env/args）后原生截图实际Nastart NAS首页已看。自动Xcode发现/WDA签名/无线全播放仍未验，不将安装成功推为这些能力已恢复。

## 12个WiFi基础窗口

本次只改JF蜂窝认证准备，S01两入口双USB四窗，加受影响S03/S08/S11/S18 JF双USB八窗。每窗30秒稀疏采样+普通退出15秒，t3/t10/t30/退出选定原图实际看过；缓存未知、无清缓存/条件注入，以下是内部first_frame信号，不是精确显示首帧或速度排名。

| 设备 | 样本/入口 | 内部信号秒 | metrics/蜂窝yes | maxStall |
|---|---|---:|---:|---:|
| iphone13 | S01 /文件 | 1.005 | 2 /0 | 0 |
| iphone13 | S01 /JF | 1.068 | 2 /0 | 0 |
| iphone13 | S03 /JF | 1.353 | 4 /0 | 0 |
| iphone13 | S08 /JF | 3.813 | 2 /0 | 0 |
| iphone13 | S11 /JF | 1.259 | 3 /0 | 0 |
| iphone13 | S18 /JF | 3.272 | 4 /0 | 0 |
| ipad | S01 /文件 | 1.819 | 2 /0 | 0 |
| ipad | S01 /JF | 1.469 | 2 /0 | 0 |
| ipad | S03 /JF | 2.526 | 5 /0 | 0 |
| ipad | S08 /JF | 6.048 | 2 /0 | 0 |
| ipad | S11 /JF | 2.749 | 3 /0 | 0 |
| ipad | S18 /JF | 3.874 | 4 /0 | 0 |

S08两USB t3黑屏转圈/t10黑场/t30电影，不把黑场单独判为加载失败；S18 iPhone13 t3转圈/t10片头/t30字幕片头。选定图退出/更多圆形轮廓完整不等于所有旋转过渡已验收。基本窗口不得回填全L2/L3、连续FPS/听音/HDR/SUB验收。

## 蜂窝定向窗口

WiFi详情准备后原生关闭WiFi，无限速/测试环境，日志URLSession实际cellular字段验证；窗口后WiFi恢复ON和普通首页。

- S03：150.573秒，31/31 metrics 为蜂窝，内部首帧信号距外层触摸 5.608155秒，maxStallCount1；普通退出/选定实际图已看。
- S11：150.545秒，13/13 metrics 为蜂窝，内部首帧信号距外层触摸 5.229393秒，maxStallCount0；普通退出/选定实际图已看。

S03新包contextRequested0.428秒、两身份probe开始0.429秒；3.470秒取到overlappedOwnSession（attempt0/path2），当前公网自身HTTP200、内网URL_-1001，contextProbeMs3036，同服务器账号/当前path2；后续路径观察变化5.961秒。原始KS流，未进入HLS。S11另一文件同样overlappedOwnSession/attempt0/path2、private URL_-1001/public HTTP200，认证准备3059ms；这是分支阳性，不是重复同样本配对。

本轮认证准备约3.04秒 vs上轮约3.60秒、内部首帧5.608155 vs6.113346秒，各单窗且网络/缓存未配对，约0.5秒差异只能作观察，不能认定稳定因果收益或全部准备已消除。上轮1.966秒unreachable不是private UsersMe精确结束时间，不能据此缩短私有探测时长。历史23.943秒HLS首段响应头等待未复现/未修复，不把本次原流结果冲掉它。

## 收尾与下一步

iphone13原24项非书签偏好逐值保持，6项自然书签变化，原S03两入口轨道保持；ipad原17项非书签偏好逐值保持，6项自然书签变化，原S03两入口轨道保持。两USB最终空env/args实际正常首页、播放器关闭、idle10/animation2、原生条件active0；真实AFC报告集合Nastart/WDA/Jetsam均0新增，旧报告和故障保留。Mac网络/VPN/无线配对/WDA/系统/NAS配置未改。

下一步同源/同轨/同起点、相同计时边界重复蜂窝配对，并在HLS慢窗同步取服务器首段就绪、压力与公网交付/多读者，继续seek与续播。S19 128.8GB两入口/HLS/深seek/十分钟、冷蜂窝/异常终止耐久书签、旧119、PadTS02花屏/幽灵seek、13Network/物理内存、增长TS追加/尾部/替换、旋转、全SUB/AUD/HDR/PiP、Lenna竞品完整帧与位移、弱RF/外部WiFi/MTP、全19×4/L2/L3/PX/UX/CB/Main全部继续开放。

私有证据目录 `2026-10-14-parallel-origin-proof-055530` 包含原始日志/媒体路径/身份/偏好/设备图片和工具失败；均未导出到仓库。下次使用设备仍先执行现场最新包门槛。
