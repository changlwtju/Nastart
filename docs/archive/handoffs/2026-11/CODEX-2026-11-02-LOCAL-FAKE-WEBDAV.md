# Codex：本机合成只读 WebDAV 夹具

2026-11-02（Asia/Shanghai）。已保存密码任务完成后执行；本轮没有App代码修改、App／真机操作、NAS访问或局域网扫描。

- 目录：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-fakelib/`，仅`library/`作为WebDAV根，不导出脚本、日志或Python环境。
- 电影40部、剧集6部×2季×4集、动漫4部，共50部／92个视频文件。45张600×900合成渐变文字海报、45份movie.nfo，剧集额外6份tvshow.nfo。海报与NFO各故意缺5部（10%），有5个超长中文名；见[样本定义](../../../testing/samples/LOCAL-FAKE-WEBDAV-20261102.md)及本机manifest.json。
- 未发现ffmpeg，按约定使用**空MKV占位，不能播放**，没有伪称为1秒MP4。library共188文件、约1.34MiB；抽查预览确认中文和长标题可读。
- 独立`.venv`安装Pillow13.0.0／WsgiDAV4.4.0。只读FilesystemProvider，禁用锁／属性持久化；外层仅允许OPTIONS／PROPFIND／GET／HEAD，文件0444／目录0555。
- 25项curl检查通过：根及分类PROPFIND均207、条目数正确；中文长路径、两季各4集、GET／HEAD／Range、NFO与空视频读取正常；10种写方法405，越界403、非导出脚本404。请求前后188文件哈希一致，无认证挑战。
- 重复start保持同PID、stop后无监听、再start取得新PID均通过；重启后PROPFIND再次207。fresh lsof仅有`127.0.0.1:8089` IPv4监听。服务独立会话运行，PID见资源登记及本机`.run/server.json`；stop核脚本路径＋实例标识后只停自身。
- 临时生命周期自测与报告生成脚本初稿各有一处语法错误，均在执行动作／写报告前失败；已修正并保留记录，未改变服务或夹具内容。HTTP自测均通过。

启动／停止：

```sh
bash ~/Downloads/Nastart-ClaudeEvidence-2026-11-02-fakelib/start.sh
bash ~/Downloads/Nastart-ClaudeEvidence-2026-11-02-fakelib/stop.sh
```

地址`http://127.0.0.1:8089/`直接映射library，无需加/library。夹具目录README.md有结构和自测命令。

447项App输入与Git index不变，剩余约5.93GiB。尚未执行App导入／显示／播放，30项需求与114播放格不新增验收。原始证据入口`/tmp/nastart-codex-fakelib-path`，含清单、海报预览、curl响应和生命周期记录；[结构结果](../../../testing/results/2026-11/CODEX-LOCAL-FAKE-WEBDAV-20261102.json)。文档检查通过：636份文档／3907本地链接，缺失0。
