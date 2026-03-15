"""Init command"""

import json
import os
from pathlib import Path

import yaml

PROMPTS_DIR = Path(__file__).parent.parent / "prompts"


def init_command() -> None:
    print("=== OrchAI Initialization ===\n")
    print("Choose agent setup:")
    print("1. Create new 'orchai-router' agent")
    print("2. Use existing agent (claude/codex/opencode)")
    choice = input("\nEnter choice (1 or 2): ").strip()

    if choice == "1":
        create_new_agent()
    elif choice == "2":
        print("\nUsing existing agent. Router Skill will be added to your project.")
    else:
        print("Invalid choice")
        return

    create_project_config()
    create_router_skill()
    print("\n✓ Initialization complete!")


def create_new_agent() -> None:
    # TODO: Fix path creation relative to CWD - 修复路径创建相对于当前工作目录的问题 (High #8)
    # Use project root directory, not current working directory
    openclaw_dir = Path.home() / ".openclaw"
    agents_dir = openclaw_dir / "agents"
    agents_dir.mkdir(parents=True, exist_ok=True)

    agent_config = {
        "name": "orchai-router",
        "description": "Intelligent routing agent",
        "prompt": "You are OrchAI Router. Use Router Skill to route tasks to appropriate repos and agents.",
        "skills": ["router"],
    }

    with open(agents_dir / "orchai-router.yaml", "w", encoding="utf-8") as f:
        yaml.dump(agent_config, f)
    print(f"✓ Created agent: {agents_dir}/orchai-router.yaml")

    # Use project root from environment or current directory
    project_root = Path(os.environ.get("ORCHAI_PROJECT_ROOT", os.getcwd()))
    (project_root / "config" / "agents").mkdir(parents=True, exist_ok=True)
    prompt_path = PROMPTS_DIR / "orchai-router.md"
    target_prompt_path = project_root / "config" / "agents" / "orchai-router.md"

    if prompt_path.exists():
        with open(target_prompt_path, "w", encoding="utf-8") as f:
            f.write(prompt_path.read_text(encoding="utf-8"))
        print(f"✓ Created agent definition: {target_prompt_path}")
    else:
        # Create default prompt if template doesn't exist
        with open(target_prompt_path, "w", encoding="utf-8") as f:
            f.write("# OrchAI Router Agent\n\nYou are an intelligent routing agent.")
        print(f"✓ Created agent definition: {target_prompt_path}")


def create_project_config() -> None:
    # TODO: Fix path creation relative to CWD - 修复路径创建相对于当前工作目录的问题 (High #8)
    # Use project root from environment or current directory
    project_root = Path(os.environ.get("ORCHAI_PROJECT_ROOT", os.getcwd()))
    config_dir = project_root / "config"
    config_dir.mkdir(parents=True, exist_ok=True)

    with open(config_dir / "projects.yaml", "w", encoding="utf-8") as f:
        yaml.dump({"repos": []}, f)

    with open(config_dir / "router_config.yaml", "w", encoding="utf-8") as f:
        yaml.dump({"fallback": {"enabled": True, "max_retries": 3}}, f)

    with open(config_dir / "openclaw.yaml", "w", encoding="utf-8") as f:
        yaml.dump(
            {
                "server": {"host": "0.0.0.0", "port": 3000},
                "workspace": {"default": "./repos"},
                "agents_dir": "./config/agents",
            },
            f,
        )

    with open(config_dir / "agents.yaml", "w", encoding="utf-8") as f:
        yaml.dump(
            {
                "agents": [
                    {"name": "orchai-router", "enabled": True},
                    {"name": "claude-code", "enabled": True},
                    {"name": "opencode", "enabled": True},
                    {"name": "codex", "enabled": True},
                ]
            },
            f,
        )

    with open(config_dir / "mcp.yaml", "w", encoding="utf-8") as f:
        yaml.dump({"servers": []}, f)

    print("✓ Created config files")


def create_router_skill() -> None:
    # TODO: Fix path creation relative to CWD - 修复路径创建相对于当前工作目录的问题 (High #8)
    # Use project root from environment or current directory
    project_root = Path(os.environ.get("ORCHAI_PROJECT_ROOT", os.getcwd()))
    skill_dir = project_root / "skills" / "router"
    skill_dir.mkdir(parents=True, exist_ok=True)

    prompt_path = PROMPTS_DIR / "router-skill.md"
    target_skill_md = skill_dir / "skill.md"

    if prompt_path.exists():
        with open(target_skill_md, "w", encoding="utf-8") as f:
            f.write(prompt_path.read_text(encoding="utf-8"))
    else:
        # Create default skill.md if template doesn't exist
        with open(target_skill_md, "w", encoding="utf-8") as f:
            f.write("# Router Skill\n\nIntelligent task routing for OrchAI.")

    with open(skill_dir / "repo_mappings.json", "w", encoding="utf-8") as f:
        json.dump({"repos": []}, f, indent=2)

    print("✓ Created Router Skill")
