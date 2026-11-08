# 网络影片详情共用已有播放限制说明

更新：2026-10-30T08:44:26+08:00。NAS恢复期仍6.1，仅代码/自建隔离模拟器；0真机发现/安装/控制、0NAS/旧凭据/播放/源写，无后台任务。

## 实现与边界

MediaDetailPlaybackNotice统一三端网络详情的说明：ISO原盘镜像、当前来源暂不能播放、文件暂不能播放。暖色info图标、语义色标题/正文，TV标题23/正文20，移动subheadline随大字换行，无新卡框/警告弹窗/假播放或重试按钮。Reason同时供MediaDetailFileRow的简短说明使用，默认泛化文案保持兼容；原盘/分段中的不可用文件可注明ISO或来源原因。

NetworkLocalMediaDetail的playbackLimitation先检查原canPlay，能播则nil；否则先ISO、再FileStation/缺播放来源、最后不支持文件的兜底说明。单文件才显示页级提示，iOS在原操作区后、TV在Hero操作后；多文件仍由可见选择区逐行解释，不叠页级提示。helper只决定说明，不决定路线/能力，不创建会话或网络请求。原canPlay谓词、单文件按钮、成员playing=member与fullScreenCover、头像loader保持。Jellyfin/设备文件原源码、所有传输/引擎/归并源不改；ISO能力、原盘主片/分段续播没有新增，播放路线文档不变。

4既有源：共用详情、网络详情、离线参数/场景；上一批共用技术字段/Disclosure/文件选择区本身保持，原合成ISO文件行改用明确原因。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，435输入，继承未提交修改保留。

## 有限验证

4既有离线参数测试过，allCases接受三个新场景；无新镜像UI测试，未重复未受影响的分类/投影/TV模型/方向测试。初次模拟器编译通过后，将不支持格式的合成样本从.mkv改成.bin，便于说明语义一致；仅重建两UI产品，参数测试的编译输入未变，不重跑；初次构建记录保留。首次实图复核又发现离线样例把Hero专用白标题放在浅色背景上，标题不清晰；修正Debug样例为语义色文字，正式Hero组件不改，重建模拟器及原生产品后重新采全9窗，原图/记录保留但不作最终证据。最终图来自修正后产品。

双模拟器Debug、双普通签名Debug、双无签名Release编译过；构建后冻结输入hash相同，30/27 Mach-O核签及TV嵌入库过。普通Debug候选无测试参数/环境、未装真机，root两包/输入清单已更新。

Debug playback-iso/source/unsupported都直接挂正式Notice和不可用FileRow，样本为ISO、无播放来源的MKV及不支持类型BIN；没有正式model/client/store、媒体文件或播放器。每端3个静态窗，共9：手机流光深ISO大字/清流浅来源/栈列深不支持；Pad清流浅ISO大字/流光深来源大字/清流浅不支持；TV流光深ISO/清流浅来源/栈列深不支持。预期说明/行文案/合成标识、连续背景采样、最终图hash及关键实图核过。只证样本组件可见布局，不证真实来源条件、图片/资料读取、点击/完整滚动/遥控/读屏/性能或播放。没有将.bin样本称作真实媒体库会索引的格式。

3自建实例shutdown/delete后fresh列表无，合成偏好哨兵保持且无额外应用键；其他实例/真机未动。原图/包/构建命令/路径只留仓库外current-playback-notice-polish-private。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T08:40:27.502093+08:00 | `2874147146a790c07715eed487699aef21f15fdeb8af06c8b3a70a101cfef60a` | `90e4c3968d192e38253064eea76f2ccc59163ce07bd840a65d807a227c2a92a5` | 30 |
| Apple TV | 2026-10-30T08:37:17.114978+08:00 | `4c1c572d7b3e5f17721b1d9f627559cfb6b5f5555c9d5e7be00ffc9a61cc2dd3` | `a8464a6060679b0aff35d7a9184d0d9556aecd954011b4b32b1d572d0d52d48f` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-playback-notice-polish.json)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。114格无新P，真实播放/ISO/弱蜂窝、头像/返回闪动/目录事务等仍等NAS恢复后fresh核设备/包再验。Astra仅后续核心播放优化提示。收尾约5.7GiB，下批先核空间、模拟器/同目录构建串行。

下一步：LibraryViews中的本机资料修改表单，整理草稿、输入错误和保存中状态；只复用控件/现有客户端事务，不把离线表单当真实纠错持久化验收。
