# 设计说明

给需要扩展、审计或调试这个 skill 的人看的技术笔记。只是想用的话,看
[README](../README.zh-CN.md) 就够了。

## 目录结构

```
skills/siyuan/
├── SKILL.md              路由表 + 最关键的规则(最先加载)
├── scripts/sy            通用客户端 —— 一个脚本覆盖全部 JSON 端点
├── data/endpoints.tsv    548 条路由:路径、方法、W/R、参数
└── references/           九个主题文件,按需逐个加载
```

## 渐进式披露

整个设计的出发点是:庞大的 API 面不应该带来庞大的上下文开销。四个层级,各自只在需要时才付费:

| 层级 | 成本 | 何时加载 |
|---|---|---|
| skill description | 约 75 token | 每个会话 —— 无法避免 |
| `SKILL.md` | 约 1.2k token | 用户提到思源时 |
| 单个 `references/*.md` | 0.6–1.8k token | agent 真正要处理该领域时 |
| `data/endpoints.tsv`(22 KB) | **0** | 从不作为文本读取 |

一次典型的"把这个存到笔记里"请求,大约消耗 **2.3k token**。

其中两个决定贡献了绝大部分节省:

**端点索引做成命令,而不是文档。** 548 条路由写成 Markdown 约 4k token,而 agent 读完整份只是为了找其中一行。改成 `sy api -g <关键词>` 之后,输出只有三行。凡是"长列表 + 只需其中一两条"形状的知识,都应该放在过滤器后面,而不是放进文件。

**响应在 8 KB 处截断。** `getDoc` 返回的是编辑器原始 DOM —— 一篇普通文档就有 74–108 KB,合 20–30k token。客户端会把它截断(UTF-8 安全)并提示 agent 改用更窄的查询。等价的 SQL 投影查询大约只要 2 KB。

## 安全设计

### 护栏

65 个端点在没有 `-y` 时一律拒绝执行:34 个 CRITICAL(删除工作空间、重置仓库、整库导入、同步配置变更、注销账号)和 31 个 HIGH(删文档/删块、查找替换、历史回滚、删标签)。

有意**不**纳入护栏的是那些可重建或仅影响 UI 状态的操作 —— `graph/resetGraph`、`system/clearTempFiles`、`storage/*`、`bookmark/removeBookmark`。把它们也纳进来只会训练出"反射式点同意"的习惯,失去的安全性比得到的更多。

### 影响面预检

在拒绝之前,客户端会报告这次调用实际会波及什么:目标文档、它下面有多少内容块、有多少其他笔记链接到它。**没有数字的确认不算真正的确认。**

被拼进 SQL 的 ID 会先按 `yyyyMMddHHmmss-xxxxxxx` 格式校验 —— 否则一个构造过的 ID 会把预检查询变成注入,把整张 `blocks` 表 dump 到 stderr(那里不受大小限制约束),并且给操作者看的是别人行的数字。

如果预检查询本身失败了,会明确报出来。**空的影响面绝不能被误读成"这个操作什么都不会删"。**

### 端点白名单

调用必须逐字节精确命中已知端点。这堵住了一个解析器差异漏洞:curl 会折叠路径中的点段,Go 路由会做百分号解码,于是 `/api/./filetree/removeDocByID` 和 `/api/filetree/removeDocByI%44` 都会抵达真正的删除接口,而朴素的字符串匹配只看到一个陌生路径就放行了。改成对照已知列表匹配之后,护栏检查的字符串必然就是服务器路由的那个字符串。

### 两个不写出来就看不出的隐患

`/api/system/exit` 被中间件标记为 `R`,但它会停掉内核进程。`/api/notebook/closeNotebook` 对普通笔记本是可逆的,但对内置的用户指南笔记本,内核走的是 `RemoveBox()` —— 永久删除。两者都已加护栏,后者会在影响面报告里说明这个分支。

### 凭据处理

