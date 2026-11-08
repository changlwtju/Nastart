# 文件夹选择共用状态与保存边界

更新：2026-10-30T09:31:18+08:00。NAS恢复期，仍6.1；仅本地代码/自建隔离模拟器。0真机发现/安装/控制、0NAS/旧凭据/播放/源写，无后台任务。

## 实现

NetworkFolderPicker使用同一NetworkFolderPickerPage展示当前路径/只读范围、选择按钮、状态和子文件夹；正式三端和Debug场景直接挂真实展示组件，不另造预览页面。沿NetworkContentPage/Section/GroupedRows、原NetworkActionLabel和共用暖色主按钮。路径换行，普通“没有子文件夹”不冒充没有视频；根不可选时说明须进入子文件夹，若根下也没有子文件夹则请返回其他位置，不再错误提示可直接选择根目录。读取中/读取失败及重新读取、使用文件夹失败及保留当前路径、处理中分别显示，读取失败不留可选按钮，保存失败仍可重选/重试。

控制器拆listingError/selectionError；back/open/chooseCurrent及重读入口检查saving，选择还检查loaded/根权限。chooseCurrent在创建Task前冻结selectedDirectory，清上次选择错误，设置saving并同步回调onSavingChanged(true)；结束defer还原。TV onExit经back守卫、选择页interactiveDismissDisabled(saving)。添加WebDAV与复用连接两个宿主接同步busy回调，工具栏取消同时禁用并守卫，复用页媒体库名称输入也禁用；这避免仅禁用子页按钮却遗漏父页取消。原model.add/addFolder/addNAS等事务及连接/凭据路径不变，文件夹编辑的浏览只选择路径仍沿原回调。

读取Task用body捕获的Request(directory,retry)，向client.list传该目录；接受成功/失败前检查取消和当前Request，防旧路径/重试失败覆盖新页。原initial仅首次可用规则、同源/根权限与只读协议保持，TV只在当前目录可选时明确给select焦点，不主动聚焦不可选根按钮。这里是实际代码接线，尚无真机或模拟器真实遥控/点击/过期响应交互结论。

3既有源（LibraryViews/OfflineUIScenario/OfflineMediaScene）、435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`。LibraryViews添加页之前的媒体/纠错/文件夹编辑代码以及ConnectionDetails/Editor原内容保持；存储模型、传输、播放、演员/海报和前批组件不变。无播放路线修改，路线文档不变。

## 有限验证

4既有OfflineUIScenarioTests和10既有LibraryFolderEditingTests过，后者以合成只读源/临时客户端存储核同源路径、绝对路径/转义字符、成功替换持久化、取消/失败保旧、陈旧扫描、等价路径和FileStation范围，不是新增UI控制器的点击/取消或NAS兼容性验收。没有新增镜像UI测试。

双模拟器Debug、双普通签名Debug、双无签名Release构建过，435输入在冻结/收尾保持；30/27 Mach-O核签/TV嵌入库检查过。普通Debug候选无测试参数/环境，未装真机，root清单已更新。

7个Debug场景folder-picker/empty/root/loading/error/selection-error/busy都只给正式Page提供合成路径/目录/内存回调和固定状态，无真实model/store/client/Keychain，无目录读取或保存Task。13静态窗：手机正常/无子目录/大字读取失败/忙碌；Pad正常/不可选空根/大字选择失败/读取中；TV正常/不可选空根/无子目录/读取失败/忙碌。跨三主题深浅色，预期文字/合成标识/连续背景与最终图hash及关键实图核过。OCR沿既有规范忽略图标感叹标点，原图保留。没有将静态首屏称完整滚动/焦点/VoiceOver或按钮动作验收，首屏外内容仍未验。

3自建实例全shutdown/delete，fresh列表无；合成偏好哨兵保持且无额外应用键，其他实例/真机不动。原图/包/命令/路径只在仓库外current-folder-picker-polish-private。约5.6GiB，下批先核空间，模拟器/同目录构建串行。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T09:26:50.907420+08:00 | `b38300f0dae0ed6042ccec716527c026d5af2eb51cd5bb8ced4b1479301165b0` | `8237456f87abd037723fb23de41104e720d95bb251dd845889391fa89b7c6e48` | 30 |
| Apple TV | 2026-10-30T09:24:22.016924+08:00 | `e0a0d724c446ea4b620abf0bb5404a759423ad9d38ce0359dff035d94e5290fb` | `ee10cf12db5abf18733b83566bfb712dfefb6f77392940945010c98925d4ab5c` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-folder-picker-polish.json)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。已核播放矩阵，本批不改能力也不新增114格P。真实目录事务/权限/重复提交与返回/陈旧读取、头像/返回闪动和大文件/弱蜂窝仍待NAS安全恢复后的fresh设备与最新包验证。Astra仅后续核心播放优化提示。

下一步连接管理的分组、关联文件夹和缺服务空态。只读审查发现：无destinations/services时仍绘制空“媒体服务”组；旧版WebDAV来源行写连接设置，实际直达选文件夹；不同连接同名文件夹缺来源区分。这些未修改，不作为已复现硬件故障。
