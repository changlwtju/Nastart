# HDR PiP 字幕合成接线门槛

核对：2026-10-21 05:31。当前[普通Debug接受子集](../archive/handoffs/2026-10/2026-10-21-PIP-PQ-NORMAL-DEBUG.md)已默认启用固定4K x420 PQ兼容HDR基础层字幕；Release/其他条件仍保护。14项L0、两台显式候选呈现与实测白点/资源自检后作此受限接受，最新普通包Pad中英PGS两图可见；不等于全格式/完整PiP/杜比动态输出或Release验收。后续门槛仍约束未验范围，不能用Mac或旧显式条件回填当前普通包。

## 输入与输出

| 边界 | 候选必须明确的内容 | 不满足时 |
| --- | --- | --- |
| 帧所有权 | 完整plan身份、seek代次、PiP代次和时钟属于当前播放器；旧回调不能用新播放器时间/新cue改旧帧 | 原帧返回，不刷新当前cue/cache |
| 源图像 | 尺寸、10-bit420全/视频范围、primaries/transfer/matrix；格式与附件一致 | 原帧返回并记结构化原因 |
| HDR格式 | 分开PQ、HLG、DV及未知；PQ标签不能证明没有DV动态信息 | DV/身份未知保持保护，直到独立元数据策略被验证 |
| 字幕输入 | 文本/外置/已解码位图及其alpha、对象origin、canvas、cue有效区间；实际内容不写分享日志 | 无cue不创建画布/池/上下文；过期cue不能回填 |
| 工作与目标 | 显式线性宽色域工作空间，目标保持源位深/全视频范围与正确色彩标签；不经SDR整帧重绘 | 任一不支持/失败返回原帧 |
| 参考白 | 用目标iOS实际转换校准，区分编码亮度、reference white和面板亮度；不得把已归一化的参考白再次乘2.03 | 不选择未经验证的产品亮度系数 |
| 附件 | 显式处理色彩/静态HDR/动态元数据，识别修改像素后哪些仍有效；不能盲拷所有附件 | 无策略的元数据路径保持原帧 |
| 输出样本 | 有匹配新buffer的format description、有效PTS及当前代次，下游接受能力在合成前判定 | 不为不可提交帧分配/渲染；不让旧样本覆盖当前状态 |

当前`MetalPlayView.set`在变换之后创建format description；`AVSampleBufferDisplayView.enqueue`在not-ready分支仍enqueue，不能把该分支当已存在的背压闸门。此为源码事实，尚未测得它在实际PiP的发生频率，也未据此改共享呈现行为。

## 缓存与资源

- 画布缓存键至少包含输出几何、字幕canvas/布局、cue身份及代次；文字/对象消失后不能重用旧画布。
- 池键不能只有宽高，还须包含像素范围/格式与影响输出的色彩配置；变更要建立正确的新池，不向旧格式buffer写新格式像素。
- 每池allocation threshold不能当全局预算。真实CMSampleBuffer可在换池后继续持有旧buffer；新/旧池各四个4K目标已达到199,134,720bytes。还未包括源图、画布、工作纹理及显示层内部持有。
- 接线前需有跨代次资源准入和可测的释放机制；仅把`pool=nil`或flush excess buffers不证明已回收下游持有。连续切换不得不断新增retired pool并用单池阈值宣称有界。
- 所有分配失败/池耗尽/上下文不可用保持原帧可提交。无cue路径与被拒绝的旧代次应零新增合成资源。
- 先测真实目标设备峰值和长时平台，再确定输出分辨率/帧率/总字节预算。Mac调用耗时和两池数据量只用于选择反例，不是iPhone性能预算。

### 已否定的附件预算机制（不得接App）

