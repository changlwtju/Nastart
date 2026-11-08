# 搜索请求归属与详情失败提示

更新：2026-10-31T06:04:37+08:00。接[缓存内容批](2026-10-31-CACHED-CONTENT-PRESENTATION.md)。按既定模型分工，仅本地代码/任务隔离模拟器，0真机发现/控制/安装、0NAS/凭据/源写/播放，无后台任务。

## 实际实现

复用现有MediaDetailReadState.swift中的UUID代次读取状态：公开为MediaReadState，保留MediaDetailReadState兼容别名；去除public及别名/显式空init后，原算法逐字一致，原元数据/人物读取仍同一实现。无独立新请求层、结果存储或持久化。

移动JellyfinSearchView实际使用该状态，task键为原始query与只由重试按钮修改的稳定UUID。非空关键词对应状态尚未开始时显示加载，避免新query的首个body展示旧结果。空关键词立刻显示搜索引导并在任务清results/重置代次；新请求begin使用原trim关键词，保350ms防抖、原store.search和取消检查。完成须同时满足未取消、当前trim词等于ticket.identity、该ticket仍为最新且loading；同词重试/切到其他词再返回不能接受旧代次，晚到的错误也不能清新结果。失败继续清results，不把上一词的内容冒充缓存；新增action.retry按钮，原搜索文案/结果网格/导航保持。会重试原查询，未加自动重试、网络调参或新播放路线。

TVDetailView原橙色caption错误/小重试替换为既有MediaLibraryNotice，标题“详情暂未更新”，保原错误原文/播放提示、reload=UUID、tv.detail.retry标识/焦点/方向/几何回调。按钮用暖色箭头、主色文字、18×12内边距和TVTileStyle；提示在暗色Hero内局部指定dark，避免浅主题primary黑字落在暗背景。Hero本身已提供dark环境，局部声明沿用现有主题策略；不把该声明当新增Hero主题修复。仅该错误块改变，所有请求/播放/其他焦点代码同。网络详情的文件信息与人物读取未改。

6既有源码/测试，439输入其余433同，无新文件。App除SearchView外逐字同；TV除详情错误块外逐字同，UI外的store/auth/服务/播放器同。数据读取归属新增防护已列明，不把这批说成只有样式修改。

## 验证与限制

12项本地测试过：原参数/隔离4与原资料读取5保留，新增3覆盖A→B→A旧响应、清空后重搜的旧ticket、完成结果不能被重复终结并且新词无旧phase。这些是纯状态时序回归，没有真实服务器或异步请求执行；App当前query/取消guard与重试键也需后续真机验证。

双模拟器Debug、正常签名Debug、双无签名Release串行构建过；先给TV重试标签补内边距后仅重建TV模拟器，保留之前构建，参数/纯逻辑未改不重跑测试。439输入构建后同、30/27 Mach-O hash/完整签名及TV嵌入库过，cp -cpR请求克隆并独立核验；正常候选无测试参数/环境、未装真机，root清单更新。

新增search-retry与detail-notice两个Debug样例，挂正式EmptyState/Notice/Hero；搜索样例没有实际query/搜索store/代次转换，详情只有合成渐变和卡片。动作为空，TV预览按钮是NetworkTVCompactStyle而非App TVTileStyle，无model/store/vault/client/Task/真实图片/网络。每端搜索错误深色1窗、详情浅/深2窗，共9静态窗文字/控件/合成标识/背景稳定/hash与6张对照表实看；浅主题下暗Hero提示文字仍可读。只是展示验证，非真实详情、遥控焦点、点击重试、输入/结果更新或滚动性能验收。3自建实例finally清/fresh无，合成偏好保持/无额外应用键，预算沿4.8/3.8启动和2GiB运行线，未清用户缓存/旧包。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T05:54:45.483535+08:00 | `484ddf1fd1343e3b2746ee188cd9496cc19ce6370a21abc3e2e971fed8eccd56` | `0d2eb29531c20787fccf7c559669c52a400fbf8798d8a5f6dbd109b8e82e67fb` | 30 |
| Apple TV | 2026-10-31T05:56:41.682935+08:00 | `f220f24eb948331f2bd1a65be61d357346a069a4447e1bcc660fe238f1a53b62` | `5143834432f2a403afb9e69e483ea27707a45003ed0585732b5aa4734b9d366a` | 27 |

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留继承未提交修改。[安全结果](../../../testing/results/2026-10/2026-10-31-search-request-ownership.json)，原始包路径/图/命令/偏好仅仓库外current-search-request-ownership-private。旧大字滚动失败与其他未验仍保留。播放路线/引擎/缓存未改，114格无新P。

## 接续

继续核对资料/人物部分读取与来源不可用的说明，优先复用现有组件，确认错误范围和重试副作用；TV详情reload仍同时启动原详情/相关内容任务，不算单独只重试详情请求。真实搜索时序/大文件/网络/播放待安全恢复的新环境，Astra仅核心优化前提示。
