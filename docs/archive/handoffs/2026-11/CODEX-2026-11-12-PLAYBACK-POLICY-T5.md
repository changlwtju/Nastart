# 2026-11-12 播放策略 T5 换源接线

接续 [T4 与 T5 预检](CODEX-2026-11-12-PLAYBACK-POLICY-T4-T5-PREFLIGHT.md)。用户确认下一集待处理或加载时忽略旧一集的选轨和跳转。播放器的正常返回仍可关闭；换集失败结束后旧一集可继续操作。

## 实现与构建

- Greenfield 播放器用 `PlaybackSourceChangeCoordinator` 驱动现有加载器和候选提交。轨道与服务端跳转合并时保留目标秒数、选轨、倍速和方向；先服务端跳转再选轨时串行提交。本地跳转使轨道候选从新位置重试，仍用 `source_track_retry_after_seek`。PiP 提交条件和自动降档额外检查仍适用。共享播放器在换集时拦截本地选轨、进度条和手势跳转。路由、Reader 和调参逻辑未改。
- HEAD `8db1cc64`，开工 140 个变更路径；保留开工工作区和索引差异。T5 修改四个 iOS 文件。签名 Debug 14:23:36–14:24:48，Xcode 27.2 (27B52)，500 个 `ios/` 文件快照（多含 `ios/README.md`），SHA-256 `6a742f231c662d62d4926a93c71c2a59af7bf67fc7dd241a95b6d3045e50ff7a`，构建后逐项一致。`Nastart.app` 为 `com.changliwen.nastart`、arm64、0.1.0/1。主程序 `a46a22ee13e75d357a82592c0ad933784ac3e36cc527a8e32a1ebd5a1df5d1f6`，dylib `6beee7cbe77e5b842112351366bdcf80de007527e6004e0ae32107b31a2c533e`。31 个嵌入 Mach-O 逐个验签，描述文件到 11-15 08:30:17 北京时间。
- iPhone 17 Pro / iOS 27.0 模拟器的 `PlaybackNextCoreTests`、`NonPlaybackPolicyTests` 共 697 项，694 通过、2 跳过、1 失败。失败为已有 `testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse`。换集互斥、失败后解除限制、跳转与选轨排序、PiP、原流显式暂停和带目标位置的音字幕状态检查均通过。移除了仅覆盖已删除 tracker 的四项旧测试。`python3 scripts/preflight.py` 改动前后输出逐行相同，保留已有失败项。

## iPhone 13 原 Wi-Fi 窗口

- iPhone14,5 / iOS 16.3.1 / USB，fresh 核对设备和原 Wi-Fi 勾选及图标。14:26:14 保留数据覆盖安装，安装回执及 fresh bundle 路径、安装前后偏好一致。空参数、空环境实见 Nastart 首页。现有 WDA Runner 在 8161 就绪，无重签或安装。14:29:55 自有 App、Runner、采集和转发归零，未切换网络，详情页图仍有 Wi-Fi 图标。
- Jellyfin 资源库 `library_failed httpStatus=401`、`session_rejected stage=library`，实见重新登录提示。未输入凭据。设备文件的 S19 仍可续播，trace `F33BB978` 实际 `localRangeProxy` / KSPlayer，实见片头和字幕，正常退出到详情，未得到 HLS 候选。路线脚本 `0 playback(s) with route evidence, 0 to check.`，无 Jellyfin 选路样本可复算。iPhone 13 本窗 W1–W10 均未触发。

## iPad 原 Wi-Fi 窗口

