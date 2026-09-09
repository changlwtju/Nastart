# Dolby Vision / Dolby Atmos 播放路线

日期：2026-09-07。状态：已列入后续优化，尚未完成实际输出验收。

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
