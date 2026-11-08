# S01 系统画中画 X 关闭有限验收

2026-10-22 01:29:31–01:30:35，13/S01/Jellyfin/原Wi-Fi、空环境/空参数。复用19:52普通Debug/-Onone包及持久WDA，零App源码/构建/安装。不是第三轮同条件S03候选诊断；目标是尚未到达过的系统X关闭，选择小H.264/8-bit原流、保留原目录选择（源音频1、字幕关闭），零Pause/Resume/换轨。开始前其他同项目任务notLoaded、自有媒体/构建/采集进程零；现场身份iPhone14,5/iOS16.3.1/USB、173输入/dirty diff、三二进制/IPA/29库签名/profile、本机安装回执重核。[安全结果](../../../testing/results/2026-10/2026-10-22-pip-system-close-s01.json)。私有指针`/tmp/nastart-pip-system-close-evidence`保存原图/完整偏好/日志/身份与脚本，prior指向最新包；Pad/18未操作。

## 一次操作与独立效果

1 Play、1 PiP，手动Home1次；PiP3/10秒原生采样后显控1次，系统“关闭画中画”触摸1次。仍复用App session选择SpringBoard目标，不新建系统session。现场唯一按钮/显示/启用/矩形/容器边界/前台重核，观察返回至一次W3C触摸0.665581秒，未用缓存EID点击、无未知动作重发。

| 时间 | 已核实际效果 |
| --- | --- |
| 01:30:01.657878 | 同完整owner pip_started，KS原流 |
| 01:30:19.745556 | 系统X触摸派发 |
| 01:30:19.800422 | 同owner requestedPlaying=false/actualPlaying=false，位置29.086秒 |
| 01:30:20.645204 | pip_stopped/restoring=false |
| 01:30:20.657211 | 同trace原流routeRevoked，上游-999属关闭清理 |
| 01:30:20.697013 | playback_ended |
| 01:30:24.063927 | 服务端接受该片stopped；后续记录窗至清理无新上游媒体派发 |

系统树原PiP容器消失，原生Home无小窗；App仍存在后才正常activate（无重启/新播放），实际回《哈尔的移动城堡》详情，继续/从头播放入口可见、字幕仍关闭。关闭→小窗消失、结束媒体会话、原详情可返回在此有限场景成立。没有把HTTP触摸成功或内部回调单独当作效果。

## 呈现与结论边界

入PiP前实际片头字卡；PiP3秒图有蓝色Studio Ghibli片头，PiP10秒图为黑场，显控前又为模糊蓝色帧。黑场是否源内容尚无同位置对照，保留未知，不把稀疏图升为完整PiP呈现/逐帧/听音/字幕验收，也不据黑场直接认定产品故障。本窗字幕本就关闭，不拿它证明有字幕或无字幕缺陷。源标题字卡中的文字不等同App字幕层。旧S03 ASS/PGS失败和18原图继续保留。

私有复用脚本的method文字误留“PGS/pause/resume”；动作实际无暂停/继续，source_capabilities明确S01/audio1/subtitle none/disabled。已在原始结果附actualMethod及metadata错误标记，公开结果改以实际动作/路线描述，不覆盖旧标签来伪造执行历史。

## 收尾与接续

正常系统X结束后，在原详情短留存再finally停止自有App/采集/100秒守卫；原生无App、Home无PiP与Wi-Fi图标已看。36书签原轨道全部一致、零增删，仅本片自然进度变化1条，其他非诊断偏好一致；App/WDA/Jetsam清单零新增。01:31独立回读当前有效session auto/idle10/cool2、173输入/包/库签名/USB身份及自有媒体/构建零残留。本窗结束页面是影片详情与Home，不把复制的“normalHome”审计字段当新增NAS首页/提速成绩。网络/SSID/蜂窝/VPN/NAS未改，持久Runner保留。

这只补PX-06的13/S01/JF/SDR/字幕Off“系统X关闭”切片，整项仍待验收，76基础矩阵不整格升P；其他设备/路线、完整音字幕/HDR/PiP/帧时间/长稳仍缺。下一步遵循[轨道内存/磁盘保存边界](2026-10-22-TRACK-SAVE-OFFLINE-BOUNDARY.md)及[清单供给边界](2026-10-22-LOCAL-MEDIA-PLAYLIST-BOUNDARY.md)先制作有区分力的反例，不再重播同条件取日志。18按用户约束继续暂缓。