- A16 iPad / iPad15,7 / iPadOS 26.6 / USB。fresh CoreDevice 确认有线、配对，原生 RSD/DVT 确认设备、无活动 Runner 和主屏。CoreDevice 查询已装 App 时返回 `0xE8000003`，该次未发安装。沿 USB 原生 RSD 的安装代理于 14:32:35 保留数据覆盖安装，查询核对新 bundle 路径，安装前后偏好一致。现有 Runner 8153 可用，未重签或部署，空启动环境下实见 Nastart 首页。
- S19 正常续播 `088C7A3A`，`verifiedSameServerLAN selectedAddressKind=localDomain originalVerdict=noEvidence`，先走 KSPlayer 原片，内部首帧 3,940 ms。14:37:15 自然触发 `sustainedRebuffering`，候选 `AEE2BB89` `mode=serverNegotiatedHLS transport=localHLSProxy`，20→12 Mbps，14:37:44 实际 `replacement_committed startsPaused=false`。该候选没有与选轨重叠。普通退出回电影详情，仍显示 AC3 2 / PGS 9。路线脚本 `2 playback(s) with route evidence, 0 to check.`。
- 为能在已确认的 HLS 上直接输入，另用同包启动参数 `NASTART_TEST_STARTUP_HLS_BPS=12000000`，仅此 App 进程生效。`75A706CE` 内网 `privateIP`、`serverNegotiatedHLS`、AC3 2 / PGS 9，内部首帧 5,834 ms，实图可辨电影。该组用于换源功能，不用于正常选路或蜂窝体验验收。

| 场景 | 结果与依据 |
| --- | --- |
| W1 单次切轨 | 已提交和出内部首帧。`211E6931 requestReason=sourceTrackSwitch audioStreamIndex=3 subtitleStreamIndex=9`。旧流 `D840A47D` 在 9528.029 秒提交一次，`candidateSeconds=9528.375 startsPaused=false`。没有独立听音记录。 |
| W3 选回原轨 | 本次未形成重叠。首选轨 3 已在 14:42:10 提交；返回轨 2 的 WDA 操作未找到轨道菜单行，未发第二次选轨。保留失败 XML/PNG。 |
| W4 选轨再服务端跳转 | 在 `BC1EA2D8` 准备中拖动约 6,085 秒，实际为引擎跳转。`seek_started` 后重试候选 `D840A47D startTimeTicks=94593259583 audioStreamIndex=2` 提交，未出现 `requestReason=serverSeek`，W4 保持未覆盖。 |
| W6 重复点下一集 | 正常空环境，《冰与火之歌》S1E1「凛冬将至」原片 `928E6831`，双击间隔 200 ms。第二集只产生一次 `playback_preparing requestReason=initialPlayback`，`CEE272CF` 一次提交，`startsPaused=false`，画面和标题均切到「国王大道」。旧一集控件被忽略有模拟器证据，真机此次未成功在短暂加载期注入旧一集选轨或跳转。 |
| W8 选轨再本地跳转 | `B4993962 sourceTrackSwitch` 准备时后退 15 秒，旧 `75A706CE` 的 `replacement_warmup_failed reason=candidateInvalidated` 后紧接 `source_track_retry_after_seek`。`8305D512 startTimeTicks=33195165362 audioStreamIndex=3 subtitleStreamIndex=9` 与引擎 `targetSeconds=3319.5165 completed=true` 对齐，随后一次 `replacement_committed startsPaused=false`。复位前后都有实际电影画面。 |

- 受控 HLS 窗复算 `8 playback(s) with route evidence, 0 to check.`。其中 `B4993962` 和 `8305D512` 两行均为 12 Mbps、`ok`。`BC1EA2D8` 和 `D840A47D` 的 `explore` 字段来自有明确目标档的内网替换，实际仍走 HLS，不计入 T4 的 4G 自然原片试探。
- `FB5C6DB2` 恢复 AC3 2 / PGS 9 并提交。首次恢复原播放位置的拖动实际只移动约 301 秒，未回到约 3309 秒，保留原日志。14:43:39 普通退出，14:43:51 核 App、Runner 和 8153 均已停止。续接用同包空启动环境，补换集与位置恢复。
- W6 独立窗口 14:44–14:50。电视剧入口第一次触控因按钮被屏幕边缘截断而未发送，滚动后进入。换集复算 `2 playback(s) with route evidence, 0 to check.`。随后只为恢复 S19 书签，以已有 Debug 固定落点覆盖 `3205.0010443` 秒，匹配字节数 `128795641934`。`5CC3E642` 在原内网从该位置出画，进度到约 3208 秒，普通退出。最终恢复空启动环境，实见首页及 Wi-Fi，14:50:53 App、Runner、8153 均归零。

## iPhone 13 用户重登后的原 Wi-Fi 补测

