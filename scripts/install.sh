#!/usr/bin/env bash
set -euo pipefail

# AgentRepoRouter installation script.
# Usage: curl -fsSL https://.../install.sh | bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SKILL_NAME="AgentRepoRouter"
SKILL_SLUG="agent-repo-router"
CANONICAL_SKILL_DIR="$HOME/.agents/skills/$SKILL_SLUG"
REPO_MAPPINGS_SCHEMA_VERSION=2
AGENT_REPO_ROUTER_REPO="${AGENT_REPO_ROUTER_REPO:-wufei-png/AgentRepoRouter}"
AGENT_REPO_ROUTER_BRANCH="${AGENT_REPO_ROUTER_BRANCH:-main}"
REMOTE_RAW_BASE_URL="https://raw.githubusercontent.com/${AGENT_REPO_ROUTER_REPO}/${AGENT_REPO_ROUTER_BRANCH}"
# Use local files from a clone when available; pipe installs fall back to GitHub raw.
AGENT_REPO_ROUTER_USE_LOCAL_CACHE="${AGENT_REPO_ROUTER_USE_LOCAL_CACHE:-auto}"
SCAN_MAX_DEPTH="${AGENT_REPO_ROUTER_SCAN_MAX_DEPTH:-5}"
SCAN_DEPTH_CONFIGURED=0
if [ -n "${AGENT_REPO_ROUTER_SCAN_MAX_DEPTH:-}" ]; then
    SCAN_DEPTH_CONFIGURED=1
fi

YES=0
HOSTS_RAW=""
HOSTS_ARG_SET=0
EXECUTION_CLIS_RAW=""
EXECUTION_CLIS_ARG_SET=0
EXISTING="backup"
EXISTING_ARG_SET=0
AUTO_SCAN=0
SCAN_ROOT=""
REPO_ARGS=()

TTY_FD=9
TTY_AVAILABLE=0
if { exec 9<>/dev/tty; } 2>/dev/null; then
    TTY_AVAILABLE=1
fi

SELECTED_CLIS=()
REPOS=()
SKILL_LANG=""
INSTALL_MODE=""
INSTALL_STRATEGY=""
INSTALL_TARGET_DIR=""
CONFIG_PATH=""
SELECTED_INSTALL_HOSTS=()
CONFIG_INSTALL_HOSTS=()

MENU_LABELS=()
MENU_VALUES=()
MENU_ENABLED=()
MENU_SELECTED=()
MENU_ROW_DETECTED=()
MENU_RESULT=""
MENU_RESULTS=()
MENU_CURSOR=0
MENU_LINES=0
MENU_MESSAGE=""
MENU_ALL_DETECTED_MODE=0
SELECTED_EXISTING_ACTION=""
EXISTING_DECISION_PATHS=()
EXISTING_DECISION_ACTIONS=()
BACKUP_ROOT=""
BACKUP_OCCURRED=0

usage() {
    cat >&2 <<'EOF'
Usage:
  install.sh [--yes] --repo PATH [--repo PATH ...] [--language zh|en] [--install-mode global|single|custom] [--hosts all|openclaw,claude-code,opencode,codex,hermes] [--execution-clis all|claude-code,opencode,cursor,codex,hermes] [--existing backup|skip|overwrite] [--scan-depth N]
  install.sh [--yes] --auto-scan --scan-root PATH [--scan-depth N] [--language zh|en] [--install-mode global|single|custom] [--hosts all|openclaw,claude-code,opencode,codex,hermes] [--execution-clis all|claude-code,opencode,cursor,codex,hermes] [--existing backup|skip|overwrite]
  install.sh

Pipe install:
  curl -fsSL https://raw.githubusercontent.com/wufei-png/AgentRepoRouter/main/scripts/install.sh | bash
EOF
    exit 1
}

require_arg() {
    local option="$1"
    local value="${2:-}"

    if [ -z "$value" ]; then
        echo "Error: $option requires a value" >&2
        usage
    fi
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --yes)
                YES=1
                shift
                ;;
            --language)
                require_arg "$1" "${2:-}"
                SKILL_LANG="$2"
                shift 2
                ;;
            --repo)
                require_arg "$1" "${2:-}"
                REPO_ARGS+=("$2")
                shift 2
                ;;
            --auto-scan)
                AUTO_SCAN=1
                shift
                ;;
            --scan-root)
                require_arg "$1" "${2:-}"
                SCAN_ROOT="$2"
                shift 2
                ;;
            --scan-depth)
                require_arg "$1" "${2:-}"
                SCAN_MAX_DEPTH="$2"
                SCAN_DEPTH_CONFIGURED=1
                shift 2
                ;;
            --install-mode)
                require_arg "$1" "${2:-}"
                INSTALL_MODE="$2"
                shift 2
                ;;
            --hosts)
                require_arg "$1" "${2:-}"
                HOSTS_RAW="$2"
                HOSTS_ARG_SET=1
                shift 2
                ;;
            --execution-clis)
                require_arg "$1" "${2:-}"
                EXECUTION_CLIS_RAW="$2"
                EXECUTION_CLIS_ARG_SET=1
                shift 2
                ;;
            --existing)
                require_arg "$1" "${2:-}"
                EXISTING="$2"
                EXISTING_ARG_SET=1
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Error: unknown option: $1" >&2
                usage
                ;;
        esac
    done

    case "$SKILL_LANG" in ""|zh|en) ;; *) usage ;; esac
    case "$INSTALL_MODE" in ""|global|single|custom) ;; *) usage ;; esac
    case "$EXISTING" in backup|skip|overwrite) ;; *) usage ;; esac
    case "$SCAN_MAX_DEPTH" in ""|*[!0-9]*|0) usage ;; esac
    case "$AGENT_REPO_ROUTER_USE_LOCAL_CACHE" in
        auto|1|true|TRUE|True|yes|YES|on|ON|0|false|FALSE|False|no|NO|off|OFF)
            ;;
        *)
            echo "Error: AGENT_REPO_ROUTER_USE_LOCAL_CACHE must be auto, true, or false" >&2
            exit 1
            ;;
    esac
}

download_remote_file() {
    local remote_path="$1"
    local dest_path="$2"
    local dest_dir
    local remote_url="${REMOTE_RAW_BASE_URL}/${remote_path}"

    dest_dir="$(dirname "$dest_path")"
    mkdir -p "$dest_dir"
    echo "  Downloading ${remote_path}..."
    if curl -fsSL "$remote_url" -o "$dest_path"; then
        echo -e "    ${GREEN}✓${NC} ${remote_path}"
        return 0
    fi
    echo -e "    ${RED}✗${NC} Failed to download ${remote_path}"
    return 1
}

should_use_local_file() {
    local path="$1"

    case "$AGENT_REPO_ROUTER_USE_LOCAL_CACHE" in
        1|true|TRUE|True|yes|YES|on|ON)
            if [ -f "$path" ]; then
                return 0
            fi
            echo -e "${RED}Error: required local file is missing: $path${NC}" >&2
            exit 1
            ;;
        auto)
            [ -f "$path" ]
            ;;
        *)
            return 1
            ;;
    esac
}

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
        IFS= read -r REPLY <&$TTY_FD || REPLY=""
    else
        IFS= read -r REPLY || REPLY=""
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

