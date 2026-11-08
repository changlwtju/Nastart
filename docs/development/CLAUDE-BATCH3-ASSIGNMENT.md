# Claude第三实施批：主题画廊的大字与可访问性

2026-11-02，Codex分配。开工与交付前读取**集成目录** `/Users/lagransun/workspace/Nastart` 的[当前交接](../handoffs/CURRENT-PLAYBACK-HANDOFF.md)和[资源登记](AGENT-RESOURCE-STATE.json)。复制目录的旧许可不生效。前两批已集成，本批不再用旧b621或2a2f源码覆盖当前文件。

## 同源独立工作区和唯一可写产品文件

- 工作目录：`/Users/lagransun/workspace/Nastart-Claude-ThemeAccessibility-20261102`；分支 `claude/theme-accessibility-batch3`，独立Git仓库，不是worktree，无remote。
- 接受基线：`a03d6a1006396f1346c33e4403d90735a7c45005`，父HEAD4de732dd；446当前接受输入逐个SHA与集成目录相同，包含两批已接入成果，iOS dirty diff b9463286。
- **完整文件写入只授：** `ios/Nastart/Nastart/Features/Mine/MineView.swift`，起始SHA-256 `9e753cf8dbf7135aa72d34979c4fad5a051cfa5857949b871f0eaa26405c3394`。Codex在交付/释放前不编辑该完整文件，在现有离线场景做模拟器验证。
- 不改AppTheme、NetworkMedia、TV文件、本地化、工程、依赖、签名、播放/认证/存储或进度/需求/资源登记。可在独立目录交本批局部diff，不整理该大文件其它区域。

## 内容与保留行为

接[首批审查D](../archive/handoffs/2026-11/2026-11-01-2028-CLAUDE-OFFLINE-UI-REVIEW.md)。已静态复核当前LaunchpadThemeGalleryView：主题说明lineLimit(2)，标题/说明/状态并排；LaunchpadThemePreviewArtwork是含固定DSM、11%、32%、2.9TB等内容的装饰性设计示意，当前根没有隐藏可访问性子树。**没有实际VoiceOver失败证据，不声称修复了实测读序或截断。**

最小实施：

1. 将该装饰性Artwork的可访问性子树隐藏，避免示意NAS/指标被当作用户真实状态；保留视觉预览，包括详情页的示意图，不隐藏真实主题说明、操作和状态。
2. 画廊每张NavigationLink的标题、描述和“当前使用／Plus”状态成为连贯可访问内容，保持链接角色和可激活行为，避免父子重复读。复用现有本地化键，不写仅中文/仅英文标签，不添加“已开通”之类新权益判断。
3. 仅在辅助字号解除说明两行限制，并使文字/状态可自然纵排或换行；普通字号尽量维持现有视觉。保留当前状态优先于Plus徽标的原显示规则。

必要时在**同一文件**抽取只接theme/isSelected等值的私有卡片标签，供正式画廊调用，方便后续安全宿主复用。不要为交图直接实例化AppearanceStore/EntitlementStore，也不要复制一个长得相似的测试卡片。若需改AppTheme/新增场景枚举或调试路由，写具体最小方案，交Codex在集成后安排。

原主题应用、Plus权限、appearanceStore写入、dismiss/showLaunchpad、导航目的地、图样内容和既有Mine/诊断/导出安全宿主均保持；不因本批顺手修其他问题。测试宿主中的英文fixture控制是明确测试标识，不做全文件本地化整理。D以外E/F仍不在本批。

## 构建、设备和交付

本批**只授源码实施，不授编译、模拟器或真机运行**。Codex正用自有iPad模拟器补横屏/交互；NAS仍恢复，普通根会恢复会话，不启动。13/Pad真机、TV、18、Runner/签名/设备偏好均不操作，不读取Codex私有证据。无需准备依赖。Claude若仍处于Linux无Swift工具，明确未编译即可，不能把静态检查当UI通过。

相对本批基线导出仅MineView补丁，仓库外本方独有目录保存；提供最终文件/补丁完整SHA、实际diff、静态核查和失败、未运行项、宿主接入建议，并明确释放完整文件写入权。不要写镜像实现的形式测试，不关闭需求编号。

唯一可在集成目录新增的本方报告：`docs/archive/handoffs/2026-11/YYYY-MM-DD-HHMM-CLAUDE-BATCH3-DELIVERY.md`。Codex收到后核基线/语义、集成、编译及实际组件中英/大字/AX；完整VoiceOver仍须实际读屏证据，静态属性不等于读序验收。共享摘要与登记由Codex单写。
