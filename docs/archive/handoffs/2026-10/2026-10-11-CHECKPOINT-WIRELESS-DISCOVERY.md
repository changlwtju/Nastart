# 2026-10-11 前台异常终止保存与iPhone18无线发现

更新时间：2026-10-11T07:45:28.864093+08:00。本轮入口已读PROGRESS、CURRENT、播放runbook及竞品矩阵；保留其他未提交修改，未提交/推送。机器摘要见[定向证据](../../../testing/results/2026-10/CHECKPOINT-WIRELESS-20261011.json)。

## 当前最新包与逐机安装

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；当前iOS差异 `6bbe470c5edbf56360564f354e73a4f47851910dcf0c0261abdff10702900eef`，173输入逐项SHA一致。普通Debug `-Onone`，构建于2026-10-11T07:13:12.115029+08:00、冻结于2026-10-11T07:15:26.728027+08:00；源码没有晚于产物的输入。包路径 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-abrupt-resume-070632/Nastart-Checkpoint-Normal-Debug.app`，IPA与原始日志在同一仓库外私有证据目录。主程序 `5b3cb2ce5701e1347cccc2553f5670d9c10c5a65b248567a07c98e146052d8b9`；Debug dylib `41f8c0ef4d656a8f18390b6f161d54cb5de33df764f5e58fd181fc35e92cd881`；KSPlayer `8e6bc9ccfd71d1aa406f1cf74f06201df62b90e577527315f72c040fe2465ebe`。逐项29库/深严格签名/链接通过，profile覆盖三机、北京时间10月18日06:23:40到期。新源实际重跑306测试/2跳过/0失败、15预检；无线工具3测试通过，不复用旧测试声明。

|设备|现场型号/系统|本轮最新包|实际正常启动|连接|
|---|---|---|---|---|
|iPhone13|iPhone14,5 /16.3.1|保留数据覆盖，25/25偏好值一致|空环境首页已核|USB|
|iPad九代|iPad12,1 /18.3.1|恢复连接后保留数据覆盖，16/16一致|空环境首页已核|USB|
|iPhone18 Pro Max|iPhone19,7 /27.0|USB保留数据覆盖，25/25一致|用户信任开发者后，拔线无线新进程/真实首页已核|安装USB、后续验证Wi-Fi|

完整名称、UDID、序列号、配对记录、IP/SSID、偏好和原始截图仅在本机私有证据 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-abrupt-resume-070632`。18安装成功与启动分开记录：初次被设备“未信任开发者”明确拒绝，不能当签名核验或正常启动通过；用户设备端确认后才补成功证据。Pad本轮先安装旧基线包、随后USB断开；旧基线不算当前新源回归。重连后更新新包，复用当前已签名安装的固定WDA fixture、原转发、正式XCTest及新session恢复，没有再次安装WDA。

## 13旧包故障与最小修改

修改前源a56c92d3、主309d3e69/Debug acb8c819独立冻结。S01设备文件KSPlayer普通Wi-Fi前台播放30秒，不先暂停/Home/普通退出，仅给核实的Nastart PID发送SIGKILL，核PID消失再空环境冷启动。冷书签621.033，对已持久诊断633.833至少回退12.800秒；实际下一次冷续播首帧621.182，证明恢复了较旧书签，而不是只凭即时AFC旧文件误判。原工具误把观察器先于导航运行的失败保留，无新播放提交；按顺序另目录重试。

仅改变GreenfieldVideoPlayerView定时本地保存间隔15→2秒并解释异常终止无法调用退出回调。现有启动seek资格保护、暂停/后台/PiP/普通退出强制保存均保留，未注入/回写书签。没有调用synchronize或清用户数据。保存频率提高，长期写入/性能开销尚未验；2秒为发起checkpoint间隔，不是硬性落盘或最大丢失保证。

## 新包有限功能结果

