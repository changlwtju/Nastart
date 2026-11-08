# 三端网络媒体演职资料状态与请求隔离

更新：2026-10-30T04:43:23+08:00。继续NAS恢复期无NAS细节，全部真机仍暂停。0设备发现/安装/控制、0NAS探针或旧凭据、0播放/源写，仍6.1，无调度或后台接续。

## 实现

正式NetworkLocalMediaDetail原来只用detailLoadFailed区分空与失败，异步未完成就可能显示“本地资料暂缺”；服务器人物补读失败也没有独立可见状态。本批新增轻量MediaDetailCreditsNotice，三端网络库实际共用：读取中带装饰性进度图标；成功空结果为“现有资料未提供演职人员信息。”；失败为“演职资料暂未读取，现有信息已保留。”。不增加空头像框，不将头像加载与演职资料状态混淆。现成人物优先展示，补读失败/加载不遮已有姓名和本地资料。

MediaDetailReadState为NFO详情与服务器人物分别记录身份、Phase和每次读取独立Ticket。成功/失败/取消只接受当前loading Ticket，同身份的旧重试也不能完成新读取；页面在应用结果前再检查Task取消与实际身份。取消回idle、不误记失败，不增加自动重试或读取次数。已接受同身份NFO仍沿缓存guard跳过，原文件/索引、人物图像URL/任务/缓存/授权和播放destination不改。服务器人物取消不再记为peopleError，真正当前请求错误沿原脱敏类型诊断。

4既有源（LibraryPosterWall、MediaDetailPresentation、OfflineUIScenario、OfflineMediaScene）及2新增文件（状态实现/5测试），总435冻结输入，继承未提交内容保留。移动/TV Jellyfin自己的资料加载未改，不将本次网络库状态误报成所有宿主都已迁移。播放路线/引擎未动，VIDEO_PLAYBACK_PIPELINE无相关变更。

Debug新增credits-loading/credits-empty/credits-error，直接挂同Notice，固定合成状态、不触发任务/账户/Keychain/model/client或URLSession。三种状态不会自动互转，不是生产源读取验收。

## 验证

- 26测试过：新状态5（旧身份结果、同身份重试、取消、成功空/失败区分、保留已有信息）、既有文件夹编辑9、保存连接8、离线参数4。临时目录、专属UserDefaults与内存只读Source；失败/取消/新扫描冲突后旧索引字节/连接保留、多个关联库原子替换及路径保持有测试。未改WebDAV编辑事务；不是Keychain、真实表单和服务器协议验收。
- 9静态组件窗：手机3（流光深普通加载、流光浅大字缺资料、栈列深大字错误）、Pad3（清流浅加载、流光深大字缺资料、清流浅大字错误）、TV3（流光深加载、清流浅缺资料、栈列深错误）。每窗预期文字/合成标识、背景相邻采样稳定，关键实图抽看。只判可见提示，不是完整横滑/方向焦点、真实头像、动画、读屏或流畅PASS。
- 双模拟器Debug、双普通签名Debug与双无签名Release编译过；普通Debug候选无测试参数/环境，30/27 Mach-O核签及TV嵌入库过，未安装真机。Release仅编译，不传离线参数当隔离。
- 3任务自建模拟器均shutdown/delete成功，fresh列表已无；合成偏好哨兵保留且无额外应用偏好。其他实例/用户设备未操作。采图脚本最早语法预检失败在创设备前修复，不属产品失败，记录保留。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，输入hash构建后同；最终两包身份如下，原图/日志/路径仅仓库外current-detail-read-state-private，root最新包/输入清单已更新。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T04:37:36.548553+08:00 | `9f08b1f37498070225215bc3d8848a07000005cd9af9b46fbfd6a762fe4924a0` | `db7f5d1a678142e8d529abe03cb8be7e6b2d60cfd683b98c6fc4aaf17ee5a7ee` | 30 |
| Apple TV | 2026-10-30T04:37:07.850543+08:00 | `9a50ef8f9dabecfd2b09ee43d41117620fe99cca4706128604005f1e87926993` | `87089e43a76555f02b60c29479a5454718383d68a3892ca90d0ebea174a88629` | 27 |

开工剩余5.3GiB，只清8份已被新两批候选替代且未安装的自有Debug包副本（隐私/Plus/帮助/旧自适应），原始图/失败/日志/hash清单保留，最新两批候选保留；旧归档路径不能当当前存在产物。收尾约4.5GiB，下批先核空间、模拟器串行、同构建目录不并发构建。

[安全结果](../../../testing/results/2026-10/2026-10-30-media-detail-read-states.json)／[离线规范](../../../testing/OFFLINE_MEDIA_UI_SCENARIOS.md)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。114格无新P；上一批手机无位移输入、TV交互门禁超时和真实头像/返回闪动等仍未验，不以本批静态状态清账。

下一步：沿独立清单继续连接/文件夹编辑的非NAS提示和取消体验，媒体缺简介/多版本/季集展示；真实源请求、图片和播放等NAS恢复并确认新环境后再fresh核设备/包。Astra只后续核心播放优化时提示。
