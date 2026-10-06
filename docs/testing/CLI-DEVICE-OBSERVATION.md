# CLI 真机观测复用手册

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
export DEVICE_UDID=00008110-001E543122E0401E
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

历史成功案例：`/tmp/nastart-20261001-resume2/s01-t15.png`、`s01-t30.png`、`s01-resume-progress.png` 配合同目录 XML、syslog.log 和 playback-summary.json；对应 [15:56 记录](../handoffs/2026-10-01-IPHONE13-RECOVERED.md)。从头约52秒、热续播约41秒；热续播有初始缓冲及累计1帧丢帧，不报整轮零卡顿。`s01-first.png` 实为准备中详情，不能当首帧。

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

源选择、时间轴及参数必须有记录；缩略图内容匹配与解码PTS/播放UI时钟分开比较。详见 [HLS 内容映射成功案例](../handoffs/2026-09-06-HLS-CONTENT-MAPPING.md)。

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

替代诊断 `scripts/device_graphics_probe.py` 与 [DVT记录](../handoffs/2026-10-01-DVT-SAMPLER-ALTERNATIVE.md) 可采约1Hz聚合FPS；[CoreProfile记录](../handoffs/2026-10-01-COREPROFILE-RAW-PROBE.md) 有原始解压事件，但显示映射/timebase/丢事件/App归属仍待验证，均不替代上述门槛。

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
