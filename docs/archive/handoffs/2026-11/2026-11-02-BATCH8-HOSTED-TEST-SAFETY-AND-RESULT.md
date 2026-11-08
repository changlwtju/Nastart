# 第八批 app-hosted 测试：NAS暂停条件下的安全核对与结果

2026-11-02。用户明确要求检查宿主启动和模拟器已保存状态，确认安全后执行`RUN_TESTS=1 bash ~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch8/run-verify-batch8.sh`。本轮由Codex执行，未改产品、测试、工程或脚本，未操作真机/NAS/VPN/配对/签名；不代表第七/八批补丁已正式集成。

## 安全判断与实际隔离

审查的是脚本实际指向的独立工作区`/Users/lagransun/workspace/Nastart-Claude-Closures-20261102`，不是仅凭集成目录同名文件推断。参照[第八批交付](2026-11-02-0945-CLAUDE-BATCH8-DELIVERY.md)、[前次只编译结果](2026-11-02-1005-CLAUDE-BATCH8-COMPILE-RESULT.md)。

- `NastartTests`的`TEST_HOST`为Nastart App；生成的xctestrun启动参数为空，没有早期离线入口，也没有自动因XCTest存在而跳过普通根的保护。**app-hosted会启动宿主，不能无条件放行旧模拟器。**
- `NastartApp.swift`普通根创建AppDataStore、NASConnectionStore等，并在`.task`调用`restoreDSMConnection`；scene active还有监控/前台刷新。若已有NAS凭据，可能认证、读取及失败后发现回退，NAS暂停期间不可执行。
- `AppStateStores.swift`的恢复方法先`loadCredential()`，缺失即返回，发生在登录/发现等I/O之前。初始化在无持久快照时采用`DisconnectedAppDataProvider`，其服务列表为空；`refreshServiceHealth`没有候选则返回。无会话且无凭据时前台刷新也返回。CloudSync默认关闭，初始构造不启动同步。
- 只查“没有NAS密码”还不够：手动服务/持久快照可能触发服务探针，所以还要排除旧App容器、服务地址与缓存。Keychain归属、Agent/Jellyfin状态与环境注入也分开核对。
- 脚本要求的`iPhone 17 Pro / iOS26.5`在开工清单中不存在。创建本轮专用同名设备，未重命名/清除现有设备。创建前空间约6.58GiB；启动前应用数量0、Keychain文件0；启动后只读SQLite查询NAS/Agent/Jellyfin服务匹配0（含`CAST(svce AS TEXT)`复核），无已安装App与Nastart数据容器。无继承的`NASTART_*`/`SIMCTL_CHILD_*`变量。
- 所选5个Appearance测试用唯一临时UserDefaults域及空通知回调；4个Privacy测试用注入步骤与UUID临时目录，未调用生产缓存清理组合、账号或NAS客户端。

因此本次可在该空白模拟器上运行原脚本。结论限于本轮源、宿主配置和空状态；不能追溯证明旧app-hosted测试安全，也不能用于有保存凭据/服务地址的实例。未增加网络封锁、测试环境变量或产品启动绕过；未抓包，不能声称独立测得全部系统/网络请求为0。

## 实际执行与结果

脚本2026-11-02 10:07:50–10:15:08（+08:00），使用Xcode27；iPhone17 Pro模拟器运行iOS26.5（23F77），非任何真机。旧只编译RESULT已保存到本机私有证据，再由脚本生成新结果。

| 项目 | 结果 |
| --- | --- |
| Debug build-for-testing，App与NastartTests | exit=0 |
| Release build | exit=0 |
| Release标记：OfflineAppearanceHost、nastart.offline-ui.appearance、offline.appearance.readback、offline.privacy.cache-counters | 各0命中 |
| AppearanceStoreInjectionTests | 5/5通过 |
| PrivacyCacheCleanerTests | 4/4通过 |
| xcresult汇总 | Passed；9总数、9通过、0失败、0跳过、0预期失败 |
| 原脚本及用户指定命令退出码 | 0 |

RESULT的测试阶段只有`exit=0`，没有逐条测试结果：脚本grep匹配`Test Case`/`Executed`，实际Xcode输出是小写`Test case`。读取`logs/B4_xctest.log`确认9条passed，再用`xcresulttool get test-results summary`核实际计数；没有修改脚本、RESULT或重跑凑数。不能只依赖顶层脚本exit0：它没有`set -e`，各阶段状态须分别读。

编译仍有KSPlayer actor隔离等警告，未在本轮修复；静态过滤输出中的`Error?`类型行也不能当实际编译失败。测试只覆盖注入存储/步骤逻辑与临时文件，不证明真实设置页面交互、生产WebKit清理、取消零副作用或完整缓存/播放验收。

## 身份与收尾

6个交付文件起始SHA与第八批交付一致；本轮额外冻结的212项App/测试/NetworkMedia/脚本输入在运行后全部相同（不是新的完整发布构建清单）。主集成源码未接入本批修改。

测试日志出现`Clone 1`，xcresult将结果归于本轮创建的目标设备；执行前后默认simctl清单未出现额外留存实例。记录的测试宿主PID已不存在；基础实例最终NAS/Agent/Jellyfin Keychain匹配仍0。初次shutdown返回149，fresh读取发现实例已Shutdown，按实际状态删除；删除后默认清单与数据路径均不存在。仅清理本轮拥有实例，既有模拟器及Simulator.app未关闭；不把shutdown非零隐去。

私有证据入口`/tmp/nastart-batch8-hosted-tests-path`，含前后清单、安全检查、旧/新RESULT、B4原日志、xcresult摘要和清理结论。原始数据及设备标识不导出。[可分享结果](../../../testing/results/2026-11/BATCH8-HOSTED-TEST-20261102.json)。

资源登记释放本轮构建/模拟器窗口，无新增产品/设备权限。NAS仍暂停、18 hands off、TV阻塞保持；唯一需求总账及114格矩阵无相应新验收，不新增P。后续以第七/八批实际交付核基线/补丁及正式集成，真实UI与真机回归仍需独立窗口。
