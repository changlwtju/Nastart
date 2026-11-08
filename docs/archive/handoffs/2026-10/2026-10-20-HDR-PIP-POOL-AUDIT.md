# HDR PiP 离线 alpha 与像素池边界

日期：2026-10-20。完成[真实蜂窝观测及三段离线审计](2026-10-20-REAL-MANIFEST-TIMING.md)后直接接续独立PX-07，未新增调度、App源码/包、设备操作、NAS媒体或蜂窝请求。不是重复32×32旧实验，本批新增1080p/4K、全/视频范围、半透明/黑描边与池压力维度。[结构化结果](../../../testing/results/2026-10/HDR-PIP-POOL-AUDIT-20261020.json)；Swift原型及完整运行日志留本机当前私有证据区的`hdr-pool-audit`，根指针`/tmp/nastart-manifest-timing-evidence`。

## 前置与现有实现

承接[真实PiP路线](2026-10-20-RECONNECTED-PIP-ROUTES.md)：13/JF原流PQ有位图cue，但当前`GreenfieldPiPSubtitleCompositor`命中`hdrPQPreserved`，保留原帧；Pad服务端烧录可见不能替代原流本地合成。App当前SDR合成池输出BGRA，按尺寸复用，分配threshold4；PQ/HLG在分配前退出。**本批未删除保护、未接入HDR产品实现。**

此前Mac32×32原型只测未覆盖区域高亮。本批以extended-linear BT.2020/RGBAh工作空间，将源及目标设为同一10-bit420全/视频范围，显式只写primaries/transfer/matrix三类色彩标签，不盲目复制全部附件。用线性约4的中性源，叠加sRGB白色alpha1、白色alpha0.5、黑色alpha0.8条带，另留透明区；不选择字幕参考nit值，也未使用实际字形或PGS画布。

## 八组数值与池压力结果

| 转移/范围 | 1080p与4K最大条带线性误差 | 未覆盖区高亮 | 四个4K输出缓冲字节 |
| --- | --- | --- | --- |
| PQ/video | 0.008200 | 4.011203保持 | 99,567,360 |
| PQ/full | 0.003342 | 4.002965保持 | 99,567,360 |
| HLG/video | 0.008470 | 3.997329保持 | 99,567,360 |
| HLG/full | 0.002236 | 3.989660保持 | 99,567,360 |

全8组均分别持有4个目标buffer，第5次使用相同threshold4请求时返回`kCVReturnWouldExceedAllocationThreshold`且无buffer；释放持有数组后可再分配。4K目标池持有数据约95MiB，尚未计源帧、工作纹理、字幕画布、下游样本持有或播放器其他内存，不把四缓冲预算当整个App上限。1080p四目标为24,900,480bytes。

Mac单进程峰值RSS226,836,480bytes，memory footprint255,312,808bytes。首次PQ/video 1080p CoreImage调用约155ms，其余该组合约1.7～2.0ms；4K约1.7～5.5ms，完整逐次值在JSON。它是本机render/read-lock墙钟，包含首次准备且并非逐帧GPU/显示计时；不换算iPhone帧率、不作手机性能通过或长期无泄漏证明。

首轮手动指定旧Downloads编译器却沿用当前默认27 SDK，Swift6.3.3/SDK6.4不匹配，在编译期退出1，未执行原型。失败日志保留；改为明确`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`下匹配的`xcrun swift`后原脚本运行成功，没有修改App或切换系统默认Xcode。

## 接续门槛与缺口

此结果补齐真实4K尺寸的基础灰阶alpha/池耗尽与恢复，支持继续设计，不证明完整HDR字幕可发布。仍需：实际字形/PGS alpha与位置、彩色/广色域/透明边缘、字幕参考白亮度；尺寸/格式/全视频范围/色彩变化时池键和缓存重建；no-cue零合成、分配失败原帧回退、下游sample-buffer持有与长时间资源平台；seek/PiP代次隔离；iOS真机色彩/4K资源及PQ/HLG/DV分别验收。DV动态元数据不能盲拷后声称保真。

下一步优先在离线设计中冻结这些输入/输出边界与最小反例，再决定是否新增有界候选；缺实际转移/元数据证据时保留原帧保护。不要直接把Mac八组通过改写为产品实现、iPhone13或iPad验收。本批无设备新状态，13仍14:20正常空环境包/已核原Wi-Fi，Pad仍09:47旧包、18离家；蜂窝前批已先停流并恢复。28项保持开放。
