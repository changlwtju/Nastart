# Claude第六批：密码首次编辑与显隐焦点的只读因果审查

2026-11-02，Codex分配。第五批交付已核四文件基线/补丁及释放后接入，实际类型修前3过/1个混合scheme反例失败，修后6过；完整编译与真机随后由Codex统一执行。无需继续改第五批目录或补丁。

## 只读范围和唯一输出

读取当前集成目录 `/Users/lagransun/workspace/Nastart` 最新AGENTS、CLAUDE、协作分工/资源登记/当前交接；产品代码只读审查：

- `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift` 中连接表单、初始化/调用链、SecureField/TextField与FocusState。
- 同目录 `PasswordInputDiagnostics.swift`、`OfflineMediaScene.swift` 中相关合成编辑夹具。
- 已分享的[选区诊断](../archive/handoffs/2026-11/2026-11-02-PASSWORD-SELECTION-DIAGNOSTICS.md)及其结构化结果、文内两轮失败/撤回来源。

不读仓库外私有证据、设备偏好、钥匙串、原始输入/trace/进程或其它聊天；没有产品/测试源码写入、编译、模拟器、真机、NAS、凭据或共享进度权限。仅可在集成目录新增独有 `docs/archive/handoffs/2026-11/YYYY-MM-DD-HHMM-CLAUDE-BATCH6-PASSWORD-CAUSAL-REVIEW.md`，起止记录所读文件哈希。Codex当前TV XCTest窗口独占，不接管任何设备/缓存。

## 要回答的问题

1. 把“预填密文首次编辑替换旧值”和“显隐切换后焦点/键盘丢失”分开。当前31事件证据中，覆盖发生在显隐前；空选区、clearsOnInsertion/clearsOnBeginEditing=false不能证明所有中间事件，也不能反推UIKit内部插入原因。不要重复建议延迟聚焦或沿两轮失败方案改同类参数。
2. 源码中是否存在重置binding/State、父级身份替换、条件分支创建新控件或焦点交接？给具体调用点、适用入口及已证/未证，不把静态路径说成真实事件。区分正式表单与合成夹具。
3. 预填安全字段首次编辑的产品语义应如何验证：替换已有密码是否可能是原生安全编辑行为，而不是必须强行追加？没有原生对照或明确产品契约时不擅自下结论，也不能借此关闭键盘/数据丢失反例。
4. 给一个最小且有鉴别力的后续受控实验方案，区分空/预填、独立SecureField/当前条件Group、显隐前后、组合输入/已提交输入及有/无诊断；说明观察哪些匿名事件能排除什么原因。禁止采集原文、长度/精确选区偏移，禁止换成更容易通过的宿主来冒充原表单验收。
5. 若需新原生插入事件或桥接，列拟改完整文件、风险及必须保留的行为即可，本批不实施。未运行如实写未运行，不能靠大括号计数/已有报告冒充新运行证据。

直接完成本批报告，不用等用户反复继续；没有新因果证据也如实交“未确定”，不凑第三次猜测修复。写入完成后释放唯一报告范围，Codex在检查点读取。
