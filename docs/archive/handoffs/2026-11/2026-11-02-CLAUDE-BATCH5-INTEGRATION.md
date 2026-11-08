# 第五批集成：WebDAV协议还原与无改动保存边界

2026-11-02。[Claude交付](2026-11-02-0650-CLAUDE-BATCH5-DELIVERY.md)、[分配](../../../development/CLAUDE-BATCH5-ASSIGNMENT.md)。私有证据 `/tmp/nastart-claude-batch5-integration-path`。

核独立a087a486分支、四文件起始/最终完整SHA与报告一致，补丁SHA `3c05a5f760581d208257feacd69aec86c973ad387404e2ce7d84794f3aa72436` 与实际四文件git diff字节完全一致。明确释放后先保存原文件/index/清单，apply --check再接入；原HEAD/index和并行TV改动保持。无用户凭据/偏好/NAS读取，无地址迁移或真实存储改写。

Fields只把合法http/https协议归小写后还原枚举；Scope纯比较先校验保存地址，只归一协议前缀大小写，其余主机/端口/路径大小写/尾斜杠/编码仍逐字比较。editConnection只替换早返回的地址比较，原相同账号/密码条件、rename/refresh/return及后续网络分支保留。该条件对混合scheme同址可成立，不把类型测试当真实钥匙串/多库事务验收。

macOS隔离SwiftPM复制实际Models中RemoteMediaEntry前的原文类型前缀、完整Fields及原有测试，无模型mock/网络或Vault。修前3个既有测试过，新增大小写用例捕获host错误；初结果脚本错匹配“threw error”而非XCTest实际“caught error”，解析断言失败保存，复核已完成原日志后修正分类，没有重跑凑证据。接入后既有3+新增3共6项全过：混合scheme、IPv6/字面百分号/中文路径及协议/端口/路径/大小写/编码/userinfo差异边界。

TV build-for-testing已编译当前共享库，移动配置、设备配置/Release及当前正常签名包仍待统一验证。之前56d94319/26b87a16在13/Pad的保留安装和静态窗属于前一版源码；新库改变后登记已将latest=false，不沿旧包验第五批。当前无第五批新真机/真实连接或播放结果，114格无新P。

第六批只读密码因果审查已通过Mac现有对话实际提交（用户消息可见、输入清空、Claude正在回复），未操作其权限/模式/设置。其0735报告现已交付，无源码或运行权限；Codex后续审查，不为完成通知再申请电脑控制。
