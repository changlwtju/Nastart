# 清单字节与编码观测、蜂窝路径连续变化反例

2026-10-19 13:01～13:31。[结构化结果](../../../testing/results/2026-10/RESPONSE-BODY-ENCODING-20261019.json)，接续[清单离线审计](2026-10-19-MANIFEST-PATH-AUDIT.md)。本批只增加共用代理诊断字段及反例测试，未改码率、缓冲、预热、证书策略、NAS/VPN或超时。前批同源复核与预测候选保持；**新的失败说明同源复核仍不能解决连续路径更新的全部情况**。

## 新观测与验证

`PlaybackResponseBodyDiagnostics.fields`在`DevicesView.swift`现有`urlSessionTaskMetrics`回调中记录最后一个transaction的：`responseBodyBytesReceivedIncludingProtocol`、`responseBodyBytesAfterDecoding`、`responseContentLength`、`responseContentEncoding`、`responseStatusCode`。原trace/transfer/task关联保持，前者包含协议/编码，不能称运营商计费流量；与delegate累计量分别保留。不用压缩后/前计数相等作为媒体有效性门槛，不改既有测速或容量规则。

编码仅输出identity/gzip/deflate/br/zstd及其合法组合，缺失为unspecified，任意其他头值为other，不回显原头。缺计数/非法长度为unknown、实测0仍为0。两项新反例覆盖压缩后小于解码前、协议分帧差值、未知/零/错误状态及不泄漏任意头值；与路径身份/容量/时序等共55项定向XCTest、0失败，15预检通过，未跑全套。首次补丁因测试函数锚点不同未应用，核实三个文件均未改变后修正锚点成功；无半写入或设备操作。

普通Debug/-Onone、Xcode27/27A266a，13:04:24构建，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留的工作区修改；ios差异`9e8e9a5d3afc4d36048e1a59f0ac7be49ea4489b07fbe55f264822b9e911a5b6`。173输入/29动态库独立及deep strict签名/IPA CRC三哈希核实，profile UTC10月24日22:23:57到期。

- Nastart：`04900ab503bbde32b0dc8e46c1d84d4b5cfca4451a42a418dd7b9d08b0356ea9`。
- debug：`3669d9bf77b16b2edea35a992efdafc4428b88960521b3aaabf011b9dcb04c25`。
- KS：`a2f7ab573fc1fb6ba0ffa0b4b9332fa044ef8300d61ae78ee6245ecbd5e78938`。

13两次现场确认USB/iPhone14,5/16.3.1及名称/UDID，备份诊断再保留25偏好覆盖，空环境普通首页/签名包实际核实，逐窗再核现场。Pad未操作，仍12:14包；18未重试不变的无线阻塞、没有发送当前包安装，均非新包真机回归。

## 真实4G S19两入口

原生Wi-Fi关闭、状态栏4G，用户报告弱蜂窝，RSRP/RSRQ/SINR仍未知。缓存unknown、没有人为限速或并发影片。

| 项目 | Jellyfin | 设备文件 |
| --- | --- | --- |
| 首次媒体清单解码后字节 | 2,785,149 | 2,549,031 |
| 同transaction接收计数（含协议/编码） | 2,791,287 | 2,554,647 |
| Content-Length / Content-Encoding | 2,785,149 / unspecified | 2,549,031 / unspecified |
| 首次清单总传输 / 正文 | 3.139秒 / 3.052秒 | 2.191秒 / 2.069秒 |
| 内部首时钟（从播放触摸） | 19.523秒 | 7.711秒 |
| 深seek目标 / 内部恢复 | 6783.601774秒 / 5.385秒 | 6808.195160秒 / 4.800秒 |
| 完成URL metrics / cellular=yes | 60 / 60 | 93 / 93 |
| maxStallCount（含seek） | 2 | 2 |

这些计数支持本窗没有显著内容压缩收益、清单确有兆字节级传输成本；**不是服务器所有端点均不支持压缩的证明**，更不是计费总字节。不能仅凭unspecified证明未压缩，必须与本窗两类计数/长度一起解释。未改变NAS/反代配置。

