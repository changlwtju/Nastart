# HDR PiP 字形、参考白与下游持有

日期：2026-10-20。承接[八组池原型](2026-10-20-HDR-PIP-POOL-AUDIT.md)，关联PX-07；本批仅离线Swift探针/设计，不改App或移除PQ/HLG保护，不发媒体、不操作设备。

## 执行前变更卡

- 当前App基线仍14:20普通Debug及iOS差异`88efcc6f4c76662d29b16603b7665a0974cf1a952aa4796dbd181bfe306177f7`；13/Pad/18设备状态承接当前交接，不以旧状态替代下次真机闸门。
- 缺口：此前只有常量条带，未经过实际字形栅格化/bitmap对象坐标，参考白物理含义未验证；单池threshold4不能证明跨格式代次的总资源限制。
- 最小实验：新增Mac命令行探针`scripts/hdr_pip_overlay_probe.swift`，CoreText实际中英字形及含alpha的生成位图对象，明确标为PGS形状fixture，非电影PGS解码/字幕内容验收。PQ/HLG、全/视频范围、1080p/4K；透明/有色未覆盖区、alpha、PQ白色编码值与布局另验。
- 参考白：先只测当前CoreImage profile转换后的10-bit灰阶码值，再用ST2084得到编码亮度；禁止凭SDR/HDR白点比先乘系数。测的是编码值，非手机面板亮度，不擅设产品字幕nit策略。
- 资源反例：同尺寸不同像素范围的两个池，各threshold4；用真实CMSampleBuffer持有旧/新像素缓冲，核各池拒绝第5个但总量可超过单池。模拟下游持有，不当实际AVSampleBufferDisplayLayer保留时间/内存。
- 保留真实原型失败/工具错误，输出原始PNG/日志在本机私有`/tmp/nastart-hdr-overlay-evidence`指向目录；分享JSON去路径/设备/凭据。L0离线观测不能升级为App/iOS/DV或字幕完整验收。
- 未改播放链路，不触发新App构建/安装或L1/L2；若后续产品接线，另做最小共用变更卡及相关SDR/HDR/PiP回归。

## 实际结果：参考白、字形与生成PGS

新增两个可复用的离线工具：[Swift字形/合成/持有探针](../../../../scripts/hdr_pip_overlay_probe.swift)、[PGS fixture写入器](../../../../scripts/hdr_pip_pgs_fixture.py)。没有改App、KSPlayer或现有正常包，不产生手机/Pad最新包回归结论。[结构化结果](../../../testing/results/2026-10/HDR-PIP-GLYPH-LIFETIME-20261020.json)保留原始指标、失败及限制。

先以64×64灰阶10-bit420读真实luma plane，按视频范围64～940/全范围0～1023归一化并用ST2084换算PQ编码亮度：

| extended-linear BT.2020输入白 | video PQ编码nit | full PQ编码nit |
| --- | --- | --- |
| 1 | 203.703 | 202.915 |
| 2.03 | 410.089 | 412.629 |
| 2.5375 | 517.824 | 513.093 |

