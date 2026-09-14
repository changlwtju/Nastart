# NAS 第六批：同条件双入口比较

关联 PX-01/PX-02，状态继续进行中。本批新增离线工具和测试、接入 preflight，并标明旧 Auto/Force 工具的历史用途；不修改 Swift 或真实服务。分支 work/nas-20260914，仍未提交/推送。

## 解决的问题

旧 playback_compare_runs.py 按 Auto/Force 汇总导出日志，没有验证片源、轨道、位置、设备或构建一致性。不同影片、未完成首帧或重复导出都可能让一个汇总值看似更快。本批保留历史工具，当前两入口实验改用 playback_compare_entries.py。

新工具读取配对 manifest 和第五批生成的报告 JSON，不靠时间相邻、片名或 Auto/Force 标记猜测可比性。每条观察独立填写条件，以避免一个公共元数据声明掩盖两次播放的差异。

## 使用

1. 从 [三组配对模板](../development/playback-pairs.example.json) 复制一份到本地 tmp 目录。模板未知字段故意不通过校验，不能当实际样本运行结果。
2. 导出两入口同条件的正常包日志，分别运行 playback_trace_report.py --json 得到报告。先处理 unassignedEvents，不能删除这项审计来绕过比较检查。
3. 为每次观察填写 report（相对 manifest 的路径）、playbackTraceID、planID，以及全部 conditions。一个 pairID 下各有一条 dsmFile 与 jellyfin；至少三组实际独立重复，不能复制同一 trace 凑数。
4. 运行：

```sh
python3 scripts/playback_compare_entries.py tmp/playback-pairs.json > tmp/playback-pairs-result.json
```

退出码 0 表示该清单满足工具的比较条件；2 表示数据不足/不匹配或输入错误。正常的拒绝结果仍输出 JSON，summary=null、issues 列原因；输入文件/JSON 本身无效则 stderr 报错。批处理不要忽略退出码。

## 配对字段与门槛

| 字段 | 填写依据 |
| --- | --- |
| sampleID / fileRevision | S 编号及相同文件版本指纹/字节数+修改时间记录；文件名本身不足 |
| audioTrack / subtitleTrack | 同一源文件的实际轨道身份；关闭字幕写 off，未知不能写 off |
| startSeconds | 明确请求起始点的有限非负数，不能用首帧已推进的位置替代 |
| device | 设备/系统的脱敏实验标识，两条观察使用同一设备 |
| network | 实验条件标识，包含接口、上游路径及负载条件；冷热/网络变化应另分组 |
| build / buildMode | 同一准确构建标识（含未提交差异标识），buildMode 必须 normal；ASan 等诊断构建拒绝 |
| cache | cold 或 warm，分开清单，不混算 |

整份清单只接受一个条件组合；跨影片/断点/设备/网络/构建/冷热拆成独立清单。实际 decodeEngine 和 playMethod 从报告取，必须明确且组内一致，避免将 HLS 与原画混成入口差距；routeKind 须存在，但不同入口可有不同 routeKind。只比较同一构建两个入口，不是跨构建优化百分比工具。

报告必须为 strict trace 输出、unassignedEvents 为空、trace/plan 唯一且非 legacy；失败或缺少 failureStages 审计不通过。只接受有限非负 tapToFirstFrameMs 且 firstFrameSignal=playbackClock。身份相同的 trace 即使来自另一个文件，也不能重复计数。

任一观察失败、缺字段或不匹配时，保留 attempts/completePairs 和 issues，不删除失败后汇总“成功样本”。至少三组完整且全组无问题才计算探索性中位数、最小/最大值，以及每组 Jellyfin−设备文件差值的中位数。

## 结论边界

输出 metric 明确为 playbackClockMs_not_screen_first_frame。无 P95、无“所有影片都快了”或自动验收结论，也不把服务端播放状态正确性、30 秒稳定性、听音或实际屏幕首帧纳入一个速度值。

metadata 是操作者基于证据填写的声明，工具检查一致性，不证明这些声明真实；entry 同样由 manifest 声明，报告不足以独立证明入口。未填入清单的实验也无法被工具发现，必须保留完整实验记录。正常构建、轨道选择、网络和冷热需在采集时核对。

缺少真实 Mac 日志，本批用合成 fixture 验证校验与计算逻辑，不产生真实性能结论。下一步 Mac 完成 16 项待验 Swift 测试及集成检查后，再采集代表样本的正常包三组配对；NAS 可直接检查/比较导出结果。

## 本批检查结果

新增 11 项 unittest，覆盖各条件不匹配、未知条件、失败/缺首帧、重复 trace、未归属事件、诊断构建、非有限数、引擎/方式/信号混用、重复不足以及 CLI 相对路径/退出码。连同此前 12 项，全部 23 项实际通过；preflight（包含新工具语法检查）和 git diff --check 通过。
