# 2026-11-20 Jellyfin 401：重复设备 ID 与当前播放窗口

用户先要求继续播放调试，随后要求解释为什么 Jellyfin 反复返回 401。本批由 Codex 串行执行，无产品源码变更、重签、安装、重新登录、Keychain 读取或 NAS 配置改动。原始身份、偏好、地址与日志仅保留本机私有证据。

## 新确认的关键缺陷

读取本机既有安装后偏好备份，按各目录独立的设备身份记录核对：iPhone 13 为 iPhone14,5 / iOS 16.3.1，iPhone 18 Pro Max 为 iPhone19,7 / iOS 27.0，完整物理 UDID 不同，但两者的 `jellyfin.client.device-id` **完全相同**。A16 iPad 的该值不同。13 的备份时间为北京时间 11-20 07:33:25，18 为 00:21:14；13 在本窗 11:40 的 fresh 偏好仍是同一值。18 本窗没有连接、控制或 fresh 读取，不能把其备份当作 12 点实时设备检查。

这是直接比较偏好字段得到的事实，不是根据通用设备名 `iPhone`、App 版本或主程序 UUID 推断。原值及用于区分设备的完整 UDID 不进入共享文档。没有读取任何 Jellyfin 真实令牌或密码。

Jellyfin 10.11.11 `SessionManager.GetAuthorizationToken` 按 `DeviceId + UserId` 查旧设备记录，先 `Logout` 再签发令牌。因而在同服务器同账号下，两台报相同设备 ID 的手机重新登录会竞争同一个身份，后一次登录会使另一份旧令牌失效。服务器源码见 [固定版本实现](https://github.com/jellyfin/jellyfin/blob/v10.11.11/Emby.Server.Implementations/Session/SessionManager.cs#L1516-L1542)。这解释了即使不换包也可能反复掉登录，不能把每次重新输入密码成功当成修复。

当前客户端 `LaunchpadView.persistentDeviceID()` 无条件信任已有偏好值，没有本机归属标记、迁移检测或重复身份隔离；`DevicesView` 的 Jellyfin 匹配客户端也复用这个值。另有独立问题：会话按 endpoint 保存，同一设备经另一地址重登后，旧地址可能仍留着已撤销令牌。11-14 的修正只增加有可用替代会话时的恢复，并未处理跨设备重复 ID 或统一登录发布。

**边界：** 已确认重复 ID 和服务器的冲突机制；没有取得 11-20 服务端同窗令牌签发/撤销记录，故尚不能指认究竟哪次操作撤销了今天 13 使用的令牌，也不能声称所有历史 401 都由此导致。ID 最初如何变成相同仍未知。当前 iCloud 正常导出键清单不含这个 key，不能无证据归因 iCloud、覆盖安装、账号改名或代理。旧服务端证据见 [11-14 日志关联](CODEX-2026-11-14-JELLYFIN-SERVER-401.md)。尝试定位既有 DSM 浏览器取证通道时，浏览器访问不可用，原生 Safari 获取又以 continuation 错误失败；没有更改浏览器、NAS 或账户设置，也未重试登录来制造新令牌轮换。

## 今天的 401 窗口

11:40 fresh 核 iPhone 13 USB、现有配对、当前源包/签名与安装回执；HEAD `8db1cc64`、178 个 dirty 路径、647 个冻结输入一致。普通 Xcode 27.2 Debug 构建完成于 11-19 07:30:40；当前主程序 `130f5626…`、Debug dylib `39299886…`、Runner `04be2209…`，完整哈希及包路径沿用 [安装记录](CODEX-2026-11-20-IPHONE13-USB-APP-WDA-INSTALL.md) 私有 manifest。App 与 30 个嵌入库、Runner 的签名、目标覆盖及 IPA CRC 重新通过；App 和 Runner 安装路径各自匹配今早回执且 ProfileValidated=true，无重装。

11:42:46 保存现场后精确结束旧 Nastart，空参数、空测试环境冷启动 PID 7971；实际图显示正常启动台和 Wi-Fi。11:45:19 打开媒体资源库，日志候选中只有公网 HTTPS root 保存会话被选中，内网候选没有保存会话。实际服务器同一性检查成功，但 `storedLibraryRecovery=noSavedLANSession`、`crossEndpointRestore=noMatchingReplacement`，随即 `library_failed httpStatus=401 transport=https` 与 `session_rejected stage=library`。实际图是预填用户名的登录页、空密码和“登录已失效”，本窗没有提交用户名密码、没有 login_failed 或 login_succeeded。它是保存令牌的读库失败，不能称密码输入错误或内网主库加载成功。

## 独立设备文件播放与收尾

Jellyfin 被阻塞后，原 Wi-Fi 下通过设备文件只读进入 S19《护戒使者》MKV（128,795,641,934 bytes），11:56:38 点击继续观看。trace `3F9EE268` / plan `CBFDE353` 为 DSM File Station 原流、localRangeProxy、KSPlayer，计划起点 67.092 秒，内部首帧 6,285 ms、位置 67.209 秒。3 秒图黑屏加载；10 秒图有真实电影画面，同时显示缓冲与 1.7 MB/s。两图均已视读。轨道保存边界为音轨 2 / PGS 9；没有实际字幕或声音验收。

采样控制进程在会话环境切换期间丢失，0/3/10 秒图存在，30 秒图、完整 timing 与采样 finally 记录缺失。日志后来有 close/viewDisappear/playback_ended，但没有可归属的按钮动作和返回页图，不判普通退出通过。上层 20 分钟独立守卫仍执行：12:00:59 删除 WDA 会话，核 App/Runner 均退出，Mac 自有子进程停止，未遗留转发。没有进行蜂窝测试或切网。本窗不是完整 30 秒或持续流畅度验收。

12:10:51 fresh USB 再核 App/Runner 均不在、8168 无监听。测试临时将文件排序从修改时间降序改为名称降序；App 停止后备份最新偏好，仅恢复本轮排序 key，并逐字段核其它当前值不变、排序恢复修改时间降序。与开工非诊断偏好相比仅合法播放进度 `playback.localResume.v1` 有变化；不覆盖新进度或还原整份旧偏好。

原始诊断按正确导出格式重建后离线工具解析 400 条事件、1 条当前 trace。首次私有转换缺少导出格式导致解析 0 条，已纠正，不当作无事件或测试通过。路线复算没有 `routeCapacityEvidence`，不能据 0 to check 判路线规则通过。

## 下一实施批完整范围方案（尚未改产品）

1. 为 Jellyfin 设备身份设置单一本机归属策略，覆盖从其它手机备份迁入旧偏好的情形；所有 Jellyfin 客户端统一使用。普通同机覆盖升级保持稳定。归属暂不可读时不反复生成新 ID。不读取/删除真实凭据，不调用远端 signOut 撤销另一台会话。
2. 对同服务器同账号的内外网登录发布和恢复作整体核对，避免一处新登录后其它 endpoint 留旧令牌；服务器/账号必须独立，验证后才能更新绑定。仅修设备 ID 不能替代此项。
3. 候选产品范围：`Core/Stores` 中的共享身份/会话策略、`Features/Launchpad/LaunchpadView.swift`、`Features/Devices/DevicesView.swift`、`PlaybackNextCoreTests.swift`；实施前按当前含 dirty 的源建立独立目录和逐文件登记，再补身份迁移、同机升级稳定、跨设备隔离与地址切换回归。不能续用旧批授权文件表。18 仍 hands off，未经新窗口不为复现而让它重登。
4. 用假令牌和服务端规则夹具先验两台设备不互踢，再在获准设备以同账号不同设备 ID 做串行对照。真实令牌已失效时仍需一次正常登录；重复掉线原因修正前，不把重登当作长期解决。

结构化结果见 [本批结果](../../../testing/results/2026-11/CODEX-JELLYFIN-DUPLICATE-DEVICE-ID-20261120.json)。证据入口 `/tmp/nastart-playback-20261120-wifi/`，两手机历史快照位于 `/tmp/nastart-codex-renew-all-20261119-current` 指向的本机私有目录。
