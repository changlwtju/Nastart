# 数据导出自由文本脱敏加固

日期：2026-11-01。承接[预览与TV服务批](2026-11-01-PREVIEW-FOOTER-AND-TV-SERVICE-REGRESSION.md)，iPad采图阻塞不重复重试，转独立隐私审查。NAS恢复期全部真机/NAS仍暂停；0真机发现/控制/安装、0真实凭据/用户导出读取、0NAS请求/播放/源写。未启动普通App、真实分享或模拟器，未改NAS/VPN/开发账号/profile，无Astra/定时/后台任务。

## 问题和接受实现

DataExportView原私有函数先把无空格且含点的文本当host，再复用诊断redactedDetail。合成反例证明：引号内密码含空格/逗号或转义时会残留，嵌入文字的URL会保留路径和参数；带点凭据还可能先走host摘要。旧诊断正则也可能匹配更长普通字段名的一部分。

在DiagnosticLogStore增加纯静态redactedExportText，正式导出的服务名称、提醒标题、提醒目标三处实际调用，移除View中的旧实现。完整URL沿既有redactedURL；嵌入URL去用户信息/路径/query/fragment，保留既有host摘要和端口，无法解析的URL用占位。已知凭据/路径键完整匹配；双引号/单引号值处理转义与换行，未闭合及末尾孤立反斜杠也遮蔽；无引号值保守处理到下一字段分隔符，另处理Basic/Bearer及六位配对码。

未改原redactedDetail/redactedHost/redactedURL、诊断record/exportLine/持久化及播放格式：新增方法前缀和redactedHost起至文件末尾均逐字节同。DataExportView仅三处调用与删旧辅助方法，导出schema/选择/ID/日期/设置字段和ShareLink动作不改。没有读取钥匙串或生成/分享用户数据。

这仍不是严格匿名：自由姓名/提醒文字、普通路径描述等无法完整识别，原ID/日期和host摘要仍可能关联个人。现有中英文提醒“自填内容可能含个人信息、分享前检查”保持；既有严格匿名项未关闭。普通未含已知秘密的文本及更长普通键名保留，不能把保守删减当无损备份承诺。

## 回归证据与保留失败

新增8个NonPlaybackPolicyTests方法。为避免普通测试宿主恢复账号/发NAS请求，本批未运行完整iOS宿主测试；从实际源码提取纯Foundation方法体、从实际测试文件提取同一8方法体，放本机私有临时macOS Swift package运行XCTest，无AppState/默认偏好/真实账号/网络依赖。它证明这些实际纯函数逻辑，不等同原生分享、全payload、iOS16/真机或UI验收。

最终同一8方法：旧生产函数2过6失败，新函数8过0失败。覆盖完整引号秘密/空格与分隔符/转义、单引号、Basic、带点凭据、内嵌URL、普通键边界、配对码、幂等、自由文本非匿名反例、未闭合引号/真实换行/孤立反斜杠、多Unicode URL与空值。不要把多条断言失败当作多个唯一用例，也不拿Swift Testing旁路“0 tests”覆盖实际XCTest的8条执行。

首次候选原8样本通过后，独立孤立反斜杠探针仍检出合成秘密；纳入现有未闭合用例、定向修正后最终8例再过。候选前六配置成功和早期6/8例结果分别归档，不充最终源验收。最初直接swiftc验证因XCTest模块/Swift覆盖层及XCTMain加载方式不匹配三次编译失败，未执行测试；改用原生Swift package测试发现后才形成红/绿结果。全部原始失败与源码保留。

## 构建、身份和边界

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，446输入仅DiagnosticLogStore、MineView和NonPlaybackPolicyTests三个既有文件变化，其他443个hash同；所有原有未提交修改保留。最终双端模拟器Debug及双端设备无签名Debug/Release六项exit0，当前输入和模拟器二进制/构建时间/SHA-256已记录，但0新模拟器/图/安装。原生UI不改，前批TV三窗属旧输入，不升级为本批UI回归。

手机缺开发描述文件、TV旧profile阻塞均保留，本轮未重试普通签名、未冻结新候选；旧签名包身份保持且不匹配最终源，根source-inputs/currentSourceAssessment已更新，本轮不重复核旧签名。无签名产物不能当可安装包。初始约15GiB，最终余量见[共享结果](../../../testing/results/2026-11/2026-11-01-export-text-privacy-regression.json)；沿2GiB运行保留线，无清用户缓存/资料，无自有后台构建/采集。私有指针 `current-export-text-privacy-private` 留全部命令、合成夹具、源码、包及失败；共享结果无设备ID/私有路径/凭据。

已核对播放架构、114格矩阵和唯一需求总账：播放链路/引擎/缓存/日志格式不变，无新P或需求关闭，无相关变化不制造矩阵/架构新状态。

## 接续

继续独立隐私审查：诊断自由文本正则仍沿旧实现，不把本批导出专用规则当全局日志安全修复；完整导出payload/ID日期关联/未知字段、严格匿名方案与真实分享未验。工具恢复后补Pad页脚和移动标记关联窗口、正式连接管理文案；真实保存/密码显隐/缓存显式取消/读屏及NAS播放保持开放。全部真机/NAS仍暂停。
