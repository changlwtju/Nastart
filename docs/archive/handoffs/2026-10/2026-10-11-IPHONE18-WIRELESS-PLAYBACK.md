# iPhone18 无线播放与书签边界取证

更新时间：2026-10-11T19:38:28.590016+08:00。本轮只推进 iPhone18 的普通 Wi-Fi 文件入口定向回归，App 源码未改；13/iPad 没有本轮最新包回归。结论为部分功能证据，未判定连续流畅、实际声音、DV/HDR、性能、竞品或完整矩阵通过。

## 最新包与设备门槛

- 重新发现无线服务并用既有配对实时读取同一设备名称、型号、系统及 UDID：用户称 iPhone18，本轮 ProductType=iPhone19,7、系统27.0，Wi-Fi/TCP可达、USB缺席。原始名称、UDID、地址、配对及偏好只留本机私有目录。
- 源码 HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`，iOS 未提交差异 SHA-256 `c6922e99474b4cc0f6ae1f6f2981fa76e0e2c6f9a4ec828e70dca7aae9e96305`；173构建输入与三二进制重核，其他未提交修改保留。普通 Debug / -Onone，17:36:31构建、17:38:03冻结；本轮无晚于产物的源码变化。
- 包为私有证据 `2026-10-11-startup-work-breakdown-173240/Nastart-Startup-Work-Breakdown-Normal-Debug.app`，同名IPA保留。主程序 `c86667effb6b441321a634bccca6372434393e86b5fb239fb7630a05179e4747`；Debug dylib `ee937c5646b45709ae98eaa81bb1136b352b4e386ce9c817e73a5a9ce3895f18`；KS库哈希及完整路径见[脱敏结果](../../../testing/results/2026-10/IPHONE18-WIRELESS-PLAYBACK-20261011.json)。29库/deep签名/链接/profile目标与有效期已核。App profile有效至UTC10月17日22:23:40。
- 19:18:03～19:18:13保留数据覆盖最新普通包，覆盖前后25非诊断偏好完全一致；没有卸载、清登录、清缓存。实际普通首页及空env/args已验证，每个播放窗口再次核当前源、包哈希、签名和新鲜配对TCP身份。S03前另一次有序终止/state1/空环境启动。
- 322测试/2跳过/0失败与15预检引用此前最终同源执行，本轮没有重跑或新增App测试。

## 无线WDA与原生Xcode分别记录

上一轮成功建立过的XCTest随后实际以 `ConnectionTerminatedError` 结束，本轮起始HTTP拒绝连接；此前已取得的首页证据仍有效，但不能沿用为当前可用状态。本轮检查了只读崩溃清单，重建正式 CoreDeviceProxy/RSD/testmanagerd/XCTest 会话，复用已有有效固定WDA，没有再次重装WDA或改网络。随后status ready、固定Runner ID、新session/source/screenshot/实际UI动作均成功，19:34:53仍ready。

设备上的两个已有WDA报告发生在19:09:33/19:09:36，符号包含XCTRunnerDaemonSession.sharedSession/XCUIDevice初始化断言；时间早于此前正式测试启动，不能据此认定后续连接断开的原因，也不能证明旧包确切签名过期时间。签名续签与已有WDA恢复见[上一轮](2026-10-11-IPHONE18-WDA-RECOVERY.md)。

19:34:53原生列表和详情均读取成功，但仍 paired / developerMode enabled / tunnel unavailable / DDI=false。WDA实际工作没有使这个原生状态恢复；原生隧道问题独立开放。Mac VPN/Tailscale/Shadowrocket、设备配对、系统、remoted和DDI配置未改。

## 两次实际播放

| 项目 | S01 普通文件 | S03 4K大文件 |
|---|---|---|
| 测量标签 | s01-wireless-r2 | s03-wireless-r1 |
| 请求观察窗口 | 30秒 | 90秒 |
| 播放前本地位置 | 1091.988秒 | 1506.876秒 |
| 合格时钟位置（非显示首帧） | 1092.105秒 | 1506.964秒 |
| 原UI退出保存 | 1123.572秒 | 1597.289秒 |
| 首callback→有效目标帧 | 194.360ms | 57.320ms |
| 有效帧前过滤数 | 200 | 9 |
| 实际截图 | t0旋转过渡；t1电影无spinner；t2/3/5/10/30电影 | t0/1预览准备；t2电影仍spinner及旋转过渡；t4/6电影无spinner；t10暗电影保留；t15/30/60/90电影无spinner |
| 轨道书签 | 音轨1、字幕关闭保持 | 旧音轨0/字幕0开启 → 音轨4/字幕关闭，未判恢复通过 |
| 自动HLS候选 | 未触发 | 全90秒未触发，不计候选40秒deadline结果 |

全部实际观测请求/响应时间、偏好读写窗口、早期黑/旋转/加载、取消与晚回调均保留；截图目标时刻不是精确采样时刻。完成请求实际分别在触摸后32.034/92.084秒，随后普通UI退出、0/1/3/10/15秒偏好观察完成。退出详情和t30/60/90原图已人工查看。媒体来源、续播点及缓存不相同，不拿这些数字给设备或竞品排名。内部视频enqueue/Metal完成、合格时钟与稀疏PNG不等于合成器显示首帧或逐帧流畅。

S01的6、S03的33条媒体响应均为有限Range且206/Content-Range起点一致；S03其中27条续段起点均等于同传输前段响应末尾+1，总媒体54005939750字节。未出现HLS清单响应；保留完整生命周期和取消记录，不据此宣称所有窗口完整交付或全传输验收。

### S03书签轨道差异

本轮原始书签音轨0/字幕0、字幕开启；无手动切轨，启动自动请求字幕0，但实际字幕清单为5、6、7、8、9，实际启用音轨4，最终保存4/关闭。源码在 `GreenfieldKSOptions.wantedAudio` 和directPlay字幕选项按源流ID选择；旧字幕0不在此清单已确认，旧音轨0来源与完整身份迁移尚未确认。不能把旧ordinal与当前stream index直接视为同一身份，不能断言新包产生新退化，也不能把这轮写成“轨道保持通过”。下一步以现在有效4/关闭做普通冷续播，并补旧编号来源、缺失轨道回退策略与实际字幕/音频验证；没有注入或改写书签来掩盖原始失败。

分析脚本原先强制两轮轨道保持的断言确实失败，失败记录保存；后续更正为独立 `sameTrackPreferences=false` 和未验收结果，未删掉这轮。前两次S01导航分别因用户前台切到ChatGPT、iPhone18实际底部设备按钮名为server.rack导致停止，均未开始播放；工具按现场实际名称修正后才采集r2，失败原图保留。

## 最终状态与下一步

19:33实际普通首页/NAS状态正常、CPU18%/RAM22%/磁盘63%，其他服务卡片此截图为未知；播放器关闭、空env/args、idle10/动画2已恢复。最终25非诊断键保留，24个非书签键完全一致，仅两条播放书签自然更新，其他书签无变化。播放前后只读报告清单相同、Nastart新增0/WDA新增0/Jetsam新增0；不排除延迟报告。

优先接续S03有效轨道冷续播与旧轨道身份、HLS完整候选deadline/分片/read/callback生命周期，再继续原生自动隧道。此前旧475秒差异、119/真实弱蜂窝、S03/S08/S11/S18/S19代表族、MTP/ISO/TV、AV/PiP/暂停预热、完整帧时间与声音、Lenna/DSOne/Jellyfin/Popcorn及全部未验PX/UX/CB/L2/L3/Main保持开放。本轮不改播放策略，不判全矩阵通过。

私有证据目录：`/Users/lagransun/Library/Application Support/Nastart/DebugEvidence/2026-10-11-iphone18-wireless-playback-191731`；所有设备原图/原始偏好/凭据、完整身份、XCTest及失败日志和冻结工具只留此目录。公开结果为白名单字段与传输别名，未写入原始设备偏好或网络凭据。

后续补记：有效4/关闭的普通冷续播已验证，旧0/0找到9月30日AVPlayer localRemux会话及组索引保存证据，精确原始流映射仍未取得；本页旧差异不改PASS。见[最新接续](2026-10-11-IPHONE18-COLD-TRACK.md)。
