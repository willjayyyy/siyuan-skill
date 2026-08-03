# Agent 自动安装说明

**本文件是写给 AI agent 看的。** 如果你是人类,请看 [README](../README.zh-CN.md) 里的手动安装说明。

如果用户让你安装这个 skill,请按顺序执行以下步骤。不要跳过验证步骤,也不要编造用户没有提供的值。

---

## 第 1 步 — 确定 skill 的安装位置

判断当前运行环境的 agent skills 目录:

| Agent | skills 目录 |
|---|---|
| Claude Code | `~/.claude/skills/` |
| 其他 | 该 agent 加载 `SKILL.md` 的目录 — 不确定就问用户 |

如果用户更希望走 Claude Code **插件**方式,告诉他们自己执行下面两条命令(你无法代替用户执行斜杠命令),然后从第 3 步继续:

```
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

## 第 2 步 — 安装 skill 文件

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.claude/skills
rm -rf ~/.claude/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.claude/skills/siyuan
chmod +x ~/.claude/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

如果 `~/.claude/skills/siyuan` 原本就存在,要主动告知用户 —— 里面可能有他们自己的修改。

## 第 3 步 — 收集连接信息

你需要两个值。**必须问用户,不要猜测,不要扫描网络,更不要默认用 localhost。**

1. **SiYuan 地址** — 例如 `http://192.168.1.10:6806` 或 `https://siyuan.example.com`,结尾不带斜杠。
2. **API token** — 用户在思源里的 **设置 → 关于 → API token** 中查看。

要提醒用户:这个 token 拥有整个笔记库的完整读写权限,只有在接受它以明文保存在本地文件中的前提下才提供。

如果用户已有配置,直接读取而不是重复询问:

```bash
cat "${SIYUAN_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/siyuan/env}" 2>/dev/null
```

## 第 4 步 — 写入配置

配置文件放在 skill 目录**之外**,这样 skill 本身不含任何私人信息、可以随意分享。路径解析顺序与客户端保持一致:

1. 已设置 `$SIYUAN_CONF` 则用它
2. 已设置 `$XDG_CONFIG_HOME` 则用 `$XDG_CONFIG_HOME/siyuan/env`
3. Windows(Git Bash / MSYS2 / Cygwin)用 `$APPDATA/siyuan/env`
4. 其余情况用 `$HOME/.config/siyuan/env`

```bash
conf="${SIYUAN_CONF:-${XDG_CONFIG_HOME:+$XDG_CONFIG_HOME/siyuan/env}}"
conf="${conf:-${APPDATA:+$APPDATA/siyuan/env}}"
conf="${conf:-$HOME/.config/siyuan/env}"
mkdir -p "$(dirname "$conf")"
umask 077
cat > "$conf" <<EOF
SIYUAN_URL=<用户给你的地址>
SIYUAN_TOKEN=<用户给你的 token>
EOF
chmod 600 "$conf"
```

**写完之后不要把 token 再回显到对话里**,也不要把它放在命令行参数上(那会进入 shell 历史,并且在 `ps` 中可见)—— 用上面的 heredoc 写法。

用户后续可能需要的可选配置(没要求就不要写):

```
SIYUAN_MAX_BYTES=8192   # 响应截断上限
SIYUAN_TIMEOUT=30       # curl 超时秒数
```

## 第 5 步 — 验证

```bash
~/.claude/skills/siyuan/scripts/sy nb
```

预期输出:每个笔记本一行,格式为 `<id>\t<名称>`。

如果失败,按下表对应处理,不要靠猜:

| 报错 | 含义 | 处理方式 |
|---|---|---|
| `SIYUAN_URL and SIYUAN_TOKEN not configured` | 在解析出的路径上没找到配置 | 重做第 4 步,并把客户端期望的路径打印给用户看 |
| `token rejected`(HTTP 401/403) | token 不对 | 请用户从 设置 → 关于 重新复制 |
| `cannot reach <url>` | 地址/端口错误、实例未运行、或被防火墙拦截 | 确认地址,请用户在浏览器里打开试试 |
| `config exists but is not readable` | 权限问题 | `ls -l` 看一下文件,修正属主 |

然后确认读取和护栏都正常:

```bash
# 读取路径
~/.claude/skills/siyuan/scripts/sy sql "SELECT count(*) n FROM blocks"

# 护栏 — 必须输出 REFUSED 并以退出码 3 结束;这里绝对不要加 -y
~/.claude/skills/siyuan/scripts/sy /api/filetree/removeDocByID -d '{"id":"x"}'
```

## 第 6 步 — 向用户汇报

告诉用户:

- skill 装在哪里、配置写在哪里
- 找到了哪些笔记本(只报名称,除非用户要求否则不要贴 ID)
- 以后提到思源、归档笔记、搜索笔记时,这个 skill 会自动加载
- 破坏性操作在他们明确确认之前会被拒绝执行

## 安装过程中的硬性规则

- **安装过程中绝对不要往用户的笔记库里写入任何内容。** 验证全部走只读路径,不要为了"确认写入正常"而新建测试文档。
- **绝对不要给破坏性端点加 `-y`。**
- **绝对不要把 token 放在命令行上**,也不要回显。
- 任何含糊之处 —— 装到哪个 agent 目录、有多个思源实例该连哪个 —— 都要问,不要假设。
