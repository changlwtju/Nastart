# TV 返回事件定位与焦点层修复

核对：2026-10-25 05:00。原始包、签名/UDID/偏好/日志/原生图仅本机私有证据，`/tmp/nastart-tv-exit-probe-evidence`文本指针。结构化脱敏结果见[JSON](../../../testing/results/2026-10/2026-10-25-tv-exit-event-probe.json)。保留[前批两轮失败与回退](2026-10-25-TV-PLAYER-EXIT-INVESTIGATION.md)，本批没有重新接受其callback、直接绑定或window手势方案。

## 新证据与接受实现

先给`KSOptions`增加DEBUG-only、无地址/账号/片源字段的有界交互回调，`KSVideoPlayerView`记录focus/exit，`TVNASPlaybackSession`将host/stop事件最多64条写入私有Caches。Release不编译记录与诊断入口。此观察版不改退出分支。

DEBUG无媒体夹具包含button、原TVSlide、未prepare的AV/KS播放器；不存在文件URL、禁用远程控制注册，不访问NAS媒体。模拟器与TV真机四种均能退回夹具根页；TV分别用1/2/3/1次Menu，不能当等价配对或一次返回承诺。TVSlide虽有吞非方向键嫌疑，实测可退，源码未改，不能将其定为根因。

观察版普通空环境S03真片出画后3次Menu仍未退；记录只有host.appear和focus变化，没有exit、host.exit或stop/disappear。故先前“dismiss/清理失效”没有事件证据，问题在本窗进入处理器之前。守卫主动停App、恢复正常首页与WDA设置，不当普通退出。

接受改动仅在tvOS实际视频焦点surface增加`.onExitCommand`，调用与根容器相同的`handleTVExit`：有控制层先隐藏；无控制层且focus.play才dismiss，否则移焦点。没有新callback/window手势，没有改变原stop/reset和fullScreenCover数据绑定。

同源码普通Debug签名包安装后，S03（54.01GB HEVC/DV标记MKV）及S01（2.95GB H264/AC3 MKV）各一窗，原生实际画面已逐张查看，各1次Menu回**同原目录/文件行**；返回前App PID未变，trace均为surface exit→host.disappear→stop.requested→stop.finished。证明本两窗焦点处理修复，不声称系统底层根因已全知或全入口返回已验。恢复首页时的显式正常重启与返回前同进程证据分开。

## 构建、安装与测试

- 现场重核客厅AppleTV14,1/tvOS18.2/paired/localNetwork，UDID一致；每窗重核508输入和当前冻结包。HEAD沿`4de732dd645b36671becff992cdef1d0163fd1e4`加原dirty。
- 27个Mach-O逐个及deep签名/依赖/描述文件设备/有效期/AppID与Keychain均核，2026-10-25 04:47:20保留数据覆盖成功。当前包为私有指针下`surface-exit/app-path`，此前`restored`稳定包已被替代。主SHA `b8b377279f8098a9e01798c4f6f3b964ef7429fb1466acd85908b96f109f8057`；Debug dylib `69d32fe565fcffb6c2c36ee96d4bfbf9d4e0e9306f3333f6dcc1d4a31f2ac0a5`；全部hash见JSON。
- 观察版32逻辑+5UI正式exit0；候选版32+5断言全过但driver未结束，确切自有进程最终TERM(-15)，不报整批成功。两项相关播放器UI随后独立正式exit0。
- 移动模拟器NonPlaybackPolicyTests：157执行、1跳过、0失败，正式exit0。tvOS普通Debug构建及Release无签名compile-only均exit0，Release未安装/未实机验收。
- 第一全夹具编译因新session主actor标注缺失失败，补@MainActor后成功；原失败和驱动中断均保留，不删除失败。

## 收尾与边界

两窗后实际正常NAS首页已看，普通空环境/空参数恢复；本批四个自有Runner均已核停，WDA设置还原，没有活动自有媒体/采集。完整偏好9→10，仅2条自然续播条目变化（包含S01新条目），其他值及glassDeck/system/海报5保持。未卸载、未清凭据、无蜂窝/网络/NAS设置变化，手机三台零设备操作。

字幕位置本批未改；S03可见中英字幕仍在视频底/黑边附近，不作为完整SUB或作者定位通过；未听音、未测帧时间/完整HDR/Release运行。28开放及114格不关闭。移动已装包早于本批共享Debug观察代码，不能称最新源码手机回归；下轮重新门禁/有效签名/构建安装。iPhone18于前批已完成最新无线安装，其实际DSM选LAN旧问题继续暂缓。

下一步：先共享字幕视频矩形/安全边距与作者画布映射，实际接入移动和TV文件入口；系统/服务端烧录适配能力单列。继续控件显示/轨道菜单及TVJF不同播放器的返回回归，不能以两个文件窗口关闭全链路需求。
