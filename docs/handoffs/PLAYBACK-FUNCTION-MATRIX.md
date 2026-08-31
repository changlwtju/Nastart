# Nastart 18×4 播放功能验收矩阵

更新时间：2026-08-29（Asia/Shanghai）

本表把“18×4 播放单元”和“每个单元要测什么”分开固定。结果填写在 18×4 单元格中，不能只写“能播放”。状态顺序固定为：

核心状态序列：`LIB / FF / ST / PA / SK / AT / SU / Q / PP / EX / MEM`

在核心序列之外，所有播放单元再追加补充项：`SA = SUB / AUD`（字幕显示 / 音频输出）。

- `FF` 首帧；`ST` 连续播放；`PA` 暂停/继续；`SK` 快进/快退；`AT` 音轨；`SU` 字幕；`Q` Jellyfin 清晰度；`PP` 画中画；`EX` 退出/断点续播；`MEM` 内存/进程稳定性。
- `SA` 不替换 `AT` 或 `SU`：`SUB` 验证字幕是否实际显示且内容正确，`AUD` 验证设备音频输出是否可听、连续且无异常；两项分别记录，避免“字幕正常但无声”或“有声但字幕乱码/重复”被合并掩盖。
- 每项状态使用：`U` 未测、`P` 通过、`F` 失败、`N/A` 不适用、`NA` 不可达、`TOOL` 工具失效。
- `LIB` 是入口资源加载：Jellyfin 记录媒体库首屏/海报/详情；设备文件记录目录加载和点击后的明确等待反馈。设备文件入口的 `Q` 固定为 `N/A`；Jellyfin 入口的 `Q` 必须测；没有字幕/第二音轨时仍要记录为 `N/A`，不能留空。
- `PP` 的自动化验收必须记录完整链路：DS One/Nastart 播放器入口点击 → 系统 PiP 浮窗出现 → SpringBoard 会话发现 PiP 控件 → 点击 `恢复全屏幕` → 回到播放器且断点保留。不能只记录 Home 后浮窗出现，也不能在错误的 App session 中猜测退出按钮。
- 传输策略是跨样本的验收前置条件，不允许在单元格中填入“某样本专用窗口”。设备文件和 Jellyfin 原始直播放流都必须记录 `client=continuous chunked`、`upstream=finite 206`、窗口切换的精确偏移、总长度和短 EOF/重试；窗口边界不能被记录为 `ST` 结束或 `EX` 触发。
- 单元格示例：核心项 `P/P/P/U/U/U/U/N/A/U/U/P`；补充项另记 `SA=P/P`。

## 入口缩写

| 缩写 | 含义 |
|---|---|
| `IP-D` | iPhone · 设备文件 |
| `IP-J` | iPhone · Jellyfin |
| `PD-D` | iPad · 设备文件 |
| `PD-J` | iPad · Jellyfin |

## 18×4 单元格总表

初始值全部为 `U`。任何一次参数或链路改动后，至少重测 S01 的四个单元以及受影响格式族；不允许沿用旧构建结果。

| 样本 | IP-D | IP-J | PD-D | PD-J |
|---|---|---|---|---|
| S01 哈尔的移动城堡 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S02 杀死比尔 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S03 碟中谍3 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S04 好东西 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S05 南方车站的聚会 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S06 爱情神话 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S07 白日焰火 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S08 黑豹：瓦坎达万岁 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S09 天空之城 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S10 奇异博士2 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S11 神奇动物在哪里 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S12 神奇动物2 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S13 非诚勿扰 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S14 无间道 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S15 奥本海默 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S16 A计划 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S17 A计划续集 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |
| S18 方世玉续集 | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U | U/U/U/U/U/U/N/A/U/U/U | U/U/U/U/U/U/U/U/U/U/U |

## 功能判定细则