- 18:22 用户在 App 内重新登录，`login_succeeded`、资源库实际加载，重开进程后仍可搜索并进入 S19。fresh USB 核设备、工作区及 T5 包和安装回执，复用现有 Runner。iPad 当时不在 USB、CoreDevice 不可用，既有原生 RSD 超时，未启动 iPad App 或 Runner。
- 18:25 使用同一签名包和 `NASTART_TEST_STARTUP_HLS_BPS=12000000` 单进程启动，`D224B94B verifiedSameServerLAN selectedAddressKind=privateIP`，`serverNegotiatedHLS`，AC3 2 / PGS 9，内部首帧 8,226 ms，有实图。逐动作保存原始诊断；部分即时偏好快照延迟落盘，以后续快照补齐。合并复算 `6 playback(s) with route evidence, 0 to check.`。

| 场景 | 结果与依据 |
| --- | --- |
| W3 选回原轨 | 轨 3 的 `4C9E5C9A sourceTrackSwitch` 开始准备，约 4.4 秒后选回轨 2。原 `D224B94B` 的候选记录 `candidateInvalidated`，无第二个准备请求或 `replacement_committed`，仍有原流实图。 |
| W2 最后一次选轨提交 | 先选轨 3（`A3062C88`），约 4.6 秒后选轨 1。第一候选 `candidateInvalidated`，`9FC0E840 playback_prepared audioStreamIndex=1 subtitleStreamIndex=9`，只有一次 `replacement_committed startsPaused=false`，候选内部首帧 12,458 ms，并有实图。实际听音未测。 |
| W1 恢复原轨 | 普通切回 AC3 2 / PGS 9，`21CF7DDD sourceTrackSwitch`。旧 `9FC0E840` 继续至 6945.501 秒，仅一次 `replacement_committed startsPaused=false`，菜单和诊断保留原选择。 |
| W9 画中画接管 | 轨 3 候选 `E6DEDFB2` 准备后点 PiP，旧 `21CF7DDD` 的候选 `candidateInvalidated`，同一旧流 `pip_started`，其间没有 `replacement_committed`。系统小窗有实画，详情仍为 AC3 2 / PGS 9，之后精确停止本轮 App 退出小窗。 |

- W10 在独立进程用已存在的诊断限速 `NASTART_TEST_MEDIA_CAP_BPS=45000000`、`NASTART_TEST_MEDIA_DELAY_SECONDS=5`、`NASTART_TEST_MEDIA_DURATION_SECONDS=70`。内网原片 `57499C1E` 的 `automatic_downshift_requested reason=deliveryBelowSourceBitrate` 触发候选 `1A213FA6`，实记 20→8 Mbps、一次 `replacement_committed`。WDA 在候选准备时查找音轨菜单未见可交互项，保存 XML/PNG；重查时候选已提交，未发选轨，W10 的重叠未覆盖。该窗复算 `2 playback(s) with route evidence, 0 to check.`。
- 18:33:24 正常关闭播放器。清掉本轮测试进程并以空参数、空环境实见首页及原 Wi-Fi 图标。18:33:48 App、Runner、8161 转发和采集全部停止。全程无网络设置变更。原始资料在私有入口 `phone-track-overlap/`。

## 本窗待验项

后续设备回归和正常续播回读见 [2026-11-13 T5 回归结论](CODEX-2026-11-13-PLAYBACK-POLICY-T5-READBACK.md)。

W4/W5/W7 需能从 App 真实触发 `requestReason=serverSeek` 的样本。当前 S19 HLS 的 `AVPlayer.seekableTimeRanges` 接受了约 6,085 秒的跨段跳转，应用实际走引擎路径。W10 仍需一次真实的降档候选与选轨重叠，先确认音轨面板可用，再等待 `automatic_downshift_requested`。W6 旧一集选轨/跳转在加载中的真机拦截和实际听音待补。以上均保留对应模拟器证据，T5 整批尚未验收。另按用户指示完成 [iPhone 18 保留数据安装](CODEX-2026-11-12-IPHONE18-T5-INSTALL.md)。

私有证据入口 `/tmp/nastart-codex-playback-t5-20261112-current`，含签名包、输入清单、预检、模拟器结果和逐步诊断。NAS 和远端文件保持只读，无提交或推送。
