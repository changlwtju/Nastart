# 2026-10-14 seek 等待状态与字幕显示

## 变更卡

- 接续 PX-02/PX-20，先核对 PROGRESS、当前交接和调试规范。保留其他未提交修改；本轮两台 USB 设备，全部 WiFi，默认空 env/args，未注入网络/性能条件。
- 基线 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，dirty `f03a7f2f3fddd6a5c3eba1d2ecfc2e10e762c626835539ea80864b1a7ad558e6`，普通 Debug 17:32:33。本轮现场核对 iPhone13/iPhone14,5/16.3.1、iPad9/iPad12,1/18.3.1、名称/UDID/USB，保存诊断和偏好后保留数据覆盖已验证签名的基线包，实际正常首页已看。完整身份、包路径和三二进制哈希留本机私有记录。
- 上轮“iPad t3 旧画面/t10 更新”重新分阶段：触摸请求起点后 1.916 秒内部提交 seek，8.357 秒引擎完成（实际 seek 约 6.441 秒）；8.398 秒取得目标附近 AV 输出。t3 发生在 seek 尚未完成期间，不能单独称为 compositor 迟到。
- 同窗目标分片 1178 请求在 seek 后立即发出，约 2.3 秒后收到响应头，首段约 3.27 秒交付完成；随后连续取 1179～1182，seek 完成位于第 1182 段交付期间。输出采样不是屏幕呈现证据，不能以其声明精确可见完成或性能提升。
- 上轮换流 10.544 秒中，服务端协商约 2.05 秒；候选约 0.07 秒完成 seek，但等待解码输出约 6.75 秒，之后等待既有连续缓冲/对齐门槛。不能把全部时间归因于主线程或任意缩小缓冲/超时。
- 发现的展示缺口：请求 seek 时控制时间立即变为目标，文字 overlay 跟着该时间显示目标 cue；暂停 seek 尚未完成时 `isTransportBuffering` 可为 false，现有 loading 判定不覆盖这个等待状态。旧画面可能搭配新字幕，且无对应等待反馈。
- 最小修正方向：向共用 UI 发布 pending seek 边界，在明确待完成的 seek 中显示等待反馈并暂不显示共享文字层；实际完成后恢复。失败回到引擎实际时间，完成/失败/换会话均释放状态。保留请求目标、暂停意图、Range、HLS/缓冲预算、解码和书签身份算法。
- 验证：控制层的暂停 seek、发布通知、失败及换会话反例；完整现有 XCTest/预检/构建；两机普通包安装门槛；原 iPad 字幕/seek 场景与 iPhone 本地路径、S01 双入口基础及 S03。网络等待速度和完整 L2/L3、字幕/声音/HDR/PiP/竞品性能另列，不能仅凭显示反馈关闭。


## 最终实现与验证

- 共用 UI 发布 `hasPendingSeek`，待完成时显示 loading 并隐藏共享文字字幕；暂停 KSME 视频还须等待目标附近 forced preview 被输出 API 接受，不能在 demux seek 回调或普通 renderer 尝试回调时提前释放。AV/音频路径不等待不存在的 KSME preview；失败恢复实际引擎时间，恢复播放/失败/换会话/断开均清理等待。
- 修改5个 iOS 输入，其他168个保持。本轮不改媒体预算、Range、HLS、解码参数、NAS、网络、轨道或书签身份。旧代码受控负例2测试5失败/0unexpected，最终383测试/2跳过/0失败；15预检、正常Debug构建、173输入/三SHA/29库独立及deep签名/profile/linkage/IPA完整性全部核对。中间两版验证保留，不能当最终真机验收。
- 最终 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，dirty `ce538bed01f20d4e123d4a45fc9238edd6988afedc9902feeece1aea31c65d61`，普通 Debug `-Onone`，构建 `2026-10-14T18:19:28.479335+08:00`。包 `Nastart-Pending-Seek-Preview-Normal-Debug.app`，IPA SHA-256 `2b1c28f9b282e15150afb2a679ec012c37fde330fb6ee5f1278ecb22d01f0f1b`。
  - `Nastart` SHA-256 `c377c2bf2dee1eaa40b53e324e94410e2c496f3a21b3599b1ea0bd2088c7b413`。
  - `Nastart.debug.dylib` SHA-256 `e1741042286d559de72035399ebc11f995261f7ccb449e7ef41f350eb9d15a7c`。
  - `Frameworks/KSPlayer.framework/KSPlayer` SHA-256 `914b39e4d9e33542081fd61d7dc4a291114472f8cf9f0832222e709f965b7bee`。

## 本轮真机结果

