# 重新连接后的双入口基线与 PiP 路线排查

日期：2026-10-20。用户已带 iPhone18 离家，仅对重新接回 Mac 的 iPhone13/iPad 操作。用户最新确认“画中画无字幕”只测过 Jellyfin，影片及发生设备未进一步确认，不扩大为设备文件同症。

## 包与执行条件

沿用本日06:48:25普通 Debug/-Onone/Xcode27包，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加未提交修改，iOS差异 `35df7015b08ee4d929683983de8ac59d2d7111f94615bf85f38894fc25ae66ed`。本批无产品源码修改/新构建。每台开始及切换前现场重读名称、UDID、型号、系统、USB连接，核当前173源码输入、三二进制哈希及已安装receipt；13为iPhone14,5/iOS16.3.1，Pad为iPad12,1/iPadOS18.3.1 Wi-Fi-only。默认空环境/空参数启动，没有注入限速或预测开关。安装身份详情承接[输出诊断](2026-10-20-CLIENT-OUTPUT-CORRELATION.md)，18成功交付见[USB安装](2026-10-20-IPHONE18-USB-INSTALL.md)。

私有证据指针 `/tmp/nastart-output-correlation-evidence`。包、完整路径/设备身份、源树/截图、原始偏好/日志只在仓库外私有目录；[结构化结果](../../../testing/results/2026-10/RECONNECTED-PIP-ROUTES-20261020.json)不带凭据或标识。

## S01 四个基础窗口

串行、各从头30秒，普通UI退出成功，外层finally再确保停App。实际抽帧均看到影片；不把以下内部时钟写作可见首帧。

| 设备/入口 | 内部推进秒 | 最大采样stall | 完成metrics蜂窝yes/no | 边界 |
| --- | --- | --- | --- | --- |
| 13/设备文件 | 1.357451 | 0 | 0/2 | 普通退出，非完整音字幕/性能验收 |
| 13/Jellyfin | 1.715566 | 0 | 0/2 | 同上 |
| Pad/设备文件 | 2.701961 | 1 | 0/2 | 保留stall，不标整项PASS |
| Pad/Jellyfin | 2.337096 | 0 | 0/2 | 同上 |

初次Pad误用同名批次目录，在播放前FileExistsError退出；独立Pad名称后才执行，原失败保留。抽样画面不能替代逐帧流畅、听音或完整字幕；四单元不关闭76单元及总账28项。

## Jellyfin S19 画中画：必须按实际路线分列

**13原流路径已复现本地HDR字幕缺失。** 普通包/空环境，LAN Range代理→KSPlayer，实际3840×2160、10-bit、PQ。约19.849秒请求PiP；系统PiP开始日志及实际桌面小窗已核。20.511秒无cue，25.545/30.558秒各有1张字幕位图，合成原因均`hdrPQPreserved`、`composited=false`、未尝试分配；对应PiP抽帧无字幕。可以定位这一窗口的缺失路径，但不自动回填用户iPhone18未观测路线。此次只做原流字幕审计，未尝试完整恢复闭环。

**Pad两个有效PiP窗口均实际回退为转码。** 初始KS原流随后因自动回退协商12Mbps H264/AAC、PGS8 Encode，最终由AVPlayer/PiP呈现。桌面小窗实见字幕，因此“PiP在任何路线都不显示字幕”不成立；不能用服务端烧录字幕的正常显示证明本地HDR字幕合成已正常。截图有不同位置/内容的cue，同一画面可能为排版字幕或切换残留，尚缺同时间轴对照，不直接认定重复层/旧cue。

Pad恢复全屏未验收：第一有效窗在读取完整辅助功能源树时超时；第二窗改为轻量SpringBoard源树，见系统PiP窗口，但原生点击后未暴露唯一恢复按钮。保留失败，停止猜测坐标/横竖屏比例补偿，不把输入未执行等同播放器恢复失败。所有窗口在外层finally停自有播放，不能记普通完整PiP关闭。

工具失败单列：13早期USB/WDA观测中断后独立停止App；Pad首次以画中画label匹配name失败，实标识为`pip.enter`，未进入PiP；另一次在开播前Runner连接拒绝，经日志核实是自有1800秒XCTest到期。之后仅复用已有有效签名Runner，600秒有界会话，无新安装，完成后主动停止。没有用重装/改视频参数掩盖工具失败。

## 当前源码与未交付设计

`GreenfieldKSPlayerRenderer.swift`的`makeOptions.pictureInPictureFrameTransform`在PiP按播放器时钟更新本地cue，并调用`GreenfieldPiPSubtitleCompositor`。现有合成器仅支持SDR：PQ/HLG命中保护分支直接返回nil，避免把HDR无声降为8-bit sRGB。此保护本批未删除。

`GreenfieldVideoPlayerView.swift`的`GreenfieldAVPlayerSurface`使用AVPlayerLayer/AVPictureInPictureController；服务端烧录已在视频像素中，App自己的SwiftUI字幕层不会自动进入系统PiP。当前两条路线必须分别验收，不能只看影片源HDR/字幕名称。

Mac离线合成原型仅用32×32合成画面：extended-linear BT.2020/RGBAh工作空间、10-bit420输出，分别PQ/HLG，sRGB白色叠层。未覆盖叠层位置的高亮线性值，PQ4.011203→4.011203、HLG3.997329→3.997329，转移标签/像素格式保持。只证明这个合成实验没有把该高亮压至SDR；不证明文字区域映射正确、真机可见、色彩完整、4K吞吐/内存、Dolby Vision元数据或发布可用。原型保留私有目录，未进入App，也未交付18。

实现前需补：源/目标色彩空间与位深匹配、文字参考亮度/alpha、尺寸/格式变更后的池重建及失败原帧回退、无cue零额外合成、上下文/像素池资源上限、seek/PiP代次隔离；DV动态元数据不能盲目全部复制而宣称保真。PQ/HLG/DV、SDR反例及文本/PGS/外置字幕都要实际输出验证。

用户另提PiP拖动进度：当前公开[AVPictureInPictureController](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller)与[自定义播放器采用PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player)没有供App在系统小窗插入自定义拖动条的接口；不承诺注入系统控件。保持系统跳转/恢复全屏拖动，App内小窗自定义进度另作可行范围评估，本批未实现，归入现有PiP需求，不另造编号。

## 收尾与下一步

本批全为原Wi-Fi，未切蜂窝或改NAS/VPN。13/Pad独立原生截图实际桌面无PiP且见Wi-Fi；非断点偏好保持、原轨道变化0、原断点未删除，测试自然推进各1条。13相对当日旧基线、Pad相对19日最终基线新增Nastart/WDA/Jetsam报告均0，不当作长期稳定性结论。自有Pad临时XCTest/保活已停，既有13持久WDA不动。

PiP HDR字幕、完整往返、大小/位置以及蜂窝首帧/seek均未关闭。蜂窝最高主线仍是首片准备/等头和后续供给；接着先做primer取消、续播/nonzero序号、Range忽略与身份隔离的本地反例，再决定是否做最小共用实现。不要再重复完整源树/猜测恢复按钮或已否定的AV等待实验。
