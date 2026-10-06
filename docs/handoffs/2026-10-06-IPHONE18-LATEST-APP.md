# iPhone18 最新 App 保留数据安装续记

更新时间：2026-10-06 15:31。用户打断播放排查，要求先把最新App安装至刚接入的iPhone18。本轮先完成此任务，未修改iOS源码，未重新安装WDA。

现场USB及CoreDevice重核目标iPhone18 Pro Max / iPhone19,7 / iOS27.0，名称iPhone；唯一对应目标、UDID、设备安装路径与原始prefs仅留本机私有证据。设备已开机解锁、安装元数据ProfileValidated=true。

最新源码HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，iOS dirty diff SHA-256 `7e0d01463a1d46dd707a4a8ef4eee91ac14cffe0cdd19a9ae18f8c36de7f5818`；冻结普通Debug -Onone包构建于 2026-10-06T14:40:13.345075+08:00，与iPhone13/iPad最近包为同一产物。源码及每个记录二进制SHA-256现场一致、deep/strict签名通过、profile包含刚接入目标且未过期。

- 主二进制 `e8557a219dc5e6652be1f8db4472935da318e77d7e97be09343d8238127584ad`。
- Debug dylib `38ce74a40ed758cec897f4505c52fc584cb37deff189caff50d01e61d2291d05`。
- KSPlayer `c2f1a42bcad0e5c30d0bcebd24576f92d8475c201589ed1f9655cc637d6e7910`。
- App profile UTC 2026-10-10T22:03:15（北京时间10月11日06:03:15）。未续签或新建签名身份。

安装前保存旧诊断与偏好，然后CoreDevice保留数据覆盖安装成功；25项非诊断偏好安装前后全部一致，没有卸载/清登录。版本仍0.1.0/1，但资格依据自己的覆盖安装receipt与指定包哈希，不能靠版本号或能启动判断更新。

启动验证的两次CLI参数错误发生于设备启动请求发送前：空环境JSON参数被拒，以及安装返回的可选persistent identifier不被当前launch命令接受。错误原样私有保留；随后移除这两个可选参数、清掉调用环境DEVICECTL_CHILD_前缀变量，以普通Bundle ID/无参数启动成功并返回进程。再次独立CoreDevice进程清单核对同PID，启动后约 69.797 秒仍运行；启动后25项非诊断偏好也全部一致。没有把这两次命令行失败记成App启动失败。

原生USB截图不可用，留TOOL；本轮正常启动证据为系统launch成功和实际进程持续存在，**没有自动核验实际前台UI截图/播放/性能**。WDA原安装保持，未建立iPhone18新XCTest会话，不宣称其当前runtime ready或免再次授权。

本轮iPhone13旧WDA session返回404，既有宿主ready；一次no-launch session恢复后重新核实最新正常启动台，无Runner重启/安装。iPad既有宿主/最新普通启动台也已重核。本轮未开始新播放采样，原画/HLS首段等待与取消、健康预测边界、精确字幕cue/控制退出、Lenna及DS One Jellyfin/DSM CB01–26正式配对和全部PX/UX缺口仍待完成，正式有效配对0。iPhone18此前离线旧d84f状态被此次自己的e855最新包安装替代；不能将安装视为跨设备回归通过。

详见[安装量化记录](../testing/IPHONE18-LATEST-APP-20261006.json)；继续播放工作读取[上一轮供流交接](2026-10-06-IPHONE13-IPAD-UPSTREAM-LOADING.md)。原始凭据、设备标识、安装/启动日志和偏好仅保留本机私有目录。
