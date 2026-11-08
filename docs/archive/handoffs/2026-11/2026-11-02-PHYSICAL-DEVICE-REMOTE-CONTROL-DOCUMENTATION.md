# 真机安装与远控方法文档交接

2026-11-02。用户要求把WDA、家庭Wi-Fi无线更新/操作、13与Pad USB调试及相关方法写入项目，供Codex与Claude共同复用。

## 交付

新增[统一手册](../../../development/PHYSICAL-DEVICE-REMOTE-CONTROL.md)，按身份/认证、传输、安装、原生服务、XCTest/WDA、验收分层；逐设备说明实际方法、当前限制、故障排查及清理。同步根AGENTS、项目/脚本导航、CLI观测、播放规范、18/TV专册、日常流程、全景报告和Claude接续/可转发指令。指令只补阅读入口，本轮未发送消息、未操作Claude权限。

关键事实：

- 18无线安装不依赖WDA；11月1日Bonjour/既有配对/AFC安装和DVT前台核验有证据。10月11日另有userspace CoreDeviceProxy/RSD→testmanagerd→真实XCTest→WDA HTTP完整恢复记录，旧profile/会话不可沿用。
- 13 USB原生进程/截图与WDA触控分开。11月2日实际安装是ios-deploy USB/nostart，pymobiledevice3安装代理负责读取已装信息，不能误写为该批安装服务。
- 新A16 Pad的CoreDevice安装/原生RSD取图已用；旧Pad过期/不覆盖A16的WDA不能用来声称新Pad触控已恢复。
- TV历史CoreDevice/原生RSD、独立tvOS安装及TV XCTest/WDA遥控成立；当前开发会话与有效profile仍阻塞。TV遥控验收优先XCUIScreen，DVT截图干扰对照不能扩大成所有失败的已证根因。
- 记录精确识别后原生退出授权、源码/签名/保留数据安装、偏好保护、会话副作用、设备/端口独占、蜂窝恢复和私有证据边界。

## 验证与未改变的现场

本轮只读本机历史、脚本与临时适配器的必要实现，未执行设备枚举、探测、安装、启动、Runner/会话创建、NAS/媒体请求或新构建。浏览上游WDA说明与Apple接口入口仅用于原理参考，不作为本机兼容性验证。

写文档前冻结832个非Markdown项目文件的本机摘要及git index身份，用于结束检查；这不是新的446项构建清单或包验签。文档检查与文件保持结果在本记录验证补记，不重复跑产品测试。

需求总账、播放链路与114格矩阵已核本批无实现/验收变化，不制造编号或新P。NAS暂停、18 hands off、TV阻塞、当前移动包早于第五批及新正常包待办保持。登记只增加手册入口和本批文档属性，不取得设备/构建/产品写入窗口。

下一步仍按当前接续：Claude交密码下一实施批完整方案；Codex支持同源工作区、范围登记、当前正常包及获窗后的13/Pad安全回归。需要输入时先解决相应Runner能力，不用静态截图冒充完整交互。

验证补记：`python3 scripts/check_documentation.py`检查618份文档、3862条本地链接，0缺失；`git diff --check`通过。开工快照的832个非Markdown项目文件全部未变，HEAD与git index SHA-256未变；没有执行产品测试或真机检查。