sync_all_detected_row() {
    local index=0
    local detected_count=0
    local selected_count=0

    if [ "$MENU_ALL_DETECTED_MODE" -ne 1 ]; then
        return
    fi

    for index in "${!MENU_LABELS[@]}"; do
        if [ "$index" -eq 0 ]; then
            continue
        fi
        if [ "${MENU_ROW_DETECTED[$index]:-0}" -eq 1 ]; then
            detected_count=$((detected_count + 1))
            if [ "${MENU_SELECTED[$index]:-0}" -eq 1 ]; then
                selected_count=$((selected_count + 1))
            fi
        fi
    done

    if [ "$detected_count" -gt 0 ] && [ "$selected_count" -eq "$detected_count" ]; then
        MENU_SELECTED[0]=1
    else
        MENU_SELECTED[0]=0
    fi
}

toggle_all_detected_rows() {
    local index=0
    local next_state=1

    if [ "${MENU_SELECTED[0]:-0}" -eq 1 ]; then
        next_state=0
    fi

    MENU_SELECTED[0]=$next_state
    for index in "${!MENU_LABELS[@]}"; do
        if [ "$index" -eq 0 ]; then
            continue
        fi
        if [ "${MENU_ROW_DETECTED[$index]:-0}" -eq 1 ]; then
            MENU_SELECTED[$index]=$next_state
        fi
    done
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
    if [ "$mode" = "single" ] && [ "${#MENU_LABELS[@]}" -gt 0 ]; then
        MENU_SELECTED[0]=1
    fi

    ui_printf "\033[?25l"
    while true; do
        if [ "$mode" = "single" ]; then
            draw_menu "$title" "Use ↑/↓ to move, Space to select, Enter to confirm."
        else
            draw_menu "$title" "Use ↑/↓ to move, Space to select, Enter to confirm."
        fi
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
                    if [ "$MENU_ALL_DETECTED_MODE" -eq 1 ] && [ "$MENU_CURSOR" -eq 0 ]; then
                        toggle_all_detected_rows
                    elif [ "${MENU_SELECTED[$MENU_CURSOR]:-0}" -eq 1 ]; then
                        MENU_SELECTED[$MENU_CURSOR]=0
                    else
                        MENU_SELECTED[$MENU_CURSOR]=1
                    fi
                    sync_all_detected_row
                fi
                MENU_MESSAGE=""
                ;;
            enter)
                selected_count=0
                for index in "${!MENU_SELECTED[@]}"; do
                    if [ "$MENU_ALL_DETECTED_MODE" -eq 1 ] && [ "$index" -eq 0 ]; then
                        continue
                    fi
                    if [ "${MENU_SELECTED[$index]:-0}" -eq 1 ]; then
                        selected_count=$((selected_count + 1))
                    fi
                done

                if [ "$selected_count" -eq 0 ]; then
                    MENU_MESSAGE="${RED}${empty_message}${NC}"
                    continue
                fi

                for index in "${!MENU_SELECTED[@]}"; do
                    if [ "$MENU_ALL_DETECTED_MODE" -eq 1 ] && [ "$index" -eq 0 ]; then
                        continue
                    fi
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

get_execution_cli_command() {
    case "$1" in
        claude-code) echo "claude" ;;
        opencode) echo "opencode" ;;
        cursor) echo "agent" ;;
        codex) echo "codex" ;;
        hermes) echo "hermes" ;;
        *) return 1 ;;
    esac
}

get_host_command() {
    case "$1" in
        openclaw) echo "openclaw" ;;
        claude-code) echo "claude" ;;
        opencode) echo "opencode" ;;
        codex) echo "codex" ;;
        hermes) echo "hermes" ;;
        *) return 1 ;;
    esac
}

get_host_label() {
    case "$1" in
        openclaw) echo "OpenClaw" ;;
        claude-code) echo "Claude Code" ;;
        opencode) echo "OpenCode" ;;
        codex) echo "Codex" ;;
        hermes) echo "Hermes" ;;
        *) echo "$1" ;;
    esac
}

get_host_dir() {
    case "$1" in
        openclaw) echo "$HOME/.openclaw/skills/$SKILL_SLUG" ;;
        claude-code) echo "$HOME/.claude/skills/$SKILL_SLUG" ;;
        opencode) echo "$HOME/.config/opencode/skills/$SKILL_SLUG" ;;
        codex) echo "$CANONICAL_SKILL_DIR" ;;
        hermes) echo "$HOME/.hermes/skills/software-development/$SKILL_SLUG" ;;
        *) return 1 ;;
    esac
}