两机都先核新包收据，再在同普通Wi-Fi/S01文件KSPlayer条件执行前台30秒、仅目标SIGKILL、正常冷启动、冷偏好0/1/3/10秒读数、实际冷续播30秒及普通UI退出。

|设备|最后持久诊断时钟|稳定冷保存|冷续播首帧|首帧减保存|
|---|---:|---:|---:|---:|
|13|678.846|680.148|680.244|0.096秒|
|Pad|743.152|743.333|743.408|0.075秒|

两次新包样本未出现原13秒回退，音轨/字幕偏好及书签键保持，真实电影、原页面普通退出已查看。最新诊断不是精确终止时钟，不能据这些数字给最大丢失界限或帧性能PASS。不同终止相位、Jetsam/自发crash/整机重启、JF/AV、新源暂停/PiP及长期写入影响继续待验。13/Pad收尾正常空环境首页、NAS/DSM/JF在线，其他服务警告保留；播放器关闭、native条件active0，WDA idle10/动画2已恢复。

## 18无线问题分层结论

USB现场配对/开发隧道可用。手机与Mac处同一网段，当前地址直连经物理网络接口、ping和TCP建立可用；最初协议握手超时随后成功，旧地址失败不能判配对无效。用户拔线后现场USB枚举明确无18，直接Wi-Fi TCP重新读取同UDID/iPhone19,7/27.0并validate既有配对，userspace RSD、容器、DVT启动及截图成功；第一次返回已有后台进程且截图不是目标App，明确排除，重新kill-existing空环境启动后才核实际Nastart正常首页。

先前Python mDNS浏览遗漏系统已发现的目标；default=str还把Address对象变成描述字符串，不能当原始IP继续探测。新增只读 `scripts/discover_paired_wireless_device.py`，使用macOS DNS-SD解析已知目标实例及当前地址，现有配对/autopair=false/实时UDID验证。广告随机端口明文lockdown超时保留，标准lockdown端口确认成功；不把两种协议探测混为同一失败。新工具本轮拔线实测通过，无手工旧IP回退；错误UDID拒绝、地址撤销过滤和同地址端口回退三工具测试通过。私有配置和原始输出不得进仓库，使用说明见[CLI手册](../../../testing/CLI-DEVICE-OBSERVATION.md#2026-10-11-已配对无线设备的发现与身份核验)。

**仍未解决的是原生CoreDevice/Device Hub自动通道**：拔线后Device Hub不可用，原生tunnel unavailable/DDI=false；userspace替代路线成功不等于WDA、LLDB、完整无线性能都已恢复。Mac Tailscale与Shadowrocket同时连接，Apple TN3158把VPN作为开发通信排查线索；用户要求保持现有配置，未关闭VPN/代理/改防火墙/取消配对，因果根因未确定。原生候选主机名解析超时、remoted日志及en0查询实验失败均保留，不强行归因VPN。

Apple官方[无线设备运行说明](https://help.apple.com/xcode/mac/current/en.lproj/dev3e2f4ee6d.html)允许无线运行及地址连接；[TN3158](https://developer.apple.com/documentation/technotes/tn3158-resolving-xcode-15-device-connection-issues)说明VPN可能干扰开发通信。当前实证支持继续已验证无线启动、截图及诊断读取，不需把接线作为这些工作的前提；原生工具能力逐项补验。

## 接续

先用新的只读无线发现工具获取并校验当前18端点，再过最新包门槛；已有userspace RSD/DVT路线可继续正常启动/截图/诊断。原生CoreDevice自动连接仍待不改现有网络条件下定位；WDA/LLDB/性能各自取证。继续新包JF/AV、暂停/PiP及不同SIGKILL相位、119根因、真实弱蜂窝大文件双入口/旧ordinal0、完整帧/Lenna等竞品同条件量化及全部PX/UX/CB/L2/L3/Main。竞品有效配对0，无本轮滚动/播放性能验收。精确临时helper与SHA归档在私有helpers-private，失败/超时不丢弃；现有正式WDA/转发供后续复用。
