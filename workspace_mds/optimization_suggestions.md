# OrchAI 优化建议

## 一、架构优化点

### 1.1 简化 MCP 管理（✅ 已在计划中）

**当前方案**：统一共享 MCP，所有 Agent 共享基础服务

**优化建议**：
```yaml
# config/mcp.yaml
shared_mcp:
  - github      # 所有 Agent 共享
  - gitlab
  - docs
  - context7

# 项目级 MCP 通过 Skills 实现
# repos/project-a/.claude/skills/build/skill.md
```

**收益**：
- 减少配置重复
- 降低上下文消耗
- 简化认证管理

### 1.2 项目级 Skills 替代专属 MCP（✅ 强烈推荐）

**问题**：每个 Agent 配一套 MCP 导致配置膨胀

**解决方案**：
```
repos/project-a/
├── .claude/skills/
│   ├── build/skill.md       # 项目构建流程
│   ├── test/skill.md        # 测试流程
│   └── deploy/skill.md      # 部署流程
```

**收益**：
- Agent 启动时自动加载
- 项目特定逻辑封装
- 减少 MCP 服务器数量

### 1.3 Session 复用策略（借鉴 acpx）

**核心机制**：
```typescript
// 按 (git root, agent, name) 三元组路由
sessionKey = `${gitRoot}:${agentType}:${sessionName}`

// 支持并行会话
acpx codex -s bugfix 'fix flaky test'
acpx codex -s release 'draft release notes'
```

**收益**：
- 避免重复初始化
- 保持上下文连续性
- 支持并行工作流

---

## 二、Router 优化

### 2.1 混合路由策略（规则 + LLM）

**Phase 1：规则优先**
```typescript
// 快速路由（无 LLM 调用）
if (task.includes('review PR')) return 'code-reviewer';
if (task.includes('fix bug')) return 'bug-fixer';
if (cwd.includes('frontend')) return 'frontend-agent';
```

**Phase 2：LLM 兜底**
```typescript
// 复杂任务使用 LLM 分析
const analysis = await llm.analyze(task);
return analysis.suggestedAgent;
```

**收益**：
- 降低 API 成本
- 提升响应速度
- 保持灵活性

### 2.2 项目匹配优化

**方法 1：Git Root 匹配**
```typescript
// 从当前目录向上查找 git root
const gitRoot = findGitRoot(cwd);
const project = projectRegistry.get(gitRoot);
```

**方法 2：关键字匹配**
```typescript
// 基于任务关键字匹配项目
const keywords = extractKeywords(task);
const project = matchProjectByKeywords(keywords);
```

**方法 3：最近使用**
```typescript
// 优先使用最近活跃的项目
const recentProjects = getRecentProjects(userId);
```

---

## 三、性能优化

### 3.1 Session 预热

**问题**：首次启动 Agent 需要 5-10s

**解决方案**：
```typescript
// 启动时预热常用 Agent
await Promise.all([
  acpAdapter.warmup('claude', '/path/to/main-project'),
  acpAdapter.warmup('opencode', '/path/to/frontend'),
]);
```

**收益**：
- 首次任务响应更快
- 用户体验提升

### 3.2 并行执行

**场景**：多个独立子任务

```typescript
// 并行执行
const results = await Promise.all([
  acpAdapter.execute('tester', cwd, 'run tests'),
  acpAdapter.execute('doc-writer', cwd, 'update docs'),
  acpAdapter.execute('security', cwd, 'security scan'),
]);
```

**收益**：
- 总耗时 = max(子任务耗时)
- 而非 sum(子任务耗时)

### 3.3 结果缓存

**场景**：重复查询

```typescript
// 缓存知识库查询结果
const cacheKey = `qa:${hash(question)}`;
const cached = await cache.get(cacheKey);
if (cached) return cached;

const result = await agent.query(question);
await cache.set(cacheKey, result, ttl: 3600);
```

---

## 四、可靠性优化

### 4.1 错误重试

**借鉴 acpx**：
```typescript
async function executeWithRetry(
  fn: () => Promise<T>,
  maxRetries = 3
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await sleep(2 ** i * 1000); // 指数退避
    }
  }
}
```

### 4.2 Fallback 机制

**Agent 不可用时的降级策略**：
```typescript
const agentPriority = ['opencode', 'claude', 'codex'];

for (const agent of agentPriority) {
  try {
    return await acpAdapter.execute(agent, cwd, task);
  } catch (error) {
    console.warn(`${agent} failed, trying next...`);
  }
}
```

### 4.3 超时控制

**防止任务卡死**：
```typescript
const result = await Promise.race([
  acpAdapter.execute(agent, cwd, task),
  timeout(30 * 60 * 1000) // 30 分钟超时
]);
```

