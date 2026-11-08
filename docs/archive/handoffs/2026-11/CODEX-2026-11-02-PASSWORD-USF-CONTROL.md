# Codex：密码首次编辑 A 的 U／S／F 对照

2026-11-02，12:15–12:17（Asia/Shanghai）。同一 `Claude-PW-iphone`（iPhone17 Pro／iOS27.0），复用与 F1 完全相同的已安装 Debug 二进制；0构建、0新模拟器、0真机／NAS操作。开始约4.016GiB，结束约4.007GiB。

| 组别 | 实现与窗口 | 初值→输入1字符后 | 结果 |
| --- | --- | --- | --- |
| U-r1 | 原生 UITextField 探针 | 12→1 | 替换 |
| U-r2 | 原生 UITextField 探针，fresh进程 | 12→1 | 替换 |
| S-r1 | bare SwiftUI SecureField 探针 | 12→1 | 替换 |
| S-r2 | bare SwiftUI SecureField 探针，fresh进程 | 12→1 | 替换 |
| F（历史） | 正式表单隔离宿主 F1，standard，无trace r3及补图窗 | 12→1 | 替换 |

F引用[已有F1记录](CODEX-2026-11-02-F1-BATCH7-8-INTEGRATION.md)，本轮没有重跑F或将旧F计作新增覆盖。U/S每轮均使用原生电脑控制点击密码框，再点屏幕键盘一个字符；初始12点、最终1点由AX与截图核对，四轮均有前／后截图，工具未拒绝。没有设置密码值、粘贴、显示密码或读取密码明文。

## 明确条件

U=`--offline-ui password-probe-uikit`，S=`--offline-ui password-probe-swiftui`；两者共同追加：

```text
--offline-ui-text-size standard
--offline-password-initial prefilled
--offline-password-secure secure
--offline-password-content-type on
--offline-password-modifiers bare
```

**不带 `--offline-password-trace`**；四轮结束均复核trace文件不存在。预填来自与F1相同的固定合成初值。内容类型 on 对齐F1默认条件，对应batch7方案的U2／S2条件；不是U1／S1的content-type off对照。`start-visible`只允许表单场景，未给探针传该非法旗标。

源码核对：U在`makeUIView`中先设置secure再设置合成初值，无delegate、无SwiftUI文本绑定、`updateUIView`不回写文本；S只有SecureField／状态绑定、样式和内容类型；两者均在SwiftUI宿主内，不构造NAS／账号对象。

## 归因结论

**按本轮U也复现的判据，A可定位为本机iOS27安全输入控件路径的替换行为；正式表单逻辑、显隐切换或SwiftUI自有字段桥接都不是其发生的必要条件。** 这支持用户提出的“安全输入框编辑预填值时系统清空／替换”的解释。

“内部先清空再写入”的精确时序未直接测量：本轮只记录前后圆点数，不含中间文本或trace；U仍由SwiftUI宿主承载，且本轮没有plain、content-type off、其他iOS版本或真机对照。因此不写成所有iOS条件下的系统保证，也不能据此判定已修复体验。显隐后焦点／键盘丢失是另一问题，未测试或关闭。

## 收尾与接续

逐轮核目标PID／实际可执行路径后只结束本轮App；最终App进程已退出，原模拟器保持Booted，未运行stop、未删除实例、未清缓存或偏好。447项输入／Git index与安装二进制哈希均不变。原始证据在`/tmp/nastart-codex-password-US-path`（四组完整启动参数、截图、无trace与精确退出证据、源码／包身份）。[结构结果](../../../testing/results/2026-11/CODEX-PASSWORD-USF-20261102.json)。

本轮完成指定四窗；不重复相同无改动矩阵、不改产品代码。下一阶段如需更强机制区分，另定plain／内容类型对照；显隐失焦独立处理。30项需求状态／114格保持。文档检查通过：630份文档／3894本地链接，缺失0。
