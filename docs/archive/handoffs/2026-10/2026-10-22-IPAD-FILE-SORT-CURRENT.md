# iPad正常文件导航与排序控制边界

2026-10-22 08:26。接[既有Pad正常基线](2026-10-22-PAD-PROCESS-AND-MINE.md)与[13样本探查](2026-10-22-NATURAL-SORT-SAMPLE-DISCOVERY.md)；[结构化结果](../../../testing/results/2026-10/2026-10-22-ipad-file-sort-current.json)。两窗均未改变App源码、构建、安装或重跑测试，零文件预览/下载/Play/PiP。18继续按用户安排暂缓。

## 身份和控制链

两次均现场核名称、iPad12,1/iOS18.3.1、UDID、USB及本机保留数据安装回执；沿用05:26普通Debug/-Onone，173输入/当前dirty diff、三二进制/29库签名、profile目标/期限和IPA CRC重核。完整包路径、SHA及原始设备证据只在`/tmp/nastart-ipad-sort-current-evidence`，package-private-root接当前包。普通App启动后实际读取空env/args。

先用单owner原生RSD保存Home与进程/偏好，退出RSD后复用原签名已安装固定Runner，经native XCTest有界运行，不重建/安装WDA；ready后立即正常App-bound会话。原生RSD/DVT最终复核只在自有Runner host停止后执行，没有两个原生owner争用。WDA PNG仍倒置180度，已实际查看，所有输入按当轮AX语义，不从倒置图片猜坐标。

## 两窗实际结果

首窗正常首页NAS在线，但助手沿用了iPhone导航name“设备”，本Pad实际name为SF Symbol、label才是“设备”；唯一目标断言阻止输入，零点击。保存当前AX/PNG，结束自有App/日志/Runner host并核18偏好不变。一次原生复核仍见另一个Nastart PID，它既不是首窗前PID也不是本窗owned PID；未擅自停止或推断来源、媒体任务。已保存诊断且Home无PiP，按既有正常基线授权继续第二窗。

第二窗只将私有助手导航选择器改为实际label，正常进入设备页与文件根目录，12文件夹整屏AX/实际截图一致。排序菜单按钮name/label存在、enabled=true，但displayed GET为false，守卫在发点击前拒绝；本窗仅两次导航点击，零排序点击。finally原排序恢复也在同一个可见性守卫前停止，未发恢复点击；完整最终18偏好与首窗开始完全一致，所以没有排序状态需要回写。后续排队的名称降序/进目录命令未执行。保留两次TOOL失败，不当App排序失败或通过，不绕过守卫或发第三个同条件窗。

## 收尾与接续

两窗设置均auto/idle10/cool2 GET回读，自有App与日志停止、host已SIGINT结束。08:25:22最终原生Nastart=0、Runner=0、自有host=0，18完整非诊断偏好与第一窗开始相同，原生Home无PiP/Wi-Fi图标实际已看；未改网络、未使用蜂窝。

下一步先离线核Pad toolbar可见性/方向/命中前提或转独立已有播放缺口，不能直接删displayed守卫或再跑同条件。13数字自然序和缺失元数据真机样本仍缺，Pad排序/完整SUB/AUD/PiP及18原图均未新增验收；28项保持开放。
