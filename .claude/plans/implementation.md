# AgentRepoRouter 实现计划

## 项目目标

实现基于 OpenClaw 的多 agent 编排系统，支持智能路由、多项目管理、自动 fallback 和自我进化。

## 核心设计决策

### 1. Agent 架构
- **主要逻辑在 Router Skill 中**
- **提供 init 命令**：用户选择创建新 agent 或使用现有 agent
  - 新 agent：专门的 `agent-repo-router` agent，提示词包含路由职责
  - 现有 agent：复用 claude-code/opencode，添加 Router Skill

### 2. 自我进化机制
- Skill 分析任务 → 找不到 repo 时返回候选列表
- Agent 与用户交互确认
- Agent 自动更新 `router-skill.md` 添加新 repo 映射

### 3. Fallback 策略
- 自动按优先级尝试：首选 → 备选1 → 备选2
- 配置文件定义优先级顺序

### 4. Project-Level 支持
测试 repo 配置所有三种 CLI：
- `.claude.json` (Claude Code)
- `opencode.json` (OpenCode)
- `.codex/config.toml` (Codex)

---

## 实现阶段

### Phase 1: 初始化系统 (init 命令)

**目标**: 提供交互式初始化，配置 OpenClaw 和 agent

**任务**:
1. 创建 `orchai init` 命令
2. 询问用户选择：
   - [ ] 创建新的 `agent-repo-router` agent
   - [ ] 使用现有 agent (claude-code/opencode/codex)
3. 生成配置文件：
   - [ ] `config/openclaw.yaml` - OpenClaw 配置
   - [ ] `config/agents.yaml` - Agent 注册表
   - [ ] `config/projects.yaml` - 项目列表
   - [ ] `config/mcp.yaml` - MCP 配置
4. 如果选择新 agent：
   - [ ] 生成 agent 定义文件 `config/agents/agent-repo-router.md`
   - [ ] 包含专门的路由提示词
   - [ ] 包含自我进化指令

**输出文件**:
```
config/
├── openclaw.yaml
├── agents.yaml
├── projects.yaml
├── mcp.yaml
└── agents/
    └── agent-repo-router.md  (可选)
```

---

### Phase 2: Router Skill 实现

**目标**: 实现智能路由逻辑

**任务**:
1. 创建 Router Skill 目录结构
   ```
   skills/agent-repo-router/
   ├── skill.md           # Skill 定义和提示词
   ├── router.py          # 路由逻辑实现
   └── repo_mappings.json # Repo 映射配置
   ```

2. 实现路由逻辑 (`router.py`):
   - [ ] 任务分类（LLM 分析）
   - [ ] Repo 匹配（关键字 + 模糊匹配）
   - [ ] Agent 选择（按任务类型 + fallback）
   - [ ] 返回路由结果或候选列表

3. Skill 定义 (`skill.md`):
   - [ ] 输入格式：用户任务描述
   - [ ] 输出格式：
     ```json
     {
       "found": true,
       "repo": "project-a",
       "agent": "claude-code",
       "taskType": "bugfix",
       "confidence": 0.95
     }
     ```
     或
     ```json
     {
       "found": false,
       "candidates": ["project-a", "project-b"],
       "reason": "Multiple projects match 'login'"
     }
     ```

4. Repo 映射配置 (`repo_mappings.json`):
   ```json
   {
     "repos": [
       {
         "name": "project-a",
         "path": "/path/to/project-a",
         "keywords": ["auth", "login", "user"],
         "description": "Authentication service",
         "agents": {
           "primary": "claude-code",
           "fallback": ["opencode", "codex"]
         },
         "skills": ["build_and_test"]
       }
     ]
   }
   ```

---

### Phase 3: ACP 适配层

**目标**: 实现 ACP 协议调用，支持多 CLI

