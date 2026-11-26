# 2026-11-13 W10 预热播放器首次接入字幕修正

接续 [隔离验证](CODEX-2026-11-13-PLAYBACK-POLICY-T5-W10-SUBTITLE-SIM.md)。在 `GreenfieldKSPlayerRenderer.prepareReplacement` 创建候选层后初始化其字幕模型 URL，再调用 `prepareToPlay`。原先由首次挂载触发的异步字幕复位现在发生在预热期，后续同 URL 挂载沿用已有字幕模型。此次修正位于渲染器接入顺序，沿用原路线模型、换源协调和调参常数。HEAD `8db1cc64`，冻结的 500 个构建输入仅渲染器与定向测试两处与旧 T5 包不同。

## 定向测试

- 在同源独立副本、专用 iPhone 17 / iOS 27.0 模拟器和 `--offline-ui empty` 宿主中，新用例通过实际 `prepareReplacement` 预热本地合成视频，再挂载并选字幕。旧实现一例失败，挂载前模型 URL 未初始化，随后选轨被清空、禁用。修正后六例通过，含新增回归、同 URL PiP 回挂、预热失败与取消、Reader 代理原片解码、主动关闭字幕和先初始化再选轨的对照。已知基线 Range 用例不在此次定向范围。
- 首次真机构建借用私有 DerivedData 克隆，SwiftShims 缓存仍绑定旧路径，失败后改用干净 DerivedData 和本机锁定依赖，原证据未覆盖。

## 包与安装

- 07:05:28–07:06:39 构建签名 Debug，dylib `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`，主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`。包核 deep/strict、30 个嵌入库及 IPA CRC，覆盖 iPhone 13 和 iPhone 18 的描述文件有效至 11-15 08:30:17（北京时间）。 [iPhone 18 保留安装](CODEX-2026-11-13-IPHONE18-W10-SUBTITLE-INSTALL.md)
- iPhone 13（iPhone14,5 / iOS 16.3.1）fresh 核名称、完整 UDID 和有线连接。07:08:32 保留数据覆盖安装完成，fresh bundle 回执与 30 项偏好相等。原生空环境启动截图实见启动台和 Wi-Fi 图标，仍显示 NAS 恢复提示。结束空环境自有进程后另开受控播放。
- 07:09 首次受控窗从启动台导航时，恢复提示把 Jellyfin 卡片推到屏幕可点区域外。自动触摸实际进了「设备」页。未发播放，原生清理 App、Runner、转发及采集。重试增加启动等待及卡片与底栏的可见几何核对，完成 Jellyfin → S19 详情。

## iPhone 13 W10 实播

- 07:10:48–07:14:52，原 Wi-Fi，USB 控制，复用既有 Runner。S19 原片 `341BF366` 从 7522.054 秒续播，`audioStreamIndex=2 subtitleStreamIndex=9`，内部首帧 6,425 ms。仅在本进程沿用 W10 45 Mbps、延迟 5 秒、持续 70 秒的诊断限速。
- 07:12:47.322 `automatic_downshift_requested reason=deliveryBelowSourceBitrate deliveryCapacity=25761627`。候选 `AE278EE9` 20→12 Mbps 开始准备，07:12:49.734 实际触摸轨 3，App 随后记录原自动候选 `stage=manifestPreparation cancelled=true` 与 `automatic_downshift_abandoned`。07:12:52.274 产生手动候选 `5DD9E82F mode=jellyfinOriginalDirectPlay audioStreamIndex=3 subtitleStreamIndex=9`。
- 手动候选在预热约 23.4 秒后取得 `replacement_candidate_opened preview=7532.4`，随后 `candidate_seek_completed target=7537.673 completed=true`。未取得 `candidate_aligned` 或提交，实际出现「无法准备播放」，旧流仍有画面及简体中文字幕。手动切轨真机未通过，本窗无法验证修正后手动候选接管的字幕。
- 07:14:00.807 原流再次发起独立降档，`81AFA70C` 20→12 Mbps，仍带音轨 2 和 `subtitleStreamIndex=9 requestedServerSubtitleIndex=9`，07:14:30.872 提交。旧流交接保存及 HLS 关闭保存均为 `audioTrackID=2 subtitleTrackID=9 subtitlesDisabled=false`。HLS 内部首帧 30,045 ms。此次 HLS 的字幕保留证据来自请求和保存，接管后的实际字幕画面未单独核实。
- 试图打开音轨菜单以恢复原选项时控件未出现，未发改轨。日志显示 07:14:40 有普通关闭边界，后续意外又出现原片准备 `70AD1780` 及播放器，具体重新进入触发源未核。该流仍为轨 2 / 9。保存诊断后以原生进程控制收尾，App、Runner、8161 和采集归零，主屏幕 Wi-Fi 图标复核通过。期间未切网。
- 路线脚本 `5 playback(s) with route evidence, 0 to check.`。手动候选行实际原片与显式选轨保留原片规则相符，复算不代表实际提交。慢切轨与候选对齐失败交回，按总交接未改模型或参数。真实听音、手动候选成功接管后的字幕和普通退出稳定性仍待。两轮原始证据分别位于私有入口的 `phone/`、`phone-retry/`。

私有证据入口 `/tmp/nastart-codex-w10-subtitle-fix-20261113-current`。
