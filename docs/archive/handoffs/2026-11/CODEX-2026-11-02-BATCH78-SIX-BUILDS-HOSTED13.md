# Codex：第七／八批六配置与13项宿主测试补验

2026-11-02（Asia/Shanghai）。用户释放磁盘后明确续跑；主集成工作区保留原 HEAD／dirty／index，本轮没有产品源码修改、真机操作或 NAS 访问。前轮受阻与 F1 结果保留在[原报告](CODEX-2026-11-02-F1-BATCH7-8-INTEGRATION.md)。

## 结果

Xcode 27.0（27A266a），独立 DerivedData／APFS 复制的依赖缓存，锁定依赖版本并禁止自动解析／更新。六配置全部 `CODE_SIGNING_ALLOWED=NO`、arm64；首项为 build-for-testing，其他为 build，未请求签名更新或安装真机。

| 配置 | 退出码 | 执行时间（+08:00） |
| --- | --- | --- |
| iOS Simulator Debug | 0 | 11:44:07–11:47:37 |
| iOS device Debug | 0 | 11:50:46–11:54:02 |
| iOS device Release | 0 | 11:54:02–11:58:47 |
| tvOS Simulator Debug | 0 | 11:58:48–12:00:05 |
| tvOS device Debug | 0 | 12:00:05–12:01:14 |
| tvOS device Release | 0 | 12:02:19–12:03:59 |

- **13/13 app-hosted XCTest 通过**：AppearanceStoreInjectionTests 5、PrivacyCacheCleanerTests 4、NastartShareOutcomeTests 4。原日志与 xcresult 均核对：13 总数、13 通过、0 失败、0 跳过。当前主目录实际编译／运行，不再借用独立目录旧9项结果；前轮同源缓存包14项仍是单独历史证据。
- **Release 排除通过**：iOS 28／tvOS 25 个 Mach-O 二进制，各13个密码／外观／缓存／分享调试标记全部0；排除测试插件后的 iOS Debug 30 个二进制，同13标记均有正对照。正式 `mine.share.failed`／`mine.privacy.clear_cache_partial` 两语言键仍在 Release 资源中。完整二进制哈希在私有证据。
- **447项冻结输入全部保持**，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`、Git index 哈希不变。相对路径清单 SHA-256 `3ee11a90c8d57869e5ccb0d47272eaed6e05f66accd36a510ed3e5c0568fafec`。

## 宿主、空间与失败记录

创建专用 iPhone17 Pro／iOS26.5（23F77）模拟器。创建前0 App／数据容器／Keychain文件；启动后无 Nastart、无匹配 Nastart/Jellyfin Keychain服务。按源码无凭据即返回、服务／缓存为空的门槛运行普通宿主，无自定义 NASTART／SIMCTL_CHILD 测试条件；所选测试只用临时偏好域、临时文件和注入闭包。此证据不能用于带账号的普通根，也不作系统全网络请求抓包结论。

专用实例 terminate／shutdown／delete 成功，fresh 清单与路径均已不存在，Keychain复核0匹配；原 `Claude-PW-iphone` 仍 Booted，未 stop／删除。最终无 xcodebuild 进程，本轮窗口释放。

起始约10.8GiB。进入最后两项时约3GiB，先报告，再仅删除**本轮新建目录**的已完成 iOS `Build/Intermediates.noindex`（约1.21GiB）；应用包、测试二进制、xcresult／日志保留，未删其他批次／共享模块缓存。最终约4.02GiB，未触2GiB运行保留线。

最后一项首次启动被“another build is active”门禁阻止，**未进入编译**；当时PID未采到、归属未知。fresh复核无 xcodebuild 后才启动末项并通过。门禁失败记录保留，未停止任何未知进程；原串行脚本退出1不等同六配置编译失败。编译仍有既有 actor 隔离等警告；此前静态预检五类失败未在本轮修复，不声称全检查全绿。

私有证据：`/tmp/nastart-codex-batch78-validation-path`，含六条完整命令／日志／状态、447清单、13项xcresult、宿主门禁／清理、空间清理与二进制哈希／标记检查。[可分享JSON](../../../testing/results/2026-11/CODEX-BATCH78-VALIDATION-20261102.json)。

`check_documentation.py` 通过（629文档／3887本地链接，缺失0）。完整 UI／真实分享完成与失败、缓存取消零副作用、密码原因及修复仍未因此验收；未生成可安装的正常签名包、未做当前源真机回归。30项需求状态／114格保持，不新增播放P。
