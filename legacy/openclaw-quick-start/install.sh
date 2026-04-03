#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "  OpenClaw Quick Start Installer"
echo "=============================================="
echo ""

step "Checking prerequisites..."

command -v node &>/dev/null || err "Node.js not found. Install Node.js 18+ first."
command -v npm &>/dev/null || err "npm not found."
command -v git &>/dev/null || err "Git not found."

ok "Prerequisites OK (Node.js: $(node --version), npm: v$(npm --version), Git: $(git --version | cut -d' ' -f3))"

step "Installing OpenClaw..."

if command -v openclaw &>/dev/null; then
    ok "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'unknown')"
else
    npm install -g openclaw
    ok "OpenClaw installed"
fi

step "Installing Agent CLIs..."

npm install -g @anthropic-ai/claude-code 2>/dev/null && ok "Claude Code installed" || warn "Claude Code may already be installed"
npm install -g opencode-ai 2>/dev/null && ok "OpenCode installed" || warn "OpenCode may already be installed"
npm install -g @openai/codex 2>/dev/null && ok "Codex CLI installed" || warn "Codex CLI may already be installed"

step "Setting up project structure..."

mkdir -p "${SCRIPT_DIR}/skills/build_and_test"
mkdir -p "${SCRIPT_DIR}/skills/bug-fix"
mkdir -p "${SCRIPT_DIR}/skills/doc-writer"
mkdir -p "${SCRIPT_DIR}/skills/code-review"
mkdir -p "${SCRIPT_DIR}/projects"

cat > "${SCRIPT_DIR}/skills/build_and_test/SKILL.md" << 'SKILLEOF'
---
name: build_and_test
description: Build and test the project. Use for running tests, installing dependencies, and coverage reports.
---

# Build and Test Skill

## Commands

### build
```bash
# Python
pip install -r requirements.txt
# Node.js
npm install
```

### test
```bash
# Python
pytest tests/ -v
# Node.js
npm test
```

### coverage
```bash
# Python
pytest tests/ --cov=src --cov-report=term-missing
# Node.js
npm test -- --coverage
```
SKILLEOF

cat > "${SCRIPT_DIR}/skills/bug-fix/SKILL.md" << 'SKILLEOF'
---
name: bug-fix
description: Specialized in fixing bugs. Use when tasks involve debugging, error fixing, or bug resolution.
---

# Bug Fix Skill

## Workflow

1. **Understand the bug** - Read relevant files, run tests to reproduce
2. **Identify root cause** - Analyze code flow, look for logic errors
3. **Implement fix** - Make minimal changes, no new features
4. **Verify** - Run tests, ensure no regressions

## Guidelines

- Verify the bug exists before fixing
- Make minimal, targeted changes
- Don't refactor while fixing bugs
SKILLEOF

cat > "${SCRIPT_DIR}/skills/doc-writer/SKILL.md" << 'SKILLEOF'
---
name: doc-writer
description: Specialized in documentation. Use when tasks involve writing or updating docs.
---

# Documentation Writer Skill

## Responsibilities

1. Read and understand existing docs
2. Answer questions about documentation
3. Update and improve docs
4. Maintain consistency

## Guidelines

- Reference existing docs when answering
- Provide concrete examples
- Don't make assumptions
SKILLEOF

cat > "${SCRIPT_DIR}/skills/code-review/SKILL.md" << 'SKILLEOF'
---
name: code-review
description: Perform code reviews. Use when asked to review code, PRs, or suggest improvements.
---

# Code Review Skill

## Review Process

1. **Understand context** - Read files, understand purpose
2. **Review for correctness** - Logic errors, security, performance
3. **Review for style** - Conventions, naming, comments
4. **Provide feedback** - Be specific, suggest improvements
SKILLEOF

ok "Created skills"

cat > "${SCRIPT_DIR}/openclaw.json" << 'EOF'
{
  "$schema": "https://openclaw.ai/schema.json",
  "skills": {
    "load": {
      "extraDirs": ["./skills"],
      "watch": true
    }
  }
}
EOF

ok "Created openclaw.json template"

cat > "${SCRIPT_DIR}/scripts/router.sh" << 'ROUTEREOF'
#!/bin/bash
set -e

PROJECTS_DIR="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/projects"
MAPPINGS_FILE="$(dirname "${BASH_SOURCE[0]}")/repo_mappings.json"
AGENT_PRIORITY=(claude-code opencode codex)

