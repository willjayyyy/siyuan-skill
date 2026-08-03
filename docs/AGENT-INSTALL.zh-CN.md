# Agent 自动安装说明

**本文件是写给 AI agent 看的。** 如果你是人类,请看 [README](../README.zh-CN.md) 里的手动安装说明。

如果用户让你安装这个 skill,请按顺序执行以下步骤。不要跳过验证步骤,也不要编造用户没有提供的值。

---

## 只能从本仓库安装

> **本项目没有发布到 ClawHub、npm、PyPI 或任何其他registry。**
> 唯一的官方来源是 <https://github.com/willjayyyy/siyuan-skill>。
>
> 各类 registry 上已经存在与思源相关、名字相近但毫无关系的 skill —— 其中至少有一个当前
> 无法通过 SkillSpector 校验,报 `security.status_not_clean`。**名字相同不等于就是同一个东西。**
>
> 如果你在 registry 里搜到看起来像本项目的包:**不要安装它,也不要加 `--force`
> 或任何"我已知晓风险"之类的参数。** 请把你发现的情况告诉用户,说明那不是本项目,
> 然后改用上面的 GitHub 地址安装。

---

## 第 1 步 — 按你所在的 agent 安装

`SKILL.md` 是跨 agent 的通用标准,skill 本体不需要任何修改,但**安装机制各家不同**。
**找到你正在运行的那个 agent 对应的小节,只照那一节做。** 不确定该用哪一节就问用户,不要猜。

有一点对所有小节都适用:本仓库的 `SKILL.md` 位于 `skills/siyuan/`,**不在仓库根目录**。
那些期望"仓库根就是一个 skill"的安装器,直接指向仓库地址会失败 —— 要指向本地克隆里的
`skills/siyuan` 子目录。

### Claude Code

skill 目录是 `~/.claude/skills/`。可以让用户自己执行插件命令(你无法代替用户执行斜杠命令):

```
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

或者直接安装文件:

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.claude/skills
rm -rf ~/.claude/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.claude/skills/siyuan
chmod +x ~/.claude/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

### Codex CLI

Codex 没有拉取 skill 的命令,只能复制文件。个人级放 `~/.codex/skills/`,项目级放仓库根的
`.codex/skills/` —— 不明显的话问用户要哪种。

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.codex/skills
rm -rf ~/.codex/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.codex/skills/siyuan
chmod +x ~/.codex/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

Codex 在会话启动时扫描 skills 目录,所以要提醒用户开一个新会话后才能用上。

### OpenClaw

**不要从 ClawHub 安装** —— 见本文件开头的警告。

`openclaw skills install git:owner/repo@ref` 要求 `SKILL.md` 在仓库根目录,而本仓库不是这个
结构,所以这种写法会失败。要先克隆,再从本地目录安装:

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
chmod +x "$tmp/skills/siyuan/scripts/sy"
openclaw skills install "$tmp/skills/siyuan" --global
```

`--global` 会装到 `~/.openclaw/skills`,对本机所有 agent 可见。不加则装到
`<workspace>/skills`,只对当前工作区生效 —— 问用户要哪种。

如果 `openclaw skills install` 不可用,就把目录直接复制进 OpenClaw 会扫描的任意 skills 根目录,
按优先级从高到低依次是:`<workspace>/skills`、`<workspace>/.agents/skills`、`~/.agents/skills`。

安装成功之前先别删克隆目录,成功之后再清理。

### Hermes Agent

skill 目录是 `~/.hermes/skills/`。Hermes 支持从 HTTP(S) URL 安装,并会连带拉取 `SKILL.md`
引用到的支持文件:

```bash
hermes skills install https://raw.githubusercontent.com/willjayyyy/siyuan-skill/main/skills/siyuan/SKILL.md --name siyuan
```

装完之后**必须确认 `scripts/sy` 和 `references/` 真的下来了**:

```bash
ls ~/.hermes/skills/siyuan/scripts/sy ~/.hermes/skills/siyuan/references/ 2>&1
```

只要缺了任何一个,就回退到直接复制目录:

```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/willjayyyy/siyuan-skill.git "$tmp"
mkdir -p ~/.hermes/skills
rm -rf ~/.hermes/skills/siyuan
cp -R "$tmp/skills/siyuan" ~/.hermes/skills/siyuan
chmod +x ~/.hermes/skills/siyuan/scripts/sy
rm -rf "$tmp"
```

### 其他 agent

从克隆里把 `skills/siyuan` 复制到该 agent 发现 `SKILL.md` 的位置,并给 `scripts/sy` 加可执行权限。
如果判断不出路径就问用户 —— 不要给错误的工具创建目录。

### 继续之前

