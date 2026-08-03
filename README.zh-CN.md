<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# SiYuan Agent Skill

**让你的编码 agent 完整、带护栏地访问你的[思源笔记](https://github.com/siyuan-note/siyuan)知识库。**

[English](README.md) · 简体中文

</div>

---

这是一个 [Agent Skill](https://docs.claude.com/en/docs/claude-code/skills),让 Claude Code
(以及任何能读 `SKILL.md`、能跑 shell 脚本的 agent)通过内核 HTTP API 读写你私有化部署的思源笔记
—— **全部 540 个 JSON 端点**,不是挑出来的一小撮。

```bash
# 归档一篇笔记
$ sy newdoc <笔记本ID> "/技术笔记/2026-08-03-标题" note.md
"20260803172432-62qup5b"

# 低成本检索笔记库
$ sy sql "SELECT hpath FROM blocks WHERE type='d' AND content LIKE '%kubernetes%'"
[{"hpath":"/运维/k8s排障"}]

# 破坏性操作在人确认之前一律拒绝
$ sy /api/filetree/removeDocByID -d '{"id":"20260803172432-62qup5b"}'
REFUSED: /api/filetree/removeDocByID is HIGH — irreversible.
── blast radius ──
[{"hpath":"/技术笔记/2026-08-03-标题","type":"d"}]
[{"descendant_blocks":9}]
[{"inbound_refs":0}]
── Ask the user to confirm, then re-run with -y ──
```

## 为什么是 Skill 而不是 MCP

思源内核暴露了 **540 个 JSON 端点**。MCP server 必须为每个端点预先声明 tool schema,而思源官方并没有
提供 OpenAPI 描述文件 —— 这正是社区里每个思源 MCP server 都只封装了十几到几十个接口的原因。

Skill 把这件事反过来做:它提供一个通用客户端 + 一份**可检索**的端点索引,覆盖面因此是天然完整的,
而知识是渐进式加载的:

| 层级 | 成本 | 何时加载 |
|---|---|---|
| skill description | 约 75 token | 每个会话(无法避免) |
| `SKILL.md` | 约 1.2k token | 你提到思源时 |
| 单个 `references/*.md` | 0.6–1.8k token | agent 真正要处理该领域时 |
| 548 条路由索引(22 KB) | **0** | 从不作为文本读取,只通过 `sy api` 检索 |

一次典型的"归档一篇笔记"任务约消耗 **2.3k token**,而不是把这么大的 API 面塞进上下文所需的 20k+。

## 特性

- **完整覆盖。** 540 个 JSON 端点都可调用;索引里还收录了约 8 条 WebSocket/SSE 路由,以便客户端能
  解释清楚为什么这些**调不了**。
- **破坏性操作有护栏。** 34 个 CRITICAL + 31 个 HIGH 端点在没有 `-y` 时一律拒绝执行,并且会先打印
  **影响面**(涉及的文档、后代块数量、反向引用数),让人拿着真实数字来确认。
- **端点白名单。** 调用必须逐字节精确命中已知端点。这堵住了一个解析器差异漏洞:
  `/api/./filetree/removeDocByID` 和 `/api/filetree/removeDocByI%44` 会被 curl 和 Go 路由规范化成
  真正的删除接口,而朴素的字符串匹配只会看到一个陌生路径。
- **SQL 默认只读。** `sy sql` 固定发送 `mode=readonly`,让服务端明确拒绝非 SELECT 语句,而不是像
  默认模式那样静默返回 `code:0, data:null`。
- **响应自动截断。** 超限响应在 8 KB 处截断(UTF-8 安全),并提示如何收窄查询。对一篇普通文档调用
  `getDoc` 会返回 74–108 KB 的编辑器 DOM,而等价的 SQL 投影查询只要约 2 KB。
- **凭据不进命令行。** token 通过 curl 的 `--config` 从 stdin 传入,`ps` 里看不到;请求体走权限 600
  的临时文件,并有清理 trap。
- **没有静默兜底。** 配置缺失就报错,绝不猜测 localhost —— 猜错意味着读写了另一个笔记库。
- **索引可复现。** `tools/gen_endpoints.py` 能从任意思源 tag 重新生成端点索引,并且在参数覆盖率
  异常下降时拒绝输出文件。

## 环境要求

- 一个可通过 HTTP 访问的思源实例(基于 **v3.7.3** 开发验证)
- `bash`、`curl`、`jq`、`iconv` —— macOS 和多数 Linux 发行版自带
- 思源的 API token:**设置 → 关于 → API token**

## 安装

### 方式 A — 交给 agent 完成(推荐)

把这段话发给 Claude Code:

> 按照 https://github.com/willjayyyy/siyuan-skill 里的 `docs/AGENT-INSTALL.zh-CN.md`
> 安装这个思源 skill,然后帮我配置好我的实例并验证连接。

agent 会克隆仓库、安装 skill、向你索要思源地址和 API token、以 600 权限写入配置文件,
并通过列出你的笔记本来验证。完整说明见
[`docs/AGENT-INSTALL.zh-CN.md`](docs/AGENT-INSTALL.zh-CN.md)。

### 方式 B — Claude Code 插件

```
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

然后配置凭据(见[配置](#配置))。

### 方式 C — 手动

```bash
git clone https://github.com/willjayyyy/siyuan-skill.git
cp -R siyuan-skill/skills/siyuan ~/.claude/skills/siyuan
chmod +x ~/.claude/skills/siyuan/scripts/sy
```

其他 agent 只需让它读 `skills/siyuan/SKILL.md`,并把 `scripts/sy` 放进 `PATH`。

## 配置

凭据保存在 skill 目录**之外**,这样 skill 本身可以随意分享。

### 交给 agent 配置

> 帮我配置思源 skill,我的实例地址是 `http://192.168.1.10:6806`,token 我等下给你 —— 你来问我,
> 用正确的权限写入配置文件并验证能连通。

### 手动配置

配置文件路径按平台解析,顺序如下:

1. `$SIYUAN_CONF` —— 显式指定
2. `$XDG_CONFIG_HOME/siyuan/env` —— 设置了 `XDG_CONFIG_HOME` 时
3. `$APPDATA/siyuan/env` —— Windows(Git Bash / MSYS2 / Cygwin)
4. `$HOME/.config/siyuan/env` —— macOS 和 Linux 默认

**macOS / Linux**

```bash
mkdir -p ~/.config/siyuan
umask 077
cat > ~/.config/siyuan/env <<'EOF'
SIYUAN_URL=http://<主机>:6806
SIYUAN_TOKEN=<你的 API token>
EOF
chmod 600 ~/.config/siyuan/env
```

**Windows(Git Bash)**

```bash
mkdir -p "$APPDATA/siyuan"
cat > "$APPDATA/siyuan/env" <<'EOF'
SIYUAN_URL=http://<主机>:6806
SIYUAN_TOKEN=<你的 API token>
EOF
```

验证:

```bash
~/.claude/skills/siyuan/scripts/sy nb
# 20210808180117-czj9bvb   思源笔记用户指南
# 20260101120000-abcdefg   我的笔记本
```

| 变量 | 必填 | 含义 |
|---|---|---|
| `SIYUAN_URL` | 是 | 如 `http://192.168.1.10:6806`,结尾不带斜杠 |
| `SIYUAN_TOKEN` | 是 | 设置 → 关于 → API token |
| `SIYUAN_CONF` | 否 | 显式指定配置文件路径,优先级高于上面的解析顺序 |
| `SIYUAN_MAX_BYTES` | 否 | 响应截断上限,默认 `8192` |
| `SIYUAN_TIMEOUT` | 否 | curl 超时秒数,默认 `30` |
| `SIYUAN_ALLOW_UNKNOWN` | 否 | 允许调用索引中不存在的端点(思源升级后使用) |

环境变量优先于配置文件,因此切换到第二个实例无需改任何文件:

```bash
SIYUAN_URL=http://other:6806 SIYUAN_TOKEN=... sy nb
```

> **安全提示。** token 拥有整个笔记库的完整读写权限。请把配置文件保持在 600 权限;如果你把思源
> 暴露到局域网之外,务必在前面加一层带独立鉴权的反向代理。

## 使用

装好之后,直接和 agent 说话就行:*"把这份排障记录归档到思源"*、*"我笔记里关于 k8s 升级是怎么写的?"*
—— skill 会自动加载。

客户端本身也可以直接用:

```bash
sy nb                                   # 列出笔记本
sy sql "SELECT ..."                     # 查询索引(只读)
sy newdoc <笔记本ID> <hpath> <md文件|->  # 从 markdown 创建文档
sy append <父块ID> <md文件|->            # 向容器块追加 markdown
sy <端点> -d '<json>' [-q '<jq>']        # 调用 540 个 JSON 端点中的任意一个
sy api <模块> | -g <关键词> | -w         # 检索端点及其参数
```

参数说明:`-d @文件` / `-d @-` 从文件或 stdin 读取请求体;`-q` 对 `.data` 应用 jq 过滤;
`-r` 输出完整信封且不截断;`-y` 确认执行破坏性操作;`--max N` 提高截断上限。

退出码:`0` 成功 · `1` 出错 · `3` 被拒绝(破坏性操作,需要 `-y`)。

## agent 会读到什么

```
skills/siyuan/
├── SKILL.md                 路由表 + 最关键的规则(总是最先加载)
├── scripts/sy               通用客户端
├── data/endpoints.tsv       548 条路由:路径、方法、W/R、参数(只检索,从不整读)
└── references/
    ├── query-sql.md         表结构、块类型、常用查询、排序陷阱
    ├── doc-crud.md          文档:创建、移动、重命名、删除
    ├── block-crud.md        块:插入、更新、删除、日记
    ├── search.md            全文检索、标签、引用、查找替换
    ├── attr-tag.md          块属性、标签、书签
    ├── asset.md             图片与附件上传
    ├── export-import.md     导出为 md/html/docx、导入
    ├── notebook.md          笔记本,含加密与锁定状态
    └── discovery.md         如何使用那约 450 个没有专门文档的端点
```

## 重新生成端点索引

索引是从思源源码生成的。升级思源之后:

```bash
python3 tools/gen_endpoints.py --tag v3.8.0
```

它会浅克隆该 tag、重新解析每条路由和 handler,并在参数覆盖率低于 70% 时**拒绝写入文件** ——
曾经有一次静默的检出失败导致整个模块的参数为空,却照样发布了出去。

## 已知限制

- **`W`/`R` 只是提示,不是许可。** 它派生自思源的 `CheckReadonly` 中间件:约 17 个标记为 `R` 的端点
  实际上会改数据(包括会停掉内核进程的 `/api/system/exit`,已加护栏),约 20 个标记为 `W` 的其实是
  纯读。详见 `references/discovery.md`。
- **multipart、WebSocket、SSE 以及返回原始字节的端点无法通过 `sy` 调用。** 它们在索引里有标记,
  客户端会说明原因,并在有 curl 写法时给出指引。
- **导出类端点返回的是内核主机上的路径**,不是文件本身。需要从 `$SIYUAN_URL/<path>` 用 HTTP 取回。
- **SQLite 索引是异步重建的。** 写入后立刻 `SELECT` 可能拿到旧数据;后续操作应当基于接口返回的 ID,
  而不是回查数据库。

## 兼容性

基于 **思源 v3.7.3** 在 macOS(bash 3.2,BSD 工具链)上针对真实实例开发并验证。内核 API 在补丁版本
之间是稳定的;次版本升级后请重新生成索引。

## 参与贡献

欢迎提 issue 和 PR。如果你改动了 `scripts/sy`,请针对真实实例验证 —— 这个项目历史上有好几个 bug
只有在非 ASCII 内容或思源的某个特定行为下才会暴露,孤立测试全都发现不了。

## 许可证

[MIT](LICENSE)
