# 位图字幕作者坐标与三端新包回归

后续现场更新：iPhone18 已由[有线续签更新](2026-10-25-IPHONE18-WIRED-REFRESH.md)完成，TV 当前包和首屏修复见[根栏与间距](2026-10-25-TV-ROOT-SCROLL-AND-PAGE-SPACING.md)。下文“18未装”仅为此前批次现场。

核对：2026-10-25 07:15；[结构化结果](../../../testing/results/2026-10/2026-10-25-authored-bitmap-and-device-refresh.json)。私有证据文本指针 `/tmp/nastart-signing-resume-evidence`，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加原 dirty 保留。

## 接受实现与有限测试

- KS `SubtitleViewportGeometry.videoFrame` 提供未裁切 fit/fill 视频矩形；`imageRect` 对作者画布的 origin 和位图尺寸使用同一个变换，渲染最后才裁切。原 `videoRect` 仍返回可见视频交集，文字字幕原字号/边距规则保持。
- `SubtitlePart.imageUsesCanvasCoordinates` 区分作者定位位图与旧无定位图片；解码器标记作者坐标，画布缺失才回退视频自然尺寸。明确的 `(0,0)` 是有效作者位置，不能视为缺省。
- `SubtitleBitmapLayer` 直接观察字幕模型，独立用于移动 Greenfield 和 TV KS 字幕子树；两处原字幕流排除已定位位图，避免双层和固定底部重画。原父播放器焦点隔离保留。
- 13 项移动定向测试通过，包括横竖屏两种实际 SwiftUI 图层像素边界、零点、fill 裁切、旧底部图片、PGS 组合/清理；TV 35 逻辑＋2 无媒体播放器返回 UI 正式 exit 0；两端普通 Debug 构建和 TV Release compile-only 成功。不是完整媒体字幕、实际听音、帧时间或 Release 运行验收。

## 当前批安装与身份

570 移动/509 TV 输入；移动 30 个、TV 27 个 Mach-O 独立签名和哈希核对。iPhone13 06:21:53、新 Pad 06:21:58 保留数据安装同一移动正常 Debug 包；TV 06:23:12 保留数据安装正常 Debug 包。三台正常空环境/空参数原生首页实际看过。主 SHA 和时间见结果，产物只在私有目录。随后 TV 的导航修复会产生更新包，接续以当前交接指定的最终包为准。

13/Pad 新 profile 实际包含两台设备、至 10 月 31 日有效，纠正此前以为 13 必须复用临期 profile 的推断。iPhone18 本批无 USB、Xcode unavailable，新 profile 不含18；旧签名中国时间 06:23:57 已到期。18本批未安装，不拿24日23:57旧成功替代最新。已一次询问连接解锁，未重复催促、未改地址/配对/网络。

## 真机失败与边界

13 两次 S03/JF 单次“继续观看”输入均超时，第二次已分离点击与独立原生采集，3/10/30/45 秒仍是影片详情；没有本批真实电影截图。随后日志在约06:43:35～39出现迟到的 KS ready/first_frame，晚于采集窗口；不能断言没有播放，也不能用内部事件代替屏幕字幕。设备时钟约差0.1秒，不足以解释该延迟。保留两轮失败后停止相同条件试验。收集报告未发现本日 Nastart 崩溃；不据此排除全部崩溃可能。06:46原生正常首页、App state及 WDA 设置恢复核过；未知所有权的预存13 Runner没有启停。完整偏好对比仅诊断和自然续播变化，原轨道/登录/外观未改。

新 Pad 只准备到 S03 详情，0播放命令；07:09新USB列表已无Pad，原生重连报 RemotePairingError。自有有界 Runner 的主机进程不在，但设备端 Runner 和临时 WDA 设置最终复核受阻，不能写已核停/已恢复。下次识别后先核 Runner 与设置；不重装、清数据或改VPN绕过。13仍USB可用，Pad原网络/外观配置未改。

无蜂窝、NAS/VPN/网络设置改动，不启动并发媒体。28需求、114矩阵格不新增整格PASS。作者定位真实cue、移动输入延迟、TV真实字幕/退出及跨平台完整会话契约继续开放。