- iphone13：iPhone14,5/16.3.1/USB，安装 `2026-10-14T18:20:22.241235+08:00`；保留数据覆盖，25项安装偏好逐值保持、实际空env/args正常首页已核。最终24项非书签偏好及全部34项原书签轨道字段保持，4项自然书签变化；真实Nastart/WDA/Jetsam新增 `{'Nastart': 0, 'WebDriverAgent': 0, 'JetsamEvent': 0}`。
- ipad：iPad12,1/18.3.1/USB，安装 `2026-10-14T18:20:04.113167+08:00`；保留数据覆盖，18项安装偏好逐值保持、实际空env/args正常首页已核。最终17项非书签偏好及全部27项原书签轨道字段保持，4项自然书签变化；真实Nastart/WDA/Jetsam新增 `{'Nastart': 0, 'WebDriverAgent': 0, 'JetsamEvent': 0}`。
- `iphone13/wifi-mi2-jf-candidate`：MI2 ASS暂停±15目标画面与单层字幕、等待隐藏文字、显隐/旋转及普通退出已看；未测连续帧/精确可见完成。URL metrics非蜂窝49，蜂窝0；普通退出已核。
- `iphone13/wifi-subtitle-clearance-s01-file-head`：S01文件影片/暂停±15和普通退出已看；前进t0转圈，后退t0旧图且未见转圈（截图请求跨preview信号）、t1目标图；未测逐帧呈现。URL metrics非蜂窝7，蜂窝0；普通退出已核。
- `iphone13/wifi-subtitle-clearance-s01-jf-head`：S01 Jellyfin片头/影片与普通退出已看；未做此入口seek/连续帧性能验收。URL metrics非蜂窝3，蜂窝0；普通退出已核。
- `iphone13/wifi-subtitle-clearance-s03-jf-head`：S03 Jellyfin片头推进及普通退出已看；未做此入口seek/冷续播或连续帧性能验收。URL metrics非蜂窝6，蜂窝0；普通退出已核。
- `ipad/wifi-mi2-jf-candidate`：MI2 ASS暂停±15目标画面与单层字幕、等待隐藏文字、显隐/旋转及普通退出已看；未测连续帧/精确可见完成。URL metrics非蜂窝35，蜂窝0；普通退出已核。
- `ipad/wifi-subtitle-clearance-s01-file-head`：S01文件片头/影片、暂停±15等待转圈及目标画面更新、保持暂停和普通退出已看；无完整字幕/性能验收。URL metrics非蜂窝8，蜂窝0；普通退出已核。
- `ipad/wifi-subtitle-clearance-s01-jf-head`：S01 Jellyfin片头/影片与普通退出已看；未做此入口seek/连续帧性能验收。URL metrics非蜂窝3，蜂窝0；普通退出已核。
- `ipad/wifi-subtitle-clearance-s03-jf-head`：S03 Jellyfin片头推进及普通退出已看；未做此入口seek/冷续播或连续帧性能验收。URL metrics非蜂窝7，蜂窝0；普通退出已核。
- 13 S01文件后退t0仍旧图且未见转圈，t1目标图；t0截图请求0.398～0.707秒跨过preview输出0.509秒，无法断言输出后呈现迟到，更不能证明所有可见帧都有等待覆盖。保留此窗口，逐帧呈现仍待取证，不加任意延迟掩盖边界。
- 两机 MI2 从原 PGS 切 ASS（Pad原生KS本地，13兼容AV换流），实际固定暂停字幕显隐与横竖屏已看；恢复原 PGS 轨道后退出。恢复 PGS 的暂停窗口可能落在无 cue/待图片解码时，不能称其字幕内容已验收。
- iPad MI2 暂停前进：内部 seek完成约0.220秒，目标输出确认约1.180秒；后退约0.829/2.017秒。截图捕获旧图转圈且共享ASS隐藏，后续目标图及单层ASS恢复，保持暂停。数字是内部信号差值，不是精确可见完成时间或速度对比。
- 另6个S01双入口/S03 JF启动与普通退出窗口，S01文件入口各补暂停±15秒；实际选定图逐窗核对，完整采样请求起止保留。全部WiFi，无注入条件；最终两机实际正常首页/播放器关闭、空env/args、WDA idle10/动画2、原生active条件0。

## 证据与未完成项

- 安全汇总：[`PENDING-SEEK-PRESENTATION-20261014.json`](../../../testing/results/2026-10/PENDING-SEEK-PRESENTATION-20261014.json)。完整原始偏好、设备身份/连接、各动作、PNG/XML、诊断、失败、源码隔离和包在本机私有目录 `2026-10-14-seek-output-stages-180034`；不将原始设备偏好/凭据写入仓库。
- 本轮缩小的是等待反馈与共享字幕显示缺口，未证明网络/seek速度改善。Pad自动兼容候选在手动大seek时以candidateInvalidated结束（阶段alignment），保留完整事件；历史自动候选alignment失败继续开放；本轮iPad原生KS、iPhone13兼容AV与旧AV慢窗的源/缓存条件不同，不能作性能排名。旧AV目标分片响应/交付及约6.44秒seek、10.544秒换流均未关闭。
- 旧基线、AFC读取失败/重试、空cue尝试、误用native replacement等待、受控负例及中间验证均保留，不丢弃失败/超时。等待失败/再次操作/迟到预览/会话切换的边界有定向测试，未执行真机故障注入。
- 下一步先以最新正常包复验旧iPad AV慢路径并同步服务端准备/分片交付/输出，继续定位自动兼容候选预热alignment失败。S03双入口seek/冷续播/HLS23.943秒、S19/119/PadTS02/13Network/增长TS、全SUB/AUD/HDR/PiP/竞品完整帧/弱RF/外部WiFi/MTP/19×4/L2/L3/PX/UX/CB/Main仍开放。iPhone18未装本轮ce53包，不可沿用旧包认定当前源码通过。
