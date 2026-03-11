#!/bin/bash

# Spinner Dependency
# Expects common.sh to be sourced for _printf_aligned and color variables

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
