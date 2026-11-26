# 2026-11-12 iPhone 13 WDA 开发通道恢复

Codex 执行，时间为北京时间。接续 [T2 蜂窝与登录](CODEX-2026-11-12-PLAYBACK-POLICY-T2.md)。

- 04:26 fresh USB 核对 iPhone 13（iPhone14,5 / iOS 16.3.1，20D67）、既有配对和当前 Nastart 安装回执。Nastart 为 T0 签名 Debug `8025285b…`，Runner 为本批已验证的 iOS 16 兼容包 `f6c6980e…`，profile 至 11-16 19:51:31，未覆盖任何 App。
- 原生日志证实，设备 `DTServiceHub` PID 9304 收到连接后报告 `Failed to create output kqueue(): 24`，接着断开 DTX socket。24 对应 `EMFILE`，创建队列所需文件描述符耗尽。Runner 因此在 XCTest 就绪前失败；既有 USB 配对及截图服务仍可用。耗尽的触发条件未查明。
- 04:28 对当前开发镜像作有界恢复。已核现装镜像签名与本机 iPhone14,5/16.3.1 (20D67) 镜像签名逐字节一致，DMG SHA-256 `cc76842f3bc22260ef46f3c0ef3e23d2c84c59f5eca5f10b077b8fb65aa08cde`，`hdiutil verify` 成功。卸载并重新挂载同一开发镜像均完成，最终签名相同。
- 重挂后 04:28:55 仍是同一 PID 9304，重复报 `kqueue(): 24`。CoreDevice 精确目标的进程查询返回 `com.apple.dt.CoreDeviceError 1000`，无法通过此通道操作该设备进程。WDA `/status` 未达到 ready；重装签名 Runner不解决该前置错误。
- 本窗无媒体或登录提交，原 Wi-Fi 仍在。已停本批的临时采集和转发。下一步需重新启动设备以重建开发服务，已请用户决定重启方式；开机首次解锁后复核 App 身份、Wi-Fi、DVT、Runner ready 和实际输入，再按已有授权处理 Jellyfin 登录。
- 私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `phone/wda-recovery/`；旧 USB 报错原文另见 `phone/t2-reauth/dvt-debug-usb-private.log`。

## 已执行用户批准的单次重启

- 04:33:18 发出一次 iPhone 13 重启命令，工具返回 0。发出前重新核对 USB UDID、型号、iOS 与既有配对，并保留 Nastart 诊断。04:33:32 目标从 USB 列表消失，04:33:52 同一目标重新出现。开机后复核 iPhone14,5 / iOS 16.3.1 / 20D67。
- 开机后开发镜像查询返回 0 个签名。已告知用户完成首次解锁。解锁后检查现装 App/Runner，必要时挂载已核验的同一开发镜像，然后核实 DVT 握手、XCTest Runner ready 和实际操作。此阶段尚无 WDA 或 Jellyfin 登录结果。

## 解锁后恢复结果

- 04:37 核同一设备和 T0 安装路径，源输入及当前签名包一致。挂载原签名开发镜像，USB DVT 重新能列进程。首次 Runner 预检因已有 Nastart 和 Runner 进程中止；原生实图为主屏幕，原 Wi-Fi 图标可见。核既有 Runner 无 HTTP 会话、无自有或其他可见测试转发，保存偏好和诊断后，04:42:18 按已确认 bundle 可执行路径、启动时间和 PID 精确结束两个闲置进程。
- 复用现装签名 Runner，XCTest、8161 和 `ready=true` 成立。空参数、空环境启动 Nastart，以原生元素点击进入 Jellyfin 资源库，旧会话仍返回 401。在用户授权下使用历史明确提供的对应账号，安全输入框提交一次。诊断记录 `login_succeeded`、`library_loaded`、`serverIDRecorded httpStatus=200`，实际 UI 可见资源库搜索，登录表单消失。
- WDA 恢复和 Wi-Fi 登录通过，成功会话为内网端点。随后在实际 T2 蜂窝窗验证了恢复后的 WDA 切网和操作能力。04:45:31 普通测试通道收尾，原 Wi-Fi 连接勾选与状态栏图标双核，App、Runner 和转发归零。私有证据见同批目录下 `phone/wda-post-restart/`。
