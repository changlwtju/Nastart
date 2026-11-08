# 字幕服务端选择与画中画候选归属接续

## 2026-10-12 字幕服务端选择与画中画候选归属
- 更新时间：2026-10-12T21:04:09.700998+08:00。USB13/Pad优先，配对无线18另更新；每设备现场名称/型号/系统/UDID/连接重核，原始身份、凭据、偏好、原图只在私有目录。新源5a1e70c5普通Debug主e74c7ffe/Debug477aedc5/KSbaaeb6e0；173输入/29逐库签名/深验/profile/IPA/链接/最终三SHA核验，实际328测试/2跳过/0失败、15预检。其他dirty及网络/系统/配对保留。
- 旧6939日志确认KS PiP启动后自动AV候选仍提交；新代码以PiP启动代次守卫所有候选准备/提交。外置文本及Off明确请求服务端字幕-1，PGS源索引保留，增加实际协商诊断与2项回归测试；真实新包HLS候选未触发，旧重复原句未复验，不宣称根因全解/全SUB通过。
- 20:26:43/20:27:19两USB及20:33:11无线18保留容器覆盖成功，25/16/25偏好逐值不变；USB空env实际首页已核，18本轮未启动/前台UI待验。双USB外置ASS实际PiP→同会话系统恢复→同PID全屏；19fresh字幕帧中7有文本，均hdrPQPreserved/分配未尝试/4K PQ，外置HDR浮窗字幕仍F。13返回后clock5519.171在3/10/15停住，手动恢复后推进；Pad返回10/15单白双语且clock推进，限本窗证据。
- Pad暂停ASS→PGS菜单采样仍有白与灰黄重叠，SUB=F；后续10/30仅PGS，持续时长未定。详情未就绪的13伪90秒窗、Pad重复xmark/HTTP404工具失败、文件入口两机t3仍预览/准备全部留证；文件10/30实际电影与普通退出已核，非首帧/全SUB/性能通过。
- 原JF PGS7通过正常UI恢复，最终13JF5815.383/PadJF5877.583均1/7开启；S03文件原轨保留，24/15非书签偏好一致/各2书签自然更新/无新崩溃/实际普通空env首页/播放器关闭/idle10动画2。未写偏好、清登录或改网络。
- 下一步先修13PiP返回停播和Pad暂停双层、重放历史原句/真实新HLS，再HDR保真与S01四入口/代表族、18实际界面、完整帧Lenna/DS One。全SUB/AUD/HDR/性能/蜂窝/MTP/L2/L3及全部旧PX/UX/CB/Main/475/119/HLS等未验总账保留。

## 最新包身份与安装

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS未提交diff SHA-256 `5a1e70c58e88cdabeb5a879d419268d48a0b75f30e4679eedf3d85d8350d2c2c`。普通Debug/-Onone，构建时间 `2026-10-12T20:23:53.232853+08:00`，包名 `Nastart-Subtitle-PiP-Ownership-Normal-Debug.app`，同名IPA；绝对路径在私有根的 `current-package.json`。仅保留数据覆盖，无卸载、偏好写入或登录清除。每窗口空env/args；本轮未使用测试环境变量。

| 二进制 | SHA-256 |
| --- | --- |
| Nastart | `e74c7ffe7a50d666a93e53ec2a894728878ee9311d4e64d6a662bf1b9e92bd54` |
| Nastart.debug.dylib | `477aedc5169af9cb366c3ae41f7bb6987bcddf2364436279692fa91743e55892` |
| Frameworks/KSPlayer.framework/KSPlayer | `baaeb6e0837e19b5bc002b6e19a5fe403eaaea4ab163e166d3fb0acee722eea4` |

173源码输入逐哈希及mtime、29动态库独立签名及app深度签名、IPA一致性、profile目标及UTC有效期 `2026-10-17T22:23:40`、链接和最后源码核对通过。328测试/2跳过/0失败与15预检为本轮实际执行；两项既有委托生命周期跳过仍保留，不能算已测试。

| 设备 | 现场型号/系统/连接 | 覆盖完成（UTC+8） | 安装/启动结论 |
| --- | --- | --- | --- |
| iPhone13 | iPhone14,5 / 16.3.1 / USB | 2026-10-12T20:26:43.647640+08:00 | 容器保留，25偏好一致，实际正常首页已看 |
| iPad | iPad12,1 / 18.3.1 / USB | 2026-10-12T20:27:19.223991+08:00 | 容器保留，16偏好一致，实际正常首页已看 |
| iPhone18 | iPhone19,7 / 27.0 / NETWORK，USB缺席 | 2026-10-12T20:33:11.899406+08:00 | 新包InstallComplete/lookup成功，25偏好一致；本轮无启动/截图/WDA/播放动作，实际界面未验 |

## 本轮实现与因果边界

- `PlaybackPlanningPolicy.swift`：新增Jellyfin服务端字幕选择策略；Greenfield外置文本和关闭字幕发送显式 `-1`，内嵌PGS保持源索引，legacy默认保留。
- `LaunchpadView.swift`：构建PlaybackInfo请求采用策略，记录请求索引/响应协商索引/方法。无URL、token或凭据诊断。
- `GreenfieldKSPlayerRenderer.swift`：从PiP willStart即增长代次并标记starting；starting/active以及跨过该代次的候选不可替换。
- `GreenfieldVideoPlayerView.swift`：候选在准备前/等待中/提交前用既有守卫核代次，包括手动候选；PiP失败/停止释放starting标记，旧候选不会因此重新有效。不改deadline、储备、Range、HDR策略。
- `PlaybackNextCoreTests.swift`：实际DTO JSON显式-1、PGS7/legacy保留；PiP尚未active的starting、active、恢复/失败后的旧代次候选拒绝，新增两项回归。

