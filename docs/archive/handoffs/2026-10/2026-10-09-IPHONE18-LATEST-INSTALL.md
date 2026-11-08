# 2026-10-09 iPhone 18 Pro Max 最新包安装

完成时间：2026-10-09T21:59:21.911895+08:00。用户要求安装最新包；本轮仅核对、保留数据覆盖安装与正常启动验证，未修改App源码。

现场重新确认名称iPhone、iPhone19,7 / iPhone 18 Pro Max、iOS27.0 / 24A8428、USB连接及配对有效；完整UDID、设备原始信息、诊断和偏好仅留本机私有证据目录。

## 包身份

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；保留所有既有未提交修改，iOS diff SHA-256 `cde080f24f91f44cfd9df7d390947c1cd7f0bc563846e51f455044a591e30ad8`。普通Debug -Onone，构建时间 `2026-10-09T21:13:53.778606+08:00`；包 `/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-09-av-activation-boundaries-210752/Nastart-AV-Activation-Normal-Debug.app`。重新核对146个源码/项目/配置输入均未晚于产物，主程序、debug dylib及KSPlayer哈希与交接一致；29库逐个strict验签及App deep/strict通过，目标在有效签名配置内，到期UTC `2026-10-10T22:03:15`。

- Nastart SHA-256：`1047613b4e704ba454a529b6c3c51c39090c145a0b71416e88fffa1edce59048`
- Nastart.debug.dylib SHA-256：`9c0c9fef86b467f7eb27981de070463521b0cc08ee95b4dd953e9664612cff0a`
- KSPlayer SHA-256：`eda16e6d0e22bc81045752f2f54a263b0f4f8500912378d5ac141013c9042b52`

## 安装与正常启动

先保存旧App原始故障诊断和偏好；无法仅靠版本号证明已装包身份，因此覆盖安装已验证最新包，安装成功时间 `2026-10-09T21:57:17.409182+08:00`。没有卸载或清除登录数据，25项非诊断偏好在安装后和正常启动后均一致。

正常启动无测试注入、无参数，PID 8199；工具实际附带环境仅TERM=dumb。首次传空JSON环境字典被devicectl参数解析拒绝，未启动App；清除所有继承DEVICECTL_CHILD变量后省略该选项重试成功，失败日志单独保留。

首次原生截图处于App切换动画，不作为正常首页证据；后续原生截图已人工核验实际Nastart播放器和影片画面，同一启动进程在约99.2秒后仍存在。期间可能有用户操作，未由本轮发起任何视频播放，不把这一画面当播放性能回归或首页证据，不继续干预手机操作。没有重装/启动WDA或更改网络、账号。

## 完成边界

iPhone18最新包安装和正常启动完成，可使用。没有新增播放、滚动或性能验收；原有播放失败、全矩阵/竞品/Main开放项继续按[AV边界交接](2026-10-09-AV-ACTIVATION-BOUNDARIES.md)接续。本轮未操作13/iPad，不声称两机完成当轮重核。本源码此前221测试/2跳过/0失败和15预检仅引用前批记录，未重复测试。

[脱敏安装摘要](../../../testing/results/2026-10/IPHONE18-LATEST-INSTALL-20261009.json)。
