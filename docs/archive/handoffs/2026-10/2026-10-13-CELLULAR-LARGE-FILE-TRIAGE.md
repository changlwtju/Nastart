# 2026-10-13 大文件真实蜂窝定位：等待已复现，容器服务恢复待核

记录时间：2026-10-13T08:36:43.937193+08:00。用户路上反馈设备为iPhone18、片目为《碟中谍》《指环王》，具体系列/版本和等待秒数未明确。本轮优先USB13/Pad，未取得18当轮连接、安装身份或播放测量，不将13结果等同18原始问题。

## 最新包与逐机准入

本轮没有iOS源码修改，没有重建或重跑测试。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，已有未提交iOS修改SHA `ac8f176e1d138ab418055d894cddd7d6858dc95d3059b3ed1878a24cc78bb1b1`；普通Debug -Onone，构建 `2026-10-13T07:29:18.221360+08:00`，空环境/参数启动。上轮同源348测试/2跳过/0失败及15预检仅引用，不记本轮执行。173源输入哈希/mtime、29逐库签名、deep/profile及三二进制SHA现场重核；最终173输入、deep及三SHA再核。

包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-13-ts-seek-rootcause-071852/Nastart-Seek-Decode-Metadata-Normal-Debug.app`。

| 二进制 | SHA-256 |
|---|---|
| Nastart | `7cc99e076d3a49293fe664c4d09ab186986bbd8622f661e5ddde39734d5a5370` |
| Nastart.debug.dylib | `0e2bae07cc4f8444b6ba7249cea33ae02c53ab8f350bb175ef1b0bab64bae4c2` |
| KSPlayer | `6be1f6780b3edd377d2ef6ee2e144c9213b831f45969eedbb7f7601b93067559` |

现场名称/UDID/型号/系统/USB连接逐机、各窗及最终重核，原始身份仅私有。13为iPhone14,5/iOS16.3.1，Pad为iPad12,1/iPadOS18.3.1。08:00:39/08:01:07分别保留数据覆盖同签名最新包成功，25/18非诊断偏好安装时逐值不变；实际空env/args正常首页已看后开窗。18本轮发现列表没有新连接，未安装/启动/回归。

## 四个已播放观察窗

全部从原生实际入口启动，稀疏截图与内部时钟分开；下面秒数是触摸请求开始到App内部first_frame事件，**不是实际显示首帧精确耗时**。文件/JF起点不同、引擎不同、缓存未知，不能排名。

| 设备/实际链路 | 入口/动作 | 初始路径 | 内部first_frame | 15秒按钮结果 |
|---|---|---|---|---|
| 13真实蜂窝 | S03文件续播约739.5秒 | AVPlayer/localRemux/localHLS | 8.576秒；App内部tap口径6770ms | 前428ms，独立恢复后280ms；原后退控制TOOL失败保留 |
| 13真实蜂窝 | S03文件从头 | AVPlayer/localRemux/localHLS | 7.802秒；内部6417ms | 前556ms/后591ms，原普通关闭 |
| 13真实蜂窝 | S03 Jellyfin续播约6674.6秒 | KS原流，后自动接手AV HLS | 初始3.326秒；内部2630ms | 接手后两次分别20秒均无engine完成/推进恢复，t20旧画面+spinner |
| Pad WiFi | S03文件从头 | KS原流/localRangeProxy | 2.937秒；内部1808ms | 前2425ms，独立恢复后1964ms；原后退TOOL失败保留 |

13系统WiFi实际关闭，手机VPN初始明确未连接，没有人工限速。三窗最终URL metrics分别66/43/42项全部cellular=yes，0项no；Pad50项全部no。PadWiFi不能当蜂窝。最终原生conditions两机active0；Pad最初用旧Lockdown服务读取失败InvalidService，改官方native RSD读取成功，未修改条件。Mac Tailscale/Shadowrocket保持原配置。

文件续播t7黑底spinner、t8电影+spinner、t10电影无spinner已看；从头t10/30为源片头，不能因片头较暗判黑屏。Pad t10源片头、前进t3电影已看。JF初始t10/30实际电影，接手后前后t20仍旧电影+spinner，最终原生普通关闭已看。稀疏截图不证明完整帧率、声音、字幕准确度或精确落点。

## 等待链路与新增问题

- 文件续播首个所需HLS分片184完整5571ms，其中requestMs3941/responseMs1630，h2连接复用、无客户端backpressure。只能定位到正文前等待较大，尚无NAS/公网/容器分阶段日志，不能直接归因网络或转码。
- JF首次自动降档warmup在alignment阶段40037ms失败；第二次39723ms才对齐，触摸起算150.382秒接手AV HLS。原流正文15.81秒中backpressure7803ms，不能把整段传输时间当纯网络容量。
- 接手后的独立恢复窗口，+15目标分片1695重复请求，-15目标1692重复请求；各20秒没有seek_engine_completed/seek_recovered，遥测waitingToPlay、bufferedAhead0。统计的22.351/38.228秒截断值包含后续操作/关闭，**正式判断只用各20秒观察窗**。原窗口控制揭示/关闭TOOL失败不删除，恢复窗口不倒填原成功。
- 首次文件兼容流续播已将13的原S03书签轨道4/5/字幕开启自然写成0/nil/关闭；安装时原值保留且没有手写偏好或手动切轨。JF轨道1/7/开启保留，Pad原文件/JF轨道都保留。需要查兼容流渲染轨索引与源轨选择的持久化边界，不能宣称轨道继承通过。
- `GreenfieldPlaybackBridge.swift:247`仍用局部/unknown网络上下文，并硬编码isExpensive/isConstrained=false；Launchpad侧NWPath已识别蜂窝与限制。这是确认的上下文缺口，尚不能证明40秒接手或seek等待由它导致，本轮未改。

## 服务中断与尚未执行

开始NAS界面运行时长约4天20小时，后降到3分钟；08:27/28仅DSM入口，NAS在线但JF缺失。用户随后明确 **Container Manager意外重启，要求稍等**；没有确认整个NAS重启，不把界面运行时长变化当整个NAS重启证据。该事件与此前等待的准确先后及因果未知，不能解释全部旧等待。

13计划JF从头窗在NAS登录/恢复-1001超时，尚未播放；恢复WiFi后也曾超时，后来NAS在线首页成功。Pad计划JF从头窗入口缺失，尚未播放。这两项保留NAS_RESTORE_TIMEOUT/SERVICE_UNAVAILABLE，不计播放器首帧或TOOL测量成功。S19本轮未执行。Container Manager恢复前暂停新播放压测，用户不需重新授权已经要求的回归，服务恢复后新建独立基线。

08:37补记：13原生App刷新后JF入口重新出现，图上状态仍未知；此时仅服务发现恢复，媒体库和文件服务健康/中断后播放尚未验。08:39媒体库搜索和S19详情页请求成功、实际原图已看，没有点击播放；文件服务及容器稳定性仍未确认，按用户要求等待。原运行时长字段随后32分钟与之前增长不一致，因此不据此推算重启时点。

## 收尾与接续

最终13原24/Pad原17非书签偏好完全不变；分别2/1条书签自然变化，上述13文件轨道回写异常保留。两机正常包空env/args实际首页/播放器关闭，idle10动画2，13WiFi恢复ON。前后实际Nastart/WDA/Jetsam文件名集合均0新增；旧13 04:32 Network SIGTRAP及物理内存问题未关闭。原控制工具失败、条件服务失败和轨道审计断言失败均留私有，不当App崩溃。

本机私有根：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-13-cellular-large-triage-080013`。原图/XML、身份、完整文件路径、偏好/凭据、报告及脚本只在此；冻结helpers+SHA完成。安全数值摘要：[JSON](../../../testing/results/2026-10/CELLULAR-LARGE-FILE-TRIAGE-20261013.json)。

下一步：先核容器/JF恢复及文件服务，再同文件同轨同位置的新基线与三次配对，补S19、JF从头、远距离seek和十分钟段；对HLS分片首正文/服务端请求及seek请求代次定位，再共享最小修复。兼容流源轨存储问题需独立反例；所有源码改动先测试/构建/签名/逐机覆盖，S01四单元及L2代表集回归。TS02 iPad暂停花屏、真实增长尾部/时长刷新、S19/MTP、18实际UI/自动隧道、SUB/AUD/HDR/PiP、物理footprint、竞品完整帧及19×4/PX/UX/CB/Main全旧账继续开放。本轮没有完整性能或播放PASS。
