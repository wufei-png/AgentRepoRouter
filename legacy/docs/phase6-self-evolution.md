# OrchAI 自我进化机制详细设计

> 已归档：本文档不代表当前运行时实现，仅保留作历史设计参考。

> 注：本文档保留为设计草案。当前运行时已迁移到 Shell + OpenClaw Skill 架构；
> 文中涉及的 repo 映射文件路径应理解为 `skills/router/references/repo_mappings.json` 模板，
> 部署后对应 `~/.openclaw/skills/router/references/repo_mappings.json`。

## 概述

自我进化 (Self-Evolution) 是 OrchAI 的核心特性之一，允许 Router 在无法确定项目时与用户交互学习，并将新知识持久化到配置中。

---

## 核心流程

```
用户输入 → Router 分析 → [找到唯一匹配] → 执行任务
              ↓
        [找到多个候选] → 返回候选列表 → 询问用户确认
              ↓
        [未找到匹配] → 返回空 → 询问用户项目路径
              ↓
用户确认 → 更新 repo_mappings.json → 记录学习历史 → 执行任务
```

---

## 数据结构

### 1. repo_mappings.json (扩展)

```json
{
  "repos": [
    {
      "name": "test-backend",
      "path": "/path/to/test-backend",
      "keywords": ["auth", "login", "backend", "password"],
      "description": "Python 后端服务",
      "agents": {
        "primary": "claude-code",
        "fallback": ["opencode", "codex"],
        "by_task": {
          "bugfix": "opencode",
          "feature": "claude-code",
          "qa": "codex"
        }
      },
      "skills": ["build_and_test"],
      "created_at": "2025-01-01T00:00:00Z",
      "updated_at": "2025-01-15T00:00:00Z"
    }
  ],
  "evolution": {
    "history": [
      {
        "id": "ev_001",
        "timestamp": "2025-01-15T10:30:00Z",
        "user_input": "修复登录问题",
        "selected_repo": "test-backend",
        "keywords_added": ["登录", "login"],
        "learned_from": "user_confirmation"
      }
    ],
    "stats": {
      "total_evolutions": 1,
      "successful_learning": 1,
      "failed_learning": 0
    }
  }
}
```

### 2. 新增配置文件

创建 `config/evolution.yaml`:

```yaml
enabled: true
auto_update: true  # 自动更新 mappings，无需每次询问
learning_options:
  - user_confirmation  # 用户确认后学习
  - pattern_inference # 从任务模式自动推断
  - explicit_teaching  # 用户显式教授

confidence_threshold: 1.5
max_keywords_per_repo: 20
history_retention_days: 90
```

---

## 关键函数设计

### 1. 询问用户 (ask_user_confirmation)

```python
def ask_user_confirmation(
    candidates: list[str],
    task: str
) -> dict[str, Any]:
    """
    当 Router 返回多个候选时，询问用户确认
    
    Args:
        candidates: 候选项目列表
        task: 用户原始任务
        
    Returns:
        {
            "confirmed": true,
            "selected_repo": "test-backend",
            "reason": "User selected from candidates"
        }
        或
        {
            "confirmed": false,
            "reason": "User cancelled"
        }
    """
    pass
```

### 2. 询问新项目路径 (ask_new_repo)

```python
def ask_new_repo(task: str) -> dict[str, Any]:
    """
    当没有找到任何匹配时，询问用户项目路径
    
    Returns:
        {
            "provided": true,
            "repo": {
                "name": "my-new-project",
                "path": "/path/to/project"
            }
        }
    """
    pass
```

### 3. 更新映射 (update_mapping)

```python
def update_mapping(
    repo_name: str,
    keywords: list[str],
    mappings_file: str = "skills/router/references/repo_mappings.json"
) -> dict[str, Any]:
    """
    更新 repo 的关键字映射
    
    Args:
        repo_name: 仓库名称
        keywords: 要添加的关键字
        mappings_file: 映射文件路径
        
    Returns:
        {
            "success": true,
            "repo": repo_name,
            "keywords_added": ["keyword1", "keyword2"],
            "evolution_id": "ev_xxx"
        }
    """
    pass
```

