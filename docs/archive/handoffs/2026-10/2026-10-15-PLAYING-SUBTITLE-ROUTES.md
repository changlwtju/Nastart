# 播放中字幕切换：兼容流与文本路径分开观测（2026-10-15）

本轮继续PX-20，完成6次S19兼容流字幕往返与2次S03文本字幕对照。没有App源码修改、新构建或完整播放验收。已定位可重复的等待阶段，尚不能将其全归因于NAS转码或网络；此前36次原生音轨及12次固定暂停点基线继续按原范围保留。

## 源码、包与安装门槛

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS未提交差异SHA `db8730452eaa5f58db20b0e1f74323da31540bf40575e3784d09c0f7ca1cb570`。173输入与11:39普通Debug（-Onone）一致、无晚于产物输入，三二进制SHA、29库独立签名/deep、IPA CRC/SHA及profile重核。394测试/2跳过/0失败和15预检是11:39同源结果，本轮未重跑。

- iphone13：现场核名称/UDID/型号/系统/USB，iPhone14,5/16.3.1；2026-10-15T16:42:06.699153+08:00保留数据覆盖最新包，25项安装偏好保持；普通空env/args首页实际图已看。
- ipad：现场核名称/UDID/型号/系统/USB，iPad12,1/18.3.1；2026-10-15T16:42:34.777885+08:00保留数据覆盖最新包，18项安装偏好保持；普通空env/args首页实际图已看。
- iPhone18：旧配对地址检查与新鲜服务3候选均未核到在线目标/容器，未发送Install；最后确认07:29 f5旧包，不含状态栏/字幕锚点/音轨后续优化。最新包可用不等于18已更新。
- 原始设备标识、地址、凭据、媒体/字幕内容、截图、偏好及完整日志只留本机私有目录。`/tmp/nastart-current-evidence`指向audio-output-capture窗口；previous-root保留上一批，不覆写旧样本。

## S19：真实发生了自动换流

13 Jellyfin从头播放最初为KSPlayer/directPlay，+14.030秒记录`automatic_downshift_requested reason=deliveryBelowSourceBitrate`，+29.956秒完成AV/localHLS替换。这是引擎记录的策略原因，不代表已独立确认真实吞吐或策略判断正确。

字幕操作发生在这一替换之后，实际为AV/HLS的PGS服务器字幕替换；Jellyfin报告Transcode，规划为localRemux/localHLS。不能把本轮等待解释为KS原生PGS的共享seek，也不能将之前原生音轨优化统计搬来比较。

3次往返，均切到另一PGS行后回原行；正常播放、无注入/限速/清缓存/网络切换，每次保存0/1/3/10/30秒图片/XML/偏好。缓存与播放点未控制，无旧新版本配对，无法作为版本提速对照。计时起点为原生点击请求发出，下表是日志边界，单位秒。

| 操作 | 首分片请求 | 首分片200响应头 | 候选解码帧记录 | 新流提交 |
| --- | --- | --- | --- | --- |
| subtitle-r1-out | 1.234 | 6.224 | 8.130 | 10.166 |
| subtitle-r1-back | 1.445 | 6.732 | 7.081 | 9.421 |
| subtitle-r2-out | 1.118 | 6.268 | 6.487 | 9.008 |
| subtitle-r2-back | 1.221 | 6.259 | 6.892 | 10.495 |
| subtitle-r3-out | 1.230 | 6.308 | 6.881 | 10.228 |
| subtitle-r3-back | 1.507 | 6.419 | 7.354 | 10.594 |

点击至提交9.008～10.594秒。首个视频分片约+1.1～1.5秒请求，+6.2～6.7秒才见200响应头；后续还有收片、解码与对齐等待。首轮可见首分片客户端提前结束并取消、随后另一个请求继续，全部保留，不能只取成功请求或把多次请求串作同一任务。

选定实际原图已看：等待时旧画面/转圈，t30有后续电影画面。r1-back-t10原图没有可见字幕cue，接触图中曾疑似重复，放大核对未确认重复层；不据此判SUB失败或通过。其他自然字幕帧不能替代独立cue时表。日志`decoded`/`committed`不是屏幕首帧或出声时间，离散截图不证明连续流畅。

