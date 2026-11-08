# 新 iPad 11 接入与双机调试

更新：2026-10-24 13:40，新设备接入及本批有界回归已收尾，18安装在备份层受阻。用户要求新增 iPad 11 安装 Nastart/WDA，并以新 iPad 与 iPhone 13 继续调试；iPhone18 最新包及原域名实际连接要求保持。28 个开放需求不因设备接入关闭。

## 新设备与安装

现场 USB 读取型号 iPad15,7、iPadOS 26.6（23G71），本机 Apple 设备类型映射为 iPad（A16）。名称/UDID/完整系统与连接记录在私有证据，不继承旧 iPad9 的登录或测试结果。新设备首次配对成功。首次构建因开发者模式关闭退出70；用户已开启、重启并确认，本轮 CoreDevice 重新核实 enabled / DDI 可用。第一次失败日志被第二次构建覆盖，但关闭状态的现场 JSON 和构建失败事实保留，不能声称第一份日志完整保存。

App 174 个源码输入保持、HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加既有 dirty，源码 diff SHA `260b03606d7b8f298f42332ab23adb11160cd901ec9aba37c53f5c3a95cae463`。未改 Nastart 源码、未重跑 XCTest；此前20项仅属同源码前批证据。按新设备重新自动签名，普通 Debug/-Onone/Xcode27，二进制构建于12:23:25；IPA SHA `616c8cd33b6affe387a1b0fe958a6b3f7cf566a0f9010252b87b961783c4243a`。逐库28项/外壳 deep-strict/链接/IPA CRC及二进制一致性验证通过。冻结助手首次误断言必须29库，已按实际产物核实：该设备目标包少一项 Swift CompatibilitySpan 库，不能直接继承为 iOS16 兼容包。

新 profile 至2026-10-31 04:23:18UTC，包含新 iPad 与13、不包含18；application-identifier/keychain-access-groups 与旧包相同。12:23设备目标包只为新 iPad 验证，13/18仍按10:57同源码完整29库包及各自有效 profile 核验，全局包入口未偷换为不适用变体。新 iPad 原无 Nastart，首次安装 Complete/lookup 成功，无卸载、无其他设备凭据复制。首次 DVT launch 报错；CoreDevice fallback 有进程但后续两图是桌面，不判正常首页或崩溃。保留报告拉取共7份、Nastart/WDA相关0份，不据此排除所有退出原因。

随后通过 WDA 以空环境/空参数启动，原生3/10秒两图均实际显示“连接你的第一台 NAS”，前台 bundle 与自有进程核实，已正常停止自有 App。当前 NAS 尚未登录，不能称 NAS 在线首页。iPadOS 当前窗口模式及用户 VPN/Wi-Fi 保持。

## WDA

从 Appium 官方 `v16.15.3` 固定源码 `02cb92f0e93c8b021443bcbb8eeb80932c113220` 构建，沿固定 runner/test bundle ID。第一轮退出65（工具链 /usr/local/include poison-system-directories 警告视错误），失败日志单独保存；仅本次 WDA 构建关闭 user search paths 并抑制该条告警，源码未改，第二轮 TEST BUILD SUCCEEDED。Runner/profile/各 bundle/完整 xctestrun 路径和 deep-strict 签名已核。

Runner SHA `702cce8a66d13792f360d68290f878bdd17a2f01ca2910d2244b8dc7b51a7fdd`，profile包含新 iPad、至2026-10-31 04:25:19UTC。标准 test-without-building 完成安装并建立 XCTest；实时 installed lookup、/status ready=true / productBundleIdentifier、session/source 与原生图均已核。WDA HTTP 使用本机 USB 直连8100，无其他设备重装或已有 Runner 停止。自有 XCTest 最长480秒、AC保活及退出清理；首次480秒到界停止XCTest（exit75为本批主动边界）；后复用已安装Runner的原生XCTest360秒到界停止，无再次安装，末App0/Runner0已核。

## 已完成的调试与保留失败

