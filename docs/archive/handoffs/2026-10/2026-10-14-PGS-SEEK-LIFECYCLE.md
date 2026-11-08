# 2026-10-14 PGS暂停seek显示生命周期取证

## 本轮结论与变更卡

- 关联PX-02/PX-20，接续PROGRESS/CURRENT，已读播放runbook和分层流程。上轮13两个相隔15秒目标同一句PGS，本轮未稳定复现；问题保持开放。PGS无限结束时间及SubtitleModel fallback仍为代码假设，缺独立cue时表和确定性生产反例，未做假设性清理或媒体参数修改。
- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；iOS dirty `ce538bed01f20d4e123d4a45fc9238edd6988afedc9902feeece1aea31c65d61`。普通Debug `2026-10-14T18:19:28.479335+08:00`，173输入逐字节保持、其他未提交修改保留。本轮没有App源码修改、重新构建或XCTest；383测试/2跳过/0失败及15预检是同源之前的实际结果，不能冒称本轮执行。
- 开工及各设备门槛重核名称/型号/系统/UDID/USB，完整身份仅在私有目录。13为iPhone14,5/16.3.1，Pad为iPad12,1/18.3.1。签名/包核对后19:16:01和19:16:10分别保留数据覆盖，安装25/18非诊断项逐值保持，实际空env/args首页已看。
- 全部普通包、空env/args、WiFi，未改偏好/网络/媒体参数，未注入性能条件。iPad早暂停窗是普通UI操作形成的定向条件，不能充当默认连续播放基线。10GB月总量不是测试预算。

## 包身份

- `Nastart`: `c377c2bf2dee1eaa40b53e324e94410e2c496f3a21b3599b1ea0bd2088c7b413`
- `Nastart.debug.dylib`: `e1741042286d559de72035399ebc11f995261f7ccb449e7ef41f350eb9d15a7c`
- `Frameworks/KSPlayer.framework/KSPlayer`: `914b39e4d9e33542081fd61d7dc4a291114472f8cf9f0832222e709f965b7bee`

包路径为私有证据中current-package.json所指18:19正常包；IPA SHA `2b1c28f9b282e15150afb2a679ec012c37fde330fb6ee5f1278ecb22d01f0f1b`。29库逐项签名/deep/profile/linkage沿用同一已冻结包并在安装门槛核对，收尾再验三SHA/deep/173输入/源差异。签名配置和完整设备清单仅保存在本机。

## 实际窗口

| 设备 / 私有窗口标识 | 观测引擎 | 暂停±15次数 | 引擎完成秒 | 目标预览输出秒 | WiFi / 蜂窝metrics |
| --- | --- | ---: | ---: | ---: | ---: |
| iphone13 / wifi-mi2-jf-pgs-baseline | KSPlayer | 7 | 0.038～0.101 | 0.334～0.710 | 59 / 0 |
| ipad / wifi-mi2-jf-pgs-baseline | AVPlayer / KSPlayer | 4 | 0.110～2.063 | — | 56 / 0 |
| ipad / wifi-mi2-file-pgs-native | AVPlayer / KSPlayer | 0 | — | — | 48 / 0 |
| ipad / wifi-mi2-file-pgs-early-pause | AVPlayer / KSPlayer | 4 | 0.162～0.774 | 0.600～2.183 | 63 / 0 |

表中为内部seek_started→engine_completed/seek_preview_ready，后者是输出API边界，不是屏幕精确完成。每次七张稀疏截图含实际请求/响应时刻，名义t1/t2在Pad AV取图时可延后；不能只按文件名秒数比较。15次全部捕获实际暂停Play按钮。无FPS、连续流畅或速度改善结论。

### iPhone13 / JF原生KS

原PGS定位后首个+15实际从一条字幕更新为目标处另一条双语字幕；恢复播放有空白清除及后续新句。另选ASS并恢复原PGS，再两组回退/前进；总7次暂停探针。已看启动3/10/30、各目标12秒、自然播放、控制显隐/旋转及普通退出。空字幕目标缺独立cue表，不能据此判断漏字/清除正确，历史残留不关闭。

ASS为内嵌本地选轨，活跃缓存Subtitles目录仍0个SRT；未取得原始字幕时间表。空缓存不是字幕缺失证明，也不据此反推PGS预期内容。

### iPad / JF及默认文件入口

