# 2026-11-13 《变形金刚》(2007) ISO 双入口对照

接续 [设备文件基线](CODEX-2026-11-13-ISO-MISSION-IMPOSSIBLE-SAMPLES.md) 和 [Jellyfin 重登](CODEX-2026-11-13-JELLYFIN-LAN-RELOGIN.md)。iPhone 13（iPhone14,5 / iOS 16.3.1）USB、原 Wi-Fi、现装签名 Debug `c7cf76714bcc32a0426b1982b9c63e6ec3306700b8b14927577e99e1092ddfb2`，主程序 `9ee7f0c9264661c064ffc0ac0094f9e6633f43dbc19a8ed67474f1900329bdc1`。HEAD `8db1cc64`，开工 153 个未提交路径，500 个构建输入、两处二进制哈希、签名和 fresh 安装回执均核对。07:06:39 的签名构建有效至 11-15 08:30:17（北京时间）。现装 App 和 Runner 沿用，原生空参数、空环境启动。

## Jellyfin 同文件

- 重登后普通冷启动，库搜索《变形金刚》找到三部。2007 年版展开「文件信息」，文件名与设备文件的 `Transformers.2007.Blu-ray.x264.TrueHD.5.1.3Audios.MiniBD1080P-CMCT.iso` 相同。Jellyfin 的封装字段显示 TS，镜像文件扩展名是 `.iso`，实播索引证实 `indexFormat=udf titleCount=2 selectedPath=/BDMV/STREAM/00000.m2ts virtualBytes=28241829888`，同设备文件的主片路径和虚拟长度一致。首次滚动 WDA 超时，重新核当前位置再展开，未用同名 MKV 替代。
- 从头 `EDF8CB70`，`verifiedSameServerLAN selectedAddressKind=privateIP`，`directPlay / localRangeProxy / KSPlayer`。ISO 索引 1,017 ms，内部首帧 2,120 ms，3 秒截图黑且时钟约 1 秒，10 秒及 30 秒实见片头。音轨 1、字幕轨 6。设备文件从头的内部首帧为 1,645 ms，使用音轨 2。
- Jellyfin 向前约 15 秒，`seekTargetSeconds=49.9100667 completed=true`、`seek_recovered currentSeconds=49.9614 seekRecoveryMs=2180`。跳后图见中文字幕，背景为黑帧。正常退出实见详情及「继续观看」，`local_resume_save_boundary boundary=close audioTrackID=1 subtitleTrackID=6 subtitlesDisabled=false`，`iso_resource_released registeredCount=0`。设备文件上次目标 63.478 秒、内部恢复 8,976 ms。两个落点及音轨不同，不作速度优劣判断。
- 同进程续播 `D572803A plannedStartSeconds=64.0627333`，再次选中同一 UDF 主片，`requestAudioID=1 requestSubtitleID=6`，实选轨 1 / 6。内部首帧 8,866 ms，初始定位 5,369 ms。10/30 秒均有画面和中文字幕。设备文件的 65.619 秒续播使用轨 2 / 6，内部首帧 7,320 ms。前一窗运行至 17:55:46，驱动截止触发原生收尾，续播未采到普通退出诊断；收尾核 App、Runner、8161 和采集归零、原 Wi-Fi 图标。原始证据入口 `/tmp/nastart-codex-jf-iso-compare-20261113-current`。
- 本轮两条 ISO 播放在容量脚本为 `0 playback(s) with route evidence, 0 to check.`，该路径无容量决策行，不作复算验收。ISO 上游 Content-Range、实际听音和连续性专项未单独测。本轮无代码、模型或参数修改。

## 普通退出补验与会话恢复

- 22:11:37–22:12:36 重新核同包、USB、现装回执和原 Wi-Fi，普通冷启动。22:12:05 本窗日志再次记录内网 `library_failed httpStatus=401`、`session_rejected stage=library`，实际出现登录表单。没有搜索或播放。17:48 的冷启动成功和本窗失败均保留。
- 同窗诊断表明选中本地 HTTP 保存会话，公网 HTTPS 保存项属同一用户，后续恢复记录 `waitingForIdentity`、`candidateIneligible`。现有证据只证明本轮恢复未能接管 401，服务端拒绝令牌的原因仍未知。未读凭据、改账号或改服务配置。
- WDA 删除会话超时，随后原生核 App、Runner、采集及 8161 已停止，主屏幕仍有原 Wi-Fi 图标。私有证据入口 `/tmp/nastart-codex-jf-iso-exit-20261113-current`。恢复阻塞时未把 17:55 的强制收尾计成普通退出，后续先查会话恢复，再补续播普通退出及 ISO 资源归零。
