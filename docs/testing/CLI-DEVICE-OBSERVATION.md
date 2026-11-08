# CLI 真机观测复用手册

四设备安装/传输、原生控制与WDA/XCTest分层及当前暂停条件见[真机远控手册](../development/PHYSICAL-DEVICE-REMOTE-CONTROL.md)。本页按日期保留的工具版本、端口和旧Pad记录不能直接用于当前A16；先读当前交接并fresh核包/设备窗口。

## 2026-10-27 TV遥控交互与截图隔离

[同包真实WebDAV对照](../archive/handoffs/2026-10/2026-10-27-TV-WEBDAV-SCREENSHOT-INTERFERENCE.md)显示：XCUIScreen A一次Menu返回→DVT截图B三次不返回→XCUIScreen C含暂停继续又一次返回；具体系统消费Menu机制未证，不能将所有旧失败追溯定为工具干扰。

TV遥控器/普通退出验收的同一交互窗口优先使用XCUIScreen图像，避免在每次按键前或按键间重复调用DVT截图。确需DVT画面证据时另列采集窗；如果紧接取图出现事件缺失，先用同包/同文件/相同路径且隔离取图的窗口对照，再判产品故障。固定等8秒或请求成功本身均不证明已消除干扰。保留失败/主动停止/版本、同正AUT前台PID、实际播放器消失与返回页图；底层详情AX或App进程存在不足以证明退出/普通启动成功。原生性能采集与画面/控制验收仍分开，不把该规则当作不采集真实帧的理由。


## 2026-10-18 快进与分片等待的离线分阶段报告

[分析工具](../../scripts/playback_seek_phase_report.py)读取仓库外的私有事件数组，以真实采集开始/结束的Unix秒为边界，分别输出定位完成、时钟恢复、目标分片请求、首字节等待和正文传输；不连接设备或请求影片。用 `--events`、`--start`、`--end`、`--output` 指定输入和输出，不能把事后分析时间当采集结束时间。

请求按源trace、transferID与task index分开，原标识不导出；旧请求取消不算目标分片，重叠时长不能相加。TCP写方向正常EOF不等于取消；缺少目标/身份/指标保留未知，后续seek截尾单列。响应头等待同时包含网络与上游处理，不能直接断定服务器转码根因；内部时钟恢复也不等于屏幕首帧或字幕正确。参见[本批证据](../archive/handoffs/2026-10/2026-10-18-SEEK-SEGMENT-PHASES.md)。

## 2026-10-16 候选解码后等待的离线核查

新增 `scripts/playback_handoff_alignment_report.py`：输入私有 diagnostics 事件数组、包含 `requestStart` 的动作 JSON，以及该次观测结束的 Unix 秒数，输出白名单字段报告。结束时间应取实际捕获完成边界，不能用分析时的当前时间。此工具不连接设备、不请求媒体；新的真机采集仍先执行最新包门槛。

```sh
python3 scripts/playback_handoff_alignment_report.py \
  "$EVIDENCE/events-private.json" \
  --action "$EVIDENCE/action-private.json" \
  --end-unix "$OBSERVATION_END_UNIX" \
  --output "$EVIDENCE/handoff-alignment-safe.json"
python3 -m unittest discover -s scripts -p 'test_playback_handoff_alignment_report.py'
```

报告按有界 warmup 和完全相同的源 trace 分开，事件 ID 去重且冲突时拒绝分析；缺失、失败、被下一次 warmup 截断和多次 decoded 标记不补成功值。源 trace 不证明服务器会话或候选网络所有权。

本轮 WDA 本地转发一度超时，App/Runner 原生进程仍在；新鲜 USBMux 到设备 8100 的 HTTP 请求可读同一 Runner 的 ready。随后使用独立临时转发完成采集并关闭，原转发也恢复。此类问题先区分控制请求、转发及 Runner，不能仅凭旧端口超时重装 WDA；不同时间的探测不能证明唯一故障组件。原始状态、session 和设备标识保留在私有证据，任何重新采集仍须现场核包和前台守卫。

它只标出已有门槛在单个快照中的明确阻碍：时钟差超过 0.1 秒、帧与候选差超过 0.15 秒、buffer empty、最大报告前向缓冲不足 0.5 秒，以及完整描述的单个 range 不覆盖提交所需区间。最大前向缓冲可能来自不连续的未来 range，不能直接当作可用缓冲。没有发现阻碍也不判 PASS；离散快照不允许把整段等待分配给某一个原因。`alignedToCommitSeconds` 是内部日志事件间隔，不是画面切换或实际出声延迟。

更新：2026-10-01。先读根目录 `PROGRESS.md`、`AGENTS.md`、`docs/handoffs/CURRENT-PLAYBACK-HANDOFF.md` 和 `PLAYBACK-DEBUG-RUNBOOK.md`。本文来自实际历史产物和本轮复验，不假设 CLI、编辑器与桌面 App 拥有相同宿主权限。

