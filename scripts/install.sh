#!/usr/bin/env bash
set -e

# ClawRouter 安装脚本
# 用法: curl -fsSL https://.../install.sh | bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ROUTER_SKILL_DIR="$HOME/.openclaw/skills/router"
ROUTER_CONFIG_PATH="$ROUTER_SKILL_DIR/references/repo_mappings.json"
REPO_MAPPINGS_SCHEMA_VERSION=1
TTY_FD=9
TTY_AVAILABLE=0
if exec 9<>/dev/tty 2>/dev/null; then
    TTY_AVAILABLE=1
fi

# 默认值
SELECTED_CLIS=()
REPOS=()
SKILL_LANG=""
MENU_LABELS=()
MENU_VALUES=()
MENU_ENABLED=()
MENU_SELECTED=()
MENU_RESULT=""
MENU_RESULTS=()
MENU_CURSOR=0
MENU_LINES=0
MENU_MESSAGE=""

# 查找下一个可用备份目录
next_router_backup_dir() {
    local skills_dir
    local backup_index=0
    local backup_dir=""

    skills_dir="$(dirname "$ROUTER_SKILL_DIR")"
    while true; do
        backup_dir="$skills_dir/router_backup_$backup_index"
        if [ ! -e "$backup_dir" ]; then
            echo "$backup_dir"
            return 0
        fi
        backup_index=$((backup_index + 1))
    done
}

# 检测 CLI 是否可用
check_cli() {
    command -v "$1" &>/dev/null
}

can_use_interactive_menu() {
    [ "$TTY_AVAILABLE" -eq 1 ]
}

ui_printf() {
    if [ "$TTY_AVAILABLE" -eq 1 ]; then
        printf "%b" "$1" >&$TTY_FD
    else
        printf "%b" "$1"
    fi
}

read_user_line() {
    local prompt="$1"

    ui_printf "$prompt"
    if [ "$TTY_AVAILABLE" -eq 1 ]; then
        IFS= read -r REPLY <&$TTY_FD
    else
        IFS= read -r REPLY
    fi
}

read_menu_key() {
    local key=""
    local rest=""

    IFS= read -rsn1 key <&$TTY_FD || return 1
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn2 rest <&$TTY_FD || true
        key="$key$rest"
    fi

    case "$key" in
        $'\x1b[A') echo "up" ;;
        $'\x1b[B') echo "down" ;;
        " ") echo "space" ;;
        "") echo "enter" ;;
        *) echo "other" ;;
    esac
}

draw_menu() {
    local title="$1"
    local hint="$2"
    local index=0
    local marker=""
    local checkbox=""
    local line=""

    if [ "$MENU_LINES" -gt 0 ]; then
        ui_printf "\033[${MENU_LINES}A"
    fi
    ui_printf "\033[J"

    MENU_LINES=0
    ui_printf "${title}\n"
    MENU_LINES=$((MENU_LINES + 1))
    ui_printf "${hint}\n"
    MENU_LINES=$((MENU_LINES + 1))

    for index in "${!MENU_LABELS[@]}"; do
        if [ "$index" -eq "$MENU_CURSOR" ]; then
            marker=">"
        else
            marker=" "
        fi

        if [ "${MENU_SELECTED[$index]:-0}" -eq 1 ]; then
            checkbox="[✓]"
        else
            checkbox="[ ]"
        fi

        line="${marker} ${checkbox} ${MENU_LABELS[$index]}"
        if [ "${MENU_ENABLED[$index]:-1}" -ne 1 ]; then
            line="${line} ${RED}(not available)${NC}"
        fi

        ui_printf "${line}\n"
        MENU_LINES=$((MENU_LINES + 1))
    done

    if [ -n "$MENU_MESSAGE" ]; then
        ui_printf "${MENU_MESSAGE}\n"
    else
        ui_printf "\n"
    fi
    MENU_LINES=$((MENU_LINES + 1))
}