JF在触摸后25.490秒开始候选，49.402秒提交，候选内部对齐23.813秒；本窗4次暂停探针实际AV/烧入PGS。默认文件入口也先自动提交AV，再做暂停ASS→PGS→原ASS，不能把目录名中的native当实际原生验证。以用户操作起点计，PGS切换6.723秒、ASS恢复5.404秒为内部commit边界，实际cue完整性/精确可见结束未验。

### iPad / 文件早暂停

开始播放后2.802秒提交普通Pause，内部4.082秒已暂停在1.424秒，未用测试环境或改设置；选择第二个同名简英双字，内部requestedTrackID7/native selection。大幅暂停定位、四次±15期间均KS。目标图未取得可独立核对的原生PGS有效cue；不能将“没有残留”判通过。恢复自然播放后自动换AV（本次候选内部对齐10.846秒），后续暂停图出现烧入字幕，因此该字幕不能算原生PGS恢复成功。

第一次大幅暂停定位t3对照图黑屏转圈、t10已目标图；这是稀疏对照，且部分原图被后一次定位覆盖，见下节，不作精确延时或完整原图验收。第二次实际落到1:20:44，不能把请求ratio当成预期1:19:10；原生滑块映射/目标坐标需单独复核，未宣称已精确重放上轮目标。

自动换流后菜单标签由同名行变为带codec名称，初次按旧标签恢复失败且未发选轨；查看实际菜单后选原简体ASS，内部5.609秒commit，单层文字/普通退出已看。最终所有原书签五轨道字段完全保持，见收尾，不以菜单文字作为唯一恢复证明。

## 计时与工具修正

- 本窗seek_recovered出现101.009/45.646秒，包含暂停后等待用户再次播放；不得作为慢seek样本或纳入延时分位数。保留原事件，另报引擎完成及暂停预览输出；真实超时/失败仍保留，不能借此丢弃。
- 保留首次菜单未打开、隐藏Pause误判、文件generic标签/codec后缀不匹配、前步未发动作却执行settle、换流后旧标签恢复失败及2次提前生成contact失败。均单列TOOL，不冒充App播放失败/正常完成。
- **证据缺口**：同一目录第二次position采集复用midpoint/final文件名，第一次部分PNG/XML/plist被覆盖。已看contact及剩余final原PNG保留，原失败对照不能称有完整原始帧。私有工具已在任何设备动作/文件写入前拒绝已有目标文件；受控复用测试返回预期拒绝，已有窗口所有文件哈希逐字节不变。这个工具校验不属于App XCTest。
- 同路径自动切流及时间不同，四窗不能用于同条件性能比较。无Lenna/其他竞品完整帧证据，不判流畅PASS。

## 收尾与下一步

- iphone13：24项非书签偏好、34个原书签的五轨道字段完全保持；1项自然位置变化，原书签删除0；真实集合新增Nastart/WDA/Jetsam均0。实际正常首页/播放器关闭/空env/args，WDA idle10动画2，原生条件active0。
- ipad：17项非书签偏好、27个原书签的五轨道字段完全保持；2项自然位置变化，原书签删除0；真实集合新增Nastart/WDA/Jetsam均0。实际正常首页/播放器关闭/空env/args，WDA idle10动画2，原生条件active0。

- 四窗WiFi metrics共226，蜂窝0；不代表运营商实际计量。无本轮源修改，未触发修复后的S01四单元或扩大L2/L3，旧基线归原包。
- 下一步先取得PGS显示集起止/选择/seek代际与独立预期cue（仅本机私有留内容），固定能被旧生产逻辑触发的反例，再决定最小生命周期修改；同时复核原生滑块实际目标映射、Pad暂停目标等帧。AV首分片准备/排队与NAS同期日志仍缺，未重复上一轮已失效的Safari取日志路径，也未据此改超时/缓冲。
- 历史自动预热alignment失败、10.544秒切流/HLS23.943秒、S03双入口seek/冷续播、S19/119/PadTS02/13Network/增长TS/全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX05/06/其余UX/CB/Main仍开放；18未装ce53，不以旧包验证当前源码。

结构化结果：[本轮报告](../../../testing/results/2026-10/PGS-SEEK-LIFECYCLE-20261014.json)。私有根目录：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-14-pgs-seek-lifecycle-191546`。原始偏好、设备完整身份、字幕内容和截图仅本机，未复制入仓库。
