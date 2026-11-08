# 已有连接准备状态与取消入口

更新：2026-10-30T11:42:44+08:00。接续[添加连接批](2026-10-30-SHARED-SOURCE-ADD-CHOICES.md)。NAS恢复期仅代码/任务自建隔离模拟器，仍6.1；0真机发现/控制/安装、0NAS/旧凭据/播放/源写，不改NAS/VPN，无后台任务。

## 实现与边界

NetworkExistingConnectionView在source就绪前挂正式共用NetworkExistingConnectionStatusPage：明确“选择媒体文件夹”标题、来源名称及NAS/WebDAV类型；显示准备状态，失败显示原networkMessage结果、重试和“返回上一页”。来源信息非可点击，不画TV前进箭头。两项操作普通字号紧凑并排，辅助字号上下排列（后者只编译，未取到移动端实图）。图标暖色，文字语义主次色，按钮沿既有Compact/Borderless样式。名称输入只在source就绪后显示，原名称状态仍由宿主持有。

返回来自多个宿主：添加选择、媒体库上下文菜单、连接管理和连接详情；因此不用“返回选择连接”承诺错误的目的地。toolbar取消和准备页TV返回都走cancel守卫，folderSaving时不退出，取消先标cancelled再dismiss。原source就绪的文件夹返回仍由既有FolderPicker控制。

本地prepare以body捕获的preparationAttempt接task(id:)；准入和成功/失败接收前核cancelled、Task.isCancelled和当前attempt，成功后再一起设置startingPath/source。retry只接受未取消、未保存、source为空且已有错误的状态，先清错误再增attempt，避免同一错误状态连续调度。makeSource沿原四分支：独立WebDAV连接、旧WebDAV库、NAS和缺NAS错误；保持原凭据调用/作用范围和目录起点。准备本身是同步本机读取并构造客户端，没有await或目录读取；这些守卫不等于异步迟到网络响应/中断钥匙串已实测。实际目录读取/取消仍由未改的FolderPicker负责。

文件夹选择回调及allowsRoot/Parent/onSavingChanged按去空白核同；NetworkFolderPicker及之后源码字节同，其他库控制器、连接表单、源/存储/凭据实现和播放输入保持。3既有源（LibraryViews/OfflineUIScenario/OfflineMediaScene）/435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保留，无路线变化，不改播放链路文档。

Debug existing-preparing/error/unavailable直接挂同一StatusPage，固定合成来源/类型和原因，回调为空；无正式model/store/vault/client/Task。合成错误仅验证排版，不冒充真实错误分类或登录读取成功。

## 有限验证

4既有OfflineUIScenarioTests过，接受新增场景且错误参数保持隔离；未新增镜像UI测试。双模拟器Debug、双普通签名Debug、双无签名Release构建过，435输入hash一致、30/27 Mach-O核签和TV嵌入库检查过。普通Debug候选无测试参数/环境，root清单更新，未装真机。

首TV三窗后核对宿主，发现“返回选择连接”不适用于所有入口，保留并排除初图，修正为“返回上一页”；重建双模拟器，参数枚举/测试输入未变，不重复跑4测试，原生各配置只在最终画面稳定后生成。

最终TV三主题准备/缺登录资料/NAS不可用各1窗：2自动文字/背景稳定检查通过；第三窗OCR漏读实际可见的返回按钮，50秒超时/20次尝试完整保留。原图可明确读到“返回上一页”，其余预期文字/合成标识和背景检查成立；人工复核后单列1窗人工解决OCR遗漏，不称3窗全自动PASS，不重跑已过2窗。最终三张原图均实看、hash核同。按钮实际点击、遥控返回/焦点移动、滚动、读屏、钥匙串/目录和持久化未验。

手机/Pad模拟器起步需4.8GiB，可用量不足，未建实例、无移动端画面验收；三端只取得编译及共用接线证据。TV独立3.8GiB起步，运行时保留2GiB。仅清理任务创建的NetworkMedia SwiftPM测试编译scratch（约165.5MiB可重建产物），原日志/截图/安装包与用户数据保持。初/最终2个TV实例全清，fresh列表无，合成偏好保持；收尾约4.1GiB。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T11:38:59.564965+08:00 | `a2a6dc845fc2a35198de7fe98243d9bebb28dd136d7dc2e93b56e66202740df2` | `a341469898906d0bc0ad0643060ee41bb0d01c7d42679a9e96ab0936ccfd228b` | 30 |
| Apple TV | 2026-10-30T11:38:23.995451+08:00 | `532043225671e7cb987e1ed0dd68e63c610dfd039fe7b971c8d9997b97d41d06` | `7e965f656d36523e12bbd79f48ce340b6300e2a442dc93f59db016a3f26fe3c6` | 27 |

原包/图/命令/偏好仅仓库外current-existing-connection-state-private；[安全结果](../../../testing/results/2026-10/2026-10-30-existing-connection-preparation.json)。[播放矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)已核，114格无新P。NAS安全恢复并确认新环境后fresh设备/最新包再验真实目录与大文件/弱蜂窝/头像/返回闪动；Astra仅后续核心优化提示。

下一步先核空间，补手机/Pad准备页大字号实图及真实返回交互；空间未恢复时继续连接详情的设置/关联文件夹分组和空态代码审查，不反复启动受阻模拟器，不触碰NAS。
