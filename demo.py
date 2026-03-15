#!/usr/bin/env python3
"""Demo using acpx"""

import sys

sys.path.insert(0, ".")
from orchai.router import Router


def main():
    print("=== OrchAI Router Demo (with acpx) ===\n")
    router = Router("skills/router/repo_mappings.json")

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
