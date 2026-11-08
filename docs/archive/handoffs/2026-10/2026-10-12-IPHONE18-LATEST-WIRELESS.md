# iPhone18 最新包无线覆盖

## 2026-10-12 iPhone18 最新包无线覆盖
- 更新时间：2026-10-12T19:55:10.749599+08:00。用户确认18回到局域网Wi-Fi并授权更新；现场DNS-SD与既有配对TCP核对设备名称/型号/系统/UDID，iPhone19,7/iOS27.0/无线且USB缺席，端点与原始身份仅私有。未改网络、VPN、配对、remoted或DDI；13/Pad本轮未操作。
- 源码未改，最新69395e7c普通Debug（主7d9c741f/Debug593b5bfb/KSdf76e71d）173输入/三SHA/29逐库与深度签名/profile目标及有效期/IPA核验，源码无新输入，无需重建。326测试/2跳过/0失败和15预检引用此前17:55同源结果，本轮未重跑。
- 19:51:38.133实际InstallComplete/安装lookup成功，保留容器覆盖；安装前后及启动检查后25偏好（含全部书签）逐值一致，登录未清。直接无线RSD/DVT正常空env/args launch返回PID并截图；实际原图已看，前台仍其他App，因此最新Nastart正常UI未核，不记启动/播放回归PASS。已停止额外前台操作。
- 下一步18方便时补新包实际界面；调试主线继续USB13/Pad白黄重复字幕与HDR PiP。HDR功能尚未修，全SUB/AUD/HDR/性能/蜂窝/竞品/MTP及全部旧PX/UX/CB/Main/475/119/HLS/L2/L3未验项保留。


## 安装身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，包含既有未提交修改的源码diff SHA-256 `69395e7ce67ff97898f90a2d4c9cc92832087c3bd928f104d073cd01b83ac224`，构建 `2026-10-12T17:55:42.266483+08:00`，配置普通Debug -Onone，无测试注入。包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-pip-composition-reason-175252/Nastart-PiP-Composition-Reason-Normal-Debug.app`，IPA `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-pip-composition-reason-175252/Nastart-PiP-Composition-Reason-Normal-Debug.ipa`。

- 主二进制SHA-256：`7d9c741fc3d79d69debd290996a4f790f926039de5c65d4402e764aa0a9e1d33`。
- Debug dylib：`593b5bfba294720050782c386441f00d4adaafba90157b579ea5beb2ec0de3e0`。
- KSPlayer：`df76e71df756331a8e80a0e0550683b73a24af6282db214a7401fd975af643c4`。

173源输入及最终当前源码重核，29库逐个签名、deep/strict、签名profile包含18且有效至UTC `2026-10-17T22:23:40`，IPA三二进制相同。无法用版本号证明旧包身份，所以保存旧诊断与偏好后执行保留数据覆盖，不卸载、不清登录。

现场无线发现重新解析地址，用既有配对autopair=false验证实时UDID/名称/iPhone19,7/iOS27.0；USB列表确认18缺席。无线安装开始 `2026-10-12T19:51:25.162411+08:00`，InstallComplete `2026-10-12T19:51:38.132748+08:00`，lookup确认App存在，所有25非诊断偏好与安装前完全一致，启动检查后再次一致，含原播放书签。

## 启动证据边界

WDA已知HTTP端口当前拒绝连接，没有为安装重新配对或重装Runner。既有配对CoreDeviceProxy/RSD userspace会话成功，容器可读；DVT以空env/args启动Nastart返回PID，原生截图成功，实际画面已查看但前台仍其他App，不能据PID推断Nastart界面正常。没有进行额外前台切换、点击或播放；UI和播放验证延后。也未重查/修复Xcode自动隧道，不把直接RSD成功当其恢复。

原始截图、端点、设备名称/UDID、偏好/诊断和工具日志仅本机私有：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-iphone18-latest-wireless-194654`。[安全JSON](../../../testing/results/2026-10/IPHONE18-LATEST-WIRELESS-20261012.json)。原图文件名含normal-home是工具标签，实际内容不符已明确记未通过，不能按文件名验收。

## 接续

用户已重新授权18的无线更新，可在后续方便时补实际新包UI；默认仍先USB13/Pad处理重复字幕与HDR链路。最新包只有合成原因诊断，未修HDR/重复字幕。上一轮具体失败cue、工具失败/短时重叠/清理证据和全部总账见[画中画交接](2026-10-12-PIP-COMPOSITION-REASON.md)，未验项目不删或改PASS。
