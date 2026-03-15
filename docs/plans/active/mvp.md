# MVP 实现计划

**状态**: Active
**创建时间**: 2026-03-15
**目标**: 实现 OrchAI 最小可用版本

## 目标

搭建基础架构，实现单项目的智能路由和 agent 调度。

## 实现步骤

### Phase 1: 环境搭建
- [ ] 安装 OpenClaw
- [ ] 配置 OpenClaw workspace
- [ ] 测试 OpenClaw Web UI

### Phase 2: Agent 接入
- [ ] 通过 ACP 接入 Claude Code
- [ ] 通过 ACP 接入 OpenCode
- [ ] 测试 agent 基础调用

### Phase 3: Router Skill
- [ ] 创建 Router Skill 目录结构
- [ ] 实现任务分类逻辑（LLM）
- [ ] 定义任务类型映射规则
- [ ] 测试 Router 准确性

### Phase 4: MCP 配置
- [ ] 配置 GitHub MCP
- [ ] 配置文档检索 MCP
- [ ] 测试 MCP 工具调用

### Phase 5: 单项目测试
- [ ] 选择一个测试项目
- [ ] 配置项目级 skills
- [ ] 端到端测试完整流程
- [ ] 验证任务路由正确性

## 验收标准

- OpenClaw 正常启动并可访问
- 至少 2 个 agent 可通过 ACP 调用
- Router 能正确识别 3 种以上任务类型
- 单个项目的完整流程可运行
- MCP 工具可正常调用

## 风险

- OpenClaw 配置复杂度
- ACP 协议兼容性
- Router LLM 准确率

## 下一步

完成 MVP 后进入 Phase 2: 多项目支持
