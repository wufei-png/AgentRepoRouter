# OrchAI - 实现顺序

## 核心流程

```
用户任务 → OpenClaw → Router Skill (LLM判断) → 找到对应Repo → 切换目录 → ACP启动Agent → 结果返回
```

## 实现顺序

### 1. 基础接入
- [ ] 安装 OpenClaw
- [ ] 通过 ACP 接入 Claude Code / Codex / OpenCode / Cursor
- [ ] 配置 workspace（多个项目目录）

### 2. Router Skill
- [ ] 写一个 Router Skill（LLM驱动）
- [ ] 输入：用户任务描述
- [ ] 输出：任务类型 + 关键字 → 对应Repo + Agent

任务类型：
- code review
- 知识库问答
- 特性实现
- bugfix
- 日常infra（打离线包等）

### 3. Agent 启动配置
- [ ] 配置每个项目用哪个 CLI（主选 + fallback）
- [ ] 例如：主选 OpenCode，fallback Claude Code
- [ ] **关键**：每个 repo 下的 CLI agent 启动时会在这个工作目录运行，加载这个 repo 的 project-level skills

### 4. 项目级 Skills 设计
- [ ] 在每个 repo 下创建 `.claude/skills/` 或 `.opencode/skills/`
- [ ] 定义 repo 特有的 skills（如项目构建、测试、部署流程）
- [ ] ACP 调用 agent 时自动加载对应 repo 的 skills

### 5. MCP 统一配置
- [ ] MCP 只做基础服务：GitHub/GitLab 认证、文档检索
- [ ] 所有 agent 共享这些 MCP
- [ ] 不再按 agent 分配专属 MCP

### 6. 可选：Temporal 长任务
- [ ] 当AI订阅额度刷新后，用Temporal管理长时间运行的agent集群任务
- [ ] 消耗刷新后的额度

---

## 关键文件

```
~/OrchAI/
├── config/
│   ├── openclaw.yaml          # OpenClaw 配置
│   ├── agents/                # Agent 定义
│   │   ├── claude-code.md
│   │   ├── codex.md
│   │   ├── opencode.md
│   │   └── cursor.md
│   ├── projects.yaml          # 项目列表 + 对应Agent配置
│   └── mcp.yaml               # 统一 MCP 配置 (GitHub/GitLab/Docs)
├── skills/
│   └── router/               # Router Skill (LLM)
│       └── skill.md
└── repos/                    # 各个项目repo (每个repo独立的工作目录)
    ├── project-a/
    │   ├── .claude/skills/   # 项目级 skills
    │   │   ├── build/skill.md
    │   │   ├── test/skill.md
    │   │   └── deploy/skill.md
    │   └── ...
    ├── project-b/
    │   └── .opencode/skills/ # OpenCode 项目级 skills
    └── ...
```

## 调度模式说明

### ACP 调用流程
```
用户任务 → OpenClaw → Router判断 → 找到对应Repo 
→ 切换到该Repo目录 → ACP启动Agent (带 --project 或 cd 到目录)
→ Agent 在该Repo目录下运行 → 自动加载该Repo的project-level skills
→ 任务完成 → Agent 进程结束
```

### CLI Agent 生命周期
- **OpenCode**: `opencode run "task"` = 一次性执行，进程结束
- **Claude Code**: `claude -p "task"` = 一次性执行，进程结束
- 均非常驻进程，适合任务型调度

### MCP 配置 (统一共享)
```
所有 Agent 共享的 MCP:
- github (认证、PR、issue)
- gitlab (认证、MR、issue)
- docs (文档检索)
- context7 (代码上下文)
```
