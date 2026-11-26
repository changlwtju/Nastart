# 2026-11-13 Jellyfin 冷启动认证与 ISO 续播退出

接续 [《变形金刚》双入口对照](CODEX-2026-11-13-TRANSFORMERS-ISO-JELLYFIN-COMPARISON.md)。iPhone 13（iPhone14,5 / iOS 16.3.1）、USB、原 Wi-Fi。现场核完整 UDID、500 个构建输入、现装回执及签名 Debug `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`，主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`。HEAD `8db1cc64`、开工 154 个未提交路径，包构建于 07:06:39，描述文件至 11-15 08:30:17。空参数、空环境，沿用 App 与 Runner。

## 冷启动认证

| 窗口 | 内网 HTTP | 公网 HTTPS 同账号备用项 |
| --- | --- | --- |
| 17:48 冷启动正常 | 资源库 `stage=completed`，`primaryHTTPStatus=200 currentPrimaryAuthenticated=true` | `candidateHTTPStatus=401 candidateAuthenticated=false` |
| 22:12 冷启动失败 | 选中同一内网根地址的保存项，`library_failed httpStatus=401`，随后 `primaryHTTPStatus=401 currentPrimaryAuthenticated=false` | `candidateHTTPStatus=401 candidateAuthenticated=false` |

22:12 恢复记录先是 `waitingForIdentity`，随后是 `candidateIneligible`。现有恢复路径要求不同于被拒地址且已核同服务器的局域网候选，本窗选中的原地址本身即为内网根地址。公网备用项也被服务器拒绝，日志未见可用替代会话。当前证据可以定位资源库失败发生在媒体准备前。服务器为何拒绝曾经有效的内网会话仍待服务端证据，客户端诊断没有令牌值或撤销原因。

原始诊断仅留本机，22:12 时间线来自原生收尾时保存的 App 日志。未读取 Keychain 值，未改账号、远端文件或配置。

## 重登和续播准备

- 22:16:48–22:19:03 同包新窗再现内网资源库 401 及内外网身份请求均 401。用用户已授权的 App 登录恢复，`login_succeeded` 22:18:05.013、`library_loaded stage=completed` 22:18:06.369，实见两张资源库卡片和搜索控件。2007 年《变形金刚》详情显示「在 Nastart 中播放」，没有「继续观看」。按续播断言停止，未发播放，原生核资源归零。该详情状态本身不能证明历史进度何时丢失。
- 22:19 后再次冷启动，本次无需重登即可载入同一资源库。先从当前可用入口播放并普通退出，再核详情提供「继续观看」，避免把从头播放算作续播。
- 22:19:37–22:22:41，首播 `36C66738 plannedStartSeconds=0.0`，内部首帧 1,494 ms，普通退出后 `iso_resource_released registeredCount=0`，详情确实提供「继续观看」。接着续播 `A7B8418C plannedStartSeconds=19.1874 playMethod=directPlay routeKind=localRangeProxy decodeEngine=ksPlayer`，UDF 主片 28,241,829,888 字节、音轨 1 / 字幕轨 6，内部首帧 3,223 ms，约 10 秒实图为片头。本轮取景没有台词，先前 64 秒附近续播已有中文字幕实图。
- 续播点「完成」普通退出，22:22:21.186 `local_resume_save_boundary boundary=close subtitleSelectionKnown=true subtitleTrackID=6 subtitlesDisabled=false`，22:22:21.713 `iso_resource_released registeredCount=0`，实见《变形金刚》详情与「继续观看」。路线脚本 `0 playback(s) with route evidence, 0 to check.`，ISO 路径无容量决策行。现场听音和较长时间会话持久性仍待。
- 22:20 与两次退出后的认证日志均为内网 200、公网备用项 401。22:22:41 核 App、Runner、采集、8161 已释放和原 Wi-Fi 图标。无产品代码、模型、参数、服务端配置改动。私有证据入口 `/tmp/nastart-codex-jf-iso-finish-20261113-current`、`/tmp/nastart-codex-jf-iso-closed-20261113-current`。
