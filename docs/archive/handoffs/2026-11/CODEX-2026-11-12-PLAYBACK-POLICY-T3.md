# 2026-11-12 播放策略 T3 · iPad 内网读数

## 同包与索引

- A16 iPad（iPad15,7 / iPadOS 26.6）当前 USB 身份、现装路径及 Runner 签名复核通过。HEAD `8db1cc64` 加开工未提交内容，499 个 iOS 输入无漂移。沿用 [T0 签名 Debug](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md)，dylib SHA-256 `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。普通 App 启动。Wi-Fi 图标和播放器 Wi-Fi 状态可见。
- [预检](CODEX-2026-11-12-PLAYBACK-POLICY-T3-PREFLIGHT.md) 后，07:41 在已存 SMB 连接下确认只选择 S19 影片目录。新索引只有 128,795,641,934 字节的目标文件，之前 4 库、4 连接逐项相等。其中空 `media` 项来源未确认，单独保留。坐标点选来源行及原生元素点击均弹出上下文菜单，07:46 以来源标题内的无停留短触摸实际进入海报页并打开 S19 详情。

## 07:46–07:48，SMB 起播

- Trace `5B2DB9A5`。实际 `playMethod=directPlay`、`routeKind=localRangeProxy`，内层为 SMB Reader，存在 `readerTimingWindow` 和 `readerFirstChunkDelivered`。`tapToFirstFrameMs=3354` 为内部信号，7 秒取证的画面为真实片头。音轨菜单自动化未取得唯一按钮，AC3 2 / PGS 9 配平、续播和前后 15 秒未完成。
- `python3 scripts/playback_reader_timing_report.py 5B2DB9A5 <联合诊断>` 输出 `readerWindows=33 playerSamples=49 verdict=noStall`。有计时读取 195 次、交付 202,391,735 字节，`readerSplit.wireBitrate=46378903`、`meanReadMs=179.0`、`readMs=34911 queueWaitMs=591 otherMs=75`。无卡顿判定限于报告可对齐的样本。
- 首三块的 `queueWaitMs / readerToDeliveryMs` 为 `0/704`、`192/196`、`396/667`。16,567 字节尾部请求实际连接读取 4 ms，等待队列 192 ms。两笔首块排队占 98.0% 和 59.4%，已命中交接中「首块排在旧读取后面」的判读。单次观测未改读取策略。
- 07:48:48 仅撤本轮可追溯的单影片临时索引，实际确认对话框与名称相符。读回基线的全部 4 库、4 连接相等，临时项归零。随后本轮 App、Runner、转发、采集收尾核对通过。联合原始诊断、即时取证和报告在私有指针 `/tmp/nastart-codex-playback-device-20261112-current` 下 `pad/t3-lead/`。

## HTTP 参照导航

- 07:49 的设备文件目录有界滚动 55 秒超时。07:52 下拉后搜索字段仍不可用。两次均停在 S19 播放之前，独立保存页面及诊断，随后 App、Runner、转发和采集归零。
- 07:55 尝试按修改时间排序，已实际写入排序选项。坐标操作未能选中降序或在同会话恢复名称排序，未开始播放。07:58 用原生元素选择「名称」，偏好读回名称升序。原先名称排序使用默认值，现等效值显式保存在客户端。未更改其他排序偏好。
- 07:59 用原生元素设定修改时间降序，实际进入 S19 文件夹；嵌套目录中尝试恢复时，元素点击 HTTP 404，保留失败。08:02 复用当时的排序进入同一 S19 文件，从头播放。Trace `A4A9AA15` 为 `networkClass=wifi addressKind=localDomain playMethod=directPlay routeKind=localRangeProxy`，内部首帧 1,935 ms。点击返回后的首 30 秒内，`stage=upstreamBodyProgress measurementBoundary=receivedBodyWindow bodyWindowPressured=false` 有 6 个窗，速率 28.12–105.45 Mbps，中位数 68.54 Mbps。30 秒后产生的 7 个读数另存，不计入中位数。
- 本机 SMB 连接读数为 46.38 Mbps，约为 HTTP 中位数的 68%。HTTP 两秒窗波动较大，两次起播分属同机同 Wi-Fi 的不同 App 会话，轨道和缓存条件未配平。当前可确认两笔首块排队占大半。现有结果不足以据此调整读取大小、在途并发或连接数。
- HTTP 30 秒取证图为黑屏，保留内部首帧和交付读数，显示验收未通过。普通「完成」控件未命中，恢复阶段返回普通首页，最终原生核 App、Runner、采集和 8153 转发均结束。08:04:24 按原生元素恢复「名称」「升序」，最终偏好读回 `devices.files.sort=name devices.files.sort.ascending=true`。两项原用默认值，现显式保存。HTTP 私有证据在 `pad/t3-http-read/`。

## 判定与接续

- 本批取得三项诊断读数。SMB 起播实画，SMB 续播、前后 15 秒和轨道配平未执行，HTTP 参照仅交付读数成立。播放器控件自动化在 SMB 选轨及 HTTP 普通退出失败，均保留快照。继续验证时先确保播放器控件显示与实际点击可核，再补齐同轨同缓存条件。
- T2 仍有公网播放准备 401 和路线缺项。T4 可用于试探系数的 `explore` 样本为 0，保持 3。T5 尚未开始。无产品代码、调参、NAS 配置或远端文件修改。原有 Reader 报告和路线复算脚本单测各 6 项通过。
