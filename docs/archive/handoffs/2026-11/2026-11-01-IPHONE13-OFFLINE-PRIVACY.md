# 唯一真机切换到iPhone13：最新包与隔离隐私界面

更新：2026-11-01T18:27:23.218779+08:00。[结构化结果](../../../testing/results/2026-11/2026-11-01-IPHONE13-OFFLINE-PRIVACY.json)。用户明确iPhone13数据线接MacBook作为唯一真机，Apple TV必要时可开；本轮未启用TV、不再操作18或Pad。用户再次确认NAS仍恢复，NAS连接/播放继续暂停，不反复询问或复用旧凭据绕过。

## 现场、安装与启动身份

现场USB只读确认名称iPhone、iPhone14,5、iOS16.3.1(20D67)、既有配对/完整UDID相符，原始ID仅私有。当前源码沿[裸地址批](2026-11-01-EXPORT-BARE-ADDRESS-BOUNDARIES.md)：446输入全同、HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，dirty iOS SHA-256 `bf7ebee27846e8a13d2cdea5c2220cf36c14bbe135c34582996c5006796ca1ef`。本设备批无源码修改。前批23项纯生成/文本回归0失败、六配置编译过只引用同源证据，不重计为真机功能测试，预检5类旧失败保持。

当前正常Debug -Onone重建2026-11-01T18:13:07.640864+08:00至2026-11-01T18:13:53.820879+08:00、exit0；30个Mach-O/29库与deep/strict签名、IPA CRC/内容及target profile均核过。本机现有profile有效至2026-11-08T01:08:19+00:00、包含13，无账号/配置/profile变更。包路径：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-11-01-iphone13-offline-privacy-181219/Nastart-Latest-Normal-Debug.app`；IPA同目录，仅私存。

| 包身份 | SHA-256 |
| --- | --- |
| Nastart | `aa256fad59de3c3bdf0a25fa9a279157be03e9a65c868b45af5d718f5b5beafd` |
| Nastart.debug.dylib | `8e4d035dea8153f40c72ef3057ce1502403153866f5c5dada99b92f8ea252cf3` |
| KSPlayer | `97f19100f66ff165ff4238cf8adeecff42db00eb4724daca17e6b4c3494e745d` |
| IPA | `efcdded5a1a37819974cba7774f47f09f50db0c1c429f6605dcfd244e4d513da` |

已备份必要故障/偏好，旧安装身份无法仅靠版本确认，执行一次保留容器USB覆盖，2026-11-01T18:15:27.512048+08:00明确InstallComplete/exit0、lookup成立；不卸载、不清登录/书签或真实缓存。26项非诊断偏好安装前后全同。源码/hash在安装和各离线启动前再核。根最新正常包/当前源评估已指向本包，18前批7304/379e收据保持且不含新改动，不能混淆设备。

普通空参数入口会创建AppDataStore/NASConnectionStore并恢复旧DSM会话，用户暂停NAS，因此**本批未启动普通入口、未验普通首页/正常启动回归**。只以空环境和明确 `--offline-ui privacy-cache --offline-ui-theme glassDeck --offline-ui-appearance dark` 测试参数启动同一正常包；原因/配置/归属留证，不当默认启动结果。DEBUG早分支在正式store初始化之前，只挂离线根，共用真实缓存确认Modifier但清理回调仅改内存。结束后测试进程已停止，参数不持久化、最新正常包仍保留，无测试环境变量遗留；为遵守NAS暂停不额外普通重启。

## 原生观察与保留失败

现有WDA端点不ready，设备查询有Runner但没有读到其有效profile；本地旧Runner描述文件已于2026-10-25到期。本批未改签名/账号、未重装或反复启动WDA，不能仅凭安装列表说可用。

改用原生DVT/AXAudit。首次ActivateSuspended=true返回PID，但实际截图/AX是SpringBoard，不是App，因此不当界面成功；未发任何动作。最初脚本在实图确认前枚举了错误前台，属于工具守卫不足，结果只私存且作废。随后加明确离线页面/弹窗文本上下文核对，实际动作前验证同一PID和当前原生元素。首次立即查询bundle PID不能证明进程退出，fresh DeviceInfo后确认旧PID已不在，不据false即时值宣称清理失败或仍后台运行。

iOS16既有tidevice实现说明ActivateSuspended=true可能只建后台PID，独立false配置启动后实际看到隐私页、离线标记、完整清理说明和“取消”按钮。原生元素共四项；第一动作守卫因焦点循环从说明开始而未收齐标题，0动作、失败保留。完整循环核对上下文后只派发一次Cancel，接口返回，但一秒后实图弹窗仍在，故**取消交互未通过**，不把请求成功当UI改变；未触发清理。不能据此判客户端Cancel缺陷，也可能是原生AX激活能力限制，不尝试不同私有selector或放宽系统权限。

已一次请求用户手动取消，尚无确认，本批不反复催促；180秒安全窗口到时已停止自有App，后续若弹窗已关闭须重新建立离线窗，不把超时停止当取消成功。正式清理/真实导出/分享/凭据及NAS均未执行；仅测试代码路径隔离，未作包级网络采集，不宣称手机全部网络请求为0。

## 收尾与后续

最终DeviceInfo确认自有测试PID不在；测试前后全部偏好值（含诊断）相同，26非诊断项全同，无原值回写。没有媒体播放/下载/自有后台采集，没有新定时任务。实际图可见Wi-Fi图标，未切Wi-Fi/蜂窝/VPN；不把当前信号格数或用户先前弱蜂窝报告升级为本窗无线测量。

后续仅使用13离线调试；Apple TV暂不需要。普通启动/真实ShareLink/账号/DSM/媒体验证待NAS恢复，手动取消或有效交互自动化能力仍待补。缓存prompt有限显示不等于真实清理/取消事务验收；其他既有密码显隐/Pad图与114格问题保留。已核唯一总账、播放架构/矩阵无路线变化，无新P，不清旧失败。