| 代码 | 通过条件 |
|---|---|
| `FF` | 进入播放器后有可辨认真实视频帧；只出现播放器、进度条、片源水印或转圈不算首帧 |
| `ST` | 至少 30 秒进度持续推进，期间无长时间黑/灰屏、无超时和无重复缓冲 |
| `LIB` | Jellyfin 首屏资源、海报和元数据在可接受时间内出现；设备文件目录和点击后的状态明确，不出现无反馈的归零等待 |
| `PA` | 暂停按钮和视频画面双击均可暂停；再次操作后画面从相近时间点恢复 |
| `SK` | 前进/后退 15 秒后时间点正确，画面在合理时间内恢复 |
| `AT` | 每个可用音轨可切换，切换不退出、不回到 00:00 |
| `SU` | 每个可用字幕可切换，字幕显示正确，切换不破坏播放位置 |
| `SA` | 以 `SUB/AUD` 分开判定：`SUB` 在实际画面中显示正确、无乱码/方框/重复/残留；`AUD` 在设备扬声器（必要时再测耳机/路由）中有可辨识声音、无持续静音/断续/失真，音轨切换后仍正常。没有可用字幕时 `SUB=N/A`；没有音频轨道时 `AUD=N/A`；不能只凭播放器控件存在判定通过 |
| `Q` | Jellyfin 清晰度切换成功，时间点和播放状态保留 |
| `PP` | 进入/退出 PiP 成功，回到 App 后断点保留；不支持时记录明确原因 |
| `EX` | 退出播放器再进入时断点符合产品定义，不意外从头开始 |
| `MEM` | 采样期间 App 未被 Jetsam/崩溃；记录设备日志和关键内存现象 |

## 当前已知填写

### 2026-08-31 Nastart S03 播放引擎优化验证

- 在源码修改前已执行远端/工作区核对，本地 `main` 与 `origin/main` 没有提交差异，
  但工作区存在既有未提交文档、WDA 脚本和播放相关改动；本轮未回退这些改动。
- 先将当时工作区构建出的 Nastart Debug 包安装到 iPhone 13，再应用本轮播放协商改动，
  重新构建 `/tmp/NastartEngineOptIPhoneDerived/Build/Products/Debug-iphoneos/Nastart.app`
  并安装到同一设备；`ios-deploy` 返回 `InstallComplete`，WDA 16.8.0 在 `127.0.0.1:8102`
  返回 `ready=true`，Nastart session 可读取首页 XML。
- S03《碟中谍3》详情页在 Nastart 中显示 `4K · H.265 · HDR`，默认音轨为
  `TRUEHD - 5.1 - 默认`，字幕为 `ASS`，源文件名含
  `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`，大小
  `54.01 GB`。本轮新增策略让私网/码率安全原始文件在默认音轨触发 HLS 但存在可直放音轨时，
  初始播放先选择可直放音轨，避免不必要的 Jellyfin HLS 首段等待。
- 验证结果：点击“在 Nastart 中播放”后进入内置播放器并取得真实画面；两个延后截图
  `/tmp/nastart-engine-opt-s03-now.png` 与 `/tmp/nastart-engine-opt-s03-later.png`
  内容不同且后者字幕文本变化，证明画面持续推进。syslog 出现 `MobileVLCKit` player instance
  创建；AVPlayer 初始化日志仍存在，但这是系统 player session 目前无条件构造的副作用。
- 继续优化：compatibility 初始路由已延迟 `AVURLAsset`/`AVPlayerItem` 创建，系统播放器资源
  只在实际选择 AVPlayer/PiP/HLS fallback 时准备。新包重采 S03 时，`t=2.3s` 进入播放器
  loading，`t=6.2s` 出现可辨认真实帧，`t=8.3s/12.3s` 画面继续推进；起播阶段 syslog
  仍记录 `MobileVLCKit` player instance，未见 `AVURLAsset`/`AVPlayerItem` 媒体加载关键字。
