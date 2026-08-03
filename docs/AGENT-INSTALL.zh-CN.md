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

## 第 1 步 — 先检查环境

```bash
for dep in git curl jq; do
  command -v "$dep" >/dev/null 2>&1 || echo "MISSING(必需): $dep"
done
command -v iconv >/dev/null 2>&1 || echo "missing(可选): iconv"
```

**只要有任何必需项缺失,就停在这里。** 告诉用户该装什么并等他们装好 ——
不要先把 skill 装上、指望后面能跑起来。最常缺的是 `jq`,没有它客户端完全没法用。

| 平台 | 安装命令 |
|---|---|
| macOS | `brew install jq`(较新的 macOS 已自带 `jq`) |
| Debian / Ubuntu | `sudo apt install jq` |
| Fedora / RHEL | `sudo dnf install jq` |
| Alpine | `apk add jq` |
| Arch | `sudo pacman -S jq` |
| Windows — winget | `winget install jqlang.jq` —— Windows 10 1809+ 自带;**装完必须重开 Git Bash**,新的 `PATH` 才会生效 |
| Windows — scoop / choco | `scoop install jq` 或 `choco install jq` |
| Windows — WSL | 用你所在发行版对应的 Linux 命令 |
| Windows — 手动 | 从 <https://jqlang.org/download/> 下载 `jq.exe` 放进 `PATH`(最后手段) |

`iconv` 是可选的:没有它,被截断的响应可能停在半个字符上,其余功能不受影响。

### 缺依赖时怎么处理

**这条规则适用于所有依赖,不只是 `jq`。**

- **如果安装命令需要 `sudo`**(`apt`、`dnf`、`pacman`、`apk`):把命令给用户,等他们自己执行。
  **不要代劳。** 在非交互 shell 里 `sudo` 会卡在密码提示上,而这个提示你和用户都看不到;
  更重要的是,安装系统级软件包**超出了"安装一个 skill"的授权范围** —— 用户同意的是
  往自己目录里复制几个文件,不是改动整台机器。
- **如果不需要提权**(`brew`、`scoop`、`winget`):**主动提出**代劳 ——
  "我可以帮你装,你也可以自己跑" —— 得到用户明确同意后再执行。**绝不静默安装。**
- 无论哪种方式,**装完都要重跑一遍检测循环**,确认所有必需依赖都到位了再继续。

**Windows 说明。** 必须在 **WSL** 或 **Git Bash** 里运行 —— 客户端是 shell 脚本,
在 PowerShell 和 CMD 里跑不了。Git Bash 自带 `bash`、`git`、`curl`、`iconv`,
但**不带** `jq`。

优先用 `winget install jqlang.jq`,不要让用户手动下载:一条命令、不用改 `PATH`,
而且 Windows 10 1809 及以后都自带 winget。注意 winget 本身要在 **PowerShell 或 CMD**
里运行,不是 Git Bash —— 让用户去那边执行,然后**重开 Git Bash**,再跑一次环境检查。

**如果你是在 PowerShell 或 CMD 里运行的**,要注意那里的 `bash` 解析到的是
`C:\Windows\System32\bash.exe` —— **WSL 的** bash,WSL 没配好就会失败。
这不是 skill 的问题。改成显式调用 Git Bash:

```powershell
& "C:\Program Files\Git\bin\bash.exe" "<skill目录>\scripts\sy" nb
```

**绝对不要因为 shell 问题就绕过去直接调思源 API**(用 `Invoke-RestMethod`、`curl`
或任何其他方式)。这个 skill 的全部安全保障都在 `sy` 里,自己拼的请求会把它们**全部绕过**。

## 第 2 步 — 按你所在的 agent 安装

> **本仓库没有任何安装器。** 没有 `install.sh`,没有 setup 脚本,没有任何需要执行的安装程序。
> 所谓安装,就是把 `skills/siyuan` 这个目录复制到你的 agent 的 skills 目录 —— 全部机制就这么多。
>
> `tools/gen_endpoints.py` **不是**安装器。它是维护者工具,用途是在思源发布新版本后,
> 从思源源码重新生成端点索引。**安装过程中不要运行它。**

