# iPhone18 解锁后安全启动补核：安装有效，前台未验

2026-11-04。用户回复“已解锁”，只接续[昨晚无线更新](CODEX-2026-11-03-IPHONE18-WIRELESS-UPDATE.md)尚缺的安全离线前台检查。[结构化结果](../../../testing/results/2026-11/CODEX-IPHONE18-UNLOCKED-STARTUP-20261104.json)。不重新安装、不启动普通账号根、不扩大到NAS/WDA/其它设备。

## 最新包和fresh身份门槛

本轮重新读取进度/当前交接、协作登记和真机手册，取得18独占窗口。当前447扫描输入逐项同，HEAD/dirty iOS diff同冻结包；重核App/IPA/30 Mach-O、库签名、CRC/成员、profile有效期与真实目标覆盖。正常Debug -Onone main `2090db4219666643c062b899ab376d7d1cc1edfd2dc164ca6909f6f3d1919c6b`，dylib `8a1e979bb59c4a593068e8150a9b34bbd825a8a45ad7eec47cbbf33f2afe7605`，profile到 `2026-11-08T01:08:19Z`。沿用11-03已Complete/fresh lookup的包，无需重编或覆盖。

当前DNS-SD重新解析并认证既有配对：iPhone19,7 / iOS27.0、Wi-Fi TCP、目标不在fresh USB清单；设备名/完整UDID/端点私存。直接Lockdown及userspace RSD同目标，fresh安装lookup的实际容器Path与昨晚经过核签安装的回执相同，不以版本号证明身份。启动前保存必要偏好/诊断，Nastart0；没有未知或他人会话接管。

## 两窗实际结果

1. `2026-11-04T06:17:23.943271+08:00` 至 `2026-11-04T06:17:41.324415+08:00`：显式安全离线source-add场景，environment为空，ActivateSuspended=True；启动成功且PID实际可执行路径精确匹配目标，但实际原图仍为用户其它App。不是锁屏，也不是Nastart前台。finally停止本方App，fresh Nastart0，全27项/全部偏好同。
2. `2026-11-04T06:18:54.493994+08:00` 至 `2026-11-04T06:19:11.139212+08:00`：仅补一次有历史依据的原生激活对照，先False新启动，再对已核PID/路径以True激活；返回同一PID，前后两张原始分辨率截图均已实看，仍是其它App（其中一张处于设备转场/方向变化，不能当产品旋转结果）。未对其它App点击、按键、切菜单或结束其进程。finally仅停止本方Nastart，fresh Nastart0，全27项/全部偏好同。两窗无改善后停止，不继续调参数或反复唤起。

**结论**：昨晚无线最新包安装成功、身份有效的结论保留；本轮原生启动/同PID激活返回并不能证明前台呈现，前台检查仍为未验。具体系统/前台激活机制未证，不定为App崩溃、代码UI缺陷、签名或NAS故障；不因为这一点重装或清数据。旧锁屏图和本轮失败图均保留。

每次只请求 `--offline-ui source-add --offline-ui-theme glassDeck --offline-ui-appearance dark --offline-ui-text-size standard` 及中文语言参数，environment={}；该场景已审不构造真实网络库客户端。未启动普通根、未建立DSM实际会话/视频路线，域名/端口/Keychain/网络设置不改。与昨晚安装前全偏好跨窗全值同：`True`；原始内容仅私有区。NAS请求/播放/蜂窝任务0；无新WDA/Runner/系统配置，13/Pad/TV未操作。

## 收尾与接续

App0，自有Lockdown/DVT/RSD/隧道均已关闭，18独占窗释放，无持续采集或后台控制。产品源码及真实index保持，私有指针 `/tmp/nastart-codex-iphone18-unlock-path`。更新PROGRESS/当前交接/开发状态/资源登记，将“待解锁”改为“已解锁但原生前台未核”。唯一需求总账/播放矩阵/播放技术路线已核对，本轮无实现或验收状态变化，30项开放/114格无新P。

NAS仍须等待实际恢复确认；不因用户预计本周修好就提前探测。此支线保存现场后暂止；后续明确独占窗口可另查原生前台激活，或NAS恢复后在获准普通启动条件下验证，不要求重复解锁/更新或修改域名来绕过。文档检查通过：661 documents / 3947 local links，Missing destinations: 0。
