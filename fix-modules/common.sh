#!/bin/bash

RESET=$'\e[0m'
BOLD=$'\e[1m'
WHITE=$'\e[97m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
RED=$'\e[31m'
MAGENTA=$'\e[35m'
LIGHT_PURPLE=$'\e[95m'

SUCCESS_ICON="${GREEN}✔${RESET}"
WARNING_ICON="${YELLOW}⚠${RESET}"
ERROR_ICON="${RED}✘${RESET}"
INFO_ICON="${WHITE}ℹ${RESET}"
DEBUG_ICON="${LIGHT_PURPLE}⚙${RESET}"
PROMPT_ICON="${MAGENTA}?${RESET}"

_printf_aligned() {
    local icon=$1
    local color=$2
    local label=$3
    local message=$4
    local tip=$5
    local newline=${6:-"\n"}
    
    local label_width=10

    local label_color=${color:-"${WHITE}"}

    printf "%b ${label_color}%-${label_width}s${RESET} %s%b" "${icon}" "${label}" "${message}" "${newline}"

    if [ -n "${tip}" ]; then 
        printf "%b %-${label_width}s %s\n" " " "" "${tip}"
    fi
}

printf_success() {
    if [ "${FLAGS_success}" -eq "${FLAGS_FALSE}" ]; then return; fi
    _printf_aligned "${SUCCESS_ICON}" "${GREEN}${BOLD}" "$1" "$2" "$3"
}

printf_warning() {
    if [ "${FLAGS_warning}" -eq "${FLAGS_FALSE}" ]; then return; fi
    _printf_aligned "${WARNING_ICON}" "${YELLOW}${BOLD}" "$1" "$2" "$3"
}

printf_error() {
    # Errors should typically always show unless specifically muted via success/warning flags (rare)
    _printf_aligned "${ERROR_ICON}" "${RED}${BOLD}" "$1" "$2" "$3"
}

printf_info() {
    if [ "${FLAGS_info}" -eq "${FLAGS_FALSE}" ]; then return; fi
    _printf_aligned "${INFO_ICON}" "${WHITE}${BOLD}" "$1" "$2" "$3"
}

printf_debug() {
    if [ "${FLAGS_debug}" -eq "${FLAGS_FALSE}" ]; then return; fi
    _printf_aligned "${DEBUG_ICON}" "${LIGHT_PURPLE}${BOLD}" "$1" "$2" "$3"
}

printf_prompt() {
    _printf_aligned "${PROMPT_ICON}" "${MAGENTA}${BOLD}" "$1" "$2" "$3" " "
}


printf_simple() {
    if [ "${FLAGS_info}" -eq "${FLAGS_FALSE}" ]; then return; fi
    _printf_aligned " " "" "$1" "$2" "$3"
}

# Spinner State
SPIN_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPIN_S_IDX=0

# Internal Spinner Helper
_update_spinner_frame() {
    SPIN_FRAME="${SPIN_CHARS:SPIN_S_IDX:1}"
    SPIN_S_IDX=$(((SPIN_S_IDX + 1) % ${#SPIN_CHARS}))
}

spinner() {
    local msg_prefix=$1
    local handler=$2

    if [ "${FLAGS_info}" -eq "${FLAGS_FALSE}" ]; then
        for idx in "${!MODULE_PIDS[@]}"; do
            wait "${MODULE_PIDS[$idx]}" 2>/dev/null
            $handler "${MODULE_NAMES[$idx]}" "${MODULE_PIDS[$idx]}"
        done
        return
    fi

    trap 'kill -TERM "${MODULE_PIDS[@]}" 2>/dev/null; exit 1' SIGINT SIGTERM

    local pending_ids=("${!MODULE_PIDS[@]}")
    local active_rows=0

    while [ ${#pending_ids[@]} -gt 0 ]; do
        local still_running=()
        local just_finished=()

        for idx in "${pending_ids[@]}"; do
            if kill -0 "${MODULE_PIDS[$idx]}" 2>/dev/null; then
                still_running+=("$idx")
            else
                just_finished+=("$idx")
            fi
        done

        for ((k=0; k<active_rows; k++)); do
            printf "\033[A\r\033[K"
        done

        for idx in "${just_finished[@]}"; do
            $handler "${MODULE_NAMES[$idx]}" "${MODULE_PIDS[$idx]}"
        done

        _update_spinner_frame
        active_rows=0
        for idx in "${still_running[@]}"; do
            _printf_aligned "${CYAN}${SPIN_FRAME}${RESET}" "${WHITE}${BOLD}" "${MODULE_NAMES[$idx]}" "Checking..." "" "\n"
            ((active_rows++))
        done

        pending_ids=("${still_running[@]}")
        [ ${#pending_ids[@]} -eq 0 ] && break
        sleep 0.1
    done
    if [ "${FLAGS_info}" -eq "${FLAGS_TRUE}" ]; then printf "\r\033[K"; fi
    
    trap - SIGINT SIGTERM
}

confirm() {
    local prompt=$1
    
    if [ "${FLAGS_apply}" -eq "${FLAGS_TRUE}" ]; then
        return 0
    fi

    printf "\n"
    printf_prompt "PROCEED" "${BOLD}${prompt} [Y/n] ${RESET}"
    
    read -r response
    response=${response,,} # tolower
    
    if [[ "$response" =~ ^(yes|y|)$ ]]; then
        return 0
    fi
    return 1
}