display_path() {
    local path_value="$1"
    case "$path_value" in
        "$HOME"/*) echo "~/${path_value#"$HOME"/}" ;;
        *) echo "$path_value" ;;
    esac
}

print_host_install_target() {
    local host_name="$1"
    local host_dir

    host_dir="$(get_host_dir "$host_name")"
    echo "  Target: $(display_path "$host_dir")"
    if [ "$host_name" = "codex" ]; then
        echo "  Note: Codex loads skills from ~/.agents/skills; ~/.codex/skills is not used."
    fi
}

is_execution_cli_installed() {
    local cli_command
    cli_command=$(get_execution_cli_command "$1") || return 1
    check_cli "$cli_command"
}

is_host_detected() {
    local host_command
    host_command=$(get_host_command "$1") || return 1
    check_cli "$host_command"
}

host_status_label() {
    if is_host_detected "$1"; then
        echo "${GREEN}✓ detected${NC}"
    else
        echo "${YELLOW}not detected, can still create directory${NC}"
    fi
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

join_by_comma() {
    local IFS=","
    echo "$*"
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

    for existing_path in ${REPOS[@]+"${REPOS[@]}"}; do
        if [ "$existing_path" = "$repo_path" ]; then
            return 0
        fi
    done

    return 1
}

count_installed_execution_clis() {
    local count=0
    local cli_name

    for cli_name in "claude-code" "opencode" "cursor" "codex" "hermes"; do
        if is_execution_cli_installed "$cli_name"; then
            count=$((count + 1))
        fi
    done

    echo "$count"
}

detected_install_hosts() {
    local host_name
    for host_name in "openclaw" "claude-code" "opencode" "codex" "hermes"; do
        if is_host_detected "$host_name"; then
            printf '%s\n' "$host_name"
        fi
    done
}

is_supported_host() {
    case "$1" in
        openclaw|claude-code|opencode|codex|hermes) return 0 ;;
        *) return 1 ;;
    esac
}

is_supported_execution_cli() {
    case "$1" in
        claude-code|opencode|cursor|codex|hermes) return 0 ;;
        *) return 1 ;;
    esac
}

add_selected_host() {
    local host_name="$1"

    if ! is_supported_host "$host_name"; then
        echo "Error: unsupported install host: $host_name" >&2
        exit 1
    fi
    if ! array_contains "$host_name" ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; then
        SELECTED_INSTALL_HOSTS+=("$host_name")
    fi
}

add_detected_hosts_with_fallback() {
    local detected_host=""

    while IFS= read -r detected_host; do
        [ -n "$detected_host" ] || continue
        add_selected_host "$detected_host"
    done <<EOF
$(detected_install_hosts)
EOF

    if [ "${#SELECTED_INSTALL_HOSTS[@]}" -eq 0 ]; then
        add_selected_host "codex"
        echo -e "${YELLOW}Warning: no supported agent host detected; using Codex canonical install target.${NC}"
    fi
}

parse_hosts_raw() {
    local raw_hosts="$1"
    local host_name=""

    if [ -z "$raw_hosts" ]; then
        echo "Error: --hosts requires at least one host or all" >&2
        exit 1
    fi

    SELECTED_INSTALL_HOSTS=()
    for host_name in $(printf '%s\n' "$raw_hosts" | tr ',' ' '); do
        case "$host_name" in
            all|ALL)
                add_detected_hosts_with_fallback
                ;;
            *)
                add_selected_host "$host_name"
                ;;
        esac
    done

    if [ "${#SELECTED_INSTALL_HOSTS[@]}" -eq 0 ]; then
        echo "Error: --hosts requires at least one host or all" >&2
        exit 1
    fi
}

add_selected_execution_cli() {
    local cli_name="$1"

    if ! is_supported_execution_cli "$cli_name"; then
        echo "Error: unsupported execution CLI: $cli_name" >&2
        exit 1
    fi
    if ! is_execution_cli_installed "$cli_name"; then
        echo "Error: selected execution CLI is not installed: $cli_name" >&2
        exit 1
    fi
    if ! array_contains "$cli_name" ${SELECTED_CLIS[@]+"${SELECTED_CLIS[@]}"}; then
        SELECTED_CLIS+=("$cli_name")
    fi
}

add_detected_execution_clis() {
    local cli_name=""

    SELECTED_CLIS=()
    for cli_name in "claude-code" "opencode" "cursor" "codex" "hermes"; do
        if is_execution_cli_installed "$cli_name"; then
            SELECTED_CLIS+=("$cli_name")
        fi
    done
}

parse_execution_clis_raw() {
    local raw_clis="$1"
    local cli_name=""

    if [ -z "$raw_clis" ]; then
        echo "Error: --execution-clis requires at least one CLI or all" >&2
        exit 1
    fi

    SELECTED_CLIS=()
    for cli_name in $(printf '%s\n' "$raw_clis" | tr ',' ' '); do
        case "$cli_name" in
            all|ALL)
                add_detected_execution_clis
                ;;
            *)
                add_selected_execution_cli "$cli_name"
                ;;
        esac
    done
}

validate_repo_mappings() {
    local script_dir
    local validate_path
    local tmp_validate=""

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    validate_path="$script_dir/validate_repo_mappings.sh"

    if should_use_local_file "$validate_path"; then
        bash "$validate_path" "$1" >/dev/null
        return
    fi

    tmp_validate="$(mktemp)"
    if ! download_remote_file "scripts/validate_repo_mappings.sh" "$tmp_validate"; then
        rm -f "$tmp_validate"
        echo -e "${RED}Error: Could not download scripts/validate_repo_mappings.sh${NC}"
        echo -e "${YELLOW}URL: ${REMOTE_RAW_BASE_URL}/scripts/validate_repo_mappings.sh${NC}"
        echo -e "${YELLOW}Or set AGENT_REPO_ROUTER_USE_LOCAL_CACHE=true when running from a full repo clone.${NC}"
        exit 1
    fi
    chmod +x "$tmp_validate" 2>/dev/null || true
    bash "$tmp_validate" "$1" >/dev/null
    rm -f "$tmp_validate"
}

check_environment() {
    echo "Checking environment..."

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

    if check_cli "git"; then
        echo -e "${GREEN}✓ Git${NC}"
    else
        echo -e "${RED}✗ Git not found${NC}"
        exit 1
    fi

    echo ""
}

select_language() {
    local choice=""

    if [ -n "$SKILL_LANG" ]; then
        if [ "$SKILL_LANG" = "zh" ]; then
            echo -e "${GREEN}Selected: 中文${NC}"
        else
            echo -e "${GREEN}Selected: English${NC}"
        fi
        echo ""
        return
    fi

    if [ "$YES" -eq 1 ]; then
        SKILL_LANG="zh"
        echo -e "${GREEN}Selected: 中文${NC}"
        echo ""
        return
    fi

    if can_use_interactive_menu; then
        MENU_LABELS=("中文" "English")
        MENU_VALUES=("zh" "en")
        MENU_ENABLED=(1 1)
        MENU_ALL_DETECTED_MODE=0
        run_menu "Select language / 选择语言" "single" "Please select one language."
        SKILL_LANG="$MENU_RESULT"
    else
        echo "Select language / 选择语言:"
        echo "  [1] 中文"
        echo "  [2] English"
        echo ""

        while true; do
            read_user_line "Enter choice [1-2]: "
            choice="$REPLY"
            case $choice in
                1) SKILL_LANG="zh"; break ;;
                2) SKILL_LANG="en"; break ;;
                *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
            esac
        done
    fi

    if [ "$SKILL_LANG" = "zh" ]; then
        echo -e "${GREEN}Selected: 中文${NC}"
    else
        echo -e "${GREEN}Selected: English${NC}"
    fi
    echo ""
}

build_host_menu_rows() {
    local include_all="$1"
    local host_name
    local label
    local status
    local index=0

    MENU_LABELS=()
    MENU_VALUES=()
    MENU_ENABLED=()
    MENU_ROW_DETECTED=()

    if [ "$include_all" = "true" ]; then
        MENU_LABELS+=("All detected hosts")
        MENU_VALUES+=("all-detected")
        MENU_ENABLED+=(1)
        MENU_ROW_DETECTED+=(0)
    fi

    for host_name in "openclaw" "claude-code" "opencode" "codex" "hermes"; do
        label="$(get_host_label "$host_name")"
        status="$(host_status_label "$host_name")"
        MENU_LABELS+=("${label} (${status})")
        MENU_VALUES+=("$host_name")
        MENU_ENABLED+=(1)
        if is_host_detected "$host_name"; then
            MENU_ROW_DETECTED+=(1)
        else
            MENU_ROW_DETECTED+=(0)
        fi
        index=$((index + 1))
    done
}

print_host_summary() {
    local host_name
    local marker
    local label
    local status

    echo "Install host status:"
    for host_name in "openclaw" "claude-code" "opencode" "codex" "hermes"; do
        if array_contains "$host_name" ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; then
            marker="[x]"
        else
            marker="[ ]"
        fi
        label="$(get_host_label "$host_name")"
        status="$(host_status_label "$host_name")"
        echo -e "  ${marker} ${label} (${status})"
    done
    echo ""
}

confirm_global_host_preview() {
    local index=0
    local value=""
    local key=""

    build_host_menu_rows "false"
    MENU_SELECTED=()
    MENU_ENABLED=()
    for index in "${!MENU_VALUES[@]}"; do
        value="${MENU_VALUES[$index]}"
        if array_contains "$value" ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; then
            MENU_SELECTED[$index]=1
        else
            MENU_SELECTED[$index]=0
        fi
        MENU_ENABLED[$index]=1
    done

    MENU_CURSOR=0
    MENU_LINES=0
    MENU_MESSAGE="${GREEN}Global installs once to ~/.agents/skills and links the detected hosts above. Press Enter to continue.${NC}"

    ui_printf "\033[?25l"
    while true; do
        draw_menu "Global install hosts" "All detected hosts are pre-selected. Use Custom hosts to change this."
        key=$(read_menu_key) || key="enter"
        case "$key" in
            enter) break ;;
            *) MENU_MESSAGE="${GREEN}Press Enter to continue, or restart and choose Custom hosts to change targets.${NC}" ;;
        esac
    done
    ui_printf "\033[?25h"
    ui_printf "\n"
}

select_global_hosts() {
    SELECTED_INSTALL_HOSTS=()
    add_detected_hosts_with_fallback
    if can_use_interactive_menu; then
        confirm_global_host_preview
    else
        print_host_summary
    fi
}

select_install_mode() {
    local choice=""

    if [ "$HOSTS_ARG_SET" -eq 1 ]; then
        parse_hosts_raw "$HOSTS_RAW"
        if [ -z "$INSTALL_MODE" ]; then
            if [ "${#SELECTED_INSTALL_HOSTS[@]}" -eq 1 ]; then
                INSTALL_MODE="single"
            else
                INSTALL_MODE="custom"
            fi
        fi
        if [ "$INSTALL_MODE" = "single" ] && [ "${#SELECTED_INSTALL_HOSTS[@]}" -ne 1 ]; then
            echo "Error: --install-mode single requires exactly one --hosts value" >&2
            exit 1
        fi
        echo -e "${GREEN}Selected install mode: ${INSTALL_MODE}${NC}"
        print_host_summary
        return
    fi

    if [ "$YES" -eq 1 ]; then
        if [ -z "$INSTALL_MODE" ]; then
            INSTALL_MODE="global"
        fi
        case "$INSTALL_MODE" in
            global)
                select_global_hosts
                ;;
            single|custom)
                echo "Error: --install-mode $INSTALL_MODE requires --hosts in --yes mode" >&2
                exit 1
                ;;
        esac
        echo -e "${GREEN}Selected install mode: ${INSTALL_MODE}${NC}"
        return
    fi

    if [ -n "$INSTALL_MODE" ]; then
        case "$INSTALL_MODE" in
            global)
                echo -e "${GREEN}Selected install mode: Global${NC}"
                select_global_hosts
                ;;
            single)
                echo -e "${GREEN}Selected install mode: Single host${NC}"
                select_single_host
                ;;
            custom)
                echo -e "${GREEN}Selected install mode: Custom hosts${NC}"
                select_custom_hosts
                ;;
        esac
        return
    fi

    if can_use_interactive_menu; then
        MENU_LABELS=(
            "Global (recommended) - install to ~/.agents/skills and link detected hosts"
            "Single host - install directly to one host"
            "Custom hosts - install globally and link selected hosts"
        )
        MENU_VALUES=("global" "single" "custom")
        MENU_ENABLED=(1 1 1)
        MENU_ALL_DETECTED_MODE=0
        run_menu "Install target mode" "single" "Please select one install mode."
        INSTALL_MODE="$MENU_RESULT"
    else
        echo "Install target mode:"
        echo "  [1] Global (recommended) - install to ~/.agents/skills and link detected hosts"
        echo "  [2] Single host - install directly to one host"
        echo "  [3] Custom hosts - install globally and link selected hosts"
        echo ""

        while true; do
            read_user_line "Enter choice [1-3, default 1]: "
            choice="$REPLY"
            case $choice in
                ""|1) INSTALL_MODE="global"; break ;;
                2) INSTALL_MODE="single"; break ;;
                3) INSTALL_MODE="custom"; break ;;
                *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
            esac
        done
    fi

    case "$INSTALL_MODE" in
        global)
            echo -e "${GREEN}Selected install mode: Global${NC}"
            select_global_hosts
            ;;
        single)
            echo -e "${GREEN}Selected install mode: Single host${NC}"
            select_single_host
            ;;
        custom)
            echo -e "${GREEN}Selected install mode: Custom hosts${NC}"
            select_custom_hosts
            ;;
    esac
}

select_single_host() {
    local choice=""
    local selected_host=""

    if can_use_interactive_menu; then
        build_host_menu_rows "false"
        MENU_ALL_DETECTED_MODE=0
        run_menu "Select one install host" "single" "Please select one install host."
        SELECTED_INSTALL_HOSTS=("$MENU_RESULT")
        echo -e "${GREEN}Selected install host: $(get_host_label "$MENU_RESULT")${NC}"
        print_host_install_target "$MENU_RESULT"
        echo ""
        return
    fi

    echo "Select one install host:"
    echo -e "  [1] OpenClaw     ($(host_status_label "openclaw"))"
    echo -e "  [2] Claude Code  ($(host_status_label "claude-code"))"
    echo -e "  [3] OpenCode     ($(host_status_label "opencode"))"
    echo -e "  [4] Codex        ($(host_status_label "codex"))"
    echo -e "  [5] Hermes       ($(host_status_label "hermes"))"
    echo ""

    while true; do
        read_user_line "Enter choice [1-5]: "
        choice="$REPLY"
        case $choice in
            1) selected_host="openclaw" ;;
            2) selected_host="claude-code" ;;
            3) selected_host="opencode" ;;
            4) selected_host="codex" ;;
            5) selected_host="hermes" ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                continue
                ;;
        esac
        break
    done

    SELECTED_INSTALL_HOSTS=("$selected_host")
    echo -e "${GREEN}Selected install host: $(get_host_label "$selected_host")${NC}"
    print_host_install_target "$selected_host"
    echo ""
}

select_custom_hosts() {
    local choices=""
    local choice=""
    local selected_host=""
    local has_all_detected=0

    if can_use_interactive_menu; then
        build_host_menu_rows "true"
        MENU_ALL_DETECTED_MODE=1
        run_menu "Select install hosts" "multi" "Please select at least one install host."
        SELECTED_INSTALL_HOSTS=("${MENU_RESULTS[@]}")
        echo -e "${GREEN}Selected install hosts: ${SELECTED_INSTALL_HOSTS[*]}${NC}"
        echo ""
        return
    fi

    echo "Select install hosts:"
    echo "  [0] All detected hosts"
    echo -e "  [1] OpenClaw     ($(host_status_label "openclaw"))"
    echo -e "  [2] Claude Code  ($(host_status_label "claude-code"))"
    echo -e "  [3] OpenCode     ($(host_status_label "opencode"))"
    echo -e "  [4] Codex        ($(host_status_label "codex"))"
    echo -e "  [5] Hermes       ($(host_status_label "hermes"))"
    echo ""

    while true; do
        read_user_line "Enter numbers (e.g., 0 or 1,3,5): "
        choices="$REPLY"
        if [ -z "$choices" ]; then
            echo -e "${RED}Please select at least one install host.${NC}"
            continue
        fi

        SELECTED_INSTALL_HOSTS=()
        has_all_detected=0
        for choice in $(echo "$choices" | tr ',' ' '); do
            selected_host=""
            case $choice in
                0|all|ALL) has_all_detected=1 ;;
                1) selected_host="openclaw" ;;
                2) selected_host="claude-code" ;;
                3) selected_host="opencode" ;;
                4) selected_host="codex" ;;
                5) selected_host="hermes" ;;
                *)
                    echo -e "${YELLOW}Warning: Ignoring invalid choice: $choice${NC}"
                    continue
                    ;;
            esac

            if [ -n "$selected_host" ] && ! array_contains "$selected_host" ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; then
                SELECTED_INSTALL_HOSTS+=("$selected_host")
            fi
        done

        if [ "$has_all_detected" -eq 1 ]; then
            add_detected_hosts_with_fallback
        fi

        if [ "${#SELECTED_INSTALL_HOSTS[@]}" -eq 0 ]; then
            echo -e "${RED}Please select at least one install host.${NC}"
            continue
        fi
        break
    done

    echo -e "${GREEN}Selected install hosts: ${SELECTED_INSTALL_HOSTS[*]}${NC}"
    echo ""
}

select_clis() {
    local claude_label="claude-code"
    local opencode_label="opencode"
    local cursor_label="cursor"
    local codex_label="codex"
    local hermes_label="hermes"
    local choices=""
    local choice=""
    local selected_cli=""
    local has_error=0

    if [ "$EXECUTION_CLIS_ARG_SET" -eq 1 ]; then
        parse_execution_clis_raw "$EXECUTION_CLIS_RAW"
        if [ "${#SELECTED_CLIS[@]}" -eq 0 ]; then
            echo -e "${RED}No supported execution CLIs were found. Install at least one of claude-code, opencode, cursor, codex, or hermes.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Selected execution CLIs: ${SELECTED_CLIS[*]}${NC}"
        echo ""
        return
    fi

    if [ "$YES" -eq 1 ]; then
        add_detected_execution_clis
        if [ "${#SELECTED_CLIS[@]}" -eq 0 ]; then
            echo -e "${RED}No supported execution CLIs were found. Install at least one of claude-code, opencode, cursor, codex, or hermes.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Selected execution CLIs: ${SELECTED_CLIS[*]}${NC}"
        echo ""
        return
    fi

    if [ "$(count_installed_execution_clis)" -eq 0 ]; then
        echo -e "${RED}No supported execution CLIs were found. Install at least one of claude-code, opencode, cursor, codex, or hermes.${NC}"
        exit 1
    fi

    if can_use_interactive_menu; then
        is_execution_cli_installed "claude-code" && claude_label="${claude_label} (${GREEN}installed${NC})" || claude_label="${claude_label} (${RED}not found${NC})"
        is_execution_cli_installed "opencode" && opencode_label="${opencode_label} (${GREEN}installed${NC})" || opencode_label="${opencode_label} (${RED}not found${NC})"
        is_execution_cli_installed "cursor" && cursor_label="${cursor_label} (${GREEN}installed${NC})" || cursor_label="${cursor_label} (${RED}not found${NC})"
        is_execution_cli_installed "codex" && codex_label="${codex_label} (${GREEN}installed${NC})" || codex_label="${codex_label} (${RED}not found${NC})"
        is_execution_cli_installed "hermes" && hermes_label="${hermes_label} (${GREEN}installed${NC})" || hermes_label="${hermes_label} (${RED}not found${NC})"

        MENU_LABELS=("$claude_label" "$opencode_label" "$cursor_label" "$codex_label" "$hermes_label")
        MENU_VALUES=("claude-code" "opencode" "cursor" "codex" "hermes")
        MENU_ENABLED=(0 0 0 0 0)
        MENU_ALL_DETECTED_MODE=0
        is_execution_cli_installed "claude-code" && MENU_ENABLED[0]=1
        is_execution_cli_installed "opencode" && MENU_ENABLED[1]=1
        is_execution_cli_installed "cursor" && MENU_ENABLED[2]=1
        is_execution_cli_installed "codex" && MENU_ENABLED[3]=1
        is_execution_cli_installed "hermes" && MENU_ENABLED[4]=1
        run_menu "Select execution CLIs to route to" "multi" "Please select at least one installed execution CLI."
        SELECTED_CLIS=("${MENU_RESULTS[@]}")
        echo -e "${GREEN}Selected execution CLIs: ${SELECTED_CLIS[*]}${NC}"
        echo ""
        return
    fi

    echo "Select execution CLIs to route to (select at least one):"
    echo "  [1] claude-code  ($(check_cli "claude" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [2] opencode     ($(check_cli "opencode" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [3] cursor       ($(check_cli "agent" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [4] codex        ($(check_cli "codex" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo "  [5] hermes       ($(check_cli "hermes" && echo -e "${GREEN}installed${NC}" || echo -e "${RED}not found${NC}"))"
    echo ""

    while true; do
        read_user_line "Enter numbers (e.g., 1,2,4): "
        choices="$REPLY"
        if [ -z "$choices" ]; then
            echo -e "${RED}Please select at least one CLI.${NC}"
            continue
        fi

        SELECTED_CLIS=()
        has_error=0

        for choice in $(echo "$choices" | tr ',' ' '); do
            selected_cli=""
            case $choice in
                1) selected_cli="claude-code" ;;
                2) selected_cli="opencode" ;;
                3) selected_cli="cursor" ;;
                4) selected_cli="codex" ;;
                5) selected_cli="hermes" ;;
                *)
                    echo -e "${YELLOW}Warning: Ignoring invalid choice: $choice${NC}"
                    has_error=1
                    continue
                    ;;
            esac

            if ! is_execution_cli_installed "$selected_cli"; then
                echo -e "${YELLOW}Warning: Selected CLI is not installed: $selected_cli${NC}"
                has_error=1
                continue
            fi

            if ! array_contains "$selected_cli" ${SELECTED_CLIS[@]+"${SELECTED_CLIS[@]}"}; then
                SELECTED_CLIS+=("$selected_cli")
            fi
        done

        if [ "${#SELECTED_CLIS[@]}" -eq 0 ]; then
            echo -e "${RED}Please select at least one installed CLI.${NC}"
            continue
        fi

        if [ "$has_error" -eq 1 ]; then
            echo -e "${YELLOW}Please re-enter your CLI selection using installed options only.${NC}"
            continue
        fi

        break
    done

    echo -e "${GREEN}Selected execution CLIs: ${SELECTED_CLIS[*]}${NC}"
    echo ""
}

confirm_yes_no() {
    local prompt="$1"
    local default_answer="${2:-no}"
    local answer=""
    local suffix="[y/N]"

    if [ "$default_answer" = "yes" ]; then
        suffix="[Y/n]"
    fi

    if can_use_interactive_menu; then
        if [ "$default_answer" = "yes" ]; then
            MENU_LABELS=("Yes (default)" "No")
            MENU_VALUES=("yes" "no")
        else
            MENU_LABELS=("No (default)" "Yes")
            MENU_VALUES=("no" "yes")
        fi
        MENU_ENABLED=(1 1)
        MENU_ALL_DETECTED_MODE=0
        run_menu "$prompt" "single" "Please select yes or no."
        [ "$MENU_RESULT" = "yes" ]
        return
    fi

    while true; do
        read_user_line "$prompt $suffix "
        answer="$REPLY"
        case "$answer" in
            "")
                [ "$default_answer" = "yes" ]
                return
                ;;
            y|Y|yes|YES) return 0 ;;
            n|N|no|NO) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

find_git_root() {
    local path="$1"

    while [ "$path" != "/" ] && [ -n "$path" ]; do
        if [ -d "$path/.git" ] || [ -f "$path/.git" ]; then
            printf '%s\n' "$path"
            return 0
        fi
        path="$(dirname "$path")"
    done

    return 1
}

find_repos_under() {
    local scan_root="$1"

    find "$scan_root" -maxdepth "$SCAN_MAX_DEPTH" \( -type d -name ".git" -o -type f -name ".git" \) -print 2>/dev/null \
        | while IFS= read -r git_marker; do
            dirname "$git_marker"
        done \
        | sort -u
}

print_repo_candidates() {
    local candidate=""
    for candidate in "$@"; do
        echo "  - $(basename "$candidate") ($candidate)"
    done
}

add_repo_path() {
    local repo_path="$1"

    repo_path="$(normalize_path "$repo_path")"
    if repo_path_exists "$repo_path"; then
        echo -e "${YELLOW}Warning: Duplicate project path filtered: $repo_path${NC}"
        return
    fi

    REPOS+=("$repo_path")
    echo -e "  ${GREEN}✓${NC} Added: $(basename "$repo_path") ($repo_path)"
}

add_repo_candidates() {
    local candidate=""

    for candidate in "$@"; do
        add_repo_path "$candidate"
    done
}

process_repo_path() {
    local raw_path="$1"
    local normalized=""
    local top_level=""
    local candidate=""
    local candidates=()

    if [ -z "$raw_path" ]; then
        echo -e "${YELLOW}Warning: empty repository path ignored${NC}"
        return
    fi

    if [[ "$raw_path" != /* ]]; then
        echo -e "${YELLOW}Warning: Please enter an absolute path: $raw_path${NC}"
        return
    fi

    if [ ! -d "$raw_path" ]; then
        echo -e "${YELLOW}Warning: Directory does not exist: $raw_path${NC}"
        return
    fi

    normalized="$(normalize_path "$raw_path")"
    top_level="$(find_git_root "$normalized" || true)"
    if [ -n "$top_level" ]; then
        if [ "$top_level" != "$normalized" ]; then
            echo -e "${YELLOW}Warning: $normalized is inside a git repository; using repository root $top_level${NC}"
        fi
        add_repo_path "$top_level"
        return
    fi

    echo -e "${YELLOW}Warning: $normalized is not a git repository. Scanning beneath it for repositories.${NC}"
    while IFS= read -r candidate; do
        [ -n "$candidate" ] && candidates+=("$candidate")
    done < <(find_repos_under "$normalized")

    if [ "${#candidates[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Warning: no git repositories detected beneath $normalized${NC}"
        return
    fi

    echo "Detected repositories under $normalized:"
    print_repo_candidates "${candidates[@]}"
    if [ "$YES" -eq 1 ] || confirm_yes_no "Add all detected repositories?" "yes"; then
        add_repo_candidates "${candidates[@]}"
    else
        echo "Skipped detected repositories under $normalized"
    fi
}

select_scan_depth_interactive() {
    local depth=""
    local option=""

    if can_use_interactive_menu; then
        MENU_LABELS=("$SCAN_MAX_DEPTH (default)")
        MENU_VALUES=("$SCAN_MAX_DEPTH")
        MENU_ENABLED=(1)
        MENU_ROW_DETECTED=(0)
        for option in 1 2 3 4 5; do
            if [ "$option" != "$SCAN_MAX_DEPTH" ]; then
                MENU_LABELS+=("$option")
                MENU_VALUES+=("$option")
                MENU_ENABLED+=(1)
                MENU_ROW_DETECTED+=(0)
            fi
        done
        MENU_LABELS+=("Custom depth")
        MENU_VALUES+=("custom")
        MENU_ENABLED+=(1)
        MENU_ROW_DETECTED+=(0)
        MENU_ALL_DETECTED_MODE=0
        run_menu "Repository scan depth" "single" "Please select one scan depth."
        if [ "$MENU_RESULT" != "custom" ]; then
            SCAN_MAX_DEPTH="$MENU_RESULT"
            return
        fi
    fi

    while true; do
        read_user_line "Repository scan depth [default: $SCAN_MAX_DEPTH]: "
        depth="$REPLY"
        if [ -z "$depth" ]; then
            return
        fi
        case "$depth" in
            *[!0-9]*|0)
                echo "Invalid scan depth. Please enter a positive integer."
                ;;
            *)
                SCAN_MAX_DEPTH="$depth"
                return
                ;;
        esac
    done
}

collect_auto_scan_repos() {
    local scan_root="$SCAN_ROOT"
    local candidate=""
    local candidates=()
    local depth_selected=0

    while true; do
        if [ -z "$scan_root" ]; then
            if [ "$YES" -eq 1 ]; then
                echo "Error: --auto-scan with --yes requires --scan-root PATH" >&2
                exit 1
            fi
            read_user_line "Repository prefix directory to scan: "
            scan_root="$REPLY"
        fi

        if [ ! -d "$scan_root" ]; then
            echo -e "${RED}Directory does not exist: $scan_root${NC}"
            scan_root=""
            continue
        fi

        scan_root="$(normalize_path "$scan_root")"
        if [ "$scan_root" = "/" ]; then
            echo -e "${YELLOW}Warning: refusing to scan filesystem root. Choose a narrower repository prefix directory.${NC}"
            scan_root=""
            continue
        fi

        echo "Repository prefix directory: $scan_root"
        if [ "$YES" -ne 1 ] && [ "$SCAN_DEPTH_CONFIGURED" -ne 1 ] && [ "$depth_selected" -eq 0 ]; then
            select_scan_depth_interactive
            depth_selected=1
        fi
        if [ "$YES" -eq 1 ] || confirm_yes_no "Scan this prefix for git repositories with max depth $SCAN_MAX_DEPTH?" "yes"; then
            break
        fi
        scan_root=""
        depth_selected=0
    done

    echo "Scanning for git repositories under $scan_root (max depth: $SCAN_MAX_DEPTH)..."
    while IFS= read -r candidate; do
        [ -n "$candidate" ] && candidates+=("$candidate")
    done < <(find_repos_under "$scan_root")

    if [ "${#candidates[@]}" -eq 0 ]; then
        echo -e "${YELLOW}No git repositories found.${NC}"
        return
    fi

    echo "Detected repositories:"
    print_repo_candidates "${candidates[@]}"
    if [ "$YES" -eq 1 ] || confirm_yes_no "Add all detected repositories?" "yes"; then
        add_repo_candidates "${candidates[@]}"
    else
        echo "Skipped auto-scan repositories"
    fi
}

manual_input() {
    local repo_path=""

    echo "Manual project input..."
    echo "Enter project paths one per line. If a path is not a git repository, AgentRepoRouter will scan beneath it."
    echo "Submit an empty line to finish."

    while true; do
        read_user_line "Path: "
        repo_path="$REPLY"
        [ -n "$repo_path" ] || break
        process_repo_path "$repo_path"
    done

    echo ""
}

discover_projects() {
    local choice=""
    local repo_arg=""

    for repo_arg in ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}; do
        process_repo_path "$repo_arg"
    done

    if [ "$AUTO_SCAN" -eq 1 ]; then
        collect_auto_scan_repos
    fi

    if [ "${#REPOS[@]}" -gt 0 ]; then
        return
    fi

    if [ "$YES" -eq 1 ]; then
        echo "Error: no repositories selected. Use --repo PATH or --auto-scan --scan-root PATH." >&2
        exit 1
    fi

    while [ "${#REPOS[@]}" -eq 0 ]; do
        if can_use_interactive_menu; then
            MENU_LABELS=("Auto scan (search for .git directories)" "Manual input")
            MENU_VALUES=("auto" "manual")
            MENU_ENABLED=(1 1)
            MENU_ALL_DETECTED_MODE=0
            run_menu "Project discovery" "single" "Please select one project discovery mode."
            case "$MENU_RESULT" in
                auto) collect_auto_scan_repos ;;
                manual) manual_input ;;
            esac
            continue
        fi

        echo "Project discovery:"
        echo "  [1] Auto scan (search for .git directories)"
        echo "  [2] Manual input"
        echo ""
        read_user_line "Enter choice [1-2]: "
        choice="$REPLY"
        case $choice in
            1) collect_auto_scan_repos ;;
            2) manual_input ;;
            *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
        esac
    done
}

path_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

ensure_backup_root() {
    local temp_base="${TMPDIR:-/tmp}"
    local backup_base=""

    if [ -n "$BACKUP_ROOT" ]; then
        return
    fi

    temp_base="${temp_base%/}"
    backup_base="$temp_base/agent-repo-router-skill-backups"
    mkdir -p "$backup_base"
    BACKUP_ROOT="$(mktemp -d "$backup_base/install-$(date +%Y%m%d-%H%M%S)-XXXXXXXX")"
}

next_backup_dir() {
    local target_path="$1"
    local source_label="$2"
    local name="${source_label}-$(basename "$target_path")"
    local backup_dir=""
    local backup_index=0

    ensure_backup_root
    backup_dir="$BACKUP_ROOT/$name"
    while path_exists "$backup_dir"; do
        backup_index=$((backup_index + 1))
        backup_dir="$BACKUP_ROOT/${name}_${backup_index}"
    done

    echo "$backup_dir"
}

select_existing_action() {
    local label="$1"
    local target_path="$2"
    local choice=""

    SELECTED_EXISTING_ACTION=""
    if [ "$EXISTING_ARG_SET" -eq 1 ] || [ "$YES" -eq 1 ]; then
        SELECTED_EXISTING_ACTION="$EXISTING"
        return
    fi

    echo "Existing $label detected: $target_path"

    if can_use_interactive_menu; then
        MENU_LABELS=("Backup existing target" "Overwrite existing target" "Skip install")
        MENU_VALUES=("backup" "overwrite" "skip")
        MENU_ENABLED=(1 1 1)
        MENU_ALL_DETECTED_MODE=0
        run_menu "Install target already exists" "single" "Please choose how to handle the existing target."
        SELECTED_EXISTING_ACTION="$MENU_RESULT"
        return
    fi

    echo "Install target already exists:"
    echo "  [1] Overwrite existing target"
    echo "  [2] Backup existing target"
    echo "  [3] Skip install"
    echo ""
    while true; do
        read_user_line "Enter choice [1-3, default 2]: "
        choice="$REPLY"
        case $choice in
            1) SELECTED_EXISTING_ACTION="overwrite"; return ;;
            ""|2) SELECTED_EXISTING_ACTION="backup"; return ;;
            3) SELECTED_EXISTING_ACTION="skip"; return ;;
            *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
        esac
    done
}

prepare_existing_path() {
    local target_path="$1"
    local label="$2"
    local source_label="${3:-canonical}"
    local backup_dir=""
    local action=""
    local link_target=""

    if ! path_exists "$target_path"; then
        return 0
    fi

    if get_recorded_existing_action "$target_path"; then
        action="$SELECTED_EXISTING_ACTION"
    else
        select_existing_action "$label" "$target_path"
        action="$SELECTED_EXISTING_ACTION"
    fi
    case "$action" in
        overwrite)
            if [ -L "$target_path" ]; then
                link_target="$(readlink "$target_path" 2>/dev/null || true)"
                rm -f "$target_path"
                echo -e "${GREEN}✓ Removed existing symlink $target_path -> $link_target${NC}"
            else
                rm -rf "$target_path"
                echo -e "${GREEN}✓ Overwrote existing $label${NC}"
            fi
            ;;
        backup)
            if [ -L "$target_path" ]; then
                link_target="$(readlink "$target_path" 2>/dev/null || true)"
                rm -f "$target_path"
                echo -e "${GREEN}✓ Removed existing symlink $target_path -> $link_target${NC}"
            else
                ensure_backup_root
                backup_dir="$(next_backup_dir "$target_path" "$source_label")"
                mv "$target_path" "$backup_dir"
                BACKUP_OCCURRED=1
                echo -e "${GREEN}✓ Backed up existing $label to $backup_dir${NC}"
            fi
            ;;
        skip)
            echo "Skipping install because $label already exists: $target_path"
            return 1
            ;;
    esac
    echo ""
    return 0
}

reset_existing_decisions() {
    EXISTING_DECISION_PATHS=()
    EXISTING_DECISION_ACTIONS=()
}

record_existing_decision() {
    local target_path="$1"
    local action="$2"

    EXISTING_DECISION_PATHS+=("$target_path")
    EXISTING_DECISION_ACTIONS+=("$action")
}

get_recorded_existing_action() {
    local target_path="$1"
    local index=0

    SELECTED_EXISTING_ACTION=""
    for index in "${!EXISTING_DECISION_PATHS[@]}"; do
        if [ "${EXISTING_DECISION_PATHS[$index]}" = "$target_path" ]; then
            SELECTED_EXISTING_ACTION="${EXISTING_DECISION_ACTIONS[$index]}"
            return 0
        fi
    done

    return 1
}

plan_existing_target() {
    local target_path="$1"
    local label="$2"
    local action=""

    if ! path_exists "$target_path"; then
        return 0
    fi

    select_existing_action "$label" "$target_path"
    action="$SELECTED_EXISTING_ACTION"
    if [ "$action" = "skip" ]; then
        echo "Skipping install because $label already exists: $target_path"
        return 1
    fi

    record_existing_decision "$target_path" "$action"
    return 0
}

prepare_install_dir() {
    local target_path="$1"
    local label="$2"
    local source_label="$3"

    if ! prepare_existing_path "$target_path" "$label" "$source_label"; then
        return 1
    fi
    mkdir -p "$target_path"
}

prepare_link_target() {
    local target_path="$1"
    local source_label="$2"

    if ! prepare_existing_path "$target_path" "host skill target" "$source_label"; then
        return 1
    fi
    mkdir -p "$(dirname "$target_path")"
}

print_backup_summary() {
    if [ "$BACKUP_OCCURRED" -eq 0 ]; then
        return
    fi

    echo ""
    echo "Backups moved to:"
    echo "  $BACKUP_ROOT"
    echo "Temporary backups are stored under the system temp directory and may be removed by the operating system later."
    echo ""
}

preflight_existing_targets() {
    local host_name=""
    local host_dir=""

    reset_existing_decisions
    if ! plan_existing_target "$INSTALL_TARGET_DIR" "$INSTALL_MODE install target"; then
        return 1
    fi

    if [ "$INSTALL_STRATEGY" != "symlink" ]; then
        return 0
    fi

    for host_name in ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; do
        host_dir="$(get_host_dir "$host_name")"
        if [ "$host_dir" = "$CANONICAL_SKILL_DIR" ]; then
            continue
        fi
        if ! plan_existing_target "$host_dir" "host skill target"; then
            return 1
        fi
    done

    return 0
}

resolve_install_strategy() {
    local selected_count="${#SELECTED_INSTALL_HOSTS[@]}"
    local host_name

    CONFIG_INSTALL_HOSTS=()

    if [ "$INSTALL_MODE" = "global" ]; then
        INSTALL_STRATEGY="symlink"
        INSTALL_TARGET_DIR="$CANONICAL_SKILL_DIR"
        CONFIG_INSTALL_HOSTS=("global")
        for host_name in ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; do
            CONFIG_INSTALL_HOSTS+=("$host_name")
        done
    elif [ "$INSTALL_MODE" = "custom" ]; then
        INSTALL_STRATEGY="symlink"
        INSTALL_TARGET_DIR="$CANONICAL_SKILL_DIR"
        CONFIG_INSTALL_HOSTS=(${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"})
    elif [ "$selected_count" -eq 1 ]; then
        INSTALL_STRATEGY="direct"
        INSTALL_TARGET_DIR="$(get_host_dir "${SELECTED_INSTALL_HOSTS[0]}")"
        CONFIG_INSTALL_HOSTS=("${SELECTED_INSTALL_HOSTS[0]}")
        INSTALL_MODE="single"
    else
        INSTALL_STRATEGY="symlink"
        INSTALL_TARGET_DIR="$CANONICAL_SKILL_DIR"
        CONFIG_INSTALL_HOSTS=(${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"})
    fi

    CONFIG_PATH="$INSTALL_TARGET_DIR/references/repo_mappings.json"
}

prepare_install_targets() {
    local host_name
    local host_dir
    local install_target_source_label="canonical"

    resolve_install_strategy
    if [ "$INSTALL_TARGET_DIR" != "$CANONICAL_SKILL_DIR" ] && [ "$INSTALL_STRATEGY" = "direct" ] && [ "${#SELECTED_INSTALL_HOSTS[@]}" -eq 1 ]; then
        install_target_source_label="${SELECTED_INSTALL_HOSTS[0]}"
    fi

    if ! preflight_existing_targets; then
        exit 0
    fi

    if ! prepare_install_dir "$INSTALL_TARGET_DIR" "$INSTALL_MODE install target" "$install_target_source_label"; then
        exit 0
    fi

    if [ "$INSTALL_STRATEGY" != "symlink" ]; then
        echo -e "${GREEN}✓ Direct install target: $(display_path "$INSTALL_TARGET_DIR")${NC}"
        if [ "${SELECTED_INSTALL_HOSTS[0]}" = "codex" ]; then
            echo -e "${YELLOW}Codex single-host installs directly to ~/.agents/skills; no ~/.codex/skills symlink is created.${NC}"
        fi
        echo ""
        return
    fi

    for host_name in ${SELECTED_INSTALL_HOSTS[@]+"${SELECTED_INSTALL_HOSTS[@]}"}; do
        host_dir="$(get_host_dir "$host_name")"
        if [ "$host_dir" = "$CANONICAL_SKILL_DIR" ]; then
            echo -e "${GREEN}✓ $(get_host_label "$host_name") uses canonical install target $(display_path "$CANONICAL_SKILL_DIR")${NC}"
            continue
        fi
        if ! prepare_link_target "$host_dir" "$host_name"; then
            exit 0
        fi
        ln -s "$CANONICAL_SKILL_DIR" "$host_dir"
        echo -e "${GREEN}✓ Linked $(get_host_label "$host_name") to $CANONICAL_SKILL_DIR${NC}"
    done
    echo ""
}

generate_config() {
    local repo_list_file=""
    local install_hosts_csv

    echo "Generating $CONFIG_PATH..."

    mkdir -p "$(dirname "$CONFIG_PATH")"

    repo_list_file="$(mktemp)"
    printf '%s\n' "${REPOS[@]}" > "$repo_list_file"
    install_hosts_csv="$(join_by_comma "${CONFIG_INSTALL_HOSTS[@]}")"

    node - "$CONFIG_PATH" "$REPO_MAPPINGS_SCHEMA_VERSION" "$INSTALL_MODE" "$install_hosts_csv" "$repo_list_file" "${SELECTED_CLIS[@]}" <<'EOF'
const fs = require("node:fs");
const path = require("node:path");

const [, , configPath, schemaVersionRaw, installMode, installHostsRaw, repoListPath, ...selectedClis] = process.argv;

const PROJECT_ASSET_LOCATIONS = {
  skills: {
    "claude-code": { root: path.join(".claude", "skills"), kind: "directory-skill" },
    opencode: { root: path.join(".opencode", "skills"), kind: "directory-skill" },
    codex: { root: path.join(".agents", "skills"), kind: "directory-skill" },
    hermes: { root: path.join(".agents", "skills"), kind: "directory-skill" },
  },
  agents: {
    "claude-code": { root: path.join(".claude", "agents"), kind: "markdown-file" },
    opencode: { root: path.join(".opencode", "agents"), kind: "markdown-file" },
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
    if (line.startsWith("#") || line.startsWith(">") || /^[-*]\s/.test(line)) {
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

const installHosts = installHostsRaw
  .split(",")
  .map((host) => host.trim())
  .filter(Boolean);

const payload = {
  schemaVersion: Number(schemaVersionRaw),
  installMode,
  installHosts,
  executionClis: selectedClis,
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

    validate_repo_mappings "$CONFIG_PATH"

    echo -e "${GREEN}✓ Created $CONFIG_PATH${NC}"
    echo ""
}

deploy_skill() {
    local script_dir
    local skill_zh_local
    local skill_en_local
    local guide_zh_local
    local guide_en_local
    local skill_src_zh=""
    local skill_src_en=""
    local guide_src_zh=""
    local guide_src_en=""
    local tmp_skill_zh=""
    local tmp_skill_en=""
    local tmp_guide_zh=""
    local tmp_guide_en=""
    local skill_dest="$INSTALL_TARGET_DIR/SKILL.md"
    local references_dest_dir="$INSTALL_TARGET_DIR/references"

    echo "Deploying $SKILL_NAME skill..."

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    skill_zh_local="$script_dir/../skills/$SKILL_SLUG/SKILL.zh.md"
    skill_en_local="$script_dir/../skills/$SKILL_SLUG/SKILL.en.md"
    guide_zh_local="$script_dir/../skills/$SKILL_SLUG/references/guide.zh.md"
    guide_en_local="$script_dir/../skills/$SKILL_SLUG/references/guide.en.md"

    if should_use_local_file "$skill_zh_local"; then
        skill_src_zh="$skill_zh_local"
    else
        tmp_skill_zh="$(mktemp)"
        if ! download_remote_file "skills/$SKILL_SLUG/SKILL.zh.md" "$tmp_skill_zh"; then
            rm -f "$tmp_skill_zh"
            exit 1
        fi
        skill_src_zh="$tmp_skill_zh"
    fi

    if should_use_local_file "$skill_en_local"; then
        skill_src_en="$skill_en_local"
    else
        tmp_skill_en="$(mktemp)"
        if ! download_remote_file "skills/$SKILL_SLUG/SKILL.en.md" "$tmp_skill_en"; then
            rm -f "$tmp_skill_zh" "$tmp_skill_en"
            exit 1
        fi
        skill_src_en="$tmp_skill_en"
    fi

    if should_use_local_file "$guide_zh_local"; then
        guide_src_zh="$guide_zh_local"
    else
        tmp_guide_zh="$(mktemp)"
        if download_remote_file "skills/$SKILL_SLUG/references/guide.zh.md" "$tmp_guide_zh"; then
            guide_src_zh="$tmp_guide_zh"
        else
            rm -f "$tmp_guide_zh"
            tmp_guide_zh=""
        fi
    fi

    if should_use_local_file "$guide_en_local"; then
        guide_src_en="$guide_en_local"
    else
        tmp_guide_en="$(mktemp)"
        if download_remote_file "skills/$SKILL_SLUG/references/guide.en.md" "$tmp_guide_en"; then
            guide_src_en="$tmp_guide_en"
        else
            rm -f "$tmp_guide_en"
            tmp_guide_en=""
        fi
    fi

    mkdir -p "$INSTALL_TARGET_DIR"
    mkdir -p "$references_dest_dir"

    if [ "$SKILL_LANG" = "zh" ]; then
        cp "$skill_src_zh" "$skill_dest"
        rm -f "$INSTALL_TARGET_DIR/SKILL.en.md" "$INSTALL_TARGET_DIR/SKILL.zh.md" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed Chinese version of $SKILL_NAME${NC}"
    else
        cp "$skill_src_en" "$skill_dest"
        rm -f "$INSTALL_TARGET_DIR/SKILL.zh.md" "$INSTALL_TARGET_DIR/SKILL.en.md" 2>/dev/null || true
        echo -e "${GREEN}✓ Deployed English version of $SKILL_NAME${NC}"
    fi

    if [ "$SKILL_LANG" = "zh" ]; then
        if [ -n "$guide_src_zh" ] && [ -f "$guide_src_zh" ]; then
            cp "$guide_src_zh" "$references_dest_dir/guide.zh.md"
        fi
        rm -f "$references_dest_dir/guide.en.md"
    else
        if [ -n "$guide_src_en" ] && [ -f "$guide_src_en" ]; then
            cp "$guide_src_en" "$references_dest_dir/guide.en.md"
        fi
        rm -f "$references_dest_dir/guide.zh.md"
    fi

    rm -f "$tmp_skill_zh" "$tmp_skill_en" "$tmp_guide_zh" "$tmp_guide_en"

    echo ""
}

main() {
    echo "=========================================="
    echo "  $SKILL_NAME Installation Script"
    echo "=========================================="
    echo ""

    parse_args "$@"
    check_environment
    select_language
    select_install_mode
    select_clis
    discover_projects
    prepare_install_targets
    generate_config
    deploy_skill
    print_backup_summary

    echo "=========================================="
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Use the agent host you installed into"
    echo "  2. Invoke the skill as $SKILL_SLUG"
    echo "  3. Edit $CONFIG_PATH to add repo aliases or review detected skills and agents"
    echo ""
}

main "$@"
