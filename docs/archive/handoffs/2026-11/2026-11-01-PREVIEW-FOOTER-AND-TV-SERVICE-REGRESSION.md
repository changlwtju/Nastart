# 预览页脚、TV服务遥控与NAS配置文案

日期：2026-11-01。承接[离线设置补验](2026-11-01-OFFLINE-SETTINGS-RECOVERY-AND-PRIVACY-PREVIEW-THEME.md)。NAS恢复期仅本机源码与自建模拟器；0真机发现/控制/安装、0NAS请求、0真实凭据读取、0播放/源目录写入。不改NAS/VPN/开发账号/profile，沿用既定模型分工，无Astra、定时或后台任务。既有脏树保持。

## 接受实现

- AppTheme：Debug移动settings固定底部标记移入列表页脚，sync/player改为表单内滚动标记；TV播放器预览两卡及说明加focusable，补大字遥控承载。正式设置和真实操作未改，移动实际画面仍受阻。
- TVLaunchTests：新增3个原生遥控例，glassDeck深色标准、commandCenter深色标准、cleanGrid浅色大字。实际从设置Right/Select进入，核四服务顺序/合成状态、说明完整可见、Menu返回播放器入口焦点。
- LibraryViews：正式共用连接清单“当前 NAS 已登录”改为“当前 NAS 登录配置”，仅这一处显示文案；账户、状态机、来源构造、请求、播放不变。

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；446输入仅以上3个既有文件变化，其余443个hash同。源码/构建/时间/二进制SHA-256/原始诊断及偏好仅留私有指针 `current-offline-preview-footer-private`；[共享结果](../../../testing/results/2026-11/2026-11-01-preview-footer-and-tv-service-regression.json)无设备ID或私有路径。播放架构/路线/引擎/缓存未变，114格无新P。

## 失败、修正与实际证据

首版测试额外要求底部60点，实际说明y=1003/h=24，1080高画面留53点、实图完整。该1例失败是测试边界假设，原日志/图保留；改按真实页面可见边界判断，不把此阈值当电视overscan策略。

纠正后3例2过1失败：浅色大字说明y=1219/h=24，Down四次仍零位移，确在屏外。预览缺焦点承载，正式TV页原已有卡片focusable，不能追溯定性正式页面缺陷。给Debug预览补焦点后3例过；后续NAS文案修改后按最终输入fresh再验3例全过，不累加成6唯一覆盖。

最终6张原生截图全部实看：大字初图末行/说明在下方属于待滚动状态；Down后说明1219→979，实际240点位移，四服务及页脚完整。两深色标准窗口四服务/页脚完整，Menu返回入口焦点断言通过。没有帧时间、实体遥控、VoiceOver、真实服务发现或授权验证；位移/请求成功不能当流畅，三窗也非全主题/完整正式宿主。

iPad本轮fresh实例核最新包/合成哨兵后启动英文大字player-settings。最初无本轮实例时getApp超时；仅重置工具会话后可绑定本轮窗口，安装前SpringBoard图不作App证据。启动后AX+截图、独立截图均timeoutReached，停止相同重试、未重启整个Simulator。0当前包iPad有效App图；标记修正只有源码/编译，英文大字页脚补验未完成，旧图仍属旧输入。

## 宿主NAS上下文单审

移动LaunchpadLayoutViews的networkNASContext取connection.dsmSession，有认证/FileStation代次与地址守卫。TVStorageEntry及TV NAS页的两个上下文取state.nasAccount，而TVAppState初始化直接从TVAccountVault恢复该值；没有在发布前做本轮服务器验证。context存在不足以证明当前登录，移动session存在也不保证远端持续有效。

改用“当前 NAS 登录配置”描述宿主提供配置，不新增探针、不读真实Keychain、不清凭据或改登录状态机。本轮只有源码审查/编译，TV服务预览不挂该连接管理行，所以正式新文案实图/读屏、实际会话有效性仍待验。

## 最终身份与清理

最终iOS/tvOS模拟器Debug及双端设备无签名Debug/Release共六项exit0；最终TV UI构建与3唯一UI例通过。各修正前构建/失败另存，不冒充最终输入。低影响移动标记/正式文案未加镜像测试，也未重跑无关旧套件。

手机缺开发描述文件与TV旧profile阻塞保留，本轮未重试普通签名；无签名编译不等于可安装候选。未冻结/安装新签名包，旧移动30/TV27包身份保持，currentSourceAssessment更新为不匹配最终源；本轮未重复核旧签名，沿前批证据。模拟器包各自有构建时间、主二进制/Debug dylib哈希及逐次安装核对。

5个任务实例（Pad1、TV4）全在finally终止App/关机/删除，fresh清单确认全无；安装hash及合成哨兵同，无新增应用偏好/trace。未操作无关实例/用户缓存/资料。沿用移动6GiB、TV3.8GiB启动与2GiB运行保留线，初始约17GiB，最终余量见共享结果。收尾无自有构建/采集。

## 接续

工具恢复后补Pad英文大字页脚及移动settings/sync标记关联窗口、正式连接管理新文案；不无故重跑已过TV三窗。其他主题字号、完整宿主、缓存显式取消、密码显隐、读屏、严格匿名导出及真实事务仍开放，工具阻塞时继续独立源码审查。已核对唯一需求总账、播放功能矩阵与架构：不关闭整项，矩阵无相关新状态，架构无需修改。NAS/全部真机仍暂停。