旧6939包的日志（原始root为上一交接私有目录）显示KS PiP约5392.477秒willStart、started后，自动AV候选在5407.88秒仍replacement_committed。旧恢复15秒原图已再次实际看，白色外置与灰中文/黄英文同一句重叠。因此跨PiP提交确实发生。服务端nil自动选择默认字幕可由[Jellyfin官方StreamBuilder](https://github.com/jellyfin/jellyfin/blob/master/MediaBrowser.Model/Dlna/StreamBuilder.cs)的可空索引回退逻辑确认；旧现场缺少实际协商索引日志，服务器烧录是否为该旧双层的完整根因仍是推断。

新包两个普通PiP窗口都未出现fresh AV候选预热或提交。这说明本窗未跨引擎，不能替代实际候选竞争回归，也未证明新-1在真实HLS烧录上消除了原双层。原失败字幕句必须继续复验。

## 实际真机结果与保留失败

1. iPhone13：新包普通10秒实际单白双语；外置ASS5、KS。30秒普通→桌面3/10/30→同WDA会话系统恢复按钮→原PID全屏。8 fresh PiP字幕帧中3非空，均 `hdrPQPreserved`；返回3/10/15画面停在同一帧，最近遥测clock均5519.171、ahead9.509。该返回停播为F，不能用“有全屏UI”替代播放恢复。随后手动play及实际画面推进已核。近似滑杆定位后3/10/20/30/45/60都未取到原失败字幕句，精确原句回归未完成；不从稀疏无cue推出字幕系统整体缺失。
2. iPad：新包外置ASS5、1288cue、KS/localRangeProxy。相同PiP恢复链有效，恢复10/15两张实图有单层白色中英，遥测5814.688→5824.202→5834.975。这里只验本窗，没有原旧句/真实AV候选反例。11 fresh PiP帧中4非空，均 `hdrPQPreserved`。与13合计19fresh/7非空，PQ 3840×2160、分配未尝试；外置HDR保护拒绝已定因，功能仍F。
3. Pad正常UI暂停切PGS7后，`s03-jf-pad-restored-pgs/pgs-menu.png` 实图同时白色上一层与灰黄PGS，SUB=F；后续自然10秒只有灰黄PGS、30秒无cue。持续多久及为何两层重叠待定位，不能销项。原PGS7均已自然播放并正常退出保存。
4. S03设备文件双USB串行30秒对照：t3仍预览/准备，10/30是真实电影；正常退出。13原4/5开、Pad原4/off保留。非首帧完全通过、音画、HDR保真或连续流畅验收。
5. 13首轮详情字幕控件尚未到位断言失败，而早期shell链仍执行90秒截图；实图是详情，无播放器，归TOOL而非90秒回归。已恢复正常原生详情操作。Pad Cancel与Done均名xmark导致工具断言、恢复后play原生lookup/click404；失败留证，按实际Cancel label/唯一播放控件恢复。未删除失败/超时样本。

## 最终状态与证据入口

最终重新核对源输入/三SHA/深签/USB现场身份。两机正常空env首页实图已看，NAS/JF在线，原其他服务警告保留；播放器关闭，WDA idle10/动画2。13与Pad分别24/15非书签偏好逐值一致，各2条书签自然更新，全部原轨字段恢复；13JF5815.383、PadJF5877.583均audio1/subtitle7开启，文件739.444与938.896。13终审比较开工前baseline偏好，不把中途安装时ASS5误当原轨。崩溃清单均无新增（13 Nastart13/WDA0/Jetsam26；Pad1/1/3）。

私有根为 `~/Library/Application Support/Nastart/DebugEvidence/2026-10-12-subtitle-pip-ownership-201430`；账号/UDID/设备名称/端点/完整日志/偏好/原图均仅在这里。`wireless-update/iphone18`存无线发现与安装回执。`current-package.json`、`source-inputs-private.json`、`final-audit-safe.json`、`batch-summary-safe.json`、各PiP窗口`pip-summary-safe.json`与 `frozen-helpers/`提供接续命令与精确身份。项目仅存[安全结果JSON](../../../testing/results/2026-10/SUBTITLE-PIP-OWNERSHIP-20261012.json)。

## 下一步，未验收项继续保留

优先修13 PiP返回时播放意图/底层状态和Pad暂停ASS→PGS共享覆盖层清理，补暂停保持与继续播放两种真实条件，再重放历史双层原句和真实AV竞争/显式-1协商。随后HDR保真合成方案及S01四入口/代表字幕族、手动失败回滚；18最新普通界面方便时另验。KSMEPlayer PiP setPlaying直接play/pause、共享控制状态与全屏覆盖层同步仅作为待查代码线索，未确认为停播或重叠完整根因。

完整SUB/AUD/HDR、蜂窝、完整帧时间/真实位移与Lenna/DS One同条件对照、MTP、19×4/L2/L3，以及全部旧PX/UX/CB/Main/475/119/HLS供流/deadline/分段/读取/回调等未验总账保持原状态。本批没有声称播放任务全部完成。
