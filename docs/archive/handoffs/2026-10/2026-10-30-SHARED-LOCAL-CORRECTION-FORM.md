# 本机资料修改表单共用与状态整理

更新：2026-10-30T09:07:56+08:00。NAS恢复期，仍6.1；仅本地代码/自建隔离模拟器。0真机发现/安装/控制、0NAS/旧凭据/播放/源写，无后台任务。

## 实际实现

NetworkMediaCorrectionView改用同一NetworkMediaCorrectionForm，三端正式页面和Debug隔离场景直接挂真实表单。页名与入口对齐“修改本机资料”，分影片资料、仅剧集显示的季与集、本机操作和保留的原识别资料。字段保留可见标签、原accessibilityIdentifier与键盘下一项路径；标准手机标签和值同排、辅助字号上下排，Pad常规宽度和TV把年份/类型双列、季/开始集/结束集三列，长文本随内容换行，沿原主题表面/暖色图标和共用主按钮。只明确修改本机显示，不承诺在线匹配/封面补齐或修改NAS文件。

错误单独放输入前并说明填写内容保留；六项草稿实际变化清除旧错误，不清输入。更新中独立ProgressView，禁用输入/保存/恢复/取消；save和restore再加!saving守卫避免重复提交。TV页的backAction在saving时不调用取消，移动宿主interactiveDismissDisabled(saving)。这些属于实际接线及代码约束，不冒充已验证遥控/滑动/读屏。页面仍保留待复核的版本提示及原识别资料，恢复仍调用原model.restore，不新增NAS请求。

数字解析、LocalMediaCorrection.Values构造/校验完全保持，model.correct的expected:file和restore的file.path保持；正式View以外原LibraryViews源码保持，store/模型/识别/连接/播放/演员及前批组件不变。只3既有源（LibraryViews、OfflineUIScenario、OfflineMediaScene），435输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；继承未提交修改保留。未改播放链路，路线文档无变化。

## 有限验证与失败记录

4既有离线参数测试和10既有LocalCorrectionTests过；后者用临时客户端存储核原始NFO不变、持久化/恢复、版本不足复核、陈旧编辑、取消、坏字段、写失败保旧、预算、TV目录迁移/恢复等，不是三端正式交互或NAS事务验收。最初筛选器误写LocalMediaCorrectionTests，实际只运行4参数测试；随后以真实类名单独跑10例，未把不存在类名算覆盖。没有新增镜像UI测试。

双模拟器Debug、双普通签名Debug、双无签名Release构建过；冻结后435输入hash保持，30/27 Mach-O核签与TV嵌入库检查过。普通Debug候选没有测试参数/环境，未装真机，root清单已更新。

四场景correction-movie/episode/error/busy直接挂实际表单，只有合成字符串、内存回调和原识别资料文字，无真实model/store/client/Keychain，也没有启动保存/恢复任务。各端4静态窗，共12，跨三主题深浅色并含手机/Pad错误大字。手机大字错误初轮OCR把感叹图标插入换行句中，严格字符串匹配超时；实图文字正确，保留失败图/日志不作合格窗。只规范OCR的感叹标点后以相同二进制补缺的手机错误/处理中两窗，保留先前合格的电影/剧集两窗；之后首次完成Pad/TV。未为采图改产品或重复已过窗口。最后全部截图hash/预期文本/连续背景和实图检查；静态窗不证明完整滚动、焦点/键盘、真实取消/保存/恢复、错误清除或读屏，不能将大字首屏外的操作区称已见。

4任务自建实例（首手机、补手机、Pad、TV）全部shutdown/delete，fresh列表无；合成偏好哨兵保持且无额外应用键，其他实例/真机未动。原图/包/命令/路径仅留仓库外current-correction-form-polish-private。收尾空间约6.0GiB，下轮先核空间、模拟器与同目录构建串行。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T08:59:04.836605+08:00 | `828ab95755821ef445bbbb19c39c451dc52479f488cc4c7de7e2dde593497d5b` | `b067578443e71893d0086b5e85d39bcd755ce5872f06c8d2fef0b429f8846082` | 30 |
| Apple TV | 2026-10-30T08:57:36.975219+08:00 | `002a255ce57e9d7b701bce32e2575dcc9f430b9c5425699b7bbfd52e0fb80168` | `c2c253959e55ea11d34738cd8b26bfc44e9a9f61111b30158ef01537a4eda59f` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-30-correction-form-polish.json)／[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。播放矩阵已核，本批不改播放能力或新增114格P；真实图片/目录事务/返回闪动/大文件/弱蜂窝仍待NAS安全恢复。Astra仅后续核心优化提示。

## 下一步

整理NetworkFolderPicker的当前路径、读取中、目录/保存失败和无子目录说明，并核保存时的返回边界。现有代码TV onExit仍可绕过禁用工具栏调用back；选择Task读取可变directory；根不可选时空目录说明仍称可直接选择。这些是代码审查发现，尚未修改或宣称已复现真机故障。沿原只读源和路径权限，离线根仍不得构造真实账号/存储或探测NAS。