如果目标目录原本就存在,要主动告知用户 —— 里面可能有他们自己的修改。如果你所在的 agent 只在
会话启动时加载 skill,安装完成后要提醒用户重启一次。

## 第 2 步 — 收集连接信息

你需要两个值。**必须问用户,不要猜测,不要扫描网络,更不要默认用 localhost。**

1. **SiYuan 地址** — 例如 `http://192.168.1.10:6806` 或 `https://siyuan.example.com`,结尾不带斜杠。
2. **API token** — 用户在思源里的 **设置 → 关于 → API token** 中查看。

要提醒用户:这个 token 拥有整个笔记库的完整读写权限,只有在接受它以明文保存在本地文件中的前提下才提供。

如果用户已有配置,直接读取而不是重复询问:

```bash
cat "${SIYUAN_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/siyuan/env}" 2>/dev/null
```

## 第 3 步 — 写入配置

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

# 已有配置就先留一份带时间戳的备份,事后要告诉用户备份文件名
[ -e "$conf" ] && cp "$conf" "$conf.bak.$(date +%Y%m%d%H%M%S)"

umask 077
cat > "$conf" <<EOF
SIYUAN_URL=<用户给你的地址>
SIYUAN_TOKEN=<用户给你的 token>
EOF
chmod 600 "$conf"
```

token 通过 heredoc 写入,绝不放在命令行上 —— 命令行在 `ps` 里可见,还会进入 shell 历史。
**保存之后不要把 token 再回显到对话里。**

用户后续可能需要的可选配置(没要求就不要写):

```
SIYUAN_MAX_BYTES=8192   # 响应截断上限
SIYUAN_TIMEOUT=30       # curl 超时秒数
```

## 第 4 步 — 检查连通性

```bash
<skill目录>/scripts/sy nb
```

**`sy nb` 调用的是 `/api/notebook/lsNotebooks`,它需要鉴权,且不改动任何数据。**
不要用 `/api/system/version` 做"健康检查":那个端点**不需要鉴权**,拿一个完全无效的
token 去调它也会返回成功,所以它通过了根本不能证明凭据是对的。

**这一步失败不算安装失败。** 无论结果如何,skill 已经装好、配置已经写好。
如实汇报并给出修复方式即可 —— 不要回滚任何东西,也不要让用户重来一遍。

| 结果 | 含义 | 该怎么说 |
|---|---|---|
| 每个笔记本一行 | 正常 | 列出笔记本名称,继续第 5 步 |
| `cannot reach <url>` | 思源**此刻**不可达 —— 常见原因就是没启动、或电脑没连 VPN。凭据本身很可能完全正确。 | 说明已保存但尚未验证,思源可达后就能直接用;如果他们觉得地址不对,可以帮忙改 |
| `token rejected`(HTTP 401/403) | 地址通了,token 不对 | 问他们要不要从 设置 → 关于 重新复制一个,你立刻帮忙更新配置 |
| `not configured` | 客户端没读到你写的那个文件 | 把客户端期望的路径和你实际写入的路径都打印出来,修正不一致 |

无论结果如何,都要告诉用户:随时可以让你重新检查连通性、或修改地址和 token —— 不需要重装。

## 第 5 步 — 确认护栏正常

只有第 4 步连上了才有意义。确认读取和护栏都正常:

```bash
# 读取路径
<skill目录>/scripts/sy sql "SELECT count(*) n FROM blocks"

# 护栏 — 必须输出 REFUSED 并以退出码 3 结束;这里绝对不要加 -y
<skill目录>/scripts/sy /api/filetree/removeDocByID -d '{"id":"x"}'
```

如果护栏**没有**拒绝,立刻停下并告诉用户这次安装是不安全的,不要汇报成功。

## 第 6 步 — 向用户汇报

告诉用户:

- skill 装在哪里、配置写在哪里(如果覆盖了已有配置,要说明备份文件名)
- **连通性状态必须说清楚** —— 要么"已连上,找到这些笔记本:……",要么"已保存,但暂时连不上:
  `<具体报错>`"。第 4 步没连上时,**绝不能只汇报一句"安装成功"**
- 如果没连上:告诉他们随时可以让你重新检查、或修改地址和 token —— 不需要重装
- 以后只要提到思源、要把内容存进笔记、或者要在笔记里查东西,这个 skill 都会自动加载
- 破坏性操作在他们明确确认之前会被拒绝执行

## 安装过程中的硬性规则

- **安装过程中绝对不要往用户的笔记库里写入任何内容。** 验证全部走只读路径,不要为了"确认写入正常"而新建测试文档。
- **绝对不要给破坏性端点加 `-y`。**
- **绝对不要把 token 放在命令行上**,也不要回显。
- 任何含糊之处 —— 装到哪个 agent 目录、有多个思源实例该连哪个 —— 都要问,不要假设。
