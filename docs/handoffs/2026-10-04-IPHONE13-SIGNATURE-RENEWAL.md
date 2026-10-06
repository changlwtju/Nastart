# iPhone 13 WDA / Nastart 续签（2026-10-04）

用户明确要求两包续签。开工读取进度与当前播放交接、播放runbook，现场重新核对USB iPhone13（iPhone14,5）/iOS16.3.1（20D67），配对成功，同一目标设备。原始身份、偏好与签名材料只保存在本机私有目录：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-04-renew-060251`。

## 构建与安装身份

源码HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`；已有未提交修改保留，开工快照在私有source-dirty.txt，App源码最新修改时间2026-10-02 07:33:02。本轮未改变App源码。使用现有Nastart工作区、Automatic签名Team 5436TB5498、正常Debug/-Onone构建，CLI allowProvisioningUpdates申请新profile，BUILD SUCCEEDED，无App测试环境变量。

- Nastart包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-04-renew-060251/Nastart-renewed.app`，构建完成记录06:04:29，覆盖安装成功06:06:50。
- 主二进制SHA-256：`b2a72e80bcdcf421bd8d1e174621f5ac7a69ae42f85aca78b0b88d8d6b92b6fa`。
- Debug dylib SHA-256：`6ab6193fa8c9a1f70ee820bb8e9524405a3dbb7f4052bc96db19f19492a2400c`。
- 新profile UUID `dd88270d-5c73-4aa5-bfad-c395dfba5ced`，北京时间2026-10-11 06:03:15到期。

WDA复用持久化历史兼容fixture代码与xctestrun，宿主`com.changliwen.nastart.WebDriverAgentRunner.xctrunner`、test `com.changliwen.nastart.WebDriverAgentRunner`及Team保持。私有最小签名申请工程仅用于向Xcode请求原宿主ID的profile，其生成的占位App没有安装；使用新profile与有效证书重新签名实际WDA所有嵌套库/框架/test和宿主（12个嵌套签名检查）。旧fixture有本机备份，续签fixture与安装receipt已更新。

- WDA包：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-04-renew-060251/WebDriverAgentRunner-Runner.app`，覆盖安装成功06:06:54。
- Runner SHA-256：`8f1ec108c03c4836136edbabdd27af5af1949112540abf4e4b9f97988b9de852`。
- Test SHA-256：`9b039e21f941a1075c7e97a3b7269a9604e4717db4c6828fae0ae0ff0a7e4eb3`。
- 新profile UUID `c63383c3-0922-40fa-a494-22b3f9458cb0`，北京时间2026-10-11 06:05:26到期。

两包均签名deep/strict通过，Nastart三个dylib独立签名与播放链接隔离通过。手机实际复制的新profile逐字节与所安装包embedded.mobileprovision一致，两installed appinfo ProfileValidated=true；期限依据实际profile，不仅版本号。安装方式ios-deploy保留数据覆盖，无卸载/清除登录。最初tidevice直接install .app被本地格式校验拒绝，尚未触及设备，随后用历史成功ios-deploy方式完成。

## 启动与独立授权门槛

安装前House Arrest诊断保存成功。Nastart正常无变量启动PID93033，设备进程枚举和原生截图显示真实启动台；安装前后25项非诊断偏好逐项一致，不公开其键名或值。初始启动截图并非播放回归，顶部仍有手机切换控制找不到外部切换警告；不恢复用户放弃的方法。

WDA preflight通过，06:08:16 XCTest `Test runner ready detected` / `Start execute test plan`，手机实时截图为新XCTest密码页（四个空圆点、数字键盘）。HTTP未就绪，仍需设备本机授权；签名/安装成功不等于自动化可用。没有输入密码、更改手机认证设置或执行新播放/滚动/竞品回归。

修正prepare_wda_recovery.sh与install_wda_iphone_once.sh默认PROFILE，直接读取当前WDA包embedded.mobileprovision，避免旧固定UUID文件与当前包身份/期限不一致；保留此前脚本其他未提交修改，zsh语法检查与实际preflight通过。

后续先在现场完成手机授权，再验WDA HTTP/session/source/screenshot；真机回归重新核对本轮最新正常包，不把旧af8dd6…结果当作本轮6ab619…包结果。继续原Jellyfin大文件、完整帧时间滚动及Lenna竞品待验项。

收尾2026-10-04 06:11：WDA有界90次等待后exit1，本轮Mac runner/iproxy自动清理；设备全进程复核未见WDA Runner，Nastart PID93033仍在，8102 HTTP exit7。提示仅留屏，不当作运行服务。两包续签安装任务完成，原UI调试授权仍受阻。
