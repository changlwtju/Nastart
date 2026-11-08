# 高清海报补全与客户端刮削方案

2026-10-25：新增[只读网络媒体库设计](READ_ONLY_NETWORK_MEDIA_LIBRARY.md)，用户明确WebDAV/SMB选定文件夹后，元数据、海报与纠错只落客户端，不修改NAS原文件/目录，不写回NFO或海报。完整网络源/扫描/刮削仍未实现；本文件的只读高清调研不冒充该产品能力。

2026-10-25 20:32补充：移动hero已按实际画布宽×displayScale请求880–2400/quality94并修同画布圆点/片名显示，普通13/Pad横竖实图已核；这只是原Jellyfin图片接口尺寸调整，独立高清补全/提供方替换仍未接入。

核对日期：2026-10-25。**状态：实证与设计，未接入产品。** [本批证据](../archive/handoffs/2026-10/2026-10-25-TV-DIRECTIONAL-SECTIONS-AND-HD-ARTWORK.md)／[结构化结果](../testing/results/2026-10/2026-10-25-TV-DIRECTIONAL-SECTIONS-AND-HD-ARTWORK.json)。

## 已确认的现状

Jellyfin存储的图片与NFO文字元数据不是同一个资源；4K视频不代表随附海报/背景图也4K。18条只读样本中原图既有500×750也有2000×3000，不能概括全库多数。maxWidth是上限，不能令低清源增加真实细节：白夜500×750实际仍500×750，奥本2000×3000可交付1000×1500。类别原生成图960×540的历史证据另见前批，不与影片原图混用。

客户端也有待优化项：移动普通网格固定请求540、相似片360，需按实际布局点宽×屏幕scale选择；横排已width×3。TV普通海报maxWidth1000/quality92，背景1920/详情2800，原1280背景可能放大。移动returnCacheDataElseLoad＋URL含imageTag，TV当前图片URL没有tag，应纳入失效策略。源图低清、请求不足、Thumb/Primary/Backdrop选择、截图压缩及缓存不能混为一种原因。分类已优先实际Backdrop，不表示全部图高清问题已解决。

## 两阶段工作范围

| 阶段 | 内容 | 工作规模/依赖 |
|---|---|---|
| 已识别媒体的高清图片补全 | 利用现有TMDB等明确ID与图片提供方；选高分辨率且匹配类型/语言的候选，本机缓存、缺图/离线回退、可恢复原封面；同一策略用于三端 | 中等；不必扫描整段视频或重新识别影片，但需要三端真机与缓存/滚动核对 |
| 设备文件独立自动刮削 | 文件名/年份/季集/特辑解析、多语言/同名错片处理、用户纠正、无ID检索、批量队列/失败退避与缓存 | 明显更大；单独阶段，不能将候选列表成功当完整刮削已实现 |

优先客户端缓存，不默认覆盖NAS海报或修改Jellyfin配置。Jellyfin来源先用已知ID精确匹配，避免重搜同名片引入错误；无ID/低置信度项须保留原图或待确认。物理像素预算、合理尺寸桶、有限并发/去重/取消代次、磁盘/解码内存上限和离线回退共同设计；不在每次焦点移动时向提供方重新刮削，不能牺牲启动或滚动速度。

## 实际可用的入口与边界

官方[RemoteImageController](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/RemoteImageController.cs)区分授权GET候选与需提权POST下载写入。本轮只用GET Providers/RemoteImages：既有TheMovieDb对已匹配白夜返回1200×1800中文候选，普通外部图片请求实际解码同尺寸。可据此做客户端本地补全，不必先重新注册外部账户；仍依赖NAS现有提供方/匹配ID及网络，不能称完全脱离Jellyfin。

完全独立直连数据源需另建适配器及合法可用的应用授权。TMDB的[图片接口](https://developer.themoviedb.org/reference/movie-images)提供候选，[配置及图片尺寸](https://developer.themoviedb.org/docs/image-basics)决定URL；[官方FAQ](https://developer.themoviedb.org/docs/faq)要求申请API凭据并说明来源标注/商业使用条件，尚未注册或取得。不能复制Jellyfin内置密钥或将NAS登录头转发到外部CDN。图片源没有高清图或身份匹配错误时，App自身刮削也不能保证高清正确结果。

## 尚未交付

没有新增产品开关/自动扫描/三端高清缓存/图库回写；当前实际路线继续从Jellyfin图片接口展示，上一批的分类背景优先已安装。接入后需分别核对电影/电视剧/动漫/分季/每集/演员/横图与竖图，普通和离线、账号切换、原图更新、不同列数/屏幕scale、低清与缺图、滚动帧时间及蜂窝只读图片开销。图片检索不改变影片播放/Range/解码/源轨选择。
