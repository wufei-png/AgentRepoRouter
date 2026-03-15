#!/usr/bin/env python3
"""Demo using acpx"""

import sys
from pathlib import Path

# TODO: Fix fragile path manipulation - 修复脆弱的路径操作 (Medium #6)
# Use absolute path based on file location instead of relative "."
demo_dir = Path(__file__).parent
project_root = demo_dir.parent
# TODO: Fix module insertion at beginning of path - 修复模块插入路径开头的问题 (Medium #8)
# Note: This is acceptable for demos but for production should use importlib or proper package install
sys.path.insert(0, str(project_root))

from orchai.router import Router


def main():
    print("=== OrchAI Router Demo (with acpx) ===\n")
    
    # TODO: Fix unhandled exception in demo - 修复 demo 中的未处理异常 (Critical #3)
    # Add error handling for missing mappings file
    mappings_path = project_root / "skills" / "router" / "repo_mappings.json"
    
    try:
        router = Router(str(mappings_path))
    except FileNotFoundError:
        print(f"Error: Mappings file not found: {mappings_path}")
        print("Please run 'orchai init' first to create the mappings file.")
        sys.exit(1)
    except Exception as e:
        print(f"Error initializing router: {e}")
        sys.exit(1)

    test_cases = [
        "fix login bug in test-backend",
        "update deployment documentation",
        "add password reset feature to backend",
    ]

    for task in test_cases:
        print(f"Task: {task}")
        
        # TODO: Fix no error handling for missing mappings - 修复缺失映射的错误处理 (Medium #10)
        # Add defensive check for result structure
        try:
            result = router.route(task)
            if isinstance(result, dict) and result.get("found"):
                print(f"  ✓ Route to: {result['repo']}")
                print(f"    Agent: {result['agent']}")
                print(
                    f"    Command: npx acpx@latest --cwd tests/repos/{result['repo']} {result['agent']} exec '<task>'"
                )
            else:
                reason = result.get("reason", "Unknown reason") if isinstance(result, dict) else "Invalid result"
                print(f"  ✗ Ambiguous - {reason}")
        except Exception as e:
            print(f"  ✗ Error routing task: {e}")
        
        print()


if __name__ == "__main__":
    main()
