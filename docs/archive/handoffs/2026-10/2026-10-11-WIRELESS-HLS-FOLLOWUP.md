# 2026-10-11 无线发现更新与S03长窗口接续

完成本阶段：2026-10-11T19:03:22.361212+08:00。接续[固定点交接](2026-10-11-STARTUP-FIXED-POINT.md)。本轮没有修改App源或播放策略，保留其他未提交修改；只更新证据和交接。原始设备名称/UDID/IP、配对记录、偏好、诊断、图片和回执仅留本机私有目录 `2026-10-11-wireless-hls-followup-185012`；[脱敏摘要](../../../testing/results/2026-10/WIRELESS-HLS-FOLLOWUP-20261011.json)。

## 当前源码和安装包

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，当前iOS差异SHA-256 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`。普通Debug -Onone，构建 `2026-10-11T17:36:31.155727+08:00`、冻结 `2026-10-11T17:38:03.703738+08:00`；包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.app`，IPA `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.ipa`。173输入逐项SHA、iOS差异和三二进制哈希重核；覆盖安装前重验App deep/strict签名、29库strict及有效profile/目标设备包含关系。没有源码晚于产物而沿用旧包。

- 主程序 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`。
- debug dylib `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`。
- KSPlayer `9764ba65bd197b17931a6fff5220d2883cab665daf93bcaaaa99a972de5f2c6b`。

322测试/2跳过/0失败和15预检是此前最终同源结果，本轮未重跑、未重新构建。测试环境变量和App参数为空；本轮没有偏好直接写入、网络整形、网络配置变更、取消配对或卸载。

## 逐台现场状态

| 设备 | 本轮现场身份与连接 | 最新包核对 | 启动/回归范围 |
|---|---|---|---|
| iPhone18 Pro Max | iPhone19,7，iOS27.0，完整UDID实时唯一匹配，USB缺席，已有配对Wi-Fi直连 | 2026-10-11T18:55:55.995495+08:00 AFC/installation_proxy保留数据InstallComplete及安装lookup成功；IPA中三二进制与当前已验签包一致；25项非诊断偏好完全不变 | 用户仍要求稍后验UI，本轮未启动/截图/播放，不计正常启动或最新包回归 |
| iPad | iPad12,1，iPadOS18.3.1，名称/UDID/USB现场重读 | 18:51保留数据覆盖成功，16项非诊断偏好一致 | state1终止后空环境普通启动、实际首页检查；S03普通90秒观察和原UI退出；最终首页/关闭/空环境/active0/idle10动画2均实核，其他服务卡片未知 |
| iPhone13 | iPhone14,5，iOS16.3.1，名称/UDID/USB现场只读确认 | 本轮未覆盖或证明当前安装身份 | 未发App命令，无本轮回归；下次先执行最新包门槛 |

## iPhone18无线发现的具体定位

开工时使用保存的Bonjour服务名称无法解析，旧地址直连超时。用户提供当前Wi-Fi截图后，只用截图地址和已有配对记录、不自动配对，实时核对完整UDID/型号/系统成功，并完成当前包覆盖。随后只读打开CoreDeviceProxy、进程内用户空间TCP通道、RSD，并实际建立DVT会话，同一UDID匹配。没有root、DDI挂载、系统remoted或VPN/Shadowrocket/Tailscale变更，也未启动App。

关键补查：设备当前 `com.apple.mobile.wireless_lockdown` 域可读、Wi-Fi连接已启用，**当前BonjourFullServiceName与本机私有发现配置中的旧名称不同**。旧名称在直连后再次发现仍失败；从现场设备读取的新名称重新DNS-SD解析、解析地址并核对配对身份成功，目标USB缺席。已将本轮私有发现配置刷新为设备实读名称，保留两次旧配置失败，不能下轮再次盲用历史地址或服务名。

因此本轮发现脚本失败的一项确定原因是保存的服务名称过期；当前无线安装和直接开发服务已可用。原生devicectl独立详情仍为 `tunnelState=unavailable`、developerMode enabled、ddiServicesAvailable=false。这与直接RSD/DVT成功分别留证，**没有把原生Xcode自动隧道根因归给代理软件或旧服务名，也没有宣称Xcode自动调试恢复**。设备本轮实时系统为27.0，不能沿用历史26.0.1记录。

## S03普通90秒观察：未触发候选

最新包门槛通过后，从实际文件预览“继续观看”进入：起点77.787秒，音轨4/字幕关闭，正常退出保存164.667秒，同一书签轨道保持。未直接改书签。与历史起点63.451秒不同、缓存/热状态未知，不作性能比较。

实际图片已查看：t3旋转/黑场，t4/t5黑场有spinner，t6已出电影但仍有spinner，t7电影无spinner，t30/t60/t90电影无spinner；正常关闭后的预览已核。上一次无电影截图请求开始5.005秒、首次查看的电影截图响应结束6.552秒，这是稀疏观察边界，不能称精确首帧。90秒内没有自动降档请求、没有AV/HLS候选创建或replacement commit；所以本轮**没有观察到40秒候选deadline**，不计HLS成功或超时通过。原计划以长窗口保留候选退出前结局，未触发的结果原样保留。

同源诊断：首解码调用711.347ms、首callback1620.567ms、有效帧2853.765ms/21过滤；callback→有效帧1233.198ms。demux完成调用累计2207.202ms/单次最长375.333ms；首次output容量2870.429ms→首次playable容量3643.048ms差772.619ms。完成调用区间可能重叠、在途/具体read等待/硬件callback等待未分离，不能归给纯网络或CPU。API输出不等于实际展示、声音、完整帧或连续90秒接受。

## 上轮HLS记录补查与字节口径更正

这部分是**上一轮fixed-s03-file历史证据**，不是本次90秒的新候选。本次补查包含普通退出后留下的事件，保留原始记录：

| 触屏请求后的时刻 | 已发生事件 |
|---|---|
| 20.603秒 | master上游798字节、重写后231字节 |
| 20.606/21.298秒 | media playlist请求/200响应头 |
| 29.438/29.538秒 | 完整上游清单读完/重写完成；上游1386158字节、重写后194347字节，1880分片，总时长7524.768秒，media sequence0/endlist true |
| 29.584秒 | 分片请求已发出，早于普通关闭 |
| 33.007秒 | 普通UI关闭取消warmup，itemStatus0、loadedRangeCount0，未commit；不是40秒deadline失败 |
| 36.529秒 | 上游分片返回HTTP500；发生于普通关闭和候选取消之后 |

由此更正上一阶段只列798字节master清单的有限摘要：**已有完整media playlist和分片请求**；不能称候选只收到master或没有分片请求。playlist的 `deliveredBytes` 诊断统计原始上游body，不能当成重写后的发往AVPlayer的字节长度，需分别使用inputBytes/outputBytes。分片500/25字节及Network.NWError32未丢弃；因为500在退出后到达，尚不能证明它是退出前无loaded ranges的根因，也不能排除关闭/转码会话终止关系。清单200不代表媒体分片成功。

## 下一步与未完成项

1. 在最新普通包、实际同一轨道下复现自动HLS候选，保持候选存活到完整准备deadline，收集清单/分片状态与服务端转码生命周期；不能提前关闭后将500作为原始根因。优先区分长清单读完等待、分片可用性和退出取消。
2. 细分demux读取、异步硬件callback和容量队列之前的等待；只在受控反例和证据支持时改变播放策略。本轮没有性能修复/验收。
3. 18界面仍由用户延后；原生Xcode自动隧道/间歇断开保持开放，下轮首先读取当前服务名与完整身份，不盲用私有历史端点。13开展调试前重核/覆盖当前包，继续真实蜂窝。
4. 保留旧+475.051服务器差异/耐久、FileStation119与账号代际、AV/HLS各相位、S03/S08/S11/S18/S19/MTP/ISO/TV代表族、声音/完整帧/真实位移、Lenna及DSOne/Jellyfin/Popcorn竞品和全部未验PX/UX/CB/L2/L3/Main。失败/超时不丢弃，无性能/竞品PASS。
