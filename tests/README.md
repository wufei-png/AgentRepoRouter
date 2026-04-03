# OrchAI Tests

## Scope

当前测试覆盖的是迁移后的 Shell + OpenClaw Skill 架构：

- `install.sh` 的环境检查
- `install.sh` 的语言选择和 CLI 选择
- `install.sh` 的 Manual / Auto scan 项目发现
- Router Skill 部署路径
- `repo_mappings.json` 生成路径和结构
- 测试仓库中的自定义 agent / skill 资产
- `repo_mappings.json` schema/version 校验

测试不再依赖已删除的 `orchai.*` Python 运行时，也不再要求 `acpx` 会话。

## Run

从项目根目录执行：

```bash
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run --with pytest pytest -q
```

## Real OpenClaw E2E

真实 OpenClaw e2e 是 opt-in 的，不会默认执行。

前提：

- OpenClaw Gateway 已经在本机运行并且 `openclaw health --json` 正常
- 已存在一个专用 test agent
- 推荐再准备一个专用 judge agent

所需环境变量：

```bash
export ORCHAI_REAL_E2E=1
export ORCHAI_REAL_E2E_AGENT=<test-agent-id>
export ORCHAI_REAL_E2E_AGENT_WORKSPACE=<test-agent-workspace-abs-path>
export ORCHAI_REAL_E2E_JUDGE_AGENT=<judge-agent-id>   # 可选，默认回退到 test agent
export ORCHAI_REAL_E2E_LANGUAGE=en                    # 可选，默认 en
```

运行：

```bash
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run --with pytest pytest tests/real_e2e -m real_e2e -q
```

或使用辅助脚本：

```bash
bash scripts/run_real_e2e.sh
```

说明：

- 测试不会启动 OpenClaw 服务，只会先检查 `openclaw health --json`
- 测试通过 `openclaw agent --agent <id> --message ... --json` 调用真实 Gateway
- 测试会把 router skill 的 trace 规则注入到 test agent workspace 的临时副本中，测试后自动恢复
- 测试 repo 会复制到临时目录，并重新初始化 git，因此不会污染 `tests/repos/`

## Notes

- 测试会使用 fake PATH 模拟不同 CLI 安装状态，不需要真的调用 Claude Code、OpenCode、Cursor 或 Codex。
- 测试中的安装脚本执行使用临时 `HOME`，不会污染当前用户目录。
- `tests/repos/` 只作为 fixture 目录使用，不会被 pytest 递归收集。
