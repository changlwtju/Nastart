# 2026-10-01 20:27～20:33 iPhone 13 接续与页面保护

已读 PROGRESS、CURRENT、RUNBOOK、CLI 手册、竞品矩阵和 AGENTS；仅推进 iPhone 13，iPad 继续暂缓。按协作约定未写 PROGRESS.md，既有源码修改保留。

## 本轮包身份与设备

- 现场 usbmux 枚举 iPhone 13：名称 iPhone、型号 iPhone14,5、iOS 16.3.1、UDID `00008110-001E543122E0401E`，配对校验成功。ios-deploy 的设备枚举和安装命令此次均未输出有效回执，不能据退出 0 认定安装。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，有既有未提交修改；App 源码差异 SHA256 `e37971081d969e8001a0711fb3e5a2b53f5fdfb9b5c38c747a2561c0cafb6b1d`。最新源码/配置 07:32:05，正常 Debug `-Onone` 二进制 07:32:39，本轮未改 App 源码。
- 包路径 `~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-ipad-scroll2/Nastart-adaptive.app`；deep/strict 验签成功。主程序 SHA256 `524f6ef4600db96879313d3e280f2d7de79fb2a5efe977ad777d7ad768f3b684`，dylib `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`。
- 保存崩溃报告后，复用历史 AFC 上传与原生 installation_proxy 链路：100 文件上传完成，两个设备暂存二进制回读哈希均一致；20:30 保留数据覆盖安装获 `InstallComplete`、`Complete`、`FINAL complete=1 request_rc=0`。无变量启动成功，安装后 `verified-startup` PNG/XML 显示真实启动台。此前 `startup` 仅为安装身份未完成时的诊断，不能算最新包回归。

## 工具与观察结果

- 固定 WDA 未重装；20:28 XCTest Runner PID69548，8102 ready，固定 bundle 身份正确，截图/XML 可用。
- 本轮显式 Downloads Xcode 26.6 的预检仍为无设备、无 instruments、缺 Animation Hitches。与 19:58 成功属于不同会话，不能覆盖彼此；本轮没有 Instruments trace 或完整显示帧验收。
- 独立截图/XML 动作观察原计划启动台滚动。事后检查发现 `before.xml/png` 在第一条手势前已经是 Nastart 横屏《碟中谍3》播放器（844×390），与稍早启动台截图不同。脚本仅校验 bundle，故仍发出 5 次手势；第 6 次前因前台变为 SpringBoard 自动停止。前四次零文本位移，第五次页面转换产生9项位移，均不得归为有效滚动；整轮有效验收手势记0，结果 INSUFFICIENT。
- 没有自动化点击此影片播放的记录；页面改变原因尚未确认，不能直接归因用户或 App。已询问用户设备是否空闲，等待确认后才恢复界面操作。未主动关闭不明来源播放或继续启动竞品视频；收尾已 Ctrl-C 停止本轮 WDA 启动进程（退出130），未宣称设备播放器已退出。
- 现场 Lenna 安装查询为 `com.uvov.Lenna` /1.0.17，未读取到本轮 build，未启动竞品或取得有效配对。Debug/App Store、片源/路径/轨道/缓存条件仍未满足严格排名。

## 工具修正及验证

`scripts/ui_scroll_probe.py` 正式录制新增必填 `--page-anchor`（可重复）；首次采集、每次手势前后检查可见页面标识与 App 视口坐标。即使 bundle 不变，切页或横屏坐标越界也停止，保存动作前 XML。应使用稳定且能区分页面的标识组合，不能仅给公共 Tab 名称。

新增两个反例测试：同 App 横屏播放器拒绝竖屏手势、错误页面/隐藏标识拒绝操作。15 项工具单测通过，diff 检查通过。这是自动化保护修正，未声称 App 滚动性能改善。

原始诊断、设备包回执、截图/XML、失败与动作记录仅在权限700的 `/tmp/nastart-20261001-scroll-next/`；临时观察脚本仅为失败记录保留，缺少上述页面保护，不应原样复用。

下一步：用户确认 iPhone13 空闲后，现场重验设备与包身份，恢复 WDA，确认实际页面及稳定标识再逐页采集。Instruments 在可用会话完成显示覆盖，Lenna 按同条件配对；没有完整采样不能判滚动 PASS。所有其他 PX/UX 未验收项保留原总账状态。
