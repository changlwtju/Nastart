# 正式导出表单接隔离宿主与系统分享取消

更新：2026-11-01T18:58:24.103331+08:00。接[仅13环境/缓存取消未验](2026-11-01-IPHONE13-OFFLINE-PRIVACY.md)，没有等待该支线而停止独立工作。[结构化结果](../../../testing/results/2026-11/2026-11-01-EXPORT-NATIVE-HOST.json)。用户指定USB13唯一真机、NAS仍恢复/暂停；本轮未启用TV/18/Pad、未发NAS连接/播放测试或源文件写操作，不改网络/VPN/开发账号/profile。原未提交修改保留，无定时/后台任务。

## 实现与范围

此前隔离导出页只有共用Toggle和假的成功提示，正式DataExportView又依赖AppDataStore；直接初始化该store会读取/迁移本地快照和安排提醒，不能为测试分享绕过暂停。现将实际Form、三项State/选择行、ShareLink和禁用/提示统一为NastartDataExportContent；正式私有View仍提供原dataStore投影及UserDefaults标准设置的懒闭包，未选范围不读，原schema/字段/顺序/生成器主体逐字节同。

Preferences.read(from:)用原五个设置键读取传入套件，不回写非法值或未知键；生产闭包传standard，单元测试只传新建唯一合成套件，未读真实App偏好。三个测试核两独立套件/真实键和Bool、非法与缺失回退且原字典全同、选择关闭不调用读取。原23方法体同，现26过；不是完整原生账号绑定验收。

DEBUG新增privacy-export显式场景复用同一正式Form和真实ShareLink。只给固定合成服务/提醒/偏好，未创建AppDataStore/NAS/钥匙串/云/发现store；表面样式显式注入，绕过需要AppearanceStore/EntitlementStore的全局主题modifier，生产nil分支仍沿原主题/列表modifier。离线标记在安全区，不出现在普通页面。TV该场景保持只读隐私说明，不伪造TV系统分享能力，Release不含该场景。未知参数仍走隔离invalid根。4项既有解析测试含allCases新场景及错误参数防回落，全部过。

## 构建与同源身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，dirty iOS diff SHA-256 `994ca42ce4dcbed7900a67f756aba00d24c260ba576e0490c8b06745a132d449`；446输入5改/441同，无新源文件。最终两端模拟器Debug及设备无签名Debug/Release六配置过，另正常移动Debug签名构建2026-11-01T18:42:00.071758+08:00至2026-11-01T18:45:06.340650+08:00过。30个Mach-O/29库、deep/strict签名、IPA内容/CRC及目标授权/profile有效期均核过，不改签名配置。私有包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-11-01-export-native-host-183054/Nastart-Latest-Normal-Debug.app`，IPA同目录。

| 身份 | SHA-256 |
| --- | --- |
| Nastart | `8dbd451b31a19ed0fae703d3cff86f7dbc0ea4c43a2263ac884cbabbdea11db7` |
| Nastart.debug.dylib | `dd0b7b0a67de264bc13cf49efa650b062d9948e7fae74a450d3b59ce1119088c` |
| KSPlayer | `1c34670d7ec028dcc4f3e0416c5fc29a7b360fd1c82f4c1239e4b7a9a84df92c` |
| IPA | `38fe5ecc45b225c0d97de37dab72f2724a7f12702f649f2bd65801862b80469b` |

完整预检仍10过/5类失败，与前源同类；raw字符串简易括号扫描、ATS、图标注册/fixture及旧方向规则未改，不写全绿。源/测试/构建/工具、所有旧失败及原始设备偏好仅本机私有证据；指针 `/tmp/nastart-export-native-host-path`。

## 模拟器实际操作：一条独立流程

只创建一个自有iOS27手机模拟器，非18真机，保持13唯一实机约束。装当前源冻结模拟器包并核hash，种两项合成哨兵。CUA实际显示正式表单：111初始；首坐标点击只激活窗口，未误判000，实看100后用新AX switch到000；零选择按钮disabled且提示可见。只开偏好成001，按钮恢复；点一次ShareLink，首次即时观察未见面板，后一次完整观察确认异步系统分享popover，未重发。

面板显示文本分享预览和系统操作，未选任何外部目标、未复制/保存或生成用户导出。对实有PopoverDismissRegion执行Cancel，实际面板消失，再完整AX核表单001和按钮enabled保持。该一条流程只证明隔离宿主下真实ShareLink呈现/取消返回，不把8种纯生成选择组合算8个原生UI用例，也不升级为真实Share完成、目标App、账户、完整读屏或物理iOS16交互验收。

启动预算6GiB/运行保留2GiB，结束App、关闭并删除仅本轮自建实例，fresh清单确认不在；两合成哨兵保持，无额外App业务偏好键。未关闭其他模拟器、未改剪贴板或外部分享。实际图/AX在私有证据与工具轨迹保留。

## iPhone13最终最新包核对

源码改后重新现场核13名称iPhone/iPhone14,5/iOS16.3.1(20D67)、USB/配对/完整UDID（私有），当前源与冻结包再核，保存偏好后一次保留容器覆盖；2026-11-01T18:51:10.267354+08:00InstallComplete/exit0与lookup成立，26非诊断偏好全同，不靠版本号。

仅以空环境及明确 `--offline-ui privacy-export --offline-ui-theme glassDeck --offline-ui-appearance dark` 启动正常包，iOS16原生DVT选已验证的ActivateSuspended=false，实际看见同一正式导出表单、离线标记、三开关/隐私说明/导出动作。本窗未在真机点击分享或读用户导出。App已停止，fresh DeviceInfo证实测试PID不在，全部偏好值含诊断同；正常签名包保留，参数不持久化。普通入口会恢复旧NAS会话，仍不启动/不验收普通首页，不能把该离线图当默认基线。

## 接续

此前13清理确认的原生Cancel无实际关闭仍未验，手动请求仅发一次且无回报，不重复催促、不用本次模拟器分享取消覆盖该失败；WDA签名到期不绕过。真实标准偏好/账号store绑定、真实分享/目标App/读屏、缓存清理事务/取消、严格匿名、密码显隐、Pad历史图仍开放。

唯一总账、播放架构和114格已核：无播放链路变化，不新增P或关闭编号；NAS恢复前只用13做隔离开发，TV暂不需要。后续可补手机/大字布局及独立交互证据，NAS/账号/媒体只在环境确认恢复后再逐机核包。当前无自有测试App/模拟器/构建或采集后台任务。