**任务**:
1. 创建 ACP 适配器 (`src/acp_adapter.py`):
   - [ ] 启动 ACP 客户端
   - [ ] 创建/恢复会话
   - [ ] 提交任务
   - [ ] 等待结果
   - [ ] 处理错误和 fallback

2. 支持三种 CLI:
   - [ ] Claude Code: `npx @zed-industries/claude-agent-acp`
   - [ ] OpenCode: `npx opencode-ai acp`
   - [ ] Codex: `npx @zed-industries/codex-acp`

3. Fallback 逻辑:
   ```python
   async def execute_with_fallback(repo, task, agents):
       for agent in agents:  # [primary, fallback1, fallback2]
           try:
               result = await execute_agent(agent, repo, task)
               return result
           except AgentUnavailable:
               continue
       raise AllAgentsFailed()
   ```

---

### Phase 4: 测试 Repo 创建

**目标**: 创建两个测试项目，配置完整的 project-level 文件

**Repo 1: test-backend** (Python 项目)
```
tests/repos/test-backend/
├── .claude.json          # Claude Code 配置
├── opencode.json         # OpenCode 配置
├── .codex/
│   └── config.toml       # Codex 配置
├── .claude/skills/
│   └── build_and_test/
│       └── skill.md      # 构建和测试 skill
├── src/
│   ├── main.py
│   └── auth.py           # 故意留一个 bug
├── tests/
│   └── test_auth.py
└── README.md
```

**任务**:
- [ ] 创建基础 Python 项目结构
- [ ] 添加故意的 bug（用于测试 bugfix）
- [ ] 配置三种 CLI 的 project-level 文件
- [ ] 创建 `build_and_test` skill
- [ ] 编写单元测试

**Repo 2: test-docs** (文档项目)
```
tests/repos/test-docs/
├── .claude.json
├── opencode.json
├── .codex/config.toml
├── docs/
│   ├── architecture.md
│   ├── api.md
│   └── deployment.md
└── README.md
```

**任务**:
- [ ] 创建文档项目
- [ ] 配置三种 CLI
- [ ] 添加技术文档内容

---

### Phase 5: 端到端测试

**目标**: 验证完整的路由和执行流程

**测试用例**:

#### Case 1: Feature 开发 (test-backend)
```python
# 测试输入
user_input = "在 test-backend 添加密码重置功能"

# 期望流程
1. Router 识别: taskType="feature", repo="test-backend"
2. 选择 agent: claude-code (primary)
3. 切换到 test-backend 目录
4. 加载 build_and_test skill
5. 实现功能
6. 运行测试
7. 测试通过 → 返回结果
```

#### Case 2: Bugfix (test-backend)
```python
# 测试输入
user_input = "修复 test-backend 的登录 bug"

# 期望流程
1. Router 识别: taskType="bugfix", repo="test-backend"
2. 选择 agent: opencode (primary for bugfix)
3. 切换目录
4. 加载 build_and_test skill
5. 修复 bug
6. 运行测试
7. 测试失败 → 继续修复
8. 测试通过 → 返回结果
```

#### Case 3: 文档问答 (test-docs)
```python
# 测试输入
user_input = "test-docs 的部署流程是什么？"

# 期望流程
1. Router 识别: taskType="qa", repo="test-docs"
2. 选择 agent: codex
3. 切换目录
4. 读取 docs/deployment.md
5. 返回答案
```

#### Case 4: 模糊项目（自我进化）
```python
# 测试输入
user_input = "修复登录问题"  # 没有指定项目

# 期望流程
1. Router 分析: 找到多个候选 [test-backend, test-docs]
2. 返回: {"found": false, "candidates": [...]}
3. Agent 询问用户: "你指的是哪个项目？"
4. 用户选择: "test-backend"
5. Agent 更新 router-skill.md 添加映射
6. 继续执行任务
```

