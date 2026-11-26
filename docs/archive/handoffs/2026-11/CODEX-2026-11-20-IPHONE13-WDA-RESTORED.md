# 2026-11-20 iPhone 13 WDA 恢复与实际输入验证

用户要求继续恢复 iPhone 13 WDA。Codex 于北京时间 11:26–11:30 执行，仅占 iPhone 13 USB、现装 Runner 和本机回环端口 8168；iPad、iPhone 18、NAS 与网络设置未操作。

## 身份与包

- 当前 USB 枚举后，通过既有配对 fresh 核对名称 iPhone、iPhone14,5 / iOS 16.3.1 (20D67)，完整 UDID 与今早安装回执相同，原始身份仅私存。
- HEAD `8db1cc6491c6e8bce2bc8b41f57e6112142132ba`，当前含未提交修改的 647 个源码输入、iOS diff 与 11-19 07:30:40 完成的正常 Debug 构建一致。当前源码不需重建。包路径、源码清单和 dirty 状态保留在私有证据；主程序 SHA-256 `130f56265e98d719a185ce153881d934003241d21929f9558f47c981bf073604`、Debug dylib `3929988635e08cecf4a02d4224cee7149f7857f5ac7f0910f8222fed4bd52635`、IPA `a9453b76ceb7aae94f944be8f862f6b639b27f2b9ec50fe28242350f55247f8e`。
- App、30 个嵌入库、IPA 成员与 CRC、有效描述文件及设备覆盖重新通过；Runner deep/strict 签名和目标覆盖通过。Runner 主程序 `04be22094132981816ef4e25c6f5b0ca490f984c4c997a455075e5e4775d510a`，有效期至北京时间 11-27 07:27:12，App 至 07:27:01。
- fresh installation_proxy lookup 的 App/Runner 实际安装路径与今早各自安装回执相同，均 `ProfileValidated=true`。本窗没有安装、重签、换账号、卸载或清数据。

## 实际恢复

上一会话的 usbmuxd/回环 `EPERM` 是历史阻塞。本轮 USB 枚举和后续有界设备操作获交互审批后实际成功；普通沙箱命令仍不能据此认定全局权限已解除。

备份当前 App 偏好并保存进程现场后，确认没有现有 Runner、tidevice、iproxy 或 XCTest 占用本窗口。Nastart 原已存在 PID 7667，本轮不接管其生命周期，不启动或结束该进程。

复用现装兼容 Runner，经 `tidevice xcuitest` 启动 PID 7925，`iproxy` 仅监听 `127.0.0.1:8168` 转 USB 8100。11:28:03 收到 `/status ready=true`，返回项目 Runner bundle。创建不指定被测 App 的会话，不请求 App 启动，不注入 Nastart 测试环境。实际前台为 SpringBoard PID 32；WDA PNG 已查看，状态栏可见 Wi-Fi。

第一轮控件精确名称 `NAS 视频` 没有匹配，未派发输入。读取当前 AX 后确认实际名称为 `NAS视频`，唯一、可见且启用的文件夹图标。重新查询并核前台/PID/方向，在约 0.385 秒观察年龄内单次元素点击；实际 PNG 显示该文件夹已打开。随后单次 Home 按钮关闭文件夹，实际 PNG 显示原主屏幕与 Wi-Fi 图标。没有启动文件夹内任何 App。两张结果图均已人工视读；WDA 实际输入验证通过，不只是 HTTP 成功。

## 收尾与边界

WDA 会话删除完成，终止本轮 Mac 子进程后，首次原生收尾连接发生 `BrokenPipeError`，保留完整失败日志，没有因此判 App 崩溃或重复输入。使用 fresh USB 连接重新核实：Runner 已退出，无需再发送终止；本机该设备的 tidevice/iproxy 不存在，8168 无监听。原有 Nastart PID 7667 保持。最终全部偏好与测试前相等，29 个非诊断键值无变化。11:30:54 窗口关闭并释放。

本轮恢复 WDA ready、会话、取图、元素点击与 Home 输入能力；未做 Nastart 前台、Jellyfin 读库、播放、蜂窝或性能验收。唯一需求总账与播放矩阵已核，没有新播放证据，不改验收状态。下一播放窗口仍须 fresh 核设备/源包/独占，再复用现装 Runner；按当前交接先做原 Wi-Fi 正常冷启动与 Jellyfin 读库，再补原有蜂窝播放待验项。

同日上午桌面会话接续核对：647 个冻结输入、HEAD、iOS diff、App 与 Runner 本地二进制仍与回执匹配。桌面会话的 USB 与回环连接仍返回 `EPERM`，可审批会话中的恢复结论成立，桌面会话未另开真机窗。冷启动读库复测需同时查看同窗实际资源库页面、`library_loaded stage=views/completed`、分区加载告警和主入口响应。当前源码中分区加载失败可与 `stage=completed` 并存，公网备用探测状态也须单列。旧 11-14 的读库和登录结果不计入这一版本。

私有证据：`/tmp/nastart-iphone13-wda-resume-20261120/`。包含脚本、身份、lookup、源码状态、偏好、原始 HTTP/AX/PNG、启动与失败日志；不提交原始资料。脱敏结果见 [结构化结果](../../../testing/results/2026-11/CODEX-IPHONE13-WDA-RESTORED-20261120.json)。
