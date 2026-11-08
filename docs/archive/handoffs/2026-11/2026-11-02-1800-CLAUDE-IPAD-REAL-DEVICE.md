# Claude（本地会话）：全量构建 + iPad A16 真机离线场景回归

2026-11-02 18:00（Asia/Shanghai）。用户在本会话明确授权：基于连在 MacBook 上的 iPhone 13、iPad 做真机调试，Apple TV 以后再开。NAS 仍暂停：本批没有访问 NAS、没有局域网发现，没有普通启动，iPhone 18 未触碰。

## 全量构建（六配置）

- 源码 = 主目录当前含 dirty 的基线 + 本会话改动：
  - local-library 场景；
  - 海报卡裁切；
  - 详情灰带；
  - “正在读取文件夹”文案；
  - 测试横幅。
- 构建方式：用户同意借用 Codex 已闲置的 `DerivedData/Nastart-Codex-SavedPassword-20261102/{mobile,tv}` 做增量构建，参数与 Codex 六配置一致（无签名）。
- 结果：iOS / tvOS × 模拟器 Debug、真机 Debug、真机 Release **六项全部 BUILD SUCCEEDED**。
- Release 检查：iOS Release 包中没有 `local-library` 和 `private-host-1.example.invalid-library.banner`，Debug 包中有；产品文案“正在读取文件夹”两者都有，符合预期。

## iPad A16 真机

| 项 | 结果 |
| --- | --- |
| fresh 身份 | 常立文的iPad，iPad15,7，iPadOS 26.6（23G71），有线，开发者模式已开 |
| 原已装包 | `Nastart-Latest-Normal-Debug.app`（Codex 早上的旧包）。核对时**正在运行**（PID 11439，路径与已装包一致，来源未知，可能是用户打开的） |
| 停止前现场 | 备份 `Library/Preferences/com.changliwen.nastart.plist`（哈希存私有证据）；复核同 PID 同路径后结束 |
| 新包 | 签名真机 Debug，项目既有自动签名 + 本机已装描述文件，未请求新描述文件；深度严格验签通过；描述文件 2026-11-08 到期，覆盖本机。主程序 `ae6953a0…3e27`，debug.dylib `d2aaa25f…89b1` |
| 安装 | `devicectl device install app` 保留数据覆盖安装，新路径 `…/6D1755F0-…/Nastart.app`；安装后偏好与安装前逐字节一致 |
| 启动方式 | 只用 `--offline-ui <场景> --offline-ui-text-size standard\|large`，没有普通启动 |
| 截图 | 14 个场景 × 2 字号 = 28 张，用 `devicectl device capture screenshot` 截取 |
| 收尾 | 结束本批最后启动的自有进程（PID 11737，路径已核）；收尾偏好与最初一致 |

覆盖场景：`library`、`missing`、`detail`、`detail-long`、`credits`、`episodes`、`connections`、`folder-picker`、`connection-edit`、`settings`、`privacy`、`privacy-cache`、`theme-gallery`、`help-detail`。

### 真机观察
- 没有发现真机特有问题。
- 海报墙标准字号每行 4 张、大字号每行 2 张（iPhone 大字号是单列）。
- 详情、剧集、演职人员、设置、隐私、主题页在两种字号下排版正常。
- 与模拟器一致的旧问题：清缓存确认是弹出框并盖住标题（UI 清单 #7）。
- 新的轻微观察：iPad 竖屏帮助、设置等纯文字页行宽铺满约 800pt，长段落偏长。

### 未执行 / 阻塞
- **iPhone 13**：已在下一节补做。
- **触控交互**：新 iPad 的 WDA 尚未准备，本批只有启动参数 + 截图，没有点按、滚动和返回保位实测。
- **本机假媒体库**：只监听 Mac 的 127.0.0.1，真机访问不到，所以 `local-library` 没在真机测。
- **Apple TV**：未处理，开发配对和描述文件阻塞仍在。

## 需要 Codex 同步

- 资源登记里 iPad 的已装包应改为本批签名包，`latestPackageForCurrentSourceVerified` 对本会话源码成立。
- Codex 的 `mobile`/`tv` 产物目录已被本批覆盖。
- 本批由用户直接授权 Claude 操作 iPad，已结束并释放，无遗留进程。

证据（仓库外）：
- `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-device/`
- `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/ipad-real/`
- `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-locallib/six/`

## iPhone 13 真机（18:30 补做，用户已解锁并信任）

| 项 | 结果 |
| --- | --- |
| fresh 身份 | 新版 CoreDevice 仍只列 ECID，按手册改走 USB/usbmux：名称 iPhone，iPhone14,5，iOS 16.3.1（20D67），`idevicepair validate` 成功 |
| 签名覆盖 | 同一签名包，描述文件包含这台手机 |
| 原已装包 | `Nastart-Latest-Normal-Debug.app` **正在运行**（PID 52261，07:27 启动，路径与已装包一致） |
| 停止前现场 | `ios-deploy --download` 备份 `Library/Preferences`；DVT 进程列表复核同 PID 同路径后用 DVT kill 结束 |
| 安装 | `ios-deploy --id <UDID> --no-wifi --nostart --bundle`，无卸载/清数据选项，InstallComplete；安装后偏好与安装前逐字节一致 |
| 启动与截图 | pymobiledevice3 DVT `launch "com.changliwen.nastart --offline-ui <场景> --offline-ui-text-size <字号>"`。先单独试一次，截图确认是离线页面后才批量执行；同 14 场景 × 2 字号 = 28 张，DVT screenshot |
| 收尾 | 结束本批自有进程（PID 56680，新包路径）；无旧包进程；收尾偏好与最初一致 |

### iPhone 13 观察
- 14 个场景两种字号排版正常，与模拟器一致。
- **系统版本差异**：清缓存确认在 iOS 16 上是底部操作表，带“取消”，显示正常；在 iOS 26/27 上是盖住标题的弹出框。UI 清单 #7 只在新系统上成立。
- **屏幕左侧固定位置有一条绿色横条**：所有截图里位置都相同，不随页面和字号变化，判断为手机上的系统级浮层，不是 Nastart 画的。用户确认在手机上肉眼可见；退出 Nastart 后在主屏幕同一位置复拍仍在，已确认与 App 无关。来源未知（可能是某项辅助功能的焦点框），不属于本项目、不改系统设置，未处理。
- 工具：`/Users/lagransun/Library/Application Support/Nastart/Tools/pymobiledevice3-11.1.0-py314`（已有）、`/opt/homebrew/bin/ios-deploy`、`idevice*`。本批未使用 WDA。

证据：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/iphone13-real/`，进程/安装/偏好在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-device/`。资源登记里 iPhone 13 的已装包同样需由 Codex 更新为本批签名包。
