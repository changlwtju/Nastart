# Jellyfin 搜索与海报布局修复

日期：2026-09-08。沿用 ADR 0002；真机和 NAS 访问仅局域网。

## 修改

- 搜索结果、电影/电视剧媒体库与收藏共用的 JellyfinGridPosterCard 改为由 2:3 基础画布决定尺寸，图片通过 overlay 填充裁切，避免原始横向剧照撑开网格。
- 标题最多两行并预留两行空间，超长尾部省略；副标题保留一行位置，使同排海报与年份/时长对齐。保留服务端原始片名，不根据文件名猜测并破坏标题。
- 搜索请求完成后检查任务取消状态，避免旧请求迟到覆盖新检索词的结果。
- 新增 [杜比播放路线](../../../project/DOLBY_PLAYBACK_ROADMAP.md)，明确能力识别、原流保留、回退与设备/音视频验收；未宣称杜比支持已实现。

## 检索结论

直接查询当前 LAN Jellyfin，SearchTerm=tran 返回 12 项，包括 Transformers 和 Strange 相关电影/单集/剧集。Strange 包含子串 tran；匹配也可能来自 OriginalTitle。因此此处主要是布局损坏，不能将这些匹配直接当成错误结果删除。保留服务端搜索语义。

## 验证

- build-poster-grid.log：iOS Debug 构建通过；install-poster-grid.log：iPhone 13 安装成功；preflight-poster-grid.log：项目检查通过。
- 真机正常 Jellyfin 媒体资源库入口搜索 tran，search-tran-final.png：横向剧照与电影海报同宽同高，长英文标题无跨列重叠，副标题与行间距一致。
- 电影库检索黄飞鸿，movie-posters-final.png：三张电影海报比例一致，中英文长度变化不会破坏列布局。
- 视觉修复不需要重复播放器、ISO 或整套电视矩阵；iPad、辅助功能大字号以及搜索请求竞态的真机专项尚未验证。
- 本地截图、API 凭据与日志保留在忽略的 tmp/connectivity-20260907 下，不上传仓库。
