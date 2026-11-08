# KS→AV实机验证、S01双入口与iPad更新

记录：2026-10-23 23:10（Asia/Shanghai）。承接[前批候选控制与18安装](2026-10-23-CANDIDATE-DEVICE-LAB-AND-IPHONE18.md)，结果见[安全结构化记录](../../../testing/results/2026-10/2026-10-23-ks-av-s01-and-pad-update.json)。本轮未改App源码、未新建构建或重跑XCTest；所有其他dirty保留。28项开放及76格完整通过率不变。

## 构建与逐台前置

普通Debug/-Onone/Xcode27，21:48:46构建；HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加既有dirty，174源码输入，iOS diff SHA `fb558d4295322180db2f9de34679da0427b5c8d7f2d615b570c24b4f33a77ea7`；IPA SHA `3aa6244882e38faac2404cf1b0cf6f7912cddc0a302f4ee4ceb4b6a08a883052`。逐窗核输入/三二进制/29签名/profile/IPA及自有设备安装回执，未把0.1.0/1当身份。私有根以`/tmp/nastart-candidate-device-lab-evidence`指向，读取须strip。实际姓名/UDID/偏好/凭据/包/原图/完整日志只留私有根。

13现场iPhone14,5/iOS16.3.1/USB，22:08已保留数据安装。18前批22:12:52已保留数据安装且空环境NAS在线首页已实图核，本轮0追加18 App/UI/安装/媒体，不动用户浮窗。Pad先新核名称/iPad12,1/iOS18.3.1/UDID/USB及旧诊断/偏好/原生现场，23:01:06保留数据覆盖成功，18完整非诊断偏好安装前后及正常启动/最终均一致。

## 本地连续MKV的真实KS→AV手动候选

使用本机已有FFmpeg7.1生成90秒连续640×360/30fps H.264/AAC测试图和440Hz音源，MKV与HLS使用同一压缩流重封装；MKV90.021秒/HLS清单89.98秒的容器时间差如实保留。45个不同TS段，无重复短TS/不连续拼接。47资源/生成器SHA与命令冻结于私有`ks-av-fixture`。本地有限Range/HEAD服务支持MKV，不请求NAS。原始MKV SHA `8dbea043fbafb66b73d181f898226784d707e58cef026346d0d391d57a527731`；HLS清单SHA `dc515523eb2086e47a861efa8e2d39f242730d64ddd874a52671e43c95b6bfcd`。

13于22:43–22:44显式Debug环境自动启动原流1次，单次候选按钮1次，真实生产replaceSource/warmup，不改自动策略或阈值。原计划遥测明确KSPlayer/MKV/directPlay，候选计划明确AVPlayer/HLS/localRemux。manifest183ms、decoded375ms、aligned5151ms/总预算剩34848ms后commit；对齐原流7.945秒/候选8.023秒，绝对内部时钟差0.078秒。原生截图开始Original Lab/00:01、结束Candidate Lab/00:24均实见不同动态测试图。22:44:08.697全部App/fixture/日志/180秒守卫停止，25完整非诊断偏好全同、报告名称清单新增0；开始/中途/停止前实际自有caffeinate子断言及AC均核。

这是首个本批真实KS→AV引擎切换的**有限合成片证据**，不是NAS/HEVC/TrueHD/PGS/服务端协商成功。AV新计划初期遥测stallCount1保留；稀疏原图、内时钟差与自动对齐不证明无可见停顿/连续帧时间/声音无缝。本轮未做听音验收，也不把合成音轨编码当可听成功。22:46空环境普通NAS首页恢复。

## 检索助手错误与真实S03自然候选失败

首S01助手Unicode替换字面值未匹配原片名，22:48–22:50实际检索/播放S03《碟中谍3》一次60秒；原生图显示真人电影和PGS双语，助手核对发现后记录错误，**不计S01**，不将新位置当旧7300ms窗的同条件性能回归。脚本日志原S01标签以actualSample=S03/identityFailed纠正，原始失败与自然进度保留。后续修正检索并增加点击播放前详情StaticText片名断言，未改App。

该非计划窗口真实触发自然策略，不是Debug按钮：reason=deliveryBelowSourceBitrate/attempt1，测得bodyWindow容量38.052Mbps，原片平均需求62.682Mbps。候选完整清单12.059秒；34323ms才首次解码，目标/候选4014.453秒、此时原流4033.494秒，候选已落后19.041秒，原40秒预算仅余5.676秒。

