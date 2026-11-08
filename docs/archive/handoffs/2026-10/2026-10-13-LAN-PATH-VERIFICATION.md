# LAN 验证绑定网络代次，蜂窝可达入口仍待修复

本批定位并修正了 Jellyfin 已验证局域网播放地址跨网络继续生效的问题。最新普通包已保留数据安装到 USB iPhone 13、USB iPad 和无线 iPhone 18。原 Wi-Fi 详情页 → 关闭 Wi-Fi → 播放的实测仍失败：旧 LAN 验证已失效，但媒体库本身的地址也是 privateIP/http/8096，因此此次不能宣称蜂窝首帧或 seek 已修复。

## 变更卡与版本

- 关联 PX-01/PX-03/PX-21：选路必须属于当前网络观察代次，迟到的 LAN 探测不能发布到新路径；选择的私网属性必须对应当前播放地址。
- 本批变更卡记录于 18:35，见本机 `change-card-safe.json`。基线普通 Debug 是 dirty 源 `5aa9070d0dbc15fac31175c1395f762e6e8a6b3df3880eb6dcd3cac29a76fb2b`，17:13:23 构建，主二进制 `4904f0f2`、Debug `4ec96d31`、KS `6be1f678`。本批开始先核此包并覆盖双 USB，再建立基线。
- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`。最终 dirty 源 `16c358c3729200a986c1c464cd262a9925cedb7cad401a09fa1b0fc4a8b20afb`；普通 Debug `-Onone`，构建时间 `2026-10-13T18:38:52.091180+08:00`。
- 相对本批 5aa 基线仅改 `LaunchpadPlaybackCore.swift`、`LaunchpadView.swift`、`PlaybackNextCoreTests.swift`。其他既有未提交修改保留。新增 `pathGeneration` 与带宽 cacheKey 分离；缓存读取与探测提交均核对代次；实时重算所选地址属性。有限 DEBUG 诊断记录网络类型、代次、选路类别，不导出实际地址或凭据。
- 四项确定性测试覆盖同路径复用、Wi-Fi → 蜂窝与迟到结果、返回 Wi-Fi 不复活旧验证、未知路径拒绝及新鲜蜂窝/VPN 验证仍允许。没有修改登录/SID、token 迁移、Range、超时、重试、缓冲、轨道、解码或 seek 参数。
- 实际完整 359 测试、2 跳过、0 失败，15 项 preflight 和正常构建成功。最终两条诊断补入后重新跑完整测试；前一次同样通过的记录也保留。173 个构建输入、29 个独立库签名、App deep/strict、profile、链接及 IPA 内三份二进制均核验；19:54 最终重核源码输入、源码差异、三 SHA 与签名。

| 二进制 | SHA-256 |
| --- | --- |
| Nastart | `fd13488512003156fb808172a5db332a55ed497e9553351f417d8efdca873faf` |
| Nastart.debug.dylib | `a75388310cfad3dd28aaa0dbb84982cfd49b4d7f1391d397ff7edb064c6526f3` |
| KSPlayer | `6be1f6780b3edd377d2ef6ee2e144c9213b831f45969eedbb7f7601b93067559` |

当前包为本机证据根目录中的 `Nastart-LAN-Path-Verification-Normal-Debug.app` / `.ipa`，profile 到期 UTC 2026-10-17 22:23:40。版本号 0.1.0/1 不作为安装身份依据。

## 三台设备安装与工具故障

| 设备 | 当场型号/系统/连接 | 最新安装完成 | 安装时数据核对 | 最新 UI |
| --- | --- | --- | --- | --- |
| iPhone 13 | iPhone14,5 / 16.3.1 / USB | 18:40:31 | 25 项非诊断偏好逐值相同 | 空 env/args 正常首页，逐窗核包 |
| iPad | iPad12,1 / 18.3.1 / USB | 18:48:42 | 18 项非诊断偏好逐值相同 | WDA 恢复后空 env/args 正常首页，逐窗核包 |
| iPhone 18 | iPhone19,7 / 27.0 / NETWORK | 19:50:33 | 25 项偏好全部保留，lookup 存在 | DVT 空参数启动返回 PID；实际截图仍为其他 App，Nastart 前台 UI 未验 |

每次设备与窗口重新读取名称、型号、系统、UDID 和连接，与本机记录匹配后执行；没有卸载、清数据或重新登录。名称、UDID、原偏好、凭据及原图只保存在本机私有目录。

iPad 覆盖后两次 `/status` reset，代表回归第一次也在开窗前 reset。实际拉取 crash reports，报告集合 0 新增；原生进程信息均显示 Nastart 在、Runner 不在。启动既有固定签名 XCTest fixture，未重签或构建 Runner；首恢复完成 S01 后又中断，随后用独立 XCTest 进程、新空 session 恢复。XCTest 使用既有 fixture 的系统安装行为以私有原生日志为准，不声称没有发生自动安装。恢复窗不抵消原 TOOL 故障。

iPhone 13 首个最新 S03 文件窗完整；随后 JF 窗捕获至 t7，WDA `RemoteDisconnected`，后续 session404。已实际拉取报告并读容器诊断，报告集合 0 新增。Runner `/status` ready、session null，未重装 Runner；新空 session/普通启动后 S03/S08 两入口恢复窗补齐。原不完整窗保留，不能计作 30 秒或正常退出通过。

18 本批初次发现和默认端口探测无可信身份；用户解锁后，现场广播端口也超时，既有远程配对记录未匹配到广播服务。最后对先前成功的直连地址做实时配对身份核验成功，才进行签名验证与覆盖。安装不依赖 WDA；之后用户态 RSD/DVT 隧道可用，WDA HTTP 不可用，Xcode 自动隧道仍未核通。Mac VPN、系统 remoted、配对记录均未改变。不能把默认端口超时单独归因为手机掉线，也不能将本次直连成功写成自动发现恢复。

## 历史 119 会话归属调查

分析的是上轮 5aa 原始失败，不是新 16c 回归。首次 FileStation 成功登录/attach 到 snapshot119 的单调时间差只有 104ms；请求角色是 FileStation，请求认证代次与刚发布的 FileStation 代次匹配。三个原快照合并后有 snapshot119 四条、root119 四条；17:24:03、17:31:46、17:33:55、17:35:33 四次 root 失败仍属于相同主会话/FileStation/请求代次，所捕获区间无 logout。原生重试与首页刷新没有建立新 FileStation 会话。

这没有证明服务端 119 的根因，也没有证明是旧缓存代次污染。本批先在 5aa 双 USB 各三次普通冷启动进入文件根目录，六次实际视频目录图均可见，无 119；随后 Pad 按原 S03 文件 → JF → 普通冷启动 S08 文件 → JF 顺序复验，四个 30 秒窗和正常退出完成，原图已看。上述是基线记录，不冒充 16c 最新包验证；恢复正常不能关闭历史失败。本批没有改认证或自动重登录策略。

## 原蜂窝操作仍失败

两次都从普通 LAN 首页登录、进入同一 S03 JF 详情，再用原生设置确认 Wi-Fi OFF 后点播放；不是从全新蜂窝媒体库打开，缓存、源轨/点位和持续时间不构成严格速度对照。

| 源码 | 准备时所选路由 | 样本观察末端 | 实际 t60 / 内部首帧 / metrics |
| --- | --- | --- | --- |
| 5aa 基线 | 已验证 LAN，privateIP/http/8096；媒体库原地址亦为私网 | 210.667 秒 | 黑屏 spinner/00:00；0 内部首帧，0 URL metrics |
| 16c 候选 | network=cellular、pathGeneration=3、libraryEndpoint，privateIP/8096 | 119.699 秒 | 黑屏 spinner/00:00；0 内部首帧，0 URL metrics |

候选已拒绝旧 LAN 验证，但回退到的媒体库地址依然不可用于当前蜂窝播放。Native 滑块/±15 控件尝试未产生 seek_started；这是启动失败，不能用来计算 seek 恢复速度，也不能把不同删失时长视为提速。

只读设备服务配置确认另有 HTTPS/domain/8097 备用入口，与 privateIP/http/8096 不同源。当前媒体库恢复会话按候选顺序取首个存在的 endpoint-scoped Keychain 会话，并不在网络切换时重新选择。备用域名存在并不证明其有有效会话、同服务器或同账号；本批未向备用地址转发当前 token，也未替换 client/书签身份。

另保留旧 ac8 深续播 HLS 失败分析：目标 ordinal 1695/1692 在各 20 秒 seek 窗约 0/4/14 秒重复发起，没有响应头/完成/metrics；seek 前 ordinal1692 曾 200 返回 2,017,240 bytes/1.02 秒。没有证据把 clientReadEnded/FIN 直接解释成可取消的断开，合法半关闭 GET 规则保留。它与本批从头启动不是同点同源对照。

## 最新普通包回归范围

S01 两机/两入口四窗，加 S03/S08 两机/两入口八个恢复窗，共十二个最新普通 30 秒采样与正常退出窗口；另有 Phone S03 文件一窗完整重复及 JF 一窗 TOOL 不完整。选择的真实 PNG 已查看，逐窗包身份独立记录。内部首帧不是精确首个可见帧，采样不代表连续 30 秒播放、完整显示帧时间、听音、字幕原句或 HDR 验收。

| 样本/入口 | Phone 首次内部首帧 ms | Pad 首次内部首帧 ms | Phone/Pad metrics（全部 cellular=no） |
| --- | ---: | ---: | ---: |
| S01 文件 | 714 | 1027 | 2 / 2 |
| S01 JF | 674 | 1160 | 2 / 2 |
| S03 文件恢复窗 | 896 | 1565 | 7 / 12 |
| S03 JF 恢复窗 | 789 | 2071 | 5 / 12 |
| S08 文件恢复窗 | 3183 | 5444 | 3 / 2 |
| S08 JF 恢复窗 | 3097 | 5719 | 2 / 2 |

Pad S03 文件 t10 星星片头、t15 黑屏 spinner（接手期间）、t30 黑屏无控制；JF t15 Paramount、t30 暗片头字。两窗存在自动降档/接手，第二次内部首帧分别 7075/13982ms（各播放器内部起算），不判完整连续播放或性能通过。Phone S03 选定 t30 为 Cruise/Wagner 片头，S08 两机实际科研场景；S01 为云层片头，部分有字幕。缓存、轨道、接手、观察条件不同，不进行设备排名或速度验收。

19:54 最终源/包/双 USB 身份重新核对：Phone 原 24、Pad 原 17 非书签偏好逐值不变，各六个书签自然变化；S03 文件/JF 原音轨、字幕和 Off 选择不变。两机实际空 env/args/NAS 正常首页、播放器关闭、idle10/动画2；Phone 原生 Wi-Fi=1，两机原生条件 active0。前后 Nastart/WDA/Jetsam 完整报告集合均 0 新增，不关闭旧 Network 崩溃或长期稳定性缺口。

## 接续与未完成

下一步优先用本机安全布尔观测核对 HTTPS 备用入口自己的 endpoint-scoped 登录会话、同服务器与同账号，并固定异步验证/网络代次所有权反例，再决定最小选路修复。不能因为配置了备用域名就复制 token，也不能无条件禁止蜂窝私网（有效 VPN 路由应保留）。原 Wi-Fi 详情 → 蜂窝播放必须重新成功后，才继续相同点位的首帧与深 HLS seek 配对测量；本批不验收原启动修复或性能。

119 的服务端失效原因、Pad TS02 硬解暂停花屏、Phone 旧 Network SIGTRAP/物理内存与长压、增长 TS 尾部追加/时长刷新/内容替换、横屏旋转轮廓、18 前台 UI/自动隧道、完整 SUB/AUD/HDR/PiP、Lenna 等竞品完整帧时间、真实弱 RF/外部 Wi-Fi/十分钟、S19 深位置、MTP-01～03、S11/S18 JF、完整 L2/19×4/PX/UX/CB/Main/L3 全部保留。当前规则只完成了 LAN 缓存代次保护与限定回归，未完成上述总任务。

脱敏机器摘要：[LAN-PATH-VERIFICATION-20261013.json](../../../testing/results/2026-10/LAN-PATH-VERIFICATION-20261013.json)。原始日志、原偏好/凭据、USB 身份、无线地址、PNG/XML、IPS、签名包、命令和冻结脚本哈希仅留本机：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-13-folder119-ownership-181128`。工具修正及失败/恢复记录均保留，未提交或推送 Git。