新Pad本地连续H264/AAC第一窗：18秒未见syslog first_frame明文，0截图/0候选提前停，预留10,394,424bytes；后读本机诊断新增ID证明已有first_frame，失败是采集器依赖被系统隐藏的字段，不能写播放失败。第二窗原生5图实际色条/时间码4.233→25.967，单次按钮后出现本地网络授权。原先“按钮消失”效果检查发生误判，旧summary保留并更正；独立新增持久事件确有1次debug_candidate_lab_requested/1次warmup，0commit，服务器仅原流请求，候选未成。无NAS请求，不把原流出画当候选切换通过。自有服务器/日志/守卫/保活停止、非诊断偏好相同。

用户随后回复“iPad已登录”。不重装Nastart/WDA，重新核实时USB身份/174输入/包/本机安装回执及安装路径，复用现有Runner建立360秒有界原生XCTest。13:07普通空环境/空参数NAS在线首页实图成立，首次本地网络弹窗已无。新设备菜单存在同名嵌套父子按钮，私有选择器限最外层，不以重复匹配重装App。

新Pad S01设备文件入口13:09：详情完整片名与路径核对后1次普通“从头播放”，3/10/30秒及末图实际片头/不同源画面已看；普通“完成”回同文件详情成立。正常KSPlayer/localRangeProxy路线，内部first_frame1/采样stall最大0；没有声音/完整逐帧/字幕cue或整格PASS。原书签0→1为本次首次播放新增，旧轨道变化0、其他偏好保持，不能写全部书签不变。新崩溃清单0。13:10恢复空环境普通NAS在线首页原生图已看；读取source早于异步恢复的“无正常文本”与稍后原生图分开保留。13:16新身份/源包/自有进程核App0/Runner0，桌面Wi-Fi/VPN/无PiP实图已看。Jellyfin入口与竞品尚未测。

13本批12:50:17保留数据覆盖同源码10:57完整29库包，25非诊断偏好逐值全同，12:51及12:58普通空环境NAS在线首页实图核。短本地KS→AV窗新增native hittable检查和当前应用回调，1次触摸派发年龄0.364秒/实际回调/commit均成立；6张原生图时间码推进，3/10/20/30秒横条隐藏，预留18,217,600bytes，偏好保持。不是实际NAS/PGS性能。

13真实S19窗最初样本参数小写s19被助手前置断言拒绝，0媒体/0协商/0候选，独立目录保留；仅修正调用参数后12:54:59新窗：实际原流4000.073秒，fresh12Mbps/H264/AAC/PGS8 Encode/start4012.008，candidate原生hittable=true/1次触摸/应用回调/完整提交成立。事件时间warmup→manifest 7.095秒、decoded12.447秒、aligned22.843秒、commit22.846秒，提交储备1.306秒；不与前批不同供给作提速A/B。3/10/30/45秒原生图静置横条均隐藏，末Candidate Lab/1:07:39已看；原流中英cue可见，但候选静置各图没有可验字幕cue，**不能关闭旧11:00候选字幕遮挡失败**。原流采样stall最大1、AV最大0；稀疏图/内部时钟不作全程流畅/声音/普通自动/Release验收。

私有动作记录器曾把最后显控动作时间误覆盖为候选派发时间；原summary另存，已按第一条sendingOnce改回，原图/事件时间未改。候选3/10/30/45是派发后计划点，不等于提交后同长度。末正常显控截图也不能标为纯静置。12:56停止自有App/日志/守卫/保活并DELETE精确自有NAS会话204，HTTP不单证编码进程退出；偏好全同/新增Nastart/WDA/Jetsam0。12:59独立源包/回执/USB/完整偏好两读稳定、36原书签轨道/其他24项/changedBookmarkFields空、App1/1、设置auto10/2、桌面Wi-Fi/无PiP已核。既有非本批13 WDA保留。

## iPhone18历史链路、恢复发现与当前阻塞