- 自动化注意：详情页播放按钮曾因中心点与底部 tab bar 重叠导致一次误点，本轮已将播放主操作
  移到音轨/字幕选择之前，减少小屏和 WDA 坐标点击污染。
- 控制层修复：MobileVLCKit 内置播放器自动隐藏控制条后，单击视频画面可重新显示控制项。iPhone 13
  WDA session `66B27E04-DEC4-459D-A8C9-30F57280F274` 用 Jellyfin 样本《哈尔的移动城堡》
  验证：隐藏态只保留 `显示或隐藏播放控制` 命中层，单击后 `完成`、`暂停`、`前进 15 秒`、
  `后退 15 秒`、`音轨`、`字幕`、`更多播放控制` 等按钮重新可见。截图：
  `/tmp/nastart-controls-hidden.png`、`/tmp/nastart-controls-after-tap.png`。
- 未完成项：首次精确分秒采样脚本失败，因此本轮不能填写准确 FF 秒数；未完成
  `PA/SK/AT/SU/AUD/Q/PP/EX/MEM` 全矩阵；HTTP Range/Content-Range 仍需服务端或代理日志补齐。

### 2026-08-29 DS One S03 大文件动态续采

- DS One 2.4.5 Build 4 在 iPhone 13 上继续采集 S03《碟中谍3》
  `50.3 GB` Jellyfin 样本，证据见
  [2026-08-29-DSONE-S03-DYNAMIC-CONTINUATION.md](./2026-08-29-DSONE-S03-DYNAMIC-CONTINUATION.md)。
- 本轮已确认：首个真实视频帧约在点击播放后 3 秒出现；`HEVC / 2160P /
  23FPS / 57.42mbps` 画面连续推进至少 30 秒；暂停 5 秒定帧且吞吐降到
  `0 B/s`；恢复后从相近位置继续；进度条前跳/回跳后不回到 `00:00`；音轨菜单列出
  AC-3/TrueHD 四轨且选择 TrueHD 后位置保持；字幕菜单列出 PGS/ASS 且切到 ASS 后播放不中断；
  后续自然画面已看到 ASS 双语字幕实际渲染；PiP 进入后出现 iOS 系统 PiP 浮窗，并在恢复后
  回到 S03 全屏播放器且位置、字幕保持。
- 本轮不能升级为完整 `P` 的项：精确 +/-15 秒 seek、按固定采样点完成的字幕完整性、实际音频听测、
  Jellyfin 清晰度切换、HTTP Range/Content-Range、服务端 Range 日志和 PiP 退出闭环。
  PiP 入口与恢复均有截图证据，但 SpringBoard `恢复全屏幕` XPath 退出步骤仍被 WDA 设备锁定状态阻塞；
  该项应继续记为 `TOOL/U`，待下一次稳定解锁状态下重跑。

### 2026-08-29 Range 响应校验实现状态

- Nastart 本地认证 Range proxy 已将上游 `206` / `Content-Range` / 请求起始偏移 /
  文件总长度校验收敛到 `MediaRangePolicy.validatedPartialResponse`，并在交付 body 前拒绝
  `200`、缺失或 wildcard 总长度、起始偏移不匹配、反向区间和超出文件长度的区间。
- 本次只更新跨样本传输前置策略和单元测试覆盖；未执行 DS One 2.4.5 真机动态采集，也未执行
  Nastart 四入口播放矩阵回归，因此 18×4 单元格状态不变。
- 验证状态：`preflight`、`git diff --check`、generic iphoneos app build 通过；simulator 单测仍被
  `NastartTests` target 无法解析 `MobileVLCKit` 模块阻塞，需单独修测试工程依赖后重跑。

### 2026-08-15 通用传输策略验收状态

