# 共用人物图片与紧凑操作（2026-10-27，中间构建）

三端网络详情复用MediaDetailPersonCard，新增JellyfinCreditsSource及主App当前登录校验适配。只对NFO明确movie且有有效IMDb/TMDB编号查询已登录Jellyfin；标题只缩小最多20项的完整候选页，必须精确编号一致/无冲突/唯一候选才取人物，不能用片名或人名当匹配证明。GET鉴权仅请求头、无Cookie/自动HTTP认证/重定向，512KiB资料/2MiB图片/6秒截止、JPEG/PNG验证、图片2并发与32MiB解码缓存；登录变化/取消拒绝发布。网络失败仍用本地资料，不直连NFO外链/TMDB，无源写入。

46定向测试包括真实本机HTTP元数据和像素、Cookie隔离、重定向/401/声明和实际正文上限及在途取消，全部通过。首Swift Type保留字编译错误已修/原日志保留。官方Jellyfin ItemsController并无所猜AnyProviderIdEquals参数，未使用该假定；改为有界候选＋独立精确ID验证。参考[官方控制器](https://raw.githubusercontent.com/jellyfin/jellyfin/v10.8.13/Jellyfin.Api/Controllers/ItemsController.cs)。

413冻结输入/双普通Debug：TV22:15:11主3fe6c1222d206d520adfc5010ae03347779ba3af47acfc3fb6358d2cbc8b1b13，调试库26efaee5bd5500f006709e5dcadc4e3a3859fdb5afc992ff07071790f5ecc51b/27签名；移动22:15:16主3820b96c0ed2083acfd78a8c05c4640c863af7e596de1cc31e4f24f65b2d5e8e，调试库ec2155d0b583cda83558d9554279ce9fe65a3c4c53638438881bbca739c1a65f/30签名。包与全哈希清单由本机私有current-credits-batch-private定位，HEAD仍4de732d加dirty。

TV及18已保留数据安装；18Complete及空环境普通启动台截图实看、偏好同。TV准确影片详情实际10人物照片/0照片占位实看，0播放命令；首路由ready摘要只在finally落盘导致等待误报、第二窗驱动漏目标文件/未核业务成功导致错误0照片计数均保留，不当产品失败或通过。补目标/核detailVerified后成立，自有设置readback恢复/DELETE、原Runner保留。手机/Pad尚未装这一413包，不称三端图片真机均通过。

用户随后新增修改文件夹、同端刷新位置一致，明确列表是WebDAV后补不该独特；接续将统一默认海报墙/更多菜单，并实现先扫描成功再替换路径/索引。现中间构建的“显示方式”菜单不当最终验收。用户又授权只读操作Infuse/网易爆米花参考流程；TV现场已枚举Infuse8.1.8及爆米花2.6.12，观察进行中，不修改其连接/账号或复制密钥。

用户最新要求基于当前Mac连接Pad/13/TV调试，18正在使用，只允许同步最新包，后续不主动启动/切页/操作18。22:28 fresh USB核Pad与13均可读，覆盖先走最新门禁；旧Pad不可连状态不再当当前事实。30项14/5/11、114格不增P，播放链/FTP/SMB未改变。