## 两条独立取证路线

| 路线 | 工具与结果 | 能证明 | 不能证明 |
|---|---|---|---|
| 视频画面 | WDA PNG/XML、原生截图、源帧图像匹配 | 实际内容、字幕/布局、画面随时间改变、seek 内容是否相近 | 每个显示周期流畅、精确屏幕首帧、听音 |
| 显示性能 | Instruments trace、显示 timing、hitch/commit、逐手势位移 | 有完整覆盖时的工程滚动门槛 | 仅凭空 hitch 表证明流畅、所有视频帧正确呈现 |
| 辅助诊断 | DVT 约 1 Hz FPS、播放器 tick、CoreProfile 原始事件 | 趋势、内部状态、采样服务能力 | 完整帧时间或无丢帧 |

**画面路线不等待 Instruments；性能路线不等待源帧匹配。** WDA `/source` 不包含视频像素，必须看 PNG；UI 时钟/内部 firstFrame 信号不能替代实际画面。截图 API 返回时间包含传输延迟，稀疏截图只能给观测区间。

## 1. 环境与最新包门槛

已验证环境：Apple Silicon Mac；Xcode `/Applications/Xcode.app/Contents/Developer`；iPhone 13 / iOS 16.3.1；tidevice 0.12.11（系统 Python 3.9）；libimobiledevice 的 idevice 工具、iproxy、ios-deploy；标准 Python 3 用于采集脚本。固定 WDA 16.8.0 在本机持久目录，不按天重建。设备需 USB 配对、解锁，出现 Enable UI Automation 时由用户在手机本机授权。

以下在项目根目录执行，变量可用于本文后续命令；每次建立新的证据目录。原始文件不提交 Git。

```sh
cd /Users/lagransun/workspace/Nastart
umask 077
export DEVICE_UDID='填写现场确认的目标 UDID'
export EVIDENCE="$HOME/Library/Application Support/Nastart/DebugEvidence/cli-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$EVIDENCE"
idevice_id -l
idevicepair -u "$DEVICE_UDID" validate
ideviceinfo -u "$DEVICE_UDID" -k DeviceName
ideviceinfo -u "$DEVICE_UDID" -k ProductType
ideviceinfo -u "$DEVICE_UDID" -k ProductVersion
ios-deploy -c -t 5
git rev-parse HEAD > "$EVIDENCE/head.txt"
git status --short > "$EVIDENCE/status.txt"
git diff -- ios/Nastart > "$EVIDENCE/source.diff"
export APP="$HOME/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app"
codesign --verify --deep --strict "$APP"
shasum -a 256 "$APP/Nastart" "$APP/Nastart.debug.dylib"
stat -f '%Sm %N' "$APP/Nastart.debug.dylib"
```

该 APP 是 10 月 1 日 07:32 正常 Debug `-Onone`，仅当当前源码/资源/项目配置仍与该构建相符时可复用；不能永久把它叫“最新”。本轮 HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，保留未提交修改；最新 App 源码 07:32:05，二进制 07:32:39。主程序 SHA256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`，debug dylib `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。

源码变更后先构建，检查完整 BUILD SUCCEEDED、签名及新哈希，更新 APP 路径：

```sh
./scripts/xcodebuild_nastart.sh build -scheme Nastart -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath "$EVIDENCE/DerivedData" \
  > "$EVIDENCE/build.log" 2>&1
export APP="$EVIDENCE/DerivedData/Build/Products/Debug-iphoneos/Nastart.app"
codesign --verify --deep --strict "$APP"
shasum -a 256 "$APP/Nastart" "$APP/Nastart.debug.dylib"
```

安装身份无法读回时，先保留现有故障日志/截图，按需导出诊断；覆盖安装不加卸载参数。失败不得继续标记“最新包回归”。

```sh
idevicecrashreport -u "$DEVICE_UDID" -e -k "$EVIDENCE/crashes"
ios-deploy --id "$DEVICE_UDID" --bundle "$APP" > "$EVIDENCE/install.log" 2>&1
# 必须看到最终 InstallComplete 和 Installed package，复制进度不是安装完成。
scripts/tidevice_private.py -u "$DEVICE_UDID" launch com.changliwen.nastart \
  > "$EVIDENCE/launch.log" 2>&1
scripts/tidevice_private.py -u "$DEVICE_UDID" ps --all --json > "$EVIDENCE/processes.json"
```

`ps --all` 必须保留；默认应用过滤曾漏报存活进程。iOS 16 的 CoreDevice unavailable 或 xctrace 不列设备，也不能单独推断 USB 离线。本轮 18:04、19:54 两次上述 ios-deploy 安装均有完整成功回执，数据保留。

