"""Router Skill implementation"""

from typing import Any


# TODO: Fix import from non-existent module - 修复从不存在的模块导入 (High #10)
# Use relative import or try-except to handle standalone usage
def route_task(task: str) -> dict[str, Any]:
    """Route task to appropriate repo and agent"""
    try:
        # Try relative import first (when used as package)
        from orchai.router import Router
    except ImportError:
        # Fallback for standalone usage or when orchai not in path
        import sys
        from pathlib import Path

        # Add parent directory to path for standalone usage
        skills_dir = Path(__file__).parent
        orchai_path = skills_dir.parent.parent / "orchai"
        if str(orchai_path) not in sys.path:
            sys.path.insert(0, str(orchai_path.parent))

        try:
            from orchai.router import Router
        except ImportError:
            # Last resort: direct import from project root
            project_root = Path(__file__).parent.parent.parent
            if str(project_root) not in sys.path:
                sys.path.insert(0, str(project_root))
            from orchai.router import Router

    # TODO: Fix no error handling for init failure - 修复初始化失败无错误处理的问题 (High #6)
    # Add error handling for router initialization failures
    try:
        router = Router()
    except Exception as e:
        return {
            "found": False,
            "candidates": [],
            "reason": f"Router initialization failed: {str(e)}",
        }

    try:
        return router.route(task)
    except Exception as e:
        return {"found": False, "candidates": [], "reason": f"Routing failed: {str(e)}"}
