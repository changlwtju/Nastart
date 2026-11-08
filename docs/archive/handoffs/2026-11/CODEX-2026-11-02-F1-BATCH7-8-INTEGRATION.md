# Codex：F1 手机矩阵与第七／八批集成

后续更新：[六配置与13项主目录补验](CODEX-2026-11-02-BATCH78-SIX-BUILDS-HOSTED13.md)已完成；下文保留11:33时的原始受阻记录，不能再作为当前构建状态。

2026-11-02（Asia/Shanghai）。按用户本轮派发执行；产品补丁来自 Claude，Codex 负责本次集成与验证。NAS 暂停、0 真机操作、原有 dirty 与 Git index 保留。

## F1 结果

既有 `Claude-PW-iphone`：iPhone 17 Pro／iOS 27.0，11:25–11:31，使用既有独立目录的 Debug 包；后续核对 197 个 App／测试／包源码文件与接入后的主目录相同，不冒充主目录重新构建。安装二进制完整哈希在本机私有证据。

| cells.txt 格子 | 诊断 | 圆点变化 | 结论 |
| --- | --- | --- | --- |
| F1-phone-sta-r1 | 开 | 12→1 | 替换 |
| F1-phone-sta-r2 | 开 | 12→1 | 替换 |
| F1-phone-sta-r3 | 关 | 12→1 | 替换 |
| F1-phone-lar-r1 | 开 | 12→1 | 替换 |
| F1-phone-lar-r2 | 开 | 12→1 | 替换 |
| F1-phone-lar-r3 | 关 | 12→1 | 替换 |

使用原生电脑控制点击密码框，再点一次模拟器屏幕键盘；未被工具拒绝。首格 `typeText` 未见变化，改点屏幕键盘后才出现一个字符；没有使用密码明文读取、设置值或绕过工具限制。四个 trace 窗口各 11 事件（共 44），字段不含文本、长度或选区偏移；六个完成 flag 均已写入。每格有结果截图；两个 r3 初轮只记类别，随后各按原参数 fresh 补图一次（均仍 12→1），不增加唯一覆盖数。iPad 未创建，六个 pad 格子**未执行**，未补完成标志。

循环自然到 `ALL CELLS DONE` 并自行退出；补图后仅终止本轮已识别 App，模拟器保持 Booted，**未运行 stop、未关闭或删除实例**。这只复现首次输入替换，不证明原因或修复，也未测试显隐／真实钥匙串。

## 集成与检查

- batch7 补丁 SHA-256 `34d7d73b17669ee8c071f2f26a2f725f550bcdc8cf82967b8dda311916acfdd0`；batch8 D+A+C 合并补丁 `18801345286be2ac8922dcddf88a47217605fd9ab3ae633b1c6108a21a5278e2`。单独及合并 `git apply --check` 全部 0，合并应用 0；12 个完整文件先备份、后核哈希，Git index 未变，未覆盖其他修改。
- 第七批接入 DEBUG 密码归因夹具与匿名字段；第八批接入可注入外观偏好域、缓存逐步清理／部分失败反馈、原生分享结果（仅失败提示）。UI 标识与字段白名单已同步到离线场景文档和资源登记。
- 包的全部 90 个文件与第七批已编译输入目录逐字相同；复用其已编译 macOS XCTest 产物执行 `OfflineUIScenarioTests` 8＋`WebDAVConnectionFieldsTests` 6，**14/14 通过、退出 0**。这是同源包测试重跑，未重新编译主目录完整 App。
- 六配置（iOS／tvOS 各 Simulator Debug、unsigned device Debug／Release）**全部未运行**：空间现场 1.8–3.24GiB，低于项目 6GiB 构建门槛。第八批 13 个 app-hosted 单测、当前 Release 排除与新正常包也未运行／生成；此前独立目录 9/9 不扩大成当前 13/13。已一次请求用户释放空间，未自行清缓存或启动后台重试。
- 静态 `preflight.py` 退出 1，仍显示已知五类失败（分隔符、ATS、图标规则、图标夹具、方向规则），日志完整保留；不是全绿。受影响已跟踪文件 `git diff --check` 通过。`check_documentation.py` 退出 0（628 文档／3883 本地链接，缺失 0）。

私有证据入口 `/tmp/nastart-codex-batch78-integration-path`：起止文件／index 哈希、原始矩阵截图与 JSONL、模拟器身份／二进制哈希、测试日志及六配置未运行原因。可分享结构结果见 [JSON](../../../testing/results/2026-11/CODEX-F1-BATCH78-INTEGRATION-20261102.json)。

下一步：释放到至少 6GiB 后串行执行当前集成源六配置、build-for-testing 与 13 个 app-hosted 测试（宿主须再次核无凭据／服务／缓存），再核 Release 排除。真机／NAS 不在本轮授权内；30 项需求状态和 114 格播放验收均不关闭、不新增 P。
