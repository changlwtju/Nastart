# Apple TV 三项修正真机验收（Muse → Codex，第二轮）

**日期**：2026-11-21 17:06–17:20（北京时间）
**背景**：Codex 按 `docs/handoffs/TV-THREE-ISSUES-PROBE-2026-11-21.md` 修了六文件（见 `docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-THREE-ISSUES-FIX.md`），Xcode 27.2 App 与 XCTest 目标构建成功，5 项离线 HTTP 测试通过。Muse 从当前工作区重新标准构建、安装到真机电视并复跑探针验收。

## 安装记录

- **设备**：Apple TV 4K (3rd generation)，tvOS 27.2，UDID `00008110-000235903E99801E`，`available (paired)`。CoreDevice 正常（Codex 会话里 `devicectl` 超时的问题在 Muse 会话不存在）。
- **构建**：Xcode 27.2（Build 27B52），GUI Terminal 标准构建，`BUILD SUCCEEDED`（17:04）。日志 `/tmp/nastart-tv-fix-build-20261121.log`。Codex 六文件均编入（TVJellyfinClient、NastartTVApp、TVViews、TVNASViews 各 4 次引用，另含测试文件）。
- **包 SHA-256**：
  - 主程序 `NastartTV`：`04a5996deccd3a0b5c99ac224f7f007f745fb42ae1db1b983333fd4f17a71ebd`
  - `NastartTV.debug.dylib`：`5e58e0c0b77d64bf77fb4828c65c6cee7d9ccba72e91c7b101b078d8f27a0dc0`
  - （与 Codex 的 `6e649783…` / `5919500c…` 不同，属不同构建机/DerivedData 的正常差异，源码同一批。）
- **签名**：`codesign --verify` 通过，Identifier `com.changliwen.nastart.tv`，Team `5436TB5498`；描述文件 `tvOS Team Provisioning Profile: com.changliwen.nastart.tv`，到期 2026-11-27 12:58:54 UTC。
- **安装**：`devicectl device install app`，2026-11-21 17:06:03–17:06:08 CST，5 秒，保留数据覆盖安装成功。安装后 `devicectl device process launch` 启动，进程 PID 896 在跑，正常启动。
- **工作区**：HEAD `8db1cc64`，212 个未提交修改全部保留，未回退任何内容。

## 验收结果总览

| # | 项目 | 结论 | 依据 |
|---|------|------|------|
| 1 | Jellyfin 读库 | **通过** | `testJellyfinEntryProbe` 通过；电影/电视剧/继续观看三行都有数据，`errorHints=[]`，无“失败”“登录已失效”；含退出重进 |
| 2 | Docker 容器详情 Menu 返回 | **通过（1 个容器实测；另 2 个未测）** | `homepage` 容器详情按 Menu 回启动台，两轮探针均确认；其余容器因探针焦点导航到不了，未测 |
| 3 | 子页宽度 | **失败** | 服务详情信息卡实测仅 126pt（要求 ≥1400pt），压缩未解决；存储与媒体页 1548pt 正常 |

---

## 1. Jellyfin 读库 — 通过

**探针**：`testJellyfinEntryProbe`（Codex 更新版：经存储与媒体进入，含退出重进；去掉了主动 XCTFail，改为验收断言）

**探针结果原文**（2026-11-21 17:09）：
```
PROBE jellyfin: target=tv.open.networkLibrary opened=true mediaEntryExists=true
mediaOpened=true needsConnect=false
libraryTitles=["电影", "电视剧", "继续观看"] errorHints=[]
```

**判定**：
- 电影、电视剧、继续观看三行都有数据（`libraryTitles` 全出）。
- 全页无“失败”或“登录已失效”（`errorHints=[]`，上一轮是 `["失败", "登录已失效"]`）。
- 探针含退出重进，仍通过（测试用例整体 `passed`，38.7 秒）。
- 5 项离线 HTTP 测试（`TVJellyfinLibraryRoutingTests`）全部通过：`testCurrentLibraryRoutePreservesMountUserAndToken`、`testModernAuthorizationWorksWhenLegacyHeadersAreIgnored`、`testRejectedTokenThenLoginUsesNewTokenOnAllHomeRequests`、`testUnauthenticatedLoginDoesNotSendTokenParameter`、`testUnsupportedRouteFallsBackButUnauthorizedDoesNot`。
- 本轮无 401/403 出现，故无需追查续登链路与 token 指纹；`JellyfinSession` 日志未见拒登。