---

## 五、用户体验优化

### 5.1 进度反馈

**实时显示任务进度**：
```typescript
// 监听 session/update 通知
client.on('session/update', (event) => {
  if (event.type === 'tool_call') {
    ui.showProgress(`正在执行: ${event.tool}`);
  }
});
```

### 5.2 任务预估

**Router 输出预估时间**：
```typescript
interface RouterOutput {
  estimatedDuration: number; // 分钟
  confidence: number;         // 0-1
}

// 显示给用户
ui.show(`预计耗时: ${duration} 分钟 (置信度: ${confidence * 100}%)`);
```

### 5.3 中断恢复

**长任务支持暂停/恢复**：
```typescript
// 用户按 Ctrl+C
process.on('SIGINT', async () => {
  await client.requestCancelActivePrompt();
  await sessionManager.saveState();
  ui.show('任务已暂停，可使用 orchai resume 恢复');
});
```

---

## 六、成本优化

### 6.1 模型选择策略

**根据任务复杂度选择模型**：
```typescript
const modelMap = {
  'simple': 'claude-haiku',      // 简单任务
  'medium': 'claude-sonnet',     // 中等任务
  'complex': 'claude-opus'       // 复杂任务
};

const model = modelMap[routerOutput.complexity];
```

### 6.2 Prompt 缓存

**复用系统提示词**：
```typescript
// Claude API 支持 prompt caching
const systemPrompt = {
  type: 'text',
  text: sharedInstructions,
  cache_control: { type: 'ephemeral' }
};
```

**收益**：
- 减少 90% 的 prompt token 成本
- 适用于共享指令

---

## 七、监控与调试

### 7.1 日志记录

**结构化日志**：
```typescript
logger.info('task_started', {
  taskId,
  agent,
  project,
  estimatedDuration
});

logger.info('task_completed', {
  taskId,
  duration,
  tokensUsed,
  success
});
```

### 7.2 性能指标

**关键指标**：
- 任务响应时间（P50, P95, P99）
- Agent 启动时间
- Token 使用量
- 成功率

### 7.3 错误追踪

**集成 Sentry（可选）**：
```typescript
Sentry.captureException(error, {
  tags: {
    agent,
    project,
    taskType
  }
});
```

---

## 八、安全优化

### 8.1 权限最小化

**默认 approve-reads**：
```typescript
const defaultPermissions = 'approve-reads';

// 敏感操作需要确认
if (operation.type === 'write' || operation.type === 'execute') {
  const approved = await ui.confirm(`允许 ${operation.description}?`);
  if (!approved) throw new Error('Operation denied');
}
```

### 8.2 敏感文件保护

**自动检测敏感文件**：
```typescript
const sensitivePatterns = [
  '.env',
  'credentials.json',
  'id_rsa',
  '*.pem'
];

function isSensitiveFile(path: string): boolean {
  return sensitivePatterns.some(pattern =>
    minimatch(path, pattern)
  );
}
```

### 8.3 审计日志

**记录所有文件操作**：
```typescript
auditLog.record({
  timestamp: new Date(),
  agent,
  operation: 'write',
  path: filePath,
  approved: true
});
```

---

## 九、扩展性优化

### 9.1 插件系统

**支持自定义 Agent**：
```typescript
// config/agents.yaml
agents:
  custom-agent:
    command: './bin/my-agent'
    protocol: 'acp'
    capabilities: ['code', 'test']
```

### 9.2 Hook 系统

**生命周期钩子**：
```typescript
interface Hooks {
  beforeTask?: (context: OrchAIContext) => Promise<void>;
  afterTask?: (context: OrchAIContext, result: AgentResult) => Promise<void>;
  onError?: (error: Error) => Promise<void>;
}
```

### 9.3 自定义 Router

**支持用户自定义路由逻辑**：
```typescript
// config/router.ts
export function customRouter(task: string): RouterOutput {
  // 自定义路由逻辑
  if (task.includes('urgent')) {
    return { agent: 'fast-agent', priority: 'high' };
  }
  // ...
}
```

---

## 十、总结

### 优先级排序

**P0（必须）**：
- ✅ 统一 MCP 管理
- ✅ Session 复用
- ✅ 错误重试
- ✅ 权限控制

**P1（重要）**：
- ✅ 混合路由策略
- ✅ 并行执行
- ✅ 进度反馈
- ✅ Fallback 机制

**P2（可选）**：
- 结果缓存
- 模型选择策略
- 插件系统
- 审计日志

### 实施建议

1. **MVP 阶段**：只做 P0
2. **Beta 阶段**：加入 P1
3. **生产阶段**：逐步加入 P2
