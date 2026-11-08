# iPhone 18 局域网 Wi‑Fi 更新安装包

2026-11-03最新：[用户本次授权的18无线更新](../archive/handoffs/2026-11/CODEX-2026-11-03-IPHONE18-WIRELESS-UPDATE.md)已完成保留安装，旧hands-off仅在该有界窗口内被新请求覆盖；窗口现已收尾，不转授Claude或持续控制。NAS尚未恢复，普通根/`--launch`仍不执行；安全离线前台结果/锁屏边界以报告为准。下文较早“18 hands off”是当时状态，不否定本次授权与实际Complete。

2026-11-02接续说明：本专册保留历史实现；统一分层、无线WDA建立方法与收尾见[真机远控手册](PHYSICAL-DEVICE-REMOTE-CONTROL.md)。当前18 hands off、NAS恢复暂停，不执行下文普通启动/`--launch`或设备探测；旧解释器、输入数量、profile和端点均非当前证明。

2026-10-27用户当前环境为iPad接Mac、iPhone18仅Wi-Fi；新认证修复包已用当前Bonjour身份→容器备份→AFC→InstallComplete/lookup→普通深色首页实看成功，27偏好同，见[本批](../archive/handoffs/2026-10/2026-10-27-IPAD-RECONNECTED-WIRELESS-IPHONE18.md)。这条成功不删除10-26两次安装服务超时；今后更新仍逐次核身份/新包/备份和正常启动，不要求用户先接USB。

适用于已与这台 Mac 配对的 iPhone 18（现场须重新核实为 `iPhone19,7`）。2026-10-15 将既有成功链路整理为可重复执行的发现及安装工具。本流程保留 App 容器，不卸载、不清除登录或书签，不更改 Mac VPN/网络、配对记录、手机系统或 WDA。

2026-10-24用户要求：iPhone18的DSM实际会话始终保持原域名＋端口，覆盖安装不得擅自改为内网IP。最新源码提供每连接“始终使用此地址”；可达后实际启用并核正常重启恢复，分别记录用户输入、Keychain配置、DSM session与媒体请求路线。偏好全同、安装成功或首页出现均不单证实际会话地址。原始域名/端口与凭据仅留本机私有证据；当前服务不可达时明确未安装/未启用，见[本批记录](../archive/handoffs/2026-10/2026-10-24-DSM-FIXED-ADDRESS.md)。

## 前提和能力边界

Mac 与手机接入相互可达、允许 Bonjour 的局域网，手机亮屏解锁。**同一 Wi‑Fi 名称不等于开发服务已接通**：已有配对、有效签名、服务握手以及 App 容器可读都要分别验证。访客网络/客户端隔离、地址变化或服务中断应先定位，不能据端口通或 Xcode 缓存记录判成功。用户当前仅无线连接时，继续排查无线链路，不把接数据线作为安装前提。

