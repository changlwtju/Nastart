# 共用测速的协议开销校验修正

日期：2026-10-19。关联PX-01/PX-03，起因及旧包窗口见[独立链路评估](2026-10-19-CELLULAR-LINK-ASSESSMENT.md)。这是最小公共语义修复，不改变缓冲、分片、automatic waiting、NAS或VPN配置；尚不代表蜂窝问题已解决。

## 缺陷与反例

旧`PlaybackBandwidthProbeDelegate`要求`countOfResponseBodyBytesReceived`等于`countOfResponseBodyBytesAfterDecoding`，再用前者与请求正文长度比较。[Apple对线上计数的定义](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics/countofresponsebodybytesreceived)包含协议分帧、传输编码及内容编码；[解码后计数](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics/countofresponsebodybytesafterdecoding)则是交付delegate/completion的数据量。未压缩完整HTTP/2或chunked响应也可能有不同数值，不能直接当不完整或压缩。

具体反例：1MiB正文、线上多576bytes协议开销、正文0.2秒、整次请求5秒。旧等值门槛拒绝容量证据；新规则以1MiB正文求约41.94Mbps，不把576bytes计入媒体容量，也不把5秒首字节/建连等待混成供给速率。真正慢正文仍可判不足；压缩、缓存、不完整或计时缺失仍不允许据此否定原画能力。

## 修改与验证边界

仅App公共`LaunchpadPlaybackCore.swift`及既有`PlaybackNextCoreTests.swift`变更；保留其他未提交修改。`networkPayloadBytes`要求正正文量、线上量不少于正文、无内容压缩及仅identity/chunked传输编码；delegate仍要求networkLoad/HTTP200/起止日期，sample仍校验交付量等于请求量和有效时间。

37项定向普通Debug XCTest全部通过（含现有SDK委托转发/延迟头、压缩/不完整、正文慢速、容量/冷却/接手规则及新增分帧反例），15预检通过；未跑全套。Xcode27/27A266a普通Debug真机编译通过，08:31:39包已冻结、173输入/29库/deep-strict签名/IPA CRC及三二进制哈希核验。

私有指针`/tmp/nastart-probe-framing-evidence`，工具`/tmp/nastart-probe-framing-tools`。三SHA：Nastart `78377effad844176565694e29bf77e759440590c973517350b04e57906b5d91b`，debug `5bf4ba514cc3aaec9cb01646c45218d457b470a7f31546cbb4498d820eba755c`，KS `ae90077cf5f57f43331ff251081bfc734babe24041a9e92bb948c4146d60c3a8`。ios差异`d9b6e18e49d0c5f06ad292d12192423828c12ea6ff8282778e9898672ee81604`，profile UTC10月24日22:23:57到期，原始包/偏好/身份不入仓库。

13重新现场USB/iPhone14,5/16.3.1身份核对，先留崩溃清单与偏好，再保留数据覆盖；25项偏好不变，空环境普通首页实际看过、NAS恢复正常。已完成Wi-Fi基础双入口及蜂窝两入口有界窗口，结果含失败；[结构化结果](../../../testing/results/2026-10/PROBE-PROTOCOL-FRAMING-20261019.json)。不因恢复正文计时就称整体提速，Pad/18暂不扩装此候选。

## 真机结果与新拦截点

- S01 Wi-Fi两入口各30秒、普通退出、完成指标均cellular=no，maxStallCount均0；实际看过JF开场字幕及两入口30秒云雾图，稀疏选图不验完整声音/字幕/流畅。
- S19文件详情阶段探针获得networkBody：1MiB正文343ms、总875ms、约24.40Mbps（触摸前1.203秒），初始直接AV/HLS12Mbps，避免原流试播。触摸后首次内部时钟9.658秒；14.079秒仍因完成传输估计4.63Mbps而再次降至2Mbps，25.303秒提交候选。它不是已解决的无卡顿路径，单窗不能证明起播提速。
- 文件深seek内部恢复5.012秒，目标6808.195秒，与旧窗6783.602秒不同；各40项完成指标cellular=yes/h2、stall最大2（含seek）。seek+30实际Boromir举戒指新画面；不能由目标/输出/缓存均不同的两窗算提速比例。
- S19 Jellyfin浏览阶段也恢复networkBody：1MiB正文711ms、总769ms、约11.79Mbps（触摸前7.838秒）；选择4Mbps HLS。但45秒没有进入播放页，t10/t30仍详情，深seek未执行。两次准备分别3.410/8.911秒返回后，均被`playbackContextDiscarded/ownershipChanged`丢弃；`credentialsCurrent=true`、`sessionCurrent=true`、`cancelled=false`。中间额外路径稳定等待约4.057秒，第二次后未再起播。

这把“取流已完成但不进入页面”的本窗失败定位到**准备结果发布前的路径所有权校验**，不是播放器首片解码或带宽下载零速。不能据此断言路径实际未变或直接移除校验：现有公共HTTPS蜂窝保留策略已存在，还会检查实际连接类型、精确端点、是否自签信任等；本窗未记录具体拒绝项。下一步先补该决策的最小、脱敏原因及反例，区分真实切网/账号变化与允许保留的同公共端点更新，保留凭据/跨端点隔离，不盲目放开自签或LAN跨路径结果。

## 收尾执行保障

本批蜂窝窗口工具已增加最外层finally：子任务有界、失败/超时终止其进程组，先停止本App媒体，再自动恢复原Wi-Fi；以原生网络“已选择”及原SSID核实，保存截图待实际审阅，然后回到普通空环境首页。仅开启开关不算恢复。原始SSID不发布；正常关闭和故障清理终止分列。该脚本在本机私有工具目录，结果随窗记录，不因创建脚本就声称真机已验证恢复。

已实测正常文件窗口及Jellyfin失败窗口自动finally均恢复原Wi-Fi连接；立即连接勾选截图仍显示4G，未当图标已恢复。08:43网络稳定后普通首页/NAS正常及Wi-Fi图标实际看过，最终恢复核实完成。24非书签偏好不变、原轨道变化0、自然书签变化3、新增App/WDA/Jetsam0、原生网络条件0，自有批次/保活已结束，测试模拟器Shutdown，原13持久服务保留；08:29～08:43电源日志范围无Sleep/Wake/DarkWake。

首次文件窗口在Wi-Fi控件定位阶段失败、未发媒体播放，finally仍成功恢复；重试保留错误并对新鲜状态有界重读后继续。首版子步骤同名日志被清理覆盖的缺口已明记、WDA错误单独保留，随后改为分序日志。JF无播放器时seek助手的控件断言是TOOL后果，不算执行了seek；真正产品失败为45秒未进入播放器。未观察到新增App崩溃。

## 未完成项

- networkBody真机已恢复；首帧/深seek/连续稳定仍未验收，旧真机unknown未保存具体拒绝字段，不追溯声称全部由分帧造成。
- S01双机双入口及S03/S19代表集、同条件重复、实际字幕/听音与非退化；Pad/18尚未更新本候选。
- 最高优先接续本窗JF发布校验丢弃；同时保留现有AV item深seek首片前后等待及首次兼容/继续降档问题。不能由本次探针修正替代，不重复automatic waiting实验。
