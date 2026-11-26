# 2026-11-14 iPhone 13 Jellyfin 覆盖安装前后对照

接续 [覆盖前基线与签名包](CODEX-2026-11-14-IPHONE13-JELLYFIN-OVERLAY-BASELINE.md)。用户明确授权用 WDA 在 Nastart 内登录。15:08 fresh 核对 iPhone 13 名称、完整 UDID、iPhone14,5 / iOS 16.3.1、USB、旧包安装回执、设备空闲和原 Wi-Fi。HEAD `8db1cc64`，现有未提交改动保留。所有时间为北京时间。

| 步骤 | 结论 | 诊断与页面 |
| --- | --- | --- |
| 15:09:04–15:10:28，旧包 `c7cf7671…` | 重登前已失败，授权重登后通过 | 15:09:27.972 `library_failed httpStatus=401`、`session_rejected stage=library`，内外网身份探测分别 401。15:10:14.527 一次 `login_succeeded`，随后 `serverIDRecorded httpStatus=200`、15:10:15.957 `library_loaded stage=completed libraries=3`。WDA 实见两张资源库卡片、搜索和无登录表单 |
| 15:11:22，保留数据更新 | 通过 | USB installation_proxy 明确完成，fresh 回执确认新安装身份。安装前后 30 项 App 偏好逐项相等 |
| 15:11:23–15:12:07，新包普通冷启动 | 内网现有会话直接恢复，通过 | `primaryHTTPStatus=200`、`library_loaded stage=completed libraries=3` 15:11:47.889。无新 `login_succeeded`、`session_rejected` 或 `library_failed`，两张资源库卡片和搜索可见，无登录表单 |
| 新包同窗公网备用身份探测 | 仍为 401 | `candidateHTTPStatus=401`。本窗主入口是内网，未触发公网作为主入口时的 `replacedRejected`，未验证蜂窝 |

新包于 11:33:14–11:34:28 用 Xcode 27.2 构建为签名 iOS Debug。安装前再次核 647 个输入、签名及 30 个嵌入库、目标 profile、IPA CRC。Debug dylib SHA-256 `caa776f868e9b735be43f2bbc2ef79bb8c37343a0cc81ccd2dd42bb6508df07a`，主程序 `de5cc10f62ef450b6605a358f2fb4e5bb2f8b64f8ab59a31f2823b2019f8cd2a`，IPA `74a93d2824df4c912ee7ce79b7efaf74f75b5ac75d7c389af174aa95a4d93349`，描述文件到 11-15 08:30:17。原始路径和证据保留在本机 `/tmp/nastart-codex-jellyfin-overlay-20261114-current`。本轮两次均原生空参数、空环境启动，没有卸载、清数据、切网或改远端配置。

逐操作导出并使用窗口时间过滤 1000 条诊断。旧包重登成功最终从退出前即时偏好补齐，先前读取尚未写入这批诊断。两窗路线脚本退出 0，输出 `0 playback(s) with route evidence, 0 to check.`，本轮没有播放。旧包窗删除 WDA 会话超时，Runner 退出路径结束所有自有进程。两窗均原生核 App 与 Runner 归零、采集结束、8161 释放。最后实见主屏幕原 Wi-Fi 图标。

在此配对样本中，有效内网会话经过覆盖安装仍直接可用。早前两次 401 发生在覆盖前，上午已见服务端 `Invalid token` 和同账号令牌撤销/补发，原因的逐请求归属仍待。后续公网主入口恢复应单列，不能拿本次内网通过代替。无新源码、模型或参数改动，沿用新包前批七项定向测试结果。