用户强调历史曾多次无线更新；已复核10-15、10-18及10-23原归档和10-23私有安装回执：昨天22:12:52.987273确已Complete、备份成功、已有escrow、正常NAS首页审阅。与本次意图UDID和保存Bonjour实例均相同。正确路径是实时DNS-SD→既有配对/实际UDID→HouseArrest完整偏好→AFC→installation_proxy Install→Complete/lookup→独立原生普通首页。无需WDA或USB；此前建议数据线仅备用，用户选择无线，后续不再作为前提。

初期“保存实例解析失败/名称不匹配”不能当全机离线。13:10对当前2条实际广播逐一使用目标已有配对核实时身份，第一条返回真实iPhone19,7/iOS27.0/paired，实际getValue UniqueDeviceID与目标一致；只探当前解析地址及广告/标准62078，无历史IP/网段扫描、重配或网络改动。13:13再次身份成功，HouseArrest已有EscrowBag的VendContainer响应断开；13:15 CoreDeviceProxy隧道握手断开。只读分层AFC信息、installation_proxy lookup、image_mounter状态均连接后协议reset。不能把这些说成“WDA没开启”或仅Xcode缓存失效。

用户新确认“18已解锁”后，重新解析当前匹配实例并核身份，再使用同一历史工具尝试保留数据安装；13:33:55仍在savingPreferences/VendContainer ConnectionTerminatedError，**0上传/0安装命令/0Complete/0启动**。不再重复催解锁。未有必要备份，不绕过备份门槛，不卸载/清凭据/修改网络。当前最新包未装、固定域名尚未在18启用或核实际会话，原配置未改；10:57兼容包签名/174输入/IPA/18 profile重新核有效至10-25 06:23:57本地，下次跨期先重签。

本次暴露名称假设，已在发现工具加入显式`--browse-current`：最多4条当前广播、逐条实际配对身份认证、移除广播不作候选、错误身份拒绝、失败独立保留；无名称相似就接受、旧地址或子网扫描。新增3项及原13项工具测试共16通过。这只修工具发现，不改App源码或声称备份服务恢复。新工具真机发现复核单独记录。

## 仍需接续

28需求不变；保留旧19×4=76格，新iPad19×2=38格独立（合计114），S01文件只补有限证据，其他格仍待测。下一步新Pad S01 Jellyfin入口与同机Lenna、受影响格式；13实际PGS需同轨同cue与横条失败对照、普通自动/真实失败协商，不重复无变化150秒长播。18先定位无线服务在解锁后仍reset的原因，现场变化后再备份安装；成功安装也须分开核保存地址/Keychain/实际DSM会话/媒体路线，不能沿旧自动恢复成LAN绕过用户域名要求。

## 接续与证据

私有入口 `/tmp/nastart-new-ipad-onboarding-evidence`；旧完整包入口 `/tmp/nastart-candidate-device-lab-evidence` 保持10:57。原始包、配置、设备身份、截图、报告及日志只留本机。结构化结果在 [安全结果](../../../testing/results/2026-10/2026-10-24-ipad11-onboarding.json)。本批全为 Wi-Fi，0蜂窝/0Mac NAS媒体GET；本批自有媒体、采集、测试宿主与保活均已结束，不声称回合后继续后台执行。

## 最终离线与数据核对

13:40新Pad在自有App/Runner已停止后再次读取完整偏好两次：非诊断内容稳定，S01前其他偏好逐值保持，书签仍0→1，没有为追求“全部相同”回写数据。174 App输入和ios diff重新核仍匹配当前两变体。独立remote-pairing广播1条，但本机无目标对应的该协议既有配对记录，仅记录能力缺口，不自动创建新配对或把任意广播当18。当前锁定/授权状态不足以解释所有协议reset，不再反复催解锁。

发现工具`--browse-current`已真机独立验证：当前广告1次认证到目标、identityMatches/paired=true、iPhone19,7/27.0/NETWORK、0App操作，不能替代容器服务。16工具测试通过，文档检查423份/2351本地链接/缺失0，git diff --check通过。既有未提交修改全部保留，未提交/发布。没有新增周期调度、NAS/VPN/手机网络/凭据改动，所有本批自有采集/媒体/Runner/保活结束。
