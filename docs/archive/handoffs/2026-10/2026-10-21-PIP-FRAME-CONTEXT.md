# PiP同帧上下文接线与iOS动态元数据实证

2026-10-21，接[18字幕反馈](2026-10-20-IPHONE18-CAPTION-VIDEO-RECT.md)。关联PX-06/07/20；实际合成/HDR策略未启用，竖屏视频矩形修复保持。原始日志、设备身份、偏好、截图及包只留`/tmp/nastart-pip-frame-context-evidence`指向的本机私有目录。

## 变更卡与接受实现

原回调只有CVPixelBuffer/内容时间，不能得知同一帧独立的Dolby身份、AVFrame侧数据或压缩格式描述；旧Mac20合成反例已证这种信息丢失，当前18真实用户失败也已确认PQ外置文字被保护跳过。本批补实际接线，未再重跑旧Mac元数据/字形/配额实验，未调整蜂窝、网络、解码模式或字幕时钟。

KSOptions新增可选pictureInPictureFrameTransformWithContext，旧二参数入口保留；新回调返回nil直接沿原帧提交，不再走旧回调。FFmpeg在滤镜前记录全部side-data名称/字节数，给实际VideoVTBFrame附压缩description/观察来源；VideoToolbox只标notExposedByVideoToolbox，不能把空字典说成无动态数据。MetalPlayView用同一frame构建不可变KSPictureInPictureFrameContext，随当前buffer/时间送App；App工厂在任何cue/cache/inventory读取前仍核active/完整owner/弱引用。日志仅类型、键名、长度与已知标签，不复制payload或改附件。静态EDR原有路径保持。

九项定向测试正常Xcode退出且全部通过：实际frame到context的Dolby/压缩与显示description/字典快照；完整owner、同短前缀退役、inactive/断开/弱owner；inventory不导出payload且不改原附件；原帧工厂与竖屏几何/文字像素反例。15预检通过。普通Debug/-Onone/Xcode27初包一次构建04:07:31.093151+08:00，173输入/29库签名、profile/三二进制/IPA CRC/AppleDouble/链接核实；iOS diff `2e5cd3c3890a58b542ae579f2964f536a24fcb2a7bdc56558d8b06ae959bbf02`。真实路径与哈希见私有manifest，脱敏三SHA/IPA见结构化结果。

## 设备与有界实测

现场USB重新读取13 iPhone14,5/iOS16.3.1与Pad iPad12,1/iPadOS18.3.1的名称/UDID/系统/连接。13复用已ready的持久WDA，标准系统session/source/PNG通过；04:09保留数据覆盖新包，空环境正常首页/NAS正常实际看图，24非断点偏好、36完整书签与轨道不变、零新增App/WDA/Jetsam。Pad尚未更新/新测，18随后已现场发现既有配对Wi-Fi的iPhone19,7/iOS27.0，但仍23:03旧包、未安装本批包，不迁移旧安装身份。

共享线程只有当前项目任务active，主机没有其他媒体读取；使用原Wi-Fi，不切蜂窝。首个S19导航使用“从头播放”单一后条件而超时，未发Play/PiP，失败/零媒体及清理保留。实际旧工具支持“在Nastart中播放/继续观看”等按钮；第二次改为这组既有语义并保存最后源/故障图，不重发未知动作。通过现有wda_native_actions按当前UIKit边界单次W3C触摸、每步独立读效果，未扩展公共WDA封装。

S19/Jellyfin初包一次真实播放、一次PiP并手动Home；原生3/10/30秒电影图、PiP3/10秒与实际偏好已保存。native普通画面有绿色双行字幕，PiP10秒是片名字卡；该瞬间不能说有cue但丢字幕。停止后偏好落盘新增三条同帧记录：48.841/53.876秒noCue，58.911秒imageCount1且hdrPQPreserved。全部为3840×2160、像素2016686640/PQ、sourceIsDolbyVision=true、frameHasStaticEDR=true、avFrameBeforeFilter；侧数据每帧含Content light8、Dolby Vision Metadata5384、RPU225、Mastering display88字节。压缩description有hvcC752字节；像素与显示description只有色彩/PAR等，未见DV payload，压缩扩展inventory也没有RPU键。

