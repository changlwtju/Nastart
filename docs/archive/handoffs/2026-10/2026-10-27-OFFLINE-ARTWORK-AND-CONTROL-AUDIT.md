# 离线海报首片、调试控制审计及iPhone18紧急更新

2026-10-27接[方向/FTP路径批](2026-10-27-IPAD-EXIT-ORIENTATION-FTP-PATH.md)，保留HEAD4de732d和其他dirty。[结构化结果](../../../testing/results/2026-10/2026-10-27-offline-artwork-and-control-audit.json)。私有指针`/tmp/nastart-tv-storage-ui-evidence`内`current-offline-artwork-batch-private`定位本批；包、报告、域名、凭据、设备身份及用户索引均不进仓库。

## 用户新约束和实际媒体库

用户已在iPhone18连通WebDAV，真实本机索引只读核149视频，其中90份NFO/简介/提供方ID、59份文件名结果、0本机纠错。用户尚未申请TMDB授权，明确先做离线资料与海报墙；已装tinyMediaManager Docker，优先读取其已有NFO/图片。没有注册账户、借用第三方key、配置或触发该容器。远程刮削/改名可能写源，不属于本轮只读接入。

TMDB非商业免费且要求署名，商用需按[官方FAQ](https://developer.themoviedb.org/docs/faq)询价；149美元/月是[第三方资料](https://docs.simkl.org/how-to-use-simkl/faq/how-to-add-new-shows-missing-episodes-and-movies-to-simkl/tmdb-for-movies)的粗略参考，未取得本项目正式报价。网易爆米花具体授权未核到，不推测商业合同。[tinyMediaManager命名/资料](https://www.tinymediamanager.org/docs/movies/settings)及[HTTP API](https://www.tinymediamanager.org/docs/http-api)只用于接入设计，不意味已调API或取得上游商用许可。

用户随后明确：iPhone18已带去上班，后续仅iPad、iPhone13和客厅TV调试。**iPhone18 hands off，不再安装、启动、切页或采集。** 此前用户已授权设备空闲时独占调试，其余三台继续该窗口，不把手动操作与自动化混在一起。

## 本次实现和未验收

共享模块新增LocalArtworkReference/Selection、LocalArtworkCache及LibraryPosterWall。扫描只记录同目录确已列出的JPG/JPEG/PNG，优先视频同stem的-poster/.poster/裸stem；目录poster/movie/folder/cover仅在单电影时采用，不推测多电影或单集共用封面。NFO内远程图片URL不访问。路径/大小、strong If-Match及WebDAV精确origin/不跳转保持；图片每份2MiB，声明长度不符拒绝。FileStation复用原只读download校验，真实图片链尚未验。

缓存仅本机Caches，绑定source UUID/地址/账号/选根/图片版本；有效版本才落盘，坏缓存重取，无版本不持久化；64MiB/300图、最多2并发、取消停本次请求。ImageIO仅JPEG/PNG单帧，8192边长/3200万像素上限，缩略图768；SVG/HTML/异常数据不展示。扫描事务/旧索引保持；optional artwork及artworkScanVersion兼容旧Snapshot，旧库进入页面会尝试一轮完整有界资料整理。没有在线匹配、独立源播放或NAS写操作。

三端共用海报网格/列表切换、搜索、详情/NFO简介和本机纠错入口；来源管理折叠。初版tvOS DisclosureGroup不可用已换共享显式展开按钮；新测试首缺try编译错误已修。新增12项后93测试0失败，包含真实HTTP认证/If-Match/拒绝跳转/字节预算/取消、图片解码、缓存隔离/损坏/并发/取消和旧库事务。双普通Debug构建过。

**海报展示未验收，用户已报告失败：** iPhone18更新后看到全部“暂无封面”，并指出分段文件、附加视频、光盘内部文件误作多部影片。网格出现不代表已取得真实封面；下一先查图片实际存在/命名/目录范围、迁移扫描是否取消和读取错误，再增加逻辑影片分组。物理文件索引保留，明确CD/Disc等分段合并，花絮/预告归附加内容，蓝光内部片段按光盘目录汇总，歧义不武断合并。上述分组尚未实现，不声明已交付。

## 安装身份及设备现场

386本地输入（非完整依赖闭包），普通Debug arm64/空参数环境，30/27签名Mach-O、profile/IPA/TV嵌入已核。

- 移动构建06:29:15.631689+08，主SHA `4e1661c2926ac930d3989f2e149459bc4b2e2e3daab9327366ae885b6c6de050`。
- TV构建06:29:11.598224+08，主SHA `649b5884501c8a91ea3e3dc78e61c4a36464edd06bab52016779aa34b55bdb73`。
- Pad/iPad15,7/26.6 wired：06:32:40保留数据Complete，19偏好同；后见用户正在填写WebDAV，立即保留草稿、未改字段或取消，删除自有HTTP会话/原Runner保留，未跑夹具海报页。
- 13/iPhone14,5/16.3.1 USB：06:40:38 Complete，普通首页基线与26偏好同；自有会话已清，旧系统目录故障仍开放。
- 客厅TV/AppleTV14,1/18.2 LAN：06:39:39 Complete，普通首页基线/存储页可达，14偏好同；海报夹具连接前因用户反馈控制干扰停止，夹具0请求、源同/停服/端口关闭。自有Runner已停、3项WDA设置GET恢复，原手机Runner保留。
- 18/iPhone19,7/27.0 仅Wi-Fi：06:04旧a34a6a包无线Complete/正常启动已核，截图为NAS选目录会话错误；06:40新包安装派发120秒超时留档，随后只读lookup仍装有App，149索引与尝试前逐字节同，但不能据lookup认包。用户最高优先级要求出门前更新后，fresh Bonjour/配对身份与386输入重核，**07:00:30最终4e1661…无线Complete/lookup/27偏好同**，07:00深色NAS正常首页和Wi-Fi已实看。最新包已装，不再保留“锁屏/未装”为当前阻塞；原失败仍存。未更改保存DSM地址/Keychain，实际固定域名会话及视频路线仍未验，首页不替代。

## “闪退”与调试操作的区分

用户指出可能是助手控制造成退出。立即停止主动安装/重启/切页，结束自有WDA和夹具，只读列报告而不flush/move/erase；保留手机原Runner和Pad用户草稿。时间线确认13/Pad/TV安装与基线含主动重启，18也有无线安装/启动操作，足以干扰用户手动连接。清理自有会话本身也不能默认无副作用：[上游DELETE调用kill](https://raw.githubusercontent.com/appium/WebDriverAgent/master/WebDriverAgentLib/Commands/FBSessionCommands.m)，[kill会依shouldTerminateApp结束AUT](https://raw.githubusercontent.com/appium/WebDriverAgent/master/WebDriverAgentLib/Routing/FBSession.m)。这仅证明上游能力，未现场验证当前各Runner确切清理行为。

13读到真实309报告：06:40:34 FRONTBOARD `0x8BADF00D`，background scene-update超10秒，主线程SwiftUI/AttributeGraph；不是普通主动终止。Nastart.debug.dylib UUID `c2e5c58c-c4ca-3190-bbd7-12e81f0186cf`精确对应旧a34a6a包，非新海报包A839756B…；发生在06:40:17开始/06:40:38完成覆盖之间，因果触发未定，不归新海报页也不抹去旧iOS16布局卡死。Debug启动器UUID三包相同，不能只用主stub UUID认包。13被动DVT进程读ConnectionTerminatedError保留；18/TV本窗未见新NAStart/Jetsam报告，不证明从未退出，未强制flush；TV末进程不在也不单独判崩溃。

私有安装/启动/会话助手加只读模式阻止，未来会话拟设shouldTerminateApp=false（尚未真机验证）；用户随后明确设备空闲可独占调试，再改为exclusive。之后最高优先级只做18更新，用户离家后控制文件将18加入handsOff，仅Pad/13/TV可继续。不可把旧自动重启当App缺陷或用无报告抹去watchdog。

接续优先：其余三机新包核对→独占复现/隔离13目录卡死→真实图片/分组修复及三端海报页→只读独立源播放/FTP端点凭据适配/SMB严格范围。用户手动操作时停自动控制，不重复以安装重启干扰复现。30项14进行中/5待验收/11待开始、114格无新P，无蜂窝/视频命令/周期任务或回合后后台承诺。
