# 保存门槛、内存提交与外部磁盘观测

2026-10-22 02:28–02:46。关联PX-08/PX-21，承接[旧保存边界缺证](2026-10-22-TRACK-SAVE-OFFLINE-BOUNDARY.md)。旧15:39失败seek已完成、磁盘仍ASS，不以等待/同步写盘掩盖。本批只抽取真实播放器保存边界以便反例测试，并增加Debug强制边界诊断；不宣称原失败根因已定位或产品修复。

## 本批实现（诊断，不是保存修复）

- GreenfieldVideoPlayerView的原进度/选轨推导移入同路径PlaybackLocalResumeCheckpoint，clock每2秒/close/disappear/生命周期的原门槛不变。旧返回Bool代表允许调用store，即使store内部拒绝无效时间轴也保留原cadence行为。
- LocalPlaybackResumeStore.save新增返回值（旧调用可忽略），明确invalidTimeline/encodingFailed/submitted；可选在同一把锁内读取刚写入的同key内存entry并逐字段比较。submitted只证明set调用，不保证内存匹配或磁盘持久化；新观察不调用synchronize、不重复set、不改schema/128条保留/recording语义。
- Debug只有close/viewDisappear/scene/native/pipWillStart等强制边界发local_resume_save_boundary；普通clock保存不新增日志，Release不启用内存回读与此事件。输出有限门槛布尔、源类型、完整owner UUID、源音字幕ID、保存结果、写后内存match/mismatch/notObserved及entry更新时间（Apple参考秒）；不输出key、URL、标题、账号或凭据。原guard拒绝仍不写、不通知。
- 七个反例接实际checkpoint/store：ASS→PGS/另账号隔离与字段隐私；启动/seek保护；completed后暂停预览仍阻止；无效时间轴不假报submitted；未知/重名sidecar不借旧ID；受控丢弃set区分submitted与内存mismatch；direct/missingkey不提交。现有相关ready/seek/recording测试按影响范围接续，不用它们证明真机磁盘。

私有指针`/tmp/nastart-resume-save-boundary-evidence`保留源码基线、原工作区dirty、构建/包/设备/偏好/原图与日志。旧包指针`/tmp/nastart-candidate-error-chain-evidence`为19:52历史包，不能当当前源码最新回归。Pad/18未操作，18用户选择暂缓保持。

## 测试、包与安装

143项NonPlaybackPolicyTests：142通过/1既有设备配置缺失跳过/0失败，Xcode正常退出；七新增反例全部执行。另用已构建测试包test-without-building执行11项已有recording/LocalResume测试，11通过/0失败，含append/替换/截断/迁移、身份隔离、无效写入和通知顺序。143项的结束标记为TEST SUCCEEDED，11项为TEST EXECUTE SUCCEEDED，分别核正常进程退出与实际用例数，不重复测试。15预检通过。

一次正常Debug/-Onone/Xcode27构建02:35:01.178821+08，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加保留dirty；iOS diff `636192ec133fd31f3c6a404d68fd589c861a4edcf13156108e5d021458fc1911`，IPA `5c9216e950cd38435de76fa618042aa0b0ddf87e31eb55229c4b77b65ac4aae3`。173源码输入/29库逐签与深签/三二进制/profile/IPA CRC、AppleDouble与链接均核验。完整三SHA/包路径在私有current-package.json。profile仍至UTC10月24日22:23:57，不延长或换签名。

13现场身份/USB重核后02:38:28保留数据覆盖安装成功，25完整非诊断偏好逐值一致；未卸载/改凭据/WDA/网络。App能空环境启动并产生当前新日志/AX页面，但**NAS在线首页未完成**，安装回执actualForegroundUIVerified仍false，不冒充正常首页或播放回归。Pad/18未安装此新包，仍10-21 15:39历史包，18用户暂缓不再探测/催促。

## 正常启动失败保留，未发起媒体

02:39第一窗只等NAS在线18秒，API.Info在约8秒失败后尚不足以覆盖后续POST18秒，保存为观察不足、finally已停App/采集，不把它当完整登录deadline失败。第二窗改为覆盖完整阶段的50秒有限观察，并逐次保留最后AX；这不是重试点击或新增隐式登录重发。

| 10-22本地日志 | 第二窗实际事件 |
| --- | --- |
| 02:41:08.542924 | 开始连接DSM |
| 02:41:16.927383 | SYNO.API.Auth信息读取失败 |
| 02:41:35.108838 | Auth v7/login单次兼容尝试timeout |
| 02:41:35.109542 | DSM登录失败/timeout |
| 02:41:35.165092 | 会话恢复失败/urlError:-1001 |

API查询约8.384秒、随后登录至失败约18.182秒，是本窗日志跨度，不当整体连接性能或服务器耗时。最后AX明确“当前显示缓存数据”“DSM未连接；服务在线仅表示该服务地址可访问。点此重新连接NAS”，不是正在恢复无限未结束或已NAS连接；未有原生App页面失败截图，只保留AX/实时日志与最终原生Home，不补造画面。13复现超时仍不能直接解释18历史根因，认证/网络实现本批未改。

Mac另一次无凭据API.Info GET只用偏好中已记住的host与原自签配置，connect-timeout3/max-time6，DNS0.017秒、TCP0.221秒，TLS没有完成、HTTP0/0bytes/exit28，总3.026秒。该记住地址与本次keychain实际登录端点未证明相同，故不能作为同端点定责/改路依据；也不能单凭此断言NAS停机或App认证根因。没有媒体、密码POST探针、NAS/VPN/DNS/SSID更改或竞品重复请求。

本批0 Play/0 PiP，计划的ASS→PGS真实内存/外部磁盘窗口**未执行**；没有实际local_resume_save_boundary提交日志可用于原故障归因，不把七单测或旧包窗口当本包真机验收。停止继续登录/影片重试，待可核验的连接条件再接这一个窗口，不为复用旧证据调大等待/同步写盘。

## 收尾与接续

02:46再次重核173输入/包/全部库签名/profile/本机USB身份；25完整非诊断偏好与安装前逐值相同，36书签及进度全部相同，零媒体引起变化。App/自有采集/构建runner均结束、原生无App，最终Home无PiP/Wi-Fi图标实际已看；当前有效session在私有iphone13/normal-home-complete-restore-ui/session-id，auto/idle10/cool2 GET核实，旧01:31 session已替换。网络/蜂窝/SSID/VPN未改，持久13 WDA保留，原始crash文件名收集在私有目录（本批无精确开窗crash基线，不报当窗零新增崩溃）。

[安全结果](../../../testing/results/2026-10/2026-10-22-resume-save-observation.json)与当前文档同步。已交付编译/确定性边界与安装证据；真实保存/完整字幕PiP/NAS成功与速度、Pad/18回归仍未验收，28项保持开放。连接支线保存现场后可继续不依赖NAS的已授权工作，不自动改NAS/系统或第三轮同条件播放。
