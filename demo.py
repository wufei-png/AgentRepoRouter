#!/usr/bin/env python3
"""Demo using acpx"""

import sys
from pathlib import Path

# TODO: Fix fragile path manipulation - 修复脆弱的路径操作 (Medium #6)
# Use absolute path based on file location instead of relative "."
demo_dir = Path(__file__).parent
project_root = demo_dir.parent
sys.path.insert(0, str(project_root))

from orchai.router import Router


def main():
    print("=== OrchAI Router Demo (with acpx) ===\n")
    router = Router(str(project_root / "skills" / "router" / "repo_mappings.json"))

    test_cases = [
        "fix login bug in test-backend",
        "update deployment documentation",
        "add password reset feature to backend",
    ]

    for task in test_cases:
        print(f"Task: {task}")
        result = router.route(task)
        if result["found"]:
            print(f"  ✓ Route to: {result['repo']}")
            print(f"    Agent: {result['agent']}")
            print(
                f"    Command: npx acpx@latest --cwd tests/repos/{result['repo']} {result['agent']} exec '<task>'"
            )
        else:
            print("  ✗ Ambiguous")
        print()


if __name__ == "__main__":
    main()
