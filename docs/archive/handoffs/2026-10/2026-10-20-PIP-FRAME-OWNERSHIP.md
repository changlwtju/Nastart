# PiP 帧所有权与共享surface反例

日期：2026-10-20。承接[字形与寿命原型](2026-10-20-HDR-PIP-GLYPH-AND-LIFETIME.md)，关联PX-06/PX-07；原始日志/包/设备身份仅在本机私有区，当前指针`/tmp/nastart-pip-ownership-evidence`。

## 执行前变更卡

- App基线14:20普通Debug，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加原未提交修改，iOS差异`88efcc6f4c76662d29b16603b7665a0974cf1a952aa4796dbd181bfe306177f7`。
- 共享surface新反例：同IOSurface的新CVPixelBuffer没有私有token，原包装释放后预算0且新池获准，但旧surface仍24,891,904bytes；外部移除附件时原buffer仍持有而预算也归零。否定把旧token原型接成全局预算，不继续调quota。
- 所有权源码缺口：PiP变换只判断当前active，未核创建该回调的完整plan；回调在读播放器时钟、更新cue/缓存前缺所有权边界。其他解码回调已有plan检查；仅8位日志ID不适合充当完整身份。
- 最小修复：控制器保存当前完整plan UUID；PiP变换以同一工厂包装，在任何cue/合成副作用前核active/完整plan/控制器存活。开始KS/AV会话设置身份，disconnect清空；renderer退休清理用同完整身份。诊断仍仅原短ID，不输出完整UUID。HDR保护/缓冲/等待/字幕时钟与分片均不改。
- L0：实际包装回调的先后返回受控；未active、未知owner、同前缀新plan、KS转AV/新会话、断开、关闭再进、owner释放；现有PiP保活/停止/同URL重挂及暂停字幕反例。先验证旧规则反例，再普通签名构建一次。
- L1/L2：设备逐台现场重核并核最新安装身份；SDR正常PiP及原失败HDR保护分列，正常包空环境，两设备与双入口按实际可达范围。工具/连接受阻保留未验，不猜恢复按钮/不重复旧失败操作。
- 本批不启用HDR原型或预算token，不把这一归属修复当HDR/PiP字幕已交付。若触及广泛呈现行为再扩大验证，当前不触发L3。

## 实现与包

实际修改位于`GreenfieldKSPlayerRenderer.swift`的`renderingPlanID`、帧回调工厂、KS连接与退休清理，以及`GreenfieldVideoPlayerView.swift`的AV连接。工厂检查在变换之前；返回nil沿原有调用约定提交原帧，不接预算token、不改HDR保护。四个新增实际工厂测试覆盖未知/inactive、同短前缀不同完整UUID、断开/重进、owner释放、源buffer/PTS透传及nil结果；连同六项既有生命周期用例，9通过/1跳过/0失败。跳过为模拟器不支持系统PiP，不写10通过。15预检通过。

一次必要的普通Debug/-Onone/Xcode27构建于16:16:59.676117+08:00完成，HEAD加未提交修改，iOS差异`491ed044d0c13cbf31ee3f70125f599431fcb3e783a167097fa9f3d55e7a1184`。173输入、29库逐一/整体签名、链接、IPA CRC/三二进制哈希已核。主程序`df32a4befe3768aa1eac0d8175c028c00f5141eb3c93b392f88128ef4a10e1d8`，debug dylib`f43015ca6ce6c3e3f4b1180e1c6d16e107bab012b8d7442d5f01c574cd71bfb1`，KSPlayer`d2ccf7a95166b81d1491dea583eb4518ef23a00add3f91d8a3b9d0e9da2b7e37`；其余身份见[结构化结果](../../../testing/results/2026-10/PIP-FRAME-OWNERSHIP-20261020.json)。包/源码清单/真实身份留私有指针，不再构建重复包。

16:15起现场重核13 iPhone14,5/iOS16.3.1和Pad iPad12,1/iPadOS18.3.1的名称/UDID/USB，各自保留数据覆盖最新包并实际看空环境正常首页/Wi-Fi。18随用户离家不探测。每次换设备/新窗口另核173输入/签名/包/现场身份；版本号不作为安装证据。Pad复用有效已装Runner、native RSD限600秒，无Runner重建/安装；结束只停本批Pad Runner，保留13既有Runner。

## 实际回归及失败

本批只有Wi-Fi普通空环境，不新增蜂窝采集或性能对照。S01三窗各10秒，13文件入口未进入媒体；不是S01四单元通过。

