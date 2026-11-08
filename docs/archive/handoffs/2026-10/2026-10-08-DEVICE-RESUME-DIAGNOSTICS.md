# 2026-10-08 双设备诊断修正与真实蜂窝接续

用户最新说明 iPhone13 已具备蜂窝条件，覆盖此前当天无蜂窝/明天 eSIM 的计划。本轮先恢复两机最新包门槛，再完成一个有限诊断修正及串行播放取证。蜂窝启动/缓冲、ISO 续播速度、PX/UX/CB 和 L2 仍未验收。

## 变更卡

问题：PX-01/PX-02 长等待观测缺口。DiagnosticLogStore 每来一个事件取消并重排750ms任务，持续事件可能让保存任务一直未执行；1000条上限另会裁剪早期事件。
基线：HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，既有未提交修改全部保留。07:25后现场逐机核对13 iPhone14,5/iOS16.3.1/20D67、iPad12,1/18.3.1/22D72，USB/配对有效；旧普通65f6/a339/KS5fa4、diff372e仅列基线，分别保留数据覆盖及25/16偏好和实际正常启动已核。18已离线，仍为07:15安装包，不算本轮新源码回归。
复现：旧包 iPad 文件 ISO 续播 trace A54E6C64，索引1556ms/准备1574ms，时钟信号等待12605ms、位置79.707秒；3秒转屏等待、10秒黑图、30秒电影与中文。早期偏好读回仍旧；不能由此断言所有日志丢失。
共用规则/最小修正：非错误事件共用当前750ms批次截止，到期在串行后台队列保存最新快照；错误取消批次立即保存，clear保持FIFO删除。增加隔离UserDefaults测试入口。只改变日志调度和观测，不改变Range、缓冲、解码、seek参数。
分段观测：给KSPlayer现有初始avformat_seek_file加单调起止和结果；首次时钟推进记录open、streamInfo、ready、initialSeek、首视频包/解码、ready到时钟。缺失/非法时间为unknown，未请求seek为notRequested。首包/解码是相对prepare的累计时间，readyToClock包含其后的工作，不能把各项简单相加；时钟/解码也不等于实际呈现帧。

## L0 与最新包身份

- 旧调度+新测试入口的连续日志反例失败（2项中1失败），修正后193项测试、2跳过、0失败；错误立即保存/clear不复活和非法阶段unknown测试通过。15预检通过。
- 普通Debug `-Onone`，空环境/空参数启动，10:41:14+08构建。HEAD如上，iOS工作树diff SHA-256 `e942c3d3f5648b0ddb1011400af409c6c0008563e5414739994d5e390d13b247`。
- Nastart SHA-256 `777911af4e815a76912599e95f176facb0418cf3aafc8918b687194f01950b65`；debug dylib `01874cce91dae3115ba9f1116979416c3244d090cc053e972be2b1e9e2a63ba0`；KSPlayer `eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`。
- 137源码/项目/包锁输入无晚于构建，29库独立及deep严格签名/链接验证通过；有效描述文件包含两机。签名描述文件有效至2026-10-10 22:03:15 UTC。
- 10:42:26/28两机重新现场核对名称、型号、系统、UDID、USB及配对，保存旧诊断后保留数据覆盖安装此包；安装/正常启动25/16非诊断偏好一致，原生实际启动台已核。完整UDID、安装回执、包路径、签名输出和原始偏好仅留本机私有证据目录。
- 包：本机DebugEvidence本轮 `iso-device-files-20261008-072518/Nastart-DiagnosticStages-Latest-Debug.app`；完整绝对路径记录在本机diagnostic-stages-package.json及每机current-package.json。

## L1 本轮证据

| 设备/入口 | 本轮边界和结果 | 归属 |
| --- | --- | --- |
| iPad/Jellyfin/28GB ISO | trace9DE40951，从0首播，时钟1665ms；open167.504/streamInfo605.697/ready25.628ms，首包861.957/解码863.161ms，未请求初始seek；45秒采样、电影画面/普通退出 | 诊断生效；开头logos无可核对中文字幕cue，不能仅凭Chinese配置判cue通过 |
| iPad/设备文件/同ISO续播 | trace5AD0DE3A，既有保存位置212.464秒，时钟5492ms/位置212.518；open347.587/streamInfo608.559/ready6.902ms，初始seek2288.296ms/result0，首包3722.215/解码3722.874ms，readyToClock4406.862ms；45秒窗口实际中文/电影、普通退出 | 续播等待仍在；不是与旧79.568秒位置同条件提速对照 |
| iPhone13/真实蜂窝/Jellyfin/S03 | trace9F51281B，5G状态且Wi-Fi OFF，26项URLSession metrics全部cellular=yes；缓存VOD预热1303ms/准备1478ms，AVPlayer HLS 8Mbps、时钟29571ms；71遥测/120844ms，起始等待后又在约87.870秒等待，stallCount2、accessLogStalls1，120秒图实际电影/双语/普通退出 | FAIL保留，不能判流畅；不是人为3G限速样本 |
| iPhone13/真实蜂窝/设备文件/S03 | traceFD1FA59D，5G/Wi-Fi OFF、41项URL metrics全部cellular=yes；文件入口verifiedJellyfinHLS 2Mbps、准备1988ms，保存位置1870.132秒、时钟11871ms/1870.501；88遥测/119787ms，仅初始计数1，后续窗口未新增、accessLogStalls0，120秒图电影/双语，普通退出预览正常 | 启动仍超目标；与Jellyfin从0/8Mbps条件不同，不作两个入口性能排名 |
| iPad/Jellyfin/ISO中文补证 | trace14A42834，从0/90秒窗口，时钟3703ms，open206.680/streamInfo2672.882/ready9.377ms，无初始seek；82遥测/86897ms，stallCount0但丢帧26，t90实际电影/中文、普通退出 | 字幕正确性证据；26丢帧保留，不作流畅/首播速度验收 |

