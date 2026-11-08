# 既有WDA链路复用与iPhone 18最新包更新

2026-10-20 22:42后按用户明确要求接续。完整原始身份、端点、偏好、截图和日志保留在`/tmp/nastart-pip-pause-observation-evidence`指向的本机私有目录`wda-reuse-and-iphone18`；不是新建安装/控制体系。

## WDA实际核验

现场USB重新读取13（iPhone14,5/iOS16.3.1）与Pad（iPad12,1/iPadOS18.3.1）的名称、型号、系统、UDID及连接，标识只私存。13调用现有`start_wda_iphone.sh`，显式XCODE_APP=/Applications/Xcode.app，持久签名fixture核实、已有8102 ready/固定host，脚本正常退出，不增加Runner或转发。Pad核已有签名/profile/目标授权与安装metadata，经既有native RSD/XCTest路径启动，无构建/覆盖安装；沿用已存在且目标UDID现场核实的8101转发。

两端ready=true/预期Runner Bundle ID后，均用已有`wda_capture.py --bundle com.apple.springboard --times 0`正常建立session、前台守卫、获取source/PNG，命令退出0。实际看图均为系统桌面、无PiP、可见原生Wi-Fi；finally恢复auto/idle10/cool2。这里只是系统UI/WDA健康，不是App最新包播放/帧时间回归；Pad App仍16:16旧包，测试其App前须保留数据更新21:39包。

Pad稍后Runner的DTX连接关闭，原生进程快照与自有host PID均已无Runner；真实异常保留，不能把早先source/PNG成功当长期稳定。旧清理助手两次断言要求App也不存在，但该WDA-only批次没有启动Nastart，现场仍有原旧包后台进程；没有向它发送停止命令，错误归为清理前提不适用，不宣称App已停。现有13 Runner及既有转发保留。后续单RSD owner的有界核验另记，不能据时间接近就断言断连唯一原因。

## iPhone 18安装与正常启动

用户本次新增明确要求更新18，取代旧“离家不操作”现场限制。按[现有无线流程](../../../development/IPHONE18-WIFI-UPDATE.md)和现有discover/install工具，系统DNS-SD实时重新解析，TCP lockdown核实际配对UDID/设备名，iPhone19,7/iOS27.0、USB不存在，未配对/改网络或VPN。无需WDA。

复用21:39:31.631055+08:00普通Debug/-Onone/Xcode27包，HEAD `4de732dd645b36671becff992cdef1d0163fd1e4`加原dirty；iOS diff `3ee22cab315329e2d27e6851d223bc506d51c868b73dda27da6b2dc798485642`。173输入、29库签名、整体签名、profile/目标授权、IPA CRC/AppleDouble检查与三二进制重核，没有重新构建：

| 产物 | SHA-256 |
| --- | --- |
| Nastart | `d7d45c2f117828d98e04638db439ca13f5ad0a5bf5e779371b9ddf9f5198cf24` |
| Nastart.debug.dylib | `267ccbb0c0fa4af9c5370145d7fe68bc630c8442f2c5cf9c098cae1582fcdee3` |
| Frameworks/KSPlayer.framework/KSPlayer | `d9c31bcda3f8a16a58ad4d595bc0bf9d3f74de51ed6c0998fb7844927156f18f` |
| IPA | `be8164a95245cf923f83a7878c9075a7d2ed860f612cafcc7a4a7c29af341341` |

22:42:48+08:00 installation_proxy明确Complete，随后lookup确有App；事前容器偏好已保存，保留数据覆盖一次，未卸载或清登录。安装后25项非诊断键/值全部一致，包含完整书签对象。

首次同命令DVT正常启动返回明确DTXNsError，未收到成功，不掩盖或重装。随后一次独立原生只读截图确认设备未锁；与App无关的界面内容只留私有证据。22:46单独使用已有normal_launch函数，实时RSD身份核对、environment={}、arguments=[]正常启动成功；实际打开原始PNG看到Nastart启动台、NAS状态正常/在线、播放器关闭及Wi-Fi图标。Jellyfin此图为未知，不扩大成全服务健康。启动后25项非诊断偏好再次逐值一致，不回写旧数据。无需人工动作，未发媒体播放或切蜂窝。

## 验证边界与接续

本批只验证最新包安装/普通首页与系统WDA控制；不新增任何播放、字幕/音频、完整PiP或帧时间P。新PiP实际诊断和导航级失败另见[暂停观测批次](2026-10-20-PIP-PAUSE-OBSERVATION.md)。51项WDA/17项暂停单测双Python通过，4私有集成；Swift14项断言13过/1跳过但两次测试收尾挂起，普通真机包build一次成功。28项需求开放不变。没有周期调度或结束后后台执行承诺。

## 单owner有界补核

22:51:50与22:52:52两次同一USB转发ready/固定Bundle ID均成功，相隔62.021657秒；期间没有第二个native RSD/DVT连接。随后精确SIGINT结束自有有界XCTest host，保留原转发和13持久Runner，未发App或媒体命令。它只验证这段有界控制可用，未证明此前DTX断连的唯一原因或长期稳定。用户随后提供18字幕失败截图，主任务转到实际字幕布局/PiP问题，停止扩展WDA工具。