### 诊断下载的USB备用路径（2026-10-02实测）

若`ios-deploy --download`等待设备超时，但`idevice_id`/配对/WDA仍确认同一USB手机在线，可独立使用 [容器诊断下载脚本](../../scripts/download_device_diagnostics.py)：

```sh
/usr/bin/python3 scripts/download_device_diagnostics.py \
  --device "$DEVICE_UDID" --output "$EVIDENCE/container-diagnostics"
```

目录必须是仓库外的新目录；原始plist可能含凭据，权限限定本机私有。脚本复用已有tidevice私有缓存并明确`VendContainer`读取`Library/Preferences`，只读，不安装/启动/写App。普通`tidevice fsync -B ... pull Library/...`默认`VendDocuments`曾返回InstallationLookupFailed但退出0并打印pulled，不能以此当下载成功；须核对真实文件及解析。iPhone13实测644,306 bytes/1,000条诊断，S01设备文件两路停止/续播取证闭环。此替代只解决诊断读取，不证明Instruments或App安装身份恢复。

## 2. 固定 WDA 启动

项目脚本：`scripts/prepare_wda_recovery.sh`、`scripts/start_wda_iphone.sh`、`scripts/install_wda_iphone_once.sh`。新增 `scripts/tidevice_private.py` 替代 `/tmp` 缓存 wrapper；不修改 HOME，私有缓存默认放 `~/Library/Application Support/Nastart/Tools/tidevice-cache`，需系统 Python 已有 tidevice。

在独立终端前台保持下面启动进程：

```sh
export TIDEVICE_BIN="$PWD/scripts/tidevice_private.py"
export WDA_RUNTIME_DIR="$EVIDENCE/wda"
scripts/prepare_wda_recovery.sh
scripts/start_wda_iphone.sh
```

另一个终端读取状态：

```sh
curl --fail --max-time 5 http://127.0.0.1:8102/status
```

成功必须同时满足 ready=true 和 `value.build.productBundleIdentifier=com.changliwen.nastart.WebDriverAgentRunner.xctrunner`，并成功创建 session、获取 source/PNG。host/test 固定 ID 分别为上述 `.xctrunner` 与 `com.changliwen.nastart.WebDriverAgentRunner`；本机包在 `~/Library/Application Support/Nastart/WDA/iPhone-16.3.1`。

脚本实际使用 `tidevice xcuitest -B HOST -e USE_PORT:8100 -e WDA_PRODUCT_BUNDLE_IDENTIFIER:HOST` 与 `iproxy 8102:8100 -u UDID`。直接 launch Runner 不建立 XCTest 会话。本轮 18:04 PID68575、19:53 PID69302 均 ready；PID 仅为历史，不可复用。

若新转发连上残留默认身份 `com.facebook.WebDriverAgentRunner`，先核对设备安装 host、进程和占用端口；确认是固定包的残留 Runner 后停止该包再重启上述脚本：

```sh
scripts/tidevice_private.py -u "$DEVICE_UDID" kill com.changliwen.nastart.WebDriverAgentRunner.xctrunner
```

不要杀未知进程或另起多套转发。只有包缺失/签名失效/明确安装验证失败才调用 install 脚本。收尾 Ctrl-C 停止本轮启动脚本，让它清理自己创建的转发；不要按进程名批量 kill。

## 3. 视频截图：立即可独立执行

新增标准库脚本 `scripts/wda_capture.py`：校验前台 bundle、保存 PNG/XML、每张请求起止 wall-clock/monotonic、session ID 和错误。输出目录必须不存在。默认不清 App 数据、不注入 App 测试变量；新建 WDA session 会激活 App，播放中请复用 session。

```sh
python3 scripts/wda_capture.py --wda http://127.0.0.1:8102 \
  --times 0 --output "$EVIDENCE/startup"
export WDA_SESSION=$(cat "$EVIDENCE/startup/session-id")
# 通过现有 UI 进入 S01 播放，或在手机上点播放；不要硬编码旧元素 ID/坐标。
python3 scripts/wda_capture.py --wda http://127.0.0.1:8102 \
  --session "$WDA_SESSION" --times 0,3,10,30 --output "$EVIDENCE/video"
```

这里 t=0 是命令开始采集，不是播放点击。每张真实时刻见 capture.json；请求变慢时记录实际延后，不伪造精确 t=3/10/30。必要时保留操作点击的独立时间戳，才可给首帧上界/区间。暂停画面不变不等于卡顿。

WDA 暂不可用时，独立截图备选（先通过本机 help 确认工具存在）：

```sh
idevicescreenshot -u "$DEVICE_UDID" "$EVIDENCE/native.png"
```

它不能操作 UI、不能独自完成时序验收；文件格式以实际工具输出为准。

