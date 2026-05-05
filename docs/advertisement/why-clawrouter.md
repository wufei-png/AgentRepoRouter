# 为什么已经有 Claude Code、Codex、Cursor、OpenCode，还值得装一个 ClawRouter

如果你现在已经在同时使用多个 AI coding CLI，你大概率已经遇到过这些问题：

- 你知道这个任务应该在某个 repo 里做，但要先想起来路径。
- 你记得某个项目里有自定义 skill 或 agent，但不记得它挂在哪个 CLI 目录下。
- 你想把 OpenClaw 当成统一入口，但真正执行时还是要自己切换到 Claude Code、OpenCode、Cursor 或 Codex。
- 你并不一定需要一个庞大的多 agent 调度平台，你只是想“先路由对，再调用对”。

这正是 ClawRouter 的切入点。

![ClawRouter 宣传图](ads.png)

## ClawRouter 不是另一个大而全平台

ClawRouter 不是要替代 OpenClaw，也不是要重造 Claude Code、Codex、Cursor、OpenCode。

它做的事情很克制：

- 让 OpenClaw 成为统一入口
- 让 Router Skill 先选对 repo
- 再根据 repo aliases、project-level skills、project-level agents 选对路径
- 最后仍然调用原生 CLI 执行

一句话概括：

> OpenClaw 管入口，ClawRouter 管路由，原生 CLI 管执行。

## 它解决的是“入口碎片化”，不是“算力不够多”

现在市面上已经有不少很强的 agent orchestration 项目：

- 有的擅长并行 fan-out，让多个模型同时 review
- 有的擅长 worktree、PR 生命周期、CI 自动修复
- 有的擅长看板和长期任务流转

这些项目很强，但也更重。

ClawRouter 的设计思路刚好相反：它先把最常见、最频繁、最影响效率的那层问题解决掉。

那就是：

- 这个任务属于哪个 repo？
- 这个 repo 有没有现成的 skill 或 agent？
- 这个场景更适合哪个 CLI？
- 在不破坏原生约定的前提下，怎么让 OpenClaw 自动导航过去？

## ClawRouter 的关键设计亮点

### 1. 它是 OpenClaw 原生 skill，不是外挂控制台

你不需要再维护另一个 orchestrator 主进程，也不需要再接受一套新的 runtime 心智模型。

安装后，ClawRouter 直接落在：

```text
~/.openclaw/skills/router/
```

这意味着它天然适合已经把 OpenClaw 当作日常入口的人。

### 2. 它把 repo 配置从“路径列表”升级成了“路由目录”

现在的 `repo_mappings.json` 不只是路径表，而是一个可导航的 repo catalog：

- `name`: 正式 repo 名
- `path`: 绝对路径
- `aliases`: repo 别名，比如 `api`、`admin`、`docs`
- `skills`: 已检测到的 project-level skills 摘要
- `agents`: 已检测到的 project-level agents 摘要

这一步非常关键。

以前只有路径时，Router 只能靠 repo 名和任务文本猜。
现在有了 aliases、skills、agents，OpenClaw 在真正执行前就已经拿到了结构化导航线索。

### 3. 它尊重各个 CLI 的原生生态

ClawRouter 不会强行把所有 CLI 抹平。

它接受现实：

- Claude Code 有自己的 `.claude/agents/` 和 `.claude/skills/`
- OpenCode 有自己的 `.opencode/agents/` 和 `.opencode/skills/`
- Cursor 有自己的 agent 方式
- Codex 有 `.agents/skills/`、`.codex/agents/`、`AGENTS.md`

很多“统一层”做着做着就会把这些差异都抽象掉，最后抽象反而成了损耗。

ClawRouter 的亮点恰恰在于：它统一入口，但不破坏原生约定。

### 4. 它先看项目级资产，再看全局默认

这是一个非常正确的产品判断。

真正和 repo 强绑定的 skill 和 agent，优先级本来就应该高于全局通用 helper。

ClawRouter 的 Router Skill 会先看：

- repo 是否命中
- alias 是否命中
- 该 repo 是否已经检测到项目级 skill
- 该 repo 是否已经检测到项目级 agent

只有这些都不够可靠时，才走全局和 fallback。

这个顺序让行为更可预测，也更接近真实团队项目的工作方式。

### 5. 它是“轻编排”，所以上手成本低

你不需要：

- 先建一个复杂看板
- 配一堆 worktree 生命周期
- 接入 PR 机器人
- 引入额外后台调度服务

如果你现在最大的痛点只是：

> 我已经有好几个 CLI 和好几个 repo，但我想让 OpenClaw 自动帮我走到最合适的执行路径。

那 ClawRouter 正好够用。

## 一个很典型的使用场景

假设你对 OpenClaw 说：

```text
fix the auth bug in the api project, use the repo's build_and_test skill
```

ClawRouter 可以做的事情是：

1. 先通过 `api` 命中 repo alias
2. 在该 repo 的 `repo_mappings.json` 条目里看到已检测的 `build_and_test` skill
3. 看到该 repo 下还存在某个 `bugfix` agent
4. 根据 repo 上下文和 CLI 顺序选中最合适的执行路径
5. 最终仍然调用原生 CLI 直接执行

这个过程看起来不“炫技”，但它非常实用。

因为它把你每天都会重复做的导航动作，收进了 OpenClaw 的一次对话里。

## ClawRouter 适合谁

它最适合这些用户：

- 已经把 OpenClaw 当作主要入口的人
- 同时使用 Claude Code、Codex、OpenCode、Cursor 中两个或以上的人
- 有多个本地 repo，需要在它们之间频繁切换的人
- 已经在 repo 内维护了 project-level skills 或 agents，希望这些资产能被自动利用的人
- 不想一上来就上重型 orchestration 平台的人

## ClawRouter 不适合谁

如果你的核心需求是下面这些，ClawRouter 不是主角：

- 你要同一个任务并行跑 3 到 5 个 CLI 做结果共识
- 你要 worktree、PR、CI、review comments 的全自动生命周期
- 你要一个强约束的多阶段 SDLC orchestration 系统

这时更适合把 ClawRouter 放在前面做入口和路由，再配合别的重型项目完成后续编排。

## 为什么现在值得试

现在这个版本的 ClawRouter 已经不再只是一个“提示词路由器”。

它已经具备了几个更有含金量的特征：

- 有安装器
- 有结构化 repo config
- 有 aliases
- 有自动检测的 project-level skills 和 agents
- 有 references 文档把复杂 CLI 约定拆出去
- 有单测、集成测试、E2E 测试和可选 live E2E

这意味着它已经从“想法”进入了“可以持续打磨的产品骨架”。

## 最后的判断

如果你期待的是一个能代替所有 agent runtime 的超级平台，ClawRouter 不是那个项目。

但如果你期待的是：

> 用 OpenClaw 统一入口，把多 repo、多 CLI、多项目级 skill/agent 的导航问题一次性理顺。

那 ClawRouter 值得你试一次。

它的价值，不在于有多重，而在于它正好卡在一个很多人已经开始痛、但还没有被很好填平的空位上。

## 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/wufei-png/ClawRouter/main/scripts/install.sh | bash
openclaw
```

安装完成后，优先看一眼：

```text
~/.openclaw/skills/router/references/repo_mappings.json
```

把 repo alias 补好，确认自动检测到的 skills 和 agents 是否符合你的项目实际情况。做到这一步，你就已经把 OpenClaw 的 coding 入口体验往前推了一大截。
