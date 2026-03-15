"""CLI entry point"""

import argparse
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
    parser = argparse.ArgumentParser(prog="orchai")
    # TODO: Fix missing --help flag - 修复缺失的 --help 标志 (Medium #7)
    # Add help flag that users expect
    parser.add_argument(
        "-h", 
        "--help", 
        action="store_true", 
        help="Show this help message and exit"
    )
    parser.add_argument("command", help="Command to run (init)", nargs="?")
    parser.add_argument(
        "args", 
        nargs="*", 
        help="Arguments for the command (e.g., '1' or '2' for init)"
    )
    
    # Use parse_known_args to handle unknown arguments gracefully
    args, unknown = parser.parse_known_args()
    
    # Handle help flag
    if args.help:
        parser.print_help()
        return EXIT_SUCCESS
    
    # Handle missing command
    if not args.command:
        print("Usage: orchai <command>", file=sys.stderr)
        print("Commands: init", file=sys.stderr)
        return EXIT_INVALID_ARGS
    
    cmd = args.command

    if cmd == "init":
        try:
            # Pass optional choice argument (e.g., "1" or "2")
            choice = args.args[0] if args.args else None
            init_command(choice)
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