[寿命探针](../../scripts/hdr_pip_lifetime_probe.swift)早期七类/十二代次及Mac离屏层实验，只验证保留附件的同一CVPixelBuffer包装。新增[共享surface反例](../archive/handoffs/2026-10/2026-10-20-PIP-FRAME-OWNERSHIP.md)已否定其全局上限：新的CVPixelBuffer可共享同一IOSurface而没有token，原包装释放后预算归零、新池准入，但别名仍持有24,891,904bytes；移除附件也会在原buffer仍持有24,891,840bytes时提前退额。不得接入产品或靠调整150MiB实验quota修补此所有权缺口。iOS/PiP真实资源上限仍未解决。

完整plan身份检查已单独接入实际帧回调工厂：active、完整UUID及弱控制器存活先于cue/cache/变换；KS与AV开始会话设置身份，disconnect立即失效。它只解决会话归属，不等于seek/PiP全部代次或HDR资源门槛完成。

## 确定性反例与验收分界

| 层级 | 必须保留的用例 |
| --- | --- |
| 位图/色彩L0 | 实际中英字形、彩色/半透明边缘、PGS调色板解码；全/视频范围，1080p/4K；未覆盖区与控制像素；裁切、非1:1画布、无效尺寸 |
| 生命周期L0 | cue→无cue→新cue、暂停、seek旧cue迟到、PiP退出/再进、plan替换旧buffer回调；不得混用所有权 |
| 资源L0 | 同尺寸换范围/色彩、换尺寸、旧CMSampleBuffer持有、池耗尽、分配/format-description失败；回退、恢复及跨代次总量 |
| 真机L1/L2 | 当前正常包核验后，SDR与已确认的PQ/HLG/DV分列，两设备/两入口按实际路线选覆盖；全屏→后台→恢复→关闭及真实字幕内容、色彩、音画、帧时间/内存 |

当前只有Mac字形/生成PGS像素往返与部分HDR样本数值。CLI sub2video在cue起始边界缺一帧的现象保留，不当App字幕时序通过；电影真实PGS、iOS画布/API行为、完整边缘/长时资源和DV仍未完成。当前普通Debug仅接受下文已验证的固定兼容子集；扩展格式/完整默认Release交付仍需这些门槛闭合，不能删除其他HDR保护。

## 2026-10-20 实际帧上下文边界复核

本节保留10-20接线前审计背景，表中10-21项为实际更新；当前启用范围以页首与普通Debug接受记录为准。见[会话与PiP闭环批次](../archive/handoffs/2026-10/2026-10-20-SESSION-VALIDITY-AND-PIP-ROUNDTRIP.md)。

| 源码位置 | 当前实际数据路径 | 接线限制 |
| --- | --- | --- |
| `FFmpegDecode.swift`侧数据循环 | 静态mastering/content-light/ambient数据写入`VideoVTBFrame.edrMetaData`；DOVI RPU/metadata、HDR10+/Vivid分支只读取局部变量，未在该循环写入帧上下文 | 这不证明硬解CVPixelBuffer自身没有元数据；当前实际附件及DV输出仍未知，不能概括为所有DV信息已丢失 |
| `Resample.swift`的`VideoSwresample.change` | VideoToolbox输入直接取原CVPixelBuffer；软件路径转像素并设置色彩标签；`isDovi`取自asset track标志后保存在frame | 硬/软路径分开核验，不由PQ或文件名判定DV profile/实际显示 |
| `Model.swift`的`VideoVTBFrame` | `isDovi`与`edrMetaData`独立于`corePixelBuffer`存在 | 仅传CVPixelBuffer不能保证接收者知道这些字段 |
| `MetalPlayView.draw` | 留存frame的`isDovi`；Metal路径给metalLayer设置`frame.edrMetadata`，sample-buffer路径则使用CVPixelBuffer及其format description | Metal层的EDR配置不自动等于sample-buffer PiP已有同样上下文 |
| `KSOptions.pictureInPictureFrameTransformWithContext`及`MetalPlayView.set` | 10-21新增同一decoded frame的Dolby身份/配置、静态EDR存在性、侧数据名称/长度/观察来源、压缩/显示description；旧二参入口保留，新入口拒绝不走旧入口 | 已用于两源真实iOS只读inventory；已接正确24bytes静态编码，兼容基础层不复制旧动态payload；普通Debug受限准入，Release/其他格式仍保护，完整动态保真与资源长稳未验 |
| `GreenfieldPiPSubtitleCompositor.composite` | 当前三参数重载在有cue时先核普通Debug开关、实际帧上下文与固定PQ准入；线性2020/10-bit PQ/正确mastering的新样本描述由MetalPlayView重建 | 已知兼容基础层才处理；未知动态信息/HLG/格式尺寸/元数据/运行时自检失败保持原帧，不能以PQ标签代替DV配置 |