此为实际iOS解码帧的独立动态数据存在证据，不能只看CV附件或PQ标签把该源归普通HDR10；也不证明系统输出点亮DV、具体profile或完整逐帧元数据保真。必须在修改像素后单列DV有效性/输出策略，不能盲拷原RPU或去掉保护。18用户外置字幕片源/入口仍未明确，本窗不替代其复现或把PGS/外置互验。

每窗最外层先停自有App并原生确认无进程，90秒独立期限守卫随后取消，WDA恢复auto/idle10/cool2；原生设置的原网络名称/Wi-Fi及桌面已实际核。24非断点偏好/36原轨道保持，第二窗仅一项自然进度变化、书签无增删，新增App/WDA/Jetsam均0。此为有界元数据观测，不是完整PiP往返、SUB/AUD/帧时间或性能通过；S03对照另记。

## 固定单池的新资源反例

[新探针](../../../../scripts/hdr_pip_fixed_pool_probe.swift)只测试Mac单一固定格式/尺寸池，和已否定的CVBuffer附件token方案不同：池保持存活、minimum4/maximumAge0、allocation threshold4，不创建retired池或按包装释放退额。实际4K10-bit420视频范围四个IOSurface共99,567,616bytes；四个CMSampleBuffer持有时拒绝第五个，12代次的尺寸/范围改变全部拒绝，不能说支持动态格式切换。移除原包装附件、别名保留共享surface后也拒绝新分配，别名像素未改变；释放后24次复用仍只有四个surface。

它只证明该Mac固定池中的分配/别名压力行为；代价是永久持有该池，不能直接当iOS总预算、完整App RSS、动态格式/多实例资源管理或HDR合成准入。旧token反例保持否定，不靠调整quota绕过。后续须在目标iOS独立验证，并解决输出几何/格式转换、资源回收与不同会话共享，未接产品。

## S03与配置快照补证

04:17:54–04:19:59初包S03/Jellyfin真实窗一次Play/一次PiP与手动Home；普通画面PGS双语可见，PiP电影图无字幕。三帧48.2/53.235/58.248秒均imageCount1、hdrPQPreserved，RPU分别391/392/387bytes、metadata5384、mastering88、content-light8；压缩hvcC188bytes。仍不把普通PGS覆盖18外置文字或未观测的播放入口。

随后代码补Dolby配置/profile/compatibility/layer flags快照，VideoToolbox异步提交前同时保留source description/config/fps/timebase，防止旧帧读取重建后的session。九项定向再次正常Xcode通过，04:26后的独立新源码包iOS diff `dd6b530689d6822f973b5ac0d98d89de970079bb2e3113c26f4781177c387f63`；173输入/29签名库/IPA再次核实。13于04:29保留数据覆盖、空环境实际首页/NAS正常；24非断点偏好/36原书签完整保持，零新增App/WDA/Jetsam。此为第二次有必要的不同源码构建，非重复原样构建。

04:29:45–04:31:31短S03新配置窗一次Play/一次PiP，24.052/29.087秒无cue记录已证实际profile7、compatibility6、BL/EL/RPU flags均1；不把PQ标签推断成杜比配置。普通首页、PiP电影、最终原生Settings原SSID与Wi-Fi图标均实际看图核实。三媒体窗均在独立90秒守卫保护下结束，App原生停止/无进程、守卫取消，WDA恢复10/2；每窗24偏好/36原轨道保持，仅各一项自然进度、无书签增删、无新增崩溃。未做蜂窝，未改网络/VPN/用户轨道。

## 后续候选隔离

继续阶段已建立独立私有指针`/tmp/nastart-pip-pq-candidate-evidence`。Debug显式`NASTART_PIP_PQ_CANDIDATE=1`的4K PQ兼容HDR基础层原型另批验证，普通空环境与Release均未启用；当前源码因此晚于本节04:29包，不得继续把它当最新源码回归。正确编码静态24bytes须归一化FFmpeg rational、GBR/白点/max/min大端序，不能复制原MasteringDisplayMetadata内存布局；旧正常Metal静态路径另有编码审计问题，本批未修改也未验收。
