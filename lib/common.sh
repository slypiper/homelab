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

# System Information
declare -A OS_INFO
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_INFO[NAME]=$NAME
    OS_INFO[ID]=$ID
    OS_INFO[VERSION]=$VERSION
else
    OS_INFO[NAME]=$(uname -s)
    OS_INFO[ID]="unknown"
    OS_INFO[VERSION]=$(uname -r)
fi

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
