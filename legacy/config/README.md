# OrchAI Config 目录说明

> 已归档至 `legacy/config/`，不参与当前运行时。

`legacy/config/` 目录不再参与当前运行时。

迁移后的实际运行时只依赖两类文件：

- `scripts/install.sh`
- `~/.openclaw/skills/router/SKILL.md`
- `~/.openclaw/skills/router/references/repo_mappings.json`

当前 `config/` 下的 YAML 和 prompt 文件仅作为历史参考或配置示例保留，不会被 `scripts/install.sh`、Router Skill 或当前测试套件加载。

## 当前推荐做法

如果你要修改运行时行为：

1. 编辑 `skills/router/SKILL.zh.md` 或 `skills/router/SKILL.en.md`
2. 编辑 `skills/router/references/repo_mappings.json` 作为示例模板
3. 重新运行 `bash scripts/install.sh`，将选中的语言版本部署为 `~/.openclaw/skills/router/SKILL.md`

## 目录状态

| 路径 | 状态 |
|------|------|
| `legacy/config/agents.yaml` | 历史示例，不参与运行时 |
| `legacy/config/router_config.yaml` | 历史示例，不参与运行时 |
| `legacy/config/mcp.yaml` | 历史示例，不参与运行时 |
| `legacy/config/openclaw.yaml` | 历史示例，不参与运行时 |
| `legacy/config/projects.yaml` | 历史示例，不参与运行时 |
| `legacy/config/agents/orchai-router.md` | 历史 prompt 草稿，不参与运行时 |
