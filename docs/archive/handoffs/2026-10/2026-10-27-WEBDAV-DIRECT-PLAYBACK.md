# WebDAV独立媒体库直接播放：首个有限实现

2026-10-27接[TV季集与空系列](2026-10-27-TV-SERIES-AND-EMPTY-CATALOG-NATIVE.md)。本批从资料展示进入实际播放：129模块测试通过，三台留家设备已更新最终普通Debug包，iPad自有MP4和真实NAS MKV已有画面证据。真实NAS普通退出仍未验收；不是三端完整播放交付。iPhone18全程hands off，未安装、启动或连接访问。

## 接受的实现及源码映射

- `WebDAVMediaResource.swift`：仅从当前本机库中完全匹配的已索引视频创建内存能力，核库UUID/非File Station来源/所选根内精确路径/正大小/版本提示；拒绝陈旧或根外条目。一次GET最多1MiB，Range有限、Accept-Encoding identity；优先强ETag/If-Match，弱/缺ETag仅在严格HTTP日期可用时采用If-Unmodified-Since。响应必须206、完整精确Content-Range与索引总长、相同版本及精确完整正文；200全片、重定向、multipart/HTML/JSON/XML、编码压缩、短读/超量/版本变化均不返回媒体。412转为文件变化提示。
- `WebDAV.swift`的`DAVRequestOperation`：新增可选响应校验/精确正文长度，旧目录/NFO/图片调用默认nil保持原语义。每个读取仍独立ephemeral任务与20秒请求/25秒resource截止、Basic/Digest单次挑战、精确host/port、无ambient credential/cookie/cache及不跟跳转；播放用系统TLS信任。取消时丢弃已缓存字节并终止自有请求。强ETag/修改时间是乐观HTTP版本条件，不是远端文件系统原子快照/物理目录锁。
- `WebDAVPlaybackSession.swift`：只监听127.0.0.1随机端口，随机token路径只映射同一个文件；解码器拿不到原NAS地址、账号或密码。单会话最多2本地连接、16KiB请求头、10秒监听准备/30秒本地空闲上限。GET/HEAD、单段/开放/suffix Range；不接受其他文件、复合Range、重复/歧义头或请求体。先校验首上游窗口再发成功；客户端收到连续已知Content-Length响应（完整无Range为200、范围为206），每个1MiB上游窗口不当客户端EOF，版本中途变化会关闭不完整正文而非伪装结束。发完/客户端失败/stop时关闭本轮连接和任务，撤销URL；不改原AuthenticatedMediaStreamProxy窗口、HLS或DSM/Jellyfin路线。
- `SourceContext`/`LibraryViews`/`LibraryPosterWall`/`NetworkLibraryPlaybackView`：宿主提供既有播放器回调，单文件详情新增播放；多文件按成员明确选择，原盘不猜主片、分段暂不自动串播；ISO和File Station索引未开放此新入口。创建时重新读当前库，以该库UUID从Keychain取已有WebDAV登录，只在内存持有。关闭/消失撤销本机会话。回调随共享模型传入所有详情/季集弹层，不再依赖第一候选的环境继承。
- 移动`LaunchpadLayoutViews.LaunchpadMediaShortcuts`将本机URL/标题/长度交现有`GreenfieldVideoPlayerView`，实际引擎随既有规划；TV`TVNASViews.TVNetworkLibraryPlayer`复用设备文件KS渲染。没有借用DSM/Jellyfin凭据或匹配/转码回退；File Station可仍从浏览文件走旧路线。稳定续播键、下一集、网络库sidecar、ISO和多段串播仍待。

## 测试与构建、失败保留

新增16项：库/路径/版本/整数溢出与预算；真实HTTP的Basic与Digest、连续/seek/suffix/chunked正文、忽略Range/错误状态、不同大小/版本/缺失版本、短/超量/编码/错误文档、不跟跳转、不跨资源带cookie/认证、预取消/进行中取消；实际loopback的完整3窗口、HEAD不读源、非法目标/方法/Range、撤销与中途版本变化不成功结束；本地HTTP解析歧义/溢出边界。最终完整129项0失败。首全套120秒超时，末打印在既有NFO/网络段，不能由缓冲日志准确定位根因；仅停止记录的自有测试树后复跑123过，桥/宿主完成后129过，最终模型回调版再129过。没有为绕过超时修改旧认证。

App输入从393增至399，最终冻结逐SHA零漂移。最初环境回调候选已双构建并签包，但iPad详情不出现播放按钮；读容器确认精确1个MP4/正确来源及安装身份，改为共享模型后出现。失败候选包完整归私有before-model-playback-route-package；旧fa4c98/831f47归before-webdav-playback-package，不覆盖旧证据。

