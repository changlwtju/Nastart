# Dolby Vision / Dolby Atmos 播放路线

日期：2026-09-10 更新。状态：已开始能力识别与原画路由建设，尚未完成实际杜比输出验收。

遵循 [ADR 0002](../adr/0002-single-playback-optimization-mainline.md)：只建设 Greenfield 新架构，KS 原流优先，AVPlayer 是其兼容分支；当前仅使用局域网媒体测试。

## 目标与阶段

1. **能力识别**：记录视频 DV profile、level、兼容基础层及封装，音轨区分普通 E-AC-3、E-AC-3 JOC、TrueHD Atmos。缺失元数据标为未知，不根据文件名或多声道数量推断 Atmos。
2. **原流路由**：对设备与系统支持的 DV / E-AC-3 JOC 组合验证 AVPlayer 原流播放或保留元数据的重封装；复用现有认证与播放控件。不要把 AAC 转码或普通 PCM 解码标为 Atmos。
3. **兼容回退**：不兼容 profile、封装或输出设备时提供可播放的 HDR/SDR、多声道/立体声回退，并区分片源规格与实际输出。TrueHD Atmos、DV Profile 7 增强层单独研究，不预先承诺无损支持。
4. **验收后开放**：通过下面矩阵后再宣称对应组合受支持；不得以“能出画面、有声音”作为杜比效果通过的证据。

## 验收矩阵

| 维度 | 覆盖与证据 |
| --- | --- |
| 视频 | DV P5、P8 兼容基础层、P7 独立样本，HDR10/SDR 对照；记录容器、实际渲染路径、色彩表现与元数据保留情况 |
| 音频 | 普通 DD+ 对照、已确认的 E-AC-3 JOC、TrueHD Atmos；记录系统音频路由及可用的空间音频输出证据 |
| 设备 | iPhone/iPad 的不同系统与硬件；扬声器、支持的耳机及可用外部设备分别验证，不能互相替代 |
| 播放 | 首帧、连续播放、暂停恢复、前后 seek、音字幕切换、退出续播及音画同步 |
| 传输 | 局域网原流与必要重封装，确认无意外 AAC 转码或丢失 DV 元数据 |

当前 NAS《繁花》样本为 DV Profile 5，但音轨为普通 DD+ 双声道/AAC，不能充当 Atmos 验收样本。现有 KSPlayer 音频解码至 PCM 的链路尚未证明保留 Atmos 对象信息。后续需补充有明确来源及规格的局域网样本。

## 官方参考

- [Apple HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/)
- [Apple：Incorporating HDR video with Dolby Vision into your apps](https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf)
- [Apple HLS examples](https://developer.apple.com/streaming/examples/)（参考格式信息，当前不通过公网播放样本）

## 实施时机与标识（2026-09-08）

本轮先完成清晰度交接、PiP 生命周期与电视剧上下集回归；其后开展原生杜比输出分支。片源能力识别可先行，但将“片源含 DV/Atmos”与“本次输出已启用”分为不同状态。播放页杜比标识仅在对应运行链路获得充分证据后点亮，元数据标签、普通 E-AC-3 或 HEVC 不作为点亮条件。排期以验收门槛为准，不以固定日期代替验证。

## 与原画链路同步实施（2026-09-10）

用户授权在设备文件/Jellyfin 原画链路统一时同步考虑 Dolby Vision / Atmos。当前提交范围：

- Jellyfin 自动原画与显式原画均查询实际 KSPlayer 音频解码器，不因 VLC 的 TrueHD 限制或系统播放器的 iPad FLAC 限制换轨/转码。`eac3-joc` 映射至 E-AC-3 解码器；DTS-HD 的服务端名称映射至 DCA 解码器。只表示可尝试解码声音，不表示保留对象音频。
- Jellyfin 保留视频 `DvProfile`、`DvLevel`、`DvBlSignalCompatibilityId` 以及音轨结构化 `Profile` / `AudioSpatialFormat`；诊断区分 E-AC-3 JOC、明确标注 Atmos 的 TrueHD、Atmos 信息未知的 TrueHD/普通 E-AC-3。禁止从片名、轨道标题或声道数推断。
- 共用 KSPlayer 渲染器从实际轨道读取 DV 配置、增强层存在标记和位深，记录设备 HDR 资格与当时音频输出端口。设备文件入口因此也有实际轨道证据。HDR 资格和轨道配置都不是屏幕 Dolby Vision 输出证明。
- `source_capabilities` / Jellyfin `sourceCapabilities` 诊断中的 `dolbyVisionOutput`、`dolbyAtmosOutput` 均保持 `unverified`。KS 路径注明 `decodedPCM`，源信息与当前输出分开，不点亮产品杜比标识。

后续按以下两条路径验证，继续共用现有控件、认证、字幕和清晰度交接：

1. **视频**：先验证现有 KSPlayer → VideoToolbox → 显示层链路的 10-bit 像素与逐帧 DV 元数据。现有代码已经设置 `PropagatePerFrameHDRDisplayMetadata=true`，但仍需检查不同 Profile 的格式描述、显示路径与实际色彩。AVPlayer 对兼容的 DV 8.4 媒体是官方可用参考分支；不能把该结论外推至 P5、P7、P8.1 或所有 iOS 版本。
2. **音频**：优先为确认的 E-AC-3 JOC 研究保留压缩音轨的系统播放/兼容重封装分支，并按耳机、扬声器、AirPlay/外接设备分别验证。现有 HLS 兼容转码可能输出 AAC，现有 KS 解码输出 PCM，两者都不自动成为 Atmos 输出。TrueHD Atmos 对象信息和 P7 增强层处理仍为独立未验证项目。

本轮模拟器测试覆盖识别与路由边界、真实音视频交接和 Range 传输，不替代杜比显示/听音验收。优先验证现有 iPhone/iPad；具体耳机或外接输出设备按用户反馈补充。

依据：Apple 的 [Dolby Vision 应用指南](https://developer.apple.com/av-foundation/Incorporating-HDR-video-with-Dolby-Vision-into-your-apps.pdf) 明确了 DV 8.4 的 AVPlayer/显示层播放与元数据条件；[HLS 格式要求](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/) 与 [官方样本](https://developer.apple.com/streaming/examples/) 用于核对 DV/JOC 封装和系统分支，不把文档支持等同于当前安装包已通过验收。
