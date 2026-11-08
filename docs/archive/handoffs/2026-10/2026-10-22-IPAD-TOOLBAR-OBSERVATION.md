# iPad菜单实际命中目标与新FileStation失败

2026-10-22 08:38。接[前批两次工具失败](2026-10-22-IPAD-FILE-SORT-CURRENT.md)，[结构化结果](../../../testing/results/2026-10/2026-10-22-ipad-toolbar-observation.json)。无App源码/构建/安装/测试重跑、无新通用工具封装；只修本机私有助手选取的实际原生目标并补已有CLI规范。18继续按用户安排暂缓。

## 身份、源码与观察条件

两窗各自现场核名称/iPad12,1/iOS18.3.1/UDID/USB，重核05:26普通Debug/-Onone、HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty、173输入/29库签名/profile/IPA及本机安装回执。完整包路径、三个二进制SHA、原始偏好/AX/PNG/日志只在私有指针`/tmp/nastart-ipad-toolbar-current-evidence`，package-private-root接当前包。App实际env/args均空。沿用已签名已安装Runner，native XCTest单owner有界180秒；原生RSD前后观察均在Runner host生命周期外，没有重装WDA。

离线读`AppTabRootView`确认PadOS18走sidebarAdaptable，`DevicesView`的Menu标签附在SwiftUI容器上，没有发现App禁用排序的条件；旧13成功与Pad失败AX都有同位置外层Other/内层Button，因此结构相同本身不能解释失败。本机旧WDA源目录已不存在，未用历史构建索引冒充现有源码或重建依据。

## 只读属性窗

两次普通导航到文件页，然后只读查唯一外层Other与内层Button的displayed/enabled/rect/accessible/hittable。同PID/方向PORTRAIT前后相同，两者同矩形；外层displayed/enabled/hittable=true、accessible=false，内层displayed/hittable=false、enabled/accessible=true。未发菜单/排序操作，没有删可见性守卫。WDA PNG仍倒置，实际已看，不从PNG猜坐标；以上是目标属性差异，不是截图倒置唯一根因结论。

该窗文件页实际显示DSM/FileStation权限/会话错误。按本窗时间截取持久化诊断：新DSM登录与新FileStation登录成功、附加并发布同pair后，snapshot list_share v2/v1、browserRoot v2均HTTP200/API119，所有requestAuthenticationGeneration都等于附加FileStation generation；浏览器仅一次请求后保留119，没有同SID浏览器回退。不能归为只读了旧browser会话、旧包或HTTP502；具体SID失效来源仍未知。未点重试/断开/重登、未改NAS/VPN。完整原文仅私有保存。

## 实际菜单窗

此窗只在新核的唯一导航栏外层Other自身displayed/enabled/hittable均true、rect与当轮AX一致、PID/方向未变后，发一次语义原生click；不点之前不可见的内层按钮、不在动作失败后换目标重发。实际菜单与勾选实图/AX成立，点击原名称条件后菜单消失，正常返回NAS在线首页实图已看。18完整偏好与只读窗开始逐值一致，未改变排序方向/值，不当名称双向、日期/大小/类型/完整UX-02通过。

此新正常会话的snapshot与browserRoot均list_share v2一次HTTP200 success，根目录12行实际可见。不是失败窗的手动重登/重试，也不据后窗成功关闭间歇API119、认定根因或恢复速度验收。后续若做Pad排序，只沿已验证实际容器守卫并检查真实目录数据；不再执行只找内层Button的旧助手，不重复菜单本身验证。

## 两窗离线对照

仅解析已保存诊断，未追加设备/网络请求：两窗各两次登录（DSM与FileStation），日志记录的目标、账号表示和两个session标签分别相同；两窗已捕获生命周期中均无logout事件，请求均绑定各自新附加FS generation。不能把本次差异归为日志中可见的地址切换或旧browser源；账号/地址只按脱敏日志表示比较，不代替私有实际身份或线上SID证明。没有同窗logout也不能排除别的客户端、窗前活动或服务端主动失效。没有精确wire SID及NAS服务端会话生命周期证据，不为未知原因加等待、重登或改NAS/VPN。

## 收尾与接续

两窗零文件预览/下载/Play/PiP；auto/idle10/cool2均GET回读，自有App/日志/Runner host停止。08:37:30最终原生Nastart=0、Runner=0、自有host=0，18完整非诊断偏好与第一窗开始相同；原生Home无PiP/Wi-Fi图标实际已看，未改变网络/使用蜂窝。wrapper-menu保存本窗session但host已停，不能沿用。

菜单自动化阻塞已有具体可行目标，不作产品修复或完整排序验收。下一步优先离线区分两窗FileStation失效/成功的生命周期与请求归属，或接已有不同字幕/seek缺口，不盲重登、追加相同失败媒体或清理凭据；28项保持开放。