### 4. 记录学习历史 (record_evolution)

```python
def record_evolution(
    user_input: str,
    selected_repo: str,
    keywords_added: list[str],
    learning_type: str,  # "user_confirmation" | "pattern_inference" | "explicit_teaching"
    mappings_file: str = "skills/router/references/repo_mappings.json"
) -> dict[str, Any]:
    """
    记录学习历史
    
    Returns:
        {
            "success": true,
            "evolution_id": "ev_001",
            "history_entry": {...}
        }
    """
    pass
```

### 5. 关键字提取 (extract_keywords)

```python
def extract_keywords(task: str, repo_name: str) -> list[str]:
    """
    从任务描述中提取关键字
    
    Args:
        task: "修复 test-backend 的登录 bug"
        repo_name: "test-backend"
        
    Returns:
        ["登录", "login", "bug", "fix"]
    """
    # 移除项目名称
    # 提取动词/名词
    # 移除停用词
    # 返回关键字列表
    pass
```

---

## 集成到 Router

### 扩展 route() 返回值

```python
def route(
    task: str,
    repos: list[dict[str, Any]],
    confidence_threshold: float = 1.5,
    auto_learn: bool = False,  # 新增：是否自动学习
) -> dict[str, Any]:
    """
    路由任务
    
    Returns:
        # 找到唯一匹配
        {
            "found": true,
            "repo": "test-backend",
            "path": "/path/to/test-backend",
            "agent": "claude-code",
            "taskType": "bugfix",
            "confidence": 0.95,
            "needs_confirmation": false
        }
        
        # 找到多个候选
        {
            "found": false,
            "candidates": ["test-backend", "test-docs"],
            "reason": "Multiple repos match the task",
            "needs_confirmation": true,
            "confirmation_type": "select_repo"
        }
        
        # 未找到匹配
        {
            "found": false,
            "candidates": [],
            "reason": "No repos matched the task",
            "needs_confirmation": true,
            "confirmation_type": "new_repo"
        }
    """
```

---

## 交互流程实现

### 场景 1: 多个候选（需要用户选择）

```python
async def handle_multiple_candidates(
    route_result: dict,
    task: str
) -> dict[str, Any]:
    """处理多个候选项目的情况"""
    
    # 1. 显示候选列表给用户
    candidates = route_result["candidates"]
    print(f"找到多个可能的项目:")
    for i, repo in enumerate(candidates, 1):
        print(f"  {i}. {repo}")
    
    # 2. 询问用户选择
    selected = await ask_user_confirmation(candidates, task)
    
    if not selected["confirmed"]:
        return {"success": False, "cancelled": True}
    
    # 3. 提取关键字并更新映射
    keywords = extract_keywords(task, selected["selected_repo"])
    
    # 4. 记录学习历史
    record_evolution(
        user_input=task,
        selected_repo=selected["selected_repo"],
        keywords_added=keywords,
        learning_type="user_confirmation"
    )
    
    # 5. 更新映射文件
    update_mapping(selected["selected_repo"], keywords)
    
    return {
        "success": True,
        "repo": selected["selected_repo"],
        "keywords_learned": keywords
    }
```

### 场景 2: 没有匹配（需要用户提供项目）

```python
async def handle_no_match(
    route_result: dict,
    task: str
) -> dict[str, Any]:
    """处理没有找到匹配的情况"""
    
    # 1. 询问用户项目路径
    repo_info = await ask_new_repo(task)
    
    if not repo_info["provided"]:
        return {"success": False, "cancelled": True}
    
    new_repo = repo_info["repo"]
    
    # 2. 验证路径存在
    if not Path(new_repo["path"]).exists():
        return {
            "success": False,
            "error": f"Path does not exist: {new_repo['path']}"
        }
    
    # 3. 提取关键字
    keywords = extract_keywords(task, new_repo["name"])
    
    # 4. 添加新仓库到映射
    add_new_repo(new_repo, keywords)
    
    # 5. 记录学习历史
    record_evolution(
        user_input=task,
        selected_repo=new_repo["name"],
        keywords_added=keywords,
        learning_type="explicit_teaching"
    )
    
    return {
        "success": True,
        "repo": new_repo,
        "keywords_learned": keywords
    }
```

