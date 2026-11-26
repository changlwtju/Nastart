# 2026-11-09 iPhone 18 解锁后无线更新复查

用户确认手机已解锁，04:09 起重新执行现有配对的无线身份和安装前检查。iPhone19,7、iOS 27.0 的实时身份匹配，配对认证成功，名称与 UDID 记录在本机私有证据。直接服务读取的 `PasswordProtected` 为 false。系统 CoreDevice 同时显示 paired、tunnel unavailable、DDI services false。

待安装的是回退后接受的正常签名 Debug，产品源码对应 `d3dbc9c4`，当前 HEAD `8db1cc64` 与该包的产品输入一致。构建时间为 2026-11-08 17:31:43 +08:00，主程序 SHA-256 `2f8e29cd25d5a8b59e99045c44b21079e796bed5d88cfb39214d9a7226c204a6`，Debug dylib SHA-256 `3ac443127f9ece12fafbc91f2e81077be843f0ee959f501bac5be912ab4f680f`。372 个已跟踪 iOS 输入、IPA CRC 和成员、30 个嵌入库签名、deep/strict 以及有效且覆盖目标的 profile 均已核对。包和 IPA 路径留在本机私有记录。

| 通道 | 本轮结果 |
| --- | --- |
| 当前 Bonjour 广播与 IPv4 配对 TCP | 匹配目标，已配对认证通过 |
| HouseArrest App 容器备份 | `VendContainer` 发出后连接断开，未取得偏好文件 |
| installation_proxy 的只读 bundle 查询 | 连接断开，未取得已装 App 信息 |
| 系统原生无线开发服务 | 无匹配的可用 RSD 目标 |
| 当前同一 Bonjour 主机的两个 IPv6 地址 | 均匹配真实设备并通过配对认证，App 容器备份仍断开 |

未上传 IPA、未发送 Install、未请求启动或停止 App。安装结果保持待完成。当前可证明身份与配对可用、App 服务连接不可用，故障原因尚未确定。用户已完成解锁动作，后续应定位无线服务断开的原因，再恢复安装。原始服务错误和当前端点留在本机私有证据，未改配对、网络、账号或设备设置。本次设备窗口已释放。
