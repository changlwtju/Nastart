# WDA USB结构化集成与现有会话只读核验

2026-10-20，接[查询/动作边界](2026-10-20-WDA-QUERY-ACTION-BOUNDARY.md)。关联PX-06，28项开放不变；[结构化结果](../../../testing/results/2026-10/WDA-USB-SESSION-INTEGRATION-20261020.json)。

## 已完成

新增[USB/session适配器](../../../../scripts/wda_usb_session.py)和[集成测试](../../../../scripts/test_wda_usb_session.py)。USB连接延迟打开，原HTTP状态/响应体保留给既有guard分类；UTF-8按字节长度发送，正常、HTTP错误、解析失败和超时均关闭连接，transport自身不重试。提供私有reply保存钩子，新私有助手在分类前保存HTTP/协议错误原文；保存失败同样关闭连接/阻止继续动作。session限定命令，拒绝跨session响应、任意激活/设置修改；只读前后核实际bundle/PID/方向，固定defaultActiveApplication时拒绝把该结果当真实前台。观察是串行快照，不能承诺原子锁住场景。

加入独立UI观察：每次新读source、PNG和前后scene。UI transition verifier只接受明确控件由无到唯一可见可用/由唯一到无，同时要求新截图字节变化、私有保存成功，且只能使用一次。PNG签名/字节变化及控件状态不代表电影内容或实际暂停；恢复电影、时钟、音频和帧时间仍分别验。

私有证据指针`/tmp/nastart-wda-usb-integration-evidence`，新`tools/nastart_guarded_native.py`接此USB/session/guard；旧工具和旧失败文件不改。新助手不把查询异常转换为空列表、不自动触摸容器；目标缺失即停。显式重显还需系统树及四控件查询均无目标，按预期播放意图验证三控件和新图；一次未核即阻断，不能继续重显。暂停/恢复点击仍必须传独立实际效果回调，不能用UI transition确认代替。

36项单测在系统Python3.9及Homebrew3.14通过，其中19项是新增USB/session集成；另8项私有助手集成通过。旧Pad实际404响应体保持原字节，经内存HTTP/socket进入新传输：查询重读后模拟空目标，无真实恢复；查询耗尽不会变成容器点击，同一404作为动作响应时一次发送后封锁。还覆盖错误/超时关闭、固定App伪前台、scene/session变化、未知可见性控件阻止重显、HTTP200但界面不变、截图未变及保存失败、重复verifier。早期测试替身在HTTPResponse构造阶段抛错引发析构告警，改为读响应阶段抛错；最终两个runtime无告警。没有为此重复旧电影窗口。

## 21:07 iPhone13现有会话实测

先重新核现场名称/型号/系统/UDID及USB连接（私有全值），iPhone14,5/iOS16.3.1；173个输入、iOS diff、16:16普通Debug包三二进制/深签名匹配，复核此前保留数据安装成功及正常首页receipt。复用该可信安装，未重建/重装，不称重新验过App首页或播放。

新transport读取现有`/status`/session，defaultActiveApplication确为auto；读出当前原生设置App/PID、竖屏source/PNG并前后核同scene成功。没有创建session、App启动、点击、WDA设置/网络修改或媒体请求。当前原生无线局域网页选中网络与私有原SSID精确匹配，实际截图状态栏Wi-Fi图标可见；此项是本批重新观察，区别于19:58历史收尾。Pad本批未探测，旧Wi-Fi/安装/偏好/崩溃结果仍为历史；18离家不操作。本批未重新拉偏好/崩溃清单，不补写零新增。

## 下一步与效果证据边界

USB真实只读链路已接通，但尚未在真实PiP树验证新助手，13恢复目标缺失、Pad查询stale及延迟旋转黑图不关闭。下一步先完成暂停的私有独立效果适配，再评估一次有界定向窗；不因44项离线检查和设置页成功就重播。

源码复核发现：DiagnosticLogStore以固定750ms批次异步持久化；KS telemetry的ksPlayerState使用本次可选state参数，周期采样可以是`-`；镜像planID仅8字符，不能冒充完整UUID帧归属。效果适配须以新事件身份/同playbackTrace与plan、实际采集边界及原生控件结合，旧偏好内容、文件mtime或deltaSeconds=0均不足以证明本次暂停；时钟也不替代真实恢复画面。未改这些App实现，不为观测而添加无依据产品补丁。

HDR/API119/弱蜂窝/竞品等沿既有优先级，无新结果不制造状态。PQ/HLG保护和16:16普通包保持。详细字段只在本文件和结构化结果，PROGRESS/当前交接仅保留接续摘要。

收尾检查：36项单测在两Python通过、8项私有集成、15项preflight通过；文档357份/1856本地链接/缺失0，git diff --check通过。iOS差异保持冻结，自有本机证据区进程0，临时保活随只读命令结束。
