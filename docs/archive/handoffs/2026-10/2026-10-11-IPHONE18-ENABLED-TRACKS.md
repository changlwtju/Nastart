# iPhone18 开启字幕与非默认音轨冷续播

更新时间：2026-10-11T20:25:16.390564+08:00。App源码未改，接续上一轮有效4/off验证，完成普通界面选择2/5开启后的退出和冷续播定向证据。13/Pad没有本轮最新包回归；全量验收仍开放。

## 最新包与无线现场

现场DNS-SD重新解析、既有配对TCP实时核对设备名/型号/系统/UDID：用户iPhone18，iPhone19,7 / iOS27.0，Wi-Fi TCP62078、USB缺席；身份和端点仅存本机私有证据。网络、VPN、配对、remoted和DDI未改。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS未提交差异 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`，其他dirty保留。173输入哈希及mtime复核，最近输入17:35:43早于17:36:31普通Debug/-Onone构建、17:38:03冻结；三SHA及deep/strict签名、29库与profile目标/有效期、IPA三二进制均核实，未重建同源包。主 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`；Debug `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`。包绝对路径、KS哈希和安装时刻见[脱敏JSON](../../../testing/results/2026-10/IPHONE18-ENABLED-TRACKS-20261011.json)。

本轮最新包保留数据覆盖成功，前后25非诊断偏好全一致；未卸载、清登录或清缓存。新UI session、有序终止/state1→空env/args实际普通首页/NAS正常已看。播放前再次重核输入/包与实时TCP身份。322测试/2跳过/0失败、15预检引用此前最终同源结果，本轮无源变更未重跑，不声称新测试。

## WDA恢复与独立原生通道

本轮起始WDA HTTP拒绝连接；现有固定Runner签名/profile有效，未重装。通过既有配对CoreDeviceProxy/RSD正式XCTest恢复，ready/固定Bundle、session/source/screenshot/操作均可用。恢复期间发现两份新WDA报告（20:16:31、20:16:32），均为SIGABRT、lastExceptionBacktrace含XCTRunnerDaemonSession.sharedSession / XCUIDevice / XCUIInitializeForUITesting；发生在Nastart本轮播放前。原报告只读拉取不删除，分类为WDA初始化工具故障，根因未定，不归为Nastart媒体/签名或VPN故障。

20:21原生列表/详情仍paired、developerMode enabled、tunnel unavailable、DDI=false；实际原生进程查询失败CoreDeviceError4016。原生自动隧道仍未修复，直接无线WDA的成功不能替代它。最终直接WDA仍ready。

## 普通轨道选择和正常保存

S03设备文件路线，普通继续观看；从当前粤语音轨4实际菜单选“国语”，日志对应源音轨2。字幕菜单含重名“简英双字”，按本轮真实菜单位置选择第一项，日志对应源字幕5；不是猜索引或写入偏好。选轨后3/10/30/45秒原图保留并人工查看：3秒有中英cue但控制层使其变暗且英文与底部按钮重叠；10/30/45秒控制隐藏，实际中英cue可读，所见无乱码/重复层/底裁。声音可听性/切轨声效时延未采集，不当AUD通过。

普通UI退出保存：1627.262 /4/关闭 →1728.254 /音轨2/字幕5开启。选择导致轨道改变符合本次操作，未把它错误判成轨道保持失败；仅S03书签自然更新，没有直接改写偏好。

## 普通冷续播

有序终止确认state1→空env/args普通首页，未清媒体或NAS缓存（unknown）。原详情“继续观看”，没有再次选轨；起点1728.254，首合格内部时钟1728.382（+0.128），不是实际首显示帧测量。t1仍准备页，t2电影/控制栏/无当前cue，t3已有中英cue但控制栏重叠，t10/30/45电影与自然中英cue可读且控制栏隐藏，原图均保留。目标3秒截图实际采集窗口4.319～4.899秒，保留真实时间不写精确3秒首帧。

45秒观察后，普通UI退出请求距触摸46.882秒，保存1773.545；音轨2、字幕5开启保持。有效目标帧前过滤9帧，callback→有效帧55.829ms，仅内部指标。没有自动HLS候选，不算40秒候选deadline结果。稀疏PNG、时钟、内部API不能证明连续流畅/音频/HDR或竞品排名。

**本次有效源轨道冷保存恢复成立；字幕完整性不判通过。** 控制栏可见时英文字幕与按钮重叠已留证，需同cue暂停对照并检查实际内嵌字幕布局；控制隐藏时的新自然cue不能覆盖旧乱码/残留等失败语料。旧AV0/0身份迁移也仍开放，本轮2/5成功不覆盖历史失败。

## 最终状态与接续

最终20:22实际普通首页/NAS正常，CPU19%/RAM22%/磁盘63%，其他服务未知；播放器关闭/空env和args、idle10/动画2恢复。25非诊断偏好键相同，24非书签键和其他书签一致，仅S03自然更新，登录保留。以恢复后且播放前清单为基线，播放后Nastart/WDA/Jetsam新增均0；整轮仍保留恢复期两WDA失败，不能写整轮零故障，也不排除延迟报告。

接续优先：可见控制栏与字幕重叠的同cue复现/布局修复、实际声音；旧AV跨引擎身份兼容；HLS完整候选deadline、分片/read/callback/容量；原生自动隧道。旧475/119/弱蜂窝、S03/S08/S11/S18/S19族、AV/PiP/暂停预热、MTP/ISO/TV、逐帧流畅度、Lenna/DS One/JF/爆米花及全部未验PX/UX/CB/L2/L3/Main继续保留。

私有证据：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-iphone18-wireless-playback-201546`。设备原图、原始偏好/凭据/名称/UDID/端点/关联ID/日志仅本机；工具快照已冻结并哈希。[上一轮](2026-10-11-IPHONE18-COLD-TRACK.md)。