另须区分回调的内容时间与实际输出：当前enqueue使用`.zero` sample PTS及`DisplayImmediately`，传入回调的`time.seconds`不能当作显示层已呈现的PTS。本文不据此改时钟/显示策略。新元数据上下文、失败回退与真实iOS输出先做可区分反例；保留现有保护，不盲拷动态附件或把设计字段写成已交付API。

## 上下文缺失与未知拒绝的可执行反例

[Mac探针](../../scripts/hdr_pip_context_probe.swift)与[本批结果](../archive/handoffs/2026-10/2026-10-20-PIP-PAUSED-RESTORE.md)新增20个合成输入用例，没有修改App或实际回调接口。运行方式：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/hdr_pip_context_probe.swift <仓库外私有输出目录>`。

同一个CVPixelBuffer和同一内容时间可投影自模拟非DV/DV上下文，明确已知的非DV fixture与显式DV得到不同的候选判定；现有回调参数却相同。因此三类色彩标签不能替代独立frame身份/元数据inventory。该实验未测实际硬解附件，不能断言实际DV信息全丢失。

探针分别拒绝未知frame Dolby身份、未知动态inventory、未知/未处理静态EDR和缺源description上下文；显式DV即使缺transfer也拒绝，HDR10+/Vivid不借PQ标签放行。退役plan/无cue在准入函数内不读元数据；拒绝项不调用renderer。PQ/HLG×全/视频范围四个已知fixture只验证上下文层，renderer故障注入后仍返回同一原buffer/标签，不分配目标buffer。参考白、真实字幕、下游接受与全局资源所有权均未被本探针解决，“上下文可实验”不能当产品准入。

## Mac硬件编解码的元数据载体观察

[元数据探针](../../scripts/hdr_pip_metadata_probe.swift)以192×128生成Main10帧，经本机硬件VT编码/解码读取压缩description、CV附件和由原CV重建的description。最终PQ静态Auto、HLG Auto、HLG None三组各12帧，硬件解码实际返回true；不是KSPlayer/iOS/电影/DV profile或画面亮度验收。详见[本批归档](../archive/handoffs/2026-10/2026-10-20-WDA-QUERY-ACTION-BOUNDARY.md)。

- PQ的24字节MasteringDisplayColorVolume和4字节ContentLightLevelInfo在压缩description、12帧CV和重建description中哈希一致。
- HLG Auto压缩样本有12个NAL type62，12帧CV各有420字节DolbyVisionRPUData、哈希各异；HLG None两者均为0。两组均明确关闭decoder生成HDR元数据并返回0；传播true在Auto返回0、None返回`kVTPropertyNotSupportedErr(-12900)`，该配置差异保留，不说解码设置全部等价。编码端Auto/None的实际NAL差异可独立观察，不能由HLG标签或未主动设置DV字段推断没有动态元数据。
- HLG Auto由原CV重建的description没有DolbyVisionRPUData键，但原CV仍持有附件。不能据此宣称当前App已丢失动态元数据；修改像素、新建CV或只拷色彩标签须另验。当前PQ/HLG原帧保护继续保留。

这些本机生成样本补了真实CV附件载体证据，未证明真实iOS硬解的完整元数据inventory，也没有解决字幕修改后动态元数据的有效性、DV显示或全局资源所有权。

## 2026-10-21实际iOS输入与下一候选

[本批接线/实证](../archive/handoffs/2026-10/2026-10-21-PIP-FRAME-CONTEXT.md)已用13的S19与S03/Jellyfin取得实际AVFrame-before-filter数据，两者均4K PQ且独立Dolby身份为true；侧数据有静态mastering/content-light与动态RPU/metadata，像素/显示扩展却未见这些payload。S03三帧RPU391/392/387字节，不能把动态数据当固定静态拷贝。这个结论不替代18用户外置字幕原片/入口，配置补窗已证S03 profile7/compat6，但不证明具体DV显示。VideoToolbox异步上下文须在发解码请求时保留description/配置/fps/timebase，不能读取稍后被重建的self.session；notExposedByVideoToolbox仍是未知，不当无动态数据。

[固定单池探针](../../scripts/hdr_pip_fixed_pool_probe.swift)的新Mac反例使用唯一长寿命固定配置池、禁止age-out/换池。四个4K10-bit420表面共99,567,616bytes；四个真实sample/共享surface别名仍持有时均拒绝分配，24次同池复用保持四表面。只验证此固定配置，变尺寸/变范围全部拒绝；永久占用、iOS/多实例/完整App峰值和动态格式仍未验，未接产品，不推翻旧附件token否定结论。

下一候选先限Debug显式实验及已核实的PQ兼容基础层：保留位深/色彩，允许哪些Dolby配置输出HDR10必须由实际profile/BL/compatibility记录及[Dolby官方profile表](https://ott.dolby.com/OnDelKits/Dolby_Vision_Online_Delivery_Kit/v1/Documentation/Specs/Visio_Profiles/help_files/topics/c_dovi_profiles_public.html)逐项核对；不得由PQ标签推断，不冒充保持DV动态输出。未知/不兼容profile、HDR10+/Vivid、未知侧数据检查路径均原帧返回。修改后的帧不能盲带原RPU或MaxCLL/MaxFALL；mastering数据按Apple SDK要求的24字节大端SEI及实际有理数单位独立编码/验字节，不能直接拷内存结构。

该段是待实现/验证的候选范围，尚未改变产品HDR/PiP路线。启用普通包前仍须目标iOS白亮度/未覆盖像素、真实文本/位图、已知峰值/跨代次资源及两设备受影响路径证据；实验结束恢复最新空环境普通包。

## 10-21显式候选实现

`NASTART_PIP_PQ_CANDIDATE=1`仅Debug开启，默认/Release仍保护。固定4K x420、PQ/2020、FFmpeg-before-filter已知侧数据，Dolby仅已核兼容7.6/8.1基础层；保留10-bit PQ，正确归一化并重编码mastering 24bytes，丢弃原RPU及不再适用的CLL/FALL，明确输出为HDR10兼容基础层，不宣称杜比动态保真。池固定且不退休，surface ID终身账本遇第五个新surface停用，不再尝试第六个；单进程白点/roundtrip/4持有及共享surface别名自检失败则原帧回退。校准后14项L0正常通过，13/Pad S03原流系统PiP3均实际中英PGS可见；实测白点分别99.9128/203.703nit，按实测增益仅处理字幕后203.703/201.490nit，roundtrip0及固定四surface/别名检查通过。13短窗phys峰1097.754MiB/RSS261.469MiB，不是长稳/全App上限；外置文字、完整音画/帧时间与暂停恢复仍未验收。旧正常Metal静态元数据内存布局审计问题独立保留，不能把此候选编码说成已修全部HDR路线。

## 普通Debug接受决定（05:31）

相同合成路线已从显式条件接入普通Debug默认，环境0可退回旧保护，Release仍false；入场条件和设备校准/固定池校验未放宽。当前仅接受受限功能实现，不关闭全部验证门槛；最新普通包Pad实际呈现与13输出记录分列，13最新截图未落cue不判实际字幕通过，外置文字/竖屏/闭环与完整资源/音画仍接续。详见[普通记录](../archive/handoffs/2026-10/2026-10-21-PIP-PQ-NORMAL-DEBUG.md)。
