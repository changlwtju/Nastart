# 2026-10-13 正在增长的 TS 冷续播身份修复

- 更新时间：2026-10-13T00:09:33.249551+08:00；本轮从10月12日23:39接续，USB13/Pad优先，无线18另更新。现场名称/型号/系统/UDID/连接逐窗重核；原始身份/凭据/偏好/原图仅私有。HEAD4de732dd、dirty源3e3aa7b7，普通Debug主db592e17/Debug2a88b452/KSe68d7420；173输入/29逐库签名/深验/profile/IPA/链接及最终三SHA核验；实际344测试、2跳过、0失败及15预检。其他dirty及网络/系统/配对保留。
- 上轮4e36 R01旧失败保留：保存130.6754后增长换metadata key，冷启动initialPosition0。新版本TS/m2ts/mts先验证64KiB文件头与此前已写入区间，长度不减/mtime不退且checkpoint匹配才恢复；持久化仅哈希/偏移/长度/时间。相同文件头而旧checkpoint改变、截短、mtime倒退、身份响应错误/短数据均拒绝旧位置与轨道；普通文件revision key不变，旧TS仅精确metadata匹配才迁移，旧书签保留。三个源文件、7项新回归，未改缓冲/decoder/尾部等待策略。
- 双USB串行R01真实30秒请求窗→普通退出→空env/args冷启动/刷新→继续观看30秒→普通退出。13同key见证长度1186201600→1243611136，保存42.270066667→启动相同42.270066667→退出83.166066667；Pad1319108608→1492385792，40.517611111→启动相同40.517611111→78.330944444，轨道1/nil开启保留。两机冷窗t3仍黑底spinner，t10/30实际画面已看；首帧速度/完整流畅/声音未验，不能用startup临时0占位判成从头。
- Pad固定S05旧769.469611原key完整保留，新内容身份正常迁移，真实启动769.469611/initialSeek0/t30电影/普通退出794.613611；非完整精确seek/电影总矩阵通过。Pad首次目标行离屏、首次reveal底部排除过严导致TOOL失败，原图与失败脚本保留；核对实际末行后按App边界修正，冷窗4次有界滚动后打开，无排序偏好改变，不计性能PASS。
- 23:48:09/19双USB与23:49:22无线18同最新包保留数据覆盖成功，安装时25/18/25偏好不变；USB空env/args实际首页已核，18未本轮启动/实际UI与自动隧道待验。最终13原24/Pad原17非书签偏好逐值不变，各1/2书签自然新增/更新，S03文件/JF原位置与原轨未动、0新崩溃、播放器关闭、idle10动画2。未手写设备偏好/书签、清登录、卸载、修改NAS录制或网络。
- 下一步先增长文件尾部等待/追加后恢复与时长刷新、录制结束/替换文件真实负例，再旧主线HDR PiP/历史字幕原句与代表集。两段采样不是整文件哈希，保留两段都相同但中间改写的身份限制；本轮不证明全部替换情形。18实际UI、全SUB/AUD/HDR/性能/蜂窝/Lenna及所有旧PX/UX/CB/Main/MTP/L2/L3、475/119/HLS等未验总账保留。


## 最新源码与安装包

- HEAD：`4de732dd645b36671becff992cdef1d0163fd1e4`。源码diff SHA-256：`3e3aa7b7c6dfd15bfe1faad767abb5386e3e18eba57776348b235749423183be`。
- 配置：普通Debug -Onone，空env/args、无测试条件注入；构建时间 `2026-10-12T23:46:31.128172+08:00`，产物晚于全部173个输入。
- App：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-recording-ts-resume-233923/Nastart-Recording-Resume-Content-Witness-Normal-Debug.app`；IPA：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-12-recording-ts-resume-233923/Nastart-Recording-Resume-Content-Witness-Normal-Debug.ipa`。29个动态库逐个签名、深度签名、目标profile/有效期、IPA三SHA及链接核验完成。
- `Nastart` SHA-256：`db592e17b0ec4b0f87c245d60e34906c125ffc8a24b7f1073d612c47df1adc42`。
- `Nastart.debug.dylib` SHA-256：`2a88b4525cb835b49ba39f3f8ba2aa456531e71fe58e4f7565b754833e7cb831`。
- `Frameworks/KSPlayer.framework/KSPlayer` SHA-256：`e68d742056f06b8806d18ce13f3027b47a2d9bc380671b7371a985b6d139f785`。