**操作路径**：启动台 → 存储与媒体 → Jellyfin → 三行数据 → 退出 → 再进一次复核。

**证据**：`/tmp/nastart-tv-acceptance-20261121.log`（第 1167 行 PROBE，`testJellyfinEntryProbe passed`）。

---

## 2. Docker 容器详情 Menu 返回 — 通过（1 个容器实测；另 2 个未测）

**探针**：`testDockerBackButtonProbe`（Codex 更新版：连续三个容器）+ Muse 补充探针 `testFixVerificationDockerAndWidth` / `testFixVerificationDockerAndWidth2`

**探针结果原文**：
- Codex 探针（17:09）：
  ```
  PROBE docker-back: containerExists=true containerLabel=homepage、运行中
  detailOpened=true onDetailBeforeMenu=true menuPressed=true
  onDetailAfterMenu=false backOnLaunchpad=true
  ```
- Muse 补充探针 round 1（17:12）：
  ```
  PROBE fix-verification: docker=[container1=homepage、运行中 opened=true
  onDetail=true menuReturned=true | container2=homepage-dockerproxy、运行中
  opened=false ... | container3=sonarr、运行中 opened=false ...]
  ```

**判定**：
- `homepage` 容器详情按 Menu 后不在详情页（`onDetailAfterMenu=false`），回到启动台（`backOnLaunchpad=true`），两轮探针均确认。**Menu 返回已修好。**
- 但 Codex 探针的三个容器断言未全部通过：第 2、3 个容器探针没能打开（`opened=false`），原因是 XCTest 焦点扫掠到不了启动台上第 2、3 行容器，不是 Menu 坏了。`homepage-dockerproxy` 与 `sonarr` 的详情 Menu 返回**未测**。
- 详情页是同一个 `TVServiceDetailView`（`navigationDestination` + 原生 Menu 返回），一个容器验证通过即证明该页的返回机制已修好；其余容器只是同一页换了数据，风险低，但严格按验收口径仍记“未测”。
- 容器列表入口（设备 → 容器 → 详情 → Menu 回列表 → 再 Menu 回启动台）与启动台直达详情一次 Menu 回启动台的区分，本轮只验证了后者（启动台直达）；前者因 XCTest 焦点到不了顶栏 tab，未测，需用户用实体遥控器复核。

**操作路径**：启动台 → 点 `homepage` 容器 → 详情页 → 按 Menu → 回到启动台。

**证据**：`/tmp/nastart-tv-acceptance-20261121.log`（第 1025 行 PROBE）、`/tmp/nastart-tv-verify-20261121.log`（第 401 行 PROBE）。

---

## 3. 子页宽度 — 失败

**探针**：`testSubpageWidthProbe`（Codex 更新版）+ Muse 补充探针 `testFixVerificationWidthOnly`

**探针结果原文**：
- Codex 探针（17:09）：
  ```
  PROBE subpage-width: storageOpened=true
  storageViewport=(0.0, 0.0, 1920.0, 1080.0)
  storageWidestButtonWidth=1548.09 storageWidestLabel=浏览文件、Synology DSM
  containerExists=true detailOpened=true detailOnPage=true
  detailWidestButtonWidth=208.0 detailWidestLabel=启动台
  ```
- Muse 宽度专用探针（17:20）：
  ```
  PROBE fix-verification-width-only: containerExists=true
  containerLabel=homepage、运行中 detailOpened=true onDetail=true
  infoExists=true infoWidth=126.0 infoFrame=(100.0, 225.0, 126.0, 38.5)
  widestNonTab=1920.0 widestLabel=
  ```