usage() {
    cat << USAGE
Usage: router.sh [OPTIONS] <task> [project]

Route a task to the appropriate agent and project.

OPTIONS:
    -a, --agent AGENT   Force specific agent (claude-code|opencode|codex)
    -p, --project PROJ  Force specific project
    -l, --list          List available projects
    -h, --help          Show this help

EXAMPLES:
    router.sh "fix login bug"
    router.sh "add user auth" my-backend
    router.sh -a opencode "update docs"
    router.sh --list
USAGE
}

list_projects() {
    if [ ! -f "$MAPPINGS_FILE" ]; then
        echo "No projects configured. Edit: $MAPPINGS_FILE"
        return
    fi
    echo "Available projects:"
    jq -r '.repos[] | "  \(.name)\n    path: \(.path)\n    keywords: \(.keywords | join(", "))"' "$MAPPINGS_FILE" 2>/dev/null || cat "$MAPPINGS_FILE"
}

find_project() {
    local task_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if [ ! -f "$MAPPINGS_FILE" ]; then
        echo "default"
        return
    fi
    if command -v jq &>/dev/null; then
        local matched=$(jq -r --arg task "$task_lower" \
            '.repos[] | select(.keywords | map(. == $task or contains($task) or ($task | contains(.))) | any) | .name' \
            "$MAPPINGS_FILE" | head -1)
        [ -n "$matched" ] && [ "$matched" != "null" ] && echo "$matched" || echo "default"
    else
        echo "default"
    fi
}

find_agent() {
    local task_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$task_lower" in
        *fix*|*bug*|*error*|*issue*) echo "opencode" ;;
        *add*|*implement*|*create*|*new*) echo "claude-code" ;;
        *refactor*|*clean*|*improve*) echo "claude-code" ;;
        *doc*|*readme*|*guide*) echo "codex" ;;
        *review*|*check*|*audit*) echo "claude-code" ;;
        *) echo "${AGENT_PRIORITY[0]}" ;;
    esac
}

execute_task() {
    local project="$1"
    local agent="$2"
    local task="$3"
    local project_path="${PROJECTS_DIR}/${project}"
    
    [ ! -d "$project_path" ] && project_path="."
    
    if [ -d "$project_path/.git" ]; then
        echo "Executing in: $project_path"
        echo "Agent: $agent"
        echo "Task: $task"
        echo ""
        npx acpx@latest "$agent" --cwd "$project_path" "exec" "$task"
    else
        err "Project must be a git repository: $project_path"
    fi
}

main() {
    local force_agent=""
    local force_project=""
    local list_mode=false
    local task=""
    local project=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--agent) force_agent="$2"; shift 2 ;;
            -p|--project) force_project="$2"; shift 2 ;;
            -l|--list) list_mode=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) [ -z "$task" ] && task="$1" || project="$1"; shift ;;
        esac
    done
    
    [ "$list_mode" = true ] && list_projects && exit 0
    [ -z "$task" ] && usage && exit 1
    
    project="${force_project:-$(find_project "$task")}"
    agent="${force_agent:-$(find_agent "$task")}"
    
    execute_task "$project" "$agent" "$task"
}

main "$@"
ROUTEREOF

chmod +x "${SCRIPT_DIR}/scripts/router.sh"

cat > "${SCRIPT_DIR}/scripts/repo_mappings.json" << 'EOF'
{
  "repos": [
    {
      "name": "default",
      "path": "./projects/default",
      "keywords": ["default"],
      "description": "Default project"
    }
  ]
}
EOF

ok "Created router.sh and repo_mappings.json"

step "Creating sample project..."

if [ ! -d "${PROJECTS_DIR}/default" ]; then
    mkdir -p "${PROJECTS_DIR}/default"
    cd "${PROJECTS_DIR}/default"
    git init -q
    echo "# Default Project" > README.md
    git add README.md
    git commit -q -m "Initial commit"
    ok "Created sample project"
fi

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Configure your model provider:"
echo "   openclaw configure"
echo ""
echo "2. Add your projects to:"
echo "   ${SCRIPT_DIR}/scripts/repo_mappings.json"
echo ""
echo "3. Run tasks directly:"
echo "   cd your-project && npx acpx@latest opencode \"your task\""
echo ""
echo "   Or use the router:"
echo "   ${SCRIPT_DIR}/scripts/router.sh \"fix bug\""
echo ""
echo "4. Add project-specific skills:"
echo "   your-project/.claude/skills/your-skill/SKILL.md"
echo ""
