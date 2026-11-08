# TV正式确认框复用与原生输入未验证

2026-11-02。[结果](../../../testing/results/2026-11/TV-NATIVE-DISCONNECT-CONFIRMATIONS-20261102.json)。私有 `/tmp/nastart-tv-disconnect-native-path`。这是接续旧第二批原生确认/取消待验项，不是真实NAS退出验收。

只改TVNASViews与NastartTVApp两现有TV文件，2改/444同、移动415输入/iOS diff未变、原HEAD/index保持，Claude四文件未改。三处正式confirmationDialog抽为同一ViewModifier，原三种标题/按钮文案、destructive/cancel角色及空取消动作保持；三段清旧错/调用真实退出/捕获错误的回调原文各仍唯一存在，未改TVAppState、Keychain或logout。追加按钮AX标识供实际测试。

DEBUG仅在最早account-connections根额外带--offline-ui-confirmations时走新合成宿主，复用同一正式modifier，注入本地失败动作/次数。未创建TVAppState/账号/client，无网络。合成cleared标记不是正式回调运行证据；旧9状态检查不冒充新UI验收。

TV Sim Debug、unsigned Debug、Release三配置均过。自建tvOS27实例同包静态画面可见，初始旧错误及attempts0可见；guest AX没有App子树。Return/点击及临时键盘捕获下Return/space均没有实际弹框或次数变化，因此确认/取消/返回焦点均未验，保留失败，不重复同条件调参或换成程序直接弹框当通过。键盘捕获通过菜单关闭，窗口标题恢复tvOS27；finally停App/shutdown/delete、fresh不存在，哨兵同/0新增键。

下一使用项目现有TV UITests的XCUIRemote执行真实Select/Menu/取消/确认与焦点断言，不以编译或合成计数替代原生UI。TV真机发现/有效签名旧阻塞、NAS暂停/18不占用保持，114格无新P。
