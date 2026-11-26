# 2026-11-13 《碟中谍5》冷续播与 Jellyfin ISO 对照

接续 [新样本首轮](CODEX-2026-11-13-ISO-MISSION-IMPOSSIBLE-SAMPLES.md)。iPhone 13（iPhone14,5 / iOS 16.3.1）原 Wi-Fi，USB 控制，现装签名 Debug `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`，主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`。HEAD `8db1cc64`，开工 151 个未提交路径，构建时间 07:06:39，500 个含未提交改动的输入、签名与 fresh 安装回执核对一致。描述文件有效至 11-15 08:30:17。复用现装 App 和 Runner，原生空参数、空环境启动。

## 设备文件《碟中谍5：神秘国度》

- 17:23:25–17:26:35。正常冷启动后通过设备文件重开同一 55,092,144,234 字节 MKV，详情提供「继续观看」。`DDCBFAD1 plannedStartSeconds=70.058 playMethod=directPlay routeKind=localRangeProxy decodeEngine=ksPlayer`，`audio_track_changed engineTrackID=1`、`subtitle_track_changed requestedTrackID=10`。3 秒图显示 01:10 和缓冲，10 秒实图出画，30 秒有中文字幕，内部首帧 `tapToFirstFrameMs=7045`，引擎初始定位 402 ms。收到同文件尾段 `206`（55,092,135,511 至 55,092,144,233，完整交付 8,723 字节）。
- 普通退出后实见文件详情和「继续观看」。引擎确认 DV Profile 7 源和 Speaker，`dolbyVisionOutput=unverified dolbyAtmosOutput=unverified`，实际 Dolby 输出和现场听音未测。路线脚本 `0 playback(s) with route evidence, 0 to check.`，此原片路径无容量决策行。
- 首次切到 Jellyfin 服务后，「媒体资源库」触控未转入资源库，搜索控件未出现。保存服务页和缺控件截图，释放 App、Runner、采集和 8161 后开独立重试窗口。私有证据入口 `/tmp/nastart-codex-samples-resume-20261113-current`。

## Jellyfin 对照受阻

- 17:26:47–17:28:13，重新核对设备安装回执和窗口。进入资源库后 `library_failed httpStatus=401`、`session_rejected stage=library`，显示 App 内 Jellyfin 登录表单。未读凭据、未触密码眼睛、未发搜索或播放。搜索不到同一镜像与登录失败是不同结论，本轮只确认后者。恢复需要用户在 App 内重新登录。
- 两窗均未改网络，最后实图为主屏幕与 Wi-Fi 图标，App、Runner、8161 和采集归零。私有证据入口 `/tmp/nastart-codex-jf-iso-20261113-current`。

## 设备文件《变形金刚2：卷土重来》

- Jellyfin 登录待恢复期间，17:28:53–17:30:38 用同包、原 Wi-Fi 和同一设备文件入口独立抽测 27 GB ISO。引擎 `7DA29B40`，`iso_prepared indexFormat=udf titleCount=2 selectedPath=/BDMV/STREAM/00000.m2ts segmentCount=1 virtualBytes=29256185856 indexElapsedMs=1627 preparationElapsedMs=1634`，`directPlay / localRangeProxy / KSPlayer`。
- 内部首帧 1,632 ms。3 秒图黑且播放时钟约 1 秒，10 秒和 30 秒均实见片头画面。引擎选音轨 3 和字幕轨 5，字幕清单 8 条。文件名标注 DTS-HD MA 5.1，实测本次只记录 Speaker / decodedPCM，未独立核所选音轨编码、实际听音或字幕画面。
- 正常退出实见详情和「继续观看」，`iso_resource_released registeredCount=0`。未在本窗发跳转或续播。路线脚本 `0 playback(s) with route evidence, 0 to check.`，无容量决策行。原 Wi-Fi 图标、主屏幕和 App、Runner、采集及 8161 归零已核。私有证据入口 `/tmp/nastart-codex-iso2-20261113-current`。本批未改代码、模型或参数，未重跑单测。
