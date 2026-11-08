# 电视详情重试按钮焦点路径

更新：2026-10-31T07:26:22+08:00。接[演职状态批](2026-10-31-CREDITS-STATE-PARITY.md)。按既定模型分工，仅本地代码/专属电视模拟器；0真机发现/控制/安装、0NAS/旧凭据/源写/播放，无后台任务。

## 实际实现

新增公开纯MediaDetailFocusMap，按当前actions/people/related/relatedRetry/files返回语义目标，不持有UI、客户端或数据。保原人物/影片左右边缘钳制、Hero下移进首位演员与有效动作/人物记忆；下移路径补相关重试，文件向上优先回重试。重试向上回最后有效相关作品，无相关时回演员或动作；空区跳过，不返回过期记忆或捏造play。移除重试后的fallback选有效相关作品、文件、演员、动作。

TVDetailView实际用该规则替换原私有方向判定，新增lastRelated记忆及related retry的FocusState/方向/几何ID/滚动锚点。requested目标为重试时滚至其区域、异步再确认仍存在后落焦；点击相关重试先移到有效fallback再触发原reload，避免按钮马上消失时失焦。relatedRetry移除时也补救，但不因旧requested记录抢走当前其他有效焦点。主Hero/演员/相关行/文件原布局、defaultFocus与滚动流程保持；新演员入口逻辑认可从retry返回的记忆。

原retry标签抽为TVDetailRetryButton，正式与新隔离场景共用TVTileStyle/暖箭头/18×12/标识，原reload=UUID只执行一次，所有读取状态、client detail/similar任务和播放器cover逐字同。没有新请求/重试预算/影片选择或媒体文件操作。移动生产视图不改，共用包新增规则供复用。

## 隔离与验证

新增7个规则回归覆盖16种有/无演员、相关作品、重试、文件组合，行边缘、记忆恢复、过期ID、全空与单项；加原12参数/读取回归共19过。新3个TVLaunchTests只用--offline-ui detail-focus-retry/empty/only，专用early branch在TVAppState/普通App内容创建前选择，旧tv-exit-probe及构造TVJellyfinClient的旧fixture均未使用。iOS收到这些显式参数仍留隔离提示，不回正常根。

新TVDetailFocusOfflineScene只在Debug，固定人物/海报、焦点绑定/滚动/内存计数，复用正式规则、真实TVDetailRetryButton/TVTileStyle、人物卡/框、TVPosterStyle及文件Disclosure；没有model/store/vault/client/媒体/网络Task。三个用例通过XCUIRemote真实方向键、hasFocus、重试isHittable、Select后按钮消失/计数=1断言，核对演员→相关→重试→文件及反向、记住第二个相关作品、无演员/相关直达重试、无下方内容返回Hero。它们证明隔离层的实际方向键/选择，不是把滑动请求或静态截图当通过。

初UI构建后加最终移除前fallback/过期requested保护，仅重建UI目标；包内规则/参数未改，不重复单元测试。首次三UI用例全过，但测试工具重装目标更换容器路径，收尾仍读旧app/data路径，导致记录脚本异常；初偏好false是旧路径空读，不能说App清数据。原日志/xcresult/安全记录保留。修正核验为测试后重新取实际路径，再用同源码/同包另建专属实例补核三项，仍全过，安装前后主/dylib hash同、两哨兵保持/无额外应用键。两次运行只计3个唯一UI用例，不膨胀为6个。

最终xcresult导出1张成功附件已实看：重试消失、重试次数1、第二相关作品焦点边框和文件入口可见。未做真实Jellyfin完整详情页、长横排、真实数据替换、触摸板手势、Menu/返回或中间焦点与帧时间验收；界面fixture虽用实际样式/规则，未构造正式client页面。两自建实例均finally关删且fresh列表无；沿3.8GiB启动/2GiB运行预算，未清用户缓存/旧包。

双模拟器Debug、UI build-for-testing、正常签名Debug/无签名Release串行过；UI/runtime包与正常包同441输入（原439+2新文件），UI测试后输入不漂移。30/27 Mach-O核hash/完整签名及TV嵌入库过，cp -cpR请求克隆独立核验，正常候选无测试参数/环境、未装真机，root清单更新。5既有源/测试修改、2新源/测试，原其余434输入同。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T07:19:22.678053+08:00 | `8ec24ce21f2283b06c0f8e509a5bd447b74813a8b90ff4137180e1e6a48b2d9a` | `cc3da849663656fa74e3fed62dcf23feaf729f6f47d95e0557468de351b072a0` | 30 |
| Apple TV | 2026-10-31T07:21:11.451117+08:00 | `5d4db4d9ffaf4995f661dd587248970d858954f39678d1c895873eeccde4c3f8` | `fd50f0811700fdf67e12ef6bae55abb132f6fd750ae54a12c7a7b86dd2d4e985` | 27 |

[安全结果](../../../testing/results/2026-10/2026-10-31-tv-detail-retry-focus.json)，原始路径/包/日志/xcresult/图/偏好只在仓库外current-tv-detail-retry-focus-private。旧大字无位移、资料头像与其余未验仍保留；播放路线/引擎/缓存未改，114格无新P。

## 接续

核对其他详情操作消失/返回时焦点，并评估网络媒体详情复用此规则；先保其回调与真实数据条件，不能因三个隔离用例关闭完整TV详情验收。真实服务更新/长行/触摸板与物理遥控仍等安全环境。私有旧通用收尾脚本有439固定值，本批新计441，后续须动态核对，不能盲用。
