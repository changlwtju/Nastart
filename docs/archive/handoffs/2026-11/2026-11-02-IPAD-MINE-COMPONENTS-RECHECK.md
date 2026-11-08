# iPad退出确认后：新包覆盖与实际组件大字核对

2026-11-02，Asia/Shanghai。[结构化结果](../../../testing/results/2026-11/2026-11-02-IPAD-MINE-COMPONENTS-RECHECK.json)、[前批集成](2026-11-02-CLAUDE-BATCH1-INTEGRATION-AND-MINE-UI.md)。私有指针 `/tmp/nastart-ipad-mine-recheck-path`，原身份/偏好/应用路径/图片仅本机。

用户明确回复“已退出Nastart，可继续核对”。01:35 fresh CoreDevice重核名称、完整UDID、iPad15,7/A16/iPadOS26.6、wired/paired/connected；446源码输入及b946源diff、当前正常Debug包签名/profile重核。第一次检查仍见1个Nastart进程，于01:36在安装派发前正确停止，原失败保存，没有沿用户回复跳过进程检查。

随后将进程可执行文件与fresh app lookup的com.changliwen.nastart实际安装URL精确绑定，并核开发构建及当前Codex独占窗口，才将其确认为用户已退出的本项目App进程。先保存进程诊断/原偏好，停止前再核同PID/同实际可执行路径，01:38仅停止该目标，fresh Nastart0。不是停止未知/另一会话进程；Claude无任何设备许可。首次本地检查错误假设安装目录名必须Nastart.app而失败，未派发停止；实为冻结包的目录名称，修为bundle ID及fresh URL精确关联后再执行，错误和修正均留存。

01:39:02–01:39:12保留数据覆盖，Install success/exit0与fresh bundle lookup成立，未卸载/清登录。正常Debug/-Onone包01:11:16–01:12:02构建，main `a03b284f9428c830aab4ce03c3c37cdc16aecfa08c6109ee6c8ee73e01382f89`、debug dylib `6a588beffff1cd3ab979fb5f459ff8445941aa141b0c28ec04b49044237022f9`；包路径在前批私有current-package清单，全部签名/目标授权及源哈希已重核，无新源码或重构建。安装前后19项非诊断偏好一致，全值含诊断亦同。

01:40:01–01:40:26四个独立原生窗：mine-info/diagnostics各中文accessibility2与英文standard。每次启动前核无Nastart、无terminate-existing、无测试环境；显式离线参数和进程语言覆盖，不启动普通根。四张真实截图已看：竖屏退出/说明行无明显截断；大字诊断三操作/指标纵排，123/4/2及时间12:34:56均可见，本台初始视口未被底部DEBUG标记遮挡；英文标准三操作及摘要横排。标记与合成控制是测试宿主，不能当完整正式Mine/诊断页或真实连接状态。未点击说明、复制/清除/分享，未旋转/滚动/完整VoiceOver/帧时间验收；不追溯修正手机初始视口页脚遮挡结论。

每窗finally停止对应本方PID，fresh均无Nastart；从停止残留进程前到四窗最后，全部原偏好含诊断一致，19项非诊断保持。原生启动成功仅为显式隔离参数，普通入口会恢复NAS故未验；正常包留机，无自有采集/Runner/模拟器或后台任务。NAS暂停不因截图中第三方恢复进度而解除，未发起NAS/媒体/蜂窝任务、未操作13/18/TV。

iPad准备状态更新，Claude设备运行窗仍未授。接续读取用户新提供的Claude第二批交付并审查；不将当前Pad静态证据算作TV新补丁的验收。114格及需求编号不变；旋转/交互/完整读屏、真实宿主/分享完成保持开放。

补核自动化工具：本机既有iPad WebDriverAgent Runner profile至2026-10-25 12:00:45 UTC，已过期且不含本轮A16 UDID；仅离线读取profile，没有安装/启动Runner或改签名。因此不能沿旧Runner直接做当前A16旋转/触摸回归。此阻塞属于自动化Runner，当前正常App profile仍有效、四次隔离启动成功，两者不混淆。
