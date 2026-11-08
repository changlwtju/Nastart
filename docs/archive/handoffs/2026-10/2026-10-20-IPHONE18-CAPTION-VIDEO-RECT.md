# iPhone 18竖屏字幕锚点修复与HDR PiP缺字幕确认

2026-10-20用户在已更新21:39包上提供两张真实截图：竖屏电影居中、字幕却落在整屏底端；系统PiP电影存在但没有字幕。原图路径、哈希及原始偏好只留本机私有指针`/tmp/nastart-iphone18-caption-layout-evidence`；本批不把用户截图当自动化帧时间/听音证据。

## 变更卡

关联PX-20字幕呈现与PX-06/07 PiP。根因之一已从源码确认：SharedBuiltInPlayerView的外置文字与GreenfieldSubtitleOverlay的内置文本/位图均按整屏VStack底端定位，未采用实际fit视频矩形；原“screen-edge”位图测试也在固定错误预期。此前画面下黑边可放字幕，不等于竖屏应贴手机最底部；用户最新反馈优先。

本次共用修改：PlaybackSubtitleViewportPolicy按实时视频尺寸、视口及fit/fill求可见视频矩形；PlaybackSubtitleViewport把字幕限定到该矩形底部，safe-area仅在视频实际触及屏幕底边时补足。内置文本/位图和外置文字共用，位图保留自身canvas比例；KS在实际naturalSize变化时发布尺寸，AV在presentationSize/clock更新时发布，旧VLC回退也供自身videoSize。未知/无效尺寸不绘制错位字幕，尚未拿到正确几何不回退贴屏底；不改变音视频传输、播放状态或HDR策略。

## 当前实际验证与失败

4项最终XCTest全部通过且Xcode正常退出：fit/fill/横竖屏/非法尺寸、安全边界；实际SwiftUI外置文字像素；原生解码位图在390×844、844×390与1024×768的像素位置；自身canvas缩放。导出并实际查看竖屏文字/位图ImageRenderer附件，字幕均在居中视频范围附近而非屏底。只是合成渲染/几何L0，不能代替真机电影、双入口或完整字幕矩阵。

首轮测试编译遇到CGFloat.nan字面量歧义，已显式类型修复；下一轮4项中3项通过、midX精确比较422.00000000000006与422失败，改有意义浮点容差。该失败轮测试收尾未退出，精确停止自有xcodebuild，失败和日志全部保留；最终不同源码4/4且正常TEST SUCCEEDED，不挪用此前PiP14项两轮收尾挂起为通过。

23:03:59.403640+08:00普通Debug/-Onone/Xcode27新包一次真机构建成功。当前HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加既有dirty，iOS diff `7f60418a8418bcfcc1043983a8f5b228a47f4e9555ee8307f475d76760c2f629`。173输入、29库逐一/整体签名、profile/目标授权、三二进制、IPA CRC/无AppleDouble及链接重核；实际路径私存。

| 产物 | SHA-256 |
| --- | --- |
| Nastart | `03b2b47c9459a1e8f90ce57d1717da29b278a4c9f64cc065a5545d25ac0cca71` |
| Nastart.debug.dylib | `d633fe2ddc6cc62e976a603a188f22d11069f2e095be5b0bd66212d0dccc0fd4` |
| Frameworks/KSPlayer.framework/KSPlayer | `24e61e5112ba5ee6c30a78fc37fb4d5a05af3988fd19a714848b575a11a4b497` |
| IPA | `417c3e5bcabd66658db5efb958db88cdeaed48657eb87244ba4a478925a8c900` |

## 设备安装

18通过系统DNS-SD重新解析、既有配对及实时身份核实为iPhone19,7/iOS27.0、Wi-Fi、USB不存在。23:06:10+08:00保留数据覆盖Complete/lookup；明确environment={}、arguments=[]正常启动，实际PNG看到启动台/NAS正常、播放器关闭及Wi-Fi。安装后和启动后25项非诊断偏好含完整书签均逐值不变。没有卸载、清登录、重配对或改VPN/网络，未重复安装同包。18新包实际字幕电影操作尚未回归；用户原两张失败图属于21:39旧包，不回填为23:03新包失败/通过。

13准备新包时发现/status未含sessionId，闸门在安装前停止；不是WDA未安装。随后按已有wda_capture创建明确SpringBoard session并恢复临时设置后接续，23:08单次保留数据覆盖成功，实际空环境正常首页/NAS正常，24项非断点偏好、36原书签轨道与完整书签不变，新增App/WDA/Jetsam均0。设置session收尾响应超时保留，未重发；独立原生确认自有App已无进程，实际设置原网络名称/Wi-Fi与回原桌面图均已核。新包电影字幕仍未回归。Pad仍16:16旧App，未假称新包覆盖。

## HDR PiP缺字幕已实证，尚未修复

不启动App、不点击/下载媒体地读取18当前用户测试偏好，当前KSPlayer、3840×2160、像素格式2016686640、SMPTE_ST_2084_PQ、外置文字。实际有cue时textLength31/57、imageCount0，但composited=false/`hdrPQPreserved`；无cue另记`noCue`。所以这次确有已解析文字被HDR保护分支跳过，不能再用“字幕尚未选中/仅WDA控件问题”解释。截图及当前诊断不证明具体DV profile、真实动态元数据inventory、音画或全局资源预算。

本批只修全屏几何，保留PQ/HLG保护；不宣称HDR PiP字幕已经可用。下一步继续现有[HDR接线约束](../../../development/HDR-PIP-COMPOSITION-CONTRACT.md)的实际iOS帧上下文/动态与静态元数据策略、修改像素有效性和跨代次资源寿命，达到门槛后再接合成；不盲删保护、不把Mac原型当iPhone交付。当前事实已写入技术路线/开发状态/唯一总账/矩阵，28项开放不变。
