# TS 跳转解码观测：iPad 花屏仍未修复

关联 PX-02、PX-20、PX-21，接续 [上一轮扩展验证](2026-10-13-TS-SEEK-EXPANDED.md)。本轮完成限量观测和双 USB 对照；没有实施播放策略修复，不能标 L1/L2 或稳定发布通过。

## 安装与源码门槛

- 2026-10-13T07:49:39.666356+08:00 收尾。现场逐机核对名称、UDID、连接和系统；USB13为iPhone14,5/iOS16.3.1，USBPad为iPad12,1/iOS18.3.1，均解锁、已有WDA ready。原始身份仅在私有证据。
- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，未提交iOS差异SHA `ac8f176e1d138ab418055d894cddd7d6858dc95d3059b3ed1878a24cc78bb1b1`；只新增FFmpegDecode.swift的DEBUG限量元数据。启动/每次flush分别最多2/12包、2/96帧，记录包标记、发送返回值、帧格式/错误及flush epoch，不记录媒体内容、URL或凭据。没有改变解码、seek、Range、缓冲或片名策略；日志有开销，本轮不接受性能结果。
- 普通Debug构建 `2026-10-13T07:29:18.221360+08:00`，173输入、29库逐项签名/deep/profile/链接/IPA三SHA重核。主 `7cc99e076d3a49293fe664c4d09ab186986bbd8622f661e5ddde39734d5a5370`；Debug `0e2bae07cc4f8444b6ba7249cea33ae02c53ab8f350bb175ef1b0bab64bae4c2`；KS `6be1f6780b3edd377d2ef6ee2e144c9213b831f45969eedbb7f7601b93067559`。
- 当前包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-13-ts-seek-rootcause-071852/Nastart-Seek-Decode-Metadata-Normal-Debug.app`。最新包保留容器覆盖：Pad `2026-10-13T07:31:54.153132+08:00`，13 `2026-10-13T07:38:42.022743+08:00`；18/25非诊断偏好安装时逐值一致。空env/args正常首页实际图已看后才开窗，没有卸载/清数据/改登录、网络、系统、NAS录制或重装WDA。
- 最新源码实际348测试、2跳过、0失败，15预检及构建通过。初版e434仅日志通道不同，测试/Pad安装留历史，未开回归窗；最终ac8再测试、覆盖后采集。18本轮未操作，当前包安装身份/实际UI/自动隧道不作已验。

## 已取得的证据

- 同一已有录制TS02（mpegts/HEVC Main1080p8bit30fps/AAC，上轮1126170624bytes/1802.641677秒），不是当前增长录制的追尾验收。两机串行从头30秒→暂停→中段/85%/25%/中段四次拖动→暂停t3/10/30→前进15×3、后退15×4、前进15×1→暂停t3/10/30→恢复90秒请求窗→普通关闭。实际请求间隔和全部失败保留在JSON；不是同一计时或全回调/逐帧性能采样。
- 两机原始输出均为`framePixelFormat=158`、`hwFrames=true`；当前包依赖头文件独立宏值探测确认158为AV_PIX_FMT_VIDEOTOOLBOX。实际FFmpeg硬解输出已确认。`hwDevice=false`的上下文字段不覆盖硬件帧证据，也不能用原`ffmpegVideoToolboxEligible`配置标记替代此证据。
- Pad四次拖动后选定暂停图14:45未见旧大片花屏；按钮后14:45在t10、t30均出现明显眉毛/额头/面部方块与重影，**FAIL仍未关闭**。两次强制提交均报告目标885.4559801111111/PTS886.859，不能把报告PTS视为独立源帧身份或正确内容证明。恢复t90图16:16场景正常、退出正常，不能抵消暂停失败。
- Pad清晰阶段epoch8与失败阶段epoch24，最先12个输入包和17个原始输出帧的已记录数值字段分别一致，首帧原始PTS79817310/90000=886.859、flags=0/decodeErrors=0，而实际图像质量不同。尚无包内容摘要/输出像素摘要/独立同帧参考，所以参考帧/硬解会话/队列代次的具体根因未确认。
- Pad限量记录153包/273帧，60个发送返回AVERROR_UNKNOWN(-1313558101)，其余93为0。13限量152包/217帧，64个UNKNOWN、其余88为0。两机采集的帧decodeErrors均0、无CORRUPT位；13选定拖动/按钮暂停图14:46未见旧大片花屏，恢复t90图16:17及普通关闭正常。UNKNOWN并非Pad独有，不能直接等同花屏原因；没有观察到EAGAIN，不能按猜测修EAGAIN丢包。
- 两机12次seek请求各24条flush记录；多个采样首包为非关键帧。需要继续核对随机访问/参考帧/flush后的所有权，未据次数认定重复flush就是根因。记录中的generation为启动观测代次0，不是seek请求身份；没有宣称代次隔离已验证。
- 源码原先把非0的avcodec_send_packet返回直接忽略，当前仍保持行为；新增日志确认此诊断缺口。官方[send/receive契约](https://ffmpeg.org/doxygen/trunk/group__lavc__encdec.html)可用于后续区分需接收重试的EAGAIN和实际解码错误，不能用它推断本样本根因。

## 受限对照、收尾与下一步

- 旧35ed普通包Pad单次原生滑块请求885.455980实际897.354637/提交898.759，t10有局部皮肤纹理斑块且缺原始参考，随后恢复30秒/退出正常；**不计同位置源帧排除**。iPad长名称元素404、13工具缺native_touch方法、宏探测缺include路径都留TOOL，已用当前UI/正确API或隔离头文件修正，不当播放通过；Mac隔离PyAV仅准备，未获得独立源帧。
- 双USB前后完整Nastart/WDA/Jetsam报告文件集合均0新增，历史13 Network SIGTRAP及物理内存归属未关闭。未测physical footprint、长期压力、实际声音、字幕完整性、HDR或显示帧时序。
- 最终13原24/Pad原17非书签偏好逐值不变，各1个TS02书签自然更新，原S03文件/Jellyfin整条书签均不变。两机最新普通包空环境实际首页/NAS正常、播放器关闭、WDA idle10/动画2已核。
- 下一步：匿名输入包/输出像素摘要及真实seek所有权，再做同源受控软/硬解对照，确认共享缺陷后最小修复和原失败双USB回归。暂不扩大格式验收掩盖暂停图像失败。
- S01四单元、L2代表族/S19/MTP、真实增长尾部/时长刷新、历史SUB/AUD/HDR、竞品完整帧时序/蜂窝/19×4、PX/UX/CB/Main/L2/L3与18实际UI/自动隧道全部旧未验账保留。

证据JSON：[TS-DECODE-TRACE-20261013](../../../testing/results/2026-10/TS-DECODE-TRACE-20261013.json)。原始图/身份/偏好/凭据/日志仅本机私有目录 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-13-ts-seek-rootcause-071852`。
