# Apple TV 临时加入核对与 iPhone13 中英文大字

更新：2026-11-01T19:31:34.257075+08:00。接[正式导出宿主](2026-11-01-EXPORT-NATIVE-HOST.md)，[结构化结果](../../../testing/results/2026-11/2026-11-01-APPLETV-REJOIN-AND-IPHONE13-LARGE-TEXT.json)。用户明确允许临时打开电视/Apple TV，与USB13继续开发，睡前可关TV；覆盖此前“13唯一/TV暂不需要”的设备范围。NAS仍恢复、连接及播放继续暂停，18/Pad不操作。原修改全保留；无NAS/VPN/系统/开发账号/配对资料或签名配置更改。

## Apple TV：开机与可调试分开

用户回复已打开后重新核现场：客厅，AppleTV14,1，tvOS18.2，已有配对；完整UDID与CoreDevice ID核相同但仅存私有。开发tunnel仍unavailable；原生RSD独立连接报告目标未发现。清单另有tvOS27模拟设备，不混作这台真机。

当前源正常tvOS Debug沿原项目/配置重建，未加allowProvisioningUpdates，exit65：缺com.changliwen.nastart.tv的tvOS App Development描述文件。保留旧包的profile目标授权仍在，但2026-10-31T05:46:14Z已到期；旧包与当前源不符，未拿旧包回归、未覆盖安装、未启动TV App或Runner。因此本轮0 TV最新包UI/遥控/性能验收，不能称App故障或播放失败。

只发一次Xcode Devices and Simulators恢复开发连接的人工动作请求，结果待；开机确认不等同开发连接恢复。签名还需有效profile，连接成功本身也不能越过包闸门，不改账号/配置绕过。TV可随用户关机，本轮不持有TV控制或采集后台任务。

## iPhone13：最新包闸门与两窗静态图

现场USB iPhone/iPhone14,5/iOS16.3.1，已配对；当前HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`、iOS dirty diff `994ca42ce4dcbed7900a67f756aba00d24c260ba576e0490c8b06745a132d449`，446输入均与前批冻结源一致。本批无产品/测试源码改动，不无故重跑已完成26＋4测试、六配置或5类旧失败预检。移动正常Debug包构建2026-11-01T18:42:00.071758+08:00至2026-11-01T18:45:06.340650+08:00，私有路径 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-11-01-export-native-host-183054/Nastart-Latest-Normal-Debug.app`，主SHA `8dbd451b31a19ed0fae703d3cff86f7dbc0ea4c43a2263ac884cbabbdea11db7`，Debug dylib `dd0b7b0a67de264bc13cf49efa650b062d9948e7fae74a450d3b59ce1119088c`。源/IPA/库签名/profile授权重新核，保留数据覆盖一次，2026-11-01T19:26:46.451253+08:00 InstallComplete/exit0/lookup；26非诊断偏好全同。未卸载/清登录。

正常签名包以显式privacy-export/glassDeck/dark/large，空环境分别启动中文与英文两窗。英文增加仅进程参数AppleLanguages/AppleLocale，未改系统语言。large实际映射accessibility2；两窗实际PNG已看：三项开关、完整隐私footer与导出按钮均在初始视口，未见截断，无需滚动才到动作。屏幕已有绿色辅助焦点覆盖层，保留现场不改系统设置；不以图片声称完整读屏/焦点验收。未点击分享、未读用户导出、非取消或真实分享完成验收。

每窗finally主动结束自有测试PID，fresh DeviceInfo证实不在；全偏好含diagnostics值均同。最新正常签名包留在13，测试参数未持久化；因普通入口会恢复旧NAS仍未默认启动，离线Form图不是普通首页/账号绑定验收。NAS0命令、0播放、0新模拟器或自有下载/采集后台。

## 接续与边界

优先等TV开发连接实际结果，恢复后仍须当前源有效签名包/保留数据安装，才做隔离设置、遥控焦点/返回；TV关闭或继续受阻则以13推进独立离线工作，不反复催同一人工动作。13缓存取消旧失败/手动补验、真实分享/读屏/严格匿名/密码显隐及Pad历史项保持；NAS恢复前不启动普通账号根或连接/播放。

已核唯一需求总账/114格矩阵，无新增播放P或需求关闭；播放实现/架构无改。原始设备身份、偏好、日志/图片、包与工具均仓库外私有，指针 `/tmp/nastart-appletv-rejoin-path`。