| 设备/入口 | 本批实际结果 | 不能据此宣称 |
| --- | --- | --- |
| Pad S01/JF，KS | 真实出画、系统PiP有电影画面；唯一系统恢复按钮点击后回App播放器，普通完成退出。返回即时截图黑，未取延迟画面 | 完整画面连续性/听音/帧时间通过；黑图也不能独断为播放器黑屏故障 |
| Pad S01/文件，KS | 真实出画、实际系统PiP窗口/电影画面；直接谓词查询恢复控件返回stale element/404，最外层终止App | 无恢复闭环、无普通退出通过；不得丢掉失败 |
| 13 S01/JF | 真实电影画面；工具仅找`pip.enter`而当前中文控件为“画中画”，未发PiP动作，最外层停App | 不当产品PiP失败或正常退出通过 |
| 13 S01/文件 | 实际文件页显示DSM会话/权限错误；browserRoot `list_share` HTTP200/API119，未开始播放 | 不当网络未接Wi-Fi、不要求清登录；后续snapshot新会话成功与旧browser会话另列 |
| 13 S19/JF第一次35秒 | 原流实际字幕，仍被旧工具错误名称阻塞，未发PiP动作 | 不算HDR PiP验收 |
| 13 S19/JF修正工具后35秒 | 以当前唯一中文控件进入PiP，唯一容器揭示“恢复全屏幕”，系统按钮回App；延迟2秒及再5秒截图字幕实际变化。完成控件查询未等显现而未唯一命中，最外层终止App | 不算完整普通退出/音画/帧连续性通过；不再为工具重播 |

13修正工具后的真实回调为KS、3840×2160、10-bit420/PQ，37.022/42.057秒均imageCount1、`hdrPQPreserved`、未分配/未合成；小窗截图无PGS，恢复全屏后字幕可见。确认帧归属工厂允许当前plan进入既有变换，仍没有实现HDR字幕；PQ不等于DV/实际显示位深。手动Home均明确记录，自动Home未观察到，不验收点击PiP自动回桌面体验。

新增系统恢复路径使用当前唯一语义元素，不读完整SpringBoard树、不猜坐标。Pad成功、Pad另窗stale及13中文命名/退出等待失败全部保留。首次Mac反例编译失败（Create out-param需Unmanaged）已按Create所有权修正；私有日志保留，不算首轮成功。Pad旧tidevice停止因iOS18无legacy developer image失败，随后WDA精确bundle终止并state1确认；后续原生RSD确认无自有媒体/Runner。收尾中“App已停”导致WDA应用会话读状态失败，改独立原生进程核实，未重开媒体。

## 收尾与下一依赖

每窗最外层停自有App媒体并取消120秒独立守卫；未改Wi-Fi开关、蜂窝或VPN。13结束独立USB实见原SSID勾选/状态栏Wi-Fi，Pad普通首页及停止后原生桌面均实际可见Wi-Fi。先停媒体后离线分析，最终两App进程均已停；Pad自有Runner停止、13持久Runner保留，自有主机Python/保活进程匹配0。

13的24/Pad的17项非断点偏好逐项不变，原36/29书签轨道保持、无删除/新增书签，各仅2项自然播放进度变化；App/WDA/Jetsam新增各0。首页NAS卡未连接不当全环境健康。安装时13的25/Pad的18项含断点结构，不混写成最终非断点计数。

先离线核browserRoot API119的会话代次与新snapshot成功的发布边界，以及已有PiP恢复/退出图像时序；不先要求用户重登或反复重播。HDR资源方案须能覆盖共享IOSurface/移附件，不再调旧token quota；保护保持。更完整SDR/多入口往返、音画/深seek与真实弱蜂窝仍开放；本批不关闭任何需求。


## 收尾后直接接续的会话离线复核

复用已有两设备私有快照并按事件ID去重，没有新启动/媒体/网络/构建。8个API119来自同一DSM认证代次和同一FileStation代次、三个client实例，其中snapshot2/browserRoot6；不是三个不同认证代次。首次119之前2.813秒已附上文件会话、0.420秒前已同时sourcePrepared/connectionPublished；snapshot先报119，41ms后browser也失败，2.588秒后同一pair再次发布，后续仍119。在首失败前8秒至后13秒的13日志内没有logout事件；不排除未观测的外部/服务端会话变化。

后续重新启动的两组新认证/文件会话在snapshot成功。因此否定“仅browser未收到最新FileStation会话”的初始假设，也不能据此归为密码失效、一般NAS不通或本机主动logout。`prepareFolderCache/publishFolderSession`已有同MainActor发布和身份保护；本批不加盲重登/清凭据/弱化119错误传播，不再构建。下一依赖是现有登录/附加至首次FileStation请求之间的会话有效性及失效来源，需有可区分反例才新增诊断或改动。完整安全序列已并入结构化结果，凭据/SID/真实设备标识未导出。

后续同包补证及单调时钟口径修正见[会话有效性与PiP普通退出闭环](2026-10-20-SESSION-VALIDITY-AND-PIP-ROUNDTRIP.md)：旧2.813/0.420秒为异步Date观察，单调观察为2834/457ms；13文件/Pad JF两个指定闭环已补齐，旧失败仍保留。