| 设备 | 当轮现场型号/系统/连接 | 覆盖安装时间（上海，10月12日） | 最新正常界面 | 回归 |
| --- | --- | --- | --- | --- |
| iPhone 13 | iPhone14,5 /16.3.1 /USB | 23:48:19 | 空环境实际首页已看 | R01增长后冷续播，最终83.166066667 |
| iPad | iPad12,1 /18.3.1 /USB | 23:48:09 | 空环境实际首页已看 | R01增长冷续播78.330944444、S05迁移794.613611 |
| iPhone 18 | iPhone19,7 /27.0 /既有配对TCP无线 | 23:49:22 | 本轮未启动，待验 | 未测试 |

## 实现与验证范围

`GreenfieldPlaybackBridge.swift` 增加录制内容身份与持久化见证，录制书签在每次冷启动内容验证前不可读取。`DevicesView.swift` 详情提前准备身份，启动等待结果，使用受限HTTP Range读取；要求206、起点/长度/总长正确、非HTML/JSON/压缩响应。一次最多读取64KiB，每次会话有请求/资源超时，忽略Range的200不会被整文件下载。认证URL和媒体字节不写书签；仅存哈希与校验元信息。

普通mp4/mkv等完整文件维持原revision身份。TS/m2ts/mts采用账户/服务器/路径与文件头内容身份，再验证上一checkpoint，允许真实追加而不直接忽略大小/mtime。失败身份不阻止打开媒体，但不自动恢复未经验证的录制进度。旧书签仅在严格大小/mtime身份恰好匹配时迁移，原条目保留；上轮已增长而失配的老书签不猜测迁移。本轮新正常播放保存后，两机冷续播的同key、长度增长、初始位置、实际t10/30画面和正常退出齐全。

7项新增测试含真实HTTP Range fixture、冷store重建、相同prefix的不同checkpoint内容替换、缩短/时间倒退、缺失/短数据、忽略Range/认证/压缩/错误偏移、精确旧revision迁移。344执行/2跳过/0失败，15预检全部通过。没有修改NAS录制内容来制造负例；真实NAS文件替换、录制结束与持续尾部恢复仍待验。

两段64KiB是有界内容见证，不是整文件历史哈希：若替换恰好保留文件头和旧checkpoint、只改中间，当前策略不能识别。不得宣传所有替换都可靠识别。更强文件generation标识或历史覆盖范围校验需另做方案，不能按目录名/主播名/文件名硬编码。

两机冷窗t3 spinner已实际看，t10/30有视频：不当低延迟/声音/完整帧PASS。内部startup first frame并不等于显示首帧；冷准备期间telemetry current0占位也不等于放弃保存位置。30秒是请求采样边界，准备和普通退出耗时使最终保存差值并非准确30秒。所有失败/超时留存：旧4e36 R01续播失败、Pad离屏断言和底部过滤TOOL失败、原历史API119/签名/隧道问题不因本窗正常而关闭。

## 最终状态和未完成项

- 13原24、Pad原17非书签偏好逐值不变；原S03文件/JF书签整条保持：13文件739.444/4/5开启、JF6128.139/1/7开启；Pad文件938.896/4/off、JF5860.423337333334/1/7开启。13仅R01、PadR01和迁移S05共1/2新书签自然保存。无手写偏好、无轨道清理回填。
- 两USB实际正常空env/args首页、NAS正常、播放器关闭、WDA idle10/cooloff2；崩溃清单新增0。原NAS服务状态警告不计全服务通过。18当前新包覆盖与25项偏好保持已核，本轮实际UI/播放与Xcode自动通道未核；现有VPN/网络/配对未变。
- 下轮优先验证正在增长尾部：到打开时旧末尾后是否等待、追加后恢复、时长更新；先可靠重现再修改代理/解码策略，并依runbook完成所需fixture/代表族。当前并未实现持续追尾，因此不能用短时从头/冷续播替代直播尾部通过。
- 后续录制结束/文件实际替换身份负例，更强generation识别；历史HDR PQ PiP外置字幕仍F、重复原句“Remember / I can figure…”、手动prepare失败回滚/13真实AV、S01四入口/代表S08/S11/S18/S19、19×4及HLS deadline/分片/read callback均保留。性能/竞品仍按Lenna主对照完整帧执行，全部旧PX/UX/CB/Main/475/119/MTP/L2/L3不关闭。

安全证据见[本轮JSON](../../../testing/results/2026-10/RECORDING-TS-COLD-RESUME-20261013.json)，上轮失败和TS打开修复见[上轮](2026-10-12-DEVICE-FILE-TS-RECORDING.md)。原始证据只在本机私有目录，详见JSON中的私有目录指针。
