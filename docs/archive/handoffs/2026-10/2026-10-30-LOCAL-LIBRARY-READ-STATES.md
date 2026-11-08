# 本机媒体库读取状态与共用恢复入口

更新：2026-10-30T16:30:55+08:00。接续[首页与墙共用状态](2026-10-30-SHARED-HOME-AND-WALL-STATUS.md)。仍6.1；NAS恢复期只本地代码与自建隔离模拟器，0真机发现/控制/安装、0NAS/旧凭据/播放/源写。不改NAS/VPN，无后台任务。

## 问题与正式接入

代码审查发现NetworkLibraryFilesView只要找不到指定ID便显示ProgressView，不能区分读取失败、尚未完成与入口移除。未宣称真机复现：LibraryPosterWall中改文件夹原本已有onSaved→dismiss，本批保留该回调，不把改路径后必然一直转圈当既成事实。

新增纯Foundation的LibraryLocalReadState管理本机资料读取的idle/loading/ready/failed及所属错误。NetworkLibrariesModel.refresh实际使用它代替refreshGeneration：每个异步读取返回后核当前请求与Task取消，再应用数据/继续下一阶段；旧请求的成功、失败、取消不得盖掉新请求；取消/提前返回只结束其仍在进行的读取，回到可重试idle。旧缓存数据不会因失败被清空。原adoptLegacyConnections及其本机凭据/存储事务逐字保持，未改变事务本身，也未验证其并发取消或回滚。

读取失败使用不含端点/路径/系统原文的本机资料提示，只归localRead.failureMessage；不再沿用网络/地址诊断。displayError为原操作error优先、再本机读取错误，实际接首页和海报墙三个显示位置。重试开始/成功清掉自己的旧读取错误，不清掉原扫描/删除等操作错误。其他model方法从adoptLegacyConnections至类结尾逐字同；海报墙除model.error→model.displayError外逐字同，修改目录的dismiss、海报/搜索/播放/焦点等保留。

FilesView只在库缺失时用NetworkLibraryAccessStatePage，库仍在就继续原海报墙。读取中明确是本机已保存资料；失败/idle提供重试与返回；ready却无ID提示“媒体库已变更”并返回重选。重试只调用现有本机refresh，不发扫描/目录请求；稳定ZStack上管理本页所建retryTask，返回/消失仅取消本页任务，不调用扫描取消。真实Task/导航行为仍待端到端核验。

新状态页与原已有连接准备/错误页共用NetworkReadPageActions，保留原按钮文字、暖色图标、语义色、TV紧凑按钮、标识和回调；iOS辅助大字纵排，普通横排。NoticeContent允许定制标题，原消费者默认“操作提示”；新失败页不再重复显示两个标题。4既有源+1新源+1测试文件，437输入，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，继承未提交修改保持。

## 验证与限制

3条新纯状态测试覆盖重叠请求晚到、旧错误/取消不覆盖新请求、失败后重试清理及完成后拒绝晚到错误、取消回idle后可重试；4既有OfflineUIScenarioTests覆盖新增4场景显式参数/错误隔离，共7通过。它们不构造真实model/store/vault，不等价于SwiftUI任务取消与本机迁移联调。

Debug新增read-loading/error/missing/idle，直接挂正式状态页、固定合成说明、空回调；无model/store/vault/client、网络/目录/影片读取。计划三端各4新状态+2已有连接状态，共18窗；实际TV6静态窗合格，三主题/亮暗、正确按钮出现及不出现、合成标识、背景两样本稳定、图hash核对；六原图已实看。手机/Pad均低于4.8GiB预算，有界等待后未建实例，12窗待；旧批移动图不补算当前抽取后的组件验收。TV按3.8GiB起步/2GiB运行保留线，两轮共2自建实例finally清理，fresh列表无，合成偏好原样且无新增应用键。

初次截图脚本因系统Python无Pillow在创建实例前退出（0实例/0窗），改用已存在的带Pillow运行时；没有安装依赖。最终截图无失败重采。最初一次7测试与双模拟器编译通过后去掉失败页重复标题，证据保留pre-capture-heading-refinement；随后首轮6窗和各配置构建均通过，收尾审查又发现本机读取仍沿用networkMessage，修成本机提示后重新编译/重采。首轮6窗/构建保留pre-local-read-error-copy-refinement，不算最终源码验收；最终只计6窗，两轮共2实例已清。没有删除失败、超时或旧证据，本批未做缓存/磁盘整理。

双模拟器Debug、原生双签名Debug/双无签名Release全部串行通过，437输入构建前后hash一致、30/27 Mach-O哈希/核签及TV嵌入库过。无测试参数/环境的普通Debug候选已冻结仓库外、未装真机，root最新清单更新。实际返回/重试/本机读取/移除/大字移动布局、遥控/读屏/滚动/真实海报/播放都未验；播放矩阵114格无新P，路线/引擎/缓存不改。

| 候选 | 构建时间 | 主二进制SHA-256 | Debug dylib SHA-256 | 核签Mach-O |
|---|---|---|---|---|
| iPhone/iPad | 2026-10-30T16:27:28.432269+08:00 | `73e49067bf940ddff3df8170a56b339635ce82149a28e100b65d74b663cb42be` | `82ff316570b9ceeb3efb7f677dec84400ef056deeb5dfd785d43e50f51c86d94` | 30 |
| Apple TV | 2026-10-30T16:29:19.719977+08:00 | `fbbbf512475ab6124bf407ca3881f9e5f5b64ca1ee832f70c9dbe05abdf6972c` | `b45b30456574a618b51a33957810059e2ad5a0a677cbc589e2f04ecec1d08e09` | 27 |

原包/截图/命令/偏好只在仓库外current-library-local-read-private；[安全结果](../../../testing/results/2026-10/2026-10-30-local-library-read-states.json)。接续先核空间，预算达标再补新状态移动12窗及上一批首页/墙移动12窗、旧Pad准备状态/真实返回，不降保留线或反复建受阻实例。后续已核首页读取失败仅提示、没有直接重试入口，优先复用恢复动作补齐；保持源文件只读。真机/NAS仍等安全恢复，Astra只后续核心播放优化提示。