缺同期服务器转码/排队/首分片日志，尚不能拆清服务端生成与传输各耗多少。未据此降低缓冲、放松对齐或追加按片名参数。

## S03：原画文本字幕路径对照

Pad Jellyfin S03从头正常播放，普通菜单记录原PGS选择后切ASS；首次ASS已加载约11.424秒才开始一轮ASS out/back。两次操作期间都有KSPlayer遥测，没有换流/共享seek事件。out+2.175秒记录1288 cues加载完成，t3有实际文字；back后的自然t30帧也见文字。缓存返回路径无loaded日志，源码有按URL cue cache；back走缓存属于推断，不冒充直接缓存测量。

这只说明本轮原画文本切换没有复现S19约10秒的兼容流等待；不是跨设备/同片/同点/同缓存性能排名，2.175秒也不是精确字幕首显。t30无cue的自然间隙不直接判字幕消失。完整字幕、音画同步与实际听音仍未验收。原PGS已普通菜单恢复，实际暂停字幕图与退出图保留。

## USB数字回采能力探测：停止，无听音结论

Mac CoreMediaIO临时允许本进程发现iOS muxed输入，名称唯一对应两台配对设备，采集UID独立于物理UDID；实际采集身份挑战未完成。输入端口虽列vide/soun，不能证明取得屏幕或播放音频。仅使用muxed iOS设备，没有创建环境麦克风输入。

两个受控首页启动均0视频buffer/0音频buffer，WDA读守卫分别reset/refused后finally停止；中间一次旧session404发生在采集进程启动前，单列TOOL。第二次实际失败后停止该路线，不继续碰运气。采集会话结束、原CoreMediaIO开关恢复，两端WDA ready，未重装Runner，无新增Nastart崩溃。这些是能力/工具失败，不是App无声证据，也不能冒充扬声器听音验收。

依据Apple官方[CoreMediaIO屏幕设备开关](https://developer.apple.com/documentation/coremediaio/kcmiohardwarepropertyallowscreencapturedevices)与[AVFoundation采集配置](https://developer.apple.com/documentation/avfoundation/capture-setup)。仅列出媒体端口或running=true不代表收到sample，必须以实际buffer/画面验证。

旧phase分析器只取启动30秒end且末尾-jf误分类入口，原输出保留，不用于切字幕结论；本轮新报告独立合并全部偏好快照，按事件ID去重，明确Jellyfin入口，避免把磁盘写入延迟当作事件缺失。18工具的两次解释器路径/依赖错误未触设备，后来用已安装系统Python完成现场查询，失败留本机记录。

## 收尾与后续

- iphone13 2026-10-15T17:08:07.457890+08:00：普通空env/args正常首页实际图已看、播放器关闭；24项非书签偏好保持，35原书签0删除/五轨道字段0变化，1项自然位置变化、0新增；Nastart/WDA/Jetsam0新增，native active conditions0、WDA idle10/cool2。
- ipad 2026-10-15T17:08:08.358028+08:00：普通空env/args正常首页实际图已看、播放器关闭；17项非书签偏好保持，28原书签0删除/五轨道字段0变化，1项自然位置变化、0新增；Nastart/WDA/Jetsam0新增，native active conditions0、WDA idle10/cool2。

两个播放窗非蜂窝URLSession metrics173、蜂窝0（含切换、准备及原始失败；事件数不是字节/月额度）。最终源码、签名包与开工一致，保留所有既有未提交修改。

下一步优先同时间轴服务端首分片日志与请求取消/重发关联，检查兼容流字幕是否能避免不必要的视频重建；必须保持字幕正确性、时钟对齐和失败回退，再做同设备同源同点回归。实际听音需可信输出通道。18恢复实时连接后先核身份再覆盖最新包并普通启动。PX-20继续进行中；MI2、PGS独立时表、Pad大seek、预热alignment、HLS/NAS、S03冷续播、全SUB/AUD/HDR/PiP、竞品完整帧、网络/弱RF/MTP/19×4及全部原PX/UX/CB/Main/L2/L3未完成项保留。

[结构化记录](../../../testing/results/2026-10/PLAYING-SUBTITLE-ROUTES-20261015.json)。
