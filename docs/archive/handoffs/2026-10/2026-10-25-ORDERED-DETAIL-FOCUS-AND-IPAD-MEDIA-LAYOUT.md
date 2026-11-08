# 详情页方向键完整闭环与 iPad 媒体布局

> 后续用户复核未通过：首 Down 仍先闪第二演员再回第一；相似片 Down 应总从首片进入，旧“恢复上次相似片”预期已被明确修正。以下通过记录只证明旧规则的最终落点，不证明无瞬态错误或新规则完成。见[分支总交接](2026-10-25-SESSION-WRAP-UP-AND-NEXT-STEPS.md)。

核对日期：2026-10-25。[结构化结果](../../../testing/results/2026-10/2026-10-25-ORDERED-DETAIL-FOCUS-AND-IPAD-MEDIA-LAYOUT.json)。私有指针 `/tmp/nastart-detail-chain-evidence`；最后TV导航在runtime-corrected-order，移动最终为mobile-layout-final/intent-candidate，初版mobile仅历史失败证据。原始设备身份/地址/凭据/截图/包/报告均留仓库外。

## 修正上一批验收遗漏

用户指出播放操作Down会到第二演员，要求逐键完成“播放→演员左右→相似影片左右→演员左右→播放”的整个往返。上一批只有跨区可达/演员边界，没有验证精确入口与记忆；旧测试用Left补到第一演员，不能继续称其覆盖完整顺序。

新testOrderedDetailFocusRoundTrip使用真实TVDetailView和原有DEBUG内存夹具，每个方向键都断言具体ID，不补救、不接受任一同区节点。旧源首Down→cast-0失败，整条35断言失败包含连锁及旧版缺similar ID，不能推断35个独立产品故障。原失败保留。

## 实际接受的 TV 规则

TVViews.TVDetailView统一拥有focusedDetail/requestedDetailFocus、lastActionFocus/lastPersonFocus/lastSimilarFocus。播放/从头/简介等动作Down从首演员进入，无演员时可进相似片；演员Up回最后使用的动作，Down进上次相似片或初始首片；相似片Up回原演员，无演员则回动作。横排Left/Right只移动一项，首尾停止。TVPersonCard的高亮使用同一FocusState绑定，TVMediaShelf仅详情上下文启用显式焦点，首页普通列表保留原规则；原电影/季/集二维跨行模型不改。

懒加载滚动使用ForEach真实ID，目标未呈现时先scrollTo原ID，并在onAppear后提交焦点；异步提交检查请求仍匹配，避免旧请求抢焦点。行选择只记请求确认的目标及发出方向键的源，不能让系统短暂空间落点覆盖原选择。竖向只nil anchor揭示相邻区域，不强制中心。

候选失败保留：第一版走完大部分后，从演员末端回hero再Down仍无法实现cast-0，原因是滚动定位使用未呈现子节点ID；第二版related Up时系统中间落在cast-9，被无条件onChange当成记忆覆盖cast-11。分别修正懒列表真实身份/呈现提交和确认后的记忆更新，未靠调超时、居中或延迟常量绕过。最终40逻辑＋7无媒体UI正式通过，含完整严格顺序与原返回/面板/边界回归。

## 真机完整顺序

普通最新包真实《变形金刚3》44步逐键核对：play Down首演员→Right第二→Right第三→Left第二→Down第一相似片→Right第二→Right第三→Left第二→Up原第二演员→Right第三→Left第二→Up原play；Right到restart→Down仍首演员；Left首位不越界，逐项Right至第20人及右边界；Down回原第二相似片→Right第三→Left第二→Up原第20人→Left第19人→Up原restart→Down回首演员→Up原restart→Left play。普通Menu返回墙/库/启动台，没有触发播放。

相似片以App当轮已显示前三张为唯一顺序依据，不重新请求服务器来猜顺序。首真机脚本额外调用Similar后服务器给了不同顺序/内容，误报第五步失败；保存错夹具并停止Runner/恢复设置，相同普通包重开受控窗改按App真实顺序后44步通过。实际前三张均精确断言；完整7张相似片首尾边界由内存UI夹具覆盖，不把真实仅前三张扩张成全库验收。

