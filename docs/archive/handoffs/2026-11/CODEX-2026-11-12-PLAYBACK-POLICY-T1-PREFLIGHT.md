# 2026-11-12 T1 内网回归预检

Codex 执行。依据 [总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md) 和 [V1/V2 场景](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md#三真机验证清单)，时间为北京时间。

- 03:35:36 A16 iPad（iPad15,7 / iPadOS 26.6），03:36:04 iPhone 13（iPhone14,5 / iOS 16.3.1）。两台各自 USB fresh 核对；Nastart 的实际安装路径与 [T0](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) 当轮签名 Debug `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0` 安装回执相符。
- 两台均有已安装的 Runner，安装查询返回 `ProfileValidated=true`。此字段未提供当前有效期；设备独立描述文件枚举未返回该 Runner 的描述文件。iPad 的 Runner 路径与 11-10 已验证的那份安装记录相同；该兼容包的嵌入描述文件于 11-11 08:39:52 到期。iPhone 13 上一轮验证用的描述文件于 11-11 08:42:31 到期，本轮没有找到可确认的更新版已装 Runner。
- 本机已有同一开发团队的 Runner 描述文件，覆盖两台当前 UDID，与 T0 的开发签名证书有交集，有效至 11-16 19:51:31。可用各设备原兼容夹具的副本分别续签，现场仅按需部署，须先获得本轮 Runner 授权。也可由用户手动操作 iPad，Codex 独立采集。两种方案已一次告知用户。
- V1 起播、续播、从头均未开始；V2 未取得自然降档观察。无 `playback_prepared`、`renditionCeiling` 或降档的新样本，未对真机样本复算。离线路线复算工具自测 6/6 通过。
- 本窗只读。未启动或更改 App/Runner，未切网、未发出媒体请求；结束核两台 App/Runner 均未运行，设备占用释放。未改产品代码或参数。取证见私有指针 `/tmp/nastart-codex-playback-device-20261112-current`，其中 `pad/t1-input-preflight-private.json` 与 `phone/t1-input-preflight-private.json`。

续接 T1。每个播放动作后立即导出；V1 检查实际内网地址、`*DirectPlay`、`maxBitrate=unlimitedOriginal`、主记录 `renditionCeiling=legacyBudget` 和首帧，V2 只记录自然触发的降档。之后按总交接决定能否继续。T2 蜂窝窗口尚未开启，T3–T6 保持待办。