#### Case 5: Fallback 测试
```python
# 测试输入
user_input = "在 test-backend 添加日志功能"

# 模拟场景: claude-code 不可用

# 期望流程
1. Router 选择: claude-code (primary)
2. 尝试启动 claude-code → 失败
3. Fallback 到 opencode
4. 成功执行任务
5. 返回结果，标注使用了 opencode
```

**测试实现**:
- [ ] 单元测试: `tests/unit/test_router.py`
- [ ] 单元测试: `tests/unit/test_acp_adapter.py`
- [ ] 集成测试: `tests/integration/test_routing.py`
- [ ] 端到端测试: `tests/e2e/test_full_flow.py`

---

### Phase 6: 自我进化实现

**目标**: Agent 自动学习新的 repo 映射

**任务**:
1. Agent 提示词（如果创建新 agent）:
   ```markdown
   # AgentRepoRouter Router Agent

   你是一个智能路由 agent，负责将用户任务分配给合适的项目和 agent。

   ## 核心职责
   1. 分析用户任务
   2. 调用 Router Skill 获取路由结果
   3. 如果找不到项目，询问用户并学习

   ## 自我进化流程
   当 Router Skill 返回 `found: false` 时：
   1. 列出候选项目让用户选择
   2. 用户确认后，更新 `skills/agent-repo-router/repo_mappings.json`
   3. 添加新的关键字映射
   4. 继续执行任务

   ## 示例
   用户: "修复登录问题"
   Router: {"found": false, "candidates": ["test-backend", "test-docs"]}
   你: "我找到两个可能的项目：test-backend 和 test-docs。你指的是哪个？"
   用户: "test-backend"
   你: [更新 repo_mappings.json，添加 "登录" → "test-backend" 映射]
   你: "好的，我已经记住了。现在开始修复..."
   ```

2. 实现自动更新逻辑:
   - [ ] 读取 `repo_mappings.json`
   - [ ] 添加新关键字到对应 repo
   - [ ] 保存更新后的配置
   - [ ] 记录学习历史

---

## 项目结构

```
AgentRepoRouter/
├── src/
│   ├── __init__.py
│   ├── cli.py              # orchai 命令行入口
│   ├── init.py             # init 命令实现
│   ├── router.py           # Router 逻辑
│   └── acp_adapter.py      # ACP 适配器
├── skills/
│   └── router/
│       ├── skill.md
│       ├── router.py
│       └── repo_mappings.json
├── config/
│   ├── openclaw.yaml
│   ├── agents.yaml
│   ├── projects.yaml
│   ├── mcp.yaml
│   └── agents/
│       └── agent-repo-router.md
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── e2e/
│   └── repos/
│       ├── test-backend/
│       └── test-docs/
├── docs/
├── CLAUDE.md
└── README.md
```

---

## 验收标准

### 功能性
- [ ] `orchai init` 可正常初始化配置
- [ ] Router 能正确识别 5 种任务类型
- [ ] 支持 3 种 CLI (Claude Code, OpenCode, Codex)
- [ ] Fallback 逻辑正常工作
- [ ] 自我进化功能可用
- [ ] 所有端到端测试通过

### 测试覆盖
- [ ] 单元测试覆盖率 > 80%
- [ ] 集成测试覆盖核心流程
- [ ] 端到端测试覆盖 5 个场景

### 文档
- [ ] README 包含快速开始
- [ ] CLAUDE.md 包含架构说明
- [ ] 每个 skill 有完整的 skill.md

---

## 风险和缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| ACP 协议兼容性问题 | 高 | 先测试单个 CLI，逐步添加 |
| Router LLM 准确率低 | 中 | 提供详细的提示词，支持用户确认 |
| Project-level 配置复杂 | 中 | 提供模板和示例 |
| Fallback 逻辑失败 | 低 | 完善错误处理和日志 |

---

## 下一步

完成此计划后：
1. 添加更多 agent (Cursor, Gemini)
2. 集成 Temporal 支持长任务
3. 添加 Web UI
4. 支持更多 MCP 服务
