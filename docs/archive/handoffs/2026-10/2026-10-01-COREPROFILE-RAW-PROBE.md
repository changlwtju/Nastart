# 2026-10-01 17:32 CoreProfile 原始事件流接续

已读 PROGRESS、CURRENT、AGENTS、播放 runbook、竞品矩阵和 PX/UX 总账；按协作约定不写 PROGRESS.md。保留所有既有修改，未修改 App 源码。

## 现场与本轮范围

- 现场 usbmux 仅见 iPhone 13：名称 iPhone，型号 iPhone14,5，iOS 16.3.1，UDID `REDACTED-DEVICE-01`；配对 validate 成功。
- HEAD `9a9941cd4ec82625f680b5193b3a0f66797eb851`，工作区仍有既有 App/脚本/文档修改。本轮未核对设备 App 安装身份，未安装、启动或操作 App，不开展最新包回归。历史 `a79ae773…` 只作背景。
- WDA 8102 `/status` 本轮连接失败（curl 退出 7）；没有重装 WDA，也未据此判断 App 故障。iPad 按用户此前要求暂缓，iPhone 18 未调试。

## 新取得的证据

1. 读取本机已安装 pymobiledevice3 的 CoreProfileSessionTap 配置实现，用现有 tidevice USB/DVT 连接 `com.apple.instruments.server.services.coreprofilesessiontap`；服务建通道、setConfig 均成功。
2. 初次尝试接收线程因 tidevice 不支持 `DTKTraceTapMessage` 反序列化中断，0 数据块。原始异常保留，不能把服务可连接当作采样成功。
3. 临时私有诊断程序在解码失败时保留原始 DTX payload，未改系统安装的 Python 包。8 秒有界采集收到 52 块、32,926,143 bytes；有 25 秒总超时和约 32 MiB 数据停止门槛。结束发送 stop 并关闭连接，采集进程正常退出；未取得 stop 的独立应答，不能称其为服务端停采回执。
4. 42 块为 flags=1799 的压缩消息。依据本机 compression.h 的 `COMPRESSION_LZ4=0x100`，用系统 libcompression 解压；42 块输出长度均与消息声明一致，共 122,667,840 bytes。
5. 排除 stackshot 数据后，按本机 pykdebugparser 的 kdebug v2 格式解析，得到 1,898,765 个事件、922 种 event ID，解析无异常。原始 tick 首尾为 14978414826707 / 14978596452496。

这证明直接 USB/DVT 的原始事件采集及解压解析路径可行，已不止约 1 Hz 聚合 FPS。但尚未取得显示事件名称映射、校准 timebase、验证丢事件/覆盖率、建立 App 归属或 hitch 区间，**不等于完整帧采样恢复，滚动仍 INSUFFICIENT**。本轮未做手势、播放、竞品配对，没有新增 App 性能结论。

原始证据全部位于权限 700 的 `/tmp/nastart-coreprofile-20261001-1730/`，包括失败 `probe.py/run.log`、成功 `raw-probe.py/raw-run.log`、`decode.py`、`parse.py`、`raw/report.json`、`raw/decode-report.json`、`raw/parse-report.json` 与原始/解压数据。可能包含设备进程信息，仅留本机，不纳入仓库。临时探测脚本不是正式验收后端；尤其不能直接将任何内核事件频率当显示帧率。

## 未解决项与下一步

- 优先接续：取得本设备 trace code 映射和 mach timebase，识别实际显示/提交事件；检查缺口、丢事件与动作时间覆盖，再决定是否接入 ui_scroll_probe。不能降低现有逐帧门槛。
- UI 回归之前恢复固定 WDA，按 AGENTS 重新核对/必要时保留数据覆盖安装最新正常包，保存启动证据；本轮未完成这道门槛。
- UX-06 滚动仍未验收，Lenna 同源/路径/轨道/缓存/共同计时与至少五组配对仍未完成。Debug 与商店包不作公平性能胜负。
- PX-03 原画旧停滞根因、真实失败回退、ISO 蜂窝和切网复测未闭环；PX-01/02/20/21 的同条件首帧/seek/轨道实际生效及剩余生命周期场景仍待验。
- PX-04 继续暂缓；PX-05～19 的 PiP/HDR/字幕/剧集/投屏及实际 Dolby 输出按原批次保留；UX-01～05 与全部矩阵缺口不因本轮采样进展改变状态。iPad 暂缓不等于已解决。

本轮 `git diff --check` 通过；无 App 构建、真机功能 PASS 或性能排名。
