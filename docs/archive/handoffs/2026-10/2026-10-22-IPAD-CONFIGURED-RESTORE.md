# 同包iPad更新与原生NAS首页核验

2026-10-22 05:40–05:45，关联UX-05，接[配置地址恢复](2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md)和[13真实保存窗](2026-10-22-TRACK-SAVE-MEMORY-WINDOW.md)。无新源码、构建、WDA安装或媒体；复用05:26正常Debug/-Onone/Xcode27包，diff `e65a8da17ea0db5e1a22d374c2bb79c5d5d8dd4eb4acb4a5fedd8f3057cbaa16`、IPA `45d213bafb07a70a3543980ff961388a817172e7e9176185f67c76fb2b1eaf9b`，173输入/29库签名/profile/IPA内容逐项再次核验。完整SHA/设备/偏好/图日志在`/tmp/nastart-ipad-configured-restore-evidence`，prior为配置地址恢复包目录。

## 现场门槛与失败路径

当前设备名称、iPad12,1/iPadOS18.3.1、UDID与USB现场已核。旧WDA当前不ready，不能继承20日的瞬间ready/控制成功。legacy截图接口报InvalidService，自动查找DeveloperImage亦未找到，未实际挂载/更新系统；保存失败后采用项目既有原生RSD路径，未因截图工具失败重装App或WDA。

保留数据覆盖前18完整非诊断偏好/旧诊断已保存，签名与目标授权核验通过。第一条devicectl安装在分配RSD设备时失败：CoreDevice -1、mobiledevice -402653181、Failed to allocate RSD device；未进入安装，不标成功或删原记录。随后使用既有配对USB/usbmux installation_proxy，autopair=false且实时UDID核对，无新配对/改凭据/网络。Install明确Complete，lookup确有目标Bundle，05:43:58+08完成；18项完整偏好键和值逐值一致。没有卸载/清容器。

## 正常启动与收尾

另一次现场身份、173输入/有效包/本机安装回执门槛通过后，用单owner原生userspace RSD/DVT正常启动；environment={}、arguments=[]、无测试注入，未独立回读进程env，区分13的WDA参数实际读回证据。只一次launch，5/15/30秒原生Screenshot采集，全部原图私存；未发媒体/手势或尝试未知WDA动作。

主登录05:45:16.773→18.477成功，FileStation18.751→20.273成功。这是本窗日志跨度，不当冷启动完整耗时、Strict CB15或竞品配对。15秒实图NAS在线/状态正常，各服务仍未知；30秒实图NAS在线、DSM/Homepage/Jellyfin在线，Radarr/Sonarr/Prowlarr为警告，未据此判全部服务健康或修改服务/NAS设置。顶部NAS认证与独立服务探测分列；未核“我的”页面交互。

正常启动后18项完整非诊断偏好仍全部相同。最外层finally在同一DVT owner中向本窗PID发SIGKILL并收到应答，再读原生进程表核schema/该PID与Nastart名称均不存在；自有syslog结束、RSD/USB客户端及临时assertion随命令退出。最终实际Home无PiP/Wi-Fi图标已看，无网络/蜂窝/SSID/VPN更改、零媒体流量，不将工具失败当播放故障。WDA未建立session/source，不声称恢复交互可用，也未改其设置。

[安全结果](../../../testing/results/2026-10/2026-10-22-ipad-configured-restore.json)。13继续同05:26最新正常包，保存窗已收尾；18仍10-21 15:39历史包、遵守用户暂缓，不探测/切前台/催促。下一步只复用已签名Pad Runner恢复有界WDA控制，再接受影响的剩余页面/字幕场景；未获得包缺失/签名失败证据不重建/安装WDA。旧保存失败原因、冷恢复耐久、完整SUB/AUD/PiP/帧时间和竞品配对待验，28项状态不变。

## 05:51–05:56既有WDA复用与所有权收尾

继续下一阶段，仅复用10-18已签名且设备已安装的固定Runner；现场重核fixture深签/profile有效/目标授权，再按项目既有native RSD/XCTest单owner方式启动，run timeout缩为120秒。没有构建、安装、切媒体或Nastart启动请求。05:52 USB直连现场目标返回ready/预期固定Bundle ID；正常SpringBoard系统session、快速source及PNG成功，auto/idle10/cool2设回后GET已核。本次WDA PNG实际上下倒置，后续原生RSD Home图方向正常，不借这张PNG验App方向、坐标输入或字幕；下轮动作仍须现场矩形/方向核对。

系统只读观察完成后精确核自有host PID/命令并SIGINT停止，host正常按intentional返回-2；未保持后台Runner。第一次旧清理助手要求所有Nastart也不存在而断言失败：其首次原生表已无Runner，却有一个不同于05:45本窗App PID的新Nastart进程。WDA-only脚本未请求Nastart启动，来源/所有权未证明，不归为用户动作、后台唤醒或App崩溃；保留失败，不停止该新PID。随后仅修正私有清理助手所有权前提（不是App源码/新包），重新读原生表核自有Runner不存在、早前自有Nastart PID不存在、新Nastart仍1且零停止；13持久Runner/既有转发未动。下轮媒体前先核此进程归属/实际媒体状态，不能把只无host采集进程当互斥通过。

最终原生Home无PiP/Wi-Fi已看，18完整偏好仍与安装前逐值相同；173输入/包/29签名/profile与当前Pad USB身份再核，自有安装/采集/XCTest/清理host无残留，网络/凭据未改。一次只读审计误用了默认Python而缺pymobiledevice3，未发设备操作；改用既定/usr/bin/python3完成，不记设备故障。控制健康有限切片已补，Pad App导航/我的/字幕/媒体仍待；下一轮使用已验证的有界Runner复用路径，不重建/重装或复制旧失效session。28项状态保持。
