# Apple TV 服务详情宽度复测验收（Muse → Codex，第三轮）

**日期**：2026-11-21 17:31–17:34（北京时间）
**背景**：上一轮（17:06–17:20）宽度验收失败是测量假象——旧 `tv.service.info` 标识落在四个 StaticText 上，`firstMatch` 取到的 126pt 是“当前服务”文本，不是信息卡。Codex 本轮修了标识与宽度约束（见 `docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-SERVICE-DETAIL-WIDTH.md`），Muse 从当前工作区重新标准构建、安装并按三主题复测。

## 安装记录

- **设备**：Apple TV 4K (3rd generation)，tvOS 27.2，UDID `00008110-000235903E99801E`，`available (paired)`。
- **构建**：Xcode 27.2（Build 27B52），GUI Terminal 标准构建，`BUILD SUCCEEDED`（17:29）。日志 `/tmp/nastart-tv-width-build-20261121.log`。宽度修正源码（TVNASViews.swift）已编入。
- **包 SHA-256**：
  - 主程序 `NastartTV`：`3b1eccccf038966224fe86f6a6e13589d444068d31b9ae9e19a530981a62d3c4`
  - `NastartTV.debug.dylib`：`1a5d4da2aad56eac331457e632844d107226cf9fd7fe81f277e3838c63e2e918`
  - （与 Codex 的 `3e1a1ca7…` 不同，属不同构建机/DerivedData 的正常差异，源码同一批。）
- **签名**：`codesign --verify` 通过，Identifier `com.changliwen.nastart.tv`，Team `5436TB5498`；描述文件 `tvOS Team Provisioning Profile: com.changliwen.nastart.tv`，到期 2026-11-27 12:58:54 UTC。
- **安装**：`devicectl device install app`，2026-11-21 17:31:15–17:31:21 CST，6 秒，保留数据覆盖安装成功。安装后 `devicectl device process launch` 启动，进程 PID 921 在跑，正常启动。
- **工作区**：HEAD `8db1cc64`，214 个未提交修改全部保留，未回退任何内容。

## 验收结果总览

| 主题 | 结论 | 信息卡 frame | 视口 |
|------|------|-------------|------|
| 清流 cleanGrid | **通过** | (150, 195, 1620, 256) | (0, 0, 1920, 1080) |
| 栈列 commandCenter | **通过** | (150, 195, 1620, 256) | (0, 0, 1920, 1080) |
| 流光 glassDeck | **通过** | (150, 195, 1620, 256) | (0, 0, 1920, 1080) |

**三主题全部通过。服务详情宽度问题已解决。**

---

## 逐主题结果

### 清流（cleanGrid）— 通过

- **探针**：`testFixVerificationWidthCleanGrid`，`passed`（36.6 秒）。
- **探针结果原文**：
  ```
  PROBE fix-verification-width: theme=清流(cleanGrid)
  containerExists=true containerLabel=homepage、运行中
  detailOpened=true onDetail=true
  PROBE service-detail-card: type=XCUIElementType(rawValue: 48)
  frame=(150.0, 195.0, 1620.0, 256.0) viewport=(0.0, 0.0, 1920.0, 1080.0)
  ```
- **判定**：`tv.service.info` 只匹配一个信息卡（`cards.count == 1` 断言通过）；宽度 1620pt ≥ 1400pt；横向 150–1770 在视口 0–1920 内。

### 栈列（commandCenter）— 通过

- **探针**：`testFixVerificationWidthCommandCenter`，`passed`（32.5 秒）。
- **探针结果原文**：
  ```
  PROBE fix-verification-width: theme=栈列(commandCenter)
  containerExists=true containerLabel=homepage、运行中
  detailOpened=true onDetail=true
  PROBE service-detail-card: type=XCUIElementType(rawValue: 48)
  frame=(150.0, 195.0, 1620.0, 256.0) viewport=(0.0, 0.0, 1920.0, 1080.0)
  ```
- **判定**：同上，单匹配、1620pt ≥ 1400pt、横向在视口内。

### 流光（glassDeck）— 通过

- **探针**：`testFixVerificationWidthGlassDeck`，`passed`（32.6 秒）。
- **探针结果原文**：
  ```
  PROBE fix-verification-width: theme=流光(glassDeck)
  containerExists=true containerLabel=homepage、运行中
  detailOpened=true onDetail=true
  PROBE service-detail-card: type=XCUIElementType(rawValue: 48)
  frame=(150.0, 195.0, 1620.0, 256.0) viewport=(0.0, 0.0, 1920.0, 1080.0)
  ```
- **判定**：同上，单匹配、1620pt ≥ 1400pt、横向在视口内。

---

## 关键说明

- **三主题 frame 完全一致**（150, 195, 1620, 256）：宽度约束与主题无关，由 `TVServiceDetailView` 在 ScrollView 外读取视口宽度、扣左右各 70pt 后设定，主题只改配色与卡片样式，不改宽度。预期内。
- **信息卡元素类型**：`XCUIElementType(rawValue: 48)` 为容器型元素（非 StaticText），证实 Codex 已把 `tv.service.info` 标识从四个文本标签收口到整张卡片节点，上一轮 126pt 的测量假象已消除。
- **卡片横向位置**：左缘 150pt、右缘 1770pt，两侧各留 150pt。`tvPageInsets` 左右各 70pt，详情页内另有 80pt 内边距，合计 150pt。卡片 1620pt 宽，远超 1400pt 要求，且完全在视口内。
- **主题切换方式**：探针用 launch argument `-appearance.launchpadTheme <theme>` 覆盖 `@AppStorage` 存储值，每主题一次全新 App 启动，互不干扰。用户日常在 App 内切换主题后，效果与本轮一致（同一份布局代码）。
- **操作路径**（三主题相同）：启动台 → 点 `homepage` 容器 → 详情页 → 测量信息卡 frame。
- **截图**：每主题一张，挂在 XCTest 结果附件里（附件名 `fix-verification-width-<theme>`），随测试报告保存在 Mac 的 DerivedData 测试结果中。

## 证据

- 探针日志：`/tmp/nastart-tv-width-themes-20261121.log`
  - 清流 PROBE：第 988 行（`fix-verification-width`）、第 996 行（`service-detail-card`）
  - 栈列 PROBE：第 1047 行、第 1055 行
  - 流光 PROBE：第 1106 行、第 1114 行
- 三个测试用例全部 `passed`，无失败断言。
- 构建日志：`/tmp/nastart-tv-width-build-20261121.log`；安装日志：`/tmp/nastart-tv-width-install-20261121.log`。

## 剩余工作

- **电视三项全部通过**：Jellyfin 读库（17:09）、Docker Menu 返回（17:09，1 容器实测）、服务详情宽度（本轮，三主题全过）。三项均已验收，无待修项。
- 待用户用实体遥控器复核的两处（探针到不了，非代码问题）：① Docker 其余容器（`homepage-dockerproxy`、`sonarr`）与容器列表入口的 Menu 返回；② 连接管理页（“我的”tab）的宽度。复核发现新问题再交给 Codex。
- 探针文件 `tvos/NastartTV/UITests/TVLaunchTests.swift` 现 1291 行，括号 193/193 平衡，含 Codex 更新的宽度探针与 Muse 追加的三主题入口。复用前请先 `git diff` 核对。
