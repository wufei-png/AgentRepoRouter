# OrchAI - 全能私人助理架构总结

## 项目概述

打造本地电脑运行的全能私人助理，处理代码需求、代码 bug、知识库问答。

---

## 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│                    交互控制层 (OpenClaw)                      │
│  - 聊天入口 / Web UI                                        │
│  - 工作区切换 / Session 管理                                 │
│  - 用户记忆可视化 / Workspace 路由                            │
│  - ACP 接线层 / agent 入口                                    │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌──────────────────┐           ┌──────────────────────┐
    │   通道A: 直连模式  │           │   通道B: 耐久模式    │
    │ (短任务 <30-60min) │           │ (长任务/定时/复杂)    │
    └──────────────────┘           └──────────────────────┘
              │                               │
              ▼                               ▼
    ┌──────────────────┐           ┌──────────────────────┐
    │ router/manager   │           │   Temporal Workflow  │
    │    ↓             │           │       ↓               │
    │ ACP agents       │           │   Activities          │
    │ + MCP tools      │           │   + ACP agents        │
    └──────────────────┘           │   + MCP tools         │
                                   └──────────────────────┘
```

---

## 协议分层选型

| 协议 | 用途 | 说明 |
|------|------|------|
| **MCP** | 工具和知识库 | 本地 repo index、文档库、向量库、Git、Issue、浏览器、数据库 |
| **ACP** | 本地 coding CLI agent | OpenClaw 官方已内置 cursor、codex、claude、opencode、gemini、qwen |
| **A2A** | 未来跨系统边界 | MCP 是 agent 用工具，A2A 是 agent 协作 |
| **Temporal** | 耐久编排 | 长任务、定时调度、失败重试、后台任务 |

---

## MCP 管理策略 - 统一共享模式

### 核心原则
**MCP 只做基础服务，所有 Agent 共享，不按 Agent 分配专属 MCP**

原因：每个 agent 都配一套 MCP 会导致：
- 配置重复
- 认证重复
- 上下文窗口快速膨胀（OpenCode 官方已警告）

### 统一 MCP (所有 Agent 共享)
- GitHub / GitLab (认证、PR、issue、MR)
- 文档检索 / Context7
- Sentry (可选)

### 项目级 Skills 替代专属 MCP
大部分工具类能力通过 **项目级 Skills** 实现：
- 每个 repo 有自己的 `.claude/skills/` 或 `.opencode/skills/`
- 定义项目特有的构建、测试、部署等流程
- Agent 启动时自动加载对应 repo 的 skills

---

## CLI Agent 生命周期与工作目录

### 两种运行模式
| 模式 | 命令 | 生命周期 |
|------|------|---------|
| **交互模式 (TUI)** | `opencode` / `claude` | 常驻，保持会话 |
| **一次性模式** | `opencode run "task"` / `claude -p "task"` | 执行完退出 |

### 调度选型
**OrchAI 使用一次性模式**：
- 任务完成后进程自动结束
- 适合任务型调度（ACP 调用 → 执行 → 返回结果 → 结束）
- 不占用常驻资源
- 每次任务可重新加载最新的 skills 和上下文

### 指定工作目录
| Agent | 指定目录方式 |
|-------|-------------|
| OpenCode | `opencode /path/to/project` |
| Claude Code | `cd /path/to/project && claude` 或 `--add-dir` |
| Codex | `codex --directory` |

### 项目级 Skill 加载
- **Claude Code**: `.claude/skills/<skill-name>/SKILL.md`
- **OpenCode**: `.opencode/skills/<skill-name>/SKILL.md` 或 `.claude/skills/`
- 自动发现：从当前目录向上扫描直到 git root

---

## 调度流程

```
用户任务 → OpenClaw → Router 判断 → 找到对应 Repo 
→ 切换到该 Repo 目录 → ACP 启动 Agent
→ Agent 在该 Repo 目录下运行 → 自动加载该 Repo 的 project-level skills
→ 加载统一 MCP (GitHub/GitLab/Docs)
→ 任务完成 → Agent 进程结束 → 返回结果
```

---

## 任务路由规则

### 进入 Temporal 耐久模式的条件
- 预计超过 30-60 分钟
- 需要定时触发
- 需要失败自动重试
- 需要中断后续跑
- 需要中途追加指令不丢上下文
- 需要审计轨迹或进度查询

### 不走 Temporal 的情况
- 修一个 bug
- 写一个函数
- 回答知识库问题
- 小范围 code review
- 单轮 brainstorm
- 10-30 分钟内能结束的任务

---

## Temporal 核心概念

| 概念 | 说明 |
|------|------|
| **Workflow** | 任务蓝图 + 当前实例，状态持久化 |
| **Activity** | 真正有副作用的步骤 (调用 CLI、读写文件、发请求) |
| **Task Queue** | 按任务类型分流，清晰路由 |
| **Worker** | 实际干活的进程 |
| **Signal/Query/Update** | 运行中发新指令、查状态、动态更新 |
| **Schedule** | 周期性启动 (替代 Cron) |

---

## 组件职责划分

### OpenClaw 负责
- 从哪进来 (统一入口)
- 当前会话属于哪个 workspace
- 用哪个 agent 接活
- UI 怎么展示
- 最终结果直出还是转发
- 短任务直接同步回复

### Temporal 负责
- 任务是不是要跑几小时
- 中途挂了怎么恢复
- 并行几个子任务
- 哪个子任务失败后重试
- 哪些步骤依赖哪些步骤
- 定时任务什么时候再跑
- 暂停/恢复/补跑/回放

---

## 最佳实践总结

> **一句话收束**：
>
> 用 OpenClaw 做壳，用 ACP 接编程 agent，用 MCP 接知识库和工具，用 A2A 做未来边界，用 Temporal 管耐久流程。

### 推荐技术栈

| 层级 | 技术选型 |
|------|----------|
| 控制面 | OpenClaw |
| Agent 适配 | ACP (acpx) |
| 工具/知识 | MCP + MCPM |
| 共享服务入口 | mcpport (仅需要时) |
| 耐久编排 | Temporal |
| 多 agent 并行 | MCO (可选) |

### 启动路径

1. **MVP 阶段**: OpenClaw + ACP + MCP (本地 STDIO)
2. **进阶阶段**: 加 MCO 做 fan-out
3. **生产阶段**: 加 Temporal 管耐久任务，接口逐步 A2A 化

---

## 不推荐的做法

- ❌ LangGraph 每个 node 一个 agent (更适合固定流程，不适合开放式 agent 操作系统)
- ❌ 所有 MCP 全量网关化 (单机优先本地 STDIO)
- ❌ 每个 agent 配完整一套 MCP (上下文消耗过大)
- ❌ Temporal 替代 OpenClaw (前后台配合，不是二选一)

---

*本文档基于架构讨论生成，供后续设计和实现参考*
