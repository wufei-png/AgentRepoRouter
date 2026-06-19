#!/usr/bin/env bash
set -e

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
# Defaults to GitHub raw for pipe installs. Set true when running from a clone.
AGENT_REPO_ROUTER_USE_LOCAL_CACHE="${AGENT_REPO_ROUTER_USE_LOCAL_CACHE:-false}"

TTY_FD=9
TTY_AVAILABLE=0
if { exec 9<>/dev/tty; } 2>/dev/null; then
    TTY_AVAILABLE=1
fi

agent_repo_router_use_local_cache() {
    case "${AGENT_REPO_ROUTER_USE_LOCAL_CACHE}" in
        1|true|TRUE|True|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

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

    for existing_path in "${REPOS[@]}"; do
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

validate_repo_mappings() {
    local script_dir
    local validate_path
    local tmp_validate=""

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    validate_path="$script_dir/validate_repo_mappings.sh"

    if agent_repo_router_use_local_cache && [ -f "$validate_path" ]; then
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
        if array_contains "$host_name" "${SELECTED_INSTALL_HOSTS[@]}"; then
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
        if array_contains "$value" "${SELECTED_INSTALL_HOSTS[@]}"; then
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
    local detected_host

    SELECTED_INSTALL_HOSTS=()
    while IFS= read -r detected_host; do
        [ -n "$detected_host" ] || continue
        SELECTED_INSTALL_HOSTS+=("$detected_host")
    done <<EOF
$(detected_install_hosts)
EOF
    if can_use_interactive_menu; then
        confirm_global_host_preview
    else
        print_host_summary
    fi
}

select_install_mode() {
    local choice=""

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

            if [ -n "$selected_host" ] && ! array_contains "$selected_host" "${SELECTED_INSTALL_HOSTS[@]}"; then
                SELECTED_INSTALL_HOSTS+=("$selected_host")
            fi
        done

        if [ "$has_all_detected" -eq 1 ]; then
            while IFS= read -r selected_host; do
                if [ -n "$selected_host" ] && ! array_contains "$selected_host" "${SELECTED_INSTALL_HOSTS[@]}"; then
                    SELECTED_INSTALL_HOSTS+=("$selected_host")
                fi
            done < <(detected_install_hosts)
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

            if ! array_contains "$selected_cli" "${SELECTED_CLIS[@]}"; then
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

auto_scan() {
    local scan_root
    local git_dir
    local repo_path
    local repo_name

    echo "Auto scan for projects..."
    echo "Enter root directory to scan (will search for .git directories):"
    read_user_line "Path: "
    scan_root="$REPLY"

    if [ ! -d "$scan_root" ]; then
        echo -e "${RED}Directory does not exist: $scan_root${NC}"
        return 1
    fi

    scan_root=$(normalize_path "$scan_root")

    echo "Scanning for git repositories..."
    REPOS=()

    while IFS= read -r git_dir; do
        repo_path=$(normalize_path "$(dirname "$git_dir")")
        repo_name=$(basename "$repo_path")

        if repo_path_exists "$repo_path"; then
            echo -e "${YELLOW}Warning: Duplicate project path filtered: $repo_path${NC}"
            continue
        fi

        REPOS+=("$repo_path")
        echo -e "  ${GREEN}✓${NC} Found: $repo_name ($repo_path)"
    done < <(find "$scan_root" -maxdepth 5 -type d -name ".git" 2>/dev/null)

    if [ "${#REPOS[@]}" -eq 0 ]; then
        echo -e "${YELLOW}No git repositories found.${NC}"
    else
        echo -e "${GREEN}Found ${#REPOS[@]} repositories${NC}"
    fi
    echo ""
}

manual_input() {
    local repo_path

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

        if [ ! -d "$repo_path" ]; then
            echo -e "${YELLOW}Warning: Directory does not exist: $repo_path${NC}"
            continue
        fi

        repo_path=$(normalize_path "$repo_path")

        if repo_path_exists "$repo_path"; then
            echo -e "${YELLOW}Warning: Duplicate project path filtered: $repo_path${NC}"
            continue
        fi

        REPOS+=("$repo_path")
        echo -e "  ${GREEN}✓${NC} Added: $repo_path"
    done

    echo ""
}

discover_projects() {
    local choice

    if can_use_interactive_menu; then
        MENU_LABELS=("Auto scan (search for .git directories)" "Manual input")
        MENU_VALUES=("auto" "manual")
        MENU_ENABLED=(1 1)
        MENU_ALL_DETECTED_MODE=0
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

next_backup_dir() {
    local target_path="$1"
    local backup_index=0
    local backup_dir=""

    while true; do
        backup_dir="${target_path}_backup_${backup_index}"
        if [ ! -e "$backup_dir" ] && [ ! -L "$backup_dir" ]; then
            echo "$backup_dir"
            return 0
        fi
        backup_index=$((backup_index + 1))
    done
}

handle_existing_link_target() {
    local target_path="$1"
    local backup_dir=""
    local choice=""

    if [ -L "$target_path" ]; then
        rm -f "$target_path"
        return
    fi

    if [ ! -e "$target_path" ]; then
        return
    fi

    echo "Existing install target detected: $target_path"

    if can_use_interactive_menu; then
        MENU_LABELS=("Delete and replace with symlink" "Backup existing target")
        MENU_VALUES=("delete" "backup")
        MENU_ENABLED=(1 1)
        MENU_ALL_DETECTED_MODE=0
        run_menu "Install target already exists" "single" "Please choose how to handle the existing target."
        choice="$MENU_RESULT"
    else
        echo "Install target already exists:"
        echo "  [1] Delete and replace with symlink"
        echo "  [2] Backup existing target"
        echo ""
        while true; do
            read_user_line "Enter choice [1-2]: "
            choice="$REPLY"
            case $choice in
                1) choice="delete"; break ;;
                2) choice="backup"; break ;;
                *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
            esac
        done
    fi

    case "$choice" in
        delete)
            rm -rf "$target_path"
            echo -e "${GREEN}✓ Deleted existing target${NC}"
            ;;
        backup)
            backup_dir="$(next_backup_dir "$target_path")"
            mv "$target_path" "$backup_dir"
            echo -e "${GREEN}✓ Backed up existing target to $backup_dir${NC}"
            ;;
    esac
    echo ""
}

