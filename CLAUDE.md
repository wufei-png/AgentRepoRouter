# OrchAI - AI Coding Agent Orchestrator

## 项目简介

OrchAI 是一个本地运行的 AI 编程助理编排系统，通过 OpenClaw 作为统一入口，管理多个 coding agent（Claude Code、Codex、OpenCode、Cursor），自动路由任务到合适的 agent 和工作目录。

## 核心能力

- **统一入口**: OpenClaw 提供 Web UI 和会话管理
- **智能路由**: LLM 驱动的 Router 自动选择合适的 agent 和项目
- **工作区隔离**: 每个项目独立工作目录，自动加载项目级 skills
- **长任务支持**: 可选 Temporal 管理耐久任务（全量 review、脑暴、MVP 实现）
- **知识库集成**: MCP 统一接入 GitHub、文档检索等服务

## 技术栈

- **控制层**: OpenClaw (统一入口、会话、workspace 路由)
- **编排层**: Temporal (可选，用于长任务)
- **Agent 层**: Claude Code / Codex / OpenCode / Cursor (通过 ACP 接入)
- **工具层**: MCP (GitHub、文档检索、知识库)
- **语言**: Python

## 架构概览

```
用户 → OpenClaw (Web UI)
  ↓
Router Skill (LLM 判断任务类型)
  ↓
选择 Repo + Agent
  ↓
切换到项目目录 → ACP 启动 Agent
  ↓
Agent 加载项目级 Skills → 执行任务
  ↓
结果返回 OpenClaw
```

## 开发工作流

1. **短任务** (< 30 分钟): 直接通过 OpenClaw → ACP → Agent
2. **长任务** (> 30 分钟): OpenClaw → Temporal Workflow → Agent 集群
3. **定时任务**: Temporal Schedule 自动触发

## 文档导航

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - 系统架构和技术决策
- [PRODUCT.md](docs/PRODUCT.md) - 产品愿景和功能规划
- [docs/plans/](docs/plans/) - 实现计划和任务追踪

## 快速开始

```bash
# 安装 OpenClaw
npm install -g openclaw

# 启动 OpenClaw
openclaw start

# 访问 Web UI
open http://localhost:3000
```

## 项目结构

```
OrchAI/
├── config/              # 配置文件
│   ├── agents/         # Agent 定义
│   ├── projects.yaml   # 项目列表
│   └── mcp.yaml        # MCP 配置
├── skills/             # 全局 skills
│   └── router/         # Router skill
├── workflows/          # Temporal workflows (可选)
└── repos/              # 管理的项目仓库
```