本轮新视频证据：`~/Library/Application Support/Nastart/DebugEvidence/2026-10-01-cli-recovery/video/00..03.png` 与同名XML、capture.json。四张请求实际偏移0/3.0039/10.0003/30.0050秒，响应耗时约299～393ms；已目视确认吉卜力片头到雾中城堡场景，退出回S01详情。日志trace2217D65A，71条telemetry、stallSampleCount0、累计丢帧末值1。截图恢复不代表整轮零丢帧，首帧仍无屏幕精确计时。

历史成功案例：`/tmp/nastart-20261001-resume2/s01-t15.png`、`s01-t30.png`、`s01-resume-progress.png` 配合同目录 XML、syslog.log 和 playback-summary.json；对应 [15:56 记录](../archive/handoffs/2026-10/2026-10-01-IPHONE13-RECOVERED.md)。从头约52秒、热续播约41秒；热续播有初始缓冲及累计1帧丢帧，不报整轮零卡顿。`s01-first.png` 实为准备中详情，不能当首帧。

## 4. 源帧匹配：历史离线复验

原脚本 `tmp/playback-20260905/match-device-content.py`、`match-device-second.py`、`probe-content-mapping.py` 尚在本机，但硬编码旧 FFmpeg 路径、NAS 地址和私有认证文件，且两次运行会覆盖同名 gray/log。**不直接联网重跑旧脚本，也不把凭据文件迁入项目。**

新增 `scripts/match_video_reference.py`，只读本地 gray/showinfo/screenshot，不连接 NAS。复验依赖 ffmpeg；以下隔离安装已实测：

```sh
export FRAME_ENV="$HOME/Library/Application Support/Nastart/Tools/frame-reference"
python3 -m venv "$FRAME_ENV"
"$FRAME_ENV/bin/pip" install imageio-ffmpeg==0.6.0
export FFMPEG=$("$FRAME_ENV/bin/python" -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')
python3 scripts/match_video_reference.py --ffmpeg "$FFMPEG" \
  --reference-gray tmp/playback-20260905/source-device-match.gray \
  --reference-log tmp/playback-20260905/private-source-device-match.log \
  --screenshot tmp/playback-20260905/content-fix-av-second.png \
  --filter 'transpose=2,crop=2176:1170:178:0,scale=1280:688,crop=768:240:256:140,scale=64:20,format=gray' \
  --allow-trailing-pts 2 --output "$EVIDENCE/match-replay.json"
```

2026-10-01 复验输出与历史 `device-content-second-match.json` 一致：1069.633/MAE2.73125；1069.600/2.7421875；1069.666/3.03046875；1069.566/3.121875。1798个 raw 帧；历史 `-to` 截止处 showinfo 多出2个尾部PTS，命令显式允许并记录丢弃。默认要求帧数严格一致，不能为未知中间丢失随意增大 allowance。

裁剪/旋转参数只适用这些历史1170×2532截图与1280×688源，换设备/方向/缩放必须重新确认区域。重复动画帧有多个近似候选，最小MAE不是唯一帧身份，也不证明逐帧流畅。历史首组 `av-forward` 匹配1054.585秒；当前 gray 已由第二组覆盖，不能拿当前数据复验首组。

新素材使用本地已授权文件提取，示例（替换本地输入路径与区间；不包含远端token）：

```sh
"$FFMPEG" -hide_banner -copyts -ss 1060 -i '/absolute/path/reference.mkv' \
  -t 60 -an -vf 'crop=768:240:256:140,scale=64:20,format=gray,showinfo' \
  -fps_mode passthrough -f rawvideo "$EVIDENCE/reference.gray" \
  2> "$EVIDENCE/reference-showinfo.log"
```

源选择、时间轴及参数必须有记录；缩略图内容匹配与解码PTS/播放UI时钟分开比较。详见 [HLS 内容映射成功案例](../archive/handoffs/2026-09/2026-09-06-HLS-CONTENT-MAPPING.md)。

## 5. Instruments：录制与导出独立恢复

先现场区分宿主能力、设备可见性、录制、导出四层：

```sh
xcode-select -p
xcrun --find xctrace
xcrun xctrace list instruments > "$EVIDENCE/instruments.log"
xcrun xctrace list templates > "$EVIDENCE/templates.log"
xcrun xctrace list devices > "$EVIDENCE/instruments-devices.log"
python3 scripts/ui_scroll_probe.py --preflight-only --device "$DEVICE_UDID" \
  --output "$EVIDENCE/sampler-preflight"
```

退出0仍可能为空；预检同时核对目标UDID、工具和模板。不因此阻塞第3节。本轮默认 Xcode 宿主工具列表/模板与历史导出可用，但无法发现 iPhone13；显式切换 Downloads 中 Xcode 26.6（17F113）后设备发现、8秒录制与全部导出成功。与下午 CLI 的“三项皆空”状态不同，尚不能断言原因全部是沙箱。不得从不同会话的结果推断永久权限配置。

