# iPhone 13 单机接续（2026-10-01）

## 用户最新工作环境

未来几天使用 MacBook + USB iPhone 13，通过 VS Code Codex 插件及 ChatGPT 客户端继续优化；暂停 Codex CLI 专项。已验证的 WDA/Instruments/截图脚本继续作为底层工具复用，不要求用户再迁移工作方式。

- 当前可执行范围：iPhone 13 页面性能、基础播放/续播、远端 NAS 可达性、Lenna 同设备对照。
- iPad 卡滞/NAS专项、iPhone18蜂窝ISO、多设备并发保留待验；不作为独立iPhone13工作的前置，也不以本机通过代替其他设备。
- 到老家后不沿用“家中局域网”结论；现场记录Wi-Fi/蜂窝及实际媒体上游分类、直放/转码、样本、轨道和缓存。网络切换不主动修改NAS或设备网络设置。
- 每次仍执行AGENTS最新包门槛。采样采用本机已验证的 `DEVELOPER_DIR=/Users/lagransun/Downloads/Xcode.app/Contents/Developer`；现场预检，不推定不同会话权限一致。
- 调试中页面/方向/前台改变，立即中止该轮手势并排除结果；只操作现场确认的页面。

## 本轮门槛（20:33起）

现场USB iPhone13 `REDACTED-DEVICE-01` / iOS16.3.1，配对成功。源码最新文件仍AppTabRootView.swift 07:32:05，正常Debug二进制07:32:39，既有工作区保留。本轮deep/strict验签、dylib SHA256 `a79ae773cf5881908022b6b37db968f2c66b273cc6a9d59889f8be82d88f1ad0`核实，保留旧诊断后ios-deploy覆盖安装最终InstallComplete/Installed package成功，普通无变量启动及真实启动台截图确认。

固定WDA未重装，Runner69597；Instruments预检ready=true/problems=[]。开始启动台及媒体长列表采样，结果以下续记。私有证据：`~/Library/Application Support/Nastart/DebugEvidence/2026-10-01-iphone13-scroll/`。


## 第一轮采样与工具修正

启动台12次真实位移全部取得，但动作窗70.064秒超出原60秒trace，结果INSUFFICIENT；本轮22条hitch、最大66.734ms不能作完整窗口性能结论，也不以7.836ms/s不完整比率判FAIL。将采集默认限时改120秒、允许60～300秒显式配置，开始新手势前检查录制是否结束，防止继续发出无采样动作。15项既有工具测试通过。