---

## Agent 提示词集成

在 `prompts/router-skill.md` 中添加：

```markdown
## 自我进化流程

当 Router 返回 `found: false` 时：

### 情况 1: 多个候选项目
1. 显示候选列表给用户
2. 询问: "你指的是哪个项目？"
3. 用户选择后，更新 `skills/router/references/repo_mappings.json`
4. 添加关键字映射
5. 继续执行任务

### 情况 2: 没有匹配的项目
1. 询问: "我没有找到匹配的项目。请告诉我项目路径，或者选择一个新的项目名称。"
2. 用户提供路径后，添加到 `repo_mappings.json`
3. 提取任务关键字作为初始关键字
4. 继续执行任务

### 关键字提取规则
- 从任务描述中提取有意义的关键词
- 移除: 项目名称、停用词、常见动词
- 保留: 功能名、技术栈、问题类型

### 学习历史
每次学习后，记录到 `evolution.history`:
- timestamp: 学习时间
- user_input: 原始用户输入
- selected_repo: 用户选择的项目
- keywords_added: 添加的关键字
- learned_from: 学习来源
```

---

## 配置选项

### 进化模式

| 模式 | 描述 | 适用场景 |
|------|------|----------|
| `user_confirmation` | 每次学习前询问用户确认 | 生产环境，精确控制 |
| `auto_update` | 自动更新，无需询问 | 快速迭代，用户信任系统 |
| `pattern_inference` | 从任务模式自动推断 | 高级用户，减少交互 |

### 配置示例

```yaml
# config/evolution.yaml
evolution:
  enabled: true
  mode: user_confirmation  # 或 auto_update
  
  # 自动学习配置
  auto_learn:
    enabled: true
    min_confidence: 0.8  # 只有置信度高于此值才自动学习
    max_keywords: 10     # 每个任务最多学习的关键字数
    
  # 关键字提取配置
  keywords:
    min_length: 2        # 最小关键字长度
    max_length: 20       # 最大关键字长度
    exclude:             # 排除列表
      - test
      - fix
      - add
      - create
      - the
      - a
      - an
      
  # 历史记录配置
  history:
    retention_days: 90
    max_entries: 1000
```

---

## 错误处理

### 1. 文件写入失败

```python
try:
    update_mapping(repo_name, keywords)
except PermissionError:
    logger.error("Permission denied writing to mappings file")
    # 回退到只记录内存，不持久化
except json.JSONDecodeError:
    logger.error("Invalid JSON in mappings file")
    # 尝试恢复或创建新文件
```

### 2. 用户取消

```python
if not confirmed:
    return {
        "success": False,
        "reason": "user_cancelled",
        "message": "用户取消了选择"
    }
```

### 3. 无效路径

```python
if not Path(repo_path).exists():
    return {
        "success": False,
        "error": "invalid_path",
        "message": f"项目路径不存在: {repo_path}"
    }
```

---

## 测试用例

### Case 1: 精确匹配（无需学习）

```python
def test_exact_match():
    # setup
    repos = [{"name": "backend", "keywords": ["backend", "api"]}]
    
    # execute
    result = route("在 backend 添加用户接口", repos)
    
    # assert
    assert result["found"] == True
    assert result["repo"] == "backend"
    assert result["needs_confirmation"] == False
```

### Case 2: 多个候选（需要选择）

