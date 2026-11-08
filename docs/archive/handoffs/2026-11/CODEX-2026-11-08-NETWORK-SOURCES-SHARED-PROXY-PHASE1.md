# 网络媒体库接入共享原流代理

2026-11-08（北京时间）。本批接续[方案审查](CODEX-2026-11-08-SHARED-PROXY-PLAN-REVIEW.md)与[Range前置](CODEX-2026-11-08-RANGE-PREREQUISITE-AND-DEVICE-BASELINE.md)。设备故障与上一个正常包的 Jellyfin 实测见 [同日连接记录](CODEX-2026-11-08-JELLYFIN-LOGIN-AND-APPLE-TV-CONNECTION.md)。

## 实现

- iOS 的 `NetworkLibraryPlayerPresentation` 以现有桥接地址注册共享原流代理，监听注册失败时回退桥接。播放请求和代理共用 trace，保留来源上下文、扩展名和版本化续播身份。取消和迟到注册通过 lease 回收，UIKit 播放呈现保留 lease 到普通退出完成，PiP 最小化保留。测试覆盖 lease 释放后路由失效而原桥接仍可读。
- 外层路由限定本次桥接 URL，拒绝客户端重定向参数，使用现有有限32MiB上游续窗。桥接最多4个活动连接，第5个空体503。桥接交付统计保留下载计量，标记 `bridgeDelivery` 且不进入源端吞吐估计。
- 组合测试首次通过后发现 HEAD 诊断有同一区间重复续窗，修正完成路径以令 HEAD 只完成一次上游任务。一次测试断言错误使用仅 GET 会发的请求发起事件，记录5过1失败。改核 HEAD 的任务完成、终态索引及无续窗，最终6/6通过。取消健康探测也不会当作共享监听器失效。

## 验证与包

空白 iOS27 模拟器最终6项通过，覆盖双层尾部跨窗、反向读取、HEAD、可撤销路由、同服务并发隔离、4个活动客户端与满额恢复。各自有实例已删除。最新正常 Debug `-Onone` 签名编译成功，冻结于10:09:03，选定542项输入清单 `fae72d6dccea751980dd8708a688a8309edd760e550b60b0680ae19d96660318`，相对上一清单仅登记6文件变化。HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 和继承未提交改动保留。

- main `4f5f0ffe431e9ea09e7e917279d0d21bb967b38af91607dd7e6b212c62f1262e`
- dylib `97b358321cdd7652b866552e24bb25c65cd1ab800bf42c4afd92905bb3147d5f`
- IPA `d6d8069e1af7375f26b712acac27ff6f82c4deaa217045b55de6abd0f06ba02c`

31个Mach-O及包签名核验通过，22个独立命名的SMB导入绑定 LibSMB2，profile 覆盖13和A16 iPad，有效至11-15 08:30:17+08。冻结包在私有证据目录 `shared-proxy-phase1/normal-package/Payload/Nastart.app`，指针 `/tmp/nastart-codex-jellyfin-login-recheck-path`。仅保留匿名化结果。结构化结果见 [本批结果](../../../testing/results/2026-11/CODEX-NETWORK-SOURCES-SHARED-PROXY-PHASE1-20261108.json)。

## 真机结果与余项

13 fresh核名称、UDID、iPhone14,5 / iOS16.3.1 / USB，私存完整身份。正常97b3包10:09:42保留数据覆盖成功并fresh lookup，29项非诊断及全部偏好安装前后相同。既有Runner、空启动参数/环境。当前 Wi-Fi/LAN，经FTP媒体库入口从头播放5,467,405,922字节MKV《赌侠》。同trace看到 `route=sharedProxy`、`routeKind=localRangeProxy`、`sourceScheme=ftp`、原始私有网络来源、`upstreamKind=networkLibraryBridge`、`measurementBoundary=bridgeDelivery` 与206。播放图像和暂停控件实看，前进15秒操作后引擎目标19.254秒、恢复19.348秒，图中约00:19与实际画面。名义t3与t13采图实际约5.5/15.2秒，不用作首帧计时。预读仍 `0 / bytesNotMaterialized`。

普通关闭目标在下一次定位时已隐藏，没有提交关闭触摸。10:11:03用精确原生停止收窗，App/Runner为0，8102转发及采集结束，45秒独立守卫未触发。播放前后仅诊断和本地续播键变化。A16 iPad于10:12:39 fresh USB仍未出现，已请接回。用户确认暂不方便接回。本批未安装或运行iPad，保留上批bb4d安装身份。iPhone18未操作。Apple TV开发连接属于同日独立排查。

这次只验证13的一个LAN FTP短窗与一次短跳转。普通退出/真机PiP、SMB、WebDAV、iPad、真实首帧、实际声音/字幕与长时继续待测。有限窗口可能增加FTP控制连接重开次数的风险待以登录次数和同条件样本核实，无性能收益结论。下一步在当前签名包补iPad与各协议对照，再实现公共ByteReader路由与可消费启动预读。仍是30项/114格，无新增整格P。源码未提交，index和最终542输入复核通过。
