# iPhone13 弱蜂窝清单与大文件等待（回归中）

本轮从PROGRESS/当前交接继续；USB现场仅iPhone13/iPhone14,5/iOS16.3.1/20D67，WDA ready/unlocked，未重装Runner；iPad用户断开、18离线。开工先核源码与850d/06d9普通包，并再次保留数据覆盖安装核25偏好及普通前台。基线无环境变量，设备SlowNetwork3G 0.78/0.33Mbps、各100ms、0loss，实际蜂窝公网HTTPS8097。无线UI转场未就绪一次TOOL，保存原图/日志，未开始播放；补等待实际可见开关后重试成功，不算播放失败或有效蜂窝样本。

旧最新850d基线补S03：详情实际54.01 GB MKV/2160p/HEVC/TrueHD；清单1,726,438字节、1880段/7524.768秒，预热20.069秒，内部首帧44.996秒。首段0三次请求（22.237/26.255/36.265秒），前两次client断连，第三次42.126秒完整111108字节；首帧后44.020秒无新增计数，初始缓冲1/AV丢帧unknown，非整体验收。小S01旧清单1,482,628字节、媒体body下载约16秒。清单响应与首段转码等待分开，不能把体积当作视频码率或从小文件外推大文件。

变更关联PX-01/PX-03/CB-01与CB-04：用Jellyfin既有Params格式缩短主/媒体清单请求中的数值/布尔参数名。参考[10.10.7服务端ParseParams](https://github.com/jellyfin/jellyfin/blob/v10.10.7/Jellyfin.Api/Helpers/StreamingHelpers.cs)，本机逐项核15个位置。仅带认证/PlaySessionID且匹配Videos/GUID/master或main.m3u8的非Range请求；身份、认证、codecs与未知参数仍显式保留，参数值、转码预算、分段长度与缓存/超时均未调整。重复、已有Params、异常值、非Jellyfin清单保持原请求；400/422仅回退原请求一次，旧task完成/metrics守卫避免取消/元数据混入新任务。该协议改动不当作候选/首段取消问题已解决。

135核心测试0失败、15preflight/普通Debug -Onone设备构建通过。最新包Nastart-ManifestQuery-Debug.app，HEAD 9a9941cd4ec82625f680b5193b3a0f66797eb851，已跟踪iOS diff SHA-256 303411ba71c8ed306824efe6eac61161928957f7f5f6611912c5268665aea501；构建时间 2026-10-07T06:10:51.466996+08:00。Main ac5dbba6355893bccb90e0a901c99e9e5a5a76eb837eeda5eb7054075bc9bca2，Debug dylib bf0bfadee6177e6dbe7640a4d897235b707eea31fcda78751b9ac72816234491，KSPlayer c814c6b3f8d1beaddef93e8c77935aa9d653835244ae7a0b772d9900e709a704；29库验签/链接通过，完整包路径/UDID/原始偏好仅在本机manifest。已保留数据覆盖，25偏好一致且实际普通前台核验；当前串行回归正常蜂窝S03、弱蜂窝S01/S03、LAN MI2，全部失败/超时保留。正式竞品配对0，原PX/UX/CB缺口及iPad/18均保留。
