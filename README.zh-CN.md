<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# SiYuan Agent Skill

**让你的 AI 助手直接使用你的[思源笔记](https://github.com/siyuan-note/siyuan)——读得到、写得进、改得动。**

[English](README.md) · 简体中文

[安装](#安装) · [支持哪些-ai-助手](#支持哪些-ai-助手) · [连接你的思源](#连接你的思源) · [安全](#你的笔记是安全的)

</div>

---

笔记在思源里,活儿在 AI 助手这边干。这个 skill 把两边连起来。

装好之后,正常说话就行:

> **你:** 把刚才排查内存泄漏的过程整理一下,放到我的技术笔记里。
>
> **助手:** 已在「技术笔记」下创建《2026-08-03 工作池内存泄漏》—— 包含根因、排除掉的三种可能、以及最终的修复方式,已打上 `#调试` `#golang` 标签。

> **你:** 我之前关于 Kubernetes 升级写过什么?
>
> **助手:** 有三篇提到。六月那篇里有你的回滚清单;八月那篇写着 CNI 插件是卡点。

> **你:** 把今天的结果补到八月那篇里。
>
> **助手:** 已在《K8s 1.29 升级》末尾追加「处理结果」小节。

不用复制粘贴,不用切窗口,不用导出再导入。

## 它能做什么

思源自己能做的,它基本都能做 —— 因为它走的就是思源客户端自己在用的那套接口,全部 540 个。

**写入** —— 把对话里产出的内容整理成笔记存进去、给已有文档追加章节、在指定位置插入内容、改写某一段、上传图片和附件。

**读取** —— 按关键词、标签、正文全库检索,取出文档大纲,顺着笔记之间的双链走,查清谁引用了谁。

**更新** —— 重命名、在笔记本之间移动、调整结构、重新打标签、修改属性、在指定范围内查找替换。

**整理** —— 创建和管理笔记本、维护标签体系、找出重复内容、发现没人引用的孤立笔记、导出为 Markdown / HTML / Word / PDF。

## 支持哪些 AI 助手

`SKILL.md` 是一套开放标准,所以这个 skill 不用改任何东西就能跨助手使用:

| 助手 | skill 存放位置 | 状态 |
|---|---|---|
| **Claude Code** | `~/.claude/skills/` | 支持 |
| **Codex CLI** | `~/.codex/skills/` | 支持 |
| **OpenClaw** | 配置根目录下的任意 `SKILL.md` | 支持 |
| **Hermes Agent** | `~/.hermes/skills/` | 支持 |
| 其他 | 该助手读取 `SKILL.md` 的位置 | 理论可用 —— 有问题请[告诉我们](https://github.com/willjayyyy/siyuan-skill/issues) |

只要这个助手能读 `SKILL.md`、能执行 shell 命令,就能用。

## 安装

### 让 AI 助手帮你装

复制下面这段,发给你的 AI 助手:

```text
帮我安装思源笔记 skill:https://github.com/willjayyyy/siyuan-skill

安装说明在这里:
https://github.com/willjayyyy/siyuan-skill/blob/main/docs/AGENT-INSTALL.zh-CN.md

装好之后问我思源的地址和 API token,安全地保存好,并验证能正常连上。
```

助手会自动下载 skill、按你用的工具放到正确位置、向你索要思源地址和 API token、以正确的文件权限保存,最后通过列出你的笔记本来确认连接成功。

### 自己动手装

下载 skill,复制到你的助手的 skills 目录:

```bash
git clone https://github.com/willjayyyy/siyuan-skill.git
cp -R siyuan-skill/skills/siyuan ~/.claude/skills/siyuan    # 或 ~/.codex/skills/、~/.hermes/skills/
chmod +x ~/.claude/skills/siyuan/scripts/sy
```

**Claude Code 用户**也可以按插件方式安装:

```text
/plugin marketplace add willjayyyy/siyuan-skill
/plugin install siyuan@siyuan-skill
```

## 连接你的思源

你需要两样东西:

- **思源的访问地址** —— 类似 `http://192.168.1.10:6806`
- **API token** —— 在思源里打开 **设置 → 关于 → API token** 就能看到

### 让助手帮你配

复制这段:

```text
帮我配置思源 skill。问我地址和 token,用安全的权限写进对应的配置文件,
然后列出我的笔记本来验证配置成功。
```

### 自己动手配

新建一个文件,写上地址和 token。位置取决于你的系统:

| 系统 | 文件位置 |
|---|---|
| macOS / Linux | `~/.config/siyuan/env` |
| Windows | `%APPDATA%\siyuan\env` |

文件内容就两行:

```text
SIYUAN_URL=http://192.168.1.10:6806
SIYUAN_TOKEN=你的-api-token
```

macOS 和 Linux 上再限制一下权限:`chmod 600 ~/.config/siyuan/env`

配好就行了。下次你提到笔记,助手会自动用上。

## 你的笔记是安全的

把积累多年的笔记交给 AI 写,需要的是真正的保护措施,而不是一句承诺。

**删除类操作必须你明确点头。** 65 个会造成数据损失的操作 —— 删文档、删笔记本、全库查找替换、回滚到旧快照 —— 默认全部拦截。助手必须回来问你。

**批准之前你看得到真实数字。** 不是含糊的一句"要删除这篇笔记吗",而是明确告诉你影响范围:*这篇文档、里面 9 个内容块、有 0 篇其他笔记引用它*。你是拿着事实做判断。

**有几个操作的危险性不写出来根本看不出。** 关闭内置的「思源笔记用户指南」笔记本,实际上是永久删除它;有一个接口调用会直接停掉思源的后台服务。这两个都会被拦下并解释清楚,而不是默默执行。

**读操作不会意外变成写操作。** 数据库查询在服务端被锁定为只读,写错的语句会明确报错,而不是悄悄改掉什么。

**你的 token 不会暴露。** 它不会出现在命令行上(那样同机的其他程序能看到),并且保存在 skill 目录之外 —— 所以 skill 本身可以放心分享。

**不做任何猜测。** 配置没写好就直接报错,绝不会悄悄连上你机器上碰巧在跑的另一个思源。

> **有一点需要你知道:** 思源的 API token 拥有整个笔记库的完整权限。请把配置文件保管好;如果你把思源暴露到家庭网络之外,务必在前面加一层正经的身份验证。

## 环境要求

- 一个网络可达的思源实例 —— 私有化部署、Docker、桌面版都行
- 基于思源 **v3.7.3** 测试
- macOS、Linux 或 Windows(Git Bash / WSL)

## 为什么不做成 MCP

MCP 需要把每个操作都预先声明出来。思源有 540 个接口,而且官方没有提供机器可读的描述文件 —— 这就是为什么现有的思源 MCP 只覆盖了十几到几十个接口。

Skill 的思路不一样:一个通用客户端,加上一份可检索的接口索引。覆盖面天然是完整的,而详细文档只在真正需要时才加载 —— 所以一次普通的记笔记请求,消耗的上下文只是同等 MCP 的一小部分,后者无论你用不用都要一直占着位置。

## 想深入了解

- [设计说明](docs/DESIGN.zh-CN.md) —— 架构、安全设计、上下文开销
- [给助手看的安装指令](docs/AGENT-INSTALL.zh-CN.md) —— AI 安装时照着做的那份
- [`skills/siyuan/`](skills/siyuan/) —— skill 本体;`references/` 是助手需要查接口细节时才会读的部分

升级了思源?用 `python3 tools/gen_endpoints.py --tag v3.8.0` 重新生成接口索引即可。

## 参与贡献

欢迎提 issue 和 PR。如果你改动了客户端脚本,请针对真实的思源实例测试 —— 这个项目历史上有好几个 bug 只有在非 ASCII 内容或思源的某个特定行为下才会暴露,孤立测试全都发现不了。

## 许可证

[MIT](LICENSE)