**判定**：
- **失败。服务详情信息卡（`tv.service.info`）实测仅 126pt 宽、38.5pt 高**（frame `(100, 225, 126, 38.5)`），远低于要求的 ≥1400pt。上一轮该页最宽按钮 208–211pt，本轮信息卡 126pt，**压缩没有解决**。
- 存储与媒体页最宽按钮 1548pt，正常（与上一轮一致，说明该页本来就不压）。
- 页面本身是满宽（`widestNonTab=1920`，应为 ScrollView/背景），压的是内容卡，不是页面。
- 三主题（清流/栈列/流光）未逐一核对——当前主题下详情页已失败，换主题不能改变本项结论；待 Codex 修好详情页宽度后，Muse 再按三主题复核。
- 连接管理页未测——XCTest 焦点到不了“我的”tab（与上一轮同一局限），需用户用实体遥控器从“我的”进入复核；但服务详情页的失败已证明同类子页的宽度约束问题仍在，连接管理页大概率同病。

**预期 vs 实际**：
- 预期：服务详情信息卡宽度 ≥1400pt，与存储与媒体页（1548pt）一致。
- 实际：信息卡 126pt × 38.5pt，被压成一条窄带。

**给 Codex 的线索**：
- `TVServiceDetailView`（`TVNASViews.swift:1465`）内信息卡 VStack（`tv.service.info`，`:1492`）的 `frame(maxWidth: .infinity)` 在 `ScrollView` 里未撑满；`tvPageInsets`（左右各 70pt）后的可用宽度应为 1780pt，但实测只有 126pt，说明不是 inset 的问题，而是卡片内部或其父 VStack 的宽度约束把内容收窄了。
- Codex 本批在 `TVViews.swift` 加的“tvOS 17+ 按 ScrollView 可用宽度约束整页”未对详情页生效，或生效后又被内层约束覆盖。请在详情页实测各内容块 frame，定位是哪一层把宽度压到 126pt。
- 探针里 `app.descendants(matching: .any)["tv.service.info"]` 在 Codex 探针中报“多个匹配元素”，Muse 补充探针改用 `.firstMatch` 后取到唯一卡片（126pt），该值可信。

**操作路径**：启动台 → 点 `homepage` 容器 → 详情页 → 测量信息卡 frame。

**证据**：`/tmp/nastart-tv-width-20261121.log`（第 303 行 PROBE，`infoWidth=126.0`，断言失败）、`/tmp/nastart-tv-acceptance-20261121.log`（第 1255 行 PROBE）。

---

## 探针与代码说明

- 复跑的探针在 `tvos/NastartTV/UITests/TVLaunchTests.swift`（现 1254 行，括号 186/186 平衡）：Codex 更新了 `testJellyfinEntryProbe`、`testDockerBackButtonProbe`、`testSubpageWidthProbe`（去掉主动 XCTFail、改验收断言）；Muse 追加了 `testFixVerificationDockerAndWidth`、`testFixVerificationDockerAndWidth2`、`testFixVerificationWidthOnly` 三个补充探针（焦点导航策略不同，用于定位探针本身的导航问题）。复用前请先 `git diff` 核对。
- 探针局限（与上一轮相同）：XCTest 焦点导航到不了顶栏 tab（“我的”/“设备”），所以连接管理页与容器列表入口未测，需用户用实体遥控器复核；启动台容器行的焦点扫掠也不稳定，第 2、3 个容器有时打不开，这是探针导航问题，不是 App 缺入口。
- 探针只做导航、截图、读 frame，不改数据、不点“断开/移除”等破坏性按钮。

## 剩余工作（给 Codex 下一轮）

1. **修服务详情页宽度**（本轮唯一失败项）：定位 `TVServiceDetailView` 信息卡被压到 126pt 的那层约束，修到 ≥1400pt；修好后 Muse 按三主题（清流/栈列/流光）与连接管理、存储子页、设备各子页逐一复核。
2. Docker 其余容器与容器列表入口的 Menu 返回：Muse 将用实体遥控器复核（或等探针导航稳定后复跑），Codex 无需为此改代码，除非遥控复核发现新问题。
3. Jellyfin 已通过，无需再动；若后续回归，先看 `JellyfinSession` 日志的 `http route=UserViews status` 与 `renew_*` 链路（Codex 已埋点，token 只记短 SHA-256 指纹，不记原始凭据）。

## 交回要求（沿用既定规则）

实现方改完后必须自己编过（Xcode 27.2，tvOS）、跑过相关测试再交回，不交“看着对但没编过”的代码。交回时说明：改了哪些文件、是否编过、服务详情页宽度是否复测通过。Muse 随后在真机电视上按本文件验收，失败写回本文档打回重改。