run_menu() {
    local title="$1"
    local mode="$2"
    local empty_message="$3"
    local key=""
    local selected_count=0
    local index=0

    MENU_RESULT=""
    MENU_RESULTS=()
    MENU_CURSOR=0
    MENU_LINES=0
    MENU_MESSAGE=""
    MENU_SELECTED=()

    for index in "${!MENU_LABELS[@]}"; do
        MENU_SELECTED[$index]=0
    done

    ui_printf "\033[?25l"
    while true; do
        draw_menu "$title" "Use ↑/↓ to move, Space to select, Enter to confirm."
        key=$(read_menu_key) || key="enter"

        case "$key" in
            up)
                if [ "$MENU_CURSOR" -gt 0 ]; then
                    MENU_CURSOR=$((MENU_CURSOR - 1))
                else
                    MENU_CURSOR=$((${#MENU_LABELS[@]} - 1))
                fi
                MENU_MESSAGE=""
                ;;
            down)
                if [ "$MENU_CURSOR" -lt $((${#MENU_LABELS[@]} - 1)) ]; then
                    MENU_CURSOR=$((MENU_CURSOR + 1))
                else
                    MENU_CURSOR=0
                fi
                MENU_MESSAGE=""
                ;;
            space)
                if [ "${MENU_ENABLED[$MENU_CURSOR]:-1}" -ne 1 ]; then
                    MENU_MESSAGE="${YELLOW}This option is not available.${NC}"
                    continue
                fi

                if [ "$mode" = "single" ]; then
                    for index in "${!MENU_SELECTED[@]}"; do
                        MENU_SELECTED[$index]=0
                    done
                    MENU_SELECTED[$MENU_CURSOR]=1
                else
                    if [ "${MENU_SELECTED[$MENU_CURSOR]:-0}" -eq 1 ]; then
                        MENU_SELECTED[$MENU_CURSOR]=0
                    else
                        MENU_SELECTED[$MENU_CURSOR]=1
                    fi
                fi
                MENU_MESSAGE=""
                ;;
            enter)
                selected_count=0
                for index in "${!MENU_SELECTED[@]}"; do
                    if [ "${MENU_SELECTED[$index]:-0}" -eq 1 ]; then
                        selected_count=$((selected_count + 1))
                    fi
                done

                if [ "$selected_count" -eq 0 ]; then
                    MENU_MESSAGE="${RED}${empty_message}${NC}"
                    continue
                fi

                for index in "${!MENU_SELECTED[@]}"; do
                    if [ "${MENU_SELECTED[$index]:-0}" -eq 1 ]; then
                        MENU_RESULTS+=("${MENU_VALUES[$index]}")
                    fi
                done
                MENU_RESULT="${MENU_RESULTS[0]}"
                break
                ;;
        esac
    done

    ui_printf "\033[?25h"
    ui_printf "\n"
}

get_cli_command() {
    case "$1" in
        claude-code) echo "claude" ;;
        opencode) echo "opencode" ;;
        cursor) echo "agent" ;;
        codex) echo "codex" ;;
        *) return 1 ;;
    esac
}

is_cli_installed() {
    local cli_command
    cli_command=$(get_cli_command "$1") || return 1
    check_cli "$cli_command"
}

array_contains() {
    local needle="$1"
    shift

    local item
    for item in "$@"; do
        if [ "$item" = "$needle" ]; then
            return 0
        fi
    done

    return 1
}

normalize_path() {
    (
        cd "$1" 2>/dev/null
        pwd
    )
}

repo_path_exists() {
    local repo_path="$1"
    local existing_path

    for existing_path in "${REPOS[@]}"; do
        if [ "$existing_path" = "$repo_path" ]; then
            return 0
        fi
    done

    return 1
}

count_installed_clis() {
    local count=0
    local cli_name

    for cli_name in "claude-code" "opencode" "cursor" "codex"; do
        if is_cli_installed "$cli_name"; then
            count=$((count + 1))
        fi
    done

    echo "$count"
}

validate_repo_mappings() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$script_dir/validate_repo_mappings.sh" "$1" >/dev/null
}

