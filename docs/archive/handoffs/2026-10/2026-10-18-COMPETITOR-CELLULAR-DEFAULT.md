# iPhone 13：Lenna 默认播放与蜂窝等待补证

2026-10-18 23:48，关联 PX-01～03、PX-05、PX-18、PX-20；需求状态只在[总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)，本批不关闭编号。[安全结果](../../../testing/results/2026-10/COMPETITOR-CELLULAR-DEFAULT-20261018.json)。执行[竞品矩阵](../../../testing/COMPETITOR-DEVICE-MATRIX.md)；本批为默认体验探索，**有效受控配对0，不能排名或验收性能**。

## 包、设备及动作范围

App源码未修改、未重编，沿用19:30:39普通Debug/-Onone、Xcode27包。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，ios差异 `636ee55a19c09aa0ec243d92784c9359005a88c47964e43fb10c4aa3a4421a59`；173输入、三二进制及deep strict签名重核。三哈希见安全JSON和[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)。包路径仅本机，指针 `/tmp/nastart-oct18-cooldown-evidence`。

13名称、UDID、iPhone14,5/16.3.1、USB连接现场核对；先留诊断，23:06:29保留数据覆盖安装成功，25项非诊断偏好完全保持，空环境实际首页已看。每轮Nastart及收尾重新通过身份/包守卫。Lenna安装清单1.0.17(610)，未更新、清缓存或改配置。iPad、18和TV本批未操作；18最新覆盖仍是[20:19那批](2026-10-18-COOLDOWN-DEVICE-RESUME.md)，正常前台/播放未验，不抢前台或反复安装。

## 新窗口与可见结果

| App / 网络 / 素材 | 观察窗 | 实际复核 | 路线与退出 |
|---|---|---|---|
| Lenna / Wi-Fi / S01从头 | 30秒 | t2黑屏转圈、t3片头、t30推进且有字幕 | t5/30 DirectStream无转码信息；关闭查找失败后主动终止，非普通退出 |
| Nastart / Wi-Fi / S01从头 | 30秒 | t1已有压制片头、t2/3正片片头、t30推进 | 2项URL metrics cellular=no、报告stall=0；普通返回详情已看 |
| Lenna / 蜂窝 / S19约6775秒续播 | 90秒 | t1黑、t2影片、t3/10/30/60/90不同画面，有中文cue | t5/30/90 DirectStream无转码信息；普通返回详情已看 |
| Nastart / 蜂窝 / S19约6852.7秒续播 | 90秒 | t3/5/6黑、t10影片+缓冲、t30/60/90推进，后段中英位图字幕 | t30 DirectPlay、t90 Transcode 4Mbps/853×480；32项metrics全cellular=yes、报告stall最大2；普通退出 |

计划tN不等于实际截图时刻，详见JSON。计时从原生click请求开始，**未直接量到触摸释放**；不是正式CB-01。S19 Lenna最后无画面/首个有画面的保守范围为动作起点后1.260～2.424秒，Nastart为6.002～10.437秒，只能分别描述。Nastart内部first_frame=11.305秒，晚于t10已见画面，不能当屏幕首呈现或与竞品排名。S01 Nastart已复核片头上界2.327秒，下界未观测。

服务器S19的item ID/media source ID/path逐项相同，实际值仅私有。但续播点不同，Lenna轨道索引未上报，Nastart PGS=8；S01 Lenna有字幕而Nastart关闭字幕。缓存未知，之前另有意外Wi-Fi S19播放。Debug/App Store、横竖屏、截图/偏好读取开销亦不同，无5对有效重复，无连续帧/听音证据。不报相对优劣、P95、AUD/SUB/HDR/稳态流畅通过；Lenna Dolby P8标记不是实际HDR输出证明。

## 首帧阶段与预测带宽

Nastart S19引擎open约701ms、streamInfo1645ms、initialSeek3407ms，首视频包约prepare+6062ms、输出API入队+7844ms，再到内部时钟信号。不同异步边界不可直接相加。首上游请求在动作后1.815秒即发，issue→首正文约195ms，不能说整个首帧前均无下载。尾部4,823,696字节请求完成于+6.946秒，正文2538ms；尾部内容是否索引尚未解析证明。

自动转码请求+13.205秒、兼容流提交+30.882秒，均晚于t10原流画面，不能解释全部首帧延迟。请求时sourceBitrate81.85Mbps、runtimeDemand67.22Mbps、前方缓冲0.437秒，采用completedTransfer15.202Mbps。源码PlaybackRecentThroughputStore取完成样本低四分位，优先于6秒内正文窗口；两条完成样本约15.20/49.70Mbps，选值与整毫秒截断的区间一致。正文窗口+9.575/+11.579/+13.602秒约40.22/56.06/51.66Mbps。

已固定“较慢尾部完成样本压过更新正文窗口”的实例。反事实只用+11.579秒正文，当时静态source>capacity×1.5为假，但下一窗口又可为真，缓冲也不足；**不能认定无需转码，更不能直接优先最新高速值当修复**。下一步先分离启动/尾部/可播放媒体的样本用途，固定慢→快和持续不足反例，验证不会推迟必要恢复，再局部修改。保留60秒预测冷却、反应式恢复及格式族回归门槛。

两App均有实际PID对应pdp_ip0公网同端口元数据，无载荷、解析错误0。Lenna捕获+83.085～99.092秒跨过退出，Nastart为+40.994～57.000秒、已为兼容流。窗口/阶段不同，含缓冲交付和双向字节口径，**不能由62.98MB/6.37MB计算速度、总用量或容量**。未改VPN/基础网络，端口相同不证明协议相同；Nastart metrics有h2，不能替Lenna补协议。

## 失败、收尾与接续

- 搜索键按Button查找失败后用键盘Return提交；转场瞬时截图与随后源树不同，另看稳定图。工具边界不计App失败。
- Lenna长按“继续”意外启动S19 Wi-Fi，关闭查找失败后主动终止；无有效计时，实际时长没有90秒守卫，不能混入上述90秒窗。
- Settings指针动作没有关Wi-Fi，实际校验失败保留；之后新源树原生Switch click成功，才采蜂窝。收尾Switch=1，S01 Wi-Fi图和cellular=no已证明重新关联。
- 24项非书签偏好不变，36条原书签五项轨道不变、无移除/新增，2条自然断点变化；新增Nastart/WDA/Jetsam报告0。原生条件0，WDA10/2、空环境实际首页已看、播放器关闭。即刻首页NAS卡片未连接且探测未完成，不推断NAS故障或已核正常。
- 23:42准确device ID的两款App服务器行均无NowPlaying/TranscodingInfo；不等于全部编码进程验收。首/中/末电源断言已留，同窗系统Sleep/Wake0，自有有界保活已结束，原13 WDA服务running保留。

私有证据 `/tmp/nastart-oct18-competitor-evidence`，工具 `/tmp/nastart-oct18-competitor-tools`。原图/偏好/身份/服务器行仅本机。App未修改，不重复计前批XCTest为新测试；本批执行文档校验。全部未验收目标、iPad/设备文件及受控竞品验证继续保留。DSM与TV连接恢复暂缓，不升级、重置或改变NAS/VPN。
