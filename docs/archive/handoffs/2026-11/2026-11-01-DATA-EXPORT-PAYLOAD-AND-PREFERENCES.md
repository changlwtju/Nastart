# 数据导出完整生成函数与偏好校验

日期：2026-11-01。承接[诊断隐私及导出盘点](2026-11-01-DIAGNOSTIC-PRIVACY-AND-PERSISTENCE.md)。NAS恢复期仅本机代码与合成数据；0真机发现/控制/安装、0真实偏好/凭据/导出读取或生成分享、0NAS/播放/源写。未启动普通App/模拟器，不改NAS/VPN/系统/开发账号/profile，沿既定模型分工，无Astra/定时/后台任务，原脏树保持。

## 接受的实现

在MineView内增加纯DataExportPayload，正式DataExportView直接调用同一生成函数；不是仅供测试的复制实现。Selection控制三个范围的懒快照读取：启动台、待办/历史、偏好只在对应选中时读取。View继续从原dataStore和原UserDefaults键提供值，ShareLink、三个选择绑定、禁用/提示、主题和导航源码逐字节保持；hasExportSelection委托同一个Selection计算。

Preferences用实际LaunchpadTheme/AppLanguage/AppThemeMode的rawValue初始化，非法/缺失值回退cleanGrid/system/system；两Bool保持原缺失时true和显式false语义。不回写原偏好。提醒kind仅在ReminderKind四种现有枚举内导出，未知/空/nil省略这个原本可选的字段，任务和存储原值不变，不伪造默认类型。未来未知类别的raw字符串因此不再出现在本版导出，其他提醒字段继续保留。

formatVersion仍1，原metadata、分组/字段名、ID、精确日期、pending/history顺序和有效设置不变；正常合法样本匹配完整version-one黄金JSON对象。服务仍仅投影name/category/visible，提醒显式列字段，不自动编码整个模型；名称/标题/目标继续用既有脱敏。原ID/日期和普通自由文本仍保留，绝非严格匿名或无损备份承诺。诊断脱敏/持久化、模型枚举、真实状态与播放链路均未改。

## 受控验证与红绿证据

新增10项完整生成测试，配合8项既有文本回归，共18唯一方法；另有8种选择输入、27种有效偏好笛卡尔组合，不能把这些循环样本累加成35个独立UI用例。检查选中字段/数组、未选不读、全不选metadata及hasSelection=false、非法秘密字符串不进入偏好、默认/false保持、四种提醒类型、未知kind省略且输入原值同、可选日期/历史顺序、字段白名单、确定性/ID日期关联和完整强类型JSON解码/黄金对象。

从实际MineView提取完整生成器、从真实模型/枚举文件提取ServiceCategory/TaskItem/三个偏好枚举/ReminderKind，连同实际脱敏静态方法和当前18方法体，在私有临时macOS Swift package执行。仅将ReminderKind中未用于导出的LocalizedStringKey标题类型用String兼容；不构造AppState或访问UserDefaults。旧版适配器保留原exportText/taskExportValue函数体，只把数据/偏好读接合成供给者、时刻接固定夹具，接口适配明确记录，非旧App真实运行。

最终同组旧实现16过2失败（非法偏好和未知kind），接受实现18过0失败；旧21条断言失败不当21个唯一用例。完整黄金JSON加入前后结果分存，同一18方法最终再核，不重复计覆盖。新生成器及两个旧函数原文、基线/接受方法体/日志/时间/hash留本机私有指针 `current-data-export-payload-private`。没有真实用户数据、偏好套件、App启动或分享，不能把这些测试当实际ShareLink、完整原生宿主、读屏或真机验收。

## 构建、身份与收尾

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，446输入仅MineView/NonPlaybackPolicyTests两个既有文件变化，其余444个hash同，无新工程/源文件。旧测试方法体保持，其他MineView页面和分享Form保持。最终双端模拟器Debug、双端设备无签名Debug/Release共六项exit0，均从最终冻结输入开始；源码、构建时间及模拟器产物主二进制/Debug dylib SHA-256已核记录，0新模拟器/图/安装。

手机缺开发profile、TV旧profile阻塞保持，本轮未重试普通签名、未冻结新候选。旧包身份不改且不匹配最终源，根清单评估已更新；本轮不重复核旧签名，不把无签名编译当可安装包。沿2GiB运行保留线，不清用户缓存/资料，最终空间见[共享结果](../../../testing/results/2026-11/2026-11-01-data-export-payload-and-preferences.json)，无自有后台构建/采集。

已核对架构、唯一需求总账、114格功能矩阵与离线场景：无播放/场景/参数变化，不制造新P或重复改架构/矩阵状态。前批日志18项/报告工具130项属其各自输入，本批未无故重跑或升级旧结果。

## 接续边界

完整纯生成函数的选择组合、偏好/类别校验与正常schema已有本批证据；实际UserDefaults/dataStore绑定、ShareLink分享/取消/目标App、完整宿主/读屏仍待。旧缓存静态迁移、无scheme裸地址/带点文本误识别和未知字段隐私边界仍开放，严格匿名尚未实现。

Pad采图继续阻塞，不重复同样CUA超时；工具恢复后补Pad页脚/设置关联窗、连接管理和诊断说明。密码显隐、缓存显式取消、真实保存和全部真机/NAS播放继续暂停或待验，不复用旧凭据绕过。
