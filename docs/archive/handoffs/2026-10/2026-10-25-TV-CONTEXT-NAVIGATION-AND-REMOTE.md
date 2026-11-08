# TV 层级、详情与遥控器适配

核对：2026-10-25T15:42:28.606186+08:00。[安全结果](../../../testing/results/2026-10/2026-10-25-tv-context-navigation-and-remote.json)。原dirty保留；私有文本指针 `/tmp/nastart-tv-context-evidence`，其中timeline-fix是最终TV、mobile-final是最终移动包，actual-play-followup补实播。没有NAS/VPN/插件/凭据修改，本批0蜂窝媒体。28开放／114格不关闭。

## 用户约束与接受实现

三端共用功能、信息层级、设计语言；TV按遥控器量身适配，不能照搬触屏控件。全局Tab只出现在四个主页面，Jellyfin/设备/设置子页归自身导航层级。

| 范围 | 实际接线/行为 | 验证边界 |
| --- | --- | --- |
| 主导航 | TVHomeView→TVRootNavigationShell，每个Tab保留独立NavigationStack；观察真实root onAppear/onDisappear。view-based NavigationLink不依赖NavigationPath计数。Tab栏保持mounted、子页高度0/不可点击/不可访问，避免重建夺焦点 | 新无网络两层UI夹具；实际库/搜索/详情/播放器→逐级返回→首页、帮助/网络一次返回；原入口卡焦点实图恢复 |
| 设置 | TVSettingsView移除自身重复NavigationStack，由共同shell拥有 | 我的→帮助→我的、设备→网络→设备实际同进程 |
| 简介 | TVOverviewLayout用23pt UIFont、实际文本宽测量，超过约7行才折叠到4行，节省至少3行；短文完整，无多余展开按钮；hero固定最小580，不因展开强行700 | 宽/窄/长/短/宽0逻辑；蜘蛛侠3约4行全显实图。无真实超长片源的全呈现验收 |
| 演职人员 | TVPersonCard保留头像/姓名/角色与横向焦点浏览，移除只有单薄简介的TVPersonView跳转；按确定留在影片 | 真机焦点及Select留原详情；未来有实际作品列表再考虑子页 |
| 重播 | 三端PlaybackControlDesign.restartSymbol=arrow.counterclockwise；只改“从头播放”，上一集图标不改 | 三端普通编译/安装；TV实际详情图标，移动本批仅正常首页 |
| JF播放控件 | TVNativePlayer顶端保留标题/更多，去X/静音；Back先面板再播放，Play/Pause键保留。音轨面板保留静音备用，不假装收到系统硬件静音事件 | 真机S01画面/暂停三角，音轨菜单备用、单次Menu两级退出；不包含TV文件KS全部控件 |
| 进度焦点 | TVPlaybackTimeline自绘轨道/滑块，聚焦稍加粗/圆点强调；label-only ButtonStyle抑制默认tvOS整片底色；没有黄色外框 | S01实际画面上焦点图已看；不以内部时钟判全流畅 |

固定TVAVVideoSurface/AVPlayerLayer、字幕视频矩形不变；未改解码、选流、20Mbps H2641080协商、Range、缓冲或40秒预算。完整播放Intent/Plan/Route仍有三端独立边界，没有因共享图标就宣称全链路统一。

## 豆瓣评分

