# NAS 登录异常响应停止隐式重试（2026-10-21）

接[文件会话提前发布](2026-10-21-NAS-COLDSTART-COMPARISON.md)，关联UX-05/CB-15与会话准备。28项状态不变。18离家暂停，不发设备请求或创建调度。

## 问题、依据与最小改动

只审查现有代码，没有重复采集12:26包的性能。发现DSMClient.login拿到success=true但没有sid时，会自然进入下一个API版本、再次POST凭据；空白sid还会被当成登录成功。另一个路径是postFormCall遇非2xx抛invalidResponse，shouldRetryLogin却允许换端点，恢复外层还能继续LAN发现后重登录。服务端是否已创建会话并不明确，不应把这些情况当作可安全重发。它们是代码与可控响应反例证明的缺口，尚无证据表明18旧长timeout正由这些路径触发。

修改只在DSMClient：成功数据中SID缺失或仅空白则抛missingSession、结束当前认证，不再自然递减版本；invalidResponse与missingSession都不允许端点/LAN认证回退。明确102/103/104的原兼容版本回退、建连前DNS/地址不可达回退保持；POST仍只用表单、不改证书/凭据存储，绝对18秒取消保持。12:26的FileStation先于可选LAN发布保持。未新增SID持久化或绕过鉴权。

## L0与正常构建

NonPlaybackPolicyTests125项：124通过、1设备端点配置缺失跳过、0失败，Xcode正常退出；15预检通过。新增反例覆盖成功缺SID/空串/空白SID各仅1次凭据POST，HTTP502经过真实POST解码→restore失败且不LAN重登，invalidResponse/missingSession恢复无回退；明确104后兼容登录仍2次成功。旧任务覆盖、取消、FileStation提前发布、绝对截止等同批通过。响应注入全部为本地URLProtocol，没有让真实NAS返回错误或清用户数据。

普通Debug/-Onone/Xcode2715:39:10.241904+08。iOS diff `6fd78d20f8d406a7794686d7e92c5316274b707ac12cac8a4a7dd52563d8d6e7`，IPA SHA `e0c196cf2195de31426041d4acfe7175298c06f1c1e618d6fbd903747ae2c877`。173输入、29库/三二进制/深签名、三设备有效profile、IPA CRC/AppleDouble与链接均核验；只因本批源码变更构建正常包一次。最新私有指针`/tmp/nastart-auth-response-evidence`，prior-private-root接12:26包；旧冷启动指针不当最新。原始安装身份、偏好、日志、截图和包只留私有区。

## 真机与结论边界

13现场iPhone14,5/iOS16.3.1/USB已保留数据覆盖；15:41:47–15:42:08空环境首页/NAS正常与已有目录5项真实图已看，25项完整非诊断偏好逐值一致。无Play/PiP/文件修改；自有App/syslog停、原生核无App、WDA恢复auto/10/2，原生Home/Wi-Fi图已看。正常成功不替代真机异常响应注入或速度验收，也不关闭历史API119/18timeout。

Pad现场iPad12,1/iPadOS18.3.1/USB，原生Home/Wi-Fi和无Runner基线已核。devicectl分配RSD设备失败（CoreDeviceError -1 / mobiledevice -402653181），保留失败，未把pending当完成。复用项目install_paired_wireless_app的install函数和原生USB RSD，核InstallComplete、安装后lookup和18项完整偏好一致；15:47:18–15:47:39空环境首页/NAS正常与同目录5项真实图已看。只复用现有签名WDA，无WDA构建/安装或新控制封装。App/syslog结束、WDA恢复auto/10/2；自有Pad Runner host精确SIGINT后原生核App/Runner均不存在，13持久Runner未动。

18仍05:31包、等待用户回家。没有蜂窝、SSID/VPN/系统/NAS改动，没有本批崩溃基线，不声称零新增崩溃；不复用旧竞品计时或新增播放矩阵P。竖屏两轮旋转效果未确认、实际文字/完整PiP仍待新证据，不追加同条件采集。

收尾：173输入、iOS差异、三二进制/IPA保持冻结身份，两台安装凭据匹配，自有批次Python host为0。技术路线、开发状态、总账、矩阵、PROGRESS与当前交接已同步；竞品条件核对后未新增对照状态。文档367份/1910本地链接、0缺失，git diff --check通过。
