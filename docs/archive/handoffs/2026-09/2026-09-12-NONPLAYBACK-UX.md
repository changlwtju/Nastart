# 服务浏览、文件排序与相似作品修正

关联唯一总账 [UX-01～UX-04](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。本批为用户追加项，原有 PX-01～PX-19 全部保留。

## 修改与原因

- 相似作品：水平 LazyHStack 改为小批量 HStack，让横向滚动区取得卡片完整高度；标题预留两行，文字按垂直固有尺寸布局，保留副标题。解决截图中海报下文字被纵向裁切，不把横向第三张部分露出误判为数据丢失。
- 文件排序：原名称/类型确有排序，但文件夹之间类型相同；新名称使用自然比较（2 在 10 前），类型按扩展名，新增原始字节大小与修改时间、升降序和跨目录偏好保存。DSM list 请求增加 time，并映射 additional.time.mtime；目录大小保持未知，避免把 inode 大小冒充递归总大小。缺失值在同组末尾，文件夹始终优先，目录日期也可排序；共享根目录或服务端未提供数据时不伪造日期。
- 服务网页：隐藏应用 TabBar；默认“简洁浏览”隐藏网页底部工具栏，顶部保留返回和菜单，后退/前进/刷新/分享均可在菜单访问。关闭简洁浏览可恢复网页工具栏，退出服务应恢复应用导航。
- 网页模式：原“专注”完全等价桌面，移出版本选择器，独立简洁浏览开关。保留自动、请求移动版、请求桌面版并增加说明。自动沿用按服务类型选择版本的策略；网站无单独版本时可能看起来相同。新模式通过 WKNavigationDelegate 的页面 preferences 在每次导航生效；切换重载当前页，保持已浏览 URL 与历史，而非重新加载入口。

## 验证

- 播放与非播放合计 65 项测试通过，含自然序、类型、100 GB 数值排序、升降序、缺失数据、DSM 时间映射、旧缓存解码兼容：`/tmp/nastart-20260912-ux-tests.log`。
- 设备构建通过：`/tmp/nastart-20260912-ux-device.log`；preflight 通过：`/tmp/nastart-20260912-ux-preflight.log`。App 与每个内嵌 dylib 分别签名核验。
- 已安装到 USB iPhone 13 / iOS 16.3.1：`tmp/playback-20260912/install-ux.log`。真实文件目录截图 `ux-current.png`、结构 `before-ux-validation.xml` 证实新菜单和 DSM 日期展示；两者是手动操作过程中的不同瞬间，不作为同目录受控排序对照。
- 手机正在手动浏览/播放，因此未完成自动化同目录升降序、服务退出导航恢复、相似作品动态字体及网页版本完整交互验证。四项保持待验收，代码通过不等于全部已验收。

页面版本语义依据：[Apple WKWebpagePreferences](https://developer.apple.com/documentation/webkit/wkwebpagepreferences)、[ContentMode](https://developer.apple.com/documentation/webkit/wkwebpagepreferences/contentmode)。版本请求不能凭空为第三方网站生成移动布局。
