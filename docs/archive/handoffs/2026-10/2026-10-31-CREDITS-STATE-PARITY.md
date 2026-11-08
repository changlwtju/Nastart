# 三端演职资料状态一致性

更新：2026-10-31T06:59:49+08:00。接[搜索与详情批](2026-10-31-SEARCH-REQUEST-OWNERSHIP.md)。按既定模型分工，仅本地代码/任务隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/源写/播放，无后台任务。

## 实际接线

原网络库已有MediaCreditsAvailability与MediaDetailCreditsNotice。本批公开其类型/resolve/初始化，resolve参数使用公开MediaReadState.Phase（原alias同类型），分类算法逐字同；Notice允许宿主传Text，原默认中文、字体/进度/secondary/组合语义及media.detail.credits.notice保持。移动补3个中英key，TV与网络沿默认文本，没有复制三套组件。

移动JellyfinMediaDetailView与TVDetailView实际消费：有当前可用people时仍挂原人物卡/图片加载器；无people时按元数据读取phase显示读取中/现有资料未提供/暂未读取。Jellyfin演职数据随detail响应取得，没有独立people请求，所以credits参数为ready，metadata只跟详情请求，不等移动后续similar或TV并行similar完成；初始idle与loading不宣称缺失。名字存在但头像未加载不进入缺资料/失败判断，原18/20上限、人物卡与图片读取均不改。

两端仅给原详情方法加MediaReadState begin/succeed/fail/cancel状态标记，没有新增请求、重排、payload接受gate或自动重试。移动原loadDetailContent移除这些标记后逐字同：保detailedItem成功赋值、音轨字幕默认与恢复、失败detailedItem=nil回退初始item、后续similar及取消返回。因此“现有信息”指当前可用资料，不声称保留每次旧完整详情/演员或修复实际头像；TV原失败保旧detail行为同。

TV相似影片失败caption按钮接共用Notice，原related架子保留；和Hero重试共用retryDetailContent标签/暖箭头/18×12/TVTileStyle，主重试ID/焦点/方向/几何修饰符同，相关重试新增tv.detail.similar.retry标识，仍reload=UUID（会重跑原详情及相似请求）。未把相关重试加入自定义方向图，原该按钮也是原生焦点，实际遥控可达未验，不能凭图关闭焦点问题。

8既有源/资源、439输入其余431同，无新源/测试；App外部store/认证/媒体项播放快照覆盖/轨道与播放函数、TV外部及方向函数同，网络库控制器/读取/图片源同。只公开旧分类/展示并接入状态，未动播放路线/引擎/缓存或源文件。

## 有限验证

12既有参数/状态回归过，含已有的pending不宣称missing、失败与成功空区别、已有people优先、同词/跨身份/重复终结；分类逻辑未变，不增镜像测试。两语言strings格式/三新key唯一性过，两模拟器Debug/正常签名Debug/无签名Release串行过。439输入构建后同、正常候选30/27 Mach-O hash/完整签名及TV嵌入库过，cp -cpR请求克隆并独立核验，无测试参数/环境、未装真机，root清单更新。

原credits-loading/empty/error/missing四个Debug场景三端各4，新增related-notice仅TV1，共13静态窗：预期/禁止文字、主题/背景连续两样本稳定/hash核过，所有对照表实看。前三个挂同一CreditsNotice，missing场景有合成人名/无照片卡片，不能把空头像当无people；related只有两合成海报与空回调。场景不构造真实model/store/vault/client/Task，不执行刚接入的Jellyfin详情方法，TV按钮是NetworkTVCompactStyle而非AppTVTileStyle。只说明组件可见区，不代表真实状态转换、资料/头像请求、重试/方向/滚动性能、英语长文/大字或读屏验收。3实例finally清/fresh无，合成偏好保持/无额外应用键；沿4.8/3.8启动及2GiB运行预算，未清用户缓存/旧包。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-31T06:50:19.735046+08:00 | `bfbaf69317958bca9cde68474678f56ca3a597cfad4dcaa65e809b5ec39a57e2` | `b14043a9b90fbcc7a9c0b509cf85901d33665c3fa7fb18bf830583d1a60d24b4` | 30 |
| Apple TV | 2026-10-31T06:52:08.802813+08:00 | `21c0fcae053c6a59e6e00617921593cd8e893b6905c06e367626fe7aa6d3fac5` | `c274a229c62c55b26378406a5c96d9b3bab60278e207edf2b377ea1447c03f88` | 27 |

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，保留继承未提交修改。[安全结果](../../../testing/results/2026-10/2026-10-31-credits-state-parity.json)，原始路径/图/命令/偏好仅仓库外current-credits-state-parity-private。旧大字位移失败、真实搜索/照片与全部积压仍留；核对播放矩阵，本批非播放，114格无新P。

## 接续

优先核TV详情状态按钮的方向/可达，当前相关重试未接自定义方向图；先抽纯焦点目标规则及合成覆盖，再接实际UI，不把截图当遥控验收。其他旧待验及真实网络/播放等安全恢复新环境，Astra仅核心播放优化前提示。
