# Codex：已保存／更改密码行集成与验证

2026-11-02（Asia/Shanghai）。按用户批准接入[Claude交付](2026-11-02-1320-CLAUDE-SAVED-PASSWORD-DELIVERY.md)。产品源码**只改 LibraryViews.swift**；没有追加聚焦延迟／其它产品改动，未操作真机／NAS。

## 集成与构建

起始SHA-256 `fd15f63fdd9935765ccce13cdd39a1c9a650dd3e3197c435a535b3a782171e07` 核对通过；补丁SHA-256 `8483f80e88f035117ccc306753a4f525f7dc358b27326038734e1606015603f6`，`git apply --check`／apply 均0。结束SHA-256 `b0d81db08225a00c2402671c1402b29bfad78dcbee0b1b2ceb50d7fad40365f5`。原447项输入中仅该文件变更；后续447项／HEAD／Git index保持，未重置其它dirty。

Xcode27.0（27A266a），本批独立DerivedData／依赖缓存，锁定版本且禁止自动解析／更新；arm64、无签名、串行执行：

| 配置 | 退出码 | 时间（+08:00） |
| --- | --- | --- |
| iOS Simulator Debug | 0 | 13:17:10–13:19:14 |
| iOS device Debug | 0 | 13:22:49–13:25:50 |
| iOS device Release | 0 | 13:25:50–13:29:47 |
| tvOS Simulator Debug | 0 | 13:29:47–13:30:55 |
| tvOS device Debug | 0 | 13:30:55–13:31:59 |
| tvOS device Release | 0 | 13:32:00–13:33:33 |

**OfflineUIScenarioTests 8＋WebDAVConnectionFieldsTests 6＝14/14通过**，当前主目录包在独立scratch重新编译，退出0。两端Release各13个调试标记全0（iOS28／TV25个Mach-O），Debug30个二进制正对照全部有命中。不是当前全App所有单测／真机验收；旧批13项宿主结果保留前源归属。

## 当前新包模拟器窗口

复用 `Claude-PW-iphone`，iPhone17 Pro／iOS27.0；本轮新Debug包安装后主二进制与debug dylib SHA均与构建产物一致。每窗fresh进程，全部不带trace，仅合成连接：

| 参数／窗口 | 观察 |
| --- | --- |
| `--offline-ui connection-edit --offline-ui-text-size standard` | 显示“已保存／更改”；一次点更改即出现空密码框和屏幕键盘，未手动点框补焦；点行内取消后恢复已保存行，键盘收起 |
| 同上，`large` | 滚到密码行后同样成立；更改、空框、眼睛与取消可见，自动键盘与取消恢复均通过 |
| standard＋`--offline-password-cell F1` | 不显示已保存行，仍是预填12点的旧框；点框后屏幕键盘输入1字符，12→1，旧行为保留 |

共3唯一窗口、8张前后／恢复截图。两个字号的聚焦均在一次原有Task请求后自动成功，**没有添加延迟、重试或手动补焦**。取消验证限于合成UI行恢复；原密码快照恢复及不更改时沿用原绑定已审源码，未做真实Keychain／服务器保存事务。新建／空密码、iPad、TV实际遥控、其它iOS版本和完整读屏未在本轮操作；显隐失焦旧问题不因此关闭。

登记后缀：`.passwordSaved`、`.changePassword`、`.cancelPasswordChange`。离线前缀`offline.connection`三项实际可见；正式编辑前缀`network.connectionEdit`三项在源码／编译中确认，未作带账号运行。默认预填connection-edit且无cell才展示新行，显式cell（含F1）保留归因旧框。

## 失败、安装与收尾

1. 首轮iOS模拟器构建退出65：我复制的编译缓存含旧绝对路径，报SwiftShims PCM路径不一致。日志／状态及本轮复制缓存已归档，仅在本批目录创建空缓存后重建通过；无产品源码修改或他人缓存清理。
2. 模拟器覆盖安装命令成功、二进制一致，但数据容器UUID改变，导致“路径必须相同”的严格断言失败。安装前后及三窗结束的偏好均为空且一致；未卸载／清数据，保留失败证据并复用已装包继续，**未重复安装**。没有安装前全量数据清单，故不声称完整数据迁移已独立核实。

三窗结束前核实际可执行路径／PID／参数，只终止本轮App；原模拟器保持Booted，未运行stop／删除实例／改偏好。无xcodebuild遗留，窗口释放；剩余约5.97GiB。447相对输入清单SHA `617f1a573102eb8d6128f9ab8c0c1dca187c01f7cc035d9d83c99894c0b45d08`。未生成可安装正常签名包、未更新任何真机；30项需求／114播放格不关闭、不新增P。

私有证据入口`/tmp/nastart-codex-savedpw-path`，含补丁前源／检查、每配置完整命令与日志、全部失败、安装／包哈希、截图、PID清理及输入清单。[结构结果](../../../testing/results/2026-11/CODEX-SAVED-PASSWORD-20261102.json)。编译仍有既有actor隔离等警告；本轮未重跑或修复此前五类静态预检失败。文档检查通过：633份文档／3901本地链接，缺失0。
