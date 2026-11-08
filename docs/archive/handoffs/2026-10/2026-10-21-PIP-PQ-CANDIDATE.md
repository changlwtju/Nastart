# 显式PQ字幕候选与目标设备参考白校准

2026-10-21，接[同帧上下文](2026-10-21-PIP-FRAME-CONTEXT.md)，对应PX-07；[脱敏结果](../../../testing/results/2026-10/2026-10-21-pip-context-candidate.json)。原始偏好/日志/包仅留本机私有指针`/tmp/nastart-pip-pq-candidate-evidence`及`/tmp/nastart-pip-pq-calibrated-evidence`，不新增WDA控制封装。

## 第一候选与失败

普通Debug包04:47:20，源码diff `689810a4b4427ee1da92621920c6c671edb37263fae5ffe89245c71621b8b3a1`。13项定向最终正常Xcode通过；首次测试参数顺序编译失败、预期字节把13250误写成13252的失败均原样保留，修正的是测试期望，不弱化GBR/大端序验证。173输入/29库签名/profile/三SHA/IPA CRC与链接已核，13保留数据覆盖、空环境首页正常，24偏好与36原轨道不变、无新增崩溃。

候选仅Debug显式环境NASTART_PIP_PQ_CANDIDATE=1，4K x420/PQ/2020、已检查侧数据与HDR10兼容基础层，正确静态24bytes，明确不复制旧RPU或CLL/FALL；普通/Release仍保护。第一真实窗04:49:36–04:52:02，13/JF S03一次Play/一次PiP及手动Home，两条imageCount1有mastering24/max1000却因hdrDeviceValidationFailed返回原帧。实际iOS白为99.912798nit、roundtrip delta0；模拟器约203，因此固定203校验失败，尚未执行四surface/共享别名资源自检。原生两张PiP电影图仍无字幕，不算成功。84条内存样本phys峰值1011.566MiB/RSS267.984MiB只属被拒绝候选/正常播放窗口，不能当实际合成峰值。

每轮独立90秒守卫，最外层停止自有App并核无进程、停止内存采样及取消守卫；再次空环境首页/NAS正常后停止，原生Settings原SSID/Wi-Fi实际看图，未改网络/VPN/蜂窝。24偏好/36原轨道保持，仅自然进度一项、无增删，App/WDA/Jetsam新增0。原失败保留，不能写成HDR字幕已修。

## 校准候选

改为按同进程实测原始白点计算203/measured增益，仅在线性BT.2020工作空间处理字幕RGB，alpha和电影输入不缩放；拒绝非有限或80–250nit之外的实测值，重测归一白190–216nit与roundtrip delta≤2后才进行固定池/别名检查。不同平台不盲乘固定2.03。依据[Apple工作色彩空间](https://developer.apple.com/documentation/coreimage/cicontextoption/workingcolorspace)及[颜色矩阵](https://developer.apple.com/documentation/coreimage/cicolormatrix)，最终仍以真实像素为证。14项定向正常Xcode通过，真机验证接续中；不代表普通启用、杜比动态输出或Release交付。

## 校准候选真实呈现

04:55:32普通Debug包，iOS diff `c4a73011f1125e0222b6230789b099cfea2ad6cc64f80603cd62d2ebea0148c4`，173输入/29签名库/三SHA/IPA CRC/profile均核。13保留数据覆盖并核实际空环境首页，Pad05:00也从16:16旧包保留数据覆盖、18项含书签非诊断偏好完整不变，随后复用既有签名Runner/USB转发确认实际空环境首页。正常与Release仍不启用HDR合成。

13 04:57:56–05:00:19的显式候选S03/JF原流窗，实际PiP3原生图有中英PGS字幕；两条composited=true/hdrPQOutputCreated，DV7/compat6、HDR10兼容基础层输出。nativeWhite99.9128→gain2.03177→203.703nit、roundtrip delta0；四surface、四持有及共享别名拒绝第五分配通过，未出现新第五surface。两次诊断采样渲染56.963/21.010ms，不是完整帧时间或性能P。78条内存phys峰1097.754MiB/RSS261.469MiB/最后999.395MiB，不是长时平台或完整资源上限。

Pad首次05:04:27–05:05:21零Play/PiP导航失败：搜索控件name为magnifyingglass而label为搜索Jellyfin；缺唯一匹配便停止，没有重发未知触摸。调整为现场已核name后05:07:16–05:09:51独立窗一次Play/一次PiP/手动Home，实际KS localRangeProxy原流（非AV烧录）；PiP3原生图同样有中英PGS字幕。两条hdrPQOutputCreated，nativeWhite203.703→gain0.996549→201.490nit，roundtrip0、四surface及别名检查通过。73.518/26.478ms只属诊断采样；没有另开RSD做内存，避免干扰自有XCTest。

两设备PiP10截图瞬间无字幕不证明丢cue；13最后noCue/image0已分列。都只验新候选PGS呈现，不替代18用户外置文字、完整暂停/恢复闭环、音画、长稳或DV动态输出；固定4K及已核兼容条件之外继续原帧保护。最外层已停App、取消守卫、空环境首页恢复、原SSID与Wi-Fi图标实际核实；13原生无进程，Pad先WDA state1、随后结束本批XCTest并原生核无App/Runner。24/17非断点偏好、36/29原轨道保持，各一自然进度、无增删，App/WDA/Jetsam新增0。Pad首次端口进程断言漏计iproxy但系统身份18.3.1一致，后续已核既有iproxy目标UID精确匹配；不新装/重建Runner。

18旧式HouseArrest在保存数据阶段ConnectionTerminated，明确零安装派发。独立现有userspace RSD只读成功保存实际数据并看见锁屏，随后以该原生通道保留数据安装同包；安装与正常首页最终结论以接续记录为准，不反复重装或把锁屏图当首页。

## 18最新包安装结论

05:12:33通过现有配对Wi-Fi的userspace RSD安装同一04:55包，installation_proxy Complete及安装后lookup均成功；备份前/后25项完整非诊断偏好键值一致，三二进制/IPA与manifest精确对应。原生通道绕过的是旧式容器握手失败，未新配对、改网络、卸载或重复安装。实际只读原生截图可见设备锁屏，空环境启动请求DTXNsError，正常首页尚未核实；已一次请用户解锁并保持亮屏，未重试PIN或声称18新包电影通过。后续只补空环境启动/实际首页，不能因启动失败重装已Complete的包。

## 暂停恢复门槛失败与正常收尾

05:16:32–05:19:00首次窗口在activeAppInfo非SpringBoard的前置检查停止；05:20:34–05:22:58复用项目已有显式系统session后确认SpringBoard，但原有PIP-SBInteractionPassThroughView查询200/matches0，未发送Pause/Restore。两次都有真实Play/PiP、实际小窗字幕仍可读，但零暂停/恢复不算闭环通过；停止同条件调参，不改全局WDA封装或盲点浮窗。第二次原App已原生停/无进程，随后空环境正常启动被旧系统session的前台判定阻断；已独立先停App、建立新App会话并核空环境首页/NAS正常、再次原生停/无App及原SSID/Wi-Fi看图。原失败/选择器限制与补救分别留存，没有把后一次正常首页补证当暂停成功。轨道/偏好不变，各仅自然进度，新增崩溃0。

接受范围随后调整为当前普通Debug的已测兼容4K PQ基础层字幕路线，Release和不满足准入的格式继续保护；不以此次控制定位失败说明HDR播放失败，也不升级成完整PiP/DV/外置字幕/帧时间验收。普通空环境的实际验证另批记录，候选显式条件证据不迁移。