本轮 iPhone13 已验证的关键环境（仅当前终端/子命令，不改全局 xcode-select）：

```sh
export DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer
xcodebuild -version
xcrun xctrace list devices
```

之后使用以下录制模式（换成现场可见的目标UDID，输出不得已存在）：

```sh
xcrun xctrace record --template 'Animation Hitches' --device "$DEVICE_UDID" \
  --all-processes --time-limit 60s --output "$EVIDENCE/scroll.trace" \
  > "$EVIDENCE/record.log" 2>&1
# 必须等待保存结束、进程成功退出后再导出。
xcrun xctrace export --input "$EVIDENCE/scroll.trace" --toc > "$EVIDENCE/toc.xml"
xcrun xctrace export --input "$EVIDENCE/scroll.trace" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches-summary"]' > "$EVIDENCE/hitches.xml"
xcrun xctrace export --input "$EVIDENCE/scroll.trace" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="hitches-ca-commit-interval"]' > "$EVIDENCE/commits.xml"
xcrun xctrace export --input "$EVIDENCE/scroll.trace" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="display-vsyncs-interval"]' > "$EVIDENCE/display.xml"
```

CPU另用 `--template 'Time Profiler'`，导出 schema `time-profile`。历史 attach PID/name 曾找不到活进程，所以使用 all-processes 后按实际 process 过滤；不是所有进程时间都归属 Nastart。自然限时保存比强制SIGINT可靠，失败的 trace 不用于判定。

本轮 iPhone13 新产物 `~/Library/Application Support/Nastart/DebugEvidence/2026-10-01-cli-recovery/iphone-alternate.trace`：自然限时8秒录制、退出0、TOC/显示/hitch/commit四项导出成功；实际duration8.418323秒，显示表374行，时间0.358349125～8.412495833秒，最大相邻间隔66.651709ms；hitch16行、App commit表0行。这是视频播放中采样能力验证，未执行滚动，不判滚动PASS或每帧完整。显示列名实际是 `timestamp`，已修正 `ui_scroll_probe.py` 原来误用 `start` 的问题；13项既有工具测试通过。

本机历史成功产物 `/tmp/nastart-oct01-final-launchpad/scroll.trace`（iPad，07:34），本轮再次导出 TOC 和 display 表，取得1945行。TOC/run时间、每个滑动窗口与显示采样覆盖须逐一检查；1945行本身不证明60秒连续采样。本轮不把旧脚本的 launchpad PASS 沿用成新版严格门槛的 PASS。

完整自动滚动入口（先看本轮 XML 确认是长列表及坐标；以下坐标仅是 iPhone13 竖屏示例）：

```sh
python3 scripts/ui_scroll_probe.py --wda http://127.0.0.1:8102 \
  --session-file "$EVIDENCE/startup/session-id" --device "$DEVICE_UDID" \
  --page poster-grid --build '填写本轮二进制哈希与配置' \
  --page-anchor '填写现场XML中持续可见且能区分页面的名称' \
  --x 300 --top 250 --bottom 650 --output "$EVIDENCE/scroll-run"
```

必须≥12次实际位移、前台校验、≥10秒动作、逐拖动显示采样连续性，再判断hitch≤5ms/s且单次<100ms。缺失结果 INSUFFICIENT；显示vsync并不自动等于视频内容提交帧，视频帧节奏仍须 renderer/present事件归属证据。

`--page-anchor` 为正式录制必填，可重复指定多个可见名称，选择不会随列表滚出屏幕的页面标题/导航控件组合；仅有所有页面共用的 Tab 名称不足以区分页面。每次动作前后核对标识和坐标是否在当前 App 视口内；标识消失、方向变化导致坐标越界或前台改变时停止。本轮 20:31 曾发现同一 App 已由启动台切到横屏播放器，不能只以 bundle 一致继续手势，更不能将页面切换造成的文本位置变化当作滚动。

20:28 的新会话即使显式使用 Downloads Xcode 仍返回无设备/无 instruments/无 Animation Hitches。以上 19:58 成功是历史实测，不能代替当前会话预检；截图路线仍可用。

替代诊断 `scripts/device_graphics_probe.py` 与 [DVT记录](../archive/handoffs/2026-10/2026-10-01-DVT-SAMPLER-ALTERNATIVE.md) 可采约1Hz聚合FPS；[CoreProfile记录](../archive/handoffs/2026-10/2026-10-01-COREPROFILE-RAW-PROBE.md) 有原始解压事件，但显示映射/timebase/丢事件/App归属仍待验证，均不替代上述门槛。

## 6. 后续顺序

