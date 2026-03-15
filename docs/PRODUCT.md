# 产品愿景

## 核心价值

OrchAI 是一个**本地运行的全能编程助理编排系统**，解决多 AI coding agent 管理和任务分配问题。

## 目标用户

- 管理多个项目的开发者
- 需要不同 AI agent 处理不同任务的团队
- 希望统一入口管理所有 AI 工具的个人

## 核心功能

### 1. 统一入口
- 一个 Web UI 管理所有 agent
- 统一会话历史
- 跨项目记忆持久化

### 2. 智能路由
- 自动识别任务类型
- 选择最合适的 agent
- 自动切换到正确的项目目录

### 3. 工作区隔离
- 每个项目独立配置
- 项目级 skills 自动加载
- 避免上下文污染

### 4. 长任务管理
- 定时任务（每 5 小时刷新订阅）
- 全量代码审查
- 多轮脑暴和方案优化
- MVP 自动实现

### 5. 知识库集成
- 统一接入 GitHub/GitLab
- 文档检索
- 代码索引

## 使用场景

### 场景 1: 日常开发
```
用户: "修复 project-a 的登录 bug"
→ Router 识别为 bugfix
→ 切换到 project-a 目录
→ 启动 Claude Code
→ 加载 project-a 的测试 skills
→ 修复并运行测试
```

### 场景 2: 代码审查
```
用户: "审查 project-b 的 PR #123"
→ Router 识别为 code_review
→ 切换到 project-b 目录
→ 启动 Codex
→ 调用 GitHub MCP 获取 PR
→ 生成审查报告
```

### 场景 3: 知识库问答
```
用户: "如何在 project-c 中配置 Redis？"
→ Router 识别为 knowledge_qa
→ 调用文档检索 MCP
→ 搜索 project-c 文档
→ 返回配置指南
```

### 场景 4: 长时间任务
```
用户: "对所有项目做全量安全审查"
→ 创建 Temporal Workflow
→ 并发启动多个 agent
→ 每个 agent 审查一个项目
→ 汇总结果
→ 生成总报告
```

## 功能优先级

### P0 (MVP)
- [ ] OpenClaw 安装和配置
- [ ] ACP 接入 Claude Code / OpenCode
- [ ] Router Skill 实现
- [ ] 基础 MCP 配置（GitHub）
- [ ] 单项目工作区测试

### P1 (核心功能)
- [ ] 多项目配置
- [ ] 项目级 skills 加载
- [ ] 所有 agent 接入（Codex、Cursor）
- [ ] 完整 MCP 配置（文档、知识库）

### P2 (增强功能)
- [ ] Temporal 集成
- [ ] 长任务管理
- [ ] 定时任务
- [ ] 任务进度查询

### P3 (优化)
- [ ] 结果缓存
- [ ] Agent 性能监控
- [ ] 成本追踪
- [ ] 自定义 Router 规则

## 成功指标

- 任务路由准确率 > 90%
- 平均响应时间 < 5 秒
- Agent 利用率均衡
- 用户满意度 > 4.5/5
