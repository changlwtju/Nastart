# 画中画播放状态与暂停字幕归属接续

## 2026-10-12 画中画播放状态与暂停字幕归属

- 更新时间：2026-10-12T22:06:32.541731+08:00。USB13/Pad优先，既有配对无线18另更新；每设备/窗口现场名称、型号、系统、UDID及连接重核，原始身份/凭据/偏好/原图仅私有。HEAD4de732dd、最终dirty源ea2f11eb，普通Debug主3ecb4173/Debugd3e7abcb/KSbaaeb6e0；173输入、29逐库签名/深验/profile/IPA/链接及最终三SHA核验。本轮实际331测试、2跳过、0失败及15预检；其他dirty、网络、系统、配对保留。
- 修正KS界面/切换按钮读取过期layer.state的问题，改读真实引擎并仅在变化时同步；外置覆盖按已提交字幕状态解析URL，暂停换PGS/Off无需等下一clock。中间d640版真实AV初始外置字幕被误清，已留证并补齐AV初始sidecar种子及第三项回归，最终ea2包已复验白双语。增加PiP返回时引擎/控件/时钟快照，不强制自动播放。
- 新鲜d640证据确认旧工具第二次点击浮窗中心实际命中系统暂停；暂停先于restore_requested。历史5519冻结同样工具模式仅作疑因，原失败未删除。最终13同PID系统返回：播放窗5982.574→5993.069且引擎/控件true；明确系统暂停窗3/10/15均6074.114、引擎/控件false且实际Play按钮，保留用户暂停。暂停窗首轮自动返回未接通，直接实际Restore补验成功；TOOL失败和重试保留。
- 最终Pad真实自动KS→AV/localHLS提交，外置请求server=-1，响应index=none/method=Encode（不能说服务端已承诺关闭烧录）；1288cue及白双语已看。暂停同句“不 / No.”切PGS7后真实AV startsPaused提交，30秒已看仅灰黄PGS、旧白层消失。启动3/10秒spinner与PGS初始准备保留；历史“Remember / I can figure…”原句未重放，不能解除历史SUB=F或宣称全SUB通过。
- 21:47:05/21:47:14两USB及21:49:28无线18保留容器覆盖成功，25/16/25偏好逐值一致；USB空env/args实际正常首页已看，18本轮未启动/前台UI待验。最终两13PiP窗16fresh帧、8有文本：有文本均hdrPQPreserved/分配未尝试/4K PQ，HDR外置浮窗字幕仍F；无候选提交跨过本次PiP，但完整竞态未验。
- 原JF PGS7经正常UI恢复；最终13JF6128.139、PadJF5860.423337333334均1/7开启，S03文件原轨及位置未动；24/15非书签偏好一致、各1JF书签自然更新、0新崩溃、普通空env实际首页/播放器关闭/idle10动画2。下一步重放历史重复原句与HDR保真方案，再最新源S01四入口/代表族、18实际界面及完整帧Lenna/DS One；全SUB/AUD/HDR/性能/蜂窝/MTP/L2/L3及全部旧PX/UX/CB/Main/475/119/HLS未验总账保留。

## 最终包身份与每台安装门槛

本轮开始基线5a1e、诊断中间d640及最终ea2分别冻结包与窗口身份。旧包故障/工具失败仅用于分析；最终结果只归ea2。每次切设备/开窗口重新读取USB或Bonjour既有配对连接、名称/型号/系统/UDID，源码diff、签名及已覆盖安装的包身份，普通env={}、args=[]。未经可靠安装身份确认先保留诊断，再保留容器覆盖；没有卸载或清登录。

| 设备 | 型号/系统/连接 | 最终覆盖时间 | 安装前后偏好 | 实际界面 |
| --- | --- | --- | --- | --- |
| iPhone13 | iPhone14,5 / 16.3.1 / USB | 21:47:05 | 25逐值一致 | 已看正常空环境首页及播放窗 |
| iPad | iPad12,1 / 18.3.1 / USB | 21:47:14 | 16逐值一致 | 已看正常空环境首页及播放窗 |
| iPhone18 | iPhone19,7 / 27.0 / NETWORK，USB缺席 | 21:49:28 | 25逐值一致 | 本轮未启动；待补最新UI/播放 |

包在本机私有根目录 `Nastart-PiP-Restore-Subtitle-State-Final-Normal-Debug.app` / 同名IPA；build 2026-10-12T21:45:21.741066+08:00。173输入hash/mtime、29逐库签名、deep/strict、profile设备及有效期（UTC2026-10-17T22:23:40）、IPA与动态链接已核。源版本包括其他既有未提交修改，没有reset/commit/push。

源码diff SHA-256：`ea2f11ebacc2d9c15f9226853517bc27ab59b013a455890a821af610c863a179`。

- Nastart：`3ecb417331c61ae36776e67b857f23fb03cf286f53c7fa2f36d5b44fc9d32a41`
- Nastart.debug.dylib：`d3e7abcbbd97fd9d33eb9be9d16870a1b7592121643e930a2f2af2f186ddaba0`
- Frameworks/KSPlayer.framework/KSPlayer：`baaeb6e0837e19b5bc002b6e19a5fe403eaaea4ab163e166d3fb0acee722eea4`


## 变更及有效验证边界