1. 最新包门槛 → WDA → S01真实截图和内容推进，独立验收画面观测。
2. iOS16优先复用已验证的Downloads Xcode26.6环境，再跑预检、逐页滚动及动作覆盖检查；不要再把默认Xcode找不到设备当成所有链路不可用。
3. 原始显示事件必须证实单位、归属、覆盖及丢失规则才进入逐帧判定；源帧匹配不作为这条路线的前置条件。
4. 流畅度/竞品测试按 `COMPETITOR-DEVICE-MATRIX.md`，保留未知/失败条件，不给尚无有效配对的排名。


## 2026-10-07：滚动采集的页面树开销与边界动作

旧WDA在iPad上为每个离屏SwiftUI元素计算`accessible/visible`曾让单次XML读取达10秒以上，并发生XCTest远程进程连接失效；USB仍可见不能证明开发者会话仍有效。保留工具失败和部分trace，按进程/崩溃/原始记录分类，不将其算成App卡滞或物理拔线。复用已签名/安装Runner恢复，不能因数据不足按天重装。

`ui_scroll_probe.py`现在保留名称/几何的原始XML，跳过全树`accessible,visible`。每个固定页面标识必须经当前WDA元素的`displayed=true`及`rect`核对，和同一次XML中唯一的同类型/同名/同位置节点一致；保存全部独立可见性检查及请求时间。无法核对就停止手势，不能凭位于屏幕内推断可见。真实位移仍使用稳定文字坐标，显示完整性仍要求每次拖动30Hz/最大50ms间隙。

每轮最多24次手势，到12次真实位移停止；边界回弹保留在全部原始记录中，不计入12次有效动作。自然结束录制；录制预算不足、DVT/WDA断连、位移不足、vsync不完整都保留INSUFFICIENT。竞品必须使用同一脚本/配置；更换Xcode主机或构建优化级别时记录，不能把跨环境探索样本用于正式胜负排名。初次实际独立标识快照核验2.294秒，属于工具能力证据，不代表App性能改善。

控制自动化还须核对播放器当前存在。2026-10-07弱S01暂停seek先成功出新画面，但之后出现未明原因的播放器回详情；仅核App Bundle而误点详情同名“播放”会启动新trace，不能当作原播放恢复失败。遇到此情况停止依赖步骤，保留页面/trace变化及TOOL，再独立重跑。


07:33补记：最新iPad Nastart r4已完成12次真实位移、129.177秒动作窗口及逐动作前台/页面守卫，但Instruments最终报告`Failed starting ktrace session`和配置缺失，仍为INSUFFICIENT。Lenna r1有21次尝试/12次位移，动作窗口124.129秒超过120.428秒trace；导出的1007条display-vsync行仅195个唯一时间，范围0.351–7.548秒（解析引用ID唯一，无全程显示覆盖），不能用低hitch数给流畅PASS。失败记录不得丢弃或当App卡滞。

iPad普通播放控制的按钮`name=xmark`、`label=完成`，不与iPhone的名称映射互换。应根据当前XML的类型/label绑定实际name，再核`displayed=true`执行，并核对退出后的实际页面。首次名称误配TOOL保留，后续按现场映射完成正常退出。120秒稀疏图片证明电影/双语字幕画面变化；偏好中的诊断记录仍早于本轮播放，退出后及正常重启后复读也未刷新，缓冲/丢帧/引擎/路由遥测均INSUFFICIENT，原因待定位。未因缺少遥测清除诊断或用户偏好。


## 2026-10-11 iPad后台与PiP冷启动取证补充

2026-10-20补充：系统小窗控件已显示时，点击`PIP-SBInteractionPassThroughView`的默认中心可能直接命中“播放”，不能把该动作后的推进归为自动恢复。先按当前SpringBoard语义Button查询播放/暂停/关闭/恢复；仅四者全缺失、已保存隐藏现场且容器唯一时，才有界点击容器显示控件，然后重新查询唯一目标。暂停保持取证须在任何小窗触摸前保存实际画面、按钮状态及同plan内容时间；控件隐藏导致的定位失败单列TOOL，不能用容器无条件点击掩盖。见[暂停与系统关闭补证](../archive/handoffs/2026-10/2026-10-20-PIP-PAUSE-ROTATION-CLOSE.md)。

查询/动作边界见[共用guard](../../scripts/wda_command_guard.py)、[USB/session适配器](../../scripts/wda_usb_session.py)及[本批集成](../archive/handoffs/2026-10/2026-10-20-WDA-USB-SESSION-INTEGRATION.md)。仅`POST /elements`的精确404 stale可同scene最多3次重读，点击不自动重发。transport保留状态/体并在所有退出关闭连接；session核实际bundle/PID/方向及返回身份，固定defaultActiveApplication时拒绝把该结果当真实前台；不自行改设置/建session/激活App。36单测/8私有旧404集成及13现有设置页实际USB只读通过，新助手与旧历史脚本分开，尚未在真实PiP使用。独立UI transition新读源/图并核明确可见控件变化，只能使用一次；控件/图片字节变化不等于实际暂停或恢复电影，不能用恒真回调。诊断偏好750ms异步保存、KS周期state可为`-`、镜像planID仅8字符；需新事件/同trace与plan及实际采集边界，缓存内容/mtime/零delta不足。原始响应/源/图/异常链只放私有证据。