`SKILL.md` 是跨 agent 的通用标准,skill 本体不需要任何修改,但**安装机制各家不同**。
**找到你正在运行的那个 agent 对应的小节,只照那一节做。** 不确定该用哪一节就问用户,不要猜。

唯一需要可执行权限的文件是 `skills/siyuan/scripts/sy`。git 里记录的模式是 755,
所以 `git clone` 会保留执行位;如果你是用别的方式拿到文件的(下载 zip、逐个抓取),
执行位会丢失 —— 下面各小节里的 `chmod +x` 就是用来补回来的。

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

## 第 5 步 — 顺手检查一下连通性

配置写好后直接跑一次,不用先问用户:

```bash
<skill目录>/scripts/sy nb
```

**`sy nb` 调用的是 `/api/notebook/lsNotebooks`,它需要鉴权,且不改动任何数据。**
不要用 `/api/system/version` 做"健康检查":那个端点**不需要鉴权**,拿一个完全无效的
token 去调它也会返回成功,所以它通过了根本不能证明凭据是对的。

**这一步失败不算安装失败。** skill 已经装好、配置已经写好。不要回滚任何东西,
不要让用户重走一遍流程,更不要因此说安装失败了。

| 结果 | 含义 | 该怎么说 |
|---|---|---|
| 每个笔记本一行 | 正常 | 列出笔记本名称 |
| `cannot reach <url>` | 思源**此刻**不可达 —— 常见原因就是没启动、或电脑没连 VPN。凭据本身很可能完全正确。 | 如实说明现在连不上,思源起来后就能直接用;并说明如果地址需要改,告诉你就行 |
| `token rejected`(HTTP 401/403) | 地址通了,token 不对 | 说明 token 不被接受,并提出:把 设置 → 关于 里的新 token 给你,你立刻更新配置 |
| `not configured` | 客户端没读到配置文件 | 把客户端期望的路径和实际写入的路径都打印出来,修正不一致 |

## 第 6 步 — 向用户汇报

告诉用户:

- skill 装在哪里、配置写在哪里(如果覆盖了已有配置,要说明备份文件名)
- **连通性结果,明确说清** —— 要么"已连上,笔记本有:……",要么"暂时连不上:`<具体报错>`"。
  没连上时**绝不能只说一句"安装成功"**
- **随时可以让你修改地址或 token、或重新检查连通性** —— 不需要重装
- 以后只要提到思源、要把内容存进笔记、或者要在笔记里查东西,这个 skill 都会自动加载
- 破坏性操作在他们明确确认之前会被拒绝执行

如果你所在的 agent 需要重启才能加载新 skill,一并提醒。

---

## 用户想确认删除保护是否生效时

```bash
<skill目录>/scripts/sy /api/filetree/removeDocByID -d '{"id":"x"}'
```

它必须输出 `REFUSED` 并以退出码 3 结束。如果没有,告诉用户这次安装是不安全的。

## 安装过程中的硬性规则

- **安装过程中绝对不要往用户的笔记库里写入任何内容。** 任何检查都必须走只读路径,不要为了"确认写入正常"而新建测试文档。
- **绝对不要给破坏性端点加 `-y`。**
- **绝对不要把 token 放在命令行上**,也不要回显。
- **绝对不要绕过 `sy` 直接访问思源 API。** `sy` 跑不起来时,去修正调用方式或如实汇报,
  不要自己重新实现一个客户端。
- **绝对不要不问就装系统软件包**,也绝对不要代替用户执行 `sudo`。先提出、等对方同意、再动手 ——
  对任何依赖都一样。
- 任何含糊之处 —— 装到哪个 agent 目录、有多个思源实例该连哪个 —— 都要问,不要假设。