这是当前Mac/CoreImage profile的实测。不能看见SDR/HDR参考白不同就再乘2.03；它会在本机重复抬升。HLG与手机面板亮度没有由此得到绝对nit结论。Apple对EDR/reference white、ISO HDR默认203及不夹限工作空间的说明可见[官方WWDC23](https://developer.apple.com/videos/play/wwdc2023/10181/)；这里的输出码值测量是独立证据，不把静态图API说明当iOS16视频验收。

CoreText实际栅格化中英字形，无缺失glyph；512×128透明画布包含不透明白、半透明白及红色控制块。放在1920×1080字幕canvas的top-left(400,800)，再映射1080p/4K源；PQ/HLG×全/视频范围共8组。实际PNG检查可见完整文字及三个块，未用HDR高亮被SDR预览夹白的图验布局；最终采用另绘SDR暗底预览，它只验位置/可见性。

继而将同一生成字形写入真实PGS PCS/WDS/PDS/ODS/END，8557bytes，17色调色板，alpha显式量化为17步长；用本机已有FFmpeg7.1 `hdmv_pgs_subtitle`解码。它是**生成PGS协议fixture**，不是电影原始PGS。活跃帧的非透明bbox为(408,834,775,920)，裁回对象后所有像素alpha、可见RGB均与量化后的期望图完全相同；不声称与未量化的原始CoreText alpha无损。生成/解码布局依据可核[FFmpeg原始解码器](https://github.com/FFmpeg/FFmpeg/blob/n8.0/libavcodec/pgssubdec.c)，实际运行版本另列，未把官方新版本当本机二进制。

解码后的PGS对象又作为HDR输入，追加同8组，合计16组字形/解码PGS数值观测。白控制块PQ仍203.703/202.915编码nit；两处未覆盖中性/彩色控制样本前后最大差0（不是全帧广色域验收）。8-bit画布alpha128/255与量化后PGS alpha136/255分别用实际栅格化alpha/颜色计算线性混合期望，不能借理想Float0.5掩盖输入精度边界。

| 输入对象 | PQ/video最大半透明RGB误差 | PQ/full | HLG/video | HLG/full |
| --- | --- | --- | --- | --- |
| CoreText RGBA8 | 0.002295 | 0.009230 | 0.002593 | 0.007545 |
| 已解码生成PGS | 0.011292 | 0.007591 | 0.001778 | 0.005503 |

各值在1080p/4K相同。此前常量条带误差<0.009不能直接升级为实际字形/所有alpha的通用阈值；本批只报告实测，不通过调系数或挑值把新对象误差改成PASS。字形边缘/色度子采样/广色域/手机API仍需单独判定。

## 直接接续：真实CMSampleBuffer持有反例

先有4K视频范围池，四个输出用CMSampleBuffer持有，再建同尺寸全范围池并持有四个输出。两个池各自第5次分配均以-6689拒绝，但八个下游样本合计像素数据199,134,720bytes，约190MiB；**单池threshold4不是跨代次总内存上限**。这是新原型资源反例，不是已测得手机App泄漏。所有样本/池在有界进程结束前释放，不能由此承诺系统显示层何时释放。

源码接续核对：`MetalPlayView.set`在frame transform之后生成format description；`AVSampleBufferDisplayView.enqueue`在not-ready分支仍enqueue，故现有该分支不能替代合成前资源准入。未测发生频率，不据此改共享呈现/丢帧策略。旧plan/seek/PiP回调身份也必须在合成前核，而不是只拿当前播放器时间处理任意旧buffer；目前没有真机旧帧污染结论。

已冻结[候选接线门槛](../../../development/HDR-PIP-COMPOSITION-CONTRACT.md)：明确源traits/DV保护、参考白、cue与输出代次、池键、跨代次资源预算/释放、下游ready、无cue及失败原帧回退反例；它是设计约束，非已交付实现。后续只有补齐这些反例才接产品候选，不能直接把每池4缓冲当已完成资源设计。

## 再接续：预算跟随像素对象寿命

新增[真实CVBuffer寿命探针](../../../../scripts/hdr_pip_lifetime_probe.swift)，验证一个候选机制而非修改App：共享预算先预留整个有界池容量，池拥有者和每个输出CVPixelBuffer共持同一Reservation；私有附件采用shouldNotPropagate，token不反持pool/buffer，避免循环。池销毁不能提前归还下游还持有的像素配额。

本机实验quota150MiB、每池保守预留136,904,704bytes（实际四帧99,567,360bytes），均是实验参数，**不是iOS生产预算**。七类断言实跑通过：

1. 四帧由真实CMSampleBuffer持有，第五帧实际CoreVideo拒绝。
2. 释放池拥有者后样本仍持有，预算保持；新格式池准入被拒绝。
3. 释放所有样本，但单独保留其中CVPixelBuffer，预算仍保持。
4. 最后独立像素释放后预算归零。
5. 再试新格式池准入成功。
6. 注入池创建失败，预留归还且计数不负。
7. 十二次全/视频范围交替，同样先持旧样本、拒绝新池、释放再恢复；每轮归零，峰值仅一池预留。

这补齐“资源必须跟随真实像素对象，而非仅跟随pool变量或CMSampleBuffer”的确定性依据。仍不能称跨进程/GPU/IOSurface总量硬上限：外部消费者是否移除私有附件、生成共享IOSurface的新wrapper、iOS系统显示层实际持有方式尚未验证；此候选未接产品，也没有真实no-cue/代次/失败原帧提交回归。不要把七类/十二代次结果改成HDR/PiP交付或直接选用实验quota。

## 继续接续：Mac实际显示层的持有与flush

同一寿命探针新增显式`--display-layer`模式，使用真实Mac `AVSampleBufferDisplayLayer`离屏enqueue四帧初始化后的黑色10-bit视频缓冲；未创建窗口、操作设备或采集影片。生产者池和样本局部变量释放后，136,904,704bytes预留仍在；五次请求0.1秒runLoop推进后的采样均持有。层status=rendering/error0，flushAndRemoveImage调用后的即时采样仍持有，随后首个runLoop采样归零，释放层后仍0。

这说明**本次Mac离屏显示层**真实保留了携带token的像素寿命，不能用enqueue返回当释放。采样不是精确释放时限，不推断“100ms以内必释放”；rendering状态也不证明可见画面或HDR点亮。它补充了系统框架层证据，尚非iOS/PiP、共享IOSurface别名或第三方移除附件条件验收。保持产品原帧保护与未接入状态。

## 失败、工具时间与限制

- 首次Swift编译失败为Int画布高度未显式转CGFloat，未执行原型；修正后运行。没有App构建失败或设备操作。
- 首次SDR预览把HDR背景夹成白色，字形位置无法可靠观察；原图保留，增加单独暗底布局预览，没有把它冒充HDR画面。
- 初始误以Float0.5作为RGBA8半透明期望；保留该比较，同时改为实际alpha及over-black颜色计算。该口径修正不改变合成系数或原始输出。
- 默认FFmpeg会归一化字幕输入起始时间，不能把输出文件序号直接当原cue时间。追加一次copyts/showinfo后，输出t0空、t1起始边界仍空、t2像素正确、t3结束后空。**精确起始时刻验收失败/未解释**，不能以t2通过掩盖；不继续调CLI参数。保留两次工具时序数据，它不证明iOS/App的cue生效/清除时间。
- 未使用NAS或新媒体，探针均有界退出，无设备/Wi-Fi/蜂窝/VPN操作。iOS差异和173源码输入未改变，13仍14:20正常包、Pad09:47旧包、18离家；这里沿用的是安装记录，没有声称现场重新核设备。
- 电影实际PGS/文本/外置、iOS16/18的CoreImage/画布行为、动态元数据、完整字形边缘/裁切、跨代次资源准入与长时平台仍未完成。没有移除App HDR保护，没有交付HDR/PiP修复；总账28项开放。

跨池生命周期机制已按上节补确定性验证；Mac离屏显示层已补持有/flush观察；下一步核iOS/PiP、共享surface/附件语义及所有权，再决定有界App候选。无需为这些离线问题反复构建/蜂窝或猜系统PiP按钮。
