"""CLI entry point"""

import sys

from .init import init_command

# TODO: Fix no proper exit codes - 修复没有正确的退出码 (Low #16)
# Define consistent exit codes
EXIT_SUCCESS = 0
EXIT_INVALID_ARGS = 1
EXIT_INIT_FAILED = 2
EXIT_UNKNOWN_COMMAND = 3


def main() -> int:
    """Main CLI entry point with proper exit codes"""
    if len(sys.argv) < 2:
        print("Usage: orchai <command>", file=sys.stderr)
        print("Commands: init", file=sys.stderr)
        return EXIT_INVALID_ARGS

    cmd = sys.argv[1]

    if cmd == "init":
        try:
            init_command()
            return EXIT_SUCCESS
        except Exception as e:
            print(f"Error during initialization: {e}", file=sys.stderr)
            return EXIT_INIT_FAILED
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        print("Available commands: init", file=sys.stderr)
        return EXIT_UNKNOWN_COMMAND


if __name__ == "__main__":
    sys.exit(main())
