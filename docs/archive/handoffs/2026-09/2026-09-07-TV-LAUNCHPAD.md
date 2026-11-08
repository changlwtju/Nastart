# 2026-09-07 电视剧、字幕与服务识别

## 用户本轮要求

- Jellyfin 媒体资源库《天才女友》播放自动横屏、双击暂停、字幕位置、退出详情恢复竖屏。
- 服务图标统一黄色主题；Homepage、MetaCubeXD 重复卡片从识别逻辑解决。
- 字幕大小位置统一、透明背景；电视剧矩阵按大体积、编码/HDR/音字幕选代表样本。
- 询问 Dolby Vision / Atmos 支持路径。LAN only，ADR0002，新架构视频主线。
- 前批音频和 ISO 修复已提交并推送 main f0d7f7f；本轮改动另行提交推送。

## 根因与修改

- 实际 NAS 快照两个 Homepage 分别为 gethomepage/homepage（3000）和 tecnativa/docker-socket-proxy（无发布端口）；后者因容器名称被错误当作网页前端并猜测出相同地址。
- 两个 MetaCubeXD 分别为 metacubex/metacubexd（9097）和 metacubex/mihomo（9090）。旧规则将 mihomo/clash 也命名 MetaCubeXD。
- 优先镜像产品身份，分离核心 API 与网页前端；基础容器不做网页端点猜测；缓存可见性按镜像重新分类，用户明确显示覆盖仍保留。
- 首页在可见候选中按规范化真实 URL 去重，保留不同端口/路径/协议以及未知地址记录。监测清单保留全部容器。相同产品名不再作为合并依据。
- ServiceIconView 全部使用 AppTheme.accent，状态颜色继续表达健康信息。
- 三个 Greenfield 播放入口先 prepareForPresentation，fullScreenCover 的 onDismiss 再次恢复 portrait，避免消失回调早于模态转场完成。KS 底层 surface 不接收手势，共用播放器控件处理单双击。
- 外挂字幕与 KS 内嵌文本共用 PlaybackSubtitleText（20pt medium、白色轻描边、无背景）；底部位置统一。PGS 位图按视频原始尺寸缩放，不能无损重新排字；HLS AVPlayer textStyleRules 透明背景，大小按视频高度比例设置。

## 证据与边界

- build-tv-launchpad.log 构建与 preflight/linkage 通过并安装。
- 《天才女友》S1E1（Jellyfin 服务端标题，2026 国产剧）由竖屏详情进入横屏，截图 tv01-start.png；双击暂停 31:56，3 秒后仍 31:56，再双击恢复 32:00。新架构，H.265/AAC，49:15 时长。
- 字幕选择列表包含 Simplified/Traditional Chinese 与 English SRT；截图 tv01-subtitle.png 中左侧竖排字为片源画面内容，不能据此推断外挂字幕位置正常。最终统一样式验证见下方补充。
- 早期退出取证已回启动台，未计为通过；最终有效取证见下方补充。
- 服务端点实际 Swift 方法提取测试通过：同地址大小写/默认端口合并，不同端口、路径、协议和无地址保留。证据 service-identity-tests.swift/log。
- 只读查询 NAS 3,247 个 Episode；样本表已加入 PLAYBACK-FUNCTION-MATRIX.md，含 9.35GB/24.8Mbps 白夜追凶、DV P5 繁花、HDR10+ 黑袍纠察队、PGS/SRT/ASS 绝命毒师与 H.264 对照组。元数据选样不等于实播验证。
- build-tv-subtitle-final.log 成功；最终安装 install-tv-subtitle-final.log，后续视觉证据另记。

## Dolby 边界

当前 KSPlayer 音频 FFmpeg 解码至 PCM/AudioUnit，不能宣称保留 Atmos 对象元数据。杜比视界需要检查 profile、RPU/增强层、封装和系统/设备实际渲染支持；普通 HEVC/HDR 能出画面不代表 Dolby Vision。可用的 DV 与 EAC3-JOC 应在新架构中协商保留原流的 AVPlayer 路由；不要将统一 AAC 转码分支当作 Atmos。TrueHD Atmos 不承诺用普通 FFmpeg 转码保留。

《繁花》样本元数据：DV Profile 5 / level 7 / compatibility 0；4 条音轨为普通 EAC3 双声道和 AAC 双声道，AudioSpatialFormat=None。可测 DV 和音轨切换，不能当 Atmos 样本。尚未执行原生 Dolby 输出能力验收。

参考：Apple HLS authoring specification、Apple Incorporating HDR video with Dolby Vision into your apps、Apple HLS examples（仅文档查阅，媒体测试未访问公网）：
- https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/
- https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf
- https://developer.apple.com/streaming/examples/

## 最终真机补充

- S1E1 `tv-subtitle-cue-2.png` 取得实际中文字幕“叫作独坐敬亭山”，位于底部中央，白字轻描边无底板；不再以片源竖排字作为字幕证据。
- 退出操作后 `tv01-exit-final.png/xml` 为竖屏《天才女友》详情，方向恢复通过；退出返回了剧集页，并非保留单集详情层级，导航层级另行回归。
- 最终基础容器端点跳过逻辑构建 build-final-identity.log 成功。最终安装 install-final-identity.log；此改动仅避免无意义后台容器网络探测，不重复播放器矩阵。
- 大文件样本均已列入矩阵，当前尚未逐个实播，不能宣称全部电视剧、HDR 或 Dolby 验收通过。

- 最终安装成功；正常入口启动台完整 UI 树 `launchpad-network-final.xml` 中 Homepage、MetaCubeXD 各 1 个按钮，网络分组数量 1；实际首屏截图确认主题色一致。NAS 与服务重新探测后显示在线/警告，不将未知缓存直接标成在线。
