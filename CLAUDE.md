# OrchAI - AI Coding Agent Orchestrator

## 项目简介

OrchAI 是一个本地运行的 AI 编程助理编排系统，通过 OpenClaw 作为统一入口，管理多个 coding agent（Claude Code、Codex、OpenCode、Cursor），自动路由任务到合适的 agent 和工作目录。

## 核心能力

- **统一入口**: OpenClaw 提供 Web UI 和会话管理
- **智能路由**: 基于关键词的任务路由（router.py）
- **工作区隔离**: 每个项目独立工作目录，自动加载项目级 skills
- **ACP 协议**: 通过 acpx 接入多种 coding agent
- **结果验证**: ResultValidator 验证 agent 执行结果

## 技术栈

- **控制层**: OpenClaw (统一入口、会话、workspace 路由)
- **Agent 层**: Claude Code / Codex / OpenCode / Cursor (通过 acpx 接入)
- **工具层**: MCP (GitHub、文档检索、知识库)
- **语言**: Python 3.11+

## 架构概览

```
用户 → OpenClaw (Web UI)
  ↓
Router Skill (关键词匹配路由)
  ↓
选择 Repo + Agent
  ↓
切换到项目目录 → acpx 启动 Agent
  ↓
Agent 执行任务
```

## 核心组件

### orchai/router.py
任务路由模块，基于关键词匹配：
- `route()` - 路由决策（关键词打分）
- `_match_score()` - 计算匹配分数
- `_classify_task()` - 任务类型分类
- `load_repos()` / `add_mapping()` - 仓库映射管理

### orchai/config.py
配置加载器（单例模式）：
- `_load_openclaw()` - OpenClaw 配置
- `_load_agents()` - Agent 列表
- `_load_mcp()` - MCP 服务器
- `_load_router_config()` - 路由配置

### orchai/acp_adapter.py
ACP 协议适配器：
- `execute_with_fallback()` - agent 回退链执行
- `_run_acpx_command()` - 调用 npx acpx

### orchai/validator.py
结果验证器：
- `validate_output()` - 验证输出
- `validate_file_changes()` - 文件变更检测
- `validate_bugfix_or_feature()` / `validate_qa()` - 分类验证

### orchai/cli.py
CLI 入口：
- `orchai init` - 初始化项目配置

## 项目结构

```
OrchAI/
├── orchai/                 # 核心 Python 包
│   ├── __init__.py
│   ├── router.py           # 路由逻辑
│   ├── config.py           # 配置加载
│   ├── acp_adapter.py      # ACP 适配器
│   ├── validator.py        # 结果验证
│   ├── cli.py              # CLI 入口
│   └── init.py             # 初始化逻辑
├── config/                 # 配置文件
│   ├── agents.yaml         # Agent 定义
│   ├── projects.yaml       # 项目列表
│   ├── mcp.yaml            # MCP 配置
│   ├── openclaw.yaml       # OpenClaw 配置
│   └── router_config.yaml  # 路由配置
├── skills/                 # 全局 skills
│   └── router/
│       ├── skill.md        # Router skill
│       └── repo_mappings.json # 仓库关键词映射
├── prompts/                # 提示词模板
│   ├── router-skill.md
│   └── orchai-router.md
├── tests/                  # 测试
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/                   # 文档
│   ├── ARCHITECTURE.md
│   └── PRODUCT.md
└── pyproject.toml          # 项目配置
```

## 快速开始

```bash
# 安装
uv venv && source .venv/bin/activate
uv pip install -e .

# 初始化
orchai init

# 运行 demo
python3 demo.py

# 直接使用 acpx
npx acpx@latest opencode --cwd tests/repos/test-backend "fix login bug"
```

## 路由配置

### repo_mappings.json 示例

```json
{
  "repos": [
    {
      "name": "test-backend",
      "path": "./tests/repos/test-backend",
      "keywords": ["auth", "api", "backend", "password", "login"],
      "description": "Backend service with authentication",
      "agents": {
        "primary": "opencode",
        "fallback": ["claude-code", "codex"]
      },
      "skills": ["build_and_test"]
    }
  ]
}
```

### 任务类型分类

| 关键词 | 类型 |
|--------|------|
| add, implement, create, new | feature |
| fix, bug, error, issue | bugfix |
| refactor, clean, improve | refactor |
| doc, readme, guide | docs |
| 其他 | qa |

## 文档导航

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - 系统架构和技术决策
- [PRODUCT.md](docs/PRODUCT.md) - 产品愿景和功能规划
- [docs/plans/](docs/plans/) - 实现计划和任务追踪