首播与文件续播两个早期有效样本均包含初始等待，最新文件样本初始计数1、首时钟后在已取得遥测内未新增，末尾丢帧2；Jellyfin首播初始计数1、末尾丢帧1。聚合displayFPS/截图不代替完整呈现帧证据。输出音频未客观取证，AUD保持U；杜比输出未验。

诊断读回：Jellyfin ISO t0/3/10仍为旧磁盘快照，30/45日期推进；文件ISO t10/30/45日期推进，手机两个蜂窝入口早期快照及t30/60/90/120推进。修正保证保存任务不被持续事件重排；UserDefaults系统磁盘刷新仍可能延迟，不承诺750ms House Arrest可见。每个早期快照独立保留，1000条上限裁剪仍开放。

## TOOL 与限制

- iPad一轮文件续播已提交播放后误用无tidevice的主机Python，预定0/3/10/30/45采样未执行；trace7A9D25CF及恢复画面/偏好保留，时钟5847ms、初始seek2590.269ms只作故障恢复时读取的内部诊断，不冒充完整45秒窗口。随后普通退出并用正确运行时独立重测。
- iPhone文件目录先按英文查找，实际S03为中文文件夹，边界12轮找不到保留TOOL；上翻找到后第一次目录跳转未就绪，保留，现场重读后进入预览。
- iPad导航包含全屏覆盖层/隐藏底层节点，快速坐标第一次未切到文件；退到资源库并正常完成退出后进入设备文件。所有失败保留；滑动只用于找目录，无帧证据不判滚动PASS。
- 两个手机样本URL代理分别保留6/10项Network.NWError错误0、clientFailed/clientBodySend，尚未确定客户端取消/重试机制的因果；不能把它们直接当上游断网，也不能因画面恢复丢弃。
- iPad ISO页面退出旋转瞬态保存，不能由瞬态截图判稳定布局；普通播放器退出已由层消失及后续正常页面证据核对。
- iPad文件冷进曾DSM未连接，随后会话恢复且换页可读；尚无证据确认停留页必定不能自动恢复，本批不修改连接逻辑。
- iPad WDA复用既有有效fixture（10月10日到期），本轮恢复XCTest及8101转发，无Runner重装；iPhone无线切换后旧WDA会话404，仅重建会话，未重装Runner。早期syslog未取得KSPlayer阶段，不用于本轮耗时。

## 待完成与下一步

本轮手机设备文件S03蜂窝采样与iPad Jellyfin中文cue补证已完成，见表；对应数字摘要见[脱敏JSON](../../../testing/results/2026-10/DEVICE-RESUME-DIAGNOSTICS-20261008.json)。

收尾10:59：手机原Wi-Fi ON已恢复、条件库存只读核对全部inactive，本轮未加人工限速；蜂窝/现有VPN设置未改，规则VPN模式未验证。两机普通空环境重开启动台、播放器已退出、idleWait10/coolOff2恢复，fresh USB/配对/WDA ready已核。手机冷进一度未连接，随后停留启动台自动显示NAS状态正常；iPad冷进类似状态随后也自动恢复在线；均只作现场观察，不作为连接修复证据。原始偏好/凭据和完整原生画面仅留私有目录，工作树其他修改全部保留。
随后按同位置、同源码/配置和独立入口重复ISO续播，判定initialSeek与seek后首包等待；S03保留长启动及供流耗尽失败，比较HLS分段网络与播放储备，再提出单一最小修正。MI2/S19真实弱蜂窝双入口、旧-1008/seek失败、长后台/PiP、Lenna及DS One同条件至少五组完整帧对照和原PX/UX/CB/L2继续开放；正式竞品配对0，无Main提交/推送。
