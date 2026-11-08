# iPad新接入、最新包准备与双工具分端

更新：2026-11-01T20:48:10.648188+08:00（Asia/Shanghai）。用户新接入iPad，当前调试设备改为iPad、13及恢复后的TV，iPhone18今晚由用户使用，两方hands off。[结果](../../../testing/results/2026-11/2026-11-01-IPAD-REJOIN-AND-COLLABORATION.json)、[分工](../../../development/CODEX-CLAUDE-COLLABORATION.md)。没有操作18/旧Pad/TV/13，没有NAS命令、普通账号根、播放/源目录写入；当前接受的446输入与994ca42c diff保持，无App或测试源码修改。

## 现场与最新包

CoreDevice fresh清单有两台Pad：旧iPad12,1/18.3.1 unavailable，新接入常立文的iPad为iPad15,7/A16、iPadOS26.6、wired/paired/connected。单独details核完整身份，RSD再认证硬件UDID一致；全部原始ID/地址仅仓库外私有。没有沿旧设备名或把另一台当目标。

复用当前接受源的正常签名Debug/-Onone包，构建2026-11-01T18:42:00.071758+08:00至2026-11-01T18:45:06.340650+08:00；主SHA `8dbd451b31a19ed0fae703d3cff86f7dbc0ea4c43a2263ac884cbabbdea11db7`、debug dylib `dd0b7b0a67de264bc13cf49efa650b062d9948e7fae74a450d3b59ce1119088c`。源/HEAD/diff/全部30 Mach-O及29库签名/IPA和目标授权、profile有效期重新核；目标在profile且至2026-11-08T01:08:19Z有效，不改签名配置。RSD/HouseArrest备份偏好后，2026-11-01T20:33:37.111010+08:00 CoreDevice保留容器覆盖exit0/success，fresh应用清单核bundle存在；19非诊断偏好全同，所有值含诊断亦同。未卸载/清登录。

## 启动失败、信任动作及真实图

首次DVT启动请求返回DTXNsError；独立CoreDevice fresh进程无Nastart，未当闪退/通过。首次CoreDevice替代驱动给空环境字典被CLI本地拒绝exit64，结果文件未产，驱动随后FileNotFoundError均留存；这不是App失败或一次真实设备启动。去掉该空参数并清除子进程DEVICECTL_CHILD_继承后，正确CLI到设备，但报CoreDevice10002/FBSService1/FBSOpen3 Security，提示可能签名、权限或profile未信任。Mac本机核签/目标授权有效仍不等于设备信任，不把泛化错误直接定为某一根因。

用户按系统页明确回复“已信任/已完成信任”，未发送或读取开发账号/验证码，不要求打开普通App。环境状态变化后，同包同隔离参数重试CoreDevice启动成功：privacy-export/glassDeck/dark/large，空测试环境；large映射accessibility2。DVT独立截图已实际看，当前竖屏全屏，三开关、完整中文隐私footer与导出动作在初始视口，无明显截断。未分享/复制/导出用户数据，非横竖旋转、完整读屏或真机交互验收，也不声称普通首页已回归。

finally按本轮启动收据的PID仅停止自有App，stop exit0，fresh进程清单无该PID、Nastart总行0。原安装前与最后偏好全值比较相同（含诊断），正常包留机、参数不持久化。失败窗与成功窗分开，不追溯改失败为通过。没有Runner、模拟器、媒体或采集后台任务。私有指针`/tmp/nastart-ipad-rejoin-path`。

## 分工更新与接续

[根CLAUDE入口](../../../../CLAUDE.md)、协作文件与资源登记已按用户最新设备更新：Codex主用13/恢复后的TV并管集成；A16 Pad准备后预留Claude UI窗口。当前Pad测试已停、没有活动Claude设备租约，Claude尚未启动/确认读取；首批可先只读离线UI审查，实施须同源独立工作区/文件范围，不能抢原集成工作区。不能把“预留Pad”当作允许随时操作或跳过最新包核对。

iPhone18今晚hands off，不读取/核对本轮安装身份，不以用户口述或早前包回执声称最新源已在18回归。NAS暂停继续，TV仍需明确单一DeviceHub验证及有效签名；前批验证码框已消失，不让用户在两个Xcode项目里找旧框。两套Xcode暂保留，26.6的13兼容路线尚未迁移。

唯一需求总账与114格已核，本批只补iPad最新包和有限静态证据，不新增播放P或关闭旧分享/取消/密码/焦点/性能编号。后续按分工集成Claude报告、准备同源工作区及设备窗口，继续已有非NAS任务。
