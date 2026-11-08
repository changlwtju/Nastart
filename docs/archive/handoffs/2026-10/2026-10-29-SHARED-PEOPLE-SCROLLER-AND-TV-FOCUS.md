# 共用人物横向容器与电视焦点入口

更新：2026-10-29T23:15:49+08:00。NAS恢复期继续UI，全部真机/NAS暂停；0真机发现/安装/控制、0NAS命令/旧凭据、0播放/源写。仍6.1，无定时或后台接续任务。

## 实现与保留

- 新MediaDetailPeopleScroller由正式网络库、移动Jellyfin和TV Jellyfin调用，统一横向ScrollView与隐藏滚动指示器。TV保留12点内边距，17+禁用越界裁剪以容纳焦点线，16保留系统行为；各宿主HStack/LazyHStack、人物数据和ID保持。
- 网络库原电视人物卡没有focusable，现包MediaFocusablePerson作为只读焦点目标。与TV Jellyfin共同使用MediaPersonFocusFrame的暖色底色/3点边框，没有放大动画、空人物详情或新播放操作。TV Jellyfin保留原FocusState ID、ScrollViewReader、requestedDetailFocus、方向导航和加载逻辑，仅复用外观/横向容器；此批没有整合这些宿主方向状态。
- 人物姓名/角色共用accessibilityElement合并阅读，空角色、原字号/图片尺寸沿上一批。未验VoiceOver，不据此称读屏通过。
- Debug credits/credits-missing挂网络库相同只读焦点包装；12项合成资料使TV首屏外有内容。最早8项会刚好落首屏，初次绿构建保留后仅扩大夹具重建；没有真实媒体/账户/store/client/URLSession。移动图片加载器、网络NetworkCreditPortrait及TVPlayIntent后播放源码与批前相同，原人物图像URL和缓存未改。

5份既有源：MediaDetailPresentation、LibraryPosterWall、移动LaunchpadView、TVViews、OfflineMediaScene。保留继承未提交修改，未改播放路线文档。本批不新增资料缺失提示，仍以来源实际状态和原文案为准；真实头像/刮削、返回闪动等不闭合。

## 有限结果与未通过

3个独立组件基线：手机流光浅色辅助字号、Pad清流浅色普通字号、TV流光深色普通字号，预期文字/合成标识、相邻背景采样稳定，实图抽看。手机长姓名角色完整换行，TV首项暖色焦点框可见；这是静态基线，不是完整浏览或性能验收。

手机3次拖动及2次横向滚轮请求没有确认位移，保留输入后截图/文字，不判横滑PASS，也无法据此归因App故障。TV一次Right请求没有确认焦点移动；600秒交互门禁随后超时并自动清理，未取到首屏外或返回首项的证据。后来重新绑定Simulator显示另一个非本任务窗口，立即停止，未操作该窗口。Pad只采静态基线，不发触控输入。两类未完成不重复调参，不伪装为全交互/流畅验收。

最早系统Python缺PIL时脚本在导入阶段终止，尚未创建设备；随后使用应用自带Python。初8人物绿构建、依赖错误和电视超时均留私有证据。最终3自建实例均shutdown/delete成功、fresh列表已无，合成偏好哨兵保持且无额外应用偏好；不等同用户真机偏好验收。

6既有测试（场景4/网格2）过；双模拟器Debug、双普通签名Debug、双无签名Release编译过。测试未覆盖SwiftUI焦点和实际头像。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，433输入与构建冻结一致；双Debug候选30/27 Mach-O核签与TV嵌入库过，未安装真机，普通启动无测试参数。初8人物构建不冒充最终12人物证据。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-29T23:11:51.414868+08:00 | `ee376a332eb2bc08a6af65ea4084833b4c5fbffbe69e4ae188289fee2aaacd3b` | `99b6654661ddfd6941eeec7f3e2c9eb6c763bc6e34fcba543c7b6d42194a08e6` | 30 |
| Apple TV | 2026-10-29T23:11:11.415254+08:00 | `523f78fe977c3f89b1ac80355617391da872b75b1a7a6674c0f6dd6ce37b1f17` | `45fe93881826d764b4db585ddfd545b7ff34c7c4e01df56cf608dab583508c2f` | 27 |

包/原始图/实例/失败只在仓库外current-shared-people-navigation-private，root最新两包及输入清单已更新。磁盘收尾约6.6GiB，下一轮先核空间；模拟器串行，构建目录不并发构建。全部真实设备保持暂停，无安装身份或真机回归结论。

[安全结果](../../../testing/results/2026-10/2026-10-29-shared-people-navigation.json)／[离线规范](../../../testing/OFFLINE_MEDIA_UI_SCENARIOS.md)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。114格无新P，旧失败保留。

下一步优先无NAS的资料缺失提示/连接编辑细节；横滑/TV移动、实际Jellyfin宿主方向返回与VoiceOver保留待验，不反复跑无位移输入。真实头像/播放须NAS恢复并确认新环境后fresh核设备/包再验，核心播放优化届时才提示Astra。