40005ms在alignment阶段超限/remaining0，原流4039.190秒/候选4020.964秒、候选reserve0，仅8.008秒下载媒体、accessLog请求2/transfer25.933秒、accessLogStalls48。CoreMedia -12889及候选资源绑定ambiguousOrTruncated保留，**不猜具体上游transfer/分片或唯一NAS/网络根因**。未aligned/未commit，原KS流保留；普通返回原详情成立，末原流遥测stallCount3。首次原时钟信号3032ms不是屏幕首帧测量；新故障不当原7300ms已修复或退化比较。

下一步主要缺口已从“能否KS→AV”细化为“真实候选清单12.059秒加初始seek/解码22.264秒期间供给/落后如何形成”。本地快速可提交不证明真实NAS能赶上；延长40秒、盲改4秒恢复储备/10秒保护或无变化重做旧PGS实验均没有新收益证据。

## 修正后的S01正常双入口

当前普通包，空环境/空参数，无音轨、字幕、seek、PiP或网络设置操作，播放前片名均核实。两个入口各1次Play、目标60秒，KSPlayer/directPlay/localRangeProxy/privateIP，窗口串行，无其他媒体任务。

| 入口 | 动作及位置 | 有限证据 | 内部时钟与遥测 | 收尾 |
| --- | --- | --- | --- | --- |
| Jellyfin | 在Nastart中播放，从头；22:51–22:52，末图01:00 | 原生片头字样、蓝雾/乡村画面变化，正常回同影片详情 | 内部747ms/0.094秒，退出stallCount0 | 22:52:42全部自有媒体/日志/守卫停止 |
| 设备文件 | 继续观看；22:53–22:54，约66.9秒开始，末图02:08 | 原生Sophie帽子店不同画面、完整原文件详情及普通返回 | 内部1079ms，退出stallCount0 | 22:54:58全部自有媒体/日志/守卫停止 |

每窗36原书签键/原轨道和其他偏好保持，各1自然进度变化、Nastart/WDA/Jetsam新增报告名0，auto10/2与WDA状态1/1；实际自有caffeinate断言/AC中途和退出均核。起点不同、不配对速度；稀疏图/采样stall0不当完整帧时间、听音、字幕全功能或整格通过。

22:55:45–53恢复空环境普通NAS在线首页；22:58独立新核源包/签名/13与18回执、完整偏好两次稳定，其他24非诊断键与安装前相同、36书签键/轨道同原值；三个不同书签仅positionSeconds/updatedAt自然推进（S03、S01/JF、S01文件）。初版收尾误预计仅两个进度书签而断言失败，已保留，按实际字段核对后重查两读稳定，不回写/清除用户进度。最终原生Home Wi-Fi/无PiP已看，自有host0，不声称13原生PID缺席。

## iPad最新包、WDA与普通首页

23:01:06当前包安装完成。既有WDA包独立/deep签名、目标及profile有效，以原生RSD/XCTest正确启动，最长180秒，不重建/重装Runner。直接点Runner不是本轮启动方法。首恢复窗WDA就绪并读到NAS状态正常，但普通首页助手仍调用旧MobileScreenshotr/DeveloperImage接口而失败；明确为截图工具失败，不当App崩溃或首页验收，保留第一窗所有原图/日志。

修正为既有原生RSD截图后仅重做一次，23:04:47–23:05:01完成：当前包/实际设备/空环境空参数核过，正常NAS在线首页由原生PNG独立看；其他收藏/服务“未知”不称全服务健康。auto10/2回读；完整18非诊断偏好与安装前相同，0媒体命令。原始有界Runner主机已停，仅清理本窗新App/PID及初始0的自有Runner，最终原生App0/Runner0和Home Wi-Fi/无PiP原图已看。前/中/后自有caffeinate断言/AC核过；不把此前已停止ready继承为下一窗就绪。

本批Pad最新包与WDA控制前置已补齐，但**S01双入口、双端媒体及其他功能仍未验**。18安装本轮无变化，不列当前阻塞。本轮无蜂窝/网络/NAS/VPN/音量设置更改、无卸载或登录清除；全部媒体/采集/自有Runner已停止，不声称回合结束后后台继续。