token 通过 curl 的 `--config` 从 stdin 传入,因此不会出现在 `ps` 里。请求体走权限 600 的临时文件,并带清理 trap。配置文件是**解析**的而非 source 的 —— source 会执行文件里的任何内容,而其中一句 `exit 0` 会让整次运行看起来是成功的。含引号或换行的 token 会被拒绝,因为它们能往 curl 的 config 块里注入额外的 header。

没有兜底 URL。默认连 localhost 意味着可能在悄悄读写机器上碰巧运行的另一个思源。

## `W`/`R` 只是提示,不是许可

它派生自思源的 `CheckReadonly` 中间件,而这并不等于"只读"。两个方向都有错:

- 约 17 个标记为 `R` 的端点会改数据 —— `system/exit`、`search/updateEmbedBlock`、`av/changeAttrViewLayout`、`ref/refreshBacklink`、`storage/updateRecentDoc*`、`notebook/unlockNotebook`,以及所有带 `savePath` 的 `export` 端点。
- 约 20 个标记为 `W` 的端点其实是纯读 —— `search/searchTag`、`searchTemplate`、`searchWidget`、`searchAsset`、`av/searchAttributeView*`、`filetree/listDocTree`。

`references/discovery.md` 明确告诉 agent:把这个标记当作弱证据,调用任何不熟悉的端点之前先去读 handler 源码。

## 重新生成端点索引

```bash
python3 tools/gen_endpoints.py --tag v3.8.0
```

它会浅克隆该 tag,解析 `router.go` 里的每一条路由(包括 `:param`、`*path` 形式以及非 `/api/` 前缀),并从五种参数绑定写法中提取参数:`arg["x"]`、`util.BindJsonArg("x")`、`c.PostForm`、`c.Query`,以及传给 `ShouldBindJSON` 的 struct 上的 json tag。它还会展开一层同包辅助函数调用 —— `fullTextSearchBlock` 和闪卡类端点的参数只有这样才拿得到。

脚本在参数覆盖率低于 70% 时会**拒绝写入文件**。这个检查的由来是:曾经有一次静默的检出失败,导致整个模块的参数为空却照样发布了出去 —— 而文档随后还为它长出了一条解释("`-` 表示该端点没有参数"),那是错的。**一个静默的数据缺陷,会长出为它自己辩护的文档。**

v3.7.3 基线:548 条路由,540 条在 `/api/` 下,300 条标记为 `W`,约 80% 带参数。

## 已知限制

**客户端调不了的端点**,全部在索引里有标记,以便客户端能说明原因:multipart 上传(13 个)、WebSocket 与 SSE 路由(约 8 个)、只接受 GET 而对 POST 返回空 200 的端点、以及返回原始字节而非标准信封的处理器。

**导出类端点返回的是内核主机上的路径**,不是文件本身。需要从 `$SIYUAN_URL/<path>` 用 HTTP 取回 —— 那些路由不在 `/api/` 下,客户端不碰。

**SQLite 索引是异步重建的。** 写入或删除后立刻 `SELECT` 可能拿到旧数据。后续操作应当基于接口返回的 ID,而不是回查数据库。

**SQL 表达不了文档顺序。** `sort` 是静态的块类型排名而非位置 —— 一篇文档里所有标题的 `sort` 都是 5。需要顺序时请用 `/api/block/getChildBlocks` 或 `/api/outline/getDocOutline`。

## 兼容性

基于思源 **v3.7.3**,在 macOS(bash 3.2,BSD 工具链)上针对真实实例开发并验证。内核 API 在补丁版本之间是稳定的;次版本升级后请重新生成索引。

依赖:`bash`、`curl`、`jq`;`iconv` 可选。`curl` 和 `jq` 在启动时检测 —— 缺 `jq` 时原先
会报成 `payload is not valid JSON: {}`,因为 `jq . 2>/dev/null` 把 "command not found"
一起吞了,只剩退出码。`iconv` 缺失则降级:截断的响应可能停在半个字符上。

不涉及 Python 或 Node 运行时;`tools/gen_endpoints.py` 是维护者脚本,不是运行时依赖。
