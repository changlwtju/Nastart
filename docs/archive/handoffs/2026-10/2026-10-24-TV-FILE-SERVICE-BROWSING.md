# Apple TV 文件与服务浏览闭环

更新：2026-10-24 23:04（Asia/Shanghai）。[结构化结果](../../../testing/results/2026-10/2026-10-24-tv-file-service-browsing.json) / [全域差异](../../../project/APPLE-TV-FUNCTION-PARITY.md)。仅本批实现与证据，不关闭28开放需求或114播放格。

## 接受实现

- `TVNASFiles`新增名称/类型/修改时间/大小及升降序面板，采用DSM服务端排序，首批与续页传相同顺序。根共享目录只展示名称/修改时间，客户端防御性拒绝向根发送不支持的size/type字段。依据[Synology官方File Station API](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Package/FileStation/All/enu/Synology_File_Station_API_Guide.pdf)的List参数；未猜整页本地排序。
- 刷新/切排序清空旧页并取消旧任务；首批/续页均用代次守卫，页内跨页按path去重。仍为手动分页，显示“已加载/总数”；筛选明说只含已加载项目，不宣称全盘搜索。空目录、无匹配、缺失元数据分别呈现。
- 普通文件可打开只读信息，媒体/目录保留直接播放/浏览，长按有文件信息。真实大小/修改时间，文件夹inode大小不冒充内容容量，未知为“未提供”。排序与信息面板使用当前主题和明确返回；没有删除/移动/NAS写操作。
- 服务资源/容器/套件目录新增名称/镜像/类型筛选、结果数量、无匹配和清除，不改原发现记录/账号/服务可见设置。移动端已有相同四种排序方向、原生筛选和文件预览；TV本批补齐浏览差异，不宣称预览/共享业务层已一致。

## 当前源包与安装

HEAD `4de732dd645b36671becff992cdef1d0163fd1e4` 加原dirty；仅TVDSMClient/TVNASViews与协议测试改动，源清单508输入/末漂移0。手机源码及两机包未改、未操作13/Pad/18，不沿用它们旧窗口为新回归。

现场客厅AppleTV14,1 / tvOS18.2 / paired localNetwork，UDID与目标身份详情本机核过，原始数据仅私有证据。普通Debug冻结包为本机私有`file-service-browsing/tv/NastartTV-File-Service-Normal-Debug.app`，27 Mach-O/依赖/有效profile/目标设备/AppID与Keychain组全核；2026-10-24T22:40:30.976238+08:00保留数据覆盖成功，无卸载。主程序SHA-256 `d8dd24196ddf15c957c28b83b510b61ba99720df907100aa2c90be54b51a65a8`，debug dylib `5dd25e0f4c6568e7df69ab292e18d4b25618d693ee0129e345ae01a248a223b9`；空环境/空参数正常启动3/10秒原生NAS首页已看。

32逻辑+1启动UI成功，包括每页服务端排序/POST凭据、根目录参数降级、时间/缺测/文件夹容量、服务镜像筛选。首次Menu可用性编译失败保留，已用兼容tvOS16排序面板修正。

## 真机观察与收尾

16个观察检查点，不等于16完整功能场景：根降序/升序、子目录修改时间/大小、文本116KB真实信息、信息Menu/排序Menu/子目录→共享目录→启动台、服务目录46→Jellyfin1→无匹配→46、文件筛选无匹配/清除、服务返回设备及末启动台。详情/修改时间列表实际图已看。大目录第二页/权限错误/快速切序竞态仍需真机验证，不以协议测试替代。

23:03实读原始偏好全部保持，0键变化；glassDeck/system/海报5，事项/凭据未改。本批自有Runner23:02:18停止，设置恢复10/2，旧13 Runner未触碰。初始host中断和“完成”标签双元素/element-click超时均保留，先观察再采用遥控focus/select完成，不混为App崩溃。无播放/下载/蜂窝/NAS写入/云写入，因此无新增播放或竞品性能结论。下一批先重新核实际设备/当前包，再代表文件/JF播放。
