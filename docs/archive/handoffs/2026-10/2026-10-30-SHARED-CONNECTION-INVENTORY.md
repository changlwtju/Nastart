# 连接管理共用分组与媒体文件夹来源

更新：2026-10-30T10:04:28+08:00。同轮接续[文件夹选择批](2026-10-30-SHARED-FOLDER-PICKER-STATES.md)，NAS恢复期仍6.1；只本地/自建隔离模拟器，0真机发现/安装/控制、0NAS/旧凭据/播放/源写，无后台任务。

## 实现

NetworkConnectionsView接同一NetworkConnectionsPage：存储连接及添加、有关联时才显示的媒体文件夹、有实际入口时才显示的媒体服务。没有可用destinations/services不再画空服务组；无存储连接时明确说明并保留添加入口。三端沿同一分组/NetworkGroupedRows、暖色图标，连接/文件夹文字恢复语义主色/次级说明，不被按钮整体染黄。原添加/编辑/复用/服务目的地和sheet回调保持，不新增服务探测或协议能力。

NetworkStoredConnectionLabel区分具备设置的连接和旧来源：前者写“连接设置与媒体文件夹”，后者写“选择媒体文件夹”，不再让点击说明与目的地相反。NetworkMediaFolderLabel由全局管理页和单连接详情实际共用，显示来源与路径；同名目录可看来源区分。来源有正式connectionID时用连接名；NAS需账号与规范地址都匹配才用当前NAS名；其他旧/已断开来源只展示协议与host/port，绝不拼完整地址、userinfo/query或显示密码。这里只读本地已有字段，不调用NAS source(for:)或制造登录。

每次body只取一次savedWebDAVConnections并用于空状态和列表，避免该computed属性里的旧来源Keychain去重读取在本次排版中额外重复；不声称真实钥匙串耗时/性能已测。未新增本地持久化、凭据加载路径或真实网络请求。

3既有源（LibraryViews/OfflineUIScenario/OfflineMediaScene）、435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；继承未提交修改保持。文件夹选择/父页busy边界、资料编辑、源与存储、所有播放/海报/演员源码保持；ConnectionDetails仅复用行展示；NetworkActionLabel增加默认false的semanticText可选参数，只有本批行主动开启，其他调用原显示保持。无路线改动，播放链路文档不变。

## 有限验证

4既有参数测试接受新connections/empty/storage场景并保隔离边界。校验/存储未改，不重复本轮上一批已过的10文件夹事务测试；未新增镜像UI测试。双模拟器Debug、双普通签名Debug、双无签名Release构建过；435输入hash相同，30/27 Mach-O核签/TV嵌入库过。普通Debug候选无测试参数/环境，未装真机，root清单更新。

初轮构建/9窗采图完成后，代码审查发现空态和列表重复读computed来源，且旧NAS不能直接借用当前NAS名；初图还显示按钮把整行染黄。修正同次body列表快照、来源匹配和语义文字色后，重建双模拟器及原生各配置并替换全9窗。初版图/命令/结果保留，排除最终证据。外层层级色.primary首轮修色未覆盖按钮Tint，实图仍染黄；保留第二组图并排除，改为既有NetworkActionLabel的semanticText可选参数，在Text上明确Color.primary/secondary，默认false保留其他入口原表现。再重建/采最终9窗，不重复无关参数测试。

最终各端3窗：完整分组、无连接、仅存储，跨三主题深浅色，手机空态/Pad仅存储含大字号。正式Page/两种真实行由Debug直接挂载，两个同名合成文件夹使用不同来源；无正式model/store/client/Keychain，回调只改内存或空操作，不执行真实目的地。检查预期文字/合成标识及无服务时不出现“媒体服务”、连续背景/最终图hash并实图复核。只能验组件条件和可见布局，不证明实际来源模型映射、真实跳转/凭据/返回/滚动/焦点/读屏，也不把首屏外内容称完整可见。

初版3＋层级色尝试3＋最终3自建实例全清，fresh列表无；合成偏好保持、无额外应用键。原图/包/命令/路径仅仓库外current-connection-inventory-polish-private。收尾约4.3GiB，下一轮先核空间、模拟器/同目录构建串行；视觉修正先稳定模拟器画面，再做原生签名Debug/Release和冻结，减少反复全配置重编。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T10:00:27.986321+08:00 | `87dec6cd831cf38fa50650696d7a5258d7a9c451c3d653946ae3a510df814757` | `4b227a517699e403d188f5a2638e2c0f0aa2caa75d8a6d14c3d21e94c7f70a69` | 30 |
| Apple TV | 2026-10-30T09:56:41.166295+08:00 | `d222229c98d1ee3292fd08424e48f1bcb45afa8984651588eab0c67342855e16` | `e27954647ec003893bcb147c6dc67c01ba1d5bb4992bec09955897e6de7a6f8e` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-connection-inventory-polish.json)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。播放矩阵已核，114格无新P；真实目录/账号与跨端展示、图像/返回闪动及大文件/弱蜂窝继续等NAS安全恢复后fresh核设备/包。Astra仅后续核心优化提示。

下一步：添加媒体文件夹页的已有连接/新增连接/协议范围说明，检查与连接管理的名称和动作一致；不得把FTP/SMB原型称生产可连接，不触碰NAS。
