# 当前包根目录名称排序核验

2026-10-22 07:28–07:33，关联UX-02。18按用户“稍后，先继续其他工作”暂缓首页，本批没有18操作。13现场名称/iPhone14,5/iOS16.3.1/UDID/USB、173输入/三二进制/29库签名/profile和本设备安装回执重新核完，复用05:26普通Debug/-Onone，无App源码修改、构建、安装或播放。原始身份/偏好/目录名/图日志只留`/tmp/nastart-file-sort-current-evidence`。

## 开窗前失败与会话范围

首个观察在零UI动作时读旧App session的activeAppInfo得到HTTP400；后续只读/status仍ready、同session的App state=1，原始响应为invalid element state/选定App未运行。不能凭activeInfo失败断定Runner死了、session无效或包未安装。未重建/安装WDA。先读实际App state并看原生Home无PiP/Wi-Fi，另一个正常App-bound基线以state1/1为门槛启动，空环境/空参数实际读回。

共享主机解码器只补安全错误代码invalid element state；原始message仍只留private_payload，不打印私有App/设备数据，不扩大重试条件。18项test_wda_command_guard通过（含该真实400形状的脱敏及不重试），未重跑App既有151项L0、未改变App包输入或行为。

## 同目录实际顺序

07:30:47–07:31:21，NAS正常首页→设备→文件根目录。原菜单实际勾选修改时间/降序。按当前唯一可见/可用菜单项选择名称、升序，再降序；同一目录两份AX均12行、同集合/唯一行且顺序完全反转。原生升/降序图实际可见项同步改变，已看图确认。这些均为共享文件夹，未进入预览/下载或播放，不改NAS文件。

根目录没有可见修改日期，修改时间相同/缺失时的名称次序不能当日期排序验收。数值自然名、混合文件/文件夹优先、类型/大小、子目录日期仍未覆盖；12行AX不冒充滚动逐帧流畅证据。

## 偏好快照时序与收尾

刚选择升序后的外部AFC偏好仍见旧false，而实际列表已升序；原轨道恢复选择修改时间后立即读取也仍旧值，主断言失败，finally又选择一次原修改时间，错误保留。没有直接写plist、synchronize或产品保存等待。App停止后的独立读取已恢复原modified/false，07:33最终再读与整个批次开始25非诊断偏好逐值完全相同，含全部36书签/原轨道/进度。只接受最终恢复已核，不把即时旧快照当保存丢失或擅自增加等待的依据。

自有App/日志已停、原生App缺席；各窗Nastart/WDA/Jetsam报告名称清单增量0，不扩为全局无崩溃。源包/173输入/29库/profile及当前USB再核，auto/idle10/cool2已GET回读，最终原生Home无PiP/Wi-Fi已看。未进行蜂窝或改网络/VPN/NAS/凭据。当前13 session在私有not-running-baseline/session-id；App已退出时先读state，不再先假定旧App target的activeInfo可用。正常页面返回Home分支未到，不用终止后Home冒充正常返回。

[安全结果](../../../testing/results/2026-10/2026-10-22-file-sort-current.json)。仅增加UX-02同根目录名称方向有限切片，28项仍开放。下一步选有实际日期/文件大小的子目录补覆盖，不重复本根目录名称窗；18按用户暂缓不探测/催促。
