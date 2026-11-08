# 当前正常包：13与A16 iPad保留安装及主题静态窗口

2026-11-02。[结果](../../../testing/results/2026-11/CURRENT-NORMAL-DEVICE-UPDATE-20261102.json)、[首次预检失败](../../../testing/results/2026-11/CURRENT-NORMAL-DEVICE-PREFLIGHT-20261102.json)、[包来源](2026-11-02-THEME-ARTWORK-SIZING.md)。私有证据 `/tmp/nastart-current-device-verification-path`，原身份、偏好、进程、路径及截图未传Claude。

首次fresh核13/iOS16.3.1/USB和iPad15,7/iPadOS26.6/wired，签名包均通过；各发现1个Nastart进程，在任何安装派发前正确停止本轮操作，失败留存。用户随后确认两机已退出，并明确允许远程结束本项目App，不必每次手动退出。重新现场核身份及安装bundle实际路径，保存诊断/全偏好；停止前再核同PID/精确可执行路径，才仅结束各目标进程。未注销/清账号、卸载、安装WDA或改系统/网络。

13于06:59:09、Pad于07:00:09保留数据覆盖完成，安装success及fresh bundle lookup成立，进程0。正常Debug -Onone为06:41构建，main `56d9431957728339a65f2b34191567f724e723aeabc84d5d18137a9699bc19e8`、dylib `26b87a16d0e1648977024acff0f87df1272ecb500313af50cb782fa1658d6b54`，签名/profile/IPA重核。后续仅2个TV文件变化，移动415输入及iOS diff4f97dc8e未变；从原446快照在TV修改前冻结mobile-source-inputs投影，设备门禁用415移动输入，不伪称移动包编译了后来的TV源码。原446快照/包清单保留。

两机各2个显式theme-gallery隔离窗：中文辅助字号、英文标准，默认无测试环境，每窗前核无App，finally仅停本方PID并复核0。13看到Flow/Stack初始文字与Plus，辅助字号Flow说明/状态分行；Glow和辅助字号Stack后半段未滚到，不能称三卡全验。Pad英文标准三卡/状态/说明完整可见；中文辅助字号三图/说明可见，Glow Plus到屏幕下边界，不算完整后续状态验收。未点击/滚动/旋转/完整VoiceOver/实际应用主题；普通账号根仍会恢复NAS，故未启动。

13初图有中央绿色检查器遮挡；旧本方AXAudit检查代码曾遍历检查器。后用现有debug inspector API关闭visuals及app monitoring，另一次同包隔离窗中央遮挡消失，左上角仍有很小绿色边缘，不能称彻底清除或用户系统无障碍设置已改变。该补验亦finally停App、偏好同。

13的26项、Pad的19项非诊断及全部偏好在停止残留、安装和所有启动前后同值；Pad还直接对比停止前到最终完整偏好同。正常包留机，当前无本方App/Runner/采集。NAS0、蜂窝0、18/TV真机0、播放114格无新P。用户远程退出授权已记根AGENTS与登记；下一可直接核身份后处理已识别App，无须重复询问手动退出。
