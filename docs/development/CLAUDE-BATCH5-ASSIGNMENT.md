# Claude第五实施批：WebDAV协议大小写还原与无改动保存边界

2026-11-02，Codex分配。第四批已交[只读审查](../archive/handoffs/2026-11/2026-11-02-0555-CLAUDE-BATCH4-WEBDAV-REVIEW.md)。Codex用实际类型在macOS离线运行，确认了条件缺陷，见[可分享结果](../testing/results/2026-11/WEBDAV-SCHEME-CASE-PROBE-20261102.json)：HTTPS/Http被WebDAVScope接受并保留大小写，Fields初始化抛host；URL==及原绝对串也不等于仅协议转小写后的URL。仅为虚构.invalid，没有网络。

## 最新同源工作区与完整文件权限

目录 `/Users/lagransun/workspace/Nastart-Claude-WebDAVScheme-20261102`；分支 `claude/webdav-scheme-batch5`，独立Git仓库/无remote，基线 `a087a4864d8cd8b52928d2fd76a0a34670065602`、父HEAD4de732dd。交接时446输入逐个同当前集成候选，含密码匿名诊断、第三批主题卡及徽标固有宽度修正；**不等于所有UI已验收**，Codex正在复验主题宿主。后续Codex可能只改Mine的DEBUG测试控制，与以下文件不重叠。

唯一可写完整文件四个：

1. `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/WebDAVConnectionFields.swift`
2. `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/Models.swift`
3. `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift`
4. `ios/Nastart/Packages/NetworkMedia/Tests/NetworkMediaTests/WebDAVConnectionFieldsTests.swift`

起始SHA见集成目录AGENT-RESOURCE-STATE.json的claudeBatch5；开工/交付重核当前集成目录登记，不能看复制副本旧许可。Codex交付/释放前不改这四个完整文件。只改本批所需段落，不格式化大文件其它区域。

## 必须满足的行为

1. `WebDAVConnectionFields(scope:)`接受合法HTTP/HTTPS协议任意大小写，转为已有Scheme枚举；端口、字面百分号/中文路径、IPv6及原地址校验边界保持。无需新增invalidSaved枚举。
2. 用户打开合法大写协议旧配置、不改协议/地址/端口/路径/凭据、只改名称或直接保存时，仍走原renameConnection早返回；**不能仅因字段还原后协议转小写就发PROPFIND、写新凭据或重建媒体库**。保持原username/password相同条件，原有改服务器/路径/凭据分支保持。
3. 可在Models的WebDAVScope提供纯地址比较方法供editConnection调用：只忽略合法协议部分大小写，其余原始地址字面比较保持；先确认待比地址合法，不把解析失败当相同。不得把整个URL lowercased（路径区分大小写），不得放宽路径大小写、端口、host/凭据或编码差异。无需迁移/回写用户保存地址。
4. 在既有WebDAVConnectionFieldsTests增加有价值回归：HTTPS/Http/混合协议还原、原IPv6/字面百分号中文往返；仅协议大小写的比较为true，http与https、不同端口/路径/路径大小写、无效地址为false。用.invalid/文档保留IPv6，只测纯类型，不初始化Vault/NetworkLibrariesModel或调用网络。

本批不改编辑初始化的try?回落提示/钥匙串失败行为；协议问题修复后是否还有其它可达转换失败要有新证据再做，不加不可达“无法还原”提示。不改存储schema/迁移、网络请求/重定向/认证/目录事务、密码输入/主题、任何源文件远端写入或整包本地化。不碰本机实际偏好/钥匙串/NAS。

## 编译与运行窗口

只授独立目录四文件源码/测试实现；没有编译、模拟器、真机或NAS权限。无Swift工具则如实交未运行。Codex负责前后回归和接入编译，不以静态检查充当通过，也不把纯比较测试升级为真实保存/凭据事务验收。

相对本基线导出仅四文件局部补丁，仓库外本方独有目录保存；交最终文件/补丁完整SHA、实际diff、测试新增与未运行项、失败、写入释放。唯一允许在集成目录新增的报告：`docs/archive/handoffs/2026-11/YYYY-MM-DD-HHMM-CLAUDE-BATCH5-DELIVERY.md`。共享摘要/登记只由Codex写；不能沿此授权运行命令访问设备或真实凭据。完成本批直接交付，无须反复等“继续”。
