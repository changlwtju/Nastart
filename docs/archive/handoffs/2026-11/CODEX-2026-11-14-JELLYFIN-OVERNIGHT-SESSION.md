# 2026-11-14 Jellyfin 隔夜冷启动

接续 [Jellyfin 冷启动认证与 ISO 续播退出](CODEX-2026-11-13-JELLYFIN-SESSION-ISO-EXIT.md)。iPhone 13 独占窗 09:29:18–09:29:56，北京时间。现场 USB 配对核对设备名称、完整 UDID、iPhone14,5 和 iOS 16.3.1，设备停在主屏幕，原 Wi-Fi 图标可见。按已授权的冷启动流程，先保留诊断与偏好，再停止经 bundle 和已安装可执行路径核对的后台 Nastart。空参数、空环境原生启动新进程，WDA 附着当前进程。

## 安装身份

HEAD `8db1cc64`，开工 155 个未提交路径。500 个冻结构建输入逐项相同，旧的 122 路径基线之后已有各批源码及文档增量。现装 App 安装回执与 11-13 保留数据安装一致，签名和目标设备覆盖有效。沿用 11-13 07:06:39 完成的签名 iOS Debug，App 描述文件有效至 11-15 08:30:17，Runner 也通过有效期和已装身份复核。

- 主程序 SHA-256 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`。
- Debug dylib SHA-256 `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`。
- IPA SHA-256 `f6983feb629b61b992bf25571e0a52376ebbe86934c24a43ba03d2f7b62ae0a1`。包路径、完整设备标识及原始快照留本机。证据入口 `/tmp/nastart-codex-jf-overnight-20261114-current`。

## 判定与依据

| 场景 | 结论 | 依据 |
| --- | --- | --- |
| 原 Wi-Fi 内网保存会话隔夜冷恢复 | 本次通过。从 11-13 22:18:05 重登到本次读库约 11 小时 12 分钟 | `diagnostics.jellyfin.library_loaded stage=views` 09:29:41.663，`stage=completed` 09:29:42.744。WDA 实见两张资源库卡片及搜索入口，无登录表单。同窗 `primaryHTTPStatus=200 currentPrimaryAuthenticated=true` |
| 同一 Wi-Fi 下的公网备用项 | 失败，公网备用会话仍返回 401 | 09:29:41.693，`stage=authenticatedOriginProbe trigger=libraryRestore candidateHTTPStatus=401 candidateAuthenticated=false sameServerAndAccount=false`。源码核对该探测由各地址自己的保存会话向 `/Users/Me` 发起，诊断 `ownEndpointTokenUsed=true redirectsAllowed=false playbackRouteChanged=false`，本窗仍使用原 Wi-Fi |
| 11-13 22:12 旧内网会话失败原因 | 待服务端证据 | 历史读取服务器日志的工具依赖旧诊断中的认证材料，本轮只核对该接入方式。没有取得当天 Jellyfin 或公网代理日志，现有客户端 HTTP 状态无法区分失效、撤销或代理端拒绝。关联窗口为 11-13 22:12、22:16–22:18 和 11-14 09:29，北京时间 |

每次页面操作后立即导出，本窗快照到达 1000 条上限，按窗口时间筛选。控制台及偏好快照分别运行路线复算，均退出 0、输出 `0 playback(s) with route evidence, 0 to check.`。本窗仅登录恢复与读库，无播放路线容量样本。

核对原 Wi-Fi 状态栏图标、主屏幕，无切网设置动作。App、Runner、采集和本机 8161 已释放。没有重新登录、重新安装或更改产品代码、播放模型、参数和服务端配置。本批没有触发产品单测或预检。一次隔夜内网通过保留为该时点的证据，历史 401、公网备用认证、蜂窝播放与实际听音仍开放。Codex 已同步进度、当前交接、开发状态、需求总账、播放矩阵、资源登记和协作分工。
