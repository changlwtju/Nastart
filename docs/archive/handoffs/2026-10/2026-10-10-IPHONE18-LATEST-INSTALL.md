# 2026-10-10 iPhone18 最新安装包

完成时间：2026-10-10T13:11:34.062969+08:00。用户中途要求优先安装，已完成最新可用开发包的保留数据覆盖与正常启动，未新增播放或性能验收。

现场重新确认设备名iPhone、iPhone18 Pro Max / iPhone19,7、iOS27.0 / 24A8428、USB连接、配对及完整UDID唯一匹配。原始UDID、设备详情、旧诊断、偏好及安装/启动回执仅在本机私有目录 `2026-10-10-iphone18-latest-install-130949`。

## 最新包身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留已有未提交修改；当前iOS差异SHA-256 `21e8797a0ebd2fd5bf7fbb85be355c27c4cdd926550deeb2db8fb0df800cb842`。普通Debug -Onone，构建 `2026-10-10T13:01:32.267381+08:00`，包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-10-folder-source-ui-125639/Nastart-Folder-Source-UI-Normal-Debug.app`。现场重核173项源码/项目/资源输入（含未提交文件）的逐项SHA与新旧时间；主二进制/debug dylib/KSPlayer哈希、29库strict及App deep/strict签名、有效profile包含目标设备、播放链接均通过。签名profile到期UTC `2026-10-10T22:03:15`。

- 主程序SHA-256 `24189030f8c7f3fbed8d30c884610a8417020a917254d19a1f64dba2af1f4b86`。
- debug dylib SHA-256 `2aaadca11a4a00306655cc88bc787910bb95efeb65c440459566e6c462f01c0d`。
- KSPlayer SHA-256 `eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`。

同源码本轮已完成262项XCTest/2跳过/0失败、15预检及18安全分析测试；安装时未重复运行。目录来源同步与取消页面规则已实现，但13/iPad真机回归尚未全部完成，不称正式验收包或119根因已修复。

## 安装与实际启动

安装前保存旧故障诊断和偏好；不能只靠0.1.0/1确认身份，因此在 `2026-10-10T13:09:56.524873+08:00` 将上述已验签包保留数据覆盖安装成功，没有卸载或清登录。25项非诊断偏好在安装后、正常启动后及最终画面核验后均一致。

普通启动清除继承的DEVICECTL_CHILD变量，不传App参数或测试条件。系统启动成功并返回PID；本轮系统记录未枚举实际环境，因此不伪称工具实际环境字典为空。独立进程清单确认同一启动PID在约33.352秒后仍存在；原生截图已逐张核验实际Nastart首页、NAS和Jellyfin绿标在线、播放器关闭。其他服务的橙色警告原样保留，不称所有服务健康。未重装/启动WDA，未改变18网络或账号。

## 继续工作边界

18可拔走使用。目录/播放调试中断点见[目录来源与页面交接](2026-10-10-FOLDER-SOURCE-UI.md)：13完成两次受控弱网MI2详情、三次目录进入退出重开；iPad第一轮因USB掉线/WDA及原生通道中断而失败，临时SlowNetworkWiFi的清理未能确认。iPad重接后先读取真实条件并清除/确认active0、恢复idleWait，再重新核对最新包和启动，保留工具失败，不能将它计为App通过或已恢复条件。

S01/S03播放本批尚未开始，S19深位置/双设备专项、真实弱网、声音/字幕/完整帧/十分钟/PiP、Lenna及全部PX/UX/CB/L2/Main开放项均保留；安装成功不是性能验收。[脱敏安装记录](../../../testing/results/2026-10/IPHONE18-LATEST-INSTALL-20261010.json)。
