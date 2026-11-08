# Apple TV 配对记录与开发连接复核

2026-10-19 19:20。用户提供两张电视照片：遥控App与设备页列有这台MacBook；系统页没有可见Developer项。此证据支持电视保留Mac配对记录，后续不得笼统写“用户未配对”，也不能仅凭无Developer菜单要求升级。历史Xcode26.6 PairAction success/error nil仍有效，但不能作为可安装开发会话的证明。

[安全结果](../../../testing/results/2026-10/APPLE-TV-PAIR-RECORD-RECHECK-20261019.json)。原始照片/身份/地址/设备清单只留仓库外本批私有证据区，指针`/tmp/nastart-tv-current-evidence`。

## 本次现场

- 独立指定Xcode27/27A266a、26.6/17F113，各有界重新读取xcdevice：两者真实TV条目均0，模拟器不计；26.6实际Devices窗口同样没有电视。未新开配对或反复刷新。
- 对用户此前提供地址只做单目标只读访问，autopair=false，实时返回AppleTV14,1/tvOS18.2、设备名已私存，但匿名公开元数据未返回硬件UDID；只证明该地址当前有符合型号的电视服务可达，不等于完整身份/可用认证/安装会话。
- 系统Bonjour两类广播各仅观察5秒，旧电视remotepairing实例本窗未见；实例可变化，不能证明电视离线或全部发现机制失效。remotectl本窗清单未见TV关键词，同样不是电视配对记录不存在的证明。
- 结论为**电视有配对记录，Xcode开发接入尚未就绪，具体根因未定**。不能把遥控配对、认证成功、开发安装目标、有效tvOS签名包及实际安装混作同一阶段。原签名/profile缺口尚未在本轮重新向Apple注册或补签；没有发送电视安装。

## 后续边界

优先核Xcode/MobileDevice发现到已认证开发服务接管的断点，以及现有认证是否可复用；若可用真实目标出现，再现场核完整身份与tvOS签名/描述文件并安装。没有目标时不重复构建、不用模拟器顶替、不重试无交互认证/PIN/重启。用户此前不便重启Mac的回复保留，本次不再催促，也没有把Mac重启设为全部项目的前置条件；移动端已授权工作可独立继续。

Apple当前文档说明tvOS没有独立的Developer Mode开关，经Device Hub配对后出现Developer Settings；缺少菜单是状态线索，不能单独确定根因。[官方说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。官方旧版Xcode配对完成观察包括设备详情及网络图标，[配对流程](https://help.apple.com/xcode/mac/current/en.lproj/devbc48d1bad.html)与照片中的电视列表不是同一个观察边界。

本批无App源码/包变化、手机媒体/网络动作、服务重启、卸载/取消配对、系统/电视更新或NAS/VPN改动。保留所有其他未提交修改，28项既有需求状态不变。

收尾：333文档/1667本地链接缺失0，`git diff --check`通过；本批有界发现与只读任务均已结束。
