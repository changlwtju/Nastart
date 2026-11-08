# 双工具分工落盘与 Apple TV 历史连接核对

更新：2026-11-01T20:31:03.324003+08:00（Asia/Shanghai）。用户要求查TV历史、确认两套Xcode职责，并将Codex/Claude Code的文件、设备与环境分工写入项目。[结构化结果](../../../testing/results/2026-11/2026-11-01-AGENT-COLLABORATION-AND-TV-HISTORY.json)，[协作分工](../../../development/CODEX-CLAUDE-COLLABORATION.md)。无产品/测试源码变更，446接受输入逐项仍匹配前批；无新构建/安装/播放/手机操作或NAS命令。

## TV发现与验证码窗口

用户照片和后续文字明确已到电视遥控App与设备页，Mac条目可见；用户报告两端Wi-Fi同路由器。先前按服务名未命中客厅不能推开发广播缺失：本轮解析6个当前服务实例，1个remotepairing与1个mobdev均和客厅AirPlay解析到同一主机，型号广告AppleTV14,1、当前IPv4路由en0。名称/主机一致仍不等于硬件认证；地址/TXT/原图均仅本机私有。

Device Hub附近配对AppleTV列表首轮空，后续关闭读菜单并在已知广播后重新进入，实际出现客厅。选择该实有行→Next出现六个空验证码框；已请用户直接在Mac输入而不发送验证码。没有读取、输入、记录验证码或提交认证。用户表示两个Xcode项目都没看到弹窗，已定位独立DeviceHub路径并Raise；最新观察窗口已消失、仍Currently Unavailable。不能继续声称旧弹窗当前仍在，不能将发现/Next写成完成配对。后续明确单一窗口再恢复，不反复让用户找已消失的输入框；不自动移除旧配对/重置网络。

## 两套Xcode与历史实际路线

mdfind/运行进程及逐子命令DEVELOPER_DIR核定：/Applications/Xcode.app为27.0/27A266a，~/Downloads/Xcode.app为26.6/17F113；全局选择27。单看/Applications会漏Downloads这一套，不能据此说只装一套。两版都在运行，不据运行并存断言根因。

[TV准备文档](../../../development/APPLE-TV-PREPARATION.md)已补历史实际链：CoreDevice fresh身份→本机原生RSD隧道身份→HouseArrest备份→devicectl保留数据覆盖→DVT诊断→需要时独立XCTest/WDA控制。10月24日Xcode27签名/安装、10月26日真实覆盖/页面以及28日至29日安装/原生清理证据均在；10月19日类似Mac条目存在但开发接入未就绪的失败也保留。**历史脚本含普通App/NAS启动，现在不直接重放。**

26.6仍被13的历史Instruments/持久WDA配置引用；27用于当前主构建/DeviceHub。暂保留两套，以后先迁移验证旧设备路线再讨论删除；未关闭用户Xcode、未卸载/删缓存或改全局xcode-select。用户报告缓存清理，不能确定具体清理内容或其因果；正常TV签名缺profile、旧profile已于10月31日05:46:14UTC到期仍是独立确认的阻塞。没有向Apple重新注册/签发/下载profile或改开发账号。

## 协作已准备的内容及未执行边界

用户要求的分工文件已建，根CLAUDE.md引导Claude读取AGENTS/分工/进度/交接/资源登记；AGENTS增加并行协作入口及共享摘要单写者规则。Codex统一集成/设备/构建调度，Claude首批可立即只读当前源码做离线UI/可访问性审查，只写独有月度报告；后续明确文件与同源独立工作区后可实施代码，非永久限制只做审查。

同一设备、Runner/会话/采集/安装窗口独占；不同worktree不隔离设备/端口/服务/缓存。当前重构建默认串行，模拟器各自创建/清理，共享依赖更新互斥；未来Pad/18需现场加入后分配。文件申领/交付/集成、初始dirty基线保护和NAS暂停均写明。资源登记为人工遵守的约定，不是实现了自动锁；超时不自动抢占。

尚未启动/联系Claude、未消耗其会员任务、未准备Claude实施worktree、未提交/推送现有dirty或自动交换上下文。只读首批允许从当前集成目录审查；不能直接从HEAD漏掉已接受未提交代码。共享总进度由Codex写，Claude交本方报告，避免互相覆盖。

唯一需求总账/播放矩阵已核，无产品/播放实现变动，不新增验收P或关闭旧编号。NAS继续暂停，TV未安装当前包，13保留前批正常8dbd/dd0b与已停止两窗结果。当前无自有App/Runner/采集、重构建或定时任务；Device Hub系统窗口不等于测试后台任务。
