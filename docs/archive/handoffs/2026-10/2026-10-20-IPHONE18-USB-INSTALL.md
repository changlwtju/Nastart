# iPhone 18 最新普通包有线安装

2026-10-20。[结构化结果](../../../testing/results/2026-10/IPHONE18-USB-INSTALL-20261020.json)，[来源批次](2026-10-20-CLIENT-OUTPUT-CORRELATION.md)。包/端点/设备名/UDID/偏好及截图仅仓库外私有。

## 从无线失败到用户授权有线

沿用[成功无线手册](../../../development/IPHONE18-WIFI-UPDATE.md)系统DNS-SD重新浏览解析，当前广播身份/型号iPhone19,7/27.0/配对核实；旧实例解析失败保留。新包173输入/HEAD及dirty差异、29库、目标profile和IPACRC核验。ditto归档的160项AppleDouble在发送前发现并排除，重新归档保留三二进制哈希与签名；坏包未发到手机。

无线HouseArrest保存偏好时ConnectionTerminated，安装命令未发送；原生备份拒绝开发服务断言。用户手动打开Nastart后新窗口仍同样断开，独立userspace CoreDeviceProxy也失败。未更改VPN、配对、手机系统或清登录，旧失败不标成功。

用户明确接入数据线并授权有线更新后，现场USB枚举、ideviceinfo设备名称/型号/系统/UDID及原生wired/connected隧道均匹配。USB VendContainer备份25项非诊断偏好成功，再核冻结源码与签名，devicectl保留数据安装返回成功。安装后25项逐值相等（含整个书签对象），没有卸载。

## 最新包与正常启动

普通Debug/-Onone/Xcode27，构建06:48:25；源码HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS差异`35df7015b08ee4d929683983de8ac59d2d7111f94615bf85f38894fc25ae66ed`。三SHA及清洁IPA SHA见结果。仅增加输出关联诊断及Params解析，不把它称为蜂窝性能修复；相关5项定向XCTest/15预检及构建签名核验通过。

通过USB native RSD实时核目标，再DVT正常启动environment={} / arguments=[]。原生截图实际见Nastart首页、NAS在线卡、Wi-Fi图标，播放器关闭；其他服务卡当时未知，不以此验收播放。启动后25项偏好再次逐值相等。安装及正常首页完成，不代表18蜂窝/音字幕/深seek/WDA验收。

用户随后已带18离家，13及iPad重新接回Mac；停止18相关动作，按最新现场接回13/Pad，不要求反复解锁或重新配对。无新周期调度、无NAS/VPN/系统更改。
