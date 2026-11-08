# 11-04 目录逐级返回集成与 13 / iPad 回归

记录时间：2026-11-04T09:26:14.285829+08:00。结论：源码已接入审查分支，名称框仅首层显示接受；iPad有限离线交互通过，13子目录后超时仍未验收。未推送。

基线 `codex/ui-integration-20261103` / `cc296744625f68355a4260f1f940aaaf97bf840d`。主目录 main HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 与真实 index 保留；含 dirty 的当前输入清单冻结，不 checkout/reset/stash，不推送。

## 接受实现

Claude 原始增量仅 `LibraryViews.swift`，SHA-256 `4e90820cfe12292efce56fd9273408ba8272c1bcbec5b8b35aa02437e8646c64`；447 输入 1 改/446 同。精确单文件提交 `f8ce99ba31d22dbee59752b6f62c70baa60e486c`，父 cc29674。iOS 每级目录是真实 navigationDestination，系统返回/左边缘向右侧滑返回一级；新增连接的第一选择页退回表单而非直接退出。tvOS 仍 history 原地切换。

接受已有连接的名称字段只在第一层：该名称描述整个新媒体库；外层 @State 与选择回调在子页保留，子页无需重复编辑。文件夹 path 描述所选目录，两者独立。真实 model.addFolder/凭据/服务端事务仍须 NAS 恢复后单独验证。

取消闭包与原 identifier 逐级传入；子页取消关闭整个选择流程。修改路径首层保留上一级/返回修改页，推入的子层交给系统返回。saving 时隐藏系统返回、禁用取消/选择、阻止交互关闭；不在全局强开 interactivePopGestureRecognizer。

## Codex 隔离测试入口

另一个单文件提交 `1293a0dc637d3c39d1f2e43eabeac34ec6ee7775` 添加 DEBUG+iOS、显式 `--offline-ui folder-picker --offline-folder-navigation` 才启用的内存目录宿主，复用同一个真实 NetworkFolderPicker 及 WebDAV 连接表单。初始目录/合成名称/表单仅内存，未创建模型、网络 client、vault、Keychain 或存储操作。最终文件 SHA `3b9d492dba474345afdbb1886165befaa8697e2c5280dad92433a7665b4048a1`，不冒称仍是 Claude 的 4e 原件。447 当前输入清单 SHA `939409ac7d8fa482b5d483b77363ca1f5485f7403c5a190804bcca0e73e08d0a`。

新增连接的 fixture submit 为合成状态切换；已有连接/修改路径 select 仅改内存草稿并显示结果。由此可验真实共用选择器的 NavigationStack/手势/取消/路径与名称传递，不能代替生产 model 事务、NAS 目录/认证/保存、已存库编辑落盘验收。busy 用 8 秒合成等待后报错，不执行保存。

## 先前探索和签名授权

原始 Claude-only 源的六配置/签名包/两机覆盖保留在私有 claude-validation，后加 fixture 后均降为旧源证据，最终源重新构建/签名/逐机安装。自建 iOS26.5 iPhone13 模拟器通过按钮返回与名称/地址/端口保留；两次 Mac AX drag 无实际路径变化，记为注入未生效，既不算侧滑 PASS，也不定产品缺陷。该自建模拟器已删并核目录不存在；其它 Claude 实例未动。

用户明确授权“允许更新两台测试 Runner 的签名并部署”。仅用现有开发账号申请各目标 profile；旧夹具不改，复制已知兼容 universal Runner 到本批私有目录再签名，12 嵌入项及 root deep/strict 均核过。手机 profile 到 2026-11-11T00:42:31Z，Pad 到 2026-11-11T00:39:52Z；各自仅需覆盖自己的 fresh 目标，不以一张覆盖另一台。此授权不扩展到 18、TV、NAS 或账号/网络设置。

## 证据边界

仍保留前批 README 来源结论：与11-01独立快照同，继承文档差异，初始作者未知；未纳入本次单文件提交。447扫描里179条继承KSPlayer Demo/Pods不在审查树，不能宣称447全被Git树跟踪。

NAS发现/认证/恢复/目录/图片/媒体均暂停；18不操作；不关闭30项需求或添加114格播放 P。未改播放链路，无需更新 VIDEO_PLAYBACK_PIPELINE 实现。

## 最终构建与逐机安装

最终含 DEBUG 内存夹具的源码重新跑六配置（iOS模拟器/真机Debug/真机Release、TV模拟器/真机Debug/真机Release）均 exit0；447输入稳定。两端 Release 各31调试标记均0，移动Debug新增4标记为正对照，TV Debug新增4标记为0。Claude交付305项是原始交付自报，本批没有将它当作最终夹具源的新单测结果。未增加镜像实现的无意义单测。

正常 Debug -Onone 构建、30 Mach-O deep/strict及逐项签名、profile和IPA成员/CRC/哈希均通过。包主程序 `d91c38710b8276e84ebd06add9399001df1d495c3341a5a51b85aa4eb6852f45`，Debug dylib `e1956f398333c697eebf7b9b2e04e15142249525594f9f68b6c2eda14f88ff55`，IPA `e450fa18f09ec2b146768041b17a7a5c7f92386471f4a25d5e5a14840bc139ea`。正常App profile到11-08T01:08:19Z；无App profile更新/账号变化。完整包路径与清单在资源登记和私有证据。

