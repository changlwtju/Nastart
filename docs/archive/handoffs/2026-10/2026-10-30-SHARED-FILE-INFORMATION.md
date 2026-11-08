# 三端多入口共用影片文件字段

更新：2026-10-30T08:17:49+08:00。NAS恢复期仍6.1，仅代码/自建隔离模拟器；0真实设备发现/安装/控制，0NAS/旧凭据/播放/源写，无后台任务。

## 实现

MediaDetailMetadataRows/Row统一字段表面、标签/值与语义色，TV标签20/值23、标签宽160，移动标签宽88，辅助字号上下排而不挤固定列。值去首尾空白、完整换行、空白行不占位；读屏组合但未实际验。MediaDetailFileProperties集中映射文件名、封装、正容量和正码率（Int64、Mbps一位小数）；未知/非正数不造0或破折号。实际没有做媒体探测。

手机JellyfinFileInformation换用共用字段/表面，保留原中英文Localizable键，旧私有行布局删除；无有效字段不画空折叠项。TVDetailSource仅加可选Path/Container/Size/Bitrate，沿已有MediaSources.first、无新请求，TV Jellyfin详情同共用字段/折叠。普通TV/移动/网络折叠仍默认收起；共用Disclosure新增可选FocusState绑定到真实按钮，TV接文件入口与原动作/演员/相似影片的上下方向及scrollTo位置，不改播放动作。不能凭函数检查称遥控成功。

网络三端同字段表面：资料来源、原文件名、扩展名、已知正容量、所在文件夹和确有本地图片时的封面来源。目录与文件名分开避免重复全路径，扩展名不冒充已探测封装；封面来源沿当前已接受metadata.artwork，补读失败只加保留资料说明，纠错仍独立按钮。来源差异保留为数据适配，不另造字段行。演员图片读取、文件选择/顺序/归并、canPlay、单文件动作与fullScreenCover、TVPlayIntent以后代码/TV播放模型及移动文件信息View之外代码均核保持；播放路线文档未动。

7既有源/435输入，继承修改保留，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`。单文件ISO没有播放按钮时的说明仍待下步，本批不把多文件已说明等同单文件已修；无ISO/主片/续播新支持。

## 有限验证

4既有离线参数测试过，无新增镜像UI测试、未重复未受影响的分类/投影套件。TV本机probe用精确生产源码片段，无替代实现：3个只读JSON案例（64位3TB、已有流信息、可选缺省）与9个新增文件焦点方向函数分支检查过。仅函数逻辑，不启动App根，不是完整TV XCTest或渲染焦点/遥控实测。

双模拟器Debug、双普通签名Debug、双无签名Release过；冻结输入构建后hash相同。30/27 Mach-O核签与TV嵌入库过，候选无测试参数/环境、未装真机，root两包/输入清单已更新。

Debug file-info直接挂正式字段/折叠（仅此预览initiallyExpanded=true），长中英文名/目录、24GB/48Mbps及合成来源；file-info-empty传空白名称/封装和负容量/零码率，直接下一段，没有空折叠。无正式账号/model/store/client或媒体文件。6静态窗：手机流光深大字资料/清流浅空值；Pad清流浅大字资料/流光深空值；TV清流浅资料/栈列深空值。预期文字/合成标识、连续背景采样、最终图hash及关键实图核过。只证可见组件，未测实际展开点击、长字段完整滚动/遥控/读屏/英文全页/帧时间，更未验真实服务字段与图片。

3自建实例shutdown/delete后fresh列表无，合成偏好哨兵保持且无额外应用键；其他实例和真机未动。原图/包/身份/路径/命令只留仓库外current-file-info-polish-private。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T08:12:43.752167+08:00 | `d5a2230e2d47c94838fa97af00e7d4fbe616b451614475e3fea5882766a9b4f7` | `95ad0ad9a0fe85b2c55358e58eb0d6ce8b3bb29804798736ef47cc1429902aef` | 30 |
| Apple TV | 2026-10-30T08:10:20.826661+08:00 | `b0779cea0fbe5502db324358730a06851e6cdb0d33d040ae4c92700d3fe88653` | `94c40cee4d877342073bb99fa66c5312490522263d26f6d1b77bd268a85e63fb` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-file-info-polish.json)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。114格无新P。收尾空间约6.3GiB；下批先核空间、模拟器/同构建目录串行。接续单文件不可播放说明与缺数据状态等无NAS细节；真实图片/目录事务/返回闪动和大文件/ISO/弱蜂窝等仍等NAS恢复后fresh核设备/包再验，Astra仅后续核心播放优化提示。