最终双普通Debug：移动12:18:56.325690+08 SHA `4d82d6adfe8f30ca0edccef8bef03533ada02bed5ef645b90f3eacce65d40f20`，TV12:18:44.395767+08 SHA `00ec0f2254a1ae4aa7af5fc2312fc1691714493f24a5f921c946868f6b4b4614`。30/27 Mach-O逐签/profile/IPA核，399输入零漂移，无App测试参数/环境。Pad12:19:27、13 12:20:45、TV12:21:05逐机fresh名称/型号/系统/UDID/连接后保留数据覆盖Complete，19/26/15非诊断偏好同、正常首页实看。不是Release或完整格式回归。

## iPad自有视频与真实NAS证据

Mac自有45秒640×360 H264移动条MP4（无音轨），HTTP Basic/只读WebDAV表单入库。首表单宏110秒到期时已经读到目录，第二段65秒到期后在详情且没有播放按钮；现场分段取证，不当连接认证失败。最终模型版在已保存临时库出现播放按钮。首播放窗3/10/30秒实图不同，但退出脚本用未支持的`/wda/tap/0`，立即由失败清理主动停App，非普通退出或崩溃；更正为上游[WDA元素命令](https://raw.githubusercontent.com/appium/WebDriverAgent/master/WebDriverAgentLib/Commands/FBElementCommands.m)的`/wda/tap`后第二窗3/10秒与正常回原详情成立。第一窗和第二窗日志/图片均保留。临时脚本后来复用了safe JSON文件名，夹具退出结论以第二窗NORMAL_EXIT日志和回页图片为依据，不能引用被后窗覆盖的JSON。

夹具总18请求/6个206，视频窗口最大1MiB、顺次覆盖2,640,017字节；0写请求，源hash相同，服务已停止/端口闭。是本机合成来源，不能代替NAS/声音/高码率性能。

真实NAS复用iPad原WebDAV登录，从原3,408文件索引精确找到S01 MKV（2,949,955,051字节），搜索后详情完整路径与私有索引核一致。第一WDA点击25秒超时，没有实图，清理主动终止App；不算NAS不可用或闪退。播放前独立Mac诊断只读0–65535：HTTP206/65,536字节/Content-Range和ETag均匹配，14.43秒；这是Mac诊断，不是手机TTFB/吞吐或新生产读取层验收，且与后续App媒体窗串行。

随后用独立DVT截屏避免依赖WDA source：点击后3.71/10.66/30.69秒均有不同实际电影画面，App进程同窗存在；实际画面已看。构建映射上此临时本机URL只能读取所选WebDAV文件，没有DSM/Jellyfin回退；但本窗没有抓原生HTTP字段/完整帧时间，不能把源码映射当实测Range日志、连续流畅或具体引擎输出验收。字幕显示/听音/音轨/seek/PiP/恢复均未验。

30秒后WDA `/source` 仍超时，未进入普通关闭按钮验证；外层finally已通过原生ProcessControl主动停本轮App。真实NAS的普通退出/控制响应仍未通过，保留调用栈，不称崩溃，也不把实际能播扩大为完整验收。后续先隔离WDA查询与App主线程响应、用已观察的原生控制区域/独立截屏确认关闭，再扩大终端/格式；不盲加播放参数或改NAS。

## 数据、设备与收尾

最终App内移除唯一临时夹具库，Pad原1库3,408完整snapshot同本批fresh基线；13和TV各原1库149，与上批最终只读基线完整同（不是本批安装前新采样）。三个设备非诊断偏好最终全同；若严格包括诊断键，Pad/13各1项自然诊断值变化、TV0，没有回写原偏好掩盖。iPad当轮WDA设置10/2/50已恢复，自有Pad/13 HTTP会话DELETE200，原Runner保留；本批没有启动TV WDA Runner。真实NAS两次失败均记录主动停止，夹具服务器已停，无自有媒体流/临时库/采集留存。没有蜂窝任务、NAS/VPN/系统配置或TMM写源命令。

13/TV只最终包安装/正常首页，本批尚无独立WebDAV播放真机证据；18不操作。30需求14进行中/5待验收/11待开始、原114格不新增P。网络库WebDAV播放由“完全未接”推进为“单文件有限实现+iPad画面成立”，普通退出/全控制/跨端/高码率/弱网/稳定续播仍开放；FTP生产和SMB严格范围亦继续。

[结构化结果](../../../testing/results/2026-10/2026-10-27-webdav-direct-playback.json)。原始设备、包、地址、凭据、索引、截图和日志均仓库外，私有指针`/tmp/nastart-tv-storage-ui-evidence`下`current-webdav-playback-batch-private`。

最终核对：486文档/2878本地链接/0缺失，git diff --check过；399输入零漂移，最终包所有二进制/深签与逐机回执匹配，公开新结果凭据值匹配0。新loopback来源的外部播放器交接/离线下载亦未验，不由既有播放器菜单推断支持。