| 设备 | 本轮 fresh 身份 | 最新包保留安装 | 安装与结束偏好 | 结果 |
| --- | --- | --- | --- | --- |
| iPhone13 | iPhone14,5 / 16.3.1 / USB、名称及UDID私存 | 08:58:56+08 Complete / fresh lookup | 26非诊断键及全部原值同 | 安全入口前台成立；子目录后的自动化超时，后续三项未验收 |
| A16 iPad | iPad15,7 / 26.6 / wired、paired、当前隧道及身份私存 | 08:59:10+08 success / fresh lookup | 19非诊断键及全部原值同 | 共用真实picker的内存UI交互通过；不是NAS/编辑落盘验收 |

运行前发现残留Nastart时，先fresh关联已装bundle的实际可执行路径/PID、保存偏好并再次匹配，再按既有用户授权精确停止；不接管未知Runner。Pad首个严格preflight因App存活停止、未装Runner，现场保留；记录中原before=None与after比较产生的false已注释为“未比较”，不当偏好变化。后续明确识别/备份/停止后正常部署。原残留启动来源未知，未据此推断零后台网络；本批仅启动源码确认的安全入口，未发NAS命令，也没有网络抓包测量。

## iPad 实际触摸结果

独占窗口09:08:20—09:16:43+08；有效Runner XCTest、目标身份、端口8104→目标8100、session和前台bundle/PID均核。环境为空；显式参数为 `--offline-ui folder-picker --offline-folder-navigation --offline-ui-theme glassDeck --offline-ui-appearance dark --offline-ui-text-size standard -AppleLanguages (zh-Hans) -AppleLocale zh_CN`。无正常账号根启动。

- 进入 `/→电影→精选→蓝光` 后，三次从弹层左边缘向右侧滑，实际path逐级变为 `电影/精选→电影→/`，名称框回到首层出现；不是直接退出整个弹层。
- 将名称改为 `PadRootName`，进入子页名称框不可见；侧滑回根仍为该名称。在子页选中 `/电影/精选`，内存结果同时包含原名称与路径。
- 从深层取消，整个合成弹层关闭；回到离线测试首页并显示取消结果。修改路径子页取消也关闭整个流程。
- 修改路径从 `电影` 起，进入 `电影/精选` 再侧滑回 `电影`；首层自定义上一级到 `/`，标签切成返回修改页；再进入并使用 `/电影/精选`，仅内存草稿结果正确。
- 新增连接从表单进入根和子页，两次侧滑依次返回根及原表单；名称、127.0.0.1、8089、路径 `/` 均保留。Pad弹层提交按钮起初不在可见区，守卫停止动作后仅滚动一次，实际位移/按钮出现才继续；未对隐藏按钮盲点。
- 合成处理中，系统返回隐藏，取消/选择/子目录禁用；同一边缘手势后仍在 `电影`，处理状态继续。8秒合成失败后，返回和取消恢复、错误可见、路径保留。

32组XML/PNG、20个路径断言，同一Nastart PID；8个实际边缘手势中7次有效pop、1次busy按预期保持。已实看关键子页、返回根、名称/路径结果、修改路径、恢复表单和busy截图。完整VoiceOver、旋转/分屏、帧时间和真实NAS事务仍未验。

## iPhone13 失败与边界

有效Runner已部署，安全入口及初始表单/目录前台可见。第一窗用pymobiledevice3 XCTest，第二窗换已知兼容tidevice旧系统通道，两窗在元素点击子目录后 `activeAppInfo` 30秒超时；随后USB `/status` 不响应，第二窗当前Runner广告的同机WDA地址也超时。各自原生诊断图仍在父目录 `/`，没有子页或侧滑有效结果。

两窗无改善后停止该点击链路；独立iPad W3C触摸全部成立提供新依据，才开第三个有界13窗，保持源码/Runner/时序不变，改用同一实际W3C触摸。仍于子目录动作后超时；没有重复侧滑或后续取消/修改路径操作。不能把Pad成功外推到13，也不在原因未证时改产品导航/加延迟。

随后被动进程查询Nastart已0，Runner仍在；退出原因未知，现有crash-copy只读目录没有本日Nastart报告，未flush/move/erase。尝试的sysmon采集只返回6个心跳/键字符串，不能作为CPU/主线程/帧时间证据。不能据此断言App崩溃、主线程死锁或测试通道根因。曾请求一次手动点按以区分，发现App已不运行后撤回；用户答现在不方便，未取得手动结果，不再要求操作或普通重开。

三窗原始失败留存；长期原生连接在收尾读取出现BrokenPipe也单列保留，不当App崩溃。结束用新连接fresh重核偏好及进程，13全部原值同、Nastart/Runner均0、转发清。最后窗结束09:23:41+08；iPad各窗结束也已核0。仅本批自有连接/转发/采集停止，未知8101旧转发未动。没有更改Wi-Fi/蜂窝/VPN/域名/端口/凭据；18/TV未操作。

## 当前接续

13：保留安装成功与安全初始页面证据，左滑逐级返回/子页取消/修改路径仍未验收。下一窗口须有新的诊断依据，或用户方便时一次有界手动观察；不再重复同一超时链路。真实目录/添加/修改持久化待用户确认NAS实际恢复后再依矩阵执行；预计本周修复不当已经恢复。

共享PROGRESS、当前交接、开发状态、唯一需求总账和资源登记随本批同步；播放矩阵只补“无新增P”的边界，播放链路未改。主HEAD/index及其它dirty保持，审查树312个iOS/TV路径仅README继承差异；179个Demo/Pods扫描项仍不在审查树。详细结构化结果见下方，原始证据/UDID/偏好/签名材料/包均仓库外。

[结构化结果](../../../testing/results/2026-11/CODEX-FOLDER-PICKER-INTEGRATION-20261104.json)。私有证据指针 `/tmp/nastart-codex-folder-picker-path`。