记录的34次水平操作，演员/相似片水平操作稳定同行Y；一次play→restart同窗观测其他行+68点，可能含前一步揭示的收尾，未定因果，不宣称全部水平动作整页零位移或帧时间流畅。首演员Down及最后回首截图已看。没有把局部闭环当全局所有动态控件/键盘/长简介、无演员/无相似等组合验收完成。

## 移动端新增布局

用户三张iPad图：hero受400高上限约束，旋转后仍窄；overlay按更宽父容器放圆点；132自适应等宽格迫使技术参数/日期断行。

LaunchpadView.JellyfinHomeView根据实际可用viewport判断横竖，内容最大宽从960到1400；JellyfinHeroCarousel用同一GeometryReader显式固定图片/TabView/圆点画布，竖16:9、横21:9，圆点在clip以内。JellyfinHeroSlide内部图片也固定画布并clip，避免aspect-fill放大ZStack导致标题/时长/播放提示溢出。图片按点宽×displayScale请求880–2400像素/quality94，沿原imageTag及缓存，不代表独立高清刮削已上线。

JellyfinMetadataStrip改JellyfinMetadataFlow自然宽度布局，移除Fact强制扩展。常规字号一项完整单行，行不足将整项换下一行；极大辅助字号可用整行高度，不以硬缩字塞入132格。共享NastartMediaFact样式/字段格式保持。只有移动UI尺寸/布局与TV焦点改变，播放选流/解码/Range/缓冲/音字幕协商不改。

## 逐机结果、失败与收尾

最终普通Debug、HEAD4de732dd加原dirty：TV510输入/27签名，20:07:31主SHA `ee6fac1c5dd34e85676f28961b6a295ce38456ba7398091fb76bd8beea0bf364` 保留数据安装。移动570输入/30签名的最终包与逐机时间/主及dylibSHA见JSON；13 iPhone14,5/iOS16.3.1与Pad iPad15,7/iPadOS26.6现场核身份、USB保留数据覆盖，profile/AppID/Keychain保持，普通空环境启动；18本批不在场/0操作。

Pad最终hero竖788×444、横1148×492，均16点侧边距；横屏轮播一周期前后位置相同，圆点98×22在画布内，标题/时长/播放提示已实际看完整。爱情神话的1080p/H.265、E-AC3/5.1与日期三项在竖屏y502/高19同排，横屏亦高19且同排。最终原生横竖图已看，普通返回首页、原Portrait恢复。

13最终hero358×202，iOS16隐藏圆点AX矩形0，首断言因此失败，不能当实际圆点越界；最终原生截图已看圆点在图内。流浪地球2各技术项高19完整单行，窄屏日期整项换到下一排；继续/从头同排、普通返回首页。原未知13 Runner及其设置不动。

移动初版曾在实图发现横屏字幕标题裁切，虽尺寸与dot矩形检查过，仍不接受为最终视觉通过；修内部画布、重新冻结与逐机安装后实图全看。初轮Pad负y的滚动位置图不是全可见hero证据；最终新普通入口检查三张均y213并在viewport内。保留旧图及phone AX断言失败。

Pad启动自有Runner前检测已有未知Runner而中止，未杀它；WDA ready且无HTTP session，后续仅创建并删除本轮HTTP session，不更改global settings，不取得Runner进程所有权。两轮Pad布局检查后原方向/设置保持，已有Runner保留；TV两轮自有Runner均停/设置恢复。最终源510/570及冻结全部二进制0漂移，TV偏好与上一批末0变化，移动仅诊断自然变化。实际Wi-Fi图标/Pad原VPN已看，无网络开关/NAS/凭据/插件修改，0媒体播放/蜂窝，非全播放/Release/帧时间矩阵验收。

## 后续边界

用户两条新报告本批具体顺序/横竖布局已验；仍继续既有全局未覆盖组合、高清海报补全、源音字幕目录和设备文件稳定KSUI。原28开放／114格保持，评分独立来源/设备文件跨设备续播、原弱蜂窝等待与18安装暂停不因本批关闭。高清来源可行性沿[方案](../../../architecture/HIGH_RESOLUTION_MEDIA_ARTWORK.md)，当前只是更合理的现有图片请求，未自动下载提供方替换海报。
