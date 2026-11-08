# 2026-09-30 iPhone 18 ISO 蜂窝播放错误

## 现场与判断

用户报告在家外蜂窝播放 ISO，多个入口偶发 `KSPlayerErrorDomain:2:avformat can't open input`，随后连接 Mac 授权读取诊断。21:43 前后已重新导出设备偏好诊断，保留安装前证据。

- 18:33:57–18:36:00，Jellyfin 四次（`E85329F3`、`E1B29F79`、`E213082D`、`3F7E742E`）及设备文件一次（`70741257`）均已成功解析 ISO/M2TS，但 KSPlayer 打开时 bytesRead=0、duration=0、ready=no，全部指向本机端口 59083。
- 已核对的失败样本进入播放器到失败约 11–15 ms。同一期间普通媒体代理有 59082→59084→59085 的重建记录；ISO 旧实现没有对应自检/失效清理。
- 19:23 的另一 ISO trace `98436F4B` 已出现首帧，因此不能推断所有 ISO 都不支持。截图的 46:41 可为续播位置，不能据此断言连续播放 46 分钟才失败。
- 蜂窝环境来自用户陈述；旧日志 networkClass=unknown，未独立证明网络类型。旧代理缺少请求级失败证据，**陈旧本机监听端口是高度可疑原因，不是已由原始 socket 错误证实的唯一根因**。

## 修正

`ISOPlaybackAdapter.swift`：每次注册前用本机 HEAD `/iso-health` 检查 ISO 代理（1.5 秒超时，不请求 NAS）；失败时清理旧监听并重建一次。监听 failed/waiting/cancelled 后清空状态，过期监听回调不能覆盖新监听。并发注册共享启动等待队列。资源保存原始注册端口，重建后仍能释放旧路由。新增 `proxyKind=iso` 的 ready/restarting/failed 诊断。

未改变 ISO 上游下载重试或转码策略。本修正处理后续打开/重开前的失效代理，不承诺已播放中的网络中断自动无缝恢复。

## 验证与安装

- 模拟器 3 项 XCTest 全部通过：保留陈旧端口后的重建、监听取消后的重建、并发注册共享监听；恢复测试实际校验 HTTP 206、Content-Range、字节内容及旧资源释放。
- 最终测试日志 `/tmp/nastart-iso-listener-tests-final.log`；结果 `/tmp/nastart-iphone18-adaptive-derived/Logs/Test/Test-Nastart-2026.09.30_21-41-51-+0800.xcresult`。
- iphoneos Debug 构建成功，codesign 严格验证、preflight、diff 检查通过。
- 21:46–21:47 保留数据安装至 iPhone 18 Pro Max（UDID 尾号 A0000A），无 `DEVICECTL_CHILD_*` 测试参数正常启动，进程 PID 3935 已核实。
- `Nastart.debug.dylib` SHA-256：`343f0b3a7190dd2511f38bbd4f9a0fb592badf8f8a74aacd4b000d6c62e77d2e`。
- 安装包：`~/Library/Application Support/Nastart/DebugEvidence/2026-09-30-iso-cellular/Nastart-iso-listener.app`。旧包保留。

## 待验

真实 ISO 双入口首帧、蜂窝与 Wi-Fi 切换/后台恢复后的重开仍待复测；本轮安装启动不等于实机播放通过。旧 8104 WDA 未运行。继续取证时筛选 `proxyKind=iso`、相同 playbackTraceID 的准备/失败/首帧事件；若自检通过仍失败，再调查上游 Range/鉴权/超时，不能直接归因蜂窝带宽。

原始诊断只保存在上述本机证据目录的 `iphone18-preferences.plist` 与 `iphone18-connected-preferences.plist`，可能包含凭据，禁止提交或复制到项目。源码及本记录未提交，保留全部既有工作区修改。