可做三端共用来源明确的评分展示，但本批没有确认当前服务器/NFO提供显式豆瓣评分。Jellyfin官方BaseItemDto将CommunityRating、ProviderIds、ExternalUrls分开；仅有通用评分或Douban影片ID，不证明该数值来自豆瓣。当前保留通用星级，不造“豆瓣”徽章、不替换NAS插件或发起刮削。后续先核可验证评分来源及影片匹配，再接共享模型。依据：[Jellyfin DTO](https://raw.githubusercontent.com/jellyfin/jellyfin/master/MediaBrowser.Model/Dto/BaseItemDto.cs)。[Apple遥控器说明](https://support.apple.com/zh-cn/102337)说明静音键受音频配置影响，保留App备用项有实际价值。

## 包身份与设备

HEAD4de732dd加未提交修改。所有包普通Debug、空环境/参数；逐次现场身份、保留数据覆盖、签名/profile/AppID/Keychain和全MachO核对，未卸载。

- TV AppleTV14,1 /18.2无线：510输入/27签名，最终安装2026-10-25T15:28:34.205239+08:00，主SHA `bf141166fc9c5356a0c14f80e741ac29f7528f5fe050efd4521de34cc4239ca9`。最终source0漂移、原10偏好不变。
- 13 iPhone14,5 /16.3.1 USB：570输入/30签名，最终安装2026-10-25T15:37:02.379055+08:00，主SHA `0b4f66d49a3f9008b320ba716b49f0c01a0b5d4737e739557f52a847dbd08e75`。Pad iPad15,7 /26.6 USB同包，安装2026-10-25T15:37:28.381818+08:00；两机安装全偏好0变化，正常首页实看，最终只诊断自然变化。Wi-Fi图标实看，Pad原VPN保持；未知13 Runner未改。iPhone18外出暂停。
- 第一移动批后TV专属样式改动使全仓570快照出现1项TV漂移；保留失败，再构建/冻结/逐台覆盖最终包，最终570/510均0漂移。没有把旧快照直接改名最新。

## 测试、真实失败与收尾

最终38逻辑＋5严格无网络UI正常通过（不是媒体全矩阵）。首个新导航夹具按钮很窄、位于当前Tab垂直焦点投影之外，8次Down未命中，4条断言失败；只改夹具目标宽度，重新正式通过。真实导航另外验证。

首个plain进度样式在TV实图出现大片灰白焦点底，最终自绘label-only已去除。首个蜘蛛侠3真片窗已出画，但音轨Menu后立即断言仍面板、App debug trace没有back；DVT截图“已截屏”通知同窗可见。按失败保留并主动kill自有媒体、恢复设置、停Runner。不能把截图通知推断写成已证唯一根因；最终改用XCUIScreen截图并等待动作落地，单次返回通过。

最终蜘蛛侠3 3/10秒及进度图仍“正在准备播放”，仅作UI/导航通过，不算播放成功。随后同最终包S01独立短窗3秒图及焦点图均实际电影/字幕可见，遥控器暂停后播放三角；一次Menu回详情，继续回搜索/库/首页，同PID、媒体普通停止。未听音、未全轨切换或验完整字幕/HDR/帧时间。

三次自有Runner均停止、设置GET恢复；13/Pad本批无新Runner、无新媒体。原手机蜂窝阶段已恢复原网，本批没有切Wi-Fi。旧KS长等待/18持续几KB、全音字幕/格式族/长时/并发/PiP仍开放。

## 触屏与遥控器的鉴别清单（源码核对，非全部真机验收）

| 交互/信息 | 移动端 | TV判断 |
| --- | --- | --- |
| 关闭视频/返回层级 | 触屏X或返回手势 | JF顶X移除，Back先菜单后播放器，再逐层回父页；KS文件现有遥控器返回保留 |
| 播放暂停 | 触屏按钮 | 硬件Play/Pause优先，屏幕按钮保留可发现性/状态反馈；S01实际暂停已看 |
| 快进回退 | 按钮/拖动时间线 | 方向键与15秒语义；焦点圆点/轨道代替触屏拖动的外框，本批未重做所有seek性能 |
| 静音音量 | App屏幕静音/音量交互 | 硬件控制优先，JF音轨菜单保留备用；KS文件当前仍有独立静音按钮，待统一收纳，不谎称已删除 |
| 播放速度/音轨/字幕/比例/信息 | 触屏菜单 | 属于实际播放功能，TV保留为可聚焦菜单；不因TV无触屏删除功能 |
| 触摸亮度、拖拽与悬停快捷键 | 移动/桌面平台手势代码 | 不强移到TV。KS源码已有tvOS onMoveCommand与非tvOS hover/drop分支，继续按平台分支核对 |
| PiP/投放 | 按平台能力提供 | 不仅凭“无触屏”删除；TV文件KS仍有对应入口，需单独核实际平台/设备能力，不写成已验 |
| 演职人员点击 | 移动独立内容页可按其内容保留 | TV当前没有实际作品集合，先只浏览；未来有有价值内容再开放跳转 |
| 主Tab/子页面 | 移动触屏有其主导航习惯 | TV子页避免主Tab焦点越层；实际返回原库/卡片，根页才开放Tab切换 |

后续仍需TV文件KS播放器完整控制、所有深层/弹窗取消及长简介真实样本；本清单明确已做和待验，不能当通盘真机完成。
