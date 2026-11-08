# 2026-10-18 iPhone 18 回家后无线安装最新包

更新：2026-10-18 07:31北京时间。当前现场见[接续交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)；本次只恢复18安装与实际普通启动核验，播放性能仍按[需求总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)开放。结构化结果见[无线安装结果](../../../testing/results/2026-10/IPHONE18-HOME-WIFI-INSTALL-20261018.json)。13/Pad上一批回归保持原归属，见[公网优先修复](2026-10-18-PUBLIC-FILE-PRIORITY.md)。

## 授权及实时身份

用户新回复确认18已接入与Mac相同的家庭Wi-Fi，并要求继续；据此恢复此前因携机离家暂停的安装工作。每个服务连接均重新核现有配对与实时UDID，目标确认为 iPhone19,7 / iOS27.0，USB不在、直接Wi-Fi TCP连接；实际设备名称、UDID、端点和配对资料只在私有证据。没有自动重新配对、切VPN/网络、卸载App或清除登录。

07:24系统Bonjour浏览没有匹配到目标广播，Xcode27清单与详情仍显示paired、developer mode enabled、tunnel unavailable。随后对本机留存的同一已配对实例重新DNS-SD解析，取得当前地址，并在同一地址62078读到匹配的实时身份及配对。不存在“未广播就换历史IP安装”或网段扫描。Xcode详情请求exit0只证明该请求返回，不能当自动隧道已恢复。

新证据独立指针 `/tmp/nastart-oct18-iphone18-evidence`，不会覆盖13/Pad正在使用的指针；原始安装/偏好/截图/失败日志均在仓库外本机私有区。此前所有失败保留。本批没有后台发现、轮询、定时安装或重试。

## 当前源码与包

复用已经冻结并在13/Pad验证的最新普通包，本批未改App源码或重建。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`；含未提交修改的ios diff SHA-256 `69b11f328bdf63192e3dfbd9df7fa042e587fc9f0891a05646c4d66870b6c24f`。173构建输入逐项哈希、HEAD/dirty diff、App/IPA、IPA CRC、29动态库、deep/strict签名、目标profile授权及有效期均重新验证，安装备份后上传前再核；结束仍匹配。

Xcode27.0/27A266a，普通Debug/-Onone，06:24:02构建的 `Nastart-Public-File-First-Normal-Debug-Renewed.app/.ipa`；正常空环境和空参数，未注入测试条件。开发签名有效至 **2026-10-25 06:23:57北京时间**。

| 产物 | SHA-256 |
| --- | --- |
| Nastart | `36e06e744cf26780bbe04e290c99b723186f0a739cb586c33682c7e66abeebf2` |
| Nastart.debug.dylib | `cc148fe87cd80e24410696a186b55d76d2cc03add18f0d13bcc006262ee10e39` |
| KSPlayer | `deacdd11f289ce60b1222de4b954fb32c3a3175e1dd6a78524c99379342cdf0e` |
| IPA | `970670a67a2fff5e03a0ddad511451ac76fa7cd8b700aff1646708687de44fe4` |

包的绝对路径在私有current-package.json。相同版本号、旧App进程或Xcode在线均未用作安装身份依据。本批没有重新运行已通过的同源27定向/61工具测试，历史全套5失败仍开放。

## 安装与数据保持

调用现有[无线安装工具](../../../../scripts/install_paired_wireless_app.py)，使用原始LockdownClient类型及既有escrow授权，HouseArrest完整偏好备份成功后，才AFC上传并发送保留容器的installation_proxy Install。07:26:51.859明确收到Complete，随后lookup存在目标App；这与此前备份断开、命令未发的失败不同，本次安装已经完成。

安装后25项非diagnostics偏好键和值全部相同，含完整65条播放书签对象；普通启动后再次读取仍逐值一致，未回写旧偏好、删增书签或改音字幕选择。诊断条目允许正常增长，原始凭据及完整偏好仅本机私存。

## 普通启动与实际截图

安装脚本首次配对CoreDeviceProxy→userspace RSD→DVT普通启动返回DTXNsError。脚本保留了Complete、lookup及数据一致的成功事实，整体exit1归类为“已安装，后验证不完整”，不能写成未安装或盲目覆盖第二次。

随后只读原生观察重新核RSD身份，读到安装后新启动的Nastart前台进程；07:27截图实际打开查看，显示正常启动台、NAS状态正常、Jellyfin在线、播放器关闭。进程或PNG文件存在本身没有被当作实际UI验收。

07:29追加一次独立正常启动，明确 `environment={}`、`arguments=[]`、无悬停调试，DVT返回启动成功；新原生截图再次实际查看为正常启动台，播放器关闭、Jellyfin在线。此时冷启后的NAS卡暂显示未连接，不能将前一张“NAS正常”直接沿用为最终冷启已恢复，亦不能以缓存CPU/RAM数值冒充实时状态。启动后25项非诊断数据仍相同。首次DTX失败原文保留，未判定唯一原因。

安装和普通UI完成不代表WDA自动化、Xcode自动隧道、双入口播放或蜂窝性能通过；本批没有安装/启动WDA、播放影片、切换手机网络或操作13/Pad。

07:31只读后观察实际前台已切至其他App；停止18进一步采屏、启动和交互，不抢占用户前台，其他App内容不写入共享报告。最近一次Nastart普通首页证据仍为07:29，不以此后非Nastart画面宣称NAS恢复或App崩溃。后观察偏好仍为25项逐值相同。

## 接下来

18最新正常包安装与启动已完成，后续真机回归仍要重新核设备/源码/当前包身份；勿继续按“等待回家/尚未安装”处理。当前未安排后台任务。下一批优先13/Pad的S19/S03双入口持续播放、候选分片及对齐，18的最新包播放回归、冷启NAS恢复和此前系统UI Automation授权分别核实，不把安装成功迁移为性能验收。