2026-10-23补充：[瞬态观测时效](../archive/handoffs/2026-10/2026-10-23-TRANSIENT-CONTROL-AGE.md)在`click_unique`提供可选`max_observation_age_seconds`（0<预算≤2秒）及只读`validate_target`。计时覆盖选取前后场景检查、重读、属性验证和发送前记录回调，过期拒绝发送；USBSession使用绑定的单调时钟。实际已发送动作的回报保留派发时选择年龄，未知效果仍封锁后续动作。未指定预算的历史脚本不会自动获得时效保护；门槛本身也不保证瞬态按钮在触摸期间继续存在，更不能证明播放/暂停/退出效果。

进入/退出播放器可改变方向。[后续边界](../archive/handoffs/2026-10/2026-10-23-PAD-S01-PAUSE-AND-EXIT.md)新增`OrientationChanged`及只读`observe_ui_after_rotation(before_scene, target_orientation)`，要求实际旧scene属于绑定session/bundle/PID且目标方向明确、不同；接口不发动作也不重试。调用方应记录进入前真实方向及明确返回目标，不能固定假设所有退出都转竖屏；其他前台/协议错误仍立即停止。70项工具测试不等于真实退出验收，当前Pad普通退出后帧仍缺，输入应答200不能补PASS。

每轮先核设备现场身份、当前源码/有效包与保留数据安装收据。iPad横屏控件可能是pause.fill/play.fill；按新App边界选择真实元素，W3C注入后验证实际效果，不能因请求成功视作已暂停。文件页横屏侧栏没有竖屏底部tab避让，基于实际边界判可见行。

iPad单次Home按钮请求可返回成功却仍显示播放器。保留失败后使用设备级WDA `/wda/homescreen`，默认活动App切到com.apple.springboard并读取新source，再核Nastart后台state2/3。截图先于source时可能仍在Home过渡，不能把该图片当完成的桌面；PiP state4仅在系统真实PiP窗口及原播放trace已确认时有意义。

即时AFC偏好文件可能落后于新进程实际UserDefaults恢复的书签和边界日志。早读数与冷首帧不符时，原读数和断言保留，先标待核/证据未收敛；在已终止且正常冷启动后、任何新播放前做0/1/3/5/10/15/20/30秒有界只读采集，记录同冷PID、空环境、播放器关闭，按原trace/plan确认边界事件及书签，缺失则证据不足。不要在终止前人为等待落盘、重放或注入/回写保存使断言通过，也不能用后续播放的新位置替代原边界。仍需实际冷续播首帧与稳定保存点交叉验证；这种检查不证明Jetsam、崩溃或重启耐久性，更不证明帧性能。详见本次签名续签及iPad回归交接。


## 2026-10-11 已配对无线设备的发现与身份核验

2026-10-15补充：[iPhone18 Wi‑Fi更新操作手册](../development/IPHONE18-WIFI-UPDATE.md)已将本节发现链路接至保留数据安装、既有escrow授权、RSD/DVT空环境启动和实际截图核验；[当次记录](../archive/handoffs/2026-10/2026-10-15-IPHONE18-WIFI-UPDATE.md)包含21:49最新c868包安装成功及25项偏好保持证据。后续每次仍重新发现/核包，不沿用此成功状态。

不要仅凭某个Python mDNS列表缺目标判定手机离线。本次底层浏览遗漏目标服务、地址对象被default=str变成描述文字；macOS系统DNS-SD能解析同一目标服务到当前Wi-Fi地址。发现与传输是独立步骤：广播中的服务端口不一定接受明文lockdownd，随机广告端口握手超时也不证明同一手机的标准连接端口不可用。

使用 `scripts/discover_paired_wireless_device.py --config <本机私有配置文件> --output <仓库外的新私有证据目录>`。配置包含预先从目标读出的udid、bonjourInstance（BonjourFullServiceName的实例部分），不得放入仓库。脚本经系统DNS-SD实时解析地址，按已有配对记录、autopair=false和实时UDID双重核验；广告端口失败时仅在同一已解析地址尝试标准lockdownd端口。它不扫网段、不新配对、不改VPN、不安装或启动App。输出摘要不含原始标识/地址，原始解析、每次失败和已验证端点留私有目录。仅接受identityMatches=true且paired=true的设备，旧地址/版本号/另一设备成功不代替当前身份。