# 检测 OpenClaw 是否安装
check_openclaw() {
    if ! check_cli "openclaw"; then
        echo -e "${RED}Error: OpenClaw is not installed.${NC}"
        echo "Please install OpenClaw first: npm install -g openclaw"
        exit 1
    fi
    echo -e "${GREEN}✓ OpenClaw is installed${NC}"
}

# 检查环境
check_environment() {
    echo "Checking environment..."

    # Node.js
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node -v | sed 's/v//')
        NODE_MAJOR=$(printf '%s' "$NODE_VERSION" | cut -d. -f1)
        if [ "$NODE_MAJOR" -lt 18 ]; then
            echo -e "${RED}✗ Node.js 18+ is required (found $NODE_VERSION)${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Node.js $NODE_VERSION${NC}"
    else
        echo -e "${RED}✗ Node.js not found${NC}"
        exit 1
    fi

    # Git
    if check_cli "git"; then
        echo -e "${GREEN}✓ Git${NC}"
    else
        echo -e "${RED}✗ Git not found${NC}"
        exit 1
    fi

    # OpenClaw
    check_openclaw

    echo ""
}

# 选择语言
select_language() {
    if can_use_interactive_menu; then
        MENU_LABELS=("中文" "English")
        MENU_VALUES=("zh" "en")
        MENU_ENABLED=(1 1)
        run_menu "Select language / 选择语言" "single" "Please select one language."
        SKILL_LANG="$MENU_RESULT"
        if [ "$SKILL_LANG" = "zh" ]; then
            echo -e "${GREEN}Selected: 中文${NC}"
        else
            echo -e "${GREEN}Selected: English${NC}"
        fi
        echo ""
        return
    fi

    echo "Select language / 选择语言:"
    echo "  [1] 中文"
    echo "  [2] English"
    echo ""

    while true; do
        read_user_line "Enter choice [1-2]: "
        choice="$REPLY"
        case $choice in
            1)
                SKILL_LANG="zh"
                echo -e "${GREEN}Selected: 中文${NC}"
                break
                ;;
            2)
                SKILL_LANG="en"
                echo -e "${GREEN}Selected: English${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
    echo ""
}

