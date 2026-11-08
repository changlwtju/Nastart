# 诊断写入前脱敏、旧记录显示与持久化回归

日期：2026-11-01。承接[导出文本批](2026-11-01-EXPORT-TEXT-PRIVACY-REGRESSION.md)，按最新进度继续独立隐私审查。全部真机/NAS仍暂停，0真机发现/控制/安装、0NAS请求/媒体/源写、0真实凭据/用户诊断/导出读取或分享；未启动普通App/模拟器。未改NAS/VPN/系统/开发账号/profile，沿既定模型分工，无Astra、定时或后台任务。

## 发现及接受实现

旧record逐个redactedDetail(value)后拼key=value：值本身没有重复字段名时，password/Authorization/path等已知敏感键无法在这一步保护，原值可能进入entries及缓存；旧文本正则对引号内空格/分隔符、内嵌URL及普通长键名边界也不充分。这里只证明源码和虚构反例，没有读取用户日志或声称已发生真实凭据泄露。

DiagnosticLogStore.record现在先redactedDetails(details)：保留非空筛选/键排序，对规范化后完整匹配的敏感键将整值遮蔽，包含驼峰令牌及Cookie头别名，其他值走redactedDetail，再形成entry。append/NSLog/保存使用已处理detail。导出和诊断复用redactedSensitiveText：完整/未闭合引号、转义/换行/孤立反斜杠、已知凭据/路径字段、Basic/Bearer/配对码及内嵌URL。字段表达式与文本表达式不可变缓存，只编译一次；没有新增每条采样的计时、采样或持久化任务。

数据导出仍独有完整URL/独立host摘要分支，诊断不会把0.0417或125.5当host。redactedHost/redactedURL策略保持；结构化durationMs/status/planID/playbackTraceID/pathDepth/tokenCount的黄金字符串核同。生产计时、追踪编号生成、播放器/路线/缓存未改；私密字段值被主动遮蔽，不能据此称日志内容全部逐字节相同。

旧缓存不做自动清除或脱敏迁移。已有DiagnosticLogEntry原始detail仍保留；显示和exportLine经过新redactedDetail保护已知内容。本批没有迁移/清理用户缓存，也不承诺旧缓存已静态去除全部秘密。entry Codable结构、头部/时间格式及append之后的保存队列、750ms普通批次、错误立即刷写、clear逻辑均原字节同。

中英文diagnostics.footer仅各改一值，键集保持，说明记录范围/最近1000条/手动清除，以及识别到的字段/网址会脱敏，分享前检查自填内容及旧记录。收窄旧说明中完整地址、文件名脱敏范围的表述；当前页面/大字/读屏未补验，不当UI通过。自由姓名、普通地址描述、未知键、host摘要和关联ID等仍不能保证严格匿名。

## 测试、失败与边界

新增6项NonPlaybackPolicyTests；选6新项、前批8导出项及4既有诊断/持久化项，共18唯一例。使用实际完整DiagnosticLogStore/DiagnosticLogEntry及选定测试方法体，在私有macOS Swift package执行；只将UIKit import替换为合成UIDevice头部占位，未启动AppState/账号宿主。基线额外用旧record的原映射体适配新formatter测试接口，实际旧record仍照旧执行。

最初18样本旧输入13过5失败、修正后18过，缓存化后再过；随后AccessToken探针检出候选残留，补入AccessToken/refreshToken/clientSecret/Set-Cookie别名及同组输入。最终同一18方法旧输入12过6失败，接受实现18过0失败；原探针/中间结果保留，不累加唯一覆盖。新项实际调用store.record，以自有随机命名UserDefaults套件核内存和已编码持久化中的合成秘密不再存在；旧entry显示/导出保护但detail不变、带引号JSON有效/幂等、普通长键和数值保持、自由文本不保证匿名均覆盖。既有连续记录批次、错误刷写/清除用例也过。仅这些测试自有合成偏好和键被清理，未读取/清除用户App偏好；不是原生iOS/TV宿主、真实缓存迁移、系统日志导出或分享验收。

首个测试提取器把MainActor标记截成独立声明，编译失败且0例执行；修正方法边界后才得到红/绿结果，失败和全部源保留，不作App故障。表达式缓存前18成功记录与文案前六配置另存，不充最终输入。6模块130项既有Python报告工具回归过；它们配合黄金字段证明有限工具兼容，不等于130个播放窗口/真机性能结果。

## 构建、身份与收尾

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，446输入只改DiagnosticLogStore、NonPlaybackPolicyTests及两语言资源4个既有文件，其他442个hash同；保留其余未提交修改。最终双端模拟器Debug、双端设备无签名Debug/Release六项exit0；每项开始均晚于最终源冻结。私有指针 `current-diagnostic-privacy-private` 保存原始合成结果、源码/命令/时间、模拟器编译包二进制/资源SHA-256和失败；[共享结果](../../../testing/results/2026-11/2026-11-01-diagnostic-privacy-and-persistence.json)不含设备ID/路径/凭据。

手机缺开发profile、TV旧profile阻塞保留，本轮未重试普通签名、未冻结新候选/安装真机。旧包身份保持，根source-inputs/currentSourceAssessment更新为不匹配最终源；旧签名沿前批证据，本轮未重核，不把无签名编译当可安装包。0新模拟器/图，无自有后台构建/采集，未清用户缓存/资料，沿2GiB运行保留线，最终空间见共享结果。

已同步播放架构中的诊断映射/核对日期，真实播放路线不改；核对唯一需求总账和114格功能矩阵，不关闭整项或制造新P。

## 完整导出只读盘点

直接核当前DataExportView源码，未生成或读取用户payload：metadata固定含formatVersion/exportedAt；启动台含已处理name、枚举category及visible；提醒含已处理title/target，但保留原UUID、精确日期、daysBefore/muted及可选kindRawValue。偏好三项主题/语言/显示模式直接导出原始UserDefaults字符串，仅缺失时回退；两个开关按Bool取值。三项原始偏好及kind尚无本批归一化/校验，完整选择组合、字段省略、序列化和真实ShareLink未验；只读盘点不当完整导出通过或严格匿名实现。

## 接续

下一独立审查完整导出payload与未知字段/裸地址文本边界，严格匿名方案、真实分享/读屏仍开放。旧缓存静态清理/迁移需要另列方案与证据，不在本批自动改用户数据。Pad采图继续阻塞，不重复同样CUA超时；工具恢复后补Pad页脚/设置关联窗、正式连接管理与诊断说明。密码显隐、缓存显式取消、真实事务及全部真机/NAS播放继续开放。
