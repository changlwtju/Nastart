# iPhone18 最新包安装与 GitHub main 同步

更新时间：2026-10-07 07:44。本轮按用户要求安装最新 NAS Start App 到刚接入的 iPhone18 Pro Max，并同步最新项目到 GitHub main；播放优化任务范围保留。

现场确认设备名称iPhone、iPhone19,7/iOS27.0/24A8428，USB在线、配对有效、CoreDevice connected；完整UDID和原始设备元数据只留本机私有证据。

最新普通Debug -Onone包构建于2026-10-07T06:10:51.466996+08:00。源码基底9a9941cd4ec82625f680b5193b3a0f66797eb851及既有iOS未提交修改，diff SHA256 303411ba71c8ed306824efe6eac61161928957f7f5f6611912c5268665aea501。现场核对136项已跟踪编译/项目输入mtime均不晚于二进制，iOS内容与先前135核心测试/成功构建一致；本轮未修改App源码，因此复用此产物。

- 主二进制SHA256：ac5dbba6355893bccb90e0a901c99e9e5a5a76eb837eeda5eb7054075bc9bca2。
- Debug dylib SHA256：bf0bfadee6177e6dbe7640a4d897235b707eea31fcda78751b9ac72816234491。
- KSPlayer SHA256：c814c6b3f8d1beaddef93e8c77935aa9d653835244ae7a0b772d9900e709a704。
- App外壳及29项库逐一验签成功，profile包含目标且仍有效；包路径及签名原始文件仅私有保留。

先保存旧偏好/故障诊断，再CoreDevice保留数据覆盖安装成功，25项非诊断偏好安装前后相同。以普通Bundle ID、无测试参数/环境启动成功，独立进程清单在约46.3秒后确认同PID仍在；启动后25项偏好也一致。没有卸载或清除登录。原生USB截图exit255，TOOL保留；本轮不声称实际前台UI、播放或性能验收。WDA未重装/启动新宿主。

GitHub目标：changlwtju/Nastart，main；初次fetch显示本地与远端均为9a9941c，无分歧。提交范围为当前App/KSPlayer Sources、测试、脚本、项目文档和脱敏证据；本机原始设备偏好/凭据不在仓库。已存在但未跟踪的第三方KSPlayer Demo/Documents及vendor-only配置为不参与App构建的参考文件，保留本机，未列入提交；其中示例有内置服务令牌，不上传。当前41工具测试及15预检通过，先前同源码135核心测试通过；提交与远端核验结果在后续追加。

弱蜂窝《碟中谍》/《指环王》大文件、设备文件/Jellyfin双入口同步优化、iPad遥测和完整显示、Lenna/DS One等正式配对及原PX/UX/CB仍未验收。本轮安装不替代跨设备性能回归。见[双入口执行卡](../testing/WEAK-CELLULAR-LARGE-FILE-DUAL-ENTRY.md)和[本轮安装量化](../testing/IPHONE18-INSTALL-MAIN-SYNC-20261007.json)。
