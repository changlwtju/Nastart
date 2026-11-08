# iPhone 18当前普通包保留数据更新

2026-10-22 07:03起，用户新授权立即更新18，覆盖此前“稍后先其他工作”的设备暂缓条件。私有包链、名称/UDID/地址/偏好/日志/原生图仅留`/tmp/nastart-iphone18-current-update-evidence`，package-private-root指[05:26当前构建](2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md)；[安全结果](../../../testing/results/2026-10/2026-10-22-iphone18-current-update.json)。

## 核包与现场发现

173源输入、HEAD/dirty iOS diff、三二进制、29库逐签/深签、profile目标/有效期、IPA CRC/无AppleDouble均重核通过，无源码改动/构建/重包。普通Debug/-Onone、构建时间05:26:28.931374+08；diff `e65a8da17ea0db5e1a22d374c2bb79c5d5d8dd4eb4acb4a5fedd8f3057cbaa16`，IPA SHA-256 `45d213bafb07a70a3543980ff961388a817172e7e9176185f67c76fb2b1eaf9b`，三SHA见结果及包私有清单。

原已知Bonjour实例未解析、CoreDevice目标三主机名也无当前IPv4；尚未发送安装，失败保留。用户回复已就绪后原实例仍不解析，遂系统DNS-SD现场重浏览当前已广播服务，逐个解析其实际主机/地址，再用原目标现有pair、autopair=False及实时UDID匹配，不扫网段/不改配对或旧IP猜测。最终明确同一iPhone19,7/iOS27.0/名称/UDID，目标不在USB、直接Wi-Fi TCP62078已配对身份通过；广播标识本身不作设备身份。

## 安装已完成、数据保持

原工具先HouseArrest保存完整偏好，再次核源包、AFC暂存、仅发送Install，07:12:13.850823+08明确Complete，随后lookup存在；25项完整非诊断偏好逐值一致，包含整个书签。未卸载/清登录/回写偏好/改系统或网络。18已由10-21 15:39历史包更新为当前05:26普通包，不再写作仍旧包。

## 正常首页尚未核实

安装后正常空环境/空参数RSD/DVT启动请求失败，com.apple.dt.deviceprocesscontrolservice code2；安装Complete/lookup和完整偏好保持事实不撤销。另一次独立正常启动（无重复安装）重核同包、实时配对/UDID、RSD及容器并保存启动前原生图：图实际为锁屏，启动请求仍DTXNsError，未返回可确认新PID/正常首页。锁屏是实际观测，不将其倒推为两次失败唯一底层根因。第二窗NSError递归采集又遇到NSError无__cause__的助手错误；原失败trace/截图保留，私有采集助手用getattr修正，未因此再跑设备。

已一次据新锁屏证据请用户解锁、直接打开Nastart停首页；用户随后明确选择“稍后，先继续其他工作”，故首页继续暂缓，不再探测/切前台；等用户主动给条件后只读原生图补核，不重复安装/催促，也不靠PID或内部登录日志宣称首页/NAS/竖屏/PiP通过。0 Play/PiP，无媒体流；自有安装/启动命令与临时awake均已结束，WDA旧Security/签名支线未重试或重装。正常首页及用户原图回归待验，28项保持开放。
