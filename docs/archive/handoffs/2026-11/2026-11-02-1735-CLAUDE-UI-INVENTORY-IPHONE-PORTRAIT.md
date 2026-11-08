# Claude（本地会话）：逐页 UI 清单（第一轮 · iPhone 竖屏）

2026-11-02 17:35（Asia/Shanghai）。按[本地开工单](../../../development/CLAUDE-LOCAL-START-HERE-2026-11-02.md)第 3 步执行。没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## 覆盖范围

- 设备：自建模拟器 `Claude-PW-iphone`（iPhone 17 Pro / iOS 27.0），竖屏，浅色，主题 cleanGrid。
- 离线场景：`OfflineUIScenario` 全部 126 个（除 `invalid`、`local-library`、两个密码探针）× 标准/大字号（`.accessibility2`）＝ **252 张**，逐张看过缩略总览，可疑处看原图。
- 另加 `local-library` 真实页交互（详见 [local-library 报告](2026-11-02-1628-CLAUDE-LOCAL-LIBRARY-SCENE.md)）。
- 构建归属：前 114 张为海报修复前的包，其余 138 张及交互复验为修复后的包。修复只改了真实海报墙卡片样式，离线场景的截图结论不受影响。
- 本机证据：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/iphone-portrait/`（命名 `<字号>--<场景>.jpg`）。

**未覆盖（未执行）**
- 启动台、设备、事项三个主入口的根页面：没有对应离线场景，而普通根可能恢复 NAS。
- 横屏、iPad、深色模式、commandCenter/glassDeck 主题、tvOS。
- VoiceOver、触控与性能。

## 问题清单（按严重程度）

| # | 级别 | 页面 / 场景 | 现象 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | P2 | 真实海报墙（local-library） | 海报卡第二行（年份、“2 季 · 8 个视频文件”、“待确认”）首字被卡片左下圆角裁掉 | **已修**（`LibraryPosterWall.swift`），已复验 |
| 2 | P2·流程 | 模拟器测试包 | `CODE_SIGNING_ALLOWED=NO` 的包写钥匙串报 -34018，表现为“无法读取或保存本机媒体库” | 改用 ad-hoc 签名，已在报告记录；后续测钥匙串路径都应签名 |
| 3 | P3 | 真实详情页 | 顶部背景图上方有一条灰色空带 | 未修 |
| 4 | ~~P3~~ | 海报墙 → 详情 → 返回 | 回到同一行，但约 10pt 上漂 | **撤销**：测量误差（截图时列表仍在惯性滑动），返回位置精确保持，见[返回保位专项](2026-11-02-1900-CLAUDE-RETURN-POSITION.md) |
| 5 | P3 | `library-updating`、`wall-updating` | “正在更新资料 · 已发现 0 个视频文件”，读起来像没找到文件；需核真实更新流程是否也这样显示 | 未修 |
| 6 | P3 | 添加 WebDAV 表单 | 切到 HTTP 后端口自动填“80”，自动化先输入的“8089”被覆盖；可能只是输入时序问题 | 待人工复现 |
| 7 | P3 | `privacy-cache` / `privacy-reset` | 两个破坏性确认样式不一致：清缓存是系统弹出框，盖住页面标题且箭头指向屏幕外；重置证书是居中卡片加暗底 | 未修 |
| 8 | P3 | 大字号离线海报墙（`library`、`missing`、`wall-category-fallback`） | 每行只有 1 张全宽海报，一屏只能看到 1 部作品 | 待设计决定 |
| 9 | P4 | 多个禁用主按钮（详情“播放”、“连接并选择文件夹”等） | 浅橙底配白字，禁用态几乎看不清 | 待设计决定 |
| 10 | P4·测试夹具 | 大字号下的 `connections`、`folder-edit*`、`source-add`、`media-failure-long`、`diagnostics`、`privacy-export` | 底部“离线界面测试”横幅或分享探针条盖住正文或主按钮，截图不可靠 | 未修（只影响 DEBUG） |
| 11 | P4·测试夹具 | `mine-info`、`diagnostics` | 夹具标签是英文（“Connected fixture”“Empty fixture”等） | 仅 DEBUG，可不改 |

已确认正常（抽查原图）：长标题两行省略且行对齐；缺海报、缺简介、缺演职人员的占位；错误/加载/空状态的标准与大字号排版；设置、Plus、隐私、帮助各页的大字号换行。

## 建议批次

1. **A 批（小改动，可直接做）**：#3 详情页灰带、#4 返回上漂、#5 “已发现 0 个”文案。
2. **B 批（测试基础）**：#10 夹具横幅改为不遮挡正文；为启动台、设备、事项根页面补离线场景，补齐清单缺口。
3. **C 批（需要设计决定）**：#7 确认弹窗统一、#8 大字号海报密度、#9 禁用按钮对比度。
4. **D 批（覆盖面）**：横屏、iPad 模拟器、深色模式与另外两个主题，各跑一轮同样的截图清单。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。