Apple 支持在配对后通过网络运行 App，详见[无线设备运行说明](https://help.apple.com/xcode/mac/current/en.lproj/dev3e2f4ee6d.html)及[Device Hub 管理设备](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)。以下 `pymobiledevice3` 路径是本项目使用的第三方协议实现，**不是 Apple 对其兼容性的保证**；本机核对版本为 `11.1.0`、`/usr/bin/python3`。升级工具后重新核对 API，不能直接沿用旧运行结论。

| 工作 | 本项目链路 | 是否依赖 WDA |
|---|---|---|
| 设备发现/身份核对 | 系统 DNS‑SD → 现有配对的 TCP lockdown → 实时 UDID | 否 |
| 保留数据更新 | HouseArrest 保存偏好 → AFC 暂存 IPA → installation_proxy `Install` → `Complete`/lookup | 否 |
| 正常启动/原生截图 | 配对 CoreDeviceProxy → userspace RSD → DVT ProcessControl/Screenshot | 否 |
| 当前脚本的点击/菜单/滑动自动化 | XCTest/WDA 会话与实际前台守卫 | 是，须另核 WDA 签名/会话 |

WDA 签名过期不构成重装 Nastart 或恢复 Xcode 自动隧道的前置条件。安装成功也不证明自动开发隧道、WDA 或播放回归通过；每层单独留证。原生 Xcode 自动发现不可用时，已认证的直接 Wi‑Fi 安装链路仍可能可用。

## 1. 先冻结当前源码的最新正常包

遵循 [AGENTS.md](../../AGENTS.md) 的逐台核包要求；从 [CURRENT-PLAYBACK-HANDOFF.md](../handoffs/CURRENT-PLAYBACK-HANDOFF.md) 确认本轮源码和正常 Debug/Release 配置。源码晚于产物、签名过期或目标不在 profile 中时先重新构建签名。`0.1.0/1`、App 能打开、另一台更新都不是当前安装身份。

准备仓库外的同批冻结记录：

- `current-package.json`：`head`、`sourceDiffSHA256`（当前 `git diff -- ios` 的 SHA-256）、构建配置/时间、`package`/`ipa` 绝对路径、`ipaSHA256`、`binaries` 三二进制哈希、`individuallyVerifiedLibraries`。
- `source-inputs-private.json`：冻结构建全部输入的绝对路径到 SHA-256 的字典，本轮为174输入（按实际冻结记录核对）。
- 本机私有发现配置：`udid` 和 `bonjourInstance`，后者取目标已读出的 `BonjourFullServiceName` 的实例部分。沿用目标标识用于发现，**每次重新解析和核实实时身份**；不要把标识、配对密钥、原始端点或偏好复制进仓库。

安装脚本会重核 HEAD、dirty diff、全部输入、App/IPA 哈希、IPA CRC及 Bundle ID、29库/实际库数签名、deep/strict 签名、profile 到期及目标授权。保存偏好后、上传前再次核对，避免准备过程中源码改变却安装旧包。

2026-10-18打包补充：IPA应只含实际的 `Payload/Nastart.app` 文件，排除 `__MACOSX` 和 `._*` AppleDouble 元数据。普通Mac归档可能把 `Payload/._Nastart.app` 一并打入，设备会以无法创建CFBundle拒绝安装；这不是无线断连或信任问题。保留失败包，重新打包后核CRC及三二进制哈希、更新IPA SHA-256，再发送安装；不需要因此卸载App或重新配对。

## 2. 系统 DNS‑SD 实时发现，核对目标身份

2026-10-17 补充：已知目标的 Bonjour 实例可能出现不同的 `supportsRP-N` 后缀。旧实例解析失败，以及 Xcode 显示 `paired / tunnel unavailable`，均不能单独判定直接 Wi‑Fi 安装不可用。本轮先用系统 DNS‑SD 浏览当前 `_apple-mobdev2._tcp` 广播，再与本机留存的同一目标配置匹配，选用当前确实存在的实例；重新解析地址并取得实际 UDID、型号及现有配对验证后，安装成功。不能凭后缀相似直接安装、沿用旧 IP 或更改配对。完整实例名和候选对应关系仅留本机私有证据。

2026-10-18补充：系统浏览暂未列出目标广播时，可对同一已配对实例执行当前DNS-SD解析，再核实际UDID/配对；本次浏览无目标而已知实例解析与直接安装成功，Xcode自动隧道仍unavailable。不能把“浏览无结果”扩大为所有直接链路不可用，也不能跳过实时解析而沿用历史IP。安装Complete后首次DVT启动失败，单独正常启动与实际截图随后通过，未重复安装；见[当次记录](../archive/handoffs/2026-10/2026-10-18-IPHONE18-HOME-WIFI-INSTALL.md)。

以下变量指向已有本机私有构建记录和配置；不要设置/覆盖 `HOME` 或 `CODEX_HOME`。输出目录每次新建，保留所有旧失败。

```sh
APP_EVIDENCE='/本机私有目录/本次冻结构建'
WIRELESS_CONFIG='/本机私有目录/目标无线发现配置.json'
RUN_ROOT="$HOME/Library/Application Support/Nastart/DebugEvidence/$(date +%Y%m%d-%H%M%S)-iphone18-wifi"

/usr/bin/python3 scripts/discover_paired_wireless_device.py \
  --config "$WIRELESS_CONFIG" \
  --output "$RUN_ROOT/discovery"
```

[发现工具](../../scripts/discover_paired_wireless_device.py) 用 `/usr/bin/dns-sd -L` 解析目标 `_apple-mobdev2._tcp`，再用 `-G v4` 解析当前地址；只接受当前 Add 地址，不把撤销记录当候选。先尝试广告端口，必要时仅在**同一解析地址**尝试标准 lockdown `62078`，不扫描网段、不自动配对。广告随机端口可能不讲明文 lockdown，不能把它的失败扩大为整台设备离线。

必须取得 `summary-safe.json` 中 `identityMatches=true`、`paired=true`；`verified-endpoint-private.json` 仅供下一阶段使用。新地址仍要以 `autopair=False`、既有配对记录和实际 UDID 核验，不能用历史 IP 或只读到名称代替。没有实时匹配即停止安装。

### 保存的广播名称失效时，按当前广播核实身份

2026-10-24实测：沿用昨天成功安装的同一目标与保存实例，本轮名称匹配/已知实例解析失败；对当前实际广播使用目标既有配对核身份，找到了真实iPhone19,7/27.0。因此名称不能作为拒绝当前目标的唯一依据。可显式运行：

```sh
/usr/bin/python3 scripts/discover_paired_wireless_device.py \
  --config "$WIRELESS_CONFIG" \
  --output "$RUN_ROOT/current-advertisements" \
  --browse-current
```

该模式仅处理最多4条当前DNS-SD广播，移除记录不作候选；每个地址仍使用目标既有配对、`autopair=False`与实际UDID认证，错误设备拒绝，无历史IP/子网扫描。失败证据分目录保留；服务可达不等于备份可用。本轮找到身份后，HouseArrest已有escrow的VendContainer、AFC/安装查询/开发握手仍断开；用户解锁后再次备份也失败，0上传/Install/启动。当前应记录“无线身份已核、备份服务受阻”，不能仍写全机离线、要求USB，或跳过备份。详[本批](../archive/handoffs/2026-10/2026-10-24-IPAD11-ONBOARDING.md)。

## 3. 保存数据，再保留容器覆盖安装

```sh
/usr/bin/python3 scripts/install_paired_wireless_app.py \
  --endpoint "$RUN_ROOT/discovery/verified-endpoint-private.json" \
  --manifest "$APP_EVIDENCE/current-package.json" \
  --inputs "$APP_EVIDENCE/source-inputs-private.json" \
  --output "$RUN_ROOT/install" \
  --launch
```

[安装工具](../../scripts/install_paired_wireless_app.py) 每次重连目标身份；先通过 HouseArrest `VendContainer` 保存 `Library/Preferences/com.changliwen.nastart.plist`（其中含凭据/诊断/书签，只能本机私存）。**直接 lockdown 路径若现有配对记录含 `EscrowBag`，启动容器服务时带上该既有授权**，不生成/替换配对记录、不读取或发送手机锁屏密码。RSD服务保持自己的认证路径。**备份失败不向安装服务发送命令**。随后 AFC 上传至设备暂存区、发送 installation_proxy `Install`，等待明确 `Status=Complete`，再 lookup `com.changliwen.nastart`。不调用卸载，不用删除 App 解决签名或连接问题。

实现须保留真实 provider 类型：`HouseArrestService` 根据 `isinstance(provider, LockdownClient)` 选择普通服务名或 RSD 的 `.shim.remote` 服务名。不能用不继承该类型的通用代理包装 lockdown；那会误选 RSD 服务名并返回 `InvalidService`。当前工具使用 `PairedHouseArrestService`，保持原始 client，只设置继承的 escrow 请求标志（API按本机11.1.0核对）。本次该工具初版失败已保留，正确实现随后完成真实安装。

只读探测可加 `--probe-only` 并去掉 `--launch`；它只核包、核身份、读取容器，不上传或安装。每次仍须使用新的 `--output` 目录。工具没有自动重试；发生断连后先看失败阶段，再开新窗口重试，避免不确定状态下反复覆盖。

`summary-safe.json` 分别记录：

- `preferencesSavedBeforeInstall`：安装前快照已保存。
- `installDispatchAttempted`：准备发送命令；不能当作已安装。
- `installCommandSent`：发送已返回；网络中断时仍可能存在交付不确定性。
- `installCompleteObserved`：确实收到 Complete，才有安装完成证据。后续清理/lookup/偏好读取失败不能抹去这个事实，应单列“安装已完成、验证不完整”。
- `postInstallLookupExists`：安装后 lookup 中确有目标 Bundle ID；lookup 的版本号不单独证明包哈希。
- `preferences`：逐值比较所有非 `diagnostics.*` 项，**包含整个书签对象**。键/值差异保留原始证据；先分析用户操作/延迟保存，不自动回写旧书签，也不宣称全部数据相同。

## 4. 启动与实际界面核验

`--launch` 在安装确认后使用配对 CoreDeviceProxy、userspace RSD/DVT，明确请求 `environment={}`、`arguments=[]` 的正常启动，保存 `normal-launch-private.png` 及启动后偏好。该方式不要求 WDA，也不暂停系统 remoted 或改变 VPN。RSD 自身仍要实时核对目标 UDID。

必须**打开原始截图实际查看**是否为 Nastart 正常首页、NAS 状态和播放器关闭；PID、启动请求成功、截图文件存在都不是实际首页证据。工具始终不自动把 `actualForegroundUIVerified` 设为 true，实际检查后另写审阅记录。锁屏/其他 App/启动失败均如实记为待验证；可由用户正常打开 App后继续核验，不能把普通启动改成测试环境启动绕过。

安装完成且实际正常启动验证完，才进入这台设备的最新包播放/界面/性能回归；回归另遵守[播放调试规范](../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)。

## 5. 按失败层排查

| 证据 | 可以下的结论/下一步 |
|---|---|
| DNS‑SD 无目标/无当前地址 | 重新核同局域网、Bonjour、客户端隔离和解锁状态；不要盲扫历史地址 |
| TCP 通但实时 UDID 不匹配/未配对 | 不是可用目标；停止，不覆盖其他手机，不自动重配 |
| lockdown 身份可读，HouseArrest 在 VendContainer 后断开 | 身份链路可用，容器服务不可用；保存故障，未安装。解锁后重试仍失败时继续服务层诊断，不能只归因为锁屏 |
| HouseArrest 可读，AFC/installation_proxy 不通 | 已备份但安装链路受阻；保留分阶段日志，未见 Complete 不报安装成功 |
| Complete 已见，lookup/后续偏好服务断开 | 安装已完成，后验证未完成；不要将其改写为“安装未开始”或盲目再次安装 |
| 安装成功但 RSD/DVT 失败 | 不撤销安装成功；正常启动/实际UI待查，WDA或Xcode自动隧道另行核验 |
| WDA 过期或无会话 | 影响该工具的交互自动化；不作为本安装链路失败原因，不按天重装 WDA |

必要时只读检查同一目标的 installation_proxy lookup、AFC 信息、已有 escrow 的服务请求或 userspace RSD，分别记录，不把“服务启动端口已返回”当服务协议可用。本机尚无 VPN 因果证据时不修改 Tailscale/Shadowrocket；用户已要求保持现有网络配置。无线受阻时明确告诉用户尚未安装及卡在哪一层。

## 6. 交接、隐私与可重复验证

当轮交接记录：现场型号/系统/无线身份核对、包源码/构建时间/配置/三SHA/IPA SHA、每次尝试时间和实际失败阶段、Complete/lookup、安装前后及启动后偏好比较、实际首页审阅及未完成项。原始设备名称、UDID/IP、配对记录、token、偏好、诊断和PNG只存仓库外私有目录；仓库内只放脱敏结论。勿用运行中的其他设备任务的全局 `/tmp/nastart-*-evidence` 指针作为新安装任务状态，给本次独立输出目录并显式传参。

工具验证（本机已有 Python 依赖，无需重装环境）：

```sh
/usr/bin/python3 -m unittest discover -s scripts -p 'test_*paired_wireless*.py'
```

11项覆盖错误设备拒绝、撤销地址过滤、同地址标准端口回退、备份失败阻止安装、备份期间源码变化阻止上传、完整书签比较、收到 Complete 后验证失败仍保留成功事实，以及既有escrow请求与普通/RSD服务名的区分。工具测试不代替真实手机安装/界面证据。

2026-10-19真实安装再次复现AppleDouble拒绝后，`verify_package`已在发送前显式检查IPA所有成员，拒绝任何`._*`或`__MACOSX`路径；相关无线工具现13项通过。旧包保留、同签名二进制清洁重包成功，见[当批记录](../archive/handoffs/2026-10/2026-10-19-INSTALL-AND-BOUNDED-PLAYBACK.md)。

当次执行结果另见[2026-10-15 无线更新记录](../archive/handoffs/2026-10/2026-10-15-IPHONE18-WIFI-UPDATE.md)。

2026-10-24当前广播模式新增移除/多接口、错误身份再正确身份、超过4条停止的3项测试；与原无线工具共16项通过，不能代替真实安装。
