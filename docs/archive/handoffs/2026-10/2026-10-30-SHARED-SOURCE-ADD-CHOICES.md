# 添加媒体文件夹：共用连接选择与协议范围

更新：2026-10-30T10:33:16+08:00。接续[连接管理批](2026-10-30-SHARED-CONNECTION-INVENTORY.md)。NAS恢复期只代码与自建隔离模拟器，仍6.1；0真机发现/控制/安装、0NAS/旧凭据/播放/源写，不改NAS/VPN，无后台任务。

## 实现

正式NetworkSourceAddView接NetworkSourceAddPage，三端共用“已有连接→新增连接→其他协议→只读说明”。已有连接点击仍进原选择文件夹宿主；WebDAV行直接复用连接管理的NetworkStoredConnectionLabel（选择文件夹说明），当前NAS保留已有登录入口。新增连接写“添加WebDAV”，明确HTTP/HTTPS以及连接后选目录。没有已有连接时不占空组；从连接管理进入的“添加存储连接”模式仍隐藏已有连接，且三元短路不读取savedWebDAVConnections。其他模式在同次body只取一次该属性供条件和ForEach共用，避免新增重复旧来源Keychain去重读取，不声称耗时优化已实测。

SMB、FTP/FTPS放在非按钮状态行，只写“暂未开放连接”，不把开发进度说明或原型作为已可用功能。状态行复用NetworkActionLabel暖色图标/语义主次文字，新增showsDisclosure默认true，只有非交互协议行传false，TV不画前进箭头也不挂Button；普通动作保持默认。页脚说明只读所选文件夹、海报资料存本机和不修改源文件。原NavigationLink、NAS/WebDAV复用sheet、onAdded/dismiss与finishAdding保持；连接表单、真实源/凭据/保存、选择目录控制器和播放代码保持。

3既有源（LibraryViews/OfflineUIScenario/OfflineMediaScene），435输入、HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保留。Debug新增source-add、source-add-empty、source-add-connection，直接挂正式Page和正式行，仅合成文字与空回调，不构造model/store/client/Keychain或Task。它们不代表实际登录、导航或账号映射验收。

## 有限验证

4既有OfflineUIScenarioTests覆盖新增场景可解析及显式参数隔离；没有新增镜像UI测试，也不重跑未改的存储/文件夹事务套件。双模拟器Debug、双普通签名Debug、双无签名Release构建过；30/27 Mach-O核签及TV嵌入库检查过，435输入hash核同。普通Debug候选无测试参数/环境，root清单已更新，未装真机。

第一次手机source-add预览，Debug的正文合成提示与底部合成标识重叠，OCR超时失败。失败截图/命令/结果保留并排除，不把失败当到页；仅移除重复Debug提示，不改正式页脚，再构建双模拟器并重采。参数测试输入未变，未重复运行。没有在视觉确认前反复构建原生各配置。

最终9静态窗：各端完整已有连接、空已有连接、仅新增存储模式各1，跨三主题/深浅色，手机及Pad空态大字。检查预期文字/合成标识、空/仅新增时无已有连接、背景稳定与最终图hash，并复核实图的文字色/分组和可见的非按钮协议行。只说明可见组件布局；TV完整页下方协议/只读说明、任何首屏外内容不声称全部可见；不证明完整滚动、焦点移动、返回、读屏、实际连接或持久化。

磁盘初4GiB保守门槛在建实例前停止；初按串行预算3.5GiB起步，但手机已通过2窗后仍触发运行时2GiB保留线，程序finally清理并保留两窗，不误记第三窗通过。实测回收后提高起步余量至4.8GiB，仅补缺余窗并继续保留2GiB线；iOS实例回收后电视预检仍低于iOS预算，暂停未启动电视；随后单独按更小的TV运行足迹设3.8GiB起步，运行时仍保留2GiB，再触发则不重试。不并发原生构建、不删既有证据或用户数据。初预检没有建立实例，不计UI失败窗。

初提示失败1＋磁盘中止1＋补余窗3自建实例全部清理，fresh列表无；合成偏好哨兵保持且无额外应用键。原始包/图/命令/偏好仅仓库外current-source-add-polish-private。收尾约4.5GiB；后续先核空间，任务模拟器串行，稳定UI后再生成原生候选。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T10:30:18.835994+08:00 | `df9d9a7e84915a3a98498551113c5cf9e2b23475f2ad9cc7b1d849cbe03047b2` | `7092937df0f9bb966c4d750c2240982121f93fd1b06b5993d85b7af490b6e4d2` | 30 |
| Apple TV | 2026-10-30T10:29:47.393450+08:00 | `a1051a00034ab8f90a736fe1579a3ce37240a131f7f545c29ed0187c5f6345c9` | `ace5db4cc846085b4a2332b2c1e211d83950af28e712c91b784f334abfa5dd75` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-source-add-choices.json)。已核[播放矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)，114格无新P。播放实现无变化，不改路线文档；真实头像/返回闪动、目录及播放等NAS安全恢复后fresh设备/最新包再验。下一步整理已有连接“准备中/失败/重试”的展示与取消边界，保留原源范围/存储事务，仍不连接NAS。
