# 详情信息区统一与真机核对

2026-10-28，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`＋已有未提交修改保留。[结构化结果](../../../testing/results/2026-10/2026-10-28-DETAIL-INFORMATION-LAYOUT.json)。原始设备身份、偏好、截图、App和诊断只在仓库外私有证据区。

## 实现与接受范围

此前只共用单个Hero/Facts/人物卡，区域排列仍分别维护。此次在NetworkMedia/MediaDetailPresentation.swift新增MediaDetailInformation<Credits,Related,Supplement>，由LibraryPosterWall中的NetworkLocalMediaDetail、移动LaunchpadView中的JellyfinMediaDetailView、TVViews中的TV详情实际调用。共同固定“演职人员→制作信息→相关推荐→补充来源/文件”，缺少内容的插槽不制造资源或数据；制作文本统一caption及分隔符，TV分区38/触屏22。TV演职标题改用原共用MediaDetailSection；现有ScrollViewReader、焦点框、人物卡动作与方向导航保留。Network TV人物间距28/触屏12。

相对前批只改四个现有输入，不增清单文件数：MediaDetailPresentation.swift、LibraryPosterWall.swift、LaunchpadView.swift、TVViews.swift。未改登录/存储/扫描/刮削网络或播放器。现有Jellyfin服务资料与NFO数据可不同（评分、清晰度、人名、可用人物），没有伪造一致数据；网络库独立离线/剧集人物及多JF关联仍开放。部分页面壳、来源特有功能与完整播放生命周期未全部统一。

## 构建与安装身份

最终36项现有资料/分组/精确编号人物读取回归0失败；不是SwiftUI截图单元测试，也不将Mac的条件编译当iOS/tvOS界面编译。两端普通Debug均实际编译成功，418源输入构建前后相同，全部Mach-O逐一和deep/strict签名核过，TV嵌入检查通过。没有Release或新播放回归。

| 最终包 | 构建时间(+08:00) | 主SHA-256 | debug dylib SHA-256 | 已核签名 |
| --- | --- | --- | --- | --- |
| 移动 | 2026-10-28T05:55:07.487088+08:00 | `b3cee16a915df8030a1336744fc8458995029cbec611d9b5ba081b8bad8b952a` | `683e26cafa0965d45785b94cba4d6dcfbce492d5fe582b8bbc0dad86c976a6e6` | 30 |
| TV | 2026-10-28T05:55:55.692307+08:00 | `eb82f5624e92d9840c530aacb5bb2e89178aa5fba7a66c429c1167d8a8c0427c` | `e7a3994e65601f8bd520832180708a99f701d0830f65f29df5e609b7ddc05555` | 27 |

每机现场fresh核名称/型号/系统/UDID/连接，源包无变化且安装身份可靠时按精确收据继续窗口；不凭0.1.0/1或另一台收据。最终13 iPhone14,5/16.3.1 USB、Pad iPad15,7/26.6 USB、客厅TV AppleTV14,1/18.2 LAN均保留数据覆盖本包并普通空参数环境启动；各轮首页实图与末恢复实图保存。18 iPhone19,7/27只配对无线覆盖Complete/lookup/27偏好同，未主动启动、取屏或控制，实际DSM域名会话路线未验。中间05:45/05:46包曾装13/TV/18，后修子项标记覆盖，最终四机重核覆盖；中间包不当最终验收。

## 六个入口的有限原生核对

13/Pad/TV两入口均进《爱情神话》，未点播放或外部链接、未改收藏/轨道/连接。13两个入口滚动后实际看到人物行、其后的制作文本及文件区；Pad WebDAV同样实看。Pad Jellyfin首轮AX visible=true但原图仍在首屏，不能据此判实际制作区可见；追加同包独立窗口按当前视口边界滚动，再实看人物/制作/推荐/来源的顺序。补窗productionInViewport成立，最终图已检查。W3C滑动仅在当前AUT/原生ScrollView矩形/窗口边界核对后执行；不作帧时间或滚动性能PASS。

TV WebDAV实际制作文本已在演职之后，文件Disclosure在其后；TV Jellyfin演职→制作→推荐同序，Down进入演员、Right/Left移动、Up回原播放动作焦点实图成立，未Select播放。遥控焦点ID/行为保留，不能扩大为全部遥控键或网络库演员交互功能已和JF相同。

六入口校验及补窗均恢复普通Nastart首页、设置恢复读回、自有HTTP会话删除；13/TV原Runner保留，Pad自有Runner与xcodebuild停止。当前无自有播放/下载采集。13/Pad/TV原149/3408/149完整索引JSON同前批，26/19/15非诊断偏好全同；18原27偏好同。0播放/0源文件写，不改NAS/VPN/系统，不卸载或清凭据，114格无新增整格P，30项14/5/11保持。

## 保留的失败与修正

首轮13与TV进入详情后找不到media.detail.production而超时；按原标签观察的第二窗证实文字已在、排列正确，但Text的name被父VStack的media.detail.information覆盖。去掉父容器标记，只保留单个制作Text和原动作标记，重新双构建/安装；最终原生明确核到制作标记及原动作标记，TV焦点往返成立。原超时、原图与中间包保留，不归为App崩溃或忽略失败。Pad AX可见与真实视口的首轮差异及补窗也保留，不通过调大等待/改播放参数绕过。

## 当前用户优先级

用户再次指出：此前要求参考Infuse或网易爆米花的网络连接设置、添加/修改文件夹，但实际观察仅首页/设置/升级，未完整走查该流程。此反馈成立。接下来优先在空闲13/Pad/TV只读观察实际添加连接、选目录、编辑已有连接/媒体目录，形成可映射到本App的具体操作，再修改实现；不把有限首页观察当完整对照，不操作使用中的18，不改竞品账号/已有连接、导入删除资源或复制服务密钥。

其余保持：共同ready/播放意图/轨道/终结仍未全统一；Pad原生播放器普通退出、TV真实目录保存、FTP App接入/FTPS522、SMB严格选根FAIL仍开放。播放实际路线沿[前批](2026-10-28-SHARED-PREPARATION-COORDINATOR.md)，本批0播放不能代替前批或未来包回归。不得声称回合结束后后台继续，不建定时任务。