`GreenfieldKSPlayerRenderer` 的KSPlayerLayer delegate在state.willSet回调里读layer.state会看到旧值，系统sample-buffer PiP又直接控制player。现在onStateChanged、toggle和轮询同步读取player.isPlaying，只有值变化才发布，诊断同时保留layer状态作为对照。没有forceResume、延长候选deadline、绕过HDR保护或素材硬编码。

`LaunchpadView` 的CJK覆盖按session已提交subtitleSelection解析external URL；已确认bitmap/关闭时立即nil，未知/legacy仍用请求。首次onAppear与onChange均用解析结果，避免PiP重建把旧sidecar重新打开。测试实际载入临时SRT、暂停clock、外置→bitmap→关闭→缓存外置恢复；另测未知选择回退。

中间d640的这项解析暴露AV无native legible group时初始sidecar未种入controls、导致白字幕消失。该真机失败保留并新增AV初始sidecar测试，GreenfieldVideoPlayerView向beginSession传入已规范化初始URL（Off仍nil），最终真实AV白字幕已看。最终实际331项测试中2项既有delegate lifetime fixture跳过、0失败，不能写“331全部通过”；15预检通过。

## iPhone13画中画：自动化污染与最终两种意图

新鲜中间包system XML里浮窗中心正位于Pause按钮矩形，系统controls截图前引擎playing=true，而旧工具第二center后restore_requested为paused。此复现是TOOL-induced pause；历史5519冻结只推断同类原因，未重做当时引擎快照。未将历史失败删除，也未用强制播放盖住正常暂停。

最终播放窗 `s03-jf-final-playing-pip-ownership` 使用避开Pause的上方视频点显控并实际系统Restore，同WDA会话/同进程且无终止App。restore_requested clock5905.539与stopped5906.925均playing/controls=true；返回3/10秒最新遥测5982.574，15秒5993.069，3/15原图电影/白双语变化。10秒重复是稀疏诊断采样，不是连续帧性能证据。

最终主动暂停窗 `s03-jf-final-paused-pip-ownership` 明确按系统Pause，首次自动恢复仍浮窗，assert及截图留证。按新鲜系统实际Restore直接点恢复补验；同PID全屏，restore/stopped及3/10/15遥测clock6074.114、engine/controls=false，已看Play按钮与相同电影/白双语。不会把补验写为首轮恢复成功；控制显示定时导致的脚本不稳仍需改善。13清理PGS菜单采样出现播放状态（未作暂停换轨通过），随后普通退出保存原1/7/on。

这两个最终PiP窗16fresh字幕帧事件、8条有文本均hdrPQPreserved/composited=false/分配未尝试/3840×2160 PQ，外置HDR浮窗字幕仍失败。1次候选预热、0候选提交可说明本窗口未跨PiP提交，不能替代完整代次竞态验收。

## iPad：真实AV外置与暂停同句切PGS

`s03-jf-pad-final-ass-pip-ownership` 名称沿用工具目录，但本窗口没有PiP。3/10秒实际spinner保留；后续自动KS/localRangeProxy→systemAVPlayer/localHLS候选提交，external1288cue、暂停时白双语“不 / No.”已看。新HLS playback_prepared明确requestedServerSubtitleIndex=-1，协商index=none/method=Encode，仅证明请求与本次单白层采样，不能宣称服务端保证不烧录。

暂停ASS→PGS7的首秒图仍准备，不算成功；随后decoded/aligned/warmup及真实replacement_committed startsPaused=true，PGS请求7、响应7/Encode。30秒原图同一句只灰中文/黄英文，白覆盖消失、暂停保持。本次是AV服务端PGS烧录结果，不假装KS native bitmap真机覆盖。历史13“Remember? At the Vatican…”和Pad“I can figure…”原句未重放，历史SUB=F保留；当前单cue有改善不能做全SUB通过。

## 清理与下一步

两USB按普通UI退出，0/4/15快照与最终普通空env首页已核；原JF音轨1/字幕7开启恢复，13JF6128.139、PadJF5860.423337333334。S03文件13=739.444/4/5/on、Pad=938.896/4/off未变化；各仅1个JF书签自然更新。相对本轮最初baseline，24/15非书签偏好逐值不变，崩溃/JetSam/WDA报告0新增，idle10/动画2恢复。原图、XML、偏好和凭据只本机私有。

下一轮先重新现场设备/源码/包门槛，然后原句精确复验白黄重复层，HDR外置PiP保真方案、PiP候选完整竞态；再最新源S01四入口与19×4/代表族S08/S11/S18/S19、实际AV手动失败回滚、HLS deadline/供流/callback与18真实正常UI/播放。Lenna/DS One须按矩阵同条件采实际位移和完整帧时间，不能以本轮离散图或手势成功判性能PASS。iPhone13本轮Wi-Fi，非蜂窝119验证。

全SUB/AUD/HDR/性能/MTP、蜂窝、自动Xcode隧道、18WDA与界面、475储存边界以及所有旧PX/UX/CB/Main/L2/L3未验总账保留。没有改变网络/VPN、系统配对或remoted/DDI。安全结构化结果见 `../testing/PIP-RESTORE-SUBTITLE-STATE-20261012.json`；原始证据在本机私有 `DebugEvidence/2026-10-12-pip-restore-subtitle-state-211050`，中间d640包/test/input与安装结果另存intermediate-d640，所有导航/控件HTTP404/未恢复/超时工具失败均保留。
