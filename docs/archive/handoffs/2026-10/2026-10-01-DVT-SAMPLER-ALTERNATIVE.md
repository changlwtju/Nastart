# 2026-10-01 17:16 USB/DVT 替代采样已取得数据

本轮读取 PROGRESS、当前交接、runbook、竞品矩阵、AGENTS；不修改 PROGRESS.md，保留既有源码修改。用户继续要求解决采样受阻，iPad 仍暂缓。

## 实际进展

- 现场 usbmux 枚举仅 iPhone 13，名称 iPhone、型号 iPhone14,5、iOS 16.3.1、UDID `REDACTED-DEVICE-01`；配对 validate 成功。
- 已安装 tidevice 的 `perf -o fps --json` 通过 USB 直接连接设备 DVT graphics 服务。没有使用宿主 xctrace，没有提权或通过外部进程绕过沙箱。
- 首次有界 15 秒能力探测取得 14 条 FPS 样本。新增可复用 `scripts/device_graphics_probe.py` 后再次实测 8 秒，取得 8 条，覆盖 7.091 秒、最大样本间距 1.015 秒；正常 SIGINT 收尾，退出 0。工具退出/清理文本 3 行保留在原始日志，解析器计入 rejected_lines，不当成帧数据。
- 原始证据仅在权限 700 的 `/tmp/nastart-sampler-alternative-20261001/` 和 `/tmp/nastart-dvt-probe-20261001-repeat/`。第二目录包含完整 report.json、graphics.jsonl、stderr.log。
- 脚本保存设备、时刻、采集时长、退出码、失败/超时收尾与原始数据；空数据、重复时钟、非法数值及平均 FPS 不能成为滚动 PASS 的 4 项检查通过，git diff --check 通过。

## 结论边界

“所有采样都不可用”已不成立：设备级图形统计可采集。此数据约每秒一条，是全设备合成图形聚合指标，不是 Nastart 独占 FPS，也不是逐帧呈现时间。静止界面低 FPS 不能解释为卡顿，不据此判断性能退化。

本轮仅探测采样服务，未安装/启动 App、未做手势、未播放或操作竞品；未重新核对设备中的 App 包身份。最新本机包身份沿用上轮记录只作背景，不能视为本轮安装核对或回归。本轮无滚动 PASS，完整帧时间采样仍未恢复。

## 接续方案

1. 直接 DVT 聚合统计可用于后续同条件诊断；先按 AGENTS 完成当轮包身份与正常启动核对，再配合 WDA 实际位移/前台证据观察。设备级归因限制须保留，不把平均 FPS 纳入现有完整帧验收。
2. 完整验收继续保留 Instruments 路径：普通 Terminal 的同一预检与真实录制/导出仍待取得；当前会话不允许提权，不自动借 Terminal 执行。
3. 若继续开发其他采样后端，需要实际获得逐帧时间并验证覆盖率，再接入滚动判定。App 内 CADisplayLink 可作为主线程诊断候选，但不能替代真实呈现时间，也不能作为竞品共同测量。

复用命令（output 必须为新目录，拒绝覆盖旧证据）：

```sh
python3 scripts/device_graphics_probe.py \
  --tidevice /tmp/nastart-20261001-wda-resume/tidevice \
  --device REDACTED-DEVICE-01 \
  --seconds 15 --output /tmp/nastart-dvt-probe-next
```

退出 0 只代表观测到聚合数据流；报告始终明确 `scroll_verdict=INSUFFICIENT`。现有 ui_scroll_probe.py 的完整帧门槛未放宽。
