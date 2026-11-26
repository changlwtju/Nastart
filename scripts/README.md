# 工具导航

工具入口保留在本目录，避免破坏已有开发命令；原始输出、设备偏好和安装包写入仓库外私有证据目录。

执行设备工具前先读[真机安装与远控手册](../docs/development/PHYSICAL-DEVICE-REMOTE-CONTROL.md)：安装、原生进程/截图与WDA是独立层；历史默认UDID/端口不可直接沿用。当前NAS暂停、18 hands off、TV发现/签名阻塞；本地预检通过不代表取得设备窗口。

| 用途 | 主要工具 |
| --- | --- |
| 项目与文档检查 | `preflight.sh`、`preflight.py`、`check_documentation.py` |
| Xcode 构建与链接检查 | `xcodebuild_nastart.sh`、`verify_playback_linkage.py`、`embed_swift_compat_span.sh` |
| 已配对无线设备与安装 | `discover_paired_wireless_device.py`、`install_paired_wireless_app.py`；先读[无线操作规范](../docs/development/IPHONE18-WIFI-UPDATE.md) |
| WDA 与原生界面操作 | `prepare_wda_recovery.sh`、`start_wda_iphone.sh`、`wda_capture.py`、`wda_native_actions.py`、`wda_command_guard.py`、`wda_usb_session.py` |
| 真机诊断与采样 | `download_device_diagnostics.py`、`device_graphics_probe.py`、`device_packet_budget.py`、`ui_scroll_probe.py`、`tidevice_private.py` |
| 播放链路与对照报告 | `playback_trace_report.py`、`playback_phase_report.py`、`playback_server_log_report.py`、`playback_handoff_alignment_report.py`、`playback_compare_entries.py`、`playback_compare_runs.py` |
| 受控夹具与资源 | `playback_lab.py`、`playback_policy_simulator.py`、`generate_playback_fixture.swift`、`generate_audio_test_sample.py`、`match_video_reference.py` |
| NAS Agent | `publish_agent_image.sh`、`install_agent_via_ssh.sh`、`upgrade_agent_via_ssh.sh`、`agent_smoke_test.py` |
| 调试保活 | `with_awake_mac.sh`；随任务生命周期持有临时断言，不改系统电源设置 |

`test_*.py` 为相应工具的回归测试。旧安装/恢复工具只按[播放调试规范](../docs/handoffs/PLAYBACK-DEBUG-RUNBOOK.md)选用，不替代逐台最新包核验。

文档调整后运行 `python3 scripts/check_documentation.py`；开发检查运行 `bash scripts/preflight.sh`。

`playback_server_log_report.py`以每次操作选中的首分片请求为5秒关联窗起点；存在唯一seek派发时先按实际派发/trace筛选，派发前旧流或其他trace的请求及其失败仍单列保留，多个派发保持歧义。没有派发标记时显式使用actionStart边界。保留HTTP失败、显式无响应/零正文、未知和候选失败阶段；时间/序号关联不证明服务端会话身份，不将清单等待、分片等待与实际解码/呈现合并为首帧。

`playback_phase_report.py` 的 `startupSegmentAttempts` 保留每次首片请求及失败，按本地trace/child区分重请求，匿名导出等头、正文、读EOF、发送失败和取消。区间可能重叠，不相加；EOF不是取消证据，缺child时关联保持未知，不证明服务端任务归属。报告只重放私有快照，不发网络请求。

`firstObservedSegmentAttempts` 按 trace 输出观察窗内播放器最早可见的分段请求，包含实际分段序号及同一 child 的重试。排除标记为预取的请求及首帧之后新发的请求，保留此前请求的迟到结果。旧 `startupSegmentAttempts` 继续按 0 号段报告。

`playback_reserve_report.py` 的 `seekCapacityPhases` 按trace/plan/请求generation/track local epoch隔离，使用样本自身单调时钟拆请求→实际codec flush→转换后首回调→首接受→首次观测playable；时间基准、目标或首回调矛盾时派生耗时为未知。等待与就绪样本之间的空档不是轮询周期或可省时间；满视频队列也不证明packet+frame储备门槛已满足。`playback_seek_phase_report.py` 另列已归属的暂停预览输出及继续后的时钟恢复，明确主动暂停可能包含于恢复耗时；缺预览不证明当时正在播放。两者均为离线报告，不发媒体/设备请求，不替代屏幕与听音。

`wda_usb_session.py`为延迟连接的私有USB/session适配器，不建立会话或修改设置；与`wda_command_guard.py`串行使用。先做逐台最新包闸门，传当前session/前台PID。UI transition只验控件及截图变化，不能用于证明暂停、电影或帧时间；参见[CLI观测规范](../docs/testing/CLI-DEVICE-OBSERVATION.md)。

瞬态控件可在 `click_unique` 指定 `max_observation_age_seconds`（大于0且不超过2秒）和只读 `validate_target` 回调。计时覆盖选取、查询重读、属性/场景复核及发送前记录；到达期限抛出 `ObservationExpired`，不发点击。未指定时保持既有调用行为。即使未过期，控件仍可能在点击期间隐藏，效果仍须独立核验，未知动作仍不重发。

`pip_pause_evidence.py`只分析调用方提供的原生UI/PNG与偏好事件快照，不连设备或发动作。需要完整owner/runtime基线、新单次实际暂停回报及相隔2秒的原生暂停UI；连续时钟/电影恢复/音频/帧时间明确未证。`wda_usb_session.py`新增固定快速source白名单和SpringBoard定向PiP属性观察，缺visible字段保持未知，截图/原文只私存。优先使用既有start/capture/native_actions链路，见[本批边界与失败](../docs/archive/handoffs/2026-10/2026-10-20-PIP-PAUSE-OBSERVATION.md)。

- `hdr_pip_fixed_pool_probe.swift`：Mac单一固定4K10-bit视频范围池的真实sample/共享IOSurface别名及12次不兼容代次拒绝；保持四surface并禁age-out/换池，结果不等于iOS/App全局资源或字幕交付。见[实证](../docs/archive/handoffs/2026-10/2026-10-21-PIP-FRAME-CONTEXT.md)。

`playback_phase_report.py` 分别保留 `deliveryCapacity` 与 `predictiveDeliveryCapacity`：前者可为单完成任务的预算提示，后者缺失时不冒充已有预测确认。当前App规则与19:24窗未发起降档的有限解释见[离线核对](../docs/archive/handoffs/2026-10/2026-10-23-IPHONE13-ADAPTATION-GATE-AUDIT.md)。