- 已通过 15/15 iOS 单元测试、preflight、Swift parse、签名 iphoneos 构建和 playback-lab 的连续 `206` Range 样本（`0-32767`、`32768-65535`）及 malformed Range `416` 边界检查。
- 当前代理策略固定为“客户端连续 chunked + 上游有限 206 窗口”，续段按每个上游任务的实际交付量计算；这是跨样本的传输实现约束，不是 S01 专用参数。
- 最终包已安装到 iPhone `00008110-001E543122E0401E` 和 iPad `00008030-001168403C43C02E`。iPad WDA 已通过标准 `xcodebuild test` → `iproxy 8101:8100 -u UDID` → `/status ready=true` 恢复，并重新采集 S01 设备文件入口 t=0/3/10/30 真实画面；不能把工具恢复或部分截图推断为 S01 新包完整通过。
- iPhone 的标准 Xcode 26.6 XCTest 通道仍会报告 `DVTBuildVersion` 空值/`Logic Testing Unavailable`，但历史 DVT 链路已恢复：正确 Bundle ID 的 WDA 16.1.5 在 `127.0.0.1:8102/status` 返回 `ready=true`，并已建立 session、读取启动台和“设备→文件”页面。iPhone 播放四单元尚未因此自动通过；仍不得用 iPad、simulator 或 playback-lab 替代 iPhone 的首帧、ST、SA、控制项或 MEM。

S01 的历史结果和证据仍以结果表为准。目前不能把 S01 四个入口标记为完整通过：iPhone 旧构建曾发生 Jetsam；修正版 iPhone 曾在 3 秒和 10 秒看到真实画面；旧的 32 KiB/8 MiB/32 MiB 窗口实验曾分别在不同时间点停滞。当前构建改为“有限上游窗口 + 客户端连续 chunked 响应”，iPad Jellyfin 已取得 t=0/3/10/30 真实帧并推进到约 1:18，仍需完成四入口全功能、并发以及 S03/S08/S11/S18 格式族回归后才能固化。

电视剧专项使用相同的核心项和 `SA=SUB/AUD` 补充项，另加 `NEXT`（接近结尾自动跳转下一集）和 `EP-RESUME`（跨集/返回上一集的断点与集号正确）。ISO 专项至少记录 `ISO9660/Range/FF/ST/SK/AT/SU/SA/EX/MEM`；ISO 样本缺失时写“样本缺失”，不得用普通视频替代。

## SA 补充项的固定采集

- `SUB`：在 `t=3/10/30s` 至少各观察一次字幕，并额外等待一个自然字幕帧；记录字幕轨道是否存在、实际显示文本、字形/编码、是否重复或残留、是否被底部裁切，以及切换后是否保持播放位置。`SUB=P` 的必要条件是画面上每个可见字都完整可辨、无方框/缺字/乱码/重复层/残留；任一采样帧出现问题即为 `SUB=F`，不能用另一个正常句子抵销。截图只能证明“画面上的字幕结果”，不能仅凭“字幕”按钮存在判定通过。
- `AUD`：在首帧出现后确认设备实际音频输出，至少覆盖 `t=3/10/30s` 的可听性和连续性；记录输出路由（设备扬声器/耳机/系统路由）、是否静音、是否断续/失真，并在存在多音轨时记录切换前后结果。音频输出不能由视频截图推断，必须有听测或等价的音频路由/系统日志证据。
- `SA` 的结果格式为 `SUB/AUD`，可写 `P/P`、`F/P`、`P/F`、`N/A/P`、`P/N/A`、`TOOL/TOOL`；任一子项未测，整体 `SA` 不得记为通过。

字幕问题的判定顺序固定为：先判断是外挂 UIKit overlay、内封 VLC/SPU、还是两条路径重复；再检查编码与 CJK 字体；最后检查布局/安全区域。不得只给某个样本添加字体、编码或位置参数。历史失败截图必须作为回归基准，且必须在修复后的同一入口、同一设备和至少一个不同字幕帧上复核。

每次填写 `P` 或 `F` 必须在结果表追加：构建时间、设备、入口、链路、截图路径、日志路径和时间点。这样后续可以区分“同一视频不同链路失败”和“同一链路不同视频失败”。