```python
def test_multiple_candidates():
    repos = [
        {"name": "backend", "keywords": ["auth", "login"]},
        {"name": "frontend", "keywords": ["login", "ui"]}
    ]
    
    result = route("修复登录问题", repos)
    
    assert result["found"] == False
    assert result["confirmation_type"] == "select_repo"
    assert "backend" in result["candidates"]
    assert "frontend" in result["candidates"]
```

### Case 3: 无匹配（需要新项目）

```python
def test_no_match():
    repos = [
        {"name": "backend", "keywords": ["api"]}
    ]
    
    result = route("修复 XXX 项目的 bug", repos)
    
    assert result["found"] == False
    assert result["confirmation_type"] == "new_repo"
```

### Case 4: 学习历史记录

```python
def test_evolution_history():
    # 模拟用户选择
    result = record_evolution(
        user_input="修复登录问题",
        selected_repo="backend",
        keywords_added=["登录", "login"],
        learning_type="user_confirmation"
    )
    
    assert result["success"] == True
    assert "evolution_id" in result
    
    # 验证历史记录
    repos = load_repos()
    evolution = repos.get("evolution", {})
    assert len(evolution["history"]) == 1
    assert evolution["history"][0]["keywords_added"] == ["登录", "login"]
```

---

## 实现优先级

| 优先级 | 功能 | 工作量 |
|--------|------|--------|
| P0 | 扩展 repo_mappings.json 结构 | 0.5d |
| P0 | 关键字提取函数 | 1d |
| P0 | update_mapping() 增强 | 0.5d |
| P1 | record_evolution() | 0.5d |
| P1 | ask_user_confirmation() 交互 | 0.5d |
| P1 | ask_new_repo() 交互 | 0.5d |
| P2 | auto_update 模式 | 1d |
| P2 | 配置加载 | 0.5d |
| P3 | 单元测试 | 1d |
| P3 | 集成测试 | 1d |

---

## 文件变更清单

### 新增文件

1. `orchai/evolution.py` - 自我进化核心逻辑
2. `config/evolution.yaml` - 进化配置

### 修改文件

1. `orchai/router.py` - 扩展 route() 返回值
2. `prompts/router-skill.md` - 添加进化说明
3. `skills/router/references/repo_mappings.json` - 扩展结构

---

## 待讨论问题

1. **是否自动备份 mappings 文件？** - 建议每次更新前备份
2. **如何处理冲突的关键字？** - 不同 repo 相同关键字
3. **是否需要版本控制？** - Git 追踪 mappings 变化
4. **学习历史是否需要持久化？** - 当前设计是嵌入 mappings，可独立



已创建详细设计文档: docs/phase6-self-evolution.md
总结
1. CLI 命令 - 当前迁移方案使用直接 CLI ✅
推荐格式:
- `cd <repo> && claude -p "<task>"`
- `cd <repo> && claude --agent <name> "<task>"`
- `cd <repo> && opencode run "<task>"`
- `cd <repo> && agent -p "<task>"`
- `cd <repo> && codex "<task>"`
结论: 当前迁移方案不再依赖 acpx，运行时统一通过直接 CLI 和提示词约定完成路由。





2. 自我进化文档
已创建 docs/phase6-self-evolution.md，包含:
- 核心流程图: 用户输入 → Router → 候选/确认 → 更新 → 执行
- 数据结构设计: 扩展 repo_mappings.json + 新增 config/evolution.yaml
- 关键函数: ask_user_confirmation(), extract_keywords(), record_evolution(), update_mapping()
- 交互场景: 
  - 多个候选 → 用户选择
  - 无匹配 → 用户提供新项目
- Agent 提示词: 集成到 router-skill.md
- 配置选项: user_confirmation / auto_update / pattern_inference 三种模式
- 错误处理: 权限错误、用户取消、无效路径
- 测试用例: 4 个核心测试场景
- 实现优先级: P0-P3 分级
文档还列出了待讨论问题:
1. 是否自动备份 mappings 文件
2. 如何处理冲突关键字
3. 是否需要版本控制
4. 学习历史是否独立持久化
