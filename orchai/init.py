"""Init command"""

import json
import os
import sys
from pathlib import Path
from typing import Optional

import yaml

PROMPTS_DIR = Path(__file__).parent.parent / "prompts"


def get_project_root() -> Path:
    """Get and validate project root directory.
    
    TODO: Fix no validation for environment variable path - 修复环境变量路径无验证的问题 (Medium #7)
    Validates ORCHAI_PROJECT_ROOT environment variable or falls back to CWD.
    
    Returns:
        Validated project root Path object.
        
    Raises:
        ValueError: If ORCHAI_PROJECT_ROOT is set but invalid.
    """
    # TODO: Fix no validation for environment variable path - 修复环境变量路径无验证的问题 (Medium #7)
    env_path = os.environ.get("ORCHAI_PROJECT_ROOT")
    
    if env_path:
        project_root = Path(env_path).expanduser().resolve()
        if project_root.exists():
            if not project_root.is_dir():
                raise ValueError(
                    f"ORCHAI_PROJECT_ROOT exists but is not a directory: {project_root}"
                )
            return project_root
        else:
            # Create if it doesn't exist but parent exists
            if project_root.parent.exists():
                print(f"Warning: Creating project directory at {project_root}")
                project_root.mkdir(parents=True, exist_ok=True)
                return project_root
            else:
                raise ValueError(
                    f"ORCHAI_PROJECT_ROOT points to non-existent path: {project_root}. "
                    "Please create the parent directory first."
                )
    
    # Fallback to current working directory
    return Path(os.getcwd())


def init_command(choice: Optional[str] = None) -> None:
    """Initialize OrchAI.
    
    Args:
        choice: Optional choice string ('1' or '2'). If not provided,
                prompts for interactive input.
    """
    print("=== OrchAI Initialization ===\n")
    print("Choose agent setup:")
    print("1. Create new 'orchai-router' agent")
    print("2. Use existing agent (claude/codex/opencode)")
    
    # TODO: Fix non-interactive input in CLI - 修复 CLI 中的非交互式输入 (High #5)
    # Support both interactive and non-interactive modes
    if choice is None:
        # Interactive mode: use input()
        if sys.stdin.isatty():
            choice = input("\nEnter choice (1 or 2): ").strip()
        else:
            # Non-interactive mode (piped input or CI/CD)
            print("\nWarning: Running in non-interactive mode. Use: orchai init 1")
            choice = "1"  # Default to option 1 in non-interactive mode
    
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
    project_root = get_project_root()
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
    project_root = get_project_root()
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
    project_root = get_project_root()
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
