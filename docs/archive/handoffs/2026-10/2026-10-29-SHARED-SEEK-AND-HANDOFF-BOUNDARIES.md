# 共用跳转状态与换源边界

更新：2026-10-29T08:03+08:00。承接[共用会话资源批](2026-10-29-SHARED-PLAYBACK-SESSION-LIFETIME.md)；[结构化结果](../../../testing/results/2026-10/2026-10-29-SHARED-SEEK-AND-HANDOFF-BOUNDARIES.json)。用户说明 Container Manager 仍在修复，继续不依赖 NAS 的工作。本批6.1执行代码整合，无设备安装/启动/控制、NAS探针/登录、蜂窝任务或源文件写入。

## 接受源码及实际差异

新增同一个 `NetworkMedia.PlaybackSeekState`，被移动 `GreenfieldPlaybackControls`（AV/KS共用）、电视 `TVPlayerControlsModel`（AV）与 `TVKSPlaybackControls`（KS）直接调用。共用绝对目标边界、有效时间线检查、连续相对操作的待完成目标优先、generation、完成确认及换会话/停止失效。移动实际AV/KS回调显式携带提交时generation，旧回调不能清空新目标；暂停预览、字幕cue及缓冲恢复等原有控制保留。

电视片尾边界从正好duration对齐到手机既有duration−0.1秒（极短片段下限0），没有另调性能参数。电视KS相对跳转优先实际引擎时钟、再回退已发布的有效时间；尚未完成的跳转仍优先其目标，和移动端一致。NaN／infinity／非正时长／溢出结果拒绝派发，不改变当前有效generation。

新增共用 `PlaybackHandoffBoundary`：移动 `canReplacePlaybackSession` 直接调用原有seek/PiP规则；电视 `TVUnifiedPlaybackSession.replace/install` 在加载前和两个await边界核时间线generation。等待服务器候选期间发生新seek或renderer重置，拒绝旧候选并经上一批共用生命周期独立release，保留原资源；这类被新意图取代的候选不显示播放错误。暂停、倍速等继续在提交时读取最新状态，TV不虚构PiP支持。

实际映射：

| 操作 | 共用实现 | 平台适配 |
|---|---|---|
| 绝对/相对目标与连续快进回退 | PlaybackSeekState.target/begin | 原生AV/KS派发 |
| 迟到完成与退出/换会话 | complete/invalidate | 媒体item/字幕预览与呈现 |
| 时间线/PiP换源当前性 | PlaybackHandoffBoundary | 移动PiP状态；TV只提供时间线 |
| 候选/旧源所有权与清理 | 既有PlaybackSessionLifetime | 原生renderer同步停止、来源release |

原生渲染/控制和完整预热、兼容换源执行仍有平台适配，本批不称所有播放细节完全同源。未改KSPlayer库核心、解码、缓冲、探测、超时、码率或seek性能参数，不作Astra优化。

## 验证

共用模块26项全部通过，其中新增8项覆盖连续目标、片尾/极短片段、非法时长/时钟、溢出、旧完成、相同位置换会话、seek/PiP换源边界及可选seek约束；其余为上一批生命周期/准备/来源定向。TV完整单元55项通过，新增真实TV会话夹具验证异步候选返回前时间线失效→候选释放→原计划/资源保留→退出再释放原资源。该夹具用控制层reset模拟generation变化，未挂真实媒体surface，不等实际遥控seek验收。

移动34项选中：33通过、0失败、1跳过。跳过项 `testPiPRestoreAndCloseHaveDifferentSessionLifetimes` 因模拟器无法创建PiP控制器，真机PiP仍待；不能把它记通过。新增移动实际控制层旧/离场回调与非法时长不派发，既有连续正反跳转、暂停预览、音轨共用seek、缓冲/续播及换源规则均保持。既有小型本地视频仅作功能回归，不当大文件优选或响应速度证据。

双端普通签名Debug、无签名Release编译成功。源输入428项逐项SHA复核一致，保留 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 与继承脏树。冻结包的路径、输入、构建/测试原始输出和完整签名只放本机私有证据。定位用 `current-shared-transport-state-private`；root包/源码清单指本批未安装候选。

| 候选 | 构建时间 | main SHA-256 | debug SHA-256 |
|---|---|---|---|
| 移动 Debug | 2026-10-29T07:57:34.380878+08:00 | `964607a0330d475461a97a2b253dcb5d290659d7627835a7e40f808e26bf08d9` | `39fc6603da36810138dc677b5eb9b2003a9bcae6b390213724a6c406c3b7f0ae` |
| TV Debug | 2026-10-29T07:57:03.124704+08:00 | `a97268926bf21e3299bba46a3c066ca25af8cf0349510f64259a39b91cfeeb0b` | `ec49cd52cf4b374a18db7e05d26d798bb1dece1d6f3880784d8ed55335f139a1` |

30/27个Mach-O逐项和deep/strict签名、TV嵌入库核对通过。Release仅编译，无签名安装或真机验收；默认args=[]/env={}候选没有安装到任何设备。所有真机仍保留前批已装包，426上一批离线候选也未安装。

## 下一步与未验

继续保持NAS/DSM/真机支线暂停，不请求新验证码或复用旧OTP。下一收敛原生命令执行及异步seek完成时的最新播放意图：源码中KSPlayerLayer.seek的ready分支仍捕获提交时autoPlay，需受控时序验证，不能直接当已复现的真机暂停故障；本批没有修改该核心。完整源切换执行与renderer接口也仍需核对。

NAS恢复后fresh核设备和最新包、保留数据覆盖，再对三入口/三端做共同基础及大文件首帧、续播、正反seek、换音轨字幕回归；核心性能优化阶段才提示Astra6。此前13约1MB/s缓冲、Pad控制/普通退出、TV内网DSM两步后失败、ISO、弱蜂窝、PiP、Release等缺口保留。0性能窗口、114格不增P，需求编号只在[唯一总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)维护。

收尾校验：428输入未漂移。首次整文件空白检查命中TVViews继承的3行尾空白；与本批修改前快照逐行比对后确认均未变，保留原稿，仅核新增/变更行无尾空白。不为修格式重新改动已签名候选。文档512份／3080本地链接／0缺链。