JF本窗两次均协商4Mbps预算、h264目标3.36Mbps、AAC、字幕8-Encode；准备耗时分别4050/13457ms。文件本窗输出规格仍未完整冻结，不能从旧2/12Mbps补值。两入口没有自动降档请求，各普通退出。t30实际JF New Line logo、文件New Line presents；seek+10分别雪山全景/位置字幕和Boromir持戒，已看原图。时钟不等同可见首帧，完整音字幕/逐帧流畅度/画质未验。

## 连续路径变化保留失败

JF第一次复核+4.909秒开始于路径5，+4.996秒记录不等价路径6，+5.397秒返回`identityPathOrOwnershipChanged`（499ms），随即发布拒绝/丢弃。账号/会话当前且任务未取消，但当前合并拒绝事件没有逐项暴露服务器/账号响应匹配结果，不能仅凭这条日志排除同时存在其他原因。

旧外层重试随后等待6.785秒到+12.198秒，重新准备清单（同解码后2,785,149 bytes，接收2,791,287 bytes，再耗1.606秒）；第二次新认证530ms成功，+14.868秒保留，最终内部首时钟19.523秒。这是前批两次快速成功之后的新反例，不能丢掉或归因本批纯观测导致播放参数退化。前批“每窗大清单一次”仅对前批三窗成立，当前新失败因真实重准备而多读一份，不修改历史结论的时间归属。

**立即后续设计**：将fresh-auth结果细分为身份不符、失去所有权/取消、网络桶变化/未知、以及“身份正确但探针期间路径再变”。只有最后一类且仍为同原端点/凭据/登录/蜂窝时，研究保留准备资源并有限重验一次；不得拿旧身份跨新路径直接发布、不得给错误服务器/账号重试掩盖、不得无限重试，也不缩稳定等待参数冒充根治。实现前补这些反例，最后一次仍变路径则原失败回退。该修复尚未实施。

## 收尾后离线分段

同trace+transferID+upstreamTaskIndex精确匹配全部60/93个metrics到issued。初版解析缺失的取消请求header时间时失败，修正为null保留原失败，未填0、未丢取消请求；不计App失败。

| 分段 | JF | 文件 |
| --- | --- | --- |
| 首成功视频片等headers / 正文 | 2.191秒 / 0.474秒 | 2.041秒 / 0.318秒 |
| 首片完成metrics→首时钟 | 1.330秒 | 1.393秒 |
| seek触摸→目标首片issued | 2.972ms | 2.294ms |
| seek目标首片等headers / 正文 | 2.946秒 / 0.448秒 | 2.657秒 / 0.462秒 |
| 目标首片完成metrics→恢复时钟 | 1.940秒 | 1.664秒 |

等头不能区分公网/运营商/服务端生成，后段包含后续取片/解码/储备，不能全称解码耗时。先解决确定的重准备额外等待，同时保留首片/清单供给优化队列，不能因这一项修复跳过其他问题。

## Wi-Fi与环境恢复

两蜂窝窗最外层finally先停本轮媒体，13:21和13:25自动恢复原Wi-Fi，原网络勾选与Wi-Fi图标实际查看后再离线分析；用户蜂窝/VPN设置保持。之后13当前包S01文件/JF各从点击采样30秒、普通退出、maxStall0，各2完成指标cellular=no，t30蓝色云雾片头实际看过，完整音字幕/帧时间未验。

最终24非书签偏好保持、原轨道变化0、自然断点变化4，新增App/WDA/Jetsam0、原生条件0。最终普通首页NAS卡片未连接，不能称登录恢复通过；Wi-Fi图标实际看过。本批未启动Pad Runner、保留原13持久WDA，测试模拟器Shutdown，无自有媒体/构建/采集。保活wrapper覆盖测试和采样；实际Sleep/Wake/DarkWake0。构建exec会话续取时旧会话ID已不可读，以磁盘构建结果及BUILD SUCCEEDED核实完成，没有重复构建。

私有`/tmp/nastart-body-encoding-evidence`、工具`/tmp/nastart-body-encoding-tools`，原始偏好/日志/设备标识/包只在私有区；仓库仅脱敏结果。技术路线、开发状态、总账、矩阵/PROGRESS/当前交接同批同步，28项仍全开放，TV/DSM约束不变。