resolve_install_strategy() {
    local selected_count="${#SELECTED_INSTALL_HOSTS[@]}"
    local host_name

    CONFIG_INSTALL_HOSTS=()

    if [ "$INSTALL_MODE" = "global" ]; then
        INSTALL_STRATEGY="symlink"
        INSTALL_TARGET_DIR="$CANONICAL_SKILL_DIR"
        CONFIG_INSTALL_HOSTS=("global")
        for host_name in "${SELECTED_INSTALL_HOSTS[@]}"; do
            CONFIG_INSTALL_HOSTS+=("$host_name")
        done
    elif [ "$selected_count" -eq 1 ]; then
        INSTALL_STRATEGY="direct"
        INSTALL_TARGET_DIR="$(get_host_dir "${SELECTED_INSTALL_HOSTS[0]}")"
        CONFIG_INSTALL_HOSTS=("${SELECTED_INSTALL_HOSTS[0]}")
        INSTALL_MODE="single"
    else
        INSTALL_STRATEGY="symlink"
        INSTALL_TARGET_DIR="$CANONICAL_SKILL_DIR"
        CONFIG_INSTALL_HOSTS=("${SELECTED_INSTALL_HOSTS[@]}")
    fi

    CONFIG_PATH="$INSTALL_TARGET_DIR/references/repo_mappings.json"
}

prepare_install_targets() {
    local host_name
    local host_dir

    resolve_install_strategy

    mkdir -p "$INSTALL_TARGET_DIR"

    if [ "$INSTALL_STRATEGY" != "symlink" ]; then
        echo -e "${GREEN}✓ Direct install target: $(display_path "$INSTALL_TARGET_DIR")${NC}"
        if [ "${SELECTED_INSTALL_HOSTS[0]}" = "codex" ]; then
            echo -e "${YELLOW}Codex single-host installs directly to ~/.agents/skills; no ~/.codex/skills symlink is created.${NC}"
        fi
        echo ""
        return
    fi

    for host_name in "${SELECTED_INSTALL_HOSTS[@]}"; do
        host_dir="$(get_host_dir "$host_name")"
        if [ "$host_dir" = "$CANONICAL_SKILL_DIR" ]; then
            echo -e "${GREEN}✓ $(get_host_label "$host_name") uses canonical install target $(display_path "$CANONICAL_SKILL_DIR")${NC}"
            continue
        fi
        mkdir -p "$(dirname "$host_dir")"
        handle_existing_link_target "$host_dir"
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

    if agent_repo_router_use_local_cache && [ -f "$skill_zh_local" ]; then
        skill_src_zh="$skill_zh_local"
    else
        tmp_skill_zh="$(mktemp)"
        if ! download_remote_file "skills/$SKILL_SLUG/SKILL.zh.md" "$tmp_skill_zh"; then
            rm -f "$tmp_skill_zh"
            exit 1
        fi
        skill_src_zh="$tmp_skill_zh"
    fi

    if agent_repo_router_use_local_cache && [ -f "$skill_en_local" ]; then
        skill_src_en="$skill_en_local"
    else
        tmp_skill_en="$(mktemp)"
        if ! download_remote_file "skills/$SKILL_SLUG/SKILL.en.md" "$tmp_skill_en"; then
            rm -f "$tmp_skill_zh" "$tmp_skill_en"
            exit 1
        fi
        skill_src_en="$tmp_skill_en"
    fi

    if agent_repo_router_use_local_cache && [ -f "$guide_zh_local" ]; then
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

    if agent_repo_router_use_local_cache && [ -f "$guide_en_local" ]; then
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

    check_environment
    select_language
    select_install_mode
    select_clis
    discover_projects
    prepare_install_targets
    generate_config
    deploy_skill

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
