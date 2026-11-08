# iPhone 18 晚间最新包安装与正常首页核验

2026-10-22 21:58–21:59。用户再次要求安装最新包，解除早间首页暂缓。本轮重新执行现场发现与核包，没有沿用早间设备在线结论。[结构化结果](../../../testing/results/2026-10/2026-10-22-iphone18-evening-install.json)。

- 现场DNS-SD当前广播与地址解析，使用既有配对、autopair=False及实际UDID核同一目标；设备名称/UDID/连接状态已本机记录，型号iPhone19,7、iOS27.0、Wi-Fi。原始身份、端点、偏好和图只在私有指针`/tmp/nastart-iphone18-evening-evidence`。
- HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`及保留dirty，173源输入与05:26普通Debug/-Onone包一致，iOS diff `e65a8da17ea0db5e1a22d374c2bb79c5d5d8dd4eb4acb4a5fedd8f3057cbaa16`。三二进制及IPA SHA、29库逐签/深签、profile目标及有效期、IPA CRC和无AppleDouble均再次核完；无新构建、源码改动或测试重跑。构建时间05:26:28.931374+08；IPA SHA-256 `45d213bafb07a70a3543980ff961388a817172e7e9176185f67c76fb2b1eaf9b`，三SHA及私有包路径见本轮结果/包清单。
- 先保存完整App偏好，重新核包后仅Install保留容器覆盖；21:59:14.330128+08明确Complete，随后lookup存在。安装前后25项完整非诊断偏好逐值一致，包含整个书签；启动后再次比较仍全部一致。未卸载、清登录或回写偏好。
- 同一实时RSD身份下以environment={}、arguments=[]正常启动成功，原生截图已实际查看：正常Nastart启动台、NAS状态正常/在线、Wi-Fi图标可见，无播放器/PiP。这只补齐18当前包安装及正常首页有限切片，不继承为字幕、原画、seek或PiP验收；早间两次DTX失败及锁屏证据保留，未定其唯一根因。
- 0 Play/0 PiP、未开蜂窝或更改NAS/VPN/系统，无自有媒体/安装采集遗留；没有为安装重试WDA。28项需求继续开放。后续18原片竖屏/完整字幕与PiP仍待独立条件，当前任务先推进13按钮seek缺口。
