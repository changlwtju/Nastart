# WDA查询陈旧快照与动作确认边界

2026-10-20，本批离线阶段已完成。关联PX-06/PX-07，28项开放不变。

依据上一批Pad在`POST /elements`的404 stale element reference，与13恢复目标缺失；只读查询失败不能等同动作失败，更不能让通用重试重放点击。本批先做离线工具修复/真实旧响应重放，不启动设备、WDA或NAS媒体，不改变App/框架/16:16普通包。

最小变更：共用结构化响应/错误分类；仅精确404 stale元素查询允许总计最多3次重新读取，每次核同一scene；其他404、无效session、协议/传输异常停止。动作至多发送一次，返回成功仍需独立实际效果证据；发送异常/效果未确认后阻止继续动作，不能自动重选元素再点。原始错误全文只留私有证据，分享日志仅类型/计数，不暴露SpringBoard树/凭据。

L0：确定性注入查询/动作错误、scene变化、非唯一/无目标、效果确认及隐私检查；另在本机私有目录重放旧实际404响应。成功门槛是旧查询可被辨认为可重读、任何不明动作不会重发；不把模拟后续查询成功写成真机通过。原恢复及Pad延迟画面缺口保留。

独立HDR支线按现有门槛继续，仅在有新可区分元数据/资源证据时推进；不重复旧20上下文或token预算试验。

WDA阶段已完成17项离线测试及旧实际404响应重放，未发设备指令；只读重读与动作一次发送/效果未核时阻断已分离。下一独立阶段用Mac生成192×128 Main10帧，经实际硬件VT编码/解码读取compressed description、CV附件及由CV重建的description，只保存元数据键/类型/长度/哈希，不渲染或碰真实影片。初测PQ的24/4字节静态数据沿途保持；HLG默认Auto窗12帧CV均出现420字节DolbyVisionRPUData，但重建description未列此键。该意外不当DV点亮/丢失结论；按本机SDK的HDRMetadataInsertionMode定义追加显式Auto/None编码控制，解码生成元数据设置单独记录，定位附件来源。App/HDR保护不改。

## 工具边界结果

新增[结构化查询/动作模块](../../../../scripts/wda_command_guard.py)及[17项确定性检查](../../../../scripts/test_wda_command_guard.py)，不自动接管旧脚本。只有精确404 stale元素查询可在同scene最多3次重读；每次核调用方实时scene指纹，目标非唯一、scene变化或其他错误停止。单次动作发送前即设阻断，HTTP错误/超时/效果未核不重新查询再点；HTTP200须独立效果验证，验证异常/非literal true仍阻止下一动作。成功后下一动作也重查当前元素。错误类型/计数可分享，原始响应和异常链只留私有区。

旧Pad真实404响应在私有证据重放：只读elements收到stale后再读取，模拟后续为空列表（没有恢复目标）；同一错误用作动作响应时只发一次动作，第二调用被阻止。没有真实设备/点击/恢复验收，静态scene与恒真effect仅为单测替身，真机调用方不得照抄。模块尚未接旧私有USB transport和实际画面效果核验，也不解决13容器重显后目标仍缺失的问题。两次真实失败继续保留，未追加媒体窗。

## 独立Mac元数据载体结果

新增[真实硬件编解码探针](../../../../scripts/hdr_pip_metadata_probe.swift)，macOS26.7，要求硬件HEVC Main10编码与解码，decoder硬件属性实际为true；最终三组各12帧，共36帧192×128生成图。decoder生成HDR元数据明确设false并均返回0；记录压缩NAL类型、compressed description、propagating/non-propagating CV附件与由原CV重建的description，仅导出键/类型/长度/哈希，不保存字幕/影片或渲染。

| 最终组 | 压缩样本与CV观察 | 原CV重建description |
| --- | --- | --- |
| PQ_staticHDR_auto | MasteringDisplayColorVolume 24字节、ContentLightLevelInfo 4字节，属性设置0；压缩description与12帧CV两字段哈希一致；NAL type62=0 | 12次成功，两字段哈希均与压缩源一致 |
| HLG_auto | NAL type62=12；12帧CV各有420字节DolbyVisionRPUData，12个不同哈希；propagate true返回0 | 12次成功，但未列DolbyVisionRPUData键 |
| HLG_none | NAL type62=0、CV RPU附件0；propagate true返回-12900（本机SDK定义kVTPropertyNotSupportedErr） | 12次成功，无RPU键 |

Auto/None编码端NAL差异实际可见，支持本机这组Auto编码带入逐帧元数据；None的decoder传播属性不支持也保留，不能说两窗所有解码设置都等价。HLG标签或没有主动设DV字段不能证明没有动态元数据。重建description不列RPU键不等于原CV附件消失，当前App保护仍返回原帧，不能宣称已证明产品丢失或DV已点亮。未解析DV profile、没有真实电影/KSPlayer/iOS/PiP、字幕修改后元数据有效性或显示/音画/资源预算验收。

编译首轮参数名不匹配已修，CopyProperty的void*接收改用Unmanaged避免对象引用指针告警，原失败/告警日志与初始默认Auto两组探索均保留。最终显式模式对照是上述三组，不把探索与代码修正后的重复当独立性能样本。没有重新跑旧20合成上下文、旧token预算或NAS媒体。

## 当前边界与接续

[结构化结果](../../../testing/results/2026-10/WDA-BOUNDARY-HDR-METADATA-20261020.json)记录17项检查、旧响应重放、三组控制及属性不支持。当前173个App输入/iOS差异保持，16:16普通包的三二进制/签名离线核对；没有App/框架修改、构建/覆盖安装、设备指令或网络开关。本批未重做真机安装身份/首页/Wi-Fi/偏好/崩溃检查，19:58上一批收尾仅作历史，不能标成新包真机回归。所有生成codec进程已结束，自有主机保活/证据区进程0。

下一步：先把结构化Reply接到私有USB transport，并提供实时scene与实际效果观测的离线集成反例，不能把7/17项通过直接换成媒体重跑；有新可区分现场证据后再补暂停恢复/Pad延迟画面。HDR已明确Mac真实载体，接产品前仍需目标iOS实际inventory/静态与动态处理策略和跨代次资源所有权；不盲拷附件、不放开PQ/HLG保护或恢复已否定token预算。其他API119/弱蜂窝/竞品等未变化，28项开放。

文档/PROGRESS/当前交接/开发状态/唯一总账/功能矩阵/技术路线/CLI手册/HDR接线门槛已同步。17项边界测试、旧实际404离线重放、最终三组36帧硬件编解码与15项preflight通过；文档356份/1846本地链接/缺失0，git diff --check通过。App冻结输入/差异、三二进制/签名仍匹配，未重复App的XCTest、构建/安装或真机媒体采集。
