# SMB祖先句柄生命周期与选根反例

2026-10-26接续[可变区/所有权](2026-10-26-SMB-VARIABLE-SPAN-AND-PAYLOAD-OWNERSHIP.md)，[结构化结果](../../../testing/results/2026-10/2026-10-26-smb-root-lifetime-boundary.json)。原型、补丁、原始断言、wire审计与构建在私有指针`/tmp/nastart-smb-root-lifetime-evidence`；本批未接App。

## 发现与局部候选

旧实现逐级CREATE确认后立即CLOSE，枚举完成又关闭根句柄，之后通过share相对完整路径重新打开NFO。3窗实际自有目录替换、根链接替换、嵌套祖先链接替换均返回并提交替换目录的`other-title`。文件长度、低精度创建/修改/变化时间相同，目录/CREATE/CLOSE版本比较没有证明目录身份，原子选根条件失败。

私有候选逐级保留最多16个祖先句柄，避免再次打开根，CREATE仅FILE_OPEN、只读访问、FILE_OPEN_REPARSE_POINT，ShareAccess由READ/WRITE/DELETE改为READ。所有NFO完成后逆序POSTQUERY CLOSE祖先，缺版本/标志、属性变化、关闭失败、取消或截止均不发布暂存；异常销毁独占context，服务端实见连接关闭。其他未提交App修改保持。

18普通候选窗通过；9 ASan窗中8原自动断言通过、1原子选根断言失败。覆盖普通/嵌套目录、替换、初始及后来NFO重解析、sharing violation、关闭失败/缺标志/属性变化及根/祖先关闭中取消、截止；失败窗保持旧库磁盘/内存/重载/TV小目录。ASan未报告失效内存，detect_leaks=0，非泄漏/TSan验收。

## 未接受的原子边界

夹具针对SMB共享删除约束的阻断是**服务端模型**，不是Windows/Samba兼容证明。独立`asan-nativeReplaceOnNFO`让夹具所有者实际执行本机目录替换，绕过该模型：候选仍成功读取4次NFO并提交`other-title`，四种旧库核对全部为false；原自动断言False完整保留。同秒低精度目录时间使关闭后比较也无法发现替换。因此候选仅缩小句柄空窗，**原子选根仍FAIL，不接生产，不声称零失败或已解决越根**；不再用重复时间戳/等待调参掩盖这个反例。

[SMB CREATE规范](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/e8fb45c1-a03d-44ca-b7ae-47385cfd7997)定义名称相对share、共享删除/重命名与最终重解析打开语义；[共享检查算法](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsa/8c0e3f4f-0729-49f4-a14d-7f7add593819)及[设置重解析](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsa/4aeefef8-92c3-4abc-af7a-a610caf8a165)还说明属性访问不能简单当作数据写共享锁。保留句柄不能被推导为所有本地写入/重解析ABA均受控。需要真实服务器的完整路径解析/作用域保证；未修改用户NAS、权限、VPN或安装服务来绕过。

## 收尾与接续

30自有服务窗口全部finally终止/wait，客户端视频READ/写请求0；仅自有反例按预定改动夹具目录，其他源保持。iOS/tvOS普通Debug arm64原型动态编译/vtool通过，未签名/嵌入；375本地App输入及冻结包30/27二进制零漂移，无App构建/安装/设备功能测试。

15:01现场CoreDevice/USB重取：13和Pad的USB可见、客厅TV连接；18/iPhone19,7/iOS27仍不可连且USB未见，未装本批。没有启动媒体/蜂窝或改设备偏好，不复用历史安装记录作为本轮回归。30需求14/5/11与114播放格保持，AV/KS未改。

检查其余解析时另发现原夹具返回SMB2.0.2、Raw客户端只提供2.1而旧C仍接受，且接收转换包前未核已建立加密会话；下一立即核严格协商/转换状态。当前全部明文夹具只证明局部控制/解析反例，不当标准服务器2.1/SMB3互通验收。原子选根独立保持开放，随后核真实SMB3/其余分配、许可签名与生产适配。
