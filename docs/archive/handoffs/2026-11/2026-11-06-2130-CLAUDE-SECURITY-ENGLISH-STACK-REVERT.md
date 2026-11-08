# Claude（本地会话）：走查第二批、英文文案、栈列试验撤销

2026-11-06 21:30（Asia/Shanghai）。接 [第一批](2026-11-06-2030-CLAUDE-AUDIT-FIRST-BATCH.md)。**没有提交，没有改共享状态。**

**设备**：iPhone 13、A16 iPad 已保留数据安装 Debug 包，dylib 前 16 位 `c1c221f751f6649b`。测试窗口已关。描述文件 11-08 09:08（+08）到期。

## 跳过 SSL 开关

原因不是默认值：内网 HTTPS 的自动信任被存成 `allowsSelfSignedCertificates`，表单回填后又当成用户选择，换成公网地址时继续生效。

- `DSMCertificateTrustPolicy.initialToggle`：保存地址是内网时，开关回填为关。
- 公网地址保留已存的值，开关打开时显示橙色警告。13 上已确认显示。
- **13 已保存的连接仍是开启**，要用户关闭开关后重新连接才会改变。没有替用户改。

## 移除媒体库确认

媒体库行长按菜单和海报墙“来源与管理”都加了确认框。**确认框未实测**：点“移除”被权限策略拦下。需要用户在真机上看一次。

## 英文文案

中文原文作 key，`en.lproj` 增加约 350 条；`networkL`、`networkText`、`networkRoleText` 在 `NetworkMediaLocalization.swift`。`AppLanguage.applyToBundleLanguageOnNextLaunch` 写 `AppleLanguages`。

13 英文走查：启动台、媒体库、连接管理、添加文件夹、海报墙、影片详情、设备各页、事项、“我的”各子页，只剩用户数据和已入库的“6 声道”是中文。语言已改回“跟随系统”。

已知限制：错误提示等非视图文字重启后才切换；英文不区分单复数；已入库资料要重新整理才变；TV 没有翻译表，仍是中文；DEBUG 预览场景未翻译；iPad 英文未走查。诊断页缺翻译的键改显示事件名。

## 栈列试验已撤销

做过机架样式（真机）和层叠卡片、多列看板（静态图），用户都不满意，要求退回。代码和文案已恢复到试验前，`grep StackRack` 无结果，13 上描述已是原文。效果图移到私有证据目录 `stack-theme-preview/`。

## 待处理

- **DSM 会话失效**：13 上 `SYNO.FileStation.List` 返回 119 时文件页失败，“重试”无效，重启 App 恢复。两次英文重启中只出现一次，触发条件未查明，与语言无关。**没修**。
- iPad 媒体库 WebDAV 旧密码未更新，可能再次触发封锁；原因未查明。
- 走查清单其余项：10～19（不含已修）、反向代理数量 0 与日志 1 不一致。
- 大文件播放等用户下载样本。

## 请 Codex 处理（如果用户安排）

审查并集成本批与前两份交接列出的文件，另加 `NetworkMediaLocalization.swift`、`NetworkLibraryPlaybackView.swift`、`LibraryPosterWall.swift`、`SeriesViews.swift`、`MediaCatalog.swift`、`LaunchpadConnectionViews.swift`、`MineView.swift`。

## 验证

撤销栈列后的源码：见 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/nas-1106/`（`six/`、`revert-tests.log`）。六配置覆盖了 DerivedData 产物，下次安装前重新做签名构建。13 主题已确认改回流光。