本次18拔线后经系统解析、直接TCP身份、userspace RSD/DVT读取容器、空环境重新启动及真实首页截图成功。Xcode27 Device Hub仍不可用、原生CoreDevice tunnel unavailable/DDI=false单列，不以替代路线成功宣布全部原生工具恢复。每轮调试仍先过最新安装包门槛，WDA/LLDB/完整性能采样分别验证。Tailscale/Shadowrocket保持原配置，未做关闭代理对照，不能断言VPN为根因。

Apple支持无线运行和手动地址连接，见[无线设备运行说明](https://help.apple.com/xcode/mac/current/en.lproj/dev3e2f4ee6d.html)；VPN可能干扰开发通信的情况见[TN3158](https://developer.apple.com/documentation/technotes/tn3158-resolving-xcode-15-device-connection-issues)。这些是排查依据，不能代替本机因果验证。

### 2026-10-16 iPad WDA配置产物核对

canonical `.xctestrun`文件存在并不代表其实际TestHostPath指向最新已续签Runner。本轮旧配置仍指向10月3日过期产物，应递归核对真实host/test路径、嵌套签名、profile及目标设备，而不能只验plist或另一份.app。10月11日续签的固定fixture验证后可复用正式test-without-building；本次短暂ready随后remote connection invalidated，不能将该瞬间作session/source/screenshot验收。失败后先保存报告，原生RSD截图可独立完成App安装启动核验，播放回归仍待WDA恢复。详见[本轮交接](../archive/handoffs/2026-10/2026-10-16-HLS-REQUEST-PHASES.md)。

## 2026-10-20 实际复用及定向观察边界

按[既有链路复用记录](../archive/handoffs/2026-10/2026-10-20-WDA-REUSE-IPHONE18-UPDATE.md)，13标准start识别已有ready无需重装；Pad已装Runner经native RSD/XCTest启动，两端现有转发目标现场匹配并用`wda_capture.py --bundle com.apple.springboard --times 0`取得系统source/PNG。capture会设置idle/cool0，调用方最外层finally恢复实际原值（本轮10/2）。App被停止后旧App-bound session可返回400，重新建立系统session，不据此重装WDA。Pad稍后DTX连接关闭保留，不用一次成功证明长期稳定。

详情完整source超时与固定快速source成功分列；`/source?excluded_attributes=visible,accessible,traits`只用于导航结构，缺字段不推可见性。定向原生PiP观察只读唯一容器/播放/暂停/关闭/恢复的displayed、enabled、rect与PNG，同scene前后核对、原文私存；桌面属性实测支持不等于PiP实际观察通过。当前三次尝试只到导航、未发播放/暂停/恢复；用户要求停止扩展封装、优先复用本文既有工具，未使用的额外touch封装已移除。


## 2026-10-22：SwiftUI Menu的实际可见目标

PadOS18普通包实测导航栏Menu可能同时有同名同位置的外层`XCUIElementTypeOther`和内层`XCUIElementTypeButton`。只看Button会漏掉实际目标：[属性与菜单实证](../archive/handoffs/2026-10/2026-10-22-IPAD-TOOLBAR-OBSERVATION.md)中外层displayed/enabled/hittable=true，内层displayed/hittable=false。结构/屏内坐标相同不代表两者均可操作，也不证明截图倒置是原因。

先保存现场AX/原生图，单独只读核实际唯一目标的displayed、enabled、hittable、rect，矩形匹配同窗AX，前后台PID/方向一致后才选定目标并发一次语义click；目标应限定在当前导航栏，不能把所有同名祖先当候选轮流点击。任一守卫失败即停止，未知动作不重发，不删displayed检查、不用倒置PNG坐标补点。菜单出现/选择原项关闭/正常返回必须各用新AX和实际图确认，不能用请求成功代替效果。此规则只补已有工具的目标识别，不新建自动换目标或重试封装。

## 2026-10-23 系统session与返回主屏路由核验

[双设备新现场](../archive/handoffs/2026-10/2026-10-23-WDA-USER-RECOVERY.md)：ready=true但sessionId为空时不可拼接旧/空session。新系统session中本轮activeAppInfo报告SpringBoard而真实屏及source已是Settings，字段与画面不符时不得单凭它宣布前台稳定或据此补发激活动作。保存实际源/图和响应，App回归仍核绑定进程并以真实画面证明。

本机WDA返回主屏使用全局`POST /wda/homescreen`；带`/session/<id>`前缀本轮两端均404，勿把它当已执行。全局请求成功后两台实际Home图已看，才确认返回。Pad Runner手动点开出现SIGABRT需保存报告；本轮经既有签名Runner的native RSD/XCTest启动取得ready与真实设置/Home操作，无重装。当前只有有限控制证据，不能外推媒体或长期稳定。
