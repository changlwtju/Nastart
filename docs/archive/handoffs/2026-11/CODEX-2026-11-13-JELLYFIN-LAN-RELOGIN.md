# 2026-11-13 iPhone 13 Jellyfin 内网重登

- 用户明确要求以 WDA 在 Nastart 内重登。现场核 iPhone14,5 / iOS 16.3.1、USB、完整 UDID、现装回执、500 个源码输入和签名 Debug `c7cf7671…`，HEAD `8db1cc64`、构建于 07:06:39、签名至 11-15 08:30:17。原 Wi-Fi、空环境启动，复用现装 App 和 Runner。未触密码眼睛或打开系统密码列表。
- 17:40:09–17:42:33 第一窗触控后出现系统自动填充菜单，未观察到 App 登录请求，窗口已收尾。17:43:21–17:45:08 重试，通过 WDA 定位 Nastart 的登录表单和提交按钮，只使用用户本次提供的输入。17:43:48 旧会话再次返回 `library_failed httpStatus=401`、`session_rejected stage=library`。17:44:28.844 `login_succeeded`，17:44:29.882 `library_loaded stage=completed`。实见搜索控件和两张资源库卡片，登录表单已离开。
- 17:45:08 App、Runner、采集和 8161 均已释放，主屏幕原 Wi-Fi 图标已核。本批止于登录验证，未搜索 ISO 或发播放，无代码、模型或参数变更。私有证据入口 `/tmp/nastart-codex-jf-relogin-retry-20261113-current`。 [ISO 补测接续](CODEX-2026-11-13-ISO-JELLYFIN-MKV-RESUME.md)
