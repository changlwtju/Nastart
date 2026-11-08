# TV 方向键衔接与高清海报实证

核对日期：2026-10-25。[结构化结果](../../../testing/results/2026-10/2026-10-25-TV-DIRECTIONAL-SECTIONS-AND-HD-ARTWORK.json)。私有指针 `/tmp/nastart-focus-audit-evidence`；设备标识、实际端点、源快照、原始截图/包/报告/URL/偏好仅留该本机目录。需求关联[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)，28开放／114格保持。

## 用户报告、实现与范围

用户 IMG_2764 报告《蜘蛛侠：英雄归来》首演员Up不能回简介/海报，第二个可回。该旧包现象来自用户实拍，不写成自行受控复现。源码显示海报在左、动作在右，第一演员位于左海报下，空间方向寻找可能无目标；按 Apple 的[focusSection语义](https://developer.apple.com/documentation/swiftui/view/focussection%28%29/)和[官方焦点说明](https://developer.apple.com/videos/play/wwdc2021/10023/)，在有可聚焦后代的内容组上提供完整矩形衔接。

实际接受：TVViews.TVDetailView完整hero加focusSection、演员组占满可用宽并设section；TVMediaShelf同样覆盖短列表空白。媒体库右上搜索及分类组、搜索表单分组；TVNASViews首页刷新/服务管理、设备资源刷新、服务页刷新、事项新增/取消与底部保存的偏移区域也补衔接。未把静态海报新增为确认按钮，未写死演员索引/强制焦点或滚动居中。原TVMediaGrid阅读顺序跨行与nil anchor最小揭示保持，主Tab仅根页与逐层Menu规则保持。

静态盘点覆盖TVViews与TVNASViews的ScrollView、Lazy网格/横排、focusable/focused/onMoveCommand入口，区别连续整宽列表、偏移按钮、独立表单和播放面板。连续整宽的设备信息卡/文件行保留系统方向规则；网格既有显式跨行算法保持。不是给所有View无差别加section；全部模态/系统键盘/播放器动态控件尚需后续覆盖，不能称全局所有方向已验完。

## 测试与真机

DEBUG专用detail-focus夹具渲染真实TVDetailView，用独立URLSession/内存URLProtocol返回12人/7相似片，无NAS/媒体或用户偏好。新testCastEdgesMoveUpToHeroAndDownToRelatedShelf检查首演员Up、末演员Up及Down进相似影片。最终40逻辑＋6无媒体UI正式过；普通产品启动不带夹具参数，Release不进入此分支。

19:30:50普通Debug保留数据覆盖TV，510输入/27逐Mach-O签名；主SHA `9896b4c924dd3bd4858a08ed8808aa3d24821e101f70fa4c4255266f9d494404`，dylib `e02545bd664c58e7afd1db81d4b2191f3e4ebf49190343d8ef386c4189cfc69c`。构建时间、全部hash、profile目标/有效期、AppID/Keychain与正常空环境启动在私有包身份。HEAD4de732dd加原dirty；最终510输入无漂移。

用户本轮明确交出遥控器后，真实《变形金刚3》31次方向核对：第二演员Left到首位希亚·拉博夫，Up到继续播放；横移至第20人Kenny Bates后Up到从头播放；随后Down回演员为迈克尔·贝（不是保持最后一人，不误述为恢复原索引），Down到相似影片、Up回演员，再Up回动作。首位回顶部及相似区原生截图已看；普通返回电影墙/库/启动台。使用同布局影片，未再逐片复测原用户蜘蛛侠，亦非帧时间/整页零位移验收。

全局第二受控窗完成32个定位/进入/返回检查：四主Tab、设备资源/服务/容器/套件/文件/网络/维护入口，网络一次Back；事项类型/日期/空标题保存禁用/取消Back，未保存事项；我的外观定位/iCloud进入返回/帮助→遥控器说明→两级返回/连接管理定位；首页文件→排序→返回文件→返回首页。仅到达和层级验收，不把按钮看见当业务功能已验。

失败保留：首编译夹具字典三元表达式触发Swift诊断失败，改明确分支类型后构建成功；第一全局脚本尝试聚焦空标题下禁用Save而失败，判断为夹具错误，恢复设置并停Runner；随后相同普通包重新有界检查，先断言禁用、不触发保存，完成其余路径。无演员修复后的方向失败。最终首页截图已看（DSM处于读取中，不当稳定状态性能证据）。两次自有Runner均停止/临时设置GET核恢复，和上一批末偏好相比0变化；13/Pad/18本批0操作，无新蜂窝/播放/媒体下载。

## 海报新需求：抽样与可行性

[高清海报方案](../../../architecture/HIGH_RESOLUTION_MEDIA_ARTWORK.md)记录实证及分阶段设计，当前仅调研/可行性验证，尚未把自动高清替换接入三端。

按各库SortName前6项抽18条：16条有Primary，6幅宽500，另有高达2000×3000；2条无图。背景图也有1280×720至3840×2160差异，不能把样本当全库多数比例。模拟TV当前maxWidth=1000/quality=92只读图片请求，《白夜追凶》实收500×750（59,053 bytes），《奥本海默》实收1000×1500（528,461 bytes）。前者受原图限制，后者可从高清源正常缩放；并未证明App所有显示/缓存都无问题。

只读GetRemoteImageProviders确认现有TheMovieDb；一条GetRemoteImages请求1.924秒返回9候选（本轮取8条），有1200×1800中文及2000×3000等版本。外部原图URL仅使用普通图片请求、不转发Jellyfin凭据，实际下载451,406 bytes/2.593秒并解码确认1200×1800。没有POST DownloadRemoteImage、库刷新/插件/配置/NAS凭据改动。不是自动刮削已交付或影片下载；后台常驻未创建。

下一阶段：统一三端高清图选择/本地缓存和错误回退；先利用已识别TMDB身份与当前只读提供方，再考虑设备文件命名解析/匹配和独立数据源授权。未做外部账户注册、密钥获取或NAS图覆盖。原TV源音字幕目录/设备文件KS控件/弱蜂窝等仍保留开放。