# 选择 CLI
select_clis() {
    local claude_label="claude-code"
    local opencode_label="opencode"
    local cursor_label="cursor"
    local codex_label="codex"

    if [ "$(count_installed_clis)" -eq 0 ]; then
        echo -e "${RED}No supported CLI tools were found. Install at least one of claude-code, opencode, cursor, or codex.${NC}"
        exit 1
    fi

    if can_use_interactive_menu; then
        if is_cli_installed "claude-code"; then
            claude_label="${claude_label} (${GREEN}installed${NC})"
        else
            claude_label="${claude_label} (${RED}not found${NC})"
        fi
        if is_cli_installed "opencode"; then
            opencode_label="${opencode_label} (${GREEN}installed${NC})"
        else
            opencode_label="${opencode_label} (${RED}not found${NC})"
        fi
        if is_cli_installed "cursor"; then
            cursor_label="${cursor_label} (${GREEN}installed${NC})"
        else
            cursor_label="${cursor_label} (${RED}not found${NC})"
        fi
        if is_cli_installed "codex"; then
            codex_label="${codex_label} (${GREEN}installed${NC})"
        else
            codex_label="${codex_label} (${RED}not found${NC})"
        fi

        MENU_LABELS=("$claude_label" "$opencode_label" "$cursor_label" "$codex_label")
        MENU_VALUES=("claude-code" "opencode" "cursor" "codex")
        MENU_ENABLED=(0 0 0 0)
        is_cli_installed "claude-code" && MENU_ENABLED[0]=1
        is_cli_installed "opencode" && MENU_ENABLED[1]=1
        is_cli_installed "cursor" && MENU_ENABLED[2]=1
        is_cli_installed "codex" && MENU_ENABLED[3]=1
        run_menu "Select CLI tools to use" "multi" "Please select at least one installed CLI."
        SELECTED_CLIS=("${MENU_RESULTS[@]}")
        echo -e "${GREEN}Selected CLIs: ${SELECTED_CLIS[*]}${NC}"
        echo ""
        return
    fi

    echo "Select CLI tools to use (select at least one):"
    echo "  [1] claude-code  ($(check_cli "claude" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [2] opencode     ($(check_cli "opencode" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [3] cursor       ($(check_cli "agent" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [4] codex        ($(check_cli "codex" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo ""

    local choices=""
    while true; do
        read_user_line "Enter numbers (e.g., 1,2,3): "
        choices="$REPLY"
        if [ -z "$choices" ]; then
            echo -e "${RED}Please select at least one CLI.${NC}"
            continue
        fi

        SELECTED_CLIS=()
        local has_error=0
        local selected_cli=""

        for choice in $(echo "$choices" | tr ',' ' '); do
            selected_cli=""
            case $choice in
                1) selected_cli="claude-code" ;;
                2) selected_cli="opencode" ;;
                3) selected_cli="cursor" ;;
                4) selected_cli="codex" ;;
                *)
                    echo -e "${YELLOW}Warning: Ignoring invalid choice: $choice${NC}"
                    has_error=1
                    continue
                    ;;
            esac

            if ! is_cli_installed "$selected_cli"; then
                echo -e "${YELLOW}Warning: Selected CLI is not installed: $selected_cli${NC}"
                has_error=1
                continue
            fi

            if ! array_contains "$selected_cli" "${SELECTED_CLIS[@]}"; then
                SELECTED_CLIS+=("$selected_cli")
            fi
        done

        if [ ${#SELECTED_CLIS[@]} -eq 0 ]; then
            echo -e "${RED}Please select at least one installed CLI.${NC}"
            continue
        fi

        if [ "$has_error" -eq 1 ]; then
            echo -e "${YELLOW}Please re-enter your CLI selection using installed options only.${NC}"
            continue
        fi

        break
    done

    echo -e "${GREEN}Selected CLIs: ${SELECTED_CLIS[*]}${NC}"
    echo ""
}

# 自动扫描项目
auto_scan() {
    echo "Auto scan for projects..."
    echo "Enter root directory to scan (will search for .git directories):"
    read_user_line "Path: "
    scan_root="$REPLY"

    # 验证路径
    if [ ! -d "$scan_root" ]; then
        echo -e "${RED}Directory does not exist: $scan_root${NC}"
        return 1
    fi

    scan_root=$(normalize_path "$scan_root")

    echo "Scanning for git repositories..."
    REPOS=()

    # 使用 find 查找 .git 目录
    while IFS= read -r git_dir; do
        repo_path=$(normalize_path "$(dirname "$git_dir")")
        repo_name=$(basename "$repo_path")

        # 跳过重复项目路径
        if repo_path_exists "$repo_path"; then
            echo -e "${YELLOW}Warning: Duplicate project path filtered: $repo_path${NC}"
            continue
        fi

        REPOS+=("$repo_path")
        echo -e "  ${GREEN}✓${NC} Found: $repo_name ($repo_path)"
    done < <(find "$scan_root" -maxdepth 5 -type d -name ".git" 2>/dev/null)

    if [ ${#REPOS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No git repositories found.${NC}"
    else
        echo -e "${GREEN}Found ${#REPOS[@]} repositories${NC}"
    fi
    echo ""
}

# 手动输入项目
manual_input() {
    echo "Manual project input..."
    echo "Enter project paths (one per line, empty line to finish):"
    echo ""

    REPOS=()
    while true; do
        read_user_line "Path: "
        repo_path="$REPLY"
        if [ -z "$repo_path" ]; then
            break
        fi

        if [[ "$repo_path" != /* ]]; then
            echo -e "${YELLOW}Warning: Please enter an absolute path: $repo_path${NC}"
            continue
        fi

        # 验证路径
        if [ ! -d "$repo_path" ]; then
            echo -e "${YELLOW}Warning: Directory does not exist: $repo_path${NC}"
            continue
        fi

        repo_path=$(normalize_path "$repo_path")
        repo_name=$(basename "$repo_path")

        # 检查重复项目路径
        if repo_path_exists "$repo_path"; then
            echo -e "${YELLOW}Warning: Duplicate project path filtered: $repo_path${NC}"
            continue
        fi

        REPOS+=("$repo_path")
        echo -e "  ${GREEN}✓${NC} Added: $repo_path"
    done

    echo ""
}

# 项目发现
discover_projects() {
    if can_use_interactive_menu; then
        MENU_LABELS=("Auto scan (search for .git directories)" "Manual input")
        MENU_VALUES=("auto" "manual")
        MENU_ENABLED=(1 1)
        run_menu "Project discovery" "single" "Please select one project discovery mode."
        if [ "$MENU_RESULT" = "auto" ]; then
            while ! auto_scan; do
                :
            done
        else
            manual_input
        fi
        return
    fi

    echo "Project discovery:"
    echo "  [1] Auto scan (search for .git directories)"
    echo "  [2] Manual input"
    echo ""

    while true; do
        read_user_line "Enter choice [1-2]: "
        choice="$REPLY"
        case $choice in
            1)
                if auto_scan; then
                    break
                fi
                ;;
            2)
                manual_input
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
}

# 处理已有 router 目录
prepare_router_directory() {
    local backup_dir=""

    if [ ! -e "$ROUTER_SKILL_DIR" ]; then
        return
    fi

    echo "Existing router skill directory detected: $ROUTER_SKILL_DIR"

    if can_use_interactive_menu; then
        MENU_LABELS=("Delete and overwrite" "Backup existing router")
        MENU_VALUES=("delete" "backup")
        MENU_ENABLED=(1 1)
        run_menu "Router skill already exists" "single" "Please choose how to handle the existing router directory."
        case "$MENU_RESULT" in
            delete)
                rm -rf "$ROUTER_SKILL_DIR"
                echo -e "${GREEN}✓ Deleted existing router directory${NC}"
                ;;
            backup)
                backup_dir="$(next_router_backup_dir)"
                mv "$ROUTER_SKILL_DIR" "$backup_dir"
                echo -e "${GREEN}✓ Backed up existing router directory to $backup_dir${NC}"
                ;;
        esac
        echo ""
        return
    fi

    echo "Router skill already exists:"
    echo "  [1] Delete and overwrite"
    echo "  [2] Backup existing router"
    echo ""

    while true; do
        read_user_line "Enter choice [1-2]: "
        choice="$REPLY"
        case $choice in
            1)
                rm -rf "$ROUTER_SKILL_DIR"
                echo -e "${GREEN}✓ Deleted existing router directory${NC}"
                break
                ;;
            2)
                backup_dir="$(next_router_backup_dir)"
                mv "$ROUTER_SKILL_DIR" "$backup_dir"
                echo -e "${GREEN}✓ Backed up existing router directory to $backup_dir${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                ;;
        esac
    done
    echo ""
}

# 生成 repo_mappings.json
generate_config() {
    echo "Generating $ROUTER_CONFIG_PATH..."

    # 创建目录
    mkdir -p "$(dirname "$ROUTER_CONFIG_PATH")"

    local repo_list_file=""
    repo_list_file="$(mktemp)"
    printf '%s\n' "${REPOS[@]}" > "$repo_list_file"

    node - "$ROUTER_CONFIG_PATH" "$REPO_MAPPINGS_SCHEMA_VERSION" "$repo_list_file" "${SELECTED_CLIS[@]}" <<'EOF'
const fs = require("node:fs");
const path = require("node:path");

const [, , configPath, schemaVersionRaw, repoListPath, ...selectedClis] = process.argv;

const PROJECT_ASSET_LOCATIONS = {
  skills: {
    "claude-code": { root: path.join(".claude", "skills"), kind: "directory-skill" },
    "opencode": { root: path.join(".opencode", "skills"), kind: "directory-skill" },
    codex: { root: path.join(".agents", "skills"), kind: "directory-skill" },
  },
  agents: {
    "claude-code": { root: path.join(".claude", "agents"), kind: "markdown-file" },
    "opencode": { root: path.join(".opencode", "agents"), kind: "markdown-file" },
    cursor: { root: path.join(".cursor", "agents"), kind: "markdown-file" },
    codex: { root: path.join(".codex", "agents"), kind: "toml-file" },
  },
};

function splitFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!match) {
    return { frontmatter: "", body: content };
  }

  return {
    frontmatter: match[1],
    body: content.slice(match[0].length),
  };
}

function parseFrontmatterValue(frontmatter, key) {
  const match = frontmatter.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  if (!match) {
    return "";
  }

  let value = match[1].trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }

  return value.trim();
}

function inferDescription(body, fallbackName, assetLabel) {
  const lines = body.split(/\r?\n/);
  let inCodeBlock = false;

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (line.startsWith("```")) {
      inCodeBlock = !inCodeBlock;
      continue;
    }
    if (inCodeBlock || line === "") {
      continue;
    }
    if (
      line.startsWith("#") ||
      line.startsWith(">") ||
      /^[-*]\s/.test(line)
    ) {
      continue;
    }
    return line;
  }

  return `Project ${assetLabel} ${fallbackName}.`;
}

function extractMarkdownMetadata(filePath, fallbackName, assetLabel) {
  const content = fs.readFileSync(filePath, "utf8");
  const { frontmatter, body } = splitFrontmatter(content);
  const name = parseFrontmatterValue(frontmatter, "name") || fallbackName;
  const description =
    parseFrontmatterValue(frontmatter, "description") ||
    inferDescription(body, name, assetLabel);

  return { name, description };
}

function parseTomlValue(content, key) {
  const match = content.match(new RegExp(`^${key}\\s*=\\s*["']([^"']+)["']$`, "m"));
  if (!match) {
    return "";
  }

  return match[1].trim();
}

function extractTomlMetadata(filePath, fallbackName, assetLabel) {
  const content = fs.readFileSync(filePath, "utf8");
  const name = parseTomlValue(content, "name") || fallbackName;
  const description =
    parseTomlValue(content, "description") || `Project ${assetLabel} ${name}.`;

  return { name, description };
}

function detectProjectAssets(repoPath, assetType) {
  const detectedAssets = {};
  const assetLocations = PROJECT_ASSET_LOCATIONS[assetType];
  const assetLabel = assetType === "skills" ? "skill" : "agent";

  for (const [cliName, config] of Object.entries(assetLocations)) {
    const assetRoot = path.join(repoPath, config.root);
    if (!fs.existsSync(assetRoot) || !fs.statSync(assetRoot).isDirectory()) {
      continue;
    }

    let assets = [];
    if (config.kind === "directory-skill") {
      assets = fs
        .readdirSync(assetRoot, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name)
        .sort((left, right) => left.localeCompare(right))
        .flatMap((entryName) => {
          const assetFilePath = path.join(assetRoot, entryName, "SKILL.md");
          if (!fs.existsSync(assetFilePath) || !fs.statSync(assetFilePath).isFile()) {
            return [];
          }
          return [extractMarkdownMetadata(assetFilePath, entryName, assetLabel)];
        });
    } else if (config.kind === "markdown-file") {
      assets = fs
        .readdirSync(assetRoot, { withFileTypes: true })
        .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
        .map((entry) => entry.name)
        .sort((left, right) => left.localeCompare(right))
        .map((entryName) => {
          const baseName = path.basename(entryName, ".md");
          return extractMarkdownMetadata(path.join(assetRoot, entryName), baseName, assetLabel);
        });
    } else if (config.kind === "toml-file") {
      assets = fs
        .readdirSync(assetRoot, { withFileTypes: true })
        .filter((entry) => entry.isFile() && entry.name.endsWith(".toml"))
        .map((entry) => entry.name)
        .sort((left, right) => left.localeCompare(right))
        .map((entryName) => {
          const baseName = path.basename(entryName, ".toml");
          return extractTomlMetadata(path.join(assetRoot, entryName), baseName, assetLabel);
        });
    }

    if (assets.length > 0) {
      detectedAssets[cliName] = assets;
    }
  }

  return detectedAssets;
}

const repoPaths = fs
  .readFileSync(repoListPath, "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);

const payload = {
  schemaVersion: Number(schemaVersionRaw),
  agents: selectedClis,
  repos: repoPaths.map((repoPath) => ({
    name: path.basename(repoPath),
    path: repoPath,
    aliases: [],
    skills: detectProjectAssets(repoPath, "skills"),
    agents: detectProjectAssets(repoPath, "agents"),
  })),
};

fs.writeFileSync(configPath, `${JSON.stringify(payload, null, 2)}\n`);
EOF

    rm -f "$repo_list_file"

    validate_repo_mappings "$ROUTER_CONFIG_PATH"

    echo -e "${GREEN}✓ Created $ROUTER_CONFIG_PATH${NC}"
    echo ""
}

# 部署 Router Skill
deploy_skill() {
    echo "Deploying Router Skill..."

    # Skill 源文件位置（相对于脚本位置）
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local skill_zh="$script_dir/../skills/router/SKILL.zh.md"
    local skill_en="$script_dir/../skills/router/SKILL.en.md"
    local references_src_dir="$script_dir/../skills/router/references"
    local skill_dest_dir="$ROUTER_SKILL_DIR"
    local skill_dest="$skill_dest_dir/SKILL.md"
    local references_dest_dir="$skill_dest_dir/references"
    local reference_path=""
    local reference_name=""

    # 验证源文件存在
    if [ ! -f "$skill_zh" ] || [ ! -f "$skill_en" ]; then
        echo -e "${RED}Error: Skill files not found in $script_dir/../skills/router/${NC}"
        echo "Please ensure SKILL.zh.md and SKILL.en.md exist."
        exit 1
    fi

    # 创建目标目录
    mkdir -p "$skill_dest_dir"
    mkdir -p "$references_dest_dir"

    # 根据语言选择部署
    if [ "$SKILL_LANG" = "zh" ]; then
        cp "$skill_zh" "$skill_dest"
        rm -f "$skill_dest_dir/SKILL.en.md" "$skill_dest_dir/SKILL.zh.md" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed Chinese version of Router Skill${NC}"
    else
        cp "$skill_en" "$skill_dest"
        rm -f "$skill_dest_dir/SKILL.zh.md" "$skill_dest_dir/SKILL.en.md" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed English version of Router Skill${NC}"
    fi

    # 同步 references 中的文档，不覆盖运行时生成的 repo_mappings.json
    if [ -d "$references_src_dir" ]; then
        find "$references_src_dir" -maxdepth 1 -type f ! -name "repo_mappings.json" | while IFS= read -r reference_path; do
            reference_name="$(basename "$reference_path")"
            case "$reference_name" in
                *.zh.md)
                    if [ "$SKILL_LANG" = "zh" ]; then
                        cp "$reference_path" "$references_dest_dir/"
                    else
                        rm -f "$references_dest_dir/$reference_name"
                    fi
                    ;;
                *.en.md)
                    if [ "$SKILL_LANG" = "en" ]; then
                        cp "$reference_path" "$references_dest_dir/"
                    else
                        rm -f "$references_dest_dir/$reference_name"
                    fi
                    ;;
                *)
                    cp "$reference_path" "$references_dest_dir/"
                    ;;
            esac
        done
    fi

    echo ""
}

# 主流程
main() {
    echo "=========================================="
    echo "  ClawRouter Installation Script"
    echo "=========================================="
    echo ""

    check_environment
    select_language
    select_clis
    discover_projects
    prepare_router_directory
    generate_config
    deploy_skill

    echo "=========================================="
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Run 'openclaw' to start"
    echo "  2. The router skill will help route tasks"
    echo "  3. Edit $ROUTER_CONFIG_PATH to add repo aliases or review detected skills and agents"
    echo ""
}

main "$@"
